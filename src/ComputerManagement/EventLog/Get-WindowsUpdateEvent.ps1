[CmdletBinding()]
param (
        [ValidateSet('Failure', 'Success')]
        [string[]]
    $Type = 'Failure',
        [Alias('StartTime')]
        [datetime]
        # Specifies start time of events
    $After,
        [Alias('EndTime')]
        [datetime]
        # Specifies end time of events
    $Before,
        [int]
        # Specifies maximum number of events to return
    $First
)


function Get-WindowsUpdateEvent {
    [CmdletBinding()]
    param (
            [ValidateSet('Failure', 'Success')]
            [string[]]
        $Type = 'Failure',
            [Alias('StartTime')]
            [datetime]
            # Specifies start time of events
        $After,
            [Alias('EndTime')]
            [datetime]
            # Specifies end time of events
        $Before,
            [int]
            # Specifies maximum number of events to return
        $First
    )

    $EventList = @{
        Failure = 20
        Success = 19
    }

    $EventFilter = @{
        ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
        Id           = foreach ($currentType in $Type) { $EventList.$currentType }
    }

    if ($After) {
        $EventFilter.StartTime = $After
    }
    if ($Before) {
        $EventFilter.EndTime = $Before
    }

    $EventProps = @{}
    if ($First) {
        $EventProps.MaxEvents = $First
    }

    Write-Debug -Message ("Using filter:`n{0}" -f ($EventFilter | Out-String))

    foreach ($currentEvent in Get-WinEvent -FilterHashtable $EventFilter @EventProps) {
        $TimeCreated = $currentEvent.TimeCreated
        $xmlEvent = [xml] $currentEvent.ToXml()
        $UpdateTitle = $xmlEvent.SelectSingleNode('//*[@Name = "updateTitle"]').InnerText

        [PSCustomObject] @{
            TimeCreated  = $TimeCreated
            ComputerName = $currentEvent.MachineName
            ErrorCode    = $xmlEvent.SelectSingleNode('//*[@Name = "errorCode"]').InnerText
            UpdateTitle  = $UpdateTitle
        }
    }
}

Get-WindowsUpdateEvent @PSBoundParameters
