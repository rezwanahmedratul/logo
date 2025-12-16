Set-Location C:\
New-Item -ItemType Directory -Path "C:\sserver" -Force | Out-Null
curl.exe -L "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip" -o "C:\sserver\sserver.zip"
Expand-Archive -Path "C:\sserver\sserver.zip" -DestinationPath "C:\sserver" -Force
Remove-Item "C:\sserver\sserver.zip" -Force -ErrorAction SilentlyContinue

# -------------------------------
# 2️⃣ Open firewall ports 12345-12364 (TCP & UDP)
# -------------------------------
$ports = 12345..12364

foreach ($p in $ports) {
    # Old-style: netsh (works)
    netsh advfirewall firewall add rule name="Shadowsocks_TCP_$p" dir=in action=allow protocol=TCP localport=$p
    netsh advfirewall firewall add rule name="Shadowsocks_UDP_$p" dir=in action=allow protocol=UDP localport=$p

    # Modern alternative (uncomment to use instead of netsh)
    # New-NetFirewallRule -DisplayName "Shadowsocks_TCP_$p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p
    # New-NetFirewallRule -DisplayName "Shadowsocks_UDP_$p" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $p
}

# -------------------------------
# 3️⃣ Create scheduled task to run run_ss.vbs
# -------------------------------
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "C:\sserver\run_ss.vbs"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)  # no limit

# Register under current user (runs at highest; run PowerShell as Admin to set RunLevel Highest)
Register-ScheduledTask `
    -TaskName "Shadowsocks Server" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force

# If you want the task to run as SYSTEM (no password), register like this (requires Admin):
# Register-ScheduledTask -TaskName "Shadowsocks Server" -Action $action -Trigger $trigger -Settings $settings -User "NT AUTHORITY\SYSTEM" -RunLevel Highest -Force
