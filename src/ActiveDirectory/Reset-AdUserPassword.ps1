#Requires -Version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID f0106eee-49f9-421b-878e-7ebfd8c9c241

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS ActiveDirectory, AD, user, password, reset

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.2] - 2021.12.31 - Moved script to Github.
        [0.0.1] - 2021.01.16 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Reset AD user password to random one
    .DESCRIPTION
        This script resets given Active Directory user, service account or computer password
    .EXAMPLE
        Get-AdGroupMember -Id IT | Get-AdUser | Reset-AdUserPassword -PassThru

        This example takes group members and resets their passwords to random ones.  The result is piped to output.
    .EXAMPLE
        Get-AdUser -Filter {Name -like 'a*'} | Reset-AdUserPassword -ReportFile accounts.csv

        This example takes group members and resets their passwords to random ones.  The result is written to
        provided report file.
    .INPUTS
        Collection of AD User Accounts
    .OUTPUTS
        The collection of account and changed password, if -PassThru switch was used
    .NOTES
        The user running script requires Reset Password permission on all affected accounts
    .LINK
        Set-ADAccountPassword: https://docs.microsoft.com/powershell/module/activedirectory/set-adaccountpassword
#>

[CmdletBinding(
    SupportsShouldProcess=$true,
    ConfirmImpact='Medium'
)]

param (
        [Parameter(
            Mandatory = $True,
            Position = 0,
            HelpMessage = "Please enter AD user name",
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # Specifies an Active Directory user object to process.
    $ADUser,

        [Alias('Password')]
        [string]
        # New password to use during reset.
    $NewPassword,

        [switch]
        # Passes the changed password with user account information to pipeline.
    $PassThru,

        [string]
        # Specifies .csv file to use for results
    $ReportFile
)

begin {
    function Get-RandomString {
        # .EXTERNALHELP telia.common-help.xml
        [OutputType([string])]
        param(
                [int]
            $Length = 8,
                [char[]]
            $Number  = (48..57 | ForEach-Object { [char]$_ }),
                [char[]]
            $Letter  = (97..122 | ForEach-Object { [char]$_ }),
                [char[]]
            $Capital = (65..90 | ForEach-Object { [char]$_ }),
                [char[]]
            $Symbol  = (33, 35, 36, 37, 40, 41, 43, 45, 46, 58, 64 | ForEach-Object { [char]$_ })
        )

        [String] $Password = ''

        $Character = $Number + $Letter + $Capital + $Symbol
        $List = 'Number', 'Letter', 'Capital', 'Symbol' | Sort-Object { Get-Random }

        foreach ($l in $List) {
            $Value = Get-Variable $l -ValueOnly
            if ($Value) {
                $Password += Get-Random -InputObject $Value
            }
        }

        do {
            $Password += Get-Random -InputObject $Character
        }
        while ( $Password.Length -lt $Length )

        $Password
    }

    if (-not $NewPassword) {
        Write-Verbose -Message 'Using random password'
        $useRandomPassword = $true
    } else {
        $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $NewPassword
    }
    $ConfirmParam = @{
        WhatIf  = $false
        Confirm = $false
    }
}

process {
    if ($PSCmdlet.ShouldProcess($ADUser, "Reset user password")) {
        if ($useRandomPassword) {
            $NewPassword = Get-RandomString -Length 15
            $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $NewPassword
        }

        try {
            $ADUser | Set-ADAccountPassword -NewPassword $SecurePassword -Reset @ConfirmParam -ErrorAction Stop
            $result = [PSCustomObject]@{
                Name     = $ADUser.Name
                UPN      = $ADUser.UserPrincipalName
                Password = $NewPassword
            }

            if ($ReportFile) {
                $exportProps = @{
                    Path              = $ReportFile
                    Append            = $true
                    NoTypeInformation = $true
                }
                $result | Export-Csv @exportProps @ConfirmParam -UseCulture -Encoding Default
            }
            if ($PassThru.IsPresent) {
                $result
            }
        } catch {
            Write-Error -ErrorRecord $_
        }
    }
}
