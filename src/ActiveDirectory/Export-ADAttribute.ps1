[cmdletbinding()]
param (
    $Target
)

$rootDse = Get-ADRootDSE
$props = 'Name','searchFlags'

$SearchProps = @{
    SearchBase = $rootDse.schemaNamingContext
    LDAPFilter = '(&(objectCategory=attributeSchema)(searchflags:1.2.840.113556.1.4.803:=16))'
    Properties = $props
}

$filterList = @(
    'Logon-Workstation'
    'Max-Storage'
    'Other-Login-Workstations'
    'Postal-Address'
    'Preferred-OU'
    'Post-Office-Box'
    'Postal-Code'
)

$SchemaList = Get-ADObject @SearchProps |
    Where-Object Name -NotIn $filterList |
    Select-Object -ExpandProperty Name


$userlist = foreach ($t in $Target) {
    Get-ADUser -Identity $t -Properties *
}

$AttributeList = $userlist |
    Get-Member -MemberType Properties |
    Select-Object -ExpandProperty Name |
    Where-Object {$_ -in $SchemaList }
Write-Verbose -Message ('got {0} attributes' -f ($AttributeList | measure).count)
write-debug -Message 'try here'

$ObjectList = foreach ($attribute in $AttributeList) {
    write-verbose -Message ('Doing {0}' -f $attribute)
    $ObjectProps = @{
        Attribute = $attribute
    }
    foreach ($user in $userlist) {
        $name = $user.samAccountName
        $ObjectProps.$name = $user.$attribute
    }
    [PSCustomObject] $ObjectProps
}

$ObjectList | Export-Csv -UseCulture -Path atribuudid.csv -NoTypeInformation -Encoding default
