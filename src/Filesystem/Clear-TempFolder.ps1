#Requires -Version 3.0

<#PSScriptInfo
    .VERSION 1.0.1

    .GUID c8542676-35df-4e9b-b8e9-b303af5ca4dc

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2021.12.31 - Moved script to Github
        [0.0.1] - 2019.07.22 - Started work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Empties temp folders provided

    .DESCRIPTION
        This script empties temp folders provided
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
    $Path,
        [switch]
        # Specifies, that temp folders from environment variables should be also processed
    $IncludeEnvironment
)


function Clear-TempFolder {
    # [OutputType([String])]
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
        $Path,
            [switch]
            # Specifies, that temp folders from environment variables should be also processed
        $IncludeEnvironment
    )

    begin {
        if ($IncludeEnvironment.IsPresent) {
            $Path += $env:TEMP, $env:TMP
        }
        $Path = $Path | Sort-Object -Unique
    }

    process {
        foreach ($item in $path) {
            if ($PSCmdlet.ShouldProcess($item, 'Empty folder')) {
                Get-ChildItem -Path $item -Recurse | Remove-Item -Recurse -Confirm:$false -WhatIf:$false
            }
        }
    }
}

Clear-TempFolder @PSBoundParameters
