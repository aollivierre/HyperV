#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Module Hyper-V

<#
.SYNOPSIS
    Creates a parent VHDX disk for use as a base for differencing data disks.

.DESCRIPTION
    This script creates a dynamic VHDX disk that serves as a parent disk for 
    differencing data disks. The disk is formatted with NTFS and is ready to 
    be used as a parent for child differencing disks.

.PARAMETER Path
    The path where the parent VHDX file will be created.

.PARAMETER Size
    The size of the disk. Default is 256GB.

.PARAMETER DiskLabel
    The volume label for the formatted disk. Default is "DATA".

.EXAMPLE
    .\Create-DataDiskParent.ps1 -Path "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"

.EXAMPLE
    .\Create-DataDiskParent.ps1 -Path "E:\VHDs\DataParent.vhdx" -Size 512GB -DiskLabel "STORAGE"

.NOTES
    Author: Enhanced Hyper-V Management
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path for the parent VHDX file")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(HelpMessage = "Size of the disk")]
    [ValidateRange(10GB, 64TB)]
    [uint64]$Size = 256GB,

    [Parameter(HelpMessage = "Volume label for the formatted disk")]
    [ValidateLength(1, 32)]
    [string]$DiskLabel = "DATA"
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

try {
    # Validate path directory exists
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $directory)) {
        throw "Directory does not exist: $directory"
    }

    # Check if file already exists
    if (Test-Path -Path $Path) {
        Write-ColorOutput -Message "VHDX file already exists at: $Path" -Level "WARNING"
        $response = Read-Host "Do you want to overwrite it? (Y/N)"
        if ($response -ne 'Y') {
            Write-ColorOutput -Message "Operation cancelled by user" -Level "INFO"
            return
        }
        Remove-Item -Path $Path -Force
    }

    Write-ColorOutput -Message "Creating parent VHDX disk..." -Level "INFO"
    Write-ColorOutput -Message "Path: $Path" -Level "INFO"
    Write-ColorOutput -Message "Size: $([math]::Round($Size/1GB, 2)) GB" -Level "INFO"
    Write-ColorOutput -Message "Type: Dynamic" -Level "INFO"

    # Create the VHDX
    $vhd = New-VHD -Path $Path -SizeBytes $Size -Dynamic -BlockSizeBytes 32MB
    
    if (-not $vhd) {
        throw "Failed to create VHDX"
    }

    Write-ColorOutput -Message "VHDX created successfully" -Level "SUCCESS"
    
    # Mount the VHDX
    Write-ColorOutput -Message "Mounting VHDX..." -Level "INFO"
    $mounted = Mount-VHD -Path $Path -Passthru
    
    # Initialize the disk
    Write-ColorOutput -Message "Initializing disk..." -Level "INFO"
    $disk = $mounted | Initialize-Disk -PartitionStyle GPT -PassThru
    
    # Create partition
    Write-ColorOutput -Message "Creating partition..." -Level "INFO"
    $partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
    
    # Format the volume
    Write-ColorOutput -Message "Formatting volume with NTFS..." -Level "INFO"
    $volume = $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel $DiskLabel -Confirm:$false
    
    # Get the assigned drive letter
    $driveLetter = $partition.DriveLetter
    Write-ColorOutput -Message "Volume formatted successfully. Temporarily mounted as $driveLetter`:" -Level "SUCCESS"
    
    # Create a marker file to identify this as a data disk parent
    $markerPath = "${driveLetter}:\__DATA_DISK_PARENT__.txt"
    $markerContent = @"
This is a parent disk for Hyper-V data disks.
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Size: $([math]::Round($Size/1GB, 2)) GB
Label: $DiskLabel

DO NOT DELETE THIS FILE
DO NOT MODIFY THIS DISK DIRECTLY
Use this disk only as a parent for differencing disks
"@
    Set-Content -Path $markerPath -Value $markerContent
    
    Write-ColorOutput -Message "Created marker file on disk" -Level "INFO"
    
    # Dismount the VHDX
    Write-ColorOutput -Message "Dismounting VHDX..." -Level "INFO"
    Dismount-VHD -Path $Path
    
    Write-ColorOutput -Message "Parent data disk created successfully!" -Level "SUCCESS"
    Write-ColorOutput -Message "Location: $Path" -Level "INFO"
    Write-ColorOutput -Message "This disk is now ready to be used as a parent for differencing data disks" -Level "INFO"
    
    # Display summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Parent VHDX: $Path" -ForegroundColor White
    Write-Host "Size: $([math]::Round($Size/1GB, 2)) GB (Dynamic)" -ForegroundColor White
    Write-Host "File System: NTFS" -ForegroundColor White
    Write-Host "Volume Label: $DiskLabel" -ForegroundColor White
    Write-Host "Status: Ready for use as parent disk" -ForegroundColor Green
}
catch {
    Write-ColorOutput -Message "Error: $_" -Level "ERROR"
    
    # Cleanup on error
    if ($mounted) {
        try {
            Dismount-VHD -Path $Path -ErrorAction SilentlyContinue
        }
        catch {
            Write-ColorOutput -Message "Failed to dismount VHD during cleanup" -Level "WARNING"
        }
    }
    
    if ((Test-Path -Path $Path) -and -not $vhd) {
        try {
            Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
            Write-ColorOutput -Message "Cleaned up incomplete VHDX file" -Level "INFO"
        }
        catch {
            Write-ColorOutput -Message "Failed to remove incomplete VHDX file" -Level "WARNING"
        }
    }
    
    throw
}