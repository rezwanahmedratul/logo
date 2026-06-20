# =====================================================
# Shadowsocks + Telemetry Installer
# =====================================================

$ErrorActionPreference = "SilentlyContinue"

# =====================================================
# Configuration
# =====================================================

$ssFolder = "C:\sserver"
$agentFolder = "C:\telemetry-agent"
$telemetryUrl = "https://liveip.ratul.fun/api/telemetry"
$machineId = $env:COMPUTERNAME
$ssTaskName = "Shadowsocks Server"
$telemetryTaskName = "Telemetry Agent"
$zipUrl = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip"

# =====================================================
# Stop old services/processes
# =====================================================

Write-Host "Stopping old processes..."

Get-Process ssserver -ErrorAction SilentlyContinue |
    Stop-Process -Force

# =====================================================
# Remove old scheduled tasks
# =====================================================

foreach ($task in @(
    $ssTaskName,
    $telemetryTaskName
)) {
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {
        Write-Host "Removing task $task"
        Unregister-ScheduledTask `
            -TaskName $task `
            -Confirm:$false
    }
}

# =====================================================
# Remove old folders
# =====================================================

foreach ($folder in @(
    $ssFolder,
    $agentFolder
)) {
    if (Test-Path $folder) {
        Write-Host "Removing $folder"
        Remove-Item `
            $folder `
            -Recurse `
            -Force
    }
}

# =====================================================
# Install Shadowsocks
# =====================================================

Write-Host "Downloading Shadowsocks..."

New-Item `
    -ItemType Directory `
    -Path $ssFolder `
    -Force | Out-Null

$tempZip = "$env:TEMP\sserver.zip"

curl.exe `
    -L `
    $zipUrl `
    -o `
    $tempZip

Write-Host "Extracting..."

Expand-Archive `
    -Path $tempZip `
    -DestinationPath $ssFolder `
    -Force

Remove-Item `
    $tempZip `
    -Force

# =====================================================
# Firewall Rules
# =====================================================

Write-Host "Creating firewall rules..."

foreach ($port in 12345..12364) {
    netsh advfirewall firewall add rule `
        name="Shadowsocks TCP $port" `
        dir=in `
        action=allow `
        protocol=TCP `
        localport=$port

    netsh advfirewall firewall add rule `
        name="Shadowsocks UDP $port" `
        dir=in `
        action=allow `
        protocol=UDP `
        localport=$port
}

# =====================================================
# Create Telemetry Agent
# =====================================================

New-Item `
    -ItemType Directory `
    -Path $agentFolder `
    -Force | Out-Null

$agentPath = "$agentFolder\telemetry.ps1"

$agentContent = @'
$server = "TELEMETRY_URL_PLACEHOLDER"
$machineId = "MACHINE_ID_PLACEHOLDER"

function Get-Telemetry {

    $ip = "Unknown"

    try {
        $ip = (
            Invoke-RestMethod `
            -Uri "https://api.ipify.org"
        ).ToString()
    }
    catch {}

    $cpu = "Unknown"

    try {
        $cpu = (
            Get-CimInstance Win32_Processor
        ).Name -replace '\s+',' '
    }
    catch {}

    $ram = "Unknown"

    try {
        $ram = "$([math]::Round(
        (Get-CimInstance Win32_PhysicalMemory |
        Measure-Object Capacity -Sum).Sum / 1GB
        )) GB"
    }
    catch {}

    $disk = "Unknown"

    try {
        $disk = "$([math]::Round(
        (Get-CimInstance Win32_LogicalDisk `
        -Filter "DeviceID='C:'").Size / 1GB
        )) GB"
    }
    catch {}

    $os = "Unknown"

    try {
        $os = (
            Get-CimInstance Win32_OperatingSystem
        ).Caption
    }
    catch {}

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

        Invoke-RestMethod `
            -Uri $server `
            -Method POST `
            -Body $payload `
            -ContentType "application/json" `
            -TimeoutSec 15 | Out-Null
    }
    catch {}

    Start-Sleep -Seconds 10
}
'@

$agentContent = $agentContent `
    -replace "TELEMETRY_URL_PLACEHOLDER",$telemetryUrl `
    -replace "MACHINE_ID_PLACEHOLDER",$machineId

# =====================================================
# Create Shadowsocks Scheduled Task
# =====================================================

Write-Host "Creating Shadowsocks task..."

$ssVbs = "$ssFolder\run_ss.vbs"

if (Test-Path $ssVbs) {

    $action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$ssVbs`""

    $trigger = New-ScheduledTaskTrigger `
        -AtStartup

    Register-ScheduledTask `
        -TaskName $ssTaskName `
        -Action $action `
        -Trigger $trigger `
        -User "SYSTEM" `
        -RunLevel Highest `
        -Force
}

# =====================================================
# Create Telemetry Scheduled Task
# =====================================================

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$agentPath`""

$trigger = New-ScheduledTaskTrigger `
    -AtStartup

Register-ScheduledTask `
    -TaskName $telemetryTaskName `
    -Action $action `
    -Trigger $trigger `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force

# =====================================================
# Start tasks immediately
# =====================================================

Start-ScheduledTask `
    -TaskName $telemetryTaskName

if (Get-ScheduledTask -TaskName $ssTaskName -ErrorAction SilentlyContinue) {

    Start-ScheduledTask `
        -TaskName $ssTaskName
}

Write-Host ""
Write-Host "================================="
Write-Host "Installation completed"
Write-Host "================================="