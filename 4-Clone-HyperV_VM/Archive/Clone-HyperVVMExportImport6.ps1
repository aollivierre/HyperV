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
        $vmcxPath = Join-Path -Path $ExportPath -ChildPath "$SourceVMName\Virtual Machines"
        $vmcxFile = Get-ChildItem -Path $vmcxPath -Filter "*.vmcx" | Select-Object -First 1
        $vmcxFilePath = Join-Path -Path $vmcxPath -ChildPath $vmcxFile.Name
        Import-VM -Path $vmcxFilePath -Copy -GenerateNewId -VirtualMachinePath $ImportPath -VhdDestinationPath $ImportPath -Name $DestinationVMName -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMName "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"
Clone-HyperVVM -SourceVMName "Win1022H2Template_19-03-23_14-04-52" -DestinationVMName "MyVM_Clone" -ExportPath "D:\VM\ExportedVMs" -ImportPath "D:\VM\ImportedVMs"
