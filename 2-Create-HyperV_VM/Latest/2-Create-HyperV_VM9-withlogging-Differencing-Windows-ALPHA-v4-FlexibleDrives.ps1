#requires -Version 5.1
#requires -Module Hyper-V
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced Hyper-V VM creation script with differencing disk support, comprehensive logging, and flexible drive handling.

.DESCRIPTION
    This script creates Hyper-V virtual machines with advanced configuration options including
    differencing disks, TPM support, and dynamic memory management. Features intelligent drive
    selection based on available space and allows user to confirm or change drive locations.

.PARAMETER EnvironmentMode
    Specifies the environment mode (dev/prod). Affects logging verbosity and behavior.

.PARAMETER EnhancedHyperVModulePath
    Path to the EnhancedHyperVAO module to import. Defaults to script root modules folder.

.PARAMETER LogPath
    Directory path for log files.

.PARAMETER SevenZipPath
    Full path to 7-Zip executable for ISO extraction.

.PARAMETER JobName
    Name identifier for the job used in logging.

.PARAMETER ConfigurationPath
    Directory path containing VM configuration files.

.PARAMETER DefaultVHDSize
    Default size for new VHD files when not using differencing disks.

.PARAMETER MinimumFreeSpaceGB
    Minimum free space required on drive for VM operations (in GB).

.PARAMETER AutoSelectDrive
    If true, automatically selects the drive with most free space without prompting.

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v4-FlexibleDrives.ps1

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v4-FlexibleDrives.ps1 -AutoSelectDrive

.NOTES
    Version: 4.0.0
    Author: Enhanced for organizational reusability
    Requires: Windows 10/11 or Windows Server 2016+, Hyper-V feature enabled
#>

[CmdletBinding()]
param(
    # Environment Configuration
    [Parameter(HelpMessage = "Environment mode for script execution")]
    [ValidateSet('dev', 'prod')]
    [string]$EnvironmentMode = 'prod',
    
    # Path Configuration
    [Parameter(HelpMessage = "Path to the EnhancedHyperVAO module")]
    [string]$EnhancedHyperVModulePath = "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1",
    
    [Parameter(HelpMessage = "Directory for log files")]
    [string]$LogPath = 'C:\Logs\HyperV',
    
    [Parameter(HelpMessage = "Path to 7-Zip executable")]
    [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe",
    
    # Job Configuration
    [Parameter(HelpMessage = "Job name for logging identification")]
    [string]$JobName = "HyperV-VMCreation",
    
    # VM Configuration
    [Parameter(HelpMessage = "Path to VM configuration files")]
    [string]$ConfigurationPath = $PSScriptRoot,
    
    [Parameter(HelpMessage = "Default VHD size for new VMs")]
    [uint64]$DefaultVHDSize = 100GB,
    
    # Drive Selection Configuration
    [Parameter(HelpMessage = "Minimum free space required on drive in GB")]
    [int]$MinimumFreeSpaceGB = 50,
    
    [Parameter(HelpMessage = "Automatically select drive with most free space")]
    [switch]$AutoSelectDrive
)

#region Custom Logging Function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [ConsoleColor]$ForegroundColor = 'White'
    )
    
    # Get calling function information
    $CallStack = Get-PSCallStack
    $CallerFunction = if ($CallStack.Count -gt 1) { $CallStack[1].FunctionName } else { '<Script>' }
    $CallerLine = if ($CallStack.Count -gt 1) { $CallStack[1].ScriptLineNumber } else { 0 }
    
    # Format timestamp
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Create log entry
    $LogEntry = "$Timestamp [$Level] [${CallerFunction}:${CallerLine}] $Message"
    
    # Console output with color based on level
    $Color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARNING' { 'Yellow' }
        'DEBUG' { 'Cyan' }
        'INFO' { $ForegroundColor }
        default { 'White' }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
    
    # File output
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    
    $LogFileName = "$JobName-$(Get-Date -Format 'yyyyMMdd').log"
    $LogFilePath = Join-Path $LogPath $LogFileName
    
    Add-Content -Path $LogFilePath -Value $LogEntry -Force
}

function Handle-Error {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    Write-Log -Message "ERROR: $($ErrorRecord.Exception.Message)" -Level 'ERROR'
    Write-Log -Message "Stack Trace: $($ErrorRecord.ScriptStackTrace)" -Level 'ERROR'
    Write-Log -Message "Error Details: $($ErrorRecord.ToString())" -Level 'ERROR'
}

function Log-Params {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Params
    )
    
    Write-Log -Message "Parameters:" -Level 'DEBUG'
    foreach ($key in $Params.Keys) {
        Write-Log -Message "  $key : $($Params[$key])" -Level 'DEBUG'
    }
}
#endregion Custom Logging Function

#region Drive Management Functions
function Get-AvailableDrives {
    <#
    .SYNOPSIS
        Gets all available drives with their free space information.
    
    .DESCRIPTION
        Retrieves information about all fixed drives on the system including
        drive letter, free space, total space, and usage percentage.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Scanning available drives..." -Level 'INFO'
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Used -ne $null -and $_.Free -ne $null
    } | ForEach-Object {
        [PSCustomObject]@{
            DriveLetter = $_.Name
            FreeSpaceGB = [Math]::Round($_.Free / 1GB, 2)
            TotalSpaceGB = [Math]::Round(($_.Used + $_.Free) / 1GB, 2)
            UsedSpaceGB = [Math]::Round($_.Used / 1GB, 2)
            PercentFree = [Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2)
        }
    } | Sort-Object FreeSpaceGB -Descending
    
    Write-Log -Message "Found $($drives.Count) drives" -Level 'DEBUG'
    return $drives
}

function Select-BestDrive {
    <#
    .SYNOPSIS
        Selects the best drive based on available space and minimum requirements.
    
    .PARAMETER MinimumFreeSpaceGB
        Minimum free space required in GB.
    
    .PARAMETER PreferredDrive
        Preferred drive letter if available and meets requirements.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$MinimumFreeSpaceGB,
        
        [Parameter()]
        [string]$PreferredDrive
    )
    
    $drives = Get-AvailableDrives
    
    # Check if preferred drive meets requirements
    if ($PreferredDrive) {
        $preferred = $drives | Where-Object { $_.DriveLetter -eq $PreferredDrive }
        if ($preferred -and $preferred.FreeSpaceGB -ge $MinimumFreeSpaceGB) {
            Write-Log -Message "Preferred drive $PreferredDrive meets requirements" -Level 'INFO'
            return $preferred
        }
    }
    
    # Get drives that meet minimum requirements
    $suitableDrives = $drives | Where-Object { $_.FreeSpaceGB -ge $MinimumFreeSpaceGB }
    
    if ($suitableDrives.Count -eq 0) {
        Write-Log -Message "No drives found with minimum $MinimumFreeSpaceGB GB free space" -Level 'ERROR'
        throw "Insufficient disk space on all drives"
    }
    
    # Return drive with most free space
    return $suitableDrives | Select-Object -First 1
}

function Show-DriveSelectionMenu {
    <#
    .SYNOPSIS
        Shows an interactive menu for drive selection.
    
    .PARAMETER SelectedDrive
        Currently selected drive information.
    
    .PARAMETER MinimumFreeSpaceGB
        Minimum free space required in GB.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SelectedDrive,
        
        [Parameter(Mandatory=$true)]
        [int]$MinimumFreeSpaceGB
    )
    
    Write-Host "`n=== Drive Selection ===" -ForegroundColor Cyan
    Write-Host "Recommended drive: $($SelectedDrive.DriveLetter): ($('{0:N2}' -f $SelectedDrive.FreeSpaceGB) GB free)" -ForegroundColor Green
    Write-Host "`nAll available drives:" -ForegroundColor Yellow
    
    $drives = Get-AvailableDrives
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $drive = $drives[$i]
        $meetsReq = if ($drive.FreeSpaceGB -ge $MinimumFreeSpaceGB) { "✓" } else { "✗" }
        $color = if ($drive.FreeSpaceGB -ge $MinimumFreeSpaceGB) { "White" } else { "DarkGray" }
        
        Write-Host ("  [{0}] {1}: - {2:N2} GB free of {3:N2} GB ({4:N1}% free) {5}" -f 
            ($i + 1), 
            $drive.DriveLetter, 
            $drive.FreeSpaceGB, 
            $drive.TotalSpaceGB, 
            $drive.PercentFree,
            $meetsReq
        ) -ForegroundColor $color
    }
    
    Write-Host "`n[A] Accept recommended drive ($($SelectedDrive.DriveLetter):)" -ForegroundColor Green
    Write-Host "[1-$($drives.Count)] Select a different drive" -ForegroundColor Yellow
    Write-Host "[Q] Quit" -ForegroundColor Red
    
    do {
        $choice = Read-Host "`nYour choice"
        
        if ($choice -match '^[Aa]$') {
            return $SelectedDrive
        }
        elseif ($choice -match '^[Qq]$') {
            Write-Log -Message "User cancelled drive selection" -Level 'WARNING'
            exit 0
        }
        elseif ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $drives.Count) {
                $selected = $drives[$index]
                if ($selected.FreeSpaceGB -lt $MinimumFreeSpaceGB) {
                    Write-Host "Warning: Selected drive has less than $MinimumFreeSpaceGB GB free space!" -ForegroundColor Red
                    $confirm = Read-Host "Continue anyway? (Y/N)"
                    if ($confirm -match '^[Yy]') {
                        return $selected
                    }
                }
                else {
                    return $selected
                }
            }
            else {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            }
        }
        else {
            Write-Host "Invalid input. Please try again." -ForegroundColor Red
        }
    } while ($true)
}

function Update-PathsForDrive {
    <#
    .SYNOPSIS
        Updates configuration paths to use the selected drive.
    
    .PARAMETER Config
        Configuration hashtable to update.
    
    .PARAMETER NewDrive
        Drive letter to use for paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory=$true)]
        [string]$NewDrive
    )
    
    Write-Log -Message "Updating paths to use drive $NewDrive" -Level 'INFO'
    
    # Helper function to update drive in path
    function Update-Drive {
        param([string]$Path, [string]$NewDrive)
        
        if ([string]::IsNullOrEmpty($Path)) {
            return $Path
        }
        
        # Check if path has a drive letter
        if ($Path -match '^[A-Za-z]:') {
            # Replace the drive letter
            return $Path -replace '^[A-Za-z]:', "$NewDrive`:"
        }
        else {
            # Path doesn't have a drive letter, prepend the new drive
            return "$NewDrive`:\$Path"
        }
    }
    
    # Update all path-related configuration values
    $pathKeys = @('VMPath', 'VHDXPath', 'ParentVHDPath', 'InstallMediaPath')
    
    foreach ($key in $pathKeys) {
        if ($Config.ContainsKey($key) -and $Config[$key]) {
            $oldPath = $Config[$key]
            $newPath = Update-Drive -Path $oldPath -NewDrive $NewDrive
            
            # Check if the new path's parent directory exists
            $parentDir = Split-Path -Path $newPath -Parent
            if ($parentDir -and -not (Test-Path $parentDir)) {
                Write-Log -Message "Creating directory: $parentDir" -Level 'INFO'
                try {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                }
                catch {
                    Write-Log -Message "Warning: Could not create directory $parentDir" -Level 'WARNING'
                }
            }
            
            $Config[$key] = $newPath
            Write-Log -Message "Updated $key`: $oldPath -> $newPath" -Level 'DEBUG'
        }
    }
    
    return $Config
}
#endregion Drive Management Functions

#region Module Import
# Import Enhanced Hyper-V module
try {
    Write-Log -Message "Importing Enhanced Hyper-V module from: $EnhancedHyperVModulePath" -Level 'INFO'
    Import-Module -Name $EnhancedHyperVModulePath -Force -ErrorAction Stop
    Write-Log -Message "Successfully imported Enhanced Hyper-V module" -Level 'INFO'
}
catch {
    Write-Log -Message "Failed to import Enhanced Hyper-V module: $_" -Level 'ERROR'
    throw
}
#endregion Module Import

# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', $EnvironmentMode, 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-Log -Message "Running in development mode" -Level 'WARNING'
    }
    'prod' {
        Write-Log -Message "Running in production mode" -Level 'INFO' -ForegroundColor Green
    }
    default {
        Write-Log -Message "Unknown mode. Defaulting to production." -Level 'WARNING'
    }
}

# Start transcript logging
$TranscriptPath = Join-Path $LogPath "Transcript-$JobName-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
try {
    Write-Log -Message "Starting transcript at: $TranscriptPath" -Level 'INFO'
    Start-Transcript -Path $TranscriptPath -Force
}
catch {
    Write-Log -Message "Failed to start transcript: $_" -Level 'WARNING'
}

try {
    #region Script Logic
    Write-Log -Message "Starting main script execution" -Level 'INFO'
    
    # Get the configuration
    $config = Get-VMConfiguration -ConfigPath $ConfigurationPath
    
    # Verify configuration was loaded
    if (-not $config) {
        Write-Log -Message "Failed to load configuration" -Level "ERROR"
        exit 1
    }
    
    # Drive selection process
    Write-Log -Message "Starting drive selection process" -Level 'INFO'
    
    # Try to get preferred drive from config VMPath
    $preferredDrive = $null
    if ($config.VMPath -and $config.VMPath -match '^([A-Za-z]):') {
        $preferredDrive = $matches[1]
        Write-Log -Message "Preferred drive from config: $preferredDrive" -Level 'DEBUG'
    }
    
    # Select best drive
    try {
        $selectedDrive = Select-BestDrive -MinimumFreeSpaceGB $MinimumFreeSpaceGB -PreferredDrive $preferredDrive
        
        # Show drive selection menu unless auto-select is enabled
        if (-not $AutoSelectDrive) {
            $selectedDrive = Show-DriveSelectionMenu -SelectedDrive $selectedDrive -MinimumFreeSpaceGB $MinimumFreeSpaceGB
        }
        
        Write-Log -Message "Selected drive: $($selectedDrive.DriveLetter) with $($selectedDrive.FreeSpaceGB) GB free" -Level 'INFO'
        
        # Update configuration paths with selected drive
        $config = Update-PathsForDrive -Config $config -NewDrive $selectedDrive.DriveLetter
    }
    catch {
        Write-Log -Message "Drive selection failed: $_" -Level 'ERROR'
        throw
    }
    
    # Extract OPNsense ISO if it's compressed using the new function
    if ($config.InstallMediaPath.EndsWith('.bz2')) {
        $expandParams = @{
            CompressedPath = $config.InstallMediaPath
            SevenZipPath   = $SevenZipPath
        }
        $extractedIsoPath = Expand-CompressedISO @expandParams
        $config.InstallMediaPath = $extractedIsoPath
    }
    
    # Create params hashtable for dismounting VHDX
    $DismountVHDXParams = @{
        VHDXPath = $config.VHDXPath
    }
    
    # Log the parameters we're about to use
    Log-Params -Params $DismountVHDXParams
    
    # Verify VHDXPath is not empty before attempting to dismount
    if ([string]::IsNullOrEmpty($DismountVHDXParams.VHDXPath)) {
        Write-Log -Message "VHDXPath is empty in configuration" -Level "ERROR"
        exit 1
    }
    
    # Check if VHDX file exists
    if (-not (Test-Path $DismountVHDXParams.VHDXPath)) {
        Write-Log -Message "VHDX file not found at: $($DismountVHDXParams.VHDXPath)" -Level "WARNING"
        Write-Log -Message "This may be expected for new VM creation without differencing disk" -Level "INFO"
    }
    else {
        # Attempt to dismount the VHDX
        Dismount-VHDX @DismountVHDXParams
    }
    
    # Get the next VM name prefix and set VM name
    $VMNamePrefix = Get-NextVMNamePrefix -config $config
    Write-Log -Message "The next VM name prefix should be: $VMNamePrefix" -Level "INFO"
    
    # Set the VM name based on extracted prefix
    $VMName = "$VMNamePrefix`_VM"
    
    # Create VM directory
    $VMFullPath = Join-Path $config.VMPath $VMName
    if (-not (Test-Path $VMFullPath)) {
        New-Item -Path $VMFullPath -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created VM directory at $VMFullPath" -Level "INFO"
    }
    
    # Get virtual switches with proper filtering
    $externalSwitchName = Get-AvailableVirtualSwitch -SwitchPurpose "WAN (External)"
    Write-Log -Message "Using external virtual switch for WAN: $externalSwitchName" -Level "INFO"
    
    $internalSwitchName = Get-AvailableVirtualSwitch -SwitchPurpose "LAN (Internal)" -PreferredType "Private"
    Write-Log -Message "Using internal virtual switch for LAN: $internalSwitchName" -Level "INFO"
    
    # Call the enhanced Create-EnhancedVM function
    $createVMParams = @{
        VMName                  = $VMName
        VMFullPath              = $VMFullPath
        MemoryStartupBytes      = $config.MemoryStartupBytes
        MemoryMinimumBytes      = $config.MemoryMinimumBytes
        MemoryMaximumBytes      = $config.MemoryMaximumBytes
        ProcessorCount          = $config.ProcessorCount
        ExternalSwitchName      = $externalSwitchName
        InternalSwitchName      = $internalSwitchName
        ExternalMacAddress      = $config.ExternalMacAddress
        InternalMacAddress      = $config.InternalMacAddress
        InstallMediaPath        = $config.InstallMediaPath
        Generation              = $config.Generation
        VMType                  = $config.VMType
        EnableVirtualizationExtensions = $config.EnableVirtualizationExtensions
        EnableDynamicMemory     = $config.EnableDynamicMemory
        MemoryBuffer            = $config.MemoryBuffer
        MemoryWeight            = $config.MemoryWeight
        MemoryPriority          = $config.MemoryPriority
        IncludeTPM              = $config.IncludeTPM
        DefaultVHDSize          = $DefaultVHDSize
    }
    
    # Add differencing disk parameters if VMType is Differencing
    if ($config.VMType -eq 'Differencing') {
        Write-Log -Message "Creating VM with differencing disk..." -Level "INFO"
        $createVMParams.VHDXPath = $config.VHDXPath
    }
    else {
        Write-Log -Message "Creating VM with new VHD..." -Level "INFO"
    }
    
    Create-EnhancedVM @createVMParams
    
    Write-Log -Message "VM creation completed successfully" -Level "INFO"
    
    # Display summary
    Write-Host "`n=== VM Creation Summary ===" -ForegroundColor Green
    Write-Host "VM Name: $VMName" -ForegroundColor White
    Write-Host "Location: $VMFullPath" -ForegroundColor White
    Write-Host "Drive Used: $($selectedDrive.DriveLetter): ($('{0:N2}' -f $selectedDrive.FreeSpaceGB) GB free)" -ForegroundColor White
    Write-Host "===========================" -ForegroundColor Green
    
    #endregion Script Logic
}
catch {
    Write-Log -Message "An error occurred during script execution: $_" -Level 'ERROR'
    Handle-Error -ErrorRecord $_
    throw
}
finally {
    # Stop transcript
    try {
        Stop-Transcript
        Write-Log -Message "Transcript stopped" -Level 'INFO'
    }
    catch {
        Write-Log -Message "Failed to stop transcript: $_" -Level 'WARNING'
    }
}