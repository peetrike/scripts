#Requires -version 2.0

[CmdletBinding()]
param (
        [ValidateSet('Isatap', '6to4', 'Teredo', 'All')]
        [string[]]
    $Protocol = 'All'
)


function Get-IPv6Tunnel {
    [CmdletBinding()]
    param (
            [ValidateSet('Isatap', '6to4', 'Teredo', 'All')]
            [string[]]
        $Protocol = 'All'
    )

    $OsVersion = [Environment]::OSVersion.Version.Major
    $UsePS = [bool] (Get-Module NetworkTransition -ListAvailable)
    if ($Protocol -like 'All') {
        $Protocol = 'Isatap', '6to4', 'Teredo'
    }
    function Get-NetshState {
        [CmdletBinding()]
        param (
                [string]
            $Protocol
        )
        $Pattern = '{0}\s+: (\w+)' -f ('State', 'Type')[$Protocol -like 't*']
        $Result = (
            'interface {0} show state' -f $Protocol |
                netsh.exe |
                Select-String $Pattern
        ).Matches
        ($Result | Select-Object -ExpandProperty Groups)[1].Value
    }

    $Result = @{}
    switch ($Protocol) {
        'Isatap' {
            $Result.$_ = if ($UsePS) {
                (Get-NetIsatapConfiguration).State
            } elseif ($OsVersion -gt 5) {
                Get-NetshState -Protocol $_
            } else { 'not present' }
        }
        '6to4' {
            $Result.$_ = if ($UsePS) {
                (Get-Net6to4Configuration).State
            } elseif ($OsVersion -gt 5) {
                Get-NetshState -Protocol $_
            } else { 'not present' }
        }
        'Teredo' {
            $Result.$_ = if ($UsePS) {
                (Get-NetTeredoConfiguration).Type
            } elseif ($OsVersion -gt 5) {
                Get-NetshState -Protocol $_
            } else { 'not present' }
        }
    }

    New-Object psobject -Property $Result
}

Get-IPv6Tunnel @PSBoundParameters
