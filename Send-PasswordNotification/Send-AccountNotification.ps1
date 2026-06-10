#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.2
    .GUID 616f40c2-2629-4b1e-bc1c-25707f1c31ce

    .AUTHOR Peter Wawa
    .COMPANYNAME !ZUM!
    .COPYRIGHT (c) 2026 Peter Wawa.  All rights reserved.

    .TAGS e-mail email notification Windows PSEdition_Desktop PSEdition_Core

    .LICENSEURI https://github.com/peetrike/scripts/blob/main/LICENSE
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.2] 2026.06.10 - Add 0 as valid value for DaysBefore parameter.
        [0.0.1] 2026.06.10 - Initial version

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Send e-mail about AD account expiration
    .DESCRIPTION
        Send e-mail notification about AD account expiration in near future
    .PARAMETER WhatIf
        Shows what would happen if the script runs.
        The script is not run.
    .PARAMETER Confirm
        Prompts you for confirmation before sending out e-mail messages
    .EXAMPLE
        Send-AccountNotification.ps1 -DaysBefore 5,1

        Sends e-mail to users, whose account expires within 5 or 1 days.
    .EXAMPLE
        Send-AccountNotification.ps1 7 -ConfigFile my.config

        Sends notification 7 days before account expires.  Uses custom configuration file.
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        The script requires a config file.  You can download sample config file from
        https://github.com/peetrike/scripts/blob/main/Send-PasswordNotification/Send-AccountNotification.config
    .LINK
        about_ActiveDirectory
    .LINK
        Send-MailMessage
#>

[CmdletBinding(
    SupportsShouldProcess,
    DefaultParameterSetName = 'Action'
)]
[OutputType([PSCustomObject])]
param (
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = 'Specify number of days before account expiration',
            ParameterSetName = 'Action'
        )]
        [int[]]
        # Number of days before account expiration, when to send warning.  Can contain more than one number.
    $DaysBefore,
        [Parameter(
            ParameterSetName = 'Action'
        )]
        [ValidateScript( {
            if (Test-Path -Path $_ -PathType Leaf) { $true }
            else {
                throw 'Config file not found'
            }
        })]
        [PSDefaultValue(Help = '<scriptname>.config in the same folder as script')]
        [string]
        # Configuration file to read.  By default the config file is
        # in the same directory as script and has the same name with .config extension.
    $ConfigFile = $(Join-Path -Path $PSScriptRoot -ChildPath ((Get-Item $PSCommandPath).BaseName + '.config')),
        [switch]
        # Return script result to standard output.  By default the script has
        # no output.  The objects in standard output are same that are
        # used to generate report .CSV file
    $PassThru,
        [Parameter(
            Mandatory,
            ParameterSetName = 'Version'
        )]
        [switch]
        # Returns script version.
    $Version
)

if ($PSCmdlet.ParameterSetName -like 'Version') {
    $result = Select-String -Path $PSCommandPath -Pattern '^\s*\.VERSION (\d(\.\d){0,3})$'
    $ver = $result.Matches.Groups[1].value
    try {
        [semver] $ver
    } catch {
        [version] $ver
    }
    return
}

$ConfigFile = Resolve-Path -Path $ConfigFile
Write-Verbose -Message "Loading Config file: $ConfigFile"
$conf = [xml] ''
$conf.Load($ConfigFile)

$mailSettings = @{
    Subject    = $conf.config.mail.subject
    From       = $conf.config.mail.from
    SmtpServer = $conf.config.server
    Encoding   = [text.encoding]::UTF8
    Priority   = $conf.config.mail.priority
    To         = ''
    Body       = ''
}
if ($conf.config.mail.item('bodyAsHtml')) {
    $mailSettings.BodyAsHtml = $true
}

$ReportFile = $conf.config.reportfile
if ($ReportFile) {
    $CsvProps = @{
        NoTypeInformation = $true
        UseCulture        = $true
        Encoding          = 'utf8'
        Path              = $ReportFile
        Confirm           = $false
        WhatIf            = $false
    }
}

$DomainName = (Get-ADDomain).NetBIOSName
$DaysBefore = $DaysBefore | Where-Object { $_ -ge 0 } | Sort-Object -Unique -Descending
$UserProperties = @(
    'AccountExpirationDate'
    'mail'
    'manager'
)
$ExpireSplat = @{
    AccountExpiring = $true
    UsersOnly       = $true
    TimeSpan        = [timespan]::FromDays($DaysBefore[0] + 1)
}
if ($conf.config.ou) {
    $ExpireSplat.SearchBase = $conf.config.ou
}
$ExcludedOU = $conf.config.excludeou
$UsingManagerMail = [bool] $conf.config.user.item('useManagerMail')

Search-ADAccount @ExpireSplat | Get-ADUser -Properties $UserProperties | Where-Object {
    -not ($ExcludedOU -and $_.DistinguishedName -like "*$ExcludedOU") -and
    ($UsingManagerMail -and $_.Manager -or $_.mail) -and
    $DaysBefore -contains (New-TimeSpan -End $_.AccountExpirationDate).Days
} | ForEach-Object {
    $ExpireDays = (New-TimeSpan -End $_.AccountExpirationDate).Days
    $userName = if ($conf.config.user.item('useSamAccountName')) {
        '{0}\{1}' -f $DomainName, $_.SamAccountName
    } else {
        $_.UserPrincipalName
    }
    $mail = if ($UsingManagerMail) {
        (Get-ADUser -Identity $_.Manager -Properties mail).mail
    } else {
        $_.mail
    }
    Write-Verbose -Message "User $username ($mail), account expires in $ExpireDays days."

    $mailSettings.To = $mail
    $mailSettings.Body = ($conf.config.mail.item('body').InnerText -f $userName, $ExpireDays)


    if ($PSCmdLet.ShouldProcess($mail, 'Send e-mail message')) {
        $OutputProps = @{
            Date         = [datetime]::Now.ToString('s')
            User         = $userName
            Mail         = $mail
            Days         = $ExpireDays
            ErrorMessage = $null
        }

        try {
            Send-MailMessage @mailSettings -ErrorAction Stop
            $OutputProps.MailSent = $true
        } catch {
            $OutputProps.ErrorMessage = $_.Exception.Message
            $OutputProps.MailSent = $false
        }
        $OutputObject = [PSCustomObject] $OutputProps
        if ($ReportFile) {
            $OutputObject | Export-Csv @CsvProps -Append
        }
        if ($PassThru) {
            $OutputObject
        }
    }
}
