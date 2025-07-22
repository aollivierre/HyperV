# 🔧 EnhancedHyperVAO PowerShell Module

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-brightgreen.svg)](CHANGELOG.md)

A comprehensive PowerShell module for advanced Hyper-V management, providing enhanced automation capabilities for virtual machine creation, configuration, and operations.

---

## 📋 **Table of Contents**

- [🚀 Quick Start](#-quick-start)
- [✨ Features](#-features)
- [📦 Installation](#-installation)
- [🏗️ Module Structure](#️-module-structure)
- [📚 Function Reference](#-function-reference)
- [💡 Usage Examples](#-usage-examples)
- [⚙️ Configuration](#️-configuration)
- [🔧 Advanced Usage](#-advanced-usage)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🚀 **Quick Start**

```powershell
# Import the module
Import-Module EnhancedHyperVAO

# Initialize Hyper-V services
Initialize-HyperVServices

# Create a new VM with differencing disk
New-CustomVMWithDifferencingDisk -VMName "TestVM" -VMFullPath "C:\VMs\TestVM" -VHDPath "C:\VMs\TestVM\TestVM.vhdx" -SwitchName "Default Switch" -MemoryStartupBytes 2GB -MemoryMinimumBytes 1GB -MemoryMaximumBytes 4GB -Generation 2

# Start the VM
Start-VMEnhanced -VMName "TestVM"

# Connect to VM console
Connect-VMConsole -VMName "TestVM"
```

---

## ✨ **Features**

### 🎯 **Core Capabilities**
- **VM Creation & Management**: Create VMs with advanced configurations
- **Differencing Disk Support**: Efficient storage with parent/child VHD relationships
- **Dynamic Memory Management**: Automatic memory allocation and scaling
- **TPM Integration**: Secure VMs with TPM 2.0 support
- **Boot Configuration**: Flexible boot device management
- **Validation Framework**: Comprehensive validation for VMs and storage

### 🔧 **Advanced Features**
- **Interactive Menus**: User-friendly VM creation workflows
- **Configuration Management**: External configuration file support
- **Dependency Tracking**: Automatic detection of VM dependencies
- **Enhanced Logging**: Detailed logging with multiple levels
- **Error Handling**: Robust error handling and recovery
- **Modular Architecture**: Clean, maintainable code structure

---

## 📦 **Installation**

### **Prerequisites**
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Hyper-V feature enabled
- Administrator privileges

### **Install from Local Path**
```powershell
# Clone or download the module
git clone https://github.com/aollivierre/EnhancedHyperVAO.git

# Import the module
Import-Module .\EnhancedHyperVAO\EnhancedHyperVAO.psd1
```

### **Verify Installation**
```powershell
# Check available functions
Get-Command -Module EnhancedHyperVAO

# View module information
Get-Module EnhancedHyperVAO
```

---

## 🏗️ **Module Structure**

The EnhancedHyperVAO module follows a modular architecture with functions organized by purpose:

```
EnhancedHyperVAO/
├── 📄 EnhancedHyperVAO.psd1          # Module manifest
├── 📄 EnhancedHyperVAO.psm1          # Main module loader
├── 📁 Modules/                       # Function modules
│   ├── 🔧 VMCreation.psm1            # VM creation functions
│   ├── ⚙️ VMConfiguration.psm1       # VM configuration functions
│   ├── 🔄 VMOperations.psm1          # VM runtime operations
│   ├── 📊 VMInformation.psm1         # VM information functions
│   ├── ✅ VMValidation.psm1          # Validation functions
│   ├── 💾 StorageManagement.psm1     # Storage operations
│   └── 🛠️ SystemUtilities.psm1       # System utilities
├── 📄 README.md                      # This file
├── 📄 CHANGELOG.md                   # Version history
└── 📄 RELEASE_NOTES.md               # Release information
```

---

## 📚 **Function Reference**

### 🔧 **VM Creation (VMCreation.psm1)**

#### `New-CustomVMWithDifferencingDisk`
Creates a new VM with advanced configuration options and optional differencing disk support.

```powershell
New-CustomVMWithDifferencingDisk -VMName "MyVM" -VMFullPath "C:\VMs\MyVM" -VHDPath "C:\VMs\MyVM\MyVM.vhdx" -SwitchName "Default Switch" -MemoryStartupBytes 4GB -MemoryMinimumBytes 2GB -MemoryMaximumBytes 8GB -Generation 2 -UseDifferencing $true -ParentVHDPath "C:\VMs\Templates\Template.vhdx"
```

#### `New-DifferencingVHDX`
Creates a differencing VHDX file linked to a parent disk.

```powershell
New-DifferencingVHDX -ParentPath "C:\VMs\Templates\Template.vhdx" -ChildPath "C:\VMs\MyVM\MyVM.vhdx"
```

#### `CreateVMFolder`
Creates organized folder structure for VM files.

```powershell
CreateVMFolder -VMPath "C:\VMs" -VMName "MyVM"
```

#### `Show-VMCreationMenu`
Displays an interactive menu for VM creation options.

```powershell
$choice = Show-VMCreationMenu
```

### ⚙️ **VM Configuration (VMConfiguration.psm1)**

#### `ConfigureVM`
Configures VM processor settings and enables virtualization extensions.

```powershell
ConfigureVM -VMName "MyVM" -ProcessorCount 4
```

#### `ConfigureVMBoot`
Sets VM boot device configuration.

```powershell
# Boot from DVD
ConfigureVMBoot -VMName "MyVM"

# Boot from specific disk
ConfigureVMBoot -VMName "MyVM" -DifferencingDiskPath "C:\VMs\MyVM\MyVM.vhdx"
```

#### `Add-DVDDriveToVM`
Adds a DVD drive with ISO to the VM.

```powershell
Add-DVDDriveToVM -VMName "MyVM" -InstallMediaPath "C:\ISOs\Windows.iso"
```

#### `EnableVMTPM`
Enables TPM 2.0 for the VM.

```powershell
EnableVMTPM -VMName "MyVM"
```

#### `EnsureUntrustedGuardianExists`
Creates HGS guardian for TPM operations.

```powershell
EnsureUntrustedGuardianExists -GuardianName "UntrustedGuardian"
```

### 🔄 **VM Operations (VMOperations.psm1)**

#### `Start-VMEnhanced`
Starts a VM with validation checks.

```powershell
Start-VMEnhanced -VMName "MyVM"
```

#### `Connect-VMConsole`
Connects to VM console using VMConnect.

```powershell
Connect-VMConsole -VMName "MyVM" -ServerName "localhost"
```

#### `Shutdown-DependentVMs`
Safely shuts down VMs that depend on a specific VHDX.

```powershell
Shutdown-DependentVMs -VHDXPath "C:\VMs\Templates\Template.vhdx"
```

### 📊 **VM Information (VMInformation.psm1)**

#### `Get-VMConfiguration`
Interactive configuration file selection and editing.

```powershell
$config = Get-VMConfiguration -ConfigPath "D:\VM\Configs" -Editor "VSCode"
```

#### `Get-DependentVMs`
Finds VMs that use a specific VHDX as parent.

```powershell
$dependentVMs = Get-DependentVMs -VHDXPath "C:\VMs\Templates\Template.vhdx"
```

#### `Get-NextVMNamePrefix`
Generates sequential VM name prefix.

```powershell
$nextName = Get-NextVMNamePrefix -Config $configObject
```

### ✅ **Validation (VMValidation.psm1)**

#### `Validate-VMExists`
Checks if a VM exists.

```powershell
$exists = Validate-VMExists -VMName "MyVM"
```

#### `Validate-VMStarted`
Checks if a VM is running.

```powershell
$isRunning = Validate-VMStarted -VMName "MyVM"
```

#### `Validate-ISOAdded`
Verifies if an ISO is attached to a VM.

```powershell
$isoAttached = Validate-ISOAdded -VMName "MyVM" -InstallMediaPath "C:\ISOs\Windows.iso"
```

#### `Validate-VHDMount`
Checks if a VHDX is mounted.

```powershell
$isMounted = Validate-VHDMount -VHDXPath "C:\VMs\MyVM\MyVM.vhdx"
```

### 💾 **Storage Management (StorageManagement.psm1)**

#### `Dismount-VHDX`
Safely dismounts a VHDX file after checking for dependencies.

```powershell
Dismount-VHDX -VHDXPath "C:\VMs\MyVM\MyVM.vhdx"
```

### 🛠️ **System Utilities (SystemUtilities.psm1)**

#### `Initialize-HyperVServices`
Starts essential Hyper-V services.

```powershell
Initialize-HyperVServices
```

#### `Parse-Size`
Converts size strings to bytes.

```powershell
$bytes = Parse-Size -Size "4GB"
$bytes = Parse-Size -Size "512MB"
```

---

## 💡 **Usage Examples**

### **Example 1: Complete VM Setup**
```powershell
# Initialize services
Initialize-HyperVServices

# Create VM folder
$vmPath = CreateVMFolder -VMPath "C:\VMs" -VMName "WebServer01"

# Create differencing disk
New-DifferencingVHDX -ParentPath "C:\VMs\Templates\Server2022.vhdx" -ChildPath "$vmPath\WebServer01.vhdx"

# Create VM
New-CustomVMWithDifferencingDisk -VMName "WebServer01" -VMFullPath $vmPath -VHDPath "$vmPath\WebServer01.vhdx" -SwitchName "Default Switch" -MemoryStartupBytes 4GB -MemoryMinimumBytes 2GB -MemoryMaximumBytes 8GB -Generation 2

# Configure VM
ConfigureVM -VMName "WebServer01" -ProcessorCount 4
EnableVMTPM -VMName "WebServer01"

# Start VM
Start-VMEnhanced -VMName "WebServer01"

# Connect to console
Connect-VMConsole -VMName "WebServer01"
```

### **Example 2: Bulk VM Management**
```powershell
# Get configuration
$config = Get-VMConfiguration -ConfigPath "D:\VM\Configs"

# Create multiple VMs
1..5 | ForEach-Object {
    $vmName = "VM$($_.ToString('00'))"
    $vmPath = CreateVMFolder -VMPath "C:\VMs" -VMName $vmName
    
    New-CustomVMWithDifferencingDisk -VMName $vmName -VMFullPath $vmPath -VHDPath "$vmPath\$vmName.vhdx" -SwitchName $config.SwitchName -MemoryStartupBytes (Parse-Size $config.MemoryStartup) -MemoryMinimumBytes (Parse-Size $config.MemoryMinimum) -MemoryMaximumBytes (Parse-Size $config.MemoryMaximum) -Generation $config.Generation
    
    Start-VMEnhanced -VMName $vmName
}
```

### **Example 3: Template Management**
```powershell
# Find dependent VMs
$dependentVMs = Get-DependentVMs -VHDXPath "C:\VMs\Templates\Template.vhdx"

# Safely shutdown dependent VMs before template maintenance
Shutdown-DependentVMs -VHDXPath "C:\VMs\Templates\Template.vhdx"

# Perform template updates...
# ...

# Restart dependent VMs
$dependentVMs | ForEach-Object {
    Start-VMEnhanced -VMName $_.Name
}
```

---

## ⚙️ **Configuration**

### **Configuration Files**
The module supports external configuration files in PowerShell Data File (.psd1) format:

```powershell
# Example: WebServerConfig.psd1
@{
    VMNamePrefixFormat = "WEB{0:D2}"
    SwitchName = "Default Switch"
    MemoryStartup = "4GB"
    MemoryMinimum = "2GB" 
    MemoryMaximum = "8GB"
    ProcessorCount = 4
    Generation = 2
    VHDSizeBytes = 100GB
}
```

### **Environment Variables**
```powershell
# Optional: Set default paths
$env:ENHANCEDHYPERVAO_CONFIG_PATH = "D:\VM\Configs"
$env:ENHANCEDHYPERVAO_VM_PATH = "C:\VMs"
$env:ENHANCEDHYPERVAO_TEMPLATE_PATH = "C:\VMs\Templates"
```

---

## 🔧 **Advanced Usage**

### **Custom Logging**
The module uses `Write-EnhancedLog` for detailed logging. Ensure your logging framework is configured:

```powershell
# Example logging configuration
$LoggingParams = @{
    LogLevel = "INFO"
    LogPath = "C:\Logs\HyperV.log"
    MaxLogSize = "10MB"
}
```

### **Error Handling**
All functions include comprehensive error handling:

```powershell
try {
    New-CustomVMWithDifferencingDisk -VMName "TestVM" @vmParams
    Write-Host "VM created successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to create VM: $($_.Exception.Message)"
    # Additional error handling...
}
```

### **Validation Workflows**
Build validation into your workflows:

```powershell
if (Validate-VMExists -VMName "MyVM") {
    if (Validate-VMStarted -VMName "MyVM") {
        Connect-VMConsole -VMName "MyVM"
    } else {
        Start-VMEnhanced -VMName "MyVM"
    }
} else {
    Write-Warning "VM 'MyVM' does not exist"
}
```

---

## 🤝 **Contributing**

We welcome contributions! Please see our contributing guidelines:

### **Development Setup**
1. Fork the repository
2. Create a feature branch
3. Make changes in the appropriate PSM1 module
4. Test your changes
5. Submit a pull request

### **Coding Standards**
- Follow PowerShell best practices
- Include proper error handling
- Add comprehensive comments
- Use `Write-EnhancedLog` for logging
- Include parameter validation

### **Testing**
```powershell
# Run module tests
Invoke-Pester

# Import and test functions
Import-Module .\EnhancedHyperVAO.psd1 -Force
Get-Command -Module EnhancedHyperVAO
```

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 **Support**

- **GitHub Issues**: [Report bugs or request features](https://github.com/aollivierre/EnhancedHyperVAO/issues)
- **Documentation**: [Wiki and examples](https://github.com/aollivierre/EnhancedHyperVAO/wiki)
- **Discussions**: [Community discussions](https://github.com/aollivierre/EnhancedHyperVAO/discussions)

---

## 🏆 **Acknowledgments**

- PowerShell Community for best practices and guidance
- Hyper-V team for excellent virtualization platform
- Contributors and users who provide valuable feedback

---

**Made with ❤️ for the PowerShell and Hyper-V community**