# Restart Hyper-V services
Write-Host "Restarting Hyper-V services..." -ForegroundColor Cyan
Restart-Service vmms -Force
Restart-Service nvspwmi -Force -ErrorAction SilentlyContinue
Write-Host "Hyper-V services restarted" -ForegroundColor Green

# Refresh network configuration
Write-Host "Refreshing network configuration..." -ForegroundColor Cyan
ipconfig /release
ipconfig /renew
ipconfig /flushdns
Write-Host "Network configuration refreshed" -ForegroundColor Green

# Test connection
Write-Host "Testing connection to OPNsense..." -ForegroundColor Cyan
ping 198.18.1.1