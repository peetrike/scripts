#Requires -Version 2

<#
    .SYNOPSIS
        Sample script that downloads files using WinSCP
    .DESCRIPTION
        This script downloads files using WinSCP .NET component
    .NOTES
        You need installed WinSCP or Assembly .DLL from https://winscp.net/eng/docs/library_install
    .LINK
        https://winscp.net/eng/docs/library_powershell#example
    .EXAMPLE
        Get-Content .\connection.json | ConvertFrom-Json | .\Invoke-WinSCPdl.ps1
        Take connection details from .json file and pass them to script
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
            $Log = $LogFilePath
        )

        process {
            if ($Message) {
                Write-Verbose $Message
                $LogMessage = '{0} - {1}' -f [datetime]::Now, $Message
                $LogMessage | Out-File -FilePath $Log -Append
            }
        }
    }

}

process {
        #determine, where the Assembly is installed
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
        $File = $directoryInfo.Files | Where-Object { (-Not $_.IsDirectory) -and $_.Name -like $Pattern }

        foreach ($f in $File) {
            ('Downloading file: {0}{1}' -f $remotePath, $f.Name) | Write-Log

            $RemoteFileName = $session.EscapeFileMask($remotePath + $f.Name)
            $session.GetFiles($RemoteFileName, $localPath).Check()
            $filepath = Join-Path $localPath $f.Name

            if (Test-Path $filepath) {
                ('The file is downloaded to {0}' -f $filepath) | Write-Log

                $fileSize = (Get-Item $filepath).Length
                if ($fileSize -eq $f.Length) {
                    ('The downloaded file length {0} is the same as in FTP server' -f $fileSize) | Write-Log
                    $session.RemoveFiles($RemoteFileName) | Write-Log
                }
            }
        }
    } catch {
        $_.Exception.Message
    } finally {
        $session.Dispose()
    }
}
