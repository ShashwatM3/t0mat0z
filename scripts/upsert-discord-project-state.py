#!/usr/bin/env python3
"""Upsert public-safe project state into the Meta hackathon Discord.

Requires DISCORD_LAB_BOT_TOKEN or DISCORD_BOT_TOKEN in the environment.
Visible Discord content is read from final_docs/project-state-discord.md.
Uses curl for Discord API calls because the local Python HTTP stack can trip Discord edge filtering.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

API = "https://discord.com/api/v10"
GUILD_ID = "1504987658005516481"
BOT_ID = "1504346059416277132"
MANIFEST = Path("final_docs/discord-project-update-manifest.json")
SOURCE = Path("final_docs/project-state-discord.md")
SCREENSHOT_PACKET = Path("final_docs/screenshots/disease-scout-packet.png")
SCREENSHOT_PENDING = Path("final_docs/screenshots/disease-scout-pending.png")

CHANNELS = {
    "general": "1504987658936647894",
    "start-here": "1504993813410873434",
    "decisions": "1504993815822467243",
    "blockers": "1504993818536054936",
    "resources": "1504993822416044075",
    "use-cases": "1504993824907198514",
    "technical-notes": "1504993827402809375",
    "mobile-app": "1504993831374819358",
    "backend-ai": "1504994326424326205",
    "demo-script": "1504994329079451944",
    "agent-log": "1504994332766244904",
    "goals": "1505014264656560148",
}


def token() -> str:
    value = os.environ.get("DISCORD_LAB_BOT_TOKEN") or os.environ.get("DISCORD_BOT_TOKEN")
    if not value:
        raise SystemExit("DISCORD_LAB_BOT_TOKEN or DISCORD_BOT_TOKEN is required")
    return value


def curl_json(method: str, route: str, payload: dict | None = None) -> dict:
    cmd = [
        "curl", "-sS", "-X", method,
        "-H", f"Authorization: Bot {token()}",
        "-H", "User-Agent: DiscordBot (https://github.com/hermes, 1.0)",
    ]
    if payload is not None:
        cmd += ["-H", "Content-Type: application/json", "--data", json.dumps(payload)]
    cmd.append(f"{API}{route}")
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out) if out.strip() else {}


def curl_upload(channel_id: str, content: str, files: list[Path]) -> dict:
    cmd = [
        "curl", "-sS", "-X", "POST",
        "-H", f"Authorization: Bot {token()}",
        "-H", "User-Agent: DiscordBot (https://github.com/hermes, 1.0)",
        "-F", f"payload_json={json.dumps({'content': content, 'allowed_mentions': {'parse': []}})}",
    ]
    for i, path in enumerate(files):
        cmd += ["-F", f"files[{i}]=@{path.as_posix()}"]
    cmd.append(f"{API}/channels/{channel_id}/messages")
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {"guild_id": GUILD_ID, "messages": {}, "screenshots_message_id": None}


def save_manifest(manifest: dict) -> None:
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_messages() -> dict[str, str]:
    if not SOURCE.exists():
        raise SystemExit(f"missing source file: {SOURCE}")

    messages: dict[str, list[str]] = {}
    current: str | None = None
    for raw_line in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("## #"):
            current = line.removeprefix("## #").strip()
            messages[current] = []
            continue
        if current is not None:
            messages[current].append(line)

    parsed = {name: "\n".join(lines).strip() for name, lines in messages.items()}
    missing = [name for name in CHANNELS if not parsed.get(name)]
    if missing:
        raise SystemExit(f"missing Discord message sections: {', '.join(missing)}")
    too_long = {name: len(content) for name, content in parsed.items() if len(content) > 1900}
    if too_long:
        raise SystemExit(f"message too long for Discord safety margin: {too_long}")
    return parsed


def upsert_message(channel_name: str, channel_id: str, content: str, manifest: dict) -> str:
    messages = manifest.setdefault("messages", {})
    message_id = messages.get(channel_name)
    payload = {"content": content, "allowed_mentions": {"parse": []}}
    if message_id:
        result = curl_json("PATCH", f"/channels/{channel_id}/messages/{message_id}", payload)
        if result.get("id"):
            return "updated"
    result = curl_json("POST", f"/channels/{channel_id}/messages", payload)
    messages[channel_name] = result["id"]
    return "created"


def verify_messages(manifest: dict, messages: dict[str, str]) -> dict[str, str]:
    verified: dict[str, str] = {}
    for name in CHANNELS:
        message_id = manifest.get("messages", {}).get(name)
        if not message_id:
            verified[name] = "missing-manifest-id"
            continue
        result = curl_json("GET", f"/channels/{CHANNELS[name]}/messages/{message_id}")
        if result.get("id") != message_id:
            verified[name] = "missing"
        elif result.get("content") != messages[name]:
            verified[name] = "content-mismatch"
        else:
            verified[name] = "verified"
    return verified


def main() -> int:
    messages = load_messages()
    manifest = load_manifest()
    statuses = {}
    for name, content in messages.items():
        statuses[name] = upsert_message(name, CHANNELS[name], content, manifest)

    if SCREENSHOT_PACKET.exists() and SCREENSHOT_PENDING.exists():
        existing = manifest.get("screenshots_message_id")
        caption = "**Demo screenshots**\nPending capture state.\nCompleted supervisor-packet state."
        if existing:
            try:
                curl_json("PATCH", f"/channels/{CHANNELS['demo-script']}/messages/{existing}", {"content": caption, "allowed_mentions": {"parse": []}})
                statuses["demo-script-screenshots"] = "caption-updated"
            except subprocess.CalledProcessError:
                existing = None
        if not existing:
            result = curl_upload(CHANNELS["demo-script"], caption, [SCREENSHOT_PENDING, SCREENSHOT_PACKET])
            manifest["screenshots_message_id"] = result["id"]
            statuses["demo-script-screenshots"] = "created"

    save_manifest(manifest)
    verified = verify_messages(manifest, messages)
    print(json.dumps({"statuses": statuses, "verified": verified}, indent=2, sort_keys=True))
    if any(value != "verified" for value in verified.values()):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
