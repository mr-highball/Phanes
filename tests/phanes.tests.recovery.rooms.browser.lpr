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

program PhanesRecoveryRoomsBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils,
  FPJSON,
  phanes.tools.browser,
  phanes.tools.files;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GEvidence: TJSONObject;
  GChecks: TJSONArray;

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

procedure Check(const ACondition: Boolean; const AName: String);
begin
  GChecks.Add(TJSONObject.Create(['name', AName, 'passed', ACondition]));
  Require(ACondition, AName);
  WriteLn('PASS ', AName);
  Flush(Output);
end;

procedure ClickNode(const AId: String);
begin
  GPage.Click('#interior-children button[data-node=' + Quote(AId) + ']');
end;

function ReadStored: String;
begin
  Result := GPage.Text('new Promise((resolve,reject)=>{' +
    'const o=indexedDB.open("phanes-recovery",1);o.onerror=()=>reject(o.error);' +
    'o.onsuccess=()=>{const d=o.result,t=d.transaction(["sessions"],"readonly"),' +
    'r=t.objectStore("sessions").get(sessionStorage.getItem("phanes-session-key"));' +
    'r.onerror=()=>reject(r.error);r.onsuccess=()=>resolve(JSON.stringify(r.result));' +
    't.oncomplete=()=>d.close()}})');
  Require((Result <> '') and (Result <> 'null'), 'Missing native recovery checkpoint');
end;

procedure CheckLayouts;
begin
  Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true',
    'Named-room controls do not overflow the phone viewport');
  Check(GPage.Text('(()=>{const b=document.getElementById("interior-frame"),' +
    'r=b.getBoundingClientRect();return r.width>=44&&r.height>=44&&r.left>=0&&' +
    'r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight})()') = 'true',
    'Phone Look closer control remains a usable touch target');
  GPage.Screenshot(GOutput + '/named-lab-phone.png');
  GPage.Resize(1280, 900);
  Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true',
    'Recovered named-room controls do not overflow the desktop viewport');
  GPage.Screenshot(GOutput + '/named-lab-recovered-desktop.png');
end;

procedure RunJourney;
var
  LBeforeNodes: String;
  LFuture: String;
  LHistory: String;
  LInterior: String;
  LPickVersion: Double;
  LSelection: String;
  LStored: String;
  LTarget: String;
  LWorld: String;
  LBounds: TJSONObject;
begin
  GPage.WaitFor('document.body.dataset.startupState==="ready"', 180000);
  GPage.SetValue('region-size', '4');
  GPage.SetValue('world-seed', '732');
  GPage.Click('#create-world');
  GPage.WaitFor('phanesEditor.world&&!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection()');
  GPage.SetValue('selection-layer', '', 'change');
  GPage.Click('#clear-region');
  GPage.WaitFor('!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  { Mask indices address the entire world grid, not the bounding rectangle. }
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,' +
    'selectionScale:1,selectionCells:[5]};phanesEditorActions.syncSelection()');
  GPage.Click('[data-intent="cabin"]');
  GPage.Click('[data-catalog-group="cabin"]');
  GPage.Click('[data-catalog-asset="cabin"]');
  GPage.Click('#catalog-apply');
  GPage.WaitFor('!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Text('phanesEditor.world.layers[3][5]') = 'cabin',
    'Catalog Apply creates the selected cabin at world cell 5');
  Check(GPage.Text('!document.getElementById("design-rooms").disabled') = 'true',
    'A cabin created through the authoring control offers named-room design');
  GPage.Click('#design-rooms');
  GPage.Click('#space-layout-six');
  GPage.WaitFor('!phanesEditor.worker&&phanesEditor.interiorRoom==="building-1-1.plan"&&' +
    'phanesEditor.world.composition.nodes.filter(n=>n.role==="bay").length===6&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(True, 'The six-bay control publishes a rendered cabin plan');
  ClickNode('building-1-1.plan.bay-5');
  GPage.Click('#space-program-lab');
  GPage.WaitFor('!phanesEditor.worker&&' +
    'phanesEditor.world.composition.nodes.some(n=>n.id==="building-1-1.plan.bay-5.room"&&' +
    'n.asset==="phanes.space.laboratory.v1")&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Text('phanesEditor.interiorSelected') = 'building-1-1.plan.bay-5.room',
    'The laboratory control opens the named Bay 5 room');

  LTarget := GPage.Text('phanesEditor.world.composition.nodes.find(n=>' +
    'n.parent==="building-1-1.plan.bay-5.room"&&n.role==="bookcase").id');
  ClickNode(LTarget);
  ClickNode(LTarget + '.tier-2');
  LTarget := GPage.Text('phanesEditor.world.composition.nodes.find(n=>' +
    'n.parent===' + Quote(LTarget + '.tier-2') + ').id');
  ClickNode(LTarget);
  Check(GPage.Text('phanesEditor.interiorSelected') = LTarget,
    'A real nested shelf object is selected through the room controls');
  GPage.Click('#interior-frame');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'document.body.dataset.renderedInterior===phanesEditor.interiorRoom');

  { Make both history stacks nonempty, then return to the framed object. }
  GPage.Click('#interior-looks button[aria-pressed="false"]');
  GPage.WaitFor('!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  GPage.Click('#interior-undo');
  GPage.WaitFor('!phanesEditor.worker&&phanesEditor.future.length>0&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
  Check(GPage.Text('phanesEditor.history.length>0&&phanesEditor.future.length>0') = 'true',
    'The named-room checkpoint contains both Undo and Redo stacks');
  Check(GPage.Text('phanesEditor.interiorSelected') = LTarget,
    'Undo keeps the selected nested shelf object');

  { Choose a different object without moving the framed camera. The following
    canvas click must travel through the live pointer and Castle ray path. }
  GPage.Click('#interior-parent');
  Check(GPage.Text('phanesEditor.interiorSelected') <> LTarget,
    'Selecting the shelf tier changes selection without reframing the camera');
  LPickVersion := GPage.Number('phanesPickVersion');
  LBounds := TJSONObject(GPage.Evaluate(
    'document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
  try
    GPage.ClickAt(LBounds.Floats['x'] + LBounds.Floats['width'] / 2,
      LBounds.Floats['y'] + LBounds.Floats['height'] / 2);
  finally
    LBounds.Free;
  end;
  GPage.WaitFor('phanesPickVersion>' + FloatToStr(LPickVersion) + '&&' +
    'phanesEditor.interiorSelected===' + Quote(LTarget), 30000);
  Check(True, 'A fresh canvas pointer and rendered ray pick the framed nested object');

  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,' +
    'selectionScale:1,selectionCells:[0,5,10,15]};phanesEditorActions.syncSelection()');
  Check(GPage.Text('phanesEditor.selection.selectionCells.length') = '4',
    'The checkpoint uses a nonrectangular four-cell authoring mask');

  LWorld := GPage.Text('JSON.stringify(phanesEditor.world)');
  LHistory := GPage.Text('JSON.stringify(phanesEditor.history)');
  LFuture := GPage.Text('JSON.stringify(phanesEditor.future)');
  LSelection := GPage.Text('JSON.stringify(phanesEditor.selection)');
  LInterior := GPage.Text('JSON.stringify(phanesInteriorUI.snapshot())');
  GPage.Execute('window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('phanesSessionSaved===true&&' +
    'phanesSessionSavedRevision===phanesSessionSavingRevision', 30000);
  LStored := ReadStored;
  WriteText(GOutput + '/named-room-checkpoint.json', UTF8String(LStored));
  Check(GPage.Text('(()=>{const s=' + LStored + ';return JSON.stringify(s.world)===' +
    Quote(LWorld) + '&&JSON.stringify(s.history)===' + Quote(LHistory) +
    '&&JSON.stringify(s.future)===' + Quote(LFuture) +
    '&&JSON.stringify(s.selection)===' + Quote(LSelection) +
    '&&JSON.stringify(s.interior)===' + Quote(LInterior) + '})()') = 'true',
    'Native IndexedDB stores the exact named-room authoring checkpoint');

  Check(GPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Named-room authoring has no uncaught browser errors before graphics loss');
  GPage.Execute('window.phanesRecoveryRoomsOldPage=true;phanesStyleProbeLoseContext()');
  GPage.WaitFor('document.body.dataset.rendererState==="ready"&&!phanesRecovering&&' +
    'typeof phanesRecoveryRoomsOldPage==="undefined"&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion&&' +
    'phanesRenderedCameraVersion===phanesCameraVersion', 180000);
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') = LWorld,
    'Graphics recovery restores the exact six-bay laboratory world');
  Check(GPage.Text('JSON.stringify(phanesEditor.history)') = LHistory,
    'Graphics recovery restores the exact Undo stack');
  Check(GPage.Text('JSON.stringify(phanesEditor.future)') = LFuture,
    'Graphics recovery restores the exact Redo stack');
  Check(GPage.Text('JSON.stringify(phanesEditor.selection)') = LSelection,
    'Graphics recovery restores the nontrivial authoring selection');
  Check(GPage.Text('JSON.stringify(phanesInteriorUI.snapshot())') = LInterior,
    'Graphics recovery restores the exact named-room and nested-object context');
  Check(GPage.Text('phanesStyleProbeSnapshot().errors.length===0') = 'true',
    'Named-room graphics recovery has no uncaught browser errors');

  { Prove the restored camera/object relation is freshly pickable. }
  GPage.Click('#interior-parent');
  Check(GPage.Text('phanesEditor.interiorSelected') <> LTarget,
    'Recovered tier selection changes without reframing the restored camera');
  LPickVersion := GPage.Number('phanesPickVersion');
  LBounds := TJSONObject(GPage.Evaluate(
    'document.getElementById("castle-canvas").getBoundingClientRect().toJSON()'));
  try
    GPage.ClickAt(LBounds.Floats['x'] + LBounds.Floats['width'] / 2,
      LBounds.Floats['y'] + LBounds.Floats['height'] / 2);
  finally
    LBounds.Free;
  end;
  GPage.WaitFor('phanesPickVersion>' + FloatToStr(LPickVersion) + '&&' +
    'phanesEditor.interiorSelected===' + Quote(LTarget), 30000);
  Check(True, 'After recovery, a fresh rendered pointer/ray pick selects the intended object');

  LBeforeNodes := GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + Quote(LTarget) + '))');
  GPage.Click('#interior-looks button[aria-pressed="false"]');
  GPage.WaitFor('!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + Quote(LTarget) + '))') = LBeforeNodes,
    'A continued local object edit preserves every unrelated composition node');
  CheckLayouts;
end;

procedure Run;
var
  LGuid: TGuid;
  LProbe: UTF8String;
  LProfile: String;
begin
  Require(ParamCount = 4,
    'Usage: recovery-rooms BROWSER URL EVIDENCE STYLE-PROBE');
  GOutput := ExpandFileName(ParamStr(3));
  Require(not DirectoryExists(GOutput), 'Use a fresh evidence directory');
  ForceDirectories(GOutput);
  CreateGUID(LGuid);
  LProfile := GOutput + '/profile-' + GUIDToString(LGuid);
  GEvidence := TJSONObject.Create(['url', ParamStr(2),
    'driverBinarySha256', HashFile(ParamStr(0)),
    'styleProbeSha256', HashFile(ParamStr(4)),
    'method', 'Pascal WFC CDP, real IndexedDB, WebGL loss and rendered picking']);
  GChecks := TJSONArray.Create;
  GEvidence.Add('checks', GChecks);
  GPage := TBrowserProbe.Create(ParamStr(1), LProfile);
  try
    try
      LProbe := ReadText(ParamStr(4));
      if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
        (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
      begin
        Delete(LProbe, 1, 3);
      end;
      GPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
      GPage.Resize(390, 844, 3);
      GPage.Navigate(ParamStr(2));
      RunJourney;
      GEvidence.Add('metrics', GetJSON(GPage.Text(
        'JSON.stringify(phanesStyleProbeSnapshot())'), True));
      GEvidence.Add('success', True);
    except
      on LException: Exception do
      begin
        GEvidence.Add('success', False);
        GEvidence.Add('failure', LException.Message);
        try
          GPage.Screenshot(GOutput + '/failure.png');
          WriteText(GOutput + '/failure-state.txt',
            UTF8String(GPage.Text('document.body.innerText')));
          WriteText(GOutput + '/failure-debug.json', UTF8String(GPage.Text(
            'JSON.stringify({selected:phanesEditor?.interiorSelected,' +
            'room:phanesEditor?.interiorRoom,pickVersion:phanesPickVersion,' +
            'pickAction:phanesPickAction,errors:phanesStyleProbeSnapshot().errors})')));
        except
          on Exception do
          begin
          end;
        end;
        raise;
      end;
    end;
  finally
    WriteText(GOutput + '/evidence.json', GEvidence.FormatJSON);
    GPage.Free;
    GEvidence.Free;
  end;
end;

begin
  Run;
end.
