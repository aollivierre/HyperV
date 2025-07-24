# SharedUtilities.psm1
# Contains shared utility functions used across all modules

function Handle-Error {
    <#
    .SYNOPSIS
        Handles and logs error information.
    
    .DESCRIPTION
        Provides consistent error handling across all modules.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    # Try to use Write-Error for module context
    Write-Error "ERROR: $($ErrorRecord.Exception.Message)"
    Write-Debug "Stack Trace: $($ErrorRecord.ScriptStackTrace)"
    Write-Debug "Error Details: $($ErrorRecord.ToString())"
    
    # Also write to host for immediate visibility
    Write-Host "ERROR: $($ErrorRecord.Exception.Message)" -ForegroundColor Red
}

# Export the function
Export-ModuleMember -Function 'Handle-Error'