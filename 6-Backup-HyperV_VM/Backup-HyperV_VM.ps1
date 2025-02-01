function Backup-HyperVVM {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    $allVMs = Get-VM

    foreach ($vm in $allVMs) {
        $backupParams = @{
            SourceVMName             = $vm.Name
            DestinationVMDescription = "${vm.Name}_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            ExportPath               = $ExportPath
            ImportPath               = $ExportPath
        }

        Clone-HyperVVM @backupParams
    }
}

# Define backup location
$backupPath = "E:\VM\Exported_July_20_2023"
Backup-HyperVVM -ExportPath $backupPath

Write-Host "All VMs have been backed up to $backupPath" -ForegroundColor Green
