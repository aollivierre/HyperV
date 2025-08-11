# Test VM numbering fix
Write-Host "`n=== Testing VM Numbering Fix ===" -ForegroundColor Cyan

# Import the module
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Show current VMs with numbers
Write-Host "`nCurrent VMs with numbering:" -ForegroundColor Yellow
$numberedVMs = Get-VM | Where-Object { $_.Name -match '^(\d{3})\s*-' } | 
    Sort-Object { if ($_.Name -match '^(\d{3})\s*-') { [int]$matches[1] } } -Descending |
    Select-Object -First 5

foreach ($vm in $numberedVMs) {
    if ($vm.Name -match '^(\d{3})\s*-') {
        Write-Host "  [$($matches[1])] $($vm.Name)" -ForegroundColor Gray
    }
}

# Test the function
$testConfig = @{
    VMNamePrefixFormat = "{0:D3} - TEST - VM Numbering"
}

Write-Host "`nTesting Get-NextVMNamePrefix..." -ForegroundColor Yellow
$nextName = Get-NextVMNamePrefix -Config $testConfig

Write-Host "`nResult: Next VM should be named: $nextName" -ForegroundColor Green

# Verify the number is correct
if ($nextName -match '^(\d{3})\s*-') {
    $nextNumber = [int]$matches[1]
    Write-Host "Next VM number: $nextNumber" -ForegroundColor Green
    
    # Check if it's greater than the highest existing
    $highestExisting = 0
    Get-VM | Where-Object { $_.Name -match '^(\d{3})\s*-' } | ForEach-Object {
        if ($_.Name -match '^(\d{3})\s*-') {
            $num = [int]$matches[1]
            if ($num -gt $highestExisting) {
                $highestExisting = $num
            }
        }
    }
    
    if ($nextNumber -eq ($highestExisting + 1)) {
        Write-Host "`nSUCCESS: Numbering continues correctly from $highestExisting to $nextNumber" -ForegroundColor Green
    } else {
        Write-Host "`nERROR: Expected $($highestExisting + 1) but got $nextNumber" -ForegroundColor Red
    }
}