#include "count.iss"
[Setup]
AppId=ItemContoursSpeciesUnknown
AppName=Item Contours for Species Unknown
AppVersion=2026.11.02
DefaultDirName={autopf}\Steam\steamapps\common\Species Unknown
UsePreviousAppDir=no
DisableProgramGroupPage=yes
DisableWelcomePage=yes
DisableReadyPage=yes
DirExistsWarning=no
AppendDefaultDirName=no
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallFilesDir={app}\.ItemContoursInstaller
OutputDir=output
OutputBaseFilename=ItemContours-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
UninstallDisplayName=Item Contours (Species Unknown)
[Files]
#include "payload.iss"
[Code]
var
 Paths, Hashes: array[0..{#FileCount}-1] of String;
 Owned, Changed, Existed: array[0..{#FileCount}-1] of Boolean;
 Game, Meta: String;
 Complete, Started, HadOwnership: Boolean;

procedure Init;
begin
#include "init.iss"
end;

function Digest(P: String): String;
begin
 Result := '';
 if FileExists(P) then Result := GetSHA256OfFile(P);
end;

function ResolveGame(P: String): String;
begin
 Result := RemoveBackslashUnlessRoot(P);
 if not FileExists(Result+'\Binaries\Win64\SpeciesUnknown-Win64-Shipping.exe') then
   if FileExists(Result+'\SpeciesUnknown\Binaries\Win64\SpeciesUnknown-Win64-Shipping.exe') then
     Result := Result+'\SpeciesUnknown';
end;

function Running(P: String): Boolean;
var W, Rows, Row: Variant; E: String;
begin
 Result := False;
 try
  W := CreateOleObject('WbemScripting.SWbemLocator');
  Rows := W.ConnectServer('', 'root\CIMV2').ExecQuery('SELECT ExecutablePath FROM Win32_Process WHERE Name="SpeciesUnknown-Win64-Shipping.exe"');
  for Row := 0 to Rows.Count-1 do begin
   E := Rows.ItemIndex(Row).ExecutablePath;
   if CompareText(E,P+'\Binaries\Win64\SpeciesUnknown-Win64-Shipping.exe')=0 then Result:=True;
   if E='' then Result:=True;
  end;
 except
  RaiseException('Windows could not check whether the game is closed. Close the game and try again.');
 end;
end;

function Validate(P: String): String;
var I: Integer; F: String;
begin
 Result := '';
 if not FileExists(P+'\Binaries\Win64\SpeciesUnknown-Win64-Shipping.exe') or not DirExists(P+'\Content\Paks') then begin
  Result := 'Choose the Species Unknown game folder containing Binaries and Content, or its parent folder.'; exit;
 end;
 if Running(P) then begin Result := 'Close Species Unknown before installing or removing Item Contours.'; exit; end;
 for I:=0 to {#FileCount}-1 do if not Owned[I] then begin
  F:=P+'\'+Paths[I];
  if (Pos('\mods.txt',Paths[I])=0) and (Pos('\mods.json',Paths[I])=0) then
   if FileExists(F) and (Digest(F)<>Hashes[I]) then begin
    Result:='Your existing UE4SS files differ from the supported version. Nothing was changed. Please use a separate compatible game setup. File: '+Paths[I]; exit;
   end;
 end;
 if FileExists(P+'\Binaries\Win64\ue4ss\Mods\ItemHighlighter\enabled.txt') or FileExists(P+'\Binaries\Win64\ue4ss\Mods\ContourRenderTest\enabled.txt') then
  Result:='An older item highlighting prototype is enabled. Disable that prototype before installing Item Contours.';
end;

function InitializeSetup: Boolean;
begin Init; Result:=True; end;

procedure InitializeWizard;
begin
 WizardForm.SelectDirLabel.Caption := 'Choose your Species Unknown game folder. You can select the Steam game folder or the inner SpeciesUnknown folder.';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
 Game:=ResolveGame(WizardDirValue);
 Result:=Validate(Game);
 if Result<>'' then exit;
 WizardForm.DirEdit.Text:=Game;
 Meta:=Game+'\.ItemContoursInstaller';
end;

procedure CopyChecked(S,D: String);
begin
 if not ForceDirectories(ExtractFileDir(D)) then RaiseException('Cannot create folder: '+ExtractFileDir(D));
 if not CopyFile(S,D,False) then RaiseException('Cannot write file: '+D);
 if Digest(S)<>Digest(D) then RaiseException('Copied file did not verify: '+D);
end;

procedure Rollback;
var I: Integer; F,B,Failures: String;
begin
 Failures:='';
 for I:={#FileCount}-1 downto 0 do if Changed[I] then begin
  F:=Game+'\'+Paths[I]; B:=Meta+'\recovery\'+IntToStr(I);
  if Existed[I] then begin
   if Digest(F)<>Digest(B) then CopyFile(B,F,False);
   if Digest(F)<>Digest(B) then Failures:=Failures+F+#13#10 else Changed[I]:=False;
  end else begin
   if FileExists(F) then DeleteFile(F);
   if FileExists(F) then Failures:=Failures+F+#13#10 else Changed[I]:=False;
  end;
 end;
 if Failures<>'' then RaiseException('Some files could not be restored. Keep the recovery backups in '+Meta+'. Close the game before retrying. Files: '+Failures);
 if Started then begin
  if HadOwnership then begin
   if Digest(Meta+'\ownership.ini')<>Digest(Meta+'\recovery\ownership-before.ini') then CopyChecked(Meta+'\recovery\ownership-before.ini',Meta+'\ownership.ini');
  end
  else if FileExists(Meta+'\ownership.ini') and not DeleteFile(Meta+'\ownership.ini') then RaiseException('Cannot restore the installer ownership record. Keep '+Meta);
  Started:=False;
 end;
end;

procedure SaveOwnership(K,Name,Value: String);
begin
 if not SetIniString(K,Name,Value,Meta+'\ownership.ini') then RaiseException('Cannot save install recovery information in '+Meta);
 if GetIniString(K,Name,'',Meta+'\ownership.ini')<>Value then RaiseException('Install recovery information did not verify in '+Meta);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var I: Integer; F, K, OldHash: String;
begin
 if CurStep=ssInstall then begin
  try
   if Validate(Game)<>'' then RaiseException('Game state changed. Close the game and try again.');
   ForceDirectories(Meta);
   HadOwnership:=FileExists(Meta+'\ownership.ini');
   if HadOwnership then CopyChecked(Meta+'\ownership.ini',Meta+'\recovery\ownership-before.ini');
   Started:=True;
   for I:=0 to {#FileCount}-1 do begin
    F:=Game+'\'+Paths[I]; K:=IntToStr(I);
    if not Owned[I] and FileExists(F) then continue;
    OldHash:=GetIniString(K,'installed','',Meta+'\ownership.ini');
    if Owned[I] and (OldHash<>'') and FileExists(F) and (Pos('\config.lua',Paths[I])>0) then continue;
    ExtractTemporaryFile(K);
    Existed[I]:=FileExists(F);
    if Existed[I] then CopyChecked(F,Meta+'\recovery\'+K);
    if Owned[I] and (GetIniString(K,'baseline','',Meta+'\ownership.ini')='') then begin
     if Existed[I] then begin
      CopyChecked(F,Meta+'\backups\'+K);
      SaveOwnership(K,'baseline','original');
     end else SaveOwnership(K,'baseline','absent');
    end;
    Changed[I]:=True;
    CopyChecked(ExpandConstant('{tmp}\')+K,F);
    if Digest(F)<>Hashes[I] then RaiseException('File verification failed: '+Paths[I]);
    if Owned[I] then SaveOwnership(K,'installed',Hashes[I]);
   end;
   { Final success is recorded only at ssDone. }
  except
   Rollback;
   RaiseException(GetExceptionMessage);
  end;
 end;
 if CurStep=ssDone then Complete:=True;
end;

procedure DeinitializeSetup;
begin if not Complete then Rollback; end;

function InitializeUninstall: Boolean;
begin
 Init; Game:=ExpandConstant('{app}'); Meta:=Game+'\.ItemContoursInstaller';
 Result:=not Running(Game);
 if not Result then MsgBox('Close Species Unknown before removing Item Contours.',mbError,MB_OK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var I: Integer; F,K,H: String;
begin
 if CurUninstallStep=usUninstall then begin
  if Running(Game) then RaiseException('Close Species Unknown and run uninstall again.');
  for I:=0 to {#FileCount}-1 do if Owned[I] then begin
   F:=Game+'\'+Paths[I]; K:=IntToStr(I);
   H:=GetIniString(K,'installed','',Meta+'\ownership.ini');
   if (H<>'') and (Digest(F)=H) then begin
    if GetIniString(K,'baseline','',Meta+'\ownership.ini')='original' then
      CopyChecked(Meta+'\backups\'+K,F)
    else if not DeleteFile(F) then RaiseException('Cannot remove '+F);
   end;
  end;
  DeleteFile(Meta+'\ownership.ini');
 end;
end;
