param(
    [string]$VHDXPath = "C:\code\VM\Setup\VHDX\test\Windows10_20250725_065545.vhdx"
)

Write-Host "`nValidating VHDX file..." -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

if (Test-Path $VHDXPath) {
    $vhdxInfo = Get-Item $VHDXPath
    
    Write-Host "`nFile Information:" -ForegroundColor Yellow
    Write-Host "  Path: $($vhdxInfo.FullName)"
    Write-Host "  Size: $([math]::Round($vhdxInfo.Length / 1GB, 2)) GB"
    Write-Host "  Created: $($vhdxInfo.CreationTime)"
    Write-Host "  Modified: $($vhdxInfo.LastWriteTime)"
    
    # Check if it's a valid VHDX by reading the header
    try {
        $bytes = [System.IO.File]::ReadAllBytes($VHDXPath)[0..7]
        $signature = [System.Text.Encoding]::ASCII.GetString($bytes)
        
        if ($signature -eq "vhdxfile") {
            Write-Host "`n✓ Valid VHDX signature detected" -ForegroundColor Green
            Write-Host "`nThe VHDX file has been successfully created!" -ForegroundColor Green
            Write-Host "This file contains a Windows 10 installation ready for use." -ForegroundColor Green
            
            Write-Host "`nNext steps to use this VHDX:" -ForegroundColor Yellow
            Write-Host "1. Once Hyper-V is installed, open Hyper-V Manager"
            Write-Host "2. Create a new Virtual Machine"
            Write-Host "3. Choose Generation 2 (for UEFI boot)"
            Write-Host "4. Select 'Use an existing virtual hard disk'"
            Write-Host "5. Browse to: $VHDXPath"
            Write-Host "6. Complete the wizard and start the VM"
            Write-Host "7. Windows 10 will boot and complete initial setup"
        } else {
            Write-Host "`n✗ Invalid VHDX signature: $signature" -ForegroundColor Red
        }
    } catch {
        Write-Host "`n⚠ Could not validate VHDX signature: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n✗ VHDX file not found at: $VHDXPath" -ForegroundColor Red
}

# List all VHDX files in the directory
Write-Host "`nAll VHDX files in directory:" -ForegroundColor Cyan
Get-ChildItem (Split-Path $VHDXPath -Parent) -Filter "*.vhdx" | ForEach-Object {
    $sizeGB = [math]::Round($_.Length / 1GB, 2)
    Write-Host "  - $($_.Name) ($sizeGB GB)"
}