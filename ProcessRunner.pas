unit ProcessRunner;
{$mode Delphi}

interface

uses
  Windows,
  SysUtils,
  Classes,
  SyncObjs;

type
  TProcessOutputKind = (
    pokStdOut,
    pokStdErr
  );

  TProcessOutputEvent = procedure(
    Sender: TObject;
    Kind: TProcessOutputKind;
    const Text: string
  ) of object;

  TProcessFinishedEvent = procedure(
    Sender: TObject;
    ExitCode: DWORD
  ) of object;


  TProcessReaderThread = class;
  TProcessWaitThread = class;


  TProcessRunner = class(TComponent)
  private
    FProcessHandle: THandle;
    FThreadHandle: THandle;

    FStdOutRead: THandle;
    FStdErrRead: THandle;

    FStdOutThread: TProcessReaderThread;
    FStdErrThread: TProcessReaderThread;
    FWaitThread: TProcessWaitThread;

    FRunning: Boolean;
    FExitCode: DWORD;

    FOnOutput: TProcessOutputEvent;
    FOnFinished: TProcessFinishedEvent;

    FCriticalSection: TCriticalSection;

    procedure DoOutput(
      Kind: TProcessOutputKind;
      const Text: string
    );

    procedure DoFinished(
      ExitCode: DWORD
    );

    procedure ProcessFinished(
      ExitCode: DWORD
    );

    procedure CloseHandles;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Execute(
      const ProgramName: string;
      const Parameters: string = '';
      const WorkingDir: string = '';
      ShowWindow: Word = SW_HIDE;
      Wait: Boolean = False
    ): DWORD;

    procedure Terminate;

    property Running: Boolean read FRunning;
    property ExitCode: DWORD read FExitCode;

  published
    property OnOutput: TProcessOutputEvent
      read FOnOutput
      write FOnOutput;

    property OnFinished: TProcessFinishedEvent
      read FOnFinished
      write FOnFinished;
  end;


  TProcessReaderThread = class(TThread)
  private
    FRunner: TProcessRunner;
    FPipe: THandle;
    FKind: TProcessOutputKind;

    FBuffer: TBytes;

    procedure ProcessBytes(
      const Data: TBytes
    );

    procedure SendLine(
      const Line: string
    );

  protected
    procedure Execute; override;

  public
    constructor Create(
      ARunner: TProcessRunner;
      APipe: THandle;
      AKind: TProcessOutputKind
    );

    destructor Destroy; override;
  end;


  TProcessWaitThread = class(TThread)
  private
    FRunner: TProcessRunner;
    FProcessHandle: THandle;

  protected
    procedure Execute; override;

  public
    constructor Create(
      ARunner: TProcessRunner;
      AProcessHandle: THandle
    );
  end;


implementation


{ ===========================================================================
  TProcessReaderThread
  =========================================================================== }

constructor TProcessReaderThread.Create(
  ARunner: TProcessRunner;
  APipe: THandle;
  AKind: TProcessOutputKind
);
begin
  inherited Create(True);

  FreeOnTerminate := True;

  FRunner := ARunner;
  FPipe := APipe;
  FKind := AKind;

  Start;
end;


destructor TProcessReaderThread.Destroy;
begin
  if FPipe <> 0 then
    CloseHandle(FPipe);

  inherited;
end;


procedure TProcessReaderThread.Execute;
const
  BUFFER_SIZE = 8192;
var
  Buffer: array[0..BUFFER_SIZE - 1] of Byte;
  BytesRead: DWORD;
  Data: TBytes;
begin
  while not Terminated do
  begin
    if not ReadFile(
      FPipe,
      Buffer,
      SizeOf(Buffer),
      BytesRead,
      nil
    ) then
      Break;

    if BytesRead = 0 then
      Break;

    SetLength(Data, BytesRead);

    Move(
      Buffer[0],
      Data[0],
      BytesRead
    );

    ProcessBytes(Data);
  end;

  { Entregar una última línea aunque no termine en CR/LF }
  if Length(FBuffer) > 0 then
  begin
    SendLine(
      TEncoding.UTF8.GetString(FBuffer)
    );

    SetLength(FBuffer, 0);
  end;
end;


procedure TProcessReaderThread.ProcessBytes(
  const Data: TBytes
);
var
  Temp: TBytes;
  StartPos: Integer;
  I: Integer;
  Line: TBytes;
begin
  { Concatenar buffer anterior + datos nuevos }

  SetLength(
    Temp,
    Length(FBuffer) + Length(Data)
  );

  if Length(FBuffer) > 0 then
    Move(
      FBuffer[0],
      Temp[0],
      Length(FBuffer)
    );

  if Length(Data) > 0 then
    Move(
      Data[0],
      Temp[Length(FBuffer)],
      Length(Data)
    );

  FBuffer := Temp;

  StartPos := 0;

  I := 0;

  while I < Length(FBuffer) do
  begin
    if FBuffer[I] = 10 then
    begin
      { LF encontrado }

      if (I > StartPos) and
         (FBuffer[I - 1] = 13) then
      begin
        { CRLF }

        Line := Copy(
          FBuffer,
          StartPos,
          I - StartPos - 1
        );
      end
      else
      begin
        { Solo LF }

        Line := Copy(
          FBuffer,
          StartPos,
          I - StartPos
        );
      end;

      SendLine(
        TEncoding.UTF8.GetString(Line)
      );

      StartPos := I + 1;
    end;

    Inc(I);
  end;

  { Guardar la parte incompleta }

  if StartPos > 0 then
  begin
    FBuffer := Copy(
      FBuffer,
      StartPos,
      Length(FBuffer) - StartPos
    );
  end;
end;


procedure TProcessReaderThread.SendLine(const Line: string);
var
  S: string;
  Kind: TProcessOutputKind;
  Runner: TProcessRunner;
begin
  S := Line;
  Kind := FKind;
  Runner := FRunner;

  TThread.Queue(nil, procedure
    begin
      if Assigned(Runner) then
        Runner.DoOutput(
          Kind,
          S
        );
    end
  );
end;


{ ===========================================================================
  TProcessWaitThread
  =========================================================================== }

constructor TProcessWaitThread.Create(
  ARunner: TProcessRunner;
  AProcessHandle: THandle
);
begin
  inherited Create(True);

  FreeOnTerminate := True;

  FRunner := ARunner;
  FProcessHandle := AProcessHandle;

  Start;
end;


procedure TProcessWaitThread.Execute;
var
  ExitCode: DWORD;
begin
  WaitForSingleObject(
    FProcessHandle,
    INFINITE
  );

  if GetExitCodeProcess(
    FProcessHandle,
    ExitCode
  ) then
  begin
    TThread.Queue(
      nil,
      procedure
      begin
        FRunner.ProcessFinished(
          ExitCode
        );
      end
    );
  end;
end;


{ ===========================================================================
  TProcessRunner
  =========================================================================== }

constructor TProcessRunner.Create(
  AOwner: TComponent
);
begin
  inherited Create(AOwner);

  FProcessHandle := 0;
  FThreadHandle := 0;

  FStdOutRead := 0;
  FStdErrRead := 0;

  FStdOutThread := nil;
  FStdErrThread := nil;
  FWaitThread := nil;

  FRunning := False;
  FExitCode := DWORD(-1);

  FCriticalSection := TCriticalSection.Create;
end;


destructor TProcessRunner.Destroy;
begin
  Terminate;

  FCriticalSection.Free;

  inherited;
end;


procedure TProcessRunner.CloseHandles;
begin
  if FThreadHandle <> 0 then
  begin
    CloseHandle(FThreadHandle);
    FThreadHandle := 0;
  end;

  if FProcessHandle <> 0 then
  begin
    CloseHandle(FProcessHandle);
    FProcessHandle := 0;
  end;

  if FStdOutRead <> 0 then
  begin
    CloseHandle(FStdOutRead);
    FStdOutRead := 0;
  end;

  if FStdErrRead <> 0 then
  begin
    CloseHandle(FStdErrRead);
    FStdErrRead := 0;
  end;
end;


function TProcessRunner.Execute(
  const ProgramName: string;
  const Parameters: string;
  const WorkingDir: string;
  ShowWindow: Word;
  Wait: Boolean
): DWORD;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  SA: TSecurityAttributes;

  StdOutWrite: THandle;
  StdErrWrite: THandle;

  CommandLine: string;

  CurrentDir: PWideChar;

  ExitCode: DWORD;
begin
  Result := DWORD(-1);

  if FRunning then
    raise Exception.Create(
      'Ya hay un proceso ejecutándose.'
    );

  FillChar(
    SI,
    SizeOf(SI),
    0
  );

  FillChar(
    PI,
    SizeOf(PI),
    0
  );

  FillChar(
    SA,
    SizeOf(SA),
    0
  );

  StdOutWrite := 0;
  StdErrWrite := 0;

  FExitCode := DWORD(-1);


  { -------------------------------------------------------------------------
    Seguridad
    ------------------------------------------------------------------------- }

  SA.nLength := SizeOf(SA);
  SA.lpSecurityDescriptor := nil;
  SA.bInheritHandle := True;


  { -------------------------------------------------------------------------
    stdout
    ------------------------------------------------------------------------- }

  if not CreatePipe(
    FStdOutRead,
    StdOutWrite,
    @SA,
    0
  ) then
    RaiseLastOSError;

  if not SetHandleInformation(
    FStdOutRead,
    HANDLE_FLAG_INHERIT,
    0
  ) then
    RaiseLastOSError;


  { -------------------------------------------------------------------------
    stderr
    ------------------------------------------------------------------------- }

  if not CreatePipe(
    FStdErrRead,
    StdErrWrite,
    @SA,
    0
  ) then
    RaiseLastOSError;

  if not SetHandleInformation(
    FStdErrRead,
    HANDLE_FLAG_INHERIT,
    0
  ) then
    RaiseLastOSError;


  try

    { -----------------------------------------------------------------------
      STARTUPINFO
      ----------------------------------------------------------------------- }

    SI.cb := SizeOf(SI);

    SI.dwFlags :=
      STARTF_USESHOWWINDOW or
      STARTF_USESTDHANDLES;

    SI.wShowWindow := ShowWindow;

    SI.hStdInput :=
      GetStdHandle(STD_INPUT_HANDLE);

    SI.hStdOutput :=
      StdOutWrite;

    SI.hStdError :=
      StdErrWrite;


    { -----------------------------------------------------------------------
      Línea de comandos
      ----------------------------------------------------------------------- }

    if Parameters <> '' then
      CommandLine :=
        '"' + ProgramName + '" ' + Parameters
    else
      CommandLine :=
        '"' + ProgramName + '"';


    if WorkingDir <> '' then
      CurrentDir :=
        PWideChar(WorkingDir)
    else
      CurrentDir := nil;


    { -----------------------------------------------------------------------
      Crear proceso
      ----------------------------------------------------------------------- }

    if not CreateProcessW(
      nil,
      PWideChar(CommandLine),
      nil,
      nil,
      True,
      CREATE_NEW_PROCESS_GROUP or
      NORMAL_PRIORITY_CLASS,
      nil,
      CurrentDir,
      SI,
      PI
    ) then
      RaiseLastOSError;


    FProcessHandle := PI.hProcess;
    FThreadHandle := PI.hThread;

    FRunning := True;


    { -----------------------------------------------------------------------
      El padre NO debe conservar los handles de escritura.
      ----------------------------------------------------------------------- }

    CloseHandle(StdOutWrite);
    StdOutWrite := 0;

    CloseHandle(StdErrWrite);
    StdErrWrite := 0;


    { -----------------------------------------------------------------------
      Lectores
      ----------------------------------------------------------------------- }

    FStdOutThread :=
      TProcessReaderThread.Create(
        Self,
        FStdOutRead,
        pokStdOut
      );

    FStdOutRead := 0;


    FStdErrThread :=
      TProcessReaderThread.Create(
        Self,
        FStdErrRead,
        pokStdErr
      );

    FStdErrRead := 0;


    { -----------------------------------------------------------------------
      Espera
      ----------------------------------------------------------------------- }

    if Wait then
    begin

      WaitForSingleObject(
        FProcessHandle,
        INFINITE
      );

      if GetExitCodeProcess(
        FProcessHandle,
        ExitCode
      ) then
      begin
        FExitCode := ExitCode;
        Result := ExitCode;
      end;

      ProcessFinished(
        FExitCode
      );

    end
    else
    begin

      FWaitThread :=
        TProcessWaitThread.Create(
          Self,
          FProcessHandle
        );

    end;

  except
    on E: Exception do
    begin
      if StdOutWrite <> 0 then
        CloseHandle(StdOutWrite);

      if StdErrWrite <> 0 then
        CloseHandle(StdErrWrite);

      CloseHandles;

      FRunning := False;

      raise;
    end;
  end;


  if StdOutWrite <> 0 then
    CloseHandle(StdOutWrite);

  if StdErrWrite <> 0 then
    CloseHandle(StdErrWrite);
end;


procedure TProcessRunner.Terminate;
begin
  FCriticalSection.Acquire;

  try

    if not FRunning then
      Exit;

    if FProcessHandle <> 0 then
    begin
      Windows.TerminateProcess(
        FProcessHandle,
        1
      );
    end;

    FRunning := False;

  finally
    FCriticalSection.Release;
  end;
end;


procedure TProcessRunner.DoOutput(
  Kind: TProcessOutputKind;
  const Text: string
);
begin
  if Assigned(FOnOutput) then
    FOnOutput(
      Self,
      Kind,
      Text
    );
end;


procedure TProcessRunner.ProcessFinished(
  ExitCode: DWORD
);
begin
  FCriticalSection.Acquire;

  try

    if not FRunning then
      Exit;

    FExitCode := ExitCode;
    FRunning := False;

  finally
    FCriticalSection.Release;
  end;

  DoFinished(ExitCode);
end;


procedure TProcessRunner.DoFinished(
  ExitCode: DWORD
);
begin
  if Assigned(FOnFinished) then
    FOnFinished(
      Self,
      ExitCode
    );
end;


end.
