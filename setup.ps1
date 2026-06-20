# =====================================================
# Shadowsocks + Telemetry Installer (DEBUG VERSION)
# =====================================================

$ErrorActionPreference = "Stop"

# =====================================================
# Configuration
# =====================================================

$ssFolder = "C:\sserver"
$agentFolder = "C:\telemetry-agent"

$telemetryUrl = "https://telemetry-dashboard-dzyo.onrender.com/api/telemetry"

$machineId = $env:COMPUTERNAME

$ssTaskName = "Shadowsocks Server"
$telemetryTaskName = "Telemetry Agent"

$zipUrl = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip"


Write-Host "================================="
Write-Host "DEBUG INSTALLER STARTED"
Write-Host "Computer: $machineId"
Write-Host "PowerShell:"
$PSVersionTable.PSVersion
Write-Host "================================="


# =====================================================
# Stop old processes
# =====================================================

Write-Host ""
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

    try {

        if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {

            Write-Host "Removing task: $task"

            Unregister-ScheduledTask `
                -TaskName $task `
                -Confirm:$false
        }

    }
    catch {

        Write-Host "Task removal error:"
        Write-Host $_.Exception.Message

    }
}


# =====================================================
# Remove old folders
# =====================================================

foreach ($folder in @(
    $ssFolder,
    $agentFolder
)) {

    try {

        if (Test-Path $folder) {

            Write-Host "Removing folder: $folder"

            Remove-Item `
                $folder `
                -Recurse `
                -Force
        }

    }
    catch {

        Write-Host "Folder removal error:"
        Write-Host $_.Exception.Message

    }
}


# =====================================================
# Install Shadowsocks
# =====================================================

Write-Host ""
Write-Host "Downloading Shadowsocks..."

New-Item `
    -ItemType Directory `
    -Path $ssFolder `
    -Force |
    Out-Null


$tempZip = "$env:TEMP\sserver.zip"


curl.exe `
    -L `
    $zipUrl `
    -o `
    $tempZip


if (!(Test-Path $tempZip)) {

    throw "Download failed: $tempZip not found"

}


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

Write-Host ""
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

Write-Host ""
Write-Host "Creating telemetry agent..."


New-Item `
    -ItemType Directory `
    -Path $agentFolder `
    -Force |
    Out-Null


$agentPath = "$agentFolder\telemetry.ps1"


$agentContent = @"

`$server = "$telemetryUrl"

`$machineId = "$machineId"


Write-Host "Telemetry agent started"

Write-Host "Server:"
Write-Host `$server


function Get-Telemetry {


    `$ip = "Unknown"


    try {

        `$ip = (
            Invoke-RestMethod `
            -Uri "https://api.ipify.org" `
            -TimeoutSec 10
        ).ToString()


        Write-Host "IP:"
        Write-Host `$ip

    }
    catch {

        Write-Host "IP ERROR:"
        Write-Host `$_.Exception.Message

    }



    `$cpu = "Unknown"


    try {

        `$cpu = (
            Get-CimInstance Win32_Processor
        ).Name -replace '\s+',' '

    }
    catch {

        Write-Host "CPU ERROR:"
        Write-Host `$_.Exception.Message

    }



    `$ram = "Unknown"


    try {

        `$ramGB = (
            Get-CimInstance Win32_PhysicalMemory |
            Measure-Object Capacity -Sum
        ).Sum / 1GB


        `$ram = "$([math]::Round(`$ramGB)) GB"

    }
    catch {

        Write-Host "RAM ERROR:"
        Write-Host `$_.Exception.Message

    }

    `$disk = "Unknown"


    try {

        `$diskGB = (
            Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"
        ).Size / 1GB


        `$disk = "$([math]::Round(`$diskGB)) GB"

    }
    catch {

        Write-Host "DISK ERROR:"
        Write-Host `$_.Exception.Message

    }



    `$os = "Unknown"


    try {

        `$os = (
            Get-CimInstance Win32_OperatingSystem
        ).Caption

    }
    catch {

        Write-Host "OS ERROR:"
        Write-Host `$_.Exception.Message

    }



    return @{

        machineId = `$machineId

        hostname = `$env:COMPUTERNAME

        ip = `$ip

        user = `$env:USERNAME

        os = `$os

        cpu = `$cpu

        ram = `$ram

        disk = `$disk

    }

}



while (`$true) {


    try {


        Write-Host ""
        Write-Host "Collecting telemetry..."


        `$payload = Get-Telemetry |
            ConvertTo-Json -Compress



        Write-Host "Sending payload:"
        Write-Host `$payload



        `$response = Invoke-RestMethod `

            -Uri `$server `

            -Method POST `

            -Body `$payload `

            -ContentType "application/json" `

            -TimeoutSec 15



        Write-Host "SUCCESS"

        Write-Host "Server response:"

        Write-Host (`$response | ConvertTo-Json)



    }

    catch {


        Write-Host ""

        Write-Host "TELEMETRY SEND ERROR:"

        Write-Host `$_.Exception.Message


    }



    Start-Sleep -Seconds 10

}


"@



Set-Content `

    -Path $agentPath `

    -Value $agentContent `

    -Encoding UTF8



Write-Host "Telemetry agent created:"
Write-Host $agentPath



# =====================================================
# Create Shadowsocks Scheduled Task
# =====================================================

Write-Host ""

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

else {

    Write-Host "Shadowsocks VBS not found:"
    Write-Host $ssVbs

}




# =====================================================
# Create Telemetry Scheduled Task
# =====================================================


Write-Host ""

Write-Host "Creating telemetry task..."



$action = New-ScheduledTaskAction `

    -Execute "powershell.exe" `

    -Argument "-NoExit -ExecutionPolicy Bypass -File `"$agentPath`""



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


Write-Host ""

Write-Host "Starting telemetry task..."



Start-ScheduledTask `

    -TaskName $telemetryTaskName



if (Get-ScheduledTask -TaskName $ssTaskName -ErrorAction SilentlyContinue) {


    Write-Host "Starting Shadowsocks task..."


    Start-ScheduledTask `

        -TaskName $ssTaskName

}



Write-Host ""

Write-Host "================================="
Write-Host "DEBUG INSTALLATION COMPLETED"
Write-Host "================================="

Write-Host ""

Write-Host "Telemetry agent location:"
Write-Host $agentPath

Write-Host ""

Write-Host "To manually test:"
Write-Host "powershell.exe -ExecutionPolicy Bypass -File $agentPath"