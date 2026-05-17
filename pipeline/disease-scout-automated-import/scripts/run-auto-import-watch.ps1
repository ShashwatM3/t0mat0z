param(
    [string]$ConfigPath = "",
    [ValidateSet("live", "local-fast")]
    [string]$Provider = "",
    [string]$WatchPath = "",
    [string]$OutDir = "",
    [switch]$Watch,
    [switch]$SpeakResult
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

$selectedProvider = if ([string]::IsNullOrWhiteSpace($Provider)) { $config.classifier.provider } else { $Provider }
$autoImportScript = Resolve-FromRepo $config.paths.autoImportScript
$watchPath = if ([string]::IsNullOrWhiteSpace($WatchPath)) { Resolve-FromRepo $config.paths.watchPath } else { Resolve-FromRepo $WatchPath }
$outDir = if ([string]::IsNullOrWhiteSpace($OutDir)) { Resolve-FromRepo $config.paths.outDir } else { Resolve-FromRepo $OutDir }
$apiUrl = if ([string]::IsNullOrWhiteSpace($config.classifier.customBridgeUrl)) { $config.classifier.apiUrl } else { $config.classifier.customBridgeUrl }

$argList = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $autoImportScript,
    "-Provider",
    $selectedProvider,
    "-WatchPath",
    $watchPath,
    "-OutDir",
    $outDir,
    "-ApiUrl",
    $apiUrl,
    "-Crop",
    $config.observationDefaults.crop,
    "-Zone",
    $config.observationDefaults.zone,
    "-WorkerId",
    $config.observationDefaults.workerId,
    "-WearerNote",
    $config.observationDefaults.wearerNote,
    "-IntervalSeconds",
    ([string]$config.pipeline.pollIntervalSeconds)
)

if ($Watch -or [bool]$config.pipeline.watch) {
    $argList += "-Watch"
}

if ($SpeakResult -or [bool]$config.pipeline.speakResult) {
    $argList += "-SpeakResult"
}

Write-Host "repo_root=$repoRoot"
Write-Host "config=$ConfigPath"
Write-Host "provider=$selectedProvider"
Write-Host "watch_path=$watchPath"
Write-Host "out_dir=$outDir"

& powershell @argList
