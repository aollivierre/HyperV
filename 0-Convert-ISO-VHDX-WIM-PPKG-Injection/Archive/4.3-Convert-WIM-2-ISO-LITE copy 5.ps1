# The following script will convert a WIM file to an ISO file using DISM




function Convert-WimToIso {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseImagePath,

        [Parameter(Mandatory=$true)]
        [string]$AdditionalImagesPaths,

        [Parameter(Mandatory=$true)]
        [string]$OutputIsoPath,

        [Parameter(Mandatory=$true)]
        [string]$WorkDir
    )

    # Create necessary directories
    $ISOFilesDir = Join-Path -Path $WorkDir -ChildPath "ISO_Files"
    $WIMDir = Join-Path -Path $WorkDir -ChildPath "WIM"
    New-Item -ItemType Directory -Path $ISOFilesDir -Force | Out-Null
    New-Item -ItemType Directory -Path $WIMDir -Force | Out-Null

    # Step 1: Copy base image files
    Write-Output "Copying base image files..."
    Copy-Item -Path (Join-Path -Path $BaseImagePath -ChildPath "*") -Destination $ISOFilesDir -Recurse -Force

    # Step 2: Create base WIM image
    $BaseWimFile = Join-Path -Path $ISOFilesDir -ChildPath "sources\install.wim"
    $DestinationWimFile = Join-Path -Path $WIMDir -ChildPath "install.wim"
    $BaseWimIndex = 1  # Modify this based on your base image index
    Write-Output "Creating base WIM image..."
    dism /Export-Image /SourceImageFile:$BaseWimFile /SourceIndex:$BaseWimIndex /DestinationImageFile:$DestinationWimFile /DestinationName:"Base Image"

    # Step 3: Add additional images to base WIM
    foreach ($ImagePath in $AdditionalImagesPaths) {
        $ImageFile = Join-Path -Path $ImagePath -ChildPath "install.wim"
        Write-Output "Adding image $ImagePath to base WIM..."
        dism /Export-Image /SourceImageFile:$ImageFile /SourceIndex:1 /DestinationImageFile:$DestinationWimFile /DestinationName:"Additional Image $($ImagePath)"
    }

    # Step 4: Replace the original WIM file with the new WIM
    Write-Output "Replacing original WIM with the new multi-image WIM..."
    Copy-Item -Path $DestinationWimFile -Destination $BaseWimFile -Force

    # Step 5: Create the ISO file
    Write-Output "Creating ISO file..."
    $OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    $BootImage = Join-Path -Path $ISOFilesDir -ChildPath "boot\etfsboot.com"
    $EFIImage = Join-Path -Path $ISOFilesDir -ChildPath "efi\microsoft\boot\efisys.bin"
    & $OscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$BootImage"#pEF,e,b"$EFIImage" "$ISOFilesDir" "$OutputIsoPath"

    Write-Output "ISO file created successfully at $OutputIsoPath"
}

# Example usage:
Convert-WimToIso -BaseImagePath "C:\Path\To\BaseImage" -AdditionalImagesPaths @("C:\Path\To\AdditionalImage1", "C:\Path\To\AdditionalImage2") -OutputIsoPath "C:\Path\To\Output\CustomWindows10.iso" -WorkDir "C:\Path\To\WorkingDirectory"



function Convert-WimToIso {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$WimPath,

        [Parameter(Mandatory=$true)]
        [string]$IsoOutputPath,

        [Parameter(Mandatory=$true)]
        [int]$ImageIndex,

        [Parameter(Mandatory=$true)]
        [string]$TempPath
    )

    try {
        # Create temporary directories
        Write-Host "Creating temporary directories" -ForegroundColor Cyan
        $mountPath = Join-Path -Path $TempPath -ChildPath "mount"
        $isoContentPath = Join-Path -Path $TempPath -ChildPath "iso"
        $oscdimgPath = Join-Path -Path $TempPath -ChildPath "oscdimg"
        $tempWimPath = Join-Path -Path $TempPath -ChildPath "installtemp.wim"

        foreach ($dir in @($mountPath, $isoContentPath, $oscdimgPath)) {
            if (-not (Test-Path -Path $dir)) {
                New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
            }
        }

        # Copy the WIM to a temporary location
        Write-Host "Copying WIM to temporary location" -ForegroundColor Cyan
        Copy-Item -Path $WimPath -Destination $tempWimPath -Force

        # Set the temporary WIM to read/write
        Write-Host "Setting temporary WIM as read/write" -ForegroundColor Cyan
        Set-ItemProperty -Path $tempWimPath -Name IsReadOnly -Value $false

        # Mount the WIM
        Write-Host "Mounting WIM" -ForegroundColor Cyan
        $mount = Mount-WindowsImage -ImagePath $tempWimPath -Path $mountPath -Index $ImageIndex

        # Copy WIM contents to ISO content directory
        Write-Host "Copying WIM contents to ISO content directory" -ForegroundColor Cyan
        try {
            Copy-Item -Path "$mountPath\*" -Destination $isoContentPath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Warning: Some files or directories could not be copied due to permission issues or missing paths." -ForegroundColor Yellow
            $_.Exception.Message
        }

        # Dismount the WIM and save changes
        Write-Host "Dismounting WIM and saving changes" -ForegroundColor Cyan
        Dismount-WindowsImage -Path $mountPath -Save

        # Set the original WIM to read/write
        Write-Host "Setting original WIM as read/write" -ForegroundColor Cyan
        Set-ItemProperty -Path $WimPath -Name IsReadOnly -Value $false

        # Replace the original WIM with the modified WIM
        Write-Host "Replacing original WIM with modified WIM" -ForegroundColor Cyan
        Remove-Item -Path $WimPath -Force
        Move-Item -Path $tempWimPath -Destination $WimPath

        # Download oscdimg
        Write-Host "Downloading oscdimg" -ForegroundColor Cyan
        $oscdimgUrl = "https://github.com/andrew-s-taylor/oscdimg/archive/main.zip"
        $oscdimgZipPath = Join-Path -Path $TempPath -ChildPath "oscdimg.zip"
        Invoke-WebRequest -Uri $oscdimgUrl -OutFile $oscdimgZipPath -ErrorAction Stop

        # Unzip oscdimg
        Write-Host "Unzipping oscdimg" -ForegroundColor Cyan
        Expand-Archive -Path $oscdimgZipPath -DestinationPath $oscdimgPath -Force

        # Create the ISO file
        Write-Host "Creating ISO" -ForegroundColor Cyan
        $oscdimgExePath = Join-Path -Path $oscdimgPath -ChildPath "oscdimg-main\oscdimg.exe"
        $efiBootFile = Join-Path -Path $isoContentPath -ChildPath "efi\microsoft\boot\efisys.bin"
        if (-not (Test-Path -Path $efiBootFile)) {
            Write-Host "ERROR: Boot sector file not found: $efiBootFile" -ForegroundColor Red
            throw "Boot sector file not found"
        }
        & $oscdimgExePath -b$efiBootFile -pEF -u1 -udfver102 $isoContentPath $IsoOutputPath

        Write-Host "ISO created successfully: $IsoOutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
        if (Test-Path -Path $mountPath) {
            Write-Host "Attempting to dismount the WIM due to error." -ForegroundColor Yellow
            Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction SilentlyContinue
        }
        if (Test-Path -Path $tempWimPath) {
            Write-Host "Cleaning up temporary WIM" -ForegroundColor Yellow
            Remove-Item -Path $tempWimPath -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        Write-Host "Cleaning up temporary directories" -ForegroundColor Cyan
        foreach ($dir in @($mountPath, $isoContentPath, $oscdimgPath)) {
            if (Test-Path -Path $dir) {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path -Path $oscdimgZipPath) {
            Remove-Item -Path $oscdimgZipPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# Example usage with splatting
$params = @{
    WimPath = "D:\VM\Setup\WIM\install.wim"
    IsoOutputPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-PPKG-Professional.ISO"
    ImageIndex = 1
    TempPath = "C:\Temp\WimToIso"
}

Convert-WimToIso @params
