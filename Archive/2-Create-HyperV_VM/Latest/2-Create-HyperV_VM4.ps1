# Define parameters
param(
    [string]$VMNamePrefix = "Win1022H2Template",
    [string]$SwitchName = "External",
    [string]$InstallMediaPath = "D:\VM\Setup\ISO\Windows_10_22H2_Oct_29_2022.iso"
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
# $Datetime = [System.DateTime]::Now.ToString("dd/MM/yy_HH_mm_ss")

$Datetime = [System.DateTime]::Now.ToString("dd-MM-yy_HH-mm-ss")
$VMName = "$VMNamePrefix`_$Datetime"
$VMPath = "D:\VM"
$VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
New-Item -ItemType Directory -Force -Path $VMFullPath
$VHDPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"

$VMName = "$VMNamePrefix`_$Datetime"
$NewVMSplat = @{
    Generation         = 2
    # Path               = "D:\VM\$VMName"
    Path               = $VMFullPath
    Name               = $VMName
    NewVHDSizeBytes    = 30GB
    # NewVHDPath         = "D:\VM\$VMName\$VMName.vhdx"
    NewVHDPath         = $VHDPath
    MemoryStartupBytes = 6GB
    SwitchName         = $SwitchName
}
New-VM @NewVMSplat

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMediaPath

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $VMName

# Configure Virtual Machine to Boot from DVD
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive

# Configure Virtual Machine
$ProcessorCount = 24
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount
Set-VMMemory $VMName

$owner = Get-HgsGuardian UntrustedGuardian
$kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot

Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

# Now you can use the Enable-VMTPM command to enable the virtual TPM chip
Enable-VMTPM -VMName $VMName


 # Remove DVD drive from Virtual Machine
#  Remove-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0