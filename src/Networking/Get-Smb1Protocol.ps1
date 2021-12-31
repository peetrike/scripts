#Requires -version 2.0

[CmdletBinding()]
param (
        [ValidateSet('Both', 'Client', 'Server')]
        [string]
    $Target = 'Both'
)


function Get-Smb1Protocol {
    [CmdletBinding()]
    param (
            [ValidateSet('Both', 'Client', 'Server')]
            [string]
        $Target = 'Both'
    )

    $OsVersion = [System.Environment]::OSVersion.Version
    $Incomplete = @{
        Client = $true
        Server = $true
    }
    $Result = @{
        Client = $true
        Server = $true
    }

    if ($OsVersion -ge '6.3') {
        Write-Verbose -Message 'Checking optional feature'
        $FeatureName = 'SMB1Protocol'
        $FeatureList = Get-WindowsOptionalFeature -Online -FeatureName "$FeatureName*"

        $disabled = [Microsoft.Dism.Commands.FeatureState]::Disabled
        $FeatureState = ($FeatureList | Where-Object { $_.FeatureName -like $FeatureName }).State
        if ($FeatureState -eq $disabled) {
            $Result.Client = $false # Disabled
            $Result.Server = $false # Disabled
            $Incomplete.Client = $false
            $Incomplete.Server = $false
        } elseif ($OsVersion -ge '10.0') {
            $nameList = $Target
            if ($Target -like 'Both') {
                $nameList = 'Client', 'Server'
            }
            foreach ($feature in $nameList) {
                Write-Verbose -Message ('Processing feature {0}' -f $feature)
                $ProtocolFeature = $FeatureList | Where-Object { $_.FeatureName -like "*$feature" }
                $Result.$feature = $ProtocolFeature.State -eq [Microsoft.Dism.Commands.FeatureState]::Enabled
                $Incomplete.$feature = $Result.$feature
            }
        }
    }

    if ($Incomplete.Client -and ($Target -notlike 'Server')) { # check Client
        Write-Verbose -Message 'Checking client service'
        $Smb1Service = Get-Service -Name mrxsmb10 -ErrorAction SilentlyContinue
        if (-not $Smb1Service -or ($Smb1Service.Status -ne 'Running')) {
            $Result.Client = $false # Disabled
        }
    }

    if ($Target -notlike 'Client' -and $Incomplete.Server) { # check Server
        if ($OsVersion -ge '6.2') {
            Write-Verbose -Message 'Checking using Get-SmbServerConfiguration'
            $result.Server = (Get-SmbServerConfiguration).EnableSMB1Protocol
        } elseif ($OsVersion -ge '6.0') {
            Write-Verbose -Message 'Checking server using registry'
            $SmbParams = Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters
            if ($SmbParams.SMB1 -eq 0) {
                $result.Server = $false # Disabled
            }
        }
    }

    if ($Target -like 'Both') {
        New-Object -TypeName PSObject -Property $Result
    } else {
        $Result.$Target
    }
}

Get-Smb1Protocol @PSBoundParameters
