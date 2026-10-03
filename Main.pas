unit Main;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Buttons, Menus, INIFiles, LazFileUtils,
  DOM, XMLRead, XMLUtils, LazUTF8, FileUtil, XPath;

type

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn_DetenerServidor: TBitBtn;
    BitBtn_IniciarServidor: TBitBtn;
    Button_CancelarDescarga: TButton;
    Button_MenuTest: TButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    ComboBox_Instalado: TComboBox;
    Button_IniciarJuego: TButton;
    ComboBox_DisponibleParaDescargar: TComboBox;
    Button_DescargarJuego: TButton;
    CheckBox_BorrarCache: TCheckBox;
    Memo_Servidor: TMemo;
    MenuItem_DesinstalarJuego: TMenuItem;
    MenuItem_InstalarActualizarBootstrapper: TMenuItem;
    MenuItem_InstalarActualizarServidor: TMenuItem;
    MenuItem_InstalarActualizarAplicaciones: TMenuItem;
    MenuItem_RecargarXml: TMenuItem;
    PopupMenu: TPopupMenu;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    StatusBar1: TStatusBar;
    procedure BitBtn_DetenerServidorClick(Sender: TObject);
    procedure BitBtn_IniciarServidorClick(Sender: TObject);
    procedure Button_CancelarDescargaClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject);
    procedure Button_IniciarJuegoClick(Sender: TObject);
    procedure Button_DescargarJuegoClick(Sender: TObject);
    procedure Button_MenuTestClick(Sender: TObject);
    procedure MenuItem_DesinstalarJuegoClick(Sender: TObject);
    procedure MenuItem_InstalarActualizarAplicacionesClick(Sender: TObject);
    procedure MenuItem_InstalarActualizarBootstrapperClick(Sender: TObject);
    procedure MenuItem_InstalarActualizarServidorClick(Sender: TObject);
    procedure MenuItem_RecargarXmlClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

{ Threads }
JuegoThread = class(TThread)
private
  FButtonClicked: TButton;
  FMenuItemClicked: TMenuItem;
protected
  procedure Execute; override;
public
  property GetButtonClicked: TButton read FButtonClicked write FButtonClicked;
  property GetMenuItemClicked: TMenuItem read FMenuItemClicked write FMenuItemClicked;
end;


DescargasThread = class(TThread)
protected
  procedure Execute; override;
end;


ServidorThread = class(TThread)
private
  FButtonClicked: TButton;
  FMenuItemClicked: TMenuItem;
  FBitBtnClicked: TBitBtn;
protected
  procedure Execute; override;
public
  property GetButtonClicked: TButton read FButtonClicked write FButtonClicked;
  property GetMenuItemClicked: TMenuItem read FMenuItemClicked write FMenuItemClicked;
  property GetBitBtnClicked: TBitBtn read FBitBtnClicked write FBitBtnClicked;
end;


var
  Form1: TForm1;
  XMLDocument1: TXMLDocument;
  RutaEjecutable: String;
  GitPath: String;
  NodejsPath: String;
  NpmCliPath: String;
  MangoPath: String;
  WgetPath: String;
  BootstrapperPath: String;
  ManifestID: String;
  GameInstallPath: String;
  GameDownloadCachePath: String;
  SpaceNinjaServerPath: String;
  SpaceNinjaServerURL: String;
  BootstrapperUrl: String;

implementation

uses
  MyFunctions, XmlManager, Procedures;
{$R *.lfm}


{ #todo 5 -cGeneral : Añadir un botón para cancelar las descargas del juego (detener el hilo y matar los procesos) }
{ #todo 5 -cGeneral : Guardar las URL de descargas en un archivo .ini
- Si en un futuro cambian, se podrán editar y la aplicación seguirá funcionando.}
{ #todo 5 -cGeneral : Añadir comprobaciones:
- Antes de descargar un acrhivo.
- Comprobar que Warframe.x64.exe existe antes de iniciar Warframe.}
 { #todo 2 -cGeneral : ¿Añadir la versión de Warframe a los ComboBox y ordenarlos por versión? }
 { #todo -cGeneral : Descargar Git y Node.js al iniciar la aplicación para disminuir el tamaño de cara a su distribución }

 { #done 5 -cGeneral : Mover "procedure TForm1.MenuItem_DesinstalarJuegoClick" al hilo JuegoThread }
 { #done -cGeneral : Añadir la posibilidad de eliminar los juegos instalado }
 { #done -cOptimización : Mover los procedimientos a la unida 'Procedures' }
 { #done 1 -cGeneral : Añadir un Tbutton con un tbsDropDown para incluir:
 - Instalar servidor, instalar Mango, recargar xml, etc }
 { #done -cGeneral : Guardar en un achivo .ini algunas opciones:
 - El último juego jugado
 - El Checkbox para borrar la caché }

procedure TForm1.FormClose(Sender: TObject);
begin
  SaveINIFile;
  FreeAndNil(XMLDocument1);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Application.HintPause := 1000;  // Modifica los segundos que tarda en aparecer el hint al poner el ratón sobre un botón

  { Inicializar las variables globales }
  RutaEjecutable        := ExtractFileDir(Application.ExeName);
  GitPath               := RutaEjecutable + '\git\bin\git.exe';
  NodejsPath            := RutaEjecutable + '\nodejs\node.exe';
  NpmCliPath            := RutaEjecutable + '\nodejs\node_modules\npm\bin\npm-cli.js';
  MangoPath             := RutaEjecutable + '\nodejs\node_modules\steam-manifest-tools\mango.js';
  WgetPath              := RutaEjecutable + '\wget\wget.exe';
  SpaceNinjaServerPath  := RutaEjecutable + '\SpaceNinjaServer';
  SpaceNinjaServerURL   := 'https://openwf.io/SpaceNinjaServer.git';
  BootstrapperPath      := RutaEjecutable + '\Bootstrapper Setup.exe';
  BootstrapperUrl       := 'https://about.openwf.io/supplementals/Bootstrapper%20Setup.exe';
  GameInstallPath       := '\nodejs\install\230411\';
  GameDownloadCachePath := '\nodejs\depot\230411\';

  try
    ReadXMLFile(XMLDocument1, RutaEjecutable + '\manifest.xml');
    AddInstalledGamesToComboBox(ComboBox_Instalado.Items, True);

    LoadINIFile;

    { Añade al menú "Disponible para descargar" los juegos listados en el manifes.xml }
    GetXMLNodeValues('title', ComboBox_DisponibleParaDescargar.Items, XMLDocument1);

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

procedure TForm1.Button_MenuTestClick(Sender: TObject);
var
  button: TControl;
  lowerLeft: TPoint;
begin
  if Sender is TControl then
  begin
    button := TControl(Sender);
    lowerLeft := Point(0, button.Height);
    lowerLeft := button.ClientToScreen(lowerLeft);
    PopupMenu.Popup(lowerLeft.X, lowerLeft.Y);
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
  AThread.GetButtonClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  BThread := ServidorThread.Create(True);
  BThread.FreeOnTerminate := true;
  BThread.GetButtonClicked := Sender as TButton; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  { Obtiene el Manifest del juego seleccionado }
  ManifestID := GetBuildInfo(ComboBox_Instalado.Text, 'manifest', XMLDocument1);

  if FileExists(RutaEjecutable + GameInstallPath + ManifestID + '\Warframe.x64.exe') then
  begin
    BThread.Start;
    AThread.Start;
  end
  else
    MessageDlg(Format('%s no está instalado o la instalación no es correcta.', [ComboBox_Instalado.Text]), mtError, [mbOK], 0);
end;

procedure TForm1.MenuItem_InstalarActualizarBootstrapperClick(Sender: TObject);
var
  AThread: JuegoThread;
begin
  AThread := JuegoThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.GetMenuItemClicked := Sender as TMenuItem; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  { Obtiene el Manifest del juego seleccionado }
  ManifestID := GetBuildInfo(ComboBox_Instalado.Text, 'manifest', XMLDocument1);

  AThread.Start;
end;

procedure TForm1.MenuItem_DesinstalarJuegoClick(Sender: TObject);
var
  AThread: JuegoThread;
begin
  AThread := JuegoThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.GetMenuItemClicked := Sender as TMenuItem; // "Envía" una señal al Thread para saber
                                                      // que se ha iniciado con este botón

  AThread.Start;
end;



//=================//
//    Descargas    //
//=================//
procedure TForm1.Button_DescargarJuegoClick(Sender: TObject);
var
  AThread: DescargasThread;
begin
  AThread := DescargasThread.Create(True);
  AThread.FreeOnTerminate := true;

  AThread.Start;
end;

procedure TForm1.Button_CancelarDescargaClick(Sender: TObject);
begin
  try
    //IntToStr(StopProcess('node.exe'));
    //ExecNewProcess('taskkill /f /im node.exe', RutaEjecutable + '\nodejs', Form1.Memo_Servidor);
    ExecNewProcess('taskkill /f /t /pid ' + IntToStr(GetProcessPID('node.exe')), RutaEjecutable + '\nodejs', Form1.Memo_Servidor);
    except
      on E: Exception do
        ShowMessage('No ha sido posible detener el proceso: ' + E.Message);
    end;
end;

procedure TForm1.MenuItem_RecargarXmlClick(Sender: TObject);
begin
  try
    ReadXMLFile(XMLDocument1, RutaEjecutable + '\manifest.xml');
    ComboBox_DisponibleParaDescargar.Items.Clear;

    { Añade al menú "Disponible para descargar" los juegos listados en el manifes.xml }
    GetXMLNodeValues('title', ComboBox_DisponibleParaDescargar.Items, XMLDocument1);

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
procedure TForm1.BitBtn_IniciarServidorClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.GetBitBtnClicked := Sender as TBitBtn; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.start;
end;

procedure TForm1.BitBtn_DetenerServidorClick(Sender: TObject);
begin
  try
    StopProcess('node.exe');
    except
      on E: Exception do
        ShowMessage('No ha sido posible detener el proceso: ' + E.Message);
    end;
end;

procedure TForm1.MenuItem_InstalarActualizarServidorClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := True;
  AThread.GetMenuItemClicked := Sender as TMenuItem; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.Start;
end;

procedure TForm1.MenuItem_InstalarActualizarAplicacionesClick(Sender: TObject);
var
  AThread: ServidorThread;
begin
  AThread := ServidorThread.Create(True);
  AThread.FreeOnTerminate := true;
  AThread.GetMenuItemClicked := Sender as TMenuItem; // "Envía" una señal al Thread para saber
                                                     // que se ha iniciado con este botón
  AThread.Start;
end;




{-------------------------------------------- Threads ----------------------------------------------
---------------------------------------------------------------------------------------------------}
procedure JuegoThread.Execute;
var
  Parametros: string;
  WorkingDir: string;
  s: String;
begin
  { Iniciar el juego }
  if FButtonClicked = Form1.Button_IniciarJuego then
  begin
    Parametros := RutaEjecutable + GameInstallPath + ManifestID + '\Warframe.x64.exe';
    WorkingDir := RutaEjecutable + GameInstallPath + ManifestID;

    Form1.Button_MenuTest.Enabled := False;
    Form1.Button_IniciarJuego.Enabled := False;
    Form1.Button_DescargarJuego.Enabled := False;

    Sleep(3000); // Esperar unos segundos para que al servidor le de tiempo a iniciarse
    try
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    except
      on E: Exception do
        MessageDlg('Error al iniciar el juego: ' + E.Message, mtError, [mbOK], 0);
    end;
    StopProcess('node.exe');

    Form1.Button_MenuTest.Enabled := True;
    Form1.Button_IniciarJuego.Enabled := True;
    Form1.Button_DescargarJuego.Enabled := True;
  end;

  { Instalar / Actualizar el Bootstrapper }
  if FMenuItemClicked = Form1.MenuItem_InstalarActualizarBootstrapper then
  begin
    Form1.Memo_Servidor.Clear;

    Form1.Button_MenuTest.Enabled := False;
    Form1.Button_IniciarJuego.Enabled := False;

    DescargarInstalarBootstrapper;

    Form1.Button_MenuTest.Enabled := True;
    Form1.Button_IniciarJuego.Enabled := True;
  end;

  { Desinstalar un juego }
  if FMenuItemClicked = Form1.MenuItem_DesinstalarJuego then
  begin
    Form1.Button_IniciarJuego.Enabled := False;
    Form1.Button_DescargarJuego.Enabled := False;

    s := GetBuildInfo(Form1.ComboBox_Instalado.Text, 'manifest', XMLDocument1);
    DeleteDirectoryRecursively(RutaEjecutable + GameInstallPath + s);

    Form1.ComboBox_Instalado.Clear;
    AddInstalledGamesToComboBox(Form1.ComboBox_Instalado.Items, True);

     if Form1.ComboBox_DisponibleParaDescargar.Items.Count > 0 then
        Form1.ComboBox_DisponibleParaDescargar.ItemIndex := 0
      else
        Form1.ComboBox_DisponibleParaDescargar.ItemIndex := -1;

    Form1.Button_IniciarJuego.Enabled := True;
    Form1.Button_DescargarJuego.Enabled := True;
  end;
end;

procedure DescargasThread.Execute;
var
  Parametros: string;
  WorkingDir: string;
  ExitCode: Integer;
  res: TModalResult;
begin
  Form1.Memo_Servidor.Clear;
  Form1.Button_DescargarJuego.Enabled := False;
  Form1.MenuItem_InstalarActualizarAplicaciones.Enabled := False;

  Form1.CheckBox_BorrarCache.Enabled := False;
  Form1.StatusBar1.SimpleText := 'Descargando ' + Form1.ComboBox_DisponibleParaDescargar.Text + '...';

  ManifestID := GetBuildInfo(Form1.ComboBox_DisponibleParaDescargar.text, 'manifest', XMLDocument1);

  Parametros := Format('"%s" "%s" download-and-install 230411 %s', [NodejsPath, MangoPath, ManifestID]);
  WorkingDir := RutaEjecutable + '\nodejs';

  { Descarga el juego seleccionado }
  try
    ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    ExitCode := ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    //ShowMessage(IntToStr(ExitCode));

    { Si se cancela la descarga }
    if ExitCode > 0 then
      begin
        Form1.Memo_Servidor.Lines.Add('');
        Form1.Memo_Servidor.Lines.Add('||======== Descarga cancelada ========||');

        res := QuestionDlg('Descarga cancelada', 'La descarga se ha cancelado debido a un error en la descarga o por acción del usuario.' + sLineBreak + sLineBreak + '¿Desea eliminar la descarga incompleta?', mtConfirmation, [mrYes, mrNo], 0);
        case res of
          mrYes: DeleteDirectoryRecursively(RutaEjecutable + GameInstallPath + ManifestID);
        end;

        Form1.Button_DescargarJuego.Enabled := True;
        Form1.CheckBox_BorrarCache.Enabled := True;
        Form1.MenuItem_InstalarActualizarAplicaciones.Enabled := True;
        Form1.StatusBar1.SimpleText := '';
        Exit;
      end;

    if Form1.CheckBox_BorrarCache.Checked = true then
    begin
      Form1.StatusBar1.SimpleText := 'Elimiando la caché de archivos descargados...';
      DeleteDirectoryRecursively(RutaEjecutable + GameDownloadCachePath);
    end;
	  
    DescargarInstalarBootstrapper;

    Form1.ComboBox_Instalado.Items.Clear;
    AddInstalledGamesToComboBox(Form1.ComboBox_Instalado.Items, True);

    except
      on E: Exception do
      begin
        MessageDlg('Ha ocurrido un error al descargar Warframe: ' + E.Message, mtError, [mbOK], 0);
      end;
    end;
    Form1.Button_DescargarJuego.Enabled := True;
    Form1.CheckBox_BorrarCache.Enabled := True;
    Form1.MenuItem_InstalarActualizarAplicaciones.Enabled := True;
    Form1.StatusBar1.SimpleText := '';
end;

procedure ServidorThread.Execute;
var
  i: Integer;
  Parametros: string;
  WorkingDir: string;
begin
  { Iniciar el servidor }
  if (FBitBtnClicked = Form1.BitBtn_IniciarServidor) or (FButtonClicked = Form1.Button_IniciarJuego) then
  begin
    Form1.Memo_Servidor.Clear;

    //Form1.Button_MenuTest.Enabled := False;
    Form1.BitBtn_IniciarServidor.Enabled := False;
    Form1.BitBtn_DetenerServidor.Enabled := True;
    Form1.MenuItem_InstalarActualizarServidor.Enabled := False;
    Form1.MenuItem_InstalarActualizarAplicaciones.Enabled := False;

    Parametros := Format('"%s" "%s" run raw', [NodejsPath, NpmCliPath]);
    WorkingDir := SpaceNinjaServerPath;

    try
      //OpenURL('http://localhost');
      ExecNewProcess(Parametros, WorkingDir, Form1.Memo_Servidor);
    except
      on E: Exception do
        MessageDlg('Error al iniciar el servidor: ' + E.Message, mtError, [mbOK], 0);
    end;

    //Form1.Button_MenuTest.Enabled := True;
    Form1.BitBtn_IniciarServidor.Enabled := True;
    Form1.BitBtn_DetenerServidor.Enabled := False;
    Form1.MenuItem_InstalarActualizarServidor.Enabled := True;
    Form1.MenuItem_InstalarActualizarAplicaciones.Enabled := True;
  end;

  { Instalar / Actualizar servidor }
  if FMenuItemClicked = Form1.MenuItem_InstalarActualizarServidor then
  begin
    Form1.Memo_Servidor.Clear;

    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := False;

    InstalarActualizarServidor;
    InstalarActualizarLibraryDependencies;
    DescargarActualizarStrippedAssets;

    for i := 0 to Form1.ComponentCount - 1 do // Activa todos los botones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := True;
  end;

  { Instalar / Actualizar aplicaciones }
  if FMenuItemClicked = Form1.MenuItem_InstalarActualizarAplicaciones then
  begin
    Form1.Memo_Servidor.Clear;

    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botoones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := False;

    DescargarActualizarMango;
  // Descargar Git
  // Descargar Node.js
  // Descargar wget
    //end;
    for i := 0 to Form1.ComponentCount - 1 do // Descativa todos los botoones
      if Form1.Components[i] is TButton then
        (Form1.Components[i] as TButton).Enabled := True;
  end;
end;

end.
