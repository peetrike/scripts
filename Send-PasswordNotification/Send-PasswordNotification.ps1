#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.7.2
    .GUID 4ff55e9c-f6ca-4549-be4c-92ff07b085e4

    .AUTHOR Peter Wawa
    .COMPANYNAME !ZUM!
    .COPYRIGHT (c) 2022 Peter Wawa.  All rights reserved.

    .TAGS password e-mail email notification Windows PSEdition_Desktop PSEdition_Core

    .LICENSEURI https://github.com/peetrike/scripts/blob/master/LICENSE
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES https://github.com/peetrike/scripts/blob/master/Send-PasswordNotification/CHANGELOG.md

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Sends e-mail notification to users whose password is about to expire.

    .DESCRIPTION
        Script is meant to send e-mail notifications about expiring passwords.
        The notification is sent only to users who:
            1. are enabled
            2. can change their password
            3. has an e-mail address
            4. has been logged on at least once
            5. their password expires in time
            6. password is not yet expired

        The script uses config file, that contains information necessary to send e-mail.

        Script requires ActiveDirectory module on the computer where script runs.  Script also
        requires AD WS (or AD GMS) service on any domain controller.

    .PARAMETER WhatIf
        Shows what would happen if the script runs.
        The script is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before sending out e-mail messages

    .EXAMPLE
        Send-PasswordNotification.ps1 -DaysBefore 5,1

        Sends e-mail to users, whose password expires within 5 or 1 days.

    .EXAMPLE
        Send-PasswordNotification.ps1 7 -ConfigFile my.config

        Sends notification 7 days before password expires.  Uses custom configuration file.

    .INPUTS
        List of days before password expiration

    .OUTPUTS
        None

    .NOTES
        The script requires a config file.  You can download sample config file from
        https://github.com/peetrike/scripts/blob/master/Send-PasswordNotification/Send-PasswordNotification.config

    .LINK
        about_ActiveDirectory

    .LINK
        Send-MailMessage
#>

[CmdletBinding(
    SupportsShouldProcess = $True,
    DefaultParameterSetName = 'Action'
)]
[OutputType([PSCustomObject])]
param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = 'Specify number of days before password expiration',
            #ValueFromPipeLine = $true,
            ParameterSetName = 'Action'
        )]
        [int[]]
        # Number of days before password expiration, when to send warning.  Can contain more than one number.
    $DaysBefore,
        [parameter(
            ParameterSetName = 'Action'
        )]
        [ValidateScript( {
            if (test-path -Path $_) { $true }
            else {
                throw 'Config file not found'
            }
        })]
        [PSDefaultValue(Help = '<scriptname>.config in the same folder as script')]
        [String]
        # Configuration file to read.  By default the config file is
        # in the same directory as script and has the same name with .config extension.
    $ConfigFile = $(Join-Path -Path $PSScriptRoot -ChildPath ((get-item $PSCommandPath).BaseName + '.config')),
        [switch]
        # Return script result to standard output.  By default the script has
        # no output.  The objects in standard output are same that are
        # used to generate report .CSV file
    $PassThru,
        [parameter(
            Mandatory = $true,
            ParameterSetName = 'Version'
        )]
        [Switch]
        # Returns script version.
    $Version
)

    # Script version
if ($PSCmdlet.ParameterSetName -like 'Version') {
    $result = Select-String -Path $PSCommandPath -Pattern '^\s*\.VERSION (\d(\.\d){0,3})$'
    $ver = $result.Matches.Groups[1].value
    try {
        [semver] $ver
    } catch {
        [version] $ver
    }
}

Write-Verbose -Message "Loading Config file: $ConfigFile"
$conf = [xml](Get-Content -Path $ConfigFile)

$AdDomain = Get-ADDomain
$mailSettings = @{
    Subject    = $conf.config.mail.subject
    From       = $conf.config.mail.from
    SmtpServer = $conf.config.server
    Encoding   = [text.encoding]::UTF8
    To         = ''
    Body       = ''
}

    # get users
$AndPart = ' -and '
$searchProperties = @{
    Filter     = 'Enabled -eq $true' + $AndPart +
                 'PasswordNeverExpires -eq $false' + $AndPart +
                 'logonCount -ge 1' + $AndPart +
                 'mail -like "*"'
    Properties = @(
        'CannotChangePassword'
        'mail'
        'manager'
        'msDS-UserPasswordExpiryTimeComputed'
        'PasswordExpired'
    )
}
if ($conf.config.ou) {
    $searchProperties.SearchBase = $conf.config.ou
    #$searchProperties.SearchScope = 'Subtree'
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

Get-ADUser @searchProperties |
    Where-Object { -not ($_.CannotChangePassword -or $_.PasswordExpired) } |
    ForEach-Object {
        $PasswordExpireDate = [datetime]::FromFileTime($_.'msDS-UserPasswordExpiryTimeComputed')
        $PasswordDays = (New-TimeSpan -End $PasswordExpireDate).days
        Write-Debug -Message "pwdDays = $PasswordDays"

        $userName = if ($conf.config.user.item('useSamAccountName')) {
            '{0}\{1}' -f $AdDomain.NetBIOSName, $_.SamAccountName
        } else {
            $_.UserPrincipalName
        }

        $userMail = if ($conf.config.user.item('useManagerMail')) {
                # use manager's e-mail instead of user's, if available
            $managerMail = (Get-ADUser -Identity $_.manager -Properties mail).mail
            if ($managerMail) {
                $managerMail
            } else { $_.mail }
        } else {
            $_.mail
        }

        if ($PasswordDays -ge 1) {
            foreach ($day in $DaysBefore) {
                Write-Debug -Message "Processing day $day, user $userName"
                if ($PasswordDays -eq $day) {
                    $mailSettings.To = $userMail
                    $mailSettings.Body = ($conf.config.mail.body -f $userName, $day)
                    $OutputProps = @{
                        Date         = [datetime]::Now.ToString('s')
                        User         = $userName
                        Mail         = $userMail
                        Days         = $day
                        ErrorMessage = $null
                    }
                    # Write-Debug ('Message body: {0}' -f $mailSettings.Body)
                    Write-Verbose -Message "User $username ($userMail), password expires in $day days."
                    if ($PSCmdLet.ShouldProcess($userMail, 'Send e-mail message')) {
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
            }
        }
    }
