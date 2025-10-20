; ----- installer/TrayVBox.iss -----

; If the build didn’t pass these in, set sane defaults
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "."
#endif

#define AppName  "TrayVBox"
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

; --- Icon references (guarded so missing files won't break the build) ---
#ifexist "{#SourceDir}\assets\trayvbox-setup.ico"
SetupIconFile={#SourceDir}\assets\trayvbox-setup.ico
#endif
#ifexist "{#SourceDir}\assets\trayvbox.ico"
UninstallDisplayIcon={app}\trayvbox.ico
#endif

[Files]
Source: "{#SourceDir}\TrayVBox.ps1";            DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\TrayVBox.version.psd1";   DestDir: "{app}"; Flags: ignoreversion

; Install icons if present
#ifexist "{#SourceDir}\assets\trayvbox.ico"
Source: "{#SourceDir}\assets\trayvbox.ico";     DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist "{#SourceDir}\assets\trayvbox-setup.ico"
Source: "{#SourceDir}\assets\trayvbox-setup.ico"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Dirs]
Name: "{commonappdata}\TrayVBox"; Flags: uninsneveruninstall

[Icons]
; Start Menu shortcut (two variants: with or without icon), chosen at preprocess time
#ifexist "{#SourceDir}\assets\trayvbox.ico"
Name: "{group}\TrayVBox"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\TrayVBox.ps1"""; \
  WorkingDir: "{app}"; IconFilename: "{app}\trayvbox.ico"
#else
Name: "{group}\TrayVBox"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\TrayVBox.ps1"""; \
  WorkingDir: "{app}"
#endif

[Run]
; Create/overwrite a per-user logon task that starts the tray hidden
Filename: "{cmd}"; \
  Parameters: "/C schtasks /Create /TN {#TaskName} /TR ""{sys}\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """"{app}\TrayVBox.ps1"""""" /SC ONLOGON /RL HIGHEST /F /IT"; \
  Flags: runhidden

[UninstallRun]
; Remove the scheduled task on uninstall
Filename: "{cmd}"; Parameters: "/C schtasks /Delete /TN {#TaskName} /F"; Flags: runhidden