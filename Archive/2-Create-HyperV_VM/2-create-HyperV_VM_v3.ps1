param(
    [string]$VMNamePrefix = "Win10_WinGet",
    [string]$SwitchName = "External",
    [string]$InstallMediaPath = "D:\VM\Setup\ISO\Windows_10_22H2_Oct_29_2022.iso"
)

trap {
    Write-Error $_.Exception
    exit 1
}

if (Get-Service -DisplayName *hyper*) {
    if ((Get-Service vmcompute).Status -ne "Running") {
        Start-Service vmcompute
    }
    if ((Get-Service vmms).Status -ne "Running") {
        Start-Service vmms
    }
}

$Datetime = [System.DateTime]::Now.ToString("dd/MM/yy_HH_mm_ss")
$VMName = "$VMNamePrefix`_$Datetime"
$NewVMSplat = @{
    Generation         = 2
    Path               = "D:\VM\$VMName"
    Name               = $VMName
    NewVHDSizeBytes    = 30GB
    NewVHDPath         = "D:\VM\$VMName\$VMName.vhdx"
    MemoryStartupBytes = 6GB
    SwitchName         = $SwitchName
}
New-VM @NewVMSplat

Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath

$DVDDrive = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive

$ProcessorCount = 24
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount
Set-VMMemory $VMName

$owner = Get-HgsGuardian UntrustedGuardian
$kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

Enable-VMTPM -VMName $VMName
