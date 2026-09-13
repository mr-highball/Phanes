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
unit phanes.tools.browser;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  FPJSON,
  Process,
  wfc_browser_cdp;

type
  TBrowserProbe = class
  private
    FProcess: TProcess;
    FClient: TWfcBrowserCDP;
    FSession: String;
    FTouch: Boolean;
    function Command(const AMethod: String; const AParams: TJSONObject = nil;
      const APage: Boolean = True): TJSONObject;
  public
    constructor Create(const AExecutable, AProfile: String);
    destructor Destroy; override;
    procedure Navigate(const AURL: String);
    procedure InstallScript(const ASource: String);
    procedure BlockURLs(const APatterns: array of String);
    procedure Resize(const AWidth, AHeight: Integer; const ADensity: Double = 1);
    procedure Lifecycle(const AState: String);
    function Evaluate(const AExpression: String): TJSONData;
    function Text(const AExpression: String): String;
    function Number(const AExpression: String): Double;
    procedure Execute(const AExpression: String);
    procedure WaitFor(const AExpression: String; const ATimeout: Cardinal = 120000);
    procedure Click(const ASelector: String);
    procedure ClickAt(const AX, AY: Double);
    procedure Hold(const ASelector: String; const AMilliseconds: Cardinal);
    procedure Touch(const AType: String; const APoints: TJSONArray);
    procedure Key(const AKey: String; const ACode: Integer);
    procedure HoldKey(const AKey: String; const ACode: Integer; const AMilliseconds: Cardinal);
    procedure SetValue(const AId, AValue: String; const AEvent: String = 'input');
    procedure Screenshot(const APath: String; const ACanvas: Boolean = False);
    function GPU: TJSONObject;
    function Metrics: TJSONObject;
    function Profile(const AMilliseconds: Cardinal): TJSONObject;
    procedure BeginProfile;
    function EndProfile: TJSONObject;
  end;

implementation

uses
  Base64,
  wfc_browser_capture_app,
  wfc_browser_socket;

procedure TBrowserProbe.BlockURLs(const APatterns: array of String);
var
  LURLs: TJSONArray;
  LPattern: String;
begin
  Command('Network.enable').Free;
  LURLs := TJSONArray.Create;
  for LPattern in APatterns do
  begin
    LURLs.Add(LPattern);
  end;
  Command('Network.setBlockedURLs', TJSONObject.Create(['urls', LURLs])).Free;
end;

function TBrowserProbe.Command(const AMethod: String; const AParams: TJSONObject;
  const APage: Boolean): TJSONObject;
begin
  try
    if APage then
    begin
      Result := FClient.Call(AMethod, AParams, FSession);
    end else
    begin
      Result := FClient.Call(AMethod, AParams);
    end;
  finally
    AParams.Free;
  end;
end;

constructor TBrowserProbe.Create(const AExecutable, AProfile: String);
var
  LEndpoint: TStringList;
  LDeadline: QWord;
  LPort: Integer;
  LPath: String;
  LReply: TJSONObject;
  LTarget: String;
begin
  inherited Create;
  WfcBrowserPrepareProfile(AProfile);
  FProcess := TProcess.Create(nil);
  FProcess.Executable := AExecutable;
  FProcess.Options := [poNoConsole];
  FProcess.Parameters.Add('--headless=new');
  FProcess.Parameters.Add('--no-first-run');
  FProcess.Parameters.Add('--no-default-browser-check');
  FProcess.Parameters.Add('--remote-debugging-port=0');
  FProcess.Parameters.Add('--user-data-dir=' + AProfile);
  if GetEnvironmentVariable('PHANES_SOFTWARE_GPU') = '1' then
  begin
    FProcess.Parameters.Add('--enable-unsafe-swiftshader');
    FProcess.Parameters.Add('--use-angle=swiftshader');
  end else
  begin
    FProcess.Parameters.Add('--enable-gpu');
    {$ifdef MSWINDOWS}
    FProcess.Parameters.Add('--use-angle=d3d11');
    {$endif}
  end;
  FProcess.Parameters.Add('about:blank');
  FProcess.Execute;
  LDeadline := WfcBrowserTickCount64 + 120000;
  LEndpoint := TStringList.Create;
  try
    repeat
      if not FProcess.Running then
      begin
        raise Exception.Create('The owned test browser stopped before publishing its endpoint.');
      end;
      if FileExists(IncludeTrailingPathDelimiter(AProfile) + 'DevToolsActivePort') then
      begin
        try
          LEndpoint.LoadFromFile(IncludeTrailingPathDelimiter(AProfile) + 'DevToolsActivePort');
        except
          on EFOpenError do
          begin
            LEndpoint.Clear;
          end;
        end;
      end;
      if LEndpoint.Count >= 2 then
      begin
        Break;
      end;
      if WfcBrowserTickCount64 >= LDeadline then
      begin
        raise Exception.Create('Timed out waiting for the owned browser endpoint.');
      end;
      Sleep(25);
    until False;
    WfcBrowserParseEndpoint(LEndpoint.Text, LPort, LPath);
  finally
    LEndpoint.Free;
  end;
  FClient := TWfcBrowserCDP.Create(LPort, LPath, WfcBrowserTickCount64 + 3600000, 33554432);
  LReply := Command('Target.createTarget', TJSONObject.Create(['url', 'about:blank']), False);
  try
    LTarget := LReply.Strings['targetId'];
  finally
    LReply.Free;
  end;
  LReply := Command('Target.attachToTarget',
    TJSONObject.Create(['targetId', LTarget, 'flatten', True]), False);
  try
    FSession := LReply.Strings['sessionId'];
  finally
    LReply.Free;
  end;
  LReply := Command('Page.enable');
  LReply.Free;
  LReply := Command('Runtime.enable');
  LReply.Free;
  LReply := Command('Performance.enable');
  LReply.Free;
end;

destructor TBrowserProbe.Destroy;
var
  LReply: TJSONObject;
begin
  if FClient <> nil then
  begin
    try
      LReply := Command('Browser.close', nil, False);
      LReply.Free;
    except
      on Exception do
      begin
        { A successful browser shutdown may close the socket before replying. }
      end;
    end;
  end;
  FClient.Free;
  if FProcess <> nil then
  begin
    if FProcess.Running then
    begin
      FProcess.Terminate(0);
    end;
    FProcess.Free;
  end;
  inherited;
end;

procedure TBrowserProbe.Lifecycle(const AState: String);
begin
  if (AState <> 'frozen') and (AState <> 'active') then
  begin
    raise Exception.Create('Choose frozen or active browser lifecycle state.');
  end;
  Command('Page.setWebLifecycleState', TJSONObject.Create(['state', AState])).Free;
  if AState = 'active' then
  begin
    Command('Page.bringToFront').Free;
    Command('Emulation.setFocusEmulationEnabled', TJSONObject.Create(['enabled', True])).Free;
  end;
end;

procedure TBrowserProbe.Navigate(const AURL: String);
var
  LReply: TJSONObject;
begin
  LReply := Command('Page.navigate', TJSONObject.Create(['url', AURL]));
  try
    if LReply.Find('errorText') <> nil then
    begin
      raise Exception.Create(LReply.Strings['errorText']);
    end;
  finally
    LReply.Free;
  end;
end;

procedure TBrowserProbe.InstallScript(const ASource: String);
var
  LReply: TJSONObject;
begin
  Execute(ASource);
  LReply := Command('Page.addScriptToEvaluateOnNewDocument', TJSONObject.Create(['source', ASource]));
  LReply.Free;
end;

procedure TBrowserProbe.Resize(const AWidth, AHeight: Integer; const ADensity: Double);
var
  LReply: TJSONObject;
begin
  FTouch := AWidth < 700;
  LReply := Command('Emulation.setDeviceMetricsOverride', TJSONObject.Create([
    'width', AWidth, 'height', AHeight, 'deviceScaleFactor', ADensity, 'mobile', False]));
  LReply.Free;
  LReply := Command('Emulation.setTouchEmulationEnabled',
    TJSONObject.Create(['enabled', FTouch]));
  LReply.Free;
end;

function TBrowserProbe.Evaluate(const AExpression: String): TJSONData;
var
  LReply: TJSONObject;
  LValue: TJSONData;
begin
  LReply := Command('Runtime.evaluate', TJSONObject.Create([
    'expression', AExpression, 'returnByValue', True, 'awaitPromise', True,
    'timeout', 15000]));
  try
    if LReply.Find('exceptionDetails') <> nil then
    begin
      raise Exception.Create('Browser binding failed: ' + LReply.Objects['exceptionDetails'].AsJSON);
    end;
    LValue := LReply.Objects['result'].Find('value');
    if LValue = nil then
    begin
      Result := TJSONNull.Create;
    end else
    begin
      Result := LValue.Clone;
    end;
  finally
    LReply.Free;
  end;
end;

function TBrowserProbe.Text(const AExpression: String): String;
var
  LValue: TJSONData;
begin
  LValue := Evaluate(AExpression);
  try
    Result := LValue.AsString;
  finally
    LValue.Free;
  end;
end;

procedure TBrowserProbe.Execute(const AExpression: String);
var
  LValue: TJSONData;
begin
  LValue := Evaluate(AExpression);
  LValue.Free;
end;

function TBrowserProbe.Number(const AExpression: String): Double;
var
  LValue: TJSONData;
begin
  LValue := Evaluate(AExpression);
  try
    Result := LValue.AsFloat;
  finally
    LValue.Free;
  end;
end;

procedure TBrowserProbe.WaitFor(const AExpression: String; const ATimeout: Cardinal);
var
  LDeadline: QWord;
  LValue: TJSONData;
  LReady: Boolean;
begin
  LDeadline := WfcBrowserTickCount64 + ATimeout;
  repeat
    LValue := Evaluate(AExpression);
    try
      LReady := (LValue.JSONType = jtBoolean) and LValue.AsBoolean;
    finally
      LValue.Free;
    end;
    if LReady then
    begin
      Exit;
    end;
    if WfcBrowserTickCount64 >= LDeadline then
    begin
      raise Exception.Create('Browser wait timed out: ' + AExpression);
    end;
    Sleep(25);
  until False;
end;

procedure TBrowserProbe.Click(const ASelector: String);
var
  LQuery: TJSONString;
  LBox: TJSONObject;
  LX: Double;
  LY: Double;
begin
  LQuery := TJSONString.Create(ASelector);
  try
    if Text('document.querySelector(' + LQuery.AsJSON + ').disabled===true') = 'true' then
    begin
      raise Exception.Create('Cannot click a disabled target: ' + ASelector);
    end;
    Execute('document.querySelector(' + LQuery.AsJSON + ').scrollIntoView({block:"nearest"})');
    if Text('(()=>{const e=document.querySelector(' + LQuery.AsJSON +
      '),r=e.getBoundingClientRect();return e.contains(document.elementFromPoint(' +
      'r.x+r.width/2,r.y+r.height/2))})()') <> 'true' then
    begin
      raise Exception.Create('Click target is outside the viewport or covered: ' + ASelector);
    end;
    LBox := TJSONObject(Evaluate('document.querySelector(' + LQuery.AsJSON +
      ').getBoundingClientRect().toJSON()'));
  finally
    LQuery.Free;
  end;
  try
    LX := LBox.Floats['x'] + LBox.Floats['width'] / 2;
    LY := LBox.Floats['y'] + LBox.Floats['height'] / 2;
    if (LBox.Floats['width'] <= 0) or (LBox.Floats['height'] <= 0) then
    begin
      raise Exception.Create('Cannot click a hidden or empty target: ' + ASelector);
    end;
  finally
    LBox.Free;
  end;
  ClickAt(LX, LY);
end;

procedure TBrowserProbe.ClickAt(const AX, AY: Double);
var
  LReply: TJSONObject;
  LPoints: TJSONArray;
begin
  if FTouch then
  begin
    LPoints := TJSONArray.Create;
    LPoints.Add(TJSONObject.Create(['x', AX, 'y', AY]));
    LReply := Command('Input.dispatchTouchEvent',
      TJSONObject.Create(['type', 'touchStart', 'touchPoints', LPoints]));
    LReply.Free;
    LReply := Command('Input.dispatchTouchEvent',
      TJSONObject.Create(['type', 'touchEnd', 'touchPoints', TJSONArray.Create]));
    LReply.Free;
    Exit;
  end;
  LReply := Command('Input.dispatchMouseEvent', TJSONObject.Create([
    'type', 'mousePressed', 'x', AX, 'y', AY, 'button', 'left', 'clickCount', 1]));
  LReply.Free;
  LReply := Command('Input.dispatchMouseEvent', TJSONObject.Create([
    'type', 'mouseReleased', 'x', AX, 'y', AY, 'button', 'left', 'clickCount', 1]));
  LReply.Free;
end;

procedure TBrowserProbe.Key(const AKey: String; const ACode: Integer);
var
  LReply: TJSONObject;
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create([
    'type', 'keyDown', 'key', AKey, 'code', AKey, 'windowsVirtualKeyCode', ACode]);
  if AKey = 'Enter' then
  begin
    LParams.Add('text', #13);
    LParams.Add('unmodifiedText', #13);
  end;
  LReply := Command('Input.dispatchKeyEvent', LParams);
  LReply.Free;
  LReply := Command('Input.dispatchKeyEvent', TJSONObject.Create([
    'type', 'keyUp', 'key', AKey, 'windowsVirtualKeyCode', ACode]));
  LReply.Free;
end;

procedure TBrowserProbe.HoldKey(const AKey: String; const ACode: Integer;
  const AMilliseconds: Cardinal);
var
  LReply: TJSONObject;
begin
  LReply := Command('Input.dispatchKeyEvent', TJSONObject.Create([
    'type', 'keyDown', 'key', AKey, 'windowsVirtualKeyCode', ACode]));
  LReply.Free;
  try
    Sleep(AMilliseconds);
  finally
    LReply := Command('Input.dispatchKeyEvent', TJSONObject.Create([
      'type', 'keyUp', 'key', AKey, 'windowsVirtualKeyCode', ACode]));
    LReply.Free;
  end;
end;

procedure TBrowserProbe.SetValue(const AId, AValue, AEvent: String);
var
  LId: TJSONString;
  LValue: TJSONString;
  LEvent: TJSONString;
begin
  LId := TJSONString.Create(AId);
  LValue := TJSONString.Create(AValue);
  LEvent := TJSONString.Create(AEvent);
  try
    Execute('document.getElementById(' + LId.AsJSON + ').value=' + LValue.AsJSON);
    Execute('document.getElementById(' + LId.AsJSON + ').dispatchEvent(new Event(' +
      LEvent.AsJSON + ',{bubbles:true}))');
  finally
    LId.Free;
    LValue.Free;
    LEvent.Free;
  end;
end;

procedure TBrowserProbe.Screenshot(const APath: String; const ACanvas: Boolean);
var
  LParams: TJSONObject;
  LReply: TJSONObject;
  LBox: TJSONObject;
  LBytes: String;
  LFile: TFileStream;
begin
  LReply := Command('Input.dispatchMouseEvent', TJSONObject.Create([
    'type', 'mouseMoved', 'x', 0, 'y', 0, 'button', 'none']));
  LReply.Free;
  Sleep(200);
  LParams := TJSONObject.Create(['format', 'png', 'captureBeyondViewport', False]);
  if ACanvas then
  begin
    LBox := TJSONObject(Evaluate('document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
    try
      LParams.Add('clip', TJSONObject.Create(['x', LBox.Floats['x'], 'y', LBox.Floats['y'],
        'width', LBox.Floats['width'], 'height', LBox.Floats['height'], 'scale', 1]));
    finally
      LBox.Free;
    end;
  end;
  LReply := Command('Page.captureScreenshot', LParams);
  try
    LBytes := DecodeStringBase64(LReply.Strings['data']);
    LFile := TFileStream.Create(APath, fmCreate);
    try
      if LBytes <> '' then
      begin
        LFile.WriteBuffer(LBytes[1], Length(LBytes));
      end;
    finally
      LFile.Free;
    end;
  finally
    LReply.Free;
  end;
end;

function TBrowserProbe.GPU: TJSONObject;
begin
  Result := Command('SystemInfo.getInfo', nil, False);
end;

function TBrowserProbe.Metrics: TJSONObject;
begin
  Result := Command('Performance.getMetrics');
end;

function TBrowserProbe.Profile(const AMilliseconds: Cardinal): TJSONObject;
begin
  BeginProfile;
  Sleep(AMilliseconds);
  Result := EndProfile;
end;

procedure TBrowserProbe.BeginProfile;
var
  LReply: TJSONObject;
begin
  LReply := Command('Profiler.enable');
  LReply.Free;
  LReply := Command('Profiler.start');
  LReply.Free;
end;

function TBrowserProbe.EndProfile: TJSONObject;
begin
  Result := Command('Profiler.stop');
end;

procedure TBrowserProbe.Touch(const AType: String; const APoints: TJSONArray);
var
  LReply: TJSONObject;
begin
  LReply := Command('Input.dispatchTouchEvent', TJSONObject.Create([
    'type', AType, 'touchPoints', APoints]));
  LReply.Free;
end;

procedure TBrowserProbe.Hold(const ASelector: String; const AMilliseconds: Cardinal);
var
  LQuery: TJSONString;
  LBounds: TJSONObject;
  LReply: TJSONObject;
  LX: Double;
  LY: Double;
begin
  LQuery := TJSONString.Create(ASelector);
  try
    LBounds := TJSONObject(Evaluate('document.querySelector(' +
      LQuery.AsJSON + ').getBoundingClientRect().toJSON()'));
  finally
    LQuery.Free;
  end;
  try
    LX := LBounds.Floats['x'] + LBounds.Floats['width'] / 2;
    LY := LBounds.Floats['y'] + LBounds.Floats['height'] / 2;
    if (LBounds.Floats['width'] <= 0) or (LBounds.Floats['height'] <= 0) then
    begin
      raise Exception.Create('Cannot hold a hidden control: ' + ASelector);
    end;
  finally
    LBounds.Free;
  end;
  LReply := Command('Input.dispatchTouchEvent', TJSONObject.Create([
    'type', 'touchStart', 'touchPoints', TJSONArray.Create([
      TJSONObject.Create(['x', LX, 'y', LY, 'id', 1])])]));
  LReply.Free;
  try
    Sleep(AMilliseconds);
  finally
    LReply := Command('Input.dispatchTouchEvent', TJSONObject.Create([
      'type', 'touchEnd', 'touchPoints', TJSONArray.Create]));
    LReply.Free;
  end;
end;

end.
