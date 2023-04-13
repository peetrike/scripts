#Requires -Version 3
#Requires -Modules ActiveDirectory

<#PSScriptInfo

    .VERSION 1.0.0
    .GUID 3ceb849d-0ba6-448a-91b6-6f5e89ead39d

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2023  All rights reserved.

    .TAGS ActiveDirectory, AD, user, account, import

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.0] - 2023.04.13 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Create AD users based on .CSV file
    .DESCRIPTION
        This script takes user account info from .CSV file and creates new user accounts.
        If ProxyAddresses property is present, it should have addresses separated
        by -ProxySeparator parameter value (by default + character).
        Script adds ProxyAddresses property to user accounts after creating users.

        It is also assumed, that .CSV file contains at least following properties:
            * GivenName
            * Surname
            * SamAccountName
    .EXAMPLE
        Import-ADUser -CsvPath users.csv
        This example creates new user account based on specified .csv file
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(Mandatory)]
        [ValidateScript({
            Test-Path -Path $_ -PathType Leaf
        })]
        [Alias('Path')]
        [String]
        # Specifies .CSV file path
    $CsvPath,
        [Alias('OU')]
        [string]
        # OU name to use for creating user accounts.
    $OrganizationalUnit,
        [string]
        # Character used to separate ProxyAddresses values
    $ProxySeparator = '+',
        [string]
        # The .CSV file delimiter
    $Delimiter = ';',
        [string]
        # The .CSV file encoding
    $Encoding = 'UTF8'
)

$CsvProps = @{
    Path      = $CsvPath
    Delimiter = $Delimiter
    Encoding  = $Encoding
}

$NewUserProps = @{
    Enabled = $true
}
if ($OrganizationalUnit) {
    $NewUserProps.Path = $OrganizationalUnit
    Write-Verbose -Message ('Adding users to: {0}' -f $OrganizationalUnit)
} else {
    Write-Verbose -Message ('Adding users to default location: {0}' -f (Get-ADDomain).UsersContainer)
}


foreach ($User in Import-Csv @CsvProps) {
    if (-not $user.Name) {
        $UserName = '{0} {1}' -f $User.GivenName, $User.Surname
        $User | Add-Member -MemberType NoteProperty -Name 'Name' -Value $UserName
    }
    if ($User.AccountPassword) {
        $User.AccountPassword = ConvertTo-SecureString -AsPlainText -Force -String $User.AccountPassword
    } else {
        $NewUserProps.Enabled = $false
    }
    if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Add new user')) {
        $ADAccount = $User |
            Select-Object * -ExcludeProperty ProxyAddresses |
            New-ADUser @NewUserProps -PassThru
        if ($User.ProxyAddresses) {
            $ProxyList = $User.proxyAddresses.Split($ProxySeparator)
            $ADAccount | Set-ADUser -Add @{ proxyAddresses = $ProxyList } -PassThru
        } else {
            $ADAccount
        }
    }
}
