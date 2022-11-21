#Requires -Version 5.1

<#PSScriptInfo
    .VERSION 0.1.0
    .GUID 7851aa67-806f-4bf1-8f11-ef343c1f4d88

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS office365 exchange calendar sharing

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-11-17 - Initial release
        [0.1.0] - 2022-11-21 - Add -Operation parameter

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Changes calendar folder permissions for provided mailboxes
    .DESCRIPTION
        This script changes calendar folder permissions (sharing) for provided mailboxes
    .EXAMPLE
        Get-Mailbox -OrganizationalUnit Users | Set-CalendarPermission.ps1 -User Bertha -AccessLevel Reviewer
        Explanation of what the example does
    .EXAMPLE
        Set-CalendarPermission.ps1 -Identity Allan -User 'Office Assistants' -AccessLevel LimitedDetails
        Explanation of what the example does
    .INPUTS
        List of mailbox objects to change
    .NOTES
        General notes
    .LINK
        https://learn.microsoft.com/powershell/module/exchange/add-mailboxfolderpermission
    .LINK
        https://learn.microsoft.com/powershell/module/exchange/remove-mailboxfolderpermission
    .LINK
        https://learn.microsoft.com/powershell/module/exchange/set-mailboxfolderpermission
#>

[CmdletBinding(
    SupportsShouldProcess
)]
[OutputType([void])]

param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [string]
        # The Identity parameter specifies the mailbox you want to view.
    $Identity,

        [Parameter(Mandatory)]
        [ValidateScript({
            Get-Recipient -Identity $_
        })]
        [string]
        # The User parameter specifies the mailbox, mail user, or mail-enabled security group
        # (security principal) that's granted permission to the mailbox folder.
    $User,

        [Parameter(Mandatory)]
        [ValidateSet(
            'None',
            'AvailabilityOnly',
            'LimitedDetails',
            'Reviewer'
        )]
        [string]
        # The AccessRights parameter specifies the permissions that you want to modify.
        # The values that you specify replace the existing permissions for the user on the folder.
    $AccessRight,

        [ValidateSet(
            'Add',
            'Change',
            'Remove'
        )]
        [String]
        # The permission operation
    $Operation = 'Change',

        [string[]]
        # Specifies known calendar folder names
    $KnownName = @(
        'Calendar'
        'Kalendarz'
        'Kalendārs'
        'Kalender'
        'Kalendorius'
    )
)

process {
    [array] $CalendarList = Get-MailboxFolderStatistics -Identity $Identity -FolderScope calendar |
        Where-Object Name -In $KnownName
    if ($CalendarList.Count -eq 1) {
        $FolderIdentity = '{0}:\{1}' -f $Identity, $CalendarList[0].Name
        switch ($Operation) {
            'Add' {
                $PermCommand = Get-Command Add-MailboxFolderPermission
                $PermProps = @{
                    Identity     = $FolderIdentity
                    User         = $User
                    AccessRights = $AccessRight
                }
                $ShouldProcessMessage = 'Add permission on'
            }
            'Change' {
                $PermCommand = Get-Command Set-MailboxFolderPermission
                $PermProps = @{
                    Identity     = $FolderIdentity
                    User         = $User
                    AccessRights = $AccessRight
                }
                $ShouldProcessMessage = 'Change permission on'
            }
            'Remove' {
                $PermCommand = Get-Command Remove-MailboxFolderPermission
                $PermProps = @{
                    Identity = $FolderIdentity
                    User     = $User
                }
                $ShouldProcessMessage = 'Remove permission on'
            }
        }
        if ($PSCmdlet.ShouldProcess($FolderIdentity, $ShouldProcessMessage)) {
            & $PermCommand @PermProps
        }
    } else {
        Write-Warning -Message ('Mailbox {0} has {1} calendar folders, skipping' -f $Identity, $CalendarList.Count)
    }
}
