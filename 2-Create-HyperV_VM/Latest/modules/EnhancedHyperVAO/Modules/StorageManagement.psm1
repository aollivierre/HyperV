# StorageManagement.psm1
# Disk and storage-related operations

function Dismount-VHDX {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    Begin {
        Write-Host "Starting Dismount-VHDX function"
    }

    Process {
        try {
            Write-Host "Validating if the VHDX is mounted: $VHDXPath"
            $isMounted = Validate-VHDMount -VHDXPath $VHDXPath
            Write-Host "Validation result: VHDX is mounted = $isMounted"

            if ($isMounted) {
                Write-Host "Checking for dependent VMs using the VHDX: $VHDXPath"
                $dependentVMs = Get-DependentVMs -VHDXPath $VHDXPath
                $runningVMs = $dependentVMs | Where-Object { $_.State -eq 'Running' }
                
                if ($runningVMs.Count -gt 0) {
                    Write-Warning "Found running VMs using the VHDX. Skipping dismount."
                    foreach ($vm in $runningVMs) {
                        Write-Warning "Running dependent VM: $($vm.Name)"
                    }
                    return
                }

                Write-Host "No running VMs found using the VHDX. Proceeding with dismount."
                Dismount-VHD -Path $VHDXPath -ErrorAction Stop
                Write-Host "VHDX dismounted successfully."
            } else {
                Write-Host "$VHDXPath is already dismounted or not mounted."
            }
        } catch {
            Write-Error "An error occurred while dismounting the VHDX: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Exiting Dismount-VHDX function"
    }
}

function Expand-CompressedISO {
    <#
    .SYNOPSIS
    Extracts a compressed ISO file using 7-Zip.

    .DESCRIPTION
    This function extracts compressed ISO files (like .bz2) using 7-Zip.
    It checks if the extracted file already exists and handles directory creation.

    .PARAMETER CompressedPath
    Path to the compressed ISO file.

    .PARAMETER SevenZipPath
    Path to the 7-Zip executable.

    .EXAMPLE
    $extractedPath = Expand-CompressedISO -CompressedPath "C:\ISOs\opnsense.iso.bz2" -SevenZipPath "C:\Program Files\7-Zip\7z.exe"

    .OUTPUTS
    String. Returns the path to the extracted ISO file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompressedPath,

        [Parameter(Mandatory = $true)]
        [string]$SevenZipPath
    )

    Begin {
        Write-Host "Starting Expand-CompressedISO function"
    }

    Process {
        try {
            $extractedIsoPath = $CompressedPath -replace '\.bz2$', ''
            
            # Check if the extracted ISO already exists
            if (-not (Test-Path -Path $extractedIsoPath)) {
                Write-Host "Extracting compressed ISO..."
                
                # Verify 7-Zip exists
                if (-not (Test-Path -Path $SevenZipPath)) {
                    throw "7-Zip executable not found at: $SevenZipPath"
                }
                
                $extractDir = Split-Path -Path $extractedIsoPath -Parent
                
                # Make sure the target directory exists
                if (-not (Test-Path -Path $extractDir)) {
                    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
                    Write-Host "Created directory: $extractDir"
                }
                
                # Extract using 7-Zip with correct parameters
                $extractParams = @(
                    "e", 
                    "`"$CompressedPath`"", 
                    "-o`"$extractDir`"", 
                    "-y"
                )
                
                Write-Host "Running 7-Zip extraction: $SevenZipPath $extractParams"
                $process = Start-Process -FilePath $SevenZipPath -ArgumentList $extractParams -Wait -NoNewWindow -PassThru
                
                if ($process.ExitCode -eq 0 -and (Test-Path -Path $extractedIsoPath)) {
                    Write-Host "Successfully extracted ISO to $extractedIsoPath"
                } else {
                    throw "Failed to extract ISO file. Exit code: $($process.ExitCode)"
                }
            } else {
                Write-Host "Using existing extracted ISO: $extractedIsoPath"
            }

            return $extractedIsoPath
        }
        catch {
            Write-Error "Error extracting ISO: $_"
            Handle-Error -ErrorRecord $_
            throw
        }
    }

    End {
        Write-Host "Exiting Expand-CompressedISO function"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Dismount-VHDX',
    'Expand-CompressedISO'
)