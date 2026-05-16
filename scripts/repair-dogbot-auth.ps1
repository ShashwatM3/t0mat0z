param(
    [switch]$SkipTokenPrompt,
    [string]$AuthOut = "final_docs\overnight\dogbot-auth-status.json",
    [string]$AuditOut = "final_docs\overnight\dogbot-reaction-audit.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$python = Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    $python = "python.exe"
}
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$safeTokenHelper = Join-Path $codexHome "skills\discord\scripts\save_discord_lab_token.ps1"

function Write-AuthBlockerDetails {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    try {
        $status = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        Write-Output "Could not parse Dogbot auth status at ${Path}: $($_.Exception.Message)"
        return
    }

    Write-Output "Dogbot auth status: $($status.status)"
    if ($status.blocker) {
        Write-Output "Blocker: $($status.blocker)"
    }
    foreach ($candidate in @($status.checks)) {
        Write-Output "Candidate $($candidate.label): bot=$($candidate.bot_username), me=$($candidate.me_status), guild_visible=$($candidate.target_guild_visible), channel=$($candidate.channel_status), error=$($candidate.channel_error)"
        if ($candidate.invite_url) {
            Write-Output "Invite URL: $($candidate.invite_url)"
        }
    }
}

Push-Location $repoRoot
try {
    if (-not $SkipTokenPrompt) {
        if (-not (Test-Path -LiteralPath $safeTokenHelper)) {
            throw "Safe token helper missing: $safeTokenHelper"
        }
        & powershell -ExecutionPolicy Bypass -File $safeTokenHelper
        if ($LASTEXITCODE -ne 0) {
            throw "Safe token helper exited with $LASTEXITCODE"
        }
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\dogbot-auth-check.ps1" -Out $AuthOut
    if ($LASTEXITCODE -ne 0) {
        Write-AuthBlockerDetails -Path $AuthOut
        throw "Dogbot auth check still failed. See $AuthOut."
    }

    $flush = & $python "scripts\dogbot-experiment-log.py" "flush-pending"
    if ($LASTEXITCODE -ne 0) {
        throw "Dogbot pending receipt flush failed."
    }

    $audit = & $python "scripts\dogbot-experiment-log.py" "audit"
    if ($LASTEXITCODE -ne 0) {
        throw "Dogbot live audit failed."
    }
    $audit | Set-Content -Path $AuditOut -Encoding UTF8

    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\demo-ready-check.ps1" -Out ".\final_docs\overnight\demo-ready-check.json" -AllowPendingMorningAudit -DogbotAuditPath $AuditOut
    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\demo-day-status.ps1" -Out ".\final_docs\overnight\demo-day-status.md" -JsonOut ".\final_docs\overnight\demo-day-status.json"

    Write-Output "Dogbot auth repaired and live audit refreshed."
    Write-Output "auth=$AuthOut"
    Write-Output "flush=$($flush | Out-String)"
    Write-Output "audit=$AuditOut"
}
catch {
    Write-Output "Dogbot auth repair did not complete: $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location
}
