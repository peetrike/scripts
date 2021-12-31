#Requires -Version 2.0

[CmdletBinding()]
param(
        [String]
    $Id = '*',
        [String]
    $DisplayName = '*',
        [ValidateSet('CurrentUser', 'LocalMachine', 'Both')]
        [string[]]
    $Scope = 'LocalMachine'
)

function Get-InstalledSoftware {
    [CmdletBinding()]
    param(
            [String]
        $Id = '*',
            [String]
        $DisplayName = '*',
            [ValidateSet('CurrentUser', 'LocalMachine', 'Both')]
            [string[]]
        $Scope = 'LocalMachine'
    )

    function Get-RegPath {
        [CmdletBinding()]
        param (
                [ValidateSet('CurrentUser', 'LocalMachine', 'Both')]
                [string[]]
            $Scope = 'LocalMachine'
        )

        $PartialUninstallPath = @(
            'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
            'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
        if ($Scope -eq 'Both') { $Scope = 'CurrentUser', 'LocalMachine' }

        $root = switch ($Scope) {
            'CurrentUser' {
                'HKCU:'
            }
            'LocalMachine' {
                'HKLM:'
            }
        }
        $PartialUninstallPath |
            ForEach-Object { Join-Path -Path $root -ChildPath $_ } |
            Where-Object { Test-Path -Path $_ }
    }

    $SelectProperty = @(
        'DisplayName'
        'DisplayVersion'
        'EstimatedSize'
        'InstallDate'
        'InstallSource'
        #'InstanceId'
        'Language'
        'Publisher'
        'UninstallString'
    )
    $TypeName = 'CustomObject.InstalledSoftware'

    $UninstallRegistryKey = foreach ($p in Get-RegPath -Scope $Scope) {
        Get-ChildItem -Path $p |
            Where-Object { $_.PSChildName -like "*$Id" } |
            ForEach-Object {
                $_.name -replace $_.name.split('\')[0], ('{0}:' -f $_.psdrive)
            }
    }
    foreach ($key in $UninstallRegistryKey) {
        $InstalledSoftware = Get-ItemProperty $key

        if ($InstalledSoftware.DisplayName -like $DisplayName) {
            $keyId = $key.Split('\')[-1]
            $KeyProperties = @{
                'PSPath' = $key
                'Id'     = $keyId
            }

            Write-Verbose ('Getting installed software: {0}  Id: "{1}"' -f $InstalledSoftware.DisplayName, $keyId)
            foreach ($Property in $SelectProperty) {
                if ($InstalledSoftware."$Property") {
                    if ($Property -like 'InstallDate') {
                        try {
                            $dateValue = [datetime]('{0:0000\.00\.00}' -f [int]$InstalledSoftware."$Property")
                        } catch {
                            Write-Verbose -Message $_.Exception.Message
                            $dateValue = $null
                        }
                        $KeyProperties.Add($Property, $dateValue)
                    } else {
                        $KeyProperties.Add($Property, $InstalledSoftware."$Property")
                    }
                } else { $KeyProperties.Add($Property, $null) }
            }

            if ($PSVersionTable.PSVersion.Major -eq 2) {
                $Object = New-Object PSObject -Property $KeyProperties
                $Object.psobject.TypeNames.Insert(0, $TypeName)
                $Object
            } else {
                $KeyProperties.PSTypeName = $TypeName
                [PSCustomObject] $KeyProperties
            }
        }
    }
}

Get-InstalledSoftware @PSBoundParameters
