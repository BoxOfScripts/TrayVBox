; ----- installer/TrayVBox.iss -----

; If the build didn’t pass these in, set sane defaults
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "."
#endif

#define AppName "TrayVBox"
#define TaskName "TrayVBox_AutoStart"

[Setup]
AppId={{8B25D5C3-5B6E-4E3C-9C9C-0C9AA0F2A1C1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=.
OutputBaseFilename={#AppName}-{#AppVersion}-Setup
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes
UninstallDisplayIcon={app}\trayvbox.ico
SetupIconFile={#SourceDir}\trayvbox.ico

[Files]
Source: "{#SourceDir}\TrayVBox.ps1";            DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\TrayVBox.version.psd1";   DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\trayvbox.ico";            DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\TrayVBox"; Flags: uninsneveruninstall

[Icons]
Name: "{group}\TrayVBox"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\TrayVBox.ps1"""; \
  WorkingDir: "{app}"; IconFilename: "{app}\trayvbox.ico"

[Run]
Filename: "{cmd}"; \
  Parameters: "/C schtasks /Create /TN {#TaskName} /TR ""{sys}\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """"{app}\TrayVBox.ps1"""""" /SC ONLOGON /RL HIGHEST /F /IT"; \
  Flags: runhidden

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C schtasks /Delete /TN {#TaskName} /F"; Flags: runhidden