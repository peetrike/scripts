#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.2.0
    .GUID 508c2641-1b33-4ea7-b6db-ef7eaffa6433

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2018.  All rights reserved.

    .TAGS compress, log

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES Microsoft.Powershell.Archive
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.2.0] - 2020-05-04 - Now, -Months filters out files from beginning of month, not from current day in month
        [1.1.6] - 2018-12-28 - fixed problem with Compress-Archive: archive file was deleted if no files found to compress
        [1.1.5] - 2018-12-28 - changed 7-zip discovery and comment-based help
        [1.1.4] - 2018-10-15 - changed 7-Zip command line and added 7-zip process exit status check
        [1.1.3] - 2018-10-15 - changed -Days and -Months parameters
        [1.1.2] - 2018-10-15 - changed examples in help
        [1.1.1] - 2018-10-15 - changed lastwritetime filter for -Days parameter.  it now includes days equal or greater than -Days parameter
        [1.1.0] - 2018-10-15 - added parameter -Months and removed parameter -Interval
        [1.0.2] - 2018-10-15 - modified -Filter parameter
        [1.0.1] - 2018-10-15 - modified comment-based help
        [1.0.0] - 2018-10-15 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Compress old log files

    .DESCRIPTION
        This script will compress all files that are older than specified number of days (or months) to archive file.

    .EXAMPLE
        PS C:\> Compress-OldLog.ps1 -Days 30
        This command compresses all files older than 30 days in current directory.

    .EXAMPLE
        PS C:\> Compress-OldLog.ps1 -Path c:\logs -Filter *.log
        This command compresses log files (*.log) from path c:\logs.

    .EXAMPLE
        PS C:\> Get-ChildItem c:\logs | Compress-OldLog.ps1 -Months 3 -Filter *.log
        This command compresses all *.log files older than 3 months in subfolders under path c:\logs.

    .INPUTS
        Files to be compressed

    .OUTPUTS
        None

    .NOTES
        This command stops without processing files, if there is no archiver.  Supported archivers are:
            Powershell 5.0 or newer (Compress-Archive)
            7-Zip

    .LINK
        Compress-Archive https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Archive/Compress-Archive
        7-Zip http://7-zip.org
#>

[CmdLetBinding()]
Param(
        [parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [ValidateScript( {
            if (Test-Path -Path $_) { $true }
            else {
                throw (New-Object -TypeName 'System.Management.Automation.ItemNotFoundException' -ArgumentList "Path not found: $_")
            }
        })]
        [Alias('FullName')]
        [string[]]
        # Specifies the path or paths to the files that you want to compress.  Wildcards are permitted.  The default location is the current directory (.).
    $Path = $PWD,
        [string]
        # Specifies a filter in the provider's format or language.  The value of this parameter qualifies the Path parameter.
    $Filter,
        [parameter(
            ParameterSetName = 'Days'
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        # Specifies how many days old files will be compressed.  The default is 90 days.  Archive name contains full date.
    $Days = 90,
        [parameter(
            Mandatory = $true,
            ParameterSetName = 'Months'
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        # Specifies how many months old files will be compressed.  Archive name contains ony year and month.
    $Months,
        [switch]
        # Indicates that this cmdlet gets the items in the specified locations and in all child items of the locations.
    $Recurse
)

begin {
    $7ZipPath = Get-ItemProperty -Path HKLM:\software\7-Zip -Name Path* -ErrorAction SilentlyContinue

    if (Get-Command -Name Compress-Archive -ErrorAction SilentlyContinue) {
        $archiver = 'Powershell'
    } elseif ($7ZipPath) {
        $archiver = '7-zip'
        if ($7ZipPath.Path64) { $7ZipPath = Join-Path -Path $7ZipPath.Path64 -ChildPath '7z.exe' }
        else { $7ZipPath = Join-Path -Path $7ZipPath.Path -ChildPath '7z.exe' }

        if ( -not (Test-Path -Path $7ZipPath)) {
            throw (New-Object -TypeName 'System.Management.Automation.ItemNotFoundException' -ArgumentList '7-Zip not found, aborting')
        }
    } else {
        throw (New-Object -TypeName 'System.Management.Automation.ItemNotFoundException' -ArgumentList 'No archiver detected, aborting')
    }

    Write-Verbose -Message ('Using archiver: {0}' -f $archiver)
    $DirParams = @{ }
    if ($Filter) {
        $DirParams.Filter = $Filter
    }
    if ($Recurse) {
        $DirParams.Recurse = $true
    }
    if ($PSCmdlet.ParameterSetName -eq 'Months') {
        $MonthsAgo = ([datetime]::Today).AddMonths(-$Months)
        $MonthsAgo = $MonthsAgo.AddDays(1-$MonthsAgo.Day)
        $DateFilter = { $_.lastwritetime -le $MonthsAgo }
        $archiveFileName = '{0:yyyy-MM}.zip' -f $MonthsAgo.AddMonths(-1)
    } else {
        $DateFilter = { ($_ | New-TimeSpan).Days -ge $Days }
        $archiveFileName = '{0:yyyy-MM-dd}.zip' -f ([datetime]::Now).AddDays(-$Days)
    }
}

process {
    Write-Verbose -Message ('Processing path {0}' -f $Path)
    $DirParams.Path = $Path

    if ($PSVersionTable.PSVersion -ge '3.0') {
        $files = Get-ChildItem -File @DirParams |
            Where-Object -FilterScript $DateFilter
    } else {
        $files = Get-ChildItem @DirParams |
            Where-Object { -not $_.PSIsContainer } |
            Where-Object -FilterScript $DateFilter
    }

    if ((Test-Path -Path $Path -PathType Container) -and (@($Path).Count -eq 1) ) {
        $archivePath = Join-Path -Path $Path -ChildPath $archiveFileName
    } elseif (@($Path).Count -eq 1) {
        $archivePath = Join-Path -Path (Split-Path -Path $Path -Parent) -ChildPath $archiveFileName
    }
    Write-Verbose -Message ('compressing to archive: {0}' -f $archivePath)

    $CallerErrorActionPreference = $ErrorActionPreference
    switch ($archiver) {
        '7-zip' {
            $ErrorActionPreference = 'Stop'
            $files | ForEach-Object {
                try {
                    Write-Verbose -Message ('Processing file: {0}' -f $_.Name)
                    & $7ZipPath a "$archivePath" ('{0}' -f $_.FullName)
                    if (-not $LASTEXITCODE) { Remove-Item -Path $_.FullName }
                } catch {
                    Write-Error -ErrorRecord $_ -ErrorAction $CallerErrorActionPreference
                }
            }
            $ErrorActionPreference = $CallerErrorActionPreference
        }
        'Powershell' {
            $CompressParams = @{
                DestinationPath = $archivePath
            }
            if (Test-Path -Path $archivePath) {
                $CompressParams.Update = $true
            }
            if ($files) {
                try {
                    $files | Compress-Archive @CompressParams -ErrorAction Stop
                    $files | Remove-Item -ErrorAction Stop
                } catch {
                    Write-Error -ErrorRecord $_ -ErrorAction $CallerErrorActionPreference
                }
            }
        }
    }
}
