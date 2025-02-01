
# Check if the script is running with administrative privileges
function IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

if (-not (IsAdmin)) {
    Write-Host "Script needs to be run as Administrator. Relaunching with admin privileges." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}


function Initialize-ScriptAndLogging {
    $ErrorActionPreference = 'SilentlyContinue'
    $deploymentName = "CreateNewHyperV_VM" # Replace this with your actual deployment name
    $scriptPath = "C:\code\$deploymentName"
    # $hadError = $false

    try {
        if (-not (Test-Path -Path $scriptPath)) {
            New-Item -ItemType Directory -Path $scriptPath -Force | Out-Null
            Write-Host "Created directory: $scriptPath"
        }

        $computerName = $env:COMPUTERNAME
        $Filename = "CreateNewHyperV_VM"
        $logDir = Join-Path -Path $scriptPath -ChildPath "exports\Logs\$computerName"
        $logPath = Join-Path -Path $logDir -ChildPath "$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')"
        
        if (!(Test-Path $logPath)) {
            Write-Host "Did not find log file at $logPath" -ForegroundColor Yellow
            Write-Host "Creating log file at $logPath" -ForegroundColor Yellow
            $createdLogDir = New-Item -ItemType Directory -Path $logPath -Force -ErrorAction Stop
            Write-Host "Created log file at $logPath" -ForegroundColor Green
        }
        
        $logFile = Join-Path -Path $logPath -ChildPath "$Filename-Transcript.log"
        Start-Transcript -Path $logFile -ErrorAction Stop | Out-Null

        $CSVDir = Join-Path -Path $scriptPath -ChildPath "exports\CSV"
        $CSVFilePath = Join-Path -Path $CSVDir -ChildPath "$computerName"
        
        if (!(Test-Path $CSVFilePath)) {
            Write-Host "Did not find CSV file at $CSVFilePath" -ForegroundColor Yellow
            Write-Host "Creating CSV file at $CSVFilePath" -ForegroundColor Yellow
            $createdCSVDir = New-Item -ItemType Directory -Path $CSVFilePath -Force -ErrorAction Stop
            Write-Host "Created CSV file at $CSVFilePath" -ForegroundColor Green
        }

        return @{
            ScriptPath  = $scriptPath
            Filename    = $Filename
            LogPath     = $logPath
            LogFile     = $logFile
            CSVFilePath = $CSVFilePath
        }

    }
    catch {
        Write-Error "An error occurred while initializing script and logging: $_"
    }
}
$initializationInfo = Initialize-ScriptAndLogging



# Script Execution and Variable Assignment
# After the function Initialize-ScriptAndLogging is called, its return values (in the form of a hashtable) are stored in the variable $initializationInfo.

# Then, individual elements of this hashtable are extracted into separate variables for ease of use:

# $ScriptPath: The path of the script's main directory.
# $Filename: The base name used for log files.
# $logPath: The full path of the directory where logs are stored.
# $logFile: The full path of the transcript log file.
# $CSVFilePath: The path of the directory where CSV files are stored.
# This structure allows the script to have a clear organization regarding where logs and other files are stored, making it easier to manage and maintain, especially for logging purposes. It also encapsulates the setup logic in a function, making the main script cleaner and more focused on its primary tasks.


$ScriptPath = $initializationInfo['ScriptPath']
$Filename = $initializationInfo['Filename']
$logPath = $initializationInfo['LogPath']
$logFile = $initializationInfo['LogFile']
$CSVFilePath = $initializationInfo['CSVFilePath']




function AppendCSVLog {
    param (
        [string]$Message,
        [string]$CSVFilePath
       
    )

    $csvData = [PSCustomObject]@{
        TimeStamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Message      = $Message
    }

    $csvData | Export-Csv -Path $CSVFilePath -Append -NoTypeInformation -Force
}


function CreateEventSourceAndLog {
    param (
        [string]$LogName,
        [string]$EventSource
    )

    # Check if the event log exists, and if not, create it
    if (-not (Get-WinEvent -ListLog $LogName -ErrorAction SilentlyContinue)) {
        try {
            New-EventLog -LogName $LogName -Source $EventSource
        }
        catch [System.InvalidOperationException] {
            Write-Warning "Error creating the event log. Make sure you run PowerShell as an Administrator."
        }
    }
    elseif (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
        # Get the existing log name for the event source
        $existingLogName = (Get-WinEvent -ListLog * | Where-Object { $_.LogName -contains $EventSource }).LogName

        # If the existing log name is different from the desired log name, unregister the source and register it with the correct log name
        if ($existingLogName -ne $LogName) {
            Remove-EventLog -Source $EventSource -ErrorAction SilentlyContinue
            try {
                New-EventLog -LogName $LogName -Source $EventSource
            }
            catch [System.InvalidOperationException] {
                New-EventLog -LogName $LogName -Source $EventSource
            }
        }
    }
}

function Write-CustomEventLog {
    param (
        [string]$LogName,
        [string]$EventSource,
        [int]$EventID = 1000,
        [string]$EventMessage,
        [string]$Level = 'INFO'
    )

    # Map the Level to the corresponding EntryType
    switch ($Level) {
        'DEBUG' { $EntryType = 'Information' }
        'INFO' { $EntryType = 'Information' }
        'WARNING' { $EntryType = 'Warning' }
        'ERROR' { $EntryType = 'Error' }
        default { $EntryType = 'Information' }
    }

    # Write the event to the custom event log
    try {
        Write-EventLog -LogName $LogName -Source $EventSource -EventID $EventID -Message $EventMessage -EntryType $EntryType
    }
    catch [System.InvalidOperationException] {
        Write-Warning "Error writing to the event log. Make sure you run PowerShell as an Administrator."
    }
}

$LogName = (Get-Date -Format "HHmmss") + "_CreateNewHyperV_VM"
$EventSource = (Get-Date -Format "HHmmss") + "_CreateNewHyperV_VM"

# Call the Create-EventSourceAndLog function
CreateEventSourceAndLog -LogName $LogName -EventSource $EventSource

# Call the Write-CustomEventLog function with custom parameters and level
# Write-CustomEventLog -LogName $LogName -EventSource $EventSource -EventMessage "Outlook Signature Restore completed with warnings." -EventID 1001 -Level 'WARNING'


function Write-EnhancedLog {
    param (
        [string]$Message,
        [string]$Level = 'INFO',
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [string]$CSVFilePath = "$scriptPath\exports\CSV\$(Get-Date -Format 'yyyy-MM-dd')-Log.csv",
        [string]$CentralCSVFilePath = "$scriptPath\exports\CSV\$Filename.csv",
        [switch]$UseModule = $false,
        [string]$Caller = (Get-PSCallStack)[0].Command
    )

    # Add timestamp, computer name, and log level to the message
    $formattedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $($env:COMPUTERNAME): [$Level] [$Caller] $Message"

    # Set foreground color based on log level
    switch ($Level) {
        'INFO' { $ForegroundColor = [ConsoleColor]::Green }
        'WARNING' { $ForegroundColor = [ConsoleColor]::Yellow }
        'ERROR' { $ForegroundColor = [ConsoleColor]::Red }
    }

    # Write the message with the specified colors
    $currentForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor
    # Write-output $formattedMessage
    Write-host $formattedMessage
    $Host.UI.RawUI.ForegroundColor = $currentForegroundColor

    # Append to CSV file
    AppendCSVLog -Message $formattedMessage -CSVFilePath $CSVFilePath
    AppendCSVLog -Message $formattedMessage -CSVFilePath $CentralCSVFilePath

    # Write to event log (optional)
    # Write-CustomEventLog -EventMessage $formattedMessage -Level $Level


    Write-CustomEventLog -LogName $LogName -EventSource $EventSource -EventMessage $formattedMessage -EventID 1001 -Level $Level
}

function Export-EventLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    try {
        wevtutil epl $LogName $ExportPath

        if (Test-Path $ExportPath) {
            Write-EnhancedLog -Message "Event log '$LogName' exported to '$ExportPath'" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
        else {
            Write-EnhancedLog -Message "Event log '$LogName' not exported: File does not exist at '$ExportPath'" -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
        }
    }
    catch {
        Write-EnhancedLog -Message "Error exporting event log '$LogName': $($_.Exception.Message)" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    }
}

# # Example usage
# $LogName = 'CreateNewHyperV_VMLog'
# # $ExportPath = 'Path\to\your\exported\eventlog.evtx'
# $ExportPath = "C:\code\CreateNewHyperV_VM\exports\Logs\$logname.evtx"
# Export-EventLog -LogName $LogName -ExportPath $ExportPath






#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################



Write-EnhancedLog -Message "Logging works" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)


###############################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################
#################################################################################################################################


function Validate-VHDMount {
    <#
    .SYNOPSIS
    Validates if a specified VHDX file is mounted.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    begin {
        Write-EnhancedLog -Message "Starting Validate-VHDMount function" -Level "INFO"
    }

    process {
        try {
            # Check if the VHDX is mounted
            $vhd = Get-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
            if ($vhd -and $vhd.Attached) {
                Write-EnhancedLog -Message "VHDX is mounted: $VHDXPath" -Level "INFO" -ForegroundColor Green
                return $true
            }
            else {
                Write-EnhancedLog -Message "VHDX is not mounted: $VHDXPath" -Level "INFO" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-EnhancedLog -Message "An error occurred while validating VHD mount status: $_" -Level "ERROR" -ForegroundColor Red
            throw $_
        }
    }

    end {
        Write-EnhancedLog -Message "Exiting Validate-VHDMount function" -Level "INFO"
    }
}

function Dismount-VHDX {
    <#
    .SYNOPSIS
    Dismounts a specified VHDX file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    begin {
        Write-EnhancedLog -Message "Starting Dismount-VHDX function" -Level "INFO"
    }

    process {
        try {
            $isMounted = Validate-VHDMount -VHDXPath $VHDXPath
            if ($isMounted) {
                Write-EnhancedLog -Message "Dismounting VHDX: $VHDXPath" -Level "INFO" -ForegroundColor Yellow
                Dismount-VHD -Path $VHDXPath
                Write-EnhancedLog -Message "VHDX dismounted successfully." -Level "INFO" -ForegroundColor Green
            }
            else {
                Write-EnhancedLog -Message "$VHDXPath is already dismounted" -Level "INFO" -ForegroundColor Yellow
            }
        }
        catch {
            Write-EnhancedLog -Message "An error occurred while dismounting the VHDX: $_" -Level "ERROR" -ForegroundColor Red
            throw $_
        }
    }

    end {
        Write-EnhancedLog -Message "Exiting Dismount-VHDX function" -Level "INFO"
    }
}








# Define the parameters to be used for the function
$DismountVHDXParams = @{
    VHDXPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_May_19_2024-test4.VHDX"
    # NewUnattendSource    = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\3.2-Inject-Unattend-VHDX\Unattend\unattend.xml"
    # ScriptPath           = "D:\Code\GitHub\CB\CB\Hyper-V\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows.ps1"
}

# Call the function to perform operations
Dismount-VHDX @DismountVHDXParams

















function Get-NextVMNamePrefix {
    # No need for a naming pattern parameter anymore
    # Load the Hyper-V module
    # Import-Module Hyper-V -ErrorAction SilentlyContinue

    # Get all VMs, sort them by CreationTime in descending order to get the most recent one first
    $mostRecentVM = Get-VM | Sort-Object -Property CreationTime -Descending | Select-Object -First 1

    # Initialize the prefix number
    $prefixNumber = 0

    if ($null -ne $mostRecentVM) {
        # Extract the prefix number from the most recent VM's name
        # Assuming the VM name starts with a numeric prefix followed by a separator
        if ($mostRecentVM.Name -match '^\d+') {
            $prefixNumber = [int]$matches[0]
        }
    }

    # Increment the prefix number for the next VM
    $nextPrefixNumber = $prefixNumber + 1

    # Format the new prefix with the incremented number
    $newVMNamePrefix = '{0:D3} - BCFHT-EJ-Win11-SAML-VPN-FortiClient -' -f $nextPrefixNumber

    return $newVMNamePrefix
}

# Usage example:
$VMNamePrefix = Get-NextVMNamePrefix
# Write-Host "The next VM name prefix should be: $VMNamePrefix"

# Assuming Write-EnhancedLog is a custom function that logs messages with additional details
Write-EnhancedLog -Message "The next VM name prefix should be: $VMNamePrefix" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)


# $DBG








# [string]$VMNamePrefix = $newVMNamePrefix


# [string]$VMNamePrefix = "Test021-AOllivierre-Sandbox-BYOD-WH4B-Passkeys-Entra-Reg"
# [string]$VMNamePrefix = "032 - KDENLIVE-WORKGROUPRENDERING" #increment the prefix number everytime
[string]$SwitchName = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
# [string]$InstallMediaPath = "D:\VM\Setup\ISO\RunPSOOBEv3.iso"
[string]$InstallMediaPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-PPKG.iso"
# [string]$InstallMediaPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
# [string]$InstallMediaPath = "D:\VM\Setup\ISO\Windows_10_22H2_July_29_2023.iso"
# [string]$InstallMediaPath = "D:\VM\Setup\iso\Windows_SERVER_2022_EVAL_x64FRE_en-us.iso"

trap {
    Write-EnhancedLog -Message "Error encountered: $_.Exception" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    exit 1
}

function Initialize-HyperVServices {
    Write-EnhancedLog -Message "Starting Initialize-HyperVServices function" -Level "INFO"
    if (Get-Service -DisplayName *hyper*) {
        Start-Service vmcompute -ErrorAction SilentlyContinue
        Start-Service vmms -ErrorAction SilentlyContinue
        Write-EnhancedLog -Message "Hyper-V services started" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }
    Write-EnhancedLog -Message "Exiting Initialize-HyperVServices function" -Level "INFO"
}

function CreateVMFolder {
    param(
        [string]$VMPath,
        [string]$VMName
    )
    Write-EnhancedLog -Message "Starting CreateVMFolder function" -Level "INFO"
    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    # Use Out-Null to suppress the output of New-Item
    New-Item -ItemType Directory -Force -Path $VMFullPath | Out-Null
    Write-EnhancedLog -Message "VM folder created at $VMFullPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting CreateVMFolder function" -Level "INFO"
    # Return only $VMFullPath
    return $VMFullPath
}


# function New-CustomVM {
#     param(
#         [string]$VMName,
#         [string]$VMFullPath,
#         [string]$differencingDiskPath,
#         [string]$SwitchName,
#         [int64]$MemoryStartupBytes = 4096MB,
#         [int64]$MemoryMinimumBytes = 4096MB,
#         [int64]$MemoryMaximumBytes = 16GB
#     )
#     Write-EnhancedLog -Message "Starting New-CustomVM function" -Level "INFO"
#     $NewVMSplat = @{
#         Generation         = 2
#         Path               = $VMFullPath
#         Name               = $VMName
#         NewVHDSizeBytes    = 100GB
#         NewVHDPath         = $differencingDiskPath
#         MemoryStartupBytes = $MemoryStartupBytes
#         SwitchName         = $SwitchName
#     }
#     New-VM @NewVMSplat

#     # Set dynamic memory
#     Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes $MemoryMinimumBytes -MaximumBytes $MemoryMaximumBytes -StartupBytes $MemoryStartupBytes

#     Write-EnhancedLog -Message "VM $VMName created with dynamic memory" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
#     Write-EnhancedLog -Message "Exiting New-CustomVM function" -Level "INFO"
# }










function New-CustomVMWithDifferencingDisk {
    param(
        [string]$VMName,
        [string]$VMFullPath,
        [string]$ParentVHDPath,
        [string]$DifferencingDiskPath,
        [string]$SwitchName,
        [int64]$MemoryStartupBytes = 4096MB,
        [int64]$MemoryMinimumBytes = 4096MB,
        [int64]$MemoryMaximumBytes = 16GB
    )

    Write-Output "Starting New-CustomVMWithDifferencingDisk function"

    # Create the VM without a VHD
    $NewVMSplat = @{
        Generation         = 2
        Path               = $VMFullPath
        Name               = $VMName
        MemoryStartupBytes = $MemoryStartupBytes
        SwitchName         = $SwitchName
        NoVHD              = $true
    }
    New-VM @NewVMSplat

    # Set dynamic memory
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes $MemoryMinimumBytes -MaximumBytes $MemoryMaximumBytes -StartupBytes $MemoryStartupBytes

    # Create a differencing disk
    New-VHD -Path $DifferencingDiskPath -ParentPath $ParentVHDPath -Differencing

    # Attach the differencing disk to the VM
    Add-VMHardDiskDrive -VMName $VMName -Path $DifferencingDiskPath

    # Configure additional VM settings (processors, TPM, etc.)
    # Set-VMProcessor -VMName $VMName -Count 2
    # Set-VMFirmware -VMName $VMName -EnableSecureBoot On -EnableTpm



    Write-EnhancedLog -Message "VM $VMName created with dynamic memory" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "VM $VMName created with a differencing disk based on $ParentVHDPath" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting New-CustomVM function" -Level "INFO"
}








function Add-DVDDriveToVM {
    param(
        [string]$VMName,
        [string]$InstallMediaPath
    )
    Write-EnhancedLog -Message "Starting Add-DVDDriveToVM function" -Level "INFO"
    Add-VMScsiController -VMName $VMName
    # Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath
    Write-EnhancedLog -Message "DVD drive added to $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting Add-DVDDriveToVM function" -Level "INFO"
}

function ConfigureVMBoot {
    param(
        [string]$VMName,
        [string]$DifferencingDiskPath
    )
    Write-EnhancedLog -Message "Starting ConfigureVMBoot function" -Level "INFO"


     # Set the differencing disk as the first boot device
    #  $bootOrder = Get-VMFirmware -VMName $VMName | Select-Object -ExpandProperty BootOrder
    #  $newBootOrder = $vhd, ($bootOrder | Where-Object { $_ -ne $vhd })
    #  Set-VMFirmware -VMName $VMName -BootOrder $newBootOrder

    # $DVDDrive = Get-VMDvdDrive -VMName $VMName
    # Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive


     # Get the Hard Drive you want to boot from
     $VHD = Get-VMHardDiskDrive -VMName $VMName | Where-Object { $_.Path -eq $DifferencingDiskPath }

     # Set the VHD as the first boot device
     Set-VMFirmware -VMName $VMName -FirstBootDevice $VHD

    Write-EnhancedLog -Message "VM Boot configured for $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting ConfigureVMBoot function" -Level "INFO"
}

function ConfigureVM {
    param(
        [string]$VMName
    )
    Write-EnhancedLog -Message "Starting ConfigureVM function" -Level "INFO"
    $ProcessorCount = 24
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount
    Set-VMMemory $VMName
    Write-EnhancedLog -Message "VM $VMName configured" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting ConfigureVM function" -Level "INFO"
}


function EnsureUntrustedGuardianExists {
    param (
        [string]$GuardianName = 'UntrustedGuardian'
    )

    Write-EnhancedLog -Message "Checking for the existence of the guardian: $GuardianName" -Level "INFO"

    try {
        $guardian = Get-HgsGuardian -Name $GuardianName -ErrorAction SilentlyContinue
        if ($null -eq $guardian) {
            Write-EnhancedLog -Message "Guardian $GuardianName not found. Creating..." -Level "WARNING"
            New-HgsGuardian -Name $GuardianName -GenerateCertificates
            Write-EnhancedLog -Message "Guardian $GuardianName created successfully" -Level "INFO"
        } else {
            Write-EnhancedLog -Message "Guardian $GuardianName already exists" -Level "INFO"
        }
    }
    catch {
        Write-EnhancedLog -Message "Error occurred while checking or creating the guardian: $_" -Level "ERROR"
        throw
    }
}



function EnableVMTPM {
    param(
        [string]$VMName
    )
    Write-EnhancedLog -Message "Starting Enable-VMTPM function" -Level "INFO"
    $owner = Get-HgsGuardian UntrustedGuardian
    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
    Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData
    Enable-VMTPM -VMName $VMName
    Write-EnhancedLog -Message "TPM enabled for $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting Enable-VMTPM function" -Level "INFO"
}

# Main Script Execution
Write-EnhancedLog -Message "Starting main script execution" -Level "INFO"
Initialize-HyperVServices

# Ensure the Untrusted Guardian exists
EnsureUntrustedGuardianExists

$Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$VMName = "$VMNamePrefix`_$Datetime"

$VMPath = "D:\VM"
$VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName

$differencing_VHDX_DiskPath = Join-Path -Path $VMFullPath -ChildPath "$VMName-diff.vhdx"

# $VMCreated = New-CustomVM -VMName $VMName -VMFullPath $VMFullPath -VHDPath $differencingDiskPath -SwitchName $SwitchName


# $VMCreated = New-CustomVMWithDifferencingDisk -VMName $VMName -VMFullPath $VMFullPath -ParentVHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX" -DifferencingDiskPath $differencing_VHDX_DiskPath -SwitchName $SwitchName
$VMCreated = New-CustomVMWithDifferencingDisk -VMName $VMName -VMFullPath $VMFullPath -ParentVHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-Enterprise.VHDX" -DifferencingDiskPath $differencing_VHDX_DiskPath -SwitchName $SwitchName





# # Example usage of the function
# New-CustomVMWithDifferencingDisk -VMName "Windows11AutopilotVM" `
#                                  -VMFullPath "D:\VMs\Windows11AutopilotVM" `
#                                  -ParentVHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX" `
#                                  -DifferencingDiskPath "D:\VMs\Windows11AutopilotVM\Windows11AutopilotVM-Diff.vhdx" `
#                                  -SwitchName "Default Switch"



# Define the parameters in a hashtable
$NewCustomVMWithDifferencingDiskvmParams = @{
    VMName               = $VMName
    VMFullPath           = $VMFullPath
    ParentVHDPath        = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
    # ParentVHDPath        = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    DifferencingDiskPath = $differencing_VHDX_DiskPath
    SwitchName           = $SwitchName
}

# Create the VM using the splatting operator
$VMCreated = New-CustomVMWithDifferencingDisk @NewCustomVMWithDifferencingDiskvmParams



if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
    Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    exit
}

if ($VMCreated) {
    # Proceed with other VM dependent functions
    # ...

    # Add-DVDDriveToVM -VMName $VMName -InstallMediaPath $InstallMediaPath
    ConfigureVMBoot -VMName $VMName -DifferencingDiskPath $differencing_VHDX_DiskPath
    ConfigureVM -VMName $VMName



    EnableVMTPM -VMName $VMName
    Write-EnhancedLog -Message "Completed main script execution" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}
else {
    Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    exit 1
}

# Stop transcript logging
Stop-Transcript


# Example usage
# $EvenlogExportPath = Join-Path -Path $logPath -ChildPath "$LogName-Transcript.evtx"
# Export-EventLog -LogName $LogName -ExportPath $EvenlogExportPath













function Validate-VMExists {
    param (
        [string]$VMName
    )

    # Check if the VM exists
    try {
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        return $true
    }
    catch {
        Write-EnhancedLog -Message "VM $VMName does not exist. $_" -Level "ERROR" -ForegroundColor Red
        return $false
    }
}

function Validate-VMStarted {
    param (
        [string]$VMName
    )

    # Check if the VM is running
    try {
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        if ($vm.State -eq 'Running') {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-EnhancedLog -Message "Failed to check the state of VM $VMName. $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Start-VMEnhanced {
    <#
    .SYNOPSIS
    Starts a specified VM if it exists and is not already running.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    try {
        # Validate if the VM exists
        if (-not (Validate-VMExists -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName does not exist. Exiting function." -Level "ERROR" -ForegroundColor Red
            return
        }

        # Check if the VM is already running
        if (Validate-VMStarted -VMName $VMName) {
            Write-EnhancedLog -Message "VM $VMName is already running." -Level "INFO" -ForegroundColor Yellow
        }
        else {
            # Start the VM
            Start-VM -Name $VMName -ErrorAction Stop
            Write-EnhancedLog -Message "VM $VMName has been started successfully." -Level "INFO" -ForegroundColor Green
        }
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while starting the VM $VMName. $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Connect-VMConsole {
    <#
    .SYNOPSIS
    Launches VMConnect to connect to the console of a specified VM.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        [string]$ServerName = "localhost",
        [int]$Count = 1
    )

    try {
        # Validate if the VM exists
        if (-not (Validate-VMExists -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName does not exist. Exiting function." -Level "ERROR" -ForegroundColor Red
            return
        }

        # Validate if the VM is running
        if (-not (Validate-VMStarted -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName is not running. Cannot connect to console." -Level "ERROR" -ForegroundColor Red
            return
        }

        # Construct the argument list for VMConnect
        $vmConnectArgs = "$ServerName `"$VMName`""
        if ($Count -gt 1) {
            $vmConnectArgs += " -C $Count"
        }

        # Debug output to check the constructed arguments
        Write-EnhancedLog -Message "VMConnect arguments: $vmConnectArgs" -Level "DEBUG" -ForegroundColor Yellow

        # Launch VMConnect
        Start-Process -FilePath "vmconnect.exe" -ArgumentList $vmConnectArgs -ErrorAction Stop
        Write-EnhancedLog -Message "VMConnect launched for VM $VMName on $ServerName with count $Count." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while launching VMConnect for VM $VMName. $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}


# Example usage with splatting
$StartVMParams = @{
    # VMName = "YourVMNameHere"
    VMName = $VMName
}

$ConnectVMConsoleParams = @{
    VMName     = $VMName
    ServerName = "localhost"
    Count      = 1

}

# Start the VM
Start-VMEnhanced @StartVMParams

# Connect to the VM console
Connect-VMConsole @ConnectVMConsoleParams
