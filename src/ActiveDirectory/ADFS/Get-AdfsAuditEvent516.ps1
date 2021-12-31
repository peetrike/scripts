<#
    .SYNOPSIS
        Collects information from ADFS event 516
    .DESCRIPTION
        This script collects AD FS Account Locked events (EventId 516) and
        reports them to pipeline or to .csv file
    .EXAMPLE
        Get-AdfsAuditEvent516.ps1 -After ([datetime]::Today) -Path report.csv

        Reports all AD FS lockout events for today. The result is saved to
        report.csv file.
    .EXAMPLE
        Get-AdfsAuditEvent516.ps1 -After 2021.05.01 -User domain\user

        Reports all AD FS lockout events since May 1 for user 'domain\user'
#>

[CmdletBinding()]
param (
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [string]
        # Specifies user in a form of domain\user address to filter events
    $User = '*',
        [string]
        # scecifies .CSV file path to save events to
    $Path
)

$EventFilter = @{
    LogName      = 'Security'
    ProviderName = 'AD FS Auditing'
    ID           = 516
}

if ($After) {
    $EventFilter.StartTime = $After
}

$events = Get-WinEvent -FilterHashtable $EventFilter |
    ForEach-Object {
        $currentEvent = $_
        $eventProps = @{
            TimeCreated = $currentEvent.TimeCreated
            Id          = $currentEvent.Id
            User        = $currentEvent.Properties[1].Value
            IP          = $currentEvent.Properties[2].Value
            BadPwdCount = $currentEvent.Properties[3].Value
            BadPwdTime  = $currentEvent.Properties[4].Value
        }
        New-Object -TypeName PSCustomObject -Property $eventProps
    } |
    Where-Object { $_.User -like $User }

if ($Path) {
    Export-Csv -UseCulture -Encoding utf8 -NoTypeInformation -Path $Path
} else {
    $events
}
