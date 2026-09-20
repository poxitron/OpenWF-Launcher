unit Procedures;

{$mode Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, jwatlhelp32, windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls, INIFiles, Process, ShellApi,
  laz2_DOM, laz2_XMLRead, laz2_XMLUtils, LazUTF8, FileUtil, LazFileUtils, Math;

function GetManifestBasedOnGameName(xmlDoc: TXMLDocument; const GameTitle: String): String; // Devuelve el manifest que corresponde con el nombre del juego seleccionado
function GetGameNameBasedOnManifest(xmlDoc: TXMLDocument; const ManifestID: String): String; //Devuelve el nombre del juego que corresponde con el manifest seleccionado
procedure DescargarBootstrapper(ProgramName: String; WorkingDir: String);
procedure InstalarBootstrapper(ProgramName: String; WorkingDir: String);

implementation

uses
  Main, MyFunctions;

{ Devuelve el manifest que corresponde con el nombre del juego seleccionado }
function GetManifestBasedOnGameName(xmlDoc: TXMLDocument; const GameTitle: String): String;
var
  GameNode: TDOMNode;
  ManifestNode: TDOMNode;
  TitleNode: TDOMNode;
begin
  Result := '';
  GameNode := xmlDoc.DocumentElement.FirstChild;

  while Assigned(GameNode) and (GameNode.NodeName = 'game') do
  begin
    ManifestNode := GameNode.FirstChild;
    while Assigned(ManifestNode) do
    begin
      if ManifestNode.TextContent = GameTitle then
      begin
        TitleNode := ManifestNode.PreviousSibling;
        Result := TitleNode.TextContent;
      end;
      ManifestNode := ManifestNode.NextSibling;
    end;
    GameNode := GameNode.NextSibling;
  end;
{ Usage example:
  s := GetManifestBasedOnGameName(XMLDocument1, ComboBox.Text);
}
end;

{ Devuelve el nombre del juego que corresponde con el manifest seleccionado }
function GetGameNameBasedOnManifest(xmlDoc: TXMLDocument; const ManifestID: String): String;
var
  GameNode: TDOMNode;
  ManifestNode: TDOMNode;
  TitleNode: TDOMNode;
begin
  Result := '';
  GameNode := xmlDoc.DocumentElement.FirstChild;

  while Assigned(GameNode) and (GameNode.NodeName = 'game') do
  begin
    ManifestNode := GameNode.FirstChild;
    while Assigned(ManifestNode) do
    begin
      if ManifestNode.TextContent = ManifestID then
      begin
        TitleNode := ManifestNode.NextSibling;
        Result := TitleNode.TextContent;
      end;
      ManifestNode := ManifestNode.NextSibling;
    end;
    GameNode := GameNode.NextSibling;
  end;
  { Usage example:
    s := GetManifestBasedOnGameName(XMLDocument1, '8617432299175747361');
  }
end;

procedure DescargarBootstrapper(ProgramName: String; WorkingDir: String);
begin
  Form1.StatusBar1.SimpleText := 'Descargando el Bootstrapper...';
  try
    ExecNewProcess(ProgramName, WorkingDir, Form1.Memo_Servidor);
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar el bootstrapper: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;

procedure InstalarBootstrapper(ProgramName: String; WorkingDir: String);
begin
  Form1.StatusBar1.SimpleText := 'Instalando el bootstrapper...';
  try
    ExecNewProcess(ProgramName, WorkingDir, Form1.Memo_Servidor);
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al instalar el bootstrapper: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;

end.

