#Requires -Version 5.1
#Requires -Modules RemoteDesktopManager, ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.2
    .GUID d9a680e6-c78c-42dd-a231-ce71e4842977

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS rdm, user

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktopManager, ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2021.10.06 - Changed RDM module name
        [1.0.1] - 2021.09.30 - Change user reference when trying to delete user
        [1.0.0] - 2021.06.01 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Update RDM user information

    .DESCRIPTION
        This script fills RDM user accounts with names and e-mail addresses.  It
        also removes non-existing and disabled user accounts from data source.

    .EXAMPLE
        Update-RdmUser -DataSource MyDB

        Checks the users in data source provided from command line

    .NOTES
        The script requires RDM module available from PowerShell Gallery.  That
        module requires that data sources are upgraded so that RDM v2021.2.x is
        able to connect to them.
    .LINK
        https://help.remotedesktopmanager.com/psmodule.html
#>

[CmdletBinding(
    SupportsShouldProcess=$true
)]
[OutputType([PSCustomObject])]

param (
        [ValidateScript( {
            Get-RDMDataSource -Name $_
        })]
        [string]
        # RDM Data Source to be used
    $DataSource = (Get-RDMCurrentDataSource).Name
)

if ($DataSource) {
    Get-RDMDataSource -Name $DataSource | Set-RDMCurrentDataSource
    #Update-RDMRepository
    Update-RDMUI
}

Write-Verbose -Message ('Working with Data Source: {0}' -f $DataSource)

foreach ($user in Get-RDMUser) {
    $needsUpdate = $false
    $notExist = $false
    try {
        $AdUSer = Get-ADUser -Identity $user.Name.Split('\')[-1] -Properties mail
        if (-not $AdUSer.Enabled) {
            $notExist = $true
        }
    } catch {
        $notExist = $true
    }
    $Name = '{0} ({1})' -f $user.Description, $user.Name
    if ($notExist -and $PSCmdlet.ShouldProcess($Name, 'Remove user from database')) {
        Remove-RDMUser -ID $user.ID -DeleteSQLLogin
    } else {
        if (-not $user.FirstName) {
            $needsUpdate = $true
            $user.FirstName = $AdUSer.GivenName
        }
        if (-not $user.LastName) {
            $needsUpdate = $true
            $user.LastName = $AdUSer.Surname
        }
        if (-not $user.Email) {
            $needsUpdate = $true
            $user.Email = $AdUSer.mail
        }
        if ($needsUpdate -and $PSCmdlet.ShouldProcess($user.name, 'Update user')) {
            Set-RDMUser -User $user
        }
    }
}
