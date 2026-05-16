param(
    [string]$Out = "final_docs\overnight\demo-ready-check.json",
    [string]$WebUrl = "http://localhost:19006",
    [string]$BackendHealthUrl = "http://localhost:8787/health",
    [string]$DogbotAuditPath = "",
    [switch]$AllowPendingMorningAudit,
    [switch]$RunDogbotAudit
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceRoot = (Resolve-Path (Join-Path $repoRoot "..\..")).Path
$python = Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    $python = "python.exe"
}
$stopAt = [datetime]"2026-05-16T10:00:00-07:00"

function Resolve-OutputPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Path))
}

$outPath = Resolve-OutputPath -Path $Out

function Test-Web {
    param(
        [string]$Url,
        [switch]$Json
    )

    $started = Get-Date
    try {
        if ($Json) {
            $body = Invoke-RestMethod -Uri $Url -TimeoutSec 10
            return [ordered]@{
                ok = $true
                url = $Url
                elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds)
                body = $body
                error = $null
            }
        }

        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        return [ordered]@{
            ok = ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400)
            url = $Url
            status_code = [int]$response.StatusCode
            elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds)
            length = [int64]$response.RawContentLength
            error = $null
        }
    }
    catch {
        return [ordered]@{
            ok = $false
            url = $Url
            elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds)
            error = $_.Exception.Message
        }
    }
}

function Read-Json {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    return Get-Content -Raw $Path | ConvertFrom-Json
}

function Artifact-Row {
    param([string]$RelPath)
    $path = Join-Path $repoRoot $RelPath
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    return [ordered]@{
        path = $RelPath.Replace("\", "/")
        exists = [bool]$item
        size_bytes = if ($item) { [int64]$item.Length } else { $null }
        last_write_time = if ($item) { $item.LastWriteTime.ToString("o") } else { $null }
    }
}

$blockers = @()
$warnings = @()

$backend = Test-Web -Url $BackendHealthUrl -Json
if (-not ($backend.ok -and $backend.body -and $backend.body.ok)) {
    $blockers += "Backend health is not ok."
}

$web = Test-Web -Url $WebUrl
if (-not $web.ok) {
    $blockers += "Web simulator is not reachable."
}

$artifactPaths = @(
    "final_docs\overnight\demo-operator-card.md",
    "final_docs\overnight\demo-day-proof-packet.md",
    "final_docs\overnight\baseline-desktop.png",
    "final_docs\overnight\baseline-mobile-390.png",
    "final_docs\overnight\baseline-display-600.png",
    "final_docs\overnight\visual-professionalism-audit.json",
    "final_docs\overnight\visual-professionalism-audit.md",
    "final_docs\overnight\latency-demo-audit.json",
    "final_docs\overnight\latency-demo-audit.md",
    "final_docs\overnight\dogbot-auth-repair.md",
    "final_docs\overnight\open-fieldbot-hackathon-invite.cmd",
    "final_docs\overnight\live-model-smoke.json",
    "final_docs\overnight\live-model-diversity-smoke.json",
    "final_docs\overnight\live-ui-upload-smoke.json",
    "final_docs\overnight\live-ui-upload-smoke.png",
    "final_docs\overnight\network-preflight-latest.json",
    "final_docs\overnight\visible-holdout-score-latest.md",
    "final_docs\android-dat-checklist.md",
    "final_docs\discord-experiment-manifest.json"
)
$artifacts = @($artifactPaths | ForEach-Object { Artifact-Row -RelPath $_ })
$missingArtifacts = @($artifacts | Where-Object { -not $_.exists })
if ($missingArtifacts.Count -gt 0) {
    $blockers += "Missing required demo artifacts: $((@($missingArtifacts | ForEach-Object { $_.path }) -join ', '))"
}

$liveUi = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\live-ui-upload-smoke.json")
$liveUiOk = $false
if ($liveUi) {
    $liveUiOk = $liveUi.status -eq "pass" -and
        [bool]$liveUi.checks.browser_upload_reached_backend -and
        [bool]$liveUi.checks.no_treatment_advice -and
        $liveUi.response_status -eq 200
}
if (-not $liveUiOk) {
    $blockers += "Live browser upload smoke is missing or not passing."
}

$liveModel = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\live-model-smoke.json")
$liveModelOk = $false
if ($liveModel) {
    $liveModelOk = $liveModel.status -eq "pass" -and $null -eq $liveModel.observation.treatment_recommendation
}
if (-not $liveModelOk) {
    $blockers += "Live model smoke is missing or not passing."
}

$liveDiversity = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\live-model-diversity-smoke.json")
$liveDiversityOk = $false
if ($liveDiversity) {
    $liveDiversityOk = $liveDiversity.status -eq "pass" -and
        [int]$liveDiversity.unique_response_signatures -ge 2 -and
        [int]$liveDiversity.treatment_advice_count -eq 0
}
if (-not $liveDiversityOk) {
    $blockers += "Live model diversity smoke is missing or not passing."
}

$visualAudit = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\visual-professionalism-audit.json")
$visualAuditOk = $false
if ($visualAudit) {
    $visualAuditOk = $visualAudit.status -eq "pass" -and [int]$visualAudit.failed_count -eq 0
}
if (-not $visualAuditOk) {
    $blockers += "Visual professionalism audit is missing or not passing."
}

$latencyAudit = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\latency-demo-audit.json")
$latencyAuditOk = $false
if ($latencyAudit) {
    $latencyAuditOk = $latencyAudit.status -ne "fail"
    if ($latencyAudit.status -eq "warn") {
        $warnings += "Latency demo audit has warnings: $((@($latencyAudit.warnings) -join ' | '))"
    }
}
if (-not $latencyAuditOk) {
    $blockers += "Latency demo audit is missing or failing."
}

$dogbotAuth = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\dogbot-auth-status.json")
if ($dogbotAuth -and $dogbotAuth.status -eq "blocked") {
    $blockers += "Dogbot live auth is blocked: $($dogbotAuth.blocker)"
}
$dogbotAuthCandidates = @()
if ($dogbotAuth -and $dogbotAuth.checks) {
    $dogbotAuthCandidates = @($dogbotAuth.checks | ForEach-Object {
        [ordered]@{
            label = $_.label
            bot_username = $_.bot_username
            me_status = $_.me_status
            guilds_status = $_.guilds_status
            target_guild_visible = $_.target_guild_visible
            target_guild_name = $_.target_guild_name
            channel_status = $_.channel_status
            channel_error = $_.channel_error
            invite_url = $_.invite_url
        }
    })
}

$pendingReceiptPath = Join-Path $repoRoot "final_docs\overnight\dogbot-pending-receipts.jsonl"
$pendingReceiptRecords = @()
if (Test-Path $pendingReceiptPath) {
    try {
        $pendingReceiptRecords = @(Get-Content -LiteralPath $pendingReceiptPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    }
    catch {
        $blockers += "Dogbot pending receipt queue could not be parsed: $($_.Exception.Message)"
    }
}
if ($pendingReceiptRecords.Count -gt 0) {
    $blockers += "Dogbot pending receipt queue has $($pendingReceiptRecords.Count) unflushed local receipt(s)."
}

$network = Read-Json -Path (Join-Path $repoRoot "final_docs\overnight\network-preflight-latest.json")
if (-not $network) {
    $warnings += "Network preflight latest report is missing."
}
elseif ($network.status -eq "fail") {
    $blockers += "Network preflight status is fail."
}
elseif ($network.status -eq "warn") {
    $warnings += "Network preflight has warnings: $((@($network.warnings) -join ' | '))"
}

$manifest = Read-Json -Path (Join-Path $repoRoot "final_docs\discord-experiment-manifest.json")
$manifestSummary = [ordered]@{
    ok = $false
    message_count = 0
    screenshot_count = 0
    latest_experiment = $null
    latest_message_id = $null
}
if ($manifest) {
    $messages = @($manifest.messages)
    $withScreenshots = @($messages | Where-Object { [int]$_.screenshot_count -gt 0 })
    $latest = if ($messages.Count -gt 0) { $messages[-1] } else { $null }
    $manifestSummary = [ordered]@{
        ok = $messages.Count -ge 20 -and $withScreenshots.Count -ge 5
        message_count = $messages.Count
        screenshot_count = $withScreenshots.Count
        latest_experiment = if ($latest) { $latest.experiment_id } else { $null }
        latest_message_id = if ($latest) { $latest.message_id } else { $null }
    }
}
if (-not $manifestSummary.ok) {
    $blockers += "Dogbot manifest does not have enough receipts/screenshots for demo proof."
}

$dogbotAudit = $null
if ($DogbotAuditPath -and (Test-Path $DogbotAuditPath)) {
    try {
        $dogbotAudit = Get-Content -Raw $DogbotAuditPath | ConvertFrom-Json
        if (-not $dogbotAudit.channel_status.under_project_control) {
            $blockers += "Dogbot audit artifact did not verify Project Control channel route."
        }
        $flagged = @($dogbotAudit.review | Where-Object { $_.flagged_for_morning_review })
        if ($flagged.Count -gt 0) {
            $warnings += "Dogbot audit artifact has $($flagged.Count) flagged receipt(s) for review."
        }
    }
    catch {
        if ($RunDogbotAudit) {
            $dogbotAudit = $null
            $warnings += "Dogbot audit artifact parse failed, falling back to live audit: $($_.Exception.Message)"
        }
        else {
            $warnings += "Dogbot audit artifact parse failed: $($_.Exception.Message)"
        }
    }
}

if (-not $dogbotAudit -and $RunDogbotAudit) {
    Push-Location $repoRoot
    try {
        $auditOutput = & $python "scripts\dogbot-experiment-log.py" "audit" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dogbotAudit = ($auditOutput | Out-String | ConvertFrom-Json)
            if (-not $dogbotAudit.channel_status.under_project_control) {
                $blockers += "Dogbot audit did not verify Project Control channel route."
            }
            $flagged = @($dogbotAudit.review | Where-Object { $_.flagged_for_morning_review })
            if ($flagged.Count -gt 0) {
                $warnings += "Dogbot audit has $($flagged.Count) flagged receipt(s) for review."
            }
        }
        else {
            $warnings += "Dogbot live audit failed: $($auditOutput | Out-String)"
        }
    }
    finally {
        Pop-Location
    }
}
elseif (-not $dogbotAudit) {
    $warnings += "Dogbot live audit not run by demo-ready-check; use -RunDogbotAudit for live Discord read-back."
}

$morningAuditPath = Join-Path $workspaceRoot "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md"
$morningAuditExists = Test-Path $morningAuditPath
if (((Get-Date) -lt $stopAt -or $AllowPendingMorningAudit) -and -not $morningAuditExists) {
    $warnings += "Morning audit is pending until 10:00 AM."
}
elseif ((Get-Date) -ge $stopAt -and -not $morningAuditExists) {
    $blockers += "Morning audit is missing after stop time."
}

$status = if ($blockers.Count -gt 0) {
    "fail"
}
elseif ($warnings.Count -gt 0) {
    "warn"
}
else {
    "pass"
}

$result = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    status = $status
    web = $web
    backend_health = $backend
    live_ui_upload = if ($liveUi) {
        [ordered]@{
            ok = $liveUiOk
            image = $liveUi.image_filename
            model = $liveUi.observation.model_name
            confidence = $liveUi.observation.confidence
            no_treatment_advice = $liveUi.checks.no_treatment_advice
            screenshot = $liveUi.screenshot
        }
    } else { $null }
    live_model_smoke_ok = $liveModelOk
    live_model_diversity_ok = $liveDiversityOk
    visual_professionalism = if ($visualAudit) {
        [ordered]@{
            ok = $visualAuditOk
            status = $visualAudit.status
            verdict = $visualAudit.verdict
            screenshot_count = $visualAudit.screenshot_count
            failed_count = $visualAudit.failed_count
        }
    } else { $null }
    latency_demo = if ($latencyAudit) {
        [ordered]@{
            ok = $latencyAuditOk
            status = $latencyAudit.status
            max_model_latency_ms = $latencyAudit.max_model_latency_ms
            average_model_latency_ms = $latencyAudit.average_model_latency_ms
            max_service_latency_ms = $latencyAudit.max_service_latency_ms
            fallback = $latencyAudit.fallback
        }
    } else { $null }
    dogbot_auth = if ($dogbotAuth) {
        [ordered]@{
            status = $dogbotAuth.status
            candidate_count = $dogbotAuth.candidate_count
            selected = $dogbotAuth.selected
            blocker = $dogbotAuth.blocker
            candidates = $dogbotAuthCandidates
        }
    } else { $null }
    network_status = if ($network) { $network.status } else { $null }
    recommended_route = if ($network) { $network.recommended_demo_urls } else { $null }
    dogbot_manifest = $manifestSummary
    dogbot_pending_receipts = [ordered]@{
        count = $pendingReceiptRecords.Count
        path = "final_docs/overnight/dogbot-pending-receipts.jsonl"
        experiment_ids = @($pendingReceiptRecords | ForEach-Object { $_.experiment_id })
    }
    dogbot_live_audit = if ($dogbotAudit) {
        [ordered]@{
            under_project_control = $dogbotAudit.channel_status.under_project_control
            receipt_count = @($dogbotAudit.review).Count
            flagged_count = @($dogbotAudit.review | Where-Object { $_.flagged_for_morning_review }).Count
            source = if ($DogbotAuditPath -and (Test-Path $DogbotAuditPath)) { "artifact" } else { "live_api" }
        }
    } else { $null }
    morning_audit = [ordered]@{
        path = "docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md"
        exists = $morningAuditExists
        pending_until = $stopAt.ToString("o")
    }
    artifacts = $artifacts
    blockers = $blockers
    warnings = $warnings
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

Write-Output "report=$outPath"
Write-Output "status=$status"
Write-Output "blockers=$($blockers.Count)"
Write-Output "warnings=$($warnings.Count)"
Write-Output "dogbot_manifest_messages=$($manifestSummary.message_count)"
Write-Output "dogbot_pending_receipts=$($pendingReceiptRecords.Count)"
if ($liveUi) {
    Write-Output "live_ui_model=$($liveUi.observation.model_name)"
    Write-Output "live_ui_confidence=$($liveUi.observation.confidence)"
}
if ($visualAudit) {
    Write-Output "visual_status=$($visualAudit.status)"
    Write-Output "visual_failed=$($visualAudit.failed_count)"
}
if ($latencyAudit) {
    Write-Output "latency_status=$($latencyAudit.status)"
    Write-Output "max_model_latency_ms=$($latencyAudit.max_model_latency_ms)"
}
foreach ($warning in $warnings) {
    Write-Output "warning=$warning"
}
foreach ($blocker in $blockers) {
    Write-Output "blocker=$blocker"
}

if ($status -eq "fail") {
    exit 1
}
