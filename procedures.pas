unit Procedures;

{$mode Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, FileUtil;

procedure DescargarInstalarBootstrapper;
procedure InstalarActualizarServidor;
procedure CopiarArchivoConfigServidor;
procedure InstalarActualizarLibraryDependencies;
procedure DescargarActualizarStrippedAssets;
procedure DescargarActualizarMango;
procedure AddInstalledGamesToComboBox(const Dest: TStrings);

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
  Parametros: string;
  WorkingDir: string;
begin
  if not DirectoryExists(SpaceNinjaServerPath) then
  begin
    { Instala el servidor si no está instalado }
    Parametros:= GitPath + ' clone ' + SpaceNinjaServerURL;
    WorkingDir:= RutaEjecutable;

    Form1.Memo_Servidor.Lines.Add('||======== Instalando el servidor ========||');
    Form1.StatusBar1.SimpleText := 'Instalando el servidor...';
    try
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
      Form1.StatusBar1.SimpleText := '';
    except
      on E: Exception do
      begin
        MessageDlg('Error al instalar el servidor: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end;
  end
  else
  begin
    { Actualiza el servidor si ya estaba instalado }
    WorkingDir := SpaceNinjaServerPath;

    Form1.Memo_Servidor.Lines.Add('||======== Actualizando el servidor ========||');
    Form1.StatusBar1.SimpleText := 'Actualizando el servidor...';
    try
      ExecNewProcess(Format('"%s" fetch --prune', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" restore package-lock.json', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" stash', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      ExecNewProcess(Format('"%s" checkout --force origin/main', [GitPath]), WorkingDir, Form1.Memo_Servidor);
      Form1.StatusBar1.SimpleText:= '';
    except
      on E: Exception do
      begin
        MessageDlg('Error al actualizar el servidor: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end;
  end;
end;

procedure CopiarArchivoConfigServidor;
var
  SourceFile: String;
  DestFile: String;
begin
  SourceFile := SpaceNinjaServerPath + '\config-vanilla.json';
  DestFile := SpaceNinjaServerPath + '\config.json';

  { Si el archivo 'config.json' ya existe, sale del proceso para no reemplazarlo,
     evitando que el usuario pierda la configuración que tenía }
  if FileExists(RutaEjecutable + DestFile) then
    Exit;
  try
    if not CopyFile(PChar(SourceFile), PChar(DestFile), false) then
      raise Exception.Create('El archivo config-vanilla.json no existe.');
  except
    on E: Exception do
    begin
      MessageDlg('Error al crear el archivo config.json: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
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
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar las dependencias del servidor: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;

procedure DescargarActualizarStrippedAssets;
var
  Parametros: string;
  WorkingDir: string;
begin
  { Descarga los stripped assets si no están instalados }
  if not DirectoryExists(SpaceNinjaServerPath + '\static\data\stripped-assets') then
  begin
    Parametros := Format('"%s" clone https://openwf.io/stripped-assets.git', [GitPath]);
    WorkingDir := SpaceNinjaServerPath + '\static\data';

    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('||======== Descargando los stripped assets ========||');
    Form1.StatusBar1.SimpleText := 'Descargando los stripped assets...';
    try
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
      Form1.StatusBar1.SimpleText := '';
    except
      on E: Exception do
      begin
        MessageDlg('Error al descargar los stripped assets: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end
  end
  else
  { Actualiza los stripped assets si ya estaban instalados }
  begin
    Parametros := Format('"%s" pull', [GitPath]);
    WorkingDir := SpaceNinjaServerPath + '\static\data\stripped-assets';

    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('||======== Actualizando los stripped assets ========||');
    Form1.StatusBar1.SimpleText := 'Actualizando los stripped assets...';
    try
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
      Form1.StatusBar1.SimpleText := '';
    except
      on E: Exception do
      begin
        MessageDlg('Error al actualizar los stripped assets: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end;
  end;

  { Actualiza los stripped assets si ya estban instalados }
  if DirectoryExists(SpaceNinjaServerPath + '\static\data\0') then
  begin
    Parametros := Format('"%s" pull', [GitPath]);
    WorkingDir := SpaceNinjaServerPath + '\static\data\0\';

    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('');
    Form1.Memo_Servidor.Lines.Add('||======== Actualizando los stripped assets ========||');
    Form1.StatusBar1.SimpleText := 'Actualizando los stripped assets...';
    try
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
      Form1.StatusBar1.SimpleText := '';
    except
      on E: Exception do
      begin
        MessageDlg('Error al actualizar los stripped assets: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end;
  end;
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
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar Mango: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;

procedure AddInstalledGamesToComboBox(const Dest: TStrings);
var
  Path: String;
  FolderName: String;
  GameName: String;
  List_Instalado: TStringList;
begin
  try
    List_Instalado := TStringList.Create;

    { Obtiene el directorio completo de los juegos instalados y devuelve el nombre de la carpeta del juego }
    for Path in FindAllDirectories(RutaEjecutable + GameInstallPath, false) do
      List_Instalado.Add(StringReplace(Path, RutaEjecutable + GameInstallPath, '', [rfReplaceAll, rfIgnoreCase]));

    { Ordena la lista en sentido descendente }
    List_Instalado.CustomSort(StringListSortCompare);

    { Por cada string que hay en el List_Instalado, reemplaza el nombre de la carpeta
      por los títulos de los juegos y los añade al ComboBox }
    if List_Instalado.Count > 0 then
    begin
      for FolderName in List_Instalado do
      begin
        GameName := GetBuildInfo(FolderName, 'title', XMLDocument1);
        Dest.Add(GameName);
      end;
    end;
  finally
    List_Instalado.Free;
  end;
  { Ejemplo:
    AddInstalledGamesToComboBox(ComboBox_Instalado.Items); }
end;

end.

