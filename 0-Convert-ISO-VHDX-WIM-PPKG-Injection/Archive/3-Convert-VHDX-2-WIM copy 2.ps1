# #first mount the vhdx file
# dism /capture-image /imagefile:D:\VM\Setup\WIM\install.wim /capturedir:H:\ /name:"Windows 11 Custom Image"


function Validate-VHDMount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    # Check if the VHDX is mounted
    $vhd = Get-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    if ($vhd -and $vhd.Attached) {
        Write-Host "VHDX is mounted: $VHDXPath" -ForegroundColor Green
        return $true
    } else {
        Write-Host "VHDX is not mounted: $VHDXPath" -ForegroundColor Red
        return $false
    }
}

function Capture-CustomImage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ImageFile,
        
        [Parameter(Mandatory=$true)]
        [string]$CaptureDir,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageName
    )

    try {
        Write-Output "Starting image capture..."
        
        # Run the DISM command
        $dismCommand = "/capture-image /imagefile:$ImageFile /capturedir:$CaptureDir /name:`"$ImageName`""
        Write-Output "Executing: dism.exe $dismCommand"
        $process = Start-Process -FilePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" -ArgumentList $dismCommand -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            throw "DISM command failed with exit code $($process.ExitCode)"
        }

        Write-Output "Image capture completed successfully."
    } catch {
        Write-Error "An error occurred: $_"
    }
}

function Mount-Capture-DismountVHD {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath,
        
        [Parameter(Mandatory = $true)]
        [string]$ImageFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ImageName
    )

    # Error handling
    try {
        Write-Host "Starting process to mount, capture, and dismount VHDX" -ForegroundColor Yellow

        # Validate if the VHDX is already mounted
        Write-Host "Validating initial mount state..." -ForegroundColor Cyan
        if (Validate-VHDMount -VHDXPath $VHDXPath) {
            throw "The VHDX file is already mounted. Please dismount it before proceeding."
        }

        # Mount the VHDX file
        Write-Host "Mounting VHDX file: $VHDXPath" -ForegroundColor Cyan
        $VHD = Mount-VHD -Path $VHDXPath -PassThru

        # Validate the mount
        Write-Host "Validating mount state after mounting..." -ForegroundColor Cyan
        if (-Not (Validate-VHDMount -VHDXPath $VHDXPath)) {
            throw "Failed to mount the VHDX file."
        }

        # Ensure the correct drive letter is H:
        $Volume = Get-Volume -DriveLetter H -ErrorAction SilentlyContinue
        if (-Not $Volume) {
            throw "Unable to find the H: drive. Ensure the VHDX file has the correct drive letter."
        }
        $DriveLetter = $Volume.DriveLetter

        # Construct the CaptureDir parameter correctly
        $CaptureDir = "${DriveLetter}:\"

        # Call the Capture-CustomImage function using splatting
        $params = @{
            ImageFile = $ImageFilePath
            CaptureDir = $CaptureDir
            ImageName = $ImageName
        }
        Capture-CustomImage @params

    } catch {
        Write-Error "An error occurred: $_"
    } finally {
        # Always attempt to dismount the VHDX
        try {
            Write-Host "Dismounting VHDX file: $VHDXPath" -ForegroundColor Cyan
            Dismount-VHD -Path $VHDXPath -ErrorAction Stop

            # Validate the dismount
            Write-Host "Validating mount state after dismounting..." -ForegroundColor Cyan
            if (Validate-VHDMount -VHDXPath $VHDXPath) {
                throw "Failed to dismount the VHDX file."
            }
        } catch {
            Write-Error "Failed to dismount the VHDX file: $_"
        }
    }
}

# Example usage:
$VHDXPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
$ImageFilePath = "D:\VM\Setup\WIM\install.wim"
$ImageName = "Windows 11 Custom Image"

Mount-Capture-DismountVHD -VHDXPath $VHDXPath -ImageFilePath $ImageFilePath -ImageName $ImageName
