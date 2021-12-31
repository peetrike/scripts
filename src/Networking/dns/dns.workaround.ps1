#Requires -Version 2.0

[CmdletBinding(
    SupportsShouldProcess = $true
)]
param (
        [Parameter()]
        [ValidateSet('Enable', 'Disable')]
        [string]
    $Action = 'Enable',
        [switch]
    $NoRestart,
        [switch]
    $Force
)

$Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\DNS\parameters'
$Property = 'TcpReceivePacketSize'
# Get-ItemProperty -Path $key -Name $Property

if (get-service -Name dns -ErrorAction SilentlyContinue) {
    if ($PSCmdlet.ShouldProcess('DNS Server', 'Apply workaround')) {
        switch ($Action) {
            'Enable' {
                if (-not (Get-ItemProperty -Path $key -Name $Property -ErrorAction SilentlyContinue)) {
                    New-ItemProperty  -Path $Key -Name $Property -Value 0xff00 -Verbose:$false
                } else {
                    if ($Force -or $PSCmdlet.ShouldContinue('The value already exists, overwrite?', 'Apply workaround')) {
                        Set-ItemProperty -Path $Key -Name $Property -Value 0xff00 -Verbose:$false
                    }
                }
            }
            'Disable' {
                if ($Force -or $PSCmdlet.ShouldContinue('Do you want to delete value from registry?', 'Removal')) {
                    Remove-ItemProperty -Path $Key -Name $Property
                }
            }
        }

        if (-not $NoRestart.IsPresent) {
            Restart-Service DNS
        }
    }
} else {
    Write-Warning 'DNS Server is not present in this server'
}
