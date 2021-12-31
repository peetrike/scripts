#Requires -Version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.2

    .GUID 6e7bc3e9-22b7-4915-9246-e65816f49a78

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS report, logon, event, AD

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2021.12.29 - Fixed required modules
        [1.0.1] - 2021.01.07 - Initial Release
        [1.0.0] - 2021.01.06 - Started work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates Logon Event report
    .DESCRIPTION
        This script generates logon/logoff event report.
    .EXAMPLE
        .\Get-AuditLogonReport.ps1 -After ([datetime]::Today) | Out-Gridview
        This example generates report of logon events for today.  Result
        is displayed in Grid View.
    .EXAMPLE
        .\Get-AuditLogonReport.ps1 -Type Failure, Logon | Export-Csv -UseCulture -Path logonreport.csv
        This example generates report of successful and failed logons.
        The result is saved as .csv file
    .LINK
        Get-WinEvent
#>

[CmdletBinding()]
param (
        [ValidateSet('Failure', 'Logon')]
        [string[]]
        # Specifies type of events to collect
    $Type = 'Logon',
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before
)

$EventList = @(
    @{
        Label = 'A ticket granting service (TGS) ticket was granted'
        Type  = 'Logon'
        Id    = 673     # Audit Account Logon
    }
    @{
        Label = 'Kerberos Preauthentication failed'
        Type  = 'Failure'
        Id    = 675     # Audit Account Logon
    }
    @{
        Label = 'A TGS ticket was not granted'
        Type  = 'Failure'
        Id    = 677     # Audit Account Logon
    }
    @{
        Label = 'Logon failure. A domain account logon was attempted.'
        Type  = 'Failure'
        Id    = 681     # Audit Account Logon
    }
    @{
        Label = 'A Kerberos authentication ticket (TGT) was requested.'
        Type  = 'Logon'
        Id    = 4768    # Advanced Audit Kerberos Authentication
    }
    @{
        Label = 'A Kerberos authentication ticket (TGT) was requested.'
        Type  = 'Failure'
        Id    = 4768    # Advanced Audit Kerberos Authentication
    }
    @{
        Label = 'Kerberos pre-authentication failed'
        Type  = 'Failure'
        Id    = 4771    # Advanced Audit Kerberos Authentication
    }
    @{
        Label = 'The computer attempted to validate the credentials for an account.'
        Type  = 'Logon'
        Id    = 4776    # Advanced Audit Credential Validation
    }
    @{
        Label = 'The computer attempted to validate the credentials for an account.'
        Type  = 'Failure'
        Id    = 4776    # Advanced Audit Credential Validation
    }
)

function stringTime {
    param (
            [datetime]
        $time
    )

    $time.ToUniversalTime().ToString('o')
}

$xPathFilter = '*[System[(' + (
    $(
        $EventList |
            Where-Object { $Type -contains $_.Type } |
            #Sort-Object -Property Id -Unique |
            ForEach-Object { 'EventID={0}' -f $_.Id }
    ) -join ' or '
) + ')'
if ($After -or $Before) {
    $xPathFilter += ' and TimeCreated[@SystemTime'
    if ($After) {
        $xPathFilter += "&gt;='{0}'" -f (stringTime $After)
        if ($Before) { $xPathFilter += ' and @SystemTime' }
    }
    if ($Before) {
        $xPathFilter += "&lt;='{0}'" -f (stringTime $Before)
    }
    $xPathFilter += ']'
}
$xPathFilter += ']]'

Write-Debug -Message ("Using filter:`n{0}" -f $xPathFilter)
$xmlFilter = "<QueryList>
  <Query Id='0' Path='Security'>
    <Select Path='Security'>{0}</Select>
  </Query>
</QueryList>" -f $xPathFilter

foreach ($dc in Get-ADDomainController -Filter *) {
    Write-Verbose -Message ('Connecting with {0}' -f $dc.Name)
    Get-WinEvent -FilterXml $xmlFilter -ComputerName $dc.HostName | ForEach-Object {
        $CurrentEvent = $_
        $XmlEvent = [xml]$currentEvent.ToXml()
        $XmlData = $XmlEvent.Event.EventData.Data
        $domain = ($XmlData | Where-Object { $_.Name -like 'TargetDomainName' }).'#text'
        $user = ($XmlData | Where-Object { $_.Name -like 'TargetUserName' }).'#text'
        $AccountSid = [Security.Principal.SecurityIdentifier] ($xmlData | Where-Object { $_.Name -like 'TargetSid' }).'#text'

        $eventProps = @{
            TimeCreated   = $currentEvent.TimeCreated
            EventType     = $currentEvent.KeywordsDisplayNames -join ','
            Id            = $currentEvent.Id
            User          = if ($domain) { '{0}\{1}' -f $domain, $user } else { $user }
            Account       = if ($AccountSid) {
                $AccountSid.Translate([Security.Principal.NTAccount]).Value
            } else { $null }
            SourceMachine = ($xmlData | Where-Object { $_.Name -like 'Workstation' }).'#text'
            SourceIp      = ($xmlData | Where-Object { $_.Name -like 'IpAddress' }).'#text'
            Status        = ($xmlData | Where-Object { $_.Name -like 'Status' }).'#text'
        }

        New-Object -TypeName PSCustomObject -Property $eventProps
    }
}
