#Requires -Version 3
#Requires -Modules NTFSSecurity
#Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.1.5
    .GUID c38bc73d-e9d7-4775-a60f-779d5cc44ebd
    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.
    .TAGS acl, sync, folder
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES NTFSSecurity

    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2019.07.11 Start of work
        [1.0.0] - 2019.07.15 Initial release
        [1.0.1] - 2019.07.15 Fixed setting owner
        [1.1.0] - 2019.07.15 Added -AdminAccount parameter
        [1.1.1] - 2019.07.16 Added existing permission check if -AdminAccount parameter is present
        [1.1.2] - 2019.08.23 Fixed:
                    * using -AdminAccount
                    * using -CopyProfile
                    * changed processing of long paths
        [1.1.3] - 2019.08.23 Fixed non-existing command New-Item2
        [1.1.4] - 2019.08.23 Changed:
                    * reduced PS Version requirement to 3.0
                    * refactored destination folder path calculation
                    * added double-check before disabling inheritance on terget path
                    * added retry on obtaining source folder ACL / Inheritance
        [1.1.5] - 2019.10.29 Copy-Acl - added check for bypassing not resolved SIDs

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Synchronizes folder tree from remote file share to local disk

    .DESCRIPTION
        This script synchronizes folder tree from remote file share to local disk.
        Only folders and folder ACL-s are synchronized.

        If MigrationTable is specified, then during synchronization the ACL-s are
        translated using migration table.

        If AdminAccount is specified, then that account will be added with
        Full Control permission to root folder and all folders,
        where inheritance is denined.

    .EXAMPLE
        PS C:\> Sync-FolderTree -Path .\source -Destination d:\folder

        This command copies folder tree from .\source to d:\folder

    .EXAMPLE
        PS C:\> Sync-FolderTree -Path .\source -MigrationTable c:\mt.csv

        This command copies folder tree from .\source to current directory,
        using migration table c:\mt.scv

    .EXAMPLE
        PS C:\> Sync-FolderTree -Path .\source -CopyOwner

        This command copies folder tree from .\source to current directory
        and adjusts the owner of new folders the same as source folders

    .EXAMPLE
        PS C:\> Sync-FolderTree -Path .\source -AdminAccount Domain\FileServerAdmin

        This command copies folder tree from .\source to current directory
        and adds Full Control permissions to Domain\FileServerAdmin account.

    .INPUTS
        String or System.IO.DirectoryInfo

        Folders that have to be synchronized

    .OUTPUTS
        None

    .NOTES
        The migration table is CSV file that should contain at least following columns:
            - SourceSid
            - DestinationName
        If DestinationName is domain account/group, the name should be prefixed by 'Domain\'.
        During synchronization, the discovered ACE account SID is replaced by DestinationName,
        if found in migration table.

        If source root folder has only inherited ACEs, then no permissions will be copied.

    .LINK
        NTFSSecurity module: https://github.com/raandree/NTFSSecurity
        Get-ChildItem
#>

[CmdLetBinding(
    SupportsShouldProcess
)]
Param(
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
        # Source folder to synchronize
    $Path,
        [parameter(
            Position = 1
        )]
        [ValidateScript( {
            Test-Path -Path $_ -PathType Container
        })]
        [PSDefaultValue(Help = 'Current Directory')]
        [string]
        # destination folder, where to sync fonder hierarhy
    $Destination = $PWD,
        [ValidateScript( {
            Test-Path -Path $_ -PathType Leaf
        })]
        [Alias('MT')]
        [string]
        # Optional migration table to translate foregin SIDs to user accounts
    $MigrationTable,
        [switch]
        # Specifies, that owner of original directory must be added to destination
    $CopyOwner,
        [string[]]
        # Specifies user account to whom will be given Full Control access
    $AdminAccount
)

begin {
    function Copy-Acl {
        [cmdletbinding()]
        param (
                [string]
            $Path,
                [string]
            $Destination,
                [Object[]]
            $MigrationTable,
                [switch]
            $CopyOwner,
                [string[]]
            $AdminAccount
        )

        try {
            $ACL = Get-NTFSAccess -Path $Path -ExcludeInherited -Verbose:$false -ErrorAction Stop
        } catch {
            Write-Warning -Message 'Accessing ACL failed, retrying...'
            $ACL = Get-NTFSAccess -Path $Path -ExcludeInherited -Verbose:$false
        }
        foreach ($item in $ACL) {
            $NewAccount = $null
            if ($MigrationTable) {
                $NewAccount = ($MigrationTable | Where-Object SourceSid -like $item.Account.Sid).DestinationName
            }
            if (-not $NewAccount) {
                $NewAccount = $item.Account.AccountName
            }
            if ($NewAccount) {
                Write-Verbose -Message ('Adding account {0}' -f $NewAccount)
                $AccessParams = @{
                    Path             = $Destination
                    Account          = $NewAccount
                    AccessRights     = $item.AccessRights
                    AccessType       = $item.AccessControlType
                    InheritanceFlags = $item.InheritanceFlags
                    PropagationFlags = $item.PropagationFlags
                }
                Add-NTFSAccess @AccessParams -Verbose:$false
            }
        }

            # inheritance should be taken away after adding permissions,
            # otherwise Add-NTFSAccess gets 'Acess Denied' error
        try {
            $Inheritance = Get-NTFSInheritance -Path $Path -ErrorAction Stop -Verbose:$false
        } catch {
            Write-Warning -Message 'Accessing inheritance failed, retrying...'
            $Inheritance = Get-NTFSInheritance -Path $Path -Verbose:$false
        }
        if ($Inheritance -and (-not $Inheritance.AccessInheritanceEnabled)) {
            if ($AdminAccount) {
                Write-Verbose -Message ('COPY-ACL: Adding Admin rights to account {0}' -f $AdminAccount)
                Add-NTFSAccess -Path $Destination -Account $AdminAccount -AccessRights FullControl -Verbose:$false
            }
            Write-Verbose -Message ('Removing inheritance from {0}' -f $Destination)
            Disable-NTFSAccessInheritance -Path $Destination -RemoveInheritedAccessRules -Verbose:$false
        }

        if ($CopyOwner) {
            try {
                $oldOwner = (Get-NTFSOwner -Path $Path -Verbose:$false -ErrorAction Stop).Owner
            } catch {
                Write-Warning -Message 'Accessing owner failed, retrying...'
                $oldOwner = (Get-NTFSOwner -Path $Path -Verbose:$false).Owner
            }
            if ($MigrationTable) {
                $NewOwner = ($MigrationTable | Where-Object SourceSid -like $oldOwner.Sid).DestinationName
            }
            if (-not $NewOwner) {
                $NewOwner = $oldOwner
            }
            Write-Verbose -Message ('Setting owner {0}' -f $NewOwner)

            Set-NTFSOwner -Path $Destination -Account $NewOwner -Verbose:$false
        }
    }

    $aclParams = @{
        CopyOwner = $CopyOwner
    }
    if ($AdminAccount) {
        $aclParams.AdminAccount = $AdminAccount
    }
    if ($MigrationTable) {
        $MigTable = Import-Csv -Path $MigrationTable -UseCulture -Encoding UTF8
        if ($MigTable) {
            $aclParams.MigrationTable = $MigTable
        }
    }
}

process {
    foreach ($item in $Path) {
        $FolderItem = Get-Item2 -Path $item
        $ItemFullName = $FolderItem.FullName
        Write-Verbose -Message ('Processing source folder {0}' -f $item)
        $destinationItem = Join-Path -Path $Destination -ChildPath $FolderItem.Name
        if (-not (Test-Path2 -Path $destinationItem -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($destinationItem, 'Create folder')) {
                $null = New-Item -Path $destinationItem -ItemType Directory -Confirm:$false -WhatIf:$false
            }
        }
        $aclParams.Path = $ItemFullName
        $aclParams.Destination = $destinationItem
        if ($PSCmdlet.ShouldProcess($destinationItem, 'Copy ACL')) {
            Copy-Acl @aclParams
        }
        try {
            $Inheritance = Get-NTFSInheritance -Path $ItemFullName -ErrorAction Stop -Verbose:$false
        } catch {
            Write-Warning -Message 'Accessing inheritance failed, retrying...'
            $Inheritance = Get-NTFSInheritance -Path $ItemFullName -Verbose:$false
        }
        if ($AdminAccount -and $Inheritance.AccessInheritanceEnabled) {
            try {
                $CurrentPermissionSet = Get-NTFSAccess -Account $AdminAccount -Path $destinationItem -ErrorAction Stop -Verbose:$false
            } catch {
                $CurrentPermissionSet = Get-NTFSAccess -Account $AdminAccount -Path $destinationItem -Verbose:$false
            }
            if ((-not $CurrentPermissionSet) -or ($CurrentPermissionSet.AccessRights -notlike 'FullControl') ) {
                Write-Verbose -Message ('Adding Admin rights to {0}' -f $AdminAccount)
                Add-NTFSAccess -Path $destinationItem -Account $AdminAccount -AccessRights FullControl -Verbose:$false
            } else {
                Write-Verbose -Message ('Admin account {0} already has full access' -f $AdminAccount)
            }
        }

        $FolderTree = Get-ChildItem2 -Path $item -Recurse -Directory
        foreach ($folder in $FolderTree) {
            $RelativePath = $folder.FullName.Replace($ItemFullName, '').TrimStart('\')
            Write-Verbose -Message ('Operating with {0}' -f $RelativePath)
            $NewPath = Join-Path -Path $destinationItem -ChildPath $RelativePath
            if (-not (Test-Path2 -Path $NewPath -PathType Container)) {
                if ($PSCmdlet.ShouldProcess($NewPath, 'Create folder')) {
                    $null = New-Item -Path $NewPath -ItemType Directory -Confirm:$false -WhatIf:$false
                }
            }
            if ($PSCmdlet.ShouldProcess($NewPath, 'Copy ACL')) {
                $aclParams.Path = $folder.FullName
                $aclParams.Destination = $NewPath
                Copy-Acl @aclParams
            }
        }
    }
}
