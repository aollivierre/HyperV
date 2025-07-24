# Check VM 096 properties
$vmName = '096 - ABC Lab - Win 10 migration to Windows 11_VM'
$vm = Get-VM -Name $vmName

Write-Host "VM Properties:" -ForegroundColor Cyan
Write-Host "Name: $($vm.Name)"
Write-Host "State: $($vm.State)"
Write-Host "Generation: $($vm.Generation)"
Write-Host "ProcessorCount: $($vm.ProcessorCount)"

# Check Secure Boot
$firmware = Get-VMFirmware -VMName $vmName
Write-Host "`nSecurity Settings:" -ForegroundColor Cyan
Write-Host "Secure Boot: $($firmware.SecureBoot)"
Write-Host "Secure Boot Template: $($firmware.SecureBootTemplate)"

# Check TPM
$security = Get-VMSecurity -VMName $vmName
Write-Host "TPM Enabled: $($security.TpmEnabled)"

# Check Memory
$memory = Get-VMMemory -VMName $vmName
Write-Host "`nMemory Settings:" -ForegroundColor Cyan
Write-Host "Startup: $([Math]::Round($memory.Startup / 1GB, 2))GB"
Write-Host "Minimum: $([Math]::Round($memory.Minimum / 1GB, 2))GB"
Write-Host "Maximum: $([Math]::Round($memory.Maximum / 1GB, 2))GB"
Write-Host "Dynamic Memory: $($memory.DynamicMemoryEnabled)"