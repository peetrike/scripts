﻿#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 47266bc4-ca5d-418d-b7a2-44f05b26ea05

    .AUTHOR CPG4285
    .COMPANYNAME MyCompany
    .COPYRIGHT (c) MyCompany 2022.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
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
    $UserName = $xmlEvent.SelectSingleNode('//*[@Name = "SubjectUserName"]').InnerText
    $Sid = $xmlEvent.SelectSingleNode('//*[@Name = "SubjectUserSid"]').InnerText

    $eventProps = @{
        TimeCreated  = $currentEvent.TimeCreated
        Id           = $currentEvent.Id
        UserLogon    = $UserName
        RadiusClient = $xmlEvent.SelectSingleNode('//*[@Name = "ClientName"]').InnerText
        Result       = $xmlEvent.SelectSingleNode('//*[@Name = "Reason"]').InnerText
        IP           = $xmlEvent.SelectSingleNode('//*[@Name = "CallingStationID"]').InnerText
    }

    if ($UserName -like 'host/*') {
        $computer = Get-ADcomputer -id $Sid
        $eventProps.UserName = $computer.DNSHostName
    } else {
        $user = if ($UserName -match '^\w+$' ) {
            Get-ADUser -id $UserName
        } else {
            Get-ADUser -id $Sid
        }
        $eventProps.UserName = $user.Name
    }
    [PSCustomObject] $eventProps
}