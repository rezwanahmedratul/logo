# =====================================================
# Shadowsocks + Telemetry Installer (DEBUG VERSION)
# Part 1/3
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


Write-Host ""
Write-Host "================================="
Write-Host "Telemetry Installer DEBUG MODE"
Write-Host "================================="

Write-Host "Computer:"
Write-Host $machineId

Write-Host "PowerShell:"
$PSVersionTable.PSVersion


# =====================================================
# Stop old processes
# =====================================================

Write-Host ""
Write-Host "Stopping old processes..."


try {

    Get-Process ssserver -ErrorAction SilentlyContinue |
        Stop-Process -Force

}
catch {

    Write-Host "Process stop error:"
    Write-Host $_.Exception.Message

}



# =====================================================
# Remove old scheduled tasks
# =====================================================

Write-Host ""
Write-Host "Removing old tasks..."


foreach ($task in @(
    $ssTaskName,
    $telemetryTaskName
)) {

    try {

        $existingTask = Get-ScheduledTask `
            -TaskName $task `
            -ErrorAction SilentlyContinue


        if ($existingTask) {

            Write-Host "Removing:"
            Write-Host $task


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

Write-Host ""
Write-Host "Removing old folders..."


foreach ($folder in @(
    $ssFolder,
    $agentFolder
)) {

    try {

        if (Test-Path $folder) {

            Write-Host "Removing:"
            Write-Host $folder


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

    throw "Download failed. ZIP file not found."

}



Write-Host "Extracting Shadowsocks..."


Expand-Archive `
    -Path $tempZip `
    -DestinationPath $ssFolder `
    -Force



Remove-Item `
    $tempZip `
    -Force



Write-Host "Shadowsocks installed:"
Write-Host $ssFolder



# =====================================================
# Firewall Rules
# =====================================================

Write-Host ""
Write-Host "Creating firewall rules..."


foreach ($port in 12345..12364) {


    try {


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
    catch {

        Write-Host "Firewall error:"
        Write-Host $_.Exception.Message

    }

}


Write-Host ""
Write-Host "Part 1 completed successfully."

# =====================================================
# Create Telemetry Agent
# Part 2/3
# =====================================================


Write-Host ""
Write-Host "Creating telemetry agent..."


New-Item `
    -ItemType Directory `
    -Path $agentFolder `
    -Force |
    Out-Null



$agentPath = "$agentFolder\telemetry.ps1"

$logPath = "$agentFolder\telemetry.log"



$agentContent = @'

$server = "__SERVER_URL__"

$machineId = "__MACHINE_ID__"

$log = "__LOG_PATH__"



function Write-Log($message) {

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content `
        -Path $log `
        -Value "$time : $message"

}



Write-Log "Telemetry agent started"

Write-Log "Server: $server"



function Get-Telemetry {


    $ip = "Unknown"


    try {

        $ip = (
            Invoke-RestMethod `
            -Uri "https://api.ipify.org" `
            -TimeoutSec 10
        ).ToString()


        Write-Log "IP: $ip"

    }

    catch {

        Write-Log "IP ERROR: $($_.Exception.Message)"

    }



    $cpu = "Unknown"


    try {

        $cpu = (
            Get-CimInstance Win32_Processor
        ).Name -replace '\s+',' '

    }

    catch {

        Write-Log "CPU ERROR: $($_.Exception.Message)"

    }




    $ram = "Unknown"


    try {

        $ramGB = (
            Get-CimInstance Win32_PhysicalMemory |
            Measure-Object Capacity -Sum
        ).Sum / 1GB


        $ram = ([math]::Round($ramGB)).ToString() + " GB"

    }

    catch {

        Write-Log "RAM ERROR: $($_.Exception.Message)"

    }




    $disk = "Unknown"


    try {

        $diskGB = (
            Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"
        ).Size / 1GB


        $disk = ([math]::Round($diskGB)).ToString() + " GB"

    }

    catch {

        Write-Log "DISK ERROR: $($_.Exception.Message)"

    }




    $os = "Unknown"


    try {

        $os = (
            Get-CimInstance Win32_OperatingSystem
        ).Caption

    }

    catch {

        Write-Log "OS ERROR: $($_.Exception.Message)"

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


        Write-Log "Collecting telemetry"



        $payload = Get-Telemetry |
            ConvertTo-Json -Compress



        Write-Log "Sending payload:"
        Write-Log $payload



        $response = Invoke-RestMethod `

            -Uri $server `

            -Method POST `

            -Body $payload `

            -ContentType "application/json" `

            -TimeoutSec 15



        Write-Log "SUCCESS"

        Write-Log ($response | ConvertTo-Json)



    }


    catch {


        Write-Log "SEND ERROR:"
        Write-Log $_.Exception.Message


    }



    Start-Sleep -Seconds 10

}

'@



# Replace placeholders safely

$agentContent = $agentContent.Replace(
    "__SERVER_URL__",
    $telemetryUrl
)


$agentContent = $agentContent.Replace(
    "__MACHINE_ID__",
    $machineId
)


$agentContent = $agentContent.Replace(
    "__LOG_PATH__",
    $logPath
)



Set-Content `

    -Path $agentPath `

    -Value $agentContent `

    -Encoding UTF8



Write-Host "Telemetry agent created:"
Write-Host $agentPath



Write-Host ""
Write-Host "Testing generated telemetry script syntax..."


powershell.exe `
    -ExecutionPolicy Bypass `
    -Command "& { [void][scriptblock]::Create((Get-Content '$agentPath' -Raw)); Write-Host 'Syntax OK' }"



Write-Host ""
Write-Host "Part 2 completed successfully."

# =====================================================
# Scheduled Tasks
# Part 3/3
# =====================================================


# =====================================================
# Create Shadowsocks Scheduled Task
# =====================================================

Write-Host ""
Write-Host "Creating Shadowsocks scheduled task..."


$ssVbs = "$ssFolder\run_ss.vbs"



if (Test-Path $ssVbs) {


    try {


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



        Write-Host "Shadowsocks task created"


    }

    catch {


        Write-Host "Shadowsocks task error:"

        Write-Host $_.Exception.Message


    }

}

else {


    Write-Host "WARNING:"
    Write-Host "Shadowsocks VBS not found:"
    Write-Host $ssVbs


}




# =====================================================
# Create Telemetry Scheduled Task
# =====================================================


Write-Host ""

Write-Host "Creating telemetry scheduled task..."



try {


    $action = New-ScheduledTaskAction `

        -Execute "powershell.exe" `

        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agentPath`""



    $trigger = New-ScheduledTaskTrigger `

        -AtStartup `

        -RandomDelay (New-TimeSpan -Seconds 30)



    Register-ScheduledTask `

        -TaskName $telemetryTaskName `

        -Action $action `

        -Trigger $trigger `

        -User "SYSTEM" `

        -RunLevel Highest `

        -Force



    Write-Host "Telemetry task created"


}

catch {


    Write-Host "Telemetry task error:"

    Write-Host $_.Exception.Message


}




# =====================================================
# Start Tasks Immediately
# =====================================================


Write-Host ""

Write-Host "Starting telemetry task..."



try {


    Start-ScheduledTask `

        -TaskName $telemetryTaskName



    Write-Host "Telemetry started"


}

catch {


    Write-Host "Telemetry start error:"

    Write-Host $_.Exception.Message


}




if (Get-ScheduledTask -TaskName $ssTaskName -ErrorAction SilentlyContinue) {


    Write-Host ""

    Write-Host "Starting Shadowsocks..."



    try {


        Start-ScheduledTask `

            -TaskName $ssTaskName



        Write-Host "Shadowsocks started"


    }

    catch {


        Write-Host "Shadowsocks start error:"

        Write-Host $_.Exception.Message


    }


}



# =====================================================
# Final Status
# =====================================================


Write-Host ""

Write-Host "================================="
Write-Host "INSTALLATION COMPLETE"
Write-Host "================================="


Write-Host ""

Write-Host "Telemetry file:"
Write-Host $agentPath


Write-Host ""

Write-Host "Telemetry log:"
Write-Host $logPath


Write-Host ""

Write-Host "To debug telemetry manually:"
Write-Host "powershell.exe -ExecutionPolicy Bypass -File $agentPath"


Write-Host ""

Write-Host "Waiting 15 seconds for first heartbeat..."

Start-Sleep -Seconds 15



if (Test-Path $logPath) {


    Write-Host ""

    Write-Host "Latest telemetry log:"

    Get-Content $logPath -Tail 20


}

else {


    Write-Host ""

    Write-Host "No telemetry log created yet."

}