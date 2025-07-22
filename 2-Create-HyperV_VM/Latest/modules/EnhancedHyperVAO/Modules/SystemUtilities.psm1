# SystemUtilities.psm1
# System initialization and utility functions

function Initialize-HyperVServices {
    [CmdletBinding()]
    param ()

    Begin {
        Write-Host "Starting Initialize-HyperVServices function"
    }

    Process {
        try {
            Write-Host "Checking for Hyper-V services"
            if (Get-Service -DisplayName *hyper*) {
                Write-Host "Starting Hyper-V services: vmcompute and vmms"
                Start-Service -Name vmcompute -ErrorAction SilentlyContinue
                Start-Service -Name vmms -ErrorAction SilentlyContinue
                Write-Host "Hyper-V services started" -ForegroundColor ([ConsoleColor]::Green)
            } else {
                Write-Warning "No Hyper-V services found"
            }
        } catch {
            Write-Error "An error occurred while starting Hyper-V services: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Initialize-HyperVServices function"
    }
}

function Parse-Size {
    <#
    .SYNOPSIS
    Parses a size string and converts it to bytes.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Size
    )

    Begin {
        Write-Host "Starting Parse-Size function"
    }

    Process {
        try {
            Write-Host "Parsing size string: $Size"
            switch -regex ($Size) {
                '^(\d+)\s*KB$' {
                    $result = [int64]$matches[1] * 1KB
                    Write-Host "Parsed size: $Size to $result bytes"
                    return $result
                }
                '^(\d+)\s*MB$' {
                    $result = [int64]$matches[1] * 1MB
                    Write-Host "Parsed size: $Size to $result bytes"
                    return $result
                }
                '^(\d+)\s*GB$' {
                    $result = [int64]$matches[1] * 1GB
                    Write-Host "Parsed size: $Size to $result bytes"
                    return $result
                }
                '^(\d+)\s*TB$' {
                    $result = [int64]$matches[1] * 1TB
                    Write-Host "Parsed size: $Size to $result bytes"
                    return $result
                }
                default {
                    Write-Error "Invalid size format: $Size"
                    throw "Invalid size format: $Size"
                }
            }
        } catch {
            Write-Error "An error occurred while parsing size: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Parse-Size function"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Initialize-HyperVServices',
    'Parse-Size'
)