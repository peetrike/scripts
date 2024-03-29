[CmdletBinding()]
param (
        [string]
        # Define all your ADFS servers
    $Server = $env:COMPUTERNAME
)

#XML filter to look for the event 4625
$EventFilter = @{
    FilterXPath = '*[System[Provider[@Name="Microsoft-Windows-Security-Auditing"] and Task = 12546 and EventID=4625]]'
    LogName     = 'Security'
    Oldest      = $true
    MaxEvents   = 100
}

#List all locked out event on all servers
$_pick_one = foreach ($_server in $Server) {
    #List all the event 4625
    Get-WinEvent -ComputerName $_server @EventFilter -ea SilentlyContinue |
        ForEach-Object {
            #We check what is the username input
            if ($_.Properties[6].Value) {
                $_target_account = '{0}\{1}' -f $_.Properties[6].Value, $_.Properties[5].Value
            } else {
                $_target_account = $_.Properties[5].Value
            }
            New-Object -TypeName psobject -Property @{
                Server  = $_server
                Time    = $_.TimeCreated
                Account = $_target_account
            }
        }
}

#Ask the user to chose (here we need to do some parsing of the input, it is not done as today
$_picked = $_pick_one | Out-GridView -OutputMode Single

if ($_picked) {
    $_xml_account = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[ EventData[ Data and (Data='$($_picked.Account)-The referenced account is currently locked out and may not be logged on to') ] ]</Select></Query></QueryList>"
    $_get_operation = Get-WinEvent -MaxEvents 1 -ComputerName $_picked.Server -FilterXml $_xml_account
    $_operation_id = $_get_operation.Properties[0].Value

    #Look for event 410 and 403 containing the same Activity ID than the lokout event
    #thanks Renato for helping me out here 🙂
    $_xml_operation = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[ EventData[ Data and (Data='$_operation_id') ] ] and *[System[(EventID=410) or (EventID=403)]]</Select></Query></QueryList>"
    $_get_info = Get-WinEvent -ComputerName $_picked.Server -FilterXml $_xml_operation
    #Display the results
    $_get_info | ForEach-Object {
        If ( $_.ID -eq 410 ) {
            Write-Output "DateTime: `t$($_picked.Time)"
            Write-Output "Server:   `t$($_picked.Server)"
            Write-Output "Account:  `t$($_picked.Account)"
            Write-Output "ExternalIP:`t$($_.Properties[10].Value)"
            Write-Output "WAPServer: `t$($_.Properties[12].Value)"
        }
        If ( $_.ID -eq 403 ) {
            Write-Output "UserAgent:`t$($_.Properties[8].Value)"
            Write-Output "InternalIP:`t$($_.Properties[2].Value)"
        }
    }
}
