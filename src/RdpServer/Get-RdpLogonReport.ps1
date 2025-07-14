<#PSScriptInfo
    .VERSION 1.0.2
    .GUID f774707e-5178-4546-ad34-6cf87d724db9

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2025.  All rights reserved.

    .TAGS rdp logon event

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2025.07.14 - Wrap script contents in function
        [1.0.1] - 2025.07.14 - Fix logoff event type message
        [1.0.0] - 2025.07.14 - Remove ComputerName parameter
        [0.2.0] - 2025.03.06 - Use Hashtable filter
        [0.1.1] - 2021.12.31 - Update script metadata
        [0.1.0] - 2021.12.31 - Move script from BitBucket
    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Get RDP event report
    .DESCRIPTION
        This script can be used to list the user accounts that have logged
        into the Remote Desktop Session.  It searches the
        "TerminalServices-LocalSessionManager" event log for events that mark
        logon/logoff and disconnect/reconnect.
    .EXAMPLE
        .\Get-RdpLogonReport.ps1 -Type Logon

        This example returns only logon events.
    .NOTES
        Date:  June 3, 2016
        Modified by: Peter Wawa
    .LINK
        Original from: https://gallery.technet.microsoft.com/scriptcenter/Get-Terminal-Server-Logins-dd12c279
#>

[CmdletBinding()]
param (
        [ValidateSet('Logon', 'Logoff', 'Disconnect', 'Reconnect', 'All')]
        [string[]]
        # Specifies types of events to collect
    $Type = 'All',
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before
)

function Get-RdpLogonReport {
    [CmdletBinding()]
    param (
            [ValidateSet('Logon', 'Logoff', 'Disconnect', 'Reconnect', 'All')]
            [string[]]
            # Specifies types of events to collect
        $Type = 'All',
            [Alias('StartTime')]
            [datetime]
            # Specifies start time of events
        $After,
            [Alias('EndTime')]
            [datetime]
            # Specifies end time of events
        $Before
    )

    if ($Type -eq 'All') {
        $Type = 'Logon', 'Logoff', 'Disconnect', 'Reconnect'
    }

    $EventId = switch ($Type) {
        'Logon' { 21, 1101 }
        'Logoff' { 23, 1103 }
        'Disconnect' { 24, 1104 }
        'Reconnect' { 25, 1105 }
    }

    $Filter = @{
        LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
        Id      = $EventId
    }
    if ($After) {
        $Filter.StartTime = $After
    }
    if ($Before) {
        $Filter.EndTime = $Before
    }

    foreach ($currentEvent in Get-WinEvent -FilterHashtable $Filter) {
        $XmlEvent = [xml]$currentEvent.ToXml()

        $eventProps = @{
            TimeCreated = $currentEvent.TimeCreated
            EventId     = $currentEvent.Id
            EventType   = switch ($currentEvent.Id) {
                21 { 'Logon' }
                1101 { 'Logon' }
                23 { 'Logoff' }
                1103 { 'Logoff' }
                24 { 'DisConnect' }
                1104 { 'Disconnect' }
                25 { 'ReConnect' }
                1105 { 'Reconnect' }
            }
            User        = $XmlEvent.event.UserData.EventXML.User
            Address     = $XmlEvent.event.UserData.EventXML.Address
            SessionId   = $XmlEvent.event.UserData.EventXML.SessionID
        }

        New-Object -TypeName PSCustomObject -Property $eventProps
    }
}

Get-RdpLogonReport @PSBoundParameters
