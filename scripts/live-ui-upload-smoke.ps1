param(
    [string]$ImagePath = (Join-Path $env:USERPROFILE "Downloads\DiseaseScout-Test-Images-20260516-000304\blind_upload_images\disease_scout_blind_09.jpg"),
    [string]$ReportText = "yellowing and spots on lower leaves",
    [string]$WebUrl = "http://localhost:19006",
    [string]$Out = "final_docs\overnight\live-ui-upload-smoke.json",
    [string]$Screenshot = "final_docs\overnight\live-ui-upload-smoke.png"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ImagePath)) {
    throw "ImagePath not found: $ImagePath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$appRoot = Join-Path $repoRoot "app"
$outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Out))
$screenshotPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Screenshot))
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $screenshotPath) | Out-Null

$backend = Invoke-RestMethod -Uri "http://localhost:8787/health" -TimeoutSec 10
if (-not $backend.ok) {
    throw "Backend /health did not return ok=true."
}

$web = Invoke-WebRequest -Uri $WebUrl -UseBasicParsing -TimeoutSec 10
if ([int]$web.StatusCode -lt 200 -or [int]$web.StatusCode -ge 400) {
    throw "Web URL returned HTTP $($web.StatusCode)."
}

$oldImage = [Environment]::GetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_IMAGE", "Process")
$oldReport = [Environment]::GetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_REPORT", "Process")
$oldOut = [Environment]::GetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_OUT", "Process")
$oldScreenshot = [Environment]::GetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_SCREENSHOT", "Process")
$oldWeb = [Environment]::GetEnvironmentVariable("DISEASE_SCOUT_WEB_URL", "Process")

try {
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_IMAGE", (Resolve-Path $ImagePath).Path, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_REPORT", $ReportText, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_OUT", $outPath, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_SCREENSHOT", $screenshotPath, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_WEB_URL", $WebUrl, "Process")

    Push-Location $appRoot
    try {
        $output = & npx.cmd playwright test tests/e2e/disease-scout.live-upload.spec.js --reporter=list 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    }
    finally {
        Pop-Location
    }
}
finally {
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_IMAGE", $oldImage, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_REPORT", $oldReport, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_OUT", $oldOut, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_LIVE_UI_UPLOAD_SCREENSHOT", $oldScreenshot, "Process")
    [Environment]::SetEnvironmentVariable("DISEASE_SCOUT_WEB_URL", $oldWeb, "Process")
}

$output | ForEach-Object { Write-Output $_ }
if ($exitCode -ne 0) {
    exit $exitCode
}

if (-not (Test-Path $outPath)) {
    throw "Expected report was not written: $outPath"
}
if (-not (Test-Path $screenshotPath)) {
    throw "Expected screenshot was not written: $screenshotPath"
}

$report = Get-Content -Raw $outPath | ConvertFrom-Json
if ($report.status -ne "pass") {
    throw "Live UI upload report did not pass."
}
if (-not $report.checks.browser_upload_reached_backend -or -not $report.checks.no_treatment_advice) {
    throw "Live UI upload checks did not pass."
}

Write-Output "report=$outPath"
Write-Output "screenshot=$screenshotPath"
Write-Output "provider=$($backend.provider)"
Write-Output "model=$($report.observation.model_name)"
Write-Output "possible_disease=$($report.observation.possible_disease)"
Write-Output "confidence=$($report.observation.confidence)"
