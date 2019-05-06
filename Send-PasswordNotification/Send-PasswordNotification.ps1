#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo

    .VERSION 1.5.0

    .GUID 4ff55e9c-f6ca-4549-be4c-92ff07b085e4

    .AUTHOR Peter Wawa

    .COMPANYNAME !ZUM!

    .COPYRIGHT (c) 2019 Peter Wawa.  All rights reserved.

    .TAGS password, e-mail, notification

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

		The script uses config file, that contains information nessesary to send e-mail.

		Script requires ActiveDirectory module on the computer where script runs.  Script also
		requires AD WS (or AD GMS) service on any domain controller.

    .PARAMETER WhatIf
        Shows what would happen if the script runs.
        The script is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before sending out e-mail messages

    .EXAMPLE
        PS C:\> Send-PasswordNotification.ps1 -DaysBefore 5,1

        Sends e-mail to users, whose password expires within 5 or 1 days.

    .EXAMPLE
        PS C:\> Send-PasswordNotification.ps1 7 -configFile my.config

        Sends notification 7 days before password expires.  Uses custom configuration file.

    .INPUTS
        List of days before password expiration

    .OUTPUTS
        None

    .NOTES
        The script requires a config file with similar to following content:

        <?xml version="1.0" encoding="utf-8" ?>
        <config>
            <ou></ou> <!-- Search base OU, if needed -->
        	<user>
        		<!-- If the next element exist, the script refers to user as domain\samAccountName -->
        		<!-- Otherwise, the script refers to user as userPrincipalName -->
        <!--
        		<useSamAccountName />
        -->
        	</user>
        	<server>mail.server</server>
        	<mail>
        		<from>PasswordNotifier@localhost</from>
        		<subject>Your password will expire soon </subject>
        		<body>Dear User,

        Password of Your user account ({0}) expires in {1} days.
        Please change Your password ASAP.
        		</body>
        	</mail>
        </config>

    .LINK
        about_ActiveDirectory

    .LINK
        Send-MailMessage
#>

[cmdletbinding(
    SupportsShouldProcess = $True,
    DefaultParameterSetName = 'Action'
)]
param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = 'Specify number of days before password expiration',
            ValueFromPipeLine = $true,
            ParameterSetName = 'Action'
        )]
        [int[]]
        # Number of days before password expiration, when to send warning.  Can contain	more than one number.
    $DaysBefore,
        [parameter(
            ParameterSetName = 'Action'
        )]
        [ValidateScript({
            if (test-path -Path $_) {$true}
            else {
                throw 'Config file not found'
            }
        })]
        [String]
        # Configuration file to read.  By default the config file is in the same directory as script and has the same name with .config extension.
    $ConfigFile = $(Join-Path -Path $PSScriptRoot -ChildPath ((get-item $PSCommandPath).BaseName + '.config')),
        [parameter(
            Mandatory = $true,
            ParameterSetName = 'Version'
        )]
        [Switch]
        # Returns script version.
    $Version
)

    # Script version
Set-Variable -Name Ver -Option Constant -Scope Script -Value '1.5.0' -WhatIf:$false -Confirm:$false

if ($PSCmdlet.ParameterSetName -like 'Version') {
    "Version $Ver"
    exit 3
}

    # check for required module
<# if (Get-Module ActiveDirectory) {
    Write-Verbose -Message 'Active Directory module already loaded'
} elseif (Get-Module ActiveDirectory -ListAvailable ) {
    Import-Module ActiveDirectory
} else {
    throw 'No Active Directory module installed'
} #>

Write-Verbose -Message "Loading Config file: $ConfigFile"
$conf = [xml](Get-Content -Path $ConfigFile)

    # get Max Password age from Domain Policy
$MaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
Write-Debug -Message ('Max Password Age: {0}' -f $MaxPasswordAge)

    # Get Domain functional level.
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
$searchProperties = @{
    Filter = 'Enabled -eq $true -and PasswordNeverExpires -eq $false -and PasswordExpired -eq $false -and logonCount -ge 1 -and mail -like "*"'
    Properties = 'PasswordLastSet', 'mail'
}
if ($conf.config.ou) {
    $searchProperties.SearchBase = $conf.config.ou
    #$searchProperties.SearchScope = 'Subtree'
}
Get-ADUser @searchProperties |
    Where-Object {-not $_.CannotChangePassword} |
    ForEach-Object {
        $PasswordAge = $MaxPasswordAge
        if ($AdDomain.DomainMode -ge 3) {   # [Microsoft.ActiveDirectory.Management.ADDomainMode]::Windows2008Domain
            $accountFGPP = Get-ADUserResultantPasswordPolicy -Identity $_
            if ($accountFGPP) {
                $PasswordAge = $accountFGPP.MaxPasswordAge
            }
        }
        Write-Debug -Message "pwdAge = $PasswordAge"

            # TODO: check for PasswordLastSet attribute existence
        $PasswordDays = ($_.PasswordLastSet.Add($PasswordAge) - [datetime]::Now).days
        Write-Debug -Message "pwdDays = $PasswordDays"

        if ($conf.config.user.item('useSamAccountName')) {
            $userName = '{0}\{1}' -f $AdDomain.NetBIOSName, $_.SamAccountName
        } else {
            $userName = $_.UserPrincipalName
        }
        $userMail = $_.mail
        if ($PasswordDays -ge 1) {
            foreach ($day in $DaysBefore) {
                Write-Debug -Message "Processing day $day, user $userName"
                if ($PasswordDays -eq $day) {
                    $mailSettings.To = $userMail
                    $mailSettings.Body = ($conf.config.mail.body -f $userName, $day)
                    if ($PSCmdLet.ShouldProcess($userMail, 'Send e-mail message')) {
                        Send-MailMessage @mailSettings
                    }
                    # Write-Debug $mailSettings.Body
                    Write-Verbose -Message "User $username ($userMail), password expires in $day days."
                }
            }
        }
    }
