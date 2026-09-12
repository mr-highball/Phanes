(*
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
program PhanesEngineHost;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses
  Classes, SysUtils, JS, Web, WebAssembly, WasiEnv, WasiHostApp, JOB_Browser, phanes.startup.parts;

{$I phanes.host.assets.inc}

type
  TStartupBridge = class external name 'Object'(TJSObject)
    procedure stage(const APhase, ALabel: String);
    procedure progress(const ALoaded, ATotal: Double);
    procedure fail(const AMessage: String);
    procedure log(const AMessage: String);
    procedure started;
  end;

  TEngineHost = class(TWASIHost)
  protected
    function CreateWebAssembly(APath: String; AImportObject: TJSObject): TJSPromise; override;
  public
    procedure RunEngine(ABeforeStart: TBeforeStartCallback);
  end;

  TEngineApplication = class(TWASIHostApplication)
  private
    FBridge: TJSObjectBridge;
    function BeforeEngineStart(ASender: TObject;
      ADescriptor: TWebAssemblyStartDescriptor): Boolean;
    procedure EngineOutput(ASender: TObject; AOutput: String);
    function DataLoaded(AValue: JSValue): JSValue;
    function EngineStarted(AValue: JSValue): JSValue;
    function Failed(AValue: JSValue): JSValue;
  protected
    procedure DoRun; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  GApplication: TEngineApplication;

function Startup: TStartupBridge;
begin
  Result := TStartupBridge(TJSObject(window)['phanesStartup']);
end;

procedure PrepareGraphicsContext;
var
  LCanvas: TJSHTMLCanvasElement;
  LOptions: TJSObject;
  LContext: JSValue;
begin
  LCanvas := TJSHTMLCanvasElement(document.getElementById('castle-canvas'));
  LOptions := TJSObject.new;
  LOptions['alpha'] := False;
  LOptions['antialias'] := False;
  LOptions['premultipliedAlpha'] := False;
  LOptions['stencil'] := True;
  { Context attributes are fixed by the first getContext call. CGE reuses this
    context; the pinned web backend otherwise omits the stencil buffer needed
    by its public cross-scene shadow-volume renderer. }
  LContext := LCanvas.getContext('webgl2', LOptions);
  if isNull(LContext) then
  begin
    LContext := LCanvas.getContext('webgl', LOptions);
  end;
  if isNull(LContext) then
  begin
    raise Exception.Create('Could not create the graphics context.');
  end;
end;

function ErrorMessage(const AValue: JSValue): String;
begin
  if isObject(AValue) and (TJSObject(AValue)['message'] <> Undefined) then
  begin
    Result := String(TJSObject(AValue)['message']);
  end else
  begin
    Result := String(AValue);
  end;
end;

function Download(const AUrl, APhase, ALabel: String): TJSPromise;
begin
  Result := DownloadStartupFile(StartupPartsJson, AUrl, APhase, ALabel);
end;
function TEngineHost.CreateWebAssembly(APath: String; AImportObject: TJSObject): TJSPromise;
begin
  Result := Download(APath, 'engine-download', 'Downloading the engine')._then(
    function(AValue: JSValue): JSValue
    begin
      Startup.stage('compile', 'Preparing the engine');
      DoBeforeInstantiate;
      { Instantiate the received buffer directly: no Blob URL or second fetch.
        WASI still owns imports, memory, exports and native exception conversion. }
      Result := TJSWebAssembly.instantiate(TJSArrayBuffer(AValue), AImportObject);
    end);
end;

procedure TEngineHost.RunEngine(ABeforeStart: TBeforeStartCallback);
begin
  { RunPreparedDescriptor reinstantiates the module. The initial prepared
    instance already owns everything needed; run it without a second allocation. }
  RunWebAssemblyInstance(ABeforeStart, nil, nil);
end;

constructor TEngineApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBridge := TJSObjectBridge.Create(WasiEnvironment);
  RunEntryFunction := '_initialize';
  OnConsoleWrite := @EngineOutput;
end;

procedure TEngineApplication.EngineOutput(ASender: TObject; AOutput: String);
begin
  console.log(AOutput);
  Startup.log(AOutput);
end;

function TEngineApplication.BeforeEngineStart(ASender: TObject;
  ADescriptor: TWebAssemblyStartDescriptor): Boolean;
begin
  FBridge.InstanceExports := ADescriptor.Exported;
  Result := True;
end;

function TEngineApplication.Failed(AValue: JSValue): JSValue;
begin
  Startup.fail(ErrorMessage(AValue));
  Result := Undefined;
end;

function TEngineApplication.EngineStarted(AValue: JSValue): JSValue;
begin
  Result := TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
    begin
      Startup.stage('initialize', 'Starting the renderer');
      { Give the phase label a painted frame before synchronous native startup. }
      window.requestAnimationFrame(procedure(ATime: Double)
        begin
          window.setTimeout(procedure
            var
              LDescriptor: TWebAssemblyStartDescriptor;
            begin
              try
                if document.body.getAttribute('data-startup-state') = 'failed' then
                begin
                  AResolve(False);
                  Exit;
                end;
                PrepareGraphicsContext;
                TEngineHost(Host).RunEngine(@BeforeEngineStart);
                LDescriptor := Host.PreparedStartDescriptor;
                { WASI catches exceptions internally and can still return success.
                  Read the prepared descriptor, not the pre-run returned copy. }
                if LDescriptor.RunExceptionClass <> '' then
                begin
                  AReject(TJSError.new(LDescriptor.RunExceptionClass + ': ' +
                    LDescriptor.RunExceptionMessage));
                end else
                begin
                  Startup.started;
                  AResolve(True);
                end;
              except
                on LException: Exception do
                begin
                  AReject(TJSError.new(LException.Message));
                end;
                on LError: TJSError do
                begin
                  AReject(LError);
                end;
              end;
            end, 0);
        end);
    end);
end;

function TEngineApplication.DataLoaded(AValue: JSValue): JSValue;
begin
  { CGE reads its packed data through JOB during native initialization. }
  document.Properties['CastleApplicationData'] := AValue;
  Result := StartWebAssembly(EngineAssetUrl, False, nil, nil)._then(@EngineStarted);
end;

procedure TEngineApplication.DoRun;
begin
  Startup.log('Build: ' + EngineAssetUrl);
  Download(DataAssetUrl, 'assets-download', 'Downloading world assets')._then(
    @DataLoaded)._then(nil, @Failed);
  Terminate;
end;

begin
  try
    TEngineApplication.SetWasiHostClass(TEngineHost);
    GApplication := TEngineApplication.Create(nil);
    GApplication.Initialize;
    GApplication.Run;
  except
    on LException: Exception do
    begin
      Startup.fail(LException.Message);
    end;
    on LError: TJSError do
    begin
      Startup.fail(LError.Message);
    end;
  end;
  { Keep the application and JOB environment alive for subsequent engine frames. }
end.
