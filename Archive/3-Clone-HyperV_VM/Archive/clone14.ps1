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
    # ...
    # Check for duplicate VM IDs
    # ...
    # Create a checkpoint of the source VM
    # ...

    # Remove the DVD drive from the source VM
    try {
        $sourceVm = Get-VM -Name $SourceVMName
        $dvdDrive = Get-VMDvdDrive -VM $sourceVm
        if ($dvdDrive) {
            Remove-VMDvdDrive -VM $sourceVm -ErrorAction Stop
            Write-Host "Removed DVD drive from VM: $SourceVMName" -ForegroundColor Green
        }
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
    Write-Host ("New VM Name: $DestinationVMName") -ForegroundColor Cyan
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
