<#PSScriptInfo

    .VERSION 1.0.1
    .GUID 5e8d2e80-f59a-4205-9160-f94b106f90dd

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2025.  All rights reserved.

    .TAGS font PSEdition_Core PSEdition_Desktop Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2025.08.06 - Initial Release
        [1.0.0] - 2025.05.30 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Installs fonts
    .DESCRIPTION
        This script installs fonts from specified path.  The Scope parameter determines where to install fonts.
    .NOTES
        This script runs only on Windows
    .INPUTS
        List of folders or font files
    .EXAMPLE
        .\Install-Font.ps1 -Path .\myfont.ttf

        This example installs font from current directory to CurrentUser scope
    .EXAMPLE
        .\Install-Font.ps1 -Path \\server\fonts -Scope AllUsers

        This example installs fonts from \\server\fonts directory to AllUsers scope
    .EXAMPLE
        Get-ChildItem -Path .\fonts | .\Install-Font.ps1 -Force

        This example installs fonts provided by Get-ChildItem cmdlet.
        Fonts are reinstalled, when already installed.
#>

[OutputType([void])]
[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Mandatory,
            Position = 0,
            HelpMessage = 'Please enter path to font or folder containing fonts',
            ValueFromPipelineByPropertyName
        )]
        [ValidateScript({
            Test-Path -Path $_
        })]
        [Alias('FullName')]
        [string]
        # Specifies path to font or folder containing fonts
    $Path,
        [switch]
        # Specifies that folders containing fonts should be searched recursively
    $Recurse,
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]
        # Specifies scope to install fonts
    $Scope = 'CurrentUser',
        [switch]
        # Reinstalls fonts, when already installed
    $Force
)

begin {
    Add-Type -AssemblyName PresentationCore

    function Test-IsAdmin {
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Role = [Security.Principal.WindowsBuiltinRole]::Administrator
        ([Security.Principal.WindowsPrincipal] $CurrentUser).IsInRole($Role)
    }
    function Get-FontName {
        [CmdletBinding()]
        param (
                [Parameter(
                    Mandatory
                )]
                [Collections.Generic.IDictionary[cultureinfo, string]]
            $Name
        )

        @(
            $PSCulture, 'en-us' | ForEach-Object { $Name[$_] }
            $Name.Values[0]
        ) | Select-Object -First 1
    }

    switch ($Scope) {
        'CurrentUser' {
            $regDrive = 'HKCU:'
            $TargetPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\Fonts'
        }
        'AllUsers' {
            if (-not (Test-IsAdmin)) {
                $Exception = [Management.Automation.PSSecurityException] 'Admin Privileges required'
                throw $Exception
            }
            $regDrive = 'HKLM:'
            $TargetPath = [System.Environment]::GetFolderPath('Fonts')
        }
    }
    $RegPath = $regDrive + '\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

    $confirmOff = @{
        Confirm = $false
    }
}

process {
    $FontItem = Get-Item -Path $Path
    $FontList = if ($FontItem.PSIsContainer) {
        Get-ChildItem -Path ($FontItem.FullName + '\*') -File -Include '*.ttf', '*.otf' -Recurse:$Recurse
    } else {
        $FontItem
    }
    foreach ($fontFile in $FontList) {
        #Write-Verbose -Message ('Installing font "{0}"' -f $fontFile.Name)
        $typeFace = [Windows.Media.GlyphTypeface] [uri] $fontFile.FullName
        $FamilyName = Get-FontName -Name $typeFace.Win32FamilyNames
        $FaceName = Get-FontName -Name $typeFace.Win32FaceNames
        $FontType = switch ($fontFile.Extension) {
            '.ttf' { 'TrueType' }
            '.otf' { 'OpenType' }
            default {
                Write-Error -Message ('Unknown font extension: {0}' -f $_)
                continue
            }
        }
        $FontName = '{0} {1} ({2})' -f $FamilyName, $FaceName, $FontType

        $TargetName = Join-Path -Path $TargetPath -ChildPath $fontFile.Name
        if ((Test-Path -Path $TargetName -PathType Leaf) -and -not $Force) {
            Write-Verbose -Message ('Font "{0}" already exists' -f $FontName)
            continue
        }

        if ($PSCmdlet.ShouldProcess($FontName, 'Install font')) {
            Copy-Item -Path $FontFile.FullName -Destination $TargetPath @confirmOff
            Set-ItemProperty -Path $RegPath -Name $FontName -Value $fontFile.Name -Type String @confirmOff
        }
    }
}
