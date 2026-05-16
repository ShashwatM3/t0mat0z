param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$Out
)

$ErrorActionPreference = 'Stop'

function Read-Jsonl {
    param([Parameter(Mandatory = $true)][string]$Path)
    $rows = New-Object System.Collections.Generic.List[object]
    $lineNumber = 0
    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $lineNumber += 1
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $rows.Add(($line | ConvertFrom-Json))
        } catch {
            throw "${Path}:$lineNumber invalid JSONL: $($_.Exception.Message)"
        }
    }
    return $rows
}

function Write-Jsonl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object[]]$Rows
    )
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $lines = foreach ($row in $Rows) {
        $row | ConvertTo-Json -Compress -Depth 10
    }
    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

function Get-ImageFeatures {
    param([Parameter(Mandatory = $true)][string]$Path)

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

function New-Prediction {
    param([Parameter(Mandatory = $true)][object]$Row)

    $features = Get-ImageFeatures -Path $Row.image_path
    $poorEvidence = ($features.foreground_ratio -lt 0.10) -or ($features.mean_brightness -lt 62)
    $suspicious = ($features.yellow_ratio -gt 0.12) -or ($features.dark_ratio -gt 0.035) -or (($features.green_ratio -lt 0.18) -and ($features.foreground_ratio -gt 0.12))

    if ($poorEvidence) {
        $possibleDisease = 'not enough evidence to identify'
        $confidence = 'low'
        $limitationFlags = @('too_far', 'poor_contrast', 'single_view_only')
        $evidenceQuality = 'image evidence is weak; leaf occupies too little of the usable frame or contrast is too low'
        $nextCheck = 'Move closer, steady the view, and capture the affected leaf plus a nearby normal leaf.'
        $reviewStatus = 'recapture_needed'
    } elseif ($suspicious) {
        $possibleDisease = 'possible disease or stress signal'
        $confidence = 'medium'
        $limitationFlags = @('single_view_only', 'no_healthy_comparison')
        $evidenceQuality = 'single-view image contains color or spot patterns that should be reviewed'
        $nextCheck = 'Capture the underside of the affected leaf and one neighboring healthy comparison plant.'
        $reviewStatus = 'supervisor_review'
    } else {
        $possibleDisease = 'no visible disease concern'
        $confidence = 'medium'
        $limitationFlags = @('single_view_only')
        $evidenceQuality = 'single-view image is usable as a baseline comparison'
        $nextCheck = 'Use this as a comparison record and inspect neighboring plants if symptoms appear.'
        $reviewStatus = 'clear'
    }

    return [pscustomobject]@{
        image_id = $Row.image_id
        worker_id = $Row.worker_id
        crop = $Row.crop
        zone = $Row.zone
        capture_source = $Row.capture_source
        report_channel = $Row.report_channel
        wearer_note = $Row.wearer_note
        possible_disease = $possibleDisease
        confidence = $confidence
        limitation_flags = $limitationFlags
        evidence_quality = $evidenceQuality
        next_check = $nextCheck
        review_status = $reviewStatus
        treatment_recommendation = $null
        baseline_features = $features
    }
}

$rows = Read-Jsonl -Path $InputPath
$predictions = New-Object System.Collections.Generic.List[object]

foreach ($row in $rows) {
    $allowedNames = @($row.PSObject.Properties.Name)
    $forbidden = @('bucket', 'original_label', 'original_path', 'capture_quality', 'expected_limitation_flags', 'source_image_id') |
        Where-Object { $allowedNames -contains $_ }
    if ($forbidden.Count -gt 0) {
        throw "prediction input contains hidden fields: $($forbidden -join ', ')"
    }
    if (-not (Test-Path -LiteralPath $row.image_path)) {
        throw "image not found: $($row.image_path)"
    }
    $predictions.Add((New-Prediction -Row $row))
}

Write-Jsonl -Path $Out -Rows $predictions.ToArray()
"predictions=$($predictions.Count) output=$Out"
