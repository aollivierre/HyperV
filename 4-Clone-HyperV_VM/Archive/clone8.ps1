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
        $exportParams = @{
            Name = $SourceVMName
            Path = $ExportPath
            ErrorAction = 'Stop'
        }
        Export-VM @exportParams
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Create the import path if it doesn't exist
    if (-not (Test-Path -Path $ImportPath)) {
        try {
            New-Item -ItemType Directory -Path $ImportPath -ErrorAction Stop | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    # Import the VM
    try {
        $importParams = @{
            # Path = Join-Path -Path $ExportPath -ChildPath "$SourceVMName\Virtual Machines\*.vmcx"
            Path = "D:\VM\ExportedVMs\Win1022H2Template_19-03-23_14-04-52_20230319_153910\Win1022H2Template_19-03-23_14-04-52\Virtual Machines\29E59B85-14A3-4BCE-9AA4-EDDE1C5D9546.vmcx"
            Copy = $true
            GenerateNewId = $true
            VirtualMachinePath = $ImportPath
            VhdDestinationPath = $ImportPath
            ErrorAction = 'Stop'
        }
        Import-VM @importParams
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

# Example usage:
# Clone-HyperVVM -SourceVMName "MyVM" -DestinationVMName "MyVM_Clone" -ExportPath "C:\ExportedVMs" -ImportPath "C:\ImportedVMs"
$cloneParams = @{
    SourceVMName = "Win1022H2Template_19-03-23_14-04-52"
    DestinationVMName = "MyVM_Clone"
    ExportPath = "D:\VM\ExportedVMs"
    ImportPath = "D:\VM\ImportedVMs"
}
Clone-HyperVVM @cloneParams

# D:\VM\ExportedVMs\Win1022H2Template_19-03-23_14-04-52_20230319_151857\Win1022H2Template_19-03-23_14-04-52\Virtual Machines\29E59B85-14A3-4BCE-9AA4-EDDE1C5D9546.vmcx

