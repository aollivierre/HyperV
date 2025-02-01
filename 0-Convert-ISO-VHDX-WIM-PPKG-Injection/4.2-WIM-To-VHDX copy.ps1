#The following is generating a non-bootable VHDX

function New-VHDXFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VhdxPath,

        [Parameter(Mandatory=$true)]
        [uint64]$VhdxSize
    )

    # Check if the VHDX file already exists
    if (Test-Path -Path $VhdxPath) {
        Write-Host "VHDX file already exists, deleting it: $VhdxPath" -ForegroundColor Yellow
        Remove-Item -Path $VhdxPath -Force
    }

    # Create a new VHDX file
    Write-Host "Creating VHDX file: $VhdxPath" -ForegroundColor Cyan
    New-VHD -Path $VhdxPath -SizeBytes $VhdxSize -Dynamic | Out-Null
}

function Mount-VHDXFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VhdxPath
    )

    Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
    $disk = Mount-VHD -Path $VhdxPath -PassThru | Get-Disk

    if ($null -eq $disk) {
        throw "Failed to mount VHDX file: $VhdxPath"
    }

    $disk
}

function Initialize-PartitionVHDX {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.Management.Infrastructure.CimInstance]$Disk,
        
        [Parameter(Mandatory=$true)]
        [char]$DriveLetter
    )

    if ($Disk.PartitionStyle -eq 'RAW') {
        Write-Host "Initializing and formatting the disk" -ForegroundColor Cyan
        Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -PassThru -ErrorAction Stop | Out-Null
        Write-Host "Creating new partition" -ForegroundColor Cyan
        $partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter $DriveLetter -ErrorAction Stop
        Write-Host "Formatting the new partition" -ForegroundColor Cyan
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -ErrorAction Stop | Out-Null
    } else {
        Write-Host "Disk is already initialized, skipping initialization" -ForegroundColor Yellow
        $partition = Get-Partition -DiskNumber $Disk.Number | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object -First 1
    }

    if ($null -eq $partition) {
        throw "Failed to get the partition information"
    }

    $partition
}

function Apply-WIMImage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$WimPath,

        [Parameter(Mandatory=$true)]
        [int]$Index,

        [Parameter(Mandatory=$true)]
        [char]$DriveLetter
    )

    Write-Host "Applying WIM image to VHDX" -ForegroundColor Cyan
    & "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" /Apply-Image /ImageFile:$WimPath /Index:$Index /ApplyDir:$($DriveLetter + ":\") | Out-Null
}

function Dismount-VHDXFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VhdxPath
    )

    Write-Host "Dismounting VHDX file: $VhdxPath" -ForegroundColor Cyan
    Dismount-VHD -Path $VhdxPath
}

function Convert-WimToVhdx {
    param (
        [Parameter(Mandatory=$true)]
        [string]$WimPath,

        [Parameter(Mandatory=$true)]
        [string]$VhdxPath,

        [Parameter(Mandatory=$true)]
        [int]$Index,

        [Parameter(Mandatory=$true)]
        [uint64]$VhdxSize,

        [Parameter(Mandatory=$true)]
        [char]$DriveLetter
    )

    try {
        # Create VHDX file
        $vhdxParams = @{
            VhdxPath = $VhdxPath
            VhdxSize = $VhdxSize
        }
        New-VHDXFile @vhdxParams

        # Mount VHDX file
        $disk = Mount-VHDXFile -VhdxPath $VhdxPath

        # Initialize and partition VHDX
        $partitionParams = @{
            Disk = $disk
            DriveLetter = $DriveLetter
        }
        Initialize-PartitionVHDX @partitionParams

        # Apply WIM image to VHDX
        $wimParams = @{
            WimPath = $WimPath
            Index = $Index
            DriveLetter = $DriveLetter
        }
        Apply-WIMImage @wimParams

        # Dismount VHDX file
        Dismount-VHDXFile -VhdxPath $VhdxPath

        Write-Host "WIM has been successfully applied to the VHDX file" -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
        if (Test-Path -Path $VhdxPath) {
            Write-Host "Attempting to dismount the VHDX due to error." -ForegroundColor Yellow
            Dismount-VHDXFile -VhdxPath $VhdxPath -ErrorAction SilentlyContinue
        }
    }
}

# Example usage
$params = @{
    WimPath = "D:\VM\Setup\WIM\install.wim"
    VhdxPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-PPKG-Professional-v2.VHDX"
    Index = 1
    VhdxSize = 100GB
    DriveLetter = "Z"
}
Convert-WimToVhdx @params
