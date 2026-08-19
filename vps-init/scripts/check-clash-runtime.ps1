[CmdletBinding()]
param(
    [string]$Controller = 'http://127.0.0.1:9097',
    [string]$Secret = '',
    [string]$AiGroup = 'AI Development',
    [string]$PublicNode = 'VPS-SantaClara',
    [string]$WireGuardNode = 'VPS-WireGuard',
    [string]$WireGuardServer = '10.66.66.1',
    [ValidateRange(1, 65535)]
    [int]$WireGuardPort = 8080,
    [string]$ProbeUrl = 'https://chatgpt.com/favicon.ico',
    [ValidateRange(1, 20)]
    [int]$Samples = 3,
    [ValidateRange(1000, 60000)]
    [int]$TimeoutMilliseconds = 8000,
    [string]$RuntimeConfigPath = (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev\clash-verge.yaml'),
    [switch]$PromptForSecret,
    [switch]$RequireController,
    [switch]$RequireWireGuard,
    [switch]$AllowIpv6,
    [switch]$RequireTun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$controllerUri = [Uri]$Controller
if ($controllerUri.Scheme -notin @('http', 'https')) {
    throw 'Controller must use http or https.'
}
if ($controllerUri.Host -notin @('127.0.0.1', 'localhost', '::1')) {
    throw 'For safety, this checker only connects to a loopback Mihomo controller.'
}

$controllerBase = $Controller.TrimEnd('/')
$headers = @{}
if ($PromptForSecret -and $Secret) {
    throw 'Use either -Secret or -PromptForSecret, not both.'
}
if ($PromptForSecret) {
    $secureSecret = Read-Host 'Mihomo controller secret' -AsSecureString
    $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
    try {
        $Secret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
}
if ($Secret) {
    $headers.Authorization = "Bearer $Secret"
}
$requestTimeoutSeconds = [Math]::Max(3, [Math]::Ceiling($TimeoutMilliseconds / 1000) + 2)
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$requiredTunExclusions = @(
    '10.0.0.0/8',
    '100.64.0.0/10',
    '127.0.0.0/8',
    '169.254.0.0/16',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '224.0.0.0/4',
    '::1/128',
    'fc00::/7',
    'fe80::/10'
)

function Get-PropertyValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Invoke-MihomoApi {
    param([string]$Path)
    return Invoke-RestMethod -Method Get -Uri "${controllerBase}${Path}" -Headers $headers -TimeoutSec $requestTimeoutSeconds
}

function Write-Check {
    param([string]$Level, [string]$Message)
    Write-Host ("[{0}] {1}" -f $Level, $Message)
}

function Test-WireGuardClient {
    $tunnelService = Get-Service -Name 'WireGuardTunnel$*' -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'Running' |
        Select-Object -First 1
    if ($null -eq $tunnelService) {
        $failures.Add('No running WireGuard tunnel service was found.')
    }
    else {
        Write-Check 'PASS' "WireGuard tunnel service '$($tunnelService.Name)' is running."
    }

    $tunnelAdapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'WireGuard|Wintun' } |
        Select-Object -First 1
    if ($null -eq $tunnelAdapter) {
        $failures.Add('No active WireGuard/Wintun adapter was found.')
    }
    else {
        Write-Check 'PASS' "WireGuard adapter '$($tunnelAdapter.Name)' is up."
    }

    $privateEndpointReachable = Test-NetConnection -ComputerName $WireGuardServer -Port $WireGuardPort -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $privateEndpointReachable) {
        $failures.Add("WireGuard private proxy endpoint ${WireGuardServer}:${WireGuardPort} is unreachable.")
    }
    else {
        Write-Check 'PASS' "WireGuard private proxy endpoint ${WireGuardServer}:${WireGuardPort} is reachable."
    }
}

function Test-MihomoRuntimeFile {
    if (-not (Test-Path -LiteralPath $RuntimeConfigPath -PathType Leaf)) {
        throw "Runtime config file does not exist: $RuntimeConfigPath"
    }

    $runtimeText = Get-Content -LiteralPath $RuntimeConfigPath -Raw
    if ($runtimeText -notmatch '(?m)^mode:\s*rule\s*$') {
        $failures.Add('Runtime file mode is not rule.')
    }
    else {
        Write-Check 'PASS' 'Runtime file mode is rule.'
    }

    $runtimeIpv6 = $runtimeText -match '(?m)^ipv6:\s*true\s*$'
    if ($runtimeIpv6 -and -not $AllowIpv6) {
        $failures.Add('Runtime file enables IPv6; use -AllowIpv6 only after the VPS path has been verified for IPv6.')
    }
    else {
        Write-Check 'PASS' "Runtime file IPv6 is $($runtimeIpv6.ToString().ToLowerInvariant())."
    }

    if ($runtimeText -match '(?m)^\s*smux:\s*$') {
        $failures.Add('Runtime file enables smux; Codex long connections must use ordinary Shadowsocks TCP for stability.')
    }
    else {
        Write-Check 'PASS' 'Runtime file does not enable smux.'
    }

    $escapedGroup = [Regex]::Escape($AiGroup)
    $groupMatch = [Regex]::Match($runtimeText, "(?ms)^[ `t]*- name:[ `t]*[^`r`n]*$escapedGroup[^`r`n]*`r?`n.*?(?=^[ `t]*- name:|\z)")
    if (-not $groupMatch.Success) {
        $failures.Add("Proxy group '$AiGroup' is missing from the runtime file.")
    }
    else {
        $groupText = $groupMatch.Value
        if ($groupText -match '(?m)^[ \t]*-[ \t]*DIRECT[ \t]*\r?$') {
            $failures.Add("Proxy group '$AiGroup' contains DIRECT and can bypass the VPS.")
        }
        if ($groupText -notmatch "(?m)^[ `t]*-[ `t]*$([Regex]::Escape($PublicNode))[ `t]*`r?$") {
            $failures.Add("Public fallback node '$PublicNode' is missing from '$AiGroup'.")
        }
        if ($RequireWireGuard -and $groupText -notmatch "(?m)^[ `t]*-[ `t]*$([Regex]::Escape($WireGuardNode))[ `t]*`r?$") {
            $failures.Add("WireGuard node '$WireGuardNode' is missing from '$AiGroup'.")
        }
    }

    if ($RequireWireGuard) {
        $escapedWireGuardNode = [Regex]::Escape($WireGuardNode)
        $wireGuardServerPattern = '(?m)^[ \t]*server:[ \t]*["'']?' + [Regex]::Escape($WireGuardServer) + '["'']?[ \t]*\r?$'
        $wireGuardNodeMatch = [Regex]::Match($runtimeText, "(?ms)^[ `t]*- name:[ `t]*[^`r`n]*$escapedWireGuardNode[^`r`n]*`r?`n.*?(?=^[ `t]*- name:|^proxy-groups:|\z)")
        if (-not $wireGuardNodeMatch.Success) {
            $failures.Add("WireGuard proxy '$WireGuardNode' is missing from the runtime file.")
        }
        elseif ($wireGuardNodeMatch.Value -notmatch $wireGuardServerPattern) {
            $failures.Add("WireGuard proxy '$WireGuardNode' does not use private server '$WireGuardServer'.")
        }
        else {
            Write-Check 'PASS' "WireGuard proxy '$WireGuardNode' uses private server '$WireGuardServer'."
        }
        Test-WireGuardClient
    }

    $tunBlockMatch = [Regex]::Match($runtimeText, '(?ms)^tun:\s*\r?\n(?:(?!^[^ \t\r\n]).)*(?=^[^ \t\r\n]|\z)')
    $tunBlockText = if ($tunBlockMatch.Success) { $tunBlockMatch.Value } else { '' }
    $runtimeTunEnabled = $tunBlockText -match '(?m)^\s+enable:\s*true\s*$'
    if ($RequireTun -and -not $runtimeTunEnabled) {
        $failures.Add('Runtime file has TUN disabled even though -RequireTun was requested.')
    }
    elseif (-not $runtimeTunEnabled) {
        $warnings.Add('Runtime file has TUN disabled. This is valid only when Codex/ChatGPT reliably follow the system proxy.')
    }
    elseif ($RequireTun) {
        foreach ($excludedAddress in $requiredTunExclusions) {
            $addressPattern = '(?m)^\s+-\s*["'']?' + [Regex]::Escape($excludedAddress) + '["'']?\s*$'
            if ($tunBlockText -notmatch $addressPattern) {
                $failures.Add("Runtime TUN route exclusions are missing '$excludedAddress'.")
            }
        }
    }

    $warnings.Add('Mihomo is using a named pipe or its REST controller is unavailable; delay probes were skipped. Use -RequireController after enabling a loopback controller to require API checks.')
}

try {
    $configs = Invoke-MihomoApi '/configs'
    $proxyResponse = Invoke-MihomoApi '/proxies'
}
catch {
    if ($RequireController) {
        Write-Error "Cannot query Mihomo controller at $controllerBase. Confirm Clash Verge is running and the controller port/secret are correct; use -PromptForSecret for a protected prompt. $($_.Exception.Message)"
        exit 2
    }
    Write-Check 'INFO' "Mihomo REST controller is unavailable; checking the merged runtime file at '$RuntimeConfigPath'."
    Test-MihomoRuntimeFile
    foreach ($warning in $warnings) { Write-Check 'WARN' $warning }
    foreach ($failure in $failures) { Write-Check 'FAIL' $failure }
    if ($failures.Count -gt 0) {
        Write-Host "Runtime file verification failed with $($failures.Count) issue(s)."
        exit 1
    }
    Write-Host 'Runtime file verification passed.'
    exit 0
}

$mode = Get-PropertyValue $configs 'mode'
if ($mode -ne 'rule') {
    $failures.Add("Runtime mode is '$mode'; expected 'rule'.")
}
else {
    Write-Check 'PASS' 'Runtime mode is rule.'
}

$mixedPort = Get-PropertyValue $configs 'mixed-port'
Write-Check 'INFO' "Effective mixed-port is $mixedPort (the Clash Verge app may override the profile YAML value)."

$ipv6 = [bool](Get-PropertyValue $configs 'ipv6')
if ($ipv6 -and -not $AllowIpv6) {
    $failures.Add('Runtime IPv6 is enabled; use -AllowIpv6 only after the VPS path has been verified for IPv6.')
}
else {
    Write-Check 'PASS' "Runtime IPv6 is $($ipv6.ToString().ToLowerInvariant())."
}

$tun = Get-PropertyValue $configs 'tun'
$tunEnabled = $false
if ($null -ne $tun) {
    $tunEnabled = [bool](Get-PropertyValue $tun 'enable')
}
if ($RequireTun -and -not $tunEnabled) {
    $failures.Add('Runtime TUN is disabled even though -RequireTun was requested.')
}
elseif (-not $tunEnabled) {
    $warnings.Add('Runtime TUN is disabled. This is valid only when Codex/ChatGPT reliably follow the system proxy.')
}
else {
    Write-Check 'PASS' 'Runtime TUN is enabled.'
    if ($RequireTun) {
        $strictRoute = [bool](Get-PropertyValue $tun 'strict-route')
        if (-not $strictRoute) {
            $failures.Add('Runtime TUN strict-route is disabled.')
        }
        $routeExclusions = @((Get-PropertyValue $tun 'route-exclude-address'))
        foreach ($excludedAddress in $requiredTunExclusions) {
            if ($routeExclusions -notcontains $excludedAddress) {
                $failures.Add("Runtime TUN route exclusions are missing '$excludedAddress'.")
            }
        }
    }
}

$proxies = Get-PropertyValue $proxyResponse 'proxies'
$aiGroupProperty = $proxies.PSObject.Properties | Where-Object { $_.Name -like "*$AiGroup*" } | Select-Object -First 1
$aiGroupObject = if ($null -eq $aiGroupProperty) { $null } else { $aiGroupProperty.Value }
if ($null -eq $aiGroupObject) {
    $failures.Add("Proxy group '$AiGroup' is missing from the effective runtime config.")
}
else {
    $members = @((Get-PropertyValue $aiGroupObject 'all')) | Where-Object { $null -ne $_ -and $_ -ne '' }
    $activeNode = Get-PropertyValue $aiGroupObject 'now'
    Write-Check 'INFO' "AI group active node is '$activeNode'; members: $($members -join ', ')."
    if ($members -contains 'DIRECT') {
        $failures.Add("Proxy group '$AiGroup' contains DIRECT and can bypass the VPS.")
    }
    if ($members -notcontains $PublicNode) {
        $failures.Add("Public fallback node '$PublicNode' is missing from '$AiGroup'.")
    }
    if ($RequireWireGuard -and $members -notcontains $WireGuardNode) {
        $failures.Add("WireGuard node '$WireGuardNode' is missing from '$AiGroup'.")
    }

    $nodeResults = @{}
    foreach ($node in $members) {
        if ($node -in @('DIRECT', 'REJECT', 'COMPATIBLE')) { continue }
        if ($null -eq (Get-PropertyValue $proxies $node)) {
            $failures.Add("AI group member '$node' is not a defined runtime proxy.")
            continue
        }

        $delays = [System.Collections.Generic.List[int]]::new()
        $sampleFailures = 0
        $encodedNode = [Uri]::EscapeDataString([string]$node)
        $encodedUrl = [Uri]::EscapeDataString($ProbeUrl)
        for ($sample = 1; $sample -le $Samples; $sample++) {
            try {
                $result = Invoke-MihomoApi "/proxies/$encodedNode/delay?timeout=$TimeoutMilliseconds&url=$encodedUrl"
                $delay = [int](Get-PropertyValue $result 'delay')
                if ($delay -le 0) { throw 'Mihomo returned a non-positive delay.' }
                $delays.Add($delay)
            }
            catch {
                $sampleFailures += 1
            }
        }
        $nodeResults[$node] = [PSCustomObject]@{ Delays = $delays; Failures = $sampleFailures }
        if ($delays.Count -gt 0) {
            $average = [Math]::Round(($delays | Measure-Object -Average).Average)
            Write-Check 'INFO' "Node '$node': $($delays.Count)/$Samples successful, average ${average}ms."
        }
        else {
            Write-Check 'INFO' "Node '$node': 0/$Samples successful."
        }
    }

    $publicResult = $nodeResults[$PublicNode]
    if ($null -ne $publicResult -and $publicResult.Failures -gt 0) {
        $failures.Add("Public fallback '$PublicNode' failed $($publicResult.Failures)/$Samples probes.")
    }
    $activeResult = $nodeResults[[string]$activeNode]
    if ($null -ne $activeResult -and $activeResult.Failures -gt 0) {
        $failures.Add("Active AI node '$activeNode' failed $($activeResult.Failures)/$Samples probes.")
    }
    foreach ($node in $nodeResults.Keys) {
        $nodeResult = $nodeResults[$node]
        if ($node -ne $PublicNode -and $node -ne $activeNode -and $nodeResult.Failures -gt 0) {
            $warnings.Add("Inactive optional node '$node' failed $($nodeResult.Failures)/$Samples probes; verify WireGuard if this is VPS-WireGuard.")
        }
    }
}

if ($RequireWireGuard) {
    Test-WireGuardClient
}

foreach ($warning in $warnings) { Write-Check 'WARN' $warning }
foreach ($failure in $failures) { Write-Check 'FAIL' $failure }

if ($failures.Count -gt 0) {
    Write-Host "Runtime verification failed with $($failures.Count) issue(s)."
    exit 1
}

Write-Host 'Runtime verification passed.'
