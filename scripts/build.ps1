param([switch]$Release)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ver  = (Import-PowerShellDataFile -Path "$root\src\TrayVBox.version.psd1").Version

# 1) Lint
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction SilentlyContinue
Invoke-ScriptAnalyzer -Path "$root\src\TrayVBox.ps1" -Settings "$root\PSScriptAnalyzerSettings.psd1" -Recurse -Severity Warning

# 2) Staging
$out = Join-Path $root "out\$ver"
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item $out -ItemType Directory -Force | Out-Null
Copy-Item "$root\src\TrayVBox.ps1"        "$out\TrayVBox.ps1"
Copy-Item "$root\src\TrayVBox.version.psd1" "$out\TrayVBox.version.psd1"
Copy-Item "$root\src\assets\trayvbox.ico" "$out\trayvbox.ico"

# 3) Build installer (Inno Setup must be installed on build agent)
$iss = "$root\installer\TrayVBox.iss"
# scripts/build.ps1  (only the ISCC line changes)
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) { $iscc = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe" }

# Force output to repo root so the upload step can find it
& $iscc "/O$root" /DAppVersion=$ver /DSourceDir="$out" "$iss"

Write-Host "Built version $ver to /out and installer /TrayVBox-$ver-Setup.exe"