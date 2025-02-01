function Convert-WimToVhdx {
    [CmdletBinding()]
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
        # Check if the VHDX file already exists
        if (Test-Path -Path $VhdxPath) {
            Write-Host "VHDX file already exists, deleting it: $VhdxPath" -ForegroundColor Yellow
            Remove-Item -Path $VhdxPath -Force
        }

        # Create a new VHDX file
        Write-Host "Creating VHDX file: $VhdxPath" -ForegroundColor Cyan
        New-VHD -Path $VhdxPath -SizeBytes $VhdxSize -Dynamic | Out-Null

        # Mount the VHDX file
        Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        $disk = Mount-VHD -Path $VhdxPath -PassThru | Get-Disk

        if ($null -eq $disk) {
            throw "Failed to mount VHDX file: $VhdxPath"
        }

        # Output disk information for debugging
        Write-Host "Disk information after mounting:" -ForegroundColor Cyan
        $disk | Format-List -Property *

        # Initialize the disk if not already initialized
        if ($disk.PartitionStyle -eq 'RAW') {
            Write-Host "Initializing and formatting the disk" -ForegroundColor Cyan
            Initialize-Disk -Number $disk.Number -PartitionStyle MBR -PassThru -ErrorAction Stop | Out-Null
            Write-Host "Creating new partition" -ForegroundColor Cyan
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $DriveLetter -ErrorAction Stop
            Write-Host "Formatting the new partition" -ForegroundColor Cyan
            Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -ErrorAction Stop | Out-Null
        } else {
            Write-Host "Disk is already initialized, skipping initialization" -ForegroundColor Yellow
            $partition = Get-Partition -DiskNumber $disk.Number | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object -First 1
        }

        if ($null -eq $partition) {
            throw "Failed to get the partition information"
        }

        # Apply the WIM image to the VHDX
        Write-Host "Applying WIM image to VHDX" -ForegroundColor Cyan
        dism.exe /Apply-Image /ImageFile:$WimPath /Index:$Index /ApplyDir:$($DriveLetter + ":\") | Out-Null

        # Dismount the VHDX file
        Write-Host "Dismounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        Dismount-VHD -Path $VhdxPath

        Write-Host "WIM has been successfully applied to the VHDX file" -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
        if (Test-Path -Path $VhdxPath) {
            Write-Host "Attempting to dismount the VHDX due to error." -ForegroundColor Yellow
            Dismount-VHD -Path $VhdxPath -ErrorAction SilentlyContinue
        }
    }
}

# Example usage
Convert-WimToVhdx -WimPath "D:\VM\Setup\WIM\install.wim" `
                  -VhdxPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-PPKG-Professional.VHDX" `
                  -Index 1 `
                  -VhdxSize 100GB `
                  -DriveLetter "Z"
