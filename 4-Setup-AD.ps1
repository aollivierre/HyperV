# Install Active Directory Domain Services using Windows PowerShell in Windows Server 2012 R2 Core.
Add-WindowsFeature AD-Domain-Services -IncludeManagementTools


# Install-WindowsFeature –Name AD-Domain-Services -IncludeManagementTools


# Create a new Active Directory forest and domain, install Domain Name Services (DNS), and promote the server to a domain controller using Windows PowerShell in Windows Server 2012 R2 Core.

Import-Module ActiveDirectory

# Install-ADDSForest -DomainName winnipegbeach.ca -InstallDNS
# Install-ADDSForest -DomainName ad.canadacomputing.ca -InstallDNS
# Install-ADDSForest -DomainName canadacomputing.ca -InstallDNS

# Install-ADDSForest -DomainName ad.canadacomputing.ca -InstallDNS

Install-ADDSForest -DomainName ccicloud.online -InstallDNS

# Install-ADDSForest -DomainName basstel.com -InstallDNS


# Type the Directory Services Restore Mode (DSRM) password twice and press Enter to save the password. The DSRM password is referred to as the SafeModeAdministratorPassword in Windows PowerShell.


# The domain controller promotion will complete and the server will be rebooted finalizing the process



Install-ADDSDomainController `
-CreateDnsDelegation:$false `
-NoGlobalCatalog:$true `
-InstallDns:$true `
-DomainName "ccicloud.online" `
-SiteName "Default-First-Site-Name" `
-DatabasePath "C:\Windows\NTDS" `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$true `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true
# -ReplicationSourceDC "REBEL-DC2012.therebeladmin.com" `


# Once execute the command it will ask for SafeModeAdministrator Password. Please use complex password to proceed. This will be used for DSRM.



# Argument

# Description

# Install-ADDSDomainController

# This cmdlet will install the domain controller in active directory infrastructure.

# -NoGlobalCatalog

# If you do not need to create the domain controller as global catalog server, this parameter can use. By default, system will enable global catalog feature.

# -SiteName

# This Parameter can use to define the active directory site name.  the default value is Default-First-Site-Name

# -DomainName

# This parameter defines the FQDN for the active directory domain.

# -ReplicationSourceDC

# Using this parameter can define the active directory replication source. By default, it will use any available domain controller. But if need we can be specific.