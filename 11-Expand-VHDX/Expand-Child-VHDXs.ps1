#!/usr/bin/env powershell

<#
.SYNOPSIS
    Expands child/differencing VHDXs to match their parent's size.

.DESCRIPTION
    This script finds all child/differencing VHDXs that use a specific parent VHDX
    and expands them to match the parent's current size.

.PARAMETER ParentVHDXPath
    The full path to the parent VHDX file

.PARAMETER NewSizeGB
    The size to expand child VHDXs to (should match parent size)

.EXAMPLE
    .\Expand-Child-VHDXs.ps1 -ParentVHDXPath "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX" -NewSizeGB 200
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ParentVHDXPath,
    
    [Parameter(Mandatory=$true)]
    [int]$NewSizeGB
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to find VMs using the specified parent VHDX (child/differencing disks only)
function Get-ChildVHDXs {
    param([string]$ParentVHDXPath)
    
    $childVMs = @()
    $allVMs = Get-VM
    
    foreach ($vm in $allVMs) {
        $vmDisks = Get-VMHardDiskDrive -VM $vm
        
        foreach ($disk in $vmDisks) {
            if ($disk.Path -and (Test-Path $disk.Path)) {
                try {
                    $vhdInfo = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
                    if ($vhdInfo -and $vhdInfo.ParentPath -eq $ParentVHDXPath) {
                        $childVMs += [PSCustomObject]@{
                            VMName = $vm.Name
                            State = $vm.State
                            DiskPath = $disk.Path
                            CurrentSizeGB = [math]::Round($vhdInfo.Size / 1GB, 2)
                        }
                    }
                }
                catch {
                    # Skip if we can't read VHD info
                }
            }
        }
    }
    
    return $childVMs
}

# Main script execution
Clear-Host
Write-ColorOutput "===============================================================" "Cyan"
Write-ColorOutput "            CHILD VHDX EXPANSION SCRIPT" "Cyan"
Write-ColorOutput "===============================================================" "Cyan"

Write-ColorOutput "`nParent VHDX: $ParentVHDXPath" "White"
Write-ColorOutput "Target Size: $NewSizeGB GB" "White"

# Check if parent VHDX file exists
if (-not (Test-Path $ParentVHDXPath)) {
    Write-ColorOutput "[ERROR] Parent VHDX file not found at specified path!" "Red"
    exit 1
}

# Check if Hyper-V module is available
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-ColorOutput "[ERROR] Hyper-V PowerShell module not found!" "Red"
    exit 1
}

# Get parent VHDX info
try {
    $parentVhdInfo = Get-VHD -Path $ParentVHDXPath
    $parentSizeGB = [math]::Round($parentVhdInfo.Size / 1GB, 2)
    Write-ColorOutput "Parent VHDX current size: $parentSizeGB GB" "Green"
}
catch {
    Write-ColorOutput "[ERROR] Cannot read parent VHDX information: $($_.Exception.Message)" "Red"
    exit 1
}

Write-ColorOutput "`nStep 1: Finding child/differencing VHDXs..." "Cyan"

# Find all child VHDXs using this parent
$childVMs = Get-ChildVHDXs -ParentVHDXPath $ParentVHDXPath

if ($childVMs.Count -eq 0) {
    Write-ColorOutput "[OK] No child/differencing VHDXs found using this parent." "Green"
    exit 0
}

Write-ColorOutput "`nFound $($childVMs.Count) child VHDX(s):" "Yellow"
Write-ColorOutput "===============================================================" "Yellow"

foreach ($child in $childVMs) {
    Write-ColorOutput "  • VM: $($child.VMName) [$($child.State)]" "White"
    Write-ColorOutput "    Current Size: $($child.CurrentSizeGB) GB" "Cyan"
    Write-ColorOutput "    Path: $($child.DiskPath)" "Gray"
    Write-ColorOutput ""
}

# Check for running VMs
$runningVMs = $childVMs | Where-Object { $_.State -eq "Running" }
if ($runningVMs.Count -gt 0) {
    Write-ColorOutput "[ERROR] The following VMs are still running:" "Red"
    foreach ($vm in $runningVMs) {
        Write-ColorOutput "  • $($vm.VMName)" "Yellow"
    }
    Write-ColorOutput "`nPlease stop these VMs before expanding their VHDXs." "Red"
    exit 1
}

Write-ColorOutput "Step 2: Expanding child VHDXs..." "Cyan"

$successCount = 0
$errorCount = 0

foreach ($childVM in $childVMs) {
    Write-ColorOutput "`nProcessing: $($childVM.VMName)" "White"
    Write-ColorOutput "Path: $($childVM.DiskPath)" "Gray"
    Write-ColorOutput "Current: $($childVM.CurrentSizeGB) GB -> Target: $NewSizeGB GB" "Cyan"
    
    if ($childVM.CurrentSizeGB -ge $NewSizeGB) {
        Write-ColorOutput "[SKIP] Child VHDX is already $($childVM.CurrentSizeGB) GB (>= target)" "Yellow"
        continue
    }
    
    try {
        # Expand child VHDX
        Resize-VHD -Path $childVM.DiskPath -SizeBytes ($NewSizeGB * 1GB)
        
        # Verify expansion
        $newVhdInfo = Get-VHD -Path $childVM.DiskPath
        $newSizeGB = [math]::Round($newVhdInfo.Size / 1GB, 2)
        
        Write-ColorOutput "[SUCCESS] Expanded to $newSizeGB GB" "Green"
        $successCount++
    }
    catch {
        Write-ColorOutput "[ERROR] Failed to expand: $($_.Exception.Message)" "Red"
        $errorCount++
    }
}

Write-ColorOutput "`n===============================================================" "Cyan"
Write-ColorOutput "EXPANSION SUMMARY" "Cyan"
Write-ColorOutput "===============================================================" "Cyan"
Write-ColorOutput "Successfully expanded: $successCount VHDX(s)" "Green"
if ($errorCount -gt 0) {
    Write-ColorOutput "Errors encountered: $errorCount VHDX(s)" "Red"
}

if ($successCount -gt 0) {
    Write-ColorOutput "`nNext Steps:" "Cyan"
    Write-ColorOutput "1. Start your VMs" "White"
    Write-ColorOutput "2. In each guest OS, open Disk Management" "White"
    Write-ColorOutput "3. Right-click the partition -> 'Extend Volume'" "White"
    Write-ColorOutput "4. Follow the wizard to use the new space" "White"
}

Write-ColorOutput "`nOperation completed!" "Green" 