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


program PhanesAuthoringBrowserTests;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GBefore: String;
  GRevision: Integer;
  GProbe: UTF8String;
  I: Integer;

procedure Check(const APass: Boolean; const AMessage: String);
begin
  Require(APass, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

function WorldPoint(const AX, AY: Double): TJSONObject;
var
  LBounds: TJSONObject;
begin
  LBounds := TJSONObject(GPage.Evaluate('document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
  try
    Result := TJSONObject.Create(['x', LBounds.Floats['x'] + AX * LBounds.Floats['width'],
      'y', LBounds.Floats['y'] + AY * LBounds.Floats['height'], 'id', 1]);
  finally
    LBounds.Free;
  end;
end;

procedure TapLand(const AX, AY: Double);
var
  LPoint: TJSONObject;
begin
  LPoint := WorldPoint(AX, AY);
  try
    GPage.ClickAt(LPoint.Floats['x'], LPoint.Floats['y']);
  finally
    LPoint.Free;
  end;
  GPage.WaitFor('!phanesAuthoringBusy', 15000);
end;

procedure Stroke(const AX, AY, ABX, ABY: Double);
begin
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(AX, AY)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(ABX, ABY)]));
  GPage.Touch('touchEnd', TJSONArray.Create);
  GPage.WaitFor('!phanesAuthoringBusy', 15000);
end;

procedure Lasso;
begin
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(0.38, 0.43)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.63, 0.43)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.63, 0.65)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.38, 0.65)]));
  GPage.Touch('touchEnd', TJSONArray.Create);
  GPage.WaitFor('!phanesAuthoringBusy', 15000);
end;

procedure CheckGestures;
var
  LBefore: String;
  LSelection: String;
  LCamera: String;
  I: Integer;
begin
  LBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
  for I := 0 to 3 do
  begin
    case I of
      0: LCamera := 'top';
      1: LCamera := 'orbit';
      2: LCamera := 'fly';
      else LCamera := 'walk';
    end;
    GPage.Click('[data-camera="' + LCamera + '"]');
    GPage.Click('[data-authoring-tool="brush"]');
    GPage.Click('#selection-clear');
    Stroke(0.40, 0.50, 0.61, 0.63);
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
      'Brush marks land in ' + LCamera);
    GPage.Screenshot(GOutput + '/brush-' + LCamera + '.png');
    GPage.Click('[data-authoring-tool="lasso"]');
    GPage.Click('#selection-clear');
    Lasso;
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 0,
      'Lasso selects touched land cells in ' + LCamera);
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LBefore,
      'Drawing a lasso in ' + LCamera + ' never edits the world');
    GPage.Screenshot(GOutput + '/lasso-' + LCamera + '.png');
  end;
  GPage.Click('[data-camera="top"]');
  GPage.Click('[data-authoring-tool="lasso"]');
  Lasso;
  Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 1,
    'Closed lasso selects multiple fine cells');
  LSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(0.4, 0.5)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.6, 0.6)]));
  GPage.Touch('touchCancel', TJSONArray.Create);
  Check((GPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection) and
    (GPage.Text('phanesAuthoringBusy') = 'false'), 'Cancelled gesture preserves the old selection');
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(0.4, 0.5)]));
  GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.6, 0.6)]));
  GPage.Key('Escape', 27);
  GPage.Touch('touchEnd', TJSONArray.Create);
  Check((GPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection) and
    (GPage.Text('phanesAuthoringBusy') = 'false'), 'Escape and subsequent release cannot publish a cancelled gesture');
  GPage.Click('[data-authoring-tool="point"]');
  TapLand(0.45, 0.48);
  Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 1,
    'A fresh selection works immediately after cancellation');
  GPage.Click('#open-groundworks');
  GPage.Click('#leave-groundworks');
  Check(GPage.Text('document.getElementById("selection-scale").value') = '1',
    'Returning from plot tools synchronizes selection precision');
  GPage.SetValue('selection-scale', '2', 'change');
  GPage.Click('[data-catalog-asset="nature-kit/tree_oak"]');
  Check((GPage.Text('document.activeElement.id') = 'catalog-choice') and
    (GPage.Text('document.getElementById("catalog-apply").disabled') = 'true'),
    'An item chosen before selecting land retains an accessible focus target');
  GPage.Click('#catalog-back');
  Check(GPage.Text('document.getElementById("catalog-confirm").hidden') = 'true',
    'Navigating to another catalog branch clears the former item intent');
  GPage.Click('[data-catalog-landscape="forest"]');
  GPage.SetValue('selection-layer', 'foliage', 'change');
  TapLand(0.45, 0.48);
  GPage.Execute('window.phanesAuthoringBaseline=JSON.stringify(phanesEditor.world)');
  GRevision := Round(GPage.Number('phanesSceneVersion'));
  GPage.Click('#catalog-apply');
  GPage.WaitFor('phanesSceneVersion===' + IntToStr(GRevision + 1) + ' && !phanesEditor.worker', 30000);
  Check(GPage.Text('phanesEditor.world.layers.every((layer,l)=>layer.every((v,i)=>' +
    '((l===2||l===4)&&phanesEditor.selection.selectionCells.includes(i))||v===JSON.parse(phanesAuthoringBaseline).layers[l][i]))') = 'true',
    'Compose forest respects the subsequently chosen foliage-only scope');
  GPage.SetValue('selection-scale', '1', 'change');
  TapLand(0.45, 0.48);
  GPage.Click('[data-catalog-group="tree"]');
  GPage.Click('[data-catalog-asset="nature-kit/tree_oak"]');
  GPage.SetValue('selection-layer', 'terrain', 'change');
  Check(GPage.Text('document.getElementById("catalog-apply").disabled') = 'true',
    'An exact tree cannot silently override a terrain-only scope');
  GPage.SetValue('selection-layer', 'foliage', 'change');
  Check(GPage.Text('document.getElementById("catalog-apply").disabled') = 'false',
    'Restoring a compatible scope enables the chosen item');
  LSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
  GPage.Click('[data-authoring-tool="lasso"]');
  GPage.Touch('touchStart', TJSONArray.Create([WorldPoint(0.4, 0.5)]));
  for I := 0 to 63 do
  begin
    GPage.Touch('touchMove', TJSONArray.Create([WorldPoint(0.4 + (I mod 2) * 0.2, 0.5 + (I mod 3) * 0.025)]));
  end;
  GPage.Touch('touchEnd', TJSONArray.Create);
  Check(GPage.Text('phanesAuthoringBusy') = 'true', 'A released multi-point stroke has pending terrain rays');
  GPage.Click('#open-audio');
  Check(GPage.Text('phanesAuthoringBusy') = 'false', 'Opening Music cancels pending terrain rays');
  GPage.Click('#close-audio');
  Sleep(400);
  Check(GPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
    'Returning from Music cannot publish the former stroke');
end;

procedure RunPascal(const APath: String);
var
  LCode: UTF8String;
begin
  LCode := UTF8String(ReadText(APath));
  if (Length(LCode) >= 3) and (Ord(LCode[1]) = $EF) and
    (Ord(LCode[2]) = $BB) and (Ord(LCode[3]) = $BF) then
  begin
    Delete(LCode, 1, 3);
  end;
  GPage.Execute('(()=>{' + String(LCode) + #10 + 'rtl.run();})();');
end;

begin
  Require(ParamCount = 3, 'Usage: authoring-checks BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
    GProbe := UTF8String(ReadText('build/phanes.tests.styles.probe.js'));
    if (Length(GProbe) >= 3) and (Ord(GProbe[1]) = $EF) and
      (Ord(GProbe[2]) = $BB) and (Ord(GProbe[3]) = $BF) then
    begin
      Delete(GProbe, 1, 3);
    end;
    GPage.InstallScript('(()=>{' + String(GProbe) + #10 + 'rtl.run();})();');
    GPage.Resize(390, 844);
    GPage.Navigate(ParamStr(2));
    GPage.WaitFor('document.body.dataset.ready==="true"');
    GPage.SetValue('region-size', '4');
    GPage.Click('#create-world');
    GPage.WaitFor('document.body.dataset.renderedRevision==="1"');
    GPage.Screenshot(GOutput + '/phone-start.png');
    GPage.SetValue('selection-scale', '2', 'change');
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 0, 'Changing precision requires a fresh explicit selection');
    TapLand(0.45, 0.48);
    GPage.Screenshot(GOutput + '/phone-selected.png');
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 1, 'Phone tap selects one fine cell');
    GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
    GPage.Click('[data-intent="forest"]');
    GPage.WaitFor('!!document.querySelector("[data-catalog-group=tree]")', 3000);
    GPage.Click('[data-catalog-group="tree"]');
    GPage.Click('[data-catalog-asset="nature-kit/tree_oak"]');
    GPage.Screenshot(GOutput + '/phone-oak.png');
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GBefore, 'Category, subcategory and item browsing never generate');
    Check(GPage.Text('document.getElementById("catalog-choice").textContent.includes("Oak")') = 'true',
      'Exact item choice is visible before applying');
    GPage.Execute('window.phanesAuthoringBaseline=JSON.stringify(phanesEditor.world)');
    GRevision := Round(GPage.Number('phanesSceneVersion'));
    GPage.Click('#catalog-apply');
    GPage.WaitFor('phanesSceneVersion===' + IntToStr(GRevision + 1) + ' && !phanesEditor.worker', 30000);
    Check(GPage.Text('phanesEditor.selection.selectionCells.every(i=>phanesEditor.world.layers[4][i]==="nature-kit/tree_oak")') = 'true',
      'The selected cell receives the exact oak model');
    Check(GPage.Text('phanesEditor.world.layers.every((layer,l)=>layer.every((v,i)=>' +
      '((l===2||l===4)&&phanesEditor.selection.selectionCells.includes(i))||v===JSON.parse(phanesAuthoringBaseline).layers[l][i]))') = 'true',
      'All unselected cells and unrelated layers remain byte-for-byte equal');
    GPage.Screenshot(GOutput + '/phone-applied.png');
    GPage.SetValue('selection-combine', 'add', 'change');
    TapLand(0.57, 0.55);
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 2, 'Add gesture keeps separate selected islands');
    GPage.SetValue('selection-combine', 'subtract', 'change');
    TapLand(0.57, 0.55);
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 1, 'Subtract gesture preserves the other island');
    GPage.SetValue('selection-combine', 'replace', 'change');
    GPage.Click('[data-authoring-tool="box"]');
    Stroke(0.37, 0.40, 0.64, 0.64);
    Check(GPage.Number('phanesEditor.selection.selectionCells.length') > 1, 'A quick box retains its press and release anchors');
    GPage.Screenshot(GOutput + '/phone-box.png');
    GPage.Click('[data-authoring-tool="point"]');
    for I := 0 to 2 do
    begin
      case I of
        0: GBefore := 'orbit';
        1: GBefore := 'fly';
        else GBefore := 'walk';
      end;
      GPage.Click('[data-camera="' + GBefore + '"]');
      GPage.Click('#selection-clear');
      TapLand(0.5, 0.55);
      GPage.Screenshot(GOutput + '/phone-' + GBefore + '-selection.png');
      Check(GPage.Number('phanesEditor.selection.selectionCells.length') = 1,
        'Land selection works in ' + GBefore);
    end;
    GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
    GPage.Click('#edit-toggle');
    TapLand(0.5, 0.55);
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GBefore, 'Explore input preserves the world');
    GPage.Resize(1280, 800);
    GPage.Click('#edit-toggle');
    GPage.Click('[data-camera="top"]');
    GPage.Screenshot(GOutput + '/desktop-authoring.png');
    Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true', 'Desktop authoring stays within the viewport');
    CheckGestures;
    RunPascal('build/phanes.tests.selection.js');
    Check(GPage.Number('phanesSelectionChecks') >= 535, 'Independent selection and plot tests also pass in pas2js');
    GPage.Execute('window.phanesTestBase = new URL(".", location.href).href');
    RunPascal('build/phanes.tests.audio.js');
    GPage.WaitFor('phanesAudioTests.completed', 120000);
    WriteText(GOutput + '/audio-protocol.json', GPage.Text('JSON.stringify(phanesAudioTests)'));
    Check(GPage.Text('phanesAudioTests.passed') = 'true', 'Music worker accepts extensions without shortening or altering an idempotent plan');
    WriteText(GOutput + '/probe.json', GPage.Text('JSON.stringify(phanesStyleProbeSnapshot())'));
    except
      on LException: Exception do
      begin
        GPage.Screenshot(GOutput + '/failure.png');
        WriteText(GOutput + '/failure-state.json', GPage.Text('JSON.stringify({' +
          'probe:phanesStyleProbeSnapshot(),selection:phanesEditor.selection,' +
          'body:document.body.dataset,html:document.getElementById("tools-panel").innerHTML})'));
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
