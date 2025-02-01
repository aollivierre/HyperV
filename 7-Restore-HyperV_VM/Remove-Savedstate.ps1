#the following script did not really a good job in removing the saved state of the VMs. I ended up using Hyper-V Manager to remove the saved state of the VMs and also change the External Switch to the correct one.


$vmcxFilePath = "E:\VM\Exported_July_29_2023\Backup_20230729_205257\Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12\Virtual Machines\8586ACF1-CE16-4DEC-B6E8-EF3122481D57.vmcx"

# Attempt to import the VM
$vm = Import-VM -Path $vmcxFilePath -Copy -GenerateNewId -ErrorAction SilentlyContinue

# Check if VM object exists
if ($vm) {
    # If the VM is in 'Saved' state, delete the saved state
    if ($vm.State -eq 'Saved') {
        Stop-VM -Name $vm.Name -Force -Confirm:$false
    }
    
    # Modify VM processor settings
    Set-VMProcessor -VMName $vm.Name -CompatibilityForMigrationEnabled $true

    # Connect VM to an available switch
    $availableSwitch = (Get-VMSwitch)[0].Name
    $vm.NetworkAdapters | ForEach-Object {
        Connect-VMNetworkAdapter -VMName $vm.Name -Name $_.Name -SwitchName $availableSwitch
    }
} else {
    Write-Host "Failed to import VM from $vmcxFilePath" -ForegroundColor Red
}