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

.PARAMETER ModulePath
    Path to the EnhancedHyperVAO module to import.

.PARAMETER PSFLogPath
    Directory path for PSFramework CSV logging.

.PARAMETER TranscriptLogPath
    Directory path for PowerShell transcript logging.

.PARAMETER SevenZipPath
    Full path to 7-Zip executable for ISO extraction.

.PARAMETER JobName
    Name identifier for the job used in logging.

.PARAMETER ConfigurationPath
    Directory path containing VM configuration files.

.PARAMETER DefaultVHDSize
    Default size for new VHD files when not using differencing disks.

.PARAMETER ModuleStarterParams
    Hashtable of parameters for Invoke-ModuleStarter.

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored.ps1

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored.ps1 -EnvironmentMode 'dev' -JobName 'DevVM-Creation'

.NOTES
    Version: 3.1.0
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
    [string]$ModulePath = "C:\code\Modulesv3\EnhancedHyperVAO\EnhancedHyperVAO.psd1",
    
    [Parameter(HelpMessage = "Directory for PSFramework log files")]
    [string]$PSFLogPath = 'C:\Logs\PSF',
    
    [Parameter(HelpMessage = "Directory for transcript log files")]
    [string]$TranscriptLogPath = "C:\Logs\Transcript",
    
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
    
    # Module Configuration
    [Parameter(HelpMessage = "Parameters for module starter")]
    [hashtable]$ModuleStarterParams = @{
        Mode                   = 'dev'
        SkipPSGalleryModules   = $true
        SkipCheckandElevate    = $true
        SkipPowerShell7Install = $true
        SkipEnhancedModules    = $true
        SkipGitRepos           = $false
    }
)

# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', $EnvironmentMode, 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-EnhancedLog -Message "Running in development mode" -Level 'WARNING'
    }
    'prod' {
        Write-EnhancedLog -Message "Running in production mode" -ForegroundColor Green
    }
    default {
        Write-EnhancedLog -Message "Unknown mode. Defaulting to production." -ForegroundColor Red
    }
}

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

# Call the function using the provided parameters
Invoke-ModuleStarter @ModuleStarterParams

# Import the specified module
Import-Module -Name $ModulePath -Force

#endregion FIRING UP MODULE STARTER

#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$parentScriptName = Get-ParentScriptName
Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
$paramGetPSFCSVLogFilePath = @{
    LogsPath         = $PSFLogPath
    JobName          = $JobName
    parentScriptName = $parentScriptName
}

$csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

$instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configure the PSFramework logging provider to use CSV format
$paramSetPSFLoggingProvider = @{
    Name            = 'logfile'
    InstanceName    = $instanceName  # Use a unique instance name
    FilePath        = $csvLogFilePath  # Use the dynamically generated file path
    Enabled         = $true
    FileType        = 'CSV'
    EnableException = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
#endregion HANDLE PSF MODERN LOGGING

#region HANDLE Transcript LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE Transcript LOGGING                                           #
#                                                                                               #
#################################################################################################
# Start the script with error handling
try {
    # Generate the transcript file path
    $GetTranscriptFilePathParams = @{
        TranscriptsPath  = $TranscriptLogPath
        JobName          = $JobName
        parentScriptName = $parentScriptName
    }
    $transcriptPath = Get-TranscriptFilePath @GetTranscriptFilePathParams
    
    # Start the transcript
    Write-EnhancedLog -Message "Starting transcript at: $transcriptPath"
    Start-Transcript -Path $transcriptPath
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging
    Wait-PSFMessage
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
}
#endregion HANDLE Transcript LOGGING

try {
    #region Script Logic
    #################################################################################################
    #                                                                                               #
    #                                    Script Logic                                               #
    #                                                                                               #
    #################################################################################################

    # Get the configuration
    $config = Get-VMConfiguration -ConfigPath $ConfigurationPath

    # Verify configuration was loaded
    if (-not $config) {
        Write-EnhancedLog -Message "Failed to load configuration" -Level "ERROR"
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
        Write-EnhancedLog -Message "VHDXPath is empty in configuration" -Level "ERROR"
        exit 1
    }

    # Attempt to dismount the VHDX
    Dismount-VHDX @DismountVHDXParams

    # Get the next VM name prefix and set VM name
    $VMNamePrefix = Get-NextVMNamePrefix -config $config
    Write-EnhancedLog -Message "The next VM name prefix should be: $VMNamePrefix" -Level "INFO"

    # Initialize paths
    $VMName = $VMNamePrefix
    $VMPath = $config.VMPath
    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    $vmDestinationPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"

    # Create VM directory
    if (-not (Test-Path -Path $VMFullPath)) {
        New-Item -ItemType Directory -Path $VMFullPath -Force | Out-Null
        Write-EnhancedLog -Message "Created VM directory at $VMFullPath" -Level "INFO"
    }

    # Initialize HyperV services
    Write-EnhancedLog -Message "Starting main script execution" -Level "INFO"
    Initialize-HyperVServices

    # Ensure guardian exists
    EnsureUntrustedGuardianExists

    # Get user's choice for VM creation type
    $choice = Show-VMCreationMenu
    $UsesDifferencing = $choice -eq '2'
    $VMCreated = $false

    # Get virtual switches dynamically using the modularized function
    $externalSwitchName = Get-AvailableVirtualSwitch -SwitchPurpose "WAN (External)"
    Write-EnhancedLog -Message "Using external virtual switch for WAN: $externalSwitchName" -Level "INFO"
    
    # For OPNsense, we need a second switch for LAN
    $internalSwitchName = Get-AvailableVirtualSwitch -SwitchPurpose "LAN (Internal)" -PreferredType "Private"
    Write-EnhancedLog -Message "Using internal virtual switch for LAN: $internalSwitchName" -Level "INFO"

    # Define common VM parameters from configuration
    $vmParams = @{
        VMName             = $VMName
        VMFullPath         = $VMFullPath
        SwitchName         = $externalSwitchName  # Use WAN switch
        MemoryStartupBytes = [int64](Invoke-Expression $config.MemoryStartupBytes.Replace('GB', '*1GB'))
        MemoryMinimumBytes = [int64](Invoke-Expression $config.MemoryMinimumBytes.Replace('GB', '*1GB'))
        MemoryMaximumBytes = [int64](Invoke-Expression $config.MemoryMaximumBytes.Replace('GB', '*1GB'))
        Generation         = $config.Generation
    }

    if ($UsesDifferencing) {
        # For differencing disk, use the template as parent and set the differencing disk path
        $vmParams['ParentVHDPath'] = $config.VHDXPath
        $vmParams['VHDPath'] = $vmDestinationPath
        $vmParams['UseDifferencing'] = $true
    }
    else {
        # For new disk, create fresh at destination
        $vmParams['NewVHDSizeBytes'] = $DefaultVHDSize
        $vmParams['VHDPath'] = $vmDestinationPath
    }

    # Create the VM based on type
    try {
        if ($UsesDifferencing) {
            Write-EnhancedLog -Message "Creating VM with differencing disk..." -Level "INFO"
            Log-Params -Params $vmParams
            $VMCreated = New-CustomVMWithDifferencingDisk @vmParams
        }
        else {
            # For new VMs without differencing disk, we need a different approach
            Write-EnhancedLog -Message "Creating VM with new VHD..." -Level "INFO"
            
            # Create VM without VHD first
            $newVMParams = @{
                Generation         = $vmParams.Generation
                Path               = $vmParams.VMFullPath
                Name               = $vmParams.VMName
                MemoryStartupBytes = $vmParams.MemoryStartupBytes
                SwitchName         = $vmParams.SwitchName
                NoVHD              = $true
            }
            
            Write-EnhancedLog -Message "Creating VM with parameters..." -Level "INFO"
            Log-Params -Params $newVMParams
            $vm = New-VM @newVMParams
            
            # Configure memory
            Write-EnhancedLog -Message "Configuring VM memory..." -Level "INFO"
            Set-VMMemory -VMName $vmParams.VMName -DynamicMemoryEnabled $true -MinimumBytes $vmParams.MemoryMinimumBytes -MaximumBytes $vmParams.MemoryMaximumBytes -StartupBytes $vmParams.MemoryStartupBytes
            
            # Create new VHD
            Write-EnhancedLog -Message "Creating new VHD at: $($vmParams.VHDPath)" -Level "INFO"
            $newVHD = New-VHD -Path $vmParams.VHDPath -SizeBytes $vmParams.NewVHDSizeBytes -Dynamic
            
            # Attach VHD to VM
            Write-EnhancedLog -Message "Attaching VHD to VM..." -Level "INFO"
            Add-VMHardDiskDrive -VMName $vmParams.VMName -Path $vmParams.VHDPath
            
            $VMCreated = $true
        }
    }
    catch {
        Write-EnhancedLog -Message "Failed to create VM: $_" -Level "ERROR"
        Write-EnhancedLog -Message "Full error details: $($_.Exception.Message)" -Level "ERROR"
        $VMCreated = $false
    }

    # Verify VM creation
    $getVMParams = @{
        Name        = $vmParams.VMName
        ErrorAction = 'SilentlyContinue'
    }

    if (-not (Get-VM @getVMParams)) {
        Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR"
        exit 1
    }

    # Configure VM if creation was successful
    if ($VMCreated) {
        if (-not $UsesDifferencing) {
            # For new VMs, add DVD drive and configure boot
            Add-DVDDriveToVM -VMName $vmParams.VMName -InstallMediaPath $config.InstallMediaPath
            # Simple call without differencing disk path for new VMs with ISO
            ConfigureVMBoot -VMName $vmParams.VMName
        }
        else {
            # Call with differencing disk path when using differencing disk
            ConfigureVMBoot -VMName $vmParams.VMName -DifferencingDiskPath $vmParams.VHDPath
        }

        # Configure VM settings (processors, memory)
        Write-EnhancedLog -Message "Configuring VM settings..." -Level "INFO"
        ConfigureVM -VMName $vmParams.VMName -ProcessorCount $config.ProcessorCount
            
        # Check if Secure Boot should be disabled based on config
        if ($config.ContainsKey('SecureBoot') -and $config.SecureBoot -eq $false) {
            Write-EnhancedLog -Message "Disabling Secure Boot as specified in config..." -Level "INFO"
            try {
                Set-VMFirmware -VMName $vmParams.VMName -EnableSecureBoot Off
                Write-EnhancedLog -Message "Secure Boot disabled successfully" -Level "INFO"
            } catch {
                Write-EnhancedLog -Message "Error disabling Secure Boot: $_" -Level "ERROR"
                # Continue with the script as this is not a critical error
            }
        } else {
            Write-EnhancedLog -Message "Secure Boot setting not specified or set to enabled in config, keeping default" -Level "INFO"
        }

        # Enable TPM for the VM
        Write-EnhancedLog -Message "Enabling TPM..." -Level "INFO"
        EnableVMTPM -VMName $vmParams.VMName
        
        # Add second network adapter for OPNsense LAN interface
        Write-EnhancedLog -Message "Adding second network adapter for LAN interface..." -Level "INFO"
        try {
            # Ensure we have a clean switch name (handle case where function returned object instead of string)
            $cleanSwitchName = if ($internalSwitchName -is [string]) { 
                $internalSwitchName 
            } else { 
                $internalSwitchName.Name 
            }
            
            Write-EnhancedLog -Message "Looking for switch with name: $cleanSwitchName" -Level "INFO"
            
            # Get the specific switch object to avoid ambiguity
            $lanSwitch = Get-VMSwitch | Where-Object { $_.Name -eq $cleanSwitchName } | Select-Object -First 1
            if ($lanSwitch) {
                Add-VMNetworkAdapter -VMName $vmParams.VMName -Name "LAN" -SwitchName $lanSwitch.Name
                Write-EnhancedLog -Message "Successfully added LAN network adapter connected to: $($lanSwitch.Name) (Type: $($lanSwitch.SwitchType))" -Level "INFO"
            } else {
                Write-EnhancedLog -Message "Could not find switch with name: $cleanSwitchName" -Level "ERROR"
                Write-EnhancedLog -Message "Available switches:" -Level "INFO"
                Get-VMSwitch | ForEach-Object { Write-EnhancedLog -Message "  - $($_.Name) (Type: $($_.SwitchType))" -Level "INFO" }
            }
        }
        catch {
            Write-EnhancedLog -Message "Failed to add second network adapter: $_" -Level "ERROR"
            Write-EnhancedLog -Message "Continuing with VM creation..." -Level "WARNING"
        }
        
        Write-EnhancedLog -Message "Completed main script execution" -Level "INFO"
    }
    else {
        Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR"
        exit 1
    }

    # Start VM and connect console
    $StartVMParams = @{
        VMName = $VMName
    }
    Log-Params -Params $StartVMParams

    $ConnectVMConsoleParams = @{
        VMName     = $VMName
        ServerName = "localhost"
        Count      = 1
    }
    Log-Params -Params $ConnectVMConsoleParams

    Start-VMEnhanced @StartVMParams
    Connect-VMConsole @ConnectVMConsoleParams

    # Initialize counters
    $summary = @{
        ConfigLoaded      = 0
        VMsChecked        = 0
        VMsCreated        = 0
        VMsFailed         = 0
        ActionsSuccessful = 0
        ActionsFailed     = 0
    }

    # Increment counters during script execution
    if ($config) {
        $summary.ConfigLoaded++
        $summary.ActionsSuccessful++
    }

    # After VM creation
    if ($VMCreated) {
        $summary.VMsCreated++
        $summary.ActionsSuccessful++
    }
    else {
        $summary.VMsFailed++
        $summary.ActionsFailed++
    }

    # Final VM creation and configuration
    if ($VMCreated) {
        $summary.ActionsSuccessful++
    }
    else {
        $summary.ActionsFailed++
    }

    # Summary Report
    Write-Host "Summary Report" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan

    Write-Host "Configuration Files Loaded: $($summary.ConfigLoaded)" -ForegroundColor Green

    Write-Host "VMs Checked: $($summary.VMsChecked)" -ForegroundColor Cyan
    Write-Host "VMs Successfully Created: $($summary.VMsCreated)" -ForegroundColor Green
    Write-Host "VMs Failed to Create: $($summary.VMsFailed)" -ForegroundColor Red

    Write-Host "Total Successful Actions: $($summary.ActionsSuccessful)" -ForegroundColor Green
    Write-Host "Total Failed Actions: $($summary.ActionsFailed)" -ForegroundColor Red

    Write-Host "============================" -ForegroundColor Cyan

    #endregion Script Logic
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging
    Wait-PSFMessage
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    
    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}