#################################################################################################################################
################################################# START VARIABLES ###############################################################
#################################################################################################################################


# Read configuration from the JSON file
# Assign values from JSON to variables

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json


# Define the available configuration files in the script root
$VMconfigPSD1Files = @(
    "config-server-2025.psd1",
    "config-client-Win11-23H2.psd1",
    "config-server-2022.psd1"
)

# Display a menu for the user to select a configuration file
Write-Host "Please select a configuration file:"
for ($i = 0; $i -lt $VMconfigPSD1Files.Count; $i++) {
    Write-Host "$($i + 1). $($VMconfigPSD1Files[$i])"
}

# Get user selection
$selection = Read-Host "Enter the number of the desired configuration file"

# Validate user selection
if ($selection -match '^[1-3]$') {
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
    } elseif ($proceed -notmatch '^[Yy]$') {
        Write-Host "Invalid input. Please run the script again and select a valid option."
        exit
    }
} else {
    Write-Host "Invalid selection. Please run the script again and select a valid option."
    exit
}

# Continue with the rest of your script using the selected $VMconfigPSD1
Write-Host "Proceeding with the selected configuration..."




# Now populate the connection parameters with values from the secrets file
# $connectionParams = @{
#     clientId     = $secrets.clientId
#     tenantID     = $secrets.tenantID
#     # ClientSecret = $secrets.ClientSecret
#     Clientcert = $certPath
# }

# $TenantName = $secrets.TenantName
# $site_objectid = "your group object id"
# $siteObjectId = $secrets.SiteObjectId

# $document_drive_name = "Documents"
# $document_drive_name = "Documents"
# $documentDriveName = $secrets.DocumentDriveName



# Assign values from JSON to variables
# $PackageName = $VMconfigPSD1.PackageName
# $PackageUniqueGUID = $VMconfigPSD1.PackageUniqueGUID
# $Version = $VMconfigPSD1.Version
# $PackageExecutionContext = $VMconfigPSD1.PackageExecutionContext
# $RepetitionInterval = $VMconfigPSD1.RepetitionInterval
# $ScriptMode = $VMconfigPSD1.ScriptMode


function Initialize-Environment {
    param (
        [string]$WindowsModulePath = "EnhancedBoilerPlateAO\2.0.0\EnhancedBoilerPlateAO.psm1",
        [string]$LinuxModulePath = "/usr/src/code/Modules/EnhancedBoilerPlateAO/2.0.0/EnhancedBoilerPlateAO.psm1"
    )

    function Get-Platform {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return $PSVersionTable.Platform
        }
        else {
            return [System.Environment]::OSVersion.Platform
        }
    }

    function Setup-GlobalPaths {
        if ($env:DOCKER_ENV -eq $true) {
            $global:scriptBasePath = $env:SCRIPT_BASE_PATH
            $global:modulesBasePath = $env:MODULES_BASE_PATH
        }
        else {
            $global:scriptBasePath = $PSScriptRoot
            # $global:modulesBasePath = "$PSScriptRoot\modules"
            $global:modulesBasePath = "D:\code\modules"
        }
    }

    function Setup-WindowsEnvironment {
        # Get the base paths from the global variables
        Setup-GlobalPaths

        # Construct the paths dynamically using the base paths
        $global:modulePath = Join-Path -Path $modulesBasePath -ChildPath $WindowsModulePath
        $global:AOscriptDirectory = Join-Path -Path $scriptBasePath -ChildPath "Win32Apps-DropBox"
        $global:directoryPath = Join-Path -Path $scriptBasePath -ChildPath "Win32Apps-DropBox"
        $global:Repo_Path = $scriptBasePath
        $global:Repo_winget = "$Repo_Path\Win32Apps-DropBox"


        # Import the module using the dynamically constructed path
        Import-Module -Name $global:modulePath -Verbose -Force:$true -Global:$true

        # Log the paths to verify
        Write-Output "Module Path: $global:modulePath"
        Write-Output "Repo Path: $global:Repo_Path"
        Write-Output "Repo Winget Path: $global:Repo_winget"
    }

    function Setup-LinuxEnvironment {
        # Get the base paths from the global variables
        Setup-GlobalPaths

        # Import the module using the Linux path
        Import-Module $LinuxModulePath -Verbose

        # Convert paths from Windows to Linux format
        # $global:AOscriptDirectory = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot"
        # $global:directoryPath = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot\Win32Apps-DropBox"
        # $global:Repo_Path = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot"
        $global:IntuneWin32App = Convert-WindowsPathToLinuxPath -WindowsPath "D:\Code\IntuneWin32App\IntuneWin32App.psm1"

        Import-Module $global:IntuneWin32App -Verbose -Global


        $global:AOscriptDirectory = "$PSscriptroot"
        $global:directoryPath = "$PSscriptroot/Win32Apps-DropBox"
        $global:Repo_Path = "$PSscriptroot"
        $global:Repo_winget = "$global:Repo_Path/Win32Apps-DropBox"
    }

    $platform = Get-Platform
    if ($platform -eq 'Win32NT' -or $platform -eq [System.PlatformID]::Win32NT) {
        Setup-WindowsEnvironment
    }
    elseif ($platform -eq 'Unix' -or $platform -eq [System.PlatformID]::Unix) {
        Setup-LinuxEnvironment
    }
    else {
        throw "Unsupported operating system"
    }
}

# Call the function to initialize the environment
Initialize-Environment


# Example usage of global variables outside the function
Write-Output "Global variables set by Initialize-Environment:"
Write-Output "scriptBasePath: $scriptBasePath"
Write-Output "modulesBasePath: $modulesBasePath"
Write-Output "modulePath: $modulePath"
Write-Output "AOscriptDirectory: $AOscriptDirectory"
Write-Output "directoryPath: $directoryPath"
Write-Output "Repo_Path: $Repo_Path"
Write-Output "Repo_winget: $Repo_winget"








#################################################################################################################################
################################################# END VARIABLES #################################################################
#################################################################################################################################

###############################################################################################################################
############################################### START MODULE LOADING ##########################################################
###############################################################################################################################

<#
.SYNOPSIS
Dot-sources all PowerShell scripts in the 'private' folder relative to the script root.

.DESCRIPTION
This function finds all PowerShell (.ps1) scripts in a 'private' folder located in the script root directory and dot-sources them. It logs the process, including any errors encountered, with optional color coding.

.EXAMPLE
Dot-SourcePrivateScripts

Dot-sources all scripts in the 'private' folder and logs the process.

.NOTES
Ensure the Write-EnhancedLog function is defined before using this function for logging purposes.
#>



Write-Host "Starting to call Get-ModulesFolderPath..."

# Store the outcome in $ModulesFolderPath
try {
  
    $ModulesFolderPath = Get-ModulesFolderPath -WindowsPath "D:\code\modules" -UnixPath "/usr/src/code/modules"
    # $ModulesFolderPath = Get-ModulesFolderPath -WindowsPath "$PsScriptRoot" -UnixPath "/usr/src/code/modules"
    Write-host "Modules folder path: $ModulesFolderPath"

}
catch {
    Write-Error $_.Exception.Message
}


Write-Host "Starting to call Get-ModulesScriptPathsAndVariables..."
# Retrieve script paths and related variables
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory "c:\" -ModulesFolderPath $ModulesFolderPath
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory $PSScriptRoot -ModulesFolderPath $ModulesFolderPath
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory $ModulesFolderPath

# $DotSourcinginitializationInfo
# $DotSourcinginitializationInfo | Format-List

Write-Host "Starting to call Import-LatestModulesLocalRepository..."
Import-LatestModulesLocalRepository -ModulesFolderPath $ModulesFolderPath -ScriptPath $PSScriptRoot


###############################################################################################################################
############################################### END MODULE LOADING ############################################################
###############################################################################################################################
try {
    Ensure-LoggingFunctionExists -LoggingFunctionName "Write-EnhancedLog"
    # Continue with the rest of the script here
    # exit
}
catch {
    Write-Host "Critical error: $_" -ForegroundColor Red
    exit
}


####################################CHECK IF RUNNING AS ADMIN##################################################################


# Check if the script is running with administrative privileges


if (-not (IsAdmin)) {
    Write-Host "Script needs to be run as Administrator. Relaunching with admin privileges." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

###############################################################################################################################
###############################################################################################################################
###############################################################################################################################

# Setup logging
Write-EnhancedLog -Message "Script Started" -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)

################################################################################################################################
################################################################################################################################
################################################################################################################################

# Execute InstallAndImportModulesPSGallery function
InstallAndImportModulesPSGallery -moduleJsonPath "$PSScriptRoot/modules.json"

################################################################################################################################
################################################ END MODULE CHECKING ###########################################################
################################################################################################################################

    
################################################################################################################################
################################################ END LOGGING ###################################################################
################################################################################################################################

#  Define the variables to be used for the function
#  $PSADTdownloadParams = @{
#      GithubRepository     = "psappdeploytoolkit/psappdeploytoolkit"
#      FilenamePatternMatch = "PSAppDeployToolkit*.zip"
#      ZipExtractionPath    = Join-Path "$PSScriptRoot\private" "PSAppDeployToolkit"
#  }

#  Call the function with the variables
#  Download-PSAppDeployToolkit @PSADTdownloadParams

################################################################################################################################
################################################ END DOWNLOADING PSADT #########################################################
################################################################################################################################


##########################################################################################################################
############################################STARTING THE MAIN FUNCTION LOGIC HERE#########################################
##########################################################################################################################

################################################################################################################################
################################################ START Ensure-ScriptPathsExist #################################################
################################################################################################################################

################################################################################################################################
################################################ START GRAPH CONNECTING ########################################################
################################################################################################################################
# $accessToken = Connect-GraphWithCert -tenantId $tenantId -clientId $clientId -certPath $certPath -certPassword $certPassword

# Log-Params -Params @{accessToken = $accessToken }

# Get-TenantDetails

################################################################################################################################
################################################ START M365 DSC CONNECTING ####################################################
################################################################################################################################

# Define the username from the secrets.psd1 file
# $SecretsFile = Join-Path -Path $PSScriptRoot -ChildPath "secrets.psd1"
# Write-EnhancedLog -Message "Reading credentials from $SecretsFile" -Level "INFO"
# $Secrets = Import-PowerShellDataFile -Path $SecretsFile
# $username = $Secrets.Username

# Assume these variables are already defined somewhere else in the script
# $certThumbprint = $Secrets.Thumbprint
# $clientId = <Your Client ID>

# Get the tenant details
# $tenantDetails = Get-TenantDetails
# if ($null -eq $tenantDetails) {
#     Write-EnhancedLog -Message "Unable to proceed without tenant details" -Level "ERROR"
#     exit
# }

# Retrieve necessary details from the tenant details
# $TenantDomain = $tenantDetails.TenantDomain

# # Read the components from the PSD1 file
# $ComponentsFile = Join-Path -Path $PSScriptRoot -ChildPath "Components.psd1"
# Write-EnhancedLog -Message "Reading components from $ComponentsFile" -Level "INFO"
# $Components = Import-PowerShellDataFile -Path $ComponentsFile


# Helper function to log parameter values


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

# $DBG

Connect-VMConsole @ConnectVMConsoleParams

# Stop-Transcript