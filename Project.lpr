program Project;

{$MODE Delphi}

uses
  Forms, Interfaces,
  Main in 'Main.pas', MyFunctions, Procedures, XmlManager;

{$R *.res}

begin
  Application.Scaled:=True;
  Application.Title:='OpenWF Launcher';
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
