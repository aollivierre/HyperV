#requires -RunAsAdministrator

<#
.SYNOPSIS
    Universal ISO to VHDX converter that works on Server 2025 without hanging.

.DESCRIPTION
    This script uses DISKPART and DISM directly to avoid Convert-WindowsImage hanging issues.
    Works on systems with or without Hyper-V PowerShell module.
#>

param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$VHDXPath = "C:\code\VM\Setup\VHDX\test\Windows10_Universal.vhdx",
    [int]$SizeGB = 100,
    [switch]$UseEFI = $true
)

function Write-Status {
    param($Message, $Color = "Cyan")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Error {
    param($Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Write-Success {
    param($Message)
    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Main script
Write-Status "`nUniversal ISO to VHDX Converter for Server 2025"
Write-Status "=============================================="
Write-Status "ISO: $ISOPath"
Write-Status "Output: $VHDXPath"
Write-Status "Size: $SizeGB GB"
Write-Status "Boot Type: $(if($UseEFI){'UEFI'}else{'BIOS'})"

# Verify ISO exists
if (!(Test-Path $ISOPath)) {
    Write-Error "ISO file not found: $ISOPath"
    exit 1
}

# Create output directory
$outputDir = Split-Path -Parent $VHDXPath
if (!(Test-Path $outputDir)) {
    Write-Status "`nCreating output directory..."
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Step 1: Create VHDX using DISKPART
Write-Status "`n[Step 1/6] Creating VHDX file using DISKPART..."
$diskpartScript = @"
create vdisk file="$VHDXPath" maximum=$($SizeGB * 1024) type=expandable
select vdisk file="$VHDXPath"
attach vdisk
convert gpt
create partition efi size=100
format quick fs=fat32 label="EFI"
assign letter=S
create partition msr size=128
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
exit
"@

if (!$UseEFI) {
    $diskpartScript = @"
create vdisk file="$VHDXPath" maximum=$($SizeGB * 1024) type=expandable
select vdisk file="$VHDXPath"
attach vdisk
convert mbr
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
active
exit
"@
}

$scriptFile = "$env:TEMP\diskpart_script.txt"
$diskpartScript | Out-File -FilePath $scriptFile -Encoding ASCII

try {
    $result = diskpart /s $scriptFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "DISKPART failed: $result"
    }
    Write-Success "VHDX created and mounted"
} catch {
    Write-Error $_
    Remove-Item $scriptFile -ErrorAction SilentlyContinue
    exit 1
} finally {
    Remove-Item $scriptFile -ErrorAction SilentlyContinue
}

# Step 2: Mount ISO
Write-Status "`n[Step 2/6] Mounting ISO..."
try {
    $iso = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $isoDrive = ($iso | Get-Volume).DriveLetter
    Write-Success "ISO mounted at ${isoDrive}:"
} catch {
    Write-Error "Failed to mount ISO: $_"
    # Cleanup
    $cleanupScript = @"
select vdisk file="$VHDXPath"
detach vdisk
exit
"@
    $cleanupScript | Out-File -FilePath "$env:TEMP\cleanup.txt" -Encoding ASCII
    diskpart /s "$env:TEMP\cleanup.txt" | Out-Null
    Remove-Item "$env:TEMP\cleanup.txt" -ErrorAction SilentlyContinue
    exit 1
}

# Step 3: Find install.wim
$wimPath = "${isoDrive}:\sources\install.wim"
if (!(Test-Path $wimPath)) {
    $wimPath = "${isoDrive}:\sources\install.esd"
    if (!(Test-Path $wimPath)) {
        Write-Error "No install.wim or install.esd found"
        Dismount-DiskImage -ImagePath $ISOPath
        exit 1
    }
}
Write-Status "Found: $wimPath"

# Step 4: List editions
Write-Status "`n[Step 3/6] Available Windows editions:"
$images = dism /Get-ImageInfo /ImageFile:"$wimPath" | Select-String "Index|Name" | ForEach-Object { $_.ToString().Trim() }
for ($i = 0; $i -lt $images.Count; $i += 2) {
    if ($images[$i] -match "Index : (\d+)") {
        $index = $matches[1]
        $name = $images[$i+1] -replace "Name : ", ""
        Write-Host "  [$index] $name"
    }
}

# Auto-select first edition
$selectedIndex = 1
Write-Success "Auto-selecting edition index: $selectedIndex"

# Step 5: Apply Windows image
Write-Status "`n[Step 4/6] Applying Windows image (this will take 5-10 minutes)..."
Write-Status "Please be patient, the process may appear to hang but is working..."

$logFile = "$env:TEMP\dism_apply_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$dismCmd = "dism /Apply-Image /ImageFile:`"$wimPath`" /Index:$selectedIndex /ApplyDir:W:\ /LogPath:`"$logFile`""

Write-Status "Executing: $dismCmd"
Write-Status "Log file: $logFile"

$startTime = Get-Date

# Run DISM in a way that shows progress
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "dism.exe"
$pinfo.Arguments = "/Apply-Image /ImageFile:`"$wimPath`" /Index:$selectedIndex /ApplyDir:W:\ /LogPath:`"$logFile`""
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $false

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo

try {
    $p.Start() | Out-Null
    
    # Monitor progress
    while (!$p.HasExited) {
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "`rApplying image... Elapsed: $elapsed seconds (Check log for details)" -NoNewline
        Start-Sleep -Seconds 5
        
        # Check if log file exists and show last line
        if (Test-Path $logFile) {
            $lastLine = Get-Content $logFile -Tail 1 -ErrorAction SilentlyContinue
            if ($lastLine -match "Progress|percent") {
                Write-Host "`r$lastLine" -NoNewline
            }
        }
    }
    
    Write-Host "" # New line
    
    if ($p.ExitCode -ne 0) {
        throw "DISM failed with exit code: $($p.ExitCode)"
    }
    
    Write-Success "Windows image applied successfully!"
} catch {
    Write-Error $_
    Write-Status "Check log file for details: $logFile"
    # Cleanup
    Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
    $cleanupScript = @"
select vdisk file="$VHDXPath"
detach vdisk
exit
"@
    $cleanupScript | Out-File -FilePath "$env:TEMP\cleanup.txt" -Encoding ASCII
    diskpart /s "$env:TEMP\cleanup.txt" | Out-Null
    Remove-Item "$env:TEMP\cleanup.txt" -ErrorAction SilentlyContinue
    exit 1
}

# Step 6: Configure boot
Write-Status "`n[Step 5/6] Configuring boot files..."
try {
    if ($UseEFI) {
        $bcdResult = & bcdboot W:\Windows /s S: /f UEFI 2>&1
    } else {
        $bcdResult = & bcdboot W:\Windows /s W: /f BIOS 2>&1
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Boot configured successfully"
    } else {
        Write-Status "Warning: Boot configuration returned: $bcdResult"
    }
} catch {
    Write-Status "Warning: Could not configure boot: $_"
}

# Step 7: Cleanup
Write-Status "`n[Step 6/6] Cleaning up..."

# Dismount ISO
Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue

# Detach VHDX
$detachScript = @"
select vdisk file="$VHDXPath"
detach vdisk
exit
"@
$detachScript | Out-File -FilePath "$env:TEMP\detach.txt" -Encoding ASCII
diskpart /s "$env:TEMP\detach.txt" | Out-Null
Remove-Item "$env:TEMP\detach.txt" -ErrorAction SilentlyContinue

# Final verification
if (Test-Path $VHDXPath) {
    $vhdxInfo = Get-Item $VHDXPath
    Write-Host "`n================================================" -ForegroundColor Green
    Write-Success "VHDX CREATED SUCCESSFULLY!"
    Write-Host "================================================" -ForegroundColor Green
    Write-Status "File: $VHDXPath"
    Write-Status "Size: $([math]::Round($vhdxInfo.Length / 1GB, 2)) GB (actual file)"
    Write-Status "Max Size: $SizeGB GB (maximum expandable)"
    Write-Status "Boot Type: $(if($UseEFI){'UEFI (Generation 2)'}else{'BIOS (Generation 1)'})"
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Open Hyper-V Manager"
    Write-Host "2. Click 'New' -> 'Virtual Machine'"
    Write-Host "3. Choose Generation $(if($UseEFI){'2'}else{'1'})"
    Write-Host "4. Select 'Use an existing virtual hard disk'"
    Write-Host "5. Browse to: $VHDXPath"
    Write-Host "6. Complete setup and start your VM!"
} else {
    Write-Error "VHDX file not found after creation"
    exit 1
}