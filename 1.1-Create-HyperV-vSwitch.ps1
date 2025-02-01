# Get the name of the virtual switch that you want the virtual machine to use by using Get-VMSwitch. For example,

Get-VMSwitch  * | Format-Table Name



Get-NetAdapter
#Gather whatever the NIC Name you got from Get-NetAdapter and that is up

New-VMSwitch "External VM Switch" `
-MinimumBandwidthMode Weight `
-NetAdapterName "Ethernet" `
-AllowManagementOS:$true