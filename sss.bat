# -------------------------------
# 0️⃣ Cleanup existing files/folders and tasks
# -------------------------------
$folderPath = "C:\sserver"
$zipPath = "C:\sserver\sserver.zip"
$taskName = "Shadowsocks Server"

# Delete folder if it exists
if (Test-Path $folderPath) {
    Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Delete zip file if it exists
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}

# Delete existing scheduled task if it exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

# -------------------------------
# 1️⃣ Create folder and download/extract files
# -------------------------------
New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
curl.exe -L "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip" -o $zipPath
Expand-Archive -Path $zipPath -DestinationPath $folderPath -Force
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# -------------------------------
# 2️⃣ Open firewall ports 12345-12364 (TCP & UDP)
# -------------------------------
$ports = 12345..12364

foreach ($p in $ports) {
    netsh advfirewall firewall add rule name="Shadowsocks_TCP_$p" dir=in action=allow protocol=TCP localport=$p
    netsh advfirewall firewall add rule name="Shadowsocks_UDP_$p" dir=in action=allow protocol=UDP localport=$p
}

# -------------------------------
# 3️⃣ Create scheduled task to run run_ss.vbs as SYSTEM
# -------------------------------
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "$folderPath\run_ss.vbs"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)  # no limit

# Register the task as SYSTEM (highest privileges)
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User "NT AUTHORITY\SYSTEM" `
    -RunLevel Highest `
    -Force
