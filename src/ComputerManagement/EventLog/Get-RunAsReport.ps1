#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.0

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
        .\Get-RunAsReport.ps1 -Type Failure, Logon | Export-Csv -UseCulture -Path logonreport.csv

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

function stringTime {
    param (
            [datetime]
        $time
    )

    $time.ToUniversalTime().ToString('o')
}

$xPathFilter = '*[System[(EventID=4648)'
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

Write-Debug -Message ("Using filter:`n{0}" -f $xPathFilter)

foreach ($currentEvent in Get-WinEvent -LogName Security -FilterXPath $xPathFilter) {
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
