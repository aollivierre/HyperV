#requires -Version 5.1
#requires -Module Hyper-V
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced Hyper-V VM creation script with differencing disk support and comprehensive logging.

.DESCRIPTION
    This script creates Hyper-V virtual machines with advanced configuration options including
    differencing disks, TPM support, and dynamic memory management. All previously hardcoded
    values have been moved to parameters for maximum flexibility across organizations.

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

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1 -EnvironmentMode 'dev' -JobName 'DevVM-Creation'

.NOTES
    Version: 3.2.0
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
    [uint64]$DefaultVHDSize = 100GB
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
    
    # Attempt to dismount the VHDX
    Dismount-VHDX @DismountVHDXParams
    
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