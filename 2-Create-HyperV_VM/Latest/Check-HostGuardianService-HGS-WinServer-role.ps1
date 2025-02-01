# Check if Host Guardian Service Role is installed
$HgsFeature = Get-WindowsFeature -Name HostGuardianServiceRole

if ($HgsFeature.Installed) {
    Write-Host "Host Guardian Service Role is installed."
} else {
    Write-Host "Host Guardian Service Role is not installed."
}
