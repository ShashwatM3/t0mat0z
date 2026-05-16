#!/usr/bin/env python3
"""Upsert public-safe project state into the Meta hackathon Discord.

Requires DISCORD_LAB_BOT_TOKEN or DISCORD_BOT_TOKEN in the environment.
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

MESSAGES = {
    "general": """Current project state: we are building Disease Scout Memory for the AIFS x Meta Wearables AgTech hackathon. The demo is a hands-free field scouting loop: glasses-style POV capture + worker note -> conservative disease/stress assessment -> missing-evidence prompt -> supervisor-ready packet. No threads needed; use the channel-specific posts below as the current map.""",
    "start-here": """Start here: Disease Scout Memory. Wearer action: a field worker looks at a tomato plant station and gives a short report. Glasses input: POV image/capture plus wearer voice/text stand-in. Structured output: disease scout observation with possible ID, confidence, limitations, next check, review status, and supervisor action. Judge-visible proof: simulator UI, JSON packet, verifier report, and screenshots.""",
    "decisions": """Current decisions: 1) Sunday lane is Disease Scout Memory, not a generic AI-glasses identifier. 2) Demo is tomato disease scouting with a supervisor-review safety posture. 3) The model must name uncertainty and missing evidence instead of giving treatment advice. 4) The phone/app owns the session; glasses are the POV capture and wearer-audio surface. 5) Discord is a status board, not a product dependency for the core demo.""",
    "blockers": """Current blockers / risks: real glasses integration still needs device-session validation; broad-state classification has known misses on healthy and poor-evidence cases; screenshots currently show simulator proof, not a full device capture; no treatment recommendations should be added unless a qualified agronomy review layer exists. Nothing secret or personal is needed in this server.""",
    "resources": """Useful references: Meta Wearables DAT docs, Android/iOS DAT repos, web app starter kit, and the hackathon agenda. Key DAT facts to keep honest: phone app starts/owns the session; glasses provide POV camera/photo/video, wearer mic, speakers, and session controls; HFP audio is wearer-voice oriented; one active session per device; do not assume lens overlays or Meta AI voice commands.""",
    "use-cases": """Use-case focus: field disease scouting memory. The stronger operator story is not “AI identifies plants”; it is “the worker closest to the issue captures evidence without stopping work, and the system turns that moment into a reviewable record.” Adjacent lanes remain harvest/packing QA, safety checklist, and expert-in-the-loop triage, but they are secondary unless the demo lane breaks.""",
    "technical-notes": """Technical notes: Expo / React Native web simulator is active. The local AI proxy accepts image data and scout context at POST /api/scout/analyze and returns a structured observation. Default analysis path can use local Codex CLI when no API key is present; optional OpenAI vision path is available via environment. Output schema includes possible_disease, confidence, evidence_quality, limitation_flags, next_check, review_status, supervisor_action, finding_why, broad_state, visible_symptoms, and treatment_recommendation=null.""",
    "mobile-app": """Mobile/app state: simulator UI has plant stations, glasses-view panel, evidence upload, operator report, scout conversation controls, assessment panel, supervisor packet, and raw JSON proof. Current fixture path: Zone B suspicious lower-leaf tomato plant -> capture -> possible early blight or leaf spot -> ask why -> packet. The current web build is screenshot-ready for team/pitch updates.""",
    "backend-ai": """Backend/AI state: verifier report has 306 manifest rows and 306 prediction rows with no missing or extra predictions. Passing checks: valid schema 100%, limitations named 100%, next check exists 100%, no treatment advice 100%, report preserved 100%, safe review status 100%. Needs improvement: broad_state 247/306 (80.7%) and bad_recapture_behavior 85/102 (83.3%).""",
    "demo-script": """Demo script: 1) Select Zone B, suspicious lower-leaf plant. 2) Worker report: “yellowing and spots on lower leaves.” 3) Trigger capture. 4) Ask “what disease might this be?” 5) Show possible early blight or leaf spot, medium confidence. 6) Ask why. 7) Show missing evidence: underside view and healthy comparison. 8) Create supervisor packet. 9) Point judges to JSON proof and no-treatment safety guard.""",
    "agent-log": """Agent receipt: Discord project-state posts were refreshed from inspected repo/demo state. Personal local file paths, tokens, account details, and raw logs were intentionally excluded from visible Discord content. Current repo organization adds a public-safe project-state note, repeatable Discord updater, and demo screenshots under final docs.""",
    "goals": """Next build goals: 1) Keep Sunday demo narrow and rehearse the Zone B flow end-to-end. 2) Add or fill a manual acceptance checklist for real glasses/mock-device capture. 3) Improve broad_state and bad-recapture verifier behavior. 4) Keep the structured packet legible enough for judges to inspect quickly. 5) Do not broaden into generic ag assistant scope.""",
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
        "-F", f"payload_json={json.dumps({'content': content})}",
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


def main() -> int:
    manifest = load_manifest()
    statuses = {}
    for name, content in MESSAGES.items():
        statuses[name] = upsert_message(name, CHANNELS[name], content, manifest)

    if SCREENSHOT_PACKET.exists() and SCREENSHOT_PENDING.exists():
        existing = manifest.get("screenshots_message_id")
        caption = "Demo screenshots: pending capture state and completed supervisor-packet state for Disease Scout Memory."
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
    print(json.dumps(statuses, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
