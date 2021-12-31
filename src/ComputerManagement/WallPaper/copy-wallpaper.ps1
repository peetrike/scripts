#Requires -Version 2

param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            HelpMessage='Provide path for pictures to be copied'
        )]
        [Alias('SourcePath')]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [String]
    $Path
    ,
        [ValidateSet('MyPictures','CommonPictures','System')]
        [String]
    $Target = 'CommonPictures'
    ,
        [String]
    $Filter = '*.jpg'
)

switch -Wildcard ($Target) {
    'system' {
        $PicturesPath = Join-Path -Path $env:windir -ChildPath 'Web\Wallpaper'
    }
    Default {
        $PicturesPath = [Environment]::GetFolderPath($Target)
    }
}

    # copy pictures, if needed
robocopy.exe $Path $PicturesPath $Filter --% /v /njh /njs /r:0
