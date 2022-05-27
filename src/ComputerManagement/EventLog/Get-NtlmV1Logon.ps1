#Requires -Version 3
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
    if (-not $IncludeAnonymous.IsPresent) {
        'EventData[Data[@Name="TargetUserName"] != "ANONYMOUS LOGON"]'
    }
) -join ' and '

$XPathQuery = '*[{0}]' -f $Query

Write-Verbose -Message ('Using Query: {0}' -f $XPathQuery)
$EventList = Get-WinEvent -FilterXPath $XPathQuery -LogName 'Security' -ErrorAction SilentlyContinue

if ($AsInt.IsPresent) {
    ($eventlist | Measure-Object).Count
} else {
    $EventList | ForEach-Object {
        [PSCustomObject] @{
            Time               = $_.TimeCreated
            UserName           = $_.Properties[5].Value
            ComputerName       = $_.Properties[11].Value
            LogonType          = $_.Properties[8].Value
            ImpersonationLevel = $_.Properties[20].Value
        }
    }
}
