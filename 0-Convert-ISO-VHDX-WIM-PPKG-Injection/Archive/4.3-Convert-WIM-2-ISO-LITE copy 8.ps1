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
    Copy-Item -Path (Split-Path -Path $WimPath -Parent) -Destination $ISOFilesDir -Recurse -Force

    # Step 2: Create base WIM image
    $BaseWimFile = Join-Path -Path $ISOFilesDir -ChildPath "sources\install.wim"
    $DestinationWimFile = Join-Path -Path $WIMDir -ChildPath "install.wim"
    $BaseWimIndex = 1  # Modify this based on your base image index
    Write-Output "Creating base WIM image..."
    dism /Export-Image /SourceImageFile:$WimPath /SourceIndex:$BaseWimIndex /DestinationImageFile:$DestinationWimFile /DestinationName:"Base Image"

    # Step 3: Replace the original WIM file with the new WIM
    Write-Output "Replacing original WIM with the new WIM..."
    Copy-Item -Path $DestinationWimFile -Destination $BaseWimFile -Force

    # Step 4: Create the ISO file
    Write-Output "Creating ISO file..."
    $OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    $BootImage = Join-Path -Path $ISOFilesDir -ChildPath "boot\etfsboot.com"
    $EFIImage = Join-Path -Path $ISOFilesDir -ChildPath "efi\microsoft\boot\efisys.bin"
    & $OscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0, e, b"$BootImage"#pEF, e, b"$EFIImage" "$ISOFilesDir" "$OutputIsoPath"

    Write-Output "ISO file created successfully at $OutputIsoPath"
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

