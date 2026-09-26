unit Procedures;

{$mode Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, FileUtil;

procedure DescargarInstalarBootstrapper;
procedure InstalarActualizarServidor;
procedure InstalarActualizarLibraryDependencies;
procedure DescargarActualizarStrippedAssets;
procedure DescargarActualizarMango;
procedure AddInstalledGamesToComboBox(const Dest: TStrings; DescendingSort: Boolean);

implementation

uses
  Main, MyFunctions, XmlManager;


procedure DescargarInstalarBootstrapper;
var
  i: Integer;
  b: Boolean;
  Parametros: String;
  WorkingDir: String;
begin

  try
    { Comprueba si se puede descargar el Bootstrapper. Devuelve 0 si tuvo éxito, 4 si no lo tuvo }
    i := ExecNewProcess(Format('"%s" --spider %s', [WgetPath, BootstrapperUrl]), RutaEjecutable, Form1.Memo_Servidor);
    case i of
      0 :
        begin
          Parametros := Format('"%s" "%s" -O "%s"', [WgetPath, BootstrapperUrl, 'Bootstrapper Setup.exe']);
          WorkingDir := RutaEjecutable;

          Form1.StatusBar1.SimpleText := 'Descargando el Bootstrapper...';
          ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
          Form1.StatusBar1.SimpleText := '';
        end;
      1..99 :
        begin
          MessageDlg('No se ha podido descargar el Bootstrapper.' + sLineBreak + 'Compruebe que la url sea accesible:' + sLineBreak + sLineBreak + 'https://about.openwf.io/supplementals/Bootstrapper Setup.exe', mtError, [mbOK], 0);
        end;
    end;
  except
    on E: Exception do
      MessageDlg('Ha ocurrido un error: ' + E.Message, mtError, [mbOK], 0);
  end;

  try
    { Comprueba si el juego está instalado }
    b := FileExists(RutaEjecutable + '\Bootstrapper Setup.exe');
    case b of
      True :
        begin
          Parametros := Format('"%s"', [BootstrapperPath]);
          WorkingDir := RutaEjecutable + GameInstallPath + ManifestID;

          Form1.StatusBar1.SimpleText := 'Instalando el bootstrapper...';
          ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
          Form1.StatusBar1.SimpleText := '';
        end;
      False :
        begin
          MessageDlg('Error al instalar el bootstrapper.' + sLineBreak + 'El archivo "Bootstrapper Setup.exe" no está descargado.', mtError, [mbOK], 0);
        end;
    end;
  except
    on E: Exception do
      MessageDlg('Ha ocurrido un error: ' + E.Message, mtError, [mbOK], 0);
  end;

end;

procedure InstalarActualizarServidor;
var
  WorkingDir: string;
  SourceFile: string;
  DestFile: string;
begin
  try
    if DirectoryExists(SpaceNinjaServerPath) then
    begin
      { Actualiza el servidor si ya estaba instalado }
      WorkingDir := SpaceNinjaServerPath;

      Form1.Memo_Servidor.Lines.Add('||======== Actualizando el servidor ========||');
      Form1.StatusBar1.SimpleText := 'Actualizando el servidor...';

      ExecNewProcess(Format('"%s" fetch --prune', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" restore package-lock.json', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" stash', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" checkout --force origin/main', [GitPath]), WorkingDir, Form1.Memo_Servidor);
    end
    else
    begin
      { Instala el servidor si no está instalado }
      WorkingDir := RutaEjecutable;

      Form1.Memo_Servidor.Lines.Add('||======== Instalando el servidor ========||');
      Form1.StatusBar1.SimpleText := 'Instalando el servidor...';

      ExecNewProcess(Format('"%s" clone "%s"', [GitPath, SpaceNinjaServerURL]), WorkingDir, Form1.Memo_Servidor);
    end;

    { Crear el archivo config.json si no existe }
    SourceFile := IncludeTrailingPathDelimiter(SpaceNinjaServerPath) + 'config-vanilla.json';
    DestFile := IncludeTrailingPathDelimiter(SpaceNinjaServerPath) + 'config.json';

    if not FileExists(DestFile) then
      if not CopyFile(PChar(SourceFile), PChar(DestFile), False) then
        raise Exception.Create('No se pudo crear el archivo config.json.');

  except
    on E: Exception do
    begin
      MessageDlg('Error al instalar/actualizar el servidor: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;

  Form1.StatusBar1.SimpleText := '';
end;

procedure InstalarActualizarLibraryDependencies;
var
  Parametros: string;
  WorkingDir: string;
begin
  Parametros := Format('"%s" "%s" install --omit=dev --no-audit', [NodejsPath, NpmCliPath]);
  WorkingDir := SpaceNinjaServerPath;

  Form1.Memo_Servidor.Lines.Add('');
  Form1.Memo_Servidor.Lines.Add('||======== Descargando las dependencias del servidor ========||');
  Form1.StatusBar1.SimpleText := 'Descargando las dependencias del servidor...';
  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar las dependencias del servidor: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  Form1.StatusBar1.SimpleText := '';
end;

procedure DescargarActualizarStrippedAssets;
var
  Parametros: string;
  WorkingDir: string;
begin
  try
  if DirectoryExists(SpaceNinjaServerPath + '\static\data\stripped-assets') then
    begin
    { Descarga los stripped assets si no están instalados }
    Parametros := Format('"%s" pull', [GitPath]);
    WorkingDir := SpaceNinjaServerPath + '\static\data\stripped-assets';

    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('||======== Actualizando los stripped assets ========||');
    Form1.StatusBar1.SimpleText := 'Actualizando los stripped assets...';

    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
  end
  else
  begin
    Parametros := Format('"%s" clone https://openwf.io/stripped-assets.git', [GitPath]);
    WorkingDir := SpaceNinjaServerPath + '\static\data';

    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('||======== Descargando los stripped assets ========||');
    Form1.StatusBar1.SimpleText := 'Descargando los stripped assets...';

    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
  end;
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar/actualizar los stripped assets: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  Form1.StatusBar1.SimpleText := '';
end;

procedure DescargarActualizarMango;
var
  Parametros: string;
  WorkingDir: string;
begin
  Parametros := Format('"%s" "%s" install -g steam-manifest-tools', [NodejsPath, NpmCliPath]);
  WorkingDir := RutaEjecutable + '\nodejs';

  Form1.Memo_Servidor.Lines.Add('||======== Descargando Mango ========||');
  Form1.StatusBar1.SimpleText := 'Descargando la última versión de Mango...';
  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar Mango: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  Form1.StatusBar1.SimpleText := '';
end;

procedure AddInstalledGamesToComboBox(const Dest: TStrings; DescendingSort: Boolean);
var
  SearchRec: TSearchRec;
  List_Instalado: TStringList;
  FolderName: String;
begin
  List_Instalado := TStringList.Create;
  try
    if FindFirst(RutaEjecutable + GameInstallPath + '*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and ((SearchRec.Attr and faDirectory) <> 0) then
          List_Instalado.Add(SearchRec.Name);
      until FindNext(SearchRec) <> 0;

      FindClose(SearchRec);
    end;

    if DescendingSort then
      List_Instalado.CustomSort(StringListDescendingSort);

    for FolderName in List_Instalado do
      Dest.Add(GetBuildInfo(FolderName, 'title', XMLDocument1));

  finally
    List_Instalado.Free;
  end;
  { Ejemplo:
    AddInstalledGamesToComboBox(ComboBox_Instalado.Items); }
end;


end.

