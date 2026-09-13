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
program PhanesStartupBrowser;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses
  JS, Web, SysUtils, Math;

type
  TSelectableTextArea = class external name 'HTMLTextAreaElement'(TJSHTMLTextAreaElement)
    procedure select;
  end;

  TStartupUI = class
  private
    FPhase: String;
    FLabel: String;
    FFailure: String;
    FLog: String;
    FLastActivity: Double;
    FStarted: Double;
    FEngineReady: Boolean;
    FHostReady: Boolean;
    FPaletteReady: Boolean;
    FReady: Boolean;
    FStalled: Boolean;
    FLoaded: Double;
    FTotal: Double;
    FTimer: NativeInt;
    procedure UpdateDetails;
    procedure CheckReady;
    function ReadyEvent(AEvent: TJSEvent): Boolean;
    function PaletteEvent(AEvent: TJSEvent): Boolean;
    function ErrorEvent(AEvent: TJSEvent): Boolean;
    function RejectionEvent(AEvent: TJSEvent): Boolean;
    function GraphicsEvent(AEvent: TJSEvent): Boolean;
    function RetryEvent(AEvent: TJSEvent): Boolean;
    function SelectDetails(AEvent: TJSEvent): Boolean;
    procedure Tick;
  public
    constructor Create;
    procedure Stage(const APhase, ALabel: String);
    procedure Progress(const ALoaded, ATotal: Double);
    procedure Fail(const AMessage: String);
    procedure Log(const AMessage: String);
    procedure HostStarted;
  end;

var
  GStartup: TStartupUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
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

constructor TStartupUI.Create;
var
  LBridge: TJSObject;
begin
  inherited Create;
  FStarted := window.performance.now;
  LBridge := TJSObject.new;
  LBridge['stage'] := @Stage;
  LBridge['progress'] := @Progress;
  LBridge['fail'] := @Fail;
  LBridge['log'] := @Log;
  LBridge['started'] := @HostStarted;
  TJSObject(window)['phanesStartup'] := LBridge;
  window.addEventListener('phanes-ready', @ReadyEvent);
  window.addEventListener('phanes-palette-ready', @PaletteEvent);
  window.addEventListener('error', @ErrorEvent, True);
  window.addEventListener('unhandledrejection', @RejectionEvent);
  Element('castle-canvas').addEventListener('webglcontextcreationerror', @GraphicsEvent);
  Element('castle-canvas').addEventListener('webglcontextlost', @GraphicsEvent);
  Element('startup-retry').addEventListener('click', @RetryEvent);
  Element('startup-select-details').addEventListener('click', @SelectDetails);
  Stage('host', 'Loading the workspace');
  FTimer := window.setInterval(@Tick, 1000);
end;

procedure TStartupUI.UpdateDetails;
begin
  TJSHTMLTextAreaElement(Element('startup-details-text')).value :=
    'Phanes startup' + #10 + 'Phase: ' + FPhase + #10 +
    'Elapsed: ' + IntToStr(Round((window.performance.now - FStarted) / 1000)) + ' s' + #10 +
    'Engine ready: ' + BoolToStr(FEngineReady, True) + #10 +
    'Initialization completed: ' + BoolToStr(FHostReady, True) + #10 +
    'Catalog ready: ' + BoolToStr(FPaletteReady, True) + #10 +
    'Download bytes: ' + FloatToStr(FLoaded) + ' / ' + FloatToStr(FTotal) + #10 +
    'Browser: ' + window.navigator.userAgent + #10 +
    'Error: ' + FFailure + #10 + FLog;
end;

procedure TStartupUI.Log(const AMessage: String);
begin
  FLog := FLog + Copy(AMessage, 1, 1000) + #10;
  if Length(FLog) > 12000 then
  begin
    Delete(FLog, 1, Length(FLog) - 12000);
  end;
  UpdateDetails;
end;

procedure TStartupUI.Stage(const APhase, ALabel: String);
begin
  if FReady or (FFailure <> '') then
  begin
    Exit;
  end;
  FPhase := APhase;
  FLabel := ALabel;
  FLastActivity := window.performance.now;
  FStalled := False;
  FLoaded := 0;
  FTotal := 0;
  document.body.setAttribute('data-startup-state', APhase);
  Element('startup-info').textContent := ALabel + '…';
  Element('status').textContent := ALabel;
  Element('startup-progress').removeAttribute('value');
  Element('startup-retry').hidden := True;
  Element('startup-help').hidden := True;
  Log(ALabel);
end;

procedure TStartupUI.Progress(const ALoaded, ATotal: Double);
var
  LText: String;
begin
  if FReady or (FFailure <> '') then
  begin
    Exit;
  end;
  FLastActivity := window.performance.now;
  FStalled := False;
  FLoaded := ALoaded;
  FTotal := ATotal;
  LText := FormatFloat('0.0', ALoaded / 1048576) + ' MB';
  if ATotal > 0 then
  begin
    Element('startup-progress').setAttribute('value', FloatToStr(Min(1, ALoaded / ATotal)));
    LText := IntToStr(Min(100, Floor(100 * ALoaded / ATotal))) + '% · ' +
      LText + ' / ' + FormatFloat('0.0', ATotal / 1048576) + ' MB';
  end;
  Element('startup-info').textContent := FLabel + ': ' + LText;
  Element('startup-retry').hidden := True;
  Element('startup-help').hidden := True;
  UpdateDetails;
end;

procedure TStartupUI.Fail(const AMessage: String);
begin
  if FReady or (FFailure <> '') then
  begin
    Exit;
  end;
  FFailure := AMessage;
  window.clearInterval(FTimer);
  document.body.setAttribute('data-startup-state', 'failed');
  TJSHTMLButtonElement(Element('create-world')).disabled := True;
  Element('startup-info').textContent := 'Could not start: ' + AMessage;
  Element('status').textContent := 'Workspace could not start';
  Element('startup-progress').hidden := True;
  Element('startup-retry').hidden := False;
  Element('startup-help').hidden := False;
  Element('startup-help').textContent := 'Retry loading, or open Startup details to share the error.';
  UpdateDetails;
  window.dispatchEvent(TJSEvent.new('phanes-startup-failed'));
end;

procedure TStartupUI.CheckReady;
begin
  if FFailure <> '' then
  begin
    Exit;
  end;
  if FEngineReady and FHostReady and FPaletteReady then
  begin
    FReady := True;
    window.clearInterval(FTimer);
    FPhase := 'ready';
    document.body.setAttribute('data-startup-state', 'ready');
    Element('startup-info').textContent := 'Your canvas is ready.';
    Element('status').textContent := 'Ready to create';
    Element('startup-progress').hidden := True;
    Element('startup-retry').hidden := True;
    Element('startup-help').hidden := True;
    Element('startup-details').hidden := True;
    UpdateDetails;
    window.dispatchEvent(TJSEvent.new('phanes-startup-ready'));
  end else if FEngineReady and FHostReady then
  begin
    Stage('catalog', 'Loading the creation catalog');
  end;
end;

procedure TStartupUI.HostStarted;
begin
  FHostReady := True;
  if not FEngineReady then
  begin
    Stage('first-frame', 'Drawing your first view');
  end;
  CheckReady;
end;

function TStartupUI.ReadyEvent(AEvent: TJSEvent): Boolean;
begin
  FEngineReady := True;
  CheckReady;
  Result := True;
end;

function TStartupUI.PaletteEvent(AEvent: TJSEvent): Boolean;
begin
  FPaletteReady := True;
  CheckReady;
  Result := True;
end;

function TStartupUI.ErrorEvent(AEvent: TJSEvent): Boolean;
var
  LMessage: String;
begin
  LMessage := String(TJSObject(AEvent)['message']);
  if (LMessage = '') or (LMessage = 'undefined') then
  begin
    if (AEvent.target <> nil) and (TJSObject(AEvent.target)['tagName'] = 'SCRIPT') then
    begin
      LMessage := 'A workspace script could not load: ' + String(TJSObject(AEvent.target)['src']);
    end else
    begin
      Exit(True);
    end;
  end;
  Fail(LMessage);
  Result := True;
end;

function TStartupUI.RejectionEvent(AEvent: TJSEvent): Boolean;
begin
  Fail(ErrorMessage(TJSObject(AEvent)['reason']));
  Result := True;
end;

function TStartupUI.GraphicsEvent(AEvent: TJSEvent): Boolean;
begin
  { A rejected WebGL2 attempt can be followed by CGE's supported WebGL1 fallback.
    Record creation errors, but let CGE decide whether both attempts failed. }
  if String(TJSObject(AEvent)['type']) = 'webglcontextlost' then
  begin
    Fail('The graphics context was lost while starting. Retry loading.');
  end else
  begin
    Log('Graphics context attempt: ' + String(TJSObject(AEvent)['statusMessage']));
  end;
  Result := True;
end;

function TStartupUI.RetryEvent(AEvent: TJSEvent): Boolean;
begin
  window.location.reload(False);
  Result := True;
end;

function TStartupUI.SelectDetails(AEvent: TJSEvent): Boolean;
begin
  TJSHTMLTextAreaElement(Element('startup-details-text')).focus;
  TSelectableTextArea(Element('startup-details-text')).select;
  Result := True;
end;

procedure TStartupUI.Tick;
begin
  if FReady or (FFailure <> '') then
  begin
    Exit;
  end;
  UpdateDetails;
  if not FStalled and (window.performance.now - FLastActivity > 30000) then
  begin
    FStalled := True;
    Element('startup-help').hidden := False;
    Element('startup-help').textContent :=
      'This step is taking longer. You can keep waiting or retry loading. ' +
      'Startup details show the current step.';
    Element('startup-retry').hidden := False;
  end;
end;

begin
  GStartup := TStartupUI.Create;
end.
