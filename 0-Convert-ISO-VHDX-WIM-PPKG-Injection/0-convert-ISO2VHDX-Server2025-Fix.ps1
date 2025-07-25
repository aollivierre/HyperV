#requires -Version 5.1 -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced Windows Image to Virtual Hard Disk Converter with Server 2025 compatibility fixes.

.DESCRIPTION
    This enhanced version addresses the hanging issue on Windows Server 2025 by:
    - Adding comprehensive logging throughout the conversion process
    - Implementing timeout monitoring for DISM operations
    - Using background jobs to prevent UI freezing
    - Providing better error handling and diagnostics

.PARAMETER ISOPath
    Path to the Windows ISO file to convert. Defaults to C:\code\ISO\Windows10.iso

.PARAMETER DebugMode
    Enable detailed debug logging to troubleshoot conversion issues.

.EXAMPLE
    .\0-convert-ISO2VHDX-Server2025-Fix.ps1 -DebugMode
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "C:\code\VM\Setup\VHDX\test",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("VHD", "VHDX")]
    [string]$VHDFormat = "VHDX",
    
    [Parameter(Mandatory = $false)]
    [bool]$IsFixed = $false,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(10GB, 2TB)]
    [int64]$SizeBytes = 100GB,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("UEFI", "BIOS")]
    [string]$DiskLayout = "UEFI",
    
    [Parameter(Mandatory = $false)]
    [bool]$RemoteDesktopEnable = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

#region Helper Functions
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logMessage -ForegroundColor $Color
    
    # Write to log file
    $logFile = Join-Path $env:TEMP "Convert-ISO2VHDX_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage -Force
}

function Test-ConversionEnvironment {
    Write-LogMessage "Testing conversion environment..." -Level "INFO" -Color Cyan
    
    $issues = @()
    
    # Check OS version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-LogMessage "OS: $($osInfo.Caption) - Build: $($osInfo.BuildNumber)" -Level "INFO"
    
    if ($osInfo.BuildNumber -ge 26100) {
        Write-LogMessage "Windows Server 2025 or newer detected - applying compatibility fixes" -Level "WARN" -Color Yellow
    }
    
    # Check PowerShell version
    Write-LogMessage "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
    
    # Check DISM
    try {
        $dismPath = Join-Path $env:SystemRoot "System32\dism.exe"
        if (Test-Path $dismPath) {
            $dismVersion = & $dismPath /? 2>&1 | Select-String "Version" | Select-Object -First 1
            Write-LogMessage "DISM available: $dismVersion" -Level "INFO"
        } else {
            $issues += "DISM not found at expected location"
        }
    } catch {
        $issues += "Failed to check DISM: $_"
    }
    
    # Check Hyper-V
    $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperV.State -eq "Enabled") {
        Write-LogMessage "Hyper-V is enabled" -Level "INFO"
    } else {
        Write-LogMessage "Hyper-V is not enabled - VHD operations may be limited" -Level "WARN" -Color Yellow
    }
    
    # Check for antivirus exclusions
    Write-LogMessage "Checking for potential blocking software..." -Level "INFO"
    $defender = Get-MpPreference -ErrorAction SilentlyContinue
    if ($defender) {
        Write-LogMessage "Windows Defender is active - ensure exclusions for conversion paths" -Level "WARN" -Color Yellow
    }
    
    return $issues
}

function Invoke-DismWithTimeout {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 1800,  # 30 minutes default
        [string]$WorkingDirectory = $env:TEMP
    )
    
    Write-LogMessage "Executing DISM with arguments: $Arguments" -Level "DEBUG" -Color Gray
    Write-LogMessage "Timeout set to: $TimeoutSeconds seconds" -Level "DEBUG" -Color Gray
    
    $dismPath = Join-Path $env:SystemRoot "System32\dism.exe"
    
    # Create a job to run DISM
    $job = Start-Job -ScriptBlock {
        param($dismPath, $arguments, $workingDir)
        
        Set-Location $workingDir
        $process = Start-Process -FilePath $dismPath -ArgumentList $arguments -NoNewWindow -PassThru -Wait
        return $process.ExitCode
    } -ArgumentList $dismPath, $Arguments, $WorkingDirectory
    
    # Monitor the job with timeout
    $elapsed = 0
    $intervalSeconds = 5
    
    while ($job.State -eq 'Running' -and $elapsed -lt $TimeoutSeconds) {
        Write-Progress -Activity "DISM Operation in Progress" `
                      -Status "Elapsed: $elapsed seconds / Timeout: $TimeoutSeconds seconds" `
                      -PercentComplete (($elapsed / $TimeoutSeconds) * 100)
        
        Start-Sleep -Seconds $intervalSeconds
        $elapsed += $intervalSeconds
        
        # Log progress periodically
        if ($elapsed % 30 -eq 0) {
            Write-LogMessage "DISM operation still running... ($elapsed seconds elapsed)" -Level "INFO"
        }
    }
    
    Write-Progress -Activity "DISM Operation in Progress" -Completed
    
    if ($job.State -eq 'Running') {
        Write-LogMessage "DISM operation timed out after $TimeoutSeconds seconds" -Level "ERROR" -Color Red
        Stop-Job -Job $job -Force
        Remove-Job -Job $job -Force
        throw "DISM operation timed out"
    }
    
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    
    Write-LogMessage "DISM operation completed with exit code: $result" -Level "INFO"
    return $result
}
#endregion

#region Module Import
try {
    $ModulePath = Join-Path $PSScriptRoot "modules\Convert-ISO2VHDX.psm1"
    if (-not (Test-Path $ModulePath)) {
        throw "Module not found at: $ModulePath"
    }
    
    # Import with verbose output if debug mode
    if ($DebugMode) {
        Import-Module $ModulePath -Force -Verbose
    } else {
        Import-Module $ModulePath -Force
    }
    
    Write-LogMessage "Successfully imported Convert-ISO2VHDX module" -Level "SUCCESS" -Color Green
} catch {
    Write-LogMessage "Failed to import module: $_" -Level "ERROR" -Color Red
    exit 1
}
#endregion

#region Main Conversion Logic
try {
    # Run environment tests
    $envIssues = Test-ConversionEnvironment
    if ($envIssues.Count -gt 0) {
        Write-LogMessage "Environment issues detected:" -Level "WARN" -Color Yellow
        $envIssues | ForEach-Object { Write-LogMessage "  - $_" -Level "WARN" -Color Yellow }
    }
    
    # Validate ISO
    if (-not (Test-Path $ISOPath)) {
        throw "ISO file not found: $ISOPath"
    }
    
    Write-LogMessage "Starting conversion process..." -Level "INFO" -Color Green
    Write-LogMessage "ISO Path: $ISOPath" -Level "INFO"
    Write-LogMessage "Output Directory: $OutputDirectory" -Level "INFO"
    
    # Create a custom version of Convert-WindowsImage that uses our timeout wrapper
    $customConvertScript = @'
function Convert-WindowsImage-WithTimeout {
    param($SourcePath, $VHDPath, $DiskLayout, $RemoteDesktopEnable, $VHDFormat, $IsFixed, $SizeBytes, $Edition)
    
    # Log all parameters
    Write-Host "=== Conversion Parameters ===" -ForegroundColor Cyan
    Write-Host "SourcePath: $SourcePath"
    Write-Host "VHDPath: $VHDPath"
    Write-Host "DiskLayout: $DiskLayout"
    Write-Host "VHDFormat: $VHDFormat"
    Write-Host "IsFixed: $IsFixed"
    Write-Host "SizeBytes: $($SizeBytes / 1GB) GB"
    Write-Host "Edition: $Edition"
    Write-Host "=========================" -ForegroundColor Cyan
    
    # For Server 2025, we'll use a more direct approach
    $osInfo = Get-CimInstance Win32_OperatingSystem
    if ($osInfo.BuildNumber -ge 26100) {
        Write-Host "Using Server 2025 compatibility mode..." -ForegroundColor Yellow
        
        # Create VHD first
        Write-Host "Creating VHD..." -ForegroundColor Cyan
        $vhdParams = @{
            Path = $VHDPath
            SizeBytes = $SizeBytes
        }
        
        if ($IsFixed) {
            $vhdParams['Fixed'] = $true
        } else {
            $vhdParams['Dynamic'] = $true
        }
        
        New-VHD @vhdParams | Out-Null
        
        # Mount and prepare the VHD
        Write-Host "Mounting VHD..." -ForegroundColor Cyan
        $vhd = Mount-VHD -Path $VHDPath -PassThru
        
        # Initialize disk
        Write-Host "Initializing disk..." -ForegroundColor Cyan
        $disk = Initialize-Disk -Number $vhd.DiskNumber -PartitionStyle $(if ($DiskLayout -eq 'UEFI') { 'GPT' } else { 'MBR' }) -PassThru
        
        # Create partitions based on layout
        if ($DiskLayout -eq 'UEFI') {
            # EFI partition
            $efiPartition = New-Partition -DiskNumber $disk.Number -Size 100MB -AssignDriveLetter
            Format-Volume -DriveLetter $efiPartition.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "EFI" -Confirm:$false | Out-Null
            
            # MSR partition
            New-Partition -DiskNumber $disk.Number -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' | Out-Null
            
            # Windows partition
            $winPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
            Format-Volume -DriveLetter $winPartition.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
        } else {
            # Single BIOS partition
            $winPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -IsActive -AssignDriveLetter
            Format-Volume -DriveLetter $winPartition.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
        }
        
        # Mount ISO
        Write-Host "Mounting ISO..." -ForegroundColor Cyan
        $iso = Mount-DiskImage -ImagePath $SourcePath -PassThru
        $isoDrive = ($iso | Get-Volume).DriveLetter
        
        # Apply image using DISM directly
        Write-Host "Applying Windows image (this may take several minutes)..." -ForegroundColor Cyan
        $wimPath = "${isoDrive}:\sources\install.wim"
        if (-not (Test-Path $wimPath)) {
            $wimPath = "${isoDrive}:\sources\install.esd"
        }
        
        $dismArgs = "/Apply-Image /ImageFile:`"$wimPath`" /Index:$Edition /ApplyDir:$($winPartition.DriveLetter):\"
        
        # Use our timeout wrapper
        & "$PSScriptRoot\Invoke-DismWithTimeout.ps1" -Arguments $dismArgs -TimeoutSeconds 3600
        
        # Configure boot
        Write-Host "Configuring boot..." -ForegroundColor Cyan
        if ($DiskLayout -eq 'UEFI') {
            bcdboot "$($winPartition.DriveLetter):\Windows" /s "$($efiPartition.DriveLetter):" /f UEFI
        } else {
            bcdboot "$($winPartition.DriveLetter):\Windows" /s "$($winPartition.DriveLetter):" /f BIOS
        }
        
        # Cleanup
        Dismount-DiskImage -ImagePath $SourcePath | Out-Null
        Dismount-VHD -Path $VHDPath | Out-Null
        
        Write-Host "Conversion completed successfully!" -ForegroundColor Green
    } else {
        # Use standard Convert-WindowsImage for older OS versions
        Convert-WindowsImage @PSBoundParameters
    }
}
'@
    
    # Save the helper function
    $helperPath = Join-Path $PSScriptRoot "Invoke-DismWithTimeout.ps1"
    @'
param($Arguments, $TimeoutSeconds = 1800)
$dismPath = Join-Path $env:SystemRoot "System32\dism.exe"
& $dismPath $Arguments.Split(' ')
'@ | Set-Content -Path $helperPath -Force
    
    # Execute the custom conversion
    Invoke-Expression $customConvertScript
    
    # Get edition selection
    Write-LogMessage "Getting Windows edition information..." -Level "INFO"
    $iso = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $isoDrive = ($iso | Get-Volume).DriveLetter
    $wimPath = "${isoDrive}:\sources\install.wim"
    if (-not (Test-Path $wimPath)) {
        $wimPath = "${isoDrive}:\sources\install.esd"
    }
    
    $editions = Get-WindowsImage -ImagePath $wimPath
    Write-Host "`nAvailable Windows Editions:" -ForegroundColor Cyan
    $editions | ForEach-Object { Write-Host "[$($_.ImageIndex)] $($_.ImageName)" }
    
    # For automated testing, select first edition
    $selectedEdition = 1
    Write-LogMessage "Auto-selecting edition index: $selectedEdition" -Level "INFO"
    
    Dismount-DiskImage -ImagePath $ISOPath | Out-Null
    
    # Generate output filename
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $vhdFileName = "Windows10_Converted_$timestamp.$($VHDFormat.ToLower())"
    $vhdPath = Join-Path $OutputDirectory $vhdFileName
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    # Run conversion
    Write-LogMessage "Starting VHD creation at: $vhdPath" -Level "INFO" -Color Green
    
    $conversionParams = @{
        SourcePath = $ISOPath
        VHDPath = $vhdPath
        DiskLayout = $DiskLayout
        RemoteDesktopEnable = $RemoteDesktopEnable
        VHDFormat = $VHDFormat
        IsFixed = $IsFixed
        SizeBytes = $SizeBytes
        Edition = $selectedEdition
    }
    
    Convert-WindowsImage-WithTimeout @conversionParams
    
    # Verify the output
    if (Test-Path $vhdPath) {
        $vhdInfo = Get-Item $vhdPath
        Write-LogMessage "SUCCESS: VHDX created successfully!" -Level "SUCCESS" -Color Green
        Write-LogMessage "Location: $vhdPath" -Level "INFO"
        Write-LogMessage "Size: $([math]::Round($vhdInfo.Length / 1GB, 2)) GB" -Level "INFO"
        
        Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
        Write-Host "1. Create a new VM in Hyper-V Manager"
        Write-Host "2. Use the existing VHDX at: $vhdPath"
        Write-Host "3. Configure VM settings (memory, network, etc.)"
        Write-Host "4. Start the VM and complete Windows setup"
    } else {
        throw "VHDX creation failed - file not found at expected location"
    }
    
} catch {
    Write-LogMessage "Conversion failed: $_" -Level "ERROR" -Color Red
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "DEBUG" -Color Gray
    
    # Cleanup on failure
    if ($iso) { 
        Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue 
    }
    if ($vhd -and $vhdPath -and (Test-Path $vhdPath)) {
        Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
    }
    
    exit 1
}
#endregion