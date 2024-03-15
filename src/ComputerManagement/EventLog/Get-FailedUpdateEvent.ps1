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


function Get-FailedUpdateEvent {
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

    function ConvertTo-StringTime {
        param (
                [datetime]
            $Time
        )

        $Time.ToUniversalTime().ToString('o')
    }

    $xPathFilter = "*[System/Provider[@Name='microsoft-windows-windowsupdateclient'] and (System/EventID=20)"
    if ($After -or $Before) {
        $xPathFilter += ' and (System/TimeCreated[@SystemTime'
        if ($After) {
            $xPathFilter += " >= '{0}'" -f (ConvertTo-StringTime $After)
            if ($Before) { $xPathFilter += ' and @SystemTime' }
        }
        if ($Before) {
            $xPathFilter += " <= '{0}'" -f (ConvertTo-StringTime $Before)
        }
        $xPathFilter += '])'
    }
    $xPathFilter += ']'

    Write-Debug -Message ("Using filter:`n{0}" -f $xPathFilter)

    foreach ($currentEvent in Get-WinEvent -LogName System -FilterXPath $xPathFilter) {
        $TimeCreated = $currentEvent.TimeCreated
        $xmlEvent = [xml] $currentEvent.ToXml()
        $UpdateTitle = $xmlEvent.SelectSingleNode('//*[@Name = "updateTitle"]').InnerText
        <# $UpdateGuid = $xmlEvent.SelectSingleNode('//*[@Name = "updateGuid"]').InnerText

        $SuccessFilter =
            '*[System[' +
            'Provider[@Name="microsoft-windows-windowsupdateclient"] and (EventID=19)' +
            (' and (TimeCreated[@SystemTime >= "{0}"])' -f (ConvertTo-StringTime $TimeCreated)) +
            ']' +
            ('and (EventData/Data="{0}")]' -f $UpdateGuid)

        if (Get-WinEvent -LogName System -FilterXPath $SuccessFilter -ErrorAction Ignore) {
            Write-Verbose -Message ('failed update that succeeded later: {0}' -f $UpdateTitle)
        } else {
            Write-Debug -Message ('failed update GUID: {0}' -f $UpdateGuid) #>
            [PSCustomObject] @{
                TimeCreated  = $TimeCreated
                ComputerName = $currentEvent.MachineName
                ErrorCode    = $xmlEvent.SelectSingleNode('//*[@Name = "errorCode"]').InnerText
                UpdateTitle  = $UpdateTitle
            }
        #}
    }
}

Get-FailedUpdateEvent @PSBoundParameters
