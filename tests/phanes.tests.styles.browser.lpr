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
program phanes.tests.styles.browser;

{$mode delphi}
{$H+}

uses
  SysUtils,
  FPJSON,
  phanes.tools.files,
  phanes.tools.browser,
  phanes.styles.catalog,
  wfc_browser_socket;

const
  StableWorld = 'JSON.stringify([phanesEditor.world,phanesEditor.history,phanesEditor.future,' +
    'phanesEditor.selection,phanesEditor.camera,phanesEditor.zoom,phanesEditor.yaw,' +
    'phanesEditor.pitch,phanesEditor.x,phanesEditor.y,phanesEditor.z,phanesEditor.panX,' +
    'phanesEditor.panY,phanesEditor.panZ,phanesSceneVersion,phanesEditor.interiorRoom,' +
    'phanesEditor.interiorSelected])';
  StyleAck = 'window.phanesRenderedStyleRevision===window.phanesStyleRevision && ' +
    'document.getElementById("style-panel").getAttribute("aria-busy")==="false"';
  StableSession = 'JSON.stringify({world:phanesEditor.world,history:phanesEditor.history,' +
    'future:phanesEditor.future,selection:phanesEditor.selection,editing:phanesEditor.editing,' +
    'camera:{camera:phanesEditor.camera,zoom:phanesEditor.zoom,yaw:phanesEditor.yaw,' +
    'pitch:phanesEditor.pitch,x:phanesEditor.x,y:phanesEditor.y,z:phanesEditor.z,' +
    'panX:phanesEditor.panX,panY:phanesEditor.panY,panZ:phanesEditor.panZ},' +
    'interior:phanesInteriorUI.snapshot(),groundwork:phanesGroundworkUI.snapshot(),' +
    'modular:phanesBuildingUI.snapshot(),landforms:phanesLandformUI.snapshot(),' +
    'quality:document.getElementById("render-quality").value,style:phanesStyleUI.snapshot(),' +
    'toolsCollapsed:document.body.classList.contains("tools-collapsed")})';
  DiagnosticState = '(()=>{const probe=typeof phanesStyleProbeSnapshot==="function"?' +
    'phanesStyleProbeSnapshot():null;const panel=document.getElementById("style-panel");' +
    'return {probe:probe,browserErrors:probe?probe.errors:[],style:{id:window.phanesStyleId,' +
    'strength:window.phanesStyleStrength,detail:window.phanesStyleDetail,' +
    'requestedRevision:window.phanesStyleRevision,' +
    'renderedRevision:window.phanesRenderedStyleRevision,' +
    'passRendered:window.phanesStylePassRendered,panelHidden:panel?panel.hidden:null,' +
    'panelBusy:panel?panel.getAttribute("aria-busy"):null,' +
    'panelRenderedRevision:panel?panel.getAttribute("data-rendered-revision"):null,' +
    'current:document.getElementById("style-current")?.textContent||null,' +
    'status:document.getElementById("style-status")?.textContent||null},' +
    'rendererState:document.body?.dataset.rendererState||null,' +
    'recovering:Boolean(window.phanesRecovering),sceneVersion:window.phanesSceneVersion,' +
    'renderedSceneRevision:document.body?.dataset.renderedRevision||null};})()';

var
  GPage: TBrowserProbe;
  GEvidence: TJSONObject;
  GChecks: TJSONArray;
  GImages: TJSONArray;
  GTimings: TJSONArray;
  GOutput: String;

procedure Save;
begin
  WriteText(GOutput + '/evidence.json', GEvidence.FormatJSON);
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  GChecks.Add(AMessage);
  Save;
end;

procedure Snapshot(const AName: String; const ACanvas: Boolean = False);
var
  LPath: String;
begin
  LPath := GOutput + '/' + AName + '.png';
  GPage.Screenshot(LPath, ACanvas);
  GImages.Add(TJSONObject.Create(['name', AName, 'sha256', HashFile(LPath)]));
  Save;
end;

procedure CaptureDiagnostics(const AName: String);
var
  LDiagnostics: TJSONData;
begin
  LDiagnostics := GPage.Evaluate(DiagnosticState);
  WriteText(GOutput + '/' + AName + '.json', LDiagnostics.FormatJSON);
  GEvidence.Add(AName, LDiagnostics);
  Save;
end;

procedure OpenStyles;
begin
  if GPage.Text('document.getElementById("style-panel").hidden') = 'true' then
  begin
    GPage.Click('#open-styles');
  end;
end;

procedure CloseStyles;
begin
  if GPage.Text('document.getElementById("style-panel").hidden') = 'false' then
  begin
    GPage.Click('#close-styles');
  end;
end;

procedure Choose(const AIndex: Integer);
var
  LStart: QWord;
begin
  OpenStyles;
  LStart := WfcBrowserTickCount64;
  GPage.Click('#style-choice-' + VisualStyles[AIndex].FId);
  GPage.WaitFor(StyleAck, 30000);
  Require(GPage.Text('phanesStyleId') = VisualStyles[AIndex].FId, 'Selected style acknowledged');
  Require(GPage.Text('phanesStylePassRendered') = LowerCase(BoolToStr(AIndex <> 0, True)),
    'None bypass or actual viewport screen pass');
  GTimings.Add(TJSONObject.Create(['id', VisualStyles[AIndex].FId,
    'inputAndRenderMs', WfcBrowserTickCount64 - LStart,
    'publishToRenderedFrameMs', GPage.Number('phanesStyleElapsedMs')]));
end;

procedure StartWorld(const AURL: String; const AWidth, AHeight: Integer;
  const ADensity: Double = 1);
begin
  GPage.Resize(AWidth, AHeight, ADensity);
  { These scenarios intentionally create a fresh world. A saved session from
    the previous scenario would instead start the recovery workflow. Keep
    recovery intact elsewhere and reset only this owned browser tab's key. }
  if GPage.Text('location.protocol === "http:" || location.protocol === "https:"') = 'true' then
  begin
    GPage.Execute('sessionStorage.removeItem("phanes-session-key");' +
      'sessionStorage.removeItem("phanes-recovery");');
  end;
  GPage.Navigate('about:blank');
  GPage.WaitFor('location.href==="about:blank"');
  GPage.Navigate(AURL);
  GPage.WaitFor('document.body && document.body.dataset.ready==="true"');
  GPage.WaitFor('!document.getElementById("create-world").disabled');
  GPage.Click('#create-world');
  GPage.WaitFor('document.body.dataset.renderedRevision==="1"');
  GPage.WaitFor(StyleAck);
  Check(GPage.Text('phanesStyleId') = 'none', 'New page starts at None');
  Check(GPage.Text('phanesStylePassRendered') = 'false', 'Default viewport bypasses style pass');
end;

procedure CheckPanel(const AWidth, AHeight: Integer);
var
  LBounds: TJSONObject;
  LId: String;
  I: Integer;
const
  Targets: array[0..3] of String = ('open-styles', 'close-styles', 'style-compare', 'style-reset');
begin
  LBounds := TJSONObject(GPage.Evaluate('document.getElementById("style-panel").getBoundingClientRect().toJSON()'));
  try
    Check((LBounds.Floats['x'] >= 0) and (LBounds.Floats['right'] <= AWidth) and
      (LBounds.Floats['y'] >= 0) and (LBounds.Floats['bottom'] <= AHeight),
      IntToStr(AWidth) + 'x' + IntToStr(AHeight) + ' panel stays inside viewport');
  finally
    LBounds.Free;
  end;
  Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true',
    IntToStr(AWidth) + ' layout has no horizontal page overflow');
  for I := 0 to High(Targets) do
  begin
    LId := Targets[I];
    LBounds := TJSONObject(GPage.Evaluate('document.getElementById("' + LId +
      '").getBoundingClientRect().toJSON()'));
    try
      Check((LBounds.Floats['width'] >= 44) and (LBounds.Floats['height'] >= 44),
        LId + ' retains a 44px target');
    finally
      LBounds.Free;
    end;
  end;
end;

procedure CheckShaderFailure(const AURL: String);
begin
  StartWorld(AURL + '?style-test-failure', 1000, 760);
  OpenStyles;
  GPage.Click('#style-choice-toon');
  GPage.WaitFor(StyleAck, 30000);
  Check(GPage.Text('phanesStyleId') = 'none', 'Shader compilation failure restores None');
  Check(Pos('unavailable', GPage.Text('document.getElementById("style-status").textContent')) > 0,
    'Shader failure explanation remains after fallback has rendered');
  Check(GPage.Text('phanesStyleProbeSnapshot().failureInjected') = 'true',
    'Failure test reached the real GLSL compilation path');
  CaptureDiagnostics('shaderFailureDiagnostics');
  Snapshot('shader-failure');
end;

procedure CheckReloadRecovery(const AURL: String);
var
  LHistory: String;
  LSession: String;
  LStyle: String;
  LWorld: String;
begin
  StartWorld(AURL, 1000, 760);
  Choose(1);
  GPage.SetValue('style-strength', '64');
  GPage.SetValue('style-detail', '81');
  GPage.WaitFor(StyleAck);
  CloseStyles;
  LWorld := GPage.Text('JSON.stringify(phanesEditor.world)');
  LHistory := GPage.Text('JSON.stringify([phanesEditor.history,phanesEditor.future])');
  LStyle := GPage.Text('JSON.stringify(phanesStyleUI.snapshot())');
  LSession := GPage.Text(StableSession);
  GPage.Execute('window.phanesStyleBeforeRecovery=true;' +
    'window.phanesStyleSaveRevision=window.phanesSessionSavingRevision||0;' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSavedRevision>window.phanesStyleSaveRevision');
  GPage.Execute('phanesStyleProbeLoseContext()');
  GPage.WaitFor('!window.phanesStyleBeforeRecovery && ' +
    'document.body?.dataset.rendererState==="ready" && !window.phanesRecovering', 180000);
  GPage.WaitFor(StyleAck, 180000);
  Check(GPage.Text('!window.phanesStyleBeforeRecovery') = 'true',
    'Graphics recovery reloads the app instead of restoring the old context');
  Check(GPage.Text('document.body.dataset.rendererState==="ready" && !window.phanesRecovering') =
    'true', 'Reloaded renderer is ready and recovery has finished');
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
    'Graphics recovery preserves the exact world');
  Check(GPage.Text('JSON.stringify([phanesEditor.history,phanesEditor.future])') = LHistory,
    'Graphics recovery preserves exact Undo and Redo history');
  Check(GPage.Text('JSON.stringify(phanesStyleUI.snapshot())') = LStyle,
    'Graphics recovery preserves exact visual style settings');
  Check(GPage.Text(StableSession) = LSession,
    'Graphics recovery preserves the complete saved session exactly');
  Check(GPage.Text('phanesStylePassRendered') = 'true',
    'Restored visual style renders through the viewport pass');
  Choose(10);
  CloseStyles;
  Check(GPage.Text('phanesStylePassRendered') = 'true',
    'A visual style changed after recovery renders through the viewport pass');
  CaptureDiagnostics('reloadRecoveryDiagnostics');
  Snapshot('context-restored');
end;

procedure Run;
var
  LProfile: String;
  LState: String;
  LOriginal: String;
  LId: TGUID;
  LURL: String;
  I: Integer;
  J: Integer;
  LWidth: Integer;
  LHeight: Integer;
  LFull: Boolean;
  LFocused: Boolean;
  LPhase: String;
  LProbe: UTF8String;
  LBox: TJSONObject;
  LX: Double;
  LY: Double;
  LSelection: String;
begin
  Require(ParamCount = 3, 'Usage: phanes.tests.styles.browser BROWSER URL NEW-EVIDENCE-DIRECTORY');
  LURL := ParamStr(2);
  LPhase := LowerCase(Trim(GetEnvironmentVariable('PHANES_STYLE_PHASE')));
  Require((LPhase = '') or (LPhase = 'ui') or (LPhase = 'failure-recovery'),
    'PHANES_STYLE_PHASE must be empty, ui, or failure-recovery');
  LFull := LPhase <> 'ui';
  LFocused := LPhase = 'failure-recovery';
  GOutput := ExpandFileName(ParamStr(3));
  Require(not DirectoryExists(GOutput), 'Use a new evidence directory');
  ForceDirectories(GOutput);
  CreateGUID(LId);
  LProfile := GOutput + '/browser-' + GUIDToString(LId);
  GEvidence := TJSONObject.Create(['url', LURL, 'runner', 'Native Pascal through pinned WFC CDP',
    'phase', LPhase]);
  GChecks := TJSONArray.Create;
  GImages := TJSONArray.Create;
  GTimings := TJSONArray.Create;
  GEvidence.Add('checks', GChecks);
  GEvidence.Add('captures', GImages);
  GEvidence.Add('timings', GTimings);
  GPage := TBrowserProbe.Create(ParamStr(1), LProfile);
  try
    LProbe := ReadText('build/phanes.tests.styles.probe.js');
    if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
      (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
    begin
      Delete(LProbe, 1, 3);
    end;
    GPage.InstallScript('(()=>{' + LProbe +
      #10 + 'rtl.run();})();');
    GEvidence.Add('gpu', GPage.GPU);
    if LFocused then
    begin
      CheckShaderFailure(LURL);
      CheckReloadRecovery(LURL);
      GEvidence.Add('passed', True);
      Exit;
    end;
    StartWorld(LURL, 1280, 800);
    Check(StrToInt(GPage.Text('document.querySelectorAll("[data-style-id]").length')) >= 21,
      'At least 20 styles plus None are available');
    Check(GPage.Text('document.querySelector("[data-intent=rocket] span").textContent') =
      'Sci-fiReach for tomorrow', 'Sci-fi category retains the existing rocket intent');
    GPage.Click('[data-camera="orbit"]');
    GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
    LState := GPage.Text(StableWorld);
    Snapshot('exterior-none', True);
    GEvidence.Add('probeNone', GPage.Evaluate('phanesStyleProbeSnapshot()'));
    LOriginal := HashFile(GOutput + '/exterior-none.png');
    if LFull then
    begin
      for I := 1 to VisualStyleCount - 1 do
      begin
        Choose(I);
        CloseStyles;
        Snapshot('exterior-' + VisualStyles[I].FId, True);
        Require(GPage.Text(StableWorld) = LState, 'Style preserves world/history/camera');
        WriteLn('Rendered exterior: ', VisualStyles[I].FId);
        Flush(Output);
      end;
      Choose(0);
      CloseStyles;
      Snapshot('exterior-none-restored', True);
      Check(HashFile(GOutput + '/exterior-none-restored.png') = LOriginal,
        'None restores the exact baseline canvas PNG after all styles');
      Check(GPage.Text(StableWorld) = LState, 'All styles preserve world/history/selection/camera');
      GEvidence.Add('metricsBeforeCycles', GPage.Metrics);
      GEvidence.Add('probeBeforeCycles', GPage.Evaluate('phanesStyleProbeSnapshot()'));
      for J := 1 to 3 do
      begin
        for I := 0 to VisualStyleCount - 1 do
        begin
          Choose(I);
        end;
      end;
      GEvidence.Add('metricsAfterCycles', GPage.Metrics);
      GEvidence.Add('probeAfterCycles', GPage.Evaluate('phanesStyleProbeSnapshot()'));
      Check(True, 'Three full repeated live-switch cycles completed');
    end;
    Choose(1);
    Snapshot('desktop-panel');
    GPage.Click('#style-compare');
    GPage.WaitFor(StyleAck);
    Check(GPage.Text('phanesStyleId') = 'none', 'Compare original bypasses the shader');
    Check(GPage.Text('document.getElementById("style-current").textContent') = 'Toon',
      'Compare original retains the selected style');
    GPage.Click('#style-compare');
    GPage.WaitFor(StyleAck);
    Check(GPage.Text('phanesStyleId') = 'toon', 'Comparison returns to selected style');
    GPage.SetValue('style-strength', '0');
    GPage.WaitFor(StyleAck);
    Check(GPage.Text('phanesStylePassRendered') = 'false', 'Zero intensity bypasses the shader');
    GPage.SetValue('style-strength', '64');
    GPage.SetValue('style-detail', '81');
    GPage.WaitFor(StyleAck);
    Check(Abs(GPage.Number('phanesStyleDetail') - 0.81) < 0.00001,
      'Live detail adjustment reaches the renderer');
    GPage.SetValue('style-search', 'nothing matches this');
    Check(GPage.Text('document.getElementById("style-empty").hidden') = 'false',
      'Search has a clear empty state');
    GPage.Key('Escape', 27);
    Check(GPage.Text('document.activeElement.id') = 'open-styles', 'Escape restores trigger focus');
    GPage.Key('Enter', 13);
    Check(GPage.Text('document.activeElement.id') = 'style-search', 'Filtered reopen focuses visible search');
    GPage.Click('#style-reset');
    GPage.WaitFor(StyleAck);
    CloseStyles;
    GPage.Click('[data-camera="top"]');
    GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
    LBox := TJSONObject(GPage.Evaluate('document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
    try
      LX := LBox.Floats['x'] + LBox.Floats['width'] * 0.45;
      LY := LBox.Floats['y'] + LBox.Floats['height'] * 0.45;
    finally
      LBox.Free;
    end;
    GPage.ClickAt(LX, LY);
    GPage.WaitFor('phanesEditor.selection.width===1 && phanesEditor.selection.depth===1');
    LSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
    for I := 0 to VisualStyleCount - 1 do
    begin
      if I in [0, 1, 6, 10, 13, 21] then
      begin
        Choose(I);
        CloseStyles;
        GPage.ClickAt(LX, LY);
        Sleep(500);
        Check(GPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
          VisualStyles[I].FId + ' preserves the regional ray pick');
        Snapshot('selection-' + VisualStyles[I].FId, True);
      end;
    end;
    Choose(0);
    CloseStyles;
    GPage.Click('[data-intent="cabin"]');
    GPage.Click('[data-catalog-group="cabin"]');
    GPage.Click('[data-catalog-asset="cabin"]');
    GPage.Execute('window.phanesStyleBeforePlacement=phanesSceneVersion');
    GPage.Click('#catalog-apply');
    GPage.WaitFor('!phanesEditor.worker && phanesSceneVersion===phanesStyleBeforePlacement+1 && ' +
      'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
    GPage.Click('#open-interior');
    GPage.WaitFor('!!phanesEditor.interiorRoom && !phanesEditor.worker && ' +
      'document.body.dataset.renderedInterior===phanesEditor.interiorRoom');
    GPage.Execute('phanesStyleProbeResetFrames()');
    Sleep(2000);
    GEvidence.Add('probeInteriorNone', GPage.Evaluate('phanesStyleProbeSnapshot()'));
    LState := GPage.Text(StableWorld);
    for I := 0 to VisualStyleCount - 1 do
    begin
      Choose(I);
      CloseStyles;
      Snapshot('interior-' + VisualStyles[I].FId, True);
      Require(GPage.Text(StableWorld) = LState, 'Style preserves populated interior');
      WriteLn('Rendered interior: ', VisualStyles[I].FId);
      Flush(Output);
    end;
    Check(True, 'All styles render a populated studio without changing its contents');
    for I := 0 to 3 do
    begin
      case I of
        0:
          begin
            LWidth := 390;
            LHeight := 844;
          end;
        1:
          begin
            LWidth := 360;
            LHeight := 740;
          end;
        2:
          begin
            LWidth := 844;
            LHeight := 390;
          end;
        else
          begin
            LWidth := 390;
            LHeight := 420;
          end;
      end;
      StartWorld(LURL, LWidth, LHeight);
      Choose(10);
      CheckPanel(LWidth, LHeight);
      Snapshot('panel-' + IntToStr(LWidth) + 'x' + IntToStr(LHeight));
      GPage.SetValue('style-group', 'Spectral', 'change');
      GPage.Click('#style-choice-aurora');
      GPage.WaitFor(StyleAck);
      GPage.Click('#style-compare');
      GPage.WaitFor(StyleAck);
      CloseStyles;
      GPage.WaitFor(StyleAck);
      Check(GPage.Text('phanesStyleId') = 'aurora', 'Closing comparison restores chosen style');
      Snapshot('world-' + IntToStr(LWidth) + 'x' + IntToStr(LHeight));
    end;
    CheckShaderFailure(LURL);
    CheckReloadRecovery(LURL);
    GEvidence.Add('passed', True);
  except
    on E: Exception do
    begin
      GEvidence.Add('failure', E.Message);
      try
        CaptureDiagnostics('failureDiagnostics');
      except
        on LDiagnosticException: Exception do
        begin
          GEvidence.Add('diagnosticCaptureFailure', LDiagnosticException.Message);
        end;
      end;
      try
        Snapshot('failure-state');
      except
        on Exception do
        begin
          { Preserve the primary failed assertion when screenshot capture also fails. }
        end;
      end;
      raise;
    end;
  end;
end;

begin
  try
    Run;
    WriteLn('Pascal visual styles browser checks passed.');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      ExitCode := 1;
    end;
  end;
  if GEvidence <> nil then
  begin
    Save;
  end;
  GPage.Free;
  GEvidence.Free;
end.
