#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.1.0

    .GUID aeb78b6a-0f41-4d74-b914-4f4c26f31acb

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2025.  All rights reserved.

    .TAGS report, logon, event

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] - 2025.04.03 - encapsulates script content in function
        [1.0.5] - 2025.01.06 - Refactored script to use Hashtable filter for events
        [1.0.4] - 2023.03.21 - Added ProcessName to report
        [1.0.3] - 2022.05.27 - Changed obtaining named properties to use XPath
        [1.0.2] - 2021.12.31 - Moved script to Github
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
        .\Get-LogonReport.ps1 -After ([datetime]::Today) | Out-GridView

        This example generates report of logon events for today.  Result
        is displayed in Grid View.
    .EXAMPLE
        .\Get-LogonReport.ps1 -Type Failure, Logon | Export-Csv -UseCulture -Path LogonReport.csv

        This example generates report of successful and failed logons.
        The result is saved as .csv file
    .EXAMPLE
        $result = .\Get-LogonReport.ps1 -Type Failure
        $result | Group-Object SourceIP | Sort-Object Count -Descending | Select-Object -First 5

        This example returns failed logon events.  The result is grouped by Source IP and then
        limited to 5 most common Source IPs
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

function Get-LogonReport {
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

$EventFilter = @{
    LogName = 'Security'
    ID      = $EventList | Where-Object { $Type -contains $_.Type } | ForEach-Object { $_.Id }
}
if ($After) {
    $EventFilter.StartTime = $After
}
if ($Before) {
    $EventFilter.EndTime = $Before
}


Write-Debug -Message ("Using filter:`n{0}" -f ($EventFilter | Out-String))

foreach ($currentEvent in Get-WinEvent -FilterHashtable $EventFilter) {
    $XmlEvent = [xml] $currentEvent.ToXml()
    $LogonType = $xmlEvent.SelectSingleNode('//*[@Name = "LogonType"]').InnerText
    $eventProps = @{
        TimeCreated = $currentEvent.TimeCreated
        EventType   = ($EventList | Where-Object { $_.Id -eq $currentEvent.Id }).Label
        Id          = $currentEvent.Id
        User        = '{1}\{0}' -f $XmlEvent.SelectSingleNode('//*[@Name = "TargetUserName"]').InnerText,
            $XmlEvent.SelectSingleNode('//*[@Name = "TargetDomainName"]').InnerText
        SourceIp    = $xmlEvent.SelectSingleNode('//*[@Name = "IpAddress"]').InnerText
        ProcessName = $xmlEvent.SelectSingleNode('//*[@Name = "ProcessName"]').InnerText
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
            default { 'LogonType Not Recognized: {0}' -f $LogonType }
        }
    }

    New-Object -TypeName PSCustomObject -Property $eventProps
}
}

Get-LogonReport @PSBoundParameters
