#Requires -version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo

    .VERSION 1.4.2

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

    .RELEASENOTES
        [1.4.3] - 2019-03-06 - changed default config file path to
        [1.4.2] - 2019-03-06 - Minor formatting changes
        [1.4.1] - 2014-09-06 - Initial release to Technet Script Gallery

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
        	<user>
        		<!-- If the next element exist, the script refers to user as domain\samAccountName -->
        		<!-- Otherwise, the script refers to user as userPrincipalName -->
        <!--
        		<useSamAccountName />
        -->
        	</user>
        	<server>mail</server>
        	<mail>
        		<from>PasswordNotifier@localhost</from>
        		<subject>Sinu parool aegub varsti</subject>
        		<body>Kallis kasutaja,

        Sinu konto ({0}) parool aegub {1} päeva pärast.
        Muuda palun esimesel võimalusel oma parooli.

        Dear User,

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
    $configFile = $(Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path) -ChildPath ($MyInvocation.MyCommand.Name.split(".")[0] + '.config')),
        [parameter(
            Mandatory = $true,
            ParameterSetName = 'Version'
        )]
        [Switch]
        # Returns script version.
    $Version
)

# Set-StrictMode -Version Latest

# Script version
Set-Variable -Name Ver -Option Constant -Scope Script -Value '1.4.2' -WhatIf:$false -Confirm:$false

if ($PSCmdlet.ParameterSetName -like 'Version') {
    "Version $Ver"
    exit 3
}

# check for required module
if (Get-Module ActiveDirectory) {
    # module already loaded
} elseif (Get-Module ActiveDirectory -ListAvailable ) {
    Import-Module ActiveDirectory
} else {
    throw 'No Active Directory module installed'
}

$configFilePath = $configFile

Write-Verbose -Message "Loading Config file: $configFilePath"
$conf = [xml](Get-Content -Path $configFilePath)

# get Max Password age from Domain Policy
$maxPwdAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
Write-Debug -Message $maxPwdAge

# Get Domain functional level.
$domainFunctionalLevel = (Get-ADDomain).DomainMode
$userDomain = (Get-ADDomain).NetBIOSName

$mailSettings = @{
    Subject    = $conf.config.mail.subject
    From       = $conf.config.mail.from
    SmtpServer = $conf.config.server
    Encoding   = [text.encoding]::UTF8
    To         = ''
    Body       = ''
}

# get users
Get-ADUser -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false -and PasswordExpired -eq $false -and logonCount -ge 1 -and Mail -like '*'} -Properties PasswordLastSet, mail |
    Where-Object {! $_.CannotChangePassword} |
    ForEach-Object {
    if ($domainFunctionalLevel -ge 3) {
        ## Windows2008 domain functional level or greater
        $accountFGPP = Get-ADUserResultantPasswordPolicy -Identity $_
        if ($accountFGPP -ne $null) {
            $pwdAge = $accountFGPP.MaxPasswordAge
        } else {
            $pwdAge = $maxPwdAge
        }
    } else {
        $pwdAge = $maxPwdAge
    }
    Write-Debug -Message "pwdAge = $pwdAge"

    # TODO: check for PasswordLastSet attribute existence
    $pwdDays = ($_.passwordlastset.Add($PwdAge) - (Get-Date)).days
    Write-Debug -Message "pwdDays = $pwdDays"

    if ($conf.config.user.item('useSamAccountName')) {
        $userName = '{0}\{1}' -f $userDomain, $_.SamAccountName
    } else {
        $userName = $_.UserPrincipalName
    }
    $userMail = $_.mail
    if ($pwdDays -ge 1) {
        foreach ($day in $DaysBefore) {
            Write-Debug -Message "Processing day $day, user $userName"
            if ($pwdDays -eq $day) {
                $mailSettings.To = $userMail
                $mailSettings.Body = ($conf.config.mail.body -f $userName, $day)
                if ($PSCmdLet.ShouldProcess($userMail, 'Send e-mail message')) {
                    Send-MailMessage @mailSettings
                }
                #					Write-Debug $mailBody
                Write-Verbose -Message "User $username ($userMail), password expires in $day days."
            }
        }
    }
}
