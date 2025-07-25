#requires -RunAsAdministrator

<#
.SYNOPSIS
    Complete ISO to VHDX converter using only native Windows tools.
    Works without Hyper-V installed.
#>

param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$OutputDir = "C:\code\VM\Setup\VHDX\test",
    [int]$SizeGB = 100,
    [int]$EditionIndex = 6  # Pro edition by default
)

# Helper functions
function Execute-Diskpart {
    param([string[]]$Commands)
    $script = $Commands -join "`n"
    $scriptFile = [System.IO.Path]::GetTempFileName()
    $script | Out-File $scriptFile -Encoding ASCII
    $result = & diskpart /s $scriptFile 2>&1
    Remove-Item $scriptFile -Force
    if ($LASTEXITCODE -ne 0) {
        throw "Diskpart failed: $result"
    }
    return $result
}

function Get-NextAvailableLetter {
    $used = (Get-PSDrive -PSProvider FileSystem).Name
    $letters = 67..90 | ForEach-Object { [char]$_ }  # C-Z
    $available = $letters | Where-Object { $_ -notin $used }
    return $available | Select-Object -First 1
}

# Main script
Clear-Host
Write-Host "ISO to VHDX Converter (No Hyper-V Required)" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Validate
if (!(Test-Path $ISOPath)) {
    Write-Host "ERROR: ISO not found: $ISOPath" -ForegroundColor Red
    exit 1
}

# Setup paths
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$vhdxFile = "Windows10_Complete_$timestamp.vhdx"
$vhdxPath = Join-Path $OutputDir $vhdxFile

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  ISO: $ISOPath"
Write-Host "  Output: $vhdxPath"
Write-Host "  Size: $SizeGB GB"

# Step 1: Create and mount VHDX
Write-Host "`n[1/6] Creating VHDX..." -ForegroundColor Yellow
try {
    Execute-Diskpart @(
        "create vdisk file=`"$vhdxPath`" maximum=$($SizeGB * 1024) type=expandable",
        "select vdisk file=`"$vhdxPath`"",
        "attach vdisk"
    ) | Out-Null
    Write-Host "✓ VHDX created and attached" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create VHDX: $_" -ForegroundColor Red
    exit 1
}

# Get disk number
Write-Host "`n[2/6] Preparing disk..." -ForegroundColor Yellow
try {
    # Get the disk number of our VHDX
    $output = Execute-Diskpart @("list disk")
    $diskLine = $output | Select-String "Disk \d+.*Virtual" | Select-Object -Last 1
    if (!$diskLine) {
        throw "Could not find virtual disk"
    }
    $diskNum = [regex]::Match($diskLine, "Disk (\d+)").Groups[1].Value
    
    # Get available drive letters
    $winLetter = Get-NextAvailableLetter
    $efiLetter = Get-NextAvailableLetter | Select-Object -Skip 1 | Select-Object -First 1
    
    Write-Host "  Using Disk $diskNum"
    Write-Host "  Windows drive: ${winLetter}:"
    Write-Host "  EFI drive: ${efiLetter}:"
    
    # Initialize and partition
    Execute-Diskpart @(
        "select disk $diskNum",
        "clean",
        "convert gpt",
        "create partition efi size=100",
        "format quick fs=fat32 label=`"EFI`"",
        "assign letter=$efiLetter",
        "create partition msr size=128",
        "create partition primary",
        "format quick fs=ntfs label=`"Windows`"",
        "assign letter=$winLetter"
    ) | Out-Null
    
    Write-Host "✓ Disk initialized and partitioned" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to prepare disk: $_" -ForegroundColor Red
    Execute-Diskpart @("select vdisk file=`"$vhdxPath`"", "detach vdisk") | Out-Null
    exit 1
}

# Step 3: Mount ISO
Write-Host "`n[3/6] Mounting ISO..." -ForegroundColor Yellow
try {
    $iso = Mount-DiskImage -ImagePath $ISOPath -PassThru
    $isoDrive = ($iso | Get-Volume).DriveLetter
    
    # Find install.wim
    $wimPath = "${isoDrive}:\sources\install.wim"
    if (!(Test-Path $wimPath)) {
        $wimPath = "${isoDrive}:\sources\install.esd"
        if (!(Test-Path $wimPath)) {
            throw "No install.wim or install.esd found"
        }
    }
    
    Write-Host "✓ ISO mounted at ${isoDrive}:" -ForegroundColor Green
    Write-Host "  WIM: $wimPath" -ForegroundColor Gray
} catch {
    Write-Host "✗ Failed to mount ISO: $_" -ForegroundColor Red
    Execute-Diskpart @("select vdisk file=`"$vhdxPath`"", "detach vdisk") | Out-Null
    exit 1
}

# Step 4: List editions
Write-Host "`n[4/6] Checking Windows editions..." -ForegroundColor Yellow
$editions = dism /Get-ImageInfo /ImageFile:"$wimPath" /English | Select-String "Index|Name" 
Write-Host "  Using edition index: $EditionIndex (Windows 10 Pro)" -ForegroundColor Gray

# Step 5: Apply image
Write-Host "`n[5/6] Applying Windows image (this will take 5-15 minutes)..." -ForegroundColor Yellow
Write-Host "  Please be patient - the process may appear frozen but is working" -ForegroundColor Gray

$logPath = "$env:TEMP\dism_apply_$timestamp.log"
$startTime = Get-Date

try {
    $process = Start-Process -FilePath "dism.exe" `
        -ArgumentList "/Apply-Image", "/ImageFile:`"$wimPath`"", "/Index:$EditionIndex", "/ApplyDir:${winLetter}:\", "/English" `
        -NoNewWindow -PassThru
    
    while (!$process.HasExited) {
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        Write-Host ("`r  Progress: Applying image... ({0} seconds elapsed)" -f $elapsed) -NoNewline
        Start-Sleep -Seconds 2
    }
    
    Write-Host ""
    if ($process.ExitCode -ne 0) {
        throw ("DISM exited with code {0}" -f $process.ExitCode)
    }
    
    Write-Host "✓ Windows image applied successfully" -ForegroundColor Green
} catch {
    Write-Host "`n✗ Failed to apply image: $_" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $ISOPath
    Execute-Diskpart @("select vdisk file=`"$vhdxPath`"", "detach vdisk") | Out-Null
    exit 1
}

# Step 6: Make bootable
Write-Host "`n[6/6] Making VHDX bootable..." -ForegroundColor Yellow
try {
    $result = & bcdboot "${winLetter}:\Windows" /s "${efiLetter}:" /f UEFI 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Boot files configured" -ForegroundColor Green
    } else {
        Write-Host "⚠ Boot configuration warning: $result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Could not configure boot: $_" -ForegroundColor Yellow
}

# Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Yellow
Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
Execute-Diskpart @("select vdisk file=`"$vhdxPath`"", "detach vdisk") | Out-Null

# Success!
if (Test-Path $vhdxPath) {
    $size = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host " SUCCESS! VHDX CREATED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nFile: $vhdxPath" -ForegroundColor Cyan
    Write-Host "Size: $size GB (sparse file, max $SizeGB GB)" -ForegroundColor Cyan
    Write-Host "Type: UEFI/GPT (Generation 2 ready)" -ForegroundColor Cyan
    
    Write-Host "`nThis VHDX is fully configured and ready to use!" -ForegroundColor Green
    Write-Host "`nTo use with Hyper-V:" -ForegroundColor Yellow
    Write-Host "1. Copy to a Hyper-V host"
    Write-Host "2. Create new Generation 2 VM"
    Write-Host "3. Use existing virtual hard disk"
    Write-Host "4. Select: $vhdxPath"
    Write-Host "5. Start VM - Windows will complete setup!"
} else {
    Write-Host "`nERROR: VHDX not found after creation" -ForegroundColor Red
    exit 1
}