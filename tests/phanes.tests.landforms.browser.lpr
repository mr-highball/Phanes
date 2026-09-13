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

program PhanesLandformBrowserChecks;
{$mode delphi}
{$H+}
uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;
var
  GPage: TBrowserProbe;
  GOutput: String;
  GBefore: String;
  GAfter: String;
  GHistory: String;
  GFuture: String;
  GSelection: String;
  GProbe: UTF8String;
  GCamera: String;
  GReport: TJSONData;
  I: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

function Quoted(const AValue: String): String;
var
  LValue: TJSONString;
begin
  LValue := TJSONString.Create(AValue);
  try
    Result := LValue.AsJSON;
  finally
    LValue.Free;
  end;
end;

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

procedure Stroke(const ALasso: Boolean);
var
  LLeft: Double;
  LRight: Double;
  LTop: Double;
  LBottom: Double;
begin
  LLeft := 0.36;
  LRight := 0.65;
  LTop := 0.45;
  LBottom := 0.65;
  if GCamera = 'orbit' then
  begin
    LLeft := 0.42;
    LRight := 0.58;
    LTop := 0.46;
    LBottom := 0.53;
  end;
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(LLeft, LTop)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(LRight, LTop)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(LRight, LBottom)]));
  if ALasso then
  begin
    GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(LLeft, LBottom)]));
  end;
  GPage.Touch('touchEnd', TJSONArray.Create);
  GPage.WaitFor('!phanesAuthoringBusy', 15000);
end;

procedure Settled;
begin
  GPage.WaitFor('!phanesEditor.worker');
  GPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
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
    Quoted(LExpected), 5000);
end;

procedure ValidateEdit(const AOperation: String; const AAmount: Integer);
begin
  GReport := GPage.Evaluate('phanesLandformCheck(' + Quoted(GBefore) + ',' +
    Quoted(GSelection) + ',' + Quoted(AOperation) + ',' + IntToStr(AAmount) + ')');
  try
    WriteText(GOutput + '/' + AOperation + '-admission.json', GReport.AsJSON);
    Check(TJSONObject(GReport).Booleans['accepted'],
      AOperation + ' preserves selection boundaries, occupied support and plant admission: ' +
      TJSONObject(GReport).Strings['reason']);
    Check(TJSONObject(GReport).Booleans['roundTrip'], AOperation + ' survives world wire round trip');
  finally
    GReport.Free;
  end;
end;

procedure SampleFrames(const AName: String);
begin
  GPage.Execute('phanesLandformStartFrames()');
  Sleep(3000);
  GPage.Execute('window.phanesLandformFrameMetrics=phanesLandformEndFrames()');
  WriteText(GOutput + '/' + AName + '-metrics.json',
    GPage.Text('JSON.stringify(phanesLandformFrameMetrics)'));
  Check((GPage.Number('phanesLandformFrameMetrics.renderedFrames') > 10) and
    (GPage.Number('phanesLandformFrameMetrics.drawCallsDuringSample') > 10),
    AName + ' continues rendering during the measured interval');
  Check(GPage.Number('phanesLandformFrameMetrics.errors.length') = 0,
    AName + ' has no recorded browser errors');
end;

procedure InstallProbe(const AName: String);
begin
  GProbe := UTF8String(ReadText('build/phanes.tests.' + AName + '.probe.js'));
  if (Length(GProbe) >= 3) and (Ord(GProbe[1]) = $EF) and
    (Ord(GProbe[2]) = $BB) and (Ord(GProbe[3]) = $BF) then
  begin
    Delete(GProbe, 1, 3);
  end;
  GPage.InstallScript('(()=>{' + String(GProbe) + #10 + 'rtl.run();})();');
end;

begin
  Require(ParamCount >= 3, 'Usage: landform-checks BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
      InstallProbe('styles');
      InstallProbe('landforms');
      GPage.Resize(390, 844, 2);
      GPage.Navigate(ParamStr(2));
      GPage.WaitFor('document.body?.dataset.startupState==="ready"');
      GPage.SetValue('region-size', '4');
      GPage.Click('#create-world');
      GPage.WaitFor('document.body.dataset.renderedRevision==="1"');
      Check(GPage.Number('phanesEditor.world.formatVersion') = 3,
        'Create this world produces a saved absolute WFC height field');
      Check(GPage.Number('phanesEditor.world.elevation.levels.length') = 81,
        'Smallest world has its complete shared-vertex grid');
      GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
        'phanesEditorActions.syncSelection();phanesEditorActions.generate("clear",null,{editLayer:""})');
      Settled;
      GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
      GPage.Click('#open-landforms');
      Check(GPage.Text('document.body.dataset.landforms') = 'true',
        'Shape the land opens the dedicated authoring controls');
      GPage.Click('[data-authoring-tool="box"]');
      ShowTools(False);
      Stroke(False);
      Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
        'Touch Box selects terrain with the tools panel collapsed');
      GSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
      ShowTools(True);
      GPage.SetValue('landform-amount', '1000', 'change');
      GPage.Click('[data-landform="land-raise"]');
      Settled;
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') <> GBefore,
        'Raise changes the selected land');
      ValidateEdit('land-raise', 1000);
      GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
      GPage.Click('#landform-undo');
      Settled;
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GBefore,
        'Terrain Undo restores the exact world');
      GPage.Click('#landform-redo');
      Settled;
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GAfter,
        'Terrain Redo restores the exact shaped world');
      GBefore := GAfter;
      GPage.Click('[data-landform="land-lower"]');
      Settled;
      ValidateEdit('land-lower', 1000);
      GPage.Click('[data-camera="orbit"]');
      GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
      GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
      for I := 0 to 3 do
      begin
        case I of
          0: GCamera := 'top';
          1: GCamera := 'orbit';
          2: GCamera := 'fly';
          else GCamera := 'walk';
        end;
        GPage.Click('[data-camera="' + GCamera + '"]');
        if I = 1 then
        begin
          GPage.Execute('Object.assign(phanesEditor,{zoom:2,pitch:0.35});' +
            'phanesEditorActions.syncCamera()');
        end;
        if I >= 2 then
        begin
          GPage.Execute('Object.assign(phanesEditor,{x:0,y:12,z:8,yaw:0,pitch:-0.6});' +
            'phanesEditorActions.syncCamera()');
        end;
        GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        ShowTools(True);
        GPage.Click('#selection-clear');
        GPage.Click('[data-authoring-tool="brush"]');
        GPage.WaitFor('document.querySelector(''[data-authoring-tool="brush"]'').getAttribute("aria-pressed")==="true"', 5000);
        ShowTools(False);
        Stroke(False);
        Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
          'Touch Brush marks WFC land in ' + GCamera);
        GPage.Hold('[data-authoring-tool="lasso"]', 80);
        GPage.WaitFor('document.querySelector(''[data-authoring-tool="lasso"]'').getAttribute("aria-pressed")==="true"', 5000);
        Stroke(True);
        Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
          'Touch Lasso marks WFC land in ' + GCamera);
        Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GAfter,
          'Selection gestures in ' + GCamera + ' preserve the exact world');
        ShowTools(True);
      end;
      GCamera := 'top';
      GPage.Click('[data-camera="top"]');
      GPage.Execute('Object.assign(phanesEditor,{zoom:1,pitch:0});phanesEditorActions.syncCamera()');
      GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
      GPage.SetValue('selection-scale', '2', 'change');
      Check(GPage.Text('document.getElementById("selection-layer").value') = 'terrain',
        'Fine landform selection retains terrain scope');
      GPage.Click('[data-authoring-tool="lasso"]');
      ShowTools(False);
      Stroke(True);
      ShowTools(True);
      GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
      GSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
      GPage.Click('[data-landform="land-hills"]');
      Settled;
      ValidateEdit('land-hills', 1000);
      { A legacy fixture uses the normal restore request and independently
        admitted empty landscape. Its first height edit must migrate only the
        selected surface, and a later no-op must keep the Redo branch. }
      GPage.Execute('window.phanesLegacyFixture=JSON.parse(JSON.stringify(phanesEditor.world));' +
        'delete phanesLegacyFixture.elevation;phanesLegacyFixture.formatVersion=2;' +
        'phanesEditorActions.generate("restore",phanesLegacyFixture,{})');
      Settled;
      GPage.Execute('phanesEditor.selection=' + GSelection + ';phanesEditorActions.syncSelection()');
      GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
      GSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
      GPage.Click('[data-landform="land-raise"]');
      Settled;
      Check(GPage.Number('phanesEditor.world.formatVersion') = 4,
        'First legacy height edit saves explicit additive interpretation');
      ValidateEdit('land-raise', 1000);
      GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
      GPage.Click('#landform-undo');
      Settled;
      GHistory := GPage.Text('JSON.stringify(phanesEditor.history)');
      GFuture := GPage.Text('JSON.stringify(phanesEditor.future)');
      GPage.Click('[data-landform="land-soften"]');
      Settled;
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GBefore,
        'Soften with no legacy height edits leaves the original world exact');
      Check((GPage.Text('JSON.stringify(phanesEditor.history)') = GHistory) and
        (GPage.Text('JSON.stringify(phanesEditor.future)') = GFuture),
        'Unchanged Soften preserves both Undo and Redo branches');
      GPage.Click('#landform-redo');
      Settled;
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GAfter,
        'Redo still restores the additive edit after an unchanged request');
      GPage.Execute('window.phanesLandformSessionResults=phanesLandformSessionChecks()');
      WriteText(GOutput + '/session-validation.json',
        GPage.Text('JSON.stringify(phanesLandformSessionResults)'));
      Check(GPage.Text('phanesLandformSessionResults.length===8 && ' +
        'phanesLandformSessionResults.every(x=>x.passed)') = 'true',
        'Saved landform controls reject malformed and contradictory contexts');
      GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
      GHistory := GPage.Text('JSON.stringify(phanesEditor.history)');
      GFuture := GPage.Text('JSON.stringify(phanesEditor.future)');
      GPage.Execute('window.phanesLandformSaved=window.phanesSessionSavingRevision||0;' +
        'window.dispatchEvent(new Event("pagehide"))');
      GPage.WaitFor('window.phanesSessionSavedRevision>window.phanesLandformSaved');
      GPage.Execute('phanesStyleProbeLoseContext()');
      GPage.WaitFor('document.body?.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
      Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GAfter,
        'Graphics recovery preserves exact landform heights');
      Check(GPage.Text('JSON.stringify(phanesEditor.history)') = GHistory,
        'Graphics recovery preserves terrain Undo history');
      Check(GPage.Text('JSON.stringify(phanesEditor.future)') = GFuture,
        'Graphics recovery preserves terrain Redo history');
      Check(GPage.Text('JSON.stringify(phanesEditor.selection)') = GSelection,
        'Graphics recovery preserves the fine landform mask');
      Check(GPage.Text('document.body.dataset.landforms') = 'true',
        'Graphics recovery reopens the landform tools');
      { Chromium surface capture interferes with later emulated touch clicks.
        Keep touch acceptance ahead of capture; default surface capture retains
        the actual phone viewport and DPR, unlike fromSurface:false. }
      GPage.Screenshot(GOutput + '/recovered-landforms-phone.png');
      SampleFrames('phone-recovered');
      GPage.Resize(1280, 900);
      GPage.Click('[data-camera="orbit"]');
      GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
      GPage.Screenshot(GOutput + '/shaped-land-desktop.png');
      SampleFrames('desktop-shaped');
    except
      on LException: Exception do
      begin
        WriteText(GOutput + '/failure.txt', LException.Message + #10 + GPage.Text('document.body.innerText'));
        WriteText(GOutput + '/events.json', GPage.Text('JSON.stringify(phanesLandformEvents)'));
        GPage.Screenshot(GOutput + '/failure.png');
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
