param(
    [string]$DatasetRoot = "",
    [string]$OutDir = "",
    [int]$MinTrainImages = 20
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Get-ImageFiles {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $Path -File -Recurse |
        Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|webp)$' })
}

function Get-RepoRelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )
    $baseFull = (Resolve-Path $BasePath).Path
    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
    if (-not $baseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = New-Object System.Uri($baseFull)
    $targetUri = New-Object System.Uri($targetFull)
    $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
    return ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string[]]$Value
    )
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Value, $encoding)
}

$repoRoot = Resolve-RepoRoot
if ([string]::IsNullOrWhiteSpace($DatasetRoot)) {
    $DatasetRoot = Join-Path $repoRoot "data\raw\PlantDoc-Dataset-master"
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $repoRoot "final_docs\finetune"
}

$DatasetRoot = (Resolve-Path $DatasetRoot).Path
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$trainRoot = Join-Path $DatasetRoot "train"
$testRoot = Join-Path $DatasetRoot "test"
if (-not (Test-Path $trainRoot)) {
    throw "Missing PlantDoc train folder: $trainRoot"
}
if (-not (Test-Path $testRoot)) {
    throw "Missing PlantDoc test folder: $testRoot"
}

$excluded = @("Tomato two spotted spider mites leaf")
$classes = Get-ChildItem -LiteralPath $trainRoot -Directory |
    Where-Object { $_.Name -like "Tomato*" -and $excluded -notcontains $_.Name } |
    Sort-Object Name

$classRows = @()
$manifestRows = New-Object System.Collections.Generic.List[object]
$labelIndex = 0

foreach ($classDir in $classes) {
    $trainFiles = Get-ImageFiles -Path $classDir.FullName
    $testDir = Join-Path $testRoot $classDir.Name
    $testFiles = Get-ImageFiles -Path $testDir
    if ($trainFiles.Count -lt $MinTrainImages) {
        continue
    }

    $classRows += [pscustomobject]@{
        label_id = $labelIndex
        class_name = $classDir.Name
        train_count = $trainFiles.Count
        test_count = $testFiles.Count
    }

    foreach ($file in $trainFiles) {
        $manifestRows.Add([pscustomobject]@{
            split = "train"
            label_id = $labelIndex
            class_name = $classDir.Name
            path = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $file.FullName
            bytes = $file.Length
        }) | Out-Null
    }
    foreach ($file in $testFiles) {
        $manifestRows.Add([pscustomobject]@{
            split = "test"
            label_id = $labelIndex
            class_name = $classDir.Name
            path = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $file.FullName
            bytes = $file.Length
        }) | Out-Null
    }

    $labelIndex += 1
}

if ($classRows.Count -lt 2) {
    throw "Need at least two tomato classes for a classifier smoke run; found $($classRows.Count)."
}

$manifestPath = Join-Path $OutDir "plantdoc-tomato-manifest.jsonl"
$labelMapPath = Join-Path $OutDir "plantdoc-tomato-label-map.json"
$receiptPath = Join-Path $OutDir "plantdoc-tomato-smoke-receipt.json"
$summaryPath = Join-Path $OutDir "plantdoc-tomato-smoke-summary.md"

$manifestRows |
    ForEach-Object { $_ | ConvertTo-Json -Compress } |
    ForEach-Object -Begin { $manifestLines = @() } -Process { $manifestLines += $_ } -End {
        Write-Utf8NoBom -Path $manifestPath -Value $manifestLines
    }

$labelMap = [ordered]@{}
foreach ($row in $classRows) {
    $labelMap[[string]$row.label_id] = $row.class_name
}
Write-Utf8NoBom -Path $labelMapPath -Value @($labelMap | ConvertTo-Json -Depth 5)

$trainTotal = ($classRows | Measure-Object -Property train_count -Sum).Sum
$testTotal = ($classRows | Measure-Object -Property test_count -Sum).Sum
$receipt = [ordered]@{
    status = "pass"
    generated_at = (Get-Date).ToString("o")
    repo_root = "."
    dataset_root = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $DatasetRoot
    training_target = "Google Colab T4 transfer learning"
    local_run_type = "dataset_manifest_smoke"
    local_gpu_training_claimed = $false
    selected_class_count = $classRows.Count
    train_image_count = [int]$trainTotal
    test_image_count = [int]$testTotal
    excluded_classes = $excluded
    min_train_images = $MinTrainImages
    artifacts = [ordered]@{
        manifest = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $manifestPath
        label_map = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $labelMapPath
        summary = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $summaryPath
        colab_notebook = "training/disease-finetune/colab_t4_plantdoc_tomato_finetune.ipynb"
        train_script = "training/disease-finetune/train_colab_t4_plantdoc_tomato.py"
    }
    classes = $classRows
}
Write-Utf8NoBom -Path $receiptPath -Value @($receipt | ConvertTo-Json -Depth 8)

$summary = @(
    "# PlantDoc Tomato Finetune Smoke Receipt"
    ""
    "- Status: pass"
    "- Local run type: dataset manifest smoke"
    "- Training target: Google Colab T4"
    "- Local GPU training claimed: false"
    "- Selected classes: $($classRows.Count)"
    "- Train images: $trainTotal"
    "- Test images: $testTotal"
    '- Manifest: `final_docs/finetune/plantdoc-tomato-manifest.jsonl`'
    '- Label map: `final_docs/finetune/plantdoc-tomato-label-map.json`'
    ""
    "## Classes"
    ""
)
foreach ($row in $classRows) {
    $summary += "- `"$($row.class_name)`": train $($row.train_count), test $($row.test_count)"
}
Write-Utf8NoBom -Path $summaryPath -Value $summary

[pscustomobject]@{
    status = "pass"
    selected_classes = $classRows.Count
    train_images = [int]$trainTotal
    test_images = [int]$testTotal
    receipt = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $receiptPath
    manifest = Get-RepoRelativePath -BasePath $repoRoot -TargetPath $manifestPath
}
