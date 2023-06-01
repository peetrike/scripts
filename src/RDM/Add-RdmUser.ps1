#Requires -Version 7
#Requires -Modules ActiveDirectory, Devolutions.PowerShell

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID a43c22d8-876b-4124-9c94-83e788f2500d

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS rdm, user

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktopManager, ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022.10.04 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Add AD user account to RDM Advanced Datastore
    .DESCRIPTION
        This script adds AD user account to RDM Advanced data source.
    .EXAMPLE
        Add-RdmUser -DataSource MyDB -User myUser

        This example adds new user to data source named MyDB
    .NOTES
        The script requires RDM module available from PowerShell Gallery.  That
        module requires that data sources are upgraded so that RDM v2021.2.x is
        able to connect to them.
    .LINK
        https://help.remotedesktopmanager.com/psmodule.html
#>

[CmdletBinding(
    SupportsShouldProcess
)]
[OutputType([PSCustomObject])]

param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # AD User account
    $User,
        [string]
        # RDM user role to add
    $Role,
        <# [ValidateScript({
            if ($_) {
                Get-RDMDataSource -Name $_
            }
        })] #>
        [string]
        # RDM Data Source to be used
    $DataSource,
        [switch]
        # add user and do not confirm
    $Force,
        [switch]
    $PassThru
)

begin {
    if ($DataSource) {
        Get-RDMDataSource -Name $DataSource | Set-RDMCurrentDataSource
        #Update-RDMRepository
        #Update-RDMUI
    } else {
        $DataSource = (Get-RDMCurrentDataSource -Verbose:$false).Name
    }
    Write-Verbose -Message ('Working with Data Source: {0}' -f $DataSource)

    $Domain = Get-ADDomain
}

process {
    $RdmUserName = '{0}\{1}' -f $domain.NetBIOSName, $user.SamAccountName

    try {
        Get-RDMUser -Name $RdmUserName
        Write-Warning -Message ('User: {0} already exists in datasource: {1}' -f $RdmUserName, $DataSource)
    } catch {
        $UserProps = @{
            Login                    = $RdmUserName
            IntegratedSecurity       = $true
            SkipCreateSQLServerLogin = $true
            Authentification         = 'SqlServer'
        }
        $RdmUser = New-RDMUser @UserProps
        $RdmUser.UserType = [Devolutions.RemoteDesktopManager.UserType]::User

        $RdmUser.FirstName = $User.GivenName
        $RdmUser.LastName = $User.Surname

        if (-not $User.Mail) {
            $user = Get-ADUser -Identity $user.SID -Properties mail
        }
        $RdmUser.Email = $user.Mail

        if ($Force -or $PSCmdlet.ShouldProcess($User.Name, 'Add user to RDM Data Source')) {
            Set-RDMUser -User $RdmUser

            if ($Role) {
                try {
                    $RoleObject = Get-RDMRole -Name $Role -ErrorAction Stop
                    Add-RDMRoleToUser -RoleObject $RoleObject -UserObject $RdmUser
                    Set-RDMUser -User $RdmUser
                } catch {
                    $ErrorProps = @{
                        Message  = "Can't find role: {0}, skipping Add Role" -f $Role
                        Category = 'InvalidArgument'
                    }
                    Write-Error @ErrorProps -ErrorAction Continue
                }
            }
        }
    }

    if ($PassThru) {
        Get-RDMUser -Name $RdmUserName
    }
}
