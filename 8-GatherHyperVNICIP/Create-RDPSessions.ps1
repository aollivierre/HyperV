# # Define the path to the CSV file containing host entries
# $hostEntriesFilePath = "C:\Windows\System32\drivers\etc\VM_Hosts_IPs.csv"

# # Import the host entries from the CSV file
# $hostEntriesData = Import-Csv -Path $hostEntriesFilePath

# # Print the imported data to verify its structure and contents
# Write-Host "Imported host entries data:" -ForegroundColor Yellow
# $hostEntriesData | Format-Table -AutoSize | Out-String | Write-Host

# Define the function to create RDP sessions
function Create-RDPSessions {
    param (
        [PSCustomObject[]]$hostEntries
    )

    # Ensure the module is imported
    if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
        Install-Module Devolutions.PowerShell -Scope CurrentUser
    }
    Import-Module Devolutions.PowerShell -ErrorAction Stop

    # Connect to the local data source
    $currentDataSource = Get-RDMDataSource -Name "Local Data Source"
    Set-RDMCurrentDataSource -DataSource $currentDataSource

    # Iterate through each host entry and create RDP sessions
    foreach ($entry in $hostEntries) {
        $ip = $entry.IPAddress
        $vmName = $entry.VMName
        $hostName = $entry.HostName
        $sessionName = "$vmName-RDP"

        # Check if the session already exists
        $existingSession = Get-RDMSession -Name $sessionName

        if ($existingSession) {
            Write-Host "RDP session already exists: $sessionName"
        } else {
            try {
                Write-Host "Creating a new RDP session: $sessionName"
                $session = New-RDMSession -Host $ip -Type "RDPConfigured" -Name $sessionName
                Set-RDMSession -Session $session -Refresh
                Update-RDMUI

                # Set additional session properties
                Set-RDMSessionUsername -ID $session.ID -Username $hostName
                # Assuming $hostName as username, replace with actual logic if different
                Set-RDMSessionDomain -ID $session.ID -Domain "domain" # Replace with actual domain
                $pass = ConvertTo-SecureString "password" -AsPlainText -Force # Replace with actual password
                Set-RDMSessionPassword -ID $session.ID -Password $pass

                Write-Host "New RDP session created: $($session.Name)"
            } catch {
                Write-Host "Error while creating the RDP session for $sessionName $_"
            }
        }
    }
}

# Call the function with the host entries
# Create-RDPSessions -hostEntries $hostEntriesData

# Verify the sessions were created
Write-Host "Verifying the new RDP sessions..."
foreach ($entry in $hostEntriesData) {
    $vmName = $entry.VMName
    $sessionName = "$vmName-RDP"
    $createdSession = Get-RDMSession -Name $sessionName

    if ($createdSession) {
        Write-Host "New RDP session verified: $($createdSession.Name)"
    } else {
        Write-Host "New RDP session not found for $sessionName. Verification failed."
    }
}
