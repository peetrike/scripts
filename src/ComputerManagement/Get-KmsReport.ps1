#Requires -Version 5.1

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 9390df9f-53c5-4eff-929e-8c437c09217d

    .AUTHOR Peter Wawa
    .COMPANYNAME !ZUM!
    .COPYRIGHT (c) Peter Wawa 2025.  All rights reserved.

    .TAGS kms

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2025-10-03 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Get report for activated servers from KMS event log
    .DESCRIPTION
        This script generates report for activated servers from KMS event log
    .EXAMPLE
        Get-KmsReport.ps1

        Returns activation count for last 7 days
    .EXAMPLE
        Get-KmsReport.ps1 -Days 3

        Returns activation count for last 3 days
    .NOTES
        General notes
    .LINK
        KMS Troubleshooting: https://learn.microsoft.com/windows-server/get-started/activation-troubleshoot-kms-general
#>

#[Alias('')]
[OutputType([psobject[]])]
[CmdletBinding()]
param (
        [ValidateRange(1, 180)]
        [ValidateNotNullOrEmpty()]
        [int]
        # Number of days to look back in Event Log
    $Days,
        [switch]
    $PassThru,
        [string]
    $LogPath = $PWD
)

function Get-KmsLog {
    [CmdletBinding()]
    param (
            [ValidateRange(1, 180)]
            [ValidateNotNullOrEmpty()]
            [int]
            # Number of days to look back in Event Log
        $Days = 7
    )

    try {
        $null = [LicenseStatus]::Unlicensed
    } catch {
        Add-Type -TypeDefinition @'
        public enum LicenseStatus {
            Unlicensed = 0,
            Licensed = 1,
            OOBGrace = 2,
            OOTGrace = 3,
            NonGenuine = 4,
            Notification = 5,
            ExtendedGrace = 6
        }
'@
    }
    $StartTime = [datetime]::Today.AddDays(-$Days)

    Get-WinEvent -FilterHashtable @{
        LogName   = 'Key Management Service'
        ID        = 12290
        StartTime = $StartTime
    } |
        ForEach-Object {
            [PSCustomObject] @{
                TimeCreated   = $_.TimeCreated
                ErrorCode     = $_.Properties.Value[1]
                # ErrorCode     = [convert]::ToInt32($_.Properties.Value[1], 16)
                MinCount      = [int] $_.Properties.Value[2]
                ComputerName  = $_.Properties.Value[3].ToLower()
                ClientId      = [guid] $_.Properties.Value[4]
                Timestamp     = [datetime] $_.Properties.Value[5]
                IsVM          = [bool] [int] $_.Properties.Value[6]
                LicenseStatus = [LicenseStatus] [int] $_.Properties.Value[7]
                Expiration    = New-TimeSpan -Minutes ([int] $_.Properties.Value[8])
            }
        }
}

$result = Get-KmsLog -Days $Days |
    Where-Object ErrorCode -like '0x0' |
    Group-Object ClientId | ForEach-Object {
        $Group = $_
        $Group.Group | Group-Object LicenseStatus | ForEach-Object {
            [PSCustomObject] @{
                Computername  = $_.Group.ComputerName | Sort-Object -Unique
                LicenseStatus = $_.Name
                Count         = $_.Count
            }
        }
    }

$CsvName = 'KMS_report_{0}.csv' -f [datetime]::Now.ToString('yyyyMMdd_HHmmss')
$CsvPath = Join-Path -Path $LogPath -ChildPath $CsvName
$CsvProps = @{
    UseCulture = $true
    Encoding   = 'UTF8'
    Path       = $CsvPath
}
if ($PSVersionTable.PSVersion.Major -gt 5) {
    $CsvProps.Encoding = 'utf8BOM'
} else {
    $CsvProps.NoTypeInformation = $true
}
$result | Export-Csv @CsvProps

if ($PassThru) {
    $result
}
