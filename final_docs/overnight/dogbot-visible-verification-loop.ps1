param(
    [Parameter(Mandatory = $true)]
    [datetime]$StopAt,

    [int]$IntervalMinutes = 45,
    [string]$LogPath = "$PSScriptRoot\dogbot-visible-verification-loop.log"
)

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $RepoRoot "..\..")).Path
$AppRoot = Join-Path $RepoRoot "app"
$ManifestPath = Join-Path $RepoRoot "final_docs\discord-experiment-manifest.json"
$PendingReceiptsPath = Join-Path $RepoRoot "final_docs\overnight\dogbot-pending-receipts.jsonl"
$HeartbeatPath = Join-Path $PSScriptRoot "overnight-heartbeat.json"
$VerifierReportPath = Join-Path $PSScriptRoot "visible-holdout-score-latest.md"
$NetworkPreflightPath = Join-Path $PSScriptRoot "network-preflight-latest.json"
$DogbotAuthStatusPath = Join-Path $PSScriptRoot "dogbot-auth-status.json"
$VisualAuditPath = Join-Path $PSScriptRoot "visual-professionalism-audit.json"
$VisualAuditMdPath = Join-Path $PSScriptRoot "visual-professionalism-audit.md"
$LatencyAuditPath = Join-Path $PSScriptRoot "latency-demo-audit.json"
$LatencyAuditMdPath = Join-Path $PSScriptRoot "latency-demo-audit.md"
$Python = Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"
if (-not (Test-Path -LiteralPath $Python)) {
    $Python = "python.exe"
}
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$GoalChecker = Join-Path $CodexHome "skills\goalbuddy\scripts\check-goal-state.mjs"
$GoalState = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\state.yaml"

function Write-LoopLog {
    param([string]$Message)
    "[$(Get-Date -Format o)] $Message" | Add-Content -Path $LogPath -Encoding UTF8
}

function Invoke-LoopCommand {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string]$Exe,
        [string[]]$CommandArgs = @(),
        [hashtable]$ExtraEnv = @{}
    )

    Write-LoopLog "command_start name=$Name cwd=$WorkingDirectory exe=$Exe args=$($CommandArgs -join ' ')"
    Push-Location $WorkingDirectory
    $oldEnv = @{}
    foreach ($key in $ExtraEnv.Keys) {
        $oldEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, [string]$ExtraEnv[$key], "Process")
    }
    try {
        $output = & $Exe @CommandArgs 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        $text = ($output | Out-String).Trim()
        Write-LoopLog "command_end name=$Name exit=$exitCode"
        if ($text) {
            $text | Add-Content -Path $LogPath -Encoding UTF8
        }
        return [pscustomobject]@{ name = $Name; exit_code = $exitCode; output = $text }
    }
    catch {
        Write-LoopLog "command_error name=$Name error=$($_.Exception.Message)"
        return [pscustomobject]@{ name = $Name; exit_code = 999; output = $_.Exception.Message }
    }
    finally {
        foreach ($key in $ExtraEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $oldEnv[$key], "Process")
        }
        Pop-Location
    }
}

function Get-ManifestCount {
    if (-not (Test-Path $ManifestPath)) { return 0 }
    try {
        $manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json
        return @($manifest.messages).Count
    }
    catch {
        Write-LoopLog "manifest_count_error $($_.Exception.Message)"
        return 0
    }
}

function Get-PendingCount {
    if (-not (Test-Path $PendingReceiptsPath)) { return 0 }
    try {
        return @((Get-Content -Path $PendingReceiptsPath -ErrorAction SilentlyContinue) | Where-Object { $_.Trim() }).Count
    }
    catch {
        Write-LoopLog "pending_count_error $($_.Exception.Message)"
        return 0
    }
}

function Get-HeartbeatStatus {
    if (-not (Test-Path $HeartbeatPath)) { return "heartbeat missing" }
    try {
        $heartbeat = Get-Content -Raw $HeartbeatPath | ConvertFrom-Json
        return "heartbeat=$($heartbeat.status); last=$($heartbeat.now)"
    }
    catch {
        return "heartbeat unreadable"
    }
}

function Remove-AppTestResults {
    $target = Join-Path $AppRoot "test-results"
    if (-not (Test-Path $target)) { return }
    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    $resolvedRoot = (Resolve-Path -LiteralPath $AppRoot).Path
    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-LoopLog "refusing_to_remove_test_results target=$resolvedTarget"
        return
    }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    Write-LoopLog "removed_transient_test_results target=$resolvedTarget"
}

Write-LoopLog "visible_verification_loop_started stop_at=$($StopAt.ToString('o')) interval_minutes=$IntervalMinutes pid=$PID"

while ((Get-Date) -lt $StopAt) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $experimentId = "T999-visible-$stamp"
    Write-LoopLog "iteration_start experiment=$experimentId"

    $dogbotAuth = Invoke-LoopCommand -Name "dogbot_auth_check" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\dogbot-auth-check.ps1", "-Out", $DogbotAuthStatusPath)
    $dogbot = if ($dogbotAuth.exit_code -eq 0) {
        Invoke-LoopCommand -Name "dogbot_audit" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "audit")
    }
    else {
        [pscustomobject]@{ name = "dogbot_audit"; exit_code = 1; output = "skipped because dogbot_auth_check failed" }
    }
    $unit = Invoke-LoopCommand -Name "npm_test" -WorkingDirectory $AppRoot -Exe "npm.cmd" -CommandArgs @("test")
    $playwright = Invoke-LoopCommand -Name "playwright_test" -WorkingDirectory $AppRoot -Exe "npx.cmd" -CommandArgs @("playwright", "test") -ExtraEnv @{ DISEASE_SCOUT_WEB_URL = "http://localhost:19006" }
    $visual = Invoke-LoopCommand -Name "visual_professionalism_audit" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\visual-professionalism-audit.ps1", "-Out", $VisualAuditPath, "-MarkdownOut", $VisualAuditMdPath)
    Remove-AppTestResults
    $network = Invoke-LoopCommand -Name "network_preflight" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-network-preflight.ps1", "-Out", $NetworkPreflightPath)
    $latency = Invoke-LoopCommand -Name "latency_demo_audit" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\latency-demo-audit.ps1", "-Out", $LatencyAuditPath, "-MarkdownOut", $LatencyAuditMdPath)
    $verifier = Invoke-LoopCommand -Name "holdout_verifier_score" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\disease-verifier.ps1", "-Command", "Score", "-Manifest", ".\data\verifier\manifests\holdout_captures.jsonl", "-Predictions", ".\data\verifier\predictions\holdout.jsonl", "-Out", $VerifierReportPath)
    $checker = Invoke-LoopCommand -Name "goalbuddy_checker" -WorkingDirectory $WorkspaceRoot -Exe "node.exe" -CommandArgs @($GoalChecker, $GoalState)

    $nonDiscordPassed = ($unit.exit_code -eq 0) -and ($playwright.exit_code -eq 0) -and ($visual.exit_code -eq 0) -and ($network.exit_code -eq 0) -and ($latency.exit_code -eq 0) -and ($verifier.exit_code -eq 0) -and ($checker.exit_code -eq 0)
    $passed = ($dogbotAuth.exit_code -eq 0) -and ($dogbot.exit_code -eq 0) -and $nonDiscordPassed
    if ($passed -or $nonDiscordPassed) {
        $manifestCount = Get-ManifestCount
        $pendingCount = Get-PendingCount
        $nextIndex = $manifestCount + $pendingCount + 1
        $screenshotArgs = @()
        if (($nextIndex % 3) -eq 0) {
            $screenshotArgs = @("--screenshot", "final_docs/overnight/baseline-display-600.png")
        }
        $heartbeat = Get-HeartbeatStatus
        if ($passed) {
            $summary = "Visible overnight verification passed with browser, dataset, Dogbot, and control checks."
            $why = "Real checks passed in this iteration: Dogbot auth check, Dogbot reaction audit, npm unit tests, Playwright browser flow, visual professionalism audit, demo network preflight, latency demo audit, holdout verifier score, and GoalBuddy checker. $heartbeat. The holdout verifier keeps failures visible; this is not a claim of perfect model accuracy. Network preflight warnings remain visible in network-preflight-latest.json."
            $dogbotAuthLabel = "scripts/dogbot-auth-check.ps1"
            $dogbotAuditLabel = "dogbot-experiment-log.py audit"
        }
        else {
            $summary = "Visible overnight verification passed locally and is queued for Dogbot after auth repair."
            $why = "Non-Discord checks passed in this iteration: npm unit tests, Playwright browser flow, visual professionalism audit, demo network preflight, latency demo audit, holdout verifier score, and GoalBuddy checker. Dogbot auth/audit are blocked right now, so this is a pending local receipt, not Discord proof and not a completion claim. $heartbeat. The holdout verifier keeps failures visible; network preflight warnings remain visible in network-preflight-latest.json."
            $dogbotAuthLabel = "scripts/dogbot-auth-check.ps1 (blocked)"
            $dogbotAuditLabel = "dogbot-experiment-log.py audit (blocked)"
        }
        $postArgs = @(
            "scripts\dogbot-experiment-log.py", "success",
            "--experiment-id", $experimentId,
            "--title", "Visible overnight verification",
            "--summary", $summary,
            "--why", $why,
            "--lane", "overnight-visible-control",
            "--test", $dogbotAuthLabel,
            "--test", $dogbotAuditLabel,
            "--test", "npm test",
            "--test", "DISEASE_SCOUT_WEB_URL=http://localhost:19006 npx playwright test",
            "--test", "scripts/visual-professionalism-audit.ps1",
            "--test", "scripts/demo-network-preflight.ps1",
            "--test", "scripts/latency-demo-audit.ps1",
            "--test", "disease-verifier.ps1 Score",
            "--test", "goalbuddy checker",
            "--changed-file", "final_docs/overnight/overnight-heartbeat.json",
            "--changed-file", "final_docs/overnight/dogbot-auth-status.json",
            "--changed-file", "final_docs/overnight/dogbot-pending-receipts.jsonl",
            "--changed-file", "final_docs/overnight/visual-professionalism-audit.json",
            "--changed-file", "final_docs/overnight/latency-demo-audit.json",
            "--changed-file", "final_docs/overnight/network-preflight-latest.json",
            "--changed-file", "final_docs/overnight/visible-holdout-score-latest.md"
        ) + $screenshotArgs
        if ($passed) {
            $post = Invoke-LoopCommand -Name "dogbot_success_post" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs ($postArgs + @("--send", "--queue-on-fail"))
            Write-LoopLog "iteration_post experiment=$experimentId exit=$($post.exit_code)"
        }
        else {
            $queued = Invoke-LoopCommand -Name "dogbot_queue_pending_receipt" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs ($postArgs + @("--queue-only"))
            Write-LoopLog "iteration_queued_pending_receipt experiment=$experimentId exit=$($queued.exit_code) dogbot_auth=$($dogbotAuth.exit_code) dogbot=$($dogbot.exit_code)"
        }
    }
    else {
        Write-LoopLog "iteration_failed_no_post experiment=$experimentId dogbot_auth=$($dogbotAuth.exit_code) dogbot=$($dogbot.exit_code) unit=$($unit.exit_code) playwright=$($playwright.exit_code) visual=$($visual.exit_code) network=$($network.exit_code) latency=$($latency.exit_code) verifier=$($verifier.exit_code) checker=$($checker.exit_code)"
    }

    $remaining = [Math]::Max(1, [int]($StopAt - (Get-Date)).TotalSeconds)
    Start-Sleep -Seconds ([Math]::Min($remaining, [Math]::Max(60, $IntervalMinutes * 60)))
}

Write-LoopLog "visible_verification_loop_stopped stop_at=$($StopAt.ToString('o'))"
