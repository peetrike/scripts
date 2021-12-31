#Requires -Version 3
#Requires -Modules NTFSSecurity
# Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.0.2
    .GUID 12786da4-6394-4fa5-b9fc-82ed8853ec8f
    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS acl, folder, report
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES NTFSSecurity
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] 2020.07.16 - Added folders with Access Denied into report.
        [1.0.1] 2020.07.16 - Added confirmation about report file existing before starting.
                           - when passing several folders to script, result is appended to report file.
        [1.0.0] 2020.07.16 - First public release
        [0.0.1] 2019.01.08 - Start of work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates folder tree ACL report.

    .DESCRIPTION
        This script generates folder tree ACL report.

        All permissions are included for report root folder, but only explicitly defined
        (not inherited) permissions are included for subfolders.

    .EXAMPLE
        PS C:\> Get-FolderACL -Path .\source -ReportFile .\PermissionReport.csv

        This command generates report for path .\source.  Report is written to file PermissionReport.csv

    .EXAMPLE
        PS C:\> Get-Item c:\folder | Get-FolderACL -PassThru | Out-GridView

        This command generates report for path c:\folder and passes it to Out-GridView window

    .INPUTS
        String or System.IO.DirectoryInfo

        Folders that have to be included in report

    .OUTPUTS
        None or ACL report object collection (with -PassThru parameter)

    .NOTES
        When user running script doesn't have access to folder, then error is recorded on console,
        but not in report file.

    .LINK
        NTFSSecurity module: https://github.com/raandree/NTFSSecurity
        Get-ChildItem
#>

[CmdLetBinding()]
param (
        [parameter(
            Position = 0,
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
            Test-Path -Path $_ -PathType Container
        })]
        [SupportsWildcards()]
        [Alias('FullName', 'Source')]
        [string[]]
        # Folder to include in report
    $Path,
        [string]
        # .CSV report file path
    $ReportFile,
        [switch]
        # delete the pre-existing report file, don't ask permission
    $Force,
        [switch]
    $PassThru
)

begin {
    function Get-AceList {
        [CmdletBinding()]
        param (
                [string]
            $Path,
                [switch]
            $ExcludeInherited
        )

        try {
            $ACL = Get-NTFSAccess -Path $Path -ExcludeInherited:$ExcludeInherited.IsPresent -Verbose:$false -ErrorAction Stop
        } catch [System.UnauthorizedAccessException] {
            [PSCustomObject] @{
                Path              = $item.FullName
                AccountSid        = $null
                AccountName       = "Access denied, can't get ACL"
                AccessRights      = $null
                AccessControlType = $null
            }
        } catch {
            Write-Warning -Message 'Accessing ACL failed, retrying...'
            $ACL = Get-NTFSAccess -Path $Path -ExcludeInherited:$ExcludeInherited.IsPresent -Verbose:$false
        }
        foreach ($item in $ACL) {
            $ObjProperties = @{
                Path              = $item.FullName
                AccountSid        = [System.Security.Principal.SecurityIdentifier]$item.Account.Sid
                AccountName       = $item.Account.AccountName
                AccessRights      = $item.AccessRights
                AccessControlType = $item.AccessControlType
            }
            [PSCustomObject] $ObjProperties
        }
    }

    $RootPathItem = @{
        Name       = 'RootPath'
        Expression = { $FolderItem.FullName }
    }
    $RelativePathItem = @{
        Name       = 'RelativePath'
        Expression = { $RelativePath }
    }
    if ($ReportFile -and (Test-Path -Path $ReportFile -PathType Leaf)) {
        if ($Force -or $PSCmdlet.ShouldContinue('The report file already exists, overwrite?', 'Overwrite file')) {
            Remove-Item -Path $ReportFile -Force
        }
    }
}

process {
    $AceList = foreach ($item in $Path) {
        $RelativePath = ''
        $FolderItem = Get-Item2 -Path $item
        $ItemFullName = $FolderItem.FullName
        Write-Verbose -Message ('Processing folder root: {0}' -f $ItemFullName)
        Get-AceList -Path $FolderItem.FullName |
            Select-Object -Property *, $RootPathItem, $RelativePathItem -ExcludeProperty Path


        $FolderTree = Get-ChildItem2 -Path $item -Recurse -Directory
        foreach ($folder in $FolderTree) {
            $RelativePath = $folder.FullName.Replace($ItemFullName, '').TrimStart('\')
            Write-Verbose -Message ('Processing folder: {0}' -f $RelativePath)
            Get-AceList -Path $Folder.FullName -ExcludeInherited |
                Select-Object -Property $RootPathItem, $RelativePathItem, * -ExcludeProperty Path
        }
    }

    if ($ReportFile) {
        $AceList |
            Export-Csv -NoTypeInformation -UseCulture -Encoding Default -Path $ReportFile -Append
    }

    if ($PassThru) {
        $AceList
    }
}
