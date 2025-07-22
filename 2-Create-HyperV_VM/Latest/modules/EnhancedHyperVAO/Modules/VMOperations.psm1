# VMOperations.psm1
# Handles VM runtime operations

function Start-VMEnhanced {
    <#
    .SYNOPSIS
    Starts the specified VM if it exists and is not already running.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )

    Begin {
        Write-Host "Starting Start-VMEnhanced function"
    }

    Process {
        try {
            Write-Host "Validating if VM $VMName exists"
            if (-not (Validate-VMExists -VMName $VMName)) {
                Write-Error "VM $VMName does not exist. Exiting function." -ForegroundColor ([ConsoleColor]::Red)
                return
            }

            Write-Host "Checking if VM $VMName is already running"
            if (Validate-VMStarted -VMName $VMName) {
                Write-Host "VM $VMName is already running." -ForegroundColor ([ConsoleColor]::Yellow)
            } else {
                Write-Host "Starting VM $VMName"
                Start-VM -Name $VMName -ErrorAction Stop
                Write-Host "VM $VMName has been started successfully." -ForegroundColor ([ConsoleColor]::Green)
            }
        } catch {
            Write-Error "An error occurred while starting the VM $VMName. $($_.Exception.Message)" -ForegroundColor ([ConsoleColor]::Red)
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Start-VMEnhanced function"
    }
}

function Connect-VMConsole {
    <#
    .SYNOPSIS
    Connects to the console of the specified VM.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [string]$ServerName = "localhost",

        [Parameter(Mandatory = $false)]
        [int]$Count = 1
    )

    Begin {
        Write-Host "Starting Connect-VMConsole function"
    }

    Process {
        try {
            Write-Host "Validating if VM $VMName exists"
            if (-not (Validate-VMExists -VMName $VMName)) {
                Write-Error "VM $VMName does not exist. Exiting function."
                return
            }

            Write-Host "Checking if VM $VMName is running"
            if (-not (Validate-VMStarted -VMName $VMName)) {
                Write-Error "VM $VMName is not running. Cannot connect to console."
                return
            }

            $vmConnectArgs = "$ServerName `"$VMName`""
            if ($Count -gt 1) {
                $vmConnectArgs += " -C $Count"
            }

            Write-Debug "VMConnect arguments: $vmConnectArgs"
            Start-Process -FilePath "vmconnect.exe" -ArgumentList $vmConnectArgs -ErrorAction Stop
            Write-Host "VMConnect launched for VM $VMName on $ServerName with count $Count."
        } catch {
            Write-Error "An error occurred while launching VMConnect for VM $VMName. $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Connect-VMConsole function"
    }
}

function Shutdown-DependentVMs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    Process {
        try {
            $dependentVMs = Get-DependentVMs -VHDXPath $VHDXPath
            foreach ($vm in $dependentVMs) {
                Write-Host "Shutting down VM: $($vm.Name)"
                Stop-VM -Name $vm.Name -Force -ErrorAction Stop
            }
        } catch {
            Write-Error "An error occurred while shutting down dependent VMs: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Start-VMEnhanced',
    'Connect-VMConsole',
    'Shutdown-DependentVMs'
)