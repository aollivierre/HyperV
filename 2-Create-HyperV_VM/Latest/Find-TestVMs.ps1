Get-VM | Where-Object { 
    $_.Name -match 'TEST|test|Dual|dual|Auto|AUTO' 
} | Select-Object Name, State | Format-Table -AutoSize