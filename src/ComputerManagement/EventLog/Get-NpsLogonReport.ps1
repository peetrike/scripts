#Requires -Version 3.0
# Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.1.0
    .GUID 47266bc4-ca5d-418d-b7a2-44f05b26ea05

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.1.0] - 2023-03-24 - Remove dependency from ActiveDirectory module
        [0.0.1] - 2022-11-10 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generate NPS logon event report
    .DESCRIPTION
        This script extracts NPS server logon succes/failure events from Event Log
    .EXAMPLE
        Get-NpsLogonReport.ps1 -After '2022-11-10'

        Get successful NPS logon events from Event log
    .INPUTS
        None
    .OUTPUTS
        List of event details
    .NOTES
        This script assumes than users who try to logon are always domain users
    .LINK
        Get-WinEvent
#>

[CmdletBinding()]
#[Alias('')]
[OutputType([psobject])]
param (
        [ValidateSet('Both', 'Failure', 'Success')]
        [string[]]
        # Specifies type of events to collect
    $Type = 'Success',
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before
)

function stringTime {
    param (
            [datetime]
        $time
    )

    $time.ToUniversalTime().ToString('o')
}


if ($Type -like 'Both') {
    $Type = 'Failure', 'Success'
}

$EventId = switch ($Type) {
    'Failure' { 6273 }
    'Success' { 6272 }
}

$xPathFilter = '*[System[(' + (
    $(
        $EventId | ForEach-Object { 'EventID={0}' -f $_ }
    ) -join ' or '
) + ')'
if ($After -or $Before) {
    $xPathFilter += ' and TimeCreated[@SystemTime'
    if ($After) {
        $xPathFilter += " >= '{0}'" -f (stringTime $After)
        if ($Before) { $xPathFilter += ' and @SystemTime' }
    }
    if ($Before) {
        $xPathFilter += " <= '{0}'" -f (stringTime $Before)
    }
    $xPathFilter += ']'
}
$xPathFilter += ']]'

Write-Verbose -Message ("Using filter:`n{0}" -f $xPathFilter)

Get-WinEvent -LogName Security -FilterXPath $xPathFilter | ForEach-Object {
    $currentEvent = $_
    $XmlEvent = [xml] $currentEvent.ToXml()
    $LogonObjectPath = $xmlEvent.SelectSingleNode('//*[@Name = "FullyQualifiedSubjectUserName"]').InnerText

    $eventProps = @{
        TimeCreated     = $currentEvent.TimeCreated
        Id              = $currentEvent.Id
        LogonObjectPath = $LogonObjectPath
        UserLogon       = $xmlEvent.SelectSingleNode('//*[@Name = "SubjectUserName"]').InnerText
        RadiusClient    = $xmlEvent.SelectSingleNode('//*[@Name = "ClientName"]').InnerText
        Result          = $xmlEvent.SelectSingleNode('//*[@Name = "Reason"]').InnerText
        CallingStation  = $xmlEvent.SelectSingleNode('//*[@Name = "CallingStationID"]').InnerText
    }

    $eventProps.UserName = switch -Regex ($LogonObjectPath) {
        '/' {
             ($LogonObjectPath -split '/')[-1]
        }
        '\\' {
            ($LogonObjectPath -split '\\')[-1]
        }
    }
    [PSCustomObject] $eventProps
}
