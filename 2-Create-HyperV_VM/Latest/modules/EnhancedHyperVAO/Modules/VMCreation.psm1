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

# Export all functions
Export-ModuleMember -Function @(
    'New-CustomVMWithDifferencingDisk',
    'New-DifferencingVHDX',
    'Show-VMCreationMenu',
    'CreateVMFolder'
)