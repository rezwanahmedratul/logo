$webuiUrl = $env:WEBUI_URL
if ([string]::IsNullOrWhiteSpace($webuiUrl)) {
    $webuiUrl = "https://liveip.ratul.fun"
}
$endpoint  = ($webuiUrl.TrimEnd('/')) + "/api/telemetry"
$machineId = $env:COMPUTERNAME

function Get-Telemetry {

    $ip = "Unknown"
    try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10).ToString() } catch {}

    $cpu = "Unknown"
    try { $cpu = (Get-CimInstance Win32_Processor).Name -replace '\s+',' ' } catch {}

    $ram = "Unknown"
    try {
        $ram = "$([math]::Round(
            (Get-CimInstance Win32_PhysicalMemory |
            Measure-Object Capacity -Sum).Sum / 1GB
        )) GB"
    } catch {}

    $disk = "Unknown"
    try {
        $disk = "$([math]::Round(
            (Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'").Size / 1GB
        )) GB"
    } catch {}

    $os = "Unknown"
    try { $os = (Get-CimInstance Win32_OperatingSystem).Caption } catch {}

    return @{
        machineId = $machineId
        hostname  = $env:COMPUTERNAME
        ip        = $ip
        user      = $env:USERNAME
        os        = $os
        cpu       = $cpu
        ram       = $ram
        disk      = $disk
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$headers = @{
    "Content-Type" = "application/json"
}

while ($true) {

    try {

        $payload = Get-Telemetry | ConvertTo-Json -Compress

        Invoke-RestMethod `
            -Uri $endpoint `
            -Method POST `
            -Headers $headers `
            -Body $payload `
            -TimeoutSec 15 | Out-Null

    }
    catch {}

    Start-Sleep -Seconds 10
}
