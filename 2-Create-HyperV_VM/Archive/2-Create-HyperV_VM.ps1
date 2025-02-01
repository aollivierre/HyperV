



$VMNAME = "DC3"

New-VM `
-Name $VMNAME `
-MemoryStartupBytes 2GB `
-NewVHDPath c:\vhd\$VMNAME.vhdx `
-NewVHDSizeBytes 30GB `
-BootDevice 'VHD' `
-Generation '2'


Start-VM -Name $VMNAME








#use the following block to build a VM with a VHDX file format and *.iso media type for boot

# Set VM Name, Switch Name, and Installation Media Path.
$VMName = 'NagiosXI'
$Switch = 'External VM Switch'
# $InstallMedia = 'C:\Users\Administrator\Desktop\en_windows_10_enterprise_x64_dvd_6851151.iso'
$InstallMedia = "d:\setup\server\server2019\svr2019.iso"

# Create New Virtual Machine
New-VM -Name $VMName -MemoryStartupBytes 16GB -Generation 2 -NewVHDPath "D:\vhd\$VMName.vhdx" -NewVHDSizeBytes 30GB -Path "D:\vhd\$VMName" -SwitchName $Switch

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMedia

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $VMName

# Configure Virtual Machine to Boot from DVD
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive



Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Verbose


New-VHD -Path D:\VHD\App2FS.vhdx -SizeBytes 500GB -fixed

Add-VMHardDiskDrive -VMName $VMName -Path D:\VHD\App2FS.vhdx -ControllerType SCSI -ControllerNumber 1


# Get-VM Test | Add-VMHardDiskDrive -ControllerType SCSI -ControllerNumber 0


Start-VM -Name $VMNAME




#####################################################################################

#use the following to determine if media type is SSD or HDD etc.. 
# will say unspecified on RAID Controller
Get-PhysicalDisk | Format-Table -AutoSize

Start-BitsTransfer -Source "https://software-download.microsoft.com/download/pr/17763.737.amd64fre.rs5_release_svc_refresh.190906-2324_server_serverdatacentereval_en-us_1.vhd" -Destination "D:\svr20192.vhd"

# Set VM Name, Switch Name, and Installation Media Path.

# $InstallMedia = 'C:\Users\Administrator\Desktop\en_windows_10_enterprise_x64_dvd_6851151.iso'
# $InstallMedia = 'c:\file.iso'
$VMName = 'Kroll'
$Switch = 'External VM Switch'
# Create New Virtual Machine
New-VM -Name $VMName `
-MemoryStartupBytes 16GB `
-Generation 1 `
-VHDPath "C:\nagiosxi-5.8.4-virtualpc-64\nagiosxi-64\nagiosxi-64.vhd" `
-Path "C:\vhd\$VMName" `
-SwitchName $Switch

# # Add DVD Drive to Virtual Machine
# Add-VMScsiController -VMName $VMName
# Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMedia

# # Mount Installation Media
# $DVDDrive = Get-VMDvdDrive -VMName $VMName

# # Configure Virtual Machine to Boot from DVD
# Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive



Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Verbose



Start-VM -Name $VMNAME