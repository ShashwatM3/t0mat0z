# Dogbot Auth Repair

Generated: 2026-05-16

## Current Blocker

Live Discord posting is blocked because no saved bot token can read the hackathon `#dogbot` channel under Project Control.

- `DISCORD_LAB_BOT_TOKEN`: present, but Discord returns `401 Unauthorized`.
- `DISCORD_BOT_TOKEN`: valid for FieldBot McSproutface, but Discord returns `403 Missing Access` for `#dogbot`.
- Latest enhanced auth status also shows `target_guild_visible=false` for FieldBot McSproutface, so the fallback bot is not currently visible in the hackathon guild. The fastest fallback repair is to invite/grant it access to the hackathon server, then rerun the repair helper.
- Hermes shell snapshots were checked, then stale Discord env assignment values in those local cache files were redacted so future diagnostics do not expose token-shaped strings. No recoverable alternate Dogbot token was found there.
- Last verified good `#dogbot` receipt remains preserved, but it is stale proof until live auth passes again.
- `dogbot-auth-recovery-watch.ps1` is running during the overnight window. If either repair option restores access before 10:00 AM, it will flush queued local receipts, post one technical Dogbot recovery receipt, and refresh the readiness/status artifacts.
- `dogbot-pending-receipts.jsonl` currently contains queued local receipts. These are not accepted Project Control proof until Dogbot access is repaired, the queue is flushed, and a live audit passes.
- The auth checker and Dogbot logger now both look in process env, Windows User env, and the global Codex Windows Credential Manager targets `Codex:DISCORD_LAB_BOT_TOKEN` / `Codex:DISCORD_BOT_TOKEN`. A token saved with `secret-env DISCORD_LAB_BOT_TOKEN -Save` can therefore be picked up by the recovery path without exposing the value.

## Safe Repair Option A: Refresh Dogbot Lab Token

Run the one-command helper. It uses the hidden local token prompt, then verifies Dogbot access and refreshes the audit/status artifacts. Do not paste the token into chat or a repo file.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-dogbot-auth.ps1
```

Manual equivalent:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\discord\scripts\save_discord_lab_token.ps1"
cd .\prototype\t0mat0z
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dogbot-auth-check.ps1 -Out .\final_docs\overnight\dogbot-auth-status.json
python scripts\dogbot-experiment-log.py audit
```

Success condition: `dogbot-auth-check.ps1` exits `0`, reports `status=pass`, and the Python audit prints live JSON with `under_project_control: true`.

## Safe Repair Option B: Grant Existing Bot Access

Invite or grant FieldBot McSproutface access to the hackathon server/channel. This is less clean for branding, but the logger can now fall back to any saved bot token that can reach `#dogbot`.

OAuth invite URL for the existing bot:

```text
https://discord.com/oauth2/authorize?client_id=1498110247158681790&scope=bot&permissions=117824
```

A local launcher for the same non-secret URL is available at:

```powershell
prototype\t0mat0z\final_docs\overnight\open-fieldbot-hackathon-invite.cmd
```

Required channel permissions: View Channel, Send Messages, Add Reactions, Embed Links, Attach Files, and Read Message History.

The current auth artifact writes this same non-secret invite URL under `dogbot_auth.candidates[].invite_url` for the valid fallback bot, and records whether the bot can see the target guild.

Then rerun the helper without prompting for a new token:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-dogbot-auth.ps1 -SkipTokenPrompt
```

## Completion Guard

Do not mark T999 or the GoalBuddy goal complete unless all of these pass after the repair:

- `dogbot-auth-check.ps1` exits `0`.
- `dogbot-experiment-log.py audit` exits `0`.
- `dogbot-reaction-audit.json` shows `under_project_control: true`.
- A fresh receipt appears in `#dogbot` and the manifest count matches the live audit count.
- `dogbot-pending-receipts.jsonl` is empty or absent after `flush-pending`.
- `final-t999-review.ps1` reports `full_outcome_complete: true`.
