function AppendCSVLog {
    param (
        [string]$Message,
        [string]$CSVFilePath_1001
           
    )
    
    $csvData = [PSCustomObject]@{
        TimeStamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Message      = $Message
    }
    
    $csvData | Export-Csv -Path $CSVFilePath_1001 -Append -NoTypeInformation -Force
}