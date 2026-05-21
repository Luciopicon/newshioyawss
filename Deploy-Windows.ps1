param(
  [switch]$SkipNodeInstall
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try { $PSDefaultParameterValues['Invoke-WebRequest:UseBasicParsing'] = $true } catch {}

$NpmExe = "npm.cmd"
$VercelExe = "vercel.cmd"
$script:LastVercelAuthStatus = "unknown"

try {
  [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

function Write-Banner {
  Clear-Host
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host " XHTTPRelayECO Windows Installer by @b3hnamrjd" -ForegroundColor Cyan
  Write-Host " Telegram Channel : https://t.me/B3hnamR" -ForegroundColor Cyan
  Write-Host " GitHub : https://github.com/B3hnamR/XHTTPRelayECO" -ForegroundColor Cyan
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host ""
}

function Write-PreflightNotice {
  Write-Host "Important: connect your VPN in TUN Mode or set as `"System Proxy`" before continuing." -ForegroundColor Magenta
  Write-Host "Tip: Press Ctrl+C at any step to stop/exit." -ForegroundColor DarkYellow
}

function Write-Step([string]$Text) {
  Write-Host ""
  Write-Host ">> $Text" -ForegroundColor Yellow
}

function Read-Default([string]$Prompt, [string]$DefaultValue) {
  $raw = Read-Host "$Prompt [$DefaultValue]"
  if ([string]::IsNullOrWhiteSpace($raw)) { return $DefaultValue }
  return $raw.Trim()
}

function Read-Optional([string]$Prompt) {
  $raw = Read-Host $Prompt
  if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
  return $raw.Trim()
}

function Read-Required([string]$Prompt) {
  while ($true) {
    $raw = Read-Host $Prompt
    if (-not [string]::IsNullOrWhiteSpace($raw)) { return $raw.Trim() }
    Write-Host "Value is required." -ForegroundColor Red
  }
}

function Normalize-PathLike([string]$PathValue) {
  $p = ""
  if ($null -ne $PathValue) { $p = $PathValue.Trim() }
  if ([string]::IsNullOrWhiteSpace($p)) { return "" }
  if (-not $p.StartsWith("/")) { $p = "/$p" }
  return $p
}

function Convert-PathToVercelSource([string]$PathValue) {
  $p = Normalize-PathLike -PathValue $PathValue
  if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "/") { $p = "/api" }
  return "$p/:path*"
}

function Convert-PathToVercelSourceBase([string]$PathValue) {
  $p = Normalize-PathLike -PathValue $PathValue
  if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "/") { $p = "/api" }
  return $p
}

function Convert-PathToVercelDestination([string]$TargetDomain, [string]$PathValue) {
  $target = ([string]$TargetDomain).TrimEnd("/")
  $p = Normalize-PathLike -PathValue $PathValue
  if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "/") { $p = "/api" }
  return "$target$p/:path*"
}

function Convert-PathToVercelDestinationBase([string]$TargetDomain, [string]$PathValue) {
  $target = ([string]$TargetDomain).TrimEnd("/")
  $p = Normalize-PathLike -PathValue $PathValue
  if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "/") { $p = "/api" }
  return "$target$p"
}

function Read-YesNo([string]$Prompt, [bool]$DefaultYes = $true) {
  $def = if ($DefaultYes) { "Y/n" } else { "y/N" }
  while ($true) {
    $v = Read-Host "$Prompt ($def)"
    if ([string]::IsNullOrWhiteSpace($v)) { return $DefaultYes }
    $x = $v.Trim().ToLowerInvariant()
    if ($x -eq "y" -or $x -eq "yes") { return $true }
    if ($x -eq "n" -or $x -eq "no") { return $false }
    Write-Host "Please enter y or n." -ForegroundColor DarkYellow
  }
}

function Choose-DeploymentMode {
  Write-Host ""
  Write-Host "Choose deployment mode:" -ForegroundColor Cyan
  Write-Host "[0] Back"
  Write-Host ""
  Write-Host "[1] FAST PIPE LEGACY  (Recommended / Best compatibility / No Fluid cost)" -ForegroundColor Green
  Write-Host "    Rewrite using /path/(.*) -> upstream/path/`$1. Best first test for video/sites/apps."
  Write-Host ""
  Write-Host "[2] FAST PIPE MODERN  (Official Vercel syntax / No Fluid cost)" -ForegroundColor Green
  Write-Host "    Rewrite using /path/:path* -> upstream/path/:path*. Cleaner routing."
  Write-Host ""
  Write-Host "[3] FAST PIPE SIMPLE  (Legacy single rule / No headers / No Fluid cost)" -ForegroundColor Green
  Write-Host "    Single rewrite only: /path/(.*) -> upstream/path/`$1. No headers, no key, no base path, no fallback."
  Write-Host ""
  Write-Host "[4] FAST PIPE SIMPLE MODERN  (Modern single rule / No headers / No Fluid cost)" -ForegroundColor Green
  Write-Host "    Single rewrite only: /path/:path* -> upstream/path/:path*. No headers, no key, no base path, no fallback."
  Write-Host ""
  Write-Host "[5] BALANCED   (Node + Fluid ON)" -ForegroundColor Cyan
  Write-Host "    Lower timeout profile for normal usage. 256 conn | 5 MB/s up/down | 60s upstream | 800s function."
  Write-Host ""
  Write-Host "[6] MAX CONN   (Node + Fluid ON)" -ForegroundColor Cyan
  Write-Host "    Higher capacity profile. 512 conn | 10 MB/s up/down | 60s upstream | 800s function."
  Write-Host ""
  Write-Host "[7] CUSTOM     (Manual)" -ForegroundColor Yellow
  Write-Host "    Set runtime, Fluid, regions, CPU, duration, limits, timeout and logs yourself."
  Write-Host ""

  $choice = Read-Default "Select mode" "1"
  switch ($choice) {
    "0" {
      return @{
        Canceled = $true
        ModeKey = "__BACK__"
      }
    }
    "1" {
      return @{
        Canceled = $false
        ModeKey = "FAST_PIPE_LEGACY"
        Runtime = "rewrite"
        RewriteStyle = "legacy"
        RewriteSecurity = "optional"
        FluidEnabled = $false
        MaxInflight = ""
        MaxUpBps = ""
        MaxDownBps = ""
        UpstreamTimeoutMs = "30000"
        FunctionTimeoutSec = 0
        FunctionCpu = ""
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "7" {
      $runtimePick = Read-Default "Runtime type (node/rewrite, 0 = Back)" "node"
      if ($runtimePick.Trim() -eq "0") {
        return @{ Canceled = $true; ModeKey = "__BACK__" }
      }
      $runtimeType = if ($runtimePick.Trim().ToLowerInvariant() -eq "rewrite") { "rewrite" } else { "node" }
      $rewriteStyle = ""
      $rewriteSecurity = ""
      if ($runtimeType -eq "rewrite") {
        Write-Host ""
        Write-Host "Custom rewrite routing:" -ForegroundColor Cyan
        Write-Host "[1] Legacy         | /path/(.*) -> upstream/path/`$1"
        Write-Host "[2] Modern         | /path/:path* -> upstream/path/:path*"
        Write-Host "[3] Simple         | single /path/(.*) -> upstream/path/`$1"
        Write-Host "[4] Simple Modern  | single /path/:path* -> upstream/path/:path*"
        Write-Host "[0] Back"
        $routePick = Read-Default "Select rewrite routing" "1"
        if ($routePick -eq "0") {
          return @{ Canceled = $true; ModeKey = "__BACK__" }
        }
        $rewriteStyle = if ($routePick -eq "2") { "modern" } elseif ($routePick -eq "3") { "simplelegacy" } elseif ($routePick -eq "4") { "simplemodern" } else { "legacy" }
        $rewriteSecurity = "optional"
      }
      $fluidEnabled = $false
      $maxInflight = ""
      $maxUpBps = ""
      $maxDownBps = ""
      $upstreamTimeout = "30000"
      $fnTimeout = 0
      $functionCpu = ""
      if ($runtimeType -eq "node") {
        $fluidEnabled = Read-YesNo -Prompt "Enable Fluid Compute for this build" -DefaultYes $true
        $functionCpu = Choose-FunctionCpu -FluidEnabled $fluidEnabled
        if ($functionCpu -eq "__BACK__") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $maxInflight = Read-Required "MAX_INFLIGHT (example: 256, 0 = Back)"
        if ($maxInflight -eq "0") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $maxUpBps = Read-Required "MAX_UP_BPS (bytes/sec, example: 5242880, 0 = Back)"
        if ($maxUpBps -eq "0") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $maxDownBps = Read-Required "MAX_DOWN_BPS (bytes/sec, example: 5242880, 0 = Back)"
        if ($maxDownBps -eq "0") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $upstreamTimeout = Read-Default "UPSTREAM_TIMEOUT_MS (ms)" "60000"
        if ($upstreamTimeout -eq "0") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $durationRange = if ($fluidEnabled) { "30..800" } else { "30..300" }
        $fnTimeoutRaw = Read-Default ("Function Max Duration seconds ({0}, 0 = Back)" -f $durationRange) "300"
        if ($fnTimeoutRaw -eq "0") { return @{ Canceled = $true; ModeKey = "__BACK__" } }
        $fnTimeout = [int]$fnTimeoutRaw
      }
      return @{
        Canceled = $false
        ModeKey = "CUSTOM_BUILD"
        Runtime = $runtimeType
        RewriteStyle = $rewriteStyle
        RewriteSecurity = $rewriteSecurity
        FluidEnabled = $fluidEnabled
        MaxInflight = $maxInflight
        MaxUpBps = $maxUpBps
        MaxDownBps = $maxDownBps
        UpstreamTimeoutMs = $upstreamTimeout
        FunctionTimeoutSec = $fnTimeout
        FunctionCpu = $functionCpu
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "2" {
      return @{
        Canceled = $false
        ModeKey = "FAST_PIPE_MODERN"
        Runtime = "rewrite"
        RewriteStyle = "modern"
        RewriteSecurity = "optional"
        FluidEnabled = $false
        MaxInflight = ""
        MaxUpBps = ""
        MaxDownBps = ""
        UpstreamTimeoutMs = "30000"
        FunctionTimeoutSec = 0
        FunctionCpu = ""
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "3" {
      return @{
        Canceled = $false
        ModeKey = "FAST_PIPE_SIMPLE"
        Runtime = "rewrite"
        RewriteStyle = "simplelegacy"
        RewriteSecurity = "optional"
        FluidEnabled = $false
        MaxInflight = ""
        MaxUpBps = ""
        MaxDownBps = ""
        UpstreamTimeoutMs = "30000"
        FunctionTimeoutSec = 0
        FunctionCpu = ""
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "4" {
      return @{
        Canceled = $false
        ModeKey = "FAST_PIPE_SIMPLE_MODERN"
        Runtime = "rewrite"
        RewriteStyle = "simplemodern"
        RewriteSecurity = "optional"
        FluidEnabled = $false
        MaxInflight = ""
        MaxUpBps = ""
        MaxDownBps = ""
        UpstreamTimeoutMs = "30000"
        FunctionTimeoutSec = 0
        FunctionCpu = ""
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "5" {
      return @{
        Canceled = $false
        ModeKey = "BALANCED_LOW_TIMEOUT"
        Runtime = "node"
        RewriteStyle = ""
        RewriteSecurity = ""
        FluidEnabled = $true
        MaxInflight = "256"
        MaxUpBps = "5242880"
        MaxDownBps = "5242880"
        UpstreamTimeoutMs = "60000"
        FunctionTimeoutSec = 800
        FunctionCpu = "standard"
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    "6" {
      return @{
        Canceled = $false
        ModeKey = "MAX_STABILITY_HIGH_CONN"
        Runtime = "node"
        RewriteStyle = ""
        RewriteSecurity = ""
        FluidEnabled = $true
        MaxInflight = "512"
        MaxUpBps = "10485760"
        MaxDownBps = "10485760"
        UpstreamTimeoutMs = "60000"
        FunctionTimeoutSec = 800
        FunctionCpu = "standard"
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
    default {
      return @{
        Canceled = $false
        ModeKey = "FAST_PIPE_LEGACY"
        Runtime = "rewrite"
        RewriteStyle = "legacy"
        RewriteSecurity = "optional"
        FluidEnabled = $false
        MaxInflight = ""
        MaxUpBps = ""
        MaxDownBps = ""
        UpstreamTimeoutMs = "30000"
        FunctionTimeoutSec = 0
        FunctionCpu = ""
        RunStressAfterDeploy = $false
        RequireRelayKey = $false
      }
    }
  }
}

function Get-UpstreamHostFromDomain([string]$TargetDomain) {
  if ([string]::IsNullOrWhiteSpace($TargetDomain)) { return "" }
  $raw = $TargetDomain.Trim()
  try {
    $u = [uri]$raw
    if ($null -ne $u -and -not [string]::IsNullOrWhiteSpace($u.Host)) { return $u.Host }
  } catch {}
  # Fallback: user may enter domain:port without scheme.
  try {
    if (-not ($raw -match '^[a-zA-Z][a-zA-Z0-9+\-.]*://')) {
      $u2 = [uri]("https://$raw")
      if ($null -ne $u2 -and -not [string]::IsNullOrWhiteSpace($u2.Host)) { return $u2.Host }
    }
  } catch {}
  return ""
}

function Get-UpstreamIpv4Candidates([string]$HostName) {
  $result = [ordered]@{
    Local  = @()
    Public = @()
    All    = @()
  }
  if ([string]::IsNullOrWhiteSpace($HostName)) { return $result }

  $local = New-Object System.Collections.Generic.List[string]
  $public = New-Object System.Collections.Generic.List[string]
  $all = New-Object System.Collections.Generic.List[string]

  $addUnique = {
    param([System.Collections.Generic.List[string]]$list, [string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    $v = $value.Trim()
    if (-not $list.Contains($v)) { [void]$list.Add($v) }
  }

  try {
    $ips = [System.Net.Dns]::GetHostAddresses($HostName)
    foreach ($ip in $ips) {
      if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
        $s = [string]$ip.IPAddressToString
        & $addUnique $local $s
        & $addUnique $all $s
      }
    }
  } catch {}

  $dnsServers = @("1.1.1.1", "8.8.8.8", "9.9.9.9")
  foreach ($dns in $dnsServers) {
    try {
      $records = Resolve-DnsName -Name $HostName -Type A -Server $dns -ErrorAction Stop
      foreach ($r in $records) {
        if ($null -ne $r.IPAddress -and -not [string]::IsNullOrWhiteSpace([string]$r.IPAddress)) {
          $s = [string]$r.IPAddress
          & $addUnique $public $s
          & $addUnique $all $s
        }
      }
    } catch {}
  }

  $result.Local = @($local.ToArray())
  $result.Public = @($public.ToArray())
  $result.All = @($all.ToArray())
  return $result
}

function Suggest-RegionFromCountry([string]$CountryName) {
  if ([string]::IsNullOrWhiteSpace($CountryName)) { return "iad1" }
  $c = $CountryName.ToLowerInvariant()
  if ($c -match "germany|france|netherlands|belgium|sweden|poland|switzerland|austria|europe") { return "fra1" }
  if ($c -match "united kingdom|ireland") { return "lhr1" }
  if ($c -match "india|pakistan|uae|turkey|iran|qatar|saudi") { return "fra1" }
  if ($c -match "japan|singapore|korea|hong kong") { return "hnd1" }
  return "iad1"
}

function Try-ResolveCountryFromIp([string]$IpAddress) {
  if ([string]::IsNullOrWhiteSpace($IpAddress)) { return "" }
  try {
    $url = "https://ipwho.is/$IpAddress"
    $resp = Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 6
    if ($null -ne $resp -and $resp.success -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$resp.country)) {
      return [string]$resp.country
    }
  } catch {}
  return ""
}

function Get-FunctionRegionCatalog {
  return @(
    [pscustomobject]@{ Code = "cdg1"; Label = "Paris, France (West)"; Detail = "Europe West / eu-west-3" },
    [pscustomobject]@{ Code = "arn1"; Label = "Stockholm, Sweden (North)"; Detail = "Europe North / eu-north-1" },
    [pscustomobject]@{ Code = "dub1"; Label = "Dublin, Ireland (West)"; Detail = "Europe West / eu-west-1" },
    [pscustomobject]@{ Code = "lhr1"; Label = "London, United Kingdom (West)"; Detail = "Europe West / eu-west-2" },
    [pscustomobject]@{ Code = "fra1"; Label = "Frankfurt, Germany (West)"; Detail = "Europe Central / eu-central-1" },
    [pscustomobject]@{ Code = "iad1"; Label = "Washington, D.C., USA (East)"; Detail = "US East / us-east-1" },
    [pscustomobject]@{ Code = "dxb1"; Label = "Dubai, United Arab Emirates (East)"; Detail = "Middle East Central / me-central-1" }
  )
}

function Normalize-RegionList([string]$RegionText) {
  if ([string]::IsNullOrWhiteSpace($RegionText)) { return @() }
  $items = @()
  foreach ($part in ($RegionText -split '[,\s]+')) {
    $p = ([string]$part).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $items += $p
  }
  return @($items | Select-Object -Unique)
}

function Choose-FunctionCpu([bool]$FluidEnabled) {
  Write-Host ""
  Write-Host "Choose Function CPU:" -ForegroundColor Cyan
  if ($FluidEnabled) {
    Write-Host "[0] Back"
    Write-Host "[1] Standard    | 1 vCPU, 2 GB memory | predictable production workloads"
    Write-Host "[2] Performance | 2 vCPUs, 4 GB memory | latency-sensitive and SSR workloads"
    $pick = Read-Default "Select CPU" "1"
    switch ($pick) {
      "0" { return "__BACK__" }
      "2" { return "performance" }
      default { return "standard" }
    }
  }

  Write-Host "[0] Back"
  Write-Host "[1] Basic       | 0.6 vCPU, 1 GB memory | cost-effective lightweight apps and APIs"
  Write-Host "[2] Standard    | 1 vCPU, 1.7 GB memory | predictable production workloads"
  Write-Host "[3] Performance | 1.7 vCPUs, 3 GB memory | latency-sensitive and SSR workloads"
  $pickNoFluid = Read-Default "Select CPU" "2"
  switch ($pickNoFluid) {
    "0" { return "__BACK__" }
    "1" { return "standard_legacy" }
    "3" { return "performance" }
    default { return "standard" }
  }
}

function Choose-FunctionRegion([string]$TargetDomain) {
  $defaultRegion = "iad1"
  $upHost = Get-UpstreamHostFromDomain -TargetDomain $TargetDomain
  if (-not [string]::IsNullOrWhiteSpace($upHost)) {
    $resolved = Get-UpstreamIpv4Candidates -HostName $upHost
    $localIps = @()
    $publicIps = @()
    $allIps = @()
    if ($null -ne $resolved.Local) { $localIps = @($resolved.Local) }
    if ($null -ne $resolved.Public) { $publicIps = @($resolved.Public) }
    if ($null -ne $resolved.All) { $allIps = @($resolved.All) }

    $hintIp = ""
    if ($publicIps.Count -gt 0) { $hintIp = [string]$publicIps[0] }
    elseif ($allIps.Count -gt 0) { $hintIp = [string]$allIps[0] }

    if ($allIps.Count -gt 0) {
      Write-Host ("Auto hint: DNS A records for '{0}' => {1}" -f $upHost, ($allIps -join ", ")) -ForegroundColor DarkGray
    }
    if ($localIps.Count -gt 0 -and $publicIps.Count -gt 0 -and ([string]$localIps[0] -ne [string]$publicIps[0])) {
      Write-Host ("Auto hint warning: local DNS resolves to {0} but public resolver resolves to {1}. Region suggestion will use public DNS." -f $localIps[0], $publicIps[0]) -ForegroundColor Yellow
    }

    $country = Try-ResolveCountryFromIp -IpAddress $hintIp
    if (-not [string]::IsNullOrWhiteSpace($country)) {
      $defaultRegion = Suggest-RegionFromCountry -CountryName $country
      Write-Host ("Auto hint: using IP {0} ({1}) -> suggested region '{2}'." -f $hintIp, $country, $defaultRegion) -ForegroundColor DarkCyan
    } elseif (-not [string]::IsNullOrWhiteSpace($hintIp)) {
      Write-Host ("Auto hint fallback: host '{0}' -> {1}, but country lookup failed (ipwho.is blocked/timeout). Using '{2}'." -f $upHost, $hintIp, $defaultRegion) -ForegroundColor DarkGray
    } else {
      Write-Host ("Auto hint fallback: DNS lookup failed for host '{0}'. Using '{1}'." -f $upHost, $defaultRegion) -ForegroundColor DarkGray
    }
  } else {
    Write-Host ("Auto hint fallback: could not parse host from TARGET_DOMAIN ('{0}'). Use full format like https://domain:port. Using '{1}'." -f $TargetDomain, $defaultRegion) -ForegroundColor DarkGray
  }

  $catalog = Get-FunctionRegionCatalog
  Write-Host ""
  Write-Host "Choose Vercel Function Region(s). You can enter multiple numbers/codes separated by comma." -ForegroundColor Cyan
  for ($i = 0; $i -lt $catalog.Count; $i++) {
    $r = $catalog[$i]
    $tag = if ($r.Code -eq $defaultRegion) { " (suggested)" } else { "" }
    Write-Host ("[{0}] {1} - {2} - {3}{4}" -f ($i + 1), $r.Label, $r.Detail, $r.Code, $tag)
  }
  Write-Host "[C] Custom region code(s)"
  $pick = Read-Default ("Select region(s)" ) $defaultRegion
  $regions = @()
  if ($pick.Trim().ToLowerInvariant() -eq "c") {
    $regions = Normalize-RegionList (Read-Required "Custom region code(s), comma-separated (example: arn1,fra1)")
  } else {
    foreach ($part in ($pick -split '[,\s]+')) {
      $p = ([string]$part).Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($p)) { continue }
      $n = 0
      if ([int]::TryParse($p, [ref]$n) -and $n -ge 1 -and $n -le $catalog.Count) {
        $regions += [string]$catalog[$n - 1].Code
      } else {
        $regions += $p
      }
    }
  }
  if ($regions.Count -eq 0) { $regions = @($defaultRegion) }
  return (@($regions | Select-Object -Unique) -join ",")
}

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

function Get-TokenStorePath([string]$ProjectRoot) {
  return (Join-Path $ProjectRoot ".vercel-token.dpapi")
}

function Get-ScopeStorePath([string]$ProjectRoot) {
  return (Join-Path $ProjectRoot ".vercel-scope.txt")
}

function Get-ProjectStateStorePath([string]$ProjectRoot) {
  return (Join-Path $ProjectRoot ".xhttprelay-project-state.json")
}

function Load-LocalProjectDeployState([string]$ProjectName) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { return $null }
  $path = Get-ProjectStateStorePath -ProjectRoot $scriptDir
  if (-not (Test-Path $path)) { return $null }
  try {
    $raw = Get-Content -Path $path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj -or $null -eq $obj.projects) { return $null }
    return @($obj.projects | Where-Object { [string]$_.ProjectName -eq $ProjectName } | Select-Object -First 1)
  } catch {
    return $null
  }
}

function Save-LocalProjectDeployState([string]$ProjectName, [string]$Scope, [string]$DeployMode, [string]$Runtime, [string]$RelayPath) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { return }
  $path = Get-ProjectStateStorePath -ProjectRoot $scriptDir
  $projects = @()
  if (Test-Path $path) {
    try {
      $raw = Get-Content -Path $path -Raw
      if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $obj = $raw | ConvertFrom-Json
        if ($null -ne $obj -and $null -ne $obj.projects) {
          $projects = @($obj.projects | Where-Object { [string]$_.ProjectName -ne $ProjectName })
        }
      }
    } catch {
      $projects = @()
    }
  }
  $projects += [pscustomobject]@{
    ProjectName = $ProjectName
    Scope = $Scope
    DeployMode = $DeployMode
    Runtime = $Runtime
    RelayPath = $RelayPath
    UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  }
  $state = [ordered]@{ projects = @($projects | Sort-Object ProjectName) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, ($state | ConvertTo-Json -Depth 20), $utf8NoBom)
}

function Save-Scope([string]$Scope, [string]$Path) {
  $value = ""
  if ($null -ne $Scope) { $value = $Scope.Trim() }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $value, $utf8NoBom)
}

function Load-Scope([string]$Path) {
  if (-not (Test-Path $Path)) { return "" }
  try {
    $raw = Get-Content $Path -Raw
    if ($null -eq $raw) { return "" }
    return $raw.Trim()
  } catch {
    return ""
  }
}

function Get-VercelTeamSlugs {
  $args = @("teams", "ls", "--no-color")
  $args += (Get-VercelTokenArgs)
  $result = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  if ($result.ExitCode -ne 0) { return @() }
  $slugs = @()
  foreach ($line in $result.Output) {
    $trim = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trim)) { continue }
    if ($trim -match '^(Fetching|ID|Name|Slug|Teams|Visit|Error:|Warning:)') { continue }
    if ($trim.StartsWith(">")) { continue }
    $parts = $trim -split '\s+'
    if ($parts.Count -ge 1) {
      $candidate = $parts[0]
      if ($candidate -match '^[a-zA-Z0-9][a-zA-Z0-9\-_]+$') {
        $slugs += $candidate
      }
    }
  }
  return @($slugs | Sort-Object -Unique)
}

function Normalize-ScopeForCli([string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($Scope)) { return "" }
  $s = $Scope.Trim()
  # Vercel CLI scope expects team slug, not orgId like team_xxx.
  if ($s.StartsWith("team_")) { return "" }
  return $s
}

function Validate-Scope([string]$Scope) {
  $s = Normalize-ScopeForCli -Scope $Scope
  if ([string]::IsNullOrWhiteSpace($s)) { return $true }
  $slugs = Get-VercelTeamSlugs
  if ($slugs.Count -eq 0) { return $true }
  return ($slugs -contains $s)
}

function Save-TokenSecure([string]$Token, [string]$Path) {
  $secure = ConvertTo-SecureString -String $Token -AsPlainText -Force
  $text = ConvertFrom-SecureString -SecureString $secure
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $text, $utf8NoBom)
}

function Load-TokenSecure([string]$Path) {
  if (-not (Test-Path $Path)) { return "" }
  try {
    $text = (Get-Content $Path -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $secure = ConvertTo-SecureString -String $text
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
      return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  } catch {
    return ""
  }
}

function Invoke-NativeSafe {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [int]$TimeoutSec = 600
  )

  # PowerShell 5.1-compatible argument handling
  $escaped = $Arguments | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '"', '\"') + '"'
    } else {
      $_
    }
  }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.WorkingDirectory = (Get-Location).Path
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
  $psi.Arguments = ($escaped -join ' ')

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
  $stderrTask = $proc.StandardError.ReadToEndAsync()
  $timeoutMs = [Math]::Max(1, $TimeoutSec) * 1000
  $finished = $proc.WaitForExit($timeoutMs)
  if (-not $finished) {
    try { $proc.Kill() } catch {}
    try { $proc.WaitForExit() } catch {}
    $safeArgs = @()
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
      if ($i -gt 0 -and [string]$Arguments[$i - 1] -eq "--token") {
        $safeArgs += "***"
      } elseif (-not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN) -and [string]$Arguments[$i] -eq [string]$env:VERCEL_TOKEN) {
        $safeArgs += "***"
      } else {
        $safeArgs += [string]$Arguments[$i]
      }
    }
    $stdout = ""
    $stderr = ""
    try { $stdout = $stdoutTask.GetAwaiter().GetResult() } catch {}
    try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch {}
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { $lines += ($stdout -split "`r?`n" | Where-Object { $_ -ne "" }) }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { $lines += ($stderr -split "`r?`n" | Where-Object { $_ -ne "" }) }
    $lines += "Command timed out after $TimeoutSec seconds: $FilePath $($safeArgs -join ' ')"
    return @{
      Output = @($lines)
      ExitCode = 124
    }
  }

  $proc.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  $lines = @()
  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    $lines += ($stdout -split "`r?`n" | Where-Object { $_ -ne "" })
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    $lines += ($stderr -split "`r?`n" | Where-Object { $_ -ne "" })
  }

  return @{
    Output = @($lines)
    ExitCode = $proc.ExitCode
  }
}

function Invoke-NativeSafeWithInput {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$InputText = "",
    [int]$TimeoutSec = 120
  )

  $escaped = $Arguments | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '"', '\"') + '"'
    } else {
      $_
    }
  }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.WorkingDirectory = (Get-Location).Path
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
  $psi.Arguments = ($escaped -join ' ')

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
  $stderrTask = $proc.StandardError.ReadToEndAsync()
  if (-not [string]::IsNullOrEmpty($InputText)) {
    $proc.StandardInput.WriteLine($InputText)
  }
  $proc.StandardInput.Close()

  $timeoutMs = [Math]::Max(1, $TimeoutSec) * 1000
  $finished = $proc.WaitForExit($timeoutMs)
  if (-not $finished) {
    try { $proc.Kill() } catch {}
    try { $proc.WaitForExit() } catch {}
    $stdout = ""
    $stderr = ""
    try { $stdout = $stdoutTask.GetAwaiter().GetResult() } catch {}
    try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch {}
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { $lines += ($stdout -split "`r?`n" | Where-Object { $_ -ne "" }) }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { $lines += ($stderr -split "`r?`n" | Where-Object { $_ -ne "" }) }
    $lines += "Command timed out after $TimeoutSec seconds."
    return @{
      Output = @($lines)
      ExitCode = 124
    }
  }

  $proc.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  $lines = @()
  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    $lines += ($stdout -split "`r?`n" | Where-Object { $_ -ne "" })
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    $lines += ($stderr -split "`r?`n" | Where-Object { $_ -ne "" })
  }

  return @{
    Output = @($lines)
    ExitCode = $proc.ExitCode
  }
}

function Get-VercelTokenArgs {
  if (-not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
    return @("--token", $env:VERCEL_TOKEN)
  }
  return @()
}

function New-RandomProjectName {
  $chars = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
  $suffix = -join (1..8 | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
  return "relay-$suffix"
}

function Ensure-NodeAndNpm {
  if (Get-Command $NpmExe -ErrorAction SilentlyContinue) {
    Write-Host "npm already installed." -ForegroundColor Green
    return
  }

  if ($SkipNodeInstall) {
    throw "npm is missing and -SkipNodeInstall was used."
  }

  if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install Node.js LTS manually and run again."
  }

  Write-Step "Installing Node.js LTS (npm included) via winget..."
  winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
  Refresh-Path

  if (-not (Get-Command $NpmExe -ErrorAction SilentlyContinue)) {
    throw "Node.js installation finished but npm is still not detected. Re-open PowerShell and retry."
  }
}

function Ensure-VercelCli {
  if (Get-Command $VercelExe -ErrorAction SilentlyContinue) {
    Write-Host "Vercel CLI already installed." -ForegroundColor Green
    return
  }

  Write-Step "Installing Vercel CLI..."
  & $NpmExe i -g vercel | Out-Host
  Refresh-Path
  if (-not (Get-Command $VercelExe -ErrorAction SilentlyContinue)) {
    throw "vercel command not found after installation."
  }
}

function Start-VercelOobLogin([string]$OutputDir) {
  Write-Host "Starting manual device login (no auto browser)..." -ForegroundColor Yellow
  $prevBrowser = $env:BROWSER
  $env:BROWSER = "none"
  try {
    $loginResult = Invoke-NativeSafe -FilePath $VercelExe -Arguments @("login", "--oob", "--no-color")
  } finally {
    if ($null -eq $prevBrowser) {
      Remove-Item Env:\BROWSER -ErrorAction SilentlyContinue
    } else {
      $env:BROWSER = $prevBrowser
    }
  }
  $loginResult.Output | Out-Host
  if ($loginResult.ExitCode -ne 0) {
    throw "vercel login failed."
  }

  $urls = @()
  foreach ($line in $loginResult.Output) {
    $matches = [regex]::Matches($line, 'https?://[^\s\)\]]+')
    foreach ($m in $matches) {
      if ($m.Value -match 'vercel\.com/(oauth/device|device)') {
        $urls += $m.Value
      }
    }
  }
  $urls = $urls | Select-Object -Unique

  if ($urls.Count -gt 0) {
    $txtPath = Join-Path $OutputDir "vercel-login-link.txt"
    $content = @(
      "Vercel Login Links"
      "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
      ""
    ) + $urls
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($txtPath, $content, $utf8NoBom)

    Write-Host ""
    Write-Host "Manual login URL(s):" -ForegroundColor Cyan
    $urls | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
    Write-Host "Saved to: $txtPath" -ForegroundColor Cyan
  } else {
    Write-Host "No explicit login URL found in output. If prompted, use: https://vercel.com/device" -ForegroundColor DarkYellow
  }
}

function Ensure-VercelLogin([string]$OutputDir, [string]$TokenStorePath) {
  Write-Step "Checking Vercel login..."

  Write-Host "Choose auth mode:" -ForegroundColor Cyan
  Write-Host "[1] Use existing login session (default)"
  Write-Host "[2] Token mode (recommended: never opens browser, supports secure save)"
  $authMode = Read-Default "Select auth mode" "1"

  if ($authMode -eq "2" -or $authMode -eq "3") {
    $token = ""
    $saved = Load-TokenSecure -Path $TokenStorePath
    if (-not [string]::IsNullOrWhiteSpace($saved)) {
      $useSaved = Read-Default "Use saved encrypted token from project folder? (Y/n)" "y"
      if ($useSaved.ToLowerInvariant() -ne "n") {
        $token = $saved
        Write-Host "Using saved encrypted token." -ForegroundColor Green
      }
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
      $token = Read-Required "Paste Vercel token (create from Vercel dashboard -> Settings -> Tokens)"
      $saveNow = Read-Default "Save token encrypted in this project folder? (Y/n)" "y"
      if ($saveNow.ToLowerInvariant() -ne "n") {
        Save-TokenSecure -Token $token -Path $TokenStorePath
        Write-Host "Token saved securely: $TokenStorePath" -ForegroundColor Green
      }
    }

    # Normalize token input: avoid hidden spaces/newlines/quotes from copy-paste
    $token = ([string]$token).Trim().Trim('"').Trim("'")
    $env:VERCEL_TOKEN = $token

    # Auth check strategy (robust):
    # 1) API direct check (most reliable)
    # 2) CLI whoami --token
    # 3) CLI whoami (uses VERCEL_TOKEN from env)
    $apiOk = $false
    $apiErr = ""
    try {
      $apiUser = Invoke-RestMethod -Method Get -Uri "https://api.vercel.com/v2/user" -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 15
      if ($null -ne $apiUser -and $null -ne $apiUser.user -and -not [string]::IsNullOrWhiteSpace([string]$apiUser.user.id)) {
        $apiOk = $true
      }
    } catch {
      $apiErr = $_.Exception.Message
    }

    $tokenWhoami = Invoke-NativeSafe -FilePath $VercelExe -Arguments @("whoami", "--token", $token)
    $envWhoami = Invoke-NativeSafe -FilePath $VercelExe -Arguments @("whoami")

    $cliOk = ($tokenWhoami.ExitCode -eq 0 -or $envWhoami.ExitCode -eq 0)
    if (-not $apiOk -and -not $cliOk) {
      Write-Host "Token auth failed." -ForegroundColor Red
      $raw = (($tokenWhoami.Output + $envWhoami.Output) | Out-String).Trim()
      if (-not [string]::IsNullOrWhiteSpace($raw)) {
        Write-Host "Vercel response (short):" -ForegroundColor DarkYellow
        $raw.Split("`n") | Select-Object -First 5 | ForEach-Object { Write-Host (" - {0}" -f ($_.Trim())) -ForegroundColor DarkYellow }
      }
      if (-not [string]::IsNullOrWhiteSpace($apiErr)) {
        Write-Host ("API response (short): {0}" -f $apiErr) -ForegroundColor DarkYellow
      }
      Write-Host ""
      Write-Host "How to fix:" -ForegroundColor Cyan
      Write-Host " 1) Create a NEW Full Access token in Vercel Dashboard > Settings > Tokens"
      Write-Host " 2) Paste token again carefully (no extra space/newline)"
      Write-Host " 3) If team project: ensure correct scope/team slug"
      throw "Token auth failed. Please create a new token and retry."
    }
    if ($apiOk -and $tokenWhoami.ExitCode -ne 0 -and $envWhoami.ExitCode -ne 0) {
      Write-Host "Token validated by API. Continuing (CLI whoami check skipped)." -ForegroundColor Green
    } elseif ($tokenWhoami.ExitCode -eq 0) {
      $tokenWhoami.Output | Out-Host
    } elseif ($envWhoami.ExitCode -eq 0) {
      $envWhoami.Output | Out-Host
    } else {
      Write-Host "Token validated." -ForegroundColor Green
    }
    return
  }

  $whoamiResult = Invoke-NativeSafe -FilePath $VercelExe -Arguments @("whoami")
  $loggedIn = $whoamiResult.ExitCode -eq 0

  if ($authMode -eq "1" -and $loggedIn) {
    $whoamiResult.Output | Out-Host
    $useCurrent = Read-Default "Use current logged-in session? (Y/n)" "y"
    if ($useCurrent.ToLowerInvariant() -eq "n") {
      Write-Step "Logging out and creating a fresh login link..."
      $logoutResult = Invoke-NativeSafe -FilePath $VercelExe -Arguments @("logout")
      $logoutResult.Output | Out-Host
      Start-VercelOobLogin -OutputDir $OutputDir
    }
  } else {
    Start-VercelOobLogin -OutputDir $OutputDir
  }

  & $VercelExe whoami | Out-Host
}

function Resolve-SessionScope([string]$ScopeStorePath) {
  $savedScope = Normalize-ScopeForCli -Scope (Load-Scope -Path $ScopeStorePath)
  if (-not [string]::IsNullOrWhiteSpace($savedScope)) {
    if (-not (Validate-Scope -Scope $savedScope)) {
      Write-Host "Saved scope '$savedScope' is invalid and will be ignored." -ForegroundColor Red
      Save-Scope -Scope "" -Path $ScopeStorePath
      $savedScope = ""
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($savedScope)) {
    $useSaved = Read-Default ("Use saved scope/team '{0}'? (Y/n)" -f $savedScope) "y"
    if ($useSaved.ToLowerInvariant() -ne "n") {
      return $savedScope
    }
  }

  Write-Host ""
  Write-Host "Scope note: enter your Vercel team slug to avoid wrong CLI context." -ForegroundColor DarkYellow
  $teams = Get-VercelTeamSlugs
  if ($teams.Count -gt 0) {
    Write-Host "Detected team slugs: $($teams -join ', ')" -ForegroundColor Cyan
  }
  while ($true) {
    $scopeInput = Read-Optional "Scope slug/team (optional, press Enter for personal account)"
    $scope = Normalize-ScopeForCli -Scope $scopeInput
    if ([string]::IsNullOrWhiteSpace($scope)) {
      Save-Scope -Scope "" -Path $ScopeStorePath
      return ""
    }
    if (Validate-Scope -Scope $scope) {
      Save-Scope -Scope $scope -Path $ScopeStorePath
      return $scope
    }
    Write-Host "Scope '$scope' does not exist. Enter a valid team slug or press Enter for personal account." -ForegroundColor Red
  }
}

function Ensure-VercelProject([string]$ProjectName, [string]$Scope) {
  Write-Step "Creating project (or reusing if already exists)..."
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("project", "add", $ProjectName)
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $args += (Get-VercelTokenArgs)

  $result = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  $output = $result.Output
  $text = $output | Out-String
  if ($result.ExitCode -ne 0 -and ($text -notmatch "already exists")) {
    if (-not [string]::IsNullOrWhiteSpace($Scope) -and $text -match "(?i)(scope does not exist|specified scope does not exist|invalid scope|scope-not-existent)") {
      Write-Host "Scope '$Scope' is invalid/unavailable. Retrying with personal account context..." -ForegroundColor DarkYellow
      $retry = Invoke-NativeSafe -FilePath $VercelExe -Arguments (@("project", "add", $ProjectName) + (Get-VercelTokenArgs))
      $retry.Output | Out-Host
      if ($retry.ExitCode -eq 0 -or (($retry.Output | Out-String) -match "already exists")) {
        return
      }
    }
    throw "vercel project add failed: $text"
  }
  $output | Out-Host
}

function Resolve-ProjectScopeForLink([string]$ProjectName) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { return "" }
  $token = [string]$env:VERCEL_TOKEN
  if ([string]::IsNullOrWhiteSpace($token)) { return "" }
  try {
    $path = "/v9/projects?name=$([uri]::EscapeDataString($ProjectName))&limit=20"
    $resp = Invoke-VercelApiGet -Path $path -Token $token -Scope ""
    if ($null -eq $resp -or $null -eq $resp.projects) { return "" }
    $hit = $resp.projects | Where-Object { [string]$_.name -eq $ProjectName } | Select-Object -First 1
    if ($null -eq $hit) { return "" }

    $accountId = ""
    if ($hit.PSObject.Properties.Name -contains "accountId" -and $hit.accountId) {
      $accountId = [string]$hit.accountId
    }
    if ([string]::IsNullOrWhiteSpace($accountId)) { return "" }
    if ($accountId.StartsWith("team_")) {
      $slug = Try-ResolveTeamSlugFromTeamId -TeamId $accountId -Token $token
      if (-not [string]::IsNullOrWhiteSpace($slug)) { return $slug }
      return $accountId
    }
    return ""
  } catch {
    return ""
  }
}

function Clear-LocalVercelProjectLink([string]$ProjectRoot) {
  $projectFile = Join-Path $ProjectRoot ".vercel\project.json"
  if (Test-Path $projectFile) {
    Remove-Item -LiteralPath $projectFile -Force -ErrorAction SilentlyContinue
  }
}

function Write-LocalVercelProjectLink([string]$ProjectName, [string]$ProjectId, [string]$OrgId, [string]$ProjectRoot) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { throw "Project name is required for local link." }
  if ([string]::IsNullOrWhiteSpace($ProjectId)) { throw "Project id is required for local link." }
  if ([string]::IsNullOrWhiteSpace($OrgId)) { throw "Org/account id is required for local link." }

  $vercelDir = Join-Path $ProjectRoot ".vercel"
  if (-not (Test-Path $vercelDir)) {
    New-Item -ItemType Directory -Path $vercelDir | Out-Null
  }
  $projectFile = Join-Path $vercelDir "project.json"
  $obj = [ordered]@{
    projectId = $ProjectId
    orgId = $OrgId
    projectName = $ProjectName
  }
  $json = $obj | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($projectFile, $json, $utf8NoBom)
  Write-Host ("Local .vercel link rebuilt from token/API: {0}" -f $ProjectName) -ForegroundColor Green
}

function Link-VercelProject([string]$ProjectName, [string]$Scope) {
  Write-Step "Linking local folder to Vercel project..."
  $Scope = Normalize-ScopeForCli -Scope $Scope
  Clear-LocalVercelProjectLink -ProjectRoot $scriptDir
  $args = @("link", "--yes", "--project", $ProjectName)
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $args += (Get-VercelTokenArgs)

  $res = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  $res.Output | Out-Host
  if ($res.ExitCode -eq 0) { return }

  # Fallback: resolve owner scope from API and retry.
  $resolvedScope = Normalize-ScopeForCli -Scope (Resolve-ProjectScopeForLink -ProjectName $ProjectName)
  if (-not [string]::IsNullOrWhiteSpace($resolvedScope) -and $resolvedScope -ne $Scope) {
    Write-Host "Link retry with resolved scope '$resolvedScope'..." -ForegroundColor DarkYellow
    $retryArgs = @("link", "--yes", "--project", $ProjectName, "--scope", $resolvedScope) + (Get-VercelTokenArgs)
    $retry = Invoke-NativeSafe -FilePath $VercelExe -Arguments $retryArgs
    $retry.Output | Out-Host
    if ($retry.ExitCode -eq 0) { return }
  }

  Write-Host "Link final retry without explicit scope..." -ForegroundColor DarkYellow
  $retryNoScopeArgs = @("link", "--yes", "--project", $ProjectName) + (Get-VercelTokenArgs)
  $retryNoScope = Invoke-NativeSafe -FilePath $VercelExe -Arguments $retryNoScopeArgs
  $retryNoScope.Output | Out-Host
  if ($retryNoScope.ExitCode -eq 0) { return }

  throw "vercel link failed."
}

function Set-VercelEnv([string]$Name, [string]$Value, [string]$Target, [string]$Scope) {
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("env", "add", $Name, $Target, "--value", $Value, "--force", "--yes")
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $args += (Get-VercelTokenArgs)
  $res = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  $res.Output | Out-Host
  if ($res.ExitCode -ne 0) {
    throw "Failed to set env var $Name for $Target."
  }
}

function New-RandomPackageName {
  $chars = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
  $suffix = -join (1..10 | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
  return "host-$suffix"
}

function New-RandomPackageVersion {
  $major = Get-Random -Minimum 1 -Maximum 4
  $minor = Get-Random -Minimum 0 -Maximum 20
  $patch = Get-Random -Minimum 0 -Maximum 30
  return "$major.$minor.$patch"
}

function New-RandomPackageDescription {
  $descriptions = @(
    "Lightweight hosting edge relay for low-bandwidth delivery",
    "Optimized download gateway for shared hosting workloads",
    "Traffic-shaped relay runtime for static and media hosting",
    "Resource-friendly transfer bridge for multi-tenant hosting",
    "Adaptive download routing layer for budget hosting plans",
    "Low-overhead HTTP delivery relay for content hosting",
    "Bandwidth-governed relay node for file delivery services",
    "Edge proxy core for controlled-speed hosting and downloads"
  )
  return ($descriptions | Get-Random)
}

function New-RandomVercelConfigName {
  $chars = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
  $suffix = -join (1..10 | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
  return "edge-$suffix"
}

function Prepare-RandomizedPackageMetadataForDeploy {
  $pkgPath = Join-Path $scriptDir "package.json"
  if (-not (Test-Path $pkgPath)) {
    return @{
      Modified = $false
      PackagePath = $pkgPath
      OriginalContent = ""
    }
  }

  $original = Get-Content -Path $pkgPath -Raw
  try {
    $obj = $original | ConvertFrom-Json
  } catch {
    Write-Host "package.json parse failed; deploying without metadata randomization." -ForegroundColor DarkYellow
    return @{
      Modified = $false
      PackagePath = $pkgPath
      OriginalContent = $original
    }
  }

  $randomName = New-RandomPackageName
  $randomVersion = New-RandomPackageVersion
  $randomDesc = New-RandomPackageDescription

  if ($obj.PSObject.Properties.Name -contains "name") {
    $obj.name = $randomName
  } else {
    $obj | Add-Member -NotePropertyName "name" -NotePropertyValue $randomName
  }
  if ($obj.PSObject.Properties.Name -contains "version") {
    $obj.version = $randomVersion
  } else {
    $obj | Add-Member -NotePropertyName "version" -NotePropertyValue $randomVersion
  }
  if ($obj.PSObject.Properties.Name -contains "description") {
    $obj.description = $randomDesc
  } else {
    $obj | Add-Member -NotePropertyName "description" -NotePropertyValue $randomDesc
  }

  $json = $obj | ConvertTo-Json -Depth 50
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($pkgPath, $json, $utf8NoBom)

  return @{
    Modified = $true
    PackagePath = $pkgPath
    OriginalContent = $original
  }
}

function Restore-PackageMetadataAfterDeploy($state) {
  if ($null -eq $state) { return }
  if (-not $state.Modified) { return }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($state.PackagePath, [string]$state.OriginalContent, $utf8NoBom)
  # keep local files clean after deploy
}

function Prepare-RandomizedVercelConfigForDeploy {
  $vercelPath = Join-Path $scriptDir "vercel.json"
  if (-not (Test-Path $vercelPath)) {
    return @{
      Modified = $false
      ConfigPath = $vercelPath
      OriginalContent = ""
    }
  }

  $original = Get-Content -Path $vercelPath -Raw
  try {
    $obj = $original | ConvertFrom-Json
  } catch {
    Write-Host "vercel.json parse failed; deploying without vercel.json randomization." -ForegroundColor DarkYellow
    return @{
      Modified = $false
      ConfigPath = $vercelPath
      OriginalContent = $original
    }
  }

  $randomName = New-RandomVercelConfigName
  if ($obj.PSObject.Properties.Name -contains "name") {
    $obj.name = $randomName
  } else {
    $obj | Add-Member -NotePropertyName "name" -NotePropertyValue $randomName
  }

  $json = $obj | ConvertTo-Json -Depth 50
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($vercelPath, $json, $utf8NoBom)

  return @{
    Modified = $true
    ConfigPath = $vercelPath
    OriginalContent = $original
  }
}

function Restore-VercelConfigAfterDeploy($state) {
  if ($null -eq $state) { return }
  if (-not $state.Modified) { return }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($state.ConfigPath, [string]$state.OriginalContent, $utf8NoBom)
  # keep local files clean after deploy
}

function Build-RewriteSecureVercelJson([string]$TargetDomain, [string]$RelayPath, [string]$PublicRelayPath, [string]$RelayKey, [string]$RewriteStyle = "legacy") {
  $style = ([string]$RewriteStyle).Trim().ToLowerInvariant()
  if ($style -eq "simple") { $style = "simplelegacy" }
  if ($style -notin @("legacy", "modern", "simplelegacy", "simplemodern")) { $style = "legacy" }
  $isSimple = $style -in @("simplelegacy", "simplemodern")

  $sourceBase = Convert-PathToVercelSourceBase -PathValue $PublicRelayPath
  $target = ([string]$TargetDomain).TrimEnd("/")
  $up = Normalize-PathLike -PathValue $RelayPath
  if ([string]::IsNullOrWhiteSpace($up) -or $up -eq "/") { $up = "/api" }
  $destinationBase = "$target$up/"
  $sourceAny = ""
  $destinationAny = ""
  if ($style -eq "modern" -or $style -eq "simplemodern") {
    $sourceAny = Convert-PathToVercelSource -PathValue $PublicRelayPath
    $destinationAny = "$target$up/:path*"
  } else {
    $sourceAny = "$sourceBase/(.*)"
    $destinationAny = "$target$up/`$1"
  }
  $rk = if ($isSimple) { "" } else { ([string]$RelayKey).Trim() }
  $headers = @()
  if (-not $isSimple) {
    foreach ($src in @($sourceBase, $sourceAny)) {
      $headers += [ordered]@{
        source = $src
        headers = @(
          [ordered]@{ key = "Cache-Control"; value = "no-store, no-cache, must-revalidate, max-age=0" },
          [ordered]@{ key = "CDN-Cache-Control"; value = "no-store" },
          [ordered]@{ key = "Vercel-CDN-Cache-Control"; value = "no-store" }
        )
      }
    }
  }
  $rewrites = @()
  $rewritePairs = if ($isSimple) {
    @(@{ Source = $sourceAny; Destination = $destinationAny })
  } else {
    @(
      @{ Source = $sourceAny; Destination = $destinationAny },
      @{ Source = $sourceBase; Destination = $destinationBase }
    )
  }
  foreach ($pair in $rewritePairs) {
    $src = [string]$pair.Source
    $dst = [string]$pair.Destination
    if (-not [string]::IsNullOrWhiteSpace($rk)) {
      $rewrites += [ordered]@{
        source = $src
        has = @(
          [ordered]@{
            type = "header"
            key = "x-relay-key"
            value = $rk
          }
        )
        destination = $dst
      }
    } else {
      $rewrites += [ordered]@{
        source = $src
        destination = $dst
      }
    }
  }
  if (-not $isSimple) {
    $rewrites += [ordered]@{
      source = "/(.*)"
      destination = "/index.html"
    }
  }
  $obj = [ordered]@{
    version = 2
    rewrites = $rewrites
    trailingSlash = $false
  }
  if ($headers.Count -gt 0) {
    $obj = [ordered]@{
      version = 2
      headers = $headers
      rewrites = $rewrites
      trailingSlash = $false
    }
  }
  return ($obj | ConvertTo-Json -Depth 20)
}

function Prepare-RewriteSecureConfigForDeploy([string]$TargetDomain, [string]$RelayPath, [string]$PublicRelayPath, [string]$RelayKey, [string]$RewriteStyle = "legacy") {
  $vercelPath = Join-Path $scriptDir "vercel.json"
  $original = ""
  if (Test-Path $vercelPath) { $original = Get-Content -Path $vercelPath -Raw }
  $json = Build-RewriteSecureVercelJson -TargetDomain $TargetDomain -RelayPath $RelayPath -PublicRelayPath $PublicRelayPath -RelayKey $RelayKey -RewriteStyle $RewriteStyle
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($vercelPath, $json, $utf8NoBom)
  return @{
    Modified = $true
    ConfigPath = $vercelPath
    OriginalContent = $original
  }
}

function Deploy-Production(
  [string]$Scope,
  [string]$Region = "",
  [string]$Runtime = "node",
  [string]$TargetDomain = "",
  [string]$RelayPath = "",
  [string]$PublicRelayPath = "",
  [string]$RelayKey = "",
  [string]$RewriteStyle = "legacy"
) {
  Write-Step "Deploying to production..."
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $randomizeState = Prepare-RandomizedPackageMetadataForDeploy
  $vercelRandomizeState = $null
  $regionState = $null
  try {
    $linked = Get-LinkedProjectInfo -ProjectRoot $scriptDir
    if (-not [string]::IsNullOrWhiteSpace($linked.ProjectName)) {
      $authSync = Disable-ProjectVercelAuthentication -ProjectName $linked.ProjectName -Scope $Scope -TokenStorePath $tokenStorePath
      $script:LastVercelAuthStatus = [string]$authSync.Status
    } else {
      $script:LastVercelAuthStatus = "unknown"
    }

    if ($Runtime -eq "rewrite") {
      $vercelRandomizeState = Prepare-RewriteSecureConfigForDeploy -TargetDomain $TargetDomain -RelayPath $RelayPath -PublicRelayPath $PublicRelayPath -RelayKey $RelayKey -RewriteStyle $RewriteStyle
      if ([string]::IsNullOrWhiteSpace(([string]$RelayKey).Trim())) {
        Write-Host ("Rewrite mode ({0}): no relay key set (no x-relay-key required)." -f $RewriteStyle) -ForegroundColor DarkYellow
      } else {
        Write-Host ("Rewrite mode ({0}): x-relay-key lock enabled." -f $RewriteStyle) -ForegroundColor DarkYellow
      }
    } else {
      $vercelRandomizeState = Prepare-RandomizedVercelConfigForDeploy
    }
    if ($Runtime -eq "node" -and -not [string]::IsNullOrWhiteSpace($Region)) {
      $regionState = Set-VercelFunctionRegion -Region $Region
    }
    $args = @("deploy", "--prod", "--yes")
    if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
    $args += (Get-VercelTokenArgs)

    Write-Host "Uploading/building on Vercel. This can take 1-3 minutes for some projects..." -ForegroundColor DarkYellow
    $result = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args -TimeoutSec 1200
    $lines = $result.Output
    if ($result.ExitCode -ne 0) {
      $errText = (($lines | Out-String).Trim())
      if ([string]::IsNullOrWhiteSpace($errText)) { $errText = "unknown deploy failure" }
      throw "vercel deploy failed: $errText"
    }

    $alias = ""
    $prod = ""
    foreach ($line in $lines) {
      if ($line -match "Aliased:\s*(https://\S+)") { $alias = $Matches[1] }
      if ($line -match "Production:\s*(https://\S+)") { $prod = $Matches[1] }
      if ([string]::IsNullOrWhiteSpace($prod) -and $line -match '^https://[^\s]+\.vercel\.app$') { $prod = $line.Trim() }
    }

    return @{
      Alias = $alias
      Production = $prod
    }
  } finally {
    if ($null -ne $regionState) { Restore-VercelConfigAfterDeploy -state $regionState }
    if ($null -ne $vercelRandomizeState) { Restore-VercelConfigAfterDeploy -state $vercelRandomizeState }
    Restore-PackageMetadataAfterDeploy -state $randomizeState
  }
}

function Get-LinkedProjectInfo([string]$ProjectRoot) {
  $projectFile = Join-Path $ProjectRoot ".vercel\project.json"
  if (-not (Test-Path $projectFile)) {
    return @{
      IsLinked = $false
      ProjectName = ""
      ProjectId = ""
      Scope = ""
    }
  }

  try {
    $obj = Get-Content $projectFile -Raw | ConvertFrom-Json
  } catch {
    return @{
      IsLinked = $false
      ProjectName = ""
      ProjectId = ""
      Scope = ""
    }
  }

  $name = ""
  if ($obj.PSObject.Properties.Name -contains "projectName" -and $obj.projectName) { $name = [string]$obj.projectName }
  $projectId = ""
  if ($obj.PSObject.Properties.Name -contains "projectId" -and $obj.projectId) { $projectId = [string]$obj.projectId }
  $scope = ""
  if ($obj.PSObject.Properties.Name -contains "orgId" -and $obj.orgId) {
    $orgId = [string]$obj.orgId
    if ($orgId.StartsWith("team_")) {
      try {
        $token = Get-VercelApiToken -TokenStorePath $tokenStorePath
        if (-not [string]::IsNullOrWhiteSpace($token)) {
          $scope = Try-ResolveTeamSlugFromTeamId -TeamId $orgId -Token $token
        }
      } catch {}
      if ([string]::IsNullOrWhiteSpace($scope)) { $scope = "" }
    } else {
      # Personal account links store a user/org id here; Vercel CLI scope must stay empty.
      $scope = ""
    }
  }

  return @{
    IsLinked = $true
    ProjectName = $name
    ProjectId = $projectId
    Scope = $scope
  }
}

function Show-DeploySummary($deployInfo) {
  Write-Host ""
  Write-Host "==============================================" -ForegroundColor Green
  Write-Host "Deployment complete." -ForegroundColor Green
  if ($deployInfo.Production) { Write-Host "Production: $($deployInfo.Production)" -ForegroundColor Green }
  if ($deployInfo.Alias) { Write-Host "Aliased:    $($deployInfo.Alias)" -ForegroundColor Green }
  if ($deployInfo.Alias -match 'https://([^/]+)') {
    Write-Host ""
    Write-Host ("Use this in your client Host field: {0}" -f $Matches[1]) -ForegroundColor Cyan
  }
  Write-Host "==============================================" -ForegroundColor Green
  Write-Host ""
}

function Show-RewriteClientGuidance($cfg, $deployInfo) {
  if ($null -eq $cfg -or $cfg.Runtime -ne "rewrite") { return }
  Write-Host ""
  Write-Host "FAST PIPE zero-compute notes:" -ForegroundColor Yellow
  Write-Host (" - This deploy uses {0} Vercel rewrites, not Node Functions." -f $cfg.RewriteStyle) -ForegroundColor Cyan
  Write-Host " - No Fluid/Function CPU/Memory/Duration is used." -ForegroundColor Cyan
  Write-Host " - no-store headers were added for the relay path to reduce CDN/cache interference." -ForegroundColor Cyan
  Write-Host " - There is still no Node throttle, retry, timeout, request log, or concurrency control in rewrite mode." -ForegroundColor DarkYellow
  Write-Host ""
  Write-Host "Client setup:" -ForegroundColor Yellow
  Write-Host (" - Host: {0}" -f ([string]$deployInfo.Alias -replace '^https?://', '').TrimEnd("/")) -ForegroundColor Cyan
  Write-Host (" - Path: {0}" -f $cfg.PublicRelayPath) -ForegroundColor Cyan
  if (-not [string]::IsNullOrWhiteSpace([string]$cfg.RelayKey)) {
    Write-Host " - XHTTP Extra: use the JSON header below." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "XHTTP Extra (client) because x-relay-key is enabled:" -ForegroundColor Yellow
    $clientRelayKey = ([string]$cfg.RelayKey).Replace("\", "\\").Replace('"', '\"')
    Write-Host '{' -ForegroundColor Cyan
    Write-Host '  "headers": {' -ForegroundColor Cyan
    Write-Host ('    "x-relay-key": "{0}"' -f $clientRelayKey) -ForegroundColor Cyan
    Write-Host '  }' -ForegroundColor Cyan
    Write-Host '}' -ForegroundColor Cyan
  } else {
    Write-Host " - No x-relay-key header is required." -ForegroundColor Green
    Write-Host " - Use a strong/random path on both this installer and your upstream inbound for privacy." -ForegroundColor DarkYellow
  }
  Write-Host ""
  Write-Host "If Instagram/YouTube still feel bad:" -ForegroundColor Yellow
  Write-Host " - Test Mux ON with low concurrency first (4 or 8). If video stalls, test Mux OFF too." -ForegroundColor Cyan
  Write-Host " - If your client has heartbeat/keepalive, try 15-20 seconds. Very low values increase Edge Requests." -ForegroundColor Cyan
  Write-Host " - On the upstream server, keep BBR enabled and test MTU 1350/1280 only if mobile routes stall." -ForegroundColor Cyan
  Write-Host " - For full control/log/throttle, use BALANCED or MAX CONN Node mode instead of rewrite." -ForegroundColor DarkYellow
}

function Get-LinkedTeamId([string]$ProjectRoot) {
  $projectFile = Join-Path $ProjectRoot ".vercel\project.json"
  if (-not (Test-Path $projectFile)) { return "" }
  try {
    $obj = Get-Content $projectFile -Raw | ConvertFrom-Json
    if ($obj.PSObject.Properties.Name -contains "orgId" -and $obj.orgId) {
      $oid = [string]$obj.orgId
      if ($oid.StartsWith("team_")) { return $oid }
    }
  } catch {}
  return ""
}

function Collect-NewDeploymentConfig([string]$DefaultScope) {
  Write-Step "Collecting config values..."
  $DefaultScope = Normalize-ScopeForCli -Scope $DefaultScope
  if ([string]::IsNullOrWhiteSpace($DefaultScope)) {
    $scope = Read-Host "Scope slug/team (optional, press Enter to skip)"
  } else {
    $scope = Read-Default "Scope slug/team" $DefaultScope
  }
  $scope = Normalize-ScopeForCli -Scope $scope
  if (-not [string]::IsNullOrWhiteSpace($scope) -and -not (Validate-Scope -Scope $scope)) {
    throw "Scope '$scope' does not exist. Enter a valid Vercel team slug."
  }
  $mode = Choose-DeploymentMode
  if ($mode.ContainsKey("Canceled") -and [bool]$mode.Canceled) {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return $null
  }
  $projectNameInput = Read-Optional "Project name on Vercel (leave empty for random, 0 = Back)"
  if ($projectNameInput -eq "0") {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return $null
  }
  $projectName = if ([string]::IsNullOrWhiteSpace($projectNameInput)) { New-RandomProjectName } else { $projectNameInput }
  $maxInflight = $mode.MaxInflight
  $maxUpBps = $mode.MaxUpBps
  $maxDownBps = $mode.MaxDownBps
  $upstreamTimeoutMs = $mode.UpstreamTimeoutMs
  $targetDomain = Read-Required "TARGET_DOMAIN (MUST be your foreign server inbound domain+port, example: https://your-domain.com:443, 0 = Back)"
  if ($targetDomain -eq "0") {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return $null
  }
  $selectedRegion = ""
  if ($mode.Runtime -eq "node") {
    $selectedRegion = Choose-FunctionRegion -TargetDomain $targetDomain
  }
  Write-Host "RELAY_PATH guide: open your foreign server inbound, set a Path starting with '/'. Enter EXACT same value here." -ForegroundColor DarkYellow
  $relayPathInput = Read-Required "RELAY_PATH (example: /api or /freedom, 0 = Back)"
  if ($relayPathInput -eq "0") {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return $null
  }
  $relayPath = Normalize-PathLike $relayPathInput
  $publicRelayPath = $relayPath
  Write-Host ("PUBLIC_RELAY_PATH auto-set to RELAY_PATH: {0}" -f $publicRelayPath) -ForegroundColor DarkCyan
  $landingTemplate = Read-Optional "LANDING_TEMPLATE (optional template folder name; empty = random each build)"
  $successLogSampleRate = ""
  $successLogMinDurationMs = ""
  $errorLogMinIntervalMs = ""
  if ($mode.Runtime -eq "node") {
    $successLogSampleRate = Read-Default "SUCCESS_LOG_SAMPLE_RATE" "0"
    $successLogMinDurationMs = Read-Default "SUCCESS_LOG_MIN_DURATION_MS" "3000"
    $errorLogMinIntervalMs = Read-Default "ERROR_LOG_MIN_INTERVAL_MS" "5000"
  }
  $relayKey = ""
  if ($mode.Runtime -eq "rewrite") {
    if ($mode.RewriteStyle -eq "simplelegacy" -or $mode.RewriteStyle -eq "simplemodern") {
      Write-Host "FAST PIPE SIMPLE: no headers will be configured." -ForegroundColor Green
      if ($mode.RewriteStyle -eq "simplemodern") {
        Write-Host "No x-relay-key prompt, no cache headers, no base path, no fallback rule. It is exactly one modern rewrite rule." -ForegroundColor DarkYellow
      } else {
        Write-Host "No x-relay-key prompt, no cache headers, no base path, no fallback rule. It is exactly one legacy rewrite rule." -ForegroundColor DarkYellow
      }
      $relayKey = ""
    } else {
      Write-Host "RELAY_KEY is optional in Fast Pipe." -ForegroundColor DarkYellow
      Write-Host "Leave it empty for no x-relay-key. If you set it, the client MUST send header x-relay-key with the exact same value." -ForegroundColor DarkYellow
      $relayKey = Read-Optional "RELAY_KEY (optional; empty = no x-relay-key required, 0 = Back)"
      if ($relayKey -eq "0") {
        Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
        return $null
      }
    }
  }

  Write-Step "Environment values selected:"
  Write-Host "TARGET_DOMAIN = $targetDomain"
  Write-Host "PROJECT_NAME  = $projectName"
  Write-Host "DEPLOY_MODE   = $($mode.ModeKey)"
  Write-Host "RUNTIME       = $($mode.Runtime)"
  if ($mode.Runtime -eq "node") {
    Write-Host ("FLUID_COMPUTE = {0}" -f $(if ($mode.FluidEnabled) { "on" } else { "off" }))
    Write-Host ("FUNCTION_TIMEOUT_SEC     = {0}" -f $mode.FunctionTimeoutSec)
    Write-Host ("FUNCTION_CPU             = {0}" -f $mode.FunctionCpu)
  } else {
    Write-Host ("REWRITE_STYLE = {0}" -f $mode.RewriteStyle)
    Write-Host ("REWRITE_SECURITY = {0}" -f $(if ([string]::IsNullOrWhiteSpace($relayKey)) { "no x-relay-key" } else { "x-relay-key required" }))
  }
  Write-Host "RELAY_PATH    = $relayPath"
  Write-Host "PUBLIC_RELAY_PATH = $publicRelayPath"
  if ($mode.Runtime -eq "node") {
    if (-not [string]::IsNullOrWhiteSpace($landingTemplate)) { Write-Host "LANDING_TEMPLATE = $landingTemplate" } else { Write-Host "LANDING_TEMPLATE = (random)" }
    Write-Host "MAX_INFLIGHT  = $maxInflight"
    Write-Host "MAX_UP_BPS    = $maxUpBps"
    Write-Host "MAX_DOWN_BPS  = $maxDownBps"
    Write-Host "UPSTREAM_TIMEOUT_MS        = $upstreamTimeoutMs"
    Write-Host "SUCCESS_LOG_SAMPLE_RATE    = $successLogSampleRate"
    Write-Host "SUCCESS_LOG_MIN_DURATION_MS= $successLogMinDurationMs"
    Write-Host "ERROR_LOG_MIN_INTERVAL_MS  = $errorLogMinIntervalMs"
  } else {
    if ([string]::IsNullOrWhiteSpace($relayKey)) {
      Write-Host "REWRITE_SECURITY_HEADER = (disabled)"
      Write-Host "RELAY_KEY               = (not set)"
    } else {
      Write-Host "REWRITE_SECURITY_HEADER = x-relay-key"
      Write-Host "RELAY_KEY               = (set)"
    }
  }
  if ($mode.Runtime -eq "node") {
    Write-Host "FUNCTION_REGION            = $selectedRegion"
  } else {
    Write-Host "REWRITE_CACHE_HEADERS      = no-store / CDN no-store"
    Write-Host ("REWRITE_PATH_MODE          = {0}" -f $mode.RewriteStyle)
    Write-Host "REWRITE_NOTE               = no Vercel ENV, Fluid, CPU, Function Region, or Max Duration will be configured."
  }

  return @{
    ProjectName = $projectName
    Scope = $scope
    DeployMode = $mode.ModeKey
    Runtime = $mode.Runtime
    RewriteStyle = $mode.RewriteStyle
    RewriteSecurity = $mode.RewriteSecurity
    FluidEnabled = [bool]$mode.FluidEnabled
    FunctionTimeoutSec = [int]$mode.FunctionTimeoutSec
    FunctionCpu = $mode.FunctionCpu
    RelayKey = $relayKey
    TargetDomain = $targetDomain
    RelayPath = $relayPath
    PublicRelayPath = $publicRelayPath
    LandingTemplate = if ($mode.Runtime -eq "node") { $landingTemplate } else { "" }
    MaxInflight = $maxInflight
    MaxUpBps = $maxUpBps
    MaxDownBps = $maxDownBps
    UpstreamTimeoutMs = $upstreamTimeoutMs
    SuccessLogSampleRate = $successLogSampleRate
    SuccessLogMinDurationMs = $successLogMinDurationMs
    ErrorLogMinIntervalMs = $errorLogMinIntervalMs
    RunStressAfterDeploy = [bool]$mode.RunStressAfterDeploy
    Region = $selectedRegion
  }
}

function Export-ShareableConfigSummary($cfg, [string]$AliasUrl = "") {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $path = Join-Path $scriptDir ("build-profile-{0}.txt" -f $stamp)
  $lines = @()
  $lines += "XHTTPRelayECO Build Profile Summary"
  $lines += "generated_at=$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))"
  $lines += "deploy_mode=$($cfg.DeployMode)"
  $lines += "runtime=$($cfg.Runtime)"
  if ($cfg.Runtime -eq "node") {
    $lines += "fluid_compute=$($cfg.FluidEnabled)"
    $lines += "function_timeout_sec=$($cfg.FunctionTimeoutSec)"
    $lines += "function_cpu=$($cfg.FunctionCpu)"
  } else {
    $lines += "rewrite_style=$($cfg.RewriteStyle)"
    $lines += "rewrite_security=$($cfg.RewriteSecurity)"
  }
  $authState = "unknown"
  if ($cfg.ContainsKey("VercelAuthentication") -and -not [string]::IsNullOrWhiteSpace([string]$cfg.VercelAuthentication)) {
    $authState = [string]$cfg.VercelAuthentication
  } elseif (-not [string]::IsNullOrWhiteSpace([string]$script:LastVercelAuthStatus)) {
    $authState = [string]$script:LastVercelAuthStatus
  }
  $lines += "vercel_authentication=$authState"
  $lines += "relay_path=$($cfg.RelayPath)"
  $lines += "public_relay_path=$($cfg.PublicRelayPath)"
  if ($cfg.Runtime -eq "node") {
    $lines += "region=$($cfg.Region)"
    $lines += "max_inflight=$($cfg.MaxInflight)"
    $lines += "max_up_bps=$($cfg.MaxUpBps)"
    $lines += "max_down_bps=$($cfg.MaxDownBps)"
    $lines += "upstream_timeout_ms=$($cfg.UpstreamTimeoutMs)"
    $lines += "success_log_sample_rate=$($cfg.SuccessLogSampleRate)"
    $lines += "success_log_min_duration_ms=$($cfg.SuccessLogMinDurationMs)"
    $lines += "error_log_min_interval_ms=$($cfg.ErrorLogMinIntervalMs)"
  } else {
    $lines += "rewrite_config=vercel_json_only"
    $lines += "rewrite_path_mode=$($cfg.RewriteStyle)"
    $lines += "rewrite_cache_headers=no-store"
    $lines += "vercel_env=not_required"
  }
  if (-not [string]::IsNullOrWhiteSpace($cfg.RelayKey)) { $lines += "relay_key=(set)" }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)
  Write-Host ("Shareable config summary saved: {0}" -f $path) -ForegroundColor Green
}

function Apply-ProductionEnv($cfg) {
  Write-Step "Setting environment variables for production..."
  if ($cfg.Runtime -eq "rewrite") {
    Write-Host "Rewrite mode uses vercel.json rewrite rules. No production ENV vars are needed or deployed for this mode." -ForegroundColor DarkYellow
    return
  }
  Set-VercelEnv -Name "TARGET_DOMAIN" -Value $cfg.TargetDomain -Target "production" -Scope $cfg.Scope
  Set-VercelEnv -Name "RELAY_PATH" -Value $cfg.RelayPath -Target "production" -Scope $cfg.Scope
  Set-VercelEnv -Name "PUBLIC_RELAY_PATH" -Value $cfg.PublicRelayPath -Target "production" -Scope $cfg.Scope
  if (-not [string]::IsNullOrWhiteSpace($cfg.LandingTemplate)) {
    Set-VercelEnv -Name "LANDING_TEMPLATE" -Value $cfg.LandingTemplate -Target "production" -Scope $cfg.Scope
  }
  if ($cfg.Runtime -eq "node") {
    Set-VercelEnv -Name "MAX_INFLIGHT" -Value $cfg.MaxInflight -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "MAX_UP_BPS" -Value $cfg.MaxUpBps -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "MAX_DOWN_BPS" -Value $cfg.MaxDownBps -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "UPSTREAM_TIMEOUT_MS" -Value $cfg.UpstreamTimeoutMs -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "SUCCESS_LOG_SAMPLE_RATE" -Value $cfg.SuccessLogSampleRate -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "SUCCESS_LOG_MIN_DURATION_MS" -Value $cfg.SuccessLogMinDurationMs -Target "production" -Scope $cfg.Scope
    Set-VercelEnv -Name "ERROR_LOG_MIN_INTERVAL_MS" -Value $cfg.ErrorLogMinIntervalMs -Target "production" -Scope $cfg.Scope
  }
  if ($cfg.Runtime -eq "node" -and -not [string]::IsNullOrWhiteSpace($cfg.RelayKey)) {
    Set-VercelEnv -Name "RELAY_KEY" -Value $cfg.RelayKey -Target "production" -Scope $cfg.Scope
  }
}

function Run-NewDeploymentFlow([string]$DefaultScope) {
  $cfg = Collect-NewDeploymentConfig -DefaultScope $DefaultScope
  if ($null -eq $cfg) { return $null }
  Ensure-VercelProject -ProjectName $cfg.ProjectName -Scope $cfg.Scope
  Ensure-LinkedToProject -ProjectName $cfg.ProjectName -Scope $cfg.Scope
  Apply-ProductionEnv -cfg $cfg
  if ($cfg.Runtime -eq "node") {
    $null = Apply-ProjectRuntimeSettings -ProjectName $cfg.ProjectName -Scope $cfg.Scope -TokenStorePath $tokenStorePath -Region $cfg.Region -FunctionTimeoutSec $cfg.FunctionTimeoutSec -FluidEnabled $cfg.FluidEnabled -FunctionCpu $cfg.FunctionCpu
  }
  $deployInfo = Deploy-Production -Scope $cfg.Scope -Region $cfg.Region -Runtime $cfg.Runtime -TargetDomain $cfg.TargetDomain -RelayPath $cfg.RelayPath -PublicRelayPath $cfg.PublicRelayPath -RelayKey $cfg.RelayKey -RewriteStyle $cfg.RewriteStyle
  $cfg.VercelAuthentication = [string]$script:LastVercelAuthStatus
  Show-DeploySummary $deployInfo
  Show-RewriteClientGuidance -cfg $cfg -deployInfo $deployInfo
  Export-ShareableConfigSummary -cfg $cfg -AliasUrl $deployInfo.Alias
  $runTests = Read-Default "Run essential health/smoke tests now? (Y/n)" "y"
  if ($runTests.ToLowerInvariant() -ne "n") {
    Run-HealthAndSmokeChecks -ProjectName $cfg.ProjectName -RelayPath $cfg.PublicRelayPath -Runtime $cfg.Runtime -RelayKey $cfg.RelayKey
    if ($cfg.RunStressAfterDeploy) {
      Write-Host "Running load-test lite pass automatically..." -ForegroundColor Yellow
      Run-LoadTestLite -ProjectName $cfg.ProjectName -RelayPath $cfg.PublicRelayPath
    }
    Read-Host "Health/smoke checks finished. Press Enter to continue"
  }
  Write-Host "Done."
  return $cfg
}

function Test-EnvTargetsProduction($Targets) {
  $normalized = Normalize-EnvTargets $Targets
  if ($normalized.Count -eq 0) { return $true }
  return ($normalized -contains "production")
}

function Get-ProductionEnvRows([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No API token available. Use token auth mode first."
  }
  $envs = Get-ProjectEnvEntriesApi -ProjectName $ProjectName -Scope $Scope -Token $token -Limit 200
  $rows = @()
  foreach ($e in $envs) {
    $key = [string]$e.key
    if ([string]::IsNullOrWhiteSpace($key)) { continue }
    if (-not (Test-EnvTargetsProduction $e.target)) { continue }
    $targets = Normalize-EnvTargets $e.target
    $targetText = if ($targets.Count -gt 0) { ($targets -join ",") } else { "production/all" }
    $rows += [pscustomobject]@{
      Key = $key
      ValuePreview = (Get-EnvValuePreview -envObj $e)
      Targets = $targetText
      UpdatedAt = (Convert-ApiTimestampToText $e.updatedAt)
    }
  }
  return @($rows | Sort-Object Key)
}

function Show-EnvEditTable($Rows, [hashtable]$PendingChanges) {
  Write-Host ""
  Write-Host "Production ENV values:" -ForegroundColor Cyan
  if ($Rows.Count -eq 0) {
    Write-Host "No production ENV entries found. Use A to add one." -ForegroundColor DarkYellow
  } else {
    for ($i = 0; $i -lt $Rows.Count; $i++) {
      $r = $Rows[$i]
      $value = [string]$r.ValuePreview
      $pendingMark = ""
      if ($PendingChanges.ContainsKey([string]$r.Key)) {
        $value = "(pending new value)"
        $pendingMark = " *"
      }
      Write-Host ("[{0}] {1}{2} = {3}  [{4}]" -f ($i + 1), $r.Key, $pendingMark, $value, $r.Targets)
    }
  }
  if ($PendingChanges.Count -gt 0) {
    Write-Host ""
    Write-Host "Pending changes:" -ForegroundColor Yellow
    foreach ($k in ($PendingChanges.Keys | Sort-Object)) {
      Write-Host (" - {0} = (new value set)" -f $k) -ForegroundColor Yellow
    }
  }
  Write-Host ""
  Write-Host "[A] Add new ENV"
  Write-Host "[C] Confirm changes and redeploy"
  Write-Host "[0] Back to main menu"
}

function Run-UpdateEnvFlow([string]$Scope) {
  Write-Step "Update production ENV vars..."

  $selected = Select-ProjectFromList -Scope $Scope -TokenStorePath $tokenStorePath
  if ($null -eq $selected) {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return $null
  }

  $projectName = [string]$selected.Name
  $projectScope = $Scope
  if ($selected.PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$selected.Scope)) {
    $projectScope = Normalize-ScopeForCli -Scope ([string]$selected.Scope)
  }
  Ensure-LinkedToProject -ProjectName $projectName -Scope $projectScope

  $state = Load-LocalProjectDeployState -ProjectName $projectName
  $runtime = "node"
  $deployMode = "ENV_UPDATE"
  $relayPath = "/api"
  if ($null -ne $state) {
    if (-not [string]::IsNullOrWhiteSpace([string]$state.Runtime)) { $runtime = [string]$state.Runtime }
    if (-not [string]::IsNullOrWhiteSpace([string]$state.DeployMode)) { $deployMode = [string]$state.DeployMode }
    if (-not [string]::IsNullOrWhiteSpace([string]$state.RelayPath)) { $relayPath = [string]$state.RelayPath }
  }
  if ($runtime -eq "rewrite") {
    Write-Host "Note: this project is marked as Fast Pipe rewrite locally. Rewrite deploys do not use Node ENV vars." -ForegroundColor DarkYellow
    $continue = Read-Default "Continue editing ENV and redeploy as Node runtime? (y/N)" "n"
    if ($continue.ToLowerInvariant() -ne "y") {
      Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
      return $null
    }
    $runtime = "node"
    $deployMode = "ENV_UPDATE_NODE"
  }

  $rows = Get-ProductionEnvRows -ProjectName $projectName -Scope $projectScope -TokenStorePath $tokenStorePath
  $pending = @{}

  while ($true) {
    Show-EnvEditTable -Rows $rows -PendingChanges $pending
    $pick = Read-Default "Select ENV number, A, C, or 0" "0"
    $p = $pick.Trim()
    if ($p -eq "0") {
      Write-Host "Canceled. No ENV changes applied." -ForegroundColor DarkYellow
      return $null
    }
    if ($p.ToLowerInvariant() -eq "a") {
      $newKey = Read-Required "New ENV key (0 = Back)"
      $newKey = $newKey.Trim()
      if ($newKey -eq "0") { continue }
      if ($newKey -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Write-Host "Invalid ENV key. Use letters, numbers and underscore; first char must not be a number." -ForegroundColor Red
        continue
      }
      $newVal = Read-Host ("New value for {0}" -f $newKey)
      $pending[$newKey] = [string]$newVal
      if (-not (@($rows | Where-Object { [string]$_.Key -eq $newKey }).Count -gt 0)) {
        $rows += [pscustomobject]@{
          Key = $newKey
          ValuePreview = "(new)"
          Targets = "production"
          UpdatedAt = "-"
        }
        $rows = @($rows | Sort-Object Key)
      }
      continue
    }
    if ($p.ToLowerInvariant() -eq "c") {
      if ($pending.Count -eq 0) {
        Write-Host "No pending ENV changes to apply." -ForegroundColor DarkYellow
        continue
      }
      Write-Host ""
      Write-Host "Final confirmation:" -ForegroundColor Yellow
      foreach ($k in ($pending.Keys | Sort-Object)) {
        Write-Host (" - {0} = (new value set)" -f $k) -ForegroundColor Yellow
      }
      $confirm = Read-Default "Apply these ENV changes and redeploy now? (y/N)" "n"
      if ($confirm.ToLowerInvariant() -ne "y") {
        Write-Host "Canceled. No ENV changes applied." -ForegroundColor DarkYellow
        return $null
      }

      foreach ($k in ($pending.Keys | Sort-Object)) {
        Set-VercelEnv -Name $k -Value ([string]$pending[$k]) -Target "production" -Scope $projectScope
      }

      $deployInfo = Deploy-Production -Scope $projectScope -Runtime "node"
      Show-DeploySummary $deployInfo

      Save-LocalProjectDeployState -ProjectName $projectName -Scope $projectScope -DeployMode $deployMode -Runtime $runtime -RelayPath $relayPath
      Write-Host "ENV update and redeploy complete." -ForegroundColor Green

      return @{
        ProjectName = $projectName
        Scope = $projectScope
        DeployMode = $deployMode
        Runtime = $runtime
        Deployed = $true
        RelayPath = $relayPath
        PublicRelayPath = $relayPath
      }
    }

    $n = 0
    if (-not [int]::TryParse($p, [ref]$n)) {
      Write-Host "Invalid selection." -ForegroundColor Red
      continue
    }
    if ($n -lt 1 -or $n -gt $rows.Count) {
      Write-Host "Out of range." -ForegroundColor Red
      continue
    }

    $key = [string]$rows[$n - 1].Key
    $newValue = Read-Host ("New value for {0}" -f $key)
    $pending[$key] = [string]$newValue
  }
}

function Show-DeploymentList([string]$ProjectName, [string]$Scope) {
  Write-Step "Recent deployments..."
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("list")
  if (-not [string]::IsNullOrWhiteSpace($ProjectName)) { $args += @($ProjectName) }
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $args += (Get-VercelTokenArgs)
  $result = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  $result.Output | Out-Host
  if ($result.ExitCode -ne 0) {
    Write-Host "Could not list deployments with scoped project. Trying generic list..." -ForegroundColor DarkYellow
    $fallback = Invoke-NativeSafe -FilePath $VercelExe -Arguments (@("list") + (Get-VercelTokenArgs))
    $fallback.Output | Out-Host
  }
}

function Ensure-LinkedToProject([string]$ProjectName, [string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    throw "Project name is required."
  }
  Write-Step "Linking local folder to Vercel project from token/API..."
  $token = Get-VercelApiToken -TokenStorePath $tokenStorePath
  if (-not [string]::IsNullOrWhiteSpace($token)) {
    $apiInfo = Resolve-ProjectApiInfo -ProjectName $ProjectName -Scope $Scope -Token $token
    if ($null -ne $apiInfo -and -not [string]::IsNullOrWhiteSpace([string]$apiInfo.Id) -and -not [string]::IsNullOrWhiteSpace([string]$apiInfo.AccountId)) {
      Clear-LocalVercelProjectLink -ProjectRoot $scriptDir
      Write-LocalVercelProjectLink -ProjectName $ProjectName -ProjectId ([string]$apiInfo.Id) -OrgId ([string]$apiInfo.AccountId) -ProjectRoot $scriptDir
      if ($apiInfo.PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$apiInfo.Scope)) {
        Save-Scope -Scope ([string]$apiInfo.Scope) -Path $scopeStorePath
      }
      return
    }
  }

  Write-Host "API link metadata not available. Falling back to Vercel CLI link." -ForegroundColor DarkYellow
  Link-VercelProject -ProjectName $ProjectName -Scope $Scope
}

function Parse-ProjectListText([string[]]$Lines) {
  $projects = @()
  foreach ($line in $Lines) {
    if ($null -eq $line) { continue }
    $clean = [regex]::Replace([string]$line, '\x1B\[[0-9;]*[A-Za-z]', '')
    $trim = $clean.Trim()
    if ([string]::IsNullOrWhiteSpace($trim)) { continue }
    if ($trim.StartsWith(">")) { continue }
    if ($trim.StartsWith("-")) { continue }
    if ($trim -match '^(Projects|Name|Updated|ID|Inspect|No projects|Fetching|Retrieving|Error:|Warning:|Visit )') { continue }
    if ($trim -match '^https?://') { continue }

    $name = ($trim -split '\s+')[0]
    if ($name -match '^[a-zA-Z0-9][a-zA-Z0-9\-_\.]+$') {
      $projects += [PSCustomObject]@{
        Name = $name
        Id = ""
      }
    }
  }
  return @($projects | Sort-Object Name -Unique)
}

function Get-ProjectsFromVercelApi([string]$Scope, [string]$TokenStorePath) {
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) { return @() }

  $scopeCandidates = New-Object System.Collections.ArrayList
  $seenScopes = @{}
  $appendScope = {
    param([string]$s)
    $normalized = ""
    if (-not [string]::IsNullOrWhiteSpace($s)) { $normalized = ([string]$s).Trim() }
    $k = if ([string]::IsNullOrWhiteSpace($normalized)) { "__personal__" } else { $normalized }
    if ($seenScopes.ContainsKey($k)) { return }
    $seenScopes[$k] = $true
    [void]$scopeCandidates.Add($normalized)
  }

  # Always include personal context.
  & $appendScope ""

  # Scope from user/session is preferred, but not trusted as the only source.
  if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    & $appendScope $Scope
    if ($Scope.StartsWith("team_")) {
      $slugFromTeamId = Try-ResolveTeamSlugFromTeamId -TeamId $Scope -Token $token
      if (-not [string]::IsNullOrWhiteSpace($slugFromTeamId)) { & $appendScope $slugFromTeamId }
    }
  }

  # Saved scope (from previous successful runs).
  $savedScope = Normalize-ScopeForCli -Scope (Load-Scope -Path $scopeStorePath)
  if (-not [string]::IsNullOrWhiteSpace($savedScope)) { & $appendScope $savedScope }

  # Team ids/slugs from API.
  try {
    $teamsResp = Invoke-VercelApiGet -Path "/v2/teams?limit=100" -Token $token -Scope ""
    if ($null -ne $teamsResp -and $null -ne $teamsResp.teams) {
      foreach ($t in $teamsResp.teams) {
        if ($t.id) { & $appendScope ([string]$t.id) }
        if ($t.slug) { & $appendScope ([string]$t.slug) }
      }
    }
  } catch {}

  # Team slugs from CLI discovery (extra fallback).
  try {
    foreach ($slug in (Get-VercelTeamSlugs)) {
      if (-not [string]::IsNullOrWhiteSpace($slug)) { & $appendScope ([string]$slug) }
    }
  } catch {}

  $results = @()
  $seen = @{}
  foreach ($sc in $scopeCandidates) {
    try {
      $resp = Invoke-VercelApiGet -Path "/v9/projects?limit=100" -Token $token -Scope $sc
      if ($null -eq $resp -or $null -eq $resp.projects) { continue }
      foreach ($p in $resp.projects) {
        $name = if ($p.name) { [string]$p.name } else { "" }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $projectId = if ($p.id) { [string]$p.id } else { "" }
        $dedupeKey = if (-not [string]::IsNullOrWhiteSpace($projectId)) { $projectId } else { "$name|$sc" }
        if ($seen.ContainsKey($dedupeKey)) { continue }
        $seen[$dedupeKey] = $true
        $ownerScope = ""
        $accountId = ""
        if ($p.PSObject.Properties.Name -contains "accountId" -and $p.accountId) {
          $accountId = [string]$p.accountId
          if ($accountId.StartsWith("team_")) {
            $slug = Try-ResolveTeamSlugFromTeamId -TeamId $accountId -Token $token
            $ownerScope = if (-not [string]::IsNullOrWhiteSpace($slug)) { $slug } else { $accountId }
          }
        }
        if ([string]::IsNullOrWhiteSpace($accountId)) {
          try {
            $userResp = Invoke-VercelApiGet -Path "/v2/user" -Token $token -Scope ""
            if ($null -ne $userResp -and $null -ne $userResp.user -and $userResp.user.id) {
              $accountId = [string]$userResp.user.id
            }
          } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($ownerScope) -and -not [string]::IsNullOrWhiteSpace($sc)) {
          if ($sc.StartsWith("team_")) {
            $slugFromScope = Try-ResolveTeamSlugFromTeamId -TeamId $sc -Token $token
            if (-not [string]::IsNullOrWhiteSpace($slugFromScope)) { $ownerScope = $slugFromScope }
          } else {
            $ownerScope = Normalize-ScopeForCli -Scope $sc
          }
        }
        $results += [PSCustomObject]@{
          Name = $name
          Id = $projectId
          Scope = $ownerScope
          AccountId = $accountId
        }
      }
    } catch {}
  }

  return @($results | Sort-Object Name, Scope)
}

function Get-ProjectsFromVercel([string]$Scope, [string]$TokenStorePath = "") {
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("project", "list", "--format", "json", "--no-color")
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $args += (Get-VercelTokenArgs)
  $result = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args

  if ($result.ExitCode -eq 0) {
    $raw = ($result.Output -join "`n")
    $raw = $raw -replace "`0", ""
    $raw = $raw.Trim()

    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      # Try to isolate JSON payload even if CLI prints extra lines before/after.
      $jsonCandidate = $raw
      $firstArray = $raw.IndexOf("[")
      $lastArray = $raw.LastIndexOf("]")
      $firstObject = $raw.IndexOf("{")
      $lastObject = $raw.LastIndexOf("}")

      if ($firstArray -ge 0 -and $lastArray -gt $firstArray) {
        $jsonCandidate = $raw.Substring($firstArray, $lastArray - $firstArray + 1)
      } elseif ($firstObject -ge 0 -and $lastObject -gt $firstObject) {
        $jsonCandidate = $raw.Substring($firstObject, $lastObject - $firstObject + 1)
      }

      try {
        $parsed = $jsonCandidate | ConvertFrom-Json

        $items = @()
        if ($parsed -is [System.Array]) {
          $items = $parsed
        } elseif ($parsed.PSObject.Properties.Name -contains "projects") {
          $items = @($parsed.projects)
        } else {
          $items = @($parsed)
        }

        $projects = @()
        foreach ($item in $items) {
          $name = ""
          if ($item.PSObject.Properties.Name -contains "name" -and $item.name) { $name = [string]$item.name }
          if ([string]::IsNullOrWhiteSpace($name)) { continue }

          $projectId = ""
          if ($item.PSObject.Properties.Name -contains "id" -and $item.id) { $projectId = [string]$item.id }
          $projects += [PSCustomObject]@{
            Name = $name
            Id = $projectId
          }
        }

        if ($projects.Count -gt 0) {
          return @($projects | Sort-Object Name -Unique)
        }
      } catch {
        # ignore and continue to text parsing fallbacks below
      }
    }

    $parsedText = Parse-ProjectListText -Lines $result.Output
    if ($parsedText.Count -gt 0) { return $parsedText }
  }

  # Fallback for CLI variants/versions where JSON format is unavailable.
  $fallbackCommands = @(
    @("project", "list", "--no-color"),
    @("projects", "list", "--no-color"),
    @("project", "ls", "--no-color"),
    @("projects", "ls", "--no-color")
  )

  foreach ($cmd in $fallbackCommands) {
    $fallbackArgs = @($cmd)
    if (-not [string]::IsNullOrWhiteSpace($Scope)) { $fallbackArgs += @("--scope", $Scope) }
    $fallbackArgs += (Get-VercelTokenArgs)
    $fallback = Invoke-NativeSafe -FilePath $VercelExe -Arguments $fallbackArgs
    if ($fallback.ExitCode -ne 0) { continue }

    $parsedText = Parse-ProjectListText -Lines $fallback.Output
    if ($parsedText.Count -gt 0) { return $parsedText }
  }

  # Final fallback: query projects via Vercel API (token mode/session token).
  $apiProjects = Get-ProjectsFromVercelApi -Scope $Scope -TokenStorePath $TokenStorePath
  if ($apiProjects.Count -gt 0) { return $apiProjects }

  throw "Could not parse Vercel project list. Try auth mode 2 (token) or set a valid scope."
}

function Get-ProjectsForSelection([string]$Scope, [string]$TokenStorePath = "") {
  $Scope = Normalize-ScopeForCli -Scope $Scope

  # API-first list: independent from local .vercel and more reliable in token mode.
  $apiProjects = @()
  try {
    $apiProjects = Get-ProjectsFromVercelApi -Scope $Scope -TokenStorePath $TokenStorePath
  } catch {}
  if ($apiProjects.Count -gt 0) { return $apiProjects }

  # CLI fallback when API cannot return items in current context.
  return (Get-ProjectsFromVercel -Scope $Scope -TokenStorePath $TokenStorePath)
}

function Select-ProjectFromList([string]$Scope, [string]$TokenStorePath = "") {
  Write-Step "Loading projects from Vercel..."
  try {
    $projects = Get-ProjectsForSelection -Scope $Scope -TokenStorePath $TokenStorePath
  } catch {
    Write-Host "Could not load project list: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Tip: continue with option 5 (Deploy as NEW project), or retry with token auth." -ForegroundColor DarkYellow
    return $null
  }
  if ($projects.Count -eq 0) {
    Write-Host "No projects found in this scope." -ForegroundColor DarkYellow
    return $null
  }

  Write-Host ""
  Write-Host "Projects:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $projects.Count; $i++) {
    $scopeText = ""
    if ($projects[$i].PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$projects[$i].Scope)) {
      $scopeText = "  (scope: $([string]$projects[$i].Scope))"
    }
    Write-Host ("[{0}] {1}{2}" -f ($i + 1), $projects[$i].Name, $scopeText)
  }
  Write-Host "[0] Cancel"

  while ($true) {
    $choiceRaw = Read-Default "Select project number" "0"
    $n = 0
    if (-not [int]::TryParse($choiceRaw, [ref]$n)) {
      Write-Host "Invalid number." -ForegroundColor Red
      continue
    }
    if ($n -eq 0) { return $null }
    if ($n -ge 1 -and $n -le $projects.Count) {
      return $projects[$n - 1]
    }
    Write-Host "Out of range." -ForegroundColor Red
  }
}

function Select-ProjectOrNewForFirstRun([string]$Scope, [string]$TokenStorePath = "") {
  Write-Step "Loading your Vercel projects from token/API..."
  try {
    $projects = Get-ProjectsForSelection -Scope $Scope -TokenStorePath $TokenStorePath
  } catch {
    Write-Host "Could not load projects list. Continuing with NEW-project flow." -ForegroundColor DarkYellow
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkGray
    $projects = @()
  }

  Write-Host ""
  Write-Host "Choose a target to continue:" -ForegroundColor Cyan
  if ($projects.Count -gt 0) {
    for ($i = 0; $i -lt $projects.Count; $i++) {
      $scopeText = ""
      if ($projects[$i].PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$projects[$i].Scope)) {
        $scopeText = "  (scope: $([string]$projects[$i].Scope))"
      }
      Write-Host ("[{0}] Use existing project: {1}{2}" -f ($i + 1), $projects[$i].Name, $scopeText)
    }
  } else {
    Write-Host "No existing projects found in current scope/account." -ForegroundColor DarkYellow
  }

  $newIndex = $projects.Count + 1
  Write-Host ("[{0}] Deploy as NEW project" -f $newIndex)

  $defaultChoice = if ($projects.Count -gt 0) { "1" } else { [string]$newIndex }
  while ($true) {
    $choiceRaw = Read-Default "Select one option" $defaultChoice
    $n = 0
    if (-not [int]::TryParse($choiceRaw, [ref]$n)) {
      Write-Host "Invalid number." -ForegroundColor Red
      continue
    }

    if ($n -eq $newIndex) {
      return @{
        Mode = "new"
        ProjectName = ""
        Scope = ""
      }
    }

    if ($n -ge 1 -and $n -le $projects.Count) {
      return @{
        Mode = "existing"
        ProjectName = $projects[$n - 1].Name
        Scope = if ($projects[$n - 1].PSObject.Properties.Name -contains "Scope") { [string]$projects[$n - 1].Scope } else { "" }
      }
    }

    Write-Host "Out of range. Choose one of the listed options." -ForegroundColor Red
  }
}

function Get-VercelApiToken([string]$TokenStorePath) {
  if (-not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
    return $env:VERCEL_TOKEN
  }
  $saved = Load-TokenSecure -Path $TokenStorePath
  if (-not [string]::IsNullOrWhiteSpace($saved)) {
    return $saved
  }
  return ""
}

function New-ScopeQuery([string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($Scope)) { return "" }
  $s = $Scope.Trim()
  if ($s.StartsWith("team_")) {
    return ("teamId={0}" -f [uri]::EscapeDataString($s))
  }
  return ("slug={0}" -f [uri]::EscapeDataString($s))
}

function Invoke-VercelApiGet([string]$Path, [string]$Token, [string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Vercel token is required for API mode."
  }
  $url = "https://api.vercel.com$Path"
  $scopeQuery = New-ScopeQuery -Scope $Scope
  if (-not [string]::IsNullOrWhiteSpace($scopeQuery)) {
    if ($url.Contains("?")) { $url = "$url&$scopeQuery" } else { $url = "$url?$scopeQuery" }
  }
  $headers = @{ Authorization = "Bearer $Token" }
  return Invoke-RestMethod -Method Get -Uri $url -Headers $headers -TimeoutSec 45
}

function Invoke-VercelApiPatch([string]$Path, [string]$Token, [string]$Scope, [hashtable]$Body) {
  if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Vercel token is required for API mode."
  }
  $url = "https://api.vercel.com$Path"
  $scopeQuery = New-ScopeQuery -Scope $Scope
  if (-not [string]::IsNullOrWhiteSpace($scopeQuery)) {
    if ($url.Contains("?")) { $url = "$url&$scopeQuery" } else { $url = "$url?$scopeQuery" }
  }
  $headers = @{
    Authorization = "Bearer $Token"
    "Content-Type" = "application/json"
  }
  $json = $Body | ConvertTo-Json -Depth 20
  return Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $json -TimeoutSec 45
}

function Invoke-VercelApiDelete([string]$Path, [string]$Token, [string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Vercel token is required for API mode."
  }
  $url = "https://api.vercel.com$Path"
  $scopeQuery = New-ScopeQuery -Scope $Scope
  if (-not [string]::IsNullOrWhiteSpace($scopeQuery)) {
    if ($url.Contains("?")) { $url = "$url&$scopeQuery" } else { $url = "$url?$scopeQuery" }
  }
  $headers = @{ Authorization = "Bearer $Token" }
  return Invoke-RestMethod -Method Delete -Uri $url -Headers $headers -TimeoutSec 45
}

function Invoke-VercelApiGetJsonLines([string]$Path, [string]$Token, [string]$Scope) {
  if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Vercel token is required for API mode."
  }
  $url = "https://api.vercel.com$Path"
  $scopeQuery = New-ScopeQuery -Scope $Scope
  if (-not [string]::IsNullOrWhiteSpace($scopeQuery)) {
    if ($url.Contains("?")) { $url = "$url&$scopeQuery" } else { $url = "$url?$scopeQuery" }
  }
  $headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/json"
  }
  $resp = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 60
  $content = ""
  if ($resp.Content -is [byte[]]) {
    $content = [System.Text.Encoding]::UTF8.GetString([byte[]]$resp.Content)
  } else {
    $content = [string]$resp.Content
  }
  if ([string]::IsNullOrWhiteSpace($content)) { return @() }
  $items = @()
  foreach ($lineRaw in ($content -split "`n")) {
    $line = ([string]$lineRaw).Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
      $items += ($line | ConvertFrom-Json -ErrorAction Stop)
    } catch {
      # Some hosts return the whole JSONL body as escaped bytes; ignore non-json fragments.
    }
  }
  return @($items)
}

function Try-ResolveTeamSlugFromTeamId([string]$TeamId, [string]$Token) {
  if ([string]::IsNullOrWhiteSpace($TeamId)) { return "" }
  if (-not $TeamId.StartsWith("team_")) { return "" }
  try {
    $resp = Invoke-VercelApiGet -Path "/v2/teams?limit=100" -Token $Token -Scope ""
    if ($null -eq $resp -or $null -eq $resp.teams) { return "" }
    $hit = $resp.teams | Where-Object { [string]$_.id -eq $TeamId } | Select-Object -First 1
    if ($null -eq $hit) { return "" }
    return [string]$hit.slug
  } catch {
    return ""
  }
}

function Convert-ApiTimestampToText($ts) {
  if ($null -eq $ts) { return "-" }
  try {
    $n = [int64]$ts
    if ($n -le 0) { return "-" }
    $dto = [DateTimeOffset]::FromUnixTimeMilliseconds($n).ToLocalTime()
    return $dto.ToString("yyyy-MM-dd HH:mm:ss")
  } catch {
    return [string]$ts
  }
}

function Get-ProjectDeploymentsApi([string]$ProjectId, [string]$Scope, [string]$Token, [int]$Limit = 20) {
  if ([string]::IsNullOrWhiteSpace($ProjectId)) { return @() }
  $path = "/v6/deployments?projectId=$([uri]::EscapeDataString($ProjectId))&limit=$Limit"
  $resp = Invoke-VercelApiGet -Path $path -Token $Token -Scope $Scope
  if ($null -eq $resp -or $null -eq $resp.deployments) { return @() }
  return @($resp.deployments)
}

function Get-ProjectEnvEntriesApi([string]$ProjectName, [string]$Scope, [string]$Token, [int]$Limit = 200) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { return @() }
  # Ask API for decrypted values when possible (depends on token/permissions/type).
  $path = "/v10/projects/$([uri]::EscapeDataString($ProjectName))/env?limit=$Limit&decrypt=true"
  $resp = Invoke-VercelApiGet -Path $path -Token $Token -Scope $Scope
  if ($null -eq $resp -or $null -eq $resp.envs) { return @() }
  return @($resp.envs)
}

function Normalize-EnvTargets($t) {
  if ($null -eq $t) { return @() }
  if ($t -is [System.Array]) {
    $arr = @()
    foreach ($x in $t) {
      if ($null -ne $x) {
        $s = [string]$x
        if (-not [string]::IsNullOrWhiteSpace($s)) { $arr += $s }
      }
    }
    return @($arr | Select-Object -Unique)
  }
  $single = [string]$t
  if ([string]::IsNullOrWhiteSpace($single)) { return @() }
  return @($single)
}

function Test-IsMaskedOrEncryptedEnvValue([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
  $v = $Value.Trim()
  # Common Vercel masked/encrypted payload patterns returned by API.
  if ($v.StartsWith("eyJ2IjoidjIi")) { return $true }  # JSON v2 blob (base64-like prefix)
  if ($v.StartsWith("ENC[")) { return $true }
  # Long base64-looking tokens are usually not human-readable secrets.
  if ($v.Length -ge 80 -and $v -match '^[A-Za-z0-9+/=]+$') { return $true }
  return $false
}

function Get-EnvValuePreview($envObj) {
  try {
    $v = ""
    if ($envObj.PSObject.Properties.Name -contains "decrypted") {
      $dv = [string]$envObj.decrypted
      if (-not [string]::IsNullOrWhiteSpace($dv)) { $v = $dv }
    }
    if ([string]::IsNullOrWhiteSpace($v) -and $envObj.PSObject.Properties.Name -contains "decryptedValue") {
      $dv2 = [string]$envObj.decryptedValue
      if (-not [string]::IsNullOrWhiteSpace($dv2)) { $v = $dv2 }
    }
    if ([string]::IsNullOrWhiteSpace($v)) {
      $v = [string]$envObj.value
    }
    if (Test-IsMaskedOrEncryptedEnvValue -Value $v) { return "(hidden/sensitive)" }
    if ($v.Length -gt 90) { return ($v.Substring(0, 90) + "...") }
    return $v
  } catch {
    return "(hidden/sensitive)"
  }
}

function Parse-DotEnvFileToMap([string]$Path) {
  $map = @{}
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $map }
  $lines = Get-Content $Path -ErrorAction SilentlyContinue
  foreach ($ln in $lines) {
    $line = [string]$ln
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $trim = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trim)) { continue }
    if ($trim.StartsWith("#")) { continue }
    if ($trim.StartsWith("export ")) { $trim = $trim.Substring(7).Trim() }
    $eq = $trim.IndexOf("=")
    if ($eq -le 0) { continue }

    $k = $trim.Substring(0, $eq).Trim()
    $v = $trim.Substring($eq + 1)
    if ([string]::IsNullOrWhiteSpace($k)) { continue }

    if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
      $v = $v.Substring(1, $v.Length - 2) -replace '\\"', '"'
    } elseif ($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")) {
      $v = $v.Substring(1, $v.Length - 2)
    }

    $map[$k] = @{
      exists = $true
      value = [string]$v
      source = "cli_pull"
    }
  }
  return $map
}

function Get-EnvMapFromCliPull([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  $map = @{}
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) { return $map }

  $Scope = Normalize-ScopeForCli -Scope $Scope
  $tmp = Join-Path $env:TEMP ("xhttprelay-env-" + [Guid]::NewGuid().ToString("N") + ".env")
  try {
    $args = @("env", "pull", $tmp, "--environment", "production", "--yes")
    if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
    $args += @("--token", $token)
    $res = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
    if ($res.ExitCode -ne 0) { return @{} }
    $map = Parse-DotEnvFileToMap -Path $tmp
    return $map
  } catch {
    return @{}
  } finally {
    try { if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } } catch {}
  }
}

function Show-DeploymentEnvConfig([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  Write-Step "Deployment ENV inspector"
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No API token available. Use token auth mode first."
  }

  $projectId = Resolve-ProjectApiId -ProjectName $ProjectName -Scope $Scope -Token $token
  if ([string]::IsNullOrWhiteSpace($projectId)) {
    throw "Could not resolve project id via API."
  }

  $deps = Get-ProjectDeploymentsApi -ProjectId $projectId -Scope $Scope -Token $token -Limit 20
  $selectedDeployment = $null
  $selectedTarget = "production"

  if ($deps.Count -gt 0) {
    Write-Host "Choose deployment:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $deps.Count; $i++) {
      $d = $deps[$i]
      $target = [string]$d.target
      if ([string]::IsNullOrWhiteSpace($target)) { $target = "-" }
      $state = [string]$d.state
      if ([string]::IsNullOrWhiteSpace($state)) { $state = "-" }
      $created = Convert-ApiTimestampToText $d.createdAt
      $alias = "-"
      try {
        if ($null -ne $d.url -and -not [string]::IsNullOrWhiteSpace([string]$d.url)) {
          $alias = [string]$d.url
        }
      } catch {}
      Write-Host ("[{0}] {1} | target={2} | state={3} | {4}" -f ($i + 1), $created, $target, $state, $alias)
    }
    $pickRaw = Read-Default "Select deployment index" "1"
    $pick = 1
    [void][int]::TryParse($pickRaw, [ref]$pick)
    if ($pick -lt 1 -or $pick -gt $deps.Count) { $pick = 1 }
    $selectedDeployment = $deps[$pick - 1]
    $st = [string]$selectedDeployment.target
    if (-not [string]::IsNullOrWhiteSpace($st)) { $selectedTarget = $st }
  } else {
    Write-Host "No deployments returned by API. Showing project ENV list only." -ForegroundColor DarkYellow
  }

  Write-Host ""
  if ($null -ne $selectedDeployment) {
    Write-Host "Selected deployment summary:" -ForegroundColor Yellow
    Write-Host ("id:      {0}" -f [string]$selectedDeployment.uid)
    Write-Host ("target:  {0}" -f $selectedTarget)
    Write-Host ("state:   {0}" -f [string]$selectedDeployment.state)
    Write-Host ("created: {0}" -f (Convert-ApiTimestampToText $selectedDeployment.createdAt))
  } else {
    Write-Host ("Target fallback for filtering: {0}" -f $selectedTarget) -ForegroundColor Yellow
  }
  Write-Host ""

  $envs = Get-ProjectEnvEntriesApi -ProjectName $ProjectName -Scope $Scope -Token $token -Limit 200
  if ($envs.Count -eq 0) {
    Write-Host "No ENV entries found via API." -ForegroundColor DarkYellow
    return
  }

  $rows = @()
  foreach ($e in $envs) {
    $key = [string]$e.key
    if ([string]::IsNullOrWhiteSpace($key)) { continue }
    $targets = Normalize-EnvTargets $e.target
    $targetText = if ($targets.Count -gt 0) { ($targets -join ",") } else { "all/unknown" }
    $effective = $false
    if ($targets.Count -eq 0) {
      $effective = $true
    } elseif ($targets -contains $selectedTarget) {
      $effective = $true
    }
    $rows += [pscustomobject]@{
      Effective = $(if ($effective) { "yes" } else { "no" })
      Key = $key
      ValuePreview = (Get-EnvValuePreview -envObj $e)
      Targets = $targetText
      UpdatedAt = (Convert-ApiTimestampToText $e.updatedAt)
    }
  }

  Write-Host ("ENV entries for project '{0}' (effective target: {1})" -f $ProjectName, $selectedTarget) -ForegroundColor Cyan
  Write-Host "Note: sensitive values may be masked by Vercel API." -ForegroundColor DarkGray
  $rows |
    Sort-Object @{ Expression = "Effective"; Descending = $true }, @{ Expression = "Key"; Descending = $false } |
    Format-Table Effective, Key, ValuePreview, Targets, UpdatedAt -AutoSize |
    Out-Host

  $save = Read-Default "Save this ENV report to txt file? (Y/n)" "y"
  if ($save.ToLowerInvariant() -ne "n") {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $out = Join-Path $scriptDir ("env-report-{0}-{1}.txt" -f $ProjectName, $stamp)
    $header = @(
      "XHTTPRelayECO ENV Report",
      ("project={0}" -f $ProjectName),
      ("selected_target={0}" -f $selectedTarget),
      ("generated_at={0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")),
      ""
    )
    $table = ($rows |
      Sort-Object @{ Expression = "Effective"; Descending = $true }, @{ Expression = "Key"; Descending = $false } |
      Format-Table Effective, Key, ValuePreview, Targets, UpdatedAt -AutoSize | Out-String)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($out, (($header -join [Environment]::NewLine) + [Environment]::NewLine + $table), $utf8NoBom)
    Write-Host ("ENV report saved: {0}" -f $out) -ForegroundColor Green
  }
}

function Build-ScopeCandidates([string]$Scope, [string]$Token, [string]$ProjectRoot = "") {
  $candidates = @()
  if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    $candidates += $Scope
    if ($Scope.StartsWith("team_")) {
      $slugFromInputTeam = Try-ResolveTeamSlugFromTeamId -TeamId $Scope -Token $Token
      if (-not [string]::IsNullOrWhiteSpace($slugFromInputTeam)) { $candidates += $slugFromInputTeam }
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $linkedTeamId = Get-LinkedTeamId -ProjectRoot $ProjectRoot
    if (-not [string]::IsNullOrWhiteSpace($linkedTeamId)) {
      $candidates += $linkedTeamId
      $slugFromLinkedTeam = Try-ResolveTeamSlugFromTeamId -TeamId $linkedTeamId -Token $Token
      if (-not [string]::IsNullOrWhiteSpace($slugFromLinkedTeam)) { $candidates += $slugFromLinkedTeam }
    }
  }
  $candidates += ""
  return @($candidates | Where-Object { $_ -ne $null } | Select-Object -Unique)
}

function Get-ObjectPropertyValue($Obj, [string[]]$Names) {
  if ($null -eq $Obj) { return $null }
  foreach ($name in $Names) {
    if ($Obj.PSObject.Properties.Name -contains $name) {
      return $Obj.$name
    }
  }
  return $null
}

function Convert-ToDoubleSafe($Value, [double]$Default = 0) {
  if ($null -eq $Value) { return $Default }
  try {
    $s = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($s)) { return $Default }
    return [double]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)
  } catch {
    return $Default
  }
}

function Format-CompactNumber([double]$Value) {
  $abs = [Math]::Abs($Value)
  if ($abs -ge 1000000000) { return ("{0:N2}B" -f ($Value / 1000000000)) }
  if ($abs -ge 1000000) { return ("{0:N2}M" -f ($Value / 1000000)) }
  if ($abs -ge 1000) { return ("{0:N1}K" -f ($Value / 1000)) }
  if ([Math]::Abs($Value - [Math]::Round($Value)) -lt 0.001) { return ("{0:N0}" -f $Value) }
  return ("{0:N2}" -f $Value)
}

function Format-DurationHours([double]$Hours) {
  if ($Hours -lt 0) { $Hours = 0 }
  if ($Hours -lt 1) {
    return ("{0:N0}m" -f ($Hours * 60))
  }
  $whole = [Math]::Floor($Hours)
  $mins = [Math]::Round(($Hours - $whole) * 60)
  if ($mins -le 0) { return ("{0:N0}h" -f $whole) }
  return ("{0:N0}h {1:N0}m" -f $whole, $mins)
}

function Get-BillingLimitCatalog {
  # Vercel does not always include plan allowance values in FOCUS charge rows.
  # These defaults mirror the visible Pro usage panel and are shown as estimated plan allowances.
  return @{
    "fast data transfer" = @{ Quantity = 100; Unit = "gigabyte"; Label = "100 GB" }
    "fast origin transfer" = @{ Quantity = 10; Unit = "gigabyte"; Label = "10 GB" }
    "edge requests" = @{ Quantity = 1000000; Unit = "requests"; Label = "1M" }
    "function invocations" = @{ Quantity = 1000000; Unit = "invocations"; Label = "1M" }
    "fluid active cpu" = @{ Quantity = 4; Unit = "hour"; Label = "4h" }
    "fluid provisioned memory" = @{ Quantity = 360; Unit = "gigabyte-hour"; Label = "360 GB-Hrs" }
    "edge request cpu duration" = @{ Quantity = 1; Unit = "hour"; Label = "1h" }
    "edge requests - additional cpu duration" = @{ Quantity = 1; Unit = "hour"; Label = "1h" }
    "microfrontends routing" = @{ Quantity = 50000; Unit = "requests"; Label = "50K" }
    "isr reads" = @{ Quantity = 1000000; Unit = "reads"; Label = "1M" }
    "isr writes" = @{ Quantity = 200000; Unit = "writes"; Label = "200K" }
  }
}

function Normalize-BillingServiceName([string]$ServiceName) {
  $s = Collapse-Whitespace -Text $ServiceName
  if ([string]::IsNullOrWhiteSpace($s)) { return "Unknown" }
  if ($s -match "(?i)^edge requests.*additional cpu duration") { return "Edge Requests - Additional CPU Duration" }
  if ($s -match "(?i)^edge request cpu duration") { return "Edge Request CPU Duration" }
  return $s
}

function Convert-BillingQuantityForDisplay([double]$Quantity, [string]$Unit, [string]$ServiceName) {
  $u = ([string]$Unit).Trim().ToLowerInvariant()
  $name = ([string]$ServiceName).Trim().ToLowerInvariant()
  $value = $Quantity
  $unitLabel = $Unit
  if ($u -match "gigabyte-hour|gb-?hrs|gb-?hours") {
    return @{ Value = $value; Unit = "gigabyte-hour"; Text = ("{0:N1} GB-Hrs" -f $value) }
  }
  if ($u -match "byte" -and $u -notmatch "gigabyte") {
    $gb = $value / 1GB
    return @{ Value = $gb; Unit = "gigabyte"; Text = ("{0:N2} GB" -f $gb) }
  }
  if ($u -match "gigabyte|gibibyte|\bgb\b" -or $name -match "transfer") {
    return @{ Value = $value; Unit = "gigabyte"; Text = ("{0:N2} GB" -f $value) }
  }
  if ($u -match "second") {
    $hours = $value / 3600
    return @{ Value = $hours; Unit = "hour"; Text = (Format-DurationHours -Hours $hours) }
  }
  if ($u -match "minute") {
    $hours = $value / 60
    return @{ Value = $hours; Unit = "hour"; Text = (Format-DurationHours -Hours $hours) }
  }
  if ($u -match "hour" -or $name -match "cpu") {
    return @{ Value = $value; Unit = "hour"; Text = (Format-DurationHours -Hours $value) }
  }
  if ($u -match "request|invocation|read|write|project|transformation") {
    return @{ Value = $value; Unit = $u; Text = (Format-CompactNumber -Value $value) }
  }
  if ([string]::IsNullOrWhiteSpace($unitLabel)) { $unitLabel = "units" }
  return @{ Value = $value; Unit = $u; Text = ("{0} {1}" -f (Format-CompactNumber -Value $value), $unitLabel) }
}

function Get-BillingUsageRatioText([string]$ServiceName, [double]$Quantity, [string]$Unit) {
  $display = Convert-BillingQuantityForDisplay -Quantity $Quantity -Unit $Unit -ServiceName $ServiceName
  $limits = Get-BillingLimitCatalog
  $key = ([string](Normalize-BillingServiceName -ServiceName $ServiceName)).ToLowerInvariant()
  if (-not $limits.ContainsKey($key)) {
    return [string]$display.Text
  }
  $limit = $limits[$key]
  return ("{0} / {1}" -f [string]$display.Text, [string]$limit.Label)
}

function Get-BillingRowColor([string]$ServiceName, [double]$Quantity, [string]$Unit, [double]$Cost) {
  $display = Convert-BillingQuantityForDisplay -Quantity $Quantity -Unit $Unit -ServiceName $ServiceName
  $limits = Get-BillingLimitCatalog
  $key = ([string](Normalize-BillingServiceName -ServiceName $ServiceName)).ToLowerInvariant()
  if ($limits.ContainsKey($key)) {
    $lim = [double]$limits[$key].Quantity
    if ($lim -gt 0) {
      $ratio = [double]$display.Value / $lim
      if ($ratio -ge 1) { return "Red" }
      if ($ratio -ge 0.8) { return "Yellow" }
    }
  }
  if ($Cost -gt 0) { return "Yellow" }
  return "Gray"
}

function Get-VercelBillingCharges([string]$Scope, [string]$TokenStorePath, [DateTime]$From, [DateTime]$To) {
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No API token available. Use token auth mode first."
  }
  $fromIso = $From.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
  $toIso = $To.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
  $path = "/v1/billing/charges?from=$([uri]::EscapeDataString($fromIso))&to=$([uri]::EscapeDataString($toIso))"
  $scopeCandidates = Build-ScopeCandidates -Scope $Scope -Token $token -ProjectRoot $scriptDir
  $lastErr = ""
  foreach ($sc in $scopeCandidates) {
    try {
      $rows = Invoke-VercelApiGetJsonLines -Path $path -Token $token -Scope $sc
      return @{
        Scope = $sc
        Rows = @($rows)
      }
    } catch {
      $lastErr = Get-ApiErrorText $_
    }
  }
  throw ("Could not load billing usage from Vercel API. {0}" -f $lastErr)
}

function Get-BillingProjectTagText($Row, [string]$TagName) {
  try {
    if ($null -eq $Row.Tags) { return "" }
    if ($Row.Tags.PSObject.Properties.Name -contains $TagName) {
      return [string]$Row.Tags.$TagName
    }
  } catch {}
  return ""
}

function Show-BillingUsageMonitor([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  Write-Step "Billing / Usage monitor"
  Write-Host "Data source: Vercel REST API /v1/billing/charges (FOCUS JSONL)." -ForegroundColor Cyan
  Write-Host "Plan limits shown as 23GB/100GB style are estimated Pro allowances when Vercel does not return limits in charge rows." -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "[0] Back to main menu"
  Write-Host "[1] Current month to date (default)"
  Write-Host "[2] Last 7 days"
  Write-Host "[3] Last 30 days"
  Write-Host "[4] Custom date range"
  $pick = Read-Default "Select billing window" "1"
  if ($pick -eq "0") { return }

  $now = Get-Date
  $from = Get-Date -Year $now.Year -Month $now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
  $to = $now
  switch ($pick) {
    "2" { $from = $now.AddDays(-7) }
    "3" { $from = $now.AddDays(-30) }
    "4" {
      $fromRaw = Read-Default "From date (YYYY-MM-DD, 0 = Back)" $from.ToString("yyyy-MM-dd")
      if ($fromRaw -eq "0") { return }
      $toRaw = Read-Default "To date (YYYY-MM-DD)" $now.ToString("yyyy-MM-dd")
      try {
        $from = [DateTime]::ParseExact($fromRaw, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $to = ([DateTime]::ParseExact($toRaw, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)).AddDays(1).AddSeconds(-1)
      } catch {
        throw "Invalid date format. Use YYYY-MM-DD."
      }
    }
  }

  $filterProject = $false
  if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    $ans = Read-Default ("Filter to selected project '{0}' only? (y/N)" -f $ProjectName) "n"
    $filterProject = ($ans.ToLowerInvariant() -eq "y")
  }

  $loaded = Get-VercelBillingCharges -Scope $Scope -TokenStorePath $TokenStorePath -From $from -To $to
  $rows = @($loaded.Rows)
  if ($filterProject) {
    $rows = @($rows | Where-Object {
      (Get-BillingProjectTagText -Row $_ -TagName "ProjectName") -eq $ProjectName
    })
  }

  Write-Host ""
  Write-Host ("Window: {0} -> {1}" -f $from.ToString("yyyy-MM-dd HH:mm"), $to.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor Cyan
  if (-not [string]::IsNullOrWhiteSpace([string]$loaded.Scope)) {
    Write-Host ("Scope used: {0}" -f [string]$loaded.Scope) -ForegroundColor DarkGray
  }
  if ($filterProject) {
    Write-Host ("Project filter: {0}" -f $ProjectName) -ForegroundColor DarkGray
  }

  if ($rows.Count -eq 0) {
    Write-Host "No billing usage rows returned for this window/filter." -ForegroundColor DarkYellow
    return
  }

  $groups = @{}
  foreach ($r in $rows) {
    $service = [string](Get-ObjectPropertyValue -Obj $r -Names @("ServiceName", "serviceName", "Product", "product"))
    $service = Normalize-BillingServiceName -ServiceName $service
    $unit = [string](Get-ObjectPropertyValue -Obj $r -Names @("ConsumedUnit", "consumedUnit", "Unit", "unit"))
    $qty = Convert-ToDoubleSafe (Get-ObjectPropertyValue -Obj $r -Names @("ConsumedQuantity", "consumedQuantity", "UsageQuantity", "usageQuantity", "quantity"))
    $billed = Convert-ToDoubleSafe (Get-ObjectPropertyValue -Obj $r -Names @("BilledCost", "billedCost", "Charge", "charge", "Cost", "cost"))
    $effective = Convert-ToDoubleSafe (Get-ObjectPropertyValue -Obj $r -Names @("EffectiveCost", "effectiveCost", "PricingQuantity", "pricingQuantity"))
    $category = [string](Get-ObjectPropertyValue -Obj $r -Names @("ServiceCategory", "serviceCategory", "ChargeCategory", "chargeCategory"))
    if ([string]::IsNullOrWhiteSpace($service)) { $service = "Unknown" }
    if (-not $groups.ContainsKey($service)) {
      $groups[$service] = [pscustomobject]@{
        Service = $service
        Category = $category
        Unit = $unit
        Quantity = 0.0
        BilledCost = 0.0
        EffectiveCost = 0.0
      }
    }
    $groups[$service].Quantity += $qty
    $groups[$service].BilledCost += $billed
    $groups[$service].EffectiveCost += $effective
    if ([string]::IsNullOrWhiteSpace([string]$groups[$service].Unit) -and -not [string]::IsNullOrWhiteSpace($unit)) {
      $groups[$service].Unit = $unit
    }
    if ([string]::IsNullOrWhiteSpace([string]$groups[$service].Category) -and -not [string]::IsNullOrWhiteSpace($category)) {
      $groups[$service].Category = $category
    }
  }

  $summaryRows = @()
  foreach ($g in $groups.Values) {
    $summaryRows += [pscustomobject]@{
      Product = [string]$g.Service
      Usage = (Get-BillingUsageRatioText -ServiceName ([string]$g.Service) -Quantity ([double]$g.Quantity) -Unit ([string]$g.Unit))
      Charge = ("${0:N2}" -f ([double]$g.BilledCost))
      Value = ("${0:N2}" -f ([double]$g.EffectiveCost))
      RawQuantity = [double]$g.Quantity
      RawUnit = [string]$g.Unit
      RawCost = [double]$g.BilledCost
    }
  }

  $totalCharge = 0.0
  $totalValue = 0.0
  foreach ($g in $groups.Values) {
    $totalCharge += [double]$g.BilledCost
    $totalValue += [double]$g.EffectiveCost
  }

  Write-Host ""
  Write-Host "Usage summary:" -ForegroundColor Cyan
  foreach ($row in ($summaryRows | Sort-Object @{ Expression = "RawCost"; Descending = $true }, Product)) {
    $color = Get-BillingRowColor -ServiceName $row.Product -Quantity $row.RawQuantity -Unit $row.RawUnit -Cost $row.RawCost
    Write-Host (" - {0}: {1} | Charge {2}" -f $row.Product, $row.Usage, $row.Charge) -ForegroundColor $color
  }

  Write-Host ""
  Write-Host ("Total charge in this window: ${0:N2}" -f $totalCharge) -ForegroundColor Yellow
  Write-Host ("Effective usage value before included/committed allowances: ${0:N2}" -f $totalValue) -ForegroundColor DarkGray
  Write-Host "Note: Charge is the API billed cost for the selected window. Value is useful for seeing real resource value even when included credit covers it." -ForegroundColor DarkGray

  $save = Read-Default "Save billing usage report to txt file? (y/N)" "n"
  if ($save.ToLowerInvariant() -eq "y") {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $out = Join-Path $scriptDir ("billing-usage-{0}.txt" -f $stamp)
    $lines = @()
    $lines += "XHTTPRelayECO Billing Usage Report"
    $lines += ("generated_at={0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
    $lines += ("window_from={0}" -f $from.ToString("yyyy-MM-dd HH:mm:ss"))
    $lines += ("window_to={0}" -f $to.ToString("yyyy-MM-dd HH:mm:ss"))
    $lines += ("scope={0}" -f [string]$loaded.Scope)
    if ($filterProject) { $lines += ("project_filter={0}" -f $ProjectName) }
    $lines += ("total_charge_usd={0:N4}" -f $totalCharge)
    $lines += ("effective_value_usd={0:N4}" -f $totalValue)
    $lines += ""
    foreach ($row in ($summaryRows | Sort-Object Product)) {
      $lines += ("{0} | usage={1} | charge={2} | value={3}" -f $row.Product, $row.Usage, $row.Charge, $row.Value)
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($out, $lines, $utf8NoBom)
    Write-Host ("Billing report saved: {0}" -f $out) -ForegroundColor Green
  }
}

function Get-ApiErrorText($errObj) {
  $msg = ""
  try {
    $msg = [string]$errObj.Exception.Message
  } catch {}
  try {
    $resp = $errObj.Exception.Response
    if ($null -ne $resp -and $resp.GetResponseStream) {
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $body = $reader.ReadToEnd()
      if (-not [string]::IsNullOrWhiteSpace($body)) {
        if ($body.Length -gt 280) { $body = $body.Substring(0, 280) + "..." }
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = $body } else { $msg = "$msg | $body" }
      }
    }
  } catch {}
  if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "unknown api error" }
  return $msg
}

function Disable-ProjectVercelAuthentication([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    return @{ Applied = $false; Status = "unknown"; Message = "project_missing" }
  }
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Deployment protection sync skipped: token not available for API." -ForegroundColor DarkYellow
    return @{ Applied = $false; Status = "unknown"; Message = "token_missing" }
  }

  $projectId = Resolve-ProjectApiId -ProjectName $ProjectName -Scope $Scope -Token $token
  if ([string]::IsNullOrWhiteSpace($projectId)) {
    Write-Host "Deployment protection sync skipped: could not resolve project id via API." -ForegroundColor DarkYellow
    return @{ Applied = $false; Status = "unknown"; Message = "project_id_missing" }
  }

  $pathCandidates = @(
    "/v9/projects/$([uri]::EscapeDataString($projectId))",
    "/v9/projects/$([uri]::EscapeDataString($ProjectName))"
  )
  $payloads = @(
    @{ ssoProtection = $null }
  )
  $scopeCandidates = Build-ScopeCandidates -Scope $Scope -Token $token -ProjectRoot $scriptDir

  $lastErr = ""
  foreach ($sc in $scopeCandidates) {
    foreach ($path in $pathCandidates) {
      foreach ($payload in $payloads) {
        try {
          $null = Invoke-VercelApiPatch -Path $path -Token $token -Scope $sc -Body $payload
          Write-Host "Deployment protection synced: Vercel Authentication set to OFF." -ForegroundColor Green
          return @{ Applied = $true; Status = "off"; Message = "patched" }
        } catch {
          $lastErr = Get-ApiErrorText $_
        }
      }
    }
  }

  Write-Host "Deployment protection sync skipped: API did not accept patch for this account/project." -ForegroundColor DarkYellow
  if (-not [string]::IsNullOrWhiteSpace($lastErr)) {
    Write-Host ("API response (short): {0}" -f $lastErr) -ForegroundColor DarkGray
  }
  Write-Host "Tip: in Vercel Dashboard -> Team/Project -> Deployment Protection, disable Vercel Authentication and redeploy." -ForegroundColor DarkYellow
  return @{ Applied = $false; Status = "unknown"; Message = $lastErr }
}

function Apply-ProjectRuntimeSettings([string]$ProjectName, [string]$Scope, [string]$TokenStorePath, [string]$Region, [int]$FunctionTimeoutSec = 60, [bool]$FluidEnabled = $true, [string]$FunctionCpu = "") {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { return $false }
  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Runtime settings sync skipped: token not available for API." -ForegroundColor DarkYellow
    return $false
  }

  $projectId = Resolve-ProjectApiId -ProjectName $ProjectName -Scope $Scope -Token $token
  if ([string]::IsNullOrWhiteSpace($projectId)) {
    Write-Host "Runtime settings sync skipped: could not resolve project id via API." -ForegroundColor DarkYellow
    return $false
  }

  $regions = Normalize-RegionList -RegionText $Region
  if ($regions.Count -eq 0) { $regions = @("iad1") }
  $timeoutMax = if ($FluidEnabled) { 800 } else { 300 }
  $timeoutSec = [Math]::Max(30, [Math]::Min($timeoutMax, $FunctionTimeoutSec))
  $cpu = ([string]$FunctionCpu).Trim().ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($cpu)) {
    $cpu = "standard"
  }
  if ($cpu -notin @("standard_legacy", "standard", "performance")) {
    $cpu = "standard"
  }
  $projectPathCandidates = @(
    "/v9/projects/$([uri]::EscapeDataString($projectId))",
    "/v9/projects/$([uri]::EscapeDataString($ProjectName))"
  )

  $fullResourceConfig = @{
    fluid = $FluidEnabled
    functionDefaultTimeout = $timeoutSec
    functionDefaultRegions = @($regions)
    functionDefaultMemoryType = $cpu
  }

  # Keep fallbacks aligned with Vercel project update schema variants.
  # Some accounts reject specific resource keys depending on plan/feature flags.
  $payloads = @(
    @{ resourceConfig = $fullResourceConfig },
    @{ resourceConfig = @{ fluid = $FluidEnabled; functionDefaultTimeout = $timeoutSec; functionDefaultRegions = @($regions) } },
    @{ resourceConfig = @{ fluid = $FluidEnabled; functionDefaultTimeout = $timeoutSec; functionDefaultMemoryType = $cpu } },
    @{ resourceConfig = @{ functionDefaultTimeout = $timeoutSec; functionDefaultRegions = @($regions); functionDefaultMemoryType = $cpu } },
    @{ resourceConfig = @{ functionDefaultRegions = @($regions); functionDefaultMemoryType = $cpu } },
    @{ resourceConfig = @{ functionDefaultMemoryType = $cpu } },
    @{ resourceConfig = @{ functionDefaultTimeout = $timeoutSec } },
    @{ resourceConfig = @{ functionDefaultRegions = @($regions) } }
  )

  $scopeCandidates = Build-ScopeCandidates -Scope $Scope -Token $token -ProjectRoot $scriptDir

  $lastErr = ""
  foreach ($sc in $scopeCandidates) {
    foreach ($path in $projectPathCandidates) {
      foreach ($payload in $payloads) {
        try {
          $null = Invoke-VercelApiPatch -Path $path -Token $token -Scope $sc -Body $payload
          Write-Host ("Runtime settings synced by API: fluid={0}, timeout={1}s, regions={2}, cpu={3}" -f $(if ($FluidEnabled) { "on" } else { "off" }), $timeoutSec, ($regions -join ","), $cpu) -ForegroundColor Green
          return $true
        } catch {
          $lastErr = Get-ApiErrorText $_
        }
      }
    }
  }

  Write-Host "Runtime settings sync skipped: API did not accept project runtime patch for this account/project." -ForegroundColor DarkYellow
  if (-not [string]::IsNullOrWhiteSpace($lastErr)) {
    Write-Host ("API response (short): {0}" -f $lastErr) -ForegroundColor DarkGray
  }
  Write-Host "Tip: in Vercel Dashboard -> Project Settings -> Functions, set Fluid/Timeout/Region manually once, then redeploy." -ForegroundColor DarkYellow
  return $false
}

function Resolve-ProjectApiInfo([string]$ProjectName, [string]$Scope, [string]$Token) {
  if ([string]::IsNullOrWhiteSpace($ProjectName) -or [string]::IsNullOrWhiteSpace($Token)) { return $null }

  $scopeCandidates = Build-ScopeCandidates -Scope $Scope -Token $Token -ProjectRoot $scriptDir
  foreach ($sc in $scopeCandidates) {
    try {
      $resp = Invoke-VercelApiGet -Path "/v9/projects?limit=100" -Token $Token -Scope $sc
      if ($null -eq $resp -or $null -eq $resp.projects) { continue }
      $hit = $resp.projects | Where-Object { [string]$_.name -eq $ProjectName } | Select-Object -First 1
      if ($null -eq $hit) { continue }

      $projectId = if ($hit.id) { [string]$hit.id } else { "" }
      $accountId = ""
      if ($hit.PSObject.Properties.Name -contains "accountId" -and $hit.accountId) {
        $accountId = [string]$hit.accountId
      }
      if ([string]::IsNullOrWhiteSpace($accountId)) {
        try {
          $userResp = Invoke-VercelApiGet -Path "/v2/user" -Token $Token -Scope ""
          if ($null -ne $userResp -and $null -ne $userResp.user -and $userResp.user.id) {
            $accountId = [string]$userResp.user.id
          }
        } catch {}
      }

      $ownerScope = ""
      if ($accountId.StartsWith("team_")) {
        $slug = Try-ResolveTeamSlugFromTeamId -TeamId $accountId -Token $Token
        $ownerScope = if (-not [string]::IsNullOrWhiteSpace($slug)) { $slug } else { $accountId }
      } elseif (-not [string]::IsNullOrWhiteSpace($sc) -and -not $sc.StartsWith("team_")) {
        $ownerScope = Normalize-ScopeForCli -Scope $sc
      }

      return [PSCustomObject]@{
        Name = $ProjectName
        Id = $projectId
        AccountId = $accountId
        Scope = $ownerScope
      }
    } catch {}
  }

  try {
    $all = Get-ProjectsFromVercelApi -Scope $Scope -TokenStorePath $tokenStorePath
    $match = $all | Where-Object { [string]$_.Name -eq $ProjectName } | Select-Object -First 1
    if ($null -ne $match) { return $match }
  } catch {}

  return $null
}

function Resolve-ProjectApiId([string]$ProjectName, [string]$Scope, [string]$Token) {
  $info = Resolve-ProjectApiInfo -ProjectName $ProjectName -Scope $Scope -Token $Token
  if ($null -eq $info) { return "" }
  return [string]$info.Id
}

function Get-LatestDeploymentApi([string]$ProjectId, [string]$Scope, [string]$Token) {
  if ([string]::IsNullOrWhiteSpace($ProjectId)) { return $null }
  $path = "/v6/deployments?projectId=$([uri]::EscapeDataString($ProjectId))&target=production&state=READY&limit=1"
  $resp = Invoke-VercelApiGet -Path $path -Token $Token -Scope $Scope
  if ($null -eq $resp -or $null -eq $resp.deployments -or $resp.deployments.Count -eq 0) { return $null }
  return $resp.deployments[0]
}

function Get-DeploymentEventsApi([string]$DeploymentId, [int]$Limit, [string]$Scope, [string]$Token) {
  if ([string]::IsNullOrWhiteSpace($DeploymentId)) { return @() }
  $path = "/v3/deployments/$DeploymentId/events?limit=$Limit"
  $resp = Invoke-VercelApiGet -Path $path -Token $Token -Scope $Scope
  if ($null -eq $resp) { return @() }
  if ($resp -is [System.Array]) { return @($resp) }
  if ($null -ne $resp.events) { return @($resp.events) }
  return @()
}

function Get-RecentLogsCli([string]$ProjectName, [string]$Scope, [int]$Minutes, [string]$TokenStorePath = "") {
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("logs", $ProjectName, "--since", "${Minutes}m", "--limit", "200", "--json", "--no-color")
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $cliToken = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if (-not [string]::IsNullOrWhiteSpace($cliToken)) { $args += @("--token", $cliToken) }
  $res = Invoke-NativeSafe -FilePath $VercelExe -Arguments $args
  if ($res.ExitCode -ne 0 -or (($res.Output | Out-String) -match "(?i)does not support filtering|unknown or unexpected option|--json")) {
    # Fallback for CLI variants that don't support JSON/flag combinations.
    $fallbackArgs = @("logs", $ProjectName, "--since", "${Minutes}m", "--limit", "200", "--no-color")
    if (-not [string]::IsNullOrWhiteSpace($Scope)) { $fallbackArgs += @("--scope", $Scope) }
    if (-not [string]::IsNullOrWhiteSpace($cliToken)) { $fallbackArgs += @("--token", $cliToken) }
    $res = Invoke-NativeSafe -FilePath $VercelExe -Arguments $fallbackArgs
  }
  if ($res.ExitCode -ne 0) {
    return @{
      Ok = $false
      Lines = @($res.Output)
      ErrorText = (($res.Output | Out-String).Trim())
    }
  }
  return @{
    Ok = $true
    Lines = @($res.Output)
    ErrorText = ""
  }
}

function Unlink-LocalProjectIfMatches([string]$ProjectName, [string]$ProjectRoot) {
  try {
    $link = Get-LinkedProjectInfo -ProjectRoot $ProjectRoot
    if ($null -eq $link) { return }
    if ([string]::IsNullOrWhiteSpace($link.ProjectName)) { return }
    if ([string]$link.ProjectName -ne [string]$ProjectName) { return }
    $projJson = Join-Path $ProjectRoot ".vercel\\project.json"
    if (Test-Path $projJson) {
      Remove-Item -LiteralPath $projJson -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Local .vercel link cleaned (deleted project was linked here)." -ForegroundColor DarkYellow
  } catch {}
}

function Remove-SelectedProject([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    throw "No selected project."
  }
  Write-Host ""
  Write-Host "DANGER: project deletion is permanent." -ForegroundColor Red
  Write-Host ("Target project: {0}" -f $ProjectName) -ForegroundColor Yellow
  if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    Write-Host ("Scope: {0}" -f $Scope) -ForegroundColor Yellow
  }
  $c1 = Read-Default "Type DELETE to continue" ""
  if ($c1 -ne "DELETE") {
    Write-Host "Canceled." -ForegroundColor DarkYellow
    return $false
  }
  $c2 = Read-Required ("Type project name to confirm ({0})" -f $ProjectName)
  if ($c2 -ne $ProjectName) {
    Write-Host "Project name mismatch. Canceled." -ForegroundColor Red
    return $false
  }

  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No API token available for project deletion."
  }

  $projectId = Resolve-ProjectApiId -ProjectName $ProjectName -Scope $Scope -Token $token
  $scopeCandidates = Build-ScopeCandidates -Scope $Scope -Token $token -ProjectRoot $scriptDir
  $pathCandidates = @()
  if (-not [string]::IsNullOrWhiteSpace($projectId)) {
    $pathCandidates += "/v9/projects/$([uri]::EscapeDataString($projectId))"
  }
  $pathCandidates += "/v9/projects/$([uri]::EscapeDataString($ProjectName))"
  $pathCandidates = @($pathCandidates | Select-Object -Unique)

  $lastErr = ""
  foreach ($sc in $scopeCandidates) {
    foreach ($p in $pathCandidates) {
      try {
        $null = Invoke-VercelApiDelete -Path $p -Token $token -Scope $sc
        Write-Host ("Project deleted: {0}" -f $ProjectName) -ForegroundColor Green
        Unlink-LocalProjectIfMatches -ProjectName $ProjectName -ProjectRoot $scriptDir
        return $true
      } catch {
        $lastErr = Get-ApiErrorText $_
      }
    }
  }

  Write-Host "API delete did not complete. Trying Vercel CLI delete fallback..." -ForegroundColor DarkYellow
  $cliArgs = @("project", "rm", $ProjectName)
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $cliArgs += @("--scope", $Scope) }
  $cliArgs += @("--token", $token, "--no-color")
  $cliResult = Invoke-NativeSafeWithInput -FilePath $VercelExe -Arguments $cliArgs -InputText "y" -TimeoutSec 180
  $cliText = ($cliResult.Output | Out-String)
  if ($cliResult.ExitCode -eq 0 -and $cliText -match "(?i)(Success|removed)") {
    Write-Host ("Project deleted: {0}" -f $ProjectName) -ForegroundColor Green
    Unlink-LocalProjectIfMatches -ProjectName $ProjectName -ProjectRoot $scriptDir
    return $true
  }
  if (-not [string]::IsNullOrWhiteSpace($cliText)) {
    $lastErr = $cliText.Trim()
  }
  throw ("Project delete failed. {0}" -f $lastErr)
}

function Run-DeleteProjectFlow([string]$Scope, [string]$TokenStorePath) {
  Write-Step "Delete Project"
  Write-Host "Choose the project you want to delete from your Vercel account." -ForegroundColor Yellow
  Write-Host "Nothing is deleted until you type DELETE and then type the exact project name." -ForegroundColor DarkYellow

  $selected = Select-ProjectFromList -Scope $Scope -TokenStorePath $TokenStorePath
  if ($null -eq $selected) {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return @{ Deleted = $false }
  }

  $projectName = [string]$selected.Name
  $projectScope = $Scope
  if ($selected.PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$selected.Scope)) {
    $projectScope = Normalize-ScopeForCli -Scope ([string]$selected.Scope)
  }

  $deleted = Remove-SelectedProject -ProjectName $projectName -Scope $projectScope -TokenStorePath $TokenStorePath
  return @{
    Deleted = [bool]$deleted
    ProjectName = $projectName
    Scope = $projectScope
  }
}

function Select-ProjectOrNewAfterDelete([string]$Scope, [string]$TokenStorePath) {
  Write-Step "Choose next project"
  Write-Host "Project list refreshed after deletion." -ForegroundColor Cyan
  return (Select-ProjectOrNewForFirstRun -Scope $Scope -TokenStorePath $TokenStorePath)
}

function Convert-JsonLineSafe([string]$Line) {
  try {
    return ($Line | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    return $null
  }
}

function Strip-AnsiCodes([string]$Text) {
  if ($null -eq $Text) { return "" }
  return ($Text -replace "`e\[[0-9;]*[A-Za-z]", "")
}

function Convert-CliTextLogLine([string]$Line) {
  $raw = Strip-AnsiCodes -Text $Line
  $t = $raw.Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }
  if ($t -match "^(Fetching|Displaying|Waiting|Ready|Visit|Tip:|Error:\s*The --follow flag does not support filtering)") { return $null }
  if ($t -match "^[-=]{3,}$") { return $null }

  $time = "-"
  if ($t -match "(?<tm>\d{1,2}:\d{2}:\d{2}(?:\.\d+)?)") { $time = $Matches.tm }

  $status = ""
  if ($t -match "(?<!\d)([1-5][0-9]{2})(?!\d)") { $status = $Matches[1] }

  $method = ""
  if ($t -match "(?i)\b(GET|POST|HEAD|PUT|PATCH|DELETE|OPTIONS)\b") { $method = $Matches[1].ToUpperInvariant() }

  $path = ""
  if ($t -match "(\/[A-Za-z0-9_\-\.~\/%]+)") { $path = $Matches[1] }

  return [pscustomobject]@{
    time = $time
    text = $t
    status = $status
    method = $method
    path = $path
    duration = ""
    hint = Translate-LogHint -Text $t
  }
}

function Get-LogMessageText($obj) {
  if ($null -eq $obj) { return "" }
  $candidates = @("text", "message", "msg")
  foreach ($k in $candidates) {
    if ($obj.PSObject.Properties.Name -contains $k) {
      $v = [string]$obj.$k
      if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
    }
  }
  return ""
}

function Get-LogStatusCode($obj) {
  if ($null -eq $obj) { return "" }
  if ($obj.PSObject.Properties.Name -contains "statusCode") {
    return [string]$obj.statusCode
  }
  $msg = Get-LogMessageText $obj
  if ($msg -match '\b([1-5][0-9]{2})\b') { return $Matches[1] }
  return ""
}

function Translate-LogHint([string]$Text) {
  $diag = Get-LogDiagnosis -Status "" -Text $Text
  return [string]$diag.Meaning
}

function Collapse-Whitespace([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  $t = $Text -replace "`r?`n", " "
  $t = $t -replace "\s{2,}", " "
  return $t.Trim()
}

function Parse-LogFieldsFromText([string]$Text) {
  $status = ""
  $method = ""
  $path = ""
  $duration = ""
  if ($Text -match "(?i)\bstatus(?:Code)?\b[:=\s'`"]+([1-5][0-9]{2})") { $status = $Matches[1] }
  if ($Text -match "(?i)\bmethod\b[:=\s'`"]+(GET|POST|HEAD|PUT|PATCH|DELETE|OPTIONS)") { $method = $Matches[1].ToUpperInvariant() }
  if ($Text -match "(?i)\b(?:rawPath|upstreamPath|path)\b[:=\s'`"]+([^,\s'`"}]+)") { $path = $Matches[1] }
  if ($Text -match "(?i)\bdurationMs\b[:=\s'`"]+([0-9]+)") { $duration = $Matches[1] }
  return @{
    Status = $status
    Method = $method
    Path = $path
    Duration = $duration
  }
}

function Get-LogDiagnosis([string]$Status, [string]$Text) {
  $t = [string]$Text
  $st = [string]$Status
  if ([string]::IsNullOrWhiteSpace($st) -and $t -match '\b([1-5][0-9]{2})\b') { $st = $Matches[1] }

  if ($t -match "(?i)not authorized|forbidden|invalid token|authentication") {
    return [pscustomobject]@{
      Tag = "SETUP"
      Color = "Red"
      Weight = 10
      Meaning = "Vercel did not accept the login/token for this project."
      Action = "Use token auth again, then make sure the selected scope/team is correct."
    }
  }
  if ($t -match "(?i)scope does not exist|invalid scope|team slug") {
    return [pscustomobject]@{
      Tag = "SETUP"
      Color = "Red"
      Weight = 11
      Meaning = "The selected Vercel team/scope is wrong."
      Action = "Select the project again from the token project list, or enter the correct team slug."
    }
  }
  if ($t -match "(?i)upstream_timeout|Task timed out after|timeout") {
    return [pscustomobject]@{
      Tag = "PROBLEM"
      Color = "Red"
      Weight = 20
      Meaning = "A request waited too long and timed out."
      Action = "Check the target server and port. If traffic is heavy, raise timeout/capacity or reduce client load."
    }
  }
  if ($t -match "(?i)ENOTFOUND|EAI_AGAIN|dns|lookup") {
    return [pscustomobject]@{
      Tag = "PROBLEM"
      Color = "Red"
      Weight = 21
      Meaning = "Vercel could not resolve the target domain."
      Action = "Check TARGET_DOMAIN spelling and DNS. If needed set UPSTREAM_DNS_ORDER=ipv4first."
    }
  }
  if ($t -match "(?i)ECONNRESET|socket hang up|ECONNREFUSED") {
    return [pscustomobject]@{
      Tag = "PROBLEM"
      Color = "Red"
      Weight = 22
      Meaning = "The target server closed or refused the connection."
      Action = "Check that the foreign server service is running and the target port is open."
    }
  }

  switch -Regex ($st) {
    "^2" {
      return [pscustomobject]@{
        Tag = "OK"
        Color = "Green"
        Weight = 90
        Meaning = "Request reached the relay and completed successfully."
        Action = "No action needed."
      }
    }
    "^3" {
      return [pscustomobject]@{
        Tag = "CHECK"
        Color = "Yellow"
        Weight = 60
        Meaning = "The request was redirected."
        Action = "If the client fails, check TARGET_DOMAIN protocol, trailing slash, and redirects on the target server."
      }
    }
    "^400$" {
      return [pscustomobject]@{
        Tag = "CHECK"
        Color = "Yellow"
        Weight = 55
        Meaning = "The path answered, but the request format was not accepted."
        Action = "This can be normal for quick tests. If real clients fail, check client protocol/path settings."
      }
    }
    "^401$|^403$" {
      return [pscustomobject]@{
        Tag = "PROBLEM"
        Color = "Red"
        Weight = 25
        Meaning = "The request was blocked by authorization."
        Action = "Check x-relay-key and make sure the client sends the same value configured during deploy."
      }
    }
    "^404$" {
      return [pscustomobject]@{
        Tag = "PROBLEM"
        Color = "Red"
        Weight = 24
        Meaning = "The requested path was not found."
        Action = "Check RELAY_PATH and the client path. They must match exactly and start with /, for example /api."
      }
    }
    "^405$" {
      return [pscustomobject]@{
        Tag = "OK"
        Color = "Green"
        Weight = 88
        Meaning = "The relay rejected an unsupported request method."
        Action = "No action needed unless your real client is using this method."
      }
    }
    "^429$" {
      return [pscustomobject]@{
        Tag = "PROBLEM"
        Color = "Red"
        Weight = 23
        Meaning = "Too many requests were sent in a short time."
        Action = "Reduce client concurrency or use a higher-capacity Node profile."
      }
    }
    "^5" {
      return [pscustomobject]@{
        Tag = "PROBLEM"
        Color = "Red"
        Weight = 20
        Meaning = "The target server or Vercel function returned a server error."
        Action = "Check target server health, port, path, and current load. Then rerun health checks."
      }
    }
  }

  if ($t -match "(?i)error|fatal|unhandled|failed") {
    return [pscustomobject]@{
      Tag = "PROBLEM"
      Color = "Red"
      Weight = 30
      Meaning = "An error was reported, but no exact HTTP status was found."
      Action = "Read the detail line below, then check target domain, relay path, and ENV values."
    }
  }
  if ($t -match "(?i)warn|warning") {
    return [pscustomobject]@{
      Tag = "CHECK"
      Color = "Yellow"
      Weight = 65
      Meaning = "A warning was reported."
      Action = "Check only if users are seeing connection issues."
    }
  }
  return [pscustomobject]@{
    Tag = "INFO"
    Color = "Gray"
    Weight = 95
    Meaning = "Informational log entry."
    Action = "No action needed."
  }
}

function Get-LogColor([string]$Status, [string]$Text) {
  $diag = Get-LogDiagnosis -Status $Status -Text $Text
  return [string]$diag.Color
}

function Write-CompactLogLine($Item) {
  $time = if ($null -ne $Item.time) { [string]$Item.time } else { "-" }
  $text = if ($null -ne $Item.text) { [string]$Item.text } else { "" }
  $hint = if ($null -ne $Item.hint) { [string]$Item.hint } else { Translate-LogHint -Text $text }
  $status = if ($null -ne $Item.status) { [string]$Item.status } else { "" }
  $method = if ($null -ne $Item.method) { [string]$Item.method } else { "" }
  $path = if ($null -ne $Item.path) { [string]$Item.path } else { "" }
  $duration = if ($null -ne $Item.duration) { [string]$Item.duration } else { "" }

  $parsed = Parse-LogFieldsFromText -Text $text
  if ([string]::IsNullOrWhiteSpace($status)) { $status = $parsed.Status }
  if ([string]::IsNullOrWhiteSpace($method)) { $method = $parsed.Method }
  if ([string]::IsNullOrWhiteSpace($path)) { $path = $parsed.Path }
  if ([string]::IsNullOrWhiteSpace($duration)) { $duration = $parsed.Duration }

  $compact = Collapse-Whitespace -Text $text
  if ($compact.Length -gt 160) { $compact = $compact.Substring(0, 160) + "..." }
  if ([string]::IsNullOrWhiteSpace($path)) { $path = "-" }
  if ([string]::IsNullOrWhiteSpace($method)) { $method = "-" }
  if ([string]::IsNullOrWhiteSpace($status)) { $status = "-" }
  if ([string]::IsNullOrWhiteSpace($duration)) { $duration = "-" }

  $diag = Get-LogDiagnosis -Status $status -Text $text
  $durationText = if ($duration -eq "-") { "time unknown" } else { "$duration ms" }
  $line = "[{0}] {1} | Status {2} | {3} {4} | {5} | Next: {6}" -f $time, $diag.Tag, $status, $method, $path, $diag.Meaning, $diag.Action
  if ($line.Length -gt 220) { $line = $line.Substring(0, 220) + "..." }
  $color = [string]$diag.Color
  Write-Host $line -ForegroundColor $color
  if ($diag.Tag -ne "OK" -and $diag.Tag -ne "INFO" -and -not [string]::IsNullOrWhiteSpace($compact)) {
    if ($compact.Length -gt 130) { $compact = $compact.Substring(0, 130) + "..." }
    Write-Host ("    Detail: {0} | Duration: {1}" -f $compact, $durationText) -ForegroundColor DarkGray
  }
}

function Write-LogSummary($Items) {
  $counts = @{
    OK = 0
    CHECK = 0
    PROBLEM = 0
    SETUP = 0
    INFO = 0
  }
  $statusCounts = @{}
  foreach ($it in @($Items)) {
    $text = if ($null -ne $it.text) { [string]$it.text } else { "" }
    $status = if ($null -ne $it.status) { [string]$it.status } else { "" }
    if ([string]::IsNullOrWhiteSpace($status)) {
      $parsed = Parse-LogFieldsFromText -Text $text
      $status = $parsed.Status
    }
    $diag = Get-LogDiagnosis -Status $status -Text $text
    $tag = [string]$diag.Tag
    if (-not $counts.ContainsKey($tag)) { $counts[$tag] = 0 }
    $counts[$tag]++
    if (-not [string]::IsNullOrWhiteSpace($status) -and $status -ne "-") {
      if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
      $statusCounts[$status]++
    }
  }

  Write-Host ""
  Write-Host "Readable summary:" -ForegroundColor Cyan
  Write-Host (" - OK: {0} successful/normal events" -f $counts.OK) -ForegroundColor Green
  Write-Host (" - Check: {0} events that may be normal but should be reviewed if users have issues" -f $counts.CHECK) -ForegroundColor Yellow
  Write-Host (" - Problem: {0} real error events" -f $counts.PROBLEM) -ForegroundColor Red
  Write-Host (" - Setup: {0} token/scope/project access issues" -f $counts.SETUP) -ForegroundColor Red
  if ($statusCounts.Count -gt 0) {
    $pairs = @()
    $statusCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { $pairs += ("{0}={1}" -f $_.Name, $_.Value) }
    Write-Host (" - HTTP status counts: {0}" -f ($pairs -join ", ")) -ForegroundColor DarkGray
  }
}

function Write-LogNextSteps($Items) {
  $texts = @()
  foreach ($it in @($Items)) {
    if ($null -ne $it.text) { $texts += [string]$it.text }
  }
  $joined = ($texts -join "`n")
  $actions = @()
  if ($joined -match "(?i)not authorized|invalid token|scope does not exist|invalid scope|team slug") {
    $actions += "Login/scope issue: use token auth again, then select the project from the token project list."
  }
  if ($joined -match "(?i)\b404\b") {
    $actions += "Path issue: check RELAY_PATH and the client path. They must match exactly, for example /api."
  }
  if ($joined -match "(?i)\b401\b|\b403\b") {
    $actions += "Key issue: check x-relay-key. If a password was set, the client must send the same header."
  }
  if ($joined -match "(?i)\b429\b|\b503\b|MAX_INFLIGHT|service unavailable") {
    $actions += "Traffic pressure: reduce client concurrency or switch to a higher-capacity Node profile."
  }
  if ($joined -match "(?i)\b500\b|\b502\b|\b504\b|timeout|upstream_timeout|Task timed out after") {
    $actions += "Server/timeout issue: check target domain, port, foreign server health, and timeout/capacity values."
  }
  if ($joined -match "(?i)ENOTFOUND|EAI_AGAIN|dns|lookup") {
    $actions += "DNS issue: check TARGET_DOMAIN spelling/DNS, or try UPSTREAM_DNS_ORDER=ipv4first."
  }
  if ($actions.Count -eq 0) {
    $actions += "No obvious failure found. If the client still fails, generate traffic and run logs again with a larger window, for example 30 minutes."
  }
  Write-Host ""
  Write-Host "What to do next:" -ForegroundColor Cyan
  foreach ($a in @($actions | Select-Object -Unique)) {
    Write-Host (" - {0}" -f $a) -ForegroundColor DarkYellow
  }
}

function Show-ProfessionalLogs([string]$ProjectName, [string]$Scope, [int]$Minutes, [string]$TokenStorePath) {
  Write-Step ("Recent logs (last {0} minutes)" -f $Minutes)
  Write-Host ("Project: {0}" -f $ProjectName) -ForegroundColor Cyan
  if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    Write-Host ("Scope:   {0}" -f $Scope) -ForegroundColor DarkGray
  }
  $errors = @()
  $allLines = @()
  $anyActivity = $false
  $cutoff = (Get-Date).AddMinutes(-1 * $Minutes)

  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if (-not [string]::IsNullOrWhiteSpace($token)) {
    try {
      $projectId = Resolve-ProjectApiId -ProjectName $ProjectName -Scope $Scope -Token $token
      if (-not [string]::IsNullOrWhiteSpace($projectId)) {
        $dep = Get-LatestDeploymentApi -ProjectId $projectId -Scope $Scope -Token $token
        if ($null -ne $dep) {
          $events = Get-DeploymentEventsApi -DeploymentId $dep.uid -Limit 300 -Scope $Scope -Token $token
          foreach ($e in $events) {
            $txt = ""
            if ($null -ne $e.payload) { $txt = [string]$e.payload.text }
            if ([string]::IsNullOrWhiteSpace($txt)) { continue }
            $anyActivity = $true
            $when = $null
            if ($null -ne $e.createdAt) {
              try { $when = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$e.createdAt).LocalDateTime } catch {}
            }
            if ($null -ne $when -and $when -lt $cutoff) { continue }
            $parsed = Parse-LogFieldsFromText -Text $txt
            $item = [pscustomobject]@{
              time = if ($null -ne $when) { $when.ToString("HH:mm:ss") } else { "-" }
              text = $txt
              status = $parsed.Status
              method = $parsed.Method
              path = $parsed.Path
              duration = $parsed.Duration
              hint = Translate-LogHint -Text $txt
            }
            $allLines += $item
            $diag = Get-LogDiagnosis -Status $item.status -Text $txt
            if ($diag.Tag -eq "PROBLEM" -or $diag.Tag -eq "SETUP") {
              $errors += $item
            }
          }
        }
      }
    } catch {
      Write-Host "API log mode failed, trying CLI fallback..." -ForegroundColor DarkYellow
    }
  }

  if ($allLines.Count -eq 0) {
    $cli = Get-RecentLogsCli -ProjectName $ProjectName -Scope $Scope -Minutes $Minutes -TokenStorePath $TokenStorePath
    if ($cli.Ok) {
      foreach ($line in $cli.Lines) {
        $obj = Convert-JsonLineSafe -Line $line
        if ($null -ne $obj) {
          $t = Get-LogMessageText $obj
          if ([string]::IsNullOrWhiteSpace($t)) { continue }
          $anyActivity = $true
          $st = Get-LogStatusCode $obj
          $pp = ""
          if ($obj.PSObject.Properties.Name -contains "path") { $pp = [string]$obj.path }
          $item = [pscustomobject]@{
            time = if ($obj.PSObject.Properties.Name -contains "createdAt") { [string]$obj.createdAt } else { "-" }
            text = $t
            status = $st
            method = if ($obj.PSObject.Properties.Name -contains "method") { [string]$obj.method } else { "" }
            path = $pp
            duration = if ($obj.PSObject.Properties.Name -contains "durationMs") { [string]$obj.durationMs } else { "" }
            hint = Translate-LogHint -Text $t
          }
          $allLines += $item
          $diag = Get-LogDiagnosis -Status $item.status -Text $t
          if ($diag.Tag -eq "PROBLEM" -or $diag.Tag -eq "SETUP") {
            $errors += $item
          }
          continue
        }

        $parsedTextLine = Convert-CliTextLogLine -Line $line
        if ($null -ne $parsedTextLine) {
          $anyActivity = $true
          $allLines += $parsedTextLine
          $diag = Get-LogDiagnosis -Status $parsedTextLine.status -Text $parsedTextLine.text
          if ($diag.Tag -eq "PROBLEM" -or $diag.Tag -eq "SETUP") {
            $errors += $parsedTextLine
          }
        }
      }
    } elseif (-not [string]::IsNullOrWhiteSpace($cli.ErrorText)) {
      Write-Host "Log history is not available from Vercel CLI in this environment." -ForegroundColor DarkYellow
      Write-Host "Use Live logs while reproducing the issue, or check token/scope/project access." -ForegroundColor DarkYellow
    }
  }

  if ($allLines.Count -gt 0) {
    Write-Host ("Found {0} readable log events." -f $allLines.Count) -ForegroundColor Green
    Write-LogSummary -Items $allLines
    Write-Host ""
    Write-Host "Important events first:" -ForegroundColor Cyan
    $displayLines = $allLines | Sort-Object @{ Expression = { (Get-LogDiagnosis -Status ([string]$_.status) -Text ([string]$_.text)).Weight }; Ascending = $true } | Select-Object -First 150
    $displayLines | ForEach-Object { Write-CompactLogLine -Item $_ }
    Write-LogNextSteps -Items $allLines
  } elseif ($anyActivity) {
    Write-Host "Traffic exists but readable log text was not returned in this window." -ForegroundColor DarkYellow
  } else {
    Write-Host "No log lines returned in selected window." -ForegroundColor Green
    Write-Host "Tip: reproduce issue, then run option 7/12 again." -ForegroundColor DarkYellow
  }

  return $errors
}

function Get-FriendlyLogStreamError([string]$Text) {
  $t = [string]$Text
  if ($t -match "(?i)not authorized|forbidden|invalid token|authentication") {
    return "Vercel rejected the token/login. Run token auth again and select the correct project."
  }
  if ($t -match "(?i)scope does not exist|invalid scope|team slug") {
    return "The Vercel scope/team is wrong. Select the project again from the token project list."
  }
  if ($t -match "(?i)not found|could not find|unknown project") {
    return "Vercel could not find this project in the selected account/scope."
  }
  if ($t -match "(?i)rate limit|too many requests") {
    return "Vercel is rate-limiting log requests. Wait a little and retry."
  }
  return "Live log stream stopped. Check token, scope, and selected project, then retry."
}

function Start-LiveLogsTranslated([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  Write-Step "Live logs"
  Write-Host ("Project: {0}" -f $ProjectName) -ForegroundColor Cyan
  if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    Write-Host ("Scope:   {0}" -f $Scope) -ForegroundColor DarkGray
  }
  Write-Host "Each new event is translated into: status, meaning, and the next action." -ForegroundColor Cyan
  Write-Host "If nothing appears, open your client and generate one connection attempt." -ForegroundColor DarkYellow
  Write-Host "Press Q to return to main menu." -ForegroundColor DarkYellow
  $Scope = Normalize-ScopeForCli -Scope $Scope
  $args = @("logs", $ProjectName, "--follow", "--no-color")
  if (-not [string]::IsNullOrWhiteSpace($Scope)) { $args += @("--scope", $Scope) }
  $liveToken = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if (-not [string]::IsNullOrWhiteSpace($liveToken)) { $args += @("--token", $liveToken) }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $VercelExe
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  # Windows PowerShell/.NET Framework compatibility:
  # ProcessStartInfo.ArgumentList can be null/unsupported, so build Arguments string.
  $quotedArgs = @()
  foreach ($a in $args) {
    $s = [string]$a
    if ($s -match '\s') {
      $quotedArgs += ('"' + ($s -replace '"', '\"') + '"')
    } else {
      $quotedArgs += $s
    }
  }
  $psi.Arguments = ($quotedArgs -join " ")

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $proc.EnableRaisingEvents = $true

  $queue = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
  $seen = @{}
  $rawErr = New-Object System.Collections.ArrayList
  $handlerOut = [System.Diagnostics.DataReceivedEventHandler]{
    param($sender, $eventArgs)
    if ($null -ne $eventArgs -and -not [string]::IsNullOrWhiteSpace($eventArgs.Data)) {
      [void]$queue.Add($eventArgs.Data)
    }
  }
  $handlerErr = [System.Diagnostics.DataReceivedEventHandler]{
    param($sender, $eventArgs)
    if ($null -ne $eventArgs -and -not [string]::IsNullOrWhiteSpace($eventArgs.Data)) {
      [void]$queue.Add($eventArgs.Data)
    }
  }

  try {
    [void]$proc.Start()
    $proc.add_OutputDataReceived($handlerOut)
    $proc.add_ErrorDataReceived($handlerErr)
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()
  } catch {
    throw ("Failed to start live log stream: {0}" -f $_.Exception.Message)
  }

  $lastHeartbeat = Get-Date
  try {
    while ($true) {
      try {
        if ([Console]::KeyAvailable) {
          $key = [Console]::ReadKey($true)
          if ($key.Key -eq [ConsoleKey]::Q) { break }
        }
      } catch {}

      $printed = 0
      while ($queue.Count -gt 0) {
        try {
          $line = [string]$queue[0]
          $queue.RemoveAt(0)

          $obj = Convert-JsonLineSafe -Line $line
          if ($null -ne $obj) {
            $txt = Get-LogMessageText $obj
            if ([string]::IsNullOrWhiteSpace($txt)) { continue }
            $sig = ("json|{0}|{1}" -f [string]$obj.createdAt, $txt)
            if ($seen.ContainsKey($sig)) { continue }
            $seen[$sig] = 1
            $item = [pscustomobject]@{
              time = if ($obj.PSObject.Properties.Name -contains "createdAt") { [string]$obj.createdAt } else { "-" }
              text = $txt
              status = Get-LogStatusCode $obj
              method = if ($obj.PSObject.Properties.Name -contains "method") { [string]$obj.method } else { "" }
              path = if ($obj.PSObject.Properties.Name -contains "path") { [string]$obj.path } else { "" }
              duration = if ($obj.PSObject.Properties.Name -contains "durationMs") { [string]$obj.durationMs } else { "" }
              hint = Translate-LogHint -Text $txt
            }
            Write-CompactLogLine -Item $item
            $printed++
            continue
          }

          $itemText = Convert-CliTextLogLine -Line $line
          if ($null -eq $itemText) {
            if ($line -match "(?i)\berror\b|\bnot authorized\b|\bforbidden\b|\binvalid\b|\bfailed\b") {
              [void]$rawErr.Add($line)
              Write-Host ("Live log problem: {0}" -f (Get-FriendlyLogStreamError -Text $line)) -ForegroundColor Red
              Write-Host ("    Detail: {0}" -f (Collapse-Whitespace -Text $line)) -ForegroundColor DarkGray
            }
            continue
          }
          $sig2 = ("txt|{0}|{1}" -f $itemText.time, $itemText.text)
          if ($seen.ContainsKey($sig2)) { continue }
          $seen[$sig2] = 1
          Write-CompactLogLine -Item $itemText
          $printed++
        } catch {
          $em = ""
          try { $em = $_.Exception.Message } catch { $em = "unknown parse error" }
          if (-not [string]::IsNullOrWhiteSpace($em)) {
            [void]$rawErr.Add($em)
            Write-Host ("Live log notice: one raw line could not be simplified. {0}" -f $em) -ForegroundColor DarkYellow
          }
          continue
        }
      }

      $now = Get-Date
      if ($printed -eq 0 -and (($now - $lastHeartbeat).TotalSeconds -ge 12)) {
        Write-Host "Waiting for traffic... start the client or run a quick health check. Press Q to go back." -ForegroundColor DarkGray
        $lastHeartbeat = $now
      }
      if ($printed -gt 0) {
        $lastHeartbeat = $now
      }

      if ($proc.HasExited -and $queue.Count -eq 0) {
        if ($proc.ExitCode -eq 0) {
          Write-Host ("Live log stream ended normally (exit={0}). Press Enter to continue." -f $proc.ExitCode) -ForegroundColor DarkYellow
        } else {
          Write-Host ("Live log stream ended with an error (exit={0})." -f $proc.ExitCode) -ForegroundColor Red
          if ($rawErr.Count -gt 0) {
            Write-Host ("Reason: {0}" -f (Get-FriendlyLogStreamError -Text ([string]$rawErr[$rawErr.Count - 1]))) -ForegroundColor DarkYellow
          } else {
            Write-Host "Reason: no readable error was returned. Check token/scope/project access, then retry." -ForegroundColor DarkYellow
          }
          Write-Host "Press Enter to continue." -ForegroundColor DarkYellow
        }
        break
      }
      Start-Sleep -Milliseconds 400
    }
  } catch {
    $m = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($m)) { $m = "unknown runtime error" }
    Write-Host ("Live log stream runtime error: {0}" -f $m) -ForegroundColor Red
    Write-Host "Retry live logs after checking token, scope, and selected project." -ForegroundColor DarkYellow
  } finally {
    try {
      if (-not $proc.HasExited) { $proc.Kill() }
    } catch {}
    try { $proc.remove_OutputDataReceived($handlerOut) } catch {}
    try { $proc.remove_ErrorDataReceived($handlerErr) } catch {}
    $proc.Dispose()
  }
}

function Get-IncidentAnalysis([string[]]$LogTexts) {
  $joined = ($LogTexts -join "`n")
  $issues = @()
  $actions = @()

  if ($joined -match "(?i)scope does not exist|invalid scope|team slug") {
    $issues += "Installer/CLI scope is invalid."
    $actions += "Set scope to a valid team slug (or empty for personal account)."
  }
  if ($joined -match "(?i)Task timed out after|upstream_timeout|504") {
    $issues += "Requests are timing out before completion."
    $actions += "Increase UPSTREAM_TIMEOUT_MS (e.g. 60000) and keep maxDuration at 60."
    $actions += "Reduce per-connection speed or concurrency spikes to shorten request lifetime."
  }
  if ($joined -match "(?i)503|MAX_INFLIGHT|service unavailable") {
    $issues += "Concurrency ceiling is being hit."
    $actions += "Increase MAX_INFLIGHT in steps (e.g. +64) and retest."
  }
  if ($joined -match "(?i)ENOTFOUND|EAI_AGAIN|ECONNRESET|dns|lookup") {
    $issues += "Upstream DNS/connectivity instability detected."
    $actions += "Set UPSTREAM_DNS_ORDER=ipv4first and verify upstream host/IP availability."
  }
  if ($joined -match "(?i)\b404\b") {
    $issues += "Relay path mismatch appears in traffic."
    $actions += "Verify RELAY_PATH in project env exactly matches client path."
  }
  if ($joined -match "(?i)\b403\b") {
    $issues += "Authorization mismatch appears in requests."
    $actions += "Check x-relay-key header and auth setup on both client and relay."
  }

  if ($issues.Count -eq 0) {
    $issues += "No clear failure signature found in sampled logs."
    $actions += "If you still have issue, reproduce traffic first, then run option 7 with a larger minutes window (e.g. 30)."
    $actions += "Status 400 in a quick check is usually OK because this test is not a real client tunnel request."
  }

  return @{
    Issues = @($issues | Select-Object -Unique)
    Actions = @($actions | Select-Object -Unique)
  }
}

function Get-HttpStatusCodeSafe([string]$Url, [string]$Method = "GET", [int]$TimeoutSec = 20, [hashtable]$Headers = $null) {
  try {
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.Timeout = $TimeoutSec * 1000
    $req.ReadWriteTimeout = $TimeoutSec * 1000
    $req.AllowAutoRedirect = $true
    if ($null -ne $Headers) {
      foreach ($k in $Headers.Keys) {
        if (-not [string]::IsNullOrWhiteSpace([string]$k)) {
          $req.Headers[[string]$k] = [string]$Headers[$k]
        }
      }
    }
    $resp = [System.Net.HttpWebResponse]$req.GetResponse()
    $code = [int]$resp.StatusCode
    $resp.Close()
    return $code
  } catch [System.Net.WebException] {
    if ($_.Exception.Response -ne $null) {
      try {
        return [int]([System.Net.HttpWebResponse]$_.Exception.Response).StatusCode
      } catch {
        return 0
      }
    }
    return 0
  } catch {
    return 0
  }
}

function Run-HealthAndSmokeChecks([string]$ProjectName, [string]$RelayPath, [string]$Runtime = "node", [string]$RelayKey = "") {
  $domain = "https://$ProjectName.vercel.app"
  $rp = if ($RelayPath.StartsWith("/")) { $RelayPath } else { "/$RelayPath" }
  $isRewrite = ([string]$Runtime).ToLowerInvariant() -eq "rewrite"
  $relayHeaders = $null
  if ($isRewrite -and -not [string]::IsNullOrWhiteSpace($RelayKey)) {
    $relayHeaders = @{ "x-relay-key" = $RelayKey }
  }

  Write-Step "Basic website check"
  try {
    $rootSw = [System.Diagnostics.Stopwatch]::StartNew()
    $rootStatus = Get-HttpStatusCodeSafe -Url "$domain/" -Method "GET" -TimeoutSec 20
    $rootSw.Stop()
    if ($rootStatus -gt 0) {
      Write-Host ("Main site is reachable. Status={0}, time={1} ms" -f $rootStatus, $rootSw.ElapsedMilliseconds) -ForegroundColor Green
    } else {
      Write-Host "Main site did not answer. Check Vercel deployment/domain first." -ForegroundColor Yellow
    }
  } catch {
    Write-Host ("Main site check failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
  }
  try {
    $apiSw = [System.Diagnostics.Stopwatch]::StartNew()
    $apiStatus = Get-HttpStatusCodeSafe -Url "$domain$rp/test" -Method "GET" -TimeoutSec 20 -Headers $relayHeaders
    $apiSw.Stop()
    if ($apiStatus -gt 0) {
      Write-Host ("Relay path answered. Status={0}, time={1} ms" -f $apiStatus, $apiSw.ElapsedMilliseconds) -ForegroundColor Green
      if ($apiStatus -eq 400) {
        Write-Host "This is usually OK: the quick test is not a real client tunnel request." -ForegroundColor DarkYellow
      }
    } else {
      Write-Host "Relay path did not answer. Check the path you entered, for example /api." -ForegroundColor Yellow
    }
  } catch {
    Write-Host ("Relay path check failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
  }

  Write-Step "Simple safety checks"
  if ($isRewrite) {
    Write-Host "Rewrite mode detected. These deeper Node checks are skipped." -ForegroundColor Cyan
    Write-Host "If you see 404 here in rewrite mode, it can simply mean your destination server returns 404 to browser-style test requests." -ForegroundColor DarkGray
    return
  }

  $st1 = Get-HttpStatusCodeSafe -Url "$domain/not-a-relay-path" -Method "GET" -TimeoutSec 20
  if ($st1 -eq 404) {
    Write-Host ("[OK] Random wrong address is blocked. Status={0}" -f $st1) -ForegroundColor Green
  } else {
    Write-Host ("[CHECK] Random wrong address returned Status={0}. Usually not critical, but check routing if the tunnel fails." -f $st1) -ForegroundColor Yellow
  }

  $st2 = Get-HttpStatusCodeSafe -Url "$domain$rp/test" -Method "PUT" -TimeoutSec 20
  if ($st2 -eq 405) {
    Write-Host ("[OK] Invalid request type is rejected. Status={0}" -f $st2) -ForegroundColor Green
  } else {
    Write-Host ("[CHECK] Invalid request type returned Status={0}. This can be OK if your destination server handles it differently." -f $st2) -ForegroundColor Yellow
  }

  $st3 = Get-HttpStatusCodeSafe -Url "$domain$rp/$([guid]::NewGuid().ToString())/0" -Method "GET" -TimeoutSec 20
  if ($st3 -ne 404 -and $st3 -gt 0) {
    Write-Host ("[OK] Your relay path was found. Status={0}" -f $st3) -ForegroundColor Green
  } else {
    Write-Host ("[PROBLEM] Your relay path was not found. Status={0}" -f $st3) -ForegroundColor Red
  }
  if ($st3 -eq 400) {
    Write-Host "What it means: the path exists. This quick test is not a real client request, so Status=400 is usually fine." -ForegroundColor DarkYellow
  } elseif ($st3 -eq 404) {
    Write-Host "What to do: the path is probably wrong. Open your foreign server inbound and copy the exact Path here, including the first slash, like /api." -ForegroundColor Red
  } elseif ($st3 -ge 500) {
    Write-Host "What it means: Vercel reached the path, but the destination server or function returned a server error." -ForegroundColor Yellow
    Write-Host "What to do: check that the target domain is online, the port is open, and the inbound service is running. If traffic is heavy, use a higher Node profile or increase timeout/capacity." -ForegroundColor Yellow
  } elseif ($st3 -ge 200 -and $st3 -lt 400) {
    Write-Host "Everything looks reachable from this quick check." -ForegroundColor Green
  }
}

function Run-LoadTestLite([string]$ProjectName, [string]$RelayPath) {
  $domain = "https://$ProjectName.vercel.app"
  $rp = if ($RelayPath.StartsWith("/")) { $RelayPath } else { "/$RelayPath" }
  $requests = [int](Read-Default "Total requests" "40")
  $parallel = [int](Read-Default "Parallel jobs" "8")
  if ($requests -lt 1) { $requests = 40 }
  if ($parallel -lt 1) { $parallel = 8 }

  Write-Step ("Load-test lite: {0} req, {1} parallel" -f $requests, $parallel)
  $activeJobs = New-Object System.Collections.ArrayList
  $done = 0
  $ok = 0
  $fail = 0
  $swAll = [System.Diagnostics.Stopwatch]::StartNew()

  for ($i = 0; $i -lt $requests; $i++) {
    while ((@($activeJobs | Where-Object { $_.State -eq "Running" })).Count -ge $parallel) {
      Start-Sleep -Milliseconds 100
      $finished = @($activeJobs | Where-Object { $_.State -ne "Running" })
      foreach ($j in $finished) {
        $result = @(Receive-Job -Job $j -ErrorAction SilentlyContinue)
        if ($result -contains 1) { $ok++ } else { $fail++ }
        Remove-Job $j -Force -ErrorAction SilentlyContinue
        [void]$activeJobs.Remove($j)
        $done++
      }
    }

    $url = "$domain$rp/$([guid]::NewGuid().ToString())/0"
    $job = Start-Job -ScriptBlock {
      param($u)
      try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.Method = "GET"
        $req.Timeout = 20000
        $req.ReadWriteTimeout = 20000
        $req.AllowAutoRedirect = $true
        $resp = [System.Net.HttpWebResponse]$req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        if ($code -gt 0 -and $code -lt 500) { return 1 }
        return 0
      } catch [System.Net.WebException] {
        if ($_.Exception.Response -ne $null) {
          try {
            $code = [int]([System.Net.HttpWebResponse]$_.Exception.Response).StatusCode
            if ($code -gt 0 -and $code -lt 500) { return 1 }
          } catch {}
        }
        return 0
      } catch {
        return 0
      }
    } -ArgumentList $url
    [void]$activeJobs.Add($job)
  }

  while ($activeJobs.Count -gt 0) {
    Start-Sleep -Milliseconds 100
    $finished = @($activeJobs | Where-Object { $_.State -ne "Running" })
    foreach ($j in $finished) {
      $result = @(Receive-Job -Job $j -ErrorAction SilentlyContinue)
      if ($result -contains 1) { $ok++ } else { $fail++ }
      Remove-Job $j -Force -ErrorAction SilentlyContinue
      [void]$activeJobs.Remove($j)
      $done++
    }
  }
  $swAll.Stop()
  Write-Host ("Load test done | ok={0} fail={1} total={2} elapsedMs={3}" -f $ok, $fail, $done, $swAll.ElapsedMilliseconds) -ForegroundColor Cyan
  if ($fail -eq 0) {
    Write-Host "Result: healthy under this light load." -ForegroundColor Green
  } else {
    Write-Host "Result: some requests failed (usually timeout/network/5xx under load)." -ForegroundColor Yellow
  }
}

function Get-EnvMapFromApi([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  $cliMap = Get-EnvMapFromCliPull -ProjectName $ProjectName -Scope $Scope -TokenStorePath $TokenStorePath
  if ($cliMap.Count -gt 0) { return $cliMap }

  $token = Get-VercelApiToken -TokenStorePath $TokenStorePath
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No token available for API env read."
  }
  # Ask API for decrypted values when possible (depends on token/permissions/type).
  $path = "/v10/projects/$([uri]::EscapeDataString($ProjectName))/env?target=production&limit=200&decrypt=true"
  $resp = Invoke-VercelApiGet -Path $path -Token $token -Scope $Scope
  $map = @{}
  if ($null -ne $resp -and $null -ne $resp.envs) {
    foreach ($e in $resp.envs) {
      $k = [string]$e.key
      if (-not [string]::IsNullOrWhiteSpace($k)) {
        $val = ""
        try {
          if ($e.PSObject.Properties.Name -contains "decrypted") {
            $dv = [string]$e.decrypted
            if (-not [string]::IsNullOrWhiteSpace($dv)) { $val = $dv }
          }
          if ([string]::IsNullOrWhiteSpace($val) -and $e.PSObject.Properties.Name -contains "decryptedValue") {
            $dv2 = [string]$e.decryptedValue
            if (-not [string]::IsNullOrWhiteSpace($dv2)) { $val = $dv2 }
          }
          if ([string]::IsNullOrWhiteSpace($val)) { $val = [string]$e.value }
        } catch {}
        $map[$k] = @{
          exists = $true
          value = $val
          source = "api"
        }
      }
    }
  }
  return $map
}

function Run-EnvDriftDetector([string]$ProjectName, [string]$Scope, [string]$TokenStorePath) {
  Write-Step "ENV drift detector"
  $profiles = @{
    balanced = @{
      "UPSTREAM_TIMEOUT_MS" = "60000"
      "MAX_INFLIGHT" = "256"
      "MAX_UP_BPS" = "5242880"
      "MAX_DOWN_BPS" = "5242880"
      "SUCCESS_LOG_SAMPLE_RATE" = "0"
      "SUCCESS_LOG_MIN_DURATION_MS" = "3000"
      "ERROR_LOG_MIN_INTERVAL_MS" = "5000"
    }
    max_connection = @{
      "UPSTREAM_TIMEOUT_MS" = "60000"
      "MAX_INFLIGHT" = "512"
      "MAX_UP_BPS" = "10485760"
      "MAX_DOWN_BPS" = "10485760"
      "SUCCESS_LOG_SAMPLE_RATE" = "0"
      "SUCCESS_LOG_MIN_DURATION_MS" = "3000"
      "ERROR_LOG_MIN_INTERVAL_MS" = "5000"
    }
  }

  Write-Host "Profiles: balanced | max_connection | 0 = Back" -ForegroundColor Cyan
  Write-Host "Profile here means: expected target values for this project's behavior." -ForegroundColor DarkGray
  $p = Read-Default "Select baseline profile" "balanced"
  if ($p -eq "0") {
    Write-Host "Canceled. Returning to main menu." -ForegroundColor DarkYellow
    return
  }
  if (-not $profiles.ContainsKey($p)) { $p = "balanced" }
  $baseline = $profiles[$p]

  $current = Get-EnvMapFromApi -ProjectName $ProjectName -Scope $Scope -TokenStorePath $TokenStorePath
  Write-Host ("Baseline profile: {0}" -f $p) -ForegroundColor Yellow
  Write-Host "This check verifies presence for all keys and value drift when value is readable from API." -ForegroundColor DarkGray
  $ok = 0
  $drift = 0
  $missing = 0
  $unknown = 0
  foreach ($k in $baseline.Keys) {
    if ($current.ContainsKey($k)) {
      $entry = $current[$k]
      $currVal = ""
      if ($null -ne $entry -and $entry.ContainsKey("value")) { $currVal = [string]$entry.value }
      if (Test-IsMaskedOrEncryptedEnvValue -Value $currVal) {
        Write-Host ("[PRESENT] {0} exists (value hidden/sensitive in API, drift not verifiable). expected={1}" -f $k, $baseline[$k]) -ForegroundColor DarkYellow
        $unknown++
      } elseif ($currVal -eq [string]$baseline[$k]) {
        Write-Host ("[OK] {0} = {1}" -f $k, $currVal) -ForegroundColor Green
        $ok++
      } else {
        Write-Host ("[DRIFT] {0} current={1} | expected={2}" -f $k, $currVal, $baseline[$k]) -ForegroundColor Yellow
        $drift++
      }
    } else {
      Write-Host ("[MISSING] {0} (recommended: {1})" -f $k, $baseline[$k]) -ForegroundColor Red
      $missing++
    }
  }
  Write-Host ""
  Write-Host ("Summary: OK={0} DRIFT={1} MISSING={2} UNKNOWN={3}" -f $ok, $drift, $missing, $unknown) -ForegroundColor Cyan
  if ($missing -gt 0 -or $drift -gt 0) {
    Write-Host "Tip: use option 3 (Update production env vars) to align values with your selected profile." -ForegroundColor Yellow
  }
}

function Run-ProfileBenchmark([string]$ProjectName, [string]$RelayPath, [string]$Scope, [string]$TokenStorePath, [string]$Runtime = "node") {
  Write-Step "Profile benchmark runner"
  Write-Host "This runner executes health + smoke + load-lite + log analysis." -ForegroundColor Cyan
  Write-Host ("Using relay path: {0}" -f $RelayPath) -ForegroundColor DarkGray
  Write-Host "IMPORTANT: this must be EXACTLY your foreign server inbound Path (for example: /api or /freedom)." -ForegroundColor Yellow
  Run-HealthAndSmokeChecks -ProjectName $ProjectName -RelayPath $RelayPath -Runtime $Runtime
  $runLoad = Read-Default "Run load-test lite now? (y/N)" "n"
  if ($runLoad.ToLowerInvariant() -eq "y") {
    Run-LoadTestLite -ProjectName $ProjectName -RelayPath $RelayPath
  }
  if (([string]$Runtime).ToLowerInvariant() -eq "rewrite") {
    Write-Host "Log analysis skipped: Fast Pipe rewrite uses Vercel rewrites and has no Node runtime logs." -ForegroundColor DarkYellow
    return
  }
  $minutes = [int](Read-Default "Minutes window for log analysis" "5")
  $errs = Show-ProfessionalLogs -ProjectName $ProjectName -Scope $Scope -Minutes $minutes -TokenStorePath $TokenStorePath

  $txts = @()
  foreach ($e in $errs) { $txts += [string]$e.text }
  $incident = Get-IncidentAnalysis -LogTexts $txts
  Write-Host ""
  Write-Host "Incident analyzer report" -ForegroundColor Yellow
  Write-Host "What broke:" -ForegroundColor Red
  foreach ($i in $incident.Issues) { Write-Host " - $i" -ForegroundColor Red }
  Write-Host "What to change:" -ForegroundColor Green
  foreach ($a in $incident.Actions) { Write-Host " - $a" -ForegroundColor Green }
}

function Set-VercelFunctionRegion([string]$Region) {
  $path = Join-Path $scriptDir "vercel.json"
  if (-not (Test-Path $path)) { throw "vercel.json not found." }
  $raw = Get-Content $path -Raw
  $json = $raw | ConvertFrom-Json
  if ($null -eq $json.functions) { throw "vercel.json has no functions block." }
  if ($null -eq $json.functions.'api/index.js') { throw "vercel.json has no functions['api/index.js'] block." }
  $regions = Normalize-RegionList -RegionText $Region
  if ($regions.Count -eq 0) { $regions = @("iad1") }
  $json.functions.'api/index.js'.regions = @($regions)
  $updated = $json | ConvertTo-Json -Depth 20
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $updated, $utf8NoBom)
  return @{
    Modified = $true
    ConfigPath = $path
    OriginalContent = $raw
  }
}

function Run-RegionABCompare([string]$ProjectName, [string]$Scope, [string]$RelayPath) {
  Write-Step "Region A/B deploy compare"
  Write-Host "This test deploys twice (Region A and Region B), then probes the same relay path." -ForegroundColor DarkGray
  Write-Host "How to read this table:" -ForegroundColor DarkGray
  Write-Host " - Lower DurationMs = usually faster region for your path." -ForegroundColor DarkGray
  Write-Host " - Status 400 usually means the path exists, but this quick probe is not a real client request." -ForegroundColor DarkGray
  Write-Host " - Status 404 usually means the Path is wrong, for example /api does not match your inbound." -ForegroundColor DarkGray
  Write-Host " - Status 500 or higher usually means the destination server/function returned an error." -ForegroundColor DarkGray
  $rp = Normalize-PathLike -PathValue $RelayPath
  $a = Read-Default "Region A" "iad1"
  $b = Read-Default "Region B" "fra1"
  $results = @()
  foreach ($r in @($a, $b)) {
    Write-Host ("Deploying with regions=['{0}'] ..." -f $r) -ForegroundColor Yellow
    try {
      $deployInfo = Deploy-Production -Scope $Scope -Region $r -Runtime "node"
      $url = "https://$ProjectName.vercel.app$rp/$([guid]::NewGuid().ToString())/0"
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $status = Get-HttpStatusCodeSafe -Url $url -Method "GET" -TimeoutSec 25
      $sw.Stop()
      $results += [pscustomobject]@{
        Region = $r
        Status = $status
        DurationMs = $sw.ElapsedMilliseconds
        Alias = $deployInfo.Alias
      }
    } catch {
      $results += [pscustomobject]@{
        Region = $r
        Status = -1
        DurationMs = -1
        Alias = "deploy_failed"
      }
      Write-Host ("Region {0} failed: {1}" -f $r, $_.Exception.Message) -ForegroundColor Red
    }
  }

  Write-Host ""
  Write-Host "A/B compare result:" -ForegroundColor Cyan
  $results | Format-Table -AutoSize | Out-Host
  $valid = @($results | Where-Object { $_.Status -gt 0 -and $_.DurationMs -ge 0 })
  if ($valid.Count -ge 2) {
    $best = $valid | Sort-Object DurationMs | Select-Object -First 1
    Write-Host ("Best region by probe latency: {0} ({1} ms, status {2})" -f $best.Region, $best.DurationMs, $best.Status) -ForegroundColor Green
  } elseif ($valid.Count -eq 1) {
    Write-Host ("Only one region returned a valid probe result: {0}" -f $valid[0].Region) -ForegroundColor Yellow
  } else {
    Write-Host "No valid probe result from either region. Check deploy output and try again." -ForegroundColor Red
  }
}

function Show-ManageMenu($selectedProjectName, $scope) {
  Write-Banner
  Write-PreflightNotice
  Write-Host ""
  Write-Host "Current target project:" -ForegroundColor Cyan
  if ($selectedProjectName) { Write-Host "Project: $selectedProjectName" } else { Write-Host "Project: (not selected)" }
  if ($scope) { Write-Host "Scope:   $scope" } else { Write-Host "Scope:   (default)" }
  Write-Host ""
  Write-Host "[1] Select project from Vercel list"
  Write-Host "[2] Redeploy selected project"
  Write-Host "[3] Update production ENV vars (choose project + editor)"
  Write-Host "[4] List recent deployments (selected project)"
  Write-Host "[5] Deploy as NEW project"
  Write-Host "[6] Run health + smoke checks"
  Write-Host "[7] Show readable logs (summary + fixes)"
  Write-Host "[8] Run load-test lite"
  Write-Host "[9] ENV drift detector"
  Write-Host "[10] Profile benchmark runner"
  Write-Host "[11] Live readable logs (press Q to stop)"
  Write-Host "[12] View deployment ENV config (full)"
  Write-Host "[13] Delete Project (choose from list)"
  Write-Host "[14] Billing / Usage monitor (REST API)"
  Write-Host "[15] Exit"
  return (Read-Default "Choose action" "1")
}

function Run-ManagementLoop([string]$InitialScope) {
  $link = Get-LinkedProjectInfo -ProjectRoot $scriptDir
  # Do not trust stale local .vercel scope for first selection.
  $scope = Normalize-ScopeForCli -Scope $InitialScope
  $selectedProjectName = ""
  $selectedRuntime = ""
  $selectedDeployMode = ""
  $selectedRelayPath = "/api"

  $firstChoice = Select-ProjectOrNewForFirstRun -Scope $scope -TokenStorePath $tokenStorePath
  if ($firstChoice.Mode -eq "existing") {
    $selectedProjectName = $firstChoice.ProjectName
    if (-not [string]::IsNullOrWhiteSpace($firstChoice.Scope)) {
      $scope = Normalize-ScopeForCli -Scope $firstChoice.Scope
    }
    Ensure-LinkedToProject -ProjectName $selectedProjectName -Scope $scope
    $savedState = Load-LocalProjectDeployState -ProjectName $selectedProjectName
    if ($null -ne $savedState) {
      $selectedRuntime = [string]$savedState.Runtime
      $selectedDeployMode = [string]$savedState.DeployMode
      if (-not [string]::IsNullOrWhiteSpace([string]$savedState.RelayPath)) { $selectedRelayPath = [string]$savedState.RelayPath }
    }
    Write-Host "Selected project: $selectedProjectName" -ForegroundColor Green
  } else {
    $newCfg = Run-NewDeploymentFlow -DefaultScope $scope
    if ($null -ne $newCfg) {
      $selectedRuntime = [string]$newCfg.Runtime
      $selectedDeployMode = [string]$newCfg.DeployMode
      $selectedRelayPath = [string]$newCfg.PublicRelayPath
      Save-LocalProjectDeployState -ProjectName ([string]$newCfg.ProjectName) -Scope ([string]$newCfg.Scope) -DeployMode $selectedDeployMode -Runtime $selectedRuntime -RelayPath $selectedRelayPath
      $link = Get-LinkedProjectInfo -ProjectRoot $scriptDir
      if ($link.ProjectName) { $selectedProjectName = $link.ProjectName }
      if ($link.Scope) { $scope = $link.Scope }
    }
  }

  while ($true) {
    if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
      Write-Host "No target project selected yet." -ForegroundColor DarkYellow
    }

    $choice = Show-ManageMenu -selectedProjectName $selectedProjectName -scope $scope
    if ($choice -eq "15") {
      Write-Host "Exit."
      break
    }

    try {
      switch ($choice) {
        "1" {
          $selected = Select-ProjectFromList -Scope $scope -TokenStorePath $tokenStorePath
          if ($null -ne $selected) {
            $selectedProjectName = $selected.Name
            if ($selected.PSObject.Properties.Name -contains "Scope" -and -not [string]::IsNullOrWhiteSpace([string]$selected.Scope)) {
              $scope = Normalize-ScopeForCli -Scope ([string]$selected.Scope)
            }
            $selectedRuntime = ""
            $selectedDeployMode = ""
            $selectedRelayPath = "/api"
            $savedState = Load-LocalProjectDeployState -ProjectName $selectedProjectName
            if ($null -ne $savedState) {
              $selectedRuntime = [string]$savedState.Runtime
              $selectedDeployMode = [string]$savedState.DeployMode
              if (-not [string]::IsNullOrWhiteSpace([string]$savedState.RelayPath)) { $selectedRelayPath = [string]$savedState.RelayPath }
            }
            Write-Host "Selected project: $selectedProjectName" -ForegroundColor Green
            Ensure-LinkedToProject -ProjectName $selectedProjectName -Scope $scope
          }
        }
        "2" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Ensure-LinkedToProject -ProjectName $selectedProjectName -Scope $scope
          $deployInfo = Deploy-Production -Scope $scope -Runtime "node"
          $selectedRuntime = "node"
          $selectedDeployMode = "NODE_REDEPLOY"
          Save-LocalProjectDeployState -ProjectName $selectedProjectName -Scope $scope -DeployMode $selectedDeployMode -Runtime $selectedRuntime -RelayPath $selectedRelayPath
          Show-DeploySummary $deployInfo
          Write-Host "Done."
        }
        "3" {
          $updatedCfg = Run-UpdateEnvFlow -Scope $scope
          if ($null -ne $updatedCfg) {
            $selectedProjectName = [string]$updatedCfg.ProjectName
            if ($updatedCfg.ContainsKey("Scope") -and -not [string]::IsNullOrWhiteSpace([string]$updatedCfg.Scope)) {
              $scope = Normalize-ScopeForCli -Scope ([string]$updatedCfg.Scope)
            }
            $selectedRuntime = [string]$updatedCfg.Runtime
            $selectedDeployMode = [string]$updatedCfg.DeployMode
            $selectedRelayPath = [string]$updatedCfg.PublicRelayPath
            Write-Host "Done."
          }
        }
        "4" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Show-DeploymentList -ProjectName $selectedProjectName -Scope $scope
          Write-Host "Done."
        }
        "5" {
          $newCfg = Run-NewDeploymentFlow -DefaultScope $scope
          if ($null -ne $newCfg) {
            $selectedRuntime = [string]$newCfg.Runtime
            $selectedDeployMode = [string]$newCfg.DeployMode
            $selectedRelayPath = [string]$newCfg.PublicRelayPath
            Save-LocalProjectDeployState -ProjectName ([string]$newCfg.ProjectName) -Scope ([string]$newCfg.Scope) -DeployMode $selectedDeployMode -Runtime $selectedRuntime -RelayPath $selectedRelayPath
            $newLink = Get-LinkedProjectInfo -ProjectRoot $scriptDir
            if ($newLink.ProjectName) { $selectedProjectName = $newLink.ProjectName }
            if ($newLink.Scope) { $scope = $newLink.Scope }
          }
        }
        "6" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          $rp = Read-Default "Relay path for checks (0 = Back)" $selectedRelayPath
          if ($rp -eq "0") { break }
          $relayKeyForCheck = ""
          if ($selectedRuntime -eq "rewrite") {
            Write-Host "If this Fast Pipe deploy uses RELAY_KEY, enter it for an accurate relay-path check." -ForegroundColor DarkYellow
            $relayKeyForCheck = Read-Optional "x-relay-key for this check only (empty = no header, 0 = Back)"
            if ($relayKeyForCheck -eq "0") { break }
          }
          Run-HealthAndSmokeChecks -ProjectName $selectedProjectName -RelayPath $rp -Runtime $selectedRuntime -RelayKey $relayKeyForCheck
        }
        "7" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          if ($selectedRuntime -eq "rewrite" -or $selectedDeployMode -like "FAST_PIPE_REWRITE_*") {
            Write-Host "Logs skipped: Fast Pipe rewrite uses Vercel rewrites and has no Node runtime logs." -ForegroundColor DarkYellow
            break
          }
          $minsRaw = Read-Default "Minutes window (0 = Back)" "5"
          if ($minsRaw -eq "0") { break }
          $mins = [int]$minsRaw
          $errs = Show-ProfessionalLogs -ProjectName $selectedProjectName -Scope $scope -Minutes $mins -TokenStorePath $tokenStorePath
          $logTexts = @()
          foreach ($e in $errs) { $logTexts += [string]$e.text }
          $inc = Get-IncidentAnalysis -LogTexts $logTexts
          Write-Host ""
          Write-Host "Quick incident report (simple):" -ForegroundColor Yellow
          Write-Host "Main issue:" -ForegroundColor Red
          foreach ($i in $inc.Issues) { Write-Host " - $i" -ForegroundColor Red }
          Write-Host "Suggested fix:" -ForegroundColor Green
          foreach ($a in $inc.Actions) { Write-Host " - $a" -ForegroundColor Green }
        }
        "8" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Write-Host "Enter your EXACT inbound Path from foreign server (must start with '/')." -ForegroundColor Yellow
          $rpRaw = Read-Default "Relay path for load test (example: /api or /freedom, 0 = Back)" $selectedRelayPath
          if ($rpRaw -eq "0") { break }
          $rp = Normalize-PathLike -PathValue $rpRaw
          Run-LoadTestLite -ProjectName $selectedProjectName -RelayPath $rp
        }
        "9" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Run-EnvDriftDetector -ProjectName $selectedProjectName -Scope $scope -TokenStorePath $tokenStorePath
        }
        "10" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Write-Host "IMPORTANT: enter your EXACT foreign server inbound Path (with leading '/')." -ForegroundColor Yellow
          $rpRaw = Read-Default "Relay path for benchmark (example: /api or /freedom, 0 = Back)" $selectedRelayPath
          if ($rpRaw -eq "0") { break }
          $rp = Normalize-PathLike -PathValue $rpRaw
          Run-ProfileBenchmark -ProjectName $selectedProjectName -RelayPath $rp -Scope $scope -TokenStorePath $tokenStorePath -Runtime $selectedRuntime
        }
        "11" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          if ($selectedRuntime -eq "rewrite" -or $selectedDeployMode -like "FAST_PIPE_REWRITE_*") {
            Write-Host "Live logs skipped: Fast Pipe rewrite uses Vercel rewrites and has no Node runtime logs." -ForegroundColor DarkYellow
            break
          }
          Start-LiveLogsTranslated -ProjectName $selectedProjectName -Scope $scope -TokenStorePath $tokenStorePath
        }
        "12" {
          if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
            Write-Host "Select a project first (option 1)." -ForegroundColor Red
            break
          }
          Show-DeploymentEnvConfig -ProjectName $selectedProjectName -Scope $scope -TokenStorePath $tokenStorePath
        }
        "13" {
          $deleteResult = Run-DeleteProjectFlow -Scope $scope -TokenStorePath $tokenStorePath
          if ($deleteResult.Deleted) {
            if ([string]$deleteResult.ProjectName -eq $selectedProjectName) {
              $selectedRuntime = ""
              $selectedDeployMode = ""
              $selectedRelayPath = "/api"
            }
            $selectedProjectName = ""
            if ($deleteResult.ContainsKey("Scope") -and -not [string]::IsNullOrWhiteSpace([string]$deleteResult.Scope)) {
              $scope = Normalize-ScopeForCli -Scope ([string]$deleteResult.Scope)
            }
            Write-Host ""
            Write-Host "Project removed. Now choose another project or deploy a new one." -ForegroundColor Yellow

            $nextChoice = Select-ProjectOrNewAfterDelete -Scope $scope -TokenStorePath $tokenStorePath
            if ($null -eq $nextChoice) { break }
            if ($nextChoice.Mode -eq "existing") {
              $selectedProjectName = [string]$nextChoice.ProjectName
              if (-not [string]::IsNullOrWhiteSpace([string]$nextChoice.Scope)) {
                $scope = Normalize-ScopeForCli -Scope ([string]$nextChoice.Scope)
              }
              Ensure-LinkedToProject -ProjectName $selectedProjectName -Scope $scope
              $selectedRuntime = ""
              $selectedDeployMode = ""
              $selectedRelayPath = "/api"
              $savedState = Load-LocalProjectDeployState -ProjectName $selectedProjectName
              if ($null -ne $savedState) {
                $selectedRuntime = [string]$savedState.Runtime
                $selectedDeployMode = [string]$savedState.DeployMode
                if (-not [string]::IsNullOrWhiteSpace([string]$savedState.RelayPath)) { $selectedRelayPath = [string]$savedState.RelayPath }
              }
              Write-Host ("Selected project: {0}" -f $selectedProjectName) -ForegroundColor Green
            } elseif ($nextChoice.Mode -eq "new") {
              $newCfg = Run-NewDeploymentFlow -DefaultScope $scope
              if ($null -ne $newCfg) {
                $selectedRuntime = [string]$newCfg.Runtime
                $selectedDeployMode = [string]$newCfg.DeployMode
                $selectedRelayPath = [string]$newCfg.PublicRelayPath
                Save-LocalProjectDeployState -ProjectName ([string]$newCfg.ProjectName) -Scope ([string]$newCfg.Scope) -DeployMode $selectedDeployMode -Runtime $selectedRuntime -RelayPath $selectedRelayPath
                $newLink = Get-LinkedProjectInfo -ProjectRoot $scriptDir
                if ($newLink.ProjectName) { $selectedProjectName = $newLink.ProjectName }
                if ($newLink.Scope) { $scope = $newLink.Scope }
              }
            }
          }
        }
        "14" {
          Show-BillingUsageMonitor -ProjectName $selectedProjectName -Scope $scope -TokenStorePath $tokenStorePath
        }
        default {
          Write-Host "Invalid option." -ForegroundColor Red
        }
      }
    } catch {
      Write-Host ""
      Write-Host "Action failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    Read-Host "Press Enter to return to main menu (or Ctrl+C to exit)"
  }
}

Write-Banner
Write-PreflightNotice
Read-Host "Press Enter to continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
$tokenStorePath = Get-TokenStorePath -ProjectRoot $scriptDir
$scopeStorePath = Get-ScopeStorePath -ProjectRoot $scriptDir

try {
  if (-not (Test-Path (Join-Path $scriptDir "api\index.js"))) {
    throw "api/index.js not found. Run this script from project root."
  }
  if (-not (Test-Path (Join-Path $scriptDir "vercel.json"))) {
    throw "vercel.json not found. Run this script from project root."
  }

  Ensure-NodeAndNpm
  Ensure-VercelCli
  Ensure-VercelLogin -OutputDir $scriptDir -TokenStorePath $tokenStorePath
  $sessionScope = Resolve-SessionScope -ScopeStorePath $scopeStorePath
  Write-Host "Deploy path: $scriptDir" -ForegroundColor DarkGray

  Run-ManagementLoop -InitialScope $sessionScope
} catch {
  Write-Host ""
  Write-Host ("Startup failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
  Write-Host "Tip: if token mode fails, generate a fresh Full Access token and retry." -ForegroundColor DarkYellow
  Read-Host "Press Enter to exit"
  exit 1
}
