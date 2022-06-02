#Requires -RunAsAdministrator

[CmdletBinding()]
param (
        [switch]
    $Restore
)

$DriveName = 'hkcr'

try {
    $null = Get-PSDrive -Name $DriveName -ErrorAction Stop
} catch {
    $null = New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name $DriveName
}


$RootPath = '{0}:\' -f $DriveName
$OriginalName = 'ms-msdt'
$NameSuffix = '_bak'
$BackupName = $OriginalName + $NameSuffix
$OriginalPath = $RootPath + $OriginalName
$BackupPath = $RootPath + $BackupName

if ($Restore.IsPresent) {
    if (Test-Path -Path $BackupPath ) {
        Rename-Item $BackupPath -NewName $OriginalName
        Set-ItemProperty -Path $OriginalPath -Name '(default)' -Value ('URL:{0}' -f $originalName)
    } else {
        Write-Verbose -Message 'Nothing to restore, backup path does not exist'
    }
} elseif (Test-Path -Path $OriginalPath ) {
    Rename-Item -Path $OriginalPath -NewName $BackupName
    Set-ItemProperty -Path $BackupPath -Name '(default)' -Value ('URL:{0}' -f $BackupName)
} else {
    Write-Verbose -Message 'Nothing to fix, protocol is not registered'
}
