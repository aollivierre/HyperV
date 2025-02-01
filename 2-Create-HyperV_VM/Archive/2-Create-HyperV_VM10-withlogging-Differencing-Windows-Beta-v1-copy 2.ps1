
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

# Define parameters to be used for the functions
$Params = @{
    General                         = @{
        VMPath             = "D:\VM"
        VMNamePattern      = '{0:D3} - Win11-UnattendXML-TEST -'
        MemoryStartupBytes = 4096MB
        MemoryMinimumBytes = 4096MB
        MemoryMaximumBytes = 16GB
        Generation         = 2
    }
    DismountVHDX                    = @{
        VHDXPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_May_19_2024-test4.VHDX"
    }
    NewCustomVMWithDifferencingDisk = @{
        ParentVHDPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_May_19_2024-test4.VHDX"
        SwitchName    = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
    }
    AddDVDDriveToVM                 = @{
        InstallMediaPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
    }
    ConfigureVMBoot                 = @{}
    ConfigureVM                     = @{}
    EnableVMTPM                     = @{}
    StartVMEnhanced                 = @{}
    ConnectVMConsole                = @{
        ServerName = "localhost"
        Count      = 1
    }
}

# Functions

function Validate-VHDMount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    begin {
        Write-EnhancedLog -Message "Starting Validate-VHDMount function" -Level "INFO"
    }

    process {
        try {
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

function Get-NextVMNamePrefix {
    param (
        [string]$VMNamePattern
    )

    $mostRecentVM = Get-VM | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    $prefixNumber = 0

    if ($null -ne $mostRecentVM -and $mostRecentVM.Name -match '^\d+') {
        $prefixNumber = [int]$matches[0]
    }

    $nextPrefixNumber = $prefixNumber + 1
    return $VMNamePattern -f $nextPrefixNumber
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
    param (
        [string]$VMPath,
        [string]$VMName
    )

    Write-EnhancedLog -Message "Starting CreateVMFolder function" -Level "INFO"
    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    New-Item -ItemType Directory -Force -Path $VMFullPath | Out-Null
    Write-EnhancedLog -Message "VM folder created at $VMFullPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting CreateVMFolder function" -Level "INFO"
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

    Write-EnhancedLog -Message "Starting New-CustomVMWithDifferencingDisk function" -Level "INFO"
    Write-EnhancedLog -Message "Parameters:" -Level "INFO"
    Write-EnhancedLog -Message "VMName: $VMName" -Level "INFO"
    Write-EnhancedLog -Message "VMFullPath: $VMFullPath" -Level "INFO"
    Write-EnhancedLog -Message "ParentVHDPath: $ParentVHDPath" -Level "INFO"
    Write-EnhancedLog -Message "DifferencingDiskPath: $DifferencingDiskPath" -Level "INFO"
    Write-EnhancedLog -Message "SwitchName: $SwitchName" -Level "INFO"
    Write-EnhancedLog -Message "MemoryStartupBytes: $MemoryStartupBytes" -Level "INFO"
    Write-EnhancedLog -Message "MemoryMinimumBytes: $MemoryMinimumBytes" -Level "INFO"
    Write-EnhancedLog -Message "MemoryMaximumBytes: $MemoryMaximumBytes" -Level "INFO"
    Write-EnhancedLog -Message "Generation: $Generation" -Level "INFO"

    try {
        $NewVMSplat = @{
            Generation         = $Generation
            Path               = $VMFullPath
            Name               = $VMName
            MemoryStartupBytes = $MemoryStartupBytes
            SwitchName         = $SwitchName
            NoVHD              = $true
        }

        Write-EnhancedLog -Message "Calling New-VM with parameters: $($NewVMSplat | Out-String)" -Level "INFO"
        New-VM @NewVMSplat

        Write-EnhancedLog -Message "Setting VM memory" -Level "INFO"
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes $MemoryMinimumBytes -MaximumBytes $MemoryMaximumBytes -StartupBytes $MemoryStartupBytes

        Write-EnhancedLog -Message "Creating differencing disk" -Level "INFO"
        New-VHD -Path $DifferencingDiskPath -ParentPath $ParentVHDPath -Differencing

        Write-EnhancedLog -Message "Adding hard disk drive to VM" -Level "INFO"
        Add-VMHardDiskDrive -VMName $VMName -Path $DifferencingDiskPath

        Write-EnhancedLog -Message "VM $VMName created with dynamic memory and a differencing disk based on $ParentVHDPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }
    catch {
        Write-EnhancedLog -Message "An error occurred in New-CustomVMWithDifferencingDisk: $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
    finally {
        Write-EnhancedLog -Message "Exiting New-CustomVMWithDifferencingDisk function" -Level "INFO"
    }
}


function Add-DVDDriveToVM {
    param (
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
    param (
        [string]$VMName,
        [string]$DifferencingDiskPath
    )

    Write-EnhancedLog -Message "Starting ConfigureVMBoot function" -Level "INFO"
    $VHD = Get-VMHardDiskDrive -VMName $VMName | Where-Object { $_.Path -eq $DifferencingDiskPath }
    Set-VMFirmware -VMName $VMName -FirstBootDevice $VHD
    Write-EnhancedLog -Message "VM Boot configured for $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Exiting ConfigureVMBoot function" -Level "INFO"
}

function ConfigureVM {
    param (
        [string]$VMName
    )

    Write-EnhancedLog -Message "Starting ConfigureVM function" -Level "INFO"
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count 24
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
        }
        else {
            Write-EnhancedLog -Message "Guardian $GuardianName already exists" -Level "INFO"
        }
    }
    catch {
        Write-EnhancedLog -Message "Error occurred while checking or creating the guardian: $_" -Level "ERROR"
        throw
    }
}

function EnableVMTPM {
    param (
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

function Validate-VMExists {
    param (
        [string]$VMName
    )

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

    try {
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        return ($vm.State -eq 'Running')
    }
    catch {
        Write-EnhancedLog -Message "Failed to check the state of VM $VMName. $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}

function Start-VMEnhanced {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    try {
        if (-not (Validate-VMExists -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName does not exist. Exiting function." -Level "ERROR" -ForegroundColor Red
            return
        }

        if (Validate-VMStarted -VMName $VMName) {
            Write-EnhancedLog -Message "VM $VMName is already running." -Level "INFO" -ForegroundColor Yellow
        }
        else {
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
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        [string]$ServerName = "localhost",
        [int]$Count = 1
    )

    try {
        if (-not (Validate-VMExists -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName does not exist. Exiting function." -Level "ERROR" -ForegroundColor Red
            return
        }

        if (-not (Validate-VMStarted -VMName $VMName)) {
            Write-EnhancedLog -Message "VM $VMName is not running. Cannot connect to console." -Level "ERROR" -ForegroundColor Red
            return
        }

        $vmConnectArgs = "$ServerName `"$VMName`""
        if ($Count -gt 1) {
            $vmConnectArgs += " -C $Count"
        }

        Write-EnhancedLog -Message "VMConnect arguments: $vmConnectArgs" -Level "DEBUG" -ForegroundColor Yellow
        Start-Process -FilePath "vmconnect.exe" -ArgumentList $vmConnectArgs -ErrorAction Stop
        Write-EnhancedLog -Message "VMConnect launched for VM $VMName on $ServerName with count $Count." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while launching VMConnect for VM $VMName. $_" -Level "ERROR" -ForegroundColor Red
        throw $_
    }
}


#Region Main Script Execution
Write-EnhancedLog -Message "Starting main script execution" -Level "INFO"
Initialize-HyperVServices

EnsureUntrustedGuardianExists

$Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$VMNamePrefix = Get-NextVMNamePrefix -VMNamePattern $Params.General.VMNamePattern
$VMName = "$VMNamePrefix`_$Datetime"
$VMPath = $Params.General.VMPath
$VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName

# Update dynamic parameters with the generated VM name and paths
$Params.NewCustomVMWithDifferencingDisk.VMName = $VMName
$Params.NewCustomVMWithDifferencingDisk.VMFullPath = $VMFullPath
$Params.NewCustomVMWithDifferencingDisk.DifferencingDiskPath = Join-Path -Path $VMFullPath -ChildPath "$VMName-diff.vhdx"
$Params.NewCustomVMWithDifferencingDisk.MemoryStartupBytes = $Params.General.MemoryStartupBytes
$Params.NewCustomVMWithDifferencingDisk.MemoryMinimumBytes = $Params.General.MemoryMinimumBytes
$Params.NewCustomVMWithDifferencingDisk.MemoryMaximumBytes = $Params.General.MemoryMaximumBytes
$Params.NewCustomVMWithDifferencingDisk.Generation = $Params.General.Generation




# Helper function to log parameter values
function Log-Params {
    param (
        [hashtable]$Params
    )

    foreach ($key in $Params.Keys) {
        Write-EnhancedLog -Message "$key $($Params[$key])" -Level "INFO"
    }
}

# Generate the VM name and paths
$Datetime = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$VMNamePrefix = Get-NextVMNamePrefix
$VMName = "$VMNamePrefix`_$Datetime"
$VMPath = $Params.General.VMPath
$VMFullPath = CreateVMFolder -VMPath $VMPath -VMName $VMName
$DifferencingDiskPath = Join-Path -Path $VMFullPath -ChildPath "$VMName-diff.vhdx"

# Update dynamic parameters with the generated VM name and paths
$Params.NewCustomVMWithDifferencingDisk.VMName = $VMName
$Params.NewCustomVMWithDifferencingDisk.VMFullPath = $VMFullPath
$Params.NewCustomVMWithDifferencingDisk.DifferencingDiskPath = $DifferencingDiskPath
$Params.NewCustomVMWithDifferencingDisk.SwitchName = $Params.General.SwitchName
$Params.NewCustomVMWithDifferencingDisk.MemoryStartupBytes = $Params.General.MemoryStartupBytes
$Params.NewCustomVMWithDifferencingDisk.MemoryMinimumBytes = $Params.General.MemoryMinimumBytes
$Params.NewCustomVMWithDifferencingDisk.MemoryMaximumBytes = $Params.General.MemoryMaximumBytes
$Params.NewCustomVMWithDifferencingDisk.Generation = $Params.General.Generation

# Log the updated parameters for debugging
Write-EnhancedLog -Message "Updated parameters for New-CustomVMWithDifferencingDisk:" -Level "INFO"
Log-Params -Params $Params.NewCustomVMWithDifferencingDisk

# Create the VM using the splatting operator
$VMCreated = New-CustomVMWithDifferencingDisk @($Params.NewCustomVMWithDifferencingDisk)

if (-not (Get-VM -Name $Params.NewCustomVMWithDifferencingDisk.VMName -ErrorAction SilentlyContinue)) {
    Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR" -ForegroundColor Red
    exit
}

if ($VMCreated) {
    # Update parameters dynamically before function calls
    $Params.AddDVDDriveToVM.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName
    $Params.ConfigureVMBoot.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName
    $Params.ConfigureVMBoot.DifferencingDiskPath = $Params.NewCustomVMWithDifferencingDisk.DifferencingDiskPath
    $Params.ConfigureVM.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName
    $Params.EnableVMTPM.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName
    $Params.StartVMEnhanced.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName
    $Params.ConnectVMConsole.VMName = $Params.NewCustomVMWithDifferencingDisk.VMName

    # Perform operations using updated parameters
    Add-DVDDriveToVM @($Params.AddDVDDriveToVM)
    ConfigureVMBoot @($Params.ConfigureVMBoot)
    ConfigureVM @($Params.ConfigureVM)
    EnableVMTPM @($Params.EnableVMTPM)
    Write-EnhancedLog -Message "Completed main script execution" -Level "INFO" -ForegroundColor Green
}
else {
    Write-EnhancedLog -Message "VM creation failed. Exiting script." -Level "ERROR" -ForegroundColor Red
    exit 1
}

# Start the VM
Start-VMEnhanced @($Params.StartVMEnhanced)

# Connect to the VM console
Connect-VMConsole @($Params.ConnectVMConsole)

# Stop transcript logging
Stop-Transcript