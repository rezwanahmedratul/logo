$server = "https://liveip.ratul.fun/api/telemetry"
$machineId = $env:COMPUTERNAME

$logFile = "C:\telemetry-agent\telemetry.log"

function Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg" |
        Out-File -FilePath $logFile -Append -Encoding utf8
}

Log "Telemetry script started"
Log "Machine ID: $machineId"

function Get-Telemetry {

    Log "Collecting telemetry"

    $ip = "Unknown"

    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org").ToString()
        Log "IP: $ip"
    }
    catch {
        Log "IP Error: $($_.Exception.Message)"
    }

    $cpu = "Unknown"

    try {
        $cpu = (Get-CimInstance Win32_Processor).Name -replace '\s+',' '
        Log "CPU OK"
    }
    catch {
        Log "CPU Error: $($_.Exception.Message)"
    }

    $ram = "Unknown"

    try {
        $ram = "$([math]::Round(
            (Get-CimInstance Win32_PhysicalMemory |
            Measure-Object Capacity -Sum).Sum / 1GB
        )) GB"
        Log "RAM OK"
    }
    catch {
        Log "RAM Error: $($_.Exception.Message)"
    }

    $disk = "Unknown"

    try {
        $disk = "$([math]::Round(
            (Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'").Size / 1GB
        )) GB"
        Log "Disk OK"
    }
    catch {
        Log "Disk Error: $($_.Exception.Message)"
    }

    $os = "Unknown"

    try {
        $os = (Get-CimInstance Win32_OperatingSystem).Caption
        Log "OS OK"
    }
    catch {
        Log "OS Error: $($_.Exception.Message)"
    }

    return @{
        machineId = $machineId
        hostname = $env:COMPUTERNAME
        ip = $ip
        user = $env:USERNAME
        os = $os
        cpu = $cpu
        ram = $ram
        disk = $disk
    }
}

while ($true) {

    try {

        $payload = Get-Telemetry |
            ConvertTo-Json -Compress

        Log "Payload: $payload"

        $response = Invoke-RestMethod `
            -Uri $server `
            -Method POST `
            -Body $payload `
            -ContentType "application/json" `
            -TimeoutSec 15

        Log "POST Success"
    }
    catch {
        Log "POST Error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 10
}