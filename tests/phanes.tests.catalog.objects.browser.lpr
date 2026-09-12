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
program PhanesCatalogObjectsBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files, phanes.catalog.admission;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GChecks: Integer;

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

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  Require(ACondition, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

procedure Settled;
begin
  GPage.WaitFor('!phanesEditor.worker&&!window.phanesCatalogLoading&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

procedure ChooseNode(const AId: String);
var
  LPath: TJSONArray;
  I: Integer;
begin
  LPath := TJSONArray(GPage.Evaluate('(()=>{const a=[],ns=phanesEditor.world.composition.nodes;' +
    'let n=ns.find(n=>n.id===' + Quote(AId) + ');while(n&&n.id!==phanesEditor.interiorRoom)' +
    '{a.unshift(n.id);n=ns.find(p=>p.id===n.parent)}return a})()'));
  try
    GPage.Click('#interior-path button[data-node="building-1-1.studio"]');
    for I := 0 to LPath.Count - 1 do
    begin
      GPage.Click('#interior-children button[data-node=' + Quote(LPath.Strings[I]) + ']');
    end;
  finally
    LPath.Free;
  end;
  Check(GPage.Text('phanesEditor.interiorSelected') = AId,
    'Breadcrumb and child controls select the intended nested object');
end;

procedure ChooseAsset(const AId: String);
var
  LRevision: Integer;
begin
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#interior-looks button[data-asset=' + Quote(AId) + ']');
  GPage.WaitFor('phanesSceneVersion>' + IntToStr(LRevision) +
    '&&!phanesEditor.worker&&!window.phanesCatalogLoading&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

procedure Run;
var
  LIds: TOptionalAssetIds;
  LAdmission: TOptionalAssetAdmission;
  LTarget: String;
  LBefore: String;
  LAfter: String;
  LOther: String;
  LMask: String;
  LCore: String;
  LStyles: UTF8String;
  LCount: Integer;
  I: Integer;
begin
  LStyles := ReadText(ParamStr(4));
  if (Length(LStyles) >= 3) and (Ord(LStyles[1]) = $EF) and
    (Ord(LStyles[2]) = $BB) and (Ord(LStyles[3]) = $BF) then
  begin
    Delete(LStyles, 1, 3);
  end;
  GPage.InstallScript('(()=>{' + String(LStyles) + #10 + 'rtl.run();})();');
  GPage.Resize(1280, 900);
  GPage.Navigate(ParamStr(2));
  GPage.WaitFor('document.body.dataset.startupState==="ready"', 180000);
  GPage.SetValue('region-size', '4');
  GPage.SetValue('world-seed', '732');
  GPage.Click('#create-world');
  GPage.WaitFor('!!phanesEditor.world&&!phanesEditor.worker', 180000);
  Settled;
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection()');
  GPage.Click('#clear-region');
  Settled;
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};' +
    'phanesEditorActions.syncSelection()');
  GPage.Click('[data-intent="cabin"]');
  GPage.Click('[data-catalog-group="cabin"]');
  GPage.Click('[data-catalog-asset="cabin"]');
  GPage.Click('#catalog-apply');
  Settled;
  Check(GPage.Text('phanesEditor.world.layers[3][5]') = 'cabin', 'Catalog Apply creates the cabin');
  GPage.Click('#open-interior');
  GPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio"&&' +
    'Number(document.body.dataset.renderedInteriorScene)===phanesSceneVersion', 180000);

  LIds := OptionalAssetIds;
  LCount := 0;
  for I := 0 to High(LIds) do
  begin
    Require(OptionalAssetAdmission(LIds[I], LAdmission), 'Missing admission');
    if LAdmission.FDomain <> oadInterior then
    begin
      Continue;
    end;
    if Odd(LCount) then
    begin
      GPage.Resize(390, 844, 2);
    end else
    begin
      GPage.Resize(1280, 900);
    end;
    LTarget := GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.role===' +
      Quote(LAdmission.FRole) + '&&!!n.support).id');
    ChooseNode(LTarget);
    GPage.SetValue('interior-category', '', 'change');
    GPage.SetValue('interior-group', '', 'change');
    GPage.SetValue('interior-search', '');
    if GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
      Quote(LTarget) + ').asset') = LIds[I] then
    begin
      LCore := GPage.Text('document.querySelector(' +
        Quote('#interior-looks button[aria-pressed="false"]') + ').dataset.asset');
      ChooseAsset(LCore);
    end;
    LBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
    LMask := GPage.Text('JSON.stringify(phanesEditor.selection)');
    LOther := GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(n=>n.id!==' +
      Quote(LTarget) + '))');
    GPage.SetValue('interior-category', LAdmission.FCategory, 'change');
    GPage.SetValue('interior-group', LAdmission.FSubcategory, 'change');
    GPage.SetValue('interior-search', 'no-such-object-phantom');
    Check(GPage.Number('document.querySelectorAll("#interior-looks button").length') = 0,
      'An unmatched search has an explicit empty result');
    Check(GPage.Text('document.getElementById("interior-choice-count").textContent.includes("No matches")') = 'true',
      'Empty search gives useful feedback');
    GPage.SetValue('interior-search', String(LAdmission.FName));
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LBefore,
      'Category, subgroup and search leave the world unchanged');
    Check(GPage.Text('!!document.querySelector(' + Quote('#interior-looks button[data-asset="' +
      LIds[I] + '"]') + ')') = 'true', 'The exact admitted item is discoverable');
    Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true',
      'Object navigation fits the active viewport');
    Check(GPage.Text('["interior-category","interior-group","interior-search"].every(id=>{' +
      'const r=document.getElementById(id).getBoundingClientRect();' +
      'return r.height>=44&&r.width>100&&r.left>=0&&r.right<=innerWidth})') = 'true',
      'Every catalog filter has a full-width touch target');
    GPage.Execute('document.getElementById("interior-catalog").scrollIntoView({block:"start"})');
    GPage.Screenshot(GOutput + '/choice-' + IntToStr(LCount) + '.png');
    ChooseAsset(LIds[I]);
    Check(GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' + Quote(LTarget) +
      ').asset') = LIds[I], 'The selected optional object is rendered: ' + LIds[I]);
    Check(GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(n=>n.id!==' +
      Quote(LTarget) + '))') = LOther, 'Every unrelated composition node remains exact');
    Check(GPage.Text('JSON.stringify(phanesEditor.selection)') = LMask,
      'The regional authoring selection remains exact');
    Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).includes(' + Quote(LIds[I]) + ')') = 'true',
      'Castle holds the selected optional source lease');
    LAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
    GPage.Click('#interior-frame');
    GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
    GPage.WaitFor('document.getElementById("toast").hidden', 15000);
    GPage.Screenshot(GOutput + '/object-' + IntToStr(LCount) + '.png');
    WriteText(GOutput + '/object-' + IntToStr(LCount) + '.json', UTF8String(LAfter));
    GPage.Click('#interior-undo');
    Settled;
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LBefore, 'Undo restores the exact prior world');
    GPage.Click('#interior-redo');
    Settled;
    Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LAfter, 'Redo restores the exact admitted world');
    Inc(LCount);
  end;
  Check(LCount = 14, 'All fourteen interior admissions have rendered application journeys');
  Check(GPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'All object journeys have no uncaught browser errors');
  Check(GPage.Text('phanesStyleProbeSnapshot().shaderFailures.length===0') = 'true',
    'All object material shaders compile successfully');
  WriteText(GOutput + '/before-recovery-metrics.json', UTF8String(GPage.Text(
    'JSON.stringify(phanesStyleProbeSnapshot())')));
  LAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
  GPage.Execute('window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('phanesSessionSaved===true', 30000);
  GPage.Execute('window.phanesObjectsOldPage=true;phanesStyleProbeLoseContext()');
  GPage.WaitFor('typeof phanesObjectsOldPage==="undefined"&&' +
    'document.body.dataset.rendererState==="ready"&&!phanesRecovering&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LAfter,
    'Graphics recovery restores the exact world containing the expanded catalog');
  Check(GPage.Text('phanesStyleProbeSnapshot().errors.length===0&&' +
    'phanesStyleProbeSnapshot().shaderFailures.length===0') = 'true',
    'Recovered optional sources render without browser or shader errors');
  GPage.Screenshot(GOutput + '/recovered.png');
  WriteText(GOutput + '/final-metrics.json', UTF8String(GPage.Text(
    'JSON.stringify(phanesStyleProbeSnapshot())')));
end;

begin
  Require(ParamCount = 4, 'Usage: catalog-objects BROWSER URL EVIDENCE STYLE-PROBE');
  GOutput := ExpandFileName(ParamStr(3));
  Require(not DirectoryExists(GOutput), 'Use a fresh evidence directory');
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
      Run;
      WriteText(GOutput + '/result.txt', 'PASS ' + IntToStr(GChecks) + ' checks' + #10);
    except
      on LException: Exception do
      begin
        WriteText(GOutput + '/failure.txt', UTF8String(LException.Message + #10 +
          GPage.Text('document.body.innerText')));
        GPage.Screenshot(GOutput + '/failure.png');
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
