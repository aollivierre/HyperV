Write-Host "`n=== Interactive Multi-NIC Test ===" -ForegroundColor Cyan
Write-Host "This will run the script in interactive mode" -ForegroundColor Yellow
Write-Host "`nInstructions:" -ForegroundColor Yellow
Write-Host "1. Select config: config-test-multinic" -ForegroundColor White
Write-Host "2. Confirm the configuration" -ForegroundColor White
Write-Host "3. Accept the recommended drive" -ForegroundColor White
Write-Host "4. The script will show multi-NIC is enabled" -ForegroundColor White
Write-Host "`nPress Enter to start..." -ForegroundColor Gray
Read-Host

# Run interactively
& "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"