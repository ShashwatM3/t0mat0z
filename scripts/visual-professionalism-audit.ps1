param(
    [string]$Out = "final_docs\overnight\visual-professionalism-audit.json",
    [string]$MarkdownOut = "final_docs\overnight\visual-professionalism-audit.md",
    [int]$FreshHours = 8
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$generatedAt = Get-Date

function Resolve-RepoPath {
    param([string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RelativePath)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $RelativePath))
}

function Analyze-Screenshot {
    param(
        [string]$Name,
        [string]$RelativePath,
        [int]$ExpectedWidth,
        [int]$MinimumHeight
    )

    $fullPath = Resolve-RepoPath $RelativePath
    $item = Get-Item -LiteralPath $fullPath -ErrorAction SilentlyContinue
    if (-not $item) {
        return [ordered]@{
            name = $Name
            path = $RelativePath.Replace("\", "/")
            ok = $false
            issue = "missing screenshot"
        }
    }

    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::new($fullPath)
    try {
        $xStep = [Math]::Max(1, [Math]::Floor($bitmap.Width / 48))
        $yStep = [Math]::Max(1, [Math]::Floor($bitmap.Height / 48))
        $unique = @{}
        $sampleCount = 0
        $nonWhiteCount = 0
        $minBrightness = 255.0
        $maxBrightness = 0.0

        for ($y = 0; $y -lt $bitmap.Height; $y += $yStep) {
            for ($x = 0; $x -lt $bitmap.Width; $x += $xStep) {
                $pixel = $bitmap.GetPixel($x, $y)
                $key = "$($pixel.R),$($pixel.G),$($pixel.B)"
                $unique[$key] = $true
                $brightness = (($pixel.R * 0.299) + ($pixel.G * 0.587) + ($pixel.B * 0.114))
                $minBrightness = [Math]::Min($minBrightness, $brightness)
                $maxBrightness = [Math]::Max($maxBrightness, $brightness)
                if ($brightness -lt 245) {
                    $nonWhiteCount += 1
                }
                $sampleCount += 1
            }
        }

        $nonWhiteRatio = if ($sampleCount -gt 0) { $nonWhiteCount / $sampleCount } else { 0 }
        $brightnessRange = $maxBrightness - $minBrightness
        $widthOk = [Math]::Abs($bitmap.Width - $ExpectedWidth) -le 2
        $heightOk = $bitmap.Height -ge $MinimumHeight
        $freshOk = (($generatedAt - $item.LastWriteTime).TotalHours -le $FreshHours)
        $nonBlankOk = $unique.Count -ge 24 -and $brightnessRange -ge 45 -and $nonWhiteRatio -ge 0.03
        $ok = $widthOk -and $heightOk -and $freshOk -and $nonBlankOk -and $item.Length -gt 10000

        $issues = @()
        if (-not $widthOk) { $issues += "expected width $ExpectedWidth, got $($bitmap.Width)" }
        if (-not $heightOk) { $issues += "expected height at least $MinimumHeight, got $($bitmap.Height)" }
        if (-not $freshOk) { $issues += "screenshot older than $FreshHours hours" }
        if (-not $nonBlankOk) { $issues += "low visual entropy or near-blank screenshot" }
        if ($item.Length -le 10000) { $issues += "screenshot file too small for credible UI proof" }

        return [ordered]@{
            name = $Name
            path = $RelativePath.Replace("\", "/")
            ok = $ok
            width = $bitmap.Width
            height = $bitmap.Height
            size_bytes = [int64]$item.Length
            last_write_time = $item.LastWriteTime.ToString("o")
            unique_sample_colors = $unique.Count
            non_white_sample_ratio = [Math]::Round($nonWhiteRatio, 4)
            brightness_range = [Math]::Round($brightnessRange, 2)
            issue = if ($issues.Count -gt 0) { $issues -join "; " } else { $null }
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

$screenshots = @(
    Analyze-Screenshot -Name "desktop" -RelativePath "final_docs\overnight\baseline-desktop.png" -ExpectedWidth 1440 -MinimumHeight 900
    Analyze-Screenshot -Name "mobile-390" -RelativePath "final_docs\overnight\baseline-mobile-390.png" -ExpectedWidth 390 -MinimumHeight 844
    Analyze-Screenshot -Name "mobile-360" -RelativePath "final_docs\overnight\baseline-mobile-360.png" -ExpectedWidth 360 -MinimumHeight 740
    Analyze-Screenshot -Name "display-600" -RelativePath "final_docs\overnight\baseline-display-600.png" -ExpectedWidth 600 -MinimumHeight 600
    Analyze-Screenshot -Name "live-ui-upload" -RelativePath "final_docs\overnight\live-ui-upload-smoke.png" -ExpectedWidth 1440 -MinimumHeight 900
)

$failed = @($screenshots | Where-Object { -not $_.ok })
$status = if ($failed.Count -gt 0) { "fail" } else { "pass" }
$warnings = @(
    "This is an automated screenshot integrity and layout-risk audit, not a substitute for human taste review."
)

$result = [ordered]@{
    generated_at = $generatedAt.ToString("o")
    status = $status
    verdict = if ($status -eq "pass") { "demo_visuals_not_obviously_broken" } else { "visual_artifacts_need_review" }
    screenshot_count = @($screenshots).Count
    failed_count = $failed.Count
    checks = @(
        "required demo screenshots exist",
        "screenshot widths match target viewports",
        "screenshot heights cover target viewports",
        "screenshots are fresh within the current run window",
        "sampled pixels are nonblank and visually varied"
    )
    screenshots = $screenshots
    warnings = $warnings
}

$outPath = Resolve-RepoPath $Out
$outParent = Split-Path -Parent $outPath
if ($outParent) {
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null
}
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

$rows = $screenshots | ForEach-Object {
    $state = if ($_.ok) { "pass" } else { "fail" }
    "- $($_.name): $state, $($_.width)x$($_.height), colors=$($_.unique_sample_colors), non_white=$($_.non_white_sample_ratio), issue=$($_.issue)"
}
$warningRows = $warnings | ForEach-Object { "- $_" }
$markdown = @(
    "# Visual Professionalism Audit",
    "",
    "Generated: $($result.generated_at)",
    "Status: $($result.status)",
    "Verdict: $($result.verdict)",
    "",
    "## Checks",
    "",
    ($result.checks | ForEach-Object { "- $_" }),
    "",
    "## Screenshot Rows",
    "",
    $rows,
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
Write-Output "screenshots=$(@($screenshots).Count)"
Write-Output "failed=$($failed.Count)"

if ($status -eq "fail") {
    exit 1
}
