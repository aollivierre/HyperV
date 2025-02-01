# Check if the current session is running as an administrator
function TestAdmin {
    $admin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
    return $admin
}

if (-not (TestAdmin)) {
    # Relaunch the script as an administrator
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`"" -Verb RunAs
    Exit
}

function Backup-FirstHyperVVM {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    # Ensure the backup directory exists
    if (-not (Test-Path -Path $ExportPath)) {
        New-Item -Path $ExportPath -ItemType Directory
    }

    # Get only the first VM
    $vm = Get-VM | Select-Object -First 1

    # Construct a unique directory for this VM based on its name and the current date/time
    $backupVMPath = Join-Path -Path $ExportPath -ChildPath "$($vm.Name)_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    # Export the VM
    try {
        Export-VM -Name $vm.Name -Path $backupVMPath
        Write-Host "Successfully backed up VM: $($vm.Name) to $backupVMPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to back up VM: $($vm.Name). Error: $_" -ForegroundColor Red
    }
}

# Define backup location
$backupPath = "E:\VM\Exported_July_29_2023"
Backup-FirstHyperVVM -ExportPath $backupPath

Write-Host "Backup process for the first VM completed." -ForegroundColor Cyan
