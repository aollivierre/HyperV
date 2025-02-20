# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'dev', 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-EnhancedLog -Message "Running in development mode" -Level 'WARNING'
        # Your development logic here
    }
    'prod' {
        Write-EnhancedLog -Message "Running in production mode" -ForegroundColor Green
        # Your production logic here
    }
    default {
        Write-EnhancedLog -Message "Unknown mode. Defaulting to production." -ForegroundColor Red
        # Default to production
    }
}

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

# Define a hashtable for splatting
$moduleStarterParams = @{
    Mode                   = 'dev'
    SkipPSGalleryModules   = $true
    SkipCheckandElevate    = $true
    SkipPowerShell7Install = $true
    SkipEnhancedModules    = $true
    SkipGitRepos           = $false
}

# Call the function using the splat
Invoke-ModuleStarter @moduleStarterParams

#endregion FIRING UP MODULE STARTER

#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$JobName = "HyperV-VMCreation"
$parentScriptName = Get-ParentScriptName
Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
$paramGetPSFCSVLogFilePath = @{
    LogsPath         = 'C:\Logs\PSF'
    JobName          = $jobName
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


#region HANDLE Transript LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE Transript LOGGING                                           #
#                                                                                               #
#################################################################################################
# Start the script with error handling
try {
    # Generate the transcript file path
    $GetTranscriptFilePathParams = @{
        TranscriptsPath  = "C:\Logs\Transcript"
        JobName          = $jobName
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
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
}
#endregion HANDLE Transript LOGGING

try {
    #region Script Logic
    #################################################################################################
    #                                                                                               #
    #                                    Script Logic                                               #
    #                                                                                               #
    #################################################################################################




    # Get the configuration
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "."
    $config = Get-VMConfiguration -ConfigPath $configPath

    # Verify configuration was loaded
    if (-not $config) {
        Write-EnhancedLog -Message "Failed to load configuration" -Level "ERROR"
        exit 1
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

    # Function to get available virtual switch
    function Get-AvailableVirtualSwitch {
        [CmdletBinding()]
        param()
        
        try {
            # Get all available virtual switches
            $switches = Get-VMSwitch -ErrorAction Stop
            
            if (-not $switches) {
                Write-EnhancedLog -Message "No virtual switches found. Creating default External switch..." -Level "WARNING"
                
                # Get the first available network adapter
                $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
                
                if ($netAdapter) {
                    # Create new external switch
                    $newSwitch = New-VMSwitch -Name "Default External Switch" -NetAdapterName $netAdapter.Name -AllowManagementOS $true
                    Write-EnhancedLog -Message "Created new external switch: $($newSwitch.Name)" -Level "INFO"
                    return $newSwitch.Name
                } else {
                    throw "No network adapters available to create virtual switch"
                }
            }
            
            # If there's only one switch, use it
            if ($switches.Count -eq 1) {
                Write-EnhancedLog -Message "Using the only available switch: $($switches[0].Name)" -Level "INFO"
                return $switches[0].Name
            }
            
            # If multiple switches exist, show selection menu
            Write-Host "`nAvailable Virtual Switches:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $switches.Count; $i++) {
                Write-Host "[$i] $($switches[$i].Name) (Type: $($switches[$i].SwitchType))"
            }
            
            do {
                $selection = Read-Host "`nSelect virtual switch [0-$($switches.Count - 1)]"
            } while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -ge $switches.Count)
            
            return $switches[[int]$selection].Name
        }
        catch {
            Write-EnhancedLog -Message "Error getting virtual switch: $_" -Level "ERROR"
            throw
        }
    }

    # Get virtual switch dynamically instead of from config
    $virtualSwitchName = Get-AvailableVirtualSwitch
    Write-EnhancedLog -Message "Using virtual switch: $virtualSwitchName" -Level "INFO"

    # Define common VM parameters from configuration
    $vmParams = @{
        VMName             = $VMName
        VMFullPath         = $VMFullPath
        VHDPath            = $vmDestinationPath
        SwitchName         = $virtualSwitchName  # Use dynamically selected switch
        MemoryStartupBytes = [int64](Invoke-Expression $config.MemoryStartupBytes.Replace('GB', '*1GB'))
        MemoryMinimumBytes = [int64](Invoke-Expression $config.MemoryMinimumBytes.Replace('GB', '*1GB'))
        MemoryMaximumBytes = [int64](Invoke-Expression $config.MemoryMaximumBytes.Replace('GB', '*1GB'))
        Generation         = $config.Generation
        UseDifferencing    = $UsesDifferencing
    }

    if ($UsesDifferencing) {
        # For differencing disk, use the template as parent
        $vmParams['ParentVHDPath'] = $config.VHDXPath
    }
    else {
        # For new disk, create fresh at destination
        $vmParams['NewVHDSizeBytes'] = 100GB  # Or get from config if available
    }

    # Create the VM
    $VMCreated = New-CustomVMWithDifferencingDisk @vmParams

    # Verify VM creation
    $getVMParams = @{
        Name        = $vmParams.VMName
        ErrorAction = 'SilentlyContinue'
    }

    if (-not (Get-VM @getVMParams)) {
        Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR"
        exit 1
    }

    # Then modify how you call it in your main script
    if ($VMCreated) {
        if (-not $UsesDifferencing) {
            Add-DVDDriveToVM -VMName $vmParams.VMName -InstallMediaPath $config.InstallMediaPath
        
            # Simple call without differencing disk path
            ConfigureVMBoot -VMName $vmParams.VMName
        }
        else {
            # Call with differencing disk path when using differencing disk
            ConfigureVMBoot -VMName $vmParams.VMName -DifferencingDiskPath $vmParams.VHDPath
        }

        ConfigureVM -VMName $vmParams.VMName -ProcessorCount $config.ProcessorCount
        EnableVMTPM -VMName $vmParams.VMName
        Write-EnhancedLog -Message "Completed main script execution" -Level "INFO"
    }
    else {
        Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR"
        exit 1
    }

  

    # $DBG

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
    if ($VMconfigPSD1) {
        $summary.ConfigLoaded++
        $summary.ActionsSuccessful++
    }

    # VM Checking Loop (within your process loop for checking VMs)
    foreach ($vm in $allVMs) {
        $summary.VMsChecked++
        if ($vm) {
            $summary.ActionsSuccessful++
        }
        else {
            $summary.ActionsFailed++
        }
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


    

    #endregion
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    # 

    
    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}