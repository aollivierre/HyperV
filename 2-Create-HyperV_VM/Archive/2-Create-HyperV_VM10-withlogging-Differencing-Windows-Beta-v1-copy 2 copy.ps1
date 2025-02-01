
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
        Write-EventLog -LogName $LogName -Source $EventSource -EventId $EventID -Message $EventMessage -EntryType $EntryType
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
    Write-Host $formattedMessage
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

# Define helper functions
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$timestamp LAB-HV01: [$Level] $Message"
}

function Initialize-HyperVServices {
    Write-Log "Starting Initialize-HyperVServices function"
    if (Get-Service -DisplayName *hyper*) {
        Start-Service vmcompute -ErrorAction SilentlyContinue
        Start-Service vmms -ErrorAction SilentlyContinue
        Write-Log "Hyper-V services started"
    }
    Write-Log "Exiting Initialize-HyperVServices function"
}

function EnsureUntrustedGuardianExists {
    Write-Log "Checking for the existence of the guardian: UntrustedGuardian"
    try {
        $guardian = Get-HgsGuardian -Name "UntrustedGuardian" -ErrorAction SilentlyContinue
        if ($null -eq $guardian) {
            Write-Log "Guardian UntrustedGuardian not found. Creating..." "WARNING"
            New-HgsGuardian -Name "UntrustedGuardian" -GenerateCertificates
            Write-Log "Guardian UntrustedGuardian created successfully"
        } else {
            Write-Log "Guardian UntrustedGuardian already exists"
        }
    } catch {
        Write-Log "Error occurred while checking or creating the guardian: $_" "ERROR"
        throw
    }
}

function CreateVMFolder {
    param (
        [string]$VMPath,
        [string]$VMName
    )
    Write-Log "Starting CreateVMFolder function"
    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    New-Item -ItemType Directory -Force -Path $VMFullPath | Out-Null
    Write-Log "VM folder created at $VMFullPath"
    Write-Log "Exiting CreateVMFolder function"
    return $VMFullPath
}

function New-CustomVMWithDifferencingDisk {
    param (
        [string]$VMName,
        [string]$VMFullPath,
        [string]$ParentVHDPath,
        [string]$DifferencingDiskPath,
        [string]$SwitchName,
        [int64]$MemoryStartupBytes,
        [int64]$MemoryMinimumBytes,
        [int64]$MemoryMaximumBytes,
        [int]$Generation
    )

    Write-Log "Starting New-CustomVMWithDifferencingDisk function"

    $NewVMSplat = @{
        Generation         = $Generation
        Path               = $VMFullPath
        Name               = $VMName
        MemoryStartupBytes = $MemoryStartupBytes
        SwitchName         = $SwitchName
        NoVHD              = $true
    }
    Write-Log "Calling New-VM with parameters: $($NewVMSplat | Out-String)"
    New-VM @NewVMSplat

    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes $MemoryMinimumBytes -MaximumBytes $MemoryMaximumBytes -StartupBytes $MemoryStartupBytes

    New-VHD -Path $DifferencingDiskPath -ParentPath $ParentVHDPath -Differencing

    Add-VMHardDiskDrive -VMName $VMName -Path $DifferencingDiskPath

    Write-Log "VM $VMName created with dynamic memory and a differencing disk based on $ParentVHDPath"
    Write-Log "Exiting New-CustomVMWithDifferencingDisk function"
}

function Add-DVDDriveToVM {
    param (
        [string]$VMName,
        [string]$InstallMediaPath
    )
    Write-Log "Starting Add-DVDDriveToVM function"
    Add-VMScsiController -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath
    Write-Log "DVD drive added to $VMName"
    Write-Log "Exiting Add-DVDDriveToVM function"
}

function ConfigureVMBoot {
    param (
        [string]$VMName,
        [string]$DifferencingDiskPath
    )
    Write-Log "Starting ConfigureVMBoot function"
    $VHD = Get-VMHardDiskDrive -VMName $VMName | Where-Object { $_.Path -eq $DifferencingDiskPath }
    Set-VMFirmware -VMName $VMName -FirstBootDevice $VHD
    Write-Log "VM Boot configured for $VMName"
    Write-Log "Exiting ConfigureVMBoot function"
}

function ConfigureVM {
    param (
        [string]$VMName
    )
    Write-Log "Starting ConfigureVM function"
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count 2
    Set-VMMemory $VMName
    Write-Log "VM $VMName configured"
    Write-Log "Exiting ConfigureVM function"
}

function EnableVMTPM {
    param (
        [string]$VMName
    )
    Write-Log "Starting Enable-VMTPM function"
    $owner = Get-HgsGuardian UntrustedGuardian
    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
    Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData
    Enable-VMTPM -VMName $VMName
    Write-Log "TPM enabled for $VMName"
    Write-Log "Exiting Enable-VMTPM function"
}

# Main Script Execution
Write-Log "Starting main script execution"

Initialize-HyperVServices
EnsureUntrustedGuardianExists

$Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$VMNamePrefix = "Win11-UnattendXML-TEST"
$VMName = "$VMNamePrefix`_$Datetime"
$VMPath = "D:\VM"
$VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName
$DifferencingDiskPath = Join-Path -Path $VMFullPath -ChildPath "$VMName-diff.vhdx"

# Set parameters
$Params = @{
    VMName               = $VMName
    VMFullPath           = $VMFullPath
    ParentVHDPath        = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_May_19_2024-test4.VHDX"
    DifferencingDiskPath = $DifferencingDiskPath
    SwitchName           = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
    MemoryStartupBytes   = 4294967296
    MemoryMinimumBytes   = 4294967296
    MemoryMaximumBytes   = 17179869184
    Generation           = 2
}

Write-Log "Updated parameters for New-CustomVMWithDifferencingDisk:"
Write-Log "VMName: $($Params.VMName)"
Write-Log "VMFullPath: $($Params.VMFullPath)"
Write-Log "ParentVHDPath: $($Params.ParentVHDPath)"
Write-Log "DifferencingDiskPath: $($Params.DifferencingDiskPath)"
Write-Log "SwitchName: $($Params.SwitchName)"
Write-Log "MemoryStartupBytes: $($Params.MemoryStartupBytes)"
Write-Log "MemoryMinimumBytes: $($Params.MemoryMinimumBytes)"
Write-Log "MemoryMaximumBytes: $($Params.MemoryMaximumBytes)"
Write-Log "Generation: $($Params.Generation)"

# Create the VM
New-CustomVMWithDifferencingDisk @Params

# Additional configurations
Add-DVDDriveToVM -VMName $VMName -InstallMediaPath "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
ConfigureVMBoot -VMName $VMName -DifferencingDiskPath $DifferencingDiskPath
ConfigureVM -VMName $VMName
EnableVMTPM -VMName $VMName

Write-Log "Completed main script execution"
