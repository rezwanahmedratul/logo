# -------------------------------
# 0️⃣ Cleanup existing files/folders and tasks
# -------------------------------
$folderPath = "C:\sserver"
$zipPath = "C:\sserver\sserver.zip"
$taskName = "Shadowsocks Server"
$processName = "ssserver"

# Stop running Shadowsocks process
Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force

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

