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

    $successfulImports = 0

    foreach ($restoreFolder in $allRestoreFolders) {
        $vmcxFile = Get-ChildItem -Path (Join-Path $restoreFolder.FullName "Virtual Machines") -Filter "*.vmcx" -Recurse

        # Ensure that the .vmcx file exists before importing
        if ($vmcxFile) {
            # Import the VM
            try {
                Import-VM -Path $vmcxFile.FullName -Copy -GenerateNewId
                Write-Host "Successfully restored VM from: $($restoreFolder.FullName)" -ForegroundColor Green
                $successfulImports++
            }
            catch {
                Write-Host "Failed to restore VM from: $($restoreFolder.FullName). Error: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "No .vmcx file found in: $($restoreFolder.FullName). Skipping..." -ForegroundColor Yellow
        }
    }

    return $successfulImports
}

# VM count before importing
$initialVMCount = (Get-VM).Count

# Define restore location
$restorePath = "E:\VM\Exported_July_29_2023\Backup_20230729_182513\Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12\Virtual Machines"
$importedCount = Restore-HyperVVM -ImportPath $restorePath

# VM count after importing
$finalVMCount = (Get-VM).Count

Write-Host "Initial VM Count: $initialVMCount" -ForegroundColor Cyan
Write-Host "Successfully Imported VMs: $importedCount" -ForegroundColor Cyan
Write-Host "Total VMs after import: $finalVMCount" -ForegroundColor Cyan

# Validate successful imports
if ($importedCount -eq $finalVMCount - $initialVMCount) {
    Write-Host "All VMs imported successfully!" -ForegroundColor Green
}
else {
    Write-Host "Some VMs failed to import." -ForegroundColor Red
}

# Stop transcript
# Stop-Transcript




$vmcxFilePath = "E:\VM\Exported_July_29_2023\Backup_20230729_205257\Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12\Virtual Machines\8586ACF1-CE16-4DEC-B6E8-EF3122481D57.vmcx"
Import-VM -Path $vmcxFilePath -Copy -GenerateNewId



$vmcxFilePath = "E:\VM\Exported_July_29_2023\Backup_20230729_205257\Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12\Virtual Machines\8586ACF1-CE16-4DEC-B6E8-EF3122481D57.vmcx"
$compareResult = Compare-VM -Path $vmcxFilePath

$compareResult.Incompatibilities | ForEach-Object {
    Write-Host "$($_.Source) - $($_.Message)" -ForegroundColor Red
}


$vmcxFilePath = "E:\VM\Exported_July_29_2023\Backup_20230729_205257\Win10_LHC_RDS_AADJ_CKRBTGT_WH4B_DEMO_16-06-23_10_26_12\Virtual Machines\8586ACF1-CE16-4DEC-B6E8-EF3122481D57.vmcx"
$vm = Import-VM -Path $vmcxFilePath -Copy -GenerateNewId -ErrorAction SilentlyContinue
Set-VMProcessor -VMName $vm.Name -CompatibilityForMigrationEnabled $true
