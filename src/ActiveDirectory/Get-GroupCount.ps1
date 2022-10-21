#Requires -Version 3
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.2
    .GUID d4a6ec0d-d2a7-4aaf-818b-237ffc74703d

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, identity

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.2] - 2022-10-21 - Add SamAccountName to returned object
        [0.0.1] - 2022-10-21 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Determine number of groups the users are member of
    .DESCRIPTION
        Discover number of groups for the provided user accounts.  The groups list contains
        all the groups that are added to Access Token when user connects through network.
    .EXAMPLE
        Get-GroupCount.ps1 -Identity $env:USERNAME
        This example returns number of groups that currently logged on user belongs to
    .EXAMPLE
        Get-ADUser -filter {Name -like 'a*'} | Get-GroupCount.ps1
        This example finds the AD user accounts using Get-ADUser cmdlet and returns
        number of groups those users belong.
    .INPUTS
        AD User Account

    .OUTPUTS
        Collection of objects with user name, UPN and number of groups

    .NOTES
        The script initiates [Security.Principal.WindowsIdentity] and counts the number of Groups property members

    .LINK
        https://learn.microsoft.com/dotnet/api/System.Security.Principal.WindowsIdentity
#>

[CmdletBinding(
    DefaultParameterSetName = 'Identity'
)]
[OutputType([PSCustomObject])]

param (
        [Parameter(
            Mandatory,
            HelpMessage = 'Enter AD User object identity',
            ParameterSetName = 'Identity'
        )]
        [String]
        # Specifies an Active Directory user object by providing one of the following property values.
        #   * Distinguished Name
        #   * GUID (objectGUID)
        #   * Security Identifier (objectSid)
        #   * SAM account name  (sAMAccountName)
        #   * User Principal Name
    $Identity,
        [Parameter(
            ParameterSetName = 'PipeLine',
            ValueFromPipeline
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # The user account object
    $User
)

process {
    if ($PSCmdlet.ParameterSetName -like 'Identity') {
        $User = Get-ADUser -Identity $Identity
    }
    $WinIdentity = ([Security.Principal.WindowsIdentity] $User.UserPrincipalName)

    [PSCustomObject]@{
        Name              = $user.Name
        UserPrincipalName = $user.UserPrincipalName
        SamAccountName    = $user.SamAccountName
        GroupCount        = $WinIdentity.Groups.Count
    }
}
