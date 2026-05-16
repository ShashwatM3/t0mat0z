param(
    [Parameter(Mandatory = $true)]
    [datetime]$StopAt,

    [string]$HeartbeatPath = "$PSScriptRoot\overnight-heartbeat.json",
    [string]$LogPath = "$PSScriptRoot\overnight-controller.log",
    [string]$StatePath = "$env:USERPROFILE\.codex\state\overnight-state.json"
)

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $RepoRoot "..\..")).Path
$AppRoot = Join-Path $RepoRoot "app"
$GoalStatePath = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\state.yaml"
$GoalAuditPath = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md"
$DogbotAuditPath = Join-Path $PSScriptRoot "dogbot-reaction-audit.json"
$DogbotAuditErrorPath = Join-Path $PSScriptRoot "dogbot-reaction-audit-error.txt"
$DogbotAuthStatusPath = Join-Path $PSScriptRoot "dogbot-auth-status.json"
$DogbotAuthRecoveryWatchLogPath = Join-Path $PSScriptRoot "dogbot-auth-recovery-watch.log"
$DogbotPendingReceiptsPath = Join-Path $PSScriptRoot "dogbot-pending-receipts.jsonl"
$VerifierReportPath = Join-Path $PSScriptRoot "morning-holdout-score.md"
$LiveModelSmokePath = Join-Path $PSScriptRoot "live-model-smoke.json"
$LiveModelDiversityPath = Join-Path $PSScriptRoot "live-model-diversity-smoke.json"
$LiveUiUploadSmokePath = Join-Path $PSScriptRoot "live-ui-upload-smoke.json"
$VisualAuditPath = Join-Path $PSScriptRoot "visual-professionalism-audit.json"
$VisualAuditMdPath = Join-Path $PSScriptRoot "visual-professionalism-audit.md"
$LatencyAuditPath = Join-Path $PSScriptRoot "latency-demo-audit.json"
$LatencyAuditMdPath = Join-Path $PSScriptRoot "latency-demo-audit.md"
$NetworkPreflightPath = Join-Path $PSScriptRoot "network-preflight-latest.json"
$DemoReadyCheckPath = Join-Path $PSScriptRoot "demo-ready-check.json"
$DemoDayStatusPath = Join-Path $PSScriptRoot "demo-day-status.md"
$DemoDayStatusJsonPath = Join-Path $PSScriptRoot "demo-day-status.json"
$DemoProofPacketPath = Join-Path $PSScriptRoot "demo-day-proof-packet.md"
$DemoOperatorCardPath = Join-Path $PSScriptRoot "demo-operator-card.md"
$FinalT999ReviewPath = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\notes\final-t999-review.md"
$FinalT999ReviewJsonPath = Join-Path $WorkspaceRoot "docs\goals\disease-scout-overnight-experiment-control\notes\final-t999-review.json"
$StopFile = Join-Path $PSScriptRoot "STOP_OVERNIGHT"
$Python = Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"
if (-not (Test-Path -LiteralPath $Python)) {
    $Python = "python.exe"
}
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$GoalChecker = Join-Path $CodexHome "skills\goalbuddy\scripts\check-goal-state.mjs"

New-Item -ItemType Directory -Force -Path $PSScriptRoot | Out-Null

function Write-Log {
    param([string]$Message)
    "[$(Get-Date -Format o)] $Message" | Add-Content -Path $LogPath -Encoding UTF8
}

function Write-JsonFile {
    param(
        [string]$Path,
        [hashtable]$Value
    )
    $dir = Split-Path -Parent $Path
    if ($dir) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $Value | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Write-Heartbeat {
    param([string]$Status)
    Write-JsonFile -Path $HeartbeatPath -Value @{
        status = $Status
        now = (Get-Date).ToString("o")
        stop_at = $StopAt.ToString("o")
        pid = $PID
        repo = "prototype/t0mat0z"
        goal = "disease-scout-overnight-experiment-control"
        stop_file = $StopFile
        morning_audit = $GoalAuditPath
        log = $LogPath
    }
}

function Invoke-LoggedCommand {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string]$Exe,
        [string[]]$CommandArgs = @(),
        [hashtable]$ExtraEnv = @{}
    )

    Write-Log "command_start name=$Name cwd=$WorkingDirectory exe=$Exe args=$($CommandArgs -join ' ')"
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
        Write-Log "command_end name=$Name exit=$exitCode"
        if ($text) {
            $text | Add-Content -Path $LogPath -Encoding UTF8
        }
        return [pscustomobject]@{
            name = $Name
            exit_code = $exitCode
            output = $text
        }
    }
    catch {
        Write-Log "command_error name=$Name error=$($_.Exception.Message)"
        return [pscustomobject]@{
            name = $Name
            exit_code = 999
            output = $_.Exception.Message
        }
    }
    finally {
        foreach ($key in $ExtraEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $oldEnv[$key], "Process")
        }
        Pop-Location
    }
}

function Write-MorningAudit {
    param([object[]]$Results)

    $dogbotSummary = "Dogbot audit did not produce parseable JSON."
    $controlSurface = "Dogbot control-surface proof unavailable."
    $flagged = @()
    $dogbotRows = @("- unavailable")
    if (Test-Path $DogbotAuditPath) {
        try {
            $dogbot = Get-Content -Raw $DogbotAuditPath | ConvertFrom-Json
            $flagged = @($dogbot.review | Where-Object { $_.flagged_for_morning_review })
            $dogbotSummary = "$(@($dogbot.review).Count) experiment receipts audited; $($flagged.Count) flagged by human thumbs-down."
            if ($dogbot.channel_status) {
                $controlSurface = "Live channel proof: #$($dogbot.channel_status.channel_name) id $($dogbot.channel_status.channel_id), parent category $($dogbot.channel_status.parent_category_id), under_project_control=$($dogbot.channel_status.under_project_control)."
            }
            $dogbotRows = @($dogbot.review | ForEach-Object {
                "- $($_.experiment_id): message $($_.message_id), up=$($_.thumbs_up_count), down=$($_.thumbs_down_count), flagged=$($_.flagged_for_morning_review), screenshots=$($_.screenshot_count)"
            })
        }
        catch {
            $dogbotSummary = "Dogbot audit JSON parse failed: $($_.Exception.Message)"
        }
    }
    if (Test-Path $DogbotAuditErrorPath) {
        $dogbotError = (Get-Content -Raw $DogbotAuditErrorPath).Trim()
        if ($dogbotError.Length -gt 240) {
            $dogbotError = $dogbotError.Substring(0, 240) + "..."
        }
        $dogbotSummary = "$dogbotSummary Latest live Dogbot audit error: $dogbotError"
    }

    $dogbotAuthSummary = "Dogbot live auth check missing."
    $dogbotAuthRows = @("- unavailable")
    if (Test-Path $DogbotAuthStatusPath) {
        try {
            $dogbotAuth = Get-Content -Raw $DogbotAuthStatusPath | ConvertFrom-Json
            $selected = if ($dogbotAuth.selected) { $dogbotAuth.selected } else { "none" }
            $dogbotAuthSummary = "status=$($dogbotAuth.status), candidates=$($dogbotAuth.candidate_count), selected=$selected."
            if ($dogbotAuth.blocker) {
                $dogbotAuthSummary = "$dogbotAuthSummary blocker=$($dogbotAuth.blocker)"
            }
            $dogbotAuthRows = @($dogbotAuth.checks | ForEach-Object {
                $invite = if ($_.invite_url) { ", invite=$($_.invite_url)" } else { "" }
                "- $($_.label): bot=$($_.bot_username), me=$($_.me_status), guild_visible=$($_.target_guild_visible), channel=$($_.channel_status), error=$($_.channel_error)$invite"
            })
            if ($dogbotAuthRows.Count -eq 0) {
                $dogbotAuthRows = @("- no candidates recorded")
            }
        }
        catch {
            $dogbotAuthSummary = "Dogbot auth status parse failed: $($_.Exception.Message)"
        }
    }
    $dogbotAuthRecoverySummary = "Dogbot auth recovery watcher log missing."
    if (Test-Path $DogbotAuthRecoveryWatchLogPath) {
        $lastRecoveryLine = (Get-Content -Path $DogbotAuthRecoveryWatchLogPath -Tail 1 -ErrorAction SilentlyContinue)
        if ($lastRecoveryLine) {
            $dogbotAuthRecoverySummary = "watcher log present; latest=$lastRecoveryLine"
        }
        else {
            $dogbotAuthRecoverySummary = "watcher log present but empty."
        }
    }
    $dogbotPendingSummary = "No pending Dogbot receipt queue found."
    if (Test-Path $DogbotPendingReceiptsPath) {
        $pendingLines = @((Get-Content -Path $DogbotPendingReceiptsPath -ErrorAction SilentlyContinue) | Where-Object { $_.Trim() })
        $dogbotPendingSummary = "$($pendingLines.Count) Dogbot receipt records queued locally for later Discord flush."
    }

    $manifestPath = Join-Path $RepoRoot "final_docs\discord-experiment-manifest.json"
    $manifestSummary = "Discord manifest missing."
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
            $messages = @($manifest.messages)
            $withScreenshots = @($messages | Where-Object { [int]$_.screenshot_count -gt 0 })
            $latest = if ($messages.Count -gt 0) { $messages[-1].experiment_id } else { "none" }
            $manifestSummary = "$($messages.Count) Dogbot receipt records; $($withScreenshots.Count) include screenshots; latest=$latest."
        }
        catch {
            $manifestSummary = "Discord manifest parse failed: $($_.Exception.Message)"
        }
    }

    $resultRows = $Results | ForEach-Object {
        "- $($_.name): exit $($_.exit_code)"
    }
    $failedCommands = @($Results | Where-Object { [int]$_.exit_code -ne 0 })
    $commandVerdict = if ($failedCommands.Count -eq 0) { "all controller commands exited 0" } else { "$($failedCommands.Count) controller commands failed" }
    $flagRows = if ($flagged.Count -gt 0) {
        $flagged | ForEach-Object { "- $($_.experiment_id): message $($_.message_id), thumbs_down_count=$($_.thumbs_down_count)" }
    }
    else {
        @("- none at audit time")
    }
    $screenshots = Get-ChildItem -Path $PSScriptRoot -Filter "*.png" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        "- ``prototype/t0mat0z/final_docs/overnight/$($_.Name)``"
    }
    if (-not $screenshots) {
        $screenshots = @("- none found")
    }

    $holdoutSummary = @("- holdout score report missing")
    if (Test-Path $VerifierReportPath) {
        $holdoutSummary = Get-Content -Path $VerifierReportPath | Where-Object {
            ($_ -match 'Manifest rows|Prediction rows|Missing predictions|Extra predictions') -or
            ($_ -match 'broad_state|bad_recapture_behavior|no_treatment_advice|valid_schema|safe_review_status|limitations_named|next_check_exists|report_preserved')
        }
    }

    $liveModelSummary = "Live model smoke missing."
    if (Test-Path $LiveModelSmokePath) {
        try {
            $liveModel = Get-Content -Raw $LiveModelSmokePath | ConvertFrom-Json
            $obs = $liveModel.observation
            $liveModelSummary = "status=$($liveModel.status), provider=$($liveModel.provider_health.provider), model=$($obs.model_name), elapsed_ms=$($liveModel.elapsed_ms), possible=$($obs.possible_disease), confidence=$($obs.confidence), treatment=$($obs.treatment_recommendation)."
        }
        catch {
            $liveModelSummary = "Live model smoke parse failed: $($_.Exception.Message)"
        }
    }

    $liveDiversitySummary = "Live model diversity smoke missing."
    if (Test-Path $LiveModelDiversityPath) {
        try {
            $liveDiversity = Get-Content -Raw $LiveModelDiversityPath | ConvertFrom-Json
            $liveDiversitySummary = "status=$($liveDiversity.status), samples=$($liveDiversity.sample_count), unique_signatures=$($liveDiversity.unique_response_signatures), unique_possible=$($liveDiversity.unique_possible_diseases), unique_broad_states=$($liveDiversity.unique_broad_states), treatment_advice_count=$($liveDiversity.treatment_advice_count), failed_sample_count=$($liveDiversity.failed_sample_count), elapsed_ms=$($liveDiversity.elapsed_ms)."
        }
        catch {
            $liveDiversitySummary = "Live model diversity smoke parse failed: $($_.Exception.Message)"
        }
    }

    $liveUiSummary = "Live browser upload smoke missing."
    if (Test-Path $LiveUiUploadSmokePath) {
        try {
            $liveUi = Get-Content -Raw $LiveUiUploadSmokePath | ConvertFrom-Json
            $liveUiSummary = "status=$($liveUi.status), image=$($liveUi.image_filename), response_status=$($liveUi.response_status), model=$($liveUi.observation.model_name), confidence=$($liveUi.observation.confidence), no_treatment_advice=$($liveUi.checks.no_treatment_advice), screenshot=$($liveUi.screenshot)."
        }
        catch {
            $liveUiSummary = "Live browser upload smoke parse failed: $($_.Exception.Message)"
        }
    }

    $visualAuditSummary = "Visual professionalism audit missing."
    if (Test-Path $VisualAuditPath) {
        try {
            $visualAudit = Get-Content -Raw $VisualAuditPath | ConvertFrom-Json
            $visualAuditSummary = "status=$($visualAudit.status), verdict=$($visualAudit.verdict), screenshots=$($visualAudit.screenshot_count), failed=$($visualAudit.failed_count)."
        }
        catch {
            $visualAuditSummary = "Visual professionalism audit parse failed: $($_.Exception.Message)"
        }
    }

    $latencyAuditSummary = "Latency demo audit missing."
    if (Test-Path $LatencyAuditPath) {
        try {
            $latencyAudit = Get-Content -Raw $LatencyAuditPath | ConvertFrom-Json
            $latencyAuditSummary = "status=$($latencyAudit.status), max_model_latency_ms=$($latencyAudit.max_model_latency_ms), average_model_latency_ms=$($latencyAudit.average_model_latency_ms), max_service_latency_ms=$($latencyAudit.max_service_latency_ms), fallback=$($latencyAudit.fallback)."
        }
        catch {
            $latencyAuditSummary = "Latency demo audit parse failed: $($_.Exception.Message)"
        }
    }

    $networkSummary = "Network preflight missing."
    if (Test-Path $NetworkPreflightPath) {
        try {
            $network = Get-Content -Raw $NetworkPreflightPath | ConvertFrom-Json
            $apiListenerCount = @($network.api_listeners).Count
            $webListenerOwnerCount = @($network.web_listeners | Select-Object -ExpandProperty owning_process -Unique).Count
            $webRouteChecks = @($network.web_route_checks)
            $webRouteOkCount = @($webRouteChecks | Where-Object { $_.ok }).Count
            $lanOkCount = @($network.lan_health_checks | Where-Object { $_.ok }).Count
            $warningCount = @($network.warnings).Count
            $routeType = $network.recommended_demo_urls.route_type
            $recommendedApi = $network.recommended_demo_urls.expo_public_disease_scout_api_url
            $networkSummary = "status=$($network.status), backend=$($network.backend_health.ok), web=$($network.web.ok), api_listeners=$apiListenerCount, web_listener_owners=$webListenerOwnerCount, web_routes_ok=$webRouteOkCount/$($webRouteChecks.Count), lan_health_ok=$lanOkCount, route_type=$routeType, recommended_api=$recommendedApi, warnings=$warningCount."
        }
        catch {
            $networkSummary = "Network preflight parse failed: $($_.Exception.Message)"
        }
    }

    $demoReadySummary = "Demo ready check missing."
    if (Test-Path $DemoReadyCheckPath) {
        try {
            $demoReady = Get-Content -Raw $DemoReadyCheckPath | ConvertFrom-Json
            $dogbotAuditSummary = if ($demoReady.dogbot_live_audit) {
                "dogbot_live_under_project_control=$($demoReady.dogbot_live_audit.under_project_control), dogbot_live_receipts=$($demoReady.dogbot_live_audit.receipt_count), dogbot_live_flagged=$($demoReady.dogbot_live_audit.flagged_count)"
            }
            else {
                "dogbot_live_audit=not_run"
            }
            $demoReadySummary = "status=$($demoReady.status), blockers=$(@($demoReady.blockers).Count), warnings=$(@($demoReady.warnings).Count), dogbot_manifest_messages=$($demoReady.dogbot_manifest.message_count), $dogbotAuditSummary, live_ui_model=$($demoReady.live_ui_upload.model), live_ui_confidence=$($demoReady.live_ui_upload.confidence)."
        }
        catch {
            $demoReadySummary = "Demo ready check parse failed: $($_.Exception.Message)"
        }
    }

    $demoDayStatusSummary = "Demo day status missing."
    if (Test-Path $DemoDayStatusJsonPath) {
        try {
            $demoDayStatus = Get-Content -Raw $DemoDayStatusJsonPath | ConvertFrom-Json
            $demoDayStatusSummary = "status=$($demoDayStatus.status), blockers=$(@($demoDayStatus.blockers).Count), warnings=$(@($demoDayStatus.warnings).Count), web_ok=$($demoDayStatus.web.ok), backend_ok=$($demoDayStatus.backend.ok), dogbot_receipts=$($demoDayStatus.demo_ready.dogbot_receipts), dogbot_flagged=$($demoDayStatus.demo_ready.dogbot_flagged), diversity_treatment_advice_count=$($demoDayStatus.live_diversity.treatment_advice_count), diversity_failed_sample_count=$($demoDayStatus.live_diversity.failed_sample_count)."
        }
        catch {
            $demoDayStatusSummary = "Demo day status parse failed: $($_.Exception.Message)"
        }
    }

    $demoRouteSummary = "Demo proof packet or operator card missing."
    if ((Test-Path $DemoProofPacketPath) -and (Test-Path $DemoOperatorCardPath)) {
        $statusPresent = if ((Test-Path $DemoDayStatusPath) -and (Test-Path $DemoDayStatusJsonPath)) { "demo-day-status.md/json present" } else { "demo-day-status missing" }
        $demoRouteSummary = "demo-day-proof-packet.md and demo-operator-card.md present; $statusPresent; operator card gives open order, live URLs, two-minute demo, proof artifacts, fallback lines, and prohibited claims."
    }

    $checklistRows = @(
        "| Requirement | Evidence | Status |",
        "| --- | --- | --- |",
        "| Run/control board | state.yaml + GoalBuddy checker | active T999, checker result in command table |",
        "| 10:00 bounded stop | controller StopAt + heartbeat | stop_at $($StopAt.ToString('o')) |",
        "| Dogbot receipts | discord-experiment-manifest.json + reaction audit | $manifestSummary |",
        "| Dogbot Project Control route | live Discord channel parent check | $controlSurface |",
        "| Dogbot live auth | dogbot-auth-check.ps1 | $dogbotAuthSummary |",
        "| Dogbot auth recovery watcher | dogbot-auth-recovery-watch.ps1/log | $dogbotAuthRecoverySummary |",
        "| Dogbot pending receipt queue | dogbot-pending-receipts.jsonl + flush-pending command | $dogbotPendingSummary |",
        "| Thumbs-down flagging | dogbot audit flags additional downvotes | $dogbotSummary |",
        "| Web workflow | npm test + Playwright | command table records result |",
        "| Mobile/display screenshots | final_docs/overnight/*.png | listed below |",
        "| Provider swappability | server tests + README/provider code | covered by npm test and prior receipts |",
        "| Live model upload path | live holdout image through /api/scout/analyze | $liveModelSummary |",
        "| Live model non-static behavior | multiple blinded holdout images through /api/scout/analyze | $liveDiversitySummary |",
        "| Live browser upload path | Playwright file upload from blind image into real UI and backend | $liveUiSummary |",
        "| Visual professionalism audit | screenshot freshness, viewport size, and nonblank visual checks | $visualAuditSummary |",
        "| Speed/latency audit | live model and local service timing with fallback script | $latencyAuditSummary |",
        "| Phone/LAN backend route | EXPO_PUBLIC_DISEASE_SCOUT_API_URL or same-host inference | covered by npm test, App.js, app README, glasses README, Android/DAT checklist, and network preflight |",
        "| Demo network preflight | web/backend/listener/LAN route artifact | $networkSummary |",
        "| Demo readiness summary | one-command status of live surfaces, proof artifacts, Dogbot manifest, and caveats | $demoReadySummary |",
        "| Demo day operator status | one-page operator status from current proof files | $demoDayStatusSummary |",
        "| Deferred/offline capture | Playwright retry test | covered by Playwright command |",
        "| Dataset/no-cheating lane | holdout verifier score | score summary below |",
        "| Android/DAT honesty | android-dat-checklist.md | checklist only; no real DAT success claim |",
        "| Judge-facing demo route | proof packet + operator card | $demoRouteSummary |",
        "| Secrets/tokens | sensitive-file scan | command table records result |",
        "| No treatment/final diagnosis | unit/safety checks + verifier score | no_treatment_advice summary below |"
    )

    $content = @(
        "# Morning Audit: Disease Scout Overnight Control",
        "",
        "Generated: $(Get-Date -Format o)",
        "Stop target: $($StopAt.ToString('o'))",
        "Controller PID: $PID",
        "Controller verdict: $commandVerdict",
        "",
        "## Objective Restated",
        "",
        "Prepare and run a controlled overnight improvement/verification loop for Disease Scout Memory that improves the web simulator, keeps Android/DAT claims honest, verifies real image/dataset behavior, posts technical Dogbot receipts with reactions, and writes a final morning audit without claiming unsupported real-glasses or disease-diagnosis capability.",
        "",
        "## Prompt-To-Artifact Checklist",
        "",
        $checklistRows,
        "",
        "## Command Results",
        "",
        $resultRows,
        "",
        "## Holdout Verifier Summary",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/morning-holdout-score.md",
        "",
        $holdoutSummary,
        "",
        "## Live Model Upload Smoke",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/live-model-smoke.json",
        "",
        $liveModelSummary,
        "",
        "## Live Model Diversity Smoke",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/live-model-diversity-smoke.json",
        "",
        $liveDiversitySummary,
        "",
        "## Live Browser Upload Smoke",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/live-ui-upload-smoke.json",
        "Screenshot: prototype/t0mat0z/final_docs/overnight/live-ui-upload-smoke.png",
        "",
        $liveUiSummary,
        "",
        "## Visual Professionalism Audit",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/visual-professionalism-audit.md",
        "JSON: prototype/t0mat0z/final_docs/overnight/visual-professionalism-audit.json",
        "",
        $visualAuditSummary,
        "",
        "## Latency Demo Audit",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/latency-demo-audit.md",
        "JSON: prototype/t0mat0z/final_docs/overnight/latency-demo-audit.json",
        "",
        $latencyAuditSummary,
        "",
        "## Demo Network Preflight",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/network-preflight-latest.json",
        "",
        $networkSummary,
        "",
        "## Demo Ready Check",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/demo-ready-check.json",
        "",
        $demoReadySummary,
        "",
        "## Demo Day Status",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/demo-day-status.md",
        "JSON: prototype/t0mat0z/final_docs/overnight/demo-day-status.json",
        "",
        $demoDayStatusSummary,
        "",
        "## Demo Route",
        "",
        "Proof packet: prototype/t0mat0z/final_docs/overnight/demo-day-proof-packet.md",
        "Operator card: prototype/t0mat0z/final_docs/overnight/demo-operator-card.md",
        "",
        $demoRouteSummary,
        "",
        "## Dogbot Auth Status",
        "",
        "Report: prototype/t0mat0z/final_docs/overnight/dogbot-auth-status.json",
        "",
        $dogbotAuthSummary,
        "",
        "Auth candidates:",
        "",
        $dogbotAuthRows,
        "",
        "Recovery watcher log: prototype/t0mat0z/final_docs/overnight/dogbot-auth-recovery-watch.log",
        "",
        $dogbotAuthRecoverySummary,
        "",
        "Pending queue: prototype/t0mat0z/final_docs/overnight/dogbot-pending-receipts.jsonl",
        "",
        $dogbotPendingSummary,
        "",
        "## Dogbot Reaction Audit",
        "",
        $dogbotSummary,
        $controlSurface,
        $manifestSummary,
        "",
        "Receipt rows:",
        "",
        $dogbotRows,
        "",
        "Flagged experiments:",
        "",
        $flagRows,
        "",
        "## Screenshot Evidence",
        "",
        $screenshots,
        "",
        "## Explicit Limitations",
        "",
        "- Current build is still an Expo/React Native web simulator, not a completed native Android DAT app.",
        "- Android/DAT readiness is represented by the checklist and payload contract unless a real-device manual row is filled later.",
        "- Disease Scout output must remain triage/evidence memory: possible disease or stress, uncertainty, limitations, next check, and supervisor packet.",
        "- Do not present holdout score as perfect model accuracy; broad_state and bad_recapture failures are intentionally visible.",
        "- Do not recommend treatment or pesticides.",
        "",
        "## Controller Note",
        "",
        "This controller writes evidence and audit output only. It does not mark the GoalBuddy goal complete automatically; T999 still needs an agent/judge audit against the original requirements before completion."
    )
    $content | Set-Content -Path $GoalAuditPath -Encoding UTF8
}

function Remove-AppTestResults {
    $target = Join-Path $AppRoot "test-results"
    if (-not (Test-Path $target)) { return }
    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    $resolvedRoot = (Resolve-Path -LiteralPath $AppRoot).Path
    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Log "refusing_to_remove_test_results target=$resolvedTarget"
        return
    }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    Write-Log "removed_transient_test_results target=$resolvedTarget"
}

Write-Log "controller_started stop_at=$($StopAt.ToString('o')) pid=$PID"
Write-Heartbeat -Status "running"

while ((Get-Date) -lt $StopAt) {
    if (Test-Path $StopFile) {
        Write-Log "stop_file_detected path=$StopFile"
        Write-Heartbeat -Status "stopped_by_stop_file"
        exit 0
    }
    Write-Heartbeat -Status "running"
    $remaining = [Math]::Max(1, [int]($StopAt - (Get-Date)).TotalSeconds)
    Start-Sleep -Seconds ([Math]::Min(60, $remaining))
}

Write-Heartbeat -Status "auditing"
Write-Log "stop_time_reached audit_start"

$results = @()
$results += Invoke-LoggedCommand -Name "dogbot_logger_py_compile" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("-m", "py_compile", "scripts\dogbot-experiment-log.py")
$results += Invoke-LoggedCommand -Name "dogbot_auth_check" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\dogbot-auth-check.ps1", "-Out", $DogbotAuthStatusPath)
$results += Invoke-LoggedCommand -Name "dogbot_flush_pending_receipts" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "flush-pending")
$dogbotAuditResult = Invoke-LoggedCommand -Name "dogbot_reaction_audit" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "audit")
$results += $dogbotAuditResult
if ([int]$dogbotAuditResult.exit_code -eq 0) {
    $dogbotAuditResult.output | Set-Content -Path $DogbotAuditPath -Encoding UTF8
    if (Test-Path $DogbotAuditErrorPath) {
        Remove-Item -LiteralPath $DogbotAuditErrorPath -Force
    }
}
else {
    $dogbotAuditResult.output | Set-Content -Path $DogbotAuditErrorPath -Encoding UTF8
    Write-Log "dogbot_reaction_audit_failed_preserving_previous_audit path=$DogbotAuditPath error_path=$DogbotAuditErrorPath"
}
$results += Invoke-LoggedCommand -Name "npm_test" -WorkingDirectory $AppRoot -Exe "npm.cmd" -CommandArgs @("test")
$results += Invoke-LoggedCommand -Name "playwright_test" -WorkingDirectory $AppRoot -Exe "npx.cmd" -CommandArgs @("playwright", "test") -ExtraEnv @{ DISEASE_SCOUT_WEB_URL = "http://localhost:19006" }
$results += Invoke-LoggedCommand -Name "visual_professionalism_audit" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\visual-professionalism-audit.ps1", "-Out", $VisualAuditPath, "-MarkdownOut", $VisualAuditMdPath)
$results += Invoke-LoggedCommand -Name "network_preflight" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-network-preflight.ps1", "-Out", $NetworkPreflightPath)
$results += Invoke-LoggedCommand -Name "live_model_smoke" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\live-model-smoke.ps1", "-Out", $LiveModelSmokePath)
$results += Invoke-LoggedCommand -Name "live_model_diversity_smoke" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\live-model-diversity-smoke.ps1", "-Out", $LiveModelDiversityPath)
$results += Invoke-LoggedCommand -Name "live_ui_upload_smoke" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\live-ui-upload-smoke.ps1")
$results += Invoke-LoggedCommand -Name "latency_demo_audit" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\latency-demo-audit.ps1", "-Out", $LatencyAuditPath, "-MarkdownOut", $LatencyAuditMdPath)
$results += Invoke-LoggedCommand -Name "demo_ready_check" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-ready-check.ps1", "-Out", $DemoReadyCheckPath, "-AllowPendingMorningAudit", "-DogbotAuditPath", $DogbotAuditPath)
$results += Invoke-LoggedCommand -Name "demo_day_status" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-day-status.ps1", "-Out", $DemoDayStatusPath, "-JsonOut", $DemoDayStatusJsonPath)
$results += Invoke-LoggedCommand -Name "holdout_verifier_score" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\disease-verifier.ps1", "-Command", "Score", "-Manifest", ".\data\verifier\manifests\holdout_captures.jsonl", "-Predictions", ".\data\verifier\predictions\holdout.jsonl", "-Out", $VerifierReportPath)
$results += Invoke-LoggedCommand -Name "sensitive_file_scan" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\scripts\check-sensitive-files.ps1", "-Mode", "Current")
Remove-AppTestResults
$results += Invoke-LoggedCommand -Name "goalbuddy_checker" -WorkingDirectory $WorkspaceRoot -Exe "node.exe" -CommandArgs @($GoalChecker, $GoalStatePath)

Write-MorningAudit -Results $results
$results += Invoke-LoggedCommand -Name "demo_day_status_final" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-day-status.ps1", "-Out", $DemoDayStatusPath, "-JsonOut", $DemoDayStatusJsonPath)
Write-MorningAudit -Results $results
$failedResults = @($results | Where-Object { [int]$_.exit_code -ne 0 })
$finalHeartbeatStatus = "audit_complete"
if ($failedResults.Count -eq 0) {
    $morningReceiptArgs = @(
        "scripts\dogbot-experiment-log.py", "success",
        "--experiment-id", "T999-morning-audit",
        "--title", "Morning audit complete",
        "--summary", "10:00 AM controller audit completed and wrote the Disease Scout morning audit.",
        "--why", "Controller checks passed: Dogbot reaction audit, npm unit tests, Playwright browser flow, visual professionalism audit, demo network preflight artifact, live model upload smoke, live model diversity smoke, live browser upload smoke, latency demo audit, demo ready check from the Dogbot audit artifact, demo day status, holdout verifier score, sensitive-file scan, and GoalBuddy checker. The morning audit includes the prompt-to-artifact checklist, phone/LAN backend route, Dogbot reaction rows, visual screenshot reset proof, visual professionalism audit proof, speed/latency fallback proof, live browser upload proof, network preflight warnings, live model proof, non-static response proof, demo readiness summary, demo day operator status, holdout score summary, and explicit limitations. Do not treat a Tailscale-only route as venue Wi-Fi proof.",
        "--lane", "morning-audit",
        "--test", "dogbot-experiment-log.py audit",
        "--test", "scripts/dogbot-auth-check.ps1",
        "--test", "final_docs/overnight/dogbot-auth-recovery-watch.ps1",
        "--test", "dogbot-experiment-log.py flush-pending",
        "--test", "npm test",
        "--test", "DISEASE_SCOUT_WEB_URL=http://localhost:19006 npx playwright test",
        "--test", "scripts/visual-professionalism-audit.ps1",
        "--test", "scripts/demo-network-preflight.ps1",
        "--test", "scripts/demo-ready-check.ps1 -DogbotAuditPath dogbot-reaction-audit.json",
        "--test", "scripts/demo-day-status.ps1",
        "--test", "scripts/live-model-smoke.ps1",
        "--test", "scripts/live-model-diversity-smoke.ps1",
        "--test", "scripts/live-ui-upload-smoke.ps1",
        "--test", "scripts/latency-demo-audit.ps1",
        "--test", "disease-verifier.ps1 Score",
        "--test", "check-sensitive-files.ps1 -Mode Current",
        "--test", "GoalBuddy checker",
        "--test", "Dogbot screenshot upload path",
        "--changed-file", "docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md",
        "--changed-file", "scripts/dogbot-experiment-log.py",
        "--changed-file", "app/tests/e2e/disease-scout.baseline.spec.js",
        "--changed-file", "app/tests/e2e/disease-scout.live-upload.spec.js",
        "--changed-file", "scripts/live-ui-upload-smoke.ps1",
        "--changed-file", "final_docs/overnight/live-ui-upload-smoke.json",
        "--changed-file", "final_docs/overnight/live-ui-upload-smoke.png",
        "--changed-file", "scripts/visual-professionalism-audit.ps1",
        "--changed-file", "final_docs/overnight/visual-professionalism-audit.json",
        "--changed-file", "final_docs/overnight/visual-professionalism-audit.md",
        "--changed-file", "scripts/latency-demo-audit.ps1",
        "--changed-file", "final_docs/overnight/latency-demo-audit.json",
        "--changed-file", "final_docs/overnight/latency-demo-audit.md",
        "--changed-file", "scripts/demo-ready-check.ps1",
        "--changed-file", "final_docs/overnight/demo-ready-check.json",
        "--changed-file", "scripts/demo-day-status.ps1",
        "--changed-file", "final_docs/overnight/demo-day-status.md",
        "--changed-file", "final_docs/overnight/demo-day-status.json",
        "--changed-file", "scripts/demo-network-preflight.ps1",
        "--changed-file", "final_docs/overnight/network-preflight-latest.json",
        "--changed-file", "scripts/live-model-smoke.ps1",
        "--changed-file", "final_docs/overnight/live-model-smoke.json",
        "--changed-file", "scripts/live-model-diversity-smoke.ps1",
        "--changed-file", "final_docs/overnight/live-model-diversity-smoke.json",
        "--changed-file", "final_docs/overnight/demo-day-proof-packet.md",
        "--changed-file", "final_docs/overnight/demo-operator-card.md",
        "--changed-file", "final_docs/overnight/morning-holdout-score.md",
        "--changed-file", "final_docs/overnight/dogbot-reaction-audit.json",
        "--changed-file", "final_docs/overnight/dogbot-auth-status.json",
        "--changed-file", "final_docs/overnight/dogbot-auth-recovery-watch.ps1",
        "--changed-file", "final_docs/overnight/dogbot-auth-recovery-watch.log",
        "--changed-file", "final_docs/overnight/dogbot-pending-receipts.jsonl",
        "--changed-file", "scripts/repair-dogbot-auth.ps1",
        "--changed-file", "final_docs/overnight/dogbot-auth-repair.md",
        "--changed-file", "final_docs/overnight/open-fieldbot-hackathon-invite.cmd",
        "--changed-file", "final_docs/overnight/dogbot-reaction-audit-error.txt",
        "--screenshot", "final_docs/overnight/baseline-display-600.png",
        "--send"
    )
    $receipt = Invoke-LoggedCommand -Name "dogbot_morning_audit_receipt" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs $morningReceiptArgs
    $results += $receipt
    if ([int]$receipt.exit_code -ne 0) {
        $finalHeartbeatStatus = "audit_complete_with_dogbot_receipt_failure"
    }
    else {
        $dogbotAuditAfterReceipt = Invoke-LoggedCommand -Name "dogbot_reaction_audit_after_morning_receipt" -WorkingDirectory $RepoRoot -Exe $Python -CommandArgs @("scripts\dogbot-experiment-log.py", "audit")
        $results += $dogbotAuditAfterReceipt
        if ([int]$dogbotAuditAfterReceipt.exit_code -eq 0) {
            $dogbotAuditAfterReceipt.output | Set-Content -Path $DogbotAuditPath -Encoding UTF8
            if (Test-Path $DogbotAuditErrorPath) {
                Remove-Item -LiteralPath $DogbotAuditErrorPath -Force
            }
        }
        else {
            $dogbotAuditAfterReceipt.output | Set-Content -Path $DogbotAuditErrorPath -Encoding UTF8
            Write-Log "dogbot_reaction_audit_after_morning_receipt_failed_preserving_previous_audit path=$DogbotAuditPath error_path=$DogbotAuditErrorPath"
        }
        $results += Invoke-LoggedCommand -Name "demo_ready_check_after_morning_receipt" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-ready-check.ps1", "-Out", $DemoReadyCheckPath, "-DogbotAuditPath", $DogbotAuditPath)
        $results += Invoke-LoggedCommand -Name "demo_day_status_after_morning_receipt" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\demo-day-status.ps1", "-Out", $DemoDayStatusPath, "-JsonOut", $DemoDayStatusJsonPath)
    }
}
else {
    Write-Log "skipping_morning_dogbot_success_receipt failed_count=$($failedResults.Count)"
    $finalHeartbeatStatus = "audit_complete_with_failures"
}
Write-MorningAudit -Results $results
$postReceiptFailures = @($results | Where-Object { [int]$_.exit_code -ne 0 })
if ($postReceiptFailures.Count -gt 0 -and $finalHeartbeatStatus -eq "audit_complete") {
    $finalHeartbeatStatus = "audit_complete_with_failures"
}
Write-Heartbeat -Status $finalHeartbeatStatus

$finalReview = Invoke-LoggedCommand -Name "final_t999_review" -WorkingDirectory $RepoRoot -Exe "powershell.exe" -CommandArgs @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts\final-t999-review.ps1", "-Out", $FinalT999ReviewPath, "-JsonOut", $FinalT999ReviewJsonPath, "-StopAt", $StopAt.ToString("o"))
$results += $finalReview
Write-MorningAudit -Results $results
if ([int]$finalReview.exit_code -ne 0) {
    Write-Heartbeat -Status "audit_complete_with_final_review_blockers"
    Write-Log "audit_complete_with_final_review_blockers morning_audit=$GoalAuditPath final_review=$FinalT999ReviewPath"
}
else {
    Write-Heartbeat -Status $finalHeartbeatStatus
    Write-Log "$finalHeartbeatStatus morning_audit=$GoalAuditPath final_review=$FinalT999ReviewPath"
}
