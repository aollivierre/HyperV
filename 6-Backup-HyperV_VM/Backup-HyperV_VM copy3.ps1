#start transcript and save to log file in the same directory as the script
# $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
# $scriptName = $MyInvocation.MyCommand.Name
# $transcriptFileName = Join-Path -Path $scriptPath -ChildPath "$scriptName.log"
# Start-Transcript -Path $transcriptFileName

# Check if the script is running as an administrator

function TestAdmin {
    $admin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
    return $admin
}

if (-not (TestAdmin)) {
    # Relaunch the script as an administrator
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`"" -Verb RunAs
    Exit
}


# $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
# $scriptName = $MyInvocation.MyCommand.Name
# $transcriptFileName = Join-Path -Path $scriptPath -ChildPath "$scriptName.log"
# Start-Transcript -Path $transcriptFileName

function Backup-HyperVVM {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    # Ensure the backup directory exists
    if (-not (Test-Path -Path $ExportPath)) {
        New-Item -Path $ExportPath -ItemType Directory
    }

    $allVMs = Get-VM

    #filter for VMs with the name Test013CPHA_HAADJ_PPKG_Clone_20230601_122449 and name Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12
    # $allVMs = $allVMs | Where-Object {$_.Name -eq "Test013CPHA_HAADJ_PPKG_Clone_20230601_122449" -or $_.Name -eq "Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12"}
    $allVMs = $allVMs | Where-Object {$_.Name -eq "Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12"}

    foreach ($vm in $allVMs) {
        $backupVMPath = Join-Path -Path $ExportPath -ChildPath "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

        # Export the VM
        try {
            Export-VM -Name $vm.Name -Path $backupVMPath
            Write-Host "Successfully backed up VM: $($vm.Name) to $backupVMPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to back up VM: $($vm.Name). Error: $_" -ForegroundColor Red
        }
    }
}

# Define backup location
$backupPath = "E:\VM\Exported_July_29_2023"
Backup-HyperVVM -ExportPath $backupPath

Write-Host "Backup process completed." -ForegroundColor Cyan

#stop transcript
# Stop-Transcript