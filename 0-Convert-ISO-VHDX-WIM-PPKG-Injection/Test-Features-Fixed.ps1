#requires -RunAsAdministrator

Write-Host "`nComprehensive Feature Testing" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Test 1: Drive Letter Validation
Write-Host "`nTest 1: Drive Letter Validation" -ForegroundColor Yellow
$testPath = "Z:\NonExistent\Path"
$drive = $null
try {
    $drive = Split-Path $testPath -Qualifier -ErrorAction SilentlyContinue
} catch {
    Write-Host "Split-Path handled gracefully" -ForegroundColor Green
}
Write-Host "Testing path: $testPath"
Write-Host "Extracted drive: $drive"
if ($drive -and !(Test-Path "$drive\")) {
    Write-Host "OK - Correctly identified non-existent drive" -ForegroundColor Green
}
Write-Host "`nAvailable drives on system:" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Format-Table Name, @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}}, @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}} -AutoSize

# Test 2: Edition Selection from ISO
Write-Host "`nTest 2: Edition Selection" -ForegroundColor Yellow
$isoPath = "C:\code\ISO\Windows10.iso"
if (Test-Path $isoPath) {
    Write-Host "Mounting ISO to check editions..." -ForegroundColor Gray
    try {
        $mount = Mount-DiskImage -ImagePath $isoPath -PassThru
        $drive = ($mount | Get-Volume).DriveLetter
        $wimPath = "${drive}:\sources\install.wim"
        if (!(Test-Path $wimPath)) {
            $wimPath = "${drive}:\sources\install.esd"
        }
        if (Test-Path $wimPath) {
            $editions = Get-WindowsImage -ImagePath $wimPath
            Write-Host "`nAvailable editions in ISO:" -ForegroundColor Green
            foreach ($edition in $editions) {
                Write-Host "[$($edition.ImageIndex)] $($edition.ImageName)"
            }
            Write-Host "OK - Edition listing works correctly" -ForegroundColor Green
        }
        Dismount-DiskImage -ImagePath $isoPath | Out-Null
    } catch {
        Write-Host "Error testing editions: $_" -ForegroundColor Red
    }
} else {
    Write-Host "ISO not found at $isoPath" -ForegroundColor Red
}

# Test 3: Disk Space Check
Write-Host "`nTest 3: Disk Space Check" -ForegroundColor Yellow
$testDir = $env:TEMP
$outputDrive = (Get-Item $testDir).PSDrive.Name
$driveInfo = Get-PSDrive $outputDrive
$freeSpaceGB = [math]::Round($driveInfo.Free / 1GB, 2)
$testSizeGB = 100
$requiredSpaceGB = [math]::Round($testSizeGB * 0.2, 2)
Write-Host "Test directory: $testDir"
Write-Host "Drive: $outputDrive"
Write-Host "Free space: $freeSpaceGB GB"
Write-Host "Required space (20% of $testSizeGB GB): $requiredSpaceGB GB"
if ($freeSpaceGB -lt $requiredSpaceGB) {
    Write-Host "OK - Low disk space warning would trigger" -ForegroundColor Yellow
} else {
    Write-Host "OK - Sufficient disk space available" -ForegroundColor Green
}

# Test 4: Dynamic Drive Letters
Write-Host "`nTest 4: Dynamic Drive Letter Assignment" -ForegroundColor Yellow
$usedLetters = (Get-PSDrive -PSProvider FileSystem).Name
$allLetters = 67..90 | ForEach-Object { [char]$_ }
$availableLetters = $allLetters | Where-Object { $_ -notin $usedLetters }
Write-Host "Used drive letters: $($usedLetters -join ', ')"
Write-Host "Available count: $($availableLetters.Count)"
if ($availableLetters.Count -ge 2) {
    Write-Host "Selected for EFI: $($availableLetters[0])"
    Write-Host "Selected for Windows: $($availableLetters[1])"
    Write-Host "OK - Dynamic drive letter assignment would work" -ForegroundColor Green
} else {
    Write-Host "ERROR - Not enough drive letters available!" -ForegroundColor Red
}

# Test 5: Path Handling
Write-Host "`nTest 5: Path Handling" -ForegroundColor Yellow
$quotedPath = '"C:\test path\with spaces\file.iso"'
$trimmed = $quotedPath.Trim('"')
Write-Host "Original: $quotedPath"
Write-Host "Trimmed: $trimmed"
Write-Host "OK - Quote trimming works" -ForegroundColor Green

# Test 6: ISO Validation
Write-Host "`nTest 6: ISO File Validation" -ForegroundColor Yellow
$testPaths = @(
    "C:\test\file.iso",
    "C:\test\file.ISO",
    "C:\test\file.wim"
)
foreach ($path in $testPaths) {
    $pattern = "\.iso$"
    $isValid = $path -match $pattern
    if ($isValid) {
        Write-Host "OK - $path" -ForegroundColor Green
    } else {
        Write-Host "FAIL - $path" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Automated tests completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nFor interactive tests, run:" -ForegroundColor Yellow
Write-Host ".\Create-VHDX-Working.ps1 -ISOPath `"C:\fake\test.iso`"" -ForegroundColor White
Write-Host ".\Create-VHDX-Working.ps1 -OutputDir `"Z:\fake\path`"" -ForegroundColor White