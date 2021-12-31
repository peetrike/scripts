#Requires -version 2.0

<#
    .LINK
        https://docs.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3
#>

[CmdletBinding()]
param (
        [ValidateSet('Both', 'Client', 'Server')]
        [string]
    $Target = 'Both',
        [ValidateSet('Disabled', 'Enabled', 'Removed')]
        [string]
    $State
)

Function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw (New-Object -TypeName System.Management.Automation.PSSecurityException -ArgumentList 'Admin Privileges required')
}

function Set-Smb1Protocol {
    [CmdletBinding(
        SupportsShouldProcess = $true
    )]
    param (
            [ValidateSet('Both', 'Client', 'Server')]
            [string]
        $Target = 'Both',
            [ValidateSet('Disabled', 'Enabled', 'Removed')]
            [string]
        $State
    )

    $OsVersion = [System.Environment]::OSVersion.Version
    $Result = @{
        Computername = ([Net.Dns]::GetHostByName($env:computerName)).HostName
        Client  = $true
        Server  = $true
        State   = $State
        Success = $false
    }
    $Incomplete = $true

    if ($OsVersion -ge '6.3') {
        switch ($Target) {
            'Both' {
                $FeatureName = 'SMB1Protocol'
                $Incomplete = $false
            }
            Default {
                $FeatureName = 'SMB1Protocol-{0}' -f $Target
                if ( Get-WindowsOptionalFeature -Online -FeatureName $FeatureName ) {
                    $Incomplete = $false
                }
            }
        }
        if (-not $Incomplete) {
            Write-Verbose -Message 'Setting using OptionalFeature'
            $ActionProps = @{
                FeatureName = $FeatureName
                Online      = $true
                NoRestart   = $true
            }
            switch ($State) {
                'Disabled' {
                    $null = Disable-WindowsOptionalFeature @ActionProps
                }
                'Enabled' {
                    $null = Enable-WindowsOptionalFeature @ActionProps
                }
                'Removed' {
                    $null = Disable-WindowsOptionalFeature @ActionProps -Remove
                }
            }
            switch ($Target) {
                'Both' {
                    $Result.Client = $State -like 'Enabled'
                    $Result.Server = $State -like 'Enabled'
                }
                Default {
                    $Result.$Target = $State -like 'Enabled'
                }
            }
            $Result.Success = $true
        }
    }

    if ($Target -notlike 'Server' -and $Incomplete) { # check Client
        if ($OsVersion -ge '6.0') {
            Write-Verbose -Message 'Changing client service State'
            $ServiceName = 'mrxsmb10'
            if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
                switch ($State) {
                    'Enabled' {
                        $null = sc.exe config lanmanworkstation depend= bowser/mrxsmb10/mrxsmb20/nsi
                        Set-Service -Name $ServiceName -StartupType Automatic -Status Running
                        $Result.Client = $true
                    }
                    Default {
                        $null = sc.exe config lanmanworkstation depend= bowser/mrxsmb20/nsi
                        Set-Service -Name $ServiceName -StartupType Disabled -PassThru | Stop-Service
                        Write-Warning -Message 'Restart is required'
                        $Result.State = 'Disabled'
                        $Result.Client = $false
                    }
                }
                $Result.Success = $true
            } elseif ($State -notlike 'Enabled') {
                $Result.Client = $false
                $Result.State = 'Disabled'
                $Result.Success = $true
            } else {
                $Result.Client = $false
                $Result.Success = $false
                Write-Error -Message 'Service "SMB 1.x MiniRedirector" does not exist, cannot enable'
            }
        } else {
            Write-Error -Message 'SMB v1 Client state cannot be changed on Windows Server 2003 or Windows XP'
        }
    }

    if ($Target -notlike 'Client' -and $Incomplete) { # check Server
        if ($OsVersion -ge '6.2') {
            Write-Verbose -Message 'Changing server state using Set-SmbServerConfiguration'
            switch ($State) {
                'Enabled' {
                    Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
                }
                Default {
                    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
                    $Result.State = 'Disabled'
                }
            }
            $Result.Server = (Get-SmbServerConfiguration).EnableSMB1Protocol
            $Result.Success = $true
        } elseif ($OsVersion -ge '6.0') {
            Write-Verbose -Message 'Changing server state using registry'
            $RegParams = @{
                Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                Name = 'SMB1'
                Type = 'DWORD'
                Force = $true
            }
            switch ($State) {
                'Enabled' {
                    Set-ItemProperty @RegParams -Value 1
                }
                Default {
                    Set-ItemProperty @RegParams -Value 0
                    $Result.State = 'Disabled'
                }
            }
            $RegParams.Remove('Type')
            $RegParams.Remove('Force')
            $Result.Server = [Boolean](Get-ItemProperty @RegParams).SMB1
            $Result.Success = $true
            Write-Warning -Message 'Restart is required'
        } else {
            Write-Error -Message 'SMB v1 Server state cannot be changed on Windows Server 2003 or Windows XP'
        }
    }

    switch ($Target) {
        'Client' {
            $Result.Remove('Server')
        }
        'Server' {
            $Result.Remove('Client')
        }
    }
    New-Object -TypeName psobject -Property $Result
}

Set-Smb1Protocol @PSBoundParameters
