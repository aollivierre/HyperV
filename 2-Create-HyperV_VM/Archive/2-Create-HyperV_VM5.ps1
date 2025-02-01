# Define parameters
param(
    [string]$VMNamePrefix = "Test-003",
    [string]$SwitchName = "VM LAN2",
    [string]$HgsGuardianName = "UntrustedGuardian"
    #[string]$InstallMediaPath = "D:\VM\Setup\ISO\Windows_10_22H2_Oct_29_2022.iso"
)

# Error handling
trap {
    Write-Error $_.Exception
    exit 1
}

# Validate HGS Guardian existence
function ValidateHgsGuardian {
    param(
        [string]$GuardianName
    )

    $guardian = Get-HgsGuardian -Name $GuardianName -ErrorAction SilentlyContinue
    if (-not $guardian) {
        throw "HGS Guardian '$GuardianName' not found. Please ensure it is configured correctly."
    }
    return $guardian
}

# Start necessary services
function Start-RequiredServices {
    "vmcompute", "vmms" | ForEach-Object {
        $service = Get-Service -Name $_
        if ($service.Status -ne "Running") {
            Start-Service $service
        }
    }
}

# Create VM function
function CreateVM {
    param(
        [string]$VMName,
        [string]$VMPath,
        [string]$SwitchName
    )

    $VMFullPath = Join-Path -Path $VMPath -ChildPath $VMName
    $VHDPath = Join-Path -Path $VMFullPath -ChildPath "$VMName.vhdx"

    New-Item -ItemType Directory -Force -Path $VMFullPath

    $NewVMSplat = @{
        Generation         = 2
        Path               = $VMFullPath
        Name               = $VMName
        NewVHDSizeBytes    = 30GB
        NewVHDPath         = $VHDPath
        MemoryStartupBytes = 2GB
        SwitchName         = $SwitchName
    }
    New-VM @NewVMSplat
}

# Main script execution
try {
    Start-RequiredServices

    $Datetime = [System.DateTime]::Now.ToString("dd-MM-yy_HH-mm-ss")
    $VMName = "$VMNamePrefix`_$Datetime"
    $VMPath = "D:\VM"

    $owner = ValidateHgsGuardian -GuardianName $HgsGuardianName

    CreateVM -VMName $VMName -VMPath $VMPath -SwitchName $SwitchName

    $ProcessorCount = 2
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -Count $ProcessorCount
    Set-VMMemory -VMName $VMName

    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
    Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData

    Enable-VMTPM -VMName $VMName
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

# Note: Uncomment and modify the sections related to DVD drive and installation media as needed.
