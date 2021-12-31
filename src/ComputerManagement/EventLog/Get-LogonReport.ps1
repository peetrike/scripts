#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.1

    .GUID aeb78b6a-0f41-4d74-b914-4f4c26f31acb

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS report, logon, event

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2020.11.04 - change date conversion
        [1.0.0] - 2020.11.03 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates Logon Event report
    .DESCRIPTION
        This script generates logon/logoff event report.
    .EXAMPLE
        .\Get-LoonReport.ps1 -After ([datetime]::Today) | Out-Gridview
        This example generates report of logon events for today.  Result
        is displayed in Grid View.
    .EXAMPLE
        .\Get-LoonReport.ps1 -Type Failure, Logon | Export-Csv -UseCulture -Path logonreport.csv
        This example generates report of successful and failed logons.
        The result is saved as .csv file
    .LINK
        Get-WinEvent
#>

[CmdletBinding()]
param (
        [ValidateSet('Failure', 'Logoff', 'Logon')]
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
        Label = 'Audit Logon Success'
        Type  = 'Logon'
        Id    = 528     # Audit Policy Logon
    }
    @{
        Label = 'Audit Logon Failure'
        Type  = 'Failure'
        Id    = 529     # Audit Policy Logon failure
    }
    @{
        Label = 'Advanced Audit Logon Success'
        Type  = 'Logon'
        Id    = 4624    # Advanced Audit Policy Logon
    }
    @{
        Label = 'Advanced Audit Logon Failure'
        Type  = 'Failure'
        Id    = 4625    # Advanced Audit Policy Logon failure
    }
    @{
        Label = 'Advanced Audit Logoff'
        Type  = 'Logoff'
        Id    = 4647    # Advanced Audit Policy Logoff
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
        $EventList | Where-Object { $Type -contains $_.Type } | ForEach-Object { 'EventID={0}' -f $_.Id }
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

foreach ($currentEvent in Get-WinEvent -FilterXml $xmlFilter) {
    $XmlEvent = [xml]$currentEvent.ToXml()
    $LogonType = ($xmlEvent.Event.EventData.Data | Where-Object { $_.Name -like 'LogonType' }).'#text'
    $eventProps = @{
        TimeCreated = $currentEvent.TimeCreated
        EventType   = ($EventList | Where-Object { $_.Id -eq $currentEvent.Id }).Label
        Id          = $currentEvent.Id
        User        = '{1}\{0}' -f (
            $XmlEvent.Event.EventData.Data | Where-Object { $_.Name -like 'TargetUserName' }
        ).'#text', (
            $XmlEvent.Event.EventData.Data | Where-Object { $_.Name -like 'TargetDomainName' }
        ).'#text'
        SourceIp    = ($xmlEvent.Event.EventData.Data | Where-Object { $_.Name -like 'IpAddress' }).'#text'
        LogonType   = switch ($LogonType) {
            2 { 'Interactive - local logon' }
            3 { 'Network' }
            4 { 'Batch' }
            5 { 'Service' }
            7 { 'Unlock (after screensaver)' }
            8 { 'NetworkCleartext' }
            9 { 'NewCredentials (local impersonation process under existing connection)' }
            10 { 'RDP' }
            11 { 'CachedInteractive' }
            default { 'LogType Not Recognised: {0}' -f $LogonType }
        }
    }

    New-Object -TypeName PSCustomObject -Property $eventProps
}
