param(
    [string]$Out = "final_docs\overnight\network-preflight.json",
    [string]$BackendHealthUrl = "http://localhost:8787/health",
    [string]$WebUrl = "http://localhost:19006",
    [int]$ApiPort = 8787,
    [int]$WebPort = 19006,
    [switch]$RequireLan
)

$ErrorActionPreference = "Stop"

function Test-WebUrl {
    param(
        [string]$Url,
        [int]$TimeoutSec = 8,
        [switch]$Json
    )

    $started = Get-Date
    try {
        if ($Json) {
            $body = Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSec
            $ended = Get-Date
            return [ordered]@{
                ok = $true
                url = $Url
                elapsed_ms = [int](($ended - $started).TotalMilliseconds)
                body = $body
                error = $null
            }
        }

        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        $ended = Get-Date
        $serverHeader = $response.Headers["Server"]
        if ($serverHeader -is [array]) {
            $serverHeader = $serverHeader -join " "
        }
        $title = $null
        if ($response.Content -match "<title>(.*?)</title>") {
            $title = $matches[1]
        }
        return [ordered]@{
            ok = ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400)
            url = $Url
            status_code = [int]$response.StatusCode
            elapsed_ms = [int](($ended - $started).TotalMilliseconds)
            content_length = if ($response.RawContentLength -ge 0) { [int64]$response.RawContentLength } else { $null }
            server = $serverHeader
            title = $title
            looks_like_disease_scout = [bool]($response.Content -match "Disease Scout")
            error = $null
        }
    }
    catch {
        $ended = Get-Date
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        return [ordered]@{
            ok = $false
            url = $Url
            status_code = $statusCode
            elapsed_ms = [int](($ended - $started).TotalMilliseconds)
            error = $_.Exception.Message
        }
    }
}

function Get-PortListeners {
    param([int]$Port)

    $connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    return @($connections | ForEach-Object {
        $processName = $null
        try {
            $processName = (Get-Process -Id $_.OwningProcess -ErrorAction Stop).ProcessName
        }
        catch {
            $processName = "unknown"
        }
        [ordered]@{
            local_address = $_.LocalAddress
            local_port = $_.LocalPort
            state = $_.State.ToString()
            owning_process = $_.OwningProcess
            process_name = $processName
        }
    })
}

function Get-AddressCandidates {
    $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
        $_.IPAddress -and
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixLength -lt 32
    })

    return @($addresses | ForEach-Object {
        $alias = [string]$_.InterfaceAlias
        $ip = [string]$_.IPAddress
        $isPrivateLan = $ip -match "^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)"
        $isTailscale = $ip -match "^(100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)"
        $isVirtual = $alias -match "(?i)vEthernet|WSL|Docker|Loopback|VMware|VirtualBox|Hyper-V"
        [ordered]@{
            ip = $ip
            interface_alias = $alias
            prefix_length = [int]$_.PrefixLength
            prefix_origin = $_.PrefixOrigin.ToString()
            is_private_lan = [bool]$isPrivateLan
            is_tailscale = [bool]$isTailscale
            is_virtual = [bool]$isVirtual
            web_url = "http://${ip}:$WebPort"
            health_url = "http://${ip}:$ApiPort/health"
            analyze_url = "http://${ip}:$ApiPort/api/scout/analyze"
            expo_public_api_url = "http://${ip}:$ApiPort/api/scout/analyze"
        }
    })
}

$generatedAt = Get-Date
$backend = Test-WebUrl -Url $BackendHealthUrl -Json -TimeoutSec 10
$web = Test-WebUrl -Url $WebUrl -TimeoutSec 10
$webRouteUrls = @($WebUrl, "http://127.0.0.1:$WebPort", "http://[::1]:$WebPort") | Select-Object -Unique
$webRouteChecks = @($webRouteUrls | ForEach-Object { Test-WebUrl -Url $_ -TimeoutSec 10 })
$apiListeners = @(Get-PortListeners -Port $ApiPort)
$webListeners = @(Get-PortListeners -Port $WebPort)
$candidates = @(Get-AddressCandidates)

$lanChecks = @($candidates | ForEach-Object {
    $check = Test-WebUrl -Url $_.health_url -Json -TimeoutSec 3
    [ordered]@{
        ip = $_.ip
        interface_alias = $_.interface_alias
        is_private_lan = $_.is_private_lan
        is_tailscale = $_.is_tailscale
        is_virtual = $_.is_virtual
        health_url = $_.health_url
        analyze_url = $_.analyze_url
        web_url = $_.web_url
        ok = [bool]$check.ok
        provider = if ($check.body) { $check.body.provider } else { $null }
        error = $check.error
    }
})

$preferred = @($lanChecks | Where-Object { $_.ok -and $_.is_private_lan -and -not $_.is_virtual } | Select-Object -First 1)
if ($preferred.Count -eq 0) {
    $preferred = @($lanChecks | Where-Object { $_.ok -and -not $_.is_virtual } | Select-Object -First 1)
}
if ($preferred.Count -eq 0) {
    $preferred = @($lanChecks | Where-Object { $_.ok } | Select-Object -First 1)
}

$backendOk = [bool]$backend.ok -and $backend.body -and [bool]$backend.body.ok
$webOk = [bool]$web.ok
$apiListenOk = @($apiListeners).Count -gt 0
$lanOk = @($lanChecks | Where-Object { $_.ok }).Count -gt 0
$privateLanOk = @($lanChecks | Where-Object { $_.ok -and $_.is_private_lan -and -not $_.is_virtual }).Count -gt 0

$status = "pass"
$blockers = @()
$warnings = @()
if (-not $backendOk) { $blockers += "Backend health endpoint did not return ok=true." }
if (-not $webOk) { $blockers += "Web simulator URL did not return HTTP 2xx/3xx." }
if (-not $apiListenOk) { $blockers += "No listener found on API port $ApiPort." }
$webListenerOwnerCount = @($webListeners | ForEach-Object { $_["owning_process"] } | Select-Object -Unique).Count
if ($webListenerOwnerCount -gt 1) {
    $warnings += "Multiple web listener owners are bound to port $WebPort. Current routes are recorded in web_route_checks; do not assume localhost and 127.0.0.1 hit the same process."
}
if (@($webRouteChecks | Where-Object { -not $_.ok }).Count -gt 0) {
    $warnings += "At least one local web route failed. Use web_route_checks before choosing a demo URL."
}
if (-not $lanOk) { $warnings += "No LAN candidate responded to /health from this laptop; phone/glasses route may need firewall or network adjustment." }
if ($lanOk -and -not $privateLanOk) { $warnings += "Only non-private-LAN candidates responded to /health. If this is a Tailscale address, the phone must also be on Tailscale; venue Wi-Fi still needs a separate check." }
if ($RequireLan -and -not $lanOk) { $blockers += "RequireLan was set and no LAN candidate responded to /health." }
if ($blockers.Count -gt 0) {
    $status = "fail"
}
elseif ($warnings.Count -gt 0) {
    $status = "warn"
}

$recommended = if ($preferred.Count -gt 0) {
    [ordered]@{
        web_url = $preferred[0].web_url
        api_health_url = $preferred[0].health_url
        expo_public_disease_scout_api_url = $preferred[0].analyze_url
        same_host_inferred_analyze_url = $preferred[0].analyze_url
        route_type = if ($preferred[0].is_private_lan) { "private_lan" } elseif ($preferred[0].is_tailscale) { "tailscale" } else { "non_private_candidate" }
    }
}
else {
    [ordered]@{
        web_url = $WebUrl
        api_health_url = $BackendHealthUrl
        expo_public_disease_scout_api_url = $null
        same_host_inferred_analyze_url = $null
        route_type = "localhost_only"
    }
}

$result = [ordered]@{
    generated_at = $generatedAt.ToString("o")
    status = $status
    backend_health = $backend
    web = $web
    web_route_checks = @($webRouteChecks)
    api_port = $ApiPort
    web_port = $WebPort
    api_listeners = @($apiListeners)
    web_listeners = @($webListeners)
    lan_candidates = @($candidates)
    lan_health_checks = @($lanChecks)
    recommended_demo_urls = $recommended
    blockers = $blockers
    warnings = $warnings
    caveats = @(
        "A local LAN health check proves the laptop can reach its own advertised address; it does not prove the phone, venue Wi-Fi, or Windows firewall will allow inbound traffic.",
        "For the real device run, open the web_url from the phone or DAT host and verify api_health_url from that same network before claiming online analysis works.",
        "If phone routing fails, set EXPO_PUBLIC_DISEASE_SCOUT_API_URL to the recommended endpoint before starting Expo, or use the localhost laptop demo fallback."
    )
}

$outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$parent = Split-Path -Parent $outPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

Write-Output "report=$outPath"
Write-Output "status=$status"
Write-Output "backend_ok=$backendOk"
Write-Output "web_ok=$webOk"
Write-Output "api_listeners=$(@($apiListeners).Count)"
Write-Output "lan_health_ok=$lanOk"
if ($recommended.expo_public_disease_scout_api_url) {
    Write-Output "recommended_api=$($recommended.expo_public_disease_scout_api_url)"
}
foreach ($warning in $warnings) {
    Write-Output "warning=$warning"
}
foreach ($blocker in $blockers) {
    Write-Output "blocker=$blocker"
}

if ($status -eq "fail") {
    exit 1
}
