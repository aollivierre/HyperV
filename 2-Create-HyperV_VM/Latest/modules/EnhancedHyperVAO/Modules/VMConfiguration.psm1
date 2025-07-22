# VMConfiguration.psm1
# Contains all VM configuration-related functions

function ConfigureVM {
    <#
    .SYNOPSIS
    Configures the specified VM with the given processor count and memory settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [int]$ProcessorCount
    )

    Begin {
        Write-Host "Starting Configure-VM function"
    }

    Process {
        try {
            Write-Host "Configuring VM processor for VM: $VMName with $ProcessorCount processors"
            Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount

            Write-Host "Configuring memory for VM: $VMName"
            Set-VMMemory -VMName $VMName

            Write-Host "VM $VMName configured"
        } catch {
            Write-Error "An error occurred while configuring VM $VMName $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Configure-VM function"
    }
}

function ConfigureVMBoot {
    <#
    .SYNOPSIS
    Configures the boot order of the specified VM. Can configure boot from either DVD drive or differencing disk.

    .DESCRIPTION
    Configures the boot settings for a VM. If DifferencingDiskPath is provided, sets the VM to boot from that disk.
    Otherwise, configures the VM to boot from DVD drive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [string]$DifferencingDiskPath
    )

    Begin {
        Write-Host "Starting Configure-VMBoot function"
        $logParams = @{
            VMName = $VMName
        }
        if ($DifferencingDiskPath) {
            $logParams['DifferencingDiskPath'] = $DifferencingDiskPath
        }
    }

    Process {
        try {
            if ($DifferencingDiskPath) {
                # Differencing disk boot configuration
                Write-Host "Retrieving hard disk drive for VM: $VMName with path: $DifferencingDiskPath"
                $VHD = Get-VMHardDiskDrive -VMName $VMName | Where-Object { $_.Path -eq $DifferencingDiskPath }

                if ($null -eq $VHD) {
                    Write-Error "No hard disk drive found for VM: $VMName with the specified path: $DifferencingDiskPath"
                    throw "Hard disk drive not found."
                }

                Write-Host "Setting VM firmware for VM: $VMName to boot from the specified disk"
                Set-VMFirmware -VMName $VMName -FirstBootDevice $VHD
            }
            else {
                # DVD drive boot configuration
                Write-Host "Retrieving DVD drive for VM: $VMName"
                $DVDDrive = Get-VMDvdDrive -VMName $VMName

                if ($null -eq $DVDDrive) {
                    Write-Error "No DVD drive found for VM: $VMName"
                    throw "DVD drive not found."
                }

                Write-Host "Setting VM firmware for VM: $VMName to boot from DVD"
                Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive
            }

            Write-Host "VM boot configured for $VMName"
        }
        catch {
            Write-Error "An error occurred while configuring VM boot for $VMName $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Configure-VMBoot function"
    }
}

function Add-DVDDriveToVM {
    <#
    .SYNOPSIS
    Adds a DVD drive with the specified ISO to the VM and validates the addition.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [string]$InstallMediaPath
    )

    Begin {
        Write-Host "Starting Add-DVDDriveToVM function"
    }

    Process {
        try {
            Write-Host "Validating if the ISO is already added to VM: $VMName"
            if (Validate-ISOAdded -VMName $VMName -InstallMediaPath $InstallMediaPath) {
                Write-Host "ISO is already added to VM: $VMName"
                return
            }

            Write-Host "Adding SCSI controller to VM: $VMName"
            Add-VMScsiController -VMName $VMName -ErrorAction Stop

            Write-Host "Adding DVD drive with ISO to VM: $VMName"
            Add-VMDvdDrive -VMName $VMName -Path $InstallMediaPath -ErrorAction Stop

            Write-Host "DVD drive with ISO added to VM: $VMName"

            Write-Host "Validating the ISO addition for VM: $VMName"
            if (-not (Validate-ISOAdded -VMName $VMName -InstallMediaPath $InstallMediaPath)) {
                Write-Error "Failed to validate the ISO addition for VM: $VMName"
                throw "ISO validation failed."
            }
        }
        catch {
            Write-Error "An error occurred while adding DVD drive to VM: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Add-DVDDriveToVM function"
    }
}

function EnableVMTPM {
    <#
    .SYNOPSIS
    Enables TPM for the specified VM.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    Begin {
        Write-Host "Starting Enable-VMTPM function"
    }

    Process {
        try {
            Write-Host "Retrieving HGS Guardian"
            $owner = Get-HgsGuardian -Name "UntrustedGuardian"

            Write-Host "Creating new HGS Key Protector"
            $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot

            Write-Host "Setting VM Key Protector for VM: $VMName"
            Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

            Write-Host "Enabling TPM for VM: $VMName"
            Enable-VMTPM -VMName $VMName

            Write-Host "TPM enabled for $VMName"
        } catch {
            Write-Error "An error occurred while enabling TPM for VM $VMName $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Enable-VMTPM function"
    }
}

function EnsureUntrustedGuardianExists {
    <#
    .SYNOPSIS
    Ensures that an untrusted guardian exists. If not, creates one.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$GuardianName = 'UntrustedGuardian'
    )

    Begin {
        Write-Host "Starting Ensure-UntrustedGuardianExists function"
    }

    Process {
        try {
            Write-Host "Checking for the existence of the guardian: $GuardianName"
            $guardian = Get-HgsGuardian -Name $GuardianName -ErrorAction SilentlyContinue

            if ($null -eq $guardian) {
                Write-Warning "Guardian $GuardianName not found. Creating..."
                New-HgsGuardian -Name $GuardianName -GenerateCertificates
                Write-Host "Guardian $GuardianName created successfully" -ForegroundColor ([ConsoleColor]::Green)
            } else {
                Write-Host "Guardian $GuardianName already exists"
            }
        } catch {
            Write-Error "An error occurred while checking or creating the guardian: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Ensure-UntrustedGuardianExists function"
    }
}

function Get-AvailableVirtualSwitch {
    <#
    .SYNOPSIS
    Gets an available virtual switch based on purpose and preference.

    .DESCRIPTION
    This function retrieves available virtual switches and allows selection based on purpose.
    It can automatically create switches if none exist and provides an interactive menu for selection.

    .PARAMETER SwitchPurpose
    Description of the switch purpose (e.g., "WAN (External)", "LAN (Internal)").

    .PARAMETER PreferredType
    Preferred switch type (External, Internal, Private). If specified, will prefer this type.

    .EXAMPLE
    $switch = Get-AvailableVirtualSwitch -SwitchPurpose "WAN (External)"

    .EXAMPLE
    $switch = Get-AvailableVirtualSwitch -SwitchPurpose "LAN (Internal)" -PreferredType "Private"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SwitchPurpose = "Default",

        [Parameter()]
        [ValidateSet("External", "Internal", "Private")]
        [string]$PreferredType
    )
    
    Begin {
        Write-Host "Starting Get-AvailableVirtualSwitch function"
    }

    Process {
        try {
            # Get all available virtual switches
            $switches = Get-VMSwitch -ErrorAction Stop
            
            if (-not $switches) {
                Write-Warning "No virtual switches found. Creating default External switch..."
                
                # Get the first available network adapter
                $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
                
                if ($netAdapter) {
                    # Create new external switch
                    $newSwitch = New-VMSwitch -Name "Default External Switch" -NetAdapterName $netAdapter.Name -AllowManagementOS $true
                    Write-Host "Created new external switch: $($newSwitch.Name)"
                    return $newSwitch.Name
                } else {
                    throw "No network adapters available to create virtual switch"
                }
            }

            # If PreferredType is specified, try to find switches of that type first
            if ($PreferredType) {
                $preferredSwitches = $switches | Where-Object { $_.SwitchType -eq $PreferredType }
                
                if ($preferredSwitches) {
                    if ($preferredSwitches.Count -eq 1) {
                        Write-Host "Using the only available $PreferredType switch: $($preferredSwitches[0].Name)"
                        return $preferredSwitches[0].Name
                    }
                    # If multiple preferred switches, use the selection logic below with filtered list
                    $switches = $preferredSwitches
                }
                else {
                    # No switches of preferred type exist, ask user if they want to create one
                    if ($PreferredType -eq "Private") {
                        Write-Host "`nNo $PreferredType switches found for $SwitchPurpose." -ForegroundColor Yellow
                        Write-Host "Available switches of other types:" -ForegroundColor Cyan
                        
                        for ($i = 0; $i -lt $switches.Count; $i++) {
                            Write-Host "[$i] $($switches[$i].Name) (Type: $($switches[$i].SwitchType))"
                        }
                        
                        Write-Host "[C] Create new $PreferredType switch" -ForegroundColor Green
                        
                        do {
                            $choice = Read-Host "`nSelect an option [0-$($switches.Count - 1)] or [C]reate new"
                        } while ($choice -notmatch '^([0-9]+|[Cc])$' -or ($choice -match '^\d+$' -and [int]$choice -ge $switches.Count))
                        
                        if ($choice -match '^[Cc]$') {
                            # User chose to create new switch
                            $cleanPurpose = $SwitchPurpose -replace '[^\w\s-]', '' -replace '\s+', '-'
                            $newSwitchName = "HyperV-$cleanPurpose-Private"
                            try {
                                Write-Host "Creating new private switch: $newSwitchName"
                                $newSwitch = New-VMSwitch -Name $newSwitchName -SwitchType Private
                                Write-Host "Successfully created private switch: $newSwitchName"
                                return $newSwitch.Name
                            }
                            catch {
                                Write-Error "Failed to create private switch: $_"
                                throw
                            }
                        } else {
                            # User chose existing switch
                            return $switches[[int]$choice].Name
                        }
                    } else {
                        # For non-Private types, just show available switches
                        Write-Host "`nNo $PreferredType switches found. Available switches:" -ForegroundColor Yellow
                        for ($i = 0; $i -lt $switches.Count; $i++) {
                            Write-Host "[$i] $($switches[$i].Name) (Type: $($switches[$i].SwitchType))"
                        }
                        
                        do {
                            $selection = Read-Host "`nSelect switch for $SwitchPurpose [0-$($switches.Count - 1)]"
                        } while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -ge $switches.Count)
                        
                        return $switches[[int]$selection].Name
                    }
                }
            }
            
            # If there's only one switch, use it
            if ($switches.Count -eq 1) {
                Write-Host "Using the only available switch: $($switches[0].Name)"
                return $switches[0].Name
            }
            
            # If multiple switches exist, show selection menu
            Write-Host "`nAvailable Virtual Switches ($SwitchPurpose):" -ForegroundColor Cyan
            for ($i = 0; $i -lt $switches.Count; $i++) {
                Write-Host "[$i] $($switches[$i].Name) (Type: $($switches[$i].SwitchType))"
            }
            
            do {
                $selection = Read-Host "`nSelect virtual switch for $SwitchPurpose [0-$($switches.Count - 1)]"
            } while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -ge $switches.Count)
            
            return $switches[[int]$selection].Name
        }
        catch {
            Write-Error "Error getting virtual switch: $_"
            Handle-Error -ErrorRecord $_
            throw
        }
    }

    End {
        Write-Host "Exiting Get-AvailableVirtualSwitch function"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'ConfigureVM',
    'ConfigureVMBoot',
    'Add-DVDDriveToVM',
    'EnableVMTPM',
    'EnsureUntrustedGuardianExists',
    'Get-AvailableVirtualSwitch'
)