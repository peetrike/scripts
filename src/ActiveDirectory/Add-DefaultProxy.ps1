#Requires -Version 2
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.3.3
    .GUID af691618-7b30-4bb3-8fa2-a4631c6b37c7

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2023.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, e-mail

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.3.3] - 2023-10-12 - Ensure that proxy addresses are unique.
        [0.3.2] - 2023-10-11 - Add previous mail address to proxy addresses.
        [0.3.1] - 2023-10-05 - Add -WhatIf/-Confirm support.
        [0.3.0] - 2023-10-05 - Add ability to change UPN with default e-mail address.
        [0.2.0] - 2022-07-20 - Use mail property when no Default proxy e-mail address exists.
        [0.1.0] - 2022-07-15 - Emit error when no Default proxy e-mail address exists.
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
        Get-AdGroupMember -Id IT | Get-AdUser | Add-DefaultProxy.ps1 -Domain 'domain.com' -FixUpn

        This example takes group members, adds new e-mail address and changes UPN.
    .INPUTS
        Collection of ADUser objects
    .OUTPUTS
        Output (if any)
    .LINK
        Set-ADUSer: https://learn.microsoft.com/powershell/module/activedirectory/set-aduser
#>

[CmdletBinding(
    SupportsShouldProcess = $true
)]
#[OutputType([void])]

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
            Mandatory = $True,
            HelpMessage = 'Please enter e-mail domain to add'
        )]
        [ValidateScript({
            if ($_ -match '^([\w-]+\.)+[\w-]+$') { $true }
            else {
                $Exception = New-Object -TypeName 'System.ArgumentException' -ArgumentList @(
                    'Please provide valid domain name'
                    'Domain'
                )
                $ErrorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @(
                    $Exception
                    'InvalidDomainName'
                    [Management.Automation.ErrorCategory]::InvalidData
                    $_
                )
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        })]
        [string]
        # e-mail domain suffix to be added
    $Domain,

        [Alias('UPN')]
        [switch]
        # Change UserPrincipalName with default e-mail
    $FixUpn
)

process {
    foreach ($User in Get-ADUser -Identity $Identity -Properties mail, proxyAddresses) {
        $ProxyList = $User.proxyAddresses
        $DefaultAddress = ($ProxyList -cmatch '^SMTP:')[0]      # -match returns array, if left side is array
        if ($DefaultAddress -match '^SMTP:(.*@)') {
            $NewDefault = $Matches[1] + $Domain
        } elseif ($User.mail) {
            $NewDefault = ($User.mail -replace '@.*', ('@' + $Domain))
        } else {
            $ErrorProps = @{
                Message            =
                    'The user account "{0}" does not have default mail address' -f $User.UserPrincipalName
                Category           = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                ErrorId            = 'MissingEmailAddress'
                TargetObject       = $User
                RecommendedAction  = 'Add primary e-mail address for user'
                #CategoryActivity   = $CategoryActivity
                CategoryTargetName = 'User account'
                CategoryTargetType = $User.GetType()
            }
            Write-Error @ErrorProps
            continue
        }
        $NewList = @(
            'SMTP:' + $NewDefault
            ($ProxyList | Where-Object { $_ -notlike "*$NewDefault" }) -replace '^SMTP', 'smtp'
        )
        if (-not ($NewList -match $user.mail)) {
            $NewList += 'smtp:' + $user.mail
        }

            # make change
        if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Change default e-mail')) {
            $SetProps = @{
                Replace      = @{ proxyAddresses = $NewList }
                EmailAddress = $NewDefault
            }
            if ($FixUPN) {
                $SetProps.UserPrincipalName = $NewDefault
            }
            Set-ADUser -Identity $User @SetProps
        }
    }
}
