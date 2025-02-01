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
    }
    else {
        Write-Host "No duplicate VM names found." -ForegroundColor Green
    }

    # Check for duplicate VM IDs
    $duplicateIdVms = $allVms | Group-Object VMId | Where-Object { $_.Count -gt 1 }
    if ($duplicateIdVms) {
        Write-Host ("Duplicate VM IDs found: " + ($duplicateIdVms | ForEach-Object { $_.Name }) -join ", ") -ForegroundColor Yellow
    }
    else {
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

    # Check the state of the source VM and stop it if it's running
    $sourceVm = Get-VM -Name $SourceVMName
    $vmState = $sourceVm.State
    # $stopVm = $false
    if ($vmState -eq 'Running' -or $vmState -eq 'Saved') {
        Write-Host "Stopping VM: $SourceVMName" -ForegroundColor Yellow
        Stop-VM -VMName $SourceVMName -Force
        # $stopVm = $true
    }

    # Remove the DVD drive from the source VM if it exists other wise the Imported VM will boot from the DVD/ISO
    try {
        $dvdDrive = Get-VMDvdDrive -VMName $SourceVMName
        if ($dvdDrive) {
            $controllerNumber = $dvdDrive.ControllerNumber
            $controllerLocation = $dvdDrive.ControllerLocation
            Remove-VMDvdDrive -VMName $SourceVMName -ControllerNumber $controllerNumber -ControllerLocation $controllerLocation -ErrorAction Stop
            Write-Host "Removed DVD drive from VM: $SourceVMName" -ForegroundColor Green
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Start the VM if it was initially running
    # if ($stopVm) {
    #     Write-Host "Starting VM: $SourceVMName" -ForegroundColor Yellow
    #     Start-VM -VMName $SourceVMName
    # }




    # Add a timestamp to the export path
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ExportPath = Join-Path -Path $ExportPath -ChildPath "${SourceVMName}_$timestamp"

    # Check if the export directory exists, and if it does, append an incremental number to the directory name
    $counter = 1
    while (Test-Path -Path $ExportPath) {
        $ExportPath = Join-Path -Path (Split-Path -Path $ExportPath -Parent) -ChildPath "${SourceVMName}_$timestamp-$counter"
        $counter++
    }

    # Export the VM
    try {
        $exportParams = @{
            Name        = $SourceVMName
            Path        = $ExportPath
            ErrorAction = 'Stop'
        }
        Export-VM @exportParams
        # "Exported VM: $SourceVMName" | Join-String -op $PSStyle.Background.BrightGreen -os $PSStyle.Reset | Write-Information
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Create the import path if it doesn't exist
    $ImportPath = Join-Path -Path $ImportPath -ChildPath "${DestinationVMDescription}_$timestamp"
    if (-not (Test-Path -Path $ImportPath)) {
        try {
            New-Item -ItemType Directory -Path $ImportPath -ErrorAction Stop | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    # Get the VMCX file from the exported VM folder
    $vmcxFile = Get-ChildItem -Path (Join-Path -Path $ExportPath -ChildPath $SourceVMName) -Filter "*.vmcx" -Recurse | Select-Object -First 1

    # Import the VM
    try {
        $importParams = @{
            Path               = $vmcxFile.FullName
            # Name = $DestinationVMName
            Copy               = $true
            GenerateNewId      = $true
            VirtualMachinePath = $ImportPath
            VhdDestinationPath = $ImportPath
            ErrorAction        = 'Stop'
        }
        # Get the imported VM by VMId
        $importedVmId = (Import-VM @importParams).VMId
        #  $DBG
        # Import-VM @importParams
        # "Imported VM: $DestinationVMName" | Join-String -op $PSStyle.Background.BrightGreen -os $PSStyle.Reset | Write-Information

        $vm = Get-VM | Where-Object { $_.VMId -eq $importedVmId }
        # $DBG

        # Generate a dynamic DestinationVMName based on the SourceVMName and a timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $DestinationVMName = "${SourceVMName}_Pending_SysPrep_Clone_$timestamp"

        # Rename the imported VM
        Rename-VM -VM $vm -NewName $DestinationVMName
        # $DBG

        # Rename the virtual hard disk file
        $vhd = Get-VHD -VMId $vm.VMId | Select-Object -First 1
        $newVhdPath = Join-Path -Path (Split-Path -Path $vhd.Path -Parent) -ChildPath "${DestinationVMName}.vhdx"
        Rename-Item -Path $vhd.Path -NewName $newVhdPath

        # Check the state of the destination VM and stop it if it's running or in a saved state
        $destVmState = $vm.State
        if ($destVmState -eq 'Running' -or $destVmState -eq 'Saved') {
            Write-Host "Stopping VM: $DestinationVMName" -ForegroundColor Yellow
            Stop-VM -VM $vm -Force
        }

        # Update the VM's hard disk drive
        Remove-VMHardDiskDrive -VMName $DestinationVMName -ControllerType SCSI -ControllerLocation 0 -ControllerNumber 0
        Add-VMHardDiskDrive -VMName $DestinationVMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path $newVhdPath


        # Change the MAC address of the virtual adapter
        Set-VMNetworkAdapter -VMName $DestinationVMName -DynamicMacAddress

        # Update the VM notes
        $vmNotes = "This VM was cloned from '$SourceVMName' on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')."
        Set-VM -VMName $DestinationVMName -Notes $vmNotes

        # Start the VM
        Write-Host "Starting VM: $DestinationVMName" -ForegroundColor Yellow
        Start-VM -Name $DestinationVMName

        # Wait for the VM to start and the network to be available
        # Start-Sleep -Seconds 60

        # Remote into the VM and sysprep
        # $credentials = Get-Credential

        # Replace 'YourUsername' and 'YourPassword' with your actual credentials
        # $username = "Admin-CCI"
        # $password = "Whatever Your Password is" | ConvertTo-SecureString -AsPlainText -Force
        # $credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password

        # $sysprepScript = {
        #     $sysprepPath = "${env:windir}\system32\sysprep\sysprep.exe"
        #     & $sysprepPath /generalize /shutdown /oobe
        # }

        # Invoke-Command -ComputerName $DestinationVMName -Credential $credentials -ScriptBlock $sysprepScript


        # Provide a summary at the end
        $totalVmsBefore = $allVms.Count
        $totalVmsAfter = (Get-VM).Count
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host ("Total VMs before: $totalVmsBefore") -ForegroundColor Cyan
        Write-Host ("Total VMs after: $totalVmsAfter") -ForegroundColor Cyan
        Write-Host ("New VM Name: $DestinationVMName") -ForegroundColor Cyan
        Write-Host ("Connect to the VM: $DestinationVMName via VM Connect and run Sysprep (do not Sysprep more than 3 times)") -ForegroundColor Cyan

    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMName "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"
$cloneParams = @{
    SourceVMName             = "Win1022H2Template_19-03-23_18-31-11"
    DestinationVMDescription = "BatmanSuperMan"
    ExportPath               = "D:\VM\ExportedVMs"
    ImportPath               = "D:\VM\ImportedVMs"
}
Clone-HyperVVM @cloneParams