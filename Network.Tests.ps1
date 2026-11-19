# Regression tests use in-memory devices. All network mutations are replaced below.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Network.ps1')
function Assert($condition,$message) {if (!$condition) {throw $message}}
function New-Card($medium,$name) {
    [pscustomobject]@{InterfaceGuid=[guid]::NewGuid().ToString('B'); NdisPhysicalMedium=$medium; Name=$name; Status='Up'; Profile='家用 Wi-Fi'; HasInternet=$true; HardwareInterface=$true; Virtual=$false; ifIndex=$medium; PnPDeviceID=$name}
}
function Reset-Cards {
    $script:wifi=New-Card 9 'Wi-Fi'
    $script:wire=New-Card 14 '以太网'
    $script:devices=@($wifi,$wire)
    $script:pnp=@()
    $script:fault=''
    $script:drops=0
    $script:joins=0
}
function Get-NetAdapter {param([switch]$IncludeHidden) $devices}
function Get-CimInstance {param($ClassName,$Filter) $pnp}
function Get-NetConnectionProfile {param($InterfaceIndex,$ErrorAction)
    $c=$devices | Where-Object ifIndex -eq $InterfaceIndex
    if ($c.HasInternet) {[pscustomobject]@{IPv4Connectivity='Internet'}}
}
function Get-NetRoute {param($InterfaceIndex,$PolicyStore,$ErrorAction)
    if ($fault -ne 'no gateway') {[pscustomobject]@{DestinationPrefix='0.0.0.0/0'}}
}
function Wireless-Profile($card) {
    if ($fault -eq 'profile unavailable') {throw 'profile unavailable'}
    return $card.Profile
}
function Reconnect-Wireless($card,$profile) {$script:joins++; $card.Profile=$profile; $card.Status='Up'}
function Disable-NetAdapter {
    param([Parameter(ValueFromPipeline)]$card,[switch]$Confirm)
    process {
        $card.Status='Disabled'
        if ($card -eq $wifi) {
            $script:drops++
            if ($fault -eq 'wire lost') {$wire.HasInternet=$false; throw 'lost target after disable'}
        }
        if ($fault -eq 'disable failed') {throw 'driver reported error after mutation'}
    }
}
function Enable-NetAdapter {
    param([Parameter(ValueFromPipeline)]$card,[switch]$Confirm)
    process {if (Is-Wifi $card) {$card.Status='Disconnected'} else {$card.Status='Up'}}
}
function Enable-PnpDevice {param($InstanceId,[switch]$Confirm)
    Assert ($InstanceId -eq 'physical-ethernet') 'wrong PnP device'
    $script:pnp=@()
    $wire.Status='Up'
    $script:devices=@($wifi,$wire)
}
function Get-PnpDeviceProperty {param($InstanceId,$KeyName) [pscustomobject]@{Data='fixture'}}
function Get-ItemProperty {param($LiteralPath) [pscustomobject]@{Characteristics=4;'*IfType'=6;NetCfgInstanceId=$wire.InterfaceGuid}}
function Expect-Failure($id,$pattern) {
    $caught=''
    try {Switch-Line $id} catch {$caught=$_.Exception.Message}
    Assert ($caught -like $pattern) "unexpected result: $caught"
}
Reset-Cards
Switch-Line $wire.InterfaceGuid
Assert ($wifi.Status -eq 'Disabled' -and $wire.Status -eq 'Up' -and $drops -eq 1) 'ethernet switch failed'
Switch-Line $wire.InterfaceGuid
Assert ($drops -eq 1) 'repeat click disconnected twice'
$wifi.Status='Up'
Switch-Line $wifi.InterfaceGuid
Assert ($wire.Status -eq 'Disabled' -and $wifi.Status -eq 'Up') 'wireless switch failed'
Reset-Cards
$fault='wire lost'
Expect-Failure $wire.InterfaceGuid '*已确认原线路恢复*'
Assert ($wifi.Status -eq 'Up' -and $joins -eq 1 -and $wifi.Profile -ceq '家用 Wi-Fi') 'original Wi-Fi not restored'
Reset-Cards
$fault='disable failed'
Expect-Failure $wifi.InterfaceGuid '*已确认原线路恢复*'
Assert ($wire.Status -eq 'Up') 'original ethernet not restored'
Reset-Cards
$fault='profile unavailable'
Expect-Failure $wire.InterfaceGuid '*profile unavailable*'
Assert ($drops -eq 0) 'disconnected without a recovery profile'
Reset-Cards
$fault='no gateway'
Assert (!(Online $wire)) 'accepted Internet profile without gateway'
Expect-Failure ([guid]::NewGuid()) '*移除*'
Reset-Cards
$script:pnp=@([pscustomobject]@{Present=$true;DeviceID='physical-ethernet';Name='Disabled Ethernet'})
$script:devices=@($wifi)
Assert ((Lookup-Card $wire.InterfaceGuid).NeedsPnpEnable) 'missing disabled card'
Switch-Line $wire.InterfaceGuid
Assert ($wire.Status -eq 'Up' -and $wifi.Status -eq 'Disabled') 'failed PnP recovery'
Reset-Cards
$v=New-Card 14 'VPN'
$v.Virtual=$true
$script:devices+=$v
Switch-Line $wifi.InterfaceGuid
Assert ($v.Status -eq 'Up') 'virtual adapter changed'
function Confirm-Switch($id,$wifiTarget) {throw 'final verification failed'}
Reset-Cards
Expect-Failure $wire.InterfaceGuid '*已确认原线路恢复*'
Assert ($joins -eq 1 -and $wifi.Status -eq 'Up') 'post-switch verification did not restore Wi-Fi'
function Reconnect-Wireless($card,$profile) {throw 'hotspot unavailable'}
Reset-Cards
Expect-Failure $wire.InterfaceGuid '*hotspot unavailable*'
Assert ($wire.Status -eq 'Up') 'recovery failure disabled target'
function Wait-Line($id,$wifiTarget) {throw 'target timed out'}
Reset-Cards
Expect-Failure $wire.InterfaceGuid '*timed out*'
Assert ($drops -eq 0 -and $wifi.Status -eq 'Up') 'original line changed during preparation'
'PASS: bidirectional switching, repeated clicks, original Wi-Fi and Ethernet recovery, missing profile, gateway, removed device, hidden PnP device, virtual adapter exclusion.'
