unit Main;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls, INIFiles,
  laz2_DOM, laz2_XMLRead, laz2_XMLUtils, LazUTF8, FileUtil, LazFileUtils;

type

  { TForm1 }

  TForm1 = class(TForm)
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    ComboBox_Instalado: TComboBox;
    Button_IniciarJuego: TButton;
    Button_InstalarActualizarBootstrapper: TButton;
    ComboBox_DisponibleParaDescargar: TComboBox;
    Button_DescargarJuego: TButton;
    Button_RecargarXml: TButton;
    CheckBox_BorrarCache: TCheckBox;
    Button_IniciarServidor: TButton;
    Button_DetenerServidor: TButton;
    Button_InstalarActualizarServidor: TButton;
    Button_InstalarActualizarAplicaciones: TButton;
    Memo_Servidor: TMemo;
    StatusBar1: TStatusBar;
    Button_Test: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject);
    procedure Button_IniciarJuegoClick(Sender: TObject);
    procedure Button_InstalarActualizarBootstrapperClick(Sender: TObject);
    procedure Button_DescargarJuegoClick(Sender: TObject);
    procedure Button_RecargarXmlClick(Sender: TObject);
    procedure Button_IniciarServidorClick(Sender: TObject);
    procedure Button_DetenerServidorClick(Sender: TObject);
    procedure Button_InstalarActualizarServidorClick(Sender: TObject);
    procedure Button_InstalarActualizarAplicacionesClick(Sender: TObject);
    procedure Button_TestClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

{ Threads }
JuegoThread = class(TThread)
private
  FButtonClicked: TButton;
protected
  procedure Execute; override;
public
  property WhatButtonWasClicked: TButton read FButtonClicked write FButtonClicked;
end;


DescargarJuegoThread = class(TThread)
protected
  procedure Execute; override;
end;


ServidorThread = class(TThread)
private
  FButtonClicked: TButton;
protected
  procedure Execute; override;
public
  property WhatButtonWasClicked: TButton read FButtonClicked write FButtonClicked;
end;


var
  Form1: TForm1;
  INI: TINIFile;
  XMLDocument1: TXMLDocument;
  GameListNode: TDOMNode;
  GameNode: TDOMNode;
  ManifestNode: TDOMNode;
  TitleNode: TDOMNode;
  List_Instalado: TStringList;
  RutaEjecutable: String;
  GitPath: string;
  NodejsPath: string;
  NpmCliPath: string;
  MangoPath: string;
  WgetPath: string;
  BootstrapperPath: string;
  ManifestID: string;
  SelectedGameName: string;

implementation

uses
  MyFunctions;
{$R *.lfm}



{TODO 5 -cGeneral :
Guardar las URL de descargas en un archivo .ini por si en un futuro las cambian.
Así se podrán editar y la aplicación seguirá funcionando}


{TODO -cGeneral : Ver si puedo definir algunas variables como constantes.}
{DONE -cDescargar :procedure DescargarBootstrapper:
- Comprobar si el archivo se puede descargar de la web antes de iniciar la descarga.
- Si se puede, iniciar la descarga.
- Si no se puede, que muestre un mensaje.}
{DONE -cDescargar :Al terminar la descarga del juego:
- Comprobar si el Bootstrapper está descargado.
- Descargarlo si fuera necesario.
- Instalarlo.}
{DONE -cDescargar : Al terminar la descarga del juego, dar la opción de eliminar los archivos temporales (carpeta 'depot')}
{DONE -cGeneral : Desactivar todos los botones al iniciar un proceso (salvo el botón de cancelar el proceso)}
{DONE -cJugar : Añadir el código para iniciar el juego}



{----------------------------------------- Procedimientos ------------------------------------------
---------------------------------------------------------------------------------------------------}
{ Devuelve el manifest que corresponde con el nombre del juego seleccionado }
function GetManifestBasedOnGameName(const GameName: String): String;
begin
  Result := '';
  GameNode := XMLDocument1.DocumentElement.FirstChild;

  while Assigned(GameNode) and (GameNode.NodeName = 'game') do
  begin
    ManifestNode := GameNode.FirstChild;
    while Assigned(ManifestNode) do
    begin
      if ManifestNode.TextContent = GameName then
      begin
        TitleNode := ManifestNode.PreviousSibling;
        Result := TitleNode.TextContent;
      end;
      ManifestNode := ManifestNode.NextSibling;
    end;
    GameNode := GameNode.NextSibling;
  end;
end;


{ Devuelve el nombre del juego que corresponde con el manifest seleccionado }
function GetGameNameBasedOnManifest(const ManifestID: String): String;
begin
  Result := '';
  GameNode := XMLDocument1.DocumentElement.FirstChild;

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
end;


procedure DescargarBootstrapper;
var
  DownloadUrl: string;
  Parametros: string;
  WorkingDir: string;
begin
  DownloadUrl := 'https://about.openwf.io/supplementals/Bootstrapper%20Setup.exe';
  Parametros := Format('"%s" "%s" -O "%s"', [WgetPath, DownloadUrl, 'Bootstrapper Setup.exe']);
  WorkingDir := RutaEjecutable;

  Form1.StatusBar1.SimpleText := 'Bootstrapper no encontrado. Descargando...';

  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al descargar el bootstrapper: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;


procedure InstalarBootstrapper(ManifestID: string);
var
  Parametros: string;
  WorkingDir: string;
begin
  Parametros := Format('"%s"', [BootstrapperPath]);
  WorkingDir := RutaEjecutable + '\nodejs\install\230411\' + ManifestID;

  Form1.StatusBar1.SimpleText := 'Instalando el bootstrapper...';

  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    Form1.StatusBar1.SimpleText := '';
  except
    on E: Exception do
    begin
      MessageDlg('Error al instalar el bootstrapper: ' + E.Message, mtError, [mbOK], 0);
      Form1.StatusBar1.SimpleText := '';
    end;
  end;
end;


procedure InstalarActualizarServidor;
var
  Parametros: string;
  WorkingDir: string;
begin
  if not DirectoryExists(RutaEjecutable + '\SpaceNinjaServer') then
  begin
    { Instala el servidor si no está instalado }
    Parametros:= GitPath + ' clone https://openwf.io/SpaceNinjaServer.git';
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
    WorkingDir := RutaEjecutable + '\SpaceNinjaServer';

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
const
  SourceFile = '\SpaceNinjaServer\config-vanilla.json';
  DestFile = '\SpaceNinjaServer\config.json';
begin
  if FileExists(RutaEjecutable + DestFile) then
    Exit;

  try
    if not CopyFile(PChar(RutaEjecutable + SourceFile), PChar(RutaEjecutable + DestFile), false) then
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
  WorkingDir := RutaEjecutable + '\SpaceNinjaServer';

  Form1.Memo_Servidor.Lines.Add('');
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

  { Actualiza los stripped assets si ya estaban instalados }
  if DirectoryExists(RutaEjecutable + '\SpaceNinjaServer\static\data\stripped-assets') then
  begin
    Parametros := Format('"%s" pull', [GitPath]);
    WorkingDir := RutaEjecutable + '\SpaceNinjaServer\static\data\stripped-assets';

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
  end
  else
  { Descarga los stripped assets si no están instalados }
  begin
    Parametros := Format('"%s" clone https://openwf.io/stripped-assets.git', [GitPath]);
    WorkingDir := RutaEjecutable + '\SpaceNinjaServer\static\data';

    Form1.Memo_Servidor.Lines.Add('');
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
    end;
  end;

  { Actualiza los stripped assets si ya estban instalados }
  if DirectoryExists(RutaEjecutable + '\SpaceNinjaServer\static\data\0') then
  begin
    Parametros := Format('"%s" pull', [GitPath]);
    WorkingDir := RutaEjecutable + '\SpaceNinjaServer\static\data\0\';

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

  //Form1.Memo_Servidor.Lines.Add('||======== Descargando Mango ========||');
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

//// Crea un archivo log
//procedure SaveString(OutFilePath: string);
//begin
//  with TStringList.Create do try
//     AddStrings(Form1.Memo_Servidor.lines);
//     SaveToFile(OutFilePath);
//   finally
//     Free;
//   end;
//end;




{----------------------------------- Fin de los procedimientos -------------------------------------
---------------------------------------------------------------------------------------------------}

procedure TForm1.FormClose(Sender: TObject);
begin
  FreeAndNil(XMLDocument1);
  List_Instalado.Free;
end;


procedure TForm1.FormCreate(Sender: TObject);
var
  Path: string;
  FolderName: string;
  GameName: string;
begin
  Application.HintPause := 1000;  // Modifica los segundos que tarda en aparecer el hint al poner el ratón sobre un botón
  Button_InstalarActualizarBootstrapper.Caption := 'Instalar' + sLineBreak + 'Bootstrapper';
  Button_InstalarActualizarServidor.Caption := 'Instalar' + sLineBreak + 'Servidor';
  Button_InstalarActualizarAplicaciones.Caption := 'Instalar' + sLineBreak + 'Mango';

  { Inicializar las variables globales }
  RutaEjecutable   := ExtractFileDir(Application.ExeName);

  {TODO 5 -cGeneral : GitPath: Apaño temporal porque el git que está en RutaEjecutable no funciona.
  Restaurar el original cuando se termine.}
//  GitPath          := 'git.exe'; // apaño temporal porque el git que está en RutaEjecutable no funciona
  GitPath          := RutaEjecutable + '\git\bin\git.exe';
  NodejsPath       := RutaEjecutable + '\nodejs\node.exe';
  NpmCliPath       := RutaEjecutable + '\nodejs\node_modules\npm\bin\npm-cli.js';
  MangoPath        := RutaEjecutable + '\nodejs\node_modules\steam-manifest-tools\mango.js';
  WgetPath         := RutaEjecutable + '\wget\wget.exe';
  BootstrapperPath := RutaEjecutable + '\Bootstrapper Setup.exe';

  List_Instalado := TStringList.Create;

  try
    ReadXMLFile(XMLDocument1, UTF8ToSys(RutaEjecutable + '\manifest.xml'));

    { Obtiene el directorio completo de los juegos instalados y devuelve el nombre de la carpeta del juego }
    for Path in FindAllDirectories(RutaEjecutable + '\nodejs\install\230411\', false) do
      List_Instalado.Add(StringReplace(Path, RutaEjecutable + '\nodejs\install\230411\', '', [rfReplaceAll, rfIgnoreCase]));

    List_Instalado.CustomSort(StringListSortCompare); // Ordena la lista en sentido descendente
    ComboBox_Instalado.Items.Assign(List_Instalado);  // Asigna la lista ordenada al ComboBox_Instalado

    { Sustituye los items del ComboBox_Instalado con los nombres de los juegos si List_Instalado no está vacío }
    if List_Instalado.Count > 0 then
    begin
      for FolderName in List_Instalado do
      begin
        GameName := GetGameNameBasedOnManifest(FolderName);
        ComboBox_Instalado.Items[List_Instalado.IndexOf(FolderName)] := GameName;
      end;
    end;

    if ComboBox_Instalado.Items.Count > 0 then
        ComboBox_Instalado.ItemIndex := 0
      else
        ComboBox_Instalado.ItemIndex := -1;

    { Añade al menú "Disponible para descargar" los juegos listados en el manifes.xml }
    GameNode := XMLDocument1.DocumentElement.FirstChild;
    while Assigned(GameNode) and (GameNode.NodeName = 'game') do
    begin
      ManifestNode := GameNode.FirstChild;
      while Assigned(ManifestNode) do
      begin
        if ManifestNode.NodeName = 'title' then
        begin
          ComboBox_DisponibleParaDescargar.Items.Add(ManifestNode.TextContent);
        end;
        ManifestNode := ManifestNode.NextSibling;
      end;
      GameNode := GameNode.NextSibling;
    end;

    if ComboBox_DisponibleParaDescargar.Items.Count > 0 then
        ComboBox_DisponibleParaDescargar.ItemIndex := 0
      else
        ComboBox_DisponibleParaDescargar.ItemIndex := -1;

  except
    on E: Exception do
    begin
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;



//=====================//
//    Iniciar Juego    //
//=====================//
procedure TForm1.Button_IniciarJuegoClick(Sender: TObject);
var
  AThread: JuegoThread;
  BThread: ServidorThread;
begin
  AThread := JuegoThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  BThread := ServidorThread.Create(True);
  BThread.FreeOnTerminate := true;
  BThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  { Obtiene el Manifest del juego seleccionado }
  SelectedGameName := ComboBox_Instalado.Text;
  ManifestID := GetManifestBasedOnGameName(SelectedGameName);

  if FileExists(RutaEjecutable + '\nodejs\install\230411\' + ManifestID + '\Warframe.x64.exe') then
  begin
    BThread.Start;
    AThread.Start;
  end
  else
    MessageDlg(Format('%s no está instalado o la instalación no es correcta.', [SelectedGameName]), mtError, [mbOK], 0);
end;


procedure TForm1.Button_InstalarActualizarBootstrapperClick(Sender: TObject);
var
  AThread: JuegoThread;
begin
  AThread := JuegoThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  { Obtiene el Manifest del juego seleccionado }
  SelectedGameName := ComboBox_Instalado.Text;
  ManifestID := GetManifestBasedOnGameName(SelectedGameName);

  AThread.Start;
end;



//=================//
//    Descargas    //
//=================//
procedure TForm1.Button_DescargarJuegoClick(Sender: TObject);
var
  AThread: DescargarJuegoThread;
begin
  AThread := DescargarJuegoThread.Create(True);
  AThread.FreeOnTerminate := true;

  AThread.Start;
end;


procedure TForm1.Button_RecargarXmlClick(Sender: TObject);
begin
  try
    ReadXMLFile(XMLDocument1, UTF8ToSys(RutaEjecutable + '\manifest.xml'));
    ComboBox_DisponibleParaDescargar.Items.Clear;

    { Añade al menú "Disponible para descargar" los juegos listados en el manifes.xml }
    GameNode := XMLDocument1.DocumentElement.FirstChild;
    while Assigned(GameNode) and (GameNode.NodeName = 'game') do
    begin
      ManifestNode := GameNode.FirstChild;
      while Assigned(ManifestNode) do
      begin
        if ManifestNode.NodeName = 'title' then
        begin
          ComboBox_DisponibleParaDescargar.Items.Add(ManifestNode.TextContent);
        end;
        ManifestNode := ManifestNode.NextSibling;
      end;
      GameNode := GameNode.NextSibling;
    end;

    if ComboBox_DisponibleParaDescargar.Items.Count > 0 then
        ComboBox_DisponibleParaDescargar.ItemIndex := 0
      else
        ComboBox_DisponibleParaDescargar.ItemIndex := -1;

    except
      on E: Exception do
        MessageDlg('Error al recargar el archivo manifest.xml: ' + E.Message, mtError, [mbOK], 0);
  end;
end;



//====================//
//      Servidor      //
//====================//
procedure TForm1.Button_IniciarServidorClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.start;
end;


procedure TForm1.Button_DetenerServidorClick(Sender: TObject);
begin
  try
    StopProcess('node.exe');
    except
      on E: Exception do
        ShowMessage('No ha sido posible detener el proceso: ' + E.Message);
    end;
end;

procedure TForm1.Button_InstalarActualizarServidorClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := True;
  AThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.Start;
end;


procedure TForm1.Button_InstalarActualizarAplicacionesClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.WhatButtonWasClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.Start;
end;



{-------------------------------------------- Threads ----------------------------------------------
---------------------------------------------------------------------------------------------------}
procedure JuegoThread.Execute;
var
  i: integer;
  Parametros: string;
  WorkingDir: string;
begin
  { Inicia el juego }
  if FButtonClicked = Form1.Button_IniciarJuego then
  begin
    Form1.Button_IniciarJuego.Enabled := False;
    Form1.Button_IniciarServidor.Enabled := False;
    Form1.Button_InstalarActualizarBootstrapper.Enabled := False;
    Form1.Button_DescargarJuego.Enabled := False;
    Form1.Button_RecargarXml.Enabled := False;

    try
      Sleep(3000); // Esperar unos segundos para que al servidor le de tiempo a iniciarse

      Parametros := RutaEjecutable + '\nodejs\install\230411\' + ManifestID + '\Warframe.x64.exe';
      WorkingDir := RutaEjecutable + '\nodejs\install\230411\' + ManifestID;

      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    except
      on E: Exception do
        MessageDlg('Error al iniciar el servidor: ' + E.Message, mtError, [mbOK], 0);
    end;
    StopProcess('node.exe');
    Form1.Button_IniciarJuego.Enabled := True;
    Form1.Button_IniciarServidor.Enabled := True;
    Form1.Button_InstalarActualizarBootstrapper.Enabled := True;
    Form1.Button_DescargarJuego.Enabled := True;
    Form1.Button_RecargarXml.Enabled := True;
  end
  else
  if FButtonClicked = Form1.Button_InstalarActualizarBootstrapper then
  begin
    Form1.Memo_Servidor.Clear;
    Form1.Button_InstalarActualizarBootstrapper.Enabled := False;
    Form1.Button_IniciarJuego.Enabled := False;

    try
      { Comprueba si la url es accesible. Devuelve 0 si tuvo éxito, 4 si no lo tuvo }
      i := ExecNewProcess(Format('"%s" --spider "https://about.openwf.io/supplementals/Bootstrapper Setup.exe"', [WgetPath]), RutaEjecutable, Form1.Memo_Servidor);  // Comprueba si la url es accesible
      if i <> 0 then
        MessageDlg('No se ha podido descargar el Bootstrapper.' + sLineBreak + 'Compruebe que la url sea accesible:' + sLineBreak + sLineBreak + 'https://about.openwf.io/supplementals/Bootstrapper Setup.exe', mtError, [mbOK], 0)
      else
      begin
        DescargarBootstrapper;
        { Comprueba si el juego está instalado }
        if FileExists(RutaEjecutable + '\nodejs\install\230411\' + ManifestID + '\Warframe.x64.exe') then
          InstalarBootstrapper(ManifestID)
        else
          MessageDlg(SelectedGameName + ' no está instalado o la instalación no es correcta.' + sLineBreak + sLineBreak + 'Se ha cancelado la instalación del Bootstrapper.', mtError, [mbOK], 0);
      end;
    except
      on E: Exception do
        MessageDlg('Ha ocurrido un error: ' + E.Message, mtError, [mbOK], 0);
    end;
    Form1.Button_InstalarActualizarBootstrapper.Enabled := True;
    Form1.Button_IniciarJuego.Enabled := True;
  end;
end;


procedure DescargarJuegoThread.Execute;
var
  Parametros: string;
  WorkingDir: string;
  Path: string;
  FolderName: string;
  GameName: string;
begin
  Form1.Memo_Servidor.Clear;
  Form1.Button_DescargarJuego.Enabled := False;
  Form1.CheckBox_BorrarCache.Enabled := False;
  Form1.StatusBar1.SimpleText := 'Descargando ' + Form1.ComboBox_DisponibleParaDescargar.Text + '...';

  ManifestID := GetManifestBasedOnGameName(Form1.ComboBox_DisponibleParaDescargar.Text);
  Parametros := Format('"%s" "%s" download-and-install 230411 %s',
                       [NodejsPath, MangoPath, ManifestID]);
  WorkingDir := RutaEjecutable + '\nodejs';

  { Descarga el juego seleccionado }
  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    Form1.StatusBar1.SimpleText := '';
    if Form1.CheckBox_BorrarCache.Checked = true then
    begin
      Form1.StatusBar1.SimpleText := 'Elimiando la caché de archivos descargados...';
      DeleteDirectoryRecursively(RutaEjecutable + '\nodejs\depot\230411');
      Form1.StatusBar1.SimpleText := '';
    end;
	  
    { Descarga e instala el bootstrapper }
    DescargarBootstrapper;
    InstalarBootstrapper(ManifestID);

    List_Instalado.Clear;
    Form1.ComboBox_Instalado.Items.Clear;

    { Obtiene el directorio completo de los juegos instalados y devuelve el nombre de la carpeta del juego }
    for Path in FindAllDirectories(RutaEjecutable + '\nodejs\install\230411\', false) do
      List_Instalado.Add(StringReplace(Path, RutaEjecutable + '\nodejs\install\230411\', '', [rfReplaceAll, rfIgnoreCase]));

    List_Instalado.CustomSort(StringListSortCompare);
    Form1.ComboBox_Instalado.Items.Assign(List_Instalado);

    { Sustituye los items del ComboBox_Instalado con los nombres de los juegos si List_Instalado no está vacío }
    if List_Instalado.Count > 0 then
    begin
      for FolderName in List_Instalado do
      begin
        GameName := GetGameNameBasedOnManifest(FolderName);
        Form1.ComboBox_Instalado.Items[List_Instalado.IndexOf(FolderName)] := GameName;
      end;
    end;

    if Form1.ComboBox_Instalado.Items.Count > 0 then
        Form1.ComboBox_Instalado.ItemIndex := 0
      else
        Form1.ComboBox_Instalado.ItemIndex := -1;

    except
      on E: Exception do
      begin
        MessageDlg('Ha ocurrido un error al descargar Warframe: ' + E.Message, mtError, [mbOK], 0);
        Form1.StatusBar1.SimpleText := '';
      end;
    end;
    Form1.Button_DescargarJuego.Enabled := True;
    Form1.CheckBox_BorrarCache.Enabled := True;
end;


procedure ServidorThread.Execute;
var
  i: Integer;
  Parametros: string;
  WorkingDir: string;
begin
  { Iniciar el servidor }
  if (FButtonClicked = Form1.Button_IniciarServidor) or (FButtonClicked = Form1.Button_IniciarJuego) then
  begin
    Form1.Memo_Servidor.Clear;
    Form1.Button_IniciarServidor.Enabled := False;
    Form1.Button_DetenerServidor.Enabled := True;
    Form1.Button_InstalarActualizarServidor.Enabled := False;
    Form1.Button_InstalarActualizarAplicaciones.Enabled := False;

    Parametros := Format('"%s" "%s" run raw', [NodejsPath, NpmCliPath]);
    WorkingDir := RutaEjecutable + '\SpaceNinjaServer';

    try
      //OpenURL('http://localhost');
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    except
      on E: Exception do
        MessageDlg('Error al iniciar el servidor: ' + E.Message, mtError, [mbOK], 0);
    end;
    Form1.Button_IniciarServidor.Enabled := True;
    Form1.Button_DetenerServidor.Enabled := False;
    Form1.Button_InstalarActualizarServidor.Enabled := True;
    Form1.Button_InstalarActualizarAplicaciones.Enabled := True;
  end
  else
  { Instalar / Actualizar servidor }
  if FButtonClicked = Form1.Button_InstalarActualizarServidor then
  begin
    Form1.Memo_Servidor.Clear;

    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := False;

    InstalarActualizarServidor;
    CopiarArchivoConfigServidor;
    InstalarActualizarLibraryDependencies;
    DescargarActualizarStrippedAssets;

    for i := 0 to Form1.ComponentCount - 1 do // Activa todos los botones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := True;
  end
  else
  { Instalar / Actualizar aplicaciones }
  if FButtonClicked = Form1.Button_InstalarActualizarAplicaciones then
  begin
    Form1.Memo_Servidor.Clear;

    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botoones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := False;

    { Descarga Mango. Si la url no es accesible, muestra un mensje de error }
    i := ExecNewProcess(Format('"%s" "%s" install -g steam-manifest-tools', [NodejsPath, NpmCliPath]), RutaEjecutable + '\nodejs', Form1.Memo_Servidor);
    if i <> 0 then
      MessageDlg('No se ha podido descargar Mango.', mtError, [mbOK], 0)
    else
    begin
      DescargarActualizarMango;
  // Descargar Git
  // Descargar Node.js
  // Descargar wget
    end;
    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botoones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := True;
  end;
end;








procedure TForm1.Button_TestClick(Sender: TObject);
var
  i: integer;
begin
  try
    i := ExecNewProcess(WgetPath + ' --spider https://about.openwf.io/supplementals/Bootstrapper%20Setup.exe', 'C:\Juegos\Warframe\wget', Form1.Memo_Servidor);
    ShowMessage(IntToStr(i));
  // Devuelve 0 si tuvo éxito, 4 si no lo tuvo
  except
    on E: Exception do
      Form1.Memo_Servidor.Lines.Add(E.Message);
  end;
end;




end.
