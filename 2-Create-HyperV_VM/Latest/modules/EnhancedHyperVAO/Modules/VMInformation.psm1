# VMInformation.psm1
# Provides VM information and discovery functions

function Get-VMConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = "D:\VM\Configs",

        [Parameter()]
        [ValidateSet('VSCode', 'Notepad', 'None')]
        [string]$Editor = 'VSCode'
    )

    Begin {
        Write-Host "Starting configuration file selection process"
        
        # Get all PSD1 files
        $getPSD1Params = @{
            Path = $ConfigPath
            Filter = "*.psd1"
            ErrorAction = 'SilentlyContinue'
        }
        
        $configFiles = Get-ChildItem @getPSD1Params
        
        if ($configFiles.Count -eq 0) {
            Write-Error "No configuration files found in $ConfigPath"
            return $null
        }
    }

    Process {
        try {
            # Display available configurations
            Write-Host "`n=== Available VM Configurations ===" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            
            $configFiles | ForEach-Object -Begin { $index = 1 } -Process {
                Write-Host ("{0,3}. {1}" -f $index++, $_.BaseName)
            }
            Write-Host "----------------------------------------" -ForegroundColor Cyan

            # Get and validate user selection
            do {
                $selection = Read-Host "`nSelect a configuration (1-$($configFiles.Count))"
                
                # Validate selection is a number and within range
                if ($selection -match '^\d+$') {
                    $selectionNum = [int]$selection
                    $validSelection = ($selectionNum -ge 1) -and ($selectionNum -le $configFiles.Count)
                } else {
                    $validSelection = $false
                }
                
                if (-not $validSelection) {
                    Write-Host "Invalid selection. Please enter a number between 1 and $($configFiles.Count)" -ForegroundColor Yellow
                }
            } while (-not $validSelection)

            # Load selected configuration
            $selectedConfig = $configFiles[$selectionNum - 1]
            $configPath = $selectedConfig.FullName
            
            $importParams = @{
                Path = $configPath
                ErrorAction = 'Stop'
            }
            
            $config = Import-PowerShellDataFile @importParams

            # Display configuration details
            Write-Host "`nConfiguration Details:" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            $config.GetEnumerator() | Sort-Object Key | ForEach-Object {
                Write-Host ("{0,-20} = {1}" -f $_.Key, $_.Value)
            }
            Write-Host "----------------------------------------" -ForegroundColor Cyan

            # Confirm or edit configuration
            do {
                $proceed = Read-Host "`nProceed with this configuration? (Y)es, (E)dit, or (C)ancel"
                
                switch -Regex ($proceed) {
                    '^[Yy]$' {
                        Write-Host "Configuration selected: $($selectedConfig.Name)"
                        return $config
                    }
                    '^[Ee]$' {
                        Write-Host "Opening configuration for editing"
                        
                        switch ($Editor) {
                            'VSCode' { Start-Process code -ArgumentList $configPath -Wait }
                            'Notepad' { Start-Process notepad -ArgumentList $configPath -Wait }
                        }
                        
                        # Reload configuration after editing
                        $config = Import-PowerShellDataFile @importParams
                        
                        Write-Host "`nUpdated Configuration:" -ForegroundColor Cyan
                        $config.GetEnumerator() | Sort-Object Key | ForEach-Object {
                            Write-Host ("{0,-20} = {1}" -f $_.Key, $_.Value)
                        }
                    }
                    '^[Cc]$' {
                        Write-Host "Configuration selection cancelled"
                        return $null
                    }
                    default {
                        Write-Host "Invalid input. Please enter Y, E, or C" -ForegroundColor Yellow
                    }
                }
            } while ($proceed -notmatch '^[Yy]$|^[Cc]$')
        }
        catch {
            Write-Error "Error processing configuration: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
            return $null
        }
    }

    End {
        Write-Host "Configuration selection process completed"
    }
}

function Get-DependentVMs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    Begin {
        Write-Host "Starting Get-DependentVMs function"
    }

    Process {
        try {
            Write-Host "Retrieving all VMs"
            $allVMs = Get-VM
            Write-Host "Total VMs found: $($allVMs.Count)"

            $dependentVMs = [System.Collections.Generic.List[PSObject]]::new()

            foreach ($vm in $allVMs) {
                $hardDrives = $vm.HardDrives
                foreach ($hd in $hardDrives) {
                    try {
                        # Check if the VHD file exists before trying to access it
                        if (Test-Path $hd.Path) {
                            # Attempt to get the parent path of the VHD
                            $parentPath = (Get-VHD -Path $hd.Path).ParentPath

                            if ($parentPath -eq $VHDXPath) {
                                $dependentVMs.Add($vm)
                                Write-Host "Dependent VM: $($vm.Name)"
                                break
                            }
                        } else {
                            # Log a warning if the VHDX file does not exist
                            Write-Warning "Warning: VHDX file not found: $($hd.Path). Skipping VM: $($vm.Name)"
                        }
                    } catch {
                        # Log a warning if there was an error accessing the VHDX file
                        Write-Warning "Warning: An error occurred while accessing VHDX file: $($hd.Path). Skipping VM: $($vm.Name)"
                    }
                }
            }

            Write-Host "Total dependent VMs using VHDX $VHDXPath $($dependentVMs.Count)"
            return $dependentVMs
        } catch {
            Write-Error "An error occurred while retrieving dependent VMs: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
            return [System.Collections.Generic.List[PSObject]]::new()
        }
    }

    End {
        Write-Host "Exiting Get-DependentVMs function"
    }
}

function Get-NextVMNamePrefix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Config
    )

    Begin {
        Write-Host "Starting Get-NextVMNamePrefix function"
    }

    Process {
        try {
            Write-Host "Retrieving the most recent VM"
            $mostRecentVM = Get-VM | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
            $prefixNumber = 0

            if ($null -ne $mostRecentVM) {
                Write-Host "Most recent VM found: $($mostRecentVM.Name)"
                if ($mostRecentVM.Name -match '^\d+') {
                    $prefixNumber = [int]$matches[0]
                    Write-Host "Extracted prefix number: $prefixNumber"
                } else {
                    Write-Host "Most recent VM name does not start with a number"
                }
            } else {
                Write-Host "No existing VMs found"
            }

            $nextPrefixNumber = $prefixNumber + 1
            $newVMNamePrefix = $Config.VMNamePrefixFormat -f $nextPrefixNumber
            Write-Host "Generated new VM name prefix: $newVMNamePrefix"

            return $newVMNamePrefix
        } catch {
            Write-Error "An error occurred in Get-NextVMNamePrefix: $($_.Exception.Message)"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-Host "Get-NextVMNamePrefix function completed"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Get-VMConfiguration',
    'Get-DependentVMs',
    'Get-NextVMNamePrefix'
)