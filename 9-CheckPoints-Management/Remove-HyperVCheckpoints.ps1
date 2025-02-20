#Requires -Modules Hyper-V, PSWriteHTML

# Script to generate a detailed HTML report of HyperV checkpoints and remove them
# Author: Anthony Ollivierre
# Date: 2025-02-13

# Function to convert bytes to readable size
function Convert-Size {
    param([long]$Size)
    $sizes = 'Bytes,KB,MB,GB,TB'
    $sizes = $sizes.Split(',')
    $index = 0
    while ($Size -ge 1kb -and $index -lt ($sizes.Count - 1)) {
        $Size = $Size / 1kb
        $index++
    }
    return "{0:N2} {1}" -f $Size, $sizes[$index]
}

# Get all VMs
$VMs = Get-VM

# Initialize collection for checkpoint data
$checkpointData = @()

# Collect checkpoint information for each VM
foreach ($VM in $VMs) {
    $checkpoints = Get-VMSnapshot -VMName $VM.Name
    
    if ($checkpoints) {
        foreach ($checkpoint in $checkpoints) {
            # Get checkpoint size (this might take some time for large checkpoints)
            $size = (Get-VHD -Path (Get-VMHardDiskDrive -VM $VM).Path -ErrorAction SilentlyContinue).FileSize
            
            $checkpointData += [PSCustomObject]@{
                VMName = $VM.Name
                CheckpointName = $checkpoint.Name
                CreationTime = $checkpoint.CreationTime
                Size = Convert-Size -Size $size
                RawSize = $size
                ParentCheckpointName = $checkpoint.ParentCheckpointName
                CheckpointType = $checkpoint.SnapshotType
            }
        }
    }
}

# Generate Summary Data
$totalCheckpoints = $checkpointData.Count
$totalSize = Convert-Size -Size ($checkpointData | Measure-Object -Property RawSize -Sum).Sum
$affectedVMs = ($checkpointData | Select-Object VMName -Unique).Count

# Generate HTML Report
New-HTML -TitleText 'HyperV Checkpoint Removal Report' -FilePath "HyperV_Checkpoint_Report.html" -ShowHTML {
    New-HTMLSection -HeaderText 'Summary' {
        New-HTMLPanel {
            New-HTMLText -Text @(
                "Total Checkpoints Found: $totalCheckpoints",
                "Total Size: $totalSize",
                "Affected VMs: $affectedVMs"
            ) -FontSize 14
        }
    }

    New-HTMLSection -HeaderText 'Detailed Checkpoint Information' {
        New-HTMLTable -DataTable $checkpointData -Filtering {
            New-TableHeader -Color Black -BackgroundColor LightSteelBlue
        } -PagingOptions @(10, 25, 50, 100)
    }

    # Add VM-specific summary
    New-HTMLSection -HeaderText 'VM Summary' {
        $vmSummary = $checkpointData | Group-Object VMName | ForEach-Object {
            [PSCustomObject]@{
                VMName = $_.Name
                CheckpointCount = $_.Count
                TotalSize = Convert-Size -Size ($_.Group | Measure-Object -Property RawSize -Sum).Sum
            }
        }
        
        New-HTMLTable -DataTable $vmSummary -Filtering {
            New-TableHeader -Color Black -BackgroundColor LightSteelBlue
        }
    }
} 

# Display summary and ask for confirmation
Write-Host "`nCheckpoint Summary:" -ForegroundColor Cyan
Write-Host "Total Checkpoints to be removed: $totalCheckpoints" -ForegroundColor Yellow
Write-Host "Total Size to be freed: $totalSize" -ForegroundColor Yellow
Write-Host "Number of VMs affected: $affectedVMs" -ForegroundColor Yellow
Write-Host "`nThe HTML report has been generated at 'HyperV_Checkpoint_Report.html'. Please review it before proceeding." -ForegroundColor Green

$confirmation = Read-Host "`nDo you want to proceed with removing all checkpoints? (Y/N)"
if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
    # Remove all checkpoints after report generation
    Write-Host "`nRemoving all checkpoints..." -ForegroundColor Yellow
    foreach ($VM in $VMs) {
        $checkpoints = Get-VMSnapshot -VMName $VM.Name
        if ($checkpoints) {
            Write-Host "Removing checkpoints for VM: $($VM.Name)" -ForegroundColor Cyan
            try {
                # Get all checkpoints and sort them by creation time (newest first)
                $sortedCheckpoints = $checkpoints | Sort-Object CreationTime -Descending
                
                # Remove each checkpoint individually
                foreach ($checkpoint in $sortedCheckpoints) {
                    Write-Host "  Removing checkpoint: $($checkpoint.Name)" -ForegroundColor Gray
                    try {
                        Remove-VMSnapshot -VMName $VM.Name -Name $checkpoint.Name -ErrorAction Stop
                        Start-Sleep -Seconds 2  # Add small delay between removals
                    }
                    catch {
                        Write-Warning "Failed to remove checkpoint '$($checkpoint.Name)' from VM '$($VM.Name)': $_"
                        # Try alternative removal method
                        try {
                            Write-Host "  Attempting alternative removal method..." -ForegroundColor Yellow
                            $checkpoint | Remove-VMSnapshot -ErrorAction Stop
                        }
                        catch {
                            Write-Error "All attempts to remove checkpoint '$($checkpoint.Name)' failed: $_"
                        }
                    }
                }
            }
            catch {
                Write-Error "Error processing checkpoints for VM '$($VM.Name)': $_"
            }
        }
    }
    Write-Host "`nProcess completed. Check above for any warnings or errors." -ForegroundColor Green
} else {
    Write-Host "`nOperation cancelled. No checkpoints were removed." -ForegroundColor Red
    Write-Host "You can review the checkpoint details in 'HyperV_Checkpoint_Report.html'" -ForegroundColor Yellow
}
