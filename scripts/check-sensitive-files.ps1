param(
  [ValidateSet("Current", "Staged", "History", "Range", "PrePush")]
  [string]$Mode = "Current",
  [string]$Range = ""
)

$ErrorActionPreference = "Stop"

$protectedPaths = @(
  @{ label = "AGENTS.md"; regex = '(^|/)AGENTS\.md$' },
  @{ label = "CLAUDE.md"; regex = '(^|/)CLAUDE\.md$' },
  @{ label = ".claude"; regex = '(^|/)\.claude/' },
  @{ label = ".cursor"; regex = '(^|/)\.cursor/' },
  @{ label = ".codex"; regex = '(^|/)\.codex/' },
  @{ label = ".cursorrules"; regex = '(^|/)\.cursorrules$' },
  @{ label = ".aiderignore"; regex = '(^|/)\.aiderignore$' },
  @{ label = "env file"; regex = '(^|/)\.env($|\.)' },
  @{ label = "credentials.json"; regex = '(^|/)credentials\.json$' },
  @{ label = "private/signing key"; regex = '\.(pem|key|p8|p12|jks|mobileprovision)$' },
  @{ label = "local database"; regex = '\.(sqlite|db)$' }
)

$secretPatterns = @(
  @{ label = "OpenAI-style key"; regex = 'sk-[A-Za-z0-9_-]{20,}' },
  @{ label = "GitHub token"; regex = 'gh[pousr]_[A-Za-z0-9_]{20,}' },
  @{ label = "GitHub fine-grained token"; regex = 'github_pat_[A-Za-z0-9_]{20,}' },
  @{ label = "AWS access key"; regex = 'AKIA[0-9A-Z]{16}' },
  @{ label = "Google API key"; regex = 'AIza[0-9A-Za-z_-]{20,}' },
  @{ label = "private key block"; regex = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
  @{ label = "assigned secret"; regex = '(?i)(password|passwd|pwd|secret|token|api[_-]?key)\s*[:=]\s*[''"][^''"\s]{8,}' }
)

$binaryExtension = '\.(png|jpg|jpeg|gif|webp|ico|pdf|zip|gz|tgz|tar|mp4|mov|wav|mp3|ttf|otf|woff|woff2)$'
$findings = New-Object System.Collections.Generic.List[object]

function Normalize-RepoPath {
  param([string]$Path)
  return ($Path -replace '\\', '/')
}

function Add-Finding {
  param(
    [string]$Scope,
    [string]$Path,
    [string]$Issue
  )
  $findings.Add([pscustomobject]@{
    scope = $Scope
    file = (Normalize-RepoPath $Path)
    issue = $Issue
  }) | Out-Null
}

function Test-ProtectedPath {
  param(
    [string]$Scope,
    [string]$Path
  )
  $repoPath = Normalize-RepoPath $Path
  foreach ($entry in $protectedPaths) {
    if ($repoPath -match $entry.regex) {
      Add-Finding -Scope $Scope -Path $repoPath -Issue "protected path: $($entry.label)"
    }
  }
}

function Get-GitText {
  param([string]$Spec)
  $priorErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & git show $Spec 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
      return $null
    }
    return ($output -join "`n")
  } catch {
    return $null
  } finally {
    $ErrorActionPreference = $priorErrorActionPreference
  }
}

function Test-SecretContent {
  param(
    [string]$Scope,
    [string]$Path,
    [string]$Text
  )
  if ([string]::IsNullOrEmpty($Text)) {
    return
  }
  foreach ($entry in $secretPatterns) {
    if ($Text -match $entry.regex) {
      Add-Finding -Scope $Scope -Path $Path -Issue "secret pattern: $($entry.label)"
      return
    }
  }
}

function Test-PathSet {
  param(
    [string]$Scope,
    [string[]]$Paths,
    [string]$BlobPrefix
  )
  foreach ($path in $Paths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
      continue
    }
    $repoPath = Normalize-RepoPath $path.Trim()
    Test-ProtectedPath -Scope $Scope -Path $repoPath
    if ($repoPath -match $binaryExtension) {
      continue
    }
    $text = Get-GitText -Spec "$BlobPrefix$repoPath"
    Test-SecretContent -Scope $Scope -Path $repoPath -Text $text
  }
}

function Test-CommitRange {
  param([string]$CommitRange)
  $commits = & git rev-list $CommitRange
  foreach ($commit in $commits) {
    $paths = & git diff-tree --root --no-commit-id --name-only --diff-filter=ACMR -r $commit
    foreach ($path in $paths) {
      if ([string]::IsNullOrWhiteSpace($path)) {
        continue
      }
      $repoPath = Normalize-RepoPath $path.Trim()
      $scope = "commit $($commit.Substring(0, 7))"
      Test-ProtectedPath -Scope $scope -Path $repoPath
      if ($repoPath -match $binaryExtension) {
        continue
      }
      $text = Get-GitText -Spec "$commit`:$repoPath"
      Test-SecretContent -Scope $scope -Path $repoPath -Text $text
    }
  }
}

switch ($Mode) {
  "Current" {
    $paths = & git ls-files
    Test-PathSet -Scope "current" -Paths $paths -BlobPrefix "HEAD:"
  }
  "Staged" {
    $paths = & git diff --cached --name-only --diff-filter=ACMR
    Test-PathSet -Scope "staged" -Paths $paths -BlobPrefix ":"
  }
  "History" {
    Test-CommitRange -CommitRange "--all"
  }
  "Range" {
    if ([string]::IsNullOrWhiteSpace($Range)) {
      throw "-Range is required when -Mode Range is used."
    }
    Test-CommitRange -CommitRange $Range
  }
  "PrePush" {
    $stdin = [Console]::In.ReadToEnd()
    $lines = $stdin -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($lines.Count -eq 0) {
      $paths = & git ls-files
      Test-PathSet -Scope "pre-push current" -Paths $paths -BlobPrefix "HEAD:"
      break
    }
    foreach ($line in $lines) {
      $parts = $line.Trim() -split '\s+'
      if ($parts.Count -lt 4) {
        continue
      }
      $localSha = $parts[1]
      $remoteSha = $parts[3]
      if ($localSha -match '^0{40}$') {
        continue
      }
      if ($remoteSha -match '^0{40}$') {
        Test-CommitRange -CommitRange $localSha
      } else {
        Test-CommitRange -CommitRange "$remoteSha..$localSha"
      }
    }
  }
}

if ($findings.Count -gt 0) {
  Write-Host "Sensitive file check failed:" -ForegroundColor Red
  $findings |
    Sort-Object scope, file, issue -Unique |
    Format-Table -AutoSize
  exit 1
}

Write-Host "Sensitive file check passed ($Mode)."
