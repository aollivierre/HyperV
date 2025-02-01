# # Start transcript and save to log file in the same directory as the script
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

function Restore-HyperVVM {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ImportPath
    )

    # Ensure the restore directory exists
    if (-not (Test-Path -Path $ImportPath)) {
        Write-Host "Restore directory $ImportPath doesn't exist. Exiting." -ForegroundColor Red
        return
    }

    $allRestoreFolders = Get-ChildItem -Path $ImportPath -Directory

    foreach ($restoreFolder in $allRestoreFolders) {
        # Import the VM
        try {
            Import-VM -Path (Join-Path $restoreFolder.FullName "Virtual Machines\*.vmcx") -Copy -GenerateNewId


            $HyperVHost = "localhost"  # Change this if you're querying a remote host
            $DefaultHyperVPath1_Restortingto = (Get-VMHost -ComputerName $HyperVHost).VirtualMachinePath
            $DefaultHyperVPath2_Restortingto =(Get-VMHost -ComputerName $HyperVHost).VirtualHardDiskPath


            Write-Host "restoring VM to: $DefaultHyperVPath2_Restortingto" -ForegroundColor Green

            Write-Host "Successfully restored VM from: $($restoreFolder.FullName)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to restore VM from: $($restoreFolder.FullName). Error: $_" -ForegroundColor Red
        }
    }
}

# Define restore location
$restorePath = "E:\VM\Exported_July_29_2023\Backup_20230729_182513"
Restore-HyperVVM -ImportPath $restorePath

Write-Host "Restore process completed." -ForegroundColor Cyan

# Stop transcript
# Stop-Transcript
