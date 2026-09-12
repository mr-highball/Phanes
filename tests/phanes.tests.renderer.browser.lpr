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

program PhanesRendererBrowserChecks;
{$mode delphi}
{$H+}
uses
  SysUtils, Math, FPJSON, phanes.tools.browser, phanes.tools.files;
var
  LPage: TBrowserProbe;
  LOutput: String;
  LWorld: String;
  LHistory: String;
  LSelection: String;
  LReturn: String;
  LProbe: UTF8String;
  LFrames: Double;
  LFuture: String;
  LSelected: String;
  LHouse: Integer;
  LAsset: String;
  LContext: String;
  LView: Integer;
  LAngle: Double;
  LProfile: TJSONObject;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Require(AValue, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

procedure CheckEntryPreserved(const APhase: String);
begin
  Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
    APhase + ': exact exterior world retained');
  Check(LPage.Text('JSON.stringify(phanesEditor.history)') = LHistory,
    APhase + ': complete Undo stack retained');
  Check(LPage.Text('JSON.stringify(phanesEditor.future)') = LFuture,
    APhase + ': complete Redo stack retained');
  Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
    APhase + ': original nonrectangular authoring mask retained');
  Check(LPage.Text('phanesEditor.interiorRoom') = '',
    APhase + ': delayed room did not open');
end;

procedure SurfaceSweep;
const
  CModes: array[0..6] of String = ('top', 'orbit', 'fly', 'walk', 'fly', 'fly', 'fly');
var
  LLayout: Integer;
  LStyle: Integer;
  LViewIndex: Integer;
  LLabel: String;
  LStyleId: String;
  LPose: String;
  LPrefix: String;
  LQuality: String;

  procedure Capture(const AName: String);
  begin
    LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion && ' +
      'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
    LPage.Execute('phanesStyleProbeResetFrames()');
    LPage.WaitFor('phanesStyleProbeSnapshot().frameIntervals.length>=3');
    LPage.Screenshot(LOutput + '/' + AName + '.png');
    WriteText(LOutput + '/' + AName + '.json', LPage.Text('JSON.stringify({' +
      'camera:JSON.parse(phanesCamera),style:phanesStyleId,' +
      'quality:document.getElementById("render-quality").value,' +
      'dpr:devicePixelRatio,css:[document.getElementById("castle-canvas").clientWidth,' +
      'document.getElementById("castle-canvas").clientHeight],' +
      'buffer:[document.getElementById("castle-canvas").width,' +
      'document.getElementById("castle-canvas").height]})'));
  end;

begin
  LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("clear",null,{editLayer:""})');
  LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("cabin")');
  LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Execute('Object.assign(phanesEditor,{x:-8,y:4,z:-1.5,yaw:0,pitch:0});' +
    'phanesEditorActions.setCamera("walk")');
  LPage.Click('#edit-toggle');
  LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
  LPage.Click('#enter-nearby');
  LPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio" && !phanesEditor.worker');
  LPage.SetValue('render-quality', 'detail', 'change');
  Capture('entry-phone');
  LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
  LHistory := LPage.Text('JSON.stringify(phanesEditor.history)');
  WriteText(LOutput + '/world.json', LWorld);
  for LLayout := 0 to 2 do
  begin
    case LLayout of
      0: begin
        LLabel := 'desktop';
        LPage.Resize(1280, 900, 1);
      end;
      1: begin
        LLabel := 'phone';
        LPage.Resize(390, 844, 2);
      end;
      2: begin
        LLabel := 'landscape';
        LPage.Resize(844, 390, 2);
      end;
    end;
    for LStyle := 0 to 1 do
    begin
      LStyleId := 'none';
      if LStyle = 1 then
      begin
        LStyleId := 'toon';
      end;
      LPage.Click('#open-styles');
      LPage.Click('#style-choice-' + LStyleId);
      LPage.Click('#close-styles');
      LPage.WaitFor('phanesStyleId==="' + LStyleId + '"');
      for LViewIndex := 0 to High(CModes) do
      begin
        case LViewIndex of
          0: LPose := '{panX:0,panY:0.8,panZ:0,zoom:1.2,yaw:0,pitch:0}';
          1: LPose := '{panX:0,panY:0.8,panZ:0,zoom:1.5,yaw:-0.4,pitch:0}';
          2: LPose := '{x:0,y:1.9,z:3.8,yaw:0,pitch:-0.15}';
          3: LPose := '{x:0,y:1.68,z:3.8,yaw:0,pitch:-0.12}';
          4: LPose := '{x:0,y:0.22,z:3.8,yaw:0,pitch:-0.025}';
          5: LPose := '{x:-3.9,y:1.15,z:3.2,yaw:0.55,pitch:-0.08}';
          6: LPose := '{x:3.9,y:1.15,z:3.2,yaw:-0.55,pitch:-0.08}';
        end;
        LPage.Execute('Object.assign(phanesEditor,' + LPose + ');' +
          'phanesEditorActions.setCamera("' + CModes[LViewIndex] + '")');
        LPrefix := LLabel + '-' + LStyleId + '-' + IntToStr(LViewIndex) + '-' + CModes[LViewIndex];
        Capture(LPrefix);
        Check(LPage.Text('phanesStyleId') = LStyleId, LPrefix + ': requested style remains active');
      end;
    end;
    Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
      LLabel + ': view/style sweep preserves the exact world');
  end;
  Check(LPage.Text('JSON.stringify(phanesEditor.history)') = LHistory,
    'View/style sweep preserves edit history');
  LPage.Resize(390, 844, 2);
  LPage.Execute('Object.assign(phanesEditor,{x:0,y:1.68,z:3.8,yaw:0,pitch:-0.12});' +
    'phanesEditorActions.setCamera("walk")');
  LPage.Click('#open-styles');
  LPage.Click('#style-choice-none');
  LPage.Click('#close-styles');
  for LViewIndex := 0 to 2 do
  begin
    case LViewIndex of
      0: LQuality := 'balanced';
      1: LQuality := 'smooth';
      2: LQuality := 'detail';
    end;
    LPage.SetValue('render-quality', LQuality, 'change');
    Capture('phone-none-quality-' + LQuality);
    Check(LPage.Number('document.getElementById("castle-canvas").width') >= 390,
      LQuality + ': phone buffer retains at least CSS-pixel resolution');
  end;
  LPage.Click('#open-styles');
  LPage.Click('#style-choice-toon');
  LPage.Click('#close-styles');
  Capture('before-recovery-toon-phone');
  LReturn := LPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,phanesEditor.y,' +
    'phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
  Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Complete surface sweep has no uncaught browser error');
  Check(LPage.Text('phanesStyleProbeSnapshot().shaderFailures.length===0') = 'true',
    'Every material and style shader compiled successfully during the sweep');
  WriteText(LOutput + '/before-recovery-shaders.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot().shaderFailures)'));
  WriteText(LOutput + '/before-recovery-errors.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot().errors)'));
  LPage.Execute('window.phanesSurfaceOriginalPage=true;phanesStyleProbeLoseContext()');
  LPage.WaitFor('!window.phanesSurfaceOriginalPage && ' +
    'document.body.dataset.rendererState==="ready" && !window.phanesRecovering && ' +
    'phanesEditor.interiorRoom==="building-1-1.studio"', 180000);
  Capture('restored-toon-phone');
  Check(LPage.Text('phanesStyleId') = 'toon', 'Recovery restores Toon on the same surfaces');
  Check(LPage.Text('document.getElementById("render-quality").value') = 'detail',
    'Recovery restores full-resolution rendering quality');
  Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
    'Styled graphics recovery preserves the exact world');
  Check(LPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,phanesEditor.y,' +
    'phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])') = LReturn,
    'Styled graphics recovery preserves the exact first-person pose');
  Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Restored surface sweep has no uncaught browser error');
  Check(LPage.Text('phanesStyleProbeSnapshot().shaderFailures.length===0') = 'true',
    'Restored material and style shaders compile successfully');
  WriteText(LOutput + '/final-shaders.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot().shaderFailures)'));
  WriteText(LOutput + '/final-errors.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot().errors)'));
end;

procedure EntryCancellation;
begin
  LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("asset",null,' +
    '{exactAsset:"city-kit-suburban/building-type-a",editLayer:"buildings"})');
  LPage.WaitFor('!phanesEditor.worker && phanesEditor.world.layers[3][5]===' +
    '"city-kit-suburban/building-type-a" && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Execute('phanesEditor.selection={x:2,z:2,width:1,depth:1};' +
    'phanesEditorActions.syncSelection();phanesEditorActions.generate("cabin")');
  LPage.WaitFor('!phanesEditor.worker && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Click('#undo');
  LPage.WaitFor('phanesEditor.future.length>0 && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,selectionScale:1,' +
    'selectionCells:[0,5,10,15]};phanesEditorActions.syncSelection();' +
    'Object.assign(phanesEditor,{x:-8,y:4,z:-0.6,yaw:0,pitch:0});' +
    'phanesEditorActions.setCamera("walk")');
  LPage.Click('#edit-toggle');
  LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
  LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
  LHistory := LPage.Text('JSON.stringify(phanesEditor.history)');
  LFuture := LPage.Text('JSON.stringify(phanesEditor.future)');
  LSelection := LPage.Text('JSON.stringify(phanesEditor.selection)');
  Check(LPage.Text('phanesEditor.history.length>0 && phanesEditor.future.length>0') = 'true',
    'Entry fixture has both nonempty history stacks');
  LPage.Execute('phanesRecoveryEntry.arm()');
  LPage.Click('#enter-nearby');
  LPage.WaitFor('phanesRecoveryEntry.responseReady===true');
  Check(LPage.Text('phanesRecoveryEntry.responseSuccess') = 'true',
    'Held entry has a successful response from the real world worker');
  Check(LPage.Text('phanesEnteringInterior===true && phanesEditor.worker!==null') = 'true',
    'First entry is genuinely pending before backgrounding');
  LPage.Lifecycle('frozen');
  LPage.Lifecycle('active');
  LPage.WaitFor('!phanesEnteringInterior && !phanesEditor.worker');
  Check(LPage.Text('phanesRecoveryEntry.terminated') = 'true',
    'Backgrounding terminates the pending native worker');
  CheckEntryPreserved('Background return');
  LPage.Execute('phanesStyleProbeResetFrames();phanesRecoveryEntry.emitLate()');
  LPage.WaitFor('phanesStyleProbeSnapshot().frameIntervals.length>=3');
  CheckEntryPreserved('Injected stale valid worker event');
  LPage.Screenshot(LOutput + '/entry-background-phone.png');
  LPage.Execute('phanesRecoveryEntry.arm()');
  LPage.Click('#enter-nearby');
  LPage.WaitFor('phanesRecoveryEntry.responseReady===true');
  Check(LPage.Text('phanesRecoveryEntry.responseSuccess && phanesEnteringInterior') = 'true',
    'Second first-entry request is pending before actual WebGL loss');
  WriteText(LOutput + '/before-loss-errors.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot().errors)'));
  Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Background cancellation has no uncaught browser errors');
  LPage.Execute('phanesStyleProbeLoseContext()');
  LPage.WaitFor('window.phanesEditor?.world && !window.phanesRecovering && ' +
    '!window.phanesRecoveryEntry?.held && ' +
    'sessionStorage.getItem("phanes-entry-test-terminated")==="true" && ' +
    'document.body.dataset.rendererState==="ready" && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(LPage.Text('sessionStorage.getItem("phanes-entry-test-terminated")') = 'true',
    'Graphics loss terminated the second pending worker before reload');
  CheckEntryPreserved('Actual graphics recovery');
  LPage.Screenshot(LOutput + '/entry-recovered-phone.png');
  LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
  LPage.Click('#enter-nearby');
  LPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio" && ' +
    '!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
    'Successful retry retains the original authoring mask');
  Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Recovered retry has no uncaught browser errors');
  LPage.Screenshot(LOutput + '/entry-success-phone.png');
  WriteText(LOutput + '/final-metrics.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot())'));
end;

begin
  Require((ParamCount = 3) or (ParamCount = 4),
    'Usage: renderer-checks BROWSER URL EVIDENCE [recovery|storage-denied|houses]');
  LOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(LOutput);
  LPage := TBrowserProbe.Create(ParamStr(1), LOutput + '/profile');
  try
    try
      LProbe := UTF8String(ReadText('build/phanes.tests.styles.probe.js'));
      if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
        (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
      begin
        Delete(LProbe, 1, 3);
      end;
      LPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
      if ParamStr(4) = 'entry-cancel' then
      begin
        LProbe := UTF8String(ReadText('build/phanes.tests.recovery.entry.probe.js'));
        if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
          (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
        begin
          Delete(LProbe, 1, 3);
        end;
        LPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
      end;
      if ParamStr(4) = 'storage-denied' then
      begin
        LProbe := UTF8String(ReadText('build/phanes.tests.storage.probe.js'));
        if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
          (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
        begin
          Delete(LProbe, 1, 3);
        end;
        LPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
      end;
      LPage.Resize(390, 844, 3);
      LPage.Navigate(ParamStr(2));
      LPage.WaitFor('document.body.dataset.startupState==="ready"');
      LPage.SetValue('region-size', '4');
      if ParamStr(4) = 'surface-sweep' then
      begin
        LPage.SetValue('world-seed', '732');
      end;
      LPage.Click('#create-world');
      LPage.WaitFor('document.body.dataset.renderedRevision==="1"');
      if ParamStr(4) = 'surface-sweep' then
      begin
        SurfaceSweep;
        Exit;
      end;
      if ParamStr(4) = 'entry-cancel' then
      begin
        EntryCancellation;
        Exit;
      end;
      if ParamStr(4) = 'modular' then
      begin
        LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("clear",null,{editLayer:""})');
        LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Click('#open-modules');
        LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:8,' +
          'selectionCells:[396,397,398,428,429,430,460,461,462]};phanesEditorActions.syncSelection()');
        Check(LPage.Text('!document.getElementById("module-build").disabled') = 'true',
          'Painted 2m footprint enables Imagine home');
        LPage.Execute('phanesStyleProbeResetFrames()');
        LPage.BeginProfile;
        LPage.Click('#module-build');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.asset==="phanes.building.modular.v1").length') = 1,
          'Actual UI builds one modular home');
        LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LProfile := LPage.EndProfile;
        try
          WriteText(LOutput + '/construction-profile.json', LProfile.AsJSON);
        finally
          LProfile.Free;
        end;
        LPage.Click('#module-focus');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.Screenshot(LOutput + '/cutaway-phone.png');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
        LSelected := LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.asset.includes("door.closed")).id');
        LPage.SetValue('module-parts', LSelected, 'change');
        LPage.Click('#module-toggle');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' + TJSONString.Create(LSelected).AsJSON + ').asset.includes("door.open")') = 'true',
          'Selected door opens in the same world document');
        LPage.Click('#module-undo');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld, 'Door Undo restores exact world');
        LPage.Click('#module-redo');
        LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Resize(1280, 900);
        LPage.Screenshot(LOutput + '/cutaway-desktop.png');
        LPage.SetValue('module-parts',
          LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.asset.includes("wall.")).id'), 'change');
        LPage.Click('#module-window');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===document.getElementById("module-parts").value).asset.includes("window.")') = 'true',
          'A selected solid wall becomes a real window module');
        LPage.Screenshot(LOutput + '/window-desktop.png');
        LPage.SetValue('module-parts', 'home-396.floor-13-13', 'change');
        LPage.SetValue('module-furniture', 'phanes.table.oak.v1', 'change');
        LPage.Click('#module-furnish');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('phanesEditor.world.composition.nodes.some(n=>n.id==="home-396.floor-13-13.furnishing.top")') = 'true',
          'A floor selection receives a table with an editable top');
        LPage.SetValue('module-parts', 'home-396.floor-13-13.furnishing.top', 'change');
        LPage.SetValue('module-content-role', 'plate', 'change');
        LPage.SetValue('module-content-count', '2');
        LPage.Click('#module-count-apply');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.role==="plate").length') = 2,
          'Modular table plate count reaches two through Arrange');
        LPage.SetValue('module-content-count', '0');
        LPage.Click('#module-contents-imagine');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.role==="plate").length') = 0,
          'Modular table plate count can return to zero through Reimagine');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(n=>n.id.includes(".furnishing")))');
        LPage.Click('#module-paint');
        LPage.Execute('phanesEditor.selection={x:1,z:1,width:2,depth:1,selectionScale:8,' +
          'selectionCells:[399,400,431,432]};phanesEditorActions.syncSelection()');
        LPage.Click('#module-extend');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(n=>n.id.includes(".furnishing")))') = LWorld,
          'Painted L-shaped extension preserves existing furnishing');
        LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Click('#module-overview');
        LPage.Screenshot(LOutput + '/furnished-extension-desktop.png');
        LPage.Resize(390, 844, 2);
        LPage.Click('#edit-toggle');
        LPage.Execute('Object.assign(phanesEditor,{x:-7,y:7,z:-10,yaw:Math.PI,pitch:0});' +
          'phanesEditorActions.setCamera("walk");phanesEditorActions.syncCamera()');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.WaitFor('!document.getElementById("module-nearby").hidden');
        LPage.Click('#module-nearby');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
          TJSONString.Create(LSelected).AsJSON + ').asset.includes("door.closed")') = 'true',
          'Nearby phone control closes the door in Explore');
        LPage.HoldKey('w', 87, 500);
        Check(LPage.Number('phanesEditor.z') < -8, 'Closed door blocks walking');
        LPage.HoldKey('s', 83, 350);
        LPage.Click('#module-nearby');
        LPage.WaitFor('!phanesEditor.worker');
        Check(LPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
          TJSONString.Create(LSelected).AsJSON + ').asset.includes("door.open")') = 'true',
          'Nearby phone control opens the door without changing context');
        LPage.HoldKey('w', 87, 1500);
        Check(LPage.Number('phanesEditor.z') > -7, 'Player walks through the open doorway');
        Check(LPage.Text('phanesEditor.interiorRoom') = '', 'Walking inside retains the exterior world context');
        LPage.Screenshot(LOutput + '/walk-inside-phone.png');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
        LHistory := LPage.Text('JSON.stringify(phanesEditor.history)');
        LContext := LPage.Text('JSON.stringify(phanesBuildingUI.snapshot())');
        LPage.Execute('window.phanesTestSaved=phanesSessionSavedRevision;' +
          'window.dispatchEvent(new Event("pagehide"))');
        LPage.WaitFor('phanesSessionSaved===true && phanesSessionSavedRevision>phanesTestSaved');
        LPage.Execute('location.reload()');
        LPage.WaitFor('window.phanesEditor?.world && !window.phanesRecovering && ' +
          'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
        Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
          'Reload restores exact world-space modules and contents');
        Check(LPage.Text('JSON.stringify(phanesEditor.history)') = LHistory,
          'Reload preserves modular edit history');
        Check(LPage.Text('JSON.stringify(phanesBuildingUI.snapshot())') = LContext,
          'Reload preserves selected home, part and cutaway tools');
        WriteText(LOutput + '/world.json', LPage.Text('JSON.stringify(phanesEditor.world)'));
        WriteText(LOutput + '/probe.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot())'));
        Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
          'Modular editing has no uncaught browser error');
        Exit;
      end;
      if ParamStr(4) = 'lighting' then
      begin
        LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("clear",null,{editLayer:""})');
        LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("asset",null,{exactAsset:"city-kit-suburban/building-type-a",editLayer:"buildings"})');
        LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Click('#edit-toggle');
        LPage.Execute('phanesEditorActions.setCamera("top")');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.Screenshot(LOutput + '/top-phone.png');
        LPage.Execute('Object.assign(phanesEditor,{panX:-8,panY:0,panZ:-8,zoom:2,yaw:0.5,pitch:-0.1});' +
          'phanesEditorActions.setCamera("orbit")');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.Screenshot(LOutput + '/orbit-phone.png');
        for LView := 0 to 3 do
        begin
          LAngle := LView * Pi / 2;
          LPage.Execute('Object.assign(phanesEditor,{x:' + FloatToStr(-8 + Sin(LAngle) * 22) +
            ',y:12,z:' + FloatToStr(-8 + Cos(LAngle) * 22) + ',yaw:' + FloatToStr(-LAngle) +
            ',pitch:-0.3});phanesEditorActions.setCamera("fly")');
          LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
          LPage.Screenshot(LOutput + '/fly-' + IntToStr(LView) + '-phone.png');
        end;
        LPage.Execute('Object.assign(phanesEditor,{x:-8,y:4,z:5,yaw:0,pitch:0});phanesEditorActions.setCamera("walk")');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.Screenshot(LOutput + '/walk-phone.png');
        LPage.Resize(1280, 900);
        LPage.Execute('Object.assign(phanesEditor,{x:14,y:14,z:14,yaw:-0.785398,pitch:-0.3});' +
          'phanesEditorActions.setCamera("fly")');
        LPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
        LPage.Screenshot(LOutput + '/fly-desktop.png');
        WriteText(LOutput + '/lighting.json', LPage.Text('JSON.stringify({probe:phanesStyleProbeSnapshot(),' +
          'camera:phanesCamera,buffer:[document.getElementById("castle-canvas").width,' +
          'document.getElementById("castle-canvas").height]})'));
        Check(LPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
          'Lighting camera sweep raises no uncaught browser error');
        Exit;
      end;
      if ParamStr(4) = 'supported-house' then
      begin
        LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("clear",null,{editLayer:""})');
        LPage.WaitFor('!phanesEditor.worker && phanesEditor.world.layers[0].every(v=>v==="meadow") && ' +
          'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Execute('phanesEditor.selection={x:1,z:1,width:2,depth:2};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("foundation",null,{groundworkTurn:1})');
        LPage.WaitFor('!phanesEditor.worker && phanesEditor.world.composition.nodes.some(n=>n.role==="plot") && ' +
          'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Execute('window.phanesTestPlot=phanesEditor.world.composition.nodes.find(n=>n.role==="plot").id;' +
          'phanesEditorActions.generate("place-building",null,{objectId:phanesTestPlot,buildingAsset:"city-kit-suburban/building-type-a"})');
        LPage.WaitFor('!phanesEditor.worker && phanesEditor.world.composition.nodes.some(n=>n.role==="building") && ' +
          'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Execute('phanesGroundworkUI.restoreCheckpoint({active:true,plot:phanesTestPlot,selected:phanesTestPlot+".deck",body:"plinth",turn:1});' +
          'window.phanesTestDeck=phanesEditor.world.composition.nodes.find(n=>n.id===phanesTestPlot+".deck");' +
          'window.phanesTestRoot=phanesEditor.world.composition.nodes.find(n=>n.id===phanesTestPlot);' +
          'Object.assign(phanesEditor,{x:phanesTestRoot.x/1000+7.4,y:(phanesTestRoot.y+phanesTestDeck.y)/1000+1.68,' +
          'z:phanesTestRoot.z/1000,yaw:1.5707963267948966,pitch:0});phanesEditorActions.setCamera("fly")');
        LPage.Click('#edit-toggle');
        LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
        Check(LPage.Text('JSON.parse(phanesNearbyInterior).supported') = 'true', 'Rotated house is targeted through its deck ownership');
        LReturn := LPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
        LContext := LPage.Text('JSON.stringify(phanesGroundworkUI.snapshot())');
        LSelection := LPage.Text('JSON.stringify(phanesEditor.selection)');
        LPage.Click('#enter-nearby');
        LPage.WaitFor('phanesEditor.interiorRoom.endsWith(".deck.building.studio") && !phanesEditor.worker && ' +
          'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection, 'Supported entry retains the complete plot selection');
        Check(LPage.Text('phanesEditor.camera') = 'walk', 'Fly enters the supported house on foot');
        LPage.Hold('[data-move="w"]', 400);
        Check(LPage.Number('phanesEditor.z') < 2.9, 'Walking works inside a house on a rotated foundation');
        LPage.Execute('phanesInteriorUI.choose(phanesEditor.world.composition.nodes.find(n=>n.role==="shelf-tier").id,false)');
        LSelected := LPage.Text('phanesEditor.interiorSelected');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
        LPage.Execute('phanesStyleProbeLoseContext()');
        LPage.WaitFor('document.body.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
        Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld, 'Supported recovery keeps plot, house and furnishings exact');
        Check(LPage.Text('JSON.stringify(phanesGroundworkUI.snapshot())') = LContext, 'Supported recovery retains selected deck and rotation context');
        Check(LPage.Text('phanesEditor.interiorSelected') = LSelected, 'Supported recovery retains nested shelf selection');
        LPage.Screenshot(LOutput + '/supported-recovered-phone.png');
        LPage.Click('#enter-nearby');
        LPage.WaitFor('phanesEditor.interiorRoom==="" && phanesRenderedCameraVersion===phanesCameraVersion');
        Check(LPage.Text('JSON.stringify([phanesEditor.camera,phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])') = LReturn,
          'Return restores the exact Fly pose above the rotated foundation');
        LPage.Screenshot(LOutput + '/supported-return-phone.png');
        Exit;
      end;
      if ParamStr(4) = 'houses' then
      begin
        for LHouse := 0 to 1 do
        begin
          LAsset := 'city-kit-suburban/building-type-a';
          if LHouse = 1 then
          begin
            LAsset := 'city-kit-suburban/building-type-f';
          end;
          LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection();' +
            'phanesEditorActions.generate("asset",null,{exactAsset:"' + LAsset + '",editLayer:"buildings"})');
          LPage.WaitFor('!phanesEditor.worker && phanesEditor.world.layers[3][5]==="' + LAsset + '" && ' +
            'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
          LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,selectionScale:1,selectionCells:[0,5,10,15]};' +
            'phanesEditorActions.syncSelection();Object.assign(phanesEditor,{x:-8,y:4,z:-0.6,yaw:0,pitch:0});' +
            'phanesEditorActions.setCamera("walk")');
          LPage.Click('#edit-toggle');
          LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
          Check(LPage.Text('document.getElementById("enter-nearby").textContent') = 'Enter house',
            'Imported shell offers explicit house entry');
          LPage.Screenshot(LOutput + '/house-' + IntToStr(LHouse) + '-outside-phone.png');
          LSelection := LPage.Text('JSON.stringify(phanesEditor.selection)');
          LReturn := LPage.Text('JSON.stringify([phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
          LPage.Click('#enter-nearby');
          LPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio" && !phanesEditor.worker && ' +
            'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
          Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
            'Imported house entry preserves the nonrectangular selection');
          Check(LPage.Text('phanesEditor.camera') = 'walk', 'House entry starts in first person');
          Check(LPage.Number('phanesEditor.z') <= 3.01, 'House spawn fits its smaller room');
          LPage.Hold('[data-move="w"]', 400);
          Check(LPage.Number('phanesEditor.z') < 2.9, 'House interior admits forward movement');
          LPage.Screenshot(LOutput + '/house-' + IntToStr(LHouse) + '-inside-phone.png');
          LPage.Click('#enter-nearby');
          LPage.WaitFor('phanesEditor.interiorRoom==="" && phanesRenderedCameraVersion===phanesCameraVersion');
          Check(LPage.Text('JSON.stringify([phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])') = LReturn,
            'House return restores the exact exterior pose');
          LPage.Click('#edit-toggle');
        end;
        { Create both sides of the edit history, then reopen an existing room.
          Entry must not consume redo or publish a duplicate interior. }
        LPage.Execute('phanesEditor.selection={x:2,z:2,width:1,depth:1};phanesEditorActions.syncSelection();' +
          'phanesEditorActions.generate("cabin")');
        LPage.WaitFor('!phanesEditor.worker && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Click('#undo');
        LPage.WaitFor('phanesEditor.future.length>0 && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        LPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,selectionScale:1,selectionCells:[0,5,10,15]};' +
          'phanesEditorActions.syncSelection();Object.assign(phanesEditor,{x:-8,y:4,z:-0.6,yaw:0,pitch:0});' +
          'phanesEditorActions.setCamera("walk")');
        LPage.Click('#edit-toggle');
        LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
        LPage.Click('#enter-nearby');
        LPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio" && !phanesEditor.worker');
        LPage.Execute('phanesInteriorUI.choose(phanesEditor.world.composition.nodes.find(n=>n.role==="shelf-tier").id,false)');
        LSelected := LPage.Text('phanesEditor.interiorSelected');
        LProbe := UTF8String(ReadText('build/phanes.tests.session.probe.js'));
        if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
          (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
        begin
          Delete(LProbe, 1, 3);
        end;
        LPage.Execute('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();phanesSessionProbeRun()');
        WriteText(LOutput + '/checkpoint-validation.json', LPage.Text('JSON.stringify(phanesSessionChecks)'));
        Check(LPage.Text('phanesSessionChecks.length===15 && phanesSessionChecks.every(x=>x.passed)') = 'true',
          'House checkpoint admits valid masks and rejects corrupt selection and history state');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
        LHistory := LPage.Text('JSON.stringify(phanesEditor.history)');
        LFuture := LPage.Text('JSON.stringify(phanesEditor.future)');
        Check((LHistory <> '[]') and (LFuture <> '[]'), 'Recovery fixture has both Undo and Redo history');
        LPage.Execute('phanesStyleProbeLoseContext()');
        LPage.WaitFor('document.body.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
        Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld, 'House recovery keeps exact world and room contents');
        Check(LPage.Text('JSON.stringify(phanesEditor.history)') = LHistory, 'House recovery keeps nonempty Undo history');
        Check(LPage.Text('JSON.stringify(phanesEditor.future)') = LFuture, 'House recovery keeps nonempty Redo history');
        Check(LPage.Text('phanesEditor.interiorSelected') = LSelected, 'House recovery keeps the selected shelf tier');
        LPage.Resize(1280, 900);
        LPage.Screenshot(LOutput + '/house-recovered-desktop.png');
        LPage.Click('#enter-nearby');
        LPage.WaitFor('phanesEditor.interiorRoom==="" && phanesRenderedCameraVersion===phanesCameraVersion');
        Check(LPage.Text('JSON.stringify([phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])') = LReturn,
          'House exterior return survives graphics recovery');
        Exit;
      end;
      if ParamStr(4) = 'storage-denied' then
      begin
        LPage.WaitFor('document.body.dataset.recoverySave==="failed"');
        Check(LPage.Text('!window.phanesRecovering && document.getElementById("renderer-recovery").hidden') = 'true',
          'Unavailable storage does not prevent creation or exploration');
        Check(LPage.Text('document.getElementById("toast").textContent.includes("Recovery storage")') = 'true',
          'Unavailable recovery storage is disclosed after creating a world');
        LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
        LPage.Execute('phanesStyleProbeLoseContext()');
        LPage.WaitFor('document.body.dataset.rendererState==="failed"');
        Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
          'Graphics loss does not discard the unsaved world');
        Check(LPage.Text('!document.getElementById("recovery-export").hidden') = 'true',
          'Graphics loss offers Export when storage is unavailable');
        LPage.Screenshot(LOutput + '/storage-unavailable-phone.png');
        Exit;
      end;
      LPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection()');
      LPage.Execute('phanesEditorActions.generate("cabin")');
      LPage.WaitFor('!phanesEditor.worker && document.body.dataset.renderedRevision==="2"');
      LPage.Execute('Object.assign(phanesEditor,{x:-8,y:4,z:-1.5,yaw:0,pitch:0});phanesEditorActions.setCamera("walk")');
      LPage.Click('#edit-toggle');
      LPage.WaitFor('!document.getElementById("enter-nearby").hidden');
      LPage.Screenshot(LOutput + '/cabin-outside-phone.png');
      LReturn := LPage.Text('JSON.stringify([phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])');
      LSelection := LPage.Text('JSON.stringify(phanesEditor.selection)');
      LPage.Click('#enter-nearby');
      LPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio" && !phanesEditor.worker');
      LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
      Check(LPage.Text('phanesEditor.camera') = 'walk', 'Nearby entry opens a walkable cabin from Explore');
      Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
        'Entering preserves the authoring selection');
      LPage.Hold('[data-move="w"]', 450);
      LPage.Screenshot(LOutput + '/cabin-inside-phone.png');
      Check(LPage.Number('phanesEditor.z') < 3.8, 'Movement works inside the cabin');
      LProbe := UTF8String(ReadText('build/phanes.tests.session.probe.js'));
      if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
        (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
      begin
        Delete(LProbe, 1, 3);
      end;
      LPage.Execute('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();phanesSessionProbeRun()');
      WriteText(LOutput + '/checkpoint-validation.json', LPage.Text('JSON.stringify(phanesSessionChecks)'));
      Check(LPage.Text('phanesSessionChecks.length===15 && phanesSessionChecks.every(x=>x.passed)') = 'true',
        'Checkpoint validation rejects malformed state and corrupted undo/redo worlds');
      LWorld := LPage.Text('JSON.stringify(phanesEditor.world)');
      LHistory := LPage.Text('JSON.stringify(phanesEditor.history)');
      LPage.Execute('window.phanesTestSaveRevision=(window.phanesSessionSavingRevision||0);' +
        'window.dispatchEvent(new Event("pagehide"))');
      LPage.WaitFor('window.phanesSessionSavedRevision>window.phanesTestSaveRevision');
      Check(LPage.Number('phanesRenderDensity') >= 1.5, 'Balanced keeps a sharpness floor on high-density screens');
      LFrames := LPage.Number('phanesRenderedFrames');
      Sleep(500);
      Check(LPage.Number('phanesRenderedFrames') > LFrames, 'The render heartbeat advances on actual CGE frames');
      LPage.Lifecycle('frozen');
      Sleep(2700);
      LPage.Lifecycle('active');
      LPage.WaitFor('!window.phanesWorldSuspended');
      Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
        'Freezing and resuming without context loss preserves the world');
      Check(LPage.Number('phanesRenderDensity') >= 1.5, 'Resuming does not collapse render density');
      LPage.Click('#open-styles');
      LPage.Click('#style-choice-toon');
      LPage.Click('#close-styles');
      LPage.Execute('phanesStyleProbeLoseContext()');
      LPage.WaitFor('document.body.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
      Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld, 'Graphics recovery preserves the exact world');
      Check(LPage.Text('JSON.stringify(phanesEditor.history)') = LHistory, 'Graphics recovery preserves undo history');
      Check(LPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection, 'Graphics recovery preserves the selection');
      Check(LPage.Text('phanesEditor.interiorRoom') = 'building-1-1.studio', 'Graphics recovery returns inside the same cabin');
      Check(LPage.Text('phanesEditor.editing') = 'false', 'Graphics recovery preserves Explore mode');
      Check(LPage.Text('phanesStyleId') = 'toon', 'Graphics recovery preserves the chosen visual style');
      LPage.Screenshot(LOutput + '/recovered-interior-phone.png');
      LPage.Click('#enter-nearby');
      LPage.WaitFor('phanesEditor.interiorRoom==="" && phanesRenderedCameraVersion===phanesCameraVersion');
      Check(LPage.Text('JSON.stringify([phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.yaw,phanesEditor.pitch])') = LReturn,
        'Return outside restores the exact exterior pose after recovery');
      LPage.Resize(1280, 900);
      LPage.Click('#open-styles');
      LPage.Click('#style-choice-none');
      LPage.Click('#close-styles');
      LPage.Screenshot(LOutput + '/cabin-outside-desktop.png');
      LPage.Click('#edit-toggle');
      LPage.Click('#undo');
      LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
      Check(LPage.Text('JSON.stringify(phanesEditor.world)') <> LWorld, 'Undo remains usable after recovery');
      LPage.Click('#redo');
      LPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
      Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld, 'Redo restores the exact pre-recovery world');
      WriteText(LOutput + '/render-metrics.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot())'));
      LPage.Execute('phanesStyleProbeLoseContext()');
      LPage.WaitFor('document.body.dataset.rendererState==="failed"');
      Check(LPage.Text('document.getElementById("recover-renderer").hidden') = 'false',
        'Repeated graphics loss offers recovery instead of a reload loop');
      Check(LPage.Text('document.activeElement.id') = 'recover-renderer',
        'Recovery failure focuses the retry action');
      LPage.Key('Escape', 27);
      Check(LPage.Text('document.getElementById("renderer-recovery").open') = 'true',
        'Escape cannot expose controls behind a failed renderer');
      LPage.Key('Tab', 9);
      Check(LPage.Text('document.activeElement.closest("#renderer-recovery")!==null') = 'true',
        'Recovery keyboard focus remains within the modal');
      LPage.Screenshot(LOutput + '/repeated-loss-desktop.png');
      LPage.Click('#recover-renderer');
      LPage.WaitFor('document.body.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
      Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
        'Explicit retry recovers a repeated graphics failure without changing the world');
    except
      on LException: Exception do
      begin
        WriteText(LOutput + '/failure.txt', LException.Message + #10 + LPage.Text('document.body.innerText'));
        LPage.Screenshot(LOutput + '/failure.png');
        raise;
      end;
    end;
  finally
    LPage.Free;
  end;
end.
