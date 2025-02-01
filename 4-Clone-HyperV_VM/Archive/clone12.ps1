function Clone-HyperVVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceVMName,

        [Parameter(Mandatory = $true)]
        [string]$DestinationVMDescription,

        [Parameter(Mandatory = $true)]
        [string]$ExportPath,

        [Parameter(Mandatory = $true)]
        [string]$ImportPath
    )

    # Check for duplicate VM names
    $allVms = Get-VM
    $duplicateNameVms = $allVms | Where-Object { $_.Name -eq $SourceVMName }
    if ($duplicateNameVms) {
        Write-Host ("Duplicate VM names found: " + ($duplicateNameVms | ForEach-Object { $_.Name }) -join ", ") -ForegroundColor Yellow
    } else {
        Write-Host "No duplicate VM names found." -ForegroundColor Green
    }

    # Check for duplicate VM IDs
    $duplicateIdVms = $allVms | Group-Object VMId | Where-Object { $_.Count -gt 1 }
    if ($duplicateIdVms) {
        Write-Host ("Duplicate VM IDs found: " + ($duplicateIdVms | ForEach-Object { $_.Name }) -join ", ") -ForegroundColor Yellow
    } else {
        Write-Host "No duplicate VM IDs found." -ForegroundColor Green
    }

    # Create a checkpoint of the source VM
    try {
        Checkpoint-VM -Name $SourceVMName -SnapshotName "Pre-Clone Snapshot - $(Get-Date -Format 'yyyyMMdd_HHmmss')" -ErrorAction Stop
        Write-Host "Created a checkpoint for VM: $SourceVMName" -ForegroundColor Green
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Add the rest of the existing Clone-HyperVVM script here, without modifications

    # Provide a summary at the end
    $totalVmsBefore = $allVms.Count
    $totalVmsAfter = (Get-VM).Count
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host ("Total VMs before: $totalVmsBefore") -ForegroundColor Cyan
    Write-Host ("Total VMs after: $totalVmsAfter") -ForegroundColor Cyan
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMDescription "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"
$cloneParams = @{
    SourceVMName             = "Win1022H2Template_19-03-23_14-04-52"
    DestinationVMDescription = "BatmanSuperMan"
    ExportPath               = "D:\VM\ExportedVMs"
    ImportPath               = "D:\VM\ImportedVMs"
}
Clone-HyperVVM @cloneParams