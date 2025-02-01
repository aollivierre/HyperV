# Remove the DVD drive from the source VM
try {
    $sourceVm = Get-VM -Name $SourceVMName
    $dvdDrive = Get-VMDvdDrive -VMName $SourceVMName
    if ($dvdDrive) {
        $vmState = $sourceVm.State
        if ($vmState -eq 'Running') {
            Write-Host "Stopping VM: $SourceVMName" -ForegroundColor Yellow
            Stop-VM -VMName $SourceVMName -Force
        }
        
        $controllerNumber = $dvdDrive.ControllerNumber
        $controllerLocation = $dvdDrive.ControllerLocation
        Remove-VMDvdDrive -VMName $SourceVMName -ControllerNumber $controllerNumber -ControllerLocation $controllerLocation -ErrorAction Stop
        Write-Host "Removed DVD drive from VM: $SourceVMName" -ForegroundColor Green

        if ($vmState -eq 'Running') {
            Write-Host "Starting VM: $SourceVMName" -ForegroundColor Yellow
            Start-VM -VMName $SourceVMName
        }
    }
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}
