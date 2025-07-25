#requires -RunAsAdministrator

<#
.SYNOPSIS
    Tests the graceful handling features of Create-VHDX-Working.ps1
#>

Write-Host "Testing Graceful Handling Features" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Test 1: Invalid ISO path
Write-Host "`nTest 1: Testing invalid ISO path handling..." -ForegroundColor Yellow
Write-Host "This should prompt for a valid ISO path" -ForegroundColor Gray
& .\Create-VHDX-Working.ps1 -ISOPath "C:\fake\path\does-not-exist.iso" -OutputDir "$env:TEMP\vhdx-test" -EditionIndex 1

# Test 2: Invalid drive letter
Write-Host "`nTest 2: Testing invalid drive letter..." -ForegroundColor Yellow
Write-Host "This should show available drives and prompt for valid path" -ForegroundColor Gray
& .\Create-VHDX-Working.ps1 -ISOPath "C:\code\ISO\Windows10.iso" -OutputDir "Z:\InvalidDrive\test" -EditionIndex 1

# Test 3: Check if dynamic drive letters work
Write-Host "`nTest 3: Checking available drive letters..." -ForegroundColor Yellow
$usedLetters = (Get-PSDrive -PSProvider FileSystem).Name
$allLetters = 67..90 | ForEach-Object { [char]$_ }
$availableLetters = $allLetters | Where-Object { $_ -notin $usedLetters }

Write-Host "Used drive letters: $($usedLetters -join ', ')"
Write-Host "Available drive letters: $($availableLetters -join ', ')"
Write-Host "Count: $($availableLetters.Count)"

if ($availableLetters.Count -lt 2) {
    Write-Host "WARNING: Less than 2 drive letters available!" -ForegroundColor Red
}

# Test 4: Test disk space check
Write-Host "`nTest 4: Checking disk space..." -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
foreach ($drive in $drives) {
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Host "$($drive.Name): drive - $freeGB GB free"
}

Write-Host "`nAll tests completed. Review output above for any issues." -ForegroundColor Green