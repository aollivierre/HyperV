#!/usr/bin/env powershell

<#
.SYNOPSIS
    Prepares a parent VHDX for expansion by checking dependencies and guiding through proper shutdown procedures.

.DESCRIPTION
    This script checks for VMs using a parent VHDX file, identifies and removes snapshots/checkpoints,
    and guides the user through graceful shutdown of dependent VMs before attempting VHDX expansion.

.PARAMETER VHDXPath
    The full path to the parent VHDX file to be expanded

.PARAMETER NewSizeGB
    The new size for the VHDX in GB

.EXAMPLE
    .\Prepare-VHDX-Expansion.ps1 -VHDXPath "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX" -NewSizeGB 200
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VHDXPath,
    
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

# Function to get user confirmation
function Get-UserConfirmation {
    param([string]$Message)
    
    do {
        $response = Read-Host "$Message (Y/N)"
    } while ($response -notmatch '^[YyNn]$')
    
    return ($response -match '^[Yy]$')
}

# Function to wait for user to complete action
function Wait-ForUserAction {
    param([string]$Message)
    
    Write-ColorOutput "`n$Message" "Yellow"
    Read-Host "Press Enter when you have completed this action"
}

# Function to find VMs using the specified VHDX (including differencing disks)
function Get-VMsUsingVHDX {
    param([string]$VHDXPath)
    
    $dependentVMs = @()
    $allVMs = Get-VM
    
    foreach ($vm in $allVMs) {
        $vmDisks = Get-VMHardDiskDrive -VM $vm
        
        foreach ($disk in $vmDisks) {
            # Check direct usage
            if ($disk.Path -eq $VHDXPath) {
                $dependentVMs += [PSCustomObject]@{
                    VMName = $vm.Name
                    State = $vm.State
                    DiskPath = $disk.Path
                    RelationType = "Direct"
                }
            }
            # Check if this is a differencing disk with our VHDX as parent
            elseif ($disk.Path -and (Test-Path $disk.Path)) {
                try {
                    $vhdInfo = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
                    if ($vhdInfo -and $vhdInfo.ParentPath -eq $VHDXPath) {
                        $dependentVMs += [PSCustomObject]@{
                            VMName = $vm.Name
                            State = $vm.State
                            DiskPath = $disk.Path
                            RelationType = "Child (Differencing)"
                        }
                    }
                }
                catch {
                    # Skip if we can't read VHD info
                }
            }
        }
    }
    
    return $dependentVMs
}

# Function to get and remove snapshots
function Remove-VMSnapshots {
    param([array]$VMs)
    
    $snapshotsFound = $false
    
    foreach ($vmInfo in $VMs) {
        $vm = Get-VM -Name $vmInfo.VMName
        $snapshots = Get-VMSnapshot -VM $vm -ErrorAction SilentlyContinue
        
        if ($snapshots) {
            $snapshotsFound = $true
            Write-ColorOutput "`nSnapshots found for VM '$($vm.Name)':" "Yellow"
            
            foreach ($snapshot in $snapshots) {
                Write-ColorOutput "  - $($snapshot.Name) (Created: $($snapshot.CreationTime))" "Cyan"
            }
            
            if (Get-UserConfirmation "Remove all snapshots for VM '$($vm.Name)'?") {
                Write-ColorOutput "Removing snapshots for '$($vm.Name)'..." "Yellow"
                
                try {
                    $snapshots | Remove-VMSnapshot -Confirm:$false
                    Write-ColorOutput "[SUCCESS] Snapshots removed successfully for '$($vm.Name)'" "Green"
                }
                catch {
                    Write-ColorOutput "[ERROR] Error removing snapshots for '$($vm.Name)': $($_.Exception.Message)" "Red"
                    return $false
                }
            }
            else {
                Write-ColorOutput "[ERROR] Cannot proceed without removing snapshots for '$($vm.Name)'" "Red"
                return $false
            }
        }
    }
    
    if (-not $snapshotsFound) {
        Write-ColorOutput "[OK] No snapshots found on any dependent VMs" "Green"
    }
    
    return $true
}

# Function to check and handle running VMs
function Handle-RunningVMs {
    param([array]$VMs)
    
    $runningVMs = $VMs | Where-Object { $_.State -eq "Running" }
    
    if ($runningVMs) {
        Write-ColorOutput "`n[WARNING] The following VMs are currently RUNNING and use this VHDX:" "Red"
        Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Red"
        
        foreach ($vm in $runningVMs) {
            Write-ColorOutput "  • VM Name: $($vm.VMName)" "Yellow"
            Write-ColorOutput "    Relationship: $($vm.RelationType)" "Cyan"
            Write-ColorOutput "    Disk Path: $($vm.DiskPath)" "Gray"
            Write-ColorOutput ""
        }
        
        Write-ColorOutput "IMPORTANT: You must gracefully shut down these VMs from WITHIN the guest OS." "Red"
        Write-ColorOutput "Do NOT use 'Turn Off' or 'Stop-VM' commands as this may cause data corruption." "Red"
        Write-ColorOutput "`nTo shut down gracefully:" "Yellow"
        Write-ColorOutput "1. Connect to each VM using Hyper-V Manager or VM Connect" "White"
        Write-ColorOutput "2. Log into the guest operating system" "White"
        Write-ColorOutput "3. Use the guest OS shutdown command (Start → Power → Shut down)" "White"
        Write-ColorOutput "4. Wait for the VM to completely power off" "White"
        
        Wait-ForUserAction "Please shut down all the above VMs gracefully from within the guest OS, then continue"
        
        return $false # Indicates we need to recheck
    }
    
    return $true # All VMs are already stopped
}

# Main script execution
Clear-Host
Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "         HYPER-V VHDX EXPANSION PREPARATION SCRIPT" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"

Write-ColorOutput "`nTarget VHDX: $VHDXPath" "White"
Write-ColorOutput "New Size: $NewSizeGB GB" "White"

# Check if VHDX file exists
if (-not (Test-Path $VHDXPath)) {
    Write-ColorOutput "[ERROR] VHDX file not found at specified path!" "Red"
    exit 1
}

# Check if Hyper-V module is available
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-ColorOutput "[ERROR] Hyper-V PowerShell module not found!" "Red"
    exit 1
}

Write-ColorOutput "`nStep 1: Finding VMs that use this VHDX..." "Cyan"

# Find all VMs using this VHDX
$dependentVMs = Get-VMsUsingVHDX -VHDXPath $VHDXPath

if ($dependentVMs.Count -eq 0) {
    Write-ColorOutput "[OK] No VMs are currently using this VHDX file." "Green"
}
else {
    Write-ColorOutput "`nFound $($dependentVMs.Count) VM(s) using this VHDX:" "Yellow"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Yellow"
    
    foreach ($vm in $dependentVMs) {
        Write-ColorOutput "  • VM: $($vm.VMName) [$($vm.State)]" "White"
        Write-ColorOutput "    Type: $($vm.RelationType)" "Cyan"
        Write-ColorOutput "    Disk: $($vm.DiskPath)" "Gray"
        Write-ColorOutput ""
    }
}

# Step 2: Handle snapshots
Write-ColorOutput "Step 2: Checking for snapshots/checkpoints..." "Cyan"

if ($dependentVMs.Count -gt 0) {
    if (-not (Remove-VMSnapshots -VMs $dependentVMs)) {
        Write-ColorOutput "[ERROR] Cannot proceed due to snapshot removal issues." "Red"
        exit 1
    }
}

# Step 3: Handle running VMs (with retry loop)
Write-ColorOutput "`nStep 3: Checking VM states..." "Cyan"

do {
    # Refresh VM information
    $dependentVMs = Get-VMsUsingVHDX -VHDXPath $VHDXPath
    $allStopped = Handle-RunningVMs -VMs $dependentVMs
    
    if (-not $allStopped) {
        # Recheck after user action
        Write-ColorOutput "`nRechecking VM states..." "Cyan"
        Start-Sleep -Seconds 2
    }
    
} while (-not $allStopped)

Write-ColorOutput "[OK] All dependent VMs are now stopped." "Green"

# Step 4: Attempt the resize
Write-ColorOutput "`nStep 4: Attempting VHDX expansion..." "Cyan"

try {
    # Final check - make sure file isn't locked
    $fileInfo = Get-Item $VHDXPath
    Write-ColorOutput "Current VHDX size: $([math]::Round($fileInfo.Length / 1GB, 2)) GB" "White"
    
    # Attempt resize
    Write-ColorOutput "Expanding VHDX to $NewSizeGB GB..." "Yellow"
    Resize-VHD -Path $VHDXPath -SizeBytes ($NewSizeGB * 1GB)
    
    # Verify new size
    $vhdInfo = Get-VHD -Path $VHDXPath
    $newSizeGB = [math]::Round($vhdInfo.Size / 1GB, 2)
    
    Write-ColorOutput "[SUCCESS] Parent VHDX expanded to $newSizeGB GB" "Green"
    
    # Step 5: Expand child/differencing VHDXs
    if ($dependentVMs.Count -gt 0) {
        Write-ColorOutput "`nStep 5: Expanding child/differencing VHDXs..." "Cyan"
        
        # Check if the standalone child expansion script exists
        $childScriptPath = Join-Path $PSScriptRoot "Expand-Child-VHDXs.ps1"
        
        if (Test-Path $childScriptPath) {
            Write-ColorOutput "Using dedicated child expansion script..." "Yellow"
            try {
                # Call the dedicated script with same parameters
                & $childScriptPath -ParentVHDXPath $VHDXPath -NewSizeGB $NewSizeGB
            }
            catch {
                Write-ColorOutput "[ERROR] Failed to execute child expansion script: $($_.Exception.Message)" "Red"
                Write-ColorOutput "Falling back to integrated expansion method..." "Yellow"
            }
        }
        else {
            # Fallback: Integrated expansion logic
            $childVMs = $dependentVMs | Where-Object { $_.RelationType -eq "Child (Differencing)" }
            
            if ($childVMs.Count -gt 0) {
                Write-ColorOutput "Found $($childVMs.Count) child VHDX(s) that need to be expanded:" "Yellow"
                
                $successCount = 0
                $errorCount = 0
                
                foreach ($childVM in $childVMs) {
                    Write-ColorOutput "`nExpanding: $($childVM.VMName)" "White"
                    Write-ColorOutput "Path: $($childVM.DiskPath)" "Gray"
                    
                    try {
                        # Get current size of child VHDX
                        $childVhdInfo = Get-VHD -Path $childVM.DiskPath
                        $currentChildSizeGB = [math]::Round($childVhdInfo.Size / 1GB, 2)
                        
                        if ($currentChildSizeGB -ge $NewSizeGB) {
                            Write-ColorOutput "[SKIP] Already $currentChildSizeGB GB (>= target)" "Yellow"
                            continue
                        }
                        
                        Write-ColorOutput "Current: $currentChildSizeGB GB -> Target: $NewSizeGB GB" "Cyan"
                        
                        # Expand child VHDX to match parent
                        Resize-VHD -Path $childVM.DiskPath -SizeBytes ($NewSizeGB * 1GB)
                        
                        # Verify expansion
                        $newChildVhdInfo = Get-VHD -Path $childVM.DiskPath
                        $newChildSizeGB = [math]::Round($newChildVhdInfo.Size / 1GB, 2)
                        
                        Write-ColorOutput "[SUCCESS] Expanded to $newChildSizeGB GB" "Green"
                        $successCount++
                    }
                    catch {
                        Write-ColorOutput "[ERROR] Failed to expand: $($_.Exception.Message)" "Red"
                        $errorCount++
                    }
                }
                
                Write-ColorOutput "`nChild Expansion Summary:" "Cyan"
                Write-ColorOutput "Successful: $successCount | Errors: $errorCount" "White"
            }
            else {
                Write-ColorOutput "[OK] No child VHDXs found to expand." "Green"
            }
        }
        
        Write-ColorOutput "`nNext Steps:" "Cyan"
        Write-ColorOutput "1. Start your VMs that use this VHDX" "White"
        Write-ColorOutput "2. In each guest OS, open Disk Management" "White"
        Write-ColorOutput "3. Right-click the partition → 'Extend Volume'" "White"
        Write-ColorOutput "4. Follow the wizard to use the new space" "White"
    }
}
catch {
    Write-ColorOutput "[ERROR] Error expanding VHDX: $($_.Exception.Message)" "Red"
    
    if ($_.Exception.Message -match "being used by another process") {
        Write-ColorOutput "`n[WARNING] The file is still locked. This could mean:" "Yellow"
        Write-ColorOutput "• A VM is still running or starting up" "White"
        Write-ColorOutput "• A snapshot merge operation is in progress" "White"
        Write-ColorOutput "• Another Hyper-V operation is accessing the file" "White"
        Write-ColorOutput "`nWait a few minutes and try running the script again." "White"
    }
    
    exit 1
}

Write-ColorOutput "`n═══════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "                    OPERATION COMPLETED" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan" 