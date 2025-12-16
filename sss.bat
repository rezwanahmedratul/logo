$folderPath = "C:\sserver"
$zipPath = "$folderPath\sserver.zip"
$processName = "ssserver"

# Stop running process
Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force

# Delete old folder if exists
if (Test-Path $folderPath) {
    Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Recreate folder
New-Item -ItemType Directory -Path $folderPath -Force | Out-Null

# Download new zip
curl.exe -L "https://raw.githubusercontent.com/rezwanahmedratul/logo/main/sserver.zip" -o $zipPath

# Extract
Expand-Archive -Path $zipPath -DestinationPath $folderPath -Force

# Remove zip
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
