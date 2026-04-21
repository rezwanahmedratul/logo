@echo off
timeout /t 5 >nul

netsh interface set interface "Ethernet" admin=disable
timeout /t 3 >nul
netsh interface set interface "Ethernet" admin=enable
