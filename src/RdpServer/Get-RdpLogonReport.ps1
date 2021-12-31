﻿<#
    .DESCRIPTION
        This script can be used to list the user accounts that have logged
        into the Remote Desktop Server defined in the $ComputerName parameter.  It searches
        the "TerminalServices-LocalSessionManager" event log for events that mark logon/logoff
        and disconnect/reconnect.
    .EXAMPLE
        .\Get-RdpLogonReport.ps1

        This example takes events from local computer.

    .NOTES
        Date:  June 3, 2016
        Modified by: Peter Wawa
    .LINK
        Original from: https://gallery.technet.microsoft.com/scriptcenter/Get-Terminal-Server-Logins-dd12c279
#>

Param(
        [Parameter(
            HelpMessage = 'Enter a local or remote hostname'
        )]
        [string]
        # Specifies the computername where to get events.
    $ComputerName = $env:COMPUTERNAME,
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

$LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'

$xPathFilter = '*[System[(EventID=21 or (EventID &gt;= 23 and EventID &lt;= 25))'
if ($After -or $Before) {
    $xPathFilter += ' and TimeCreated[@SystemTime'
    if ($After) {
        $xPathFilter += '&gt;="{0}"' -f (stringTime $After)
        if ($Before) { $xPathFilter += ' and @SystemTime' }
    }
    if ($Before) {
        $xPathFilter += '&lt;="{0}"' -f (stringTime $Before)
    }
    $xPathFilter += ']'
}
$xPathFilter += ']]'

$xmlFilter = '<QueryList>
  <Query Id="0" Path="{0}">
    <Select Path="{0}">
      {1}
    </Select>
  </Query>
</QueryList>' -f $LogName, $xPathFilter
Write-Debug -Message ("Using filter:`n{0}" -f $xmlFilter)

foreach ($currentEvent in Get-WinEvent -ComputerName $ComputerName -FilterXml $xmlFilter) {
    $XmlEvent = [xml]$currentEvent.ToXml()

    $eventProps = @{
        TimeCreated = $currentEvent.TimeCreated
        EventId     = $currentEvent.Id
        EventType   = switch ($currentEvent.Id) {
            21 { 'Logon' }
            23 { 'Logoff' }
            24 { 'DisConnect' }
            25 { 'ReConnect' }
        }
        User        = $XmlEvent.event.UserData.EventXML.User
        Address     = $XmlEvent.event.UserData.EventXML.Address
        SessionId   = $XmlEvent.event.UserData.EventXML.SessionID
    }

    New-Object -TypeName PSCustomObject -Property $eventProps
}
