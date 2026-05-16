param(
    [string]$Out = "final_docs\overnight\dogbot-auth-status.json",
    [string]$ChannelId = "1505114553606733834",
    [string]$GuildId = "1504987658005516481",
    [string]$ProjectControlCategoryId = "1504993811267457096"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-RepoPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $repoRoot $Path))
}

function Get-UserEnv {
    param([string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, "User")
}

function Get-ProcessEnv {
    param([string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Get-CredentialManagerSecret {
    param([string]$Name)

    $helper = Join-Path $env:USERPROFILE "projects\tools and scripts\secure-env.ps1"
    if (-not (Test-Path -LiteralPath $helper)) {
        return $null
    }

    try {
        . $helper
        if (-not (Get-Command Get-CodexStoredSecret -ErrorAction SilentlyContinue)) {
            return $null
        }
        return Get-CodexStoredSecret -Target "Codex:$Name"
    }
    catch {
        return $null
    }
}

function Invoke-DiscordGet {
    param(
        [string]$Token,
        [string]$Route
    )
    $out = & curl.exe -sS -w "`n%{http_code}" -X GET `
        -H "Authorization: Bot $Token" `
        -H "Content-Type: application/json" `
        -H "User-Agent: Dogbot-Auth-Check/1.0" `
        "https://discord.com/api/v10$Route"
    $lines = $out -split "`r?`n"
    $status = [int]$lines[-1]
    $body = ($lines[0..($lines.Length - 2)] -join "`n")
    $data = if ($body.Trim()) { $body | ConvertFrom-Json } else { $null }
    return [ordered]@{ status = $status; data = $data }
}

function Find-Guild {
    param(
        [object]$Guilds,
        [string]$TargetGuildId
    )

    if (-not $Guilds) {
        return $null
    }
    foreach ($guild in @($Guilds)) {
        if ([string]$guild.id -eq $TargetGuildId) {
            return $guild
        }
    }
    return $null
}

function Build-InviteUrl {
    param([string]$ApplicationId)
    if (-not $ApplicationId) {
        return $null
    }
    $permissions = 117824
    return "https://discord.com/oauth2/authorize?client_id=$ApplicationId&scope=bot&permissions=$permissions"
}

$rawCandidates = @(
    [ordered]@{ label = "DISCORD_LAB_BOT_TOKEN/User"; name = "DISCORD_LAB_BOT_TOKEN"; source = "User"; token = Get-UserEnv "DISCORD_LAB_BOT_TOKEN" },
    [ordered]@{ label = "DISCORD_LAB_BOT_TOKEN/Process"; name = "DISCORD_LAB_BOT_TOKEN"; source = "Process"; token = Get-ProcessEnv "DISCORD_LAB_BOT_TOKEN" },
    [ordered]@{ label = "DISCORD_LAB_BOT_TOKEN/CredentialManager"; name = "DISCORD_LAB_BOT_TOKEN"; source = "CredentialManager"; token = Get-CredentialManagerSecret "DISCORD_LAB_BOT_TOKEN" },
    [ordered]@{ label = "DISCORD_BOT_TOKEN/User"; name = "DISCORD_BOT_TOKEN"; source = "User"; token = Get-UserEnv "DISCORD_BOT_TOKEN" },
    [ordered]@{ label = "DISCORD_BOT_TOKEN/Process"; name = "DISCORD_BOT_TOKEN"; source = "Process"; token = Get-ProcessEnv "DISCORD_BOT_TOKEN" },
    [ordered]@{ label = "DISCORD_BOT_TOKEN/CredentialManager"; name = "DISCORD_BOT_TOKEN"; source = "CredentialManager"; token = Get-CredentialManagerSecret "DISCORD_BOT_TOKEN" }
)

$seen = @{}
$candidates = @()
foreach ($candidate in $rawCandidates) {
    if (-not $candidate.token) { continue }
    if ($seen.ContainsKey($candidate.token)) { continue }
    $seen[$candidate.token] = $true
    $candidates += $candidate
}

$checks = @()
foreach ($candidate in $candidates) {
    try {
        $me = Invoke-DiscordGet -Token $candidate.token -Route "/users/@me"
        $app = Invoke-DiscordGet -Token $candidate.token -Route "/oauth2/applications/@me"
        $guilds = Invoke-DiscordGet -Token $candidate.token -Route "/users/@me/guilds"
        $targetGuild = if ($guilds.status -eq 200) { Find-Guild -Guilds $guilds.data -TargetGuildId $GuildId } else { $null }
        $channel = Invoke-DiscordGet -Token $candidate.token -Route "/channels/$ChannelId"
        $applicationId = if ($app.data -and $app.data.id) { [string]$app.data.id } elseif ($me.data -and $me.data.id) { [string]$me.data.id } else { $null }
        $checks += [ordered]@{
            label = $candidate.label
            name = $candidate.name
            source = $candidate.source
            token_present = $true
            token_length = $candidate.token.Length
            me_status = $me.status
            application_status = $app.status
            application_id = $applicationId
            invite_url = Build-InviteUrl -ApplicationId $applicationId
            bot_id = if ($me.data) { $me.data.id } else { $null }
            bot_username = if ($me.data) { $me.data.username } else { $null }
            guilds_status = $guilds.status
            target_guild_id = $GuildId
            target_guild_visible = $null -ne $targetGuild
            target_guild_name = if ($targetGuild) { $targetGuild.name } else { $null }
            channel_status = $channel.status
            channel_name = if ($channel.data) { $channel.data.name } else { $null }
            channel_parent_id = if ($channel.data) { $channel.data.parent_id } else { $null }
            channel_error = if ($channel.data -and $channel.data.message) { $channel.data.message } else { $null }
            under_project_control = if ($channel.data) { $channel.data.parent_id -eq $ProjectControlCategoryId } else { $false }
        }
    }
    catch {
        $checks += [ordered]@{
            label = $candidate.label
            name = $candidate.name
            source = $candidate.source
            token_present = $true
            token_length = $candidate.token.Length
            error = $_.Exception.Message
            under_project_control = $false
        }
    }
}

$passing = @($checks | Where-Object { $_.channel_status -eq 200 -and $_.under_project_control })
$status = if ($passing.Count -gt 0) { "pass" } else { "blocked" }
$result = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    status = $status
    surface = "Discord Dogbot live API"
    dogbot_channel_id = $ChannelId
    guild_id = $GuildId
    project_control_category_id = $ProjectControlCategoryId
    candidate_count = $checks.Count
    selected = if ($passing.Count -gt 0) { $passing[0].label } else { $null }
    checks = $checks
    blocker = if ($status -eq "blocked") { "No available bot token can read #dogbot under Project Control. A fresh valid DISCORD_LAB_BOT_TOKEN or bot access repair is required for live Discord completion proof." } else { $null }
}

$outPath = Resolve-RepoPath $Out
$parent = Split-Path -Parent $outPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$result | ConvertTo-Json -Depth 12 | Set-Content -Path $outPath -Encoding UTF8

Write-Output "report=$outPath"
Write-Output "status=$status"
Write-Output "candidate_count=$($checks.Count)"
if ($passing.Count -gt 0) {
    Write-Output "selected=$($passing[0].label)"
}
else {
    foreach ($check in $checks) {
        Write-Output "candidate=$($check.label); me=$($check.me_status); channel=$($check.channel_status); error=$($check.channel_error)"
    }
}

if ($status -eq "blocked") {
    exit 1
}
