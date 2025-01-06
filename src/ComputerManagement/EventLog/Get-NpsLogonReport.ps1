#Requires -Version 3.0

<#PSScriptInfo
    .VERSION 0.1.4
    .GUID 47266bc4-ca5d-418d-b7a2-44f05b26ea05

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2025.  All rights reserved.

    .TAGS nps logon event

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.1.4] - 2025-01-06 - Refactor script to use hashtable filter for events
        [0.1.3] - 2023-03-24 - Add RADIUS Client IP
        [0.1.1] - 2023-03-24 - Add Authentication type
        [0.1.0] - 2023-03-24 - Remove dependency from ActiveDirectory module
        [0.0.1] - 2022-11-10 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generate NPS logon event report
    .DESCRIPTION
        This script extracts NPS server logon success/failure events from Event Log
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

if ($Type -like 'Both') {
    $Type = 'Failure', 'Success'
}

$EventFilter = @{
    LogName = 'Security'
    Id      = switch ($Type) {
        'Failure' { 6273 }
        'Success' { 6272 }
    }
}
if ($After) {
    $EventFilter.StartTime = $After
}
if ($Before) {
    $EventFilter.EndTime = $Before
}

Write-Debug -Message ("Using filter:`n{0}" -f ($EventFilter | Out-String))

Get-WinEvent -FilterHashtable $EventFilter | ForEach-Object {
    $currentEvent = $_
    $XmlEvent = [xml] $currentEvent.ToXml()
    $LogonObjectPath = $xmlEvent.SelectSingleNode('//*[@Name = "FullyQualifiedSubjectUserName"]').InnerText

    $eventProps = @{
        TimeCreated      = $currentEvent.TimeCreated
        Id               = $currentEvent.Id
        LogonObjectPath  = $LogonObjectPath
        UserLogon        = $xmlEvent.SelectSingleNode('//*[@Name = "SubjectUserName"]').InnerText
        RadiusClientName = $xmlEvent.SelectSingleNode('//*[@Name = "ClientName"]').InnerText
        RadiusClientIP   = $xmlEvent.SelectSingleNode('//*[@Name = "ClientIPAddress"]').InnerText
        Result           = $xmlEvent.SelectSingleNode('//*[@Name = "Reason"]').InnerText
        CallingStation   = $xmlEvent.SelectSingleNode('//*[@Name = "CallingStationID"]').InnerText
        AuthType         = $xmlEvent.SelectSingleNode('//*[@Name = "AuthenticationType"]').InnerText
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
