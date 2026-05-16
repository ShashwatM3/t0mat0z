param(
    [Parameter(Mandatory = $true)]
    [datetime]$StopAt,

    [int]$IntervalSeconds = 300,
    [string]$LogPath = "$PSScriptRoot\dogbot-auth-recovery-watch.log"
)

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $RepoRoot "..\..")).Path
$DogbotAuthStatusPath = Join-Path $PSScriptRoot "dogbot-auth-status.json"
$DogbotAuditPath = Join-Path $PSScriptRoot "dogbot-reaction-audit.json"
$DemoReadyPath = Join-Path $PSScriptRoot "demo-ready-check.json"
$DemoDayStatusPath = Join-Path $PSScriptRoot "demo-day-status.md"
$DemoDayStatusJsonPath = Join-Path $PSScriptRoot "demo-day-status.json"
$Python = Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"
if (-not (Test-Path -LiteralPath $Python)) {
    $Python = "python.exe"
}
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$GoalChecker = Join-Path $CodexHome "skills\goalbuddy\scripts\check-goal-state.mjs"
$GoalState = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\state.yaml"

function Write-RecoveryLog {
    param([string]$Message)
    "[$(Get-Date -Format o)] $Message" | Add-Content -Path $LogPath -Encoding UTF8
}

function Invoke-RecoveryCommand {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string]$Exe,
        [string[]]$CommandArgs = @()
    )

    Write-RecoveryLog "command_start name=$Name cwd=$WorkingDirectory exe=$Exe args=$($CommandArgs -join ' ')"
    Push-Location $WorkingDirectory
    try {
        $output = & $Exe @CommandArgs 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        $text = ($output | Out-String).Trim()
        Write-RecoveryLog "command_end name=$Name exit=$exitCode"
        if ($text) {
            $text | Add-Content -Path $LogPath -Encoding UTF8
        }
        return [pscustomobject]@{ name = $Name; exit_code = $exitCode; output = $text }
    }
    catch {
        Write-RecoveryLog "command_error name=$Name error=$($_.Exception.Message)"
        return [pscustomobject]@{ name = $Name; exit_code = 999; output = $_.Exception.Message }
    }
    finally {
        Pop-Location
    }
}

Write-RecoveryLog "auth_recovery_watch_started stop_at=$($StopAt.ToString('o')) interval_seconds=$IntervalSeconds pid=$PID"
$posted = $false

while ((Get-Date) -lt $StopAt -and -not $posted) {
    $auth = Invoke-RecoveryCommand -Name "dogbot_auth_check" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\dogbot-auth-check.ps1", "-Out", $DogbotAuthStatusPath)
    if ([int]$auth.exit_code -eq 0) {
        $audit = Invoke-RecoveryCommand -Name "dogbot_reaction_audit" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "audit")
        if ([int]$audit.exit_code -eq 0) {
            $audit.output | Set-Content -Path $DogbotAuditPath -Encoding UTF8
        }
        $flushPending = Invoke-RecoveryCommand -Name "dogbot_flush_pending_receipts" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "flush-pending")
        if ([int]$flushPending.exit_code -eq 0) {
            $auditAfterFlush = Invoke-RecoveryCommand -Name "dogbot_reaction_audit_after_pending_flush" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "audit")
            if ([int]$auditAfterFlush.exit_code -eq 0) {
                $auditAfterFlush.output | Set-Content -Path $DogbotAuditPath -Encoding UTF8
                $audit = $auditAfterFlush
            }
        }
        $ready = Invoke-RecoveryCommand -Name "demo_ready_check" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-ready-check.ps1", "-Out", $DemoReadyPath, "-AllowPendingMorningAudit", "-DogbotAuditPath", $DogbotAuditPath)
        $status = Invoke-RecoveryCommand -Name "demo_day_status" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-day-status.ps1", "-Out", $DemoDayStatusPath, "-JsonOut", $DemoDayStatusJsonPath)
        $checker = Invoke-RecoveryCommand -Name "goalbuddy_checker" -WorkingDirectory $WorkspaceRoot -Exe "node.exe" -CommandArgs @($GoalChecker, $GoalState)
        if ([int]$audit.exit_code -eq 0 -and [int]$flushPending.exit_code -eq 0 -and [int]$checker.exit_code -eq 0) {
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $postArgs = @(
                "scripts\dogbot-experiment-log.py", "success",
                "--experiment-id", "T999-dogbot-auth-restored-$stamp",
                "--title", "Dogbot live auth restored",
                "--summary", "Dogbot can again read the hackathon #dogbot channel under Project Control.",
                "--why", "Live Dogbot auth check passed, live Dogbot reaction audit completed, demo readiness/status artifacts were refreshed, and GoalBuddy checker still reports active T999. This is a control-surface recovery receipt, not a model-performance claim.",
                "--lane", "dogbot-control-surface",
                "--test", "scripts/dogbot-auth-check.ps1",
                "--test", "dogbot-experiment-log.py audit",
                "--test", "dogbot-experiment-log.py flush-pending",
                "--test", "scripts/demo-ready-check.ps1",
                "--test", "scripts/demo-day-status.ps1",
                "--test", "GoalBuddy checker",
                "--changed-file", "final_docs/overnight/dogbot-auth-status.json",
                "--changed-file", "final_docs/overnight/dogbot-pending-receipts.jsonl",
                "--changed-file", "final_docs/overnight/dogbot-reaction-audit.json",
                "--changed-file", "final_docs/overnight/demo-ready-check.json",
                "--changed-file", "final_docs/overnight/demo-day-status.json",
                "--send"
            )
            $post = Invoke-RecoveryCommand -Name "dogbot_auth_recovered_post" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs $postArgs
            if ([int]$post.exit_code -eq 0) {
                Write-RecoveryLog "auth_recovery_posted exit=0"
                $posted = $true
            }
        }
    }
    else {
        Write-RecoveryLog "auth_still_blocked"
    }

    if (-not $posted) {
        $remaining = [Math]::Max(1, [int]($StopAt - (Get-Date)).TotalSeconds)
        Start-Sleep -Seconds ([Math]::Min($remaining, [Math]::Max(30, $IntervalSeconds)))
    }
}

Write-RecoveryLog "auth_recovery_watch_stopped posted=$posted"
