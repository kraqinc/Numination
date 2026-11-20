#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{D0E55D61-7A26-4F74-BE60-6A5AA3B07F02}}
AppName=Numination
AppVersion={#AppVersion}
AppPublisher=Numination
DefaultDirName={localappdata}\Programs\Numination
DefaultGroupName=Numination
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
CloseApplications=yes
RestartApplications=no
Uninstallable=yes
UninstallDisplayName=Numination
UninstallDisplayIcon={app}\numination.exe
SetupIconFile=..\runner\resources\app_icon.ico
OutputDir=..\..\build\windows\package
OutputBaseFilename=Numination-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Numination"; Filename: "{app}\numination.exe"
Name: "{autodesktop}\Numination"; Filename: "{app}\numination.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\numination.exe"; Description: "Iniciar Numination"; Flags: nowait postinstall
