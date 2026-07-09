$url = "https://gitlab.com/rezwanahmedratul/sserver/-/raw/main/shadowsocks-installer.exe?inline=false"
$outputPath = Join-Path $env:TEMP "shadowsocks-installer.exe"

# 1. Download the file into the temp directory
Invoke-WebRequest -Uri $url -OutFile $outputPath

# 2. Run the downloaded executable
Start-Process -FilePath $outputPath -Wait
