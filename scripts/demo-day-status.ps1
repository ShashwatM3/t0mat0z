param(
    [string]$Out = "final_docs\overnight\demo-day-status.md",
    [string]$JsonOut = "final_docs\overnight\demo-day-status.json",
    [string]$WebUrl = "http://localhost:19006",
    [string]$BackendHealthUrl = "http://localhost:8787/health"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceRoot = (Resolve-Path (Join-Path $repoRoot "..\..")).Path

function Resolve-RepoPath {
    param([string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RelativePath)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $RelativePath))
}

function Read-JsonFile {
    param([string]$RelativePath)
    $path = Resolve-RepoPath $RelativePath
    if (-not (Test-Path $path)) { return $null }
    return Get-Content -Raw $path | ConvertFrom-Json
}

function Test-Http {
    param(
        [string]$Url,
        [switch]$Json
    )

    $started = Get-Date
    try {
        if ($Json) {
            $body = Invoke-RestMethod -Uri $Url -TimeoutSec 10
            return [ordered]@{
                ok = [bool]$body.ok
                url = $Url
                elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds)
                provider = $body.provider
                model = if ($body.codex_model) { $body.codex_model } else { $body.api_model }
                error = $null
            }
        }

        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        return [ordered]@{
            ok = ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400)
            url = $Url
            status_code = [int]$response.StatusCode
            length = [int64]$response.RawContentLength
            elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds)
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

function File-Row {
    param(
        [string]$Label,
        [string]$Path,
        [switch]$Workspace
    )

    $fullPath = if ($Workspace) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $workspaceRoot $Path))
    }
    else {
        Resolve-RepoPath $Path
    }
    $item = Get-Item -LiteralPath $fullPath -ErrorAction SilentlyContinue
    return [ordered]@{
        label = $Label
        path = $Path.Replace("\", "/")
        exists = [bool]$item
        size_bytes = if ($item) { [int64]$item.Length } else { $null }
        last_write_time = if ($item) { $item.LastWriteTime.ToString("o") } else { $null }
    }
}

$demoReady = Read-JsonFile "final_docs\overnight\demo-ready-check.json"
$network = Read-JsonFile "final_docs\overnight\network-preflight-latest.json"
$diversity = Read-JsonFile "final_docs\overnight\live-model-diversity-smoke.json"
$liveModel = Read-JsonFile "final_docs\overnight\live-model-smoke.json"
$liveUi = Read-JsonFile "final_docs\overnight\live-ui-upload-smoke.json"
$visualAudit = Read-JsonFile "final_docs\overnight\visual-professionalism-audit.json"
$latencyAudit = Read-JsonFile "final_docs\overnight\latency-demo-audit.json"
$dogbotAuth = Read-JsonFile "final_docs\overnight\dogbot-auth-status.json"
$heartbeat = Read-JsonFile "final_docs\overnight\overnight-heartbeat.json"
$dogbotAudit = Read-JsonFile "final_docs\overnight\dogbot-reaction-audit.json"
$morningAuditPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $workspaceRoot "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md"))
$morningAuditExists = Test-Path $morningAuditPath

$web = Test-Http -Url $WebUrl
$backend = Test-Http -Url $BackendHealthUrl -Json

$files = @(
    File-Row -Label "Operator card" -Path "final_docs\overnight\demo-operator-card.md"
    File-Row -Label "Proof packet" -Path "final_docs\overnight\demo-day-proof-packet.md"
    File-Row -Label "Demo ready JSON" -Path "final_docs\overnight\demo-ready-check.json"
    File-Row -Label "Morning audit" -Path "docs\goals\disease-scout-overnight-experiment-control\notes\morning-audit.md" -Workspace
    File-Row -Label "Live UI screenshot" -Path "final_docs\overnight\live-ui-upload-smoke.png"
    File-Row -Label "Display screenshot" -Path "final_docs\overnight\baseline-display-600.png"
    File-Row -Label "Visual audit" -Path "final_docs\overnight\visual-professionalism-audit.md"
    File-Row -Label "Latency audit" -Path "final_docs\overnight\latency-demo-audit.md"
    File-Row -Label "Dogbot auth repair" -Path "final_docs\overnight\dogbot-auth-repair.md"
    File-Row -Label "FieldBot invite launcher" -Path "final_docs\overnight\open-fieldbot-hackathon-invite.cmd"
    File-Row -Label "Dogbot pending queue" -Path "final_docs\overnight\dogbot-pending-receipts.jsonl"
    File-Row -Label "DAT checklist" -Path "final_docs\android-dat-checklist.md"
)

$pendingReceiptPath = Resolve-RepoPath "final_docs\overnight\dogbot-pending-receipts.jsonl"
$pendingReceiptRecords = @()
if (Test-Path $pendingReceiptPath) {
    try {
        $pendingReceiptRecords = @(Get-Content -LiteralPath $pendingReceiptPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    }
    catch {
        $pendingReceiptRecords = @()
    }
}

$blockers = @()
if (-not $web.ok) { $blockers += "Web simulator is not reachable." }
if (-not $backend.ok) { $blockers += "Backend health is not ok." }
if ($demoReady -and @($demoReady.blockers).Count -gt 0) {
    $blockers += @($demoReady.blockers | Where-Object { $_ -notmatch '^Dogbot pending receipt queue has ' })
}
if (-not $demoReady) { $blockers += "demo-ready-check.json is missing." }
if ($pendingReceiptRecords.Count -gt 0) {
    $blockers += "Dogbot pending receipt queue has $($pendingReceiptRecords.Count) unflushed local receipt(s)."
}

$warnings = @()
if ($demoReady) {
    $warnings += @($demoReady.warnings | Where-Object {
        -not ($morningAuditExists -and ($_ -match 'Morning audit'))
    })
}
$allowedHeartbeatStatuses = @("running", "auditing", "audit_complete")
if ($heartbeat -and ($allowedHeartbeatStatuses -notcontains $heartbeat.status)) {
    $warnings += "Overnight heartbeat status is $($heartbeat.status)."
}
if ($visualAudit -and $visualAudit.status -eq "fail") {
    $blockers += "Visual professionalism audit is failing."
}
elseif (-not $visualAudit) {
    $blockers += "Visual professionalism audit is missing."
}
if ($latencyAudit -and $latencyAudit.status -eq "fail") {
    $blockers += "Latency demo audit is failing."
}
elseif ($latencyAudit -and $latencyAudit.status -eq "warn") {
    $warnings += "Latency demo audit has warnings."
}
elseif (-not $latencyAudit) {
    $blockers += "Latency demo audit is missing."
}
if ($dogbotAuth -and $dogbotAuth.status -eq "blocked" -and -not (@($blockers) -match 'Dogbot live auth')) {
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

$result = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    status = if ($blockers.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "warn" } else { "pass" }
    web = $web
    backend = $backend
    heartbeat = if ($heartbeat) {
        [ordered]@{ status = $heartbeat.status; pid = $heartbeat.pid; now = $heartbeat.now; stop_at = $heartbeat.stop_at }
    } else { $null }
    morning_audit = [ordered]@{
        exists = $morningAuditExists
        path = "docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md"
    }
    demo_ready = if ($demoReady) {
        [ordered]@{
            status = $demoReady.status
            blockers = @($demoReady.blockers).Count
            warnings = @($demoReady.warnings).Count
            dogbot_receipts = $demoReady.dogbot_live_audit.receipt_count
            dogbot_flagged = $demoReady.dogbot_live_audit.flagged_count
            dogbot_source = $demoReady.dogbot_live_audit.source
            dogbot_pending = $pendingReceiptRecords.Count
        }
    } else { $null }
    dogbot_pending_receipts = [ordered]@{
        count = $pendingReceiptRecords.Count
        path = "final_docs/overnight/dogbot-pending-receipts.jsonl"
        experiment_ids = @($pendingReceiptRecords | ForEach-Object { $_.experiment_id })
    }
    network = if ($network) {
        [ordered]@{
            status = $network.status
            route_type = $network.recommended_demo_urls.route_type
            recommended_api = $network.recommended_demo_urls.expo_public_disease_scout_api_url
            warnings = @($network.warnings).Count
        }
    } else { $null }
    live_model = if ($liveModel) {
        [ordered]@{ status = $liveModel.status; model = $liveModel.observation.model_name; confidence = $liveModel.observation.confidence; treatment = $liveModel.observation.treatment_recommendation }
    } else { $null }
    live_diversity = if ($diversity) {
        [ordered]@{
            status = $diversity.status
            samples = $diversity.sample_count
            unique_response_signatures = $diversity.unique_response_signatures
            unique_possible_diseases = $diversity.unique_possible_diseases
            unique_broad_states = $diversity.unique_broad_states
            treatment_advice_count = $diversity.treatment_advice_count
            failed_sample_count = $diversity.failed_sample_count
        }
    } else { $null }
    live_ui = if ($liveUi) {
        [ordered]@{ status = $liveUi.status; image = $liveUi.image_filename; model = $liveUi.observation.model_name; confidence = $liveUi.observation.confidence; screenshot = $liveUi.screenshot }
    } else { $null }
    visual_professionalism = if ($visualAudit) {
        [ordered]@{ status = $visualAudit.status; verdict = $visualAudit.verdict; screenshots = $visualAudit.screenshot_count; failed = $visualAudit.failed_count }
    } else { $null }
    latency_demo = if ($latencyAudit) {
        [ordered]@{ status = $latencyAudit.status; max_model_latency_ms = $latencyAudit.max_model_latency_ms; average_model_latency_ms = $latencyAudit.average_model_latency_ms; max_service_latency_ms = $latencyAudit.max_service_latency_ms; fallback = $latencyAudit.fallback }
    } else { $null }
    dogbot_auth = if ($dogbotAuth) {
        [ordered]@{ status = $dogbotAuth.status; candidate_count = $dogbotAuth.candidate_count; selected = $dogbotAuth.selected; blocker = $dogbotAuth.blocker; candidates = $dogbotAuthCandidates }
    } else { $null }
    dogbot_audit = if ($dogbotAudit) {
        [ordered]@{ under_project_control = $dogbotAudit.channel_status.under_project_control; receipts = @($dogbotAudit.review).Count; flagged = @($dogbotAudit.review | Where-Object { $_.flagged_for_morning_review }).Count }
    } else { $null }
    files = $files
    blockers = $blockers
    warnings = $warnings
}

$jsonPath = Resolve-RepoPath $JsonOut
$jsonParent = Split-Path -Parent $jsonPath
if ($jsonParent) { New-Item -ItemType Directory -Force -Path $jsonParent | Out-Null }
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $jsonPath -Encoding UTF8

$fileRows = $files | ForEach-Object {
    $state = if ($_.exists) { "present" } else { "missing" }
    "- $($_.label): $state - ``$($_.path)``"
}

$blockerRows = if ($blockers.Count -gt 0) { $blockers | ForEach-Object { "- $_" } } else { @("- none") }
$warningRows = if ($warnings.Count -gt 0) { $warnings | ForEach-Object { "- $_" } } else { @("- none") }

$markdown = @(
    "# Demo Day Status: Disease Scout Memory",
    "",
    "Generated: $($result.generated_at)",
    "Status: $($result.status)",
    "",
    "## Open First",
    "",
    "1. Web simulator: ``$WebUrl``",
    "2. Operator card: ``final_docs/overnight/demo-operator-card.md``",
    "3. Proof packet: ``final_docs/overnight/demo-day-proof-packet.md``",
    "4. Demo ready JSON: ``final_docs/overnight/demo-ready-check.json``",
    "5. Morning audit after 10:00: ``docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md``",
    "6. Dogbot Project Control: Discord ``#dogbot``",
    "",
    "## Live Services",
    "",
    "- Web: ok=$($web.ok), url=$($web.url), length=$($web.length)",
    "- Backend: ok=$($backend.ok), provider=$($backend.provider), model=$($backend.model)",
    "- Heartbeat: status=$($result.heartbeat.status), pid=$($result.heartbeat.pid), stop_at=$($result.heartbeat.stop_at)",
    "- Morning audit: exists=$($result.morning_audit.exists), path=$($result.morning_audit.path)",
    "",
    "## Proof Summary",
    "",
    "- Demo ready: status=$($result.demo_ready.status), blockers=$($result.demo_ready.blockers), warnings=$($result.demo_ready.warnings)",
    "- Dogbot: receipts=$($result.demo_ready.dogbot_receipts), flagged=$($result.demo_ready.dogbot_flagged), pending=$($result.demo_ready.dogbot_pending), source=$($result.demo_ready.dogbot_source)",
    "- Network: status=$($result.network.status), route=$($result.network.route_type), recommended_api=$($result.network.recommended_api)",
    "- Live model: status=$($result.live_model.status), model=$($result.live_model.model), confidence=$($result.live_model.confidence), treatment=$($result.live_model.treatment)",
    "- Diversity: status=$($result.live_diversity.status), samples=$($result.live_diversity.samples), unique_signatures=$($result.live_diversity.unique_response_signatures), treatment_advice_count=$($result.live_diversity.treatment_advice_count), failed_sample_count=$($result.live_diversity.failed_sample_count)",
    "- Live UI: status=$($result.live_ui.status), image=$($result.live_ui.image), model=$($result.live_ui.model), screenshot=$($result.live_ui.screenshot)",
    "- Visual audit: status=$($result.visual_professionalism.status), verdict=$($result.visual_professionalism.verdict), screenshots=$($result.visual_professionalism.screenshots), failed=$($result.visual_professionalism.failed)",
    "- Latency audit: status=$($result.latency_demo.status), max_model=$($result.latency_demo.max_model_latency_ms) ms, average_model=$($result.latency_demo.average_model_latency_ms) ms, fallback=$($result.latency_demo.fallback)",
    "- Dogbot auth: status=$($result.dogbot_auth.status), selected=$($result.dogbot_auth.selected), blocker=$($result.dogbot_auth.blocker)",
    "- Dogbot target guild visible: $((@($result.dogbot_auth.candidates | Where-Object { $_.target_guild_visible })).Count -gt 0)",
    "",
    "## Required Files",
    "",
    $fileRows,
    "",
    "## Blockers",
    "",
    $blockerRows,
    "",
    "## Warnings",
    "",
    $warningRows,
    "",
    "## Demo Claim Boundary",
    "",
    "- Say: hands-free evidence memory, conservative possible disease or stress, missing evidence, next check, supervisor packet.",
    "- Do not say: final diagnosis, pesticide/treatment recommendation, completed native DAT app, venue Wi-Fi route proven."
)

$mdPath = Resolve-RepoPath $Out
$mdParent = Split-Path -Parent $mdPath
if ($mdParent) { New-Item -ItemType Directory -Force -Path $mdParent | Out-Null }
$markdown | Set-Content -Path $mdPath -Encoding UTF8

Write-Output "status=$($result.status)"
Write-Output "markdown=$mdPath"
Write-Output "json=$jsonPath"
Write-Output "blockers=$($blockers.Count)"
Write-Output "warnings=$($warnings.Count)"
Write-Output "dogbot_receipts=$($result.demo_ready.dogbot_receipts)"

if ($blockers.Count -gt 0) {
    exit 1
}
