<#
    .SYNOPSIS
        Collects information from ADFS event 1203
    .DESCRIPTION
        This script collects AD FS logon failed events (EventId 1203) and
        reports them to pipeline or to .CSV file
    .EXAMPLE
        Get-AdfsAuditEvent1203.ps1 -After ([datetime]::Today) -Path report.csv

        Reports all AD FS failed logon events for today.  The result is saved to
        report.csv file
    .EXAMPLE
        Get-AdfsAuditEvent1203.ps1 -After 2021.05.01 -User user@domain.com

        Reports all AD FS lockout events since May 1 for user 'user@domain.com'
#>

[CmdletBinding()]
param (
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [string]
        # Specifies user e-mail address to filter events
    $UserEmail = '*',
        [string]
        # Specifies .CSV file path to save events to
    $Path
)

$EventFilter = @{
    LogName      = 'Security'
    ProviderName = 'AD FS Auditing'
    ID           = 1203
}

if ($After) {
    $EventFilter.StartTime = $After
}

$events = Get-WinEvent -FilterHashtable $EventFilter |
    ForEach-Object {
        $currentEvent = $_
        $XmlEvent = [xml]$currentEvent.Properties[1].Value
        $eventProps = @{
            TimeCreated = $currentEvent.TimeCreated
            Id          = $currentEvent.Id
            User        = $xmlEvent.AuditBase.ContextComponents.Component[0].UserId
            IP          = $xmlEvent.AuditBase.ContextComponents.Component[3].IpAddress
            ForwarderIp = $xmlEvent.AuditBase.ContextComponents.Component[3].ForwardedIpAddress
            UserAgent   = $xmlEvent.AuditBase.ContextComponents.Component[3].UserAgentString
        }
        New-Object -TypeName PSCustomObject -Property $eventProps
    } |
    Where-Object { $_.User -like $UserEmail }

if ($Path) {
    Export-Csv -UseCulture -Encoding utf8 -NoTypeInformation -Path $Path
} else {
    $events
}
