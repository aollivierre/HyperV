function AORemoveCustomHyperVEventLogs {
    # Retrieve all event logs matching the pattern *CreateNewHyperV_VM*
    $logs = Get-EventLog -List | Where-Object { $_.Log -like "*CreateNewHyperV_VM*" }

    # Iterate over each log and remove it
    foreach ($log in $logs) {
        Write-Host "Removing Event Log:" $log.Log
        Remove-EventLog -LogName $log.Log
    }
}
AORemoveCustomHyperVEventLogs