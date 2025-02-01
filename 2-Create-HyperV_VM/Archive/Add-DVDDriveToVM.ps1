function Add-DVDDriveToVM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [string]$InstallMediaPath
    )

    Begin {
        Write-EnhancedLog -Message "Starting Add-DVDDriveToVM function" -Level "INFO"
        Log-Params -Params @{ VMName = $VMName; InstallMediaPath = $InstallMediaPath }
    }

    Process {
        try {
            Write-EnhancedLog -Message "Adding SCSI controller to VM $VMName" -Level "INFO"
            Add-VMScsiController -VMName $VMName
            Write-EnhancedLog -Message "SCSI controller added to $VMName" -Level "INFO"

            Write-EnhancedLog -Message "Adding DVD drive to VM $VMName with media path $InstallMediaPath" -Level "INFO"
            Add-VMDvdDrive -VMName $VMName -Path $InstallMediaPath
            Write-EnhancedLog -Message "DVD drive added to $VMName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        } catch {
            Write-EnhancedLog -Message "An error occurred while adding the DVD drive to VM $VMName $($_.Exception.Message)" -Level "ERROR"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-EnhancedLog -Message "Exiting Add-DVDDriveToVM function" -Level "INFO"
    }
}



