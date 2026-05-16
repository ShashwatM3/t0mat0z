param(
    [string]$Out = "final_docs\overnight\live-model-diversity-smoke.json",
    [string]$Endpoint = "http://localhost:8787/api/scout/analyze",
    [string]$HealthUrl = "http://localhost:8787/health"
)

$ErrorActionPreference = "Stop"

$samples = @(
    [ordered]@{
        id = "diversity-spot-01"
        image_id = "holdout-00000-b3404b141d-clear"
        image_path = "data\verifier\captures\holdout\clear\holdout-00000-b3404b141d-clear.jpg"
        private_expected_bucket = "bacterial_or_leaf_spot"
    },
    [ordered]@{
        id = "diversity-healthy-01"
        image_id = "holdout-00040-e990d6c955-clear"
        image_path = "data\verifier\captures\holdout\clear\holdout-00040-e990d6c955-clear.jpg"
        private_expected_bucket = "healthy"
    },
    [ordered]@{
        id = "diversity-curl-01"
        image_id = "holdout-00097-39f8901f64-clear"
        image_path = "data\verifier\captures\holdout\clear\holdout-00097-39f8901f64-clear.jpg"
        private_expected_bucket = "yellow_leaf_curl_or_mosaic"
    }
)

function Invoke-Sample {
    param([hashtable]$Sample)

    $resolvedImage = Resolve-Path -LiteralPath $Sample.image_path
    $bytes = [System.IO.File]::ReadAllBytes($resolvedImage.Path)
    $dataUrl = "data:image/jpeg;base64," + [Convert]::ToBase64String($bytes)
    $started = Get-Date
    $payload = [ordered]@{
        observation_id = "live-diversity-$($Sample.id)"
        worker_id = "worker-07"
        crop = "tomato"
        zone = "live-diversity"
        capture_source = "simulated_meta_dat_capture"
        upload_filename = "$($Sample.id).jpg"
        upload_size_bytes = $bytes.Length
        upload_mime_type = "image/jpeg"
        report_channel = "typed_report_voice_stand_in"
        wearer_note = "tomato leaf observation, single front view"
        image_data_url = $dataUrl
    }

    $response = $null
    $errorMessage = $null
    try {
        $response = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 8) -TimeoutSec 240
    }
    catch {
        $errorMessage = $_.Exception.Message
    }
    $ended = Get-Date
    $obs = if ($response) { $response.observation } else { $null }

    $signatureObject = if ($obs) {
        [ordered]@{
            possible_disease = $obs.possible_disease
            confidence = $obs.confidence
            broad_state = $obs.broad_state
            visible_symptoms = @($obs.visible_symptoms)
            limitation_flags = @($obs.limitation_flags)
            next_check = $obs.next_check
        }
    }
    else {
        $null
    }

    [ordered]@{
        sample_id = $Sample.id
        image_id = $Sample.image_id
        private_expected_bucket = $Sample.private_expected_bucket
        request_sent_label = $false
        upload_filename = $payload.upload_filename
        upload_size_bytes = $bytes.Length
        elapsed_ms = [int](($ended - $started).TotalMilliseconds)
        ok = ($null -ne $obs -and $null -eq $errorMessage)
        error = $errorMessage
        observation = $obs
        response_signature = if ($signatureObject) { ($signatureObject | ConvertTo-Json -Compress -Depth 8) } else { $null }
    }
}

$startedAll = Get-Date
$health = $null
try {
    $health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 10
}
catch {
    $health = [ordered]@{ ok = $false; error = $_.Exception.Message }
}

$results = @()
foreach ($sample in $samples) {
    $results += Invoke-Sample -Sample $sample
}
$endedAll = Get-Date

$errors = @()
foreach ($result in $results) {
    if (-not $result.ok) {
        $errors += "$($result.sample_id): $($result.error)"
        continue
    }
    $obs = $result.observation
    if (-not $obs.possible_disease -or -not $obs.confidence -or -not $obs.next_check -or -not $obs.review_status) {
        $errors += "$($result.sample_id): incomplete DiseaseScoutObservation"
    }
    if ($obs.treatment_recommendation -ne $null) {
        $errors += "$($result.sample_id): treatment_recommendation was not null"
    }
}

$signatures = @($results | Where-Object { $_.response_signature } | ForEach-Object { $_.response_signature })
$uniqueSignatures = @($signatures | Sort-Object -Unique)
$possibleDiseases = @($results | Where-Object { $_.observation } | ForEach-Object { $_.observation.possible_disease } | Sort-Object -Unique)
$broadStates = @($results | Where-Object { $_.observation } | ForEach-Object { $_.observation.broad_state } | Sort-Object -Unique)
$treatmentAdviceCount = @($results | Where-Object { $_.observation -and $null -ne $_.observation.treatment_recommendation }).Count
$failedSampleCount = @($results | Where-Object { -not $_.ok }).Count

if ($results.Count -ge 2 -and $uniqueSignatures.Count -lt 2) {
    $errors += "all live model response signatures were identical across different images"
}

$status = if ($errors.Count -eq 0) { "pass" } else { "fail" }
$report = [ordered]@{
    generated_at = $endedAll.ToString("o")
    status = $status
    elapsed_ms = [int](($endedAll - $startedAll).TotalMilliseconds)
    endpoint = $Endpoint
    provider_health = $health
    sample_count = $samples.Count
    unique_response_signatures = $uniqueSignatures.Count
    unique_possible_diseases = $possibleDiseases.Count
    unique_broad_states = $broadStates.Count
    treatment_advice_count = $treatmentAdviceCount
    failed_sample_count = $failedSampleCount
    errors = $errors
    note = "Private expected buckets are used only in this local report; request payloads use neutral filenames and do not send original labels."
    samples = $results
}

$outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$parent = Split-Path -Parent $outPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$report | ConvertTo-Json -Depth 30 | Set-Content -Path $outPath -Encoding UTF8

Write-Output "report=$outPath"
Write-Output "status=$status"
Write-Output "provider=$($health.provider)"
Write-Output "samples=$($samples.Count)"
Write-Output "unique_response_signatures=$($uniqueSignatures.Count)"
Write-Output "unique_possible_diseases=$($possibleDiseases.Count)"
Write-Output "unique_broad_states=$($broadStates.Count)"
Write-Output "treatment_advice_count=$treatmentAdviceCount"
Write-Output "failed_sample_count=$failedSampleCount"
foreach ($errorMessage in $errors) {
    Write-Output "error=$errorMessage"
}

if ($status -ne "pass") {
    exit 1
}
