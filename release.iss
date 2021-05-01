; -- 64Bit.iss --
; Demonstrates installation of a program built for the x64 (a.k.a. AMD64)
; architecture.
; To successfully run this installation and the program it installs,
; you must have a "x64" edition of Windows.

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
#define AppName "M'Overlay"
#define AppMajor
#define AppMinor
#define AppRevision
#define AppBuild
#define AppVersion GetVersionComponents("build/x64/m-overlay-x64.exe", AppMajor, AppMinor, AppRevision, AppBuild)
#define AppVersion Str(AppMajor) + "." + Str(AppMinor) + "." + Str(AppRevision)
DisableWelcomePage=no
AppName={#AppName}
AppId={#AppName}
AppVersion={#AppVersion}
AppPublisher=Bkacjios
AppPublisherURL=https://github.com/bkacjios
AppUpdatesURL=https://github.com/bkacjios/m-overlay/releases
AppSupportURL=https://github.com/bkacjios/m-overlay/issues
WizardStyle=modern
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\m-overlay-64.exe
SetupIconFile=installer/icon.ico
WizardImageFile=installer/wizardbanner.bmp
WizardSmallImageFile=installer/wizard.bmp
Compression=lzma2
SolidCompression=yes
OutputDir=./releases
OutputBaseFilename={#AppName} - installer ({#AppVersion})
; "ArchitecturesAllowed=x64" specifies that Setup cannot run on
; anything but x64.
ArchitecturesAllowed=x64
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
LicenseFile=build/x64/license.txt

[Files]                                
Source: "build/x64/license.txt"; DestDir: "{app}"; DestName: "license.txt"; Flags: ignoreversion                                    
Source: "build/x64/m-overlay-x64.exe"; DestDir: "{app}"; DestName: "m-overlay-64.exe"; Flags: ignoreversion       
Source: "build/x64/love.dll"; DestDir: "{app}"; DestName: "love.dll"; Flags: ignoreversion
Source: "build/x64/lua51.dll"; DestDir: "{app}"; DestName: "lua51.dll"; Flags: ignoreversion
Source: "build/x64/mpg123.dll"; DestDir: "{app}"; DestName: "mpg123.dll"; Flags: ignoreversion
Source: "build/x64/msvcp120.dll"; DestDir: "{app}"; DestName: "msvcp120.dll"; Flags: ignoreversion
Source: "build/x64/msvcr120.dll"; DestDir: "{app}"; DestName: "msvcr120.dll"; Flags: ignoreversion      
Source: "build/x64/OpenAL32.dll"; DestDir: "{app}"; DestName: "OpenAL32.dll"; Flags: ignoreversion
Source: "build/x64/SDL2.dll"; DestDir: "{app}"; DestName: "SDL2.dll"; Flags: ignoreversion
Source: "build/x64/sqlite3.dll"; DestDir: "{app}"; DestName: "sqlite3.dll"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\m-overlay-64.exe"

[Run]
Filename: {app}\m-overlay-64.exe; Description: "Launch {#AppName}"; Flags: postinstall shellexec skipifsilent nowait