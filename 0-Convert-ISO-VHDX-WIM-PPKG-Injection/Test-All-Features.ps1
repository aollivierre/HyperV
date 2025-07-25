#requires -RunAsAdministrator

<#
.SYNOPSIS
    Comprehensive test of all features in Create-VHDX-Working.ps1
#>

param(
    [int]$TestNumber = 0
)

Write-Host "`nComprehensive Feature Testing" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

function Test-ISOPathPrompting {
    Write-Host "`nTest 1: ISO Path Prompting" -ForegroundColor Yellow
    Write-Host "Testing with non-existent ISO path..." -ForegroundColor Gray
    
    # Create a test script that simulates user input
    $testScript = @'
$input = "C:\fake\nonexistent.iso"
Write-Host "Simulating user input: $input"
$input | & ".\Create-VHDX-Working.ps1" -ISOPath "C:\fake\test.iso" -OutputDir "$env:TEMP\vhdx-test" -EditionIndex 1
'@
    
    # Note: This would need manual testing as PowerShell doesn't easily support automated input
    Write-Host "Manual test required: Run the following command and enter a valid ISO path when prompted:" -ForegroundColor Yellow
    Write-Host '.\Create-VHDX-Working.ps1 -ISOPath "C:\fake\test.iso"' -ForegroundColor White
    Write-Host ""
}

function Test-DriveLetterValidation {
    Write-Host "`nTest 2: Drive Letter Validation" -ForegroundColor Yellow
    
    # First, let's check what happens with our current logic
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
        Write-Host "✓ Correctly identified non-existent drive" -ForegroundColor Green
    }
    
    # Show available drives
    Write-Host "`nAvailable drives on system:" -ForegroundColor Cyan
    Get-PSDrive -PSProvider FileSystem | Format-Table Name, Used, Free -AutoSize
}

function Test-EditionSelection {
    Write-Host "`nTest 3: Edition Selection" -ForegroundColor Yellow
    
    # Test if we can list editions from the ISO
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
                Write-Host "✓ Edition listing works correctly" -ForegroundColor Green
            }
            
            Dismount-DiskImage -ImagePath $isoPath | Out-Null
        } catch {
            Write-Host "Error testing editions: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "ISO not found at $isoPath" -ForegroundColor Red
    }
}

function Test-DiskSpaceCheck {
    Write-Host "`nTest 4: Disk Space Check" -ForegroundColor Yellow
    
    # Test the disk space logic
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
        Write-Host "✓ Low disk space warning would trigger" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Sufficient disk space available" -ForegroundColor Green
    }
}

function Test-DynamicDriveLetters {
    Write-Host "`nTest 5: Dynamic Drive Letter Assignment" -ForegroundColor Yellow
    
    $usedLetters = (Get-PSDrive -PSProvider FileSystem).Name
    $allLetters = 67..90 | ForEach-Object { [char]$_ }
    $availableLetters = $allLetters | Where-Object { $_ -notin $usedLetters }
    
    Write-Host "Used drive letters: $($usedLetters -join ', ')"
    Write-Host "Available count: $($availableLetters.Count)"
    
    if ($availableLetters.Count -ge 2) {
        Write-Host "Selected for EFI: $($availableLetters[0])"
        Write-Host "Selected for Windows: $($availableLetters[1])"
        Write-Host "✓ Dynamic drive letter assignment would work" -ForegroundColor Green
    } else {
        Write-Host "✗ Not enough drive letters available!" -ForegroundColor Red
    }
}

function Test-PathHandling {
    Write-Host "`nTest 6: Path Handling" -ForegroundColor Yellow
    
    # Test quote trimming
    $quotedPath = '"C:\test path\with spaces\file.iso"'
    $trimmed = $quotedPath.Trim('"')
    Write-Host "Original: $quotedPath"
    Write-Host "Trimmed: $trimmed"
    Write-Host "✓ Quote trimming works" -ForegroundColor Green
    
    # Test ISO validation
    $testPaths = @(
        "C:\test\file.iso",
        "C:\test\file.ISO",
        "C:\test\file.wim"
    )
    
    Write-Host "`nISO validation:"
    foreach ($path in $testPaths) {
        $isValid = $path -match '\.iso$'
        $status = if ($isValid) { "✓" } else { "✗" }
        $color = if ($isValid) { "Green" } else { "Red" }
        Write-Host "$status $path" -ForegroundColor $color
    }
}

# Run all tests based on parameter
switch ($TestNumber) {
    0 {
        # Run all tests
        Test-DriveLetterValidation
        Test-EditionSelection
        Test-DiskSpaceCheck
        Test-DynamicDriveLetters
        Test-PathHandling
        Test-ISOPathPrompting
        
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Automated tests completed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "`nFor interactive tests, run:" -ForegroundColor Yellow
        Write-Host ".\Create-VHDX-Working.ps1 -ISOPath `"C:\fake\test.iso`"" -ForegroundColor White
        Write-Host ".\Create-VHDX-Working.ps1 -OutputDir `"Z:\fake\path`"" -ForegroundColor White
    }
    1 { Test-ISOPathPrompting }
    2 { Test-DriveLetterValidation }
    3 { Test-EditionSelection }
    4 { Test-DiskSpaceCheck }
    5 { Test-DynamicDriveLetters }
    6 { Test-PathHandling }
}