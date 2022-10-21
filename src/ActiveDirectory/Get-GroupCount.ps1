#Requires -Version 5.1

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID d4a6ec0d-d2a7-4aaf-818b-237ffc74703d

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-10-21 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Determine number of groups the users are member of
    .DESCRIPTION
        Discover number of groups for the provided user accounts.  The list contains
        groups from Active Directory and from the computer where the script is started.
    .EXAMPLE
        Get-GroupCount.ps1 -Identity myUser
        This example finds the AD user account provided and returns number of groups that user belongs to
    .EXAMPLE
        Get-ADUser -filter [Name -like 'a*'} | Get-GroupCount.ps1
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
    DefaultParameterSetName = 'Parameter Set 1',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    HelpUri = 'http://www.microsoft.com/',
    ConfirmImpact = 'Medium'
)]
[OutputType([PSCustomObject])]

param (
        [Parameter(
            ParameterSetName = 'Identity'
        )]
        [String]
        # The user account identity
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
        GroupCount        = $WinIdentity.Groups.Count
    }
}
