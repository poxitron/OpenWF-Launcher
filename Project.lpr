program Project;

{$MODE Delphi}

uses
  Forms, Interfaces,
  Main in 'Main.pas', MyFunctions;

{$R *.res}

begin
  Application.Title:='OpenWF Launcher';
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
