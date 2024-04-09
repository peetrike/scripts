#Requires -Version 3
#Requires -Modules ActiveDirectory

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Mandatory
        )]
        [string]
    $GroupName
)

$list = Get-ADGroupMember -Identity $GroupName
$UserList = $list | Where-Object ObjectClass -EQ 'user'
$GroupList = $list | Where-Object ObjectClass -EQ 'group' | Get-ADGroup

foreach ($g in $GroupList) {
    Get-ADGroupMember -Identity $g -Recursive |
        Where-Object { $_.sid -in $UserList.sid } |
        ForEach-Object {
            $User = Get-ADUser -Identity $_
            if ($PSCmdlet.ShouldProcess($user, "Remove from group: $GroupName")) {
                Remove-ADGroupMember -Identity $GroupName -Members $User -WhatIf:$false -Confirm:$false
            }
        }
}
