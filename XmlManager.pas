unit XmlManager;

{$mode Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Buttons, Menus, INIFiles, LazFileUtils,
  DOM, XMLRead, XMLUtils, LazUTF8, FileUtil, XPath;

procedure GetXMLNodeValues(xmlDoc: TXMLDocument; NodeName: string; const Dest: TStrings);        // Devuelve el valor de todos los nodos del manifes.xml que coinciden con NodeName y los añade a Dest}
function GetBuildInfo(const FindThisValue, GetThisValue: string; xmlDoc: TXMLDocument): string;  // Busca en el manifest.xml un valor y devuelve otro valor de esa build

implementation

uses
  Main;

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

function GetBuildInfo(const FindThisValue, GetThisValue: string; xmlDoc: TXMLDocument): string;
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
        { Busca FindThisValue entre los hijos de <game> }
        ChildNode := GameNode.FirstChild;
        while ChildNode <> nil do
        begin
          if (ChildNode.NodeType = ELEMENT_NODE) and
             SameText(Trim(ChildNode.TextContent), FindThisValue) then
          begin
            { Una vez encontrada la build, se busca el GetThisValue }
            InfoNode := GameNode.FirstChild;
            while InfoNode <> nil do
            begin
              if (InfoNode.NodeType = ELEMENT_NODE) and
                 SameText(InfoNode.NodeName, GetThisValue) then
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
  { Ejemplo:
    GetBuildInfo('42.0', 'manifest', XMLDocument1); // busca la versión 42.0 y devuelve el Manifest ID
  }
end;

end.

