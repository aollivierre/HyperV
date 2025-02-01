<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)


Finally should look like this

    DisplayName                FeatureName                               State
-----------                -----------                               -----
Hyper-V                    Microsoft-Hyper-V                       Enabled
Hyper-V Offline            Microsoft-Hyper-V-Offline               Enabled
Hyper-V Online             Microsoft-Hyper-V-Online                Enabled
                           RSAT-Hyper-V-Tools-Feature              Enabled
Hyper-V Management Console Microsoft-Hyper-V-Management-Clients    Enabled
Hyper-V PowerShell cmdlets Microsoft-Hyper-V-Management-PowerShell Enabled
.NOTES
    General notes


    https://www.altaro.com/hyper-v/install-hyper-v-powershell-module/
#>

#Firs install Hyper-V role on the Windows 10 or the Windows Server on-premise (this is the full feature name which will include Microsoft-Hyper-V-Management-PowerShell)

#Step 1 on Server or client OS
DISM.exe /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V




#Enable Hyper-V on a VM in Azure to Sysprep the VHD file
# DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
# DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V-Management-PowerShell

#IF Windows 10 Client OS

Get-WindowsOptionalFeature -Online -FeatureName *hyper-v* | Select-Object DisplayName, FeatureName, state

# Install only the PowerShell module
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell

# Install the Hyper-V management tool pack (Hyper-V Manager and the Hyper-V PowerShell module)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All

# Install the entire Hyper-V stack (hypervisor, services, and tools)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All







#IF Server OS
# Install only the PowerShell module
Install-WindowsFeature -Name Hyper-V-PowerShell

# Install Hyper-V Manager and the PowerShell module (HVM only available on GUI systems)
Install-WindowsFeature -Name RSAT-Hyper-V-Tools

# Install the Hyper-V hypervisor and all tools (method #1)
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

# Install the Hyper-V hypervisor and all tools (method #2)
Install-WindowsFeature -Name Hyper-V, RSAT-Hyper-V-Tools