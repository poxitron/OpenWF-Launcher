unit XmlManager;

{$mode Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Buttons, Menus, INIFiles, LazFileUtils,
  DOM, XMLRead, XMLUtils, LazUTF8, FileUtil, XPath;

function GetManifestBasedOnGameTitle(xmlDoc: TXMLDocument; const GameTitle: String): String;     // Devuelve el manifest que corresponde con el nombre del juego seleccionado
function GetGameTitleBasedOnManifest(xmlDoc: TXMLDocument; const ManifestID: String): String;    // Devuelve el nombre del juego que corresponde con el manifest seleccionado
procedure GetXMLNodeValues(xmlDoc: TXMLDocument; NodeName: string; const Dest: TStrings);  // Devuelve todos el valor de todos los nodos del manifes.xml que coinciden con NodeName y los añade componente Dest}
function GetBuildInfo(const Parm1, Param2: string; xmlDoc: TXMLDocument): string;

implementation

uses
  Main;

function GetManifestBasedOnGameTitle(xmlDoc: TXMLDocument; const GameTitle: String): String;
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

function GetGameTitleBasedOnManifest(xmlDoc: TXMLDocument; const ManifestID: String): String;
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

procedure GetXMLNodeValues(xmlDoc: TXMLDocument; NodeName: string; const Dest: TStrings);

  procedure SearchNode(Node: TDOMNode);
  var
    Child: TDOMNode;
  begin
    if Node = nil then
      Exit;

    if SameText(Node.NodeName, NodeName) then
      Dest.Add(Node.TextContent);

    Child := Node.FirstChild;
    while Child <> nil do
    begin
      SearchNode(Child);
      Child := Child.NextSibling;
    end;
  end;

begin
  SearchNode(xmlDoc.DocumentElement);

{ Ejemplo:
  GetXMLNodeValues('title', Memo1.Lines);
}
end;

function GetBuildInfo(const Parm1, Param2: string; xmlDoc: TXMLDocument): string;
var
  GameNode:  TDOMNode;
  ChildNode: TDOMNode;
  InfoNode:  TDOMNode;
begin
  Result := '';
  try
    if (xmlDoc = nil) or (xmlDoc.DocumentElement = nil) then
      Exit;

    { Recorre los nodos <game> }
    GameNode := xmlDoc.DocumentElement.FirstChild;

    while GameNode <> nil do
    begin
      if SameText(GameNode.NodeName, 'game') then
      begin
        { Busca Parm1 entre los hijos de <game> }
        ChildNode := GameNode.FirstChild;
        while ChildNode <> nil do
        begin
          if (ChildNode.NodeType = ELEMENT_NODE) and
             SameText(Trim(ChildNode.TextContent), Parm1) then
          begin
            { Una vez encontrada la build, se busca el Param2 }
            InfoNode := GameNode.FirstChild;
            while InfoNode <> nil do
            begin
              if (InfoNode.NodeType = ELEMENT_NODE) and
                 SameText(InfoNode.NodeName, Param2) then
              begin
                Result := Trim(InfoNode.TextContent);
                Exit;
              end;
              InfoNode := InfoNode.NextSibling;
            end;
          end;
          ChildNode := ChildNode.NextSibling;
        end;
      end;
      GameNode := GameNode.NextSibling;
    end;
  except
    on E: Exception do
    begin
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

end.

