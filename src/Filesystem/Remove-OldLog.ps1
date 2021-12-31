#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.1.1
    .GUID 311baf21-66e2-46f4-9e27-16dbf4aa51a8

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS log, remove

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.1] - 2021.12.31 - Moved script to Github
        [1.1.0] - 2020-05-04 - Now, -Months filters out files from beginning of month, not from current day in month
        [1.0.1]  Fixed Powershell 2.0 compatibility
        [1.0.0]  Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Remove old log files
    .DESCRIPTION
        This script will remove all files that are older than specified number of days (or months).
    .EXAMPLE
        Remove-OldLog.ps1 -Days 30

        This command removes all files older than 30 days in current directory.
    .EXAMPLE
        Get-ChildItem c:\logs | Remove-OldLog.ps1 -Months 3 -Filter *.log

        This command removes all *.log files older than 3 months in subfolders under path c:\logs.
    .INPUTS
        Files to be removed
    .OUTPUTS
        None
    .LINK
        Remove-Item: https://docs.microsoft.com/powershell/module/Microsoft.PowerShell.Management/Remove-Item
#>

[CmdLetBinding(
    SupportsShouldProcess=$true
)]
param (
        [parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [ValidateScript( {
            if (Test-Path -Path $_) { $true }
            else {
                throw (New-Object -TypeName 'System.Management.Automation.ItemNotFoundException' -ArgumentList ('Path not found: {0}' -f $_))
            }
        })]
        [Alias('FullName')]
        [string[]]
        # Specifies the path or paths to the files that you want to remove.  Wildcards are permitted.
        # The default location is the current directory (.).
    $Path = $PWD,
        [string]
        # Specifies a filter in the provider's format or language.
        # The value of this parameter qualifies the Path parameter.
    $Filter,
        [parameter(
            ParameterSetName = 'Days'
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        # Specifies how many days old files will be removed.  The default is 90 days.
        # Archive name contains full date.
    $Days = 90,
        [parameter(
            Mandatory = $true,
            ParameterSetName = 'Months'
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        # Specifies how many months old files will be removed.  Archive name contains ony year and month.
    $Months,
        [switch]
        # Indicates that this function gets the items in the specified locations
        # and in all child items of the locations.
    $Recurse,
        [switch]
        # Forces the function to remove items that cannot otherwise be changed
    $Force
)

begin {
    $DirParams = @{ }
    $RemoveParams = @{ }
    if ($Filter) {
        $DirParams.Filter = $Filter
    }
    if ($Recurse) {
        $DirParams.Recurse = $true
    }
    if ($Force) {
        $RemoveParams.Force = $true
    }
    if ($PSCmdlet.ParameterSetName -eq 'Months') {
        $MonthsAgo = ([datetime]::Today).AddMonths(-$Months)
        $MonthsAgo = $MonthsAgo.AddDays(1-$MonthsAgo.Day)
        $DateFilter = { $_.lastwritetime -le $MonthsAgo }
    } else {
        $DateFilter = { ($_ | New-TimeSpan).Days -ge $Days }
    }
}

process {
    foreach ($folder in $Path) {
        Write-Verbose -Message ('Processing path {0}' -f $Path)
        $DirParams.Path = $folder

        if ($PSVersionTable.PSVersion -ge '3.0') {
            $files = Get-ChildItem -File @DirParams |
                Where-Object -FilterScript $DateFilter
        } else {
            $files = Get-ChildItem @DirParams |
                Where-Object { -not $_.PSIsContainer } |
                Where-Object -FilterScript $DateFilter
        }

        $files | Remove-Item @RemoveParams # -ErrorAction Stop
    }
}
