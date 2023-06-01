<#
    .SYNOPSIS
        Sample script that downloads files using WinSCP
    .DESCRIPTION
        This script downloads files using WinSCP .NET component
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        https://winscp.net/eng/docs/library_powershell#example
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

[CmdletBinding(SupportsShouldProcess)]
param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
    $HostName,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
    $UserName,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
    $Password,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
    $SshHostKeyFingerprint,
    $LocalPath = $PWD,
    $RemotePath = '/',
    $Pattern = '*',
    $LogFilePath = (Join-Path -Path $PWD -ChildPath 'download.log')
)

begin {
    function Write-Log {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
                [Parameter(Position = 0, ValueFromPipeline = $true)]
                [string]
            $Message,
                [Parameter(Position = 1)]
                [string]
            $Log = ".\Log.txt"
        )

        process {
            Write-Verbose $Message

            if ($WriteLog -or $Message) {
                if ($LogFilePath) {
                    $LogFile = $LogFilePath
                } else {
                    $LogFile = $Log
                }

                "$(Get-Date) $Message" | Out-File -FilePath $LogFile -Append
            }
        }
    }
}

process {
    $RegPath = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\winscp*'
    $assemblyPath = if ($env:WINSCP_PATH) {
        $env:WINSCP_PATH
    } elseif (Test-Path -Path $RegPath) {
        (Get-ItemProperty -Path $RegPath).InstallLocation
    } else { $PSScriptRoot }
    $AssemblyFile = Join-Path -Path $assemblyPath -ChildPath 'WinSCPnet.dll'

    try {
        Add-Type -Path $AssemblyFile

        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
        $sessionOptions.HostName = $HostName
        $sessionOptions.UserName = $UserName
        $sessionOptions.Password = $Password
        $sessionOptions.SshHostKeyFingerprint = $SshHostKeyFingerprint

        $session = New-Object WinSCP.Session
        $session.Open($sessionOptions)

        $directoryInfo = $session.ListDirectory($remotePath)
        $File = $directoryInfo.Files | Where-Object { (-Not $_.IsDirectory) -and $_.Name -like $pattern }

        foreach ($f in $File) {
            ('Downloading file: {0}{1}' -f $remotePath, $f.Name) | Write-Log

            $session.GetFiles($session.EscapeFileMask($remotePath + $f.Name), $localPath).Check()
            $filepath = Join-Path $localPath "$($f.Name)"

            if (Test-Path $filepath) {
                ('The file is downloaded to {0}' -f $filepath) | Write-Log

                if ((Get-ChildItem $filepath).Length -eq $f.Length) {
                    ('The downloaded file lenght {0} is the same as in FTP server' -f (Get-ChildItem $filepath).Length) | Write-Log
                    $session.RemoveFiles($session.EscapeFileMask($remotePath + $f.Name)) | Write-Log
                }
            }
        }
    } catch [Exception] {
        $_.Exception.Message
    } finally {
        $session.Dispose()
    }
}
