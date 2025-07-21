# Get dynamic memory status for running VMs
Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, DynamicMemoryEnabled | Format-Table -AutoSize