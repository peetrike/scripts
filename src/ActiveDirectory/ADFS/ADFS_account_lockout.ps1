#Define all your ADFS servers
$_all_adfs_servers = "ADFS.sm.local"
#XML filter to look for the event 4625
$_xml_lockout = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and Task = 12546 and (EventID=4625)]]</Select></Query></QueryList>"
#Pick one is used to store the user's input
$_pick_one = @()
#List all locked out event on all servers
$_all_adfs_servers | ForEach-Object `
{
    $_server = $_   
    #List all the event 4625
    Get-WinEvent -ComputerName $_server -FilterXml $_xml_lockout -Oldest -MaxEvents 100 | ForEach-Object `
    {
        #We check what is the username input
        If ( $_.Properties[6].Value -ne "" )
        {
            $_target_account = "$($_.Properties[6].Value)\$($_.Properties[5].Value)"
        } Else {
            $_target_account = $_.Properties[5].Value
        }
        $_pick_one += New-Object -TypeName psobject -Property @{
            Server = $_server
            Time = $_.TimeCreated
            Account = $_target_account
        }
    }
}
#Display all the results
$_inc = 0
$_pick_one | ForEach-Object `
{
    $_display_cases = $_pick_one[ $_inc ]
    Write-Host "$_inc`t-`t$($_display_cases.Server)`t$($_display_cases.Time)`t$($_display_cases.Account)"
    $_inc++
}
#Ask the user to chose (here we need to do some parsing of the input, it is not done as today
$_picked_inc = Read-Host "Select a lockout event (from 0 to $($_inc - 1))"
#Once we picked, we look at the info of the lockout using the right username and get the operation ID
$_picked = $_pick_one[ $_picked_inc ]
$_xml_account = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[ EventData[ Data and (Data='$($_picked.Account)-The referenced account is currently locked out and may not be logged on to') ] ]</Select></Query></QueryList>"
$_get_operation = Get-WinEvent `
    -MaxEvents 1 `
    -ComputerName $_picked.Server `
    -FilterXml $_xml_account
$_operation_id = $_get_operation.Properties[0].Value
#Look for event 410 and 403 containing the same Activity ID than the lokout event #thanks Renato for helping me out here 🙂
$_xml_operation = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[ EventData[ Data and (Data='$_operation_id') ] ] and *[System[(EventID=410) or (EventID=403)]]</Select></Query></QueryList>"
$_get_info = Get-WinEvent `
    -ComputerName $_picked.Server `
    -FilterXml $_xml_operation
#Display the results
$_get_info | ForEach-Object `
{
    If ( $_.ID -eq 410 )
    {
        Write-Output "DateTime: `t$($_picked.Time)"
        Write-Output "Server:   `t$($_picked.Server)"
        Write-Output "Account:  `t$($_picked.Account)"
        Write-Output "ExternalIP:`t$($_.Properties[10].Value)"
        Write-Output "WAPServer: `t$($_.Properties[12].Value)"
    }
    If ( $_.ID -eq 403 )
    {
        Write-Output "UserAgent:`t$($_.Properties[8].Value)"
        Write-Output "InternalIP:`t$($_.Properties[2].Value)"
    }
}