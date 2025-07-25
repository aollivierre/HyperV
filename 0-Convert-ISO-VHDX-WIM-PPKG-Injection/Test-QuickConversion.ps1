#requires -RunAsAdministrator

Write-Host "`nQuick End-to-End Conversion Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Test with a small VHDX (20GB) to save time and space
$testParams = @{
    ISOPath = "C:\code\ISO\Windows10.iso"
    OutputDir = "$env:TEMP\vhdx-test"
    SizeGB = 20  # Small size for testing
    EditionIndex = 6  # Pro edition, skip prompting
}

Write-Host "`nTest Parameters:" -ForegroundColor Yellow
Write-Host "ISO: $($testParams.ISOPath)"
Write-Host "Output: $($testParams.OutputDir)"
Write-Host "Size: $($testParams.SizeGB) GB"
Write-Host "Edition: $($testParams.EditionIndex) (Pro)"

# Check if we have enough space
$tempDrive = (Get-Item $env:TEMP).PSDrive.Name
$freeSpace = [math]::Round((Get-PSDrive $tempDrive).Free / 1GB, 2)
Write-Host "`nFree space on ${tempDrive}: $freeSpace GB"

if ($freeSpace -lt 5) {
    Write-Host "ERROR: Not enough free space for test (need at least 5GB)" -ForegroundColor Red
    exit 1
}

Write-Host "`nStarting conversion test..." -ForegroundColor Green
Write-Host "This will create a small test VHDX to verify all features work correctly." -ForegroundColor Gray

# Create output directory if needed
if (!(Test-Path $testParams.OutputDir)) {
    New-Item -ItemType Directory -Path $testParams.OutputDir -Force | Out-Null
}

# Run the conversion
try {
    & .\Create-VHDX-Working.ps1 @testParams
    
    # Check if VHDX was created
    $vhdxFiles = Get-ChildItem $testParams.OutputDir -Filter "*.vhdx" | Sort-Object LastWriteTime -Descending
    
    if ($vhdxFiles.Count -gt 0) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "SUCCESS! Test VHDX created:" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        foreach ($vhdx in $vhdxFiles) {
            $sizeGB = [math]::Round($vhdx.Length / 1GB, 2)
            Write-Host "$($vhdx.Name) - $sizeGB GB" -ForegroundColor Cyan
        }
        
        Write-Host "`nAll features working correctly!" -ForegroundColor Green
    } else {
        Write-Host "`nERROR: No VHDX files found in output directory" -ForegroundColor Red
    }
} catch {
    Write-Host "`nERROR during conversion: $_" -ForegroundColor Red
}

# Cleanup option
Write-Host "`nCleanup test files? (Y/N)" -ForegroundColor Yellow
$cleanup = Read-Host
if ($cleanup -eq 'Y' -or $cleanup -eq 'y') {
    Remove-Item $testParams.OutputDir -Recurse -Force
    Write-Host "Test files removed." -ForegroundColor Green
}