#!/usr/bin/env python3
"""Dogbot-style experiment receipts for the Meta Wearables hackathon.

Default mode is dry-run. Use --send only after GoalBuddy approval and payload
validation. Tokens are read from DISCORD_LAB_BOT_TOKEN or DISCORD_BOT_TOKEN via
process env, Windows User env, or Codex Windows Credential Manager targets.
Token values are never printed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import ctypes
from ctypes import wintypes
from datetime import datetime, timezone
from pathlib import Path

try:
    import winreg
except ImportError:  # pragma: no cover
    winreg = None


API = "https://discord.com/api/v10"
ROOT = Path(__file__).resolve().parents[1]
CHANNEL_ID = "1505114553606733834"
CHANNEL_NAME = "dogbot"
GUILD_ID = "1504987658005516481"
PROJECT_CONTROL_CATEGORY_ID = "1504993811267457096"
PROJECT_CONTROL_CATEGORY_LABEL = "PROJECT CONTROL category"
MANIFEST = ROOT / "final_docs" / "discord-experiment-manifest.json"
PENDING_RECEIPTS = ROOT / "final_docs" / "overnight" / "dogbot-pending-receipts.jsonl"
SAFE_SCREENSHOT_DIRS = [
    (ROOT / "final_docs" / "overnight").resolve(),
    (ROOT / "final_docs" / "screenshots").resolve(),
]
PRIVATE_PATTERN = re.compile(
    r"(C:\\|C:/|Users[\\/]+nicof|DISCORD_[A-Z_]*=|OPENAI_API_KEY=|GEMINI_API_KEY=|GOOGLE_API_KEY=|sk-[A-Za-z0-9])",
    re.IGNORECASE,
)


def read_user_env(name: str) -> str | None:
    process_value = os.environ.get(name)
    if winreg is None:
        return process_value
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment")
        user_value = winreg.QueryValueEx(key, name)[0]
        if user_value:
            return user_value
    except OSError:
        pass
    return process_value


def read_credential_manager_secret(target: str) -> str | None:
    if os.name != "nt":
        return None

    CRED_TYPE_GENERIC = 1
    ERROR_NOT_FOUND = 1168

    class FILETIME(ctypes.Structure):
        _fields_ = [
            ("dwLowDateTime", wintypes.DWORD),
            ("dwHighDateTime", wintypes.DWORD),
        ]

    class CREDENTIAL(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD),
            ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR),
            ("LastWritten", FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.c_void_p),
            ("Persist", wintypes.DWORD),
            ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR),
            ("UserName", wintypes.LPWSTR),
        ]

    credential_ptr = ctypes.c_void_p()
    advapi32 = ctypes.windll.advapi32
    advapi32.CredReadW.argtypes = [
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.DWORD,
        ctypes.POINTER(ctypes.c_void_p),
    ]
    advapi32.CredReadW.restype = wintypes.BOOL
    advapi32.CredFree.argtypes = [ctypes.c_void_p]
    advapi32.CredFree.restype = None

    if not advapi32.CredReadW(target, CRED_TYPE_GENERIC, 0, ctypes.byref(credential_ptr)):
        if ctypes.get_last_error() == ERROR_NOT_FOUND:
            return None
        return None

    try:
        credential = ctypes.cast(credential_ptr, ctypes.POINTER(CREDENTIAL)).contents
        if not credential.CredentialBlob or credential.CredentialBlobSize <= 0:
            return None
        char_count = credential.CredentialBlobSize // ctypes.sizeof(wintypes.WCHAR)
        return ctypes.wstring_at(credential.CredentialBlob, char_count)
    finally:
        advapi32.CredFree(credential_ptr)


def read_env_sources(name: str) -> list[tuple[str, str]]:
    values: list[tuple[str, str]] = []
    user_value = None
    if winreg is not None:
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment")
            user_value = winreg.QueryValueEx(key, name)[0]
        except OSError:
            user_value = None
    process_value = os.environ.get(name)
    if user_value:
        values.append((f"{name}/User", user_value))
    if process_value and process_value != user_value:
        values.append((f"{name}/Process", process_value))
    credential_value = read_credential_manager_secret(f"Codex:{name}")
    if credential_value and credential_value not in {user_value, process_value}:
        values.append((f"{name}/CredentialManager", credential_value))
    return values


def token_candidates() -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []
    seen: set[str] = set()
    for name in ("DISCORD_LAB_BOT_TOKEN", "DISCORD_BOT_TOKEN"):
        for label, value in read_env_sources(name):
            if not value or value in seen:
                continue
            seen.add(value)
            candidates.append((label, value))
    if not candidates:
        raise SystemExit("DISCORD_LAB_BOT_TOKEN or DISCORD_BOT_TOKEN is required for --send or audit.")
    return candidates


def token() -> str:
    return token_candidates()[0][1]


def curl_json(method: str, route: str, payload: dict | None = None) -> dict:
    auth_failures = []
    for label, candidate_token in token_candidates():
        for attempt in range(4):
            cmd = [
                "curl.exe",
                "-sS",
                "-w",
                "\n%{http_code}",
                "-X",
                method,
                "-H",
                f"Authorization: Bot {candidate_token}",
                "-H",
                "Content-Type: application/json",
                "-H",
                "User-Agent: Dogbot-Experiment-Control/1.0",
            ]
            if payload is not None:
                cmd += ["--data-binary", json.dumps(payload)]
            cmd.append(f"{API}{route}")
            out = subprocess.check_output(cmd, text=True)
            lines = out.splitlines()
            status = int(lines[-1]) if lines and lines[-1].isdigit() else 0
            body = "\n".join(lines[:-1]).strip()
            data = json.loads(body) if body else {}
            if status == 429:
                retry_after = float(data.get("retry_after", 1.0))
                time.sleep(max(0.5, retry_after) + (0.25 * attempt))
                continue
            if status in {401, 403}:
                auth_failures.append(f"{label}: HTTP {status} {data}")
                break
            if status >= 400:
                raise SystemExit(f"Discord API {method} {route} failed with HTTP {status}: {data}")
            return data
        else:
            raise SystemExit(f"Discord API {method} {route} remained rate-limited after retries for {label}.")
    raise SystemExit(f"Discord API {method} {route} failed auth/access for all saved bot tokens: {'; '.join(auth_failures)}")


def curl_upload(route: str, payload: dict, files: list[Path]) -> dict:
    fd, payload_name = tempfile.mkstemp(prefix="dogbot-payload-", suffix=".json")
    payload_file = Path(payload_name)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(payload, handle)
    try:
        auth_failures = []
        for label, candidate_token in token_candidates():
            for attempt in range(4):
                cmd = [
                    "curl.exe",
                    "-sS",
                    "-w",
                    "\n%{http_code}",
                    "-X",
                    "POST",
                    "-H",
                    f"Authorization: Bot {candidate_token}",
                    "-H",
                    "User-Agent: Dogbot-Experiment-Control/1.0",
                    "-F",
                    f"payload_json=<{payload_file.as_posix()};type=application/json",
                ]
                for index, file_path in enumerate(files):
                    cmd += ["-F", f"files[{index}]=@{file_path.as_posix()}"]
                cmd.append(f"{API}{route}")
                out = subprocess.check_output(cmd, text=True)
                lines = out.splitlines()
                status = int(lines[-1]) if lines and lines[-1].isdigit() else 0
                body = "\n".join(lines[:-1]).strip()
                data = json.loads(body) if body else {}
                if status == 429:
                    retry_after = float(data.get("retry_after", 1.0))
                    time.sleep(max(0.5, retry_after) + (0.25 * attempt))
                    continue
                if status in {401, 403}:
                    auth_failures.append(f"{label}: HTTP {status} {data}")
                    break
                if status >= 400:
                    raise SystemExit(f"Discord API POST {route} upload failed with HTTP {status}: {data}")
                return data
            else:
                raise SystemExit(f"Discord API POST {route} upload remained rate-limited after retries for {label}.")
        raise SystemExit(f"Discord API POST {route} upload failed auth/access for all saved bot tokens: {'; '.join(auth_failures)}")
    finally:
        if payload_file.exists():
            payload_file.unlink()


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {
        "guild_id": GUILD_ID,
        "channel_id": CHANNEL_ID,
        "channel_name": CHANNEL_NAME,
        "project_control_category_id": PROJECT_CONTROL_CATEGORY_ID,
        "messages": [],
    }


def save_manifest(manifest: dict) -> None:
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def append_pending(args: argparse.Namespace, payload: dict, screenshots: list[Path], reason: str) -> None:
    PENDING_RECEIPTS.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "queued_at": datetime.now(timezone.utc).isoformat(),
        "reason": reason,
        "experiment_id": args.experiment_id,
        "title": args.title,
        "summary": args.summary,
        "why": args.why,
        "lane": args.lane,
        "tests": list(args.test),
        "changed_files": list(args.changed_file),
        "screenshots": [path.relative_to(ROOT).as_posix() for path in screenshots],
        "payload": payload,
    }
    with PENDING_RECEIPTS.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def manifest_experiment_ids() -> set[str]:
    manifest = load_manifest()
    return {str(item.get("experiment_id")) for item in manifest.get("messages", []) if item.get("experiment_id")}


def payload_verdict(payload: dict) -> str:
    for embed in payload.get("embeds", []):
        for field in embed.get("fields", []):
            if field.get("name") == "Verdict":
                return str(field.get("value") or "accepted")
    return "accepted"


def payload_title(payload: dict) -> str | None:
    for embed in payload.get("embeds", []):
        title = embed.get("title")
        if title:
            return str(title)
    return None


def record_manifest_message(experiment_id: str, message_id: str, screenshots: list[Path], payload: dict) -> None:
    manifest = load_manifest()
    manifest["guild_id"] = GUILD_ID
    manifest["channel_id"] = CHANNEL_ID
    manifest["channel_name"] = CHANNEL_NAME
    manifest["project_control_category_id"] = PROJECT_CONTROL_CATEGORY_ID
    existing = manifest_experiment_ids()
    if experiment_id in existing:
        return
    manifest.setdefault("messages", []).append(
        {
            "experiment_id": experiment_id,
            "message_id": message_id,
            "channel_id": CHANNEL_ID,
            "channel_name": CHANNEL_NAME,
            "project_control_category_id": PROJECT_CONTROL_CATEGORY_ID,
            "sent_at": datetime.now(timezone.utc).isoformat(),
            "receipt_kind": payload_verdict(payload),
            "payload_title": payload_title(payload),
            "screenshot_count": len(screenshots),
            "screenshots": [path.relative_to(ROOT).as_posix() for path in screenshots],
        }
    )
    save_manifest(manifest)


def safe_text(value: str) -> str:
    if PRIVATE_PATTERN.search(value):
        raise SystemExit("Refusing to post private paths, secrets, or token-looking text.")
    return value.strip()


def safe_rel_path(value: str) -> str:
    safe_text(value)
    return value.replace("\\", "/").strip()


def safe_screenshots(paths: list[str]) -> list[Path]:
    safe = []
    for raw_path in paths:
        path = (ROOT / raw_path).resolve() if not Path(raw_path).is_absolute() else Path(raw_path).resolve()
        if not path.exists():
            raise SystemExit(f"Screenshot does not exist: {raw_path}")
        if path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
            raise SystemExit(f"Unsupported screenshot type: {raw_path}")
        if not any(str(path).startswith(str(root)) for root in SAFE_SCREENSHOT_DIRS):
            raise SystemExit(f"Screenshot must be under final_docs/overnight or final_docs/screenshots: {raw_path}")
        safe.append(path)
    return safe


def get_channel_status() -> dict:
    channel = curl_json("GET", f"/channels/{CHANNEL_ID}")
    return {
        "channel_id": channel.get("id"),
        "channel_name": channel.get("name"),
        "guild_id": channel.get("guild_id"),
        "parent_category_id": channel.get("parent_id"),
        "expected_project_control_category_id": PROJECT_CONTROL_CATEGORY_ID,
        "under_project_control": channel.get("parent_id") == PROJECT_CONTROL_CATEGORY_ID,
    }


def verify_channel() -> None:
    channel = get_channel_status()
    if channel.get("channel_id") != CHANNEL_ID or channel.get("channel_name") != CHANNEL_NAME or channel.get("guild_id") != GUILD_ID:
        raise SystemExit(f"Refusing to send: channel mismatch {channel}")
    if not channel.get("under_project_control"):
        raise SystemExit(f"Refusing to send: #{CHANNEL_NAME} is not under the project-control category.")


def add_reaction(channel_id: str, message_id: str, emoji: str) -> None:
    encoded = urllib.parse.quote(emoji)
    curl_json("PUT", f"/channels/{channel_id}/messages/{message_id}/reactions/{encoded}/@me")
    time.sleep(0.25)


def build_success_payload(args: argparse.Namespace, screenshots: list[Path]) -> dict:
    tests = "\n".join(f"- {safe_text(item)}" for item in args.test)
    files = "\n".join(f"- `{safe_rel_path(item)}`" for item in args.changed_file)
    fields = [
        {"name": "Experiment", "value": safe_text(args.experiment_id), "inline": True},
        {"name": "Lane", "value": safe_text(args.lane), "inline": True},
        {"name": "Verdict", "value": "accepted", "inline": True},
        {
            "name": "Control surface",
            "value": f"#{CHANNEL_NAME} inside {PROJECT_CONTROL_CATEGORY_LABEL} (`{CHANNEL_ID}`)",
            "inline": False,
        },
        {"name": "Technical proof", "value": safe_text(args.why)[:1024], "inline": False},
        {"name": "Tests", "value": tests[:1024] or "not recorded", "inline": False},
        {"name": "Changed files", "value": files[:1024] or "not recorded", "inline": False},
    ]
    embed = {
        "title": f"Disease Scout accepted experiment: {safe_text(args.title)}",
        "description": safe_text(args.summary)[:2048],
        "color": 0x365B43,
        "fields": fields,
        "footer": {"text": "Dogbot project-control (#dogbot) - Disease Scout Memory"},
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if screenshots:
        embed["image"] = {"url": f"attachment://{screenshots[0].name}"}
    return {
        "content": "",
        "embeds": [embed],
        "allowed_mentions": {"parse": []},
    }


def mark_payload_queued(payload: dict) -> dict:
    """Make a local queue receipt visibly distinct from a posted acceptance."""
    for embed in payload.get("embeds", []):
        title = embed.get("title", "")
        if title.startswith("Disease Scout accepted experiment:"):
            embed["title"] = title.replace("Disease Scout accepted experiment:", "Disease Scout queued local receipt:", 1)
        for field in embed.get("fields", []):
            if field.get("name") == "Verdict":
                field["value"] = "queued-local"
    return payload


def send_success_payload(experiment_id: str, payload: dict, screenshots: list[Path]) -> str:
    verify_channel()
    if screenshots:
        result = curl_upload(f"/channels/{CHANNEL_ID}/messages", payload, screenshots)
    else:
        result = curl_json("POST", f"/channels/{CHANNEL_ID}/messages", payload)
    if not result.get("id"):
        raise SystemExit(f"Discord send failed: {result}")

    add_reaction(CHANNEL_ID, result["id"], "\U0001F44D")
    add_reaction(CHANNEL_ID, result["id"], "\U0001F44E")
    record_manifest_message(experiment_id, result["id"], screenshots, payload)
    return result["id"]


def command_success(args: argparse.Namespace) -> int:
    screenshots = safe_screenshots(args.screenshot)
    payload = build_success_payload(args, screenshots)
    manifest_preview = {
        "experiment_id": args.experiment_id,
        "channel_id": CHANNEL_ID,
        "dry_run": not args.send,
        "screenshot_count": len(screenshots),
        "payload": payload,
    }

    if args.queue_only:
        payload = mark_payload_queued(payload)
        append_pending(args, payload, screenshots, "queue_only")
        print(json.dumps({"queued": True, "pending_path": PENDING_RECEIPTS.as_posix(), "experiment_id": args.experiment_id}, indent=2))
        return 0

    if not args.send:
        print(json.dumps(manifest_preview, indent=2))
        return 0

    try:
        message_id = send_success_payload(args.experiment_id, payload, screenshots)
    except SystemExit as exc:
        if args.queue_on_fail:
            payload = mark_payload_queued(payload)
            append_pending(args, payload, screenshots, str(exc))
            print(
                json.dumps(
                    {
                        "queued": True,
                        "pending_path": PENDING_RECEIPTS.as_posix(),
                        "experiment_id": args.experiment_id,
                        "send_error": str(exc),
                    },
                    indent=2,
                )
            )
            return 2
        raise
    print(json.dumps({"sent": True, "message_id": message_id, "reactions_added": ["thumbs_up", "thumbs_down"]}, indent=2))
    return 0


def command_flush_pending(args: argparse.Namespace) -> int:
    if not PENDING_RECEIPTS.exists():
        print(json.dumps({"pending_path": PENDING_RECEIPTS.as_posix(), "sent": [], "skipped": [], "remaining": 0}, indent=2))
        return 0

    existing = manifest_experiment_ids()
    sent = []
    skipped = []
    failures = []
    records = []
    for line in PENDING_RECEIPTS.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        records.append(json.loads(line))

    remaining_records = []
    for index, record in enumerate(records):
        experiment_id = str(record.get("experiment_id"))
        if experiment_id in existing:
            skipped.append({"experiment_id": experiment_id, "reason": "already_in_manifest"})
            continue
        try:
            screenshots = safe_screenshots(record.get("screenshots", []))
            message_id = send_success_payload(experiment_id, record["payload"], screenshots)
            existing.add(experiment_id)
            sent.append({"experiment_id": experiment_id, "message_id": message_id})
            time.sleep(0.5)
        except SystemExit as exc:
            failures.append({"experiment_id": experiment_id, "error": str(exc)})
            remaining_records.append(record)
            remaining_records.extend(records[index + 1 :])
            break

    if remaining_records:
        with PENDING_RECEIPTS.open("w", encoding="utf-8") as handle:
            for record in remaining_records:
                handle.write(json.dumps(record, sort_keys=True) + "\n")
    elif sent or skipped:
        PENDING_RECEIPTS.unlink(missing_ok=True)

    print(
        json.dumps(
            {
                "pending_path": PENDING_RECEIPTS.as_posix(),
                "sent": sent,
                "skipped": skipped,
                "failures": failures,
                "remaining": len(remaining_records),
            },
            indent=2,
        )
    )
    return 0 if not failures else 2


def reaction_count(message: dict, emoji_name: str) -> int:
    for reaction in message.get("reactions", []):
        emoji = reaction.get("emoji", {})
        if emoji.get("name") == emoji_name:
            return int(reaction.get("count", 0))
    return 0


def command_audit(args: argparse.Namespace) -> int:
    manifest = load_manifest()
    channel_status = get_channel_status()
    rows = []
    for item in manifest.get("messages", []):
        message = curl_json("GET", f"/channels/{item['channel_id']}/messages/{item['message_id']}")
        thumbs_up = reaction_count(message, "\U0001F44D")
        thumbs_down = reaction_count(message, "\U0001F44E")
        rows.append(
            {
                "experiment_id": item.get("experiment_id"),
                "message_id": item.get("message_id"),
                "thumbs_up_count": thumbs_up,
                "thumbs_down_count": thumbs_down,
                "flagged_for_morning_review": thumbs_down > 1,
                "screenshot_count": item.get("screenshot_count", 0),
                "receipt_kind": item.get("receipt_kind", "accepted"),
            }
        )
    print(
        json.dumps(
            {
                "guild_id": GUILD_ID,
                "channel_id": CHANNEL_ID,
                "channel_name": CHANNEL_NAME,
                "project_control_category_id": PROJECT_CONTROL_CATEGORY_ID,
                "channel_status": channel_status,
                "review": rows,
            },
            indent=2,
        )
    )
    return 0


def command_strip_next_action(args: argparse.Namespace) -> int:
    manifest = load_manifest()
    updated = []
    for item in manifest.get("messages", []):
        message = curl_json("GET", f"/channels/{item['channel_id']}/messages/{item['message_id']}")
        embeds = message.get("embeds", [])
        changed = False
        for embed in embeds:
            fields = embed.get("fields", [])
            kept_fields = [field for field in fields if field.get("name") != "Next action"]
            if len(kept_fields) != len(fields):
                embed["fields"] = kept_fields
                changed = True
            for field in embed.get("fields", []):
                if field.get("name") == "Why successful":
                    field["name"] = "Technical proof"
                    changed = True
        if changed and args.send:
            curl_json("PATCH", f"/channels/{item['channel_id']}/messages/{item['message_id']}", {"embeds": embeds})
        updated.append(
            {
                "experiment_id": item.get("experiment_id"),
                "message_id": item.get("message_id"),
                "changed": changed,
                "dry_run": not args.send,
            }
        )
    print(json.dumps({"channel_id": CHANNEL_ID, "updated": updated}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    success = sub.add_parser("success")
    success.add_argument("--experiment-id", required=True)
    success.add_argument("--title", required=True)
    success.add_argument("--summary", required=True)
    success.add_argument("--why", required=True)
    success.add_argument("--lane", default="overnight")
    success.add_argument("--test", action="append", default=[])
    success.add_argument("--changed-file", action="append", default=[])
    success.add_argument("--screenshot", action="append", default=[])
    success.add_argument("--next-action", default="", help=argparse.SUPPRESS)
    success.add_argument("--queue-only", action="store_true")
    success.add_argument("--queue-on-fail", action="store_true")
    success.add_argument("--send", action="store_true")
    success.set_defaults(func=command_success)

    audit = sub.add_parser("audit")
    audit.set_defaults(func=command_audit)

    flush = sub.add_parser("flush-pending")
    flush.set_defaults(func=command_flush_pending)

    strip = sub.add_parser("strip-next-action")
    strip.add_argument("--send", action="store_true")
    strip.set_defaults(func=command_strip_next_action)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
