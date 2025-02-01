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
        Import-VM -Path (Join-Path -Path $ExportPath -ChildPath "Virtual Machines\*.vmcx") `
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
