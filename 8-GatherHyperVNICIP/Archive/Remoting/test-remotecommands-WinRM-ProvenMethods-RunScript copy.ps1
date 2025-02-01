function Execute-RemoteScript {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Local script path
    $localScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"

    # Read the content of the local script
    $scriptContent = Get-Content -Path $localScriptPath -Raw

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock {
        param ($scriptContent)
        Invoke-Expression $scriptContent
    } -ArgumentList $scriptContent
    Write-Host "Method 1: Invoke-Command - End"
}

# Main script
Execute-RemoteScript -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
