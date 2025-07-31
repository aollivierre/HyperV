# Test OPNsense config which has UseAllAvailableSwitches = $true
Write-Host "`n=== Testing OPNsense VM with Multi-NIC ===" -ForegroundColor Cyan

# Run the main script and specify OPNsense config
Write-Host "Running main script with OPNsense configuration..." -ForegroundColor Yellow
Write-Host "When prompted, select: config-server-Opensense-server" -ForegroundColor Yellow

& "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"