#Requires -Version 3

<#PSScriptInfo
    .VERSION 1.1.2

    .GUID 2c86ee8e-5211-4268-8906-8e6b1b019858

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2018.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.2] - 2021.12.31 - Moved script to Github
        [1.1.1] - 2019.07.22 - Removed function Clear-TempFolder
        [1.1.0] - 2019.07.22 - Removed ChildPath and now lookin temp folder in every direct subfolder of Path
        [1.0.0] - 2019.07.22 - Initial release
        [0.0.1] - 2019.07.22 - Started work
    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Empties temp folders provided
    .DESCRIPTION
        This script empties temp folders provided from command line.
        Each path and every direct subfolder of it is combined with 'Temp'.
        If such folder is found, it is emptied.
#>

[CmdletBinding(
    SupportsShouldProcess
)]
Param(
        [parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateScript({
            Test-Path -Path $_ -PathType Container
        })]
        [Alias('FullName')]
        [string[]]
        # Specifies path to search for temp folder
    $Path
)

process {
    foreach ($folder in $Path) {
        Write-Verbose -Message ('Processing path {0}' -f $folder)
        $PathList = foreach ($subFolder in Get-ChildItem -Path $folder -Directory) {
            $MiddlePath = Join-Path -Path $folder -ChildPath $subFolder
            $EmptyPath = Join-Path -Path $MiddlePath -ChildPath 'Temp'
            if (Test-Path -Path $EmptyPath -PathType Container) {
                $EmptyPath
            }
        }
        $EmptyPath = Join-Path -Path $folder -ChildPath 'Temp'
        if (Test-Path -Path $EmptyPath -PathType Container) {
            $pathlist += $EmptyPath
        }
        if ($PathList) {
            foreach ($item in $PathList) {
                if ($PSCmdlet.ShouldProcess($item, 'Empty folder')) {
                    Get-ChildItem -Path $item -Recurse | Remove-Item -Recurse -Confirm:$false -WhatIf:$false
                }
            }
        }
    }
}
