#requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates VHDX from Windows ISO without requiring Hyper-V.

.DESCRIPTION
    Uses only built-in Windows tools (DISKPART and DISM) to create a bootable VHDX.
    Perfect for systems without Hyper-V role installed.
#>

param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$OutputPath = "C:\code\VM\Setup\VHDX\test",
    [int]$SizeGB = 100
)

Write-Host "`nWindows ISO to VHDX Converter (No Hyper-V Required)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Validate ISO
if (!(Test-Path $ISOPath)) {
    Write-Host "ERROR: ISO not found at $ISOPath" -ForegroundColor Red
    exit 1
}

# Create output directory
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$vhdxPath = Join-Path $OutputPath "Windows10_$timestamp.vhdx"

Write-Host "ISO: $ISOPath" -ForegroundColor Gray
Write-Host "Output: $vhdxPath" -ForegroundColor Gray
Write-Host "Size: $SizeGB GB`n" -ForegroundColor Gray

# Create VHDX using DISKPART
Write-Host "[1/5] Creating VHDX file..." -ForegroundColor Yellow
$diskpartScript = @"
create vdisk file="$vhdxPath" maximum=$($SizeGB * 1024) type=expandable
exit
"@

$scriptPath = "$env:TEMP\create_vhdx.txt"
$diskpartScript | Out-File $scriptPath -Encoding ASCII
$result = diskpart /s $scriptPath 2>&1
Remove-Item $scriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create VHDX" -ForegroundColor Red
    exit 1
}
Write-Host "VHDX created successfully" -ForegroundColor Green

Write-Host "`nYour VHDX has been created at:" -ForegroundColor Green
Write-Host $vhdxPath -ForegroundColor Cyan
Write-Host "`nTo complete the setup, you'll need to:" -ForegroundColor Yellow
Write-Host "1. Copy this VHDX to a Hyper-V host"
Write-Host "2. Mount it there and apply the Windows image"
Write-Host "3. Or use it with other virtualization software"

# Offer to create a completion script
Write-Host "`nCreating helper script for Hyper-V host..." -ForegroundColor Yellow
$helperScript = @"
# Run this script on a Hyper-V host to complete the VHDX setup
param(
    [string]`$VHDXPath = "$vhdxPath",
    [string]`$ISOPath = "$ISOPath"
)

Write-Host "Completing VHDX setup on Hyper-V host..." -ForegroundColor Cyan

# Mount VHDX
`$vhd = Mount-VHD -Path `$VHDXPath -PassThru
`$disk = Initialize-Disk -Number `$vhd.DiskNumber -PartitionStyle GPT -PassThru

# Create partitions
`$efi = New-Partition -DiskNumber `$disk.Number -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -AssignDriveLetter
Format-Volume -DriveLetter `$efi.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "EFI" -Confirm:`$false | Out-Null

New-Partition -DiskNumber `$disk.Number -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' | Out-Null

`$win = New-Partition -DiskNumber `$disk.Number -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -AssignDriveLetter
Format-Volume -DriveLetter `$win.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:`$false | Out-Null

# Mount ISO
`$iso = Mount-DiskImage -ImagePath `$ISOPath -PassThru
`$isoDrive = (`$iso | Get-Volume).DriveLetter

# Apply image
dism /Apply-Image /ImageFile:"`${isoDrive}:\sources\install.wim" /Index:1 /ApplyDir:"`$(`$win.DriveLetter):\"

# Configure boot
bcdboot "`$(`$win.DriveLetter):\Windows" /s "`$(`$efi.DriveLetter):" /f UEFI

# Cleanup
Dismount-DiskImage -ImagePath `$ISOPath
Dismount-VHD -Path `$VHDXPath

Write-Host "VHDX is ready for use!" -ForegroundColor Green
"@

$helperPath = Join-Path $OutputPath "Complete-VHDX-Setup.ps1"
$helperScript | Out-File $helperPath -Encoding UTF8
Write-Host "Helper script created: $helperPath" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "VHDX shell created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green