
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


[string]$VMNamePrefix = "Nova-AADJ-Abdullah"
[string]$SwitchName = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
[string]$InstallMediaPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"

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


function New-CustomVM {
    param(
        [string]$VMName,
        [string]$VMFullPath,
        [string]$VHDPath,
        [string]$SwitchName
    )
    Write-EnhancedLog -Message "Starting New-CustomVM function" -Level "INFO"
    $NewVMSplat = @{
        Generation         = 2
        Path               = $VMFullPath
        Name               = $VMName
        NewVHDSizeBytes    = 30GB
        NewVHDPath         = $VHDPath
        MemoryStartupBytes = 6GB
        SwitchName         = $SwitchName
    }
    New-VM @NewVMSplat
    Write-EnhancedLog -Message "VM $VMName created" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting New-CustomVM function" -Level "INFO"
}

function Add-DVDDriveToVM {
    param(
        [string]$VMName,
        [string]$InstallMediaPath
    )
    Write-EnhancedLog -Message "Starting Add-DVDDriveToVM function" -Level "INFO"
    Add-VMScsiController -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath
    Write-EnhancedLog -Message "DVD drive added to $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting Add-DVDDriveToVM function" -Level "INFO"
}

function ConfigureVMBoot {
    param(
        [string]$VMName
    )
    Write-EnhancedLog -Message "Starting ConfigureVMBoot function" -Level "INFO"
    $DVDDrive = Get-VMDvdDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive
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



$Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$VMName = "$VMNamePrefix`_$Datetime"

$VMPath = "C:\VM"
$VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName

$VHDPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"

$VMCreated = New-CustomVM -VMName $VMName -VMFullPath $VMFullPath -VHDPath $VHDPath -SwitchName $SwitchName

if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
    Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    exit
}

if ($VMCreated) {
    # Proceed with other VM dependent functions
    # ...

    Add-DVDDriveToVM -VMName $VMName -InstallMediaPath $InstallMediaPath
    ConfigureVMBoot -VMName $VMName
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
$EvenlogExportPath = Join-Path -Path $logPath -ChildPath "$LogName-Transcript.evtx"
Export-EventLog -LogName $LogName -ExportPath $EvenlogExportPath