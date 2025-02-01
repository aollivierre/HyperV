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



    # Get all available .psd1 files in the script root dynamically
    $VMconfigPSD1Files = Get-ChildItem -Path $PSScriptRoot -Filter "*.psd1" | Select-Object -ExpandProperty Name

    if ($VMconfigPSD1Files.Count -eq 0) {
        Write-Host "No configuration files found in the script root."
        exit
    }

    # Display a menu for the user to select a configuration file
    Write-Host "Please select a configuration file:"
    for ($i = 0; $i -lt $VMconfigPSD1Files.Count; $i++) {
        Write-Host "$($i + 1). $($VMconfigPSD1Files[$i])"
    }

    # Get user selection
    $selection = Read-Host "Enter the number of the desired configuration file"

    # Validate user selection
    if ($selection -match "^[1-$($VMconfigPSD1Files.Count)]$") {
        $VMconfigPSD1Path = Join-Path -Path $PSScriptRoot -ChildPath $VMconfigPSD1Files[$selection - 1]
        $VMconfigPSD1 = Import-PowerShellDataFile -Path $VMconfigPSD1Path
        Write-Host "Configuration loaded from $VMconfigPSD1Path"

        # Output the configuration to the console
        Write-Host "Here is the configuration:"
        $VMconfigPSD1.GetEnumerator() | ForEach-Object {
            Write-Host "$($_.Key) = $($_.Value)"
        }

        # Ask the user if they want to proceed or update the file
        $proceed = Read-Host "Do you want to proceed with this configuration? (Y)es or (N)o"
        if ($proceed -match '^[Nn]$') {
            # Open the file with VS Code
            Write-Host "Opening the configuration file in VS Code..."
            code $VMconfigPSD1Path
            Write-Host "Please update the file as needed and run the script again."
            exit
        }
        elseif ($proceed -notmatch '^[Yy]$') {
            Write-Host "Invalid input. Please run the script again and select a valid option."
            exit
        }
    }
    else {
        Write-Host "Invalid selection. Please run the script again and select a valid option."
        exit
    }

    # Continue with the rest of your script using the selected $VMconfigPSD1
    Write-Host "Proceeding with the selected configuration..."



  

    # $DBG

    $DismountVHDXParams = @{
        VHDXPath = $VMconfigPSD1.VHDXPath
    }
    Log-Params -Params $DismountVHDXParams
    Dismount-VHDX @DismountVHDXParams

    # $DBG

    $VMNamePrefix = Get-NextVMNamePrefix -config $VMconfigPSD1
    Write-EnhancedLog -Message "The next VM name prefix should be: $VMNamePrefix" -Level "INFO"

    # $DBG

    Write-EnhancedLog -Message "Starting main script execution" -Level "INFO"
    Initialize-HyperVServices


    # $DBG

    EnsureUntrustedGuardianExists

    $Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
    $VMName = "$VMNamePrefix`_$Datetime"
    $VMPath = $VMconfigPSD1.VMPath
    $VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName
    $differencing_VHDX_DiskPath = Join-Path -Path $VMFullPath -ChildPath "$VMName-diff.vhdx"

    # $DBG


    $NewCustomVMWithDifferencingDiskvmParams = @{
        VMName               = $VMName
        VMFullPath           = $VMFullPath
        ParentVHDPath        = $VMconfigPSD1.ParentVHDPath
        DifferencingDiskPath = $differencing_VHDX_DiskPath
        SwitchName           = $VMconfigPSD1.SwitchName
        MemoryStartupBytes   = [int64](Parse-Size $VMconfigPSD1.MemoryStartupBytes)
        MemoryMinimumBytes   = [int64](Parse-Size $VMconfigPSD1.MemoryMinimumBytes)
        MemoryMaximumBytes   = [int64](Parse-Size $VMconfigPSD1.MemoryMaximumBytes)
        Generation           = [int]$VMconfigPSD1.Generation
    }
    Log-Params -Params $NewCustomVMWithDifferencingDiskvmParams

    $VMCreated = New-CustomVMWithDifferencingDisk @NewCustomVMWithDifferencingDiskvmParams

    # $DBG

    if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
        Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR"
        exit
    }

    if ($VMCreated) {
        Add-DVDDriveToVM -VMName $VMName -InstallMediaPath $VMconfigPSD1.InstallMediaPath
        ConfigureVMBoot -VMName $VMName -DifferencingDiskPath $differencing_VHDX_DiskPath
        ConfigureVM -VMName $VMName -ProcessorCount $VMconfigPSD1.ProcessorCount
        EnableVMTPM -VMName $VMName
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