# VMInformation.psm1
# Provides VM information and discovery functions

function Get-VMConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = "D:\VM\Configs",

        [Parameter()]
        [ValidateSet('VSCode', 'Notepad', 'None')]
        [string]$Editor = 'VSCode',
        
        [Parameter()]
        [switch]$NonInteractive
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
            # In non-interactive mode, select the first available config
            if ($NonInteractive) {
                Write-Host "Non-interactive mode: Selecting first available configuration" -ForegroundColor Yellow
                $selectedConfig = $configFiles | Select-Object -First 1
                $configPath = $selectedConfig.FullName
                
                Write-Host "Auto-selected configuration: $($selectedConfig.BaseName)" -ForegroundColor Green
                
                $importParams = @{
                    Path = $configPath
                    ErrorAction = 'Stop'
                }
                
                $config = Import-PowerShellDataFile @importParams
                
                Write-Host "`nConfiguration loaded successfully:" -ForegroundColor Cyan
                Write-Host "File: $($selectedConfig.Name)" -ForegroundColor Cyan
                
                return $config
            }
            
            # Interactive mode (original behavior)
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
            $confirmed = $false
            do {
                $proceed = Read-Host "`nProceed with this configuration? (Y)es, (E)dit, or (C)ancel"
                
                switch -Regex ($proceed) {
                    '^[Yy]$' {
                        Write-Host "Configuration selected: $($selectedConfig.Name)"
                        $confirmed = $true
                    }
                    '^[Ee]$' {
                        Write-Host "Opening configuration for editing"
                        
                        try {
                            # Try VSCode first if available
                            $vscodePath = Get-Command code -ErrorAction SilentlyContinue
                            if ($vscodePath) {
                                Write-Host "`nOpening configuration in VS Code..." -ForegroundColor Yellow
                                Write-Host "Please edit the file and save it, then close VS Code or the file tab." -ForegroundColor Yellow
                                Write-Host "The script will wait for you to finish editing." -ForegroundColor Yellow
                                
                                # Get initial file modification time
                                $initialModTime = (Get-Item $configPath).LastWriteTime
                                
                                # Open VS Code (without -Wait as it doesn't work properly with VS Code)
                                Start-Process code -ArgumentList "`"$configPath`""
                                
                                # Wait for user to indicate they're done
                                Write-Host "`nPress Enter when you have finished editing and saved the file..." -ForegroundColor Cyan
                                Read-Host
                                
                                # Check if file was actually modified
                                $currentModTime = (Get-Item $configPath).LastWriteTime
                                if ($currentModTime -gt $initialModTime) {
                                    Write-Host "File was modified. Reloading configuration..." -ForegroundColor Green
                                }
                                else {
                                    Write-Host "File was not modified." -ForegroundColor Yellow
                                }
                            }
                            else {
                                # Fall back to notepad (which does support -Wait properly)
                                Write-Host "`nOpening configuration in Notepad..." -ForegroundColor Yellow
                                Start-Process notepad -ArgumentList "`"$configPath`"" -Wait
                            }
                            
                            # Reload configuration after editing
                            $config = Import-PowerShellDataFile @importParams
                            
                            Write-Host "`nUpdated Configuration:" -ForegroundColor Cyan
                            Write-Host "----------------------------------------" -ForegroundColor Cyan
                            $config.GetEnumerator() | Sort-Object Key | ForEach-Object {
                                Write-Host ("{0,-20} = {1}" -f $_.Key, $_.Value)
                            }
                            Write-Host "----------------------------------------" -ForegroundColor Cyan
                        }
                        catch {
                            Write-Error "Failed to open editor or reload configuration: $_"
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
            } while (-not $confirmed -and $proceed -notmatch '^[Cc]$')
            
            return $config
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
                # Look for any 3-digit number at the start of the VM name (including after whitespace)
                if ($mostRecentVM.Name -match '^(\d{3})\s*-') {
                    $prefixNumber = [int]$matches[1]
                    Write-Host "Extracted prefix number: $prefixNumber"
                } else {
                    Write-Host "Most recent VM name does not follow expected pattern (###-...)"
                    # Try to find the highest numbered VM
                    $allVMs = Get-VM | Where-Object { $_.Name -match '^(\d{3})\s*-' }
                    if ($allVMs) {
                        $highestNumber = $allVMs | ForEach-Object {
                            if ($_.Name -match '^(\d{3})\s*-') {
                                [int]$matches[1]
                            }
                        } | Sort-Object -Descending | Select-Object -First 1
                        
                        if ($highestNumber) {
                            $prefixNumber = $highestNumber
                            Write-Host "Found highest VM number from all VMs: $prefixNumber"
                        }
                    }
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