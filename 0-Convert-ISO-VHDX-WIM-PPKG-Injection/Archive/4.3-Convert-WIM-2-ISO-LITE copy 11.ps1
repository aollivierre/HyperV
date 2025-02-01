# The following script will convert a WIM file to an ISO file using DISM





function Convert-WimToIso {
    param (
        [Parameter(Mandatory = $true)]
        [string]$WimPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputIsoPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkDir
    )

    # Create necessary directories if they do not exist
    if (-Not (Test-Path -Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    $ISOFilesDir = Join-Path -Path $WorkDir -ChildPath "ISO_Files"
    $WIMDir = Join-Path -Path $WorkDir -ChildPath "WIM"
    New-Item -ItemType Directory -Path $ISOFilesDir -Force | Out-Null
    New-Item -ItemType Directory -Path $WIMDir -Force | Out-Null

    # Step 1: Copy base image files
    Write-Output "Copying base image files..."
    try {
        $BaseImagePath = Split-Path -Path $WimPath -Parent
        Copy-Item -Path "$BaseImagePath\*" -Destination $ISOFilesDir -Recurse -Force
    }
    catch {
        Write-Error "Failed to copy base image files: $_"
        return
    }

    # Step 2: Create base WIM image
    $BaseWimFile = Join-Path -Path $ISOFilesDir -ChildPath "sources\install.wim"
    $DestinationWimFile = Join-Path -Path $WIMDir -ChildPath "install.wim"
    $BaseWimIndex = 1  # Modify this based on your base image index
    Write-Output "Creating base WIM image..."
    dism /Export-Image /SourceImageFile:$WimPath /SourceIndex:$BaseWimIndex /DestinationImageFile:$DestinationWimFile /DestinationName:"Base Image"

    # Step 3: Ensure sources directory exists
    $SourcesDir = Join-Path -Path $ISOFilesDir -ChildPath "sources"
    if (-Not (Test-Path -Path $SourcesDir)) {
        New-Item -ItemType Directory -Path $SourcesDir -Force | Out-Null
    }

    # Step 4: Replace the original WIM file with the new WIM
    Write-Output "Replacing original WIM with the new WIM..."
    if (Test-Path -Path $DestinationWimFile) {
        try {
            Copy-Item -Path $DestinationWimFile -Destination $BaseWimFile -Force
        }
        catch {
            Write-Error "Failed to replace the original WIM file: $_"
            return
        }
    }
    else {
        Write-Error "Destination WIM file not found at $DestinationWimFile"
        return
    }

    # Step 5: Create the ISO file
    Write-Output "Creating ISO file..."
    $OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    $BootImage = Join-Path -Path $ISOFilesDir -ChildPath "boot\etfsboot.com"
    $EFIImage = Join-Path -Path $ISOFilesDir -ChildPath "efi\microsoft\boot\efisys.bin"

    if (-Not (Test-Path -Path $BootImage)) {
        Write-Error "Boot image not found at $BootImage"
        return
    }
    if (-Not (Test-Path -Path $EFIImage)) {
        Write-Error "EFI image not found at $EFIImage"
        return
    }

    try {
        & $OscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0, e, b"$BootImage"#pEF, e, b"$EFIImage" "$ISOFilesDir" "$OutputIsoPath"
        Write-Output "ISO file created successfully at $OutputIsoPath"
    }
    catch {
        Write-Error "Failed to create ISO file: $_"
        return
    }
}

# Parameters for the function call
$WimPath = "D:\VM\Setup\WIM\install.wim"
$IsoOutputPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-PPKG-Professional.ISO"
$WorkDir = "D:\VM\Setup\WorkDir"

# Splatting the parameters
$Params = @{
    WimPath       = $WimPath
    OutputIsoPath = $IsoOutputPath
    WorkDir       = $WorkDir
}

# Calling the function with splatting
Convert-WimToIso @Params

