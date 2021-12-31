#Requires -Version 2.0
# Requires -RunAsAdministrator

<#
    .NOTES
        ## TcpipNetbiosOptions

        - Data type: uint32
        - Access type: Read-only

        Bitmap of the possible settings related to NetBIOS over TCP/IP. Values are identified in the following list.

        - EnableNetbiosViaDhcp (0)
        - EnableNetbios (1)
        - DisableNetbios (2)

    .LINK
        https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-networkadapterconfiguration
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
    [bool]
    $UseCim = [bool] (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
)

function Test-IsAdmin {
    [CmdletBinding()]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw (New-Object -TypeName System.Management.Automation.PSSecurityException -ArgumentList "Admin Privileges required")
}

#region through registry
<# $regkey = "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces"
Get-ChildItem -Path $regkey |
    ForEach-Object {
        $_.SetValue('NetbiosOptions', 2)
    } #>
#endregion

$filter = 'IPEnabled=TRUE and TcpipNetbiosOptions!=2'
$ClassName = 'Win32_NetworkAdapterConfiguration'


$adapters = if ($UseCim) {
    Write-Verbose -Message 'Using CIM cmdlets'
    Get-CimInstance -ClassName $ClassName -Filter $filter -Verbose:$false
    $CimProps = @{
        MethodName = 'SetTcpipNetbios'
        Arguments  = @{ TcpipNetbiosOptions = 2 }
        Confirm    = $false
    }
} else {
    Write-Verbose -Message 'Using WMI cmdlets'
    Get-WmiObject -Class $ClassName -Filter $filter
}

foreach ($adapter in $adapters) {
    # Write-Verbose -Message ('Setting adapter {0}' -f $adapter.Caption)
    if ($PSCmdlet.ShouldProcess($adapter.caption, "Disable NBT")) {
        $result = if ($UseCim) {
            $adapter | Invoke-CimMethod @CimProps
        } else {
            $adapter.SetTcpipNetbios(2)
        }
        switch ($result.ReturnValue) {
            0 {
                # ok
            }
            1 {
                Write-Warning -Message ('Restart is required for adapter {0}' -f $adapter.Caption)
            }
            Default {
                Write-Error -Message ('An error {0} occured' -f $result.ReturnValue)
            }
        }
    }
}
