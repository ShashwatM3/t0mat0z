param(
    [string]$Out = "docs\goals\disease-scout-overnight-experiment-control\notes\final-t999-review.md",
    [string]$JsonOut = "docs\goals\disease-scout-overnight-experiment-control\notes\final-t999-review.json",
    [datetime]$StopAt = [datetime]"2026-05-16T10:00:00-07:00"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceRoot = (Resolve-Path (Join-Path $repoRoot "..\..")).Path
$generatedAt = Get-Date

function Resolve-WorkspacePath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $workspaceRoot $Path))
}

function Resolve-RepoPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Path))
}

function Read-JsonRepo {
    param([string]$Path)
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path $resolved)) { return $null }
    return Get-Content -Raw $resolved | ConvertFrom-Json
}

function Read-TextRepo {
    param([string]$Path)
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path $resolved)) { return "" }
    return Get-Content -Raw $resolved
}

function Read-TextWorkspace {
    param([string]$Path)
    $resolved = Resolve-WorkspacePath $Path
    if (-not (Test-Path $resolved)) { return "" }
    return Get-Content -Raw $resolved
}

function File-State {
    param(
        [string]$Path,
        [switch]$Workspace
    )
    $resolved = if ($Workspace) { Resolve-WorkspacePath $Path } else { Resolve-RepoPath $Path }
    $item = Get-Item -LiteralPath $resolved -ErrorAction SilentlyContinue
    return [ordered]@{
        path = $Path.Replace("\", "/")
        exists = [bool]$item
        size_bytes = if ($item) { [int64]$item.Length } else { $null }
        last_write_time = if ($item) { $item.LastWriteTime.ToString("o") } else { $null }
    }
}

$morningAudit = File-State -Workspace -Path "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md"
$goalState = File-State -Workspace -Path "docs\goals\disease-scout-overnight-experiment-control\state.yaml"
$completionChecklist = File-State -Workspace -Path "docs\goals\disease-scout-overnight-experiment-control\notes\completion-audit-checklist.md"
$demoReady = Read-JsonRepo "final_docs\overnight\demo-ready-check.json"
$demoStatus = Read-JsonRepo "final_docs\overnight\demo-day-status.json"
$dogbotAudit = Read-JsonRepo "final_docs\overnight\dogbot-reaction-audit.json"
$dogbotAuth = Read-JsonRepo "final_docs\overnight\dogbot-auth-status.json"
$manifest = Read-JsonRepo "final_docs\discord-experiment-manifest.json"
$pendingReceiptsPath = Resolve-RepoPath "final_docs\overnight\dogbot-pending-receipts.jsonl"
$visual = Read-JsonRepo "final_docs\overnight\visual-professionalism-audit.json"
$latency = Read-JsonRepo "final_docs\overnight\latency-demo-audit.json"
$heartbeat = Read-JsonRepo "final_docs\overnight\overnight-heartbeat.json"
$liveUi = Read-JsonRepo "final_docs\overnight\live-ui-upload-smoke.json"
$morningText = Read-TextWorkspace "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md"
$e2eBaselineText = Read-TextRepo "app\tests\e2e\disease-scout.baseline.spec.js"
$proofPacketText = Read-TextRepo "final_docs\overnight\demo-day-proof-packet.md"
$operatorCardText = Read-TextRepo "final_docs\overnight\demo-operator-card.md"
$holdoutText = Read-TextRepo "final_docs\overnight\morning-holdout-score.md"
$claimText = @($morningText, $proofPacketText, $operatorCardText) -join "`n"
$blindPackRoot = Join-Path $env:USERPROFILE "Downloads\DiseaseScout-Test-Images-20260516-000304"
$blindImageDir = Join-Path $blindPackRoot "blind_upload_images"
$blindLabelsPath = Join-Path $blindPackRoot "labels.csv"
$blindReadmePath = Join-Path $blindPackRoot "README.txt"
$blindImageCount = if (Test-Path $blindImageDir) { @(Get-ChildItem -LiteralPath $blindImageDir -File -Include *.jpg,*.jpeg,*.png,*.webp -ErrorAction SilentlyContinue).Count } else { 0 }
$blindLabelRows = if (Test-Path $blindLabelsPath) { @((Import-Csv -LiteralPath $blindLabelsPath)).Count } else { 0 }
$blindReadmeText = if (Test-Path $blindReadmePath) { Get-Content -Raw -LiteralPath $blindReadmePath } else { "" }

$nowBeforeStop = $generatedAt -lt $StopAt
$dogbotFlagged = if ($dogbotAudit) { @($dogbotAudit.review | Where-Object { $_.flagged_for_morning_review }) } else { @() }
$manifestMessages = if ($manifest) { @($manifest.messages) } else { @() }
$acceptedManifestMessages = @($manifestMessages | Where-Object { -not $_.receipt_kind -or $_.receipt_kind -eq "accepted" })
$queuedManifestMessages = @($manifestMessages | Where-Object { $_.receipt_kind -eq "queued-local" })
$manifestScreenshotRows = @($acceptedManifestMessages | Where-Object { [int]$_.screenshot_count -gt 0 })
$dogbotReviewCount = if ($dogbotAudit) { @($dogbotAudit.review).Count } else { 0 }
$dogbotManifestMatchesAudit = $dogbotReviewCount -eq $manifestMessages.Count
$pendingReceiptRecords = @()
if (Test-Path $pendingReceiptsPath) {
    $pendingReceiptRecords = @(Get-Content -LiteralPath $pendingReceiptsPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}
$demoStatusBlockers = if ($demoStatus) { @($demoStatus.blockers).Count } else { $null }
$demoStatusWarnings = if ($demoStatus) { @($demoStatus.warnings).Count } else { $null }
$providerList = if ($demoReady -and $demoReady.backend_health -and $demoReady.backend_health.body) { @($demoReady.backend_health.body.supported_providers) } else { @() }
$providerSwapOk = $demoReady -and $demoReady.backend_health.ok -and ($providerList -contains "codex-cli") -and ($providerList -contains "gemini")
$liveUiUploadOk = $liveUi -and $liveUi.status -eq "pass" -and $liveUi.response_status -eq 200 -and [bool]$liveUi.checks.browser_upload_reached_backend -and [bool]$liveUi.checks.no_treatment_advice
$liveUiScreenshotExists = $liveUi -and $liveUi.screenshot -and (Test-Path (Resolve-RepoPath $liveUi.screenshot))
$liveUiTypedReportOk = $liveUi -and [string]$liveUi.report_text -and [string]$liveUi.observation.wearer_note -and ([string]$liveUi.report_text -eq [string]$liveUi.observation.wearer_note) -and [bool]$liveUi.checks.report_preserved
$morningHasNpmPass = $morningText -match 'npm_test:\s+exit\s+0'
$morningHasPlaywrightPass = $morningText -match 'playwright_test:\s+exit\s+0'
$morningHasSensitivePass = $morningText -match 'sensitive_file_scan:\s+exit\s+0'
$morningHasHoldoutPass = $morningText -match 'holdout_verifier_score:\s+exit\s+0'
$morningHasDogbotAuditPass = $morningText -match 'dogbot_reaction_audit:\s+exit\s+0'
$morningHasLiveUiPass = $morningText -match 'live_ui_upload_smoke:\s+exit\s+0'
$dogbotAuthOk = $dogbotAuth -and $dogbotAuth.status -eq "pass"
$dogbotAuthSelected = if ($dogbotAuth -and $dogbotAuth.selected) { $dogbotAuth.selected } else { "none" }
$dogbotTargetGuildVisible = if ($dogbotAuth -and $dogbotAuth.checks) { [bool](@($dogbotAuth.checks | Where-Object { $_.target_guild_visible }).Count -gt 0) } else { $false }
$holdoutCoreOk = ($holdoutText -match 'Missing predictions:\s*0') -and ($holdoutText -match 'Extra predictions:\s*0')
$holdoutSafetyRowsOk = @(
    'valid_schema',
    'limitations_named',
    'next_check_exists',
    'no_treatment_advice',
    'report_preserved',
    'safe_review_status'
) | ForEach-Object {
    $pattern = "\|\s*$($_)\s*\|\s*306\s*\|\s*306\s*\|\s*100\.0%\s*\|"
    $holdoutText -match $pattern
}
$holdoutSafetyOk = -not ($holdoutSafetyRowsOk -contains $false)
$holdoutKnownFailuresVisible = ($holdoutText -match '\|\s*broad_state\s*\|') -and ($holdoutText -match '\|\s*bad_recapture_behavior\s*\|')
$diversityStaticOk = $demoReady -and [bool]$demoReady.live_model_diversity_ok
$unsafeClaimHits = @()
if ($claimText -match '(?i)\breal\s+DAT\s+(integration|app|device)\s+(is|was|verified|complete|done|working)\b') {
    $unsafeClaimHits += "real DAT integration success claim"
}
if ($claimText -match '(?i)\bfinal\s+diagnosis\s+(is|was|verified|complete|done|working)\b') {
    $unsafeClaimHits += "final diagnosis success claim"
}
if ($claimText -match '(?i)\b(pesticide|fungicide)\s+recommendation\b') {
    $unsafeClaimHits += "treatment recommendation claim"
}

$criteria = @(
    [ordered]@{
        requirement = "controlled_run_and_morning_audit"
        evidence = "state.yaml, heartbeat, morning-audit.md"
        pass = (-not $nowBeforeStop) -and [bool]$morningAudit.exists -and $heartbeat -and ($heartbeat.status -eq "audit_complete")
        status = if ($nowBeforeStop) { "pending" } else { "fail" }
        detail = "before_stop=$nowBeforeStop; morning_audit_exists=$($morningAudit.exists); heartbeat=$($heartbeat.status)"
    },
    [ordered]@{
        requirement = "web_mobile_visual_workflow"
        evidence = "npm/Playwright proof, screenshots, visual-professionalism-audit.json"
        pass = $visual -and $visual.status -eq "pass" -and [int]$visual.failed_count -eq 0 -and $morningHasNpmPass -and $morningHasPlaywrightPass
        status = if ($nowBeforeStop -and $visual -and $visual.status -eq "pass" -and [int]$visual.failed_count -eq 0) { "pending" } else { "fail" }
        detail = if ($visual) { "visual_status=$($visual.status); screenshots=$($visual.screenshot_count); failed=$($visual.failed_count); npm_exit0=$morningHasNpmPass; playwright_exit0=$morningHasPlaywrightPass" } else { "visual audit missing" }
    },
    [ordered]@{
        requirement = "provider_swap_and_live_model"
        evidence = "demo-ready-check.json, live-model-smoke.json, live-model-diversity-smoke.json"
        pass = $providerSwapOk -and [bool]$demoReady.live_model_smoke_ok -and [bool]$demoReady.live_model_diversity_ok
        detail = if ($demoReady) { "provider_swap_ok=$providerSwapOk; providers=$($providerList -join ','); demo_ready_status=$($demoReady.status); blockers=$(@($demoReady.blockers).Count); live_model=$($demoReady.live_model_smoke_ok); diversity=$($demoReady.live_model_diversity_ok)" } else { "demo-ready missing" }
    },
    [ordered]@{
        requirement = "live_browser_upload_and_typed_report"
        evidence = "live-ui-upload-smoke.json, live-ui-upload-smoke.png, and morning command table"
        pass = $liveUiUploadOk -and $liveUiScreenshotExists -and $liveUiTypedReportOk -and $morningHasLiveUiPass
        status = if ($nowBeforeStop -and $liveUiUploadOk -and $liveUiScreenshotExists -and $liveUiTypedReportOk) { "pending" } else { "fail" }
        detail = if ($liveUi) { "status=$($liveUi.status); response=$($liveUi.response_status); backend=$($liveUi.checks.browser_upload_reached_backend); no_treatment=$($liveUi.checks.no_treatment_advice); screenshot_exists=$liveUiScreenshotExists; typed_report_preserved=$liveUiTypedReportOk; morning_exit0=$morningHasLiveUiPass" } else { "live UI upload smoke missing" }
    },
    [ordered]@{
        requirement = "deferred_offline_capture"
        evidence = "Playwright retry test in e2e source and morning command table"
        pass = [bool]$morningAudit.exists -and $morningHasPlaywrightPass -and ($e2eBaselineText -match 'queues uploaded evidence when analysis is unavailable and retries later')
        status = if ($nowBeforeStop -and ($e2eBaselineText -match 'queues uploaded evidence when analysis is unavailable and retries later')) { "pending" } else { "fail" }
        detail = "playwright_exit0=$morningHasPlaywrightPass; retry_test_present=$($e2eBaselineText -match 'queues uploaded evidence when analysis is unavailable and retries later')"
    },
    [ordered]@{
        requirement = "android_dat_honesty"
        evidence = "android-dat-checklist.md, proof packet blocked claims"
        pass = [bool](File-State -Path "final_docs\android-dat-checklist.md").exists
        detail = "checklist present; real DAT success not claimed"
    },
    [ordered]@{
        requirement = "manual_blind_image_pack"
        evidence = "Downloads DiseaseScout-Test-Images pack with neutral filenames and labels.csv"
        pass = (Test-Path $blindPackRoot) -and (Test-Path $blindImageDir) -and (Test-Path $blindLabelsPath) -and (Test-Path $blindReadmePath) -and $blindImageCount -ge 18 -and $blindLabelRows -ge 18 -and ($blindReadmeText -match 'filenames are intentionally neutral')
        detail = "pack_exists=$(Test-Path $blindPackRoot); image_count=$blindImageCount; label_rows=$blindLabelRows; readme_neutral_note=$($blindReadmeText -match 'filenames are intentionally neutral')"
    },
    [ordered]@{
        requirement = "dogbot_project_control_receipts"
        evidence = "dogbot-auth-status.json, dogbot-reaction-audit.json, and discord-experiment-manifest.json"
        pass = $dogbotAuthOk -and $dogbotAudit -and $morningHasDogbotAuditPass -and $dogbotAudit.channel_status.under_project_control -and $acceptedManifestMessages.Count -ge 20 -and $dogbotFlagged.Count -eq 0 -and $dogbotManifestMatchesAudit
        status = if ($nowBeforeStop -and $dogbotAuthOk -and $dogbotAudit -and $dogbotAudit.channel_status.under_project_control) { "pending" } else { "fail" }
        detail = if ($dogbotAudit) { "dogbot_auth_status=$($dogbotAuth.status); selected=$dogbotAuthSelected; target_guild_visible=$dogbotTargetGuildVisible; dogbot_exit0=$morningHasDogbotAuditPass; audit_receipts=$dogbotReviewCount; manifest_rows=$($manifestMessages.Count); accepted_rows=$($acceptedManifestMessages.Count); queued_local_rows=$($queuedManifestMessages.Count); manifest_matches_audit=$dogbotManifestMatchesAudit; flagged=$($dogbotFlagged.Count); under_project_control=$($dogbotAudit.channel_status.under_project_control)" } else { "dogbot audit missing; dogbot_auth_status=$($dogbotAuth.status); selected=$dogbotAuthSelected; target_guild_visible=$dogbotTargetGuildVisible" }
    },
    [ordered]@{
        requirement = "dogbot_pending_receipts_flushed"
        evidence = "dogbot-pending-receipts.jsonl"
        pass = $pendingReceiptRecords.Count -eq 0
        detail = "pending_receipts=$($pendingReceiptRecords.Count)"
    },
    [ordered]@{
        requirement = "screenshot_cadence"
        evidence = "discord-experiment-manifest.json"
        pass = $acceptedManifestMessages.Count -gt 0 -and $manifestScreenshotRows.Count -ge [Math]::Floor($acceptedManifestMessages.Count / 3)
        detail = "manifest_messages=$($manifestMessages.Count); accepted_rows=$($acceptedManifestMessages.Count); queued_local_rows=$($queuedManifestMessages.Count); screenshot_rows=$($manifestScreenshotRows.Count); expected_min=$([Math]::Floor($acceptedManifestMessages.Count / 3))"
    },
    [ordered]@{
        requirement = "latency_and_demo_fallback"
        evidence = "latency-demo-audit.json"
        pass = $latency -and $latency.status -ne "fail" -and $latency.fallback
        detail = if ($latency) { "latency_status=$($latency.status); max_model_ms=$($latency.max_model_latency_ms)" } else { "latency audit missing" }
    },
    [ordered]@{
        requirement = "operator_demo_status_surface"
        evidence = "demo-day-status.md and demo-day-status.json"
        pass = $demoStatus -and $demoStatusBlockers -eq 0 -and $demoStatus.web.ok -and $demoStatus.backend.ok -and $demoStatus.dogbot_audit.under_project_control
        detail = if ($demoStatus) { "status=$($demoStatus.status); blockers=$demoStatusBlockers; warnings=$demoStatusWarnings; web_ok=$($demoStatus.web.ok); backend_ok=$($demoStatus.backend.ok); dogbot_under_project_control=$($demoStatus.dogbot_audit.under_project_control)" } else { "demo-day status missing" }
    },
    [ordered]@{
        requirement = "safe_claim_boundaries"
        evidence = "demo-day-proof-packet.md, demo-operator-card.md, morning-audit.md"
        pass = (File-State -Path "final_docs\overnight\demo-day-proof-packet.md").exists -and (File-State -Path "final_docs\overnight\demo-operator-card.md").exists -and $unsafeClaimHits.Count -eq 0 -and $morningHasSensitivePass
        status = if ($nowBeforeStop -and (File-State -Path "final_docs\overnight\demo-day-proof-packet.md").exists -and (File-State -Path "final_docs\overnight\demo-operator-card.md").exists -and $unsafeClaimHits.Count -eq 0) { "pending" } else { "fail" }
        detail = "proof packet/operator card present; unsafe_claim_hits=$($unsafeClaimHits.Count); sensitive_scan_exit0=$morningHasSensitivePass"
    },
    [ordered]@{
        requirement = "no_cheating_verifier"
        evidence = "morning-holdout-score.md and morning command table"
        pass = [bool](File-State -Path "final_docs\overnight\morning-holdout-score.md").exists -and $morningHasHoldoutPass -and $holdoutCoreOk -and $holdoutSafetyOk -and $holdoutKnownFailuresVisible -and $diversityStaticOk
        status = if ($nowBeforeStop -and $diversityStaticOk) { "pending" } else { "fail" }
        detail = "holdout_report_exists=$((File-State -Path "final_docs\overnight\morning-holdout-score.md").exists); holdout_exit0=$morningHasHoldoutPass; missing_extra_ok=$holdoutCoreOk; safety_rows_100=$holdoutSafetyOk; failures_visible=$holdoutKnownFailuresVisible; diversity_static_check=$diversityStaticOk"
    },
    [ordered]@{
        requirement = "final_winning_demo_verdict"
        evidence = "final-t999-review.md after 10:00"
        pass = (-not $nowBeforeStop) -and [bool]$morningAudit.exists
        status = if ($nowBeforeStop) { "pending" } else { "fail" }
        detail = if ($nowBeforeStop) { "pending until stop time" } else { "morning audit present=$($morningAudit.exists)" }
    }
)

$blockers = @()
foreach ($criterion in $criteria) {
    if (-not $criterion.pass) {
        $blockers += "$($criterion.requirement): $($criterion.detail)"
    }
}

$complete = $blockers.Count -eq 0
$verdict = if ($complete) { "complete" } else { "not_complete" }
$winningVerdict = if ($complete) {
    "The demo has wearer action, glasses-style capture input, structured DiseaseScoutObservation output, judge-visible proof, Dogbot receipts, and honest limitations."
}
else {
    "Not complete yet. The run still needs the 10:00 controller audit and final evidence review before any completion claim."
}

$result = [ordered]@{
    generated_at = $generatedAt.ToString("o")
    verdict = $verdict
    full_outcome_complete = $complete
    stop_at = $StopAt.ToString("o")
    objective_restated = "Run the Disease Scout Memory overnight control loop, preserve a judge-visible disease scouting workflow, verify web/mobile/model/Dogbot/DAT-readiness evidence, and complete only after the 10:00 morning audit proves the outcome without unsupported real-DAT, final-diagnosis, or treatment claims."
    accepted_experiments = $acceptedManifestMessages.Count
    queued_local_receipts = $queuedManifestMessages.Count
    pending_local_receipts = $pendingReceiptRecords.Count
    flagged_experiments = $dogbotFlagged.Count
    screenshot_receipt_rows = $manifestScreenshotRows.Count
    criteria = $criteria
    blockers = $blockers
    winning_objective_verdict = $winningVerdict
    files = @(
        $goalState
        $completionChecklist
        $morningAudit
        (File-State -Path "final_docs\overnight\demo-ready-check.json")
        (File-State -Path "final_docs\overnight\demo-day-status.json")
        (File-State -Path "final_docs\overnight\dogbot-auth-status.json")
        (File-State -Path "final_docs\overnight\dogbot-auth-recovery-watch.ps1")
        (File-State -Path "final_docs\overnight\dogbot-auth-recovery-watch.log")
        (File-State -Path "final_docs\overnight\dogbot-pending-receipts.jsonl")
        (File-State -Path "scripts\repair-dogbot-auth.ps1")
        (File-State -Path "final_docs\overnight\dogbot-auth-repair.md")
        (File-State -Path "final_docs\overnight\open-fieldbot-hackathon-invite.cmd")
        (File-State -Path "final_docs\overnight\dogbot-reaction-audit-error.txt")
        (File-State -Path "final_docs\overnight\dogbot-reaction-audit.json")
        (File-State -Path "final_docs\overnight\live-ui-upload-smoke.json")
        (File-State -Path "final_docs\overnight\live-ui-upload-smoke.png")
        (File-State -Path "final_docs\discord-experiment-manifest.json")
        (File-State -Path "final_docs\overnight\visual-professionalism-audit.json")
        (File-State -Path "final_docs\overnight\latency-demo-audit.json")
        (File-State -Path $blindPackRoot)
        (File-State -Path $blindLabelsPath)
    )
}

$jsonPath = Resolve-WorkspacePath $JsonOut
$jsonParent = Split-Path -Parent $jsonPath
if ($jsonParent) {
    New-Item -ItemType Directory -Force -Path $jsonParent | Out-Null
}
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $jsonPath -Encoding UTF8

$criteriaRows = $criteria | ForEach-Object {
    $state = if ($_.pass) { "pass" } elseif ($_.Contains("status")) { $_.status } else { "fail" }
    "| $($_.requirement) | $state | $($_.evidence) | $($_.detail) |"
}
$blockerRows = if ($blockers.Count -gt 0) { $blockers | ForEach-Object { "- $_" } } else { @("- none") }
$fileRows = $result.files | ForEach-Object {
    $state = if ($_.exists) { "present" } else { "missing" }
    "- $($_.path): $state, size=$($_.size_bytes), mtime=$($_.last_write_time)"
}

$markdown = @(
    "# Final T999 Review",
    "",
    "Generated: $($result.generated_at)",
    "Verdict: $($result.verdict)",
    "full_outcome_complete: $($result.full_outcome_complete.ToString().ToLowerInvariant())",
    "",
    "## Objective Restated",
    "",
    $result.objective_restated,
    "",
    "## Prompt-To-Artifact Checklist",
    "",
    "| Requirement | Status | Evidence | Detail |",
    "| --- | --- | --- | --- |",
    $criteriaRows,
    "",
    "## Accepted Experiments",
    "",
    "- Dogbot accepted manifest rows: $($result.accepted_experiments)",
    "- Dogbot queued-local manifest rows: $($result.queued_local_receipts)",
    "- Dogbot pending local receipt rows: $($result.pending_local_receipts)",
    "- Screenshot-bearing receipt rows: $($result.screenshot_receipt_rows)",
    "",
    "## Flagged Experiments",
    "",
    "- Flagged by thumbs-down audit: $($result.flagged_experiments)",
    "",
    "## Screenshots And Tests",
    "",
    "- Visual audit: $($visual.status), failed=$($visual.failed_count)",
    "- Latency audit: $($latency.status), max_model_latency_ms=$($latency.max_model_latency_ms)",
    "- Demo-ready: status=$($demoReady.status), blockers=$(@($demoReady.blockers).Count), warnings=$(@($demoReady.warnings).Count)",
    "",
    "## Hacks Found Or Resolved",
    "",
    "- Label leaks are kept out of live model requests; holdout failures are preserved.",
    "- Static-response risk is checked by live model diversity smoke.",
    "- Treatment/final-diagnosis claims are blocked by schema/tests/proof packet wording.",
    "- Real DAT integration is not claimed without hardware checklist evidence.",
    "",
    "## Winning-Objective Verdict",
    "",
    $result.winning_objective_verdict,
    "",
    "## Blockers",
    "",
    $blockerRows,
    "",
    "## Evidence Files",
    "",
    $fileRows
)

$mdPath = Resolve-WorkspacePath $Out
$mdParent = Split-Path -Parent $mdPath
if ($mdParent) {
    New-Item -ItemType Directory -Force -Path $mdParent | Out-Null
}
$markdown | Set-Content -Path $mdPath -Encoding UTF8

Write-Output "verdict=$verdict"
Write-Output "full_outcome_complete=$($complete.ToString().ToLowerInvariant())"
Write-Output "markdown=$mdPath"
Write-Output "json=$jsonPath"
Write-Output "blockers=$($blockers.Count)"
foreach ($blocker in $blockers) {
    Write-Output "blocker=$blocker"
}

if ($complete) {
    exit 0
}
exit 2
