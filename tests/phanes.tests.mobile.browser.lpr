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

program PhanesMobileBrowserChecks;
{$mode delphi}
{$H+}
uses SysUtils, Math, FPJSON, phanes.tools.browser, phanes.tools.files;
var
  LPage: TBrowserProbe;
  LOutput: String;
  LProbe: UTF8String;
  LInitial: Double;
  LAfter: Double;
  LSpan: Double;
  LState: String;
  LDraws: Double;
  LTrackId: String;
  I: Integer;

procedure Check(const APass: Boolean; const AMessage: String);
begin
  Require(APass, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

function TouchPoint(const ASelector: String; const AId: Integer): TJSONObject; forward;

procedure CheckWalking;
var
  LX: Double;
  LZ: Double;
  LRevision: Integer;
  LKey: String;
  I: Integer;
begin
  { Exercise movement on actual admitted terrain after explicitly clearing its
    props. Collision with a randomly placed tree must not masquerade as a pad failure. }
  LPage.Click('#edit-toggle');
  LPage.Click('#select-all');
  LRevision := Round(LPage.Number('phanesSceneVersion'));
  LPage.Click('#clear-region');
  LPage.WaitFor('!phanesEditor.worker && phanesSceneVersion===' + IntToStr(LRevision + 1) +
    ' && Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  LPage.Click('#edit-toggle');
  for I := 0 to 3 do
  begin
    case I of
      0: LKey := 'w';
      1: LKey := 's';
      2: LKey := 'a';
      else LKey := 'd';
    end;
    LX := LPage.Number('phanesEditor.x');
    LZ := LPage.Number('phanesEditor.z');
    LPage.Hold('[data-move="' + LKey + '"]', 450);
    Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) > 0.3,
      'First person touch movement works for ' + LKey);
  end;
  Check(LPage.Number('phanesNavigationUI.activePointerCount()') = 0,
    'Movement button releases retain no historical pointer IDs');
  LX := LPage.Number('phanesEditor.x');
  LZ := LPage.Number('phanesEditor.z');
  Sleep(400);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) < 0.02,
    'Released first-person movement stops');
  LPage.Touch('touchStart', TJSONArray.Create([
    TouchPoint('[data-move="w"]', 1), TouchPoint('[data-move="d"]', 2)]));
  Sleep(500);
  LPage.Touch('touchCancel', TJSONArray.Create);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) > 0.3,
    'First person accepts diagonal touch movement');
  LPage.Touch('touchStart', TJSONArray.Create([TouchPoint('[data-move="s"]', 1)]));
  Sleep(150);
  LPage.Execute('window.dispatchEvent(new Event("blur"))');
  LPage.Touch('touchEnd', TJSONArray.Create);
  Sleep(100);
  LX := LPage.Number('phanesEditor.x');
  LZ := LPage.Number('phanesEditor.z');
  Sleep(400);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) < 0.02,
    'Focus loss releases held first-person movement');
  LPage.Execute('document.querySelector("[data-move=s]").focus()');
  LPage.HoldKey(' ', 32, 450);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) > 0.3,
    'A focused movement button supports holding Space');
  LPage.Execute('document.getElementById("castle-canvas").focus()');
  LX := LPage.Number('phanesEditor.x');
  LZ := LPage.Number('phanesEditor.z');
  LPage.HoldKey('w', 87, 450);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) > 0.3,
    'WASD remains available through the Pascal input path');
  LPage.Touch('touchStart', TJSONArray.Create([TouchPoint('[data-move="w"]', 1)]));
  LPage.Key('3', 51);
  Check(LPage.Text('phanesEditor.camera') = 'fly', 'The camera shortcut changes view while a touch is held');
  LX := LPage.Number('phanesEditor.x');
  LZ := LPage.Number('phanesEditor.z');
  Sleep(400);
  Check(Hypot(LPage.Number('phanesEditor.x') - LX, LPage.Number('phanesEditor.z') - LZ) < 0.02,
    'Camera switching releases held movement');
  LPage.Touch('touchEnd', TJSONArray.Create);
  Check(LPage.Number('phanesNavigationUI.activePointerCount()') = 0,
    'Released pointer IDs are removed from the active input set');
end;

procedure Sample(const AName: String);
begin
  LPage.Execute('phanesStyleProbeResetFrames()');
  Sleep(6000);
  WriteText(LOutput + '/' + AName + '.json', LPage.Text('JSON.stringify(phanesStyleProbeSnapshot())'));
end;

function TouchPoint(const ASelector: String; const AId: Integer): TJSONObject;
var
  LBounds: TJSONObject;
  LQuery: TJSONString;
begin
  LQuery := TJSONString.Create(ASelector);
  try
    LBounds := TJSONObject(LPage.Evaluate('document.querySelector(' +
      LQuery.AsJSON + ').getBoundingClientRect().toJSON()'));
    try
      Result := TJSONObject.Create([
        'x', LBounds.Floats['x'] + LBounds.Floats['width'] / 2,
        'y', LBounds.Floats['y'] + LBounds.Floats['height'] / 2,
        'id', AId]);
    finally
      LBounds.Free;
    end;
  finally
    LQuery.Free;
  end;
end;

begin
  Require(ParamCount = 3, 'Usage: mobile-checks BROWSER URL EVIDENCE');
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
    LPage.Resize(390, 844);
    LPage.Navigate(ParamStr(2));
    LPage.WaitFor('document.body.dataset.ready==="true"');
    LPage.SetValue('region-size', '4');
    LPage.Click('#create-world');
    LPage.WaitFor('document.body.dataset.renderedRevision==="1"');
    Sample('4-top');
    LPage.Click('[data-camera="fly"]');
    LPage.Screenshot(LOutput + '/fly-tools-open.png');
    Check(LPage.Text('document.getElementById("walk-controls").hidden') = 'false', 'Fly has a movement pad');
    Check(LPage.Text('document.getElementById("fly-controls").hidden') = 'false', 'Fly has rise/descend');
    LInitial := LPage.Number('phanesEditor.y');
    LPage.Hold('[data-move="e"]', 1000);
    LAfter := LPage.Number('phanesEditor.y');
    Check(LAfter > LInitial + 0.3, 'Touch Rise moves up');
    LPage.Hold('[data-move="q"]', 1000);
    Check(LPage.Number('phanesEditor.y') < LAfter - 0.3, 'Touch Descend moves down');
    LInitial := LPage.Number('phanesEditor.z');
    LPage.Hold('[data-move="w"]', 1000);
    Check(Abs(LPage.Number('phanesEditor.z') - LInitial) > 0.3, 'Touch forward moves in Fly');
    LInitial := LPage.Number('phanesEditor.z');
    Sleep(600);
    Check(Abs(LPage.Number('phanesEditor.z') - LInitial) < 0.01, 'Released touch movement stops');
    LInitial := LPage.Number('phanesEditor.y');
    LAfter := LPage.Number('phanesEditor.z');
    LPage.Touch('touchStart', TJSONArray.Create([
      TouchPoint('[data-move="w"]', 1), TouchPoint('[data-move="e"]', 2)]));
    Sleep(700);
    LPage.Touch('touchCancel', TJSONArray.Create);
    Check((LPage.Number('phanesEditor.y') > LInitial + 0.3) and
      (Abs(LPage.Number('phanesEditor.z') - LAfter) > 0.3), 'Simultaneous forward and rise touches work');
    LInitial := LPage.Number('phanesEditor.y');
    LAfter := LPage.Number('phanesEditor.z');
    Sleep(500);
    Check((Abs(LPage.Number('phanesEditor.y') - LInitial) < 0.01) and
      (Abs(LPage.Number('phanesEditor.z') - LAfter) < 0.01), 'Cancelled touches release every axis');
    LSpan := LPage.Number('document.getElementById("castle-canvas").clientHeight');
    LPage.Click('#tools-toggle');
    Check(LPage.Number('document.getElementById("castle-canvas").clientHeight') > LSpan + 100, 'Collapsing tools gives exploration space');
    LPage.Screenshot(LOutput + '/fly-tools-closed.png');
    LPage.Click('#tools-toggle');
    Check(LPage.Text('document.getElementById("tools-toggle").getAttribute("aria-expanded")') = 'true', 'Tools reopen accessibly');
    LPage.Click('#edit-toggle');
    Check(LPage.Text('phanesEditor.editing') = 'false', 'Explore is a separate mode');
    LState := LPage.Text('JSON.stringify(phanesEditor.world)');
    LPage.Execute('document.getElementById("castle-canvas").focus()');
    LPage.Key('g', 71);
    Check(LPage.Text('JSON.stringify(phanesEditor.world)') = LState, 'Explore G preserves world');
    LPage.Click('[data-camera="walk"]');
    Sample('4-walk');
    LPage.Screenshot(LOutput + '/walk-explore.png');
    CheckWalking;
    LPage.Resize(844, 390);
    LPage.Click('[data-camera="fly"]');
    LPage.Screenshot(LOutput + '/fly-landscape.png');
    Check(LPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true', 'Landscape has no page overflow');
    LPage.Resize(640, 360);
    LPage.Click('#tools-toggle');
    Check(LPage.Text('phanesEditor.editing') = 'false', 'Opening tools preserves Explore mode');
    Check(LPage.Number('document.getElementById("tools-panel").getBoundingClientRect().bottom') <= 360,
      'Open drawer fits short landscape vertically');
    Check(LPage.Text('document.getElementById("reimagine").disabled') = 'true',
      'Explore cannot apply regional edits through the drawer');
    LPage.Screenshot(LOutput + '/short-landscape-open.png');
    LPage.Click('#edit-toggle');
    Check(LPage.Text('phanesEditor.editing') = 'true', 'Short landscape can return to Create');
    LPage.Screenshot(LOutput + '/short-landscape-create.png');
    Check(LPage.Text('(()=>{const e=document.querySelector("[data-move=e]"),' +
      'r=e.getBoundingClientRect();return e.contains(document.elementFromPoint(' +
      'r.x+r.width/2,r.y+r.height/2))})()') = 'true', 'Rise remains touchable beside the open creation drawer');
    LInitial := LPage.Number('phanesEditor.y');
    LPage.Hold('[data-move="e"]', 700);
    Check(LPage.Number('phanesEditor.y') > LInitial + 0.3, 'Rise works while authoring in short landscape');
    LPage.Click('#open-groundworks');
    Check(LPage.Number('document.getElementById("groundwork-tools").getBoundingClientRect().width') > 170,
      'Groundwork tools keep a usable single-column drawer');
    LPage.Screenshot(LOutput + '/short-landscape-groundworks.png');
    LPage.Click('#leave-groundworks');
    LPage.Click('#edit-toggle');
    LPage.Execute('document.getElementById("castle-canvas").focus()');
    LPage.Key('Escape', 27);
    Check(LPage.Text('document.activeElement.id') = 'tools-toggle', 'Escape releases world focus to controls');
    LPage.Resize(360, 740);
    LPage.Click('[data-camera="fly"]');
    LPage.Click('#edit-toggle');
    LPage.Screenshot(LOutput + '/narrow-phone-create.png');
    Check(LPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true',
      'A 360-pixel phone keeps the authoring toolbar inside the screen');
    Check(LPage.Text('Array.from(document.querySelectorAll("[data-authoring-tool],#walk-controls button,#fly-controls button"))' +
      '.every(e=>{const r=e.getBoundingClientRect();return e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})') = 'true',
      'Every movement and authoring control is reachable on a narrow phone');
    LPage.Resize(390, 844, 3);
    LPage.SetValue('render-quality', 'balanced', 'change');
    Sleep(500);
    Check((LPage.Number('phanesRenderDensity') <= 2) and (LPage.Number('phanesRenderDensity') >= 1.5),
      'Balanced bounds high-density rendering without dropping below its sharpness floor');
    LPage.SetValue('render-quality', 'detail', 'change');
    Check(LPage.Number('phanesRenderDensity') = 3, 'Full detail restores device density');
    LPage.SetValue('render-quality', 'balanced', 'change');
    LPage.Click('#open-audio');
    Sleep(1000);
    LDraws := LPage.Number('phanesStyleProbeSnapshot().drawCalls');
    Sleep(1500);
    Check(LPage.Number('phanesStyleProbeSnapshot().drawCalls') = LDraws,
      'Covered world submits no WebGL draw calls');
    LPage.SetValue('music-tempo', '60');
    LPage.SetValue('music-tempo', '60', 'change');
    LPage.Click('#music-mobile-toggle');
    LPage.WaitFor('phanesAudioState.activeBpm===60 && phanesAudioState.scheduledEvents>0');
    LTrackId := LPage.Text('phanesAudioState.trackId');
    for I := 0 to 2 do
    begin
      case I of
        0: LState := '160';
        1: LState := '120';
        else LState := '145';
      end;
      LPage.SetValue('music-tempo', LState);
      LPage.SetValue('music-tempo', LState, 'change');
      Sleep(150);
    end;
    LPage.WaitFor('phanesAudioState.activeBpm===145 && !phanesAudioState.tempoPending', 15000);
    Check(LPage.Text('phanesAudioState.trackId') = LTrackId, 'Rapid BPM changes keep the track identity');
    Check(LPage.Number('phanesAudioState.workerStarts') = 1, 'BPM changes reuse the WFC worker');
    Check(LPage.Number('phanesAudioState.planExtensions') >= 1, 'Faster tempo admits an extended musical form');
    Check(LPage.Number('phanesAudioState.track.seconds') >= 304, 'Faster tempo preserves five-minute duration');
    Check(LPage.Number('phanesAudioState.droppedEvents') = 0, 'Tempo change drops no scheduled voices');
    Check(LPage.Number('phanesAudioState.lateEvents') = 0, 'Tempo changes schedule notes ahead of playback');
    Check(LPage.Number('phanesAudioState.underruns') = 0, 'Tempo changes preserve playback continuity');
    Check(LPage.Text('document.getElementById("music-bpm").textContent') = '145',
      'The requested BPM display stays consistent');
    WriteText(LOutput + '/audio.json', LPage.Text('JSON.stringify(phanesAudioState)'));
    LPage.Screenshot(LOutput + '/music-tempo.png');
    LPage.Click('#close-audio');
    LPage.WaitFor('phanesStyleProbeSnapshot().drawCalls>' + FloatToStr(LDraws));
    Check(True, 'World rendering resumes after leaving music');
    except
      on LException: Exception do
      begin
        LPage.Screenshot(LOutput + '/failure.png');
        WriteText(LOutput + '/failure-state.json', LPage.Text('JSON.stringify({' +
          'body:document.body.dataset,selection:phanesEditor.selection,' +
          'html:document.getElementById("tools-panel").innerHTML,' +
          'clear:document.getElementById("clear-region").getBoundingClientRect().toJSON()})'));
        raise;
      end;
    end;
  finally
    LPage.Free;
  end;
end.
