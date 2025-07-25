#requires -Version 5.1

<#
################################################################################
# WARNING: KNOWN ISSUE ON WINDOWS SERVER 2025
# 
# This script hangs indefinitely on Windows Server 2025 and newer.
# For Server 2025, use Create-VHDX-Working.ps1 instead.
# See README-Server2025-Fix.md for details.
################################################################################

.SYNOPSIS
    Windows Image to Virtual Hard Disk Converter with module import and parameterized configuration.

.DESCRIPTION
    This script converts Windows ISO files to VHDX format with configurable parameters.
    It imports the Convert-ISO2VHDX module and provides a user-friendly interface
    for selecting Windows editions and creating virtual hard disks.

.PARAMETER ISOPath
    Path to the Windows ISO file to convert.

.PARAMETER OutputDirectory
    Directory where the VHDX file will be created.

.PARAMETER VHDFormat
    Format of the virtual hard disk (VHD or VHDX).

.PARAMETER IsFixed
    Whether to create a fixed size disk (true) or dynamic disk (false).

.PARAMETER SizeBytes
    Size of the virtual hard disk in bytes.

.PARAMETER DiskLayout
    Disk layout type (UEFI or BIOS).

.PARAMETER RemoteDesktopEnable
    Whether to enable Remote Desktop in the created image.

.EXAMPLE
    .\0-convert-ISO2VHDX-Main.ps1 -ISOPath "C:\ISO\Windows.iso" -SizeBytes 120GB

.NOTES
    Requires PowerShell 5.1 and the Convert-ISO2VHDX module.
    Must be run as Administrator.
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the Windows ISO file")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "ISO file does not exist: $_"
        }
        if ($_ -notmatch '\.(iso|ISO)$') {
            throw "File must have .iso extension: $_"
        }
        $true
    })]
    [string]$ISOPath = "D:\VM\Setup\ISO\Windows_10_22H2_July_29_2023.iso",

    [Parameter(Mandatory = $false, HelpMessage = "Directory where VHDX files will be created")]
    [string]$OutputDirectory = "D:\VM\Setup\VHDX\test",

    [Parameter(Mandatory = $false, HelpMessage = "Virtual hard disk format")]
    [ValidateSet("VHD", "VHDX")]
    [string]$VHDFormat = "VHDX",

    [Parameter(Mandatory = $false, HelpMessage = "Create fixed size disk (true) or dynamic disk (false)")]
    [bool]$IsFixed = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Size of the virtual hard disk")]
    [ValidateRange(10GB, 2TB)]
    [int64]$SizeBytes = 100GB,

    [Parameter(Mandatory = $false, HelpMessage = "Disk layout type")]
    [ValidateSet("UEFI", "BIOS")]
    [string]$DiskLayout = "UEFI",

    [Parameter(Mandatory = $false, HelpMessage = "Enable Remote Desktop in the created image")]
    [bool]$RemoteDesktopEnable = $false
)

#region Module Import
try {
    $ModulePath = Join-Path $PSScriptRoot "modules\Convert-ISO2VHDX.psm1"
    if (-not (Test-Path $ModulePath)) {
        throw "Module not found at: $ModulePath"
    }
    Import-Module $ModulePath -Force
    Write-Host "Successfully imported Convert-ISO2VHDX module" -ForegroundColor Green
} catch {
    Write-Error "Failed to import Convert-ISO2VHDX module: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Edition Information Comments
# Index: 1    Edition: Windows 11 Home
# Index: 2    Edition: Windows 11 Home N
# Index: 3    Edition: Windows 11 Home Single Language
# Index: 4    Edition: Windows 11 Education
# Index: 5    Edition: Windows 11 Education N
# Index: 6    Edition: Windows 11 Pro
# Index: 7    Edition: Windows 11 Pro N
# Index: 8    Edition: Windows 11 Pro Education
# Index: 9    Edition: Windows 11 Pro Education N
# Index: 10   Edition: Windows 11 Pro for Workstations
# Index: 11   Edition: Windows 11 Pro N for Workstations
#endregion

#region Function Definitions
function Get-WindowsEditionChoice {
    <#
    .SYNOPSIS
        Displays available Windows editions in an ISO and prompts user for selection.
    
    .DESCRIPTION
        Mounts the specified ISO file, reads the Windows image information,
        displays available editions to the user, and returns the selected edition details.
    
    .PARAMETER ISOPath
        Path to the Windows ISO file.
    
    .OUTPUTS
        Hashtable containing Index and Name of the selected edition.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ISOPath
    )

    try {
        # Mount the ISO if it exists
        Write-Host "Mounting ISO: $ISOPath" -ForegroundColor Cyan
        $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter

        # Get the path to install.wim or install.esd
        $wimPath = "$($driveLetter):\sources\install.wim"
        $esdPath = "$($driveLetter):\sources\install.esd"
        $installPath = if (Test-Path $wimPath) { $wimPath } else { $esdPath }

        if (-not (Test-Path $installPath)) {
            throw "Neither install.wim nor install.esd found in the ISO"
        }

        # Get Windows image information
        Write-Host "Reading Windows image information..." -ForegroundColor Cyan
        $editions = Get-WindowsImage -ImagePath $installPath | Select-Object ImageIndex, ImageName

        # Display menu
        Write-Host "`nAvailable Windows Editions in ISO:" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        
        foreach ($edition in $editions) {
            Write-Host ("[{0}] {1}" -f $edition.ImageIndex, $edition.ImageName)
        }
        
        Write-Host "`nPlease select an edition by entering its number or full name:" -ForegroundColor Yellow
        $choice = Read-Host

        # Check if input is a number
        if ($choice -match '^\d+$') {
            $selectedEdition = $editions | Where-Object { $_.ImageIndex -eq [int]$choice }
        } else {
            $selectedEdition = $editions | Where-Object { $_.ImageName -eq $choice }
        }

        if ($null -eq $selectedEdition) {
            throw "Invalid selection. Please run the script again and select a valid edition."
        }

        Write-Host "Selected: [$($selectedEdition.ImageIndex)] $($selectedEdition.ImageName)" -ForegroundColor Green

        return @{
            Index = $selectedEdition.ImageIndex
            Name = $selectedEdition.ImageName
        }
    }
    catch {
        throw $_
    }
    finally {
        # Always dismount the ISO
        if ($mountResult) {
            Write-Host "Dismounting ISO..." -ForegroundColor Cyan
            Dismount-DiskImage -ImagePath $ISOPath | Out-Null
        }
    }
}

function Get-DynamicVHDPath {
    <#
    .SYNOPSIS
        Generates a dynamic VHDX filename based on ISO and configuration parameters.
    
    .DESCRIPTION
        Creates a descriptive filename for the VHDX file based on the source ISO,
        Windows edition, disk size, type, and layout configuration.
    
    .OUTPUTS
        String containing the full path to the VHDX file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ISOPath,
        
        [Parameter(Mandatory = $true)]
        [string]$EditionName,
        
        [Parameter(Mandatory = $true)]
        [int64]$SizeBytes,
        
        [Parameter(Mandatory = $true)]
        [string]$VHDFormat,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsFixed,
        
        [Parameter(Mandatory = $true)]
        [string]$DiskLayout,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    # Get ISO file name without extension
    $isoName = [System.IO.Path]::GetFileNameWithoutExtension($ISOPath)
    
    # Clean up edition name for filename - handle all Windows editions
    $editionShort = $EditionName -replace 'Windows Server \d{4}|Windows \d{1,2}|Windows|Server|Evaluation|Desktop Experience|Standard|Datacenter|Core|Enterprise|Education|Home|Pro|Single Language|\(|\)', '' -replace '\s+', '-' -replace '^-|-$', ''
    
    # Format size (convert to GB for filename)
    $sizeGB = $SizeBytes / 1GB
    $sizeString = "{0}GB" -f $sizeGB
    
    # Get disk type
    $diskType = if ($IsFixed) { "Fixed" } else { "Dynamic" }
    
    # Create timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd"
    
    # Construct filename
    $fileName = @(
        $isoName,
        $editionShort,
        $sizeString,
        $diskType,
        $DiskLayout,
        $timestamp
    ) -join '_'

    # Add extension based on VHDFormat
    $fileName = "$fileName.$($VHDFormat.ToLower())"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        Write-Host "Creating output directory: $OutputDirectory" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    # Return full path
    return Join-Path $OutputDirectory $fileName
}

function Show-PostCreationGuidance {
    <#
    .SYNOPSIS
        Displays guidance for using the created VHDX file.
    
    .DESCRIPTION
        Shows comprehensive information about how to use the created VHDX,
        including options for direct usage and differencing disks.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDPath
    )
    
    Write-Host "`n=== VHDX Creation Complete ===" -ForegroundColor Green
    Write-Host "Your VHDX has been created at: $VHDPath" -ForegroundColor Green
    
    Write-Host "`nRecommended Next Steps:" -ForegroundColor Cyan
    Write-Host "This VHDX can be used in two ways:" -ForegroundColor Cyan
    
    # Direct Usage Section
    Write-Host "`n1. Direct Usage (Traditional Approach):" -ForegroundColor Yellow
    Write-Host "   You can use this VHDX directly to create a new VM."
    Write-Host "   Steps for direct usage:"
    Write-Host "   1. Copy the VHDX to your desired location (optional)"
    Write-Host "   2. In Hyper-V Manager, create a new VM"
    Write-Host "   3. Choose 'Use an existing virtual hard disk'"
    Write-Host "   4. Browse to and select this VHDX"
    Write-Host "   5. Complete the VM creation wizard"
    Write-Host "   Pros:"
    Write-Host "   [+] Simpler setup process"
    Write-Host "   [+] Each VM is completely independent"
    Write-Host "   [+] No parent disk dependencies"
    Write-Host "   [+] Can freely modify the VHDX"
    Write-Host "   [+] Recommended for production workloads"
    Write-Host "   Cons:"
    Write-Host "   [-] Takes more disk space"
    Write-Host "   [-] Longer VM creation time"
    Write-Host "   [-] Updates and patches need to be applied to each VM separately"
    
    # Differencing Disk Section
    Write-Host "`n2. Parent Disk for Differencing VHDXs (Recommended for dev/test environments):" -ForegroundColor Yellow
    Write-Host "   Use this VHDX as a parent disk to create multiple child VMs."
    Write-Host "   Steps for differencing disk setup:"
    Write-Host "   1. Make the VHDX read-only (important!)"
    Write-Host "   2. In Hyper-V Manager, create a new VM"
    Write-Host "   3. Choose 'Create a virtual hard disk'"
    Write-Host "   4. Select 'Differencing' as the disk type"
    Write-Host "   5. Select this VHDX as the parent disk"
    Write-Host "   6. Choose location for the child disk"
    Write-Host "   Pros:"
    Write-Host "   [+] Significantly reduced disk space usage"
    Write-Host "   [+] Much faster VM creation"
    Write-Host "   [+] Perfect for dev/test environments"
    Write-Host "   [+] Can create multiple VMs from a single parent"
    Write-Host "   [+] Ideal for temporary or disposable VMs"
    Write-Host "   Cons:"
    Write-Host "   [-] Parent disk must remain available"
    Write-Host "   [-] More complex setup process"
    Write-Host "   [-] Not recommended for production workloads due to:"
    Write-Host "       - Performance impact from disk chain"
    Write-Host "       - Risk of parent disk corruption affecting all children"
    Write-Host "       - Backup complexity"
    Write-Host "       - Storage migration challenges"

    Write-Host "`nPatching Strategy:" -ForegroundColor Magenta
    Write-Host "1. For Direct Usage VMs:"
    Write-Host "   * Patch each VM independently"
    Write-Host "   * Use standard Windows Update or WSUS"
    Write-Host "   * Create checkpoints before patching if needed"
    
    Write-Host "`n2. For Differencing Disk VMs:"
    Write-Host "   * DO NOT patch the parent VHDX once child VMs are created"
    Write-Host "   * Instead, patch each child VM independently"
    Write-Host "   * If you need a new base image with patches:"
    Write-Host "     1. Create a new parent VHDX with latest updates"
    Write-Host "     2. Create new child VMs from the new parent"
    Write-Host "     3. Keep the old parent for existing child VMs"

    Write-Host "`nBest Practices:" -ForegroundColor Magenta
    Write-Host "* For production workloads: Use direct VHDXs"
    Write-Host "* For dev/test environments: Differencing disks are ideal"
    Write-Host "* Keep parent VHDXs in a dedicated folder"
    Write-Host "* Version your parent VHDXs (e.g., append patch level or date)"
    Write-Host "* Document which child VMs are using which parent VHDX"
    Write-Host "* Consider creating checkpoints of child VMs before updates"
    Write-Host "* Regularly check disk chain health for differencing disks"

    Write-Host "`nPowerShell Commands for Making VHDX Read-Only:" -ForegroundColor Cyan
    Write-Host "Set-ItemProperty -Path '$VHDPath' -Name IsReadOnly -Value `$true"
}
#endregion

#region Main Script Logic
try {
    # Validate ISO path
    if (-not (Test-Path $ISOPath)) {
        throw "ISO file not found: $ISOPath"
    }

    Write-Host "Starting Windows Image to VHDX conversion process..." -ForegroundColor Green
    Write-Host "ISO Path: $ISOPath" -ForegroundColor Cyan
    Write-Host "Output Directory: $OutputDirectory" -ForegroundColor Cyan
    Write-Host "VHD Format: $VHDFormat" -ForegroundColor Cyan
    Write-Host "Disk Type: $(if ($IsFixed) { 'Fixed' } else { 'Dynamic' })" -ForegroundColor Cyan
    Write-Host "Size: $([math]::Round($SizeBytes / 1GB, 2)) GB" -ForegroundColor Cyan
    Write-Host "Disk Layout: $DiskLayout" -ForegroundColor Cyan

    # Get the Windows edition choice from user
    $selectedEdition = Get-WindowsEditionChoice -ISOPath $ISOPath

    # Get dynamic VHD path using splatting
    $dynamicVHDParams = @{
        ISOPath         = $ISOPath
        EditionName     = $selectedEdition.Name
        SizeBytes       = $SizeBytes
        VHDFormat       = $VHDFormat
        IsFixed         = $IsFixed
        DiskLayout      = $DiskLayout
        OutputDirectory = $OutputDirectory
    }

    $vhdPath = Get-DynamicVHDPath @dynamicVHDParams

    # Define and execute the conversion parameters
    $params = @{
        SourcePath          = $ISOPath
        VHDPath             = $vhdPath
        DiskLayout          = $DiskLayout
        RemoteDesktopEnable = $RemoteDesktopEnable
        VHDFormat           = $VHDFormat
        IsFixed             = $IsFixed
        SizeBytes           = $SizeBytes
        Edition             = $selectedEdition.Index
    }

    Write-Host "`nCreating virtual disk at: $vhdPath" -ForegroundColor Green
    Convert-WindowsImage @params

    # Show guidance after successful creation
    Show-PostCreationGuidance -VHDPath $vhdPath

} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
#endregion