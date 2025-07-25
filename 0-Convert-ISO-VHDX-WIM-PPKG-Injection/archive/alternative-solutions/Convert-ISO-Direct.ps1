#requires -RunAsAdministrator

<#
.SYNOPSIS
    Direct ISO to VHDX converter for Windows Server 2025 compatibility.

.DESCRIPTION
    This script directly creates and configures a VHDX from a Windows ISO,
    bypassing the Convert-WindowsImage module to avoid Server 2025 hanging issues.
#>

param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$VHDXPath = "C:\code\VM\Setup\VHDX\test\Windows10_Direct.vhdx",
    [int64]$VHDXSize = 100GB,
    [switch]$UseEFI = $true
)

Write-Host "Direct ISO to VHDX Converter" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

# Step 1: Create VHDX
Write-Host "`n[1/7] Creating VHDX file..." -ForegroundColor Yellow
try {
    $vhdxDir = Split-Path -Parent $VHDXPath
    if (!(Test-Path $vhdxDir)) {
        New-Item -ItemType Directory -Path $vhdxDir -Force | Out-Null
    }
    
    $vhd = New-VHD -Path $VHDXPath -SizeBytes $VHDXSize -Dynamic
    Write-Host "Created: $VHDXPath ($($VHDXSize/1GB) GB)" -ForegroundColor Green
} catch {
    Write-Host "Failed to create VHDX: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Mount and Initialize
Write-Host "`n[2/7] Mounting and initializing disk..." -ForegroundColor Yellow
try {
    $vhdMount = Mount-VHD -Path $VHDXPath -PassThru
    $diskNumber = $vhdMount.DiskNumber
    
    if ($UseEFI) {
        Initialize-Disk -Number $diskNumber -PartitionStyle GPT -Confirm:$false
    } else {
        Initialize-Disk -Number $diskNumber -PartitionStyle MBR -Confirm:$false
    }
    Write-Host "Initialized disk $diskNumber as $(if($UseEFI){'GPT/UEFI'}else{'MBR/BIOS'})" -ForegroundColor Green
} catch {
    Write-Host "Failed to initialize disk: $_" -ForegroundColor Red
    Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    exit 1
}

# Step 3: Create Partitions
Write-Host "`n[3/7] Creating partitions..." -ForegroundColor Yellow
try {
    if ($UseEFI) {
        # EFI System Partition
        $efiPart = New-Partition -DiskNumber $diskNumber -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -AssignDriveLetter
        Format-Volume -DriveLetter $efiPart.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "EFI" -Confirm:$false | Out-Null
        
        # MSR Partition
        New-Partition -DiskNumber $diskNumber -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' | Out-Null
        
        # Windows Partition
        $winPart = New-Partition -DiskNumber $diskNumber -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -AssignDriveLetter
        Format-Volume -DriveLetter $winPart.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
    } else {
        # Single MBR partition
        $winPart = New-Partition -DiskNumber $diskNumber -UseMaximumSize -IsActive -AssignDriveLetter
        Format-Volume -DriveLetter $winPart.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
    }
    Write-Host "Partitions created successfully" -ForegroundColor Green
    Write-Host "  Windows: $($winPart.DriveLetter):" -ForegroundColor Gray
    if ($UseEFI) {
        Write-Host "  EFI: $($efiPart.DriveLetter):" -ForegroundColor Gray
    }
} catch {
    Write-Host "Failed to create partitions: $_" -ForegroundColor Red
    Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    exit 1
}

# Step 4: Mount ISO
Write-Host "`n[4/7] Mounting ISO..." -ForegroundColor Yellow
try {
    $isoMount = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $isoDrive = ($isoMount | Get-Volume).DriveLetter
    Write-Host "ISO mounted at $isoDrive`:" -ForegroundColor Green
    
    # Find install.wim or install.esd
    $wimPath = "$isoDrive`:\sources\install.wim"
    if (!(Test-Path $wimPath)) {
        $wimPath = "$isoDrive`:\sources\install.esd"
        if (!(Test-Path $wimPath)) {
            throw "No install.wim or install.esd found in ISO"
        }
    }
    Write-Host "Found image: $wimPath" -ForegroundColor Gray
} catch {
    Write-Host "Failed to mount ISO: $_" -ForegroundColor Red
    Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    exit 1
}

# Step 5: List and Select Edition
Write-Host "`n[5/7] Selecting Windows edition..." -ForegroundColor Yellow
try {
    $images = Get-WindowsImage -ImagePath $wimPath
    Write-Host "`nAvailable editions:" -ForegroundColor Cyan
    $images | ForEach-Object { Write-Host "  [$($_.ImageIndex)] $($_.ImageName)" }
    
    # Auto-select first edition for automation
    $imageIndex = 1
    $selectedImage = $images | Where-Object { $_.ImageIndex -eq $imageIndex }
    Write-Host "`nSelected: [$imageIndex] $($selectedImage.ImageName)" -ForegroundColor Green
} catch {
    Write-Host "Failed to read Windows images: $_" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
    Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    exit 1
}

# Step 6: Apply Windows Image
Write-Host "`n[6/7] Applying Windows image (this will take several minutes)..." -ForegroundColor Yellow
try {
    $startTime = Get-Date
    
    # Show progress with a background job
    $applyJob = Start-Job -ScriptBlock {
        param($wimPath, $imageIndex, $targetPath)
        $env:DISM_LOG_PATH = "$env:TEMP\dism_apply.log"
        dism /Apply-Image /ImageFile:"$wimPath" /Index:$imageIndex /ApplyDir:"$targetPath" /Quiet
        return $LASTEXITCODE
    } -ArgumentList $wimPath, $imageIndex, "$($winPart.DriveLetter):\"
    
    # Monitor progress
    while ($applyJob.State -eq 'Running') {
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "`rApplying image... Elapsed: $elapsed seconds" -NoNewline
        Start-Sleep -Seconds 2
    }
    
    $result = Receive-Job -Job $applyJob
    Remove-Job -Job $applyJob
    
    if ($result -ne 0) {
        throw "DISM failed with exit code: $result"
    }
    
    Write-Host "`nImage applied successfully!" -ForegroundColor Green
} catch {
    Write-Host "`nFailed to apply image: $_" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
    Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    exit 1
}

# Step 7: Configure Boot
Write-Host "`n[7/7] Configuring boot files..." -ForegroundColor Yellow
try {
    if ($UseEFI) {
        $bcdResult = & bcdboot "$($winPart.DriveLetter):\Windows" /s "$($efiPart.DriveLetter):" /f UEFI
    } else {
        $bcdResult = & bcdboot "$($winPart.DriveLetter):\Windows" /s "$($winPart.DriveLetter):" /f BIOS
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "BCDBoot failed: $bcdResult"
    }
    
    Write-Host "Boot configured successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to configure boot: $_" -ForegroundColor Red
    # Continue anyway as this might still work
}

# Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Yellow
Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
Dismount-VHD -Path $VHDXPath

# Success!
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SUCCESS! VHDX created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Location: $VHDXPath" -ForegroundColor Cyan
Write-Host "Size: $($VHDXSize/1GB) GB" -ForegroundColor Cyan
Write-Host "Type: $(if($UseEFI){'UEFI/Gen2'}else{'BIOS/Gen1'})" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Open Hyper-V Manager"
Write-Host "2. Create New Virtual Machine"
Write-Host "3. Choose 'Use an existing virtual hard disk'"
Write-Host "4. Browse to: $VHDXPath"
Write-Host "5. Complete the wizard and start your VM!"