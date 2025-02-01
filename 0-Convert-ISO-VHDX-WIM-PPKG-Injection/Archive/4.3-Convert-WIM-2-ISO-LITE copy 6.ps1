# The following script will convert a WIM file to an ISO file using DISM

function Convert-WimToIso {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseImagePath,

        [Parameter(Mandatory=$true)]
        [string[]]$AdditionalImagesPaths,

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

# Parameters for the function call
$WimPath = "D:\VM\Setup\WIM\install.wim"
$IsoOutputPath = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-PPKG-Professional.ISO"

# Splatting the parameters
$Params = @{
    BaseImagePath = "D:\VM\Setup\BaseImage"
    AdditionalImagesPaths = @("D:\VM\Setup\AdditionalImages\Image1", "D:\VM\Setup\AdditionalImages\Image2")
    OutputIsoPath = $IsoOutputPath
    WorkDir = "D:\VM\Setup\WorkDir"
}

# Calling the function with splatting
Convert-WimToIso @Params
