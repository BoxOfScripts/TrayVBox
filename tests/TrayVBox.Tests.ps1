$ErrorActionPreference = 'Stop'
Describe "TrayVBox" {
  It "Loads and has a version" {
    $ver = (Import-PowerShellDataFile -Path "$PSScriptRoot\..\src\TrayVBox.version.psd1").Version
    $ver | Should -Match '^\d+\.\d+\.\d+$'
  }
  It "Parses VBoxManage list output" {
    $sample = @"
"Ubuntu" {11111111-1111-1111-1111-111111111111}
"HTPC"   {22222222-2222-2222-2222-222222222222}
"@
    $names = $sample -split "`r?`n" | ForEach-Object { if ($_ -match '^\s*"(.+?)"\s+\{'){ $matches[1] } }
    $names | Should -Contain 'Ubuntu'
    $names | Should -Contain 'HTPC'
  }
}