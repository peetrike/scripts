#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.1

    .GUID af8dbac7-6403-4aab-81ae-8798f0aead47

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2023.  All rights reserved.

    .TAGS report, runas, event

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2025.01.06 - Refactored script to use Hashtable filter for events
        [1.0.0] - 2023.11.23 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates Runas Event report
    .DESCRIPTION
        This script generates Runas event report.
    .EXAMPLE
        .\Get-RunAsReport.ps1 -After ([datetime]::Today) | Out-Gridview

        This example generates report of runas events for today.  Result
        is displayed in Grid View.
    .EXAMPLE
        .\Get-RunAsReport.ps1 | Export-Csv -UseCulture -Path logonreport.csv

        This example generates report of runas events.
        The result is saved as .csv file
    .LINK
        Get-WinEvent
#>

[CmdletBinding()]
param (
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before
)


$EventFilter = @{
    LogName = 'Security'
    ID      = 4648
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
    $eventProps = @{
        TimeCreated  = $currentEvent.TimeCreated
        SourceUser   = '{1}\{0}' -f $XmlEvent.SelectSingleNode('//*[@Name = "SubjectUserName"]').InnerText,
            $XmlEvent.SelectSingleNode('//*[@Name = "SubjectDomainName"]').InnerText
        TargetUser   = '{1}\{0}' -f $XmlEvent.SelectSingleNode('//*[@Name = "TargetUserName"]').InnerText,
            $XmlEvent.SelectSingleNode('//*[@Name = "TargetDomainName"]').InnerText
        TargetServer = $xmlEvent.SelectSingleNode('//*[@Name = "TargetServerName"]').InnerText
        ProcessName  = $xmlEvent.SelectSingleNode('//*[@Name = "ProcessName"]').InnerText
    }

    New-Object -TypeName PSCustomObject -Property $eventProps
}
