#requires -RunAsAdministrator

<#
.SYNOPSIS
    Minimal test script to isolate Convert-WindowsImage hanging issue on Server 2025
#>

param(
    [string]$ISOPath = "C:\Code\ISO\Windows_10_July_22_2025.iso",
    [switch]$UseNativeDISM
)

Write-Host "=== Minimal Conversion Test ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Direct DISM test
if ($UseNativeDISM) {
    Write-Host "Testing with native DISM commands..." -ForegroundColor Yellow
    
    # Create a small test VHDX
    $testVHDX = "C:\Code\VM\Setup\VHDX\test\test_minimal.vhdx"
    $testDir = Split-Path $testVHDX -Parent
    
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    try {
        # Create VHDX using Hyper-V cmdlets
        Write-Host "Creating test VHDX..." -ForegroundColor Cyan
        New-VHD -Path $testVHDX -SizeBytes 40GB -Dynamic -ErrorAction Stop | Out-Null
        Write-Host "VHDX created successfully" -ForegroundColor Green
        
        # Mount the VHDX
        Write-Host "Mounting VHDX..." -ForegroundColor Cyan
        $vhdMount = Mount-VHD -Path $testVHDX -Passthru -ErrorAction Stop
        Write-Host "VHDX mounted successfully" -ForegroundColor Green
        
        # Initialize disk
        Write-Host "Initializing disk..." -ForegroundColor Cyan
        $disk = Initialize-Disk -Number $vhdMount.Number -PartitionStyle GPT -PassThru -ErrorAction Stop
        
        # Create partitions (simplified UEFI layout)
        Write-Host "Creating partitions..." -ForegroundColor Cyan
        
        # EFI partition
        $efiPartition = New-Partition -DiskNumber $disk.Number -Size 100MB -AssignDriveLetter -ErrorAction Stop
        Format-Volume -DriveLetter $efiPartition.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false | Out-Null
        
        # Windows partition
        $winPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
        Format-Volume -DriveLetter $winPartition.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
        
        Write-Host "Partitions created successfully" -ForegroundColor Green
        Write-Host "  EFI Drive: $($efiPartition.DriveLetter):" -ForegroundColor Gray
        Write-Host "  Windows Drive: $($winPartition.DriveLetter):" -ForegroundColor Gray
        
        # Mount ISO
        Write-Host "Mounting ISO..." -ForegroundColor Cyan
        $isoMount = Mount-DiskImage -ImagePath $ISOPath -PassThru -ErrorAction Stop
        $isoDrive = ($isoMount | Get-Volume).DriveLetter
        Write-Host "ISO mounted to drive: ${isoDrive}:" -ForegroundColor Green
        
        # Check install.wim
        $wimPath = "${isoDrive}:\sources\install.wim"
        if (-not (Test-Path $wimPath)) {
            $wimPath = "${isoDrive}:\sources\install.esd"
        }
        
        if (Test-Path $wimPath) {
            Write-Host "Found installation media: $wimPath" -ForegroundColor Green
            
            # Get image info
            Write-Host "Getting image information..." -ForegroundColor Cyan
            $images = Get-WindowsImage -ImagePath $wimPath
            Write-Host "Found $($images.Count) images in WIM" -ForegroundColor Green
            
            # Apply image using DISM directly
            Write-Host ""
            Write-Host "Attempting to apply image using native DISM..." -ForegroundColor Yellow
            Write-Host "Command: dism /Apply-Image /ImageFile:$wimPath /Index:1 /ApplyDir:$($winPartition.DriveLetter):\" -ForegroundColor Gray
            
            $dismArgs = @(
                "/Apply-Image",
                "/ImageFile:$wimPath",
                "/Index:1",
                "/ApplyDir:$($winPartition.DriveLetter):\"
            )
            
            # Start DISM in a separate process to monitor
            $dismInfo = New-Object System.Diagnostics.ProcessStartInfo
            $dismInfo.FileName = "dism.exe"
            $dismInfo.Arguments = $dismArgs -join " "
            $dismInfo.UseShellExecute = $false
            $dismInfo.RedirectStandardOutput = $true
            $dismInfo.RedirectStandardError = $true
            $dismInfo.CreateNoWindow = $false
            
            Write-Host "Starting DISM process..." -ForegroundColor Cyan
            $dismProcess = [System.Diagnostics.Process]::Start($dismInfo)
            
            # Monitor process with timeout
            $timeout = 300 # 5 minutes
            $completed = $dismProcess.WaitForExit($timeout * 1000)
            
            if ($completed) {
                $output = $dismProcess.StandardOutput.ReadToEnd()
                $error = $dismProcess.StandardError.ReadToEnd()
                
                Write-Host "DISM Exit Code: $($dismProcess.ExitCode)" -ForegroundColor $(if($dismProcess.ExitCode -eq 0){"Green"}else{"Red"})
                
                if ($output) {
                    Write-Host "DISM Output:" -ForegroundColor Yellow
                    Write-Host $output
                }
                
                if ($error) {
                    Write-Host "DISM Errors:" -ForegroundColor Red
                    Write-Host $error
                }
            } else {
                Write-Host "DISM process timed out after $timeout seconds!" -ForegroundColor Red
                Write-Host "This indicates the hanging issue is in DISM itself" -ForegroundColor Yellow
                
                # Try to kill the process
                try {
                    $dismProcess.Kill()
                    Write-Host "DISM process terminated" -ForegroundColor Yellow
                } catch {
                    Write-Host "Failed to terminate DISM process" -ForegroundColor Red
                }
            }
            
        } else {
            Write-Host "No installation media found in ISO!" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error during test: $_" -ForegroundColor Red
    } finally {
        # Cleanup
        Write-Host ""
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        
        if ($isoMount) {
            Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
        }
        
        if ($vhdMount) {
            Dismount-VHD -Path $testVHDX -ErrorAction SilentlyContinue
        }
        
        if (Test-Path $testVHDX) {
            Remove-Item $testVHDX -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "Cleanup complete" -ForegroundColor Green
    }
    
} else {
    Write-Host "Testing with Convert-WindowsImage module..." -ForegroundColor Yellow
    
    # Import module
    $ModulePath = Join-Path $PSScriptRoot "modules\Convert-ISO2VHDX.psm1"
    Import-Module $ModulePath -Force
    
    # Simple test with verbose output
    $testParams = @{
        SourcePath = $ISOPath
        VHDPath = "C:\Code\VM\Setup\VHDX\test\test_minimal_$(Get-Date -Format 'yyyyMMdd_HHmmss').vhdx"
        VHDFormat = "VHDX"
        DiskLayout = "UEFI"
        SizeBytes = 40GB
        Edition = 1
        Verbose = $true
    }
    
    Write-Host "Starting conversion with minimal parameters..." -ForegroundColor Cyan
    Write-Host "This will help identify if the issue is parameter-specific" -ForegroundColor Gray
    
    try {
        # Use a job with monitoring
        $job = Start-Job -ScriptBlock {
            param($Module, $Params)
            Import-Module $Module
            Convert-WindowsImage @Params
        } -ArgumentList $ModulePath, $testParams
        
        Write-Host "Monitoring conversion job..." -ForegroundColor Yellow
        $timeout = 60 # 1 minute for initial response
        $elapsed = 0
        
        while ($job.State -eq 'Running' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 5
            $elapsed += 5
            
            # Check for output
            $output = Receive-Job -Job $job -Keep
            if ($output) {
                $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            }
            
            Write-Host "  ... $elapsed seconds elapsed" -ForegroundColor Gray
        }
        
        if ($job.State -eq 'Running') {
            Write-Host "Job is still running after $timeout seconds - likely hanging!" -ForegroundColor Red
            Write-Host "Stopping job..." -ForegroundColor Yellow
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
            
            Write-Host ""
            Write-Host "RECOMMENDATION: Run with -UseNativeDISM to test DISM directly" -ForegroundColor Yellow
        } else {
            Write-Host "Job completed with state: $($job.State)" -ForegroundColor Green
            $finalOutput = Receive-Job -Job $job
            if ($finalOutput) {
                Write-Host "Final output:" -ForegroundColor Yellow
                $finalOutput | ForEach-Object { Write-Host "  $_" }
            }
            Remove-Job -Job $job
        }
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If the script hangs, it confirms the Server 2025 compatibility issue"
Write-Host "2. Run with -UseNativeDISM to test DISM directly"
Write-Host "3. Check Event Viewer > Applications and Services Logs > Microsoft > Windows > DISM"
Write-Host "4. Consider using alternative methods like:" -ForegroundColor Yellow
Write-Host "   - Disk2VHD from Sysinternals"
Write-Host "   - Manual DISM commands with proper error handling"
Write-Host "   - PowerShell Desired State Configuration (DSC)"
Write-Host ""