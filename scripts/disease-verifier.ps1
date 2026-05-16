param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Stage', 'Simulate', 'ExportInput', 'Score')]
    [string]$Command,

    [string]$Root,
    [string]$Manifest,
    [string]$Predictions,
    [string]$Out = 'data\verifier',
    [string]$SourceName = 'unknown',
    [string]$SourceUrl = '',
    [string]$Split = 'dev',
    [int]$MaxPerBucket = 40,
    [int]$Seed = 17,
    [string]$WorkerId = 'worker-07',
    [string]$Crop = 'tomato',
    [string]$Zone = 'dataset-holdout',
    [ValidateSet('Constant', 'Bucket')]
    [string]$ReportMode = 'Constant',
    [string]$ReportText = 'tomato leaf observation',
    [int]$MaxFailures = 40
)

$ErrorActionPreference = 'Stop'
$ImageExtensions = @('.jpg', '.jpeg', '.png', '.webp', '.bmp')
$AllowedReviewStatuses = @('clear', 'supervisor_review', 'recapture_needed')
$RequiredPredictionFields = @(
    'image_id',
    'worker_id',
    'crop',
    'zone',
    'capture_source',
    'report_channel',
    'wearer_note',
    'possible_disease',
    'confidence',
    'limitation_flags',
    'evidence_quality',
    'next_check',
    'review_status',
    'treatment_recommendation'
)

$ReportByBucket = @{
    healthy = 'leaves look normal'
    early_blight = 'yellowing and spots on lower leaves'
    late_blight = 'dark spreading lesions on tomato leaves'
    bacterial_or_leaf_spot = 'small clustered spots on leaf surface'
    yellow_leaf_curl_or_mosaic = 'curling or mottled yellow leaves'
    stress_or_uncertain = 'leaf looks stressed or damaged'
}

function Normalize-Label {
    param([string]$Label)
    return (($Label.ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_'))
}

function Get-BucketForLabel {
    param([string]$Label)
    $normalized = Normalize-Label $Label
    $compact = $normalized -replace '_', ' '

    if (($compact -notmatch 'tomato') -and ($compact -notmatch 'healthy')) { return $null }
    if (($compact -match 'healthy') -or ($normalized -eq 'tomato_leaf')) { return 'healthy' }
    if (($compact -match 'early') -and ($compact -match 'blight')) { return 'early_blight' }
    if (($compact -match 'late') -and ($compact -match 'blight')) { return 'late_blight' }
    if ($compact -match 'bacterial|septoria|leaf spot|target spot|mold') { return 'bacterial_or_leaf_spot' }
    if ($compact -match 'yellow|curl|mosaic') { return 'yellow_leaf_curl_or_mosaic' }
    if ($compact -match 'deficiency|miner|mite|stress|damage') { return 'stress_or_uncertain' }
    return $null
}

function Write-Jsonl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object[]]$Rows
    )
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $lines = foreach ($row in $Rows) {
        $row | ConvertTo-Json -Compress -Depth 12
    }
    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

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

function Get-StableImageId {
    param(
        [string]$Split,
        [int]$Index,
        [string]$Hash
    )
    return ('{0}-{1:d5}-{2}' -f $Split, $Index, $Hash.Substring(0, 10).ToLowerInvariant())
}

function Invoke-Stage {
    if (-not $Root) { throw 'Stage requires -Root' }
    $rootPath = (Resolve-Path -Path $Root).Path
    $outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    $neutralDir = Join-Path $outPath "neutral_images\$Split"
    New-Item -ItemType Directory -Force -Path $neutralDir | Out-Null

    $groups = @{}
    $skipped = @{}
    $files = Get-ChildItem -Path $rootPath -Recurse -File | Where-Object {
        $ImageExtensions -contains $_.Extension.ToLowerInvariant()
    }

    foreach ($file in $files) {
        $rawLabel = $file.Directory.Name
        $bucket = Get-BucketForLabel $rawLabel
        if (-not $bucket) {
            if (-not $skipped.ContainsKey($rawLabel)) { $skipped[$rawLabel] = 0 }
            $skipped[$rawLabel] += 1
            continue
        }
        if (-not $groups.ContainsKey($bucket)) { $groups[$bucket] = New-Object System.Collections.Generic.List[object] }
        $groups[$bucket].Add([pscustomobject]@{ File = $file; RawLabel = $rawLabel })
    }

    $rng = [System.Random]::new($Seed)
    $rows = New-Object System.Collections.Generic.List[object]
    $index = 0

    foreach ($bucket in ($groups.Keys | Sort-Object)) {
        $items = $groups[$bucket] | Sort-Object { $rng.Next() } | Select-Object -First $MaxPerBucket
        foreach ($item in $items) {
            $hash = (Get-FileHash -Algorithm SHA256 -Path $item.File.FullName).Hash
            $imageId = Get-StableImageId -Split $Split -Index $index -Hash $hash
            $extension = $item.File.Extension.ToLowerInvariant()
            if ($extension -eq '.jpeg') { $extension = '.jpg' }
            $neutralPath = Join-Path $neutralDir "$imageId$extension"
            $operatorReport = if ($ReportMode -eq 'Bucket') { $ReportByBucket[$bucket] } else { $ReportText }
            Copy-Item -LiteralPath $item.File.FullName -Destination $neutralPath -Force
            $rows.Add([pscustomobject]@{
                image_id = $imageId
                neutral_path = $neutralPath
                source_dataset = $SourceName
                source_url = $SourceUrl
                original_path = $item.File.FullName
                original_label = $item.RawLabel
                bucket = $bucket
                split = $Split
                sha256 = $hash.ToLowerInvariant()
                worker_id = $WorkerId
                crop = $Crop
                zone = $Zone
                report_channel = 'typed_report_voice_stand_in'
                operator_report = $operatorReport
            })
            $index += 1
        }
    }

    $manifestPath = Join-Path $outPath "manifests\$Split.jsonl"
    Write-Jsonl -Path $manifestPath -Rows $rows.ToArray()

    $bucketCounts = @{}
    foreach ($row in $rows) {
        if (-not $bucketCounts.ContainsKey($row.bucket)) { $bucketCounts[$row.bucket] = 0 }
        $bucketCounts[$row.bucket] += 1
    }
    "staged=$($rows.Count) manifest=$manifestPath"
    "bucket_counts=$($bucketCounts | ConvertTo-Json -Compress)"
    if ($skipped.Count -gt 0) {
        "skipped_labels=$($skipped | ConvertTo-Json -Compress)"
    }
}

function Get-JpegCodec {
    Add-Type -AssemblyName System.Drawing
    return [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' } |
        Select-Object -First 1
}

function Save-Jpeg {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Quality = 80
    )
    $codec = Get-JpegCodec
    $encoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    $encoderParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($encoder, [int64]$Quality)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $Bitmap.Save($Path, $codec, $encoderParameters)
    $encoderParameters.Dispose()
}

function New-Canvas {
    param(
        [int]$Width,
        [int]$Height,
        [int]$R = 214,
        [int]$G = 208,
        [int]$B = 194
    )
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb($R, $G, $B))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics }
}

function Draw-Contain {
    param(
        [System.Drawing.Image]$Image,
        [System.Drawing.Graphics]$Graphics,
        [int]$Width,
        [int]$Height,
        [double]$Scale = 1.0
    )
    $ratio = [Math]::Min($Width / $Image.Width, $Height / $Image.Height) * $Scale
    $drawWidth = [int]($Image.Width * $ratio)
    $drawHeight = [int]($Image.Height * $ratio)
    $x = [int](($Width - $drawWidth) / 2)
    $y = [int](($Height - $drawHeight) / 2)
    $Graphics.DrawImage($Image, $x, $y, $drawWidth, $drawHeight)
}

function Draw-CoverCrop {
    param(
        [System.Drawing.Image]$Image,
        [System.Drawing.Graphics]$Graphics,
        [int]$Width,
        [int]$Height,
        [double]$OffsetX = 0.5,
        [double]$OffsetY = 0.35
    )
    $targetRatio = $Width / $Height
    $sourceRatio = $Image.Width / $Image.Height
    if ($sourceRatio -gt $targetRatio) {
        $cropWidth = [int]($Image.Height * $targetRatio)
        $slack = $Image.Width - $cropWidth
        $left = [int]([Math]::Max(0, [Math]::Min($slack, $slack * $OffsetX)))
        $sourceRect = [System.Drawing.Rectangle]::new($left, 0, $cropWidth, $Image.Height)
    } else {
        $cropHeight = [int]($Image.Width / $targetRatio)
        $slack = $Image.Height - $cropHeight
        $top = [int]([Math]::Max(0, [Math]::Min($slack, $slack * $OffsetY)))
        $sourceRect = [System.Drawing.Rectangle]::new(0, $top, $Image.Width, $cropHeight)
    }
    $destRect = [System.Drawing.Rectangle]::new(0, 0, $Width, $Height)
    $Graphics.DrawImage($Image, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
}

function Add-Band {
    param(
        [System.Drawing.Graphics]$Graphics,
        [int]$Width,
        [int]$Height,
        [int]$Alpha = 50
    )
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($Alpha, 255, 255, 255))
    $Graphics.FillRectangle($brush, 0, [int]($Height * 0.35), $Width, [int]($Height * 0.18))
    $brush.Dispose()
}

function Invoke-Simulate {
    if (-not $Manifest) { throw 'Simulate requires -Manifest' }
    Add-Type -AssemblyName System.Drawing
    $rows = Read-Jsonl -Path $Manifest
    $outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    $captureRows = New-Object System.Collections.Generic.List[object]

    foreach ($row in $rows) {
        if (-not (Test-Path -LiteralPath $row.neutral_path)) {
            throw "neutral image missing: $($row.neutral_path)"
        }
        $source = [System.Drawing.Image]::FromFile($row.neutral_path)
        try {
            $variants = @(
                @{ Name = 'clear'; Width = 720; Height = 1280; Quality = 90; Flags = @('single_view_only') },
                @{ Name = 'usable_but_single_view'; Width = 504; Height = 896; Quality = 72; Flags = @('single_view_only', 'off_center') },
                @{ Name = 'bad_recapture'; Width = 360; Height = 640; Quality = 45; Flags = @('too_far', 'blurred', 'single_view_only') }
            )
            foreach ($variant in $variants) {
                $qualityName = $variant.Name
                $variantDir = Join-Path $outPath "captures\$Split\$qualityName"
                $captureId = "$($row.image_id)-$qualityName"
                $capturePath = Join-Path $variantDir "$captureId.jpg"
                $canvas = New-Canvas -Width $variant.Width -Height $variant.Height
                try {
                    if ($qualityName -eq 'clear') {
                        Draw-Contain -Image $source -Graphics $canvas.Graphics -Width $variant.Width -Height $variant.Height -Scale 0.96
                    } elseif ($qualityName -eq 'usable_but_single_view') {
                        $offsetSeed = [Math]::Abs(($captureId.GetHashCode() % 100)) / 100
                        Draw-CoverCrop -Image $source -Graphics $canvas.Graphics -Width $variant.Width -Height $variant.Height -OffsetX (0.25 + ($offsetSeed * 0.45)) -OffsetY 0.35
                        Add-Band -Graphics $canvas.Graphics -Width $variant.Width -Height $variant.Height -Alpha 30
                    } else {
                        Draw-Contain -Image $source -Graphics $canvas.Graphics -Width $variant.Width -Height $variant.Height -Scale 0.46
                        Add-Band -Graphics $canvas.Graphics -Width $variant.Width -Height $variant.Height -Alpha 70
                    }
                    Save-Jpeg -Bitmap $canvas.Bitmap -Path $capturePath -Quality $variant.Quality
                } finally {
                    $canvas.Graphics.Dispose()
                    $canvas.Bitmap.Dispose()
                }
                $hash = (Get-FileHash -Algorithm SHA256 -Path $capturePath).Hash.ToLowerInvariant()
                $captureRows.Add([pscustomobject]@{
                    image_id = $captureId
                    source_image_id = $row.image_id
                    neutral_path = $capturePath
                    source_dataset = $row.source_dataset
                    source_url = $row.source_url
                    original_path = $row.original_path
                    original_label = $row.original_label
                    bucket = $row.bucket
                    split = $row.split
                    worker_id = $row.worker_id
                    crop = $row.crop
                    zone = $row.zone
                    report_channel = $row.report_channel
                    operator_report = $row.operator_report
                    capture_quality = $qualityName
                    expected_limitation_flags = $variant.Flags
                    capture_source = 'simulated_meta_dat_capture'
                    sha256 = $hash
                })
            }
        } finally {
            $source.Dispose()
        }
    }

    $captureManifest = Join-Path $outPath "manifests\$($Split)_captures.jsonl"
    Write-Jsonl -Path $captureManifest -Rows $captureRows.ToArray()
    "captures=$($captureRows.Count) manifest=$captureManifest"
}

function Invoke-ExportInput {
    if (-not $Manifest) { throw 'ExportInput requires -Manifest' }
    $rows = Read-Jsonl -Path $Manifest
    $outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    $inputRows = New-Object System.Collections.Generic.List[object]

    foreach ($row in $rows) {
        if (-not (Test-Path -LiteralPath $row.neutral_path)) {
            throw "input image missing: $($row.neutral_path)"
        }
        $inputRows.Add([pscustomobject]@{
            image_id = $row.image_id
            image_path = $row.neutral_path
            worker_id = $row.worker_id
            crop = $row.crop
            zone = $row.zone
            capture_source = $row.capture_source
            report_channel = $row.report_channel
            wearer_note = $row.operator_report
        })
    }

    $inputPath = Join-Path $outPath "inputs\$Split.jsonl"
    Write-Jsonl -Path $inputPath -Rows $inputRows.ToArray()
    "inputs=$($inputRows.Count) input=$inputPath"
}

function Test-HasRequiredFields {
    param([object]$Prediction)
    $names = @($Prediction.PSObject.Properties.Name)
    foreach ($field in $RequiredPredictionFields) {
        if ($names -notcontains $field) { return $false }
    }
    return $true
}

function Test-NoTreatmentAdvice {
    param([object]$Value)
    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) {
        $clean = $Value.Trim().ToLowerInvariant()
        return @('', 'null', 'none', 'n/a') -contains $clean
    }
    return -not [bool]$Value
}

function Get-ArrayValues {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    return @($Value)
}

function Test-BroadState {
    param(
        [object]$Truth,
        [object]$Prediction
    )
    $status = [string]$Prediction.review_status
    $possible = ([string]$Prediction.possible_disease).ToLowerInvariant()
    $confidence = ([string]$Prediction.confidence).ToLowerInvariant()
    $flags = @(Get-ArrayValues $Prediction.limitation_flags | ForEach-Object { ([string]$_).ToLowerInvariant() })

    if ($Truth.capture_quality -eq 'bad_recapture') {
        return ($status -eq 'recapture_needed') -or ($confidence -eq 'low') -or ($flags -contains 'blurred') -or ($flags -contains 'too_far')
    }
    if ($Truth.bucket -eq 'healthy') {
        return ($status -eq 'clear') -or ($possible -match 'healthy') -or ($possible -match 'no visible')
    }
    return (@('supervisor_review', 'recapture_needed') -contains $status) -and ($possible -notmatch 'no visible disease')
}

function Test-BadRecaptureBehavior {
    param([object]$Prediction)
    $status = [string]$Prediction.review_status
    $confidence = ([string]$Prediction.confidence).ToLowerInvariant()
    $flags = @(Get-ArrayValues $Prediction.limitation_flags | ForEach-Object { ([string]$_).ToLowerInvariant() })
    return ($status -eq 'recapture_needed') -or ($confidence -eq 'low') -or
        ($flags -contains 'blurred') -or ($flags -contains 'too_far') -or ($flags -contains 'poor_contrast')
}

function Invoke-Score {
    if (-not $Manifest) { throw 'Score requires -Manifest' }
    if (-not $Predictions) { throw 'Score requires -Predictions' }
    $truthRows = Read-Jsonl -Path $Manifest
    $predictionRows = Read-Jsonl -Path $Predictions

    $truthById = @{}
    foreach ($row in $truthRows) { $truthById[[string]$row.image_id] = $row }
    $predictionById = @{}
    foreach ($row in $predictionRows) { $predictionById[[string]$row.image_id] = $row }

    $scoreTotals = @{}
    $scorePassed = @{}
    $failures = New-Object System.Collections.Generic.List[object]

    foreach ($imageId in $truthById.Keys) {
        if (-not $predictionById.ContainsKey($imageId)) {
            $failures.Add([pscustomobject]@{ image_id = $imageId; reason = 'missing_prediction' })
            continue
        }
        $truth = $truthById[$imageId]
        $prediction = $predictionById[$imageId]
        $checks = @{
            valid_schema = (Test-HasRequiredFields $prediction)
            safe_review_status = ($AllowedReviewStatuses -contains ([string]$prediction.review_status))
            no_treatment_advice = (Test-NoTreatmentAdvice $prediction.treatment_recommendation)
            report_preserved = ([string]$prediction.wearer_note -eq [string]$truth.operator_report)
            limitations_named = ((Get-ArrayValues $prediction.limitation_flags).Count -gt 0)
            next_check_exists = (-not [string]::IsNullOrWhiteSpace([string]$prediction.next_check))
            broad_state = (Test-BroadState -Truth $truth -Prediction $prediction)
        }
        if ($truth.capture_quality -eq 'bad_recapture') {
            $checks.bad_recapture_behavior = (Test-BadRecaptureBehavior -Prediction $prediction)
        }
        foreach ($name in $checks.Keys) {
            if (-not $scoreTotals.ContainsKey($name)) { $scoreTotals[$name] = 0; $scorePassed[$name] = 0 }
            $scoreTotals[$name] += 1
            if ($checks[$name]) {
                $scorePassed[$name] += 1
            } else {
                $failures.Add([pscustomobject]@{
                    image_id = $imageId
                    bucket = $truth.bucket
                    capture_quality = $truth.capture_quality
                    check = $name
                    review_status = $prediction.review_status
                    possible_disease = $prediction.possible_disease
                })
            }
        }
    }

    $missingCount = @($truthById.Keys | Where-Object { -not $predictionById.ContainsKey($_) }).Count
    $extraCount = @($predictionById.Keys | Where-Object { -not $truthById.ContainsKey($_) }).Count
    $reportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    $reportDir = Split-Path -Parent $reportPath
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Disease Scout Dataset Verifier Report')
    $lines.Add('')
    $lines.Add("- Manifest rows: $($truthRows.Count)")
    $lines.Add("- Prediction rows: $($predictionRows.Count)")
    $lines.Add("- Missing predictions: $missingCount")
    $lines.Add("- Extra predictions: $extraCount")
    $lines.Add('')
    $lines.Add('## Scores')
    $lines.Add('')
    $lines.Add('| Check | Passed | Total | Rate |')
    $lines.Add('| --- | ---: | ---: | ---: |')
    foreach ($name in ($scoreTotals.Keys | Sort-Object)) {
        $rate = if ($scoreTotals[$name] -gt 0) { $scorePassed[$name] / $scoreTotals[$name] } else { 0 }
        $lines.Add(('| {0} | {1} | {2} | {3:P1} |' -f $name, $scorePassed[$name], $scoreTotals[$name], $rate))
    }
    $lines.Add('')
    $lines.Add('## Failure Samples')
    $lines.Add('')
    $sampledFailures = @($failures | Select-Object -First $MaxFailures)
    if ($sampledFailures.Count -eq 0) {
        $lines.Add('- No failures recorded.')
    } else {
        foreach ($failure in $sampledFailures) {
            $lines.Add("- ``$($failure.image_id)``: $($failure | ConvertTo-Json -Compress)")
        }
    }

    Set-Content -Path $reportPath -Value $lines -Encoding UTF8
    "report=$reportPath"
    "failures=$($failures.Count)"
}

switch ($Command) {
    'Stage' { Invoke-Stage }
    'Simulate' { Invoke-Simulate }
    'ExportInput' { Invoke-ExportInput }
    'Score' { Invoke-Score }
}
