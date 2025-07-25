# Validate specific logic from Create-VHDX-Working.ps1

Write-Host "Validating Script Logic" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

# Test 1: Path trimming
Write-Host "`nTest 1: Path quote trimming" -ForegroundColor Yellow
$testPath1 = '"C:\test\path with spaces\file.iso"'
$trimmed1 = $testPath1.Trim('"')
Write-Host "Original: $testPath1"
Write-Host "Trimmed: $trimmed1"
Write-Host "Success: $($trimmed1 -eq 'C:\test\path with spaces\file.iso')" -ForegroundColor Green

# Test 2: ISO validation regex
Write-Host "`nTest 2: ISO file validation" -ForegroundColor Yellow
$testFiles = @(
    "C:\test\file.iso",
    "C:\test\file.ISO", 
    "C:\test\file.wim",
    "file.iso"
)
foreach ($file in $testFiles) {
    $isValid = $file -match '\.iso$'
    Write-Host "$file -> Valid ISO: $isValid"
}

# Test 3: Drive letter extraction
Write-Host "`nTest 3: Drive letter extraction" -ForegroundColor Yellow
$paths = @(
    "C:\test\path",
    "D:\another\path",
    "\\network\share",
    "relative\path"
)
foreach ($path in $paths) {
    $drive = Split-Path $path -Qualifier
    Write-Host "$path -> Drive: '$drive'"
}

# Test 4: Dynamic VHDX naming
Write-Host "`nTest 4: VHDX file naming" -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$vhdxName = "Windows10_$timestamp.vhdx"
Write-Host "Generated name: $vhdxName"

Write-Host "`nAll validation tests completed!" -ForegroundColor Green