# VMValidation.psm1
# Contains all validation functions

function Validate-VMExists {
    <#
    .SYNOPSIS
    Validates if a VM with the specified name exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    Begin {
        Write-Host "Starting Validate-VMExists function"
    }

    Process {
        try {
            Write-Host "Checking existence of VM: $VMName"
            $vm = Get-VM -Name $VMName -ErrorAction Stop
            Write-Host "VM $VMName exists." -ForegroundColor ([ConsoleColor]::Green)
            return $true
        } catch {
            Write-Error "VM $VMName does not exist. $($_.Exception.Message)" -ForegroundColor ([ConsoleColor]::Red)
            Handle-Error -ErrorRecord $_
            return $false
        }
    }

    End {
        Write-Host "Exiting Validate-VMExists function"
    }
}

function Validate-VMStarted {
    <#
    .SYNOPSIS
    Validates if the specified VM is started (running).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    Begin {
        Write-Host "Starting Validate-VMStarted function"
    }

    Process {
        try {
            Write-Host "Checking state of VM: $VMName"
            $vm = Get-VM -Name $VMName -ErrorAction Stop

            if ($vm.State -eq 'Running') {
                Write-Host "VM $VMName is running."
                return $true
            }
            else {
                Write-Warning "VM $VMName is not running."
                return $false
            }
        }
        catch {
            Write-Error "Failed to check the state of VM $VMName. $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
            throw $_
        }
    }

    End {
        Write-Host "Exiting Validate-VMStarted function"
    }
}

function Validate-ISOAdded {
    <#
    .SYNOPSIS
    Validates if the specified ISO file is added to the VM.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [string]$InstallMediaPath
    )

    Begin {
        Write-Host "Starting Validate-ISOAdded function"
    }

    Process {
        try {
            Write-Host "Retrieving DVD drive information for VM: $VMName"
            $dvdDrive = Get-VMDvdDrive -VMName $VMName -ErrorAction SilentlyContinue

            if ($dvdDrive -and ($dvdDrive.Path -eq $InstallMediaPath)) {
                Write-Host "ISO is correctly added to VM: $VMName" -ForegroundColor Green
                return $true
            } else {
                Write-Warning "ISO is not added to VM: $VMName"
                return $false
            }
        } catch {
            Write-Error "An error occurred while validating ISO addition: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
            return $false
        }
    }

    End {
        Write-Host "Exiting Validate-ISOAdded function"
    }
}

function Validate-VHDMount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    Begin {
        Write-Host "Starting Validate-VHDMount function"
    }

    Process {
        try {
            Write-Host "Checking if the VHDX is mounted: $VHDXPath"
            $vhd = Get-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
            
            if ($null -eq $vhd) {
                Write-Host "Get-VHD did not return any information for the path: $VHDXPath" -ForegroundColor Red
                return $false
            }

            Write-Debug "Get-VHD output: $($vhd | Format-List | Out-String)"

            if ($vhd.Attached) {
                Write-Host "VHDX is mounted: $VHDXPath" -ForegroundColor Green
                return $true
            } else {
                Write-Host "VHDX is not mounted: $VHDXPath" -ForegroundColor Red
                return $false
            }
        } catch {
            Write-Error "An error occurred while validating VHD mount status: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
            return $false
        }
    }

    End {
        Write-Host "Exiting Validate-VHDMount function"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Validate-VMExists',
    'Validate-VMStarted',
    'Validate-ISOAdded',
    'Validate-VHDMount'
)