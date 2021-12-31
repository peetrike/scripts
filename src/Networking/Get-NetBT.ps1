#Requires -Version 2

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

[CmdletBinding()]
param ()

$filter = 'IPEnabled=TRUE and TcpipNetbiosOptions!=2'
$ClassName = 'Win32_NetworkAdapterConfiguration'

if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    Write-Verbose -Message 'Using CIM cmdlets'
    $AdapterName = @{
        Name = 'Name'
        Expression = {
            (Get-CimAssociatedInstance -InputObject $_ -Verbose:$false).NetConnectionId
        }
    }
    $CommandParams = @{
        ClassName = $ClassName
        Filter    = $filter
        Verbose   = $false
    }
    $Command = Get-Command Get-CimInstance
} else {
    Write-Verbose -Message 'Using WMI cmdlets'
    $AdapterName = @{
        Name = 'Name'
        Expression = {
            $_.GetRelated('Win32_NetworkAdapter').NetConnectionId
        }
    }
    $CommandParams = @{
        Class  = $ClassName
        Filter = $filter
    }
    $Command = Get-Command Get-WmiObject
}

& $Command @CommandParams |
    Select-Object -Property InterfaceIndex, $AdapterName, IPAddress, TcpipNetbiosOptions
