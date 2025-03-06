#Requires -Version 2
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.4.1
    .GUID af691618-7b30-4bb3-8fa2-a4631c6b37c7

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2025.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, e-mail

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.4.1] - 2025-03-06 - Fix variable name when there is no default proxy addresses.
        [0.4.0] - 2024-07-26 - Don't replace entire list, instead remove old default and add new ones.
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
                $Message = 'Invalid domain name'
                $ParameterName = 'Domain'
                $Exception = New-Object -TypeName 'System.ArgumentException' -ArgumentList @(
                    $Message
                    $ParameterName
                )
                $ErrorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @(
                    $Exception
                    'InvalidDomainName'
                    [Management.Automation.ErrorCategory]::InvalidData
                    $_
                )
                $ErrorRecord.ErrorDetails = $Message
                $ErrorRecord.ErrorDetails.RecommendedAction = 'Please provide valid domain name'
                $ErrorRecord.CategoryInfo.TargetName = $ParameterName
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
        $MailAddress = $User.mail -as [mailaddress]
        if ($DefaultAddress -match '^SMTP:(.*@)') {
            $NewDefault = $Matches[1] + $Domain
        } elseif ($User.mail) {
            $NewDefault = '{0}@{1}' -f $MailAddress.User, $Domain
        } else {
            $Message = 'The user account "{0}" does not have default mail address' -f $User.UserPrincipalName
            $ErrorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @(
                [Management.Automation.RuntimeException] $Message
                'MissingEmailAddress'
                [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $User
            )
            $ErrorRecord.ErrorDetails = $Message
            $ErrorRecord.ErrorDetails.RecommendedAction = 'Add primary e-mail address for user'
            $ErrorRecord.CategoryInfo.TargetName = 'User account'

            $PSCmdlet.WriteError($ErrorRecord)
            continue
        }
        $NewList = @(
            'SMTP:' + $NewDefault
            $DefaultAddress -replace '^SMTP', 'smtp'
            'smtp:' + $MailAddress.Address
        )

            # make change
        if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Change default e-mail')) {
            $SetProps = @{
                Add          = @{ proxyAddresses = $NewList }
                EmailAddress = $NewDefault
            }
            if ($DefaultAddress) {
                $SetProps.Remove = @{ proxyAddresses = $DefaultAddress }
            }
            if ($FixUPN) {
                $SetProps.UserPrincipalName = $NewDefault
            }
            Set-ADUser -Identity $User @SetProps
        }
    }
}
