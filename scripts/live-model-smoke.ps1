param(
    [string]$ImagePath = "data\verifier\captures\holdout\clear\holdout-00000-b3404b141d-clear.jpg",
    [string]$Out = "final_docs\overnight\live-model-smoke.json",
    [string]$Endpoint = "http://localhost:8787/api/scout/analyze",
    [string]$HealthUrl = "http://localhost:8787/health"
)

$ErrorActionPreference = "Stop"

$resolvedImage = Resolve-Path -LiteralPath $ImagePath
$bytes = [System.IO.File]::ReadAllBytes($resolvedImage.Path)
$dataUrl = "data:image/jpeg;base64," + [Convert]::ToBase64String($bytes)
$started = Get-Date

$payload = [ordered]@{
    observation_id = "live-smoke-holdout-00000-clear"
    worker_id = "worker-07"
    crop = "tomato"
    zone = "live-smoke"
    capture_source = "simulated_meta_dat_capture"
    upload_filename = "neutral-holdout-clear.jpg"
    upload_size_bytes = $bytes.Length
    upload_mime_type = "image/jpeg"
    report_channel = "typed_report_voice_stand_in"
    wearer_note = "tomato leaf observation, single front view"
    image_data_url = $dataUrl
}

$status = "pass"
$errorMessage = $null
$response = $null
try {
    $response = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 8) -TimeoutSec 240
}
catch {
    $status = "fail"
    $errorMessage = $_.Exception.Message
}

$ended = Get-Date
$health = $null
try {
    $health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 10
}
catch {
    $health = [ordered]@{ ok = $false; error = $_.Exception.Message }
}

$result = [ordered]@{
    generated_at = $ended.ToString("o")
    status = $status
    elapsed_ms = [int](($ended - $started).TotalMilliseconds)
    endpoint = $Endpoint
    provider_health = $health
    sample = [ordered]@{
        image_id = "holdout-00000-b3404b141d-clear"
        source_dataset = "PlantDoc"
        upload_filename = "neutral-holdout-clear.jpg"
        upload_size_bytes = $bytes.Length
        note = "original label intentionally omitted from request body"
    }
    error = $errorMessage
    observation = $response.observation
}

$outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$parent = Split-Path -Parent $outPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

if ($status -ne "pass") {
    throw "Live model smoke failed: $errorMessage"
}

$obs = $response.observation
if (-not $obs) {
    throw "Live model smoke did not return observation."
}
if ($obs.treatment_recommendation -ne $null) {
    throw "Live model smoke returned treatment_recommendation."
}
if (-not $obs.next_check -or -not $obs.possible_disease -or -not $obs.confidence) {
    throw "Live model smoke returned an incomplete DiseaseScoutObservation."
}

Write-Output "report=$outPath"
Write-Output "provider=$($health.provider)"
Write-Output "model=$($obs.model_name)"
Write-Output "elapsed_ms=$($result.elapsed_ms)"
