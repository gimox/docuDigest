[Setup]
AppName=DocuDigest OCR
AppVersion=1.0.0
DefaultDirName={autopf}\DocuDigestOCR
DefaultGroupName=DocuDigest OCR
OutputDir=..\build\windows
OutputBaseFilename=DocuDigestOCR-Installer
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DocuDigest OCR"; Filename: "{app}\docudiget.exe"
Name: "{commondesktop}\DocuDigest OCR"; Filename: "{app}\docudiget.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\docudiget.exe"; Description: "{cm:LaunchProgram,DocuDigest OCR}"; Flags: nowait postinstall skipifsilent
