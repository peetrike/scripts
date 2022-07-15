#Requires -Version 2
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID af691618-7b30-4bb3-8fa2-a4631c6b37c7

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, e-mail

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-07-15 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Add new e-mail domain to ProxyAddresses and make it default
    .DESCRIPTION
        This script constructs new e-mail address from current default in ProxyAddresses
        and adds it as a new default address.

    .EXAMPLE
        Add-DefaultProxy.ps1 -Identity username -Domain 'domain.com'

        Explanation of what the example does
    .EXAMPLE
        Get-AdUser -Filter {Name -like 'a*'} | Add-DefaultProxy.ps1 -Domain 'domain.com'

        This example takes Active Directory users from `Get-ADUser` cmdlet and
        adds new e-mail to them.
    .EXAMPLE
        Get-AdGroupMember -Id IT | Get-AdUser | Add-DefaultProxy.ps1 -Domain 'domain.com'

        This example takes group members and adds new e-mail address.

    .INPUTS
        Collection of ADUser objects
    .OUTPUTS
        Output (if any)

    .NOTES
        General notes

    .LINK
        Set-ADUSer: https://docs.microsoft.com/powershell/module/activedirectory/set-aduser
#>

[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'Medium'
)]
#[Alias('')]
[OutputType([void])]

param (
        [Parameter(
            Mandatory = $True,
            Position = 0,
            HelpMessage = 'Please enter AD user name',
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # Specifies an Active Directory user object to process.
    $Identity,

        [Parameter(
            Mandatory,
            HelpMessage = 'Please enter e-mail domain to add'
        )]
        [ValidateScript({
            if ($_ -match '^([\w-]+\.)+[\w-]+$') { $true }
            else { throw 'Please provide valid domain name' }
        })]
        [string]
        # e-mail domain suffix to be added
    $Domain
)

process {
    foreach ($User in Get-ADUser -Identity $Identity -Properties mail, proxyAddresses) {
        $ProxyList = $User.proxyAddresses
        $DefaultAddress = ($ProxyList -cmatch '^SMTP:')[0]      # -match returns array, if left side is array
        $NewDefault = $DefaultAddress -replace '@.*', ('@' + $Domain)
        $NewList = @(
            $NewDefault
            ($ProxyList | Where-Object { $_ -ne $NewDefault }) -replace '^SMTP', 'smtp'
        )

            # make change
        $SetProps = @{
            Replace      = @{ proxyAddresses = $NewList }
            EmailAddress = $NewDefault
        }
        Set-ADUser -Identity $User @SetProps
    }
}
