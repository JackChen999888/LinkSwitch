function Read-State {
    $ips = @(Get-NetIPInterface -PolicyStore ActiveStore)
    $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
    $cards = @(Physical-Cards -ips $ips -profiles $profiles)
    $ips = @($ips | Where-Object InterfaceIndex -in $cards.ifIndex)
    $routes = @(Get-NetRoute -PolicyStore ActiveStore | Where-Object { $_.DestinationPrefix -in '0.0.0.0/0','::/0' -and $_.InterfaceIndex -in $cards.ifIndex })
    $probe=Find-NetRoute -RemoteIPAddress '1.1.1.1' -ErrorAction SilentlyContinue | Where-Object DestinationPrefix | Select-Object -First 1
    [pscustomobject]@{ Cards=$cards; Ips=$ips; Routes=$routes; Via=$probe.InterfaceAlias }
}
function Is-Wifi($adapter) {
    $adapter.InterfaceType -eq 71 -or $adapter.NdisPhysicalMedium -in 1,9 -or $adapter.MediaType -eq 'Native 802.11'
}
function Disabled-Devices {
    # Disabled drivers can disappear from MSFT_NetAdapter completely after a reboot.
    foreach ($pnp in Get-CimInstance Win32_PnPEntity -Filter "PNPClass='Net' AND ConfigManagerErrorCode=22") {
        if (!$pnp.Present) {continue}
        $driver=(Get-PnpDeviceProperty -InstanceId $pnp.DeviceID -KeyName DEVPKEY_Device_Driver -ErrorAction SilentlyContinue).Data
        if (!$driver) {continue}
        $key=Get-ItemProperty -LiteralPath ("HKLM:\SYSTEM\CurrentControlSet\Control\Class\"+$driver) -ErrorAction SilentlyContinue
        if (!($key.Characteristics -band 4) -or $key.'*IfType' -notin 6,71 -or !$key.NetCfgInstanceId) {continue}
        [pscustomobject]@{
            InterfaceGuid=$key.NetCfgInstanceId; PnPDeviceID=$pnp.DeviceID
            Name=$pnp.Name; LinkState='Disabled'; Status='Disabled'; NeedsPnpEnable=$true
            NdisPhysicalMedium=if ($key.'*IfType' -eq 71) {9} else {14}
        }
    }
}
function Resolve-LinkState($card,$ip,$profile) {
    # Numeric NDIS/IF_OPER_STATUS values are independent of Windows display language.
    if ($card.NeedsPnpEnable -or $card.Status -eq 'Disabled' -or $card.InterfaceAdminStatus -eq 2) {return 'Disabled'}
    if ($card.MediaConnectState -eq 2 -or $card.MediaConnectionState -eq 'Disconnected') {return 'Disconnected'}
    if ($card.MediaConnectState -eq 1 -or $card.MediaConnectionState -eq 'Connected' -or $card.InterfaceOperationalStatus -eq 1) {return 'Up'}
    if ($card.Status -eq 'Up') {return 'Up'}
    $active=@($profile.IPv4Connectivity)+@($profile.IPv6Connectivity)
    if ($ip.ConnectionState -contains 'Connected' -or @($active | Where-Object {$_ -in 'Subnet','LocalNetwork','Internet'}).Count) {return 'Up'}
    if ($card.Status -eq 'Disconnected' -or $card.InterfaceOperationalStatus -in 2,7) {return 'Disconnected'}
    return 'Unknown'
}
function Physical-Cards($ips=$(Get-NetIPInterface -PolicyStore ActiveStore),$profiles=$(Get-NetConnectionProfile -ErrorAction SilentlyContinue)) {
    $disabled=@(Disabled-Devices)
    foreach ($card in Get-NetAdapter -IncludeHidden) {
        if (!$card.HardwareInterface -or $card.Virtual -or $card.Status -eq 'Not Present' -or $card.InterfaceOperationalStatus -eq 6) {continue}
        if ($card.NdisPhysicalMedium -in 8,10) {continue}
        if (!(Is-Wifi $card) -and $card.MediaType -ne '802.3' -and $card.NdisPhysicalMedium -ne 14 -and $card.InterfaceType -ne 6) {continue}
        if ($card.PnPDeviceID -in $disabled.PnPDeviceID) {continue}
        $ip=@($ips | Where-Object InterfaceIndex -eq $card.ifIndex)
        $profile=@($profiles | Where-Object InterfaceIndex -eq $card.ifIndex)
        $state=Resolve-LinkState $card $ip $profile
        $card | Add-Member -NotePropertyName LinkState -NotePropertyValue $state -Force
        $card | Add-Member -NotePropertyName HasInternetProfile -NotePropertyValue ($profile.IPv4Connectivity -contains 'Internet' -or $profile.IPv6Connectivity -contains 'Internet') -Force
        $card
    }
    $disabled
}
function Lookup-Card([guid]$id) {
    Physical-Cards | Where-Object { [guid]$_.InterfaceGuid -eq $id }
}
function Restore-Card($card) {
    if (!$card) {throw '系统未检测到需要恢复的设备。'}
    if ($card.NeedsPnpEnable) {
        Enable-PnpDevice -InstanceId $card.PnPDeviceID -Confirm:$false
    } elseif ($card.LinkState -eq 'Disabled') {
        $card | Enable-NetAdapter -Confirm:$false
    }
}
function Online($card) {
    if (!$card -or $card.LinkState -ne 'Up') {return $false}
    $profile=Get-NetConnectionProfile -InterfaceIndex $card.ifIndex -ErrorAction SilentlyContinue
    $routes=@(Get-NetRoute -InterfaceIndex $card.ifIndex -PolicyStore ActiveStore -ErrorAction SilentlyContinue)
    ($profile.IPv4Connectivity -contains 'Internet' -and '0.0.0.0/0' -in $routes.DestinationPrefix) -or
    ($profile.IPv6Connectivity -contains 'Internet' -and '::/0' -in $routes.DestinationPrefix)
}
function Wireless-Profile($card) {
    if (!('LinkSwitchWlan' -as [type])) {Add-Type -Path (Join-Path $PSScriptRoot 'Wlan.cs')}
    [LinkSwitchWlan]::Profile([guid]$card.InterfaceGuid)
}
function Disconnect-Wireless($card) {
    [LinkSwitchWlan]::Disconnect([guid]$card.InterfaceGuid)
}
function Reconnect-Wireless($card,$profile) {
    [LinkSwitchWlan]::Connect([guid]$card.InterfaceGuid,$profile)
}
function Wait-Line($id,$wifiTarget) {
    $opened=$false
    $deadline=[DateTime]::UtcNow.AddSeconds($(if ($wifiTarget) {120} else {35}))
    do {
        $card=Lookup-Card $id
        if (Online $card) {return}
        if (!$opened -and $wifiTarget -and $card.LinkState -in 'Disconnected','Unknown') {
            Start-Process explorer.exe 'ms-availablenetworks:'
            $opened=$true
        }
        Start-Sleep -Milliseconds 600
    } while ([DateTime]::UtcNow -lt $deadline)
    throw '目标线路尚未就绪。请检查连接及默认网关，原线路已保留。'
}
function Confirm-Switch($id,$wifiTarget,$disabledIds) {
    $stable=0
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    do {
        $all=@(Physical-Cards)
        $remaining=@($all | Where-Object { (Is-Wifi $_) -ne $wifiTarget -and $_.LinkState -ne 'Disabled' })
        $disabled=@($all | Where-Object LinkState -eq 'Disabled' | ForEach-Object { [guid]$_.InterfaceGuid })
        $missing=@($disabledIds | Where-Object { $_ -notin $disabled })
        if (!$remaining.Count -and !$missing.Count -and (Online ($all | Where-Object { [guid]$_.InterfaceGuid -eq $id }))) {
            $stable++
            if ($stable -ge 2) {return}
        } else {$stable=0}
        Start-Sleep -Milliseconds 600
    } while ([DateTime]::UtcNow -lt $deadline)
    throw '切换后目标线路未稳定，或另一条线路仍在连接。'
}
function Undo-Line($entry) {
    $card=Lookup-Card $entry.Id
    if (!$card) {throw '设备已移除。'}
    Restore-Card $card
    $joinRequested=$false
    $deadline=[DateTime]::UtcNow.AddSeconds(25)
    do {
        $card=Lookup-Card $entry.Id
        if ($entry.Profile -and !$joinRequested -and $card.LinkState -in 'Up','Disconnected') {
            if ($card.LinkState -ne 'Up' -or (Wireless-Profile $card) -cne $entry.Profile) {
                Reconnect-Wireless $card $entry.Profile
                $joinRequested=$true
            }
        }
        if ($card -and $card.LinkState -notin 'Disabled','Not Present' -and (!$entry.WasUp -or $card.LinkState -eq 'Up')) {
            if ((!$entry.Profile -or (Wireless-Profile $card) -ceq $entry.Profile) -and (!$entry.WasOnline -or (Online $card))) {return}
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw '未能确认设备恢复到切换前的连接状态。'
}
function Switch-Line([guid]$id) {
    $card=Lookup-Card $id
    if (!$card) {throw '所选网卡已移除，请刷新。'}
    $wifiTarget=Is-Wifi $card
    Restore-Card $card
    Wait-Line $id $wifiTarget
    $changes=New-Object Collections.Stack
    try {
        $others=@(Physical-Cards | Where-Object { (Is-Wifi $_) -ne $wifiTarget -and $_.LinkState -ne 'Disabled' })
        foreach ($other in $others) {
            if ($other.LinkState -eq 'Unknown') {throw "Windows 尚未确认 $($other.Name) 的连接状态，请稍后重试。"}
            $profile=$null
            if ((Is-Wifi $other) -and $other.LinkState -eq 'Up') {
                $profile=Wireless-Profile $other
            }
            if (!(Online (Lookup-Card $id))) {throw '目标线路已掉线。'}
            $changes.Push([pscustomobject]@{Id=[guid]$other.InterfaceGuid; Name=$other.Name; Profile=$profile; WasUp=$other.LinkState -eq 'Up'; WasOnline=(Online $other)})
            $other | Disable-NetAdapter -Confirm:$false
        }
        Confirm-Switch $id $wifiTarget @($changes | ForEach-Object {$_.Id})
    } catch {
        $message=$_.Exception.Message
        $count=$changes.Count
        $errors=@()
        while ($changes.Count) {
            $entry=$changes.Pop()
            try {Undo-Line $entry} catch {$errors+="恢复 $($entry.Name) 失败：$($_.Exception.Message)"}
        }
        if ($errors.Count) {throw ($message+' '+($errors -join ' '))}
        if ($count) {throw ($message+' 已确认原线路恢复。')}
        throw
    }
}
