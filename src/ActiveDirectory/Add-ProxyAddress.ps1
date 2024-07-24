#Requires -Version 2
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID feb5f118-5458-4cc1-bbe8-8544a479a321

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2024  All rights reserved.

    .TAGS ActiveDirectory, AD, user, e-mail

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2024-07-24 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Add new e-mail address with new domain to ProxyAddresses
    .DESCRIPTION
        This script constructs new e-mail address from current default in ProxyAddresses
        and adds it as a new address.
    .EXAMPLE
        Add-ProxyAddress.ps1 -Identity username -Domain 'domain.com'

        Adds new e-mail address with specified domain
    .EXAMPLE
        Get-AdUser -Filter {Name -like 'a*'} | Add-ProxyAddress.ps1 -Domain 'domain.com'

        This example takes Active Directory users from `Get-ADUser` cmdlet and
        adds new e-mail to them.
    .EXAMPLE
        Get-AdGroupMember -Id IT | Get-AdUser | Add-ProxyAddress.ps1 -Domain 'domain.com'

        This example takes group members and adds new e-mail address.
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
    $Domain
)

process {
    foreach ($User in Get-ADUser -Identity $Identity -Properties mail, proxyAddresses) {
        $ProxyList = $User.proxyAddresses
        $DefaultAddress = ($ProxyList -cmatch '^SMTP:')[0]      # -match returns array, if left side is array
        if ($DefaultAddress -match '^SMTP:(.*@)') {
            $NewAddress = $Matches[1] + $Domain
        } elseif ($User.mail) {
            $NewAddress = ($User.mail -replace '@.*', ('@' + $Domain))
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
            $ProxyList
            'smtp:' + $NewDefault
        )
        if (-not ($NewList -match $user.mail)) {
            $NewList += 'smtp:' + $user.mail
        }

            # make change
        if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Change default e-mail')) {
            $SetProps = @{
                Replace = @{ proxyAddresses = $NewList }
            }
            Set-ADUser -Identity $User @SetProps
        }
    }
}
