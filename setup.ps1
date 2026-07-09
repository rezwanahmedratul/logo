# =====================================================
# Shadowsocks + Telemetry Installer
# =====================================================
# Usage (run in elevated PowerShell):
#   powershell -ExecutionPolicy Bypass -File setup.ps1
# =====================================================

$ErrorActionPreference = "SilentlyContinue"

# =====================================================
# Configuration
# =====================================================

$ssFolder            = "C:\sserver"
$agentFolder         = "C:\telemetry-agent"
$webuiUrl            = "https://liveip.ratul.fun"
$telemetryEndpoint   = "$webuiUrl/api/telemetry"
$ssTaskName          = "Shadowsocks Server"
$telemetryTaskName   = "Telemetry Agent"
$zipUrl              = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip"
$telemetryScriptUrl  = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/telemetry.ps1"

# =====================================================
# Stop old services/processes
# =====================================================

Write-Host "Stopping old processes..."
Get-Process ssserver -ErrorAction SilentlyContinue | Stop-Process -Force

# =====================================================
# Remove old scheduled tasks
# =====================================================

foreach ($task in @($ssTaskName, $telemetryTaskName)) {
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {
        Write-Host "Removing task $task"
        Unregister-ScheduledTask -TaskName $task -Confirm:$false
    }
}

# =====================================================
# Remove old folders
# =====================================================

foreach ($folder in @($ssFolder, $agentFolder)) {
    if (Test-Path $folder) {
        Write-Host "Removing $folder"
        Remove-Item $folder -Recurse -Force
    }
}

# =====================================================
# Install Shadowsocks
# =====================================================

Write-Host "Downloading Shadowsocks..."
New-Item -ItemType Directory -Path $ssFolder -Force | Out-Null

$tempZip = "$env:TEMP\sserver.zip"
curl.exe -L $zipUrl -o $tempZip

Write-Host "Extracting..."
Expand-Archive -Path $tempZip -DestinationPath $ssFolder -Force
Remove-Item $tempZip -Force

# =====================================================
# Firewall Rules
# =====================================================

Write-Host "Creating firewall rules..."
foreach ($port in 12345..12364) {
    netsh advfirewall firewall add rule name="Shadowsocks TCP $port" dir=in action=allow protocol=TCP localport=$port
    netsh advfirewall firewall add rule name="Shadowsocks UDP $port" dir=in action=allow protocol=UDP localport=$port
}

# =====================================================
# Download Telemetry Agent
# =====================================================

Write-Host "Downloading telemetry agent..."
New-Item -ItemType Directory -Path $agentFolder -Force | Out-Null
$agentPath = "$agentFolder\telemetry.ps1"

Invoke-WebRequest -Uri $telemetryScriptUrl -OutFile $agentPath -UseBasicParsing

# Ensure endpoint is correct even if remote copy drifts
$content = Get-Content $agentPath -Raw
$content = $content -replace 'https://[^"]*ingest-telemetry', $telemetryEndpoint
$content = $content -replace 'https://[^"]*/api/telemetry', $telemetryEndpoint
Set-Content -Path $agentPath -Value $content -Encoding UTF8

# =====================================================
# Create Shadowsocks Scheduled Task
# =====================================================

Write-Host "Creating Shadowsocks task..."
$ssVbs = "$ssFolder\run_ss.vbs"
if (Test-Path $ssVbs) {
    $action  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$ssVbs`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $ssTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force
}

# =====================================================
# Create Telemetry Scheduled Task
# =====================================================

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agentPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $telemetryTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force

# =====================================================
# Start tasks immediately
# =====================================================

Start-ScheduledTask -TaskName $telemetryTaskName
if (Get-ScheduledTask -TaskName $ssTaskName -ErrorAction SilentlyContinue) {
    Start-ScheduledTask -TaskName $ssTaskName
}

Write-Host ""
Write-Host "================================="
Write-Host "Installation completed"
Write-Host "Telemetry endpoint: $telemetryEndpoint"
Write-Host "================================="
