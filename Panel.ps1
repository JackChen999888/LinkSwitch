param([ValidateSet('Panel','Apply','Check')][string]$Mode='Panel',[guid]$AdapterId=[guid]::Empty)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Network.ps1')
if ($Mode -eq 'Apply') {
    $lock=New-Object Threading.Mutex($false,'Local\LinkSwitchExclusiveWorker')
    try {
        try {$owned=$lock.WaitOne(0)} catch [Threading.AbandonedMutexException] {$owned=$true}
        if (!$owned) {throw '另一个面板正在切换线路。'}
        Switch-Line $AdapterId
        exit 0
    } catch {
        [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'切换未完成')
        exit 1
    } finally {if ($owned) {$lock.ReleaseMutex()}; $lock.Dispose()}
}
$form=New-Object Windows.Forms.Form
$form.Icon=[Drawing.Icon]::new((Join-Path $PSScriptRoot 'LinkSwitch.ico'),32,32)
$form.Text='网络线路面板'
$form.ClientSize=New-Object Drawing.Size(636,502)
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.StartPosition='CenterScreen'
$form.BackColor=[Drawing.Color]::FromArgb(246,248,250)
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
function Control($kind,$caption,$x,$y,$w,$h) {
    $c=New-Object "Windows.Forms.$kind"
    $c.Text=$caption
    $c.SetBounds($x,$y,$w,$h)
    $form.Controls.Add($c)
    $c
}
$title=Control Label '网络线路' 24 18 430 40
$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',18,[Drawing.FontStyle]::Bold)
$navy=[Drawing.Color]::FromArgb(25,55,82)
$teal=[Drawing.Color]::FromArgb(21,105,109)
$form.ForeColor=$navy
$summary=Control Label '' 24 72 588 90
$summary.BackColor=$navy
$summary.ForeColor=[Drawing.Color]::White
$summary.Padding=New-Object Windows.Forms.Padding(16,7,10,4)
$summary.TextAlign='MiddleLeft'
$deck=Control FlowLayoutPanel '' 24 176 597 157
$deck.AutoScroll=$true
$deck.WrapContents=$false
$wifi=Control Button '更换 Wi-Fi 热点…' 24 348 170 36
$wifi.Enabled=$false
$refresh=Control Button '刷新状态' 511 21 101 32
$updated=Control Label '正在读取状态…' 300 21 201 32
$updated.TextAlign='MiddleRight'
foreach ($b in $wifi,$refresh) {
    $b.FlatStyle='Flat'
    $b.FlatAppearance.BorderSize=0
    $b.BackColor=[Drawing.Color]::FromArgb(224,233,241)
    $b.Cursor=[Windows.Forms.Cursors]::Hand
}
$note=Control Label '选好目标线路后，面板会先确认它能上网，再断开另一条线路。' 24 404 588 80
function Add-Card($c) {
    $wireless=$c.NdisPhysicalMedium -in 1,9 -or $c.MediaType -eq 'Native 802.11'
    $kind=if ($wireless) {'Wi-Fi'} else {'网线'}
    $up=$c.Status -eq 'Up'
    $card=New-Object Windows.Forms.Panel
    $card.Size=New-Object Drawing.Size(285,134)
    $card.Margin=New-Object Windows.Forms.Padding(0,0,12,0)
    $card.BackColor=[Drawing.Color]::White
    $deck.Controls.Add($card)
    $symbol=Control Label '' 16 16 34 32
    $symbol.Text=if ($wireless) {[char]0xE701} else {[char]0xE839}
    $symbol.Font=New-Object Drawing.Font('Segoe MDL2 Assets',18)
    $symbol.ForeColor=$teal
    $heading=Control Label $kind 55 12 110 32
    $heading.Font=New-Object Drawing.Font('Microsoft YaHei UI',15,[Drawing.FontStyle]::Bold)
    $state=Control Label $(if ($up) {'已连接'} elseif ($c.Status -eq 'Disabled' -or $c.NeedsPnpEnable) {'已停用'} else {'未连接'}) 174 16 94 24
    $state.TextAlign='MiddleRight'
    $state.ForeColor=if ($up) {$teal} else {[Drawing.Color]::DimGray}
    $alias=Control Label $c.Name 17 49 250 24
    $alias.AutoEllipsis=$true
    $btn=Control Button $(if ($wireless) {'使用 Wi-Fi 并断开网线'} else {'使用网线并断开 Wi-Fi'}) 16 83 253 35
    $btn.FlatStyle='Flat'
    $btn.FlatAppearance.BorderSize=0
    $btn.BackColor=$teal
    $btn.ForeColor=[Drawing.Color]::White
    $btn.Tag=$c.InterfaceGuid
    $btn.Cursor=[Windows.Forms.Cursors]::Hand
    $btn.Add_Click({param($sender,$eventArgs) Invoke-Change $sender.Tag})
    foreach ($child in $symbol,$heading,$state,$alias,$btn) {$card.Controls.Add($child)}
}
function Show-State($s) {
    try {
        $cardState=ConvertTo-Json -Compress -InputObject @($s.Cards | Select-Object InterfaceGuid,Name,Status,NdisPhysicalMedium,MediaType)
        if ($cardState -ne $script:lastCards) {
            while ($deck.Controls.Count) {$deck.Controls[0].Dispose()}
            foreach ($c in $s.Cards) {Add-Card $c}
            $script:lastCards=$cardState
        }
        $lines=foreach ($af in 'IPv4','IPv6') {
            $scores=foreach ($r in $s.Routes) {
                $ip=$s.Ips | Where-Object { $_.AddressFamily -eq $af -and $_.InterfaceIndex -eq $r.InterfaceIndex -and $_.ConnectionState -eq 'Connected' }
                if ($ip -and $r.AddressFamily -eq $af) { [pscustomobject]@{Name=$ip.InterfaceAlias;Cost=([long]$ip.InterfaceMetric+$r.RouteMetric)} }
            }
            $best=$scores | Sort-Object Cost | Select-Object -First 1
            $name=if ($best) { (@($scores | Where-Object Cost -eq $best.Cost | Select-Object -ExpandProperty Name -Unique) -join ' / ') } else {'无可用默认线路'}
            "$af  物理线路首选：$name"
        }
        $via=if ($s.Via) {$s.Via} else {'无可用路由'}
        $wl=@($s.Cards | Where-Object {Is-Wifi $_})
        $lan=@($s.Cards | Where-Object {!(Is-Wifi $_)})
        $wifiOnly=('Up' -in $wl.Status -and !@($lan | Where-Object Status -ne 'Disabled').Count)
        $wiredOnly=('Up' -in $lan.Status -and !@($wl | Where-Object Status -ne 'Disabled').Count)
        $modeText=if ($wifiOnly) {'仅使用 Wi-Fi'} elseif ($wiredOnly) {'仅使用网线'} elseif ('Up' -in $wl.Status -and 'Up' -in $lan.Status) {'两条线路均已连接，请选择下方一条线路'} else {'尚未确认独占线路'}
        $summary.Text=(@($modeText) + $lines + "系统到 1.1.1.1 的路由：$via") -join "`r`n"
        $wifi.Enabled=$wifiOnly -and !$script:pending
        if (!$deck.Controls.Count) {$summary.Text='未找到物理网卡，正在等待设备。'}
        $updated.Text='最近更新  '+(Get-Date -Format 'HH:mm:ss')
        $script:stateValid=$true
        $deck.Enabled=!$script:pending
    } catch { Show-ReadError $_ }
}
function Show-ReadError($reason) {
    $script:stateValid=$false
    $deck.Enabled=$false
    $wifi.Enabled=$false
    $updated.Text='等待重试'
    $summary.Text="状态读取失败，将自动重试：$reason"
}
$workerTimer=New-Object Windows.Forms.Timer
$workerTimer.Interval=450
function Invoke-Change([guid]$target) {
    if ($script:pending -or !$script:stateValid) {return}
    try {
        $argsLine='-NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Mode Apply -AdapterId '+$target
        $script:pending=Start-Process "$PSHOME\powershell.exe" -ArgumentList $argsLine -Verb RunAs -WindowStyle Hidden -PassThru
        $deck.Enabled=$false
        $wifi.Enabled=$false
        $note.Text='正在切换。如果出现无线网络列表，请选择热点并连接。'
        $workerTimer.Start()
    } catch {$note.Text=$_.Exception.Message}
}
$workerTimer.Add_Tick({
    if (!$script:pending.HasExited) {return}
    $workerTimer.Stop()
    $success=$script:pending.ExitCode -eq 0
    $script:pending.Dispose()
    $script:pending=$null
    $deck.Enabled=$script:stateValid
    Request-Refresh
    $note.Text=if ($success) {'已切换，另一条线路已断开。点击另一张卡片即可切回。'} else {'切换未完成，请检查目标线路后重试。'}
})
$refresh.Add_Click({Request-Refresh})
$wifi.Add_Click({
    try { Start-Process explorer.exe 'ms-availablenetworks:'; $note.Text='选择要连接的热点。网线保持停用。' }
    catch { $note.Text=$_.Exception.Message }
})
if ($Mode -in 'Check') {
    Show-State (Read-State)
    if (!$deck.Controls.Count -or !$script:stateValid) {throw $summary.Text}
    $summary.Text
    foreach ($card in $deck.Controls) {$card.Controls | Select-Object Text,Enabled}
    $form.Dispose()
    return
}
$reader=[PowerShell]::Create()
$null=$reader.AddScript({param($file)
    $ErrorActionPreference='Stop'
    . $file
    Read-State
}).AddArgument((Join-Path $PSScriptRoot 'Network.ps1'))
$refreshTimer=New-Object Windows.Forms.Timer
$refreshTimer.Interval=200
function Request-Refresh {
    if ($script:readTask) {$script:readAgain=$true; return}
    $script:nextRead=[datetime]::UtcNow.AddSeconds(3)
    $script:readTask=$reader.BeginInvoke()
}
$refreshTimer.Add_Tick({
    if ($script:readTask) {
        if (!$script:readTask.IsCompleted) {return}
        try {
            $result=$reader.EndInvoke($script:readTask)
            if ($result.Count -ne 1) {throw '未收到网卡状态'}
            Show-State $result[0]
        } catch {Show-ReadError $_}
        finally {$script:readTask=$null; $reader.Streams.Error.Clear()}
    }
    if ($script:readAgain -or [datetime]::UtcNow -ge $script:nextRead) {
        $script:readAgain=$false
        Request-Refresh
    }
})
$form.Add_Shown({Request-Refresh; $refreshTimer.Start()})
$form.Add_FormClosed({
    $refreshTimer.Dispose()
    $workerTimer.Dispose()
    $reader.Dispose()
})
[void]$form.ShowDialog()
