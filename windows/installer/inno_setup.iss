; Inno Setup Compiler Script for Kortex Academic Workspace
; -------------------------------------------------------------
; Generates a professional Windows Setup Installer (.exe) for Kortex.

#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

#ifndef SourceBuildDir
#define SourceBuildDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "..\..\dist"
#endif

#define MyAppName "Kortex Academic Workspace"
#define MyAppPublisher "Kortex"
#define MyAppURL "https://kortex.app"
#define MyAppExeName "kortex.exe"

[Setup]
AppId={{9F82A486-4B81-4C47-A968-0824B71D041A}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Kortex
DisableProgramGroupPage=yes
OutputBaseFilename=Kortex-Setup
OutputDir={#OutputDir}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceBuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#SourceBuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
