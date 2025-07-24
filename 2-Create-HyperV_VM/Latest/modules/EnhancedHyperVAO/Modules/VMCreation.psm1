# VMCreation.psm1
# Groups all VM creation and folder management functions

function New-CustomVMWithDifferencingDisk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMFullPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VHDPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SwitchName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(512MB, 1024GB)]
        [int64]$MemoryStartupBytes,

        [Parameter(Mandatory = $true)]
        [ValidateRange(512MB, 1024GB)]
        [int64]$MemoryMinimumBytes,

        [Parameter(Mandatory = $true)]
        [ValidateRange(512MB, 1024GB)]
        [int64]$MemoryMaximumBytes,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 2)]
        [int]$Generation,

        [Parameter()]
        [string]$ParentVHDPath,

        [Parameter()]
        [bool]$UseDifferencing = $false,

        [Parameter()]
        [int64]$NewVHDSizeBytes = 100GB
    )

    Begin {
        Write-Host "Starting New-CustomVMWithDifferencingDisk function"
    }

    Process {
        try {
            # Check if VM already exists
            if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
                throw "A VM with name '$VMName' already exists"
            }

            # Prepare VM parameters
            $newVMParams = @{
                Generation = $Generation
                Path = $VMFullPath
                Name = $VMName
                MemoryStartupBytes = $MemoryStartupBytes
                SwitchName = $SwitchName
            }

            if ($UseDifferencing) {
                $newVMParams['NoVHD'] = $true
            }
            else {
                $newVMParams['NewVHDPath'] = $VHDPath
                $newVMParams['NewVHDSizeBytes'] = $NewVHDSizeBytes
            }

            # Create the VM
            Write-Host "Creating new VM '$VMName'"
            $vm = New-VM @newVMParams
            
            # Configure VM Memory
            $memoryParams = @{
                VMName = $VMName
                DynamicMemoryEnabled = $true
                MinimumBytes = $MemoryMinimumBytes
                MaximumBytes = $MemoryMaximumBytes
                StartupBytes = $MemoryStartupBytes
            }
            
            Write-Host "Configuring VM memory settings"
            Set-VMMemory @memoryParams

            if ($UseDifferencing) {
                Write-Host "Creating differencing disk"
                $vhdParams = @{
                    Path = $VHDPath
                    ParentPath = $ParentVHDPath
                    Differencing = $true
                }
                New-VHD @vhdParams
                
                Write-Host "Attaching differencing disk to VM"
                Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath
            }

            # Verify VM Configuration
            $vmCheck = Get-VM -Name $VMName -ErrorAction Stop
            if ($vmCheck.State -eq 'Off') {
                Write-Host "VM '$VMName' created successfully" -ForegroundColor ([ConsoleColor]::Green)
                return $true
            }
            else {
                throw "VM is in unexpected state: $($vmCheck.State)"
            }
        }
        catch {
            Write-Error "Failed to create VM: $($_.Exception.Message)"
            
            # Cleanup on failure
            try {
                if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
                    Write-Warning "Cleaning up failed VM"
                    Remove-VM -Name $VMName -Force -ErrorAction Stop
                }
                
                if (Test-Path $VHDPath) {
                    Write-Warning "Cleaning up VHD"
                    Remove-Item -Path $VHDPath -Force -ErrorAction Stop
                }
            }
            catch {
                Write-Error "Cleanup after failure encountered additional errors: $($_.Exception.Message)"
            }
            
            Handle-Error -ErrorRecord $_
            return $false
        }
    }

    End {
        Write-Host "Completed New-CustomVMWithDifferencingDisk function"
    }
}

function New-DifferencingVHDX {
    param(
        [string]$ParentPath,
        [string]$ChildPath
    )
    
    Write-Host "Creating differencing VHDX at $ChildPath"
    try {
        New-VHD -Path $ChildPath -ParentPath $ParentPath -Differencing
        Write-Host "Differencing VHDX created successfully"
        return $true
    }
    catch {
        Write-Error "Failed to create differencing VHDX: $_"
        return $false
    }
}

function Show-VMCreationMenu {
    Write-Host "`n=== VM Creation Options ===" -ForegroundColor Cyan
    Write-Host "1. Create VM with new VHDX disk"
    Write-Host "2. Create VM with differencing VHDX disk"
    Write-Host "`nPlease select an option (1 or 2):" -NoNewline
    
    $choice = Read-Host
    while ($choice -notin '1', '2') {
        Write-Host "Invalid selection. Please enter 1 or 2:" -ForegroundColor Yellow -NoNewline
        $choice = Read-Host
    }
    
    return $choice
}

function CreateVMFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMPath,
        
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    Begin {
        Write-Host "Starting CreateVMFolder function"
    }

    Process {
        try {
            $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
            Write-Host "Creating VM folder at path: $VMFullPath"
            New-Item -ItemType Directory -Force -Path $VMFullPath | Out-Null
            Write-Host "VM folder created at $VMFullPath" -ForegroundColor ([ConsoleColor]::Green)
            return $VMFullPath
        } catch {
            Write-Error "An error occurred while creating the VM folder: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Create-VMFolder function"
    }
}

function Create-EnhancedVM {
    <#
    .SYNOPSIS
        Creates an enhanced Hyper-V VM with advanced configuration options.
    
    .DESCRIPTION
        Creates a new VM with support for differencing disks, multiple network adapters,
        TPM, dynamic memory, and other advanced features.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $true)]
        [string]$VMFullPath,
        
        [Parameter(Mandatory = $true)]
        [string]$MemoryStartupBytes,
        
        [Parameter(Mandatory = $true)]
        [string]$MemoryMinimumBytes,
        
        [Parameter(Mandatory = $true)]
        [string]$MemoryMaximumBytes,
        
        [Parameter(Mandatory = $true)]
        [int]$ProcessorCount,
        
        [Parameter(Mandatory = $true)]
        [string]$ExternalSwitchName,
        
        [Parameter()]
        [string]$InternalSwitchName,
        
        [Parameter()]
        [string]$ExternalMacAddress,
        
        [Parameter()]
        [string]$InternalMacAddress,
        
        [Parameter()]
        [string]$InstallMediaPath,
        
        [Parameter()]
        [int]$Generation = 2,
        
        [Parameter()]
        [string]$VMType = 'Standard',
        
        [Parameter()]
        [string]$VHDXPath,
        
        [Parameter()]
        [uint64]$DefaultVHDSize = 127GB,
        
        [Parameter()]
        [bool]$EnableVirtualizationExtensions = $false,
        
        [Parameter()]
        [bool]$EnableDynamicMemory = $true,
        
        [Parameter()]
        [int]$MemoryBuffer = 20,
        
        [Parameter()]
        [int]$MemoryWeight = 100,
        
        [Parameter()]
        [int]$MemoryPriority = 80,
        
        [Parameter()]
        [bool]$IncludeTPM = $true,
        
        [Parameter()]
        [bool]$UseAllAvailableSwitches = $false,
        
        [Parameter()]
        [bool]$AutoStartVM = $false,
        
        [Parameter()]
        [bool]$AutoConnectVM = $false
    )
    
    Begin {
        Write-Host "Starting Create-EnhancedVM function"
        
        # Parse memory values
        $StartupBytes = [int64](Invoke-Expression $MemoryStartupBytes.Replace('GB', '*1GB').Replace('MB', '*1MB'))
        $MinimumBytes = [int64](Invoke-Expression $MemoryMinimumBytes.Replace('GB', '*1GB').Replace('MB', '*1MB'))
        $MaximumBytes = [int64](Invoke-Expression $MemoryMaximumBytes.Replace('GB', '*1GB').Replace('MB', '*1MB'))
    }
    
    Process {
        try {
            # Initialize HyperV services
            Initialize-HyperVServices
            
            # Ensure guardian exists if TPM is required
            if ($IncludeTPM) {
                EnsureUntrustedGuardianExists
            }
            
            # Create VM folder
            CreateVMFolder -VMPath (Split-Path $VMFullPath -Parent) -VMName $VMName
            
            # Determine if using differencing disk
            $UsesDifferencing = ($VMType -eq 'Differencing' -and $VHDXPath)
            
            if ($UsesDifferencing) {
                Write-Host "Creating VM with differencing disk"
                
                # Create differencing disk
                $vmDestinationPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"
                New-DifferencingVHDX -ParentPath $VHDXPath -ChildPath $vmDestinationPath
                
                # Create VM with differencing disk
                $vmParams = @{
                    VMName             = $VMName
                    VMFullPath         = $VMFullPath
                    SwitchName         = $ExternalSwitchName
                    MemoryStartupBytes = $StartupBytes
                    MemoryMinimumBytes = $MinimumBytes
                    MemoryMaximumBytes = $MaximumBytes
                    Generation         = $Generation
                    ParentVHDPath      = $VHDXPath
                    VHDPath            = $vmDestinationPath
                    UseDifferencing    = $true
                }
                
                $vmCreated = New-CustomVMWithDifferencingDisk @vmParams
                
                # Configure boot from differencing disk
                ConfigureVMBoot -VMName $VMName -DifferencingDiskPath $vmDestinationPath
            }
            else {
                Write-Host "Creating VM with new VHD"
                
                # Create VM without VHD first
                $newVMParams = @{
                    Generation         = $Generation
                    Path               = $VMFullPath
                    Name               = $VMName
                    MemoryStartupBytes = $StartupBytes
                    SwitchName         = $ExternalSwitchName
                    NoVHD              = $true
                }
                
                $vm = New-VM @newVMParams
                
                # Configure memory
                Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $EnableDynamicMemory `
                    -MinimumBytes $MinimumBytes -MaximumBytes $MaximumBytes -StartupBytes $StartupBytes `
                    -Buffer $MemoryBuffer -Priority $MemoryPriority
                
                # Create and attach new VHD
                $vhdPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"
                $newVHD = New-VHD -Path $vhdPath -SizeBytes $DefaultVHDSize -Dynamic
                Add-VMHardDiskDrive -VMName $VMName -Path $vhdPath
                
                # Add DVD drive if install media provided
                if ($InstallMediaPath) {
                    Add-DVDDriveToVM -VMName $VMName -InstallMediaPath $InstallMediaPath
                    ConfigureVMBoot -VMName $VMName
                }
            }
            
            # Configure VM processors
            ConfigureVM -VMName $VMName -ProcessorCount $ProcessorCount
            
            # Set processor features
            if ($EnableVirtualizationExtensions) {
                Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
            }
            
            # Configure network adapters
            if ($ExternalMacAddress) {
                Get-VMNetworkAdapter -VMName $VMName | Where-Object { $_.SwitchName -eq $ExternalSwitchName } | 
                    Set-VMNetworkAdapter -StaticMacAddress $ExternalMacAddress
            }
            
            # Add second network adapter if internal switch specified
            if ($InternalSwitchName) {
                Add-VMNetworkAdapter -VMName $VMName -Name "LAN" -SwitchName $InternalSwitchName
                
                if ($InternalMacAddress) {
                    Get-VMNetworkAdapter -VMName $VMName -Name "LAN" | 
                        Set-VMNetworkAdapter -StaticMacAddress $InternalMacAddress
                }
            }
            
            # Add all available switches as NICs if requested
            if ($UseAllAvailableSwitches) {
                Write-Host "Adding all available switches as network adapters..."
                $allSwitches = Get-VMSwitch | Where-Object { $_.Name -ne $ExternalSwitchName -and $_.Name -ne $InternalSwitchName }
                $nicIndex = 2
                
                foreach ($switch in $allSwitches) {
                    try {
                        $nicName = "NIC$nicIndex-$($switch.Name)"
                        Add-VMNetworkAdapter -VMName $VMName -Name $nicName -SwitchName $switch.Name
                        Write-Host "  Added NIC: $nicName connected to switch: $($switch.Name)"
                        $nicIndex++
                    }
                    catch {
                        Write-Warning "Failed to add NIC for switch '$($switch.Name)': $_"
                    }
                }
            }
            
            # Enable TPM if requested
            if ($IncludeTPM) {
                EnableVMTPM -VMName $VMName
            }
            
            # Enable Secure Boot for Generation 2 VMs
            if ($Generation -eq 2) {
                Enable-VMSecureBoot -VMName $VMName
            }
            
            Write-Host "VM '$VMName' created successfully"
            
            # Auto-start VM if requested
            if ($AutoStartVM) {
                Write-Host "`nAuto-starting VM..."
                Start-VM -Name $VMName
                Write-Host "VM started successfully"
                
                # Auto-connect to VM console if requested
                if ($AutoConnectVM) {
                    Write-Host "Opening VM console..."
                    Connect-VMConsole -VMName $VMName
                }
            }
            else {
                # Ask user if not auto-start
                $startVM = Read-Host "`nDo you want to start the VM now? (Y/N)"
                if ($startVM -match '^[Yy]') {
                    Start-VM -Name $VMName
                    Write-Host "VM started successfully"
                    
                    # Ask about console connection
                    $connectVM = Read-Host "Do you want to connect to the VM console? (Y/N)"
                    if ($connectVM -match '^[Yy]') {
                        Connect-VMConsole -VMName $VMName
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to create VM: $_"
            Handle-Error -ErrorRecord $_
            throw
        }
    }
    
    End {
        Write-Host "Exiting Create-EnhancedVM function"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'New-CustomVMWithDifferencingDisk',
    'New-DifferencingVHDX',
    'Show-VMCreationMenu',
    'CreateVMFolder',
    'Create-EnhancedVM'
)