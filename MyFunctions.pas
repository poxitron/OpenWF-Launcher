unit MyFunctions;

interface

uses
 LCLIntf, LCLType, LMessages,  jwatlhelp32, windows, Messages, SysUtils, Variants, Classes, Graphics,
 Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls, INIFiles, Process, ShellApi,
 DOM, XMLRead, XMLUtils, LazUTF8, FileUtil, LazFileUtils, Math;


function ExecNewProcess(ProgramName: String; WorkingDir: String; Memo: TMemo): Integer;
function StopProcess(ExeFileName: string) : Integer;
function AskAppToClose(const sCapt: PChar): boolean;  // Close applications by the window name
function DeleteDirectoryRecursively(const ADirectory: String): Boolean; // Eliminar todos los archivos y carpetas de forma recursiva
function StringListSortCompare(List: TStringList; Index1, Index2: Integer): Integer; // Sort the list in descending order
procedure DrawRounded(Control: TWinControl);

implementation


function ExecNewProcess(ProgramName: String; WorkingDir: String; Memo: TMemo): Integer;
var
  AProcess: TProcess;
  buff: String;
begin
  Result := -1;
  buff := '';
  AProcess := TProcess.Create(nil);
  try
    AProcess.Options := AProcess.Options + [poUsePipes, poNoConsole];
    AProcess.CommandLine := ProgramName;
    AProcess.CurrentDirectory := WorkingDir;

    AProcess.Execute;
    while AProcess.Running do
    begin
      if AProcess.Output.NumBytesAvailable > 0 then
      begin
        SetLength(buff, AProcess.Output.NumBytesAvailable);
        AProcess.Output.Read(buff[1], buff.Length);
        Memo.Lines.Add(buff);
      end
      else if AProcess.Stderr.NumBytesAvailable > 0 then
      begin
        SetLength(buff, AProcess.Stderr.NumBytesAvailable);
        AProcess.Stderr.Read(buff[1], buff.Length);
        Memo.Lines.Add(buff);
      end
      else
        Sleep(10);
    end;
    if AProcess.Output.NumBytesAvailable > 0 then
    begin
      SetLength(buff, AProcess.Output.NumBytesAvailable);
      AProcess.Output.Read(buff[1], buff.Length);
      Memo.Lines.Add(buff);
    end;
    if AProcess.Stderr.NumBytesAvailable > 0 then
    begin
      SetLength(buff, AProcess.Stderr.NumBytesAvailable);
      AProcess.Stderr.Read(buff[1], buff.Length);
      Memo.Lines.Add(buff);
    end;
    Result := AProcess.ExitCode;
  finally
    AProcess.Free;
  end;
end;

function StopProcess(ExeFileName: string) : Integer;
const
  PROCESS_TERMINATE = $0001;
var
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
  ContinueLoop: BOOL;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExeFileName))
       or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(ExeFileName))) then
         Result := Integer(TerminateProcess(OpenProcess(PROCESS_TERMINATE, BOOL(0),FProcessEntry32.th32ProcessID), 0));
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function AskAppToClose(const sCapt: PChar): boolean;
var AppHandle: THandle;
begin
  AppHandle:=FindWindow(Nil, sCapt);
  Result:=PostMessage(AppHandle, WM_QUIT, 0, 0);
end;

function DeleteDirectoryRecursively(const ADirectory: String): Boolean;

  function IsDirectoryEmpty(const ADirectory: String): Boolean;
  var
    SearchRec: TSearchRec;
    SearchRes: Longint;
  begin
    Result := true;
    SearchRes := FindFirst(IncludeTrailingPathDelimiter(ADirectory) + AllFilesMask, faAnyFile, SearchRec);
    try
      while SearchRes = 0 do
      begin
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          Result := False;
          Break;
        end;
        SearchRes := FindNext(SearchRec);
      end;
    finally
      SysUtils.FindClose(SearchRec);
    end;
  end;

var
  SR: TSearchRec;
  DirName: String;
  Name: String;
begin
  DirName := AppendPathDelim(ADirectory);
  if IsDirectoryEmpty(DirName) then
    RemoveDirUTF8(DirName);
  if FindFirst(DirName + '*', faAnyFile - faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or (SR.Name = '') then
          Continue;
        Name := DirName + SR.Name;
        if not DeleteFileUTF8(Name) then
        begin
          FileSetAttrUTF8(Name, faNormal);
          DeleteFileUTF8(Name);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  if FindFirst(DirName + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if ((SR.Attr and faDirectory) <> 0)  and (SR.Name <> '.') and (SR.Name <> '..') {$ifdef unix} and ((SR.Attr and faSymLink{%H-}) = 0) {$endif unix} then
         begin
           Name := DirName + SR.Name;
           FileSetAttrUTF8(Name, faNormal);
           DeleteDirectoryRecursively(DirName + SR.Name);
         end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  Result := DeleteDirectory(ADirectory, False);
end;

function StringListSortCompare(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := AnsiCompareText(List[Index2], List[Index1]);
end;

procedure DrawRounded(Control: TWinControl);
var
   R: TRect;
   Rgn: HRGN;
begin
   with Control do
   begin
     R := ClientRect;
     rgn := CreateRoundRectRgn(R.Left, R.Top, R.Right, R.Bottom, 20, 20) ;
     Perform(EM_GETRECT, 0, lParam(@r)) ;
     InflateRect(r, - 4, - 4) ;
     Perform(EM_SETRECTNP, 0, lParam(@r)) ;
     SetWindowRgn(Handle, rgn, True) ;
     Invalidate;
   end;
{ Example:
  DrawRounded(Button1); }
end;

end.
