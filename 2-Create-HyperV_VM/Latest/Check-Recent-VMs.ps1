Get-VM | Where-Object { $_.Name -like '*098*' -or $_.Name -like '*099*' } | ForEach-Object { 
    Write-Host "VM: $($_.Name)" -ForegroundColor Yellow
    $nics = Get-VMNetworkAdapter -VMName $_.Name
    Write-Host "  NICs: $($nics.Count)" -ForegroundColor Green
    $nics | Select-Object Name, SwitchName | Format-Table -AutoSize
    Write-Host ''
}