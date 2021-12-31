#Requires -Version 2

param(
        [Parameter(
            Mandatory=$false,
            Position=0
        )]
        [ValidateSet('MyPictures', 'CommonPictures', 'System')]
        [String]
    $Target = 'CommonPictures'
    ,
        [Alias('Picture')]
        [String]
    $WallPaper = ''
<#    ,
        [String]
    $Style = ''#>
)

switch -Wildcard ($Target) {
    'system' {
        $PicturesPath = Join-Path -Path $env:windir -ChildPath 'Web\Wallpaper'
    }
    Default {
        $PicturesPath = [System.Environment]::GetFolderPath($Target)
    }
}
$PictureExtension = '*.jpg'

    # specify wallpaper filename
if (-not $WallPaper) {
    $WallPaper = Get-ChildItem -Recurse -Path $PicturesPath -Include $PictureExtension |
        Get-Random -Count 1 |
        Select-Object -ExpandProperty FullName
} else {
    $WallPaper = Join-Path -Path $PicturesPath -ChildPath $WallPaper
}

<#
switch ($Style) {

}
Set-ItemProperty -path 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperStyle'
Set-ItemProperty -path 'HKCU:\Control Panel\Desktop\' -Name 'TileWallpaper'
#>

try {
    $WP = [Wallpaper.Setter]
} catch {
    $WP = Add-Type -TypeDefinition @'
    using System;
    using System.Runtime.InteropServices;
    using Microsoft.Win32;
    namespace Wallpaper {
        public class Setter {
            public const int SetDesktopWallpaper = 20;
            public const int UpdateIniFile = 0x01;
            public const int SendWinIniChange = 0x02;

            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
            private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);

            public static void SetWallpaper ( string path ) {
                SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
            }
        }
    }
'@ -Passthru

    $WP = [Wallpaper.Setter]
}

Write-Verbose -Message "Installing wallpaper $WallPaper"
# Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name 'Wallpaper' -Value $WallPaper

    # updating the user settings
# rundll32.exe user32.dll, UpdatePerUserSystemParameters
$WP::SetWallpaper($WallPaper)
