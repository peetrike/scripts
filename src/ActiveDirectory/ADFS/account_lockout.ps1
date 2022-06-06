[CmdletBinding()]
param (
    [string[]]
    $Server = $env:COMPUTERNAME
)

$EventFilter = @{
    ProviderName = 'AD FS Auditing'
    ID           =  411
}
foreach ($_server in $Server) {
    Get-WinEvent -ComputerName $_server -FilterHashTable $EventFilter -Oldest -MaxEvents 100 |
        Where-Object { $_.properties[2].value -like '*The referenced account is currently locked out*' } |
        ForEach-Object {
            $_target_account = $_.Properties[2].Value
            $u, $detail, $junk = $_target_account.Split('-')
            $ObjProperties = @{
                Server  = $_server
                Time    = $_.TimeCreated
                Account = $u
                IP      = $_.Properties[4].Value
                Detail  = $detail
            }
            New-Object PSObject -Property $ObjProperties
        } | Out-GridView
}
