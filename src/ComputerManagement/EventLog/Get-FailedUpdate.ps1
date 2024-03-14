
[CmdletBinding()]
param (
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before
)

function stringTime {
    param (
            [datetime]
        $time
    )

    $time.ToUniversalTime().ToString('o')
}

$xPathFilter = "*[System/Provider[@Name='microsoft-windows-windowsupdateclient'] and (System/EventID=20)"
if ($After -or $Before) {
    $xPathFilter += ' and (System/TimeCreated[@SystemTime'
    if ($After) {
        $xPathFilter += " >= '{0}'" -f (stringTime $After)
        if ($Before) { $xPathFilter += ' and @SystemTime' }
    }
    if ($Before) {
        $xPathFilter += " <= '{0}'" -f (stringTime $Before)
    }
    $xPathFilter += '])'
}
$xPathFilter += ']'

Write-Debug -Message ("Using filter:`n{0}" -f $xPathFilter)

foreach ($currentEvent in Get-WinEvent -LogName System -FilterXPath $xPathFilter) {
    $xmlEvent = [xml] $currentEvent.ToXml()
    [PSCustomObject] @{
        TimeCreated  = $currentEvent.TimeCreated
        ComputerName = $currentEvent.MachineName
        ErrorCode    = $xmlEvent.SelectSingleNode('//*[@Name = "errorCode"]').InnerText
        UpdateTitle  = $xmlEvent.SelectSingleNode('//*[@Name = "updateTitle"]').InnerText
    }
}
