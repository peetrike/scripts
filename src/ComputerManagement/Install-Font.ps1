<#
.SYNOPSIS
    A short one-line action-based description, e.g. 'Tests if a function is valid'
.DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
.NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [ValidateScript({
            Test-Path -Path $_ -PathType Leaf
        })]
        [Alias('FullName')]
        [string]
    $FontFile,
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]
    $Scope = 'CurrentUser'
)

begin {
    Add-Type -AssemblyName PresentationCore

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
            $RegPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            $TargetPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\Fonts'
        }
        'AllUsers' {
            if (-not (Test-IsAdmin)) {
                $Exception = [Management.Automation.PSSecurityException] 'Admin Privileges required'
                throw $Exception
            }
            $RegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            $TargetPath = Join-Path -Path $env:windir -ChildPath 'Fonts'
        }
    }

    $confirmOff = @{
        Confirm = $false
    }
}

process {
    $FontItem = Get-Item -Path $FontFile
    $typeFace = [Windows.Media.GlyphTypeface] [uri] $FontFile
    # $FontFamily = [Windows.Media.Fonts]::GetFontFamilies($FontFile)
    $FamilyName = Get-FontName -Name $typeFace.Win32FamilyNames
    $FaceName = Get-FontName -Name $typeFace.Win32FaceNames
    $FontType = switch ($FontItem.Extension) {
        '.ttf' { 'TrueType' }
        '.otf' { 'OpenType' }
        default {
            Write-Error -Message ('Unknown font extension: {0}' -f $_)
            return
        }
    }
    $FontName = '{0} {1} ({2})' -f $FamilyName, $FaceName, $FontType

    $TargetName = Join-Path -Path $TargetPath -ChildPath $FontItem.Name
    if (Test-Path -Path $TargetName -PathType Leaf) {
        Write-Verbose -Message ('Font "{0}" already exists' -f $FontName)
        return
    }

    if ($PSCmdlet.ShouldProcess($FontName, 'Install font')) {
        Copy-Item -Path $FontFile -Destination $TargetPath @confirmOff
        Set-ItemProperty -Path $RegPath -Name $FontName -Value $FontItem.Name -Type String @confirmOff
    }
}
