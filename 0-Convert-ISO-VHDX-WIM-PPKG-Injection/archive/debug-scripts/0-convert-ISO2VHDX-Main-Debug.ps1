#requires -Version 5.1

<#
.SYNOPSIS
    Enhanced Windows Image to Virtual Hard Disk Converter with debugging for Server 2025.

.DESCRIPTION
    This enhanced version includes verbose logging and error handling to debug issues
    on Windows Server 2025 where the conversion process hangs.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ISOPath = "C:\Code\ISO\Windows_10_July_22_2025.iso",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "C:\Code\VM\Setup\VHDX\test",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("VHD", "VHDX")]
    [string]$VHDFormat = "VHDX",
    
    [Parameter(Mandatory = $false)]
    [bool]$IsFixed = $false,
    
    [Parameter(Mandatory = $false)]
    [int64]$SizeBytes = 100GB,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("UEFI", "BIOS")]
    [string]$DiskLayout = "UEFI",
    
    [Parameter(Mandatory = $false)]
    [bool]$RemoteDesktopEnable = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

# Enable verbose and debug output
$VerbosePreference = if ($DebugMode) { "Continue" } else { "SilentlyContinue" }
$DebugPreference = if ($DebugMode) { "Continue" } else { "SilentlyContinue" }

#region Helper Functions
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Debug" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
    
    # Also write to a log file
    $logFile = Join-Path $OutputDirectory "conversion_debug_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    Add-Content -Path $logFile -Value $logMessage -Force
}

function Test-Prerequisites {
    Write-LogMessage "Testing prerequisites..." -Level "Info"
    
    # Check OS version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-LogMessage "OS: $($osInfo.Caption) - Version: $($osInfo.Version)" -Level "Info"
    
    # Check PowerShell version
    Write-LogMessage "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "Info"
    
    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-LogMessage "Script is not running as Administrator!" -Level "Error"
        throw "This script must be run as Administrator"
    }
    Write-LogMessage "Running as Administrator: Yes" -Level "Success"
    
    # Check Hyper-V feature
    try {
        $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
        if ($hyperV) {
            Write-LogMessage "Hyper-V Status: $($hyperV.State)" -Level "Info"
        }
    } catch {
        Write-LogMessage "Could not check Hyper-V status: $_" -Level "Warning"
    }
    
    # Check DISM
    $dismPath = Join-Path $env:WINDIR "System32\dism.exe"
    if (Test-Path $dismPath) {
        Write-LogMessage "DISM found at: $dismPath" -Level "Success"
        $dismVersion = & $dismPath /? | Select-String "Version:" | Select-Object -First 1
        if ($dismVersion) {
            Write-LogMessage "DISM $dismVersion" -Level "Info"
        }
    } else {
        Write-LogMessage "DISM not found!" -Level "Error"
    }
    
    # Check available memory
    $memory = Get-CimInstance Win32_ComputerSystem
    Write-LogMessage "Total Physical Memory: $([math]::Round($memory.TotalPhysicalMemory / 1GB, 2)) GB" -Level "Info"
    
    # Check disk space
    $drive = (Split-Path $OutputDirectory -Qualifier).TrimEnd(':')
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${drive}:'"
    $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    Write-LogMessage "Free space on ${drive}: $freeSpaceGB GB" -Level "Info"
    
    if ($freeSpaceGB -lt ($SizeBytes / 1GB * 1.5)) {
        Write-LogMessage "Warning: Free disk space might be insufficient" -Level "Warning"
    }
}
#endregion

#region Module Import with Enhanced Error Handling
Write-LogMessage "Starting module import process..." -Level "Info"

try {
    $ModulePath = Join-Path $PSScriptRoot "modules\Convert-ISO2VHDX.psm1"
    Write-LogMessage "Module path: $ModulePath" -Level "Debug"
    
    if (-not (Test-Path $ModulePath)) {
        throw "Module not found at: $ModulePath"
    }
    
    # Check module file size and last modified
    $moduleInfo = Get-Item $ModulePath
    Write-LogMessage "Module size: $($moduleInfo.Length) bytes" -Level "Debug"
    Write-LogMessage "Module last modified: $($moduleInfo.LastWriteTime)" -Level "Debug"
    
    # Import with verbose output
    Import-Module $ModulePath -Force -Verbose:$DebugMode
    Write-LogMessage "Successfully imported Convert-ISO2VHDX module" -Level "Success"
    
    # Verify the function is available
    if (Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue) {
        Write-LogMessage "Convert-WindowsImage function is available" -Level "Success"
    } else {
        throw "Convert-WindowsImage function not found after module import"
    }
    
} catch {
    Write-LogMessage "Failed to import module: $($_.Exception.Message)" -Level "Error"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "Debug"
    exit 1
}
#endregion

#region Main Conversion Process
try {
    # Run prerequisites check
    Test-Prerequisites
    
    # Validate ISO
    Write-LogMessage "Validating ISO file..." -Level "Info"
    if (-not (Test-Path $ISOPath)) {
        throw "ISO file not found: $ISOPath"
    }
    
    $isoInfo = Get-Item $ISOPath
    Write-LogMessage "ISO file size: $([math]::Round($isoInfo.Length / 1GB, 2)) GB" -Level "Info"
    
    Write-LogMessage "Starting Windows Image to VHDX conversion process..." -Level "Info"
    Write-LogMessage "Parameters:" -Level "Info"
    Write-LogMessage "  ISO Path: $ISOPath" -Level "Info"
    Write-LogMessage "  Output Directory: $OutputDirectory" -Level "Info"
    Write-LogMessage "  VHD Format: $VHDFormat" -Level "Info"
    Write-LogMessage "  Disk Type: $(if ($IsFixed) { 'Fixed' } else { 'Dynamic' })" -Level "Info"
    Write-LogMessage "  Size: $([math]::Round($SizeBytes / 1GB, 2)) GB" -Level "Info"
    Write-LogMessage "  Disk Layout: $DiskLayout" -Level "Info"
    
    # Get Windows edition with enhanced error handling
    Write-LogMessage "Mounting ISO to read Windows editions..." -Level "Info"
    
    $mountResult = $null
    $selectedEdition = $null
    
    try {
        $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
        Write-LogMessage "ISO mounted successfully" -Level "Success"
        
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        Write-LogMessage "ISO mounted to drive: $driveLetter" -Level "Info"
        
        # Check for install.wim or install.esd
        $wimPath = "${driveLetter}:\sources\install.wim"
        $esdPath = "${driveLetter}:\sources\install.esd"
        $installPath = if (Test-Path $wimPath) { $wimPath } else { $esdPath }
        
        if (-not (Test-Path $installPath)) {
            throw "Neither install.wim nor install.esd found in the ISO"
        }
        
        Write-LogMessage "Found installation file: $installPath" -Level "Info"
        
        # Get Windows editions
        Write-LogMessage "Reading Windows image information..." -Level "Info"
        $editions = Get-WindowsImage -ImagePath $installPath | Select-Object ImageIndex, ImageName
        
        Write-LogMessage "Found $($editions.Count) Windows editions" -Level "Info"
        
        # Display editions
        Write-Host "`nAvailable Windows Editions in ISO:" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        foreach ($edition in $editions) {
            Write-Host ("[{0}] {1}" -f $edition.ImageIndex, $edition.ImageName)
        }
        
        Write-Host "`nPlease select an edition by entering its number:" -ForegroundColor Yellow
        $choice = Read-Host
        
        $selectedEdition = $editions | Where-Object { $_.ImageIndex -eq [int]$choice }
        
        if ($null -eq $selectedEdition) {
            throw "Invalid selection: $choice"
        }
        
        Write-LogMessage "Selected edition: [$($selectedEdition.ImageIndex)] $($selectedEdition.ImageName)" -Level "Success"
        
    } finally {
        if ($mountResult) {
            Write-LogMessage "Dismounting ISO..." -Level "Info"
            Dismount-DiskImage -ImagePath $ISOPath | Out-Null
            Write-LogMessage "ISO dismounted" -Level "Success"
        }
    }
    
    # Create output directory
    if (-not (Test-Path $OutputDirectory)) {
        Write-LogMessage "Creating output directory: $OutputDirectory" -Level "Info"
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    # Generate VHDX filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $vhdFileName = "Windows_$($selectedEdition.ImageIndex)_$(($SizeBytes/1GB))GB_$(if($IsFixed){'Fixed'}else{'Dynamic'})_${DiskLayout}_${timestamp}.${VHDFormat.ToLower()}"
    $vhdPath = Join-Path $OutputDirectory $vhdFileName
    
    Write-LogMessage "Target VHDX path: $vhdPath" -Level "Info"
    
    # Prepare conversion parameters
    $params = @{
        SourcePath          = $ISOPath
        VHDPath             = $vhdPath
        DiskLayout          = $DiskLayout
        RemoteDesktopEnable = $RemoteDesktopEnable
        VHDFormat           = $VHDFormat
        IsFixed             = $IsFixed
        SizeBytes           = $SizeBytes
        Edition             = $selectedEdition.ImageIndex
    }
    
    Write-LogMessage "Starting Convert-WindowsImage with parameters:" -Level "Info"
    $params.GetEnumerator() | ForEach-Object {
        Write-LogMessage "  $($_.Key): $($_.Value)" -Level "Debug"
    }
    
    # Add progress monitoring
    $conversionJob = Start-Job -ScriptBlock {
        param($ModulePath, $Params)
        Import-Module $ModulePath -Force
        Convert-WindowsImage @Params -Verbose
    } -ArgumentList $ModulePath, $params
    
    Write-LogMessage "Conversion job started with ID: $($conversionJob.Id)" -Level "Info"
    
    # Monitor the job
    $timeout = New-TimeSpan -Minutes 30
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($conversionJob.State -eq 'Running' -and $stopwatch.Elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed = [math]::Round($stopwatch.Elapsed.TotalMinutes, 1)
        Write-Host "." -NoNewline
        
        # Check job output
        $output = Receive-Job -Job $conversionJob -Keep
        if ($output) {
            $output | ForEach-Object {
                Write-LogMessage "Job output: $_" -Level "Debug"
            }
        }
        
        if ($elapsed % 1 -eq 0) {
            Write-LogMessage "Conversion in progress... ($elapsed minutes elapsed)" -Level "Info"
        }
    }
    
    Write-Host "" # New line after dots
    
    # Check job results
    if ($conversionJob.State -eq 'Completed') {
        $finalOutput = Receive-Job -Job $conversionJob
        Write-LogMessage "Conversion completed successfully!" -Level "Success"
        
        if (Test-Path $vhdPath) {
            $vhdInfo = Get-Item $vhdPath
            Write-LogMessage "VHDX created: $vhdPath" -Level "Success"
            Write-LogMessage "VHDX size: $([math]::Round($vhdInfo.Length / 1GB, 2)) GB" -Level "Info"
        }
    } else {
        $error = Receive-Job -Job $conversionJob
        Write-LogMessage "Conversion failed or timed out!" -Level "Error"
        Write-LogMessage "Job state: $($conversionJob.State)" -Level "Error"
        Write-LogMessage "Error details: $error" -Level "Error"
        
        # Try to get more error information
        $jobError = Get-Job -Id $conversionJob.Id | Select-Object -ExpandProperty ChildJobs | ForEach-Object { $_.Error }
        if ($jobError) {
            Write-LogMessage "Job errors: $jobError" -Level "Error"
        }
    }
    
    Remove-Job -Job $conversionJob -Force
    
} catch {
    Write-LogMessage "Script execution failed: $($_.Exception.Message)" -Level "Error"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "Debug"
    exit 1
}
#endregion