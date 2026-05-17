param(
    [string]$WatchPath = "$env:USERPROFILE\Pictures\DiseaseScoutIncoming",
    [string]$ApiUrl = "http://localhost:8787/api/scout/analyze",
    [string]$OutDir = "final_docs\auto-import",
    [string]$Crop = "tomato",
    [string]$Zone = "Zone B",
    [string]$WorkerId = "worker-07",
    [string]$WearerNote = "automated glasses or phone photo import",
    [ValidateSet("live", "local-fast")]
    [string]$Provider = "live",
    [int]$IntervalSeconds = 2,
    [switch]$Watch,
    [switch]$SpeakResult
)

$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location) $Path
}

function Get-MimeType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".png" { return "image/png" }
        ".webp" { return "image/webp" }
        default { return "image/jpeg" }
    }
}

function Wait-FileStable {
    param(
        [string]$Path,
        [int]$Checks = 3,
        [int]$DelayMilliseconds = 500
    )

    $lastLength = -1
    for ($i = 0; $i -lt $Checks; $i++) {
        $item = Get-Item -LiteralPath $Path
        if ($item.Length -eq $lastLength -and $item.Length -gt 0) {
            return
        }

        $lastLength = $item.Length
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

function Get-ResultSentence {
    param($Observation)

    $disease = $Observation.possible_disease
    $confidence = $Observation.confidence
    $next = $Observation.next_check

    if ([string]::IsNullOrWhiteSpace($disease)) {
        $disease = "not enough evidence"
    }
    if ([string]::IsNullOrWhiteSpace($confidence)) {
        $confidence = "unknown"
    }
    if ([string]::IsNullOrWhiteSpace($next)) {
        $next = "capture a clearer close-up for supervisor review"
    }

    return "Disease Scout: $disease. Confidence $confidence. Next check: $next"
}

function Get-ImageFeatures {
    param([string]$Path)

    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::FromFile($Path)
    try {
        $stepX = [Math]::Max(1, [int]($bitmap.Width / 72))
        $stepY = [Math]::Max(1, [int]($bitmap.Height / 72))
        $total = 0
        $saturated = 0
        $greenDominant = 0
        $yellow = 0
        $dark = 0
        $brightnessSum = 0.0

        for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
            for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
                $pixel = $bitmap.GetPixel($x, $y)
                $r = [int]$pixel.R
                $g = [int]$pixel.G
                $b = [int]$pixel.B
                $max = [Math]::Max($r, [Math]::Max($g, $b))
                $min = [Math]::Min($r, [Math]::Min($g, $b))
                $brightness = ($r + $g + $b) / 3.0
                $total += 1
                $brightnessSum += $brightness
                if (($max - $min) -gt 28) { $saturated += 1 }
                if (($g -gt ($r + 8)) -and ($g -gt ($b + 12))) { $greenDominant += 1 }
                if (($r -gt 100) -and ($g -gt 88) -and ($b -lt 105) -and ([Math]::Abs($r - $g) -lt 85)) { $yellow += 1 }
                if (($brightness -lt 82) -and (($max - $min) -gt 18)) { $dark += 1 }
            }
        }

        return [pscustomobject]@{
            width = $bitmap.Width
            height = $bitmap.Height
            foreground_ratio = if ($total) { $saturated / $total } else { 0 }
            green_ratio = if ($total) { $greenDominant / $total } else { 0 }
            yellow_ratio = if ($total) { $yellow / $total } else { 0 }
            dark_ratio = if ($total) { $dark / $total } else { 0 }
            mean_brightness = if ($total) { $brightnessSum / $total } else { 0 }
        }
    } finally {
        $bitmap.Dispose()
    }
}

function New-LocalFastObservation {
    param(
        [string]$ImagePath,
        [string]$ObservationId,
        [string]$UploadFilename,
        [int]$UploadSizeBytes,
        [string]$MimeType
    )

    $features = Get-ImageFeatures -Path $ImagePath
    $poorEvidence = ($features.foreground_ratio -lt 0.10) -or ($features.mean_brightness -lt 62)
    $suspicious = ($features.yellow_ratio -gt 0.12) -or ($features.dark_ratio -gt 0.035) -or (($features.green_ratio -lt 0.18) -and ($features.foreground_ratio -gt 0.12))

    if ($poorEvidence) {
        $possibleDisease = "not enough evidence to identify"
        $confidence = "low"
        $limitationFlags = @("too_far", "lighting_issue", "single_view_only")
        $evidenceQuality = "Automated import produced weak image evidence; the leaf appears too small, dark, or low contrast for a confident disease triage."
        $nextCheck = "Move closer and capture the affected leaf plus one nearby healthy comparison leaf."
        $reviewStatus = "recapture_needed"
        $broadState = "not_enough_evidence"
        $visibleSymptoms = @("weak visual evidence")
    } elseif ($suspicious) {
        $possibleDisease = "possible disease or stress signal"
        $confidence = "medium"
        $limitationFlags = @("single_view_only", "no_healthy_comparison", "model_uncertain")
        $evidenceQuality = "Automated image triage found color or dark-spot patterns that need a closer disease review."
        $nextCheck = "Capture the underside of the affected leaf and one neighboring healthy comparison plant."
        $reviewStatus = "supervisor_review"
        $broadState = "disease_like"
        $visibleSymptoms = @("color variation", "possible spotting or stress pattern")
    } else {
        $possibleDisease = "no visible disease concern"
        $confidence = "medium"
        $limitationFlags = @("single_view_only")
        $evidenceQuality = "Automated image triage found a usable single-view baseline with no strong disease-like color or spot signal."
        $nextCheck = "Keep this as a comparison record and recapture if symptoms appear nearby."
        $reviewStatus = "clear"
        $broadState = "healthy_or_low_concern"
        $visibleSymptoms = @("no strong disease-like signal")
    }

    return [pscustomobject]@{
        observation = [ordered]@{
            observation_id = $ObservationId
            worker_id = $WorkerId
            crop = $Crop
            zone = $Zone
            image_uri = "auto-import://$UploadFilename"
            capture_source = "automated_import_watch"
            upload_filename = $UploadFilename
            upload_size_bytes = $UploadSizeBytes
            upload_mime_type = $MimeType
            report_channel = "automated_import_watch"
            wearer_note = $WearerNote
            possible_disease = $possibleDisease
            confidence = $confidence
            limitation_flags = $limitationFlags
            evidence_quality = $evidenceQuality
            next_check = $nextCheck
            supervisor_action = "Use this as fast triage only; review the saved image and request the next check before diagnosis."
            review_status = $reviewStatus
            treatment_recommendation = $null
            finding_why = "Local fast triage used image color/contrast features from the imported photo, not a final disease model."
            broad_state = $broadState
            visible_symptoms = $visibleSymptoms
            send_status = "not_sent_demo_only"
            analysis_source = "local_fast_pixel_baseline"
            model_name = "local-fast:auto-import-watch"
            model_latency_ms = 0
            baseline_features = $features
        }
    }
}

function Invoke-DiseaseScoutImport {
    param(
        [string]$ImagePath,
        [string]$ResolvedOutDir
    )

    Wait-FileStable -Path $ImagePath

    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $mime = Get-MimeType -Path $ImagePath
    $dataUrl = "data:$mime;base64,$([Convert]::ToBase64String($bytes))"
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ImagePath)
    $safeBase = ($baseName -replace '[^a-zA-Z0-9_.-]', '-')
    $observationId = "auto-import-$stamp-$safeBase"

    $payload = [ordered]@{
        observation_id = $observationId
        worker_id = $WorkerId
        crop = $Crop
        zone = $Zone
        capture_source = "automated_import_watch"
        upload_filename = [System.IO.Path]::GetFileName($ImagePath)
        upload_size_bytes = $bytes.Length
        upload_mime_type = $mime
        report_channel = "automated_import_watch"
        wearer_note = $WearerNote
        image_data_url = $dataUrl
    }

    $started = Get-Date
    if ($Provider -eq "local-fast") {
        $response = New-LocalFastObservation -ImagePath $ImagePath -ObservationId $observationId -UploadFilename ([System.IO.Path]::GetFileName($ImagePath)) -UploadSizeBytes $bytes.Length -MimeType $mime
    } else {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 12) -TimeoutSec 180
    }
    $elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
    $response.observation.model_latency_ms = $elapsedMs

    if (-not (Test-Path -LiteralPath $ResolvedOutDir)) {
        New-Item -ItemType Directory -Path $ResolvedOutDir | Out-Null
    }

    $resultPath = Join-Path $ResolvedOutDir "$stamp-$safeBase.result.json"
    $summaryPath = Join-Path $ResolvedOutDir "$stamp-$safeBase.summary.txt"
    $receiptPath = Join-Path $ResolvedOutDir "auto-import-receipts.jsonl"
    $sentence = Get-ResultSentence -Observation $response.observation

    $record = [ordered]@{
        generated_at = (Get-Date).ToString("o")
        image_path = $ImagePath
        api_url = $ApiUrl
        provider = $Provider
        elapsed_ms = $elapsedMs
        result_path = $resultPath
        summary_path = $summaryPath
        spoken = [bool]$SpeakResult
        sentence = $sentence
        response = $response
    }

    $record | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    $sentence | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    ($record | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $receiptPath -Encoding UTF8

    if ($SpeakResult) {
        try {
            $voice = New-Object -ComObject SAPI.SpVoice
            [void]$voice.Speak($sentence, 1)
        } catch {
            Write-Warning "Could not speak result through SAPI: $($_.Exception.Message)"
        }
    }

    [pscustomobject]@{
        Status = "pass"
        ImagePath = $ImagePath
        ElapsedMs = $elapsedMs
        ResultPath = $resultPath
        SummaryPath = $summaryPath
        Sentence = $sentence
    }
}

$resolvedWatchPath = Resolve-RepoPath -Path $WatchPath
$resolvedOutDir = Resolve-RepoPath -Path $OutDir
$extensions = @("*.jpg", "*.jpeg", "*.png", "*.webp")
$processed = New-Object 'System.Collections.Generic.HashSet[string]'

if (-not (Test-Path -LiteralPath $resolvedWatchPath)) {
    New-Item -ItemType Directory -Path $resolvedWatchPath | Out-Null
}

Write-Host "watch_path=$resolvedWatchPath"
Write-Host "api_url=$ApiUrl"
Write-Host "out_dir=$resolvedOutDir"
Write-Host "provider=$Provider"
Write-Host "mode=$(if ($Watch) { 'watch' } else { 'once' })"

while ($true) {
    $candidates = foreach ($extension in $extensions) {
        Get-ChildItem -LiteralPath $resolvedWatchPath -Filter $extension -File -ErrorAction SilentlyContinue
    }

    $next = $candidates |
        Where-Object { -not $processed.Contains($_.FullName) } |
        Sort-Object LastWriteTimeUtc |
        Select-Object -First 1

    if ($null -ne $next) {
        $processed.Add($next.FullName) | Out-Null
        try {
            Invoke-DiseaseScoutImport -ImagePath $next.FullName -ResolvedOutDir $resolvedOutDir | Format-List
        } catch {
            Write-Error "auto_import_failed image=$($next.FullName) error=$($_.Exception.Message)"
            if (-not $Watch) {
                exit 1
            }
        }
    } elseif (-not $Watch) {
        Write-Host "no_new_images=true"
        Write-Host "Drop a .jpg, .jpeg, .png, or .webp into $resolvedWatchPath and rerun, or use -Watch."
        break
    }

    if (-not $Watch) {
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}
