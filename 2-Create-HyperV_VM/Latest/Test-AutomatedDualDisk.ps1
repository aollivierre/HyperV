# Automated test for dual disk feature
Write-Host "`n=== Automated Dual Disk Test ===" -ForegroundColor Cyan

# First, ensure we have a parent data disk
$dataParent = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
if (-not (Test-Path $dataParent)) {
    Write-Host "Creating parent data disk..." -ForegroundColor Yellow
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\Create-DataDiskParent.ps1" -Path $dataParent
}

# Create a test config with dual disk enabled
$testConfig = @"
@{
    VMNamePrefixFormat   = "{0:D3} - AUTO TEST - Dual Disk"
    VMType               = "Standard"  # Use standard to avoid parent disk issues
    EnableDataDisk       = `$true
    DataDiskType         = "Differencing"
    DataDiskSize         = 256GB
    DataDiskParentPath   = "$dataParent"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    ProcessorCount       = 2
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    Generation           = 2
    AutoStartVM          = `$false
    AutoConnectVM        = `$false
}
"@

$configPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-auto-config.psd1"
Set-Content -Path $configPath -Value $testConfig

try {
    # Run with smart defaults to avoid prompts
    Write-Host "`nRunning VM creation with dual disks..." -ForegroundColor Yellow
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
        -ConfigurationPath "D:\Code\HyperV\2-Create-HyperV_VM\Latest" `
        -UseSmartDefaults `
        -AutoSelectDrive
    
    # Find the created VM
    Start-Sleep -Seconds 5
    $vm = Get-VM | Where-Object { $_.Name -like "*AUTO TEST - Dual Disk*" } | Sort-Object Name -Descending | Select-Object -First 1
    
    if ($vm) {
        Write-Host "`nVM created: $($vm.Name)" -ForegroundColor Green
        
        # Check disks
        $disks = Get-VMHardDiskDrive -VMName $vm.Name
        Write-Host "Number of disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
        
        foreach ($disk in $disks) {
            Write-Host "`nDisk $($disk.ControllerLocation):" -ForegroundColor Yellow
            Write-Host "  Path: $($disk.Path)"
            if (Test-Path $disk.Path) {
                $vhd = Get-VHD -Path $disk.Path
                Write-Host "  Type: $($vhd.VhdType)"
                if ($vhd.ParentPath) {
                    Write-Host "  Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Green
                }
            }
        }
        
        # Verify dual disk success
        if ($disks.Count -eq 2) {
            Write-Host "`nSUCCESS: VM created with dual disks!" -ForegroundColor Green
            
            # Check if data disk is differencing
            $dataDisk = $disks | Where-Object { $_.Path -like "*DataDisk*" }
            if ($dataDisk) {
                $dataVHD = Get-VHD -Path $dataDisk.Path
                if ($dataVHD.VhdType -eq 'Differencing') {
                    Write-Host "SUCCESS: Data disk is differencing type with parent" -ForegroundColor Green
                }
            }
        }
        
        # Cleanup
        Write-Host "`nCleaning up test VM..." -ForegroundColor Yellow
        Remove-VM -Name $vm.Name -Force
        $vmPath = Split-Path $vm.Path -Parent
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "ERROR: VM not found!" -ForegroundColor Red
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
finally {
    # Cleanup config
    Remove-Item -Path $configPath -Force -ErrorAction SilentlyContinue
}