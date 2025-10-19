param([string]$VmName)

# Relaunch in STA (needed for WinForms tray)
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  & $ps -STA -ExecutionPolicy Bypass -File $PSCommandPath @args
  exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Config ----------
$VBoxManage     = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$RefreshSeconds = 10
$Title          = if ($VmName) { "TrayVBox - $VmName" } else { "TrayVBox - All-VMs mode" }
$DebugMode      = $true      # set $false when you're happy
$LogFile        = Join-Path $env:TEMP "TrayVBox.log"

# --- Autostart config (edit as you like) ---
$AutoStartFavorites    = @()    # e.g. @("Ubuntu","HTPC")  or leave empty to rely on favorites.json
$AutoStartDelaySeconds = 4
$AutoStartLastRunning  = $true  # if last_running.json exists, it takes precedence over favorites

# --- Files for persistence ---
$ConfigDir   = Join-Path $env:ProgramData "TrayVBox"
$ConfigFile  = Join-Path $ConfigDir "favorites.json"
$LastRunFile = Join-Path $ConfigDir "last_running.json"

# ---------- Path sanity ----------
if (-not (Test-Path $VBoxManage)) {
  $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
  if ($cmd) { $script:VBoxManage = $cmd.Source }
  if (-not (Test-Path $VBoxManage)) {
    [System.Windows.Forms.MessageBox]::Show("VBoxManage not found at:`r`n$VBoxManage","TrayVBox")
    exit
  }
}

# ---------- Single-instance ----------
$scope   = if ($VmName) { $VmName } else { 'ALL' }
$created = $false
$mutex   = New-Object System.Threading.Mutex($true,"Global\TrayVBox_$scope",[ref]$created)
if (-not $created) {
  [System.Windows.Forms.MessageBox]::Show("TrayVBox already running for $scope","TrayVBox")
  exit
}

# ---------- Helpers ----------
function Get-AppIcon {
  $vbExe="C:\Program Files\Oracle\VirtualBox\VirtualBox.exe"
  if (Test-Path $vbExe){ try { return [System.Drawing.Icon]::ExtractAssociatedIcon($vbExe) } catch {Log-Debug ("ERROR: " + $_.Exception.Message)} }
  return [System.Drawing.SystemIcons]::Application
}
function New-DotImage([System.Drawing.Color]$c,[int]$s=12){
  $bmp=New-Object System.Drawing.Bitmap($s,$s)
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $brush=New-Object System.Drawing.SolidBrush($c)
  $pen=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160,0,0,0))
  $g.FillEllipse($brush,1,1,$s-3,$s-3)
  $g.DrawEllipse($pen,1,1,$s-3,$s-3)
  $pen.Dispose();$brush.Dispose();$g.Dispose()
  return $bmp
}
function Get-StatusText([bool]$r){ if($r){"[On]"}else{"[Off]"} }
function Log-Debug($m){
  if(-not $DebugMode){ return }
  $t=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $l="[$t] $m"
  Write-Information $l
  Add-Content -Path $LogFile -Value $l
}

# ---------- Run VBoxManage (sync; captures output + exit) ----------
function Run-VBox([string[]]$ArgArray) {
  $cmd = '"{0}" {1}' -f $VBoxManage, ($ArgArray -join ' ')
  Log-Debug "EXEC: $cmd"
  $ErrorActionPreference = 'Continue'
  $output = & $VBoxManage @ArgArray 2>&1
  $code   = $LASTEXITCODE
  if ($output) { Log-Debug ("OUT: " + ($output -join "`n")) }
  Log-Debug "EXIT: $code"
  return @{ Code=$code; Output=$output }
}

# ---------- Autostart helpers ----------
function Ensure-ConfigDir { if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null } }
function Get-RunningVMNames {
  (& "$VBoxManage" list runningvms 2>$null | ForEach-Object {
    if ($_ -match '^\s*"(.+?)"\s+\{') { $matches[1] }
  })
}
function Save-LastRunning {
  Ensure-ConfigDir
  $list = Get-RunningVMNames
  Log-Debug ("Saving last_running.json: " + ($list -join ", "))
  $list | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $LastRunFile
}
function Load-NameList([string]$path){
  if (-not (Test-Path $path)) { return @() }
  try {
    $raw = Get-Content -Raw -Path $path -ErrorAction Stop
    $arr = $raw | ConvertFrom-Json
    return @($arr)
  } catch {
    Log-Debug "Load-NameList error: $($_.Exception.Message)"
    return @()
  }
}
function Start-VMList([string[]]$names){
  if (-not $names -or $names.Count -eq 0) { return }
  $running = @{}
  foreach ($n in Get-RunningVMNames) { $running[$n] = $true }
  foreach ($name in $names) {
    if ($running.ContainsKey($name)) { Log-Debug "Skip already running: $name"; continue }
    Log-Debug "Autostart: $name"
    $null = Run-VBox @('startvm', $name, '--type', 'headless')
    Start-Sleep -Seconds $AutoStartDelaySeconds
  }
}

# ---------- VM list ----------
function Read-VMs{
  $all=&"$VBoxManage" list vms 2>$null
  $run=&"$VBoxManage" list runningvms 2>$null
  $running=@{}
  foreach($l in $run){ if($l -match '^\s*"(.+?)"\s+\{'){ $running[$matches[1]]=$true } }
  $vms=@()
  foreach($l in $all){
    if($l -match '^\s*"(.+?)"\s+\{([0-9a-f-]+)\}'){
      $vms+=[pscustomobject]@{Name=$matches[1];UUID=$matches[2];Running=$running.ContainsKey($matches[1])}
    }
  }
  if($VmName){$vms|Where-Object{$_.Name -eq $VmName}}else{$vms}
}

# ---------- Menu item factory (no closures; uses sender.Tag) ----------
function New-ActionItem([string]$text,[string]$vmName,[string]$action){
  $it=New-Object System.Windows.Forms.ToolStripMenuItem($text)
  $it.Tag=@{Name=$vmName;Action=$action}
  $it.Add_Click([System.EventHandler]{param($s,$e)
    $t=$s.Tag; $n=[string]$t["Name"]; $a=[string]$t["Action"]
    Log-Debug "CLICK action=$a VM=$n text='$($s.Text)'"
    if([string]::IsNullOrEmpty($n)-or [string]::IsNullOrEmpty($a)){ Log-Debug "ERROR: empty Name/Action"; return }
    switch($a){
      "start" { $vbArgs=@('startvm', $n, '--type', 'headless') }
      "save"  { $vbArgs=@('controlvm', $n, 'savestate') }
      "acpi"  { $vbArgs=@('controlvm', $n, 'acpipowerbutton') }
      "power" { $vbArgs=@('controlvm', $n, 'poweroff') }
      default { Log-Debug "ERROR: unknown action '$a'"; return }
    }
    $res = Run-VBox $vbArgs
    if ($res.Code -ne 0) {
      [System.Windows.Forms.MessageBox]::Show(
        ("VBoxManage failed (exit {0})`r`n{1}" -f $res.Code, ($res.Output -join "`r`n")),
        "TrayVBox"
      )
    }
    Rebuild-Menu
  })
  return $it
}

# ---------- Tray UI ----------
$notifyIcon=New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon=Get-AppIcon
$notifyIcon.Text=$Title
$notifyIcon.Visible=$true
$menu=New-Object System.Windows.Forms.ContextMenuStrip
$notifyIcon.ContextMenuStrip=$menu
$ImgRunning=New-DotImage([System.Drawing.Color]::FromArgb(0,168,84))
$ImgStopped=New-DotImage([System.Drawing.Color]::FromArgb(140,140,140))

function Add-VM-Submenu($vm){
  $sub=New-Object System.Windows.Forms.ToolStripMenuItem
  $sub.Text=("{0,-5} {1}" -f (Get-StatusText $vm.Running), $vm.Name)
  $sub.Image=$(if($vm.Running){$ImgRunning}else{$ImgStopped})
  $sub.Tag=$vm.Name

  if(-not $vm.Running){
    [void]$sub.DropDownItems.Add((New-ActionItem "Start (headless)" $vm.Name "start"))
  }else{
    [void]$sub.DropDownItems.Add((New-ActionItem "Save state"       $vm.Name "save"))
    [void]$sub.DropDownItems.Add((New-ActionItem "ACPI shutdown"    $vm.Name "acpi"))
    [void]$sub.DropDownItems.Add((New-ActionItem "Power off (hard)" $vm.Name "power"))
  }
  return $sub
}

function Rebuild-Menu{
  $menu.Items.Clear()
  $vms=Read-VMs
  if(-not $vms -or $vms.Count -eq 0){
    $hdr=New-Object System.Windows.Forms.ToolStripMenuItem("No VMs found")
    $hdr.Enabled=$false
    [void]$menu.Items.Add($hdr)
  }elseif($VmName){
    $vm=$vms|Select-Object -First 1
    $hdr=New-Object System.Windows.Forms.ToolStripMenuItem
    $hdr.Text=("{0,-5} {1}" -f (Get-StatusText $vm.Running), $vm.Name)
    $hdr.Enabled=$false
    $hdr.Image=$(if($vm.Running){$ImgRunning}else{$ImgStopped})
    [void]$menu.Items.Add($hdr)

    if(-not $vm.Running){
      [void]$menu.Items.Add((New-ActionItem "Start (headless)" $vm.Name "start"))
    }else{
      [void]$menu.Items.Add((New-ActionItem "Save state"       $vm.Name "save"))
      [void]$menu.Items.Add((New-ActionItem "ACPI shutdown"    $vm.Name "acpi"))
      [void]$menu.Items.Add((New-ActionItem "Power off (hard)" $vm.Name "power"))
    }
  }else{
    foreach($v in ($vms|Sort-Object Name)){ [void]$menu.Items.Add((Add-VM-Submenu $v)) }
  }

  [void]$menu.Items.Add("-")

  # ---- Favorites / Last-running controls ----
  $favSave = New-Object System.Windows.Forms.ToolStripMenuItem("Save current running as Favorites")
  $favSave.Add_Click([System.EventHandler]{ param($s,$e)
    try {
      Ensure-ConfigDir
      $cur = Get-RunningVMNames
      $cur | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $ConfigFile
      [System.Windows.Forms.MessageBox]::Show(("Saved favorites:`r`n{0}" -f ($cur -join "`r`n")), "TrayVBox")
    } catch {
      [System.Windows.Forms.MessageBox]::Show("Failed to save favorites: $($_.Exception.Message)","TrayVBox")
    }
  })
  [void]$menu.Items.Add($favSave)

  $startFav = New-Object System.Windows.Forms.ToolStripMenuItem("Start Favorites now")
  $startFav.Add_Click([System.EventHandler]{ param($s,$e)
    $fav = if (Test-Path $ConfigFile) { Load-NameList $ConfigFile } else { $AutoStartFavorites }
    Start-VMList $fav
    Rebuild-Menu
  })
  [void]$menu.Items.Add($startFav)

  $startLast = New-Object System.Windows.Forms.ToolStripMenuItem("Start Last-Running now")
  $startLast.Add_Click([System.EventHandler]{ param($s,$e)
    if (Test-Path $LastRunFile) { Start-VMList (Load-NameList $LastRunFile) } else {
      [System.Windows.Forms.MessageBox]::Show("No last-running record yet.","TrayVBox")
    }
    Rebuild-Menu
  })
  [void]$menu.Items.Add($startLast)

  [void]$menu.Items.Add("-")

  $refresh=New-Object System.Windows.Forms.ToolStripMenuItem("Refresh")
  $refresh.Add_Click([System.EventHandler]{param($sender,$eventArgs) Rebuild-Menu })
  [void]$menu.Items.Add($refresh)

  [void]$menu.Items.Add("-")
  $exit=New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
  $exit.Add_Click([System.EventHandler]{param($s,$e)
    try { Save-LastRunning } catch {Log-Debug ("ERROR: " + $_.Exception.Message)}
    $notifyIcon.Visible=$false; $timer.Stop()
    try{$mutex.ReleaseMutex()|Out-Null}catch{Log-Debug ("ERROR: " + $_.Exception.Message)}
    $mutex.Dispose()
    [System.Windows.Forms.Application]::Exit()
  })
  [void]$menu.Items.Add($exit)
}

# ---------- Run ----------
$notifyIcon                  = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon             = Get-AppIcon
$notifyIcon.Text             = $Title
$notifyIcon.Visible          = $true
$notifyIcon.ContextMenuStrip = $menu

Rebuild-Menu
$notifyIcon.Add_MouseClick([System.Windows.Forms.MouseEventHandler]{param($s,$e) if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){ Rebuild-Menu }})
$timer=New-Object System.Windows.Forms.Timer
$timer.Interval=$RefreshSeconds*1000
$timer.Add_Tick({ Rebuild-Menu })
$timer.Start()
Log-Debug "Tray started. Scope=$scope  VBoxManage=$VBoxManage"

# --- Autostart logic on launch ---
try {
  Ensure-ConfigDir
  $favorites = if (Test-Path $ConfigFile) { Load-NameList $ConfigFile } else { $AutoStartFavorites }
  $last      = if ($AutoStartLastRunning -and (Test-Path $LastRunFile)) { Load-NameList $LastRunFile } else { @() }

  if ($last -and $AutoStartLastRunning) {
    Log-Debug ("Autostart (last running): " + ($last -join ", "))
    Start-VMList $last
  } elseif ($favorites -and $favorites.Count -gt 0) {
    Log-Debug ("Autostart (favorites): " + ($favorites -join ", "))
    Start-VMList $favorites
  } else {
    Log-Debug "Autostart: nothing to do"
  }
} catch { Log-Debug "Autostart error: $($_.Exception.Message)" }

[System.Windows.Forms.Application]::Run()