#requires -Version 5.1
#requires -Module Hyper-V
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced Hyper-V VM creation script with smart defaults and minimal configuration requirements.

.DESCRIPTION
    This script creates Hyper-V virtual machines with intelligent defaults:
    - Automatically selects best drive based on available space
    - Supports "All Cores" for processor count
    - Supports "Default Switch" for network configuration
    - Automatically creates standard folder structure
    - Calculates memory based on available system resources
    - Requires minimal configuration input

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

.PARAMETER MinimumFreeSpaceGB
    Minimum free space required on drive for VM operations (in GB).

.PARAMETER AutoSelectDrive
    If true, automatically selects the drive with most free space without prompting.

.PARAMETER UseSmartDefaults
    If true, uses intelligent defaults for all possible settings.

.EXAMPLE
    .\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1 -UseSmartDefaults

.NOTES
    Version: 5.0.0
    Author: Enhanced for minimal configuration requirements
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
    [uint64]$DefaultVHDSize = 100GB,
    
    # Drive Selection Configuration
    [Parameter(HelpMessage = "Minimum free space required on drive in GB")]
    [int]$MinimumFreeSpaceGB = 50,
    
    [Parameter(HelpMessage = "Automatically select drive with most free space")]
    [switch]$AutoSelectDrive,
    
    [Parameter(HelpMessage = "Use intelligent defaults for all possible settings")]
    [switch]$UseSmartDefaults
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

#region System Information Functions
function Get-SystemResources {
    <#
    .SYNOPSIS
        Gets system resource information including CPU, memory, and storage.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Gathering system resource information..." -Level 'INFO'
    
    # Get CPU information
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $totalCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    $logicalProcessors = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    
    # Get memory information
    $memory = Get-CimInstance -ClassName Win32_ComputerSystem
    $totalMemoryGB = [Math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
    
    # Get available memory
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $availableMemoryGB = [Math]::Round($os.FreePhysicalMemory / 1MB / 1024, 2)
    
    $resources = [PSCustomObject]@{
        TotalCores = $totalCores
        LogicalProcessors = $logicalProcessors
        TotalMemoryGB = $totalMemoryGB
        AvailableMemoryGB = $availableMemoryGB
        CPUName = $cpu.Name
    }
    
    Write-Log -Message "System Resources: $($totalCores) cores ($($logicalProcessors) logical processors), $($totalMemoryGB)GB RAM ($($availableMemoryGB)GB available)" -Level 'INFO'
    
    return $resources
}

function Get-ProcessorCount {
    <#
    .SYNOPSIS
        Converts processor count value to actual number, supporting "All Cores" keyword.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ProcessorValue
    )
    
    if ($ProcessorValue -eq "All Cores" -or $ProcessorValue -eq "All") {
        $resources = Get-SystemResources
        $processors = $resources.LogicalProcessors
        Write-Log -Message "Using all available logical processors: $processors" -Level 'INFO'
        return $processors
    }
    elseif ($ProcessorValue -match '^\d+$') {
        return [int]$ProcessorValue
    }
    else {
        Write-Log -Message "Invalid processor value: $ProcessorValue. Using 2 cores as default." -Level 'WARNING'
        return 2
    }
}

function Get-SmartMemoryAllocation {
    <#
    .SYNOPSIS
        Calculates smart memory allocation based on available system resources.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RequestedMemory,
        
        [Parameter()]
        [ValidateSet('Minimum', 'Balanced', 'Maximum')]
        [string]$AllocationMode = 'Balanced'
    )
    
    $resources = Get-SystemResources
    $availableGB = $resources.AvailableMemoryGB
    
    # Calculate allocations based on mode
    switch ($AllocationMode) {
        'Minimum' {
            $startupGB = [Math]::Min(2, [Math]::Floor($availableGB * 0.2))
            $minimumGB = 1
            $maximumGB = [Math]::Min(8, [Math]::Floor($availableGB * 0.5))
        }
        'Balanced' {
            $startupGB = [Math]::Min(4, [Math]::Floor($availableGB * 0.3))
            $minimumGB = 2
            $maximumGB = [Math]::Min(16, [Math]::Floor($availableGB * 0.7))
        }
        'Maximum' {
            $startupGB = [Math]::Min(8, [Math]::Floor($availableGB * 0.5))
            $minimumGB = 4
            $maximumGB = [Math]::Floor($availableGB * 0.8)
        }
    }
    
    Write-Log -Message "Smart memory allocation: Startup=${startupGB}GB, Min=${minimumGB}GB, Max=${maximumGB}GB" -Level 'INFO'
    
    return @{
        StartupBytes = "${startupGB}GB"
        MinimumBytes = "${minimumGB}GB"
        MaximumBytes = "${maximumGB}GB"
    }
}
#endregion System Information Functions

#region Drive Management Functions
function Get-AvailableDrives {
    <#
    .SYNOPSIS
        Gets all available drives with their free space information.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Scanning available drives..." -Level 'INFO'
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Used -ne $null -and $_.Free -ne $null
    } | ForEach-Object {
        [PSCustomObject]@{
            DriveLetter = $_.Name
            FreeSpaceGB = [Math]::Round($_.Free / 1GB, 2)
            TotalSpaceGB = [Math]::Round(($_.Used + $_.Free) / 1GB, 2)
            UsedSpaceGB = [Math]::Round($_.Used / 1GB, 2)
            PercentFree = [Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2)
        }
    } | Sort-Object FreeSpaceGB -Descending
    
    # Ensure we have an array for proper count
    $driveArray = @($drives)
    Write-Log -Message "Found $($driveArray.Count) drives" -Level 'DEBUG'
    return $driveArray
}

function Select-BestDrive {
    <#
    .SYNOPSIS
        Selects the best drive based on available space and minimum requirements.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$MinimumFreeSpaceGB,
        
        [Parameter()]
        [string]$PreferredDrive
    )
    
    $drives = Get-AvailableDrives
    
    # Check if preferred drive meets requirements
    if ($PreferredDrive) {
        $preferred = $drives | Where-Object { $_.DriveLetter -eq $PreferredDrive }
        if ($preferred -and $preferred.FreeSpaceGB -ge $MinimumFreeSpaceGB) {
            Write-Log -Message "Preferred drive $PreferredDrive meets requirements" -Level 'INFO'
            return $preferred
        }
    }
    
    # Get drives that meet minimum requirements
    $suitableDrives = $drives | Where-Object { $_.FreeSpaceGB -ge $MinimumFreeSpaceGB }
    
    if ($suitableDrives.Count -eq 0) {
        Write-Log -Message "No drives found with minimum $MinimumFreeSpaceGB GB free space" -Level 'ERROR'
        throw "Insufficient disk space on all drives"
    }
    
    # Return drive with most free space
    return $suitableDrives | Select-Object -First 1
}

function Show-DriveSelectionMenu {
    <#
    .SYNOPSIS
        Shows an interactive menu for drive selection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SelectedDrive,
        
        [Parameter(Mandatory=$true)]
        [int]$MinimumFreeSpaceGB
    )
    
    Write-Host "`n=== Drive Selection ===" -ForegroundColor Cyan
    Write-Host "Recommended drive: $($SelectedDrive.DriveLetter): ($('{0:N2}' -f $SelectedDrive.FreeSpaceGB) GB free)" -ForegroundColor Green
    Write-Host "`nAll available drives:" -ForegroundColor Yellow
    
    $drives = Get-AvailableDrives
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $drive = $drives[$i]
        $meetsReq = if ($drive.FreeSpaceGB -ge $MinimumFreeSpaceGB) { "[OK]" } else { "[X]" }
        $color = if ($drive.FreeSpaceGB -ge $MinimumFreeSpaceGB) { "White" } else { "DarkGray" }
        
        Write-Host ("  [{0}] {1}: - {2:N2} GB free of {3:N2} GB ({4:N1}% free) {5}" -f 
            ($i + 1), 
            $drive.DriveLetter, 
            $drive.FreeSpaceGB, 
            $drive.TotalSpaceGB, 
            $drive.PercentFree,
            $meetsReq
        ) -ForegroundColor $color
    }
    
    Write-Host "`n[A] Accept recommended drive ($($SelectedDrive.DriveLetter):)" -ForegroundColor Green
    Write-Host "[1-$($drives.Count)] Select a different drive" -ForegroundColor Yellow
    Write-Host "[Q] Quit" -ForegroundColor Red
    
    do {
        $choice = Read-Host "`nYour choice"
        
        if ($choice -match '^[Aa]$') {
            return $SelectedDrive
        }
        elseif ($choice -match '^[Qq]$') {
            Write-Log -Message "User cancelled drive selection" -Level 'WARNING'
            exit 0
        }
        elseif ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $drives.Count) {
                $selected = $drives[$index]
                if ($selected.FreeSpaceGB -lt $MinimumFreeSpaceGB) {
                    Write-Host "Warning: Selected drive has less than $MinimumFreeSpaceGB GB free space!" -ForegroundColor Red
                    $confirm = Read-Host "Continue anyway? (Y/N)"
                    if ($confirm -match '^[Yy]') {
                        return $selected
                    }
                }
                else {
                    return $selected
                }
            }
            else {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            }
        }
        else {
            Write-Host "Invalid input. Please try again." -ForegroundColor Red
        }
    } while ($true)
}

function Get-SmartPaths {
    <#
    .SYNOPSIS
        Creates intelligent default paths based on selected drive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        
        [Parameter()]
        [hashtable]$Config = @{}
    )
    
    Write-Log -Message "Creating smart paths for drive $DriveLetter" -Level 'INFO'
    
    # Define standard folder structure
    $smartPaths = @{
        VMPath = "${DriveLetter}:\VMs"
        TemplatesPath = "${DriveLetter}:\VMs\Templates"
        ISOPath = "${DriveLetter}:\VMs\ISOs"
        ExportPath = "${DriveLetter}:\VMs\Exports"
        CheckpointPath = "${DriveLetter}:\VMs\Checkpoints"
    }
    
    # Create directories if they don't exist
    foreach ($pathKey in $smartPaths.Keys) {
        $path = $smartPaths[$pathKey]
        if (-not (Test-Path $path)) {
            try {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Log -Message "Created directory: $path" -Level 'INFO'
            }
            catch {
                Write-Log -Message "Could not create directory: $path" -Level 'WARNING'
            }
        }
    }
    
    # Merge with existing config (existing values take precedence)
    # Create a copy of keys to avoid modification during enumeration
    $configKeys = @($Config.Keys)
    foreach ($key in $configKeys) {
        if ($Config[$key] -and $Config[$key] -ne "") {
            # If the config has a value, update it with the new drive letter
            if ($key -match 'Path$' -and $Config[$key] -match '^[A-Za-z]:') {
                $Config[$key] = $Config[$key] -replace '^[A-Za-z]:', "${DriveLetter}:"
            }
        }
    }
    
    # Add smart paths for missing values (but not VHDXPath as it should be a file, not a directory)
    $smartPathKeys = @($smartPaths.Keys)
    foreach ($key in $smartPathKeys) {
        if (-not $Config.ContainsKey($key) -or [string]::IsNullOrEmpty($Config[$key])) {
            # Don't add VHDXPath or ParentVHDXPath from smart paths
            if ($key -ne 'VHDXPath' -and $key -ne 'ParentVHDXPath') {
                $Config[$key] = $smartPaths[$key]
            }
        }
    }
    
    return $Config
}
#endregion Drive Management Functions

#region Network Functions
function Get-SmartVirtualSwitch {
    <#
    .SYNOPSIS
        Intelligently selects or creates a virtual switch.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RequestedSwitch,
        
        [Parameter()]
        [ValidateSet('External', 'Internal', 'Private')]
        [string]$PreferredType = 'External'
    )
    
    if ($RequestedSwitch -eq "Default Switch" -or $RequestedSwitch -eq "Default" -or [string]::IsNullOrEmpty($RequestedSwitch)) {
        Write-Log -Message "Selecting best available switch..." -Level 'INFO'
        
        # First, check if Default Switch exists (Windows 10 1709+)
        $defaultSwitch = Get-VMSwitch | Where-Object { $_.Name -eq "Default Switch" }
        if ($defaultSwitch) {
            Write-Log -Message "Using built-in Default Switch" -Level 'INFO'
            return "Default Switch"
        }
        
        # Get all switches
        $switches = Get-VMSwitch
        
        if ($switches.Count -eq 0) {
            Write-Log -Message "No virtual switches found. Creating one..." -Level 'WARNING'
            
            # Get physical network adapters
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }
            
            if ($adapters.Count -gt 0) {
                $adapter = $adapters | Sort-Object LinkSpeed -Descending | Select-Object -First 1
                $switchName = "Auto-Created External Switch"
                
                try {
                    New-VMSwitch -Name $switchName -NetAdapterName $adapter.Name -AllowManagementOS $true
                    Write-Log -Message "Created external switch: $switchName" -Level 'INFO'
                    return $switchName
                }
                catch {
                    Write-Log -Message "Could not create external switch: $_" -Level 'WARNING'
                }
            }
            
            # Fall back to internal switch
            $switchName = "Auto-Created Internal Switch"
            New-VMSwitch -Name $switchName -SwitchType Internal
            Write-Log -Message "Created internal switch: $switchName" -Level 'INFO'
            return $switchName
        }
        
        # Prefer external switches
        $externalSwitches = $switches | Where-Object { $_.SwitchType -eq 'External' }
        
        # If multiple external switches exist, let user choose
        if ($externalSwitches.Count -gt 1) {
            Write-Host "`n=== Multiple Virtual Switches Found ===" -ForegroundColor Yellow
            Write-Host "Please select a virtual switch:" -ForegroundColor Yellow
            
            for ($i = 0; $i -lt $externalSwitches.Count; $i++) {
                $sw = $externalSwitches[$i]
                Write-Host "[$($i+1)] $($sw.Name) (External)" -ForegroundColor White
            }
            
            # If using smart defaults, auto-select the first one
            if ($script:UseSmartDefaults) {
                Write-Host "`nAuto-selecting first external switch due to -UseSmartDefaults" -ForegroundColor Cyan
                $selected = $externalSwitches | Select-Object -First 1
                Write-Log -Message "Auto-selected external switch: $($selected.Name)" -Level 'INFO'
                return $selected.Name
            }
            
            do {
                $choice = Read-Host "`nSelect switch (1-$($externalSwitches.Count))"
                if ($choice -match '^\d+$') {
                    $index = [int]$choice - 1
                    if ($index -ge 0 -and $index -lt $externalSwitches.Count) {
                        $selected = $externalSwitches[$index]
                        Write-Log -Message "User selected external switch: $($selected.Name)" -Level 'INFO'
                        return $selected.Name
                    }
                }
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            } while ($true)
        }
        elseif ($externalSwitches.Count -eq 1) {
            $selected = $externalSwitches | Select-Object -First 1
            Write-Log -Message "Selected external switch: $($selected.Name)" -Level 'INFO'
            return $selected.Name
        }
        
        # Fall back to any switch
        if ($switches.Count -gt 0) {
            $selected = $switches | Select-Object -First 1
            Write-Log -Message "Selected switch: $($selected.Name)" -Level 'INFO'
            return $selected.Name
        }
    }
    else {
        # User specified a switch name
        return $RequestedSwitch
    }
}
#endregion Network Functions

#region Configuration Processing
function Process-SmartConfiguration {
    <#
    .SYNOPSIS
        Processes configuration with smart defaults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory=$true)]
        [string]$SelectedDrive
    )
    
    Write-Log -Message "Processing configuration with smart defaults..." -Level 'INFO'
    
    # Process processor count
    if ($Config.ContainsKey('ProcessorCount')) {
        $Config.ProcessorCount = Get-ProcessorCount -ProcessorValue $Config.ProcessorCount
    }
    else {
        # Default to half of available cores
        $resources = Get-SystemResources
        $Config.ProcessorCount = [Math]::Max(2, [Math]::Floor($resources.TotalCores / 2))
    }
    
    # Process memory settings
    if (-not $Config.ContainsKey('MemoryStartupBytes') -or 
        -not $Config.ContainsKey('MemoryMinimumBytes') -or 
        -not $Config.ContainsKey('MemoryMaximumBytes')) {
        
        $memorySettings = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
        
        if (-not $Config.ContainsKey('MemoryStartupBytes')) {
            $Config.MemoryStartupBytes = $memorySettings.StartupBytes
        }
        if (-not $Config.ContainsKey('MemoryMinimumBytes')) {
            $Config.MemoryMinimumBytes = $memorySettings.MinimumBytes
        }
        if (-not $Config.ContainsKey('MemoryMaximumBytes')) {
            $Config.MemoryMaximumBytes = $memorySettings.MaximumBytes
        }
    }
    
    # Process network switch
    if ($Config.ContainsKey('SwitchName')) {
        $Config.SwitchName = Get-SmartVirtualSwitch -RequestedSwitch $Config.SwitchName
    }
    else {
        $Config.SwitchName = Get-SmartVirtualSwitch -RequestedSwitch "Default Switch"
    }
    
    # Apply smart paths
    $Config = Get-SmartPaths -DriveLetter $SelectedDrive -Config $Config
    
    # Validate critical paths exist
    if ($Config.InstallMediaPath -and -not (Test-Path $Config.InstallMediaPath)) {
        Write-Log -Message "ISO file not found: $($Config.InstallMediaPath)" -Level 'WARNING'
        
        if (-not $script:UseSmartDefaults) {
            Write-Host "`nISO file not found at: $($Config.InstallMediaPath)" -ForegroundColor Yellow
            $newPath = Read-Host "Enter correct ISO path (or press Enter to skip)"
            if ($newPath) {
                $Config.InstallMediaPath = $newPath
            }
            else {
                # User chose to skip - remove ISO path
                $Config.Remove('InstallMediaPath')
                Write-Log -Message "User skipped ISO path. Will create VM without ISO." -Level 'INFO'
            }
        }
        else {
            # In non-interactive mode, try to find any ISO in common locations
            $isoSearchPaths = @(
                "$SelectedDrive`:\VM\ISO",
                "$SelectedDrive`:\VM\ISOs", 
                "$SelectedDrive`:\VM\Setup\ISO",
                "$SelectedDrive`:\ISOs"
            )
            
            foreach ($searchPath in $isoSearchPaths) {
                if (Test-Path $searchPath) {
                    $foundIsos = Get-ChildItem -Path $searchPath -Filter "*.iso" | Select-Object -First 1
                    if ($foundIsos) {
                        $Config.InstallMediaPath = $foundIsos.FullName
                        Write-Log -Message "Auto-selected ISO: $($Config.InstallMediaPath)" -Level 'INFO'
                        break
                    }
                }
            }
        }
    }
    
    # Validate VHDX path if specified
    if ($Config.VHDXPath -and -not (Test-Path $Config.VHDXPath)) {
        Write-Log -Message "VHDX file not found: $($Config.VHDXPath)" -Level 'WARNING'
        
        if (-not $script:UseSmartDefaults) {
            Write-Host "`nVHDX file not found at: $($Config.VHDXPath)" -ForegroundColor Yellow
            $newPath = Read-Host "Enter correct VHDX path (or press Enter to create new disk)"
            if ($newPath) {
                $Config.VHDXPath = $newPath
            }
            else {
                $Config.Remove('VHDXPath')
            }
        }
        else {
            # In non-interactive mode, remove the VHDX path to create a new disk
            Write-Log -Message "VHDX not found. Will create new disk instead." -Level 'INFO'
            $Config.Remove('VHDXPath')
        }
    }
    
    # Set other smart defaults
    if (-not $Config.ContainsKey('Generation')) {
        $Config.Generation = 2  # Default to Gen 2 for modern features
    }
    
    if (-not $Config.ContainsKey('EnableDynamicMemory')) {
        $Config.EnableDynamicMemory = $true
    }
    
    if (-not $Config.ContainsKey('EnableVirtualizationExtensions')) {
        $Config.EnableVirtualizationExtensions = $false
    }
    
    if (-not $Config.ContainsKey('IncludeTPM')) {
        $Config.IncludeTPM = ($Config.Generation -eq 2)  # TPM only for Gen 2
    }
    
    return $Config
}

function Show-ConfigurationSummary {
    <#
    .SYNOPSIS
        Displays a summary of the final configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SelectedDrive
    )
    
    Write-Host "`n=== Final Configuration Summary ===" -ForegroundColor Cyan
    Write-Host "Drive:" -ForegroundColor Yellow
    Write-Host "  Selected: $($SelectedDrive.DriveLetter): ($('{0:N2}' -f $SelectedDrive.FreeSpaceGB) GB free)" -ForegroundColor White
    
    Write-Host "`nPaths:" -ForegroundColor Yellow
    Write-Host "  VM Location: $($Config.VMPath)" -ForegroundColor White
    if ($Config.VHDXPath) {
        Write-Host "  Template VHDX: $($Config.VHDXPath)" -ForegroundColor White
    }
    Write-Host "  ISO: $($Config.InstallMediaPath)" -ForegroundColor White
    
    Write-Host "`nResources:" -ForegroundColor Yellow
    Write-Host "  Processors: $($Config.ProcessorCount) cores" -ForegroundColor White
    Write-Host "  Memory: $($Config.MemoryStartupBytes) (Min: $($Config.MemoryMinimumBytes), Max: $($Config.MemoryMaximumBytes))" -ForegroundColor White
    
    if ($Config.EnableDataDisk) {
        Write-Host "`nData Disk:" -ForegroundColor Yellow
        Write-Host "  Type: $($Config.DataDiskType)" -ForegroundColor White
        if ($Config.DataDiskType -eq 'Differencing' -and $Config.DataDiskParentPath) {
            Write-Host "  Parent: $(Split-Path $Config.DataDiskParentPath -Leaf)" -ForegroundColor White
        }
        else {
            Write-Host "  Size: $([math]::Round($Config.DataDiskSize/1GB, 2)) GB" -ForegroundColor White
        }
    }
    
    Write-Host "`nNetwork:" -ForegroundColor Yellow
    Write-Host "  Switch: $($Config.SwitchName)" -ForegroundColor White
    
    Write-Host "`nVM Settings:" -ForegroundColor Yellow
    Write-Host "  Generation: $($Config.Generation)" -ForegroundColor White
    Write-Host "  Disk Type: $(if ($Config.VMType -eq 'Differencing') { 'Differencing Disk' } else { 'New Disk' })" -ForegroundColor White
    Write-Host "  Dynamic Memory: $($Config.EnableDynamicMemory)" -ForegroundColor White
    Write-Host "  TPM: $($Config.IncludeTPM)" -ForegroundColor White
    Write-Host "  Secure Boot: $(if ($Config.Generation -eq 2) { 'Enabled' } else { 'Not Available (Gen 1)' })" -ForegroundColor White
    Write-Host "===================================" -ForegroundColor Cyan
}
#endregion Configuration Processing

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
    
    # Show system information
    if ($UseSmartDefaults -or $EnvironmentMode -eq 'dev') {
        $resources = Get-SystemResources
        Write-Host "`n=== System Information ===" -ForegroundColor Cyan
        Write-Host "CPU: $($resources.CPUName)" -ForegroundColor White
        Write-Host "Total Cores: $($resources.TotalCores) (Logical: $($resources.LogicalProcessors))" -ForegroundColor White
        Write-Host "Total Memory: $($resources.TotalMemoryGB) GB (Available: $($resources.AvailableMemoryGB) GB)" -ForegroundColor White
        Write-Host "=========================" -ForegroundColor Cyan
    }
    
    # Get the configuration
    $getConfigParams = @{
        ConfigPath = $ConfigurationPath
    }
    
    # Add NonInteractive flag if using smart defaults
    if ($UseSmartDefaults) {
        $getConfigParams.NonInteractive = $true
    }
    
    $config = Get-VMConfiguration @getConfigParams
    
    # Verify configuration was loaded
    if (-not $config) {
        Write-Log -Message "Failed to load configuration" -Level "ERROR"
        exit 1
    }
    
    # Drive selection process
    Write-Log -Message "Starting drive selection process" -Level 'INFO'
    
    # Try to get preferred drive from config VMPath
    $preferredDrive = $null
    if ($config.VMPath -and $config.VMPath -match '^([A-Za-z]):') {
        $preferredDrive = $matches[1]
        Write-Log -Message "Preferred drive from config: $preferredDrive" -Level 'DEBUG'
    }
    
    # Select best drive
    try {
        $selectedDrive = Select-BestDrive -MinimumFreeSpaceGB $MinimumFreeSpaceGB -PreferredDrive $preferredDrive
        
        # Show drive selection menu unless auto-select is enabled
        if (-not $AutoSelectDrive -and -not $UseSmartDefaults) {
            $selectedDrive = Show-DriveSelectionMenu -SelectedDrive $selectedDrive -MinimumFreeSpaceGB $MinimumFreeSpaceGB
        }
        
        Write-Log -Message "Selected drive: $($selectedDrive.DriveLetter) with $($selectedDrive.FreeSpaceGB) GB free" -Level 'INFO'
    }
    catch {
        Write-Log -Message "Drive selection failed: $_" -Level 'ERROR'
        throw
    }
    
    # Process configuration with smart defaults
    $config = Process-SmartConfiguration -Config $config -SelectedDrive $selectedDrive.DriveLetter
    
    # If VMType is Differencing but VHDXPath is not set, set it from ParentVHDXPath
    if ($config.VMType -eq 'Differencing' -and $config.ContainsKey('ParentVHDXPath')) {
        if (-not $config.ContainsKey('VHDXPath') -or [string]::IsNullOrEmpty($config.VHDXPath)) {
            $config.VHDXPath = $config.ParentVHDXPath
            Write-Log -Message "Set VHDXPath from ParentVHDXPath for differencing disk" -Level 'INFO'
        }
        
        # Validate parent VHDX exists early
        if (-not (Test-Path $config.ParentVHDXPath)) {
            Write-Host "`nERROR: Parent VHDX file not found!" -ForegroundColor Red
            Write-Host "Expected location: $($config.ParentVHDXPath)" -ForegroundColor Yellow
            Write-Host "`nThe parent VHDX is required for creating differencing disks." -ForegroundColor White
            Write-Host "Please ensure the file exists at the specified location or update your configuration." -ForegroundColor White
            
            if (-not $UseSmartDefaults) {
                Write-Host "`nWould you like to:" -ForegroundColor Yellow
                Write-Host "[1] Enter a different parent VHDX path" -ForegroundColor White
                Write-Host "[2] Create a standard (non-differencing) disk instead" -ForegroundColor White
                Write-Host "[3] Cancel VM creation" -ForegroundColor White
                
                do {
                    $choice = Read-Host "`nYour choice (1-3)"
                } while ($choice -notmatch '^[1-3]$')
                
                switch ($choice) {
                    '1' {
                        $newPath = Read-Host "Enter the correct parent VHDX path"
                        if (Test-Path $newPath) {
                            $config.ParentVHDXPath = $newPath
                            $config.VHDXPath = $newPath
                            Write-Host "Parent VHDX path updated successfully" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Path not found. Exiting..." -ForegroundColor Red
                            throw "Parent VHDX not found"
                        }
                    }
                    '2' {
                        $config.VMType = 'Standard'
                        $config.Remove('VHDXPath')
                        $config.Remove('ParentVHDXPath')
                        Write-Host "Switched to standard disk creation" -ForegroundColor Green
                    }
                    '3' {
                        Write-Host "VM creation cancelled" -ForegroundColor Yellow
                        return
                    }
                }
            }
            else {
                throw "Parent VHDX not found: $($config.ParentVHDXPath)"
            }
        }
    }
    
    # Show configuration summary
    Show-ConfigurationSummary -Config $config -SelectedDrive $selectedDrive
    
    # Ask about disk type if not specified and not using smart defaults
    if (-not $UseSmartDefaults -and -not $config.ContainsKey('VMType')) {
        Write-Host "`n=== Disk Type Selection ===" -ForegroundColor Yellow
        
        # Check if we have a parent VHDX available
        $hasParentVHDX = $config.ContainsKey('ParentVHDXPath') -and (Test-Path $config.ParentVHDXPath)
        
        if ($hasParentVHDX) {
            Write-Host "[1] New Disk (Create a new VHDX file)" -ForegroundColor White
            Write-Host "[2] Differencing Disk (Create from parent: $(Split-Path $config.ParentVHDXPath -Leaf))" -ForegroundColor White
            
            do {
                $diskChoice = Read-Host "`nSelect disk type (1-2)"
                $validChoice = $diskChoice -match '^[12]$'
                
                if (-not $validChoice) {
                    Write-Host "Invalid selection. Please enter 1 or 2." -ForegroundColor Red
                }
            } while (-not $validChoice)
            
            if ($diskChoice -eq '2') {
                $config.VMType = 'Differencing'
                $config.VHDXPath = $config.ParentVHDXPath  # Set VHDXPath for differencing
                Write-Host "Using differencing disk" -ForegroundColor Green
            }
            else {
                $config.VMType = 'Standard'
                $config.Remove('VHDXPath')  # Remove VHDXPath to create new disk
                Write-Host "Creating new disk" -ForegroundColor Green
            }
        }
        else {
            # No parent VHDX available, create new disk
            $config.VMType = 'Standard'
            $config.Remove('VHDXPath')
            Write-Host "No parent VHDX available. Creating new disk." -ForegroundColor Yellow
        }
    }
    elseif ($UseSmartDefaults) {
        # In smart defaults mode, use differencing if ParentVHDXPath exists
        if ($config.ContainsKey('ParentVHDXPath') -and (Test-Path $config.ParentVHDXPath)) {
            $config.VMType = 'Differencing'
            $config.VHDXPath = $config.ParentVHDXPath
            Write-Log -Message "Smart defaults: Using differencing disk" -Level 'INFO'
        }
        else {
            $config.VMType = 'Standard'
            if ($config.ContainsKey('VHDXPath')) {
                $config.Remove('VHDXPath')
            }
            Write-Log -Message "Smart defaults: Creating new disk" -Level 'INFO'
        }
    }
    
    # Confirm configuration unless using smart defaults
    if (-not $UseSmartDefaults) {
        $confirm = Read-Host "`nProceed with this configuration? (Y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Log -Message "User cancelled operation" -Level 'WARNING'
            exit 0
        }
    }
    
    # Extract OPNsense ISO if it's compressed
    if ($config.InstallMediaPath -and $config.InstallMediaPath.EndsWith('.bz2')) {
        $expandParams = @{
            CompressedPath = $config.InstallMediaPath
            SevenZipPath   = $SevenZipPath
        }
        $extractedIsoPath = Expand-CompressedISO @expandParams
        $config.InstallMediaPath = $extractedIsoPath
    }
    
    # Handle VHDX dismounting if needed
    if ($config.VHDXPath -and (Test-Path $config.VHDXPath)) {
        $DismountVHDXParams = @{
            VHDXPath = $config.VHDXPath
        }
        Log-Params -Params $DismountVHDXParams
        Dismount-VHDX @DismountVHDXParams
    }
    
    # Get the next VM name prefix and set VM name
    $VMNamePrefix = Get-NextVMNamePrefix -config $config
    Write-Log -Message "The next VM name prefix should be: $VMNamePrefix" -Level "INFO"
    
    # Set the VM name based on extracted prefix
    $VMName = "$VMNamePrefix`_VM"
    
    # Create VM directory
    $VMFullPath = Join-Path $config.VMPath $VMName
    if (Test-Path $VMFullPath) {
        Write-Log -Message "VM directory already exists at $VMFullPath" -Level "WARNING"
        
        # Check if VM with this name exists
        $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($existingVM) {
            Write-Log -Message "VM '$VMName' already exists. Generating new name..." -Level "WARNING"
            
            # Keep incrementing until we find a unique name
            $counter = 1
            do {
                $VMName = "$VMNamePrefix`_VM_$counter"
                $VMFullPath = Join-Path $config.VMPath $VMName
                $counter++
            } while ((Test-Path $VMFullPath) -or (Get-VM -Name $VMName -ErrorAction SilentlyContinue))
            
            Write-Log -Message "Using unique VM name: $VMName" -Level "INFO"
        }
        else {
            # Directory exists but VM doesn't - clean up the directory
            Write-Log -Message "Cleaning up existing directory without VM..." -Level "INFO"
            Remove-Item -Path $VMFullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    if (-not (Test-Path $VMFullPath)) {
        New-Item -Path $VMFullPath -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created VM directory at $VMFullPath" -Level "INFO"
    }
    
    # Get virtual switches
    $externalSwitchName = if ($config.ContainsKey('ExternalSwitchName')) {
        Get-SmartVirtualSwitch -RequestedSwitch $config.ExternalSwitchName
    } else {
        $config.SwitchName
    }
    Write-Log -Message "Using virtual switch: $externalSwitchName" -Level "INFO"
    
    $internalSwitchName = if ($config.ContainsKey('InternalSwitchName')) {
        Get-AvailableVirtualSwitch -SwitchPurpose "LAN (Internal)" -PreferredType "Private"
    } else {
        $null
    }
    
    if ($internalSwitchName) {
        Write-Log -Message "Using internal virtual switch for LAN: $internalSwitchName" -Level "INFO"
    }
    
    # Prepare VM creation parameters
    $createVMParams = @{
        VMName                  = $VMName
        VMFullPath              = $VMFullPath
        MemoryStartupBytes      = $config.MemoryStartupBytes
        MemoryMinimumBytes      = $config.MemoryMinimumBytes
        MemoryMaximumBytes      = $config.MemoryMaximumBytes
        ProcessorCount          = $config.ProcessorCount
        ExternalSwitchName      = $externalSwitchName
        Generation              = $config.Generation
        EnableVirtualizationExtensions = $config.EnableVirtualizationExtensions
        EnableDynamicMemory     = $config.EnableDynamicMemory
        IncludeTPM              = $config.IncludeTPM
        DefaultVHDSize          = $DefaultVHDSize
    }
    
    # Add optional parameters
    if ($internalSwitchName) {
        $createVMParams.InternalSwitchName = $internalSwitchName
    }
    
    if ($config.ExternalMacAddress) {
        $createVMParams.ExternalMacAddress = $config.ExternalMacAddress
    }
    
    if ($config.InternalMacAddress) {
        $createVMParams.InternalMacAddress = $config.InternalMacAddress
    }
    
    if ($config.InstallMediaPath) {
        $createVMParams.InstallMediaPath = $config.InstallMediaPath
    }
    
    if ($config.VMType) {
        $createVMParams.VMType = $config.VMType
    }
    
    if ($config.MemoryBuffer) {
        $createVMParams.MemoryBuffer = $config.MemoryBuffer
    }
    
    if ($config.MemoryWeight) {
        $createVMParams.MemoryWeight = $config.MemoryWeight
    }
    
    if ($config.MemoryPriority) {
        $createVMParams.MemoryPriority = $config.MemoryPriority
    }
    
    # Add differencing disk parameters if applicable
    if ($config.VMType -eq 'Differencing' -and $config.VHDXPath) {
        Write-Log -Message "Creating VM with differencing disk..." -Level "INFO"
        $createVMParams.VHDXPath = $config.VHDXPath
    }
    else {
        Write-Log -Message "Creating VM with new VHD..." -Level "INFO"
    }
    
    # Add advanced options
    if ($config.UseAllAvailableSwitches) {
        $createVMParams.UseAllAvailableSwitches = $config.UseAllAvailableSwitches
    }
    
    if ($config.AutoStartVM) {
        $createVMParams.AutoStartVM = $config.AutoStartVM
    }
    
    if ($config.AutoConnectVM) {
        $createVMParams.AutoConnectVM = $config.AutoConnectVM
    }
    
    # Add data disk parameters if enabled
    if ($config.EnableDataDisk) {
        $createVMParams.EnableDataDisk = $config.EnableDataDisk
        
        if ($config.DataDiskType) {
            $createVMParams.DataDiskType = $config.DataDiskType
        }
        
        if ($config.DataDiskSize) {
            $createVMParams.DataDiskSize = $config.DataDiskSize
        }
        
        if ($config.DataDiskParentPath) {
            $createVMParams.DataDiskParentPath = $config.DataDiskParentPath
        }
    }
    
    # Create the VM
    Create-EnhancedVM @createVMParams
    
    Write-Log -Message "VM creation completed successfully" -Level "INFO"
    
    # Display final summary
    Write-Host "`n=== VM Creation Complete ===" -ForegroundColor Green
    Write-Host "VM Name: $VMName" -ForegroundColor White
    Write-Host "Location: $VMFullPath" -ForegroundColor White
    Write-Host "Drive: $($selectedDrive.DriveLetter): ($('{0:N2}' -f $selectedDrive.FreeSpaceGB) GB free remaining)" -ForegroundColor White
    if ($config.EnableDataDisk) {
        Write-Host "Data Disk: Enabled ($($config.DataDiskType) - $([math]::Round($config.DataDiskSize/1GB, 2)) GB)" -ForegroundColor White
    }
    Write-Host "============================" -ForegroundColor Green
    
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