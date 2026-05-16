param(
    [string]$Out = "final_docs\overnight\latency-demo-audit.json",
    [string]$MarkdownOut = "final_docs\overnight\latency-demo-audit.md",
    [string]$WebUrl = "http://localhost:19006",
    [string]$BackendHealthUrl = "http://localhost:8787/health",
    [int]$SingleModelWarnMs = 20000,
    [int]$AverageModelWarnMs = 20000,
    [int]$ServiceWarnMs = 1000
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-RepoPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Path))
}

function Read-Json {
    param([string]$Path)
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path $resolved)) {
        return $null
    }
    return Get-Content -Raw $resolved | ConvertFrom-Json
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
            return [ordered]@{ ok = [bool]$body.ok; elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds); error = $null }
        }
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        return [ordered]@{ ok = ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400); elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds); error = $null }
    }
    catch {
        return [ordered]@{ ok = $false; elapsed_ms = [int](((Get-Date) - $started).TotalMilliseconds); error = $_.Exception.Message }
    }
}

$liveModel = Read-Json "final_docs\overnight\live-model-smoke.json"
$liveDiversity = Read-Json "final_docs\overnight\live-model-diversity-smoke.json"
$liveUi = Read-Json "final_docs\overnight\live-ui-upload-smoke.json"
$webCheck = Test-Http -Url $WebUrl
$backendCheck = Test-Http -Url $BackendHealthUrl -Json

$singleLatencies = @()
if ($liveModel -and $liveModel.elapsed_ms) {
    $singleLatencies += [ordered]@{ name = "live_model_smoke"; elapsed_ms = [int]$liveModel.elapsed_ms; source = "live-model-smoke.json" }
}
if ($liveUi -and $liveUi.observation -and $liveUi.observation.model_latency_ms) {
    $singleLatencies += [ordered]@{ name = "live_ui_upload"; elapsed_ms = [int]$liveUi.observation.model_latency_ms; source = "live-ui-upload-smoke.json" }
}
if ($liveDiversity -and $liveDiversity.samples) {
    foreach ($sample in @($liveDiversity.samples)) {
        if ($sample.elapsed_ms) {
            $singleLatencies += [ordered]@{ name = "diversity_$($sample.sample_id)"; elapsed_ms = [int]$sample.elapsed_ms; source = "live-model-diversity-smoke.json" }
        }
    }
}

$serviceLatencies = @()
$serviceLatencies += [ordered]@{ name = "web_status"; elapsed_ms = [int]$webCheck.elapsed_ms; ok = [bool]$webCheck.ok; source = $WebUrl }
$serviceLatencies += [ordered]@{ name = "backend_health"; elapsed_ms = [int]$backendCheck.elapsed_ms; ok = [bool]$backendCheck.ok; source = $BackendHealthUrl }

$maxModelMs = if ($singleLatencies.Count -gt 0) { [int](@($singleLatencies | ForEach-Object { $_.elapsed_ms } | Measure-Object -Maximum).Maximum) } else { $null }
$avgModelMs = if ($singleLatencies.Count -gt 0) { [int](@($singleLatencies | ForEach-Object { $_.elapsed_ms } | Measure-Object -Average).Average) } else { $null }
$maxServiceMs = if ($serviceLatencies.Count -gt 0) { [int](@($serviceLatencies | ForEach-Object { $_.elapsed_ms } | Measure-Object -Maximum).Maximum) } else { $null }

$warnings = @()
$blockers = @()
if ($singleLatencies.Count -eq 0) {
    $blockers += "No live model latency rows found."
}
if (-not $webCheck.ok) {
    $blockers += "Web status check failed during latency audit."
}
if (-not $backendCheck.ok) {
    $blockers += "Backend health check failed during latency audit."
}
if ($null -ne $maxModelMs -and $maxModelMs -gt $SingleModelWarnMs) {
    $warnings += "A single live model call exceeded ${SingleModelWarnMs}ms."
}
if ($null -ne $avgModelMs -and $avgModelMs -gt $AverageModelWarnMs) {
    $warnings += "Average live model latency exceeded ${AverageModelWarnMs}ms."
}
if ($null -ne $maxServiceMs -and $maxServiceMs -gt $ServiceWarnMs) {
    $warnings += "A local service health/page check exceeded ${ServiceWarnMs}ms."
}

$status = if ($blockers.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "warn" } else { "pass" }
$fallback = "If a live model call stalls during judging, show live-model-diversity-smoke.json, live-ui-upload-smoke.png, and demo-day-status.md first, then retry the live upload."

$result = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    status = $status
    max_model_latency_ms = $maxModelMs
    average_model_latency_ms = $avgModelMs
    max_service_latency_ms = $maxServiceMs
    model_latency_warn_threshold_ms = $SingleModelWarnMs
    average_latency_warn_threshold_ms = $AverageModelWarnMs
    service_latency_warn_threshold_ms = $ServiceWarnMs
    model_latencies = $singleLatencies
    service_latencies = $serviceLatencies
    fallback = $fallback
    blockers = $blockers
    warnings = $warnings
}

$outPath = Resolve-RepoPath $Out
$outParent = Split-Path -Parent $outPath
if ($outParent) {
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null
}
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

$modelRows = if ($singleLatencies.Count -gt 0) {
    $singleLatencies | ForEach-Object { "- $($_.name): $($_.elapsed_ms) ms from $($_.source)" }
}
else {
    @("- none")
}
$serviceRows = if ($serviceLatencies.Count -gt 0) {
    $serviceLatencies | ForEach-Object { "- $($_.name): $($_.elapsed_ms) ms from $($_.source)" }
}
else {
    @("- none")
}
$warningRows = if ($warnings.Count -gt 0) { $warnings | ForEach-Object { "- $_" } } else { @("- none") }
$blockerRows = if ($blockers.Count -gt 0) { $blockers | ForEach-Object { "- $_" } } else { @("- none") }

$markdown = @(
    "# Latency Demo Audit",
    "",
    "Generated: $($result.generated_at)",
    "Status: $($result.status)",
    "Max model latency: $($result.max_model_latency_ms) ms",
    "Average model latency: $($result.average_model_latency_ms) ms",
    "Max service latency: $($result.max_service_latency_ms) ms",
    "",
    "## Model Latencies",
    "",
    $modelRows,
    "",
    "## Service Latencies",
    "",
    $serviceRows,
    "",
    "## Demo Fallback",
    "",
    $fallback,
    "",
    "## Blockers",
    "",
    $blockerRows,
    "",
    "## Warnings",
    "",
    $warningRows
)

$mdPath = Resolve-RepoPath $MarkdownOut
$mdParent = Split-Path -Parent $mdPath
if ($mdParent) {
    New-Item -ItemType Directory -Force -Path $mdParent | Out-Null
}
$markdown | Set-Content -Path $mdPath -Encoding UTF8

Write-Output "report=$outPath"
Write-Output "markdown=$mdPath"
Write-Output "status=$status"
Write-Output "max_model_latency_ms=$maxModelMs"
Write-Output "average_model_latency_ms=$avgModelMs"
Write-Output "max_service_latency_ms=$maxServiceMs"
foreach ($warning in $warnings) {
    Write-Output "warning=$warning"
}
foreach ($blocker in $blockers) {
    Write-Output "blocker=$blocker"
}

if ($status -eq "fail") {
    exit 1
}
