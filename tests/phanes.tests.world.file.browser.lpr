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

program PhanesWorldFileBrowser;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  JSONParser,
  phanes.tools.browser,
  phanes.tools.files,
  wfc_browser_capture_app,
  wfc_browser_cdp,
  wfc_browser_socket;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GDownloads: String;
  GDownloadClient: TWfcBrowserCDP;
  GEvidence: TJSONObject;
  GChecks: TJSONArray;
  GProbe: UTF8String;
  GSelection: String;
  GBefore: String;

function WorldPoint(const AX, AY: Double): TJSONObject;
var
  LBounds: TJSONObject;
begin
  LBounds := TJSONObject(GPage.Evaluate(
    'document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
  try
    Result := TJSONObject.Create(['x', LBounds.Floats['x'] + AX * LBounds.Floats['width'],
      'y', LBounds.Floats['y'] + AY * LBounds.Floats['height'], 'id', 1]);
  finally
    LBounds.Free;
  end;
end;

function Quote(const AText: String): String;
var
  LValue: TJSONString;
begin
  LValue := TJSONString.Create(AText);
  try
    Result := LValue.AsJSON;
  finally
    LValue.Free;
  end;
end;

function NormalJSON(const AText: String): String;
var
  LValue: TJSONData;
begin
  LValue := GetJSON(AText, True);
  try
    Result := LValue.AsJSON;
  finally
    LValue.Free;
  end;
end;

procedure Check(const ACondition: Boolean; const AName: String);
begin
  GChecks.Add(TJSONObject.Create(['name', AName, 'passed', ACondition]));
  Require(ACondition, AName);
  WriteLn('PASS ', AName);
  Flush(Output);
end;

procedure FixtureCheck(const ACondition: Boolean; const AName: String);
begin
  if not ACondition then
  begin
    WriteText(GOutput + '/fixture-failure.json', UTF8String(GPage.Text(
      'JSON.stringify({name:' + Quote(AName) + ',status:document.getElementById("status")?.textContent,' +
      'toast:document.getElementById("toast")?.textContent,lastSolve:document.body?.dataset.lastSolve,' +
      'worldFormat:phanesEditor?.world?.formatVersion,worker:Boolean(phanesEditor?.worker),' +
      'job:phanesEditor?.job,scene:window.phanesSceneVersion,' +
      'rendered:document.body?.dataset.renderedRevision,selection:phanesEditor?.selection})')));
  end;
  Check(ACondition, AName);
end;

procedure ShowTools(const AVisible: Boolean);
var
  LExpected: String;
begin
  LExpected := LowerCase(BoolToStr(AVisible, True));
  if GPage.Text('document.getElementById("tools-toggle").getAttribute("aria-expanded")') <>
    LExpected then
  begin
    GPage.Click('#tools-toggle');
  end;
  GPage.WaitFor('document.getElementById("tools-toggle").getAttribute("aria-expanded")===' +
    Quote(LExpected), 5000);
end;

procedure Stroke;
begin
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(0.36, 0.45)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.65, 0.45)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.65, 0.65)]));
  GPage.Touch('touchEnd', TJSONArray.Create);
  GPage.WaitFor('!phanesAuthoringBusy', 15000);
end;

procedure InstallLandformProbe;
begin
  GProbe := UTF8String(ReadText('build/phanes.tests.landforms.probe.js'));
  if (Length(GProbe) >= 3) and (Ord(GProbe[1]) = $EF) and
    (Ord(GProbe[2]) = $BB) and (Ord(GProbe[3]) = $BF) then
  begin
    Delete(GProbe, 1, 3);
  end;
  GPage.InstallScript('(()=>{' + String(GProbe) + #10 + 'rtl.run();})();');
end;

procedure InstallDownloadProbe;
begin
  GPage.InstallScript('window.phanesWorldFileDownloadProbe={clicks:[],anchors:[],errors:[]};' +
    'addEventListener("error",e=>phanesWorldFileDownloadProbe.errors.push(String(e.message)));' +
    'addEventListener("unhandledrejection",e=>' +
    'phanesWorldFileDownloadProbe.errors.push(String(e.reason)));' +
    'addEventListener("click",e=>{if(e.target?.id==="save-world"||' +
    'e.target?.id==="mobile-save-world")phanesWorldFileDownloadProbe.clicks.push({' +
    'id:e.target.id,trusted:e.isTrusted,detail:e.detail})},true);' +
    'const phanesWorldFileAnchorClick=HTMLAnchorElement.prototype.click;' +
    'HTMLAnchorElement.prototype.click=function(){let eventState=null;' +
    'this.addEventListener("click",e=>eventState={defaultPrevented:e.defaultPrevented,' +
    'trusted:e.isTrusted,detail:e.detail},{once:true});' +
    'const result=phanesWorldFileAnchorClick.call(this);' +
    'phanesWorldFileDownloadProbe.anchors.push({download:this.download,href:String(this.href),' +
    'event:eventState,userActivation:{isActive:navigator.userActivation?.isActive,' +
    'hasBeenActive:navigator.userActivation?.hasBeenActive}});return result}');
end;

procedure CaptureDownloadManager;
var
  LReply: TJSONObject;
  LResult: TJSONObject;
  LValue: TJSONData;
  LTarget: String;
  LSession: String;
  LDeadline: QWord;
  LCaptured: Boolean;
begin
  LReply := GDownloadClient.Call('Target.createTarget',
    TJSONObject.Create(['url', 'edge://downloads/']));
  try
    LTarget := LReply.Strings['targetId'];
  finally
    LReply.Free;
  end;
  LReply := GDownloadClient.Call('Target.attachToTarget',
    TJSONObject.Create(['targetId', LTarget, 'flatten', True]));
  try
    LSession := LReply.Strings['sessionId'];
  finally
    LReply.Free;
  end;
  LReply := GDownloadClient.Call('Runtime.enable', nil, LSession);
  LReply.Free;
  LDeadline := WfcBrowserTickCount64 + 10000;
  LCaptured := False;
  repeat
    LReply := GDownloadClient.Call('Runtime.evaluate', TJSONObject.Create([
      'expression', '(()=>{const m=document.querySelector("downloads-manager");' +
      'if(!m)return null;const items=m.items_||[];return {managerKeys:Object.keys(m),' +
      'count:items.length,items:Array.from(items,x=>({keys:Object.keys(x),id:x.id,guid:x.guid,' +
      'state:x.state,dangerType:x.dangerType,interruptReason:x.interruptReason,' +
      'lastReasonText:x.lastReasonText,filePath:x.filePath,fileName:x.fileName,' +
      'url:x.url,receivedBytes:x.receivedBytes,totalBytes:x.totalBytes,' +
      'exists:x.exists,paused:x.paused,canResume:x.canResume}))}})()',
      'returnByValue', True]), LSession);
    try
      LResult := LReply.Objects['result'];
      LValue := LResult.Find('value');
      if (LValue <> nil) and (LValue.JSONType = jtObject) then
      begin
        WriteText(GOutput + '/download-manager.json', UTF8String(LValue.FormatJSON));
        LCaptured := True;
      end;
    finally
      LReply.Free;
    end;
    if LCaptured or (WfcBrowserTickCount64 >= LDeadline) then
    begin
      Break;
    end;
    Sleep(50);
  until False;
  if not LCaptured then
  begin
    WriteText(GOutput + '/download-manager.json', UTF8String(
      '{"captured":false,"reason":"downloads-manager unavailable"}'));
  end;
end;

procedure ValidateLandform;
var
  LReport: TJSONObject;
begin
  LReport := TJSONObject(GPage.Evaluate('phanesLandformCheck(' + Quote(GBefore) + ',' +
    Quote(GSelection) + ',"land-raise",1000)'));
  try
    WriteText(GOutput + '/land-raise-admission.json', UTF8String(LReport.FormatJSON));
    FixtureCheck(LReport.Booleans['accepted'],
      'Format 4 fixture passes independent landform admission');
    FixtureCheck(LReport.Booleans['roundTrip'],
      'Format 4 fixture passes existing world-wire round trip');
  finally
    LReport.Free;
  end;
end;

procedure EnableDownloads(const AProfile: String);
var
  LLines: TStringList;
  LParameters: TJSONObject;
  LReply: TJSONObject;
  LPort: Integer;
  LPath: String;
begin
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AProfile + '/DevToolsActivePort');
    Require(LLines.Count >= 2, 'Owned browser did not provide its CDP endpoint');
    WfcBrowserParseEndpoint(LLines.Text, LPort, LPath);
  finally
    LLines.Free;
  end;
  GDownloadClient := TWfcBrowserCDP.Create(LPort, LPath,
    WfcBrowserTickCount64 + 1200000, 1048576);
  LParameters := TJSONObject.Create(['behavior', 'allow',
    'downloadPath', GDownloads, 'eventsEnabled', False]);
  try
    LReply := GDownloadClient.Call('Browser.setDownloadBehavior', LParameters);
    LReply.Free;
  finally
    LParameters.Free;
  end;
end;

function Download(const AName: String): String;
var
  LDeadline: QWord;
  LPath: String;
begin
  LPath := GDownloads + '/' + AName;
  LDeadline := WfcBrowserTickCount64 + 60000;
  while not FileExists(LPath) do
  begin
    if WfcBrowserTickCount64 >= LDeadline then
    begin
      WriteText(GOutput + '/download-failure-state.json', UTF8String(GPage.Text(
        'JSON.stringify(phanesWorldFileDownloadProbe)')));
      raise Exception.Create('Actual browser download did not finish: ' + AName);
    end;
    Sleep(50);
  end;
  Require(not FileExists(LPath + '.crdownload'), 'Download is still incomplete');
  Result := String(ReadText(LPath));
end;

procedure Settled;
begin
  GPage.WaitFor('!phanesEditor.worker && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

function ImportText(const AText: String): Integer;
var
  LVersion: Double;
begin
  Result := Round(GPage.Number('window.phanesSceneVersion||0'));
  LVersion := GPage.Number('window.phanesWorldFileVersion||0');
  GPage.Execute('(()=>{const i=document.getElementById("world-file");' +
    'const d=new DataTransfer();d.items.add(new File([' + Quote(AText) +
    '],"world.json",{type:"application/json"}));i.files=d.files;' +
    'i.dispatchEvent(new Event("change",{bubbles:true}))})()');
  GPage.WaitFor('(window.phanesWorldFileVersion||0)>' + FloatToStr(LVersion), 180000);
end;

procedure WaitForPublishedImport(const AScene: Integer);
begin
  GPage.WaitFor('!phanesEditor.worker && !window.phanesCatalogLoading && ' +
    'phanesSceneVersion>' + IntToStr(AScene) + ' && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

procedure CheckUnchangedImport(const AText, AName: String);
var
  LState: String;
begin
  LState := GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])');
  ImportText(AText);
  GPage.WaitFor('phanesWorldFileUI.status==="rejected"');
  Check(GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])') = LState, AName + ' leaves world and history unchanged');
  Check(GPage.Text('document.getElementById("toast").classList.contains("error")') = 'true',
    AName + ' reports a visible error');
end;

procedure CheckWorkerRejectedImport(const AText, AName: String);
var
  LState: String;
begin
  LState := GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])');
  ImportText(AText);
  GPage.WaitFor('!phanesEditor.worker && document.body.dataset.lastSolve==="failed"', 180000);
  Check(GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])') = LState, AName + ' leaves world and history unchanged');
  Check(GPage.Text('document.getElementById("toast").classList.contains("error")') = 'true',
    AName + ' reports worker validation failure');
end;

procedure CheckOversizedImport;
var
  LState: String;
  LVersion: Integer;
begin
  LState := GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])');
  LVersion := Round(GPage.Number('window.phanesWorldFileVersion||0'));
  GPage.Execute('(()=>{const i=document.getElementById("world-file");' +
    'const d=new DataTransfer();const f=new File([new Uint8Array(8*1024*1024+1)],' +
    '"oversized-world.json",{type:"application/json"});' +
    'window.phanesOversizedFile={size:f.size,textCalls:0};' +
    'Object.defineProperty(f,"text",{value:()=>{' +
    'phanesOversizedFile.textCalls++;return Promise.resolve("{}");}});' +
    'd.items.add(f);i.files=d.files;i.dispatchEvent(new Event("change",{bubbles:true}))})()');
  GPage.WaitFor('phanesWorldFileVersion>' + IntToStr(LVersion) + '&&' +
    'phanesWorldFileUI.status==="rejected"', 5000);
  Check(GPage.Number('phanesOversizedFile.size') = 8 * 1024 * 1024 + 1,
    'Oversized regression dispatches an actual 8 MiB plus 1 byte File');
  Check(GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future])') = LState,
    'Oversized file leaves world and history unchanged');
  Check(GPage.Text('document.getElementById("toast").classList.contains("error")') = 'true',
    'Oversized file reports a visible error');
  Check(GPage.Number('phanesOversizedFile.textCalls') = 0,
    'Oversized file is rejected before File.text is called');
end;

procedure CheckStaleRead(const AOlder, ANewer, AExpectedWorld: String);
var
  LScene: Integer;
  LVersion: Integer;
begin
  LScene := Round(GPage.Number('phanesSceneVersion'));
  LVersion := Round(GPage.Number('phanesWorldFileVersion'));
  GPage.Execute('(()=>{const input=document.getElementById("world-file");' +
    'const send=(text,name,delay)=>{const d=new DataTransfer();' +
    'const f=new File([text],name,{type:"application/json"});' +
    'Object.defineProperty(f,"text",{value:()=>delay?new Promise(resolve=>' +
    'window.phanesReleaseOlder=()=>{resolve(text);queueMicrotask(()=>queueMicrotask(()=>' +
    'window.phanesOlderAcknowledged=true))}):Promise.resolve(text)});' +
    'd.items.add(f);input.files=d.files;' +
    'input.dispatchEvent(new Event("change",{bubbles:true}))};' +
    'window.phanesOlderAcknowledged=false;send(' + Quote(AOlder) + ',"older.json",1);' +
    'send(' + Quote(ANewer) + ',"newer.json",0)})()');
  GPage.WaitFor('phanesWorldFileVersion>' + IntToStr(LVersion));
  WaitForPublishedImport(LScene);
  GPage.Execute('phanesReleaseOlder()');
  GPage.WaitFor('window.phanesOlderAcknowledged===true');
  Check(GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()') = AExpectedWorld,
    'A stale older file read cannot replace the newer accepted import');
  Check(Round(GPage.Number('phanesWorldFileVersion')) = LVersion + 1,
    'Only the current file read reports an import completion');
end;

procedure RunJourney;
var
  LWorld: String;
  LSemantics: String;
  LExport: String;
  LLegacy: String;
  LVersion2: String;
  LVersion1: String;
  LVersion2Semantics: String;
  LBad: String;
  LFilename: String;
  LScene: Integer;
begin
  GPage.Resize(1280, 900);
  GPage.Navigate(ParamStr(2));
  GPage.WaitFor('document.body?.dataset.startupState==="ready"');
  GPage.SetValue('region-size', '4');
  GPage.Click('#create-world');
  Settled;
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection();' +
    'phanesEditorActions.generate("clear",null,{editLayer:""})');
  Settled;
  FixtureCheck(GPage.Text('phanesEditor.world.layers[0].every(v=>v==="meadow")') = 'true',
    'Whole-world clear produces the accepted fresh landscape');
  FixtureCheck(GPage.Text('document.body.dataset.lastSolve') = 'passed',
    'Whole-world clear publishes a completed worker result');
  GPage.Click('#open-landforms');
  GPage.Click('[data-authoring-tool="box"]');
  ShowTools(False);
  Stroke;
  FixtureCheck(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
    'Actual Box stroke produces a nonempty terrain selection');
  GSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
  ShowTools(True);
  GPage.Execute('window.phanesLegacyFixture=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete phanesLegacyFixture.elevation;phanesLegacyFixture.formatVersion=2;' +
    'phanesEditorActions.generate("restore",phanesLegacyFixture,{})');
  Settled;
  FixtureCheck(GPage.Number('phanesEditor.world.formatVersion') = 2,
    'Worker accepts the cleared legacy format 2 fixture');
  GPage.Execute('phanesEditor.selection=' + GSelection + ';phanesEditorActions.syncSelection()');
  GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
  GPage.SetValue('landform-amount', '1000', 'change');
  GPage.Click('[data-landform="land-raise"]');
  Settled;
  FixtureCheck(GPage.Number('phanesEditor.world.formatVersion') = 4,
    'Actual legacy land edit creates a format 4 world');
  ValidateLandform;
  LWorld := GPage.Text('JSON.stringify(phanesEditor.world)');
  LSemantics := GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()');
  LFilename := 'phanes-' + GPage.Text('phanesEditor.world.seed') + '.json';
  WriteText(GOutput + '/attempted-format4.json', UTF8String(
    '{"version":4,"world":' + LWorld + '}'));
  WriteText(GOutput + '/user-activation-before-export.json', UTF8String(GPage.Text(
    'JSON.stringify({isActive:navigator.userActivation?.isActive,' +
    'hasBeenActive:navigator.userActivation?.hasBeenActive})')));
  GPage.Click('#save-world');
  LExport := Download(LFilename);
  WriteText(GOutput + '/desktop-format4.json', UTF8String(LExport));
  Check(TJSONObject(GetJSON(LExport, True)).Integers['version'] = 4,
    'Desktop Export writes a format 4 envelope');
  Check(NormalJSON(TJSONObject(GetJSON(LExport, True)).Objects['world'].AsJSON) =
    NormalJSON(LWorld), 'Desktop Export preserves the exact relative-elevation world');
  GPage.Execute('phanesEditorActions.generate("land-lower",null,' +
    '{landformAmount:1000,editLayer:"terrain"})');
  Settled;
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') <> LWorld,
    'A real worker edit distinguishes the import target');
  LScene := ImportText(LExport);
  WaitForPublishedImport(LScene);
  Check(GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()') = LSemantics,
    'Desktop file-input import restores exact format 4 terrain and world semantics');
  GPage.Screenshot(GOutput + '/desktop-imported.png');

  LBad := GPage.Text('(()=>{const e=' + LExport +
    ';e.version=3;return JSON.stringify(e)})()');
  CheckUnchangedImport(LBad, 'Mismatched envelope');
  LBad := GPage.Text('(()=>{const e=' + LExport +
    ';e.version=5;e.world.formatVersion=5;return JSON.stringify(e)})()');
  CheckUnchangedImport(LBad, 'Unsupported envelope');
  CheckUnchangedImport('{"version":4,"world":', 'Corrupt payload');
  CheckOversizedImport;
  LBad := GPage.Text('(()=>{const e=' + LExport +
    ';e.world.layers[0][0]=7;return JSON.stringify(e)})()');
  CheckWorkerRejectedImport(LBad, 'Worker-rejected corrupt world');

  LVersion2 := '{"version":2,"world":' + GBefore + '}';
  LVersion2Semantics := GPage.Text('(()=>{const w=' + GBefore +
    ';delete w.solveMilliseconds;return JSON.stringify(w)})()');
  LScene := ImportText(LVersion2);
  WaitForPublishedImport(LScene);
  Check(GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()') = LVersion2Semantics,
    'Legacy format 2 file-input import preserves its complete world semantics');
  LVersion1 := GPage.Text('(()=>{const e=' + LVersion2 +
    ';e.version=1;delete e.world.formatVersion;delete e.world.composition;' +
    'delete e.world.elevation;return JSON.stringify(e)})()');
  GPage.Execute('window.phanesV1Expected=JSON.parse(' + Quote(LVersion1) + ').world');
  LScene := ImportText(LVersion1);
  WaitForPublishedImport(LScene);
  Check(GPage.Text('phanesEditor.world.size===phanesV1Expected.size&&' +
    'phanesEditor.world.seed===phanesV1Expected.seed&&' +
    'JSON.stringify(phanesEditor.world.layers)===JSON.stringify(phanesV1Expected.layers)&&' +
    'phanesEditor.world.formatVersion===2') = 'true',
    'Legacy format 1 file-input import preserves layers and synthesizes its composition');
  LLegacy := GPage.Text('(()=>{const e=' + LExport +
    ';e.version=3;e.world.formatVersion=3;return JSON.stringify(e)})()');
  LScene := ImportText(LLegacy);
  WaitForPublishedImport(LScene);
  Check(GPage.Number('phanesEditor.world.formatVersion') = 3,
    'Legacy format 3 file-input import remains supported');
  LScene := ImportText(LExport);
  WaitForPublishedImport(LScene);
  CheckStaleRead(LLegacy, LExport, LSemantics);

  GPage.Execute('phanesEditorActions.generate("land-raise",null,' +
    '{landformAmount:1000,editLayer:"terrain"})');
  Settled;
  FixtureCheck(GPage.Number('phanesEditor.world.formatVersion') = 4,
    'Phone fixture remains a real relative-elevation world');
  LWorld := GPage.Text('JSON.stringify(phanesEditor.world)');
  LSemantics := GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()');
  GPage.Resize(390, 844, 2);
  ShowTools(True);
  GPage.Execute('document.getElementById("mobile-save-world").scrollIntoView({block:"nearest"})');
  WriteText(GOutput + '/phone-controls.json', UTF8String(GPage.Text(
    '(()=>{const b=document.getElementById("mobile-save-world");const r=b.getBoundingClientRect();' +
    'const p=b.closest(".tools-panel,aside,[role=dialog]");return JSON.stringify({' +
    'display:getComputedStyle(b).display,visibility:getComputedStyle(b).visibility,' +
    'bounds:{x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom},' +
    'insideViewport:r.x>=0&&r.right<=innerWidth&&r.y>=0&&r.bottom<=innerHeight,' +
    'hit:b.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)),' +
    'panelScrollTop:p?.scrollTop,documentScrollTop:document.scrollingElement?.scrollTop})})()')));
  Check(GPage.Text('(()=>{const b=document.getElementById("mobile-save-world");' +
    'const r=b.getBoundingClientRect();return r.width>=44&&r.height>=44&&' +
    'r.x>=0&&r.right<=innerWidth&&r.y>=0&&r.bottom<=innerHeight&&' +
    'b.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})()') = 'true',
    'Phone Export is a visible hit-tested control');
  Check(GPage.Text('(()=>{const b=document.getElementById("import-world");' +
    'const r=b.getBoundingClientRect();return r.width>0&&r.height>0&&' +
    'b.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})()') = 'true',
    'Phone Open is a visible hit-tested control');
  LFilename := 'phanes-' + GPage.Text('phanesEditor.world.seed') + '.json';
  GPage.Click('#mobile-save-world');
  LExport := Download(LFilename);
  Check(TJSONObject(GetJSON(LExport, True)).Integers['version'] = 4,
    'Phone Export downloads the format 4 envelope');
  GPage.Execute('phanesEditorActions.generate("land-lower",null,' +
    '{landformAmount:1000,editLayer:"terrain"})');
  Settled;
  LScene := ImportText(LExport);
  WaitForPublishedImport(LScene);
  Check(GPage.Text('(()=>{const w=JSON.parse(JSON.stringify(phanesEditor.world));' +
    'delete w.solveMilliseconds;return JSON.stringify(w)})()') = LSemantics,
    'Phone file-input import restores exact format 4 terrain and world semantics');
  GPage.Screenshot(GOutput + '/phone-imported.png');
end;

begin
  Require(ParamCount >= 3, 'Usage: world-file-checks BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  GDownloads := StringReplace(ExpandFileName(GOutput + '/downloads'), '/',
    PathDelim, [rfReplaceAll]);
  ForceDirectories(GDownloads);
  GEvidence := TJSONObject.Create;
  GChecks := TJSONArray.Create;
  GEvidence.Add('checks', GChecks);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    EnableDownloads(GOutput + '/profile');
    InstallLandformProbe;
    InstallDownloadProbe;
    try
      RunJourney;
      GEvidence.Add('passed', True);
    except
      on LException: Exception do
      begin
        GEvidence.Add('passed', False);
        GEvidence.Add('failure', LException.Message);
        WriteText(GOutput + '/failure.txt', UTF8String(LException.Message));
        WriteText(GOutput + '/download-probe.json', UTF8String(GPage.Text(
          'JSON.stringify(window.phanesWorldFileDownloadProbe||null)')));
        GPage.Screenshot(GOutput + '/failure.png');
        try
          CaptureDownloadManager;
        except
          on LDiagnostic: Exception do
          begin
            WriteText(GOutput + '/download-manager-failure.txt',
              UTF8String(LDiagnostic.Message));
          end;
        end;
        raise;
      end;
    end;
  finally
    WriteText(GOutput + '/evidence.json', UTF8String(GEvidence.FormatJSON));
    GDownloadClient.Free;
    GPage.Free;
    GEvidence.Free;
  end;
end.
