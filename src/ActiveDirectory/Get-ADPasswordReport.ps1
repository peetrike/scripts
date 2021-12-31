#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.5

    .GUID 0c74c504-8341-4a2c-b89b-8993b6bac6f5

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, password, report

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.5] - 2021.12.31 - Moved script to Github.
        [1.0.4] - 2020.11.24 - Renamed ExpiryDate column to PasswordExpiryDate
        [1.0.3] - 2020.11.24 - Added CannotChangePassword, LastLogonDate to report
        [1.0.2] - 2020.05.21 - Don't return ExpiryDate, if password hasn't set or password never expires.
        [1.0.1] - 2020.05.21 - added LogonCount to report.
        [1.0.0] - 2020.05.20 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Compiles Password expiration report
    .DESCRIPTION
        This script generates password expiration report for AD users.
        The result is saved as .csv file.  The report file name is current AD domain name or OU name
        when -SearchBase parameter was used.

    .EXAMPLE
        Get-ADPasswordReport -Filter {Name -like 'one*'} -SearchBase 'OU=Employees,DC=example,DC=com'

        This command finds all users that have name starting with 'one' in OU Employees and reports their password
        status.
    .EXAMPLE
        Get-ADOrganizationalUnit -Identity 'OU=Employees,DC=example,DC=com' | Get-ADPasswordReport

        This command finds all users from OU Employees and reports their password status.
    .EXAMPLE
        Get-ADPasswordReport -ReportPath c:\reports

        This command finds all users from current AD domain and reports their password.  The report is saved in
        c:\reports folder.

    .LINK
        Get-ADUser https://docs.microsoft.com/powershell/module/activedirectory/get-aduser

#>

[CmdletBinding()]
Param(
        [parameter(
            HelpMessage = "A filter, such as 'samAccountName -like `"Domain*`"', which is used to search the directory for matching users."
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        # Specifies a query string that retrieves Active Directory objects.
    $Filter = '*',
        [parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNull()]
        [Alias('DistinguishedName', 'DN')]
        [string]
        # Specifies an Active Directory path to search under.
    $SearchBase,
        [ValidateNotNullOrEmpty()]
        [PSDefaultValue(Help = 'Subtree')]
        [Microsoft.ActiveDirectory.Management.ADSearchScope]
        # Specifies the scope of an Active Directory search. Possible values are: Base, OneLevel, Subtree
    $SearchScope,
        [ValidateScript( {
            Test-Path -Path $_ -PathType Container
        } )]
        [PSDefaultValue(Help = 'Current working directory')]
        [Alias('Path')]
        [string]
        # Specifies the folder, where report .CSV should be saved.  Default value is current directory.
    $ReportPath = $PWD
)

begin {
    $AdProperties = @(
        'DisplayName'
        'CannotChangePassword'
        'LastLogonDate'
        'LogonCount'
        'PasswordExpired'
        'PasswordNeverExpires'
        'PasswordLastSet'
        'msDS-UserPasswordExpiryTimeComputed'
    )
    $UserProps = @{
        Filter     = $Filter
        Properties = $AdProperties
    }
    if ($SearchScope) {
        $UserProps.SearchScope = $SearchScope
    }

    $CsvProps = @{
        UseCulture        = $true
        Encoding          = 'Default'
        NoTypeInformation = $true
    }

    $expiryDate = @{
        Name       = 'PasswordExpiryDate'
        Expression = {
            $value = $_."msDS-UserPasswordExpiryTimeComputed"
            if ($value -and ($value -lt [datetime]::MaxValue.ToFileTime())) {
                [datetime]::FromFileTime($value)
            }
        }
    }
    $SelectProperties = (
        $AdProperties | Select-Object -First ($AdProperties.count -1)
    ) + 'UserPrincipalName', $expiryDate
}

process {
    if ($SearchBase) {
        $UserProps.SearchBase = $SearchBase
        $CsvName = (Get-ADOrganizationalUnit $SearchBase).Name
    } else {
        $CsvName = (Get-ADDomain).DnsRoot
    }

    $CsvProps.Path = Join-Path -Path $ReportPath -ChildPath ('{0}.csv' -f $CsvName)

    Get-ADUser @UserProps |
        Select-Object $SelectProperties |
        Export-Csv @CsvProps
}
