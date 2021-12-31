#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.2
    .GUID 5c09315d-fdec-4dfd-85e8-f8a61cf67a40

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS ActiveDirectory, AD, user

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2020.03.23 - fixed replace, when one or both properties are empty
        [1.0.1] - 2019.11.4 - changed commend-based-help
        [1.0.0] - 2019.11.1 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Switches values of two properties on given user accounts.

    .DESCRIPTION
        This script switches values of attributes on Active Directory User accounts.
        The accounts can be passed to script through pipeline or filtered using -Filter
        parameter.  The Filter parameter uses the PowerShell Expression Language to write
        query strings for Active Directory.

        If one of the user properties is multivalued (like otherTelephone),
        only the first property value is used for switching.

    .PARAMETER Confirm
        Prompts you for confirmation before making changes.

    .PARAMETER WhatIf
        Shows what would happen if the script runs. The changes are not run.

    .EXAMPLE
        PS C:\> Get-ADUser myAdmin | Switch-ADUserProperty -Property1 'homePhone' -Property2 'otherHomePhone'

        Switches phone attributes 'homePhone' and 'otherHomePhone' values on user 'myAdmin'.

    .EXAMPLE
        PS C:\> Switch-ADUserProperty -Filter * -SearchBase 'OU=Users,OU=company,DN=int,DN=company,DN=com'

        Switches default property values on all users from OU named 'Users'.

    .EXAMPLE
        PS C:\> Switch-ADUserProperty -Filter 'Name -like "Thomas*"' -Property1 'mobile' -Property2 'otherMobile'

        Switches property 'mobile' and 'otherMobile' values on users whose full name
        starts with 'Thomas'.

    .EXAMPLE
        PS C:\> Switch-ADUserProperty -Filter 'userPrincipalName -like "*@company.com" -PassThru

        Switches default property values on users whose UserPrincpalName ends with '@company.com'.
        Show all changed user accounts with switched phone attributes.

    .INPUTS
        None or Microsoft.ActiveDirectory.Management.ADUser

        A user object is received by the Identity parameter.

    .OUTPUTS
        None or Microsoft.ActiveDirectory.Management.ADUser

        Returns the modified user object when the PassThru parameter is specified.

    .NOTES
        You can switch any Active Directory User property value, provided that properties have
        value with same datatype.

        Please be sure that you enter property names correctly.

    .LINK
        About ActiveDirectory Filter: https://docs.microsoft.com/en-us/previous-versions/windows/powershell-scripting/dn910987(v=wps.630)

    .LINK
        Get-ADUser

    .LINK
        Set-ADUser
#>

[OutputType([Microsoft.ActiveDirectory.Management.ADUser])]
[CmdLetBinding(
    SupportsShouldProcess
)]
Param(
        [parameter(
            Mandatory,
            ParameterSetName = 'Identity',
            Position = 0,
            ValueFromPipeline
        )]
        [ValidateNotNull()]
        [Microsoft.ActiveDirectory.Management.ADUser]
    $Identity,
        [parameter(
            Mandatory,
            ParameterSetName = 'Filter',
            HelpMessage = "A filter, such as 'samAccountName -like `"Domain*`"', which is used to search the directory for matching groups."
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]
        # Specifies a query string that retrieves Active Directory objects.
        # This string uses the PowerShell Expression Language syntax.
    $Filter,
        [parameter(
            ParameterSetName = 'Filter'
        )]
        [ValidateNotNull()]
        [Alias('DistinguishedName', 'DN')]
        [string]
        # Specifies an Active Directory path to search under.
    $SearchBase,
        [parameter(
            ParameterSetName = 'Filter'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADSearchScope]
        [PSDefaultValue(Help = 'Subtree')]
        # Specifies the scope of an Active Directory search. Possible values are: Base, OneLevel, Subtree
    $SearchScope,
        [string]
        # Specifies the first property to use for value switching
    $Property1 = 'telephoneNumber',
        [string]
        # Specifies the second property to use for value switching.
    $Property2 = 'otherTelephone',
        [switch]
        # If specified, returns the modified User Account object.
    $PassThru
)

process {
    $UserProps = @{
        Properties = $Property1, $Property2
    }

    if ($PSCmdlet.ParameterSetName -eq 'Identity') {
        $UserProps.Identity = $Identity.SID
    } else {
        $UserProps.Filter = $Filter
        if ($SearchBase) {
            $UserProps.SearchBase = $SearchBase
        }
        if ($SearchScope) {
            $UserProps.SearchScope = $SearchScope
        }
    }

    foreach ($User in Get-ADUser @UserProps) {
    <# Get-ADUser @UserProps | ForEach-Object {
        $User = $_ #>
        Write-Verbose -Message ('Processing user: {0}' -f $User.samAccountName)
        if ($user.$Property1 -or $user.$Property2) {
            $SetProps = @{
                ID      = $User.SID
                Replace = @{ }
            }

            if ($User.$Property1) {
                $SetProps.Replace.$Property2 = $User.$Property1 | Select-Object -First 1
                if (-not $user.$Property2) {
                    $SetProps.Clear = $Property1
                }
            }
            if ($User.$Property2) {
                $SetProps.Replace.$Property1 = $User.$Property2 | Select-Object -First 1
                if (-not $user.$Property1) {
                    $SetProps.Clear = $Property2
                }
            }

            if ($PSCmdlet.ShouldProcess($user.samAccountName, "Switch property values")) {
                Set-ADUser @SetProps -Confirm:$false
                if ($PassThru.IsPresent) {
                    Get-ADUser $User.SID -Properties $Property1, $Property2
                }
            }
        }
    }
}
