<#
    .Description
        This script reports the various .NET Framework versions installed on the local computer.
    .Notes
	    Author		: Martin Schvartzman
        Modified by : Peter Wawa
    .Link
        Reference   : https://docs.microsoft.com/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
#>

[CmdletBinding()]
param (
        [ValidateRange(1, 4)]
        [int[]]
        # Main version of .NET Framework to be included in response
    $Generation = @(4, 3, 2, 1),
        [ValidateSet('Client', 'Full')]
        [string]
        # .NET 4.0 profile to be reported
    $Type = 'Full'
)

Function Get-NetFrameworkVersion {
    [CmdletBinding()]
    param (
            [ValidateRange(1, 4)]
            [int[]]
        $Generation = @(4, 3, 2, 1),
            [ValidateSet('Client', 'Full')]
            [string]
        $Type = 'Full'
    )

    $dotNetRegistry  = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'
    $dotNet4Registry = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4'

    $dotNet4Builds = @{
        '30319'  = @{ Version = [Version]'4.0'                                                 }
        '378389' = @{ Version = [Version]'4.5'                                                 }
        '378675' = @{ Version = [Version]'4.5.1' ; Comment = '(8.1/2012R2)'                    }
        '378758' = @{ Version = [Version]'4.5.1' ; Comment = '(8/7 SP1/Vista SP2)'             }
        '379893' = @{ Version = [Version]'4.5.2'                                               }
        '380042' = @{ Version = [Version]'4.5'   ; Comment = 'and later with KB3168275 rollup' }
        '393295' = @{ Version = [Version]'4.6'   ; Comment = '(Windows 10)'                    }
        '393297' = @{ Version = [Version]'4.6'   ; Comment = '(NON Windows 10)'                }
        '394254' = @{ Version = [Version]'4.6.1' ; Comment = '(Windows 10 1511)'               }
        '394271' = @{ Version = [Version]'4.6.1' ; Comment = '(NON Windows 10 1511)'           }
        '394802' = @{ Version = [Version]'4.6.2' ; Comment = '(Windows 10 1607/Srv16)'         }
        '394806' = @{ Version = [Version]'4.6.2' ; Comment = '(NON Windows 10 1607/Srv16)'     }
        '460798' = @{ Version = [Version]'4.7'   ; Comment = '(Windows 10 1703)'               }
        '460805' = @{ Version = [Version]'4.7'   ; Comment = '(NON Windows 10 1703)'           }
        '461308' = @{ Version = [Version]'4.7.1' ; Comment = '(Windows 10 1709)'               }
        '461310' = @{ Version = [Version]'4.7.1' ; Comment = '(NON Windows 10 1709)'           }
        '461808' = @{ Version = [Version]'4.7.2' ; Comment = '(Windows 10 1803)'               }
        '461814' = @{ Version = [Version]'4.7.2' ; Comment = '(NON Windows 10 1803)'           }
        '528040' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 10 1903/1909)'          }
        '528049' = @{ Version = [Version]'4.8.0' ; Comment = '(Non Windows 10 1903 or newer)'  }
        #'528209' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 10 2004)'               }
        '528372' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 10 2004)'               }
    }

    foreach ($g in $Generation) {
        switch ($g) {
            4 {
                Get-ChildItem -Path $dotNet4Registry |
                    Where-Object { $_.PSChildName -Like $Type } |
                    Get-ItemProperty |
                    ForEach-Object {
                        $Release = $_.Release
                        if (-not $Release) {
                            $Release = 30319
                        }
                        New-Object -TypeName PSObject -Property @{
                            #Type = $_.PSChildName
                            Version = $dotNet4Builds["$Release"].Version
                            Build   = $Release
                            Comment = $dotNet4Builds["$Release"].Comment
                        }
                    }
            }
            Default {
                Get-ChildItem -Path $dotNetRegistry |
                    Where-Object { $_.PSChildName -like "v[$g]*" } |
                    Get-ItemProperty |
                    ForEach-Object {
                        $version = [version] $_.Version
                        New-Object -TypeName PSObject -Property @{
                            Version = $version
                            Build   = $version.Build
                            SP      = $_.SP
                        }
                    }
            }
        }
    }

<#
    $RegistryPrefix = "Registry::";
#1.0 Original (on supported platforms except for Windows XP Media Center and Tablet PC)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{78705f0d-e8db-4b2d-8193-982bdda15ecd}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.0")) {
			Write-Host ".NET Framework 1.0";
		}
	} Catch {}

#1.0 Service Pack 1 (on supported platforms except for Windows XP Media Center and Tablet PC)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{78705f0d-e8db-4b2d-8193-982bdda15ecd}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.1")) {
			Write-Host ".NET Framework 1.0 service pack 1";
		}
	} Catch {}

#1.0 Service Pack 2 (on supported platforms except for Windows XP Media Center and Tablet PC)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{78705f0d-e8db-4b2d-8193-982bdda15ecd}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.2")) {
			Write-Host ".NET Framework 1.0 service pack 2";
		}
	} Catch {}

#1.0 Service Pack 3 (on supported platforms except for Windows XP Media Center and Tablet PC)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{78705f0d-e8db-4b2d-8193-982bdda15ecd}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.3")) {
			Write-Host ".NET Framework 1.0 service pack 3";
		}
	} Catch {}

#1.0 Service Pack 2 (shipped with Windows XP Media Center 2002/2004 and Tablet PC 2004)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{FDC11A6F-17D1-48f9-9EA3-9051954BAA24}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.2")) {
			Write-Host ".NET Framework 1.0 service pack 2";
		}
	} Catch {}

#1.0 Service Pack 3 (shipped with Windows XP Media Center 2002/2004 and Tablet PC 2004)
	Try {
		IF (((Get-ItemProperty -ErrorAction Stop -Path ($RegistryPrefix + "HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components\{FDC11A6F-17D1-48f9-9EA3-9051954BAA24}") | SELECT -ExpandProperty "Version") -eq "1.0.3705.3")) {
			Write-Host ".NET Framework 1.0 service pack 3";
		}
	} Catch {}
 #>
}

Get-NETFrameworkVersion @PSBoundParameters
