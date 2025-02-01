Get-Service -DisplayName *hyper*
Start-Service vmcompute
Start-Service vmms


#use the following block to build a VM with a VHDX file format and *.iso media type for boot

# Set VM Name, Switch Name, and Installation Media Path.

$Datetime= [System.Datetime]::Now.ToString("dd/MM/yy_HH_mm_ss")
$VMName = "Win10_WinGet_$($Datetime)"
$Switch = 'External'
# $InstallMedia = 'C:\Users\Administrator\Desktop\en_windows_10_enterprise_x64_dvd_6851151.iso'
# $InstallMedia = "D:\VM\Setup\ISO\Windows_11_22H2_Oct_29_2022.iso"
$InstallMedia = "D:\VM\Setup\ISO\Windows_10_22H2_Oct_29_2022.iso"

# Create New Virtual Machine


$newVMSplat = @{
    Generation         = 2
    Path               = "D:\VM\$VMName"
    Name               = $VMName
    NewVHDSizeBytes    = 30GB
    NewVHDPath         = "D:\VM\$VMName\$VMName.vhdx"
    MemoryStartupBytes = 6GB
    SwitchName         = $Switch
}


New-VM @newVMSplat

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMedia

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $VMName

# Configure Virtual Machine to Boot from DVD
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive


# -ExposeVirtualizationExtensions
# Specifies whether the hypervisor should expose the presence of virtualization extensions to the virtual machine, which enables support for nested virtualization,.
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Verbose
Set-VMProcessor $VMName -Count 24

Set-VMMemory $VMName -DynamicMemoryEnabled $false


# New-VHD -Path D:\VHD\App2FS.vhdx -SizeBytes 500GB -fixed

# Add-VMHardDiskDrive -VMName $VMName -Path D:\VHD\App2FS.vhdx -ControllerType SCSI -ControllerNumber 1


# Get-VM Test | Add-VMHardDiskDrive -ControllerType SCSI -ControllerNumber 0


# Now you would think that you can use the Enable-VMTPM command to enable the vTPM, but it will end up with the error:” Cannot modify the selected security settings of a virtual machine without a valid key protector configured. The operation failed. Cannot modify the selected security settings of virtual machine ‘XXXXX’ without a valid key protector configured. Configure a valid key protector and try again.”
# how do I configure a valid key protector?
# First you need to generate a HGS, Host Guarded Service, Key with these commands. Note! These command should only be used in lab and test environment!
$owner = Get-HgsGuardian UntrustedGuardian
$kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot

Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

# Now you can use the Enable-VMTPM command to enable the virtual TPM chip
Enable-VMTPM -VMName $VMName

# Start-VM -Name $VMNAME