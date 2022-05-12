<#
		.SYNOPSIS
			Gets an abbreviated set of info about NTLMv1 logon events.
			
        .DESCRIPTION
			This script queries the Windows Security eventlog for NTLMv1 logons in eventid 4624. The number of events returned is configurable. Whether null session logon events are included is configurable. It can be run against all domain controllers, a remote member server, or the localhost. If used against anything other than the localhost, WinRM is required to be listening on those remote hosts. If used against DCs, the ActiveDirectory PS module is required. 

		.EXAMPLE
			Get-NtlmV1LogonEvents
			
			Gets the last 30 NTLMv1 logon events from the localhost.

		.EXAMPLE
			Get-NtlmV1LogonEvents -NumEvents 10

			Gets the last 10 NTLMv1 logon events from the localhost.

		.EXAMPLE
			Get-NtlmV1LogonEvents -Target clay.pottery.uw.edu

			Gets the last 30 NTLMv1 logon events from clay.pottery.uw.edu via WinRM.

		.EXAMPLE
			Get-NtlmV1LogonEvents -Target DCs

			Gets the last 30 NTLMv1 logon events on each domain controller in the domain of the localhost. Leverages WinRM and ActiveDirectory PS module.

		.EXAMPLE
			Get-NtlmV1LogonEvents -NullSession $false

			Gets the last 30 NTLMv1 logon events--excluding null session logons--from the localhost.
			
		.PARAMETER NumEvents
			An optional parameter that overrides the default value of 30. Enter a string indicating the desired number of events to return (per host).
				
		.PARAMETER Target
			An optional parameter that specifies the target computer(s). By default, the localhost is targeted. Valid values are "DCs" or any fully qualified DNS hostname that resolves. If you use this parameter, the remote computer must be able to accept WS-Man requests. You may need to do a "winrm quickconfig" on that remote computer to enable this.

		.PARAMETER NullSession
			An optional parameter that enables you to filter out all null session NTLMv1 logons. By default, all NTLMv1 logons including null sessions are included. If you'd like to filter out null sessions, use this parameter. This parameter can make it much easier to find identifiable users to contact.
					
        .NOTES
			Author	: Eric Kool-Brown - kool@uw.edu
			Author  : Brian Arkills - barkills@uw.edu
			Created : 04/08/2014
			
        .LINK
			UWWI Documentation
				https://wiki.cac.washington.edu/display/uwwi/NTLMv1+Removal+-+problems%2C+solutions+and+workarounds
			
		.LINK
			TechNet The Most Misunderstood Windows Security Setting of All Time
				http://technet.microsoft.com/en-us/magazine/2006.08.securitywatch.aspx	
#>

[cmdletbinding()]
param([Int64]$NumEvents = 30,
	[boolean]$NullSession = $true,
	[string]$Target = "."
	)

if ($NullSession) {
	# This finds NTLM V1 logon events
	$NtLm1Filter = "Event[System[(EventID=4624)]]and Event[EventData[Data[@Name='LmPackageName']='NTLM V1']]"
}
else {
	# This finds NTLM V1 logon events without null session logons
	$NtLm1Filter = "Event[System[(EventID=4624)]]and Event[EventData[Data[@Name='LmPackageName']='NTLM V1']] and Event[EventData[Data[@Name='TargetUserName']!='ANONYMOUS LOGON']]"
}

if ($Target -eq "."){
	Write-Host "Querying security log for NTLM V1 events (ID 4624) on localhost"

	Get-WinEvent -Logname security -MaxEvents $NumEvents -FilterXPath $Ntlm1Filter |
	    select @{Label='Time';Expression={$_.TimeCreated.ToString('g')}},
        	@{Label='UserName';Expression={$_.Properties[5].Value}},
	        @{Label='WorkstationName';Expression={$_.Properties[11].Value}},
        	@{Label="LogonType";Expression={$_.properties[8].value}},
	        @{Label="ImpersonationLevel";Expression={$_.properties[20].value}}
}
else {
	#using winRM
	$remoteScript = {
	    Get-WinEvent -Logname security -MaxEvents $Using:NumEvents -FilterXPath $Using:Ntlm1Filter |
	    select @{Label='Time';Expression={$_.TimeCreated.ToString('g')}},
	        @{Label='UserName';Expression={$_.Properties[5].Value}},
        	@{Label='WorkstationName';Expression={$_.Properties[11].Value}},
	        @{Label="LogonType";Expression={$_.properties[8].value}},
        	@{Label="ImpersonationLevel";Expression={$_.properties[20].value}}
	}
	if ($Target -eq "DCs"){
		Import-Module ActiveDirectory
		$dcs = Get-ADDomainController -Filter * | select -expand hostname

		Write-Host "Querying security log for NTLM V1 events (ID 4624) on DCs $dcs"

		Invoke-Command -ComputerName $dcs -ScriptBlock $remoteScript | Select -Property Time,UserName,WorkstationName,LogonType,ImpersonationLevel,PSComputerName
	}
	else {
		Write-Host "Querying security log for NTLM V1 events (ID 4624) on remote host: $Target"

		Invoke-Command -ComputerName $Target -ScriptBlock $remoteScript | Select -Property Time,UserName,WorkstationName,LogonType,ImpersonationLevel,PSComputerName
	}
}

#########################Various info bits to help others modify this script to meet other needs######################################################
#
# Properties (EventData) fields of event 4624:
# Index Property                  Sample Value
# ----- ------------------------- -------------------------------------
# [0]   SubjectUserSid            S-1-0-0
# [1]   SubjectUserName           -
# [2]   SubjectDomainName         -
# [3]   SubjectLogonId            0x0
# [4]   TargetUserSid             S-1-5-7
# [5]   TargetUserName            ANONYMOUS LOGON
# [6]   TargetDomainName          NT AUTHORITY
# [7]   TargetLogonId             0x12cff454c
# [8]   LogonType                 3
# [9]   LogonProcessName          NtLmSsp
# [10]  AuthenticationPackageName NTLM
# [11]  WorkstationName           UAA-HONLAB01
# [12]  LogonGuid                 {00000000-0000-0000-0000-000000000000}
# [13]  TransmittedServices       -
# [14]  LmPackageName             NTLM V1
# [15]  KeyLength                 128
# [16]  ProcessId                 0x0
# [17]  ProcessName               -
# [18]  IpAddress                 128.208.99.146
# [19]  IpPort                    58560
# [20]  ImpersonationLevel        %%1833
# ImpersonationLevel is a replacement string with these mappings:
# 1833 = Impersonation

# Event log query with a time limit
#<QueryList>
#  <Query Id="0" Path="Security         
#    <Select Path="Security">*[System[(EventID=4624) and TimeCreated[@SystemTime&gt;='2014-03-07T23:33:13.000Z']]]</Select>
#  </Query>
#</QueryList>

# Filter for 4624 (Logon) events
# $loginEventFilter = "*[System[(EventID=4624)]]"
# $equallyValidFilter = "Event[System[(EventID=4624)]]"

# This finds all NTLM events, V1 and V2
# $NtlmFilter = "Event[System[(EventID=4624)]]and Event[EventData[Data[@Name='LmPackageName']!='-']]"

# Event Viewer query for NTLM events
#<QueryList>
#  <Query Id="0" Path="Security         
#    <Select Path="Security">Event[System[(EventID=4624)]] and Event[EventData[Data[@Name='LmPackageName']!='-']]</Select>
#  </Query>
#</QueryList>
#
# SIG # Begin signature block
# MIIOdgYJKoZIhvcNAQcCoIIOZzCCDmMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5sjHnP5UqP+q4UAROjmZPF+X
# g5KggglbMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
# AQUFADCBlTELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAlVUMRcwFQYDVQQHEw5TYWx0
# IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMSEwHwYD
# VQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5jb20xHTAbBgNVBAMTFFVUTi1VU0VS
# Rmlyc3QtT2JqZWN0MB4XDTEwMDUxMDAwMDAwMFoXDTE1MDUxMDIzNTk1OVowfjEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxJDAiBgNVBAMT
# G0NPTU9ETyBUaW1lIFN0YW1waW5nIFNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALw1oDZwIoERw7KDudMoxjbNJWupe7Ic9ptRnO819O0Ijl44
# CPh3PApC4PNw3KPXyvVMC8//IpwKfmjWCaIqhHumnbSpwTPi7x8XSMo6zUbmxap3
# veN3mvpHU0AoWUOT8aSB6u+AtU+nCM66brzKdgyXZFmGJLs9gpCoVbGS06CnBayf
# UyUIEEeZzZjeaOW0UHijrwHMWUNY5HZufqzH4p4fT7BHLcgMo0kngHWMuwaRZQ+Q
# m/S60YHIXGrsFOklCb8jFvSVRkBAIbuDlv2GH3rIDRCOovgZB1h/n703AmDypOmd
# RD8wBeSncJlRmugX8VXKsmGJZUanavJYRn6qoAcCAwEAAaOB9DCB8TAfBgNVHSME
# GDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQULi2wCkRK04fAAgfO
# l31QYiD9D4MwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2NybC51c2Vy
# dHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDA1BggrBgEFBQcBAQQp
# MCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
# hvcNAQEFBQADggEBAMj7Y/gLdXUsOvHyE6cttqManK0BB9M0jnfgwm6uAl1IT6TS
# IbY2/So1Q3xr34CHCxXwdjIAtM61Z6QvLyAbnFSegz8fXxSVYoIPIkEiH3Cz8/dC
# 3mxRzUv4IaybO4yx5eYoj84qivmqUk2MW3e6TVpY27tqBMxSHp3iKDcOu+cOkcf4
# 2/GBmOvNN7MOq2XTYuw6pXbrE6g1k8kuCgHswOjMPX626+LB7NMUkoJmh1Dc/VCX
# rLNKdnMGxIYROrNfQwRSb+qz0HQ2TMrxG3mEN3BjrXS5qg7zmLCGCOvb4B+MEPI5
# ZJuuTwoskopPGLWR5Y0ak18frvGm8C6X0NL2KzwwggTAMIIEKaADAgECAgImFDAN
# BgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMSEwHwYD
# VQQKExhVbml2ZXJzaXR5IG9mIFdhc2hpbmd0b24xFDASBgNVBAsTC1VXIFNlcnZp
# Y2VzMRcwFQYDVQQDEw5VVyBTZXJ2aWNlcyBDQTEmMCQGCSqGSIb3DQEJARYXaGVs
# cEBjYWMud2FzaGluZ3Rvbi5lZHUwHhcNMTIwODE0MTYwMzEyWhcNMTUwODE1MTYw
# MzEyWjCBujEhMB8GA1UEChMYVW5pdmVyc2l0eSBvZiBXYXNoaW5ndG9uMR8wHQYD
# VQQLExZJbmZvcm1hdGlvbiBUZWNobm9sb2d5MRwwGgYJKoZIhvcNAQkBFg1jaS1p
# YW1AdXcuZWR1MRAwDgYDVQQHEwdTZWF0dGxlMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MQswCQYDVQQGEwJVUzEiMCAGA1UEAxMZY29kZS5uZXRpZC53YXNoaW5ndG9uLmVk
# dTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALmVM514ZAcjgZn+Oa7j
# ZppF092FFNSajhHwfO3FWa4e140z7rDvUlXQ++Qg8J7ANzqLTC8gdQ8oLXqd0StL
# 0ZKTfyXXnJAoXoPMcK8GKqIG+fKBKeKQlFuA3IMwF8BfDCr9GPnvuL7BPiRBfP5o
# d3IyR4OgeRWH4BeN8LOrusCE5LqnJquUnSLKCEYqmtLkU0ykD55Jk3pjyXjqkFwD
# 8CQWdzU6k3apeJKijLS0Lw5zgbSkOKV8NnL7tYbT4Qo9QvR7+u7KJety7QonOGsR
# nGlK0wrOZGJlMV5gaH6s19DlNPTT9U3pfacXt4ARvYjtx8MgwTap94Y9HEi0JJJN
# 2mECAwEAAaOCAXMwggFvMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwHQYDVR0OBBYEFPBMWCTVBRKGAJOIsUoxlL+D1CSiMCQGA1UdEQQdMBuCGWNv
# ZGUubmV0aWQud2FzaGluZ3Rvbi5lZHUwgcEGA1UdIwSBuTCBtoAUVdfBM8b6k/gn
# PcsgS/VajliXfXShgZqkgZcwgZQxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEh
# MB8GA1UEChMYVW5pdmVyc2l0eSBvZiBXYXNoaW5ndG9uMRQwEgYDVQQLEwtVVyBT
# ZXJ2aWNlczEXMBUGA1UEAxMOVVcgU2VydmljZXMgQ0ExJjAkBgkqhkiG9w0BCQEW
# F2hlbHBAY2FjLndhc2hpbmd0b24uZWR1ggEAMEEGA1UdHwQ6MDgwNqA0oDKGMGh0
# dHA6Ly9jZXJ0cy5jYWMud2FzaGluZ3Rvbi5lZHUvVVdTZXJ2aWNlc0NBLmNybDAN
# BgkqhkiG9w0BAQUFAAOBgQA0WGRa2o6SOfc/m8drwY/OqItoaWCGtzpnVhC61vEt
# NZ7sHV6IFdLYwnbudQX2CcwGE2uOYZt2LqbXVNpi5m4ZHoWqQXCCpmqueT79b3+g
# OUuto1sPpI2KwV6TbI1/8xqX9Vpvx8ZazGtc08G2QLowbDkXIWJ1/6q0b144aFCU
# WDGCBIUwggSBAgEBMIGbMIGUMQswCQYDVQQGEwJVUzELMAkGA1UECBMCV0ExITAf
# BgNVBAoTGFVuaXZlcnNpdHkgb2YgV2FzaGluZ3RvbjEUMBIGA1UECxMLVVcgU2Vy
# dmljZXMxFzAVBgNVBAMTDlVXIFNlcnZpY2VzIENBMSYwJAYJKoZIhvcNAQkBFhdo
# ZWxwQGNhYy53YXNoaW5ndG9uLmVkdQICJhQwCQYFKw4DAhoFAKB4MBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMjPtb92
# rkDfACB4v7p+1Q/n89eJMA0GCSqGSIb3DQEBAQUABIIBAI3Byks+072Qirhumtks
# d1EYZzjmC3yLHn2zTeMGyt3k5bNUzn5+kP1mfIEOwbL9X7i/Zvg/xbxbVCkp3teh
# EnOvXKtwVdAxNi5HF4YoqVNiTR1WrcCoGk6IReiVoIh2Yvs9jiSRBoeXZRZK0SWd
# EfSBnrw0DN76BoMDDjqRtAKZxmg1ECDpBBhZJHi2POfsx3AuDK4mtaN0kwD1Zz+5
# eGm/TloicR2xBKJtmXzqrP+g6wWYhDLMg2H6im8yWKJErpFoBe3S2HUgnOVtovuL
# QlzK88tUxNBgYR/ECBqnC8OfsDxqJ9nsWgxEIRlTVoUIZ0kqQCB6+W2LBqRjXLeC
# Bg2hggJEMIICQAYJKoZIhvcNAQkGMYICMTCCAi0CAQAwgaowgZUxCzAJBgNVBAYT
# AlVTMQswCQYDVQQIEwJVVDEXMBUGA1UEBxMOU2FsdCBMYWtlIENpdHkxHjAcBgNV
# BAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEhMB8GA1UECxMYaHR0cDovL3d3dy51
# c2VydHJ1c3QuY29tMR0wGwYDVQQDExRVVE4tVVNFUkZpcnN0LU9iamVjdAIQR4qO
# +1nh2D8M4ULSoocHvjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwNDA4MTgzNzQ0WjAjBgkqhkiG9w0BCQQx
# FgQU3aZmswSr/R1GuF0HHp/D+C/f3gowDQYJKoZIhvcNAQEBBQAEggEAuqrHJsfa
# 1NSK/C3hB0hP1lj+u3ouENgkNRKqvXUmS0spOMO3dKPQPPteI0/yWDGbk5c43aRD
# Ct2XTccyG0nubCuxUfqEaIlWd86GVZy5oPoRD2F1fSZUKTan7tKApoyfi6VQ8e3G
# tI2jHuNs7z/urgbUCrEvGvApZ16kzxMHL7QarAk2ZMrWDSvxLXASTK003+IyLGVM
# H7fLJBvRYP+fb7/3CsfWPT2tfI1elQSxD6NpZ6QkUJRxUKyOLUF353VBxpEHhmlu
# mlmV3O0K+alH9k4v87OMWtM0kvRZn6IOGkgvl6l1uDAb3q/UVD7U2R6yIPL38xgt
# cz3OFGacBsFtbA==
# SIG # End signature block
