[CmdletBinding()]
param (
        [int]
    $Hours = 24,
        [switch]
    $IncludeAnonymous,
        [switch]
    $AsInt
)

$milliSeconds = $Hours * 3600 * 1000
$Query = @(
    'System[(EventID = 4624) and TimeCreated[timediff(@SystemTime) <= {0}]]' -f $milliSeconds
    'EventData[Data[@Name = "LmPackageName"] = "NTLM V1"]'
    if (-not $IncludeAnonymous) {
        'EventData[Data[@Name="TargetUserName"] != "ANONYMOUS LOGON"]'
    }
) -join ' and '

$XPathQuery = '*[{0}]' -f $Query

Write-Verbose -Message ('Using Query: {0}' -f $XPathQuery)
$EventList = Get-WinEvent -FilterXPath $XPathQuery -LogName 'Security' -ErrorAction SilentlyContinue

if ($AsInt.IsPresent) {
    ($EventList | Measure-Object).Count
} else {
    Write-Verbose -Message ('Exporting {0} logon events' -f $EventList.Count)
    try {
        $null = [LogonType]::Interactive
    } catch {
        Add-Type -TypeDefinition @'
            public enum LogonType {
                Interactive = 2,
                Network,
                Batch,
                Service,
                Unlock = 7,
                NetworkClearText,
                NewCredentials,
                RemoteInteractive,
                CachedInteractive
            }
'@
    }

    foreach ($currentEvent in $EventList)  {
        $xmlEvent = [xml] $currentEvent.ToXml()
        $logonType = $xmlEvent.SelectSingleNode('//*[@Name = "LogonType"]').InnerText
        New-Object -TypeName psobject -Property @{
            Time          = $currentEvent.TimeCreated
            UserName      = '{1}\{0}' -f $XmlEvent.SelectSingleNode('//*[@Name = "TargetUserName"]').InnerText,
                $XmlEvent.SelectSingleNode('//*[@Name = "TargetDomainName"]').InnerText
            UserSid       = $xmlEvent.SelectSingleNode('//*[@Name = "TargetUserSid"]').InnerText
            Computer      = $xmlEvent.SelectSingleNode('//*[@Name = "WorkstationName"]').InnerText
            IP            = $xmlEvent.SelectSingleNode('//*[@Name = "IpAddress"]').InnerText
            ProcessName   = $xmlEvent.SelectSingleNode('//*[@Name = "ProcessName"]').InnerText
            Impersonation = $xmlEvent.SelectSingleNode('//*[@Name = "ImpersonationLevel"]').InnerText
            LogonType     = [LogonType] $logonType
        }
    }
}
