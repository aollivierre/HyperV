#requires -RunAsAdministrator

param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$OutputDir = "C:\code\VM\Setup\VHDX\test",
    [int]$SizeGB = 100,
    [int]$EditionIndex = 0  # 0 means prompt for selection
)

# Script-level variables for drive letters
$script:efiLetter = ""
$script:winLetter = ""

function Execute-Diskpart {
    param([string[]]$Commands)
    $script = $Commands -join "`n"
    $scriptFile = "$env:TEMP\diskpart_$(Get-Random).txt"
    $script | Out-File $scriptFile -Encoding ASCII
    $result = & diskpart /s $scriptFile 2>&1
    Remove-Item $scriptFile -Force
    if ($LASTEXITCODE -ne 0) {
        throw "Diskpart failed: $result"
    }
    return $result
}

Clear-Host
Write-Host "ISO to VHDX Converter" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan

# Validate ISO path - prompt if not found
while (!(Test-Path $ISOPath)) {
    Write-Host ""
    Write-Host "ISO file not found: $ISOPath" -ForegroundColor Yellow
    Write-Host "Please enter the path to your Windows ISO file:" -ForegroundColor Cyan
    $ISOPath = Read-Host
    
    # Handle quotes and expand path
    $ISOPath = $ISOPath.Trim('"')
    
    if (!(Test-Path $ISOPath)) {
        Write-Host "File not found. Please try again." -ForegroundColor Red
    } elseif ($ISOPath -notmatch '\.iso$') {
        Write-Host "File must be an ISO file (*.iso)" -ForegroundColor Red
        $ISOPath = "invalid"  # Force loop to continue
    }
}

# Validate output directory
$OutputDir = $OutputDir.Trim('"')
try {
    # Check if drive exists
    $drive = Split-Path $OutputDir -Qualifier
    if ($drive -and !(Test-Path "$drive\")) {
        Write-Host ""
        Write-Host "Drive $drive does not exist." -ForegroundColor Yellow
        Write-Host "Available drives:" -ForegroundColor Cyan
        Get-PSDrive -PSProvider FileSystem | ForEach-Object { Write-Host "  $($_.Name):" }
        Write-Host ""
        Write-Host "Please enter a valid output directory path:" -ForegroundColor Cyan
        $OutputDir = Read-Host
        $OutputDir = $OutputDir.Trim('"')
    }
    
    # Create directory if it doesn't exist
    if (!(Test-Path $OutputDir)) {
        Write-Host "Creating output directory: $OutputDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction Stop | Out-Null
    }
} catch {
    Write-Host "ERROR: Cannot create output directory: $_" -ForegroundColor Red
    Write-Host "Please enter a valid output directory path:" -ForegroundColor Cyan
    $OutputDir = Read-Host
    $OutputDir = $OutputDir.Trim('"')
    
    try {
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
    } catch {
        Write-Host "ERROR: Cannot create directory. Using temp directory instead." -ForegroundColor Red
        $OutputDir = $env:TEMP
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$vhdxPath = Join-Path $OutputDir "Windows10_$timestamp.vhdx"

# Check available disk space
$outputDrive = (Get-Item $OutputDir).PSDrive.Name
$driveInfo = Get-PSDrive $outputDrive
$freeSpaceGB = [math]::Round($driveInfo.Free / 1GB, 2)
$requiredSpaceGB = [math]::Round($SizeGB * 0.2, 2)  # Estimate 20% for dynamic VHDX

if ($freeSpaceGB -lt $requiredSpaceGB) {
    Write-Host ""
    Write-Host "WARNING: Low disk space!" -ForegroundColor Yellow
    Write-Host "Available: $freeSpaceGB GB"
    Write-Host "Recommended: $requiredSpaceGB GB (for $SizeGB GB VHDX)"
    Write-Host ""
    Write-Host "Continue anyway? (Y/N)" -ForegroundColor Yellow
    $continue = Read-Host
    if ($continue -ne 'Y' -and $continue -ne 'y') {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Green
Write-Host "ISO: $ISOPath"
Write-Host "Output: $vhdxPath"
Write-Host "Size: $SizeGB GB"
Write-Host "Free Space: $freeSpaceGB GB"
Write-Host ""

# Create VHDX
Write-Host "[1/6] Creating VHDX..." -ForegroundColor Yellow
try {
    Execute-Diskpart @(
        "create vdisk file=""$vhdxPath"" maximum=$($SizeGB * 1024) type=expandable",
        "select vdisk file=""$vhdxPath""",
        "attach vdisk"
    ) | Out-Null
    Write-Host "OK - VHDX created" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    exit 1
}

# Get disk number
Write-Host "[2/6] Preparing disk..." -ForegroundColor Yellow
try {
    # Get detailed disk info
    $output = Execute-Diskpart @("list disk")
    Write-Host "Disk list:" -ForegroundColor Gray
    $output | Write-Host
    
    # Find the disk we just created - it should be the newest uninitialized disk
    $diskLines = $output -split "`n" | Where-Object { $_ -match "Disk \d+" }
    
    # Try different patterns to find our disk
    $virtualDisk = $diskLines | Where-Object { $_ -match "GB.*Online" } | Select-Object -Last 1
    
    if (!$virtualDisk) {
        # Try another pattern
        $virtualDisk = $diskLines | Where-Object { $_ -match "100 GB" } | Select-Object -Last 1
    }
    
    if (!$virtualDisk) {
        # Just get the last disk
        $virtualDisk = $diskLines | Select-Object -Last 1
    }
    
    if (!$virtualDisk) {
        throw "Could not find any disk"
    }
    
    $diskNum = [regex]::Match($virtualDisk, "Disk (\d+)").Groups[1].Value
    Write-Host "Using Disk $diskNum" -ForegroundColor Gray
    
    # Get available drive letters
    $usedLetters = (Get-PSDrive -PSProvider FileSystem).Name
    $allLetters = 67..90 | ForEach-Object { [char]$_ }  # C-Z
    $availableLetters = $allLetters | Where-Object { $_ -notin $usedLetters }
    
    if ($availableLetters.Count -lt 2) {
        throw "Not enough drive letters available. Need at least 2 free drive letters."
    }
    
    $script:efiLetter = $availableLetters[0]
    $script:winLetter = $availableLetters[1]
    
    Write-Host "Using drive letters: EFI=$($script:efiLetter), Windows=$($script:winLetter)" -ForegroundColor Gray
    
    # Partition disk
    Execute-Diskpart @(
        "select disk $diskNum",
        "clean",
        "convert gpt",
        "create partition efi size=100",
        "format quick fs=fat32 label=""EFI""",
        "assign letter=$($script:efiLetter)",
        "create partition msr size=128",
        "create partition primary",
        "format quick fs=ntfs label=""Windows""",
        "assign letter=$($script:winLetter)"
    ) | Out-Null
    
    Write-Host "OK - Disk partitioned" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    Execute-Diskpart @("select vdisk file=""$vhdxPath""", "detach vdisk") | Out-Null
    exit 1
}

# Mount ISO
Write-Host "[3/6] Mounting ISO..." -ForegroundColor Yellow
try {
    $iso = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $isoDrive = ($iso | Get-Volume).DriveLetter
    
    $wimPath = "${isoDrive}:\sources\install.wim"
    if (!(Test-Path $wimPath)) {
        $wimPath = "${isoDrive}:\sources\install.esd"
        if (!(Test-Path $wimPath)) {
            throw "No install.wim or install.esd found"
        }
    }
    
    Write-Host "OK - ISO mounted at ${isoDrive}:" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    Execute-Diskpart @("select vdisk file=""$vhdxPath""", "detach vdisk") | Out-Null
    exit 1
}

# Show and select editions
Write-Host "[4/6] Selecting Windows edition..." -ForegroundColor Yellow
try {
    # Get all available editions
    $editions = Get-WindowsImage -ImagePath $wimPath
    
    # Check if EditionIndex was pre-selected
    if ($EditionIndex -gt 0) {
        # Validate the pre-selected index
        $selected = $editions | Where-Object { $_.ImageIndex -eq $EditionIndex }
        if ($selected) {
            Write-Host "Using pre-selected edition: [$($selected.ImageIndex)] $($selected.ImageName)" -ForegroundColor Green
        } else {
            Write-Host "Invalid edition index $EditionIndex. Prompting for selection..." -ForegroundColor Yellow
            $EditionIndex = 0
        }
    }
    
    # If no valid pre-selection, prompt user
    if ($EditionIndex -eq 0) {
        Write-Host ""
        Write-Host "Available Windows Editions:" -ForegroundColor Cyan
        Write-Host "===========================" -ForegroundColor Cyan
        
        foreach ($edition in $editions) {
            Write-Host "[$($edition.ImageIndex)] $($edition.ImageName)"
        }
        
        Write-Host ""
        Write-Host "Please select an edition by entering its number:" -ForegroundColor Yellow
        $choice = Read-Host
        
        # Validate choice
        if ($choice -match '^\d+$') {
            $selectedIndex = [int]$choice
            $selected = $editions | Where-Object { $_.ImageIndex -eq $selectedIndex }
            if ($selected) {
                $EditionIndex = $selectedIndex
                Write-Host "Selected: [$($selected.ImageIndex)] $($selected.ImageName)" -ForegroundColor Green
            } else {
                throw "Invalid selection. Edition index $selectedIndex not found."
            }
        } else {
            throw "Invalid input. Please enter a number."
        }
    }
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $ISOPath
    Execute-Diskpart @("select vdisk file=""$vhdxPath""", "detach vdisk") | Out-Null
    exit 1
}

# Apply image
Write-Host "[5/6] Applying Windows image..." -ForegroundColor Yellow
Write-Host "This will take 5-15 minutes, please wait..." -ForegroundColor Gray

$startTime = Get-Date
$logPath = "$env:TEMP\dism_$timestamp.log"

try {
    # Use Start-Process to run DISM
    $dismArgs = @(
        "/Apply-Image",
        "/ImageFile:""$wimPath""",
        "/Index:$EditionIndex",
        "/ApplyDir:$($script:winLetter):\",
        "/LogPath:""$logPath"""
    )
    
    $process = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -NoNewWindow -PassThru
    
    # Monitor progress
    while (!$process.HasExited) {
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        Write-Host "Applying image... $elapsed seconds elapsed" -NoNewline
        Write-Host "`r" -NoNewline
        Start-Sleep -Seconds 5
    }
    
    Write-Host ""
    
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne $null) {
        throw "DISM failed with exit code: $($process.ExitCode)"
    }
    
    Write-Host "OK - Windows image applied" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    Write-Host "Check log: $logPath" -ForegroundColor Yellow
    Dismount-DiskImage -ImagePath $ISOPath
    Execute-Diskpart @("select vdisk file=""$vhdxPath""", "detach vdisk") | Out-Null
    exit 1
}

# Configure boot
Write-Host "[6/6] Configuring boot..." -ForegroundColor Yellow
try {
    & bcdboot "$($script:winLetter):\Windows" /s "$($script:efiLetter):" /f UEFI | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK - Boot configured" -ForegroundColor Green
    } else {
        Write-Host "WARNING - Boot configuration may have issues" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: $_" -ForegroundColor Yellow
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow
Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
Execute-Diskpart @("select vdisk file=""$vhdxPath""", "detach vdisk") | Out-Null

# Done
if (Test-Path $vhdxPath) {
    $size = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " SUCCESS! VHDX CREATED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "File: $vhdxPath" -ForegroundColor Cyan
    Write-Host "Size: $size GB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This VHDX is ready to use with Hyper-V!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Copy to Hyper-V host (if needed)"
    Write-Host "2. Create new Generation 2 VM"
    Write-Host "3. Use existing virtual hard disk"
    Write-Host "4. Browse to: $vhdxPath"
    Write-Host "5. Start VM!"
} else {
    Write-Host "ERROR: VHDX not found" -ForegroundColor Red
    exit 1
}