function New-VMFromISO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$VMNamePrefix,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$SwitchName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$InstallMediaPath,

        [Parameter(Mandatory = $false)]
        [int]$ProcessorCount = 24,

        [Parameter(Mandatory = $false)]
        [string]$MemoryAllocation = "6GB",

        [Parameter(Mandatory = $false)]
        [String]$DiskSize = 30GB,

        [Parameter(Mandatory = $false)]
        [string]$VMPath = "D:\VM"
    )

    # Error handling
    trap {
        Write-Error $_.Exception
        exit 1
    }

    # Get services and start if necessary
    if (Get-Service -DisplayName *hyper*) {
        if ((Get-Service vmcompute).Status -ne "Running") {
            Start-Service vmcompute
        }
        if ((Get-Service vmms).Status -ne "Running") {
            Start-Service vmms
        }
    }

    # Create VM
    $Datetime = [System.DateTime]::Now.ToString("dd-MM-yy_HH-mm-ss")
    $VMName = "$VMNamePrefix`_$Datetime"
    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    New-Item -ItemType Directory -Force -Path $VMFullPath
    $VHDPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"

    # $VHDSizeBytes = [System.Management.Automation.PSObject]::AsByteSize($DiskSize)


    $NewVMSplat = @{
        Generation         = 2
        Path               = $VMFullPath
        Name               = $VMName
        NewVHDSizeBytes    = $VHDSizeBytes
        NewVHDPath         = $VHDPath
        MemoryStartupBytes = $MemoryAllocation
        SwitchName         = $SwitchName
        ProcessorCount     = $ProcessorCount
    }
    New-VM @NewVMSplat -Verbose:$Verbose

    # Add DVD Drive to Virtual Machine
    Add-VMScsiController -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath

    # Mount Installation Media
    $DVDDrive = Get-VMDvdDrive -VMName $VMName

    # Configure Virtual Machine to Boot from DVD
    Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive

    # Configure Virtual Machine
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount
    Set-VMMemory -VMName $VMName -StartupBytes $MemoryAllocation

    $owner = Get-HgsGuardian UntrustedGuardian
    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot

    Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

    # Now you can use the Enable-VMTPM command to enable the virtual TPM chip
    Enable-VMTPM -VMName $VMName -Verbose:$Verbose

    # Remove DVD drive from Virtual Machine
    Remove-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0


}


New-VMFromISO -VMNamePrefix "Win1022H2Template" -SwitchName "External" -InstallMediaPath "D:\VM\Setup\ISO\Windows_10_22H2_Oct_29_2022.iso" -ProcessorCount 24 -MemoryAllocation "6GB" -DiskSize 30GB -VMPath "D:\VM" -Verbose