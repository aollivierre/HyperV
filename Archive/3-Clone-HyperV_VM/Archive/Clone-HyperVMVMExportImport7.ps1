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

    # Export the VM
    try {
        Export-VM -Name $SourceVMName -Path $ExportPath -ErrorAction Stop
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
        $importedVM = Import-VM -Path (Join-Path -Path $ExportPath -ChildPath "$SourceVMName\Virtual Machines\*.vmcx") `
                     -Copy -GenerateNewId -VirtualMachinePath $ImportPath -ErrorAction Stop

        # Rename the imported VM
        $importedVM | Rename-VM -NewName $DestinationVMName -PassThru | Set-VMProcessor -Count 2 -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMName "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"
Clone-HyperVVM -SourceVMName "Win1022H2Template_19-03-23_14-04-52" -DestinationVMName "MyVM_Clone" -ExportPath "D:\VM\ExportedVMs" -ImportPath "D:\VM\ImportedVMs"
