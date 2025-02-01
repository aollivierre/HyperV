#Unique Tracking ID: 77722627-441d-46d6-b23a-dc9fda6cedc9, Timestamp: 2024-03-18 16:00:30

# Read configuration from the JSON file
# Assign values from JSON to variables


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

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

# $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Assign values from JSON to variables
# $PackageName = $config.PackageName
# $PackageUniqueGUID = $config.PackageUniqueGUID
# $Version = $config.Version
# $PackageExecutionContext = $config.PackageExecutionContext
# $RepetitionInterval = $config.RepetitionInterval
# $ScriptMode = $config.ScriptMode




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

function Get-PrivateScriptPathsAndVariables {
    param (
        [string]$BaseDirectory
    )

    try {
        $privateFolderPath = Join-Path -Path $BaseDirectory -ChildPath "private"
        
        if (-not (Test-Path -Path $privateFolderPath)) {
            throw "Private folder path does not exist: $privateFolderPath"
        }

        # Construct and return a PSCustomObject
        return [PSCustomObject]@{
            BaseDirectory     = $BaseDirectory
            PrivateFolderPath = $privateFolderPath
        }
    }
    catch {
        Write-Host "Error in finding private script files: $_" -ForegroundColor Red
        # Optionally, you could return a PSCustomObject indicating an error state
        # return [PSCustomObject]@{ Error = $_.Exception.Message }
    }
}



# Retrieve script paths and related variables
$DotSourcinginitializationInfo = Get-PrivateScriptPathsAndVariables -BaseDirectory $PSScriptRoot

# $DotSourcinginitializationInfo
$DotSourcinginitializationInfo | Format-List


function Import-ModuleWithRetry {

    <#
.SYNOPSIS
Imports a PowerShell module with retries on failure.

.DESCRIPTION
This function attempts to import a specified PowerShell module, retrying the import process up to a specified number of times upon failure. It waits for a specified delay between retries. The function uses advanced logging to provide detailed feedback about the import process.

.PARAMETER ModulePath
The path to the PowerShell module file (.psm1) that should be imported.

.PARAMETER MaxRetries
The maximum number of retries to attempt if importing the module fails. Default is 30.

.PARAMETER WaitTimeSeconds
The number of seconds to wait between retry attempts. Default is 2 seconds.

.EXAMPLE
$modulePath = "C:\Modules\MyPowerShellModule.psm1"
Import-ModuleWithRetry -ModulePath $modulePath

Tries to import the module located at "C:\Modules\MyPowerShellModule.psm1", with up to 30 retries, waiting 2 seconds between each retry.

.NOTES
This function requires the `Write-EnhancedLog` function to be defined in the script for logging purposes.

.LINK
Write-EnhancedLog

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ModulePath,

        [int]$MaxRetries = 30,

        [int]$WaitTimeSeconds = 2
    )

    Begin {
        $retryCount = 0
        $isModuleLoaded = $false
        # Write-EnhancedLog -Message "Starting to import module from path: $ModulePath" -Level "INFO"
        Write-Host "Starting to import module from path: $ModulePath"
    }

    Process {
        while (-not $isModuleLoaded -and $retryCount -lt $MaxRetries) {
            try {
                Import-Module $ModulePath -ErrorAction Stop
                $isModuleLoaded = $true
                Write-EnhancedLog -Message "Module: $ModulePath imported successfully." -Level "INFO"
            }
            catch {
                # Write-EnhancedLog -Message "Attempt $retryCount to load module failed. Waiting $WaitTimeSeconds seconds before retrying." -Level "WARNING"
                Write-Host "Attempt $retryCount to load module failed. Waiting $WaitTimeSeconds seconds before retrying."
                Start-Sleep -Seconds $WaitTimeSeconds
            }
            finally {
                $retryCount++
            }

            if ($retryCount -eq $MaxRetries -and -not $isModuleLoaded) {
                # Write-EnhancedLog -Message "Failed to import module after $MaxRetries retries." -Level "ERROR"
                Write-Host "Failed to import module after $MaxRetries retries."
                break
            }
        }
    }

    End {
        if ($isModuleLoaded) {
            Write-EnhancedLog -Message "Module: $ModulePath loaded successfully." -Level "INFO"
        }
        else {
            # Write-EnhancedLog -Message "Failed to load module $ModulePath within the maximum retry limit." -Level "CRITICAL"
            Write-Host "Failed to load module $ModulePath within the maximum retry limit."
        }
    }
}

# Example of how to use the function
# $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "Private\EnhancedLoggingAO\2.0.0\EnhancedLoggingAO.psm1"

# Call the function to import the module with retry logic
Import-ModuleWithRetry -ModulePath $modulePath




# ################################################################################################################################
# ################################################ END MODULE LOADING ############################################################
# ################################################################################################################################



function Ensure-LoggingFunctionExists {
    if (Get-Command Write-EnhancedLog -ErrorAction SilentlyContinue) {
        Write-EnhancedLog -Message "Logging works" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }
    else {
        throw "Write-EnhancedLog function not found. Terminating script."
    }
}

# Usage
try {
    Ensure-LoggingFunctionExists
    # Continue with the rest of the script here
    # exit
}
catch {
    Write-Host "Critical error: $_" -ForegroundColor Red
    exit
}



# ################################################################################################################################
# ################################################ DOWNLOAD ServiceUI ###########################################################
# ################################################################################################################################



function Remove-ExistingServiceUI {
    [CmdletBinding()]
    param(
        [string]$TargetFolder = "$PSScriptRoot\private"
    )

    # Full path for ServiceUI.exe
    $ServiceUIPath = Join-Path -Path $TargetFolder -ChildPath "ServiceUI.exe"

    try {
        # Check if ServiceUI.exe exists
        if (Test-Path -Path $ServiceUIPath) {
            Write-EnhancedLog -Message "Removing existing ServiceUI.exe from: $TargetFolder" -Level "INFO"
            # Remove ServiceUI.exe
            Remove-Item -Path $ServiceUIPath -Force
            Write-Output "ServiceUI.exe has been removed from: $TargetFolder"
        }
        else {
            Write-EnhancedLog -Message "No ServiceUI.exe file found in: $TargetFolder" -Level "INFO"
        }
    }
    catch {
        # Handle any errors during the removal
        Write-Error "An error occurred while trying to remove ServiceUI.exe: $_"
        Write-EnhancedLog -Message "An error occurred while trying to remove ServiceUI.exe: $_" -Level "ERROR"
    }
}

function Download-And-Install-ServiceUI {
    [CmdletBinding()]
    param(
        [string]$TargetFolder = "$PSScriptRoot\private"
    )

    Begin {
        try {
            Remove-ExistingServiceUI -TargetFolder $TargetFolder
        }
        catch {
            Write-EnhancedLog -Message "Error during Remove-ExistingServiceUI: $_" -Level "ERROR"
            throw $_
        }
    }

    Process {
        # Define the URL for MDT download
        $url = "https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
        
        # Path for the downloaded MSI file
        $msiPath = Join-Path -Path $([System.IO.Path]::GetTempPath()) -ChildPath "MicrosoftDeploymentToolkit_x64.msi"
        
        try {
            # Download the MDT MSI file
            Write-EnhancedLog -Message "Downloading MDT MSI from: $url to: $msiPath" -Level "INFO"
            Invoke-WebRequest -Uri $url -OutFile $msiPath

            # Install the MSI silently
            Write-EnhancedLog -Message "Installing MDT MSI from: $msiPath" -Level "INFO"
            Start-Process msiexec.exe -ArgumentList "/i", "`"$msiPath`"", "/quiet", "/norestart" -Wait

            # Path to the installed ServiceUI.exe
            $installedServiceUIPath = "C:\Program Files\Microsoft Deployment Toolkit\Templates\Distribution\Tools\x64\ServiceUI.exe"
            $finalPath = Join-Path -Path $TargetFolder -ChildPath "ServiceUI.exe"

            # Move ServiceUI.exe to the desired location
            if (Test-Path -Path $installedServiceUIPath) {
                Write-EnhancedLog -Message "Copying ServiceUI.exe from: $installedServiceUIPath to: $finalPath" -Level "INFO"
                Copy-Item -Path $installedServiceUIPath -Destination $finalPath

                Write-EnhancedLog -Message "ServiceUI.exe has been successfully copied to: $finalPath" -Level "INFO"
            }
            else {
                throw "ServiceUI.exe not found at: $installedServiceUIPath"
            }

            # Remove the downloaded MSI file
            Remove-Item -Path $msiPath -Force
        }
        catch {
            # Handle any errors during the process
            Write-Error "An error occurred: $_"
            Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR"
        }
    }

    End {
        Write-EnhancedLog -Message "Download-And-Install-ServiceUI function execution completed." -Level "INFO"
    }
}

# Define the variables to be used for the function
$serviceUIParams = @{
    TargetFolder = "$PSScriptRoot\private"
}

# Call the function with the variables
# Download-And-Install-ServiceUI @serviceUIParams






# ################################################################################################################################
# ################################################ END SERVICE UI ################################################################
# ################################################################################################################################


# ################################################################################################################################
# ################################################ END MODULE CHECKING ###########################################################
# ################################################################################################################################




function Test-RunningAsSystem {
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User

    return $currentSid -eq $systemSid
}


function CheckAndElevate {

    <#
.SYNOPSIS
Elevates the script to run with administrative privileges if not already running as an administrator.

.DESCRIPTION
The CheckAndElevate function checks if the current PowerShell session is running with administrative privileges. If it is not, the function attempts to restart the script with elevated privileges using the 'RunAs' verb. This is useful for scripts that require administrative privileges to perform their tasks.

.EXAMPLE
CheckAndElevate

Checks the current session for administrative privileges and elevates if necessary.

.NOTES
This function will cause the script to exit and restart if it is not already running with administrative privileges. Ensure that any state or data required after elevation is managed appropriately.
#>
    [CmdletBinding()]
    param (
        # Advanced parameters could be added here if needed. For this function, parameters aren't strictly necessary,
        # but you could, for example, add parameters to control logging behavior or to specify a different method of elevation.
        # [switch]$Elevated
    )

    begin {
        try {
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            Write-EnhancedLog -Message "Checking for administrative privileges..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Blue)
        }
        catch {
            Write-EnhancedLog -Message "Error determining administrative status: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
            throw $_
        }
    }

    process {
        if (-not $isAdmin) {
            try {
                Write-EnhancedLog -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
                
                $arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" $args"
                Start-Process PowerShell -Verb RunAs -ArgumentList $arguments

                # Invoke-AsSystem -PsExec64Path $PsExec64Path
                
                Write-EnhancedLog -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                exit
            }
            catch {
                Write-EnhancedLog -Message "Failed to elevate privileges: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $_
            }
        }
        else {
            Write-EnhancedLog -Message "Script is already running with administrative privileges." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
    }

    end {
        # This block is typically used for cleanup. In this case, there's nothing to clean up,
        # but it's useful to know about this structure for more complex functions.
    }
}



function Remove-ExistingPsExec {
    [CmdletBinding()]
    param(
        [string]$TargetFolder = "$PSScriptRoot\private"
    )

    # Full path for PsExec64.exe
    $PsExec64Path = Join-Path -Path $TargetFolder -ChildPath "PsExec64.exe"

    try {
        # Check if PsExec64.exe exists
        if (Test-Path -Path $PsExec64Path) {
            Write-EnhancedLog -Message "Removing existing PsExec64.exe from: $TargetFolder"
            # Remove PsExec64.exe
            Remove-Item -Path $PsExec64Path -Force
            Write-Output "PsExec64.exe has been removed from: $TargetFolder"
        }
        else {
            Write-EnhancedLog -Message "No PsExec64.exe file found in: $TargetFolder"
        }
    }
    catch {
        # Handle any errors during the removal
        Write-Error "An error occurred while trying to remove PsExec64.exe: $_"
    }
}






function Download-PsExec {
    [CmdletBinding()]
    param(
        [string]$TargetFolder = "$PSScriptRoot\private"
    )

    Begin {

        Remove-ExistingPsExec
    }



    process {

        # Define the URL for PsExec download
        $url = "https://download.sysinternals.com/files/PSTools.zip"
    
        # Ensure the target folder exists
        if (-Not (Test-Path -Path $TargetFolder)) {
            New-Item -Path $TargetFolder -ItemType Directory
        }
  
        # Full path for the downloaded file
        $zipPath = Join-Path -Path $TargetFolder -ChildPath "PSTools.zip"
  
        try {
            # Download the PSTools.zip file containing PsExec
            Write-EnhancedLog -Message "Downloading PSTools.zip from: $url to: $zipPath"
            Invoke-WebRequest -Uri $url -OutFile $zipPath
  
            # Extract PsExec64.exe from the zip file
            Expand-Archive -Path $zipPath -DestinationPath "$TargetFolder\PStools" -Force
  
            # Specific extraction of PsExec64.exe
            $extractedFolderPath = Join-Path -Path $TargetFolder -ChildPath "PSTools"
            $PsExec64Path = Join-Path -Path $extractedFolderPath -ChildPath "PsExec64.exe"
            $finalPath = Join-Path -Path $TargetFolder -ChildPath "PsExec64.exe"
  
            # Move PsExec64.exe to the desired location
            if (Test-Path -Path $PsExec64Path) {
  
                Write-EnhancedLog -Message "Moving PSExec64.exe from: $PsExec64Path to: $finalPath"
                Move-Item -Path $PsExec64Path -Destination $finalPath
  
                # Remove the downloaded zip file and extracted folder
                Remove-Item -Path $zipPath -Force
                Remove-Item -Path $extractedFolderPath -Recurse -Force
  
                Write-EnhancedLog -Message "PsExec64.exe has been successfully downloaded and moved to: $finalPath"
            }
        }
        catch {
            # Handle any errors during the process
            Write-Error "An error occurred: $_"
        }
    }


  

}




function Invoke-AsSystem {
    <#
.SYNOPSIS
Executes a PowerShell script under the SYSTEM context, similar to Intune's execution context.

.DESCRIPTION
The Invoke-AsSystem function executes a PowerShell script using PsExec64.exe to run under the SYSTEM context. This method is useful for scenarios requiring elevated privileges beyond the current user's capabilities.

.PARAMETER PsExec64Path
Specifies the full path to PsExec64.exe. If not provided, it assumes PsExec64.exe is in the same directory as the script.

.EXAMPLE
Invoke-AsSystem -PsExec64Path "C:\Tools\PsExec64.exe"

Executes PowerShell as SYSTEM using PsExec64.exe located at "C:\Tools\PsExec64.exe".

.NOTES
Ensure PsExec64.exe is available and the script has the necessary permissions to execute it.

.LINK
https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PsExec64Path,
        [string]$ScriptPathAsSYSTEM  # Path to the PowerShell script you want to run as SYSTEM
    )

    begin {
        CheckAndElevate
        # Define the arguments for PsExec64.exe to run PowerShell as SYSTEM with the script
        $argList = "-accepteula -i -s -d powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$ScriptPathAsSYSTEM`""
        Write-EnhancedLog -Message "Preparing to execute PowerShell as SYSTEM using PsExec64 with the script: $ScriptPathAsSYSTEM" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)

        Download-PsExec
    }

    process {
        try {
            # Ensure PsExec64Path exists
            if (-not (Test-Path -Path $PsExec64Path)) {
                $errorMessage = "PsExec64.exe not found at path: $PsExec64Path"
                Write-EnhancedLog -Message $errorMessage -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $errorMessage
            }

            # Run PsExec64.exe with the defined arguments to execute the script as SYSTEM
            $executingMessage = "Executing PsExec64.exe to start PowerShell as SYSTEM running script: $ScriptPathAsSYSTEM"
            Write-EnhancedLog -Message $executingMessage -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            Start-Process -FilePath "$PsExec64Path" -ArgumentList $argList -Wait -NoNewWindow
            
            Write-EnhancedLog -Message "SYSTEM session started. Closing elevated session..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            exit

        }
        catch {
            Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
        }
    }
}




# Assuming Invoke-AsSystem and Write-EnhancedLog are already defined
# Update the path to your actual location of PsExec64.exe

# Write-EnhancedLog -Message "calling Test-RunningAsSystem" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
# if (-not (Test-RunningAsSystem)) {
#     $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
#     $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

#     Write-EnhancedLog -Message "Current session is not running as SYSTEM. Attempting to invoke as SYSTEM..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)

#     $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
#     Invoke-AsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem

# }
# else {
#     Write-EnhancedLog -Message "Session is already running as SYSTEM." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
# }


    
    
#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################



#################################################################################################################################
################################################# CALLING SERVICE UI with PSADT #################################################
#################################################################################################################################


# Start the process, wait for it to complete, and optionally hide the window

# $d_1002 = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
# Start-Process -FilePath "$d_1002\Private\ServiceUI.exe" -ArgumentList "$d_1002\Private\PSAppDeployToolkit\Toolkit\Deploy-Application.exe" -Wait -WindowStyle Hidden
# Start-Process -FilePath "$d_1002\Private\PSAppDeployToolkit\Toolkit\Deploy-Application.exe" -Wait -WindowStyle Hidden






# function Start-ServiceUIWithAppDeploy {
#     [CmdletBinding()]
#     param (
#         [string]$PSADTExecutable = "$PSScriptRoot\Private\PSAppDeployToolkit\Toolkit\Deploy-Application.exe",
#         [string]$ServiceUIExecutable = "$PSScriptRoot\Private\ServiceUI.exe",
#         [string]$DeploymentType = "install"
#     )

#     try {
#         # Verify if the ServiceUI executable exists
#         if (-not (Test-Path -Path $ServiceUIExecutable)) {
#             throw "ServiceUI executable not found at path: $ServiceUIExecutable"
#         }

#         # Verify if the PSAppDeployToolkit executable exists
#         if (-not (Test-Path -Path $PSADTExecutable)) {
#             throw "PSAppDeployToolkit executable not found at path: $PSADTExecutable"
#         }

#         # Log the start of the process
#         Write-EnhancedLog -Message "Starting ServiceUI.exe with Deploy-Application.exe" -Level "INFO"

#         # Define the arguments to pass to ServiceUI.exe
#         $arguments = "-process:explorer.exe `"$PSADTExecutable`" -DeploymentType $DeploymentType"

#         # Start the ServiceUI.exe process with the specified arguments
#         Start-Process -FilePath $ServiceUIExecutable -ArgumentList $arguments -Wait -WindowStyle Hidden

#         # Log successful completion
#         Write-EnhancedLog -Message "ServiceUI.exe started successfully with Deploy-Application.exe" -Level "INFO"
#     }
#     catch {
#         # Handle any errors during the process
#         Write-Error "An error occurred: $_"
#         Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR"
#     }
# }

# # Example usage
# Start-ServiceUIWithAppDeploy


#################################################################################################################################
################################################# END CALLING SERVICE UI with PSADT #############################################
#################################################################################################################################










#################################################################################################################################
################################################# CALLING VHDX unattend.xml INJECTOR ############################################
#################################################################################################################################


function Mount-VHDX {
    <#
    .SYNOPSIS
    Mounts a specified VHDX file.

    .DESCRIPTION
    This function mounts the specified VHDX file and returns the mounted drive path.

    .PARAMETER VHDXPath
    The path to the VHDX file to be mounted.

    .OUTPUTS
    The drive path of the mounted VHDX.

    .NOTES
    Requires the Hyper-V module.

    .EXAMPLE
    $drivePath = Mount-VHDX -VHDXPath "C:\Path\To\VHDX.vhdx"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    try {
        Write-EnhancedLog -Message "Mounting VHDX: $VHDXPath" -Level "INFO" -ForegroundColor Cyan
        $vhd = Mount-VHD -Path $VHDXPath -Passthru
        $drivePath = ($vhd | Get-Disk | Get-Partition | Get-Volume).DriveLetter + ":\"
        Write-EnhancedLog -Message "VHDX mounted successfully at $drivePath." -Level "INFO" -ForegroundColor Green
        return $drivePath
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while mounting the VHDX: $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Update-UnattendFile {
    <#
    .SYNOPSIS
    Updates the unattend.xml file in the mounted VHDX.

    .DESCRIPTION
    This function removes the existing unattend.xml file and copies a new one from the specified source path.

    .PARAMETER DrivePath
    The drive path where the unattend.xml file is located.

    .PARAMETER NewUnattendSource
    The source path of the new unattend.xml file.

    .EXAMPLE
    Update-UnattendFile -DrivePath "H:\" -NewUnattendSource "C:\Path\To\New\Unattend.xml"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$DrivePath,

        [Parameter(Mandatory = $true)]
        [string]$NewUnattendSource
    )

    try {
        $unattendPath = Join-Path -Path $DrivePath -ChildPath "unattend.xml"
        
        if (Test-Path $unattendPath) {
            Write-EnhancedLog -Message "Removing existing unattend.xml from $DrivePath" -Level "INFO" -ForegroundColor Yellow
            Remove-Item $unattendPath -Force
            Write-EnhancedLog -Message "Existing unattend.xml removed." -Level "INFO" -ForegroundColor Green
        }

        Write-EnhancedLog -Message "Copying new unattend.xml to $DrivePath" -Level "INFO" -ForegroundColor Yellow
        Copy-Item -Path $NewUnattendSource -Destination $unattendPath
        Write-EnhancedLog -Message "New unattend.xml copied successfully." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while updating unattend.xml: $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Dismount-VHDX {
    <#
    .SYNOPSIS
    Dismounts a specified VHDX file.

    .DESCRIPTION
    This function dismounts the specified VHDX file.

    .PARAMETER VHDXPath
    The path to the VHDX file to be dismounted.

    .EXAMPLE
    Dismount-VHDX -VHDXPath "C:\Path\To\VHDX.vhdx"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    try {
        Write-EnhancedLog -Message "Dismounting VHDX: $VHDXPath" -Level "INFO" -ForegroundColor Yellow
        Dismount-VHD -Path $VHDXPath
        Write-EnhancedLog -Message "VHDX dismounted successfully." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while dismounting the VHDX: $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Invoke-ScriptWithPowerShell {
    <#
    .SYNOPSIS
    Executes a specified PowerShell script using Start-Process.

    .DESCRIPTION
    This function executes the specified PowerShell script using Start-Process with the full path to PowerShell, along with the -ExecutionPolicy Bypass and -File parameters.

    .PARAMETER ScriptPath
    The path to the PowerShell script to be executed.

    .EXAMPLE
    Invoke-ScriptWithPowerShell -ScriptPath "C:\Path\To\Script.ps1"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    try {
        Write-EnhancedLog -Message "Executing script: $ScriptPath" -Level "INFO" -ForegroundColor Cyan
        Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
        Write-EnhancedLog -Message "Script executed successfully." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Validate-VHDMount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    # Check if the VHDX is mounted
    $vhd = Get-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    if ($vhd -and $vhd.Attached) {
        Write-Host "VHDX is mounted: $VHDXPath" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "VHDX is not mounted: $VHDXPath" -ForegroundColor Red
        return $false
    }
}

function Mount-VHDXFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VhdxPath
    )

    Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
    $disk = Mount-VHD -Path $VhdxPath -PassThru | Get-Disk

    if ($null -eq $disk) {
        throw "Failed to mount VHDX file: $VhdxPath"
    }

    $disk
}

function Dismount-VHDXFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VhdxPath
    )

    Write-Host "Dismounting VHDX file: $VhdxPath" -ForegroundColor Cyan
    Dismount-VHD -Path $VhdxPath
}

function UpdateVHDXUnattendAndExecuteScript {
    <#
    .SYNOPSIS
    Updates the unattend.xml in a VHDX file and executes a specified script.

    .DESCRIPTION
    This function mounts a VHDX file, updates the unattend.xml file within it, dismounts the VHDX, and executes a specified script.

    .PARAMETER VHDXPath
    The path to the VHDX file to be managed.

    .PARAMETER NewUnattendSource
    The source path of the new unattend.xml file.

    .PARAMETER ScriptPath
    The path to the PowerShell script to be executed.

    .EXAMPLE
    UpdateVHDXUnattendAndExecuteScript -VHDXPath "C:\Path\To\VHDX.vhdx" -NewUnattendSource "C:\Path\To\New\Unattend.xml" -ScriptPath "C:\Path\To\Script.ps1"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath,

        [Parameter(Mandatory = $true)]
        [string]$NewUnattendSource,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    try {
        $disk = Mount-VHDXFile -VhdxPath $VHDXPath
        $isMounted = Validate-VHDMount -VHDXPath $VHDXPath
        if ($isMounted) {
            $drivePath = ($disk | Get-Partition | Get-Volume).DriveLetter + ":\"
            Update-UnattendFile -DrivePath $drivePath -NewUnattendSource $NewUnattendSource
            Dismount-VHDXFile -VhdxPath $VHDXPath
        } else {
            throw "Failed to mount VHDX: $VHDXPath"
        }
    }
    catch {
        Write-EnhancedLog -Message "An error occurred in the VHDX management process: $_" -Level "ERROR" -ForegroundColor Red
        return
    }

    try {
        Invoke-ScriptWithPowerShell -ScriptPath $ScriptPath
    }
    catch {
        Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level "ERROR" -ForegroundColor Red
    }
}

# Define the parameters to be used for the function
$updateVHDXParams = @{
    VHDXPath             = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
    NewUnattendSource    = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\3.2-Inject-Unattend-VHDX\Unattend\unattend.xml"
    ScriptPath           = "D:\Code\GitHub\CB\CB\Hyper-V\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows.ps1"
}

# Call the function to perform operations
UpdateVHDXUnattendAndExecuteScript @updateVHDXParams




#################################################################################################################################
################################################# END CALLING VHDX unattend.xml INJECTOR ########################################
#################################################################################################################################