function Clone-HyperVVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourceVMName,

        [Parameter(Mandatory=$true)]
        [string]$DestinationVMName,

        [Parameter(Mandatory=$true)]
        [string]$ExportPath,

        [Parameter(Mandatory=$true)]
        [string]$ImportPath
    )

    # Add a timestamp to the export path
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ExportPath = Join-Path -Path $ExportPath -ChildPath "${SourceVMName}_$timestamp"

    # Check if the export directory exists, and if it does, append an incremental number to the directory name
    $counter = 1
    while (Test-Path -Path $ExportPath) {
        $ExportPath = Join-Path -Path (Split-Path -Path $ExportPath -Parent) -ChildPath "${SourceVMName}_$timestamp-$counter"
        $counter++
    }

    # Create the export directory
    New-Item -ItemType Directory -Path $ExportPath | Out-Null

    # Export the VM
    try {
        $tempExportPath = Join-Path -Path $ExportPath -ChildPath $SourceVMName
        Export-VM -Name $SourceVMName -Path $tempExportPath -ErrorAction Stop
        Move-Item -Path (Join-Path -Path $tempExportPath -ChildPath "Virtual Machines\*") -Destination $ExportPath
        Remove-Item -Path $tempExportPath -Recurse -Force
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Create the import path if it doesn't exist
    if (-not (Test-Path -Path $ImportPath)) {
        New-Item -ItemType Directory -Path $ImportPath | Out-Null
    }

    # Import the VM
    try {
        Import-VM -Path (Join-Path -Path $ExportPath -ChildPath "*.vmcx") `
                  -Copy -GenerateNewId -VirtualMachinePath $ImportPath `
                  -VhdDestinationPath $ImportPath -Name $DestinationVMName -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMName "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"


Clone-HyperVVM -SourceVMName "Win1022H2_Template_18_03_23_23_07_46" -DestinationVMName "MyVM_Clone" -ExportPath "D:\VM\ExportedVMs" -ImportPath "D:\VM\ImportedVMs"
