#Requires -Version 3.0

function Install-Updates {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    try {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Verbose "Installing PSWindowsUpdate module..."
            Install-Module -Name PSWindowsUpdate -Scope CurrentUser -Verbose:$false -Confirm:$false
        }
        
        Write-Verbose "Importing PSWindowsUpdate module..."
        Import-Module -Name PSWindowsUpdate -Verbose:$false

        Write-Verbose "Checking for updates..."
        $availableUpdates = Get-WindowsUpdate -Verbose:$false

        if ($availableUpdates.Count -gt 0) {
            Write-Verbose "Installing updates..."
            Get-WindowsUpdate -Install -Verbose:$false -Confirm:$false
            Write-Verbose "Updates installed successfully."
        } else {
            Write-Verbose "No updates available."
        }
    } catch {
        Write-Error "An error occurred while updating: $_"
    }
}

# Run the function
Install-Updates -Verbose
