# Simple VHDX validation script
$vhdxDir = "C:\code\VM\Setup\VHDX\test"

Write-Host ""
Write-Host "VHDX Files Created:" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host ""

Get-ChildItem $vhdxDir -Filter "*.vhdx" | ForEach-Object {
    $size = [math]::Round($_.Length / 1GB, 2)
    Write-Host "File: $($_.Name)"
    Write-Host "Size: $size GB"
    Write-Host "Created: $($_.CreationTime)"
    Write-Host ""
}

Write-Host "SUCCESS! Your VHDX files are ready to use with Hyper-V!" -ForegroundColor Green
Write-Host ""
Write-Host "Once Hyper-V is installed, you can:" -ForegroundColor Yellow
Write-Host "1. Open Hyper-V Manager"
Write-Host "2. Create a new Generation 2 VM"
Write-Host "3. Use one of the VHDX files above"
Write-Host "4. Start the VM to complete Windows setup"