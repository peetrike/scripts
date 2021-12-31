#Requires -Version 3.0
#Requires -Modules DhcpServer

[cmdletbinding(
    SupportsShouldProcess
)]
param(
        [parameter(
            ValueFromPipeline
        )]
        [string[]]
    $DnsSuffix = @(
        'ipfdigital.net'
        'ipfdigital.tech'
        'ipfdigital.io'
        'bapps.ipfd'
        'dev01.ipfd'
        'nonprod.ipfd'
        'preprod.ipfd'
        'prod.ipfd'
        'st01.ipfd'
        'st02.ipfd'
        'st03.ipfd'
        'st04.ipfd'
        'st05.ipfd'
        'st06.ipfd'
        'st07.ipfd'
        'st08.ipfd'
        'st09.ipfd'
        'st10.ipfd'
        'st11.ipfd'
        'st12.ipfd'
        'st13.ipfd'
        'sit.ipfd'
        'uat.ipfd'
    ),
        [ipaddress]
    $ScopeId = "192.168.0.0"
)

begin {
    $OptionId = 119
    $domainSearchListHexArray = New-Object -TypeName 'System.Collections.Generic.List[System.Byte]'
}

process {
    $domainSearchListHexArray += foreach ($domain in $DnsSuffix) {
        foreach ($domainPart in $domain.split('.')) {
            $domainPart.Length
            [byte[]]$domainPart.ToCharArray()
        }

        0x00
    }
}

end {
    Write-Verbose -Message 'DnsSuffix:'
    Write-Verbose -Message ($domainSearchListHexArray -join ',')
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId $OptionId -Value $domainSearchListHexArray
}
