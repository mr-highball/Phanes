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

program PhanesRecoveryCriticBrowser;

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
  GEvidence: TJSONObject;
  GChecks: TJSONArray;
  GDownloadClient: TWfcBrowserCDP;
  GPhone: Boolean;
  GHouse: Boolean;

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

procedure EnableDownloads(const AProfile: String);
var
  LLines: TStringList;
  LParameters: TJSONObject;
  LReply: TJSONObject;
  LPort: Integer;
  LPath: String;
begin
  { Browser download policy is scoped to the fresh browser owned by this
    fixture. The second CDP connection remains owned by this driver until all
    downloads finish, without changing the shared browser helper. }
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
  LDeadline := WfcBrowserTickCount64 + 30000;
  while not FileExists(LPath) do
  begin
    if WfcBrowserTickCount64 >= LDeadline then
    begin
      { Preserve Chromium's own state when a download assertion fails. This
        diagnostic navigation occurs only after the test has already failed. }
      try
        GPage.Navigate('chrome://downloads/');
        GPage.WaitFor('document.querySelector("downloads-manager")!==null', 10000);
        WriteText(GOutput + '/chromium-download-state.json', UTF8String(GPage.Text(
          'JSON.stringify(document.querySelector("downloads-manager").items_,' +
          '(key,value)=>typeof value==="bigint"?value.toString():value)')));
      except
        on Exception do
        begin
          { Diagnostic browser failure must not replace the download failure. }
        end;
      end;
      raise Exception.Create('The actual browser download did not finish: ' + AName);
    end;
    Sleep(50);
  end;
  Require(not FileExists(LPath + '.crdownload'), 'Download is still incomplete');
  Result := String(ReadText(LPath));
  GEvidence.Add('download', TJSONObject.Create(['name', AName,
    'bytes', FileByteCount(LPath), 'sha256', HashFile(LPath)]));
end;

function ReadStored: String;
begin
  Result := GPage.Text('phanesRecoveryCritic.readStored()');
  Require((Result <> '') and (Result <> 'null'), 'Missing actual recovery record');
end;

procedure PrepareHouse;
var
  LWalkZ: Double;
begin
  { Use real worker transactions and the existing controller bridge to prepare
    a rotated support. This is not a test of catalog discovery. }
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("clear",null,{editLayer:""})');
  GPage.WaitFor('!phanesEditor.worker && phanesEditor.world.layers[0].every(v=>v==="meadow") && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:2,depth:2};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("foundation",null,{groundworkTurn:1})');
  GPage.WaitFor('!phanesEditor.worker && phanesEditor.world.composition.nodes.some(n=>n.role==="plot") && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.Execute('window.phanesCriticPlot=phanesEditor.world.composition.nodes.find(n=>n.role==="plot").id;' +
    'phanesEditorActions.generate("place-building",null,{objectId:phanesCriticPlot,' +
    'buildingAsset:"city-kit-suburban/building-type-a"})');
  GPage.WaitFor('!phanesEditor.worker && phanesEditor.world.composition.nodes.some(n=>n.role==="building") && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.Execute('phanesGroundworkUI.restoreCheckpoint({active:true,plot:phanesCriticPlot,' +
    'selected:phanesCriticPlot+".deck",body:"plinth",turn:1})');
  if GPage.Text('document.body.classList.contains("tools-collapsed")') = 'true' then
  begin
    GPage.Click('#tools-toggle');
  end;
  GPage.Execute('document.getElementById("mobile-save-world").scrollIntoView({block:"nearest"})');
  Check(GPage.Text('(()=>{const b=document.getElementById("mobile-save-world");' +
    'const r=b.getBoundingClientRect();return !b.disabled && r.width>=44 && r.height>=44 && ' +
    'r.x>=0 && r.right<=innerWidth && r.y>=0 && r.bottom<=innerHeight && ' +
    'b.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})()') = 'true',
    'The common phone Export is reachable in actual groundwork context');
  GPage.Screenshot(GOutput + '/groundwork-export.png');
  GPage.Execute('(()=>{const ns=phanesEditor.world.composition.nodes;' +
    'const r=ns.find(n=>n.id===phanesCriticPlot);const d=ns.find(n=>n.id===phanesCriticPlot+".deck");' +
    'Object.assign(phanesEditor,{x:r.x/1000+7.4,y:(r.y+d.y)/1000+1.68,z:r.z/1000,' +
    'yaw:1.5707963267948966,pitch:0});phanesEditorActions.setCamera("fly")})()');
  GPage.Click('#edit-toggle');
  GPage.WaitFor('!document.getElementById("enter-nearby").hidden');
  GPage.Click('#enter-nearby');
  GPage.WaitFor('phanesEditor.interiorRoom.endsWith(".deck.building.studio") && !phanesEditor.worker && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.Click('#edit-toggle');
  Check(GPage.Text('phanesEditor.editing && phanesEditor.camera==="walk" && ' +
    'phanesEditor.world.composition.nodes.some(n=>n.role==="ornament")') = 'true',
    'The fixture enters a furnished imported house and keeps its walk context');
  GPage.Click('[data-camera="fly"]');
  GPage.Hold('[data-move="w"]', 2000);
  Check(GPage.Text('Math.abs(phanesEditor.x)>=4.4 || Math.abs(phanesEditor.z)>=3.9') = 'true',
    'Actual touch flight moves outside the imported room footprint');
  GEvidence.Add('houseOutsidePose', GetJSON(GPage.Text('JSON.stringify([phanesEditor.camera,' +
    'phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])'), True));
  GPage.Click('[data-camera="walk"]');
  GPage.WaitFor('phanesEditor.camera==="walk" && Math.abs(phanesEditor.x)<4.02 && ' +
    'Math.abs(phanesEditor.z)<3.52 && phanesRenderedCameraVersion===phanesCameraVersion');
  Check(GPage.Text('Math.abs(phanesEditor.x)<4.02 && Math.abs(phanesEditor.z)<3.52') = 'true',
    'Returning to First person finds standing space inside the smaller house');
  GEvidence.Add('houseFallbackPose', GetJSON(GPage.Text('JSON.stringify([phanesEditor.camera,' +
    'phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])'), True));
  LWalkZ := GPage.Number('phanesEditor.z');
  GPage.Hold('[data-move="w"]', 400);
  Check(GPage.Number('phanesEditor.z') < LWalkZ - 0.05,
    'The returned house position supports actual forward walking');
  GPage.Screenshot(GOutput + '/house-returned-to-walk.png');
  GPage.Execute('window.phanesCriticBeforeSave=phanesSessionSavedRevision;' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('phanesSessionSaved===true && phanesSessionSavedRevision>phanesCriticBeforeSave');
end;

procedure CreateBaseline;
var
  LStored: String;
  LRecord: TJSONObject;
begin
  GPage.WaitFor('document.body.dataset.startupState==="ready"');
  GPage.SetValue('region-size', '4');
  GPage.Click('#create-world');
  GPage.WaitFor('phanesEditor.world && !phanesEditor.worker && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.WaitFor('window.phanesSessionSaved===true && ' +
    'window.phanesSessionSavedRevision===window.phanesSessionSavingRevision');
  if GHouse then
  begin
    PrepareHouse;
  end;
  LStored := ReadStored;
  LRecord := TJSONObject(GetJSON(LStored, True));
  try
    Check(LRecord.Objects['world'].AsJSON =
      NormalJSON(GPage.Text('JSON.stringify(phanesEditor.world)')),
      'Baseline exists in actual IndexedDB with the complete live world');
  finally
    LRecord.Free;
  end;
  WriteText(GOutput + '/baseline.json', UTF8String(LStored));
  Check(GPage.Text('phanesRecoveryCritic.errors.length===0') = 'true',
    'Baseline startup has no captured window error');
end;

procedure StorageCase(const ACase: String);
var
  LBaseline: String;
  LLive: String;
  LHistory: String;
  LStored: String;
  LDownloaded: String;
  LFilename: String;
  LSavedRevision: Double;
  LInterior: String;
  LCamera: String;
  LCameraAfterEdit: String;
  LCameraBeforeExport: String;
  LCameraAfterExport: String;
  LEnvelope: TJSONObject;
  LRecord: TJSONObject;
begin
  LBaseline := ReadStored;
  LSavedRevision := GPage.Number('phanesSessionSavedRevision');
  GPage.Execute('phanesRecoveryCritic.arm(' + Quote(ACase) + ')');
  if GHouse then
  begin
    GPage.Execute('phanesInteriorUI.choose(phanesEditor.world.composition.nodes.find(' +
      'n=>n.role==="ornament").id,false)');
    LInterior := GPage.Text('JSON.stringify(phanesInteriorUI.snapshot())');
    LCamera := GPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,phanesEditor.y,' +
      'phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
    GEvidence.Add('cameraBeforeEdit', GetJSON(LCamera, True));
    GPage.Click('#interior-reimagine');
  end
  else
  begin
    { A non-cabin cell makes the requested cabin edit observably different. The
      normal current worker and normal publication path produce the new world. }
    GPage.Execute('(()=>{const s=phanesEditor;' +
      'const i=s.world.layers[3].findIndex(v=>v!=="cabin");' +
      'if(i<0)throw new Error("No distinct fixture cell");' +
      's.selection={x:i%s.world.size,z:Math.floor(i/s.world.size),width:1,depth:1};' +
      'phanesEditorActions.syncSelection();phanesEditorActions.generate("cabin");})()');
  end;
  GPage.WaitFor('!phanesEditor.worker && document.body.dataset.recoverySave==="failed"');
  GPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  if GHouse then
  begin
    GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
    LCameraAfterEdit := GPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,' +
      'phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
    GEvidence.Add('cameraAfterEdit', GetJSON(LCameraAfterEdit, True));
  end;
  LLive := GPage.Text('JSON.stringify(phanesEditor.world)');
  LHistory := GPage.Text('JSON.stringify([phanesEditor.history,phanesEditor.future])');
  LRecord := TJSONObject(GetJSON(LBaseline, True));
  try
    Check(LRecord.Objects['world'].AsJSON <> NormalJSON(LLive),
      'A real worker edit produced a distinct live world before the save failed');
  finally
    LRecord.Free;
  end;
  if ACase = 'put-throw' then
  begin
    Check(GPage.Number('phanesRecoveryCritic.stats.putThrows') >= 1,
      'The native recovery store put boundary received the synchronous fault');
  end
  else
  begin
    Check((GPage.Number('phanesRecoveryCritic.stats.successfulPutsBeforeAbort') >= 1) and
      (GPage.Number('phanesRecoveryCritic.stats.transactionAborts') >= 1),
      'A successful native put request was followed by transaction abort');
  end;
  Check(GPage.Number('phanesSessionSavedRevision') = LSavedRevision,
    'Failed write does not advance the committed save revision');
  Check(GPage.Text('window.phanesSessionSaved===false') = 'true',
    'Failed current state is not advertised as saved');
  LStored := ReadStored;
  Check(NormalJSON(LStored) = NormalJSON(LBaseline),
    'The complete previous database checkpoint survives the failed write');
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LLive,
    'Reading failure evidence leaves the complete new live world unchanged');
  Check(GPage.Text('JSON.stringify([phanesEditor.history,phanesEditor.future])') = LHistory,
    'Storage failure leaves both live history stacks unchanged');
  Check(GPage.Text('document.getElementById("toast").textContent.includes("Recovery storage")') =
    'true', 'Save failure provides visible recovery-storage feedback');
  GPage.Screenshot(GOutput + '/save-failed.png');
  if GHouse then
  begin
    LCameraBeforeExport := GPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,' +
      'phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
    GEvidence.Add('cameraBeforeExport', GetJSON(LCameraBeforeExport, True));
  end;
  LFilename := 'phanes-' + GPage.Text('phanesEditor.world.seed') + '.json';
  if GPhone then
  begin
    if GPage.Text('document.body.classList.contains("tools-collapsed")') = 'true' then
    begin
      GPage.Click('#tools-toggle');
    end;
    GPage.Click('#mobile-save-world');
    Check(GPage.Text('(()=>{const r=document.getElementById("mobile-save-world")' +
      '.getBoundingClientRect();return r.width>=44 && r.height>=44 && r.x>=0 && ' +
      'r.right<=innerWidth && r.y>=0 && r.bottom<=innerHeight})()') = 'true',
      'Phone Export is a visible hit-tested touch target inside the viewport');
  end
  else
  begin
    GPage.Click('#save-world');
  end;
  Check(GPage.Number('phanesRecoveryCritic.stats.downloadsIssued.length') = 1,
    'The real Export action issues its native download link');
  LDownloaded := Download(LFilename);
  LEnvelope := TJSONObject(GetJSON(LDownloaded, True));
  try
    Check(LEnvelope.Objects['world'].AsJSON = NormalJSON(LLive),
      'Actual Export downloads the new live world rather than the old checkpoint');
  finally
    LEnvelope.Free;
  end;
  Check(GPage.Text('phanesRecoveryCritic.validateExport(' + Quote(LDownloaded) + ')') = 'true',
    'The actual downloaded world passes current whole-session world admission');
  Check(NormalJSON(ReadStored) = NormalJSON(LBaseline),
    'Export does not overwrite the retained prior checkpoint');
  if GHouse then
  begin
    LCameraAfterExport := GPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,' +
      'phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
    GEvidence.Add('cameraAfterExport', GetJSON(LCameraAfterExport, True));
    Check(GPage.Text('JSON.stringify(phanesInteriorUI.snapshot())') = LInterior,
      'Saving and actual Export retain the active house and selected nested object');
    Check(LCameraAfterEdit = LCamera,
      'The content edit and failed save preserve the exact indoor camera');
    Check(LCameraBeforeExport = LCameraAfterEdit,
      'The settled edit camera remains exact before Export');
    Check(LCameraAfterExport = LCameraBeforeExport,
      'Actual Export preserves the exact indoor camera without leaving');
  end;
  GPage.Execute('phanesRecoveryCritic.arm("");' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSaved===true && ' +
    'phanesSessionSavedRevision>' + FloatToStr(LSavedRevision));
  LStored := ReadStored;
  LRecord := TJSONObject(GetJSON(LStored, True));
  try
    Check(LRecord.Objects['world'].AsJSON = NormalJSON(LLive),
      'After removing the fault, a real save commits the new world');
  finally
    LRecord.Free;
  end;
  Check(GPage.Text('document.body.dataset.recoverySave') = 'saved',
    'A successful retry clears the failure state');
  Check(GPage.Text('phanesRecoveryCritic.errors.length===0') = 'true',
    'Both failed and successful transaction paths avoid uncaught errors');
  WriteText(GOutput + '/committed-after-retry.json', UTF8String(LStored));
end;

procedure LateCase(const AKind: String);
var
  LBaseline: String;
  LMessage: String;
  LState: String;
  LDownloaded: String;
  LTerminations: Double;
begin
  LBaseline := ReadStored;
  GPage.Execute('phanesRecoveryCritic.prepareRestoreTimeout();location.reload()');
  GPage.WaitFor('window.phanesRecoveryCritic && ' +
    'phanesRecoveryCritic.stats.heldRestores===1', 180000);
  Check(GPage.Text('window.phanesRecovering===true && phanesEditor.world===null') = 'true',
    'Ordinary reload holds a real restore before world publication');
  GPage.Execute('phanesRecoveryCritic.expireRestore()');
  GPage.WaitFor('document.body.dataset.rendererState==="failed"');
  GPage.Execute('phanesRecoveryCritic.resetClock()');
  LMessage := GPage.Text('document.getElementById("recovery-message").textContent');
  Check(Pos('longer than expected', LMessage) > 0,
    'The actual controller timeout retains an actionable failed state');
  LTerminations := GPage.Number('phanesRecoveryCritic.stats.heldWorkerTerminations');
  Check(LTerminations = 1, 'Timeout terminates exactly the held restore worker');
  LState := GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future,phanesSceneVersion])');
  GPage.Execute('phanesRecoveryCritic.emitLate(' + Quote(AKind) + ')');
  GPage.WaitFor('phanesRecoveryCritic.stats.lateEvents===1');
  Check(GPage.Text('JSON.stringify([phanesEditor.world,phanesEditor.history,' +
    'phanesEditor.future,phanesSceneVersion])') = LState,
    'Late ' + AKind + ' from the old worker publishes no world or history');
  Check(GPage.Text('document.getElementById("recovery-message").textContent') = LMessage,
    'Late ' + AKind + ' cannot replace the existing timeout explanation');
  Check(GPage.Number('phanesRecoveryCritic.stats.heldWorkerTerminations') = LTerminations,
    'Late ' + AKind + ' does not terminate or dereference a different worker');
  Check(GPage.Text('phanesRecoveryCritic.errors.length===0') = 'true',
    'Late ' + AKind + ' is ignored without an uncaught callback exception');
  Check(NormalJSON(ReadStored) = NormalJSON(LBaseline),
    'Timed-out restore and its late event retain the original database record');
  GPage.Click('#recovery-export');
  LDownloaded := Download('phanes-recovery.json');
  Check(NormalJSON(LDownloaded) = NormalJSON(LBaseline),
    'Actual recovery-data download preserves the complete unmodified checkpoint');
  GPage.Screenshot(GOutput + '/late-event-retained.png');
end;

procedure Run;
var
  LProfile: String;
  LProbe: UTF8String;
  LCase: String;
  LGuid: TGuid;
begin
  Require(ParamCount = 5,
    'Usage: recovery-critic BROWSER URL EVIDENCE COMPILED-PROBE CASE' +
    ' (put-throw|put-throw-phone|put-throw-house-phone|abort|late-error|late-success|download-control)');
  LCase := ParamStr(5);
  Require((LCase = 'put-throw') or (LCase = 'abort') or
    (LCase = 'late-error') or (LCase = 'late-success') or
    (LCase = 'put-throw-phone') or (LCase = 'put-throw-house-phone') or
    (LCase = 'download-control'),
    'Unknown recovery critic case');
  GHouse := LCase = 'put-throw-house-phone';
  GPhone := (LCase = 'put-throw-phone') or GHouse;
  GOutput := ExpandFileName(ParamStr(3));
  Require(not DirectoryExists(GOutput), 'Use a fresh evidence directory for each critic run');
  ForceDirectories(GOutput);
  GDownloads := ExpandFileName(GOutput + '/downloads');
  ForceDirectories(GDownloads);
  CreateGUID(LGuid);
  LProfile := GOutput + '/profile-' + GUIDToString(LGuid);
  GEvidence := TJSONObject.Create(['case', LCase, 'url', ParamStr(2),
    'downloadDirectory', GDownloads,
    'probeSha256', HashFile(ParamStr(4)),
    'driverBinarySha256', HashFile(ParamStr(0)),
    'method', 'Pascal WFC CDP, real IndexedDB and native browser downloads']);
  GChecks := TJSONArray.Create;
  GEvidence.Add('checks', GChecks);
  GPage := TBrowserProbe.Create(ParamStr(1), LProfile);
  try
    try
      EnableDownloads(LProfile);
      LProbe := ReadText(ParamStr(4));
      if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
        (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
      begin
        Delete(LProbe, 1, 3);
      end;
      GPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
      if GPhone then
      begin
        GPage.Resize(390, 844, 3);
      end
      else
      begin
        GPage.Resize(1280, 900);
      end;
      if LCase = 'download-control' then
      begin
        GPage.Execute('phanesRecoveryCritic.makeDownloadControl()');
        GPage.Click('#critic-download-control');
        Check(NormalJSON(Download('critic-control.json')) = NormalJSON('{"control":true}'),
          'An independent native Blob download reaches the configured fixture directory');
        GEvidence.Add('success', True);
        Exit;
      end;
      GPage.Navigate(ParamStr(2));
      CreateBaseline;
      if GPhone then
      begin
        StorageCase('put-throw');
      end
      else if (LCase = 'put-throw') or (LCase = 'abort') then
      begin
        StorageCase(LCase);
      end
      else
      begin
        LateCase(Copy(LCase, 6, MaxInt));
      end;
      GEvidence.Add('stats', GetJSON(GPage.Text('JSON.stringify(phanesRecoveryCritic.stats)'), True));
      GEvidence.Add('success', True);
    except
      on LException: Exception do
      begin
        GEvidence.Add('success', False);
        GEvidence.Add('failure', LException.Message);
        try
          GEvidence.Add('faultStats', GetJSON(GPage.Text(
            'JSON.stringify(phanesRecoveryCritic.stats)'), True));
          GEvidence.Add('windowErrors', GetJSON(GPage.Text(
            'JSON.stringify(phanesRecoveryCritic.errors)'), True));
          GPage.Screenshot(GOutput + '/failure.png');
          WriteText(GOutput + '/failure-state.txt', UTF8String(GPage.Text('document.body.innerText')));
        except
          on Exception do
          begin
            { Keep the original failure if a crashed page cannot be captured. }
          end;
        end;
        raise;
      end;
    end;
  finally
    WriteText(GOutput + '/evidence.json', GEvidence.FormatJSON);
    GDownloadClient.Free;
    GPage.Free;
    GEvidence.Free;
  end;
end;

begin
  Run;
end.
