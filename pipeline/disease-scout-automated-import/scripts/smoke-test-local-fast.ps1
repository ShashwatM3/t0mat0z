param(
    [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pipelineRoot = Resolve-Path (Join-Path $scriptDir "..")
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $pipelineRoot "config\pipeline.example.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

function Resolve-FromRepo {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $repoRoot $Path
}

$incomingRelative = "final_docs\auto-import\pipeline-smoke-incoming"
$outDirRelative = "final_docs\auto-import\pipeline-smoke-output"
$incoming = Resolve-FromRepo $incomingRelative
$outDir = Resolve-FromRepo $outDirRelative
$sample = Resolve-FromRepo $config.paths.testSampleImage

if (-not (Test-Path -LiteralPath $sample)) {
    throw "Sample image not found: $sample"
}

New-Item -ItemType Directory -Path $incoming -Force | Out-Null
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$target = Join-Path $incoming ("pipeline-smoke-{0}{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), [System.IO.Path]::GetExtension($sample))
Copy-Item -LiteralPath $sample -Destination $target

$wrapper = Join-Path $scriptDir "run-auto-import-watch.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ConfigPath $ConfigPath -Provider local-fast -WatchPath $incomingRelative -OutDir $outDirRelative

$latest = Get-ChildItem -LiteralPath $outDir -Filter "*.result.json" -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1

if (-not $latest) {
    throw "Smoke test did not produce a result JSON in $outDir"
}

$result = Get-Content -LiteralPath $latest.FullName -Raw | ConvertFrom-Json

if ($result.provider -ne "local-fast") {
    throw "Expected local-fast provider, got $($result.provider)"
}

if (-not $result.response.observation.next_check) {
    throw "Observation is missing next_check."
}

[pscustomobject]@{
    status = "pass"
    result = $latest.FullName
    elapsed_ms = $result.elapsed_ms
    sentence = $result.sentence
} | Format-List
