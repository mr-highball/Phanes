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
program PhanesCatalogWorldBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

const
  BookAsset = 'phanes.catalog.book.kaykit-single.v1';
  VaseAsset = 'phanes.catalog.vase.quaternius.v1';
  NativeBookAsset = 'phanes.book.sage.v1';
  NativeOrnamentAsset = 'phanes.snail.ivory.v1';

var
  GPage: TBrowserProbe;
  GEvidence: String;
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  Inc(GChecks);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

function JSString(const AValue: String): String;
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

procedure WaitForRevision(const ARevision: Integer);
begin
  GPage.WaitFor('phanesSceneVersion>' + IntToStr(ARevision) +
    '&&!phanesEditor.worker&&!window.phanesCatalogLoading&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

function World: String;
begin
  Result := GPage.Text('JSON.stringify(phanesEditor.world)');
end;

function History: String;
begin
  Result := GPage.Text('JSON.stringify(phanesEditor.history)');
end;

function Selection: String;
begin
  Result := GPage.Text('JSON.stringify(phanesEditor.selection)');
end;

procedure ChooseNode(const AId: String);
begin
  GPage.Execute('phanesInteriorUI.choose(' + JSString(AId) + ',true)');
  GPage.WaitFor('phanesEditor.interiorSelected===' + JSString(AId) +
    '&&phanesRenderedCameraVersion===phanesCameraVersion');
end;

procedure ReplaceAsset(const ANodeId, AAssetId: String);
var
  LRevision: Integer;
  LSelector: String;
begin
  ChooseNode(ANodeId);
  LSelector := '[data-asset="' + AAssetId + '"]';
  Check(GPage.Text('!!document.querySelector(' + JSString(LSelector) + ')') = 'true',
    'Replacement appears in the actual object controls');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click(LSelector);
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
    JSString(ANodeId) + ').asset') = AAssetId, 'Object replacement publishes the chosen asset');
end;

procedure GenerateReplacement(const ANodeId, AAssetId: String);
var
  LRevision: Integer;
begin
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("contents",null,{objectId:' +
    JSString(ANodeId) + ',contentAsset:' + JSString(AAssetId) + '})');
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
    JSString(ANodeId) + ').asset') = AAssetId,
    'Validated modular replacement publishes the chosen asset');
end;

procedure CheckResidentStats(const ARequireModels: Boolean);
var
  LExpression: String;
begin
  LExpression := '(()=>{const s=JSON.parse(phanesCatalogResidentStats);return ' +
    'Number.isInteger(s.models)&&Number.isInteger(s.sourceBytes)&&' +
    'Number.isInteger(s.vertices)&&Number.isInteger(s.triangles)&&' +
    'Number.isInteger(s.texturePixels)&&s.sourceLimit===16777216&&' +
    's.vertexLimit===250000&&s.triangleLimit===50000&&' +
    's.texturePixelLimit===4194304&&s.modelLimit===32&&' +
    's.sourceBytes<=s.sourceLimit&&s.vertices<=s.vertexLimit&&' +
    's.triangles<=s.triangleLimit&&s.texturePixels<=s.texturePixelLimit&&' +
    's.models<=s.modelLimit';
  if ARequireModels then
  begin
    LExpression := LExpression + '&&s.models>=1&&s.sourceBytes>0&&s.vertices>0&&' +
      's.triangles>0&&s.texturePixels>=0';
  end;
  LExpression := LExpression + '})()';
  Check(GPage.Text(LExpression) = 'true', 'Resident statistics expose usage and enforced limits');
end;

procedure Run;
var
  LProbe: UTF8String;
  LBook: String;
  LVase: String;
  LReplacement: String;
  LUnaffected: String;
  LFinal: String;
  LUndo: String;
  LRevision: Integer;
  LWorld: String;
  LHistory: String;
  LSelection: String;
  LFailedWorld: String;
  LFailedHistory: String;
  LFailedSelection: String;
  LTarget: String;
  LFuture: String;
  LSettled: Integer;
begin
  LProbe := UTF8String(ReadText('build/catalog-world-probe/' +
    'phanes.tests.catalog.world.probe.js'));
  if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
    (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
  begin
    Delete(LProbe, 1, 3);
  end;
  GPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
  GPage.InstallScript('window.catalogWorldErrors=[];' +
    'addEventListener("error",e=>catalogWorldErrors.push(e.message));' +
    'addEventListener("unhandledrejection",e=>catalogWorldErrors.push(String(e.reason)))');
  GPage.Resize(1280, 900);
  GPage.Navigate(ParamStr(2));
  GPage.WaitFor('document.body.dataset.startupState==="ready"&&' +
    '!!window.phanesCatalogRuntime&&typeof phanesCatalogResidentStats==="string"', 180000);
  GPage.SetValue('region-size', '4');
  GPage.Click('#create-world');
  GPage.WaitFor('!!phanesEditor.world&&!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Number('phanesEditor.world.size') = 4, 'Actual Create world UI publishes a 4 by 4 world');

  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};' +
    'phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("cabin")');
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.layers[3][5]') = 'cabin',
    'Validated generation places the requested cabin');
  GPage.Click('#open-interior');
  GPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio"&&' +
    'Number(document.body.dataset.renderedInteriorScene)===phanesSceneVersion', 180000);
  Check(GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.role==="book"&&!!n.support).length') > 0,
    'Generated studio exposes a supported book');
  Check(GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.role==="ornament"&&!!n.support).length') > 0,
    'Generated studio exposes a supported ornament');

  LBook := GPage.Text('phanesEditor.world.composition.nodes.find(' +
    'n=>n.role==="book"&&!!n.support).id');
  if GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
    JSString(LBook) + ').asset') = BookAsset then
  begin
    ReplaceAsset(LBook, NativeBookAsset);
  end;
  LUnaffected := GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + JSString(LBook) + '))');
  ReplaceAsset(LBook, BookAsset);
  Check(GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + JSString(LBook) + '))') = LUnaffected,
    'Book replacement preserves every unaffected composition node exactly');

  LVase := GPage.Text('phanesEditor.world.composition.nodes.find(' +
    'n=>n.role==="ornament"&&!!n.support).id');
  if GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
    JSString(LVase) + ').asset') = VaseAsset then
  begin
    ReplaceAsset(LVase, NativeOrnamentAsset);
  end;
  LUnaffected := GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + JSString(LVase) + '))');
  ReplaceAsset(LVase, VaseAsset);
  Check(GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes.filter(' +
    'n=>n.id!==' + JSString(LVase) + '))') = LUnaffected,
    'Vase replacement preserves every unaffected composition node exactly');
  Check(GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.asset===' + JSString(BookAsset) + ').length') >= 1,
    'Published world contains the selected catalog book');
  Check(GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.asset===' + JSString(VaseAsset) + ').length') >= 1,
    'Published world contains the selected catalog vase');
  CheckResidentStats(True);
  WriteTextAtomic(GEvidence + '/resident-both.json', GPage.Text('phanesCatalogResidentStats'));
  ChooseNode(LVase);
  GPage.WaitFor('document.getElementById("toast").hidden');
  GPage.Screenshot(GEvidence + '/focused-vase-desktop.png');
  GPage.Resize(390, 844, 2);
  GPage.Screenshot(GEvidence + '/focused-vase-phone.png');

  LFinal := World;
  LHistory := History;
  LSelection := Selection;
  Check(GPage.Number('catalogWorldErrors.length') = 0,
    'Optional-world publication has no browser errors before reload');
  GPage.Execute('window.catalogWorldSaved=window.phanesSessionSavingRevision||0;' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSaved===true&&' +
    'window.phanesSessionSavedRevision>window.catalogWorldSaved');
  GPage.Execute('location.reload()');
  GPage.WaitFor('!!window.phanesEditor?.world&&!window.phanesRecovering&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(World = LFinal, 'Saved-session reload restores the exact optional world');
  Check(History = LHistory, 'Saved-session reload restores optional-world edit history');
  Check(Selection = LSelection, 'Saved-session reload restores optional-world selection');
  CheckResidentStats(True);

  LUndo := GPage.Text('JSON.stringify(phanesEditor.history[phanesEditor.history.length-1])');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#interior-undo');
  WaitForRevision(LRevision);
  Check(World = LUndo, 'Interior Undo restores the exact prior world snapshot');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#interior-redo');
  WaitForRevision(LRevision);
  Check(World = LFinal, 'Interior Redo restores the exact catalog world snapshot');

  while GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.asset.startsWith("phanes.catalog.")).length') > 0 do
  begin
    LBook := GPage.Text('phanesEditor.world.composition.nodes.find(' +
      'n=>n.asset.startsWith("phanes.catalog.")).id');
    { Generated rooms can now contain catalog food as well as books and vases.
      Retire each through a compatible core choice exposed by the actual UI. }
    ChooseNode(LBook);
    LReplacement := GPage.Text('Array.from(document.querySelectorAll(' +
      '"#interior-looks button[data-asset]")).find(b=>' +
      '!b.dataset.asset.startsWith("phanes.catalog."))?.dataset.asset||""');
    Check(LReplacement <> '', 'Optional object exposes a compatible core replacement');
    ReplaceAsset(LBook, LReplacement);
  end;
  GPage.WaitFor('JSON.parse(phanesCatalogResidentStats).models===0&&' +
    'JSON.parse(phanesCatalogReadyIds).length===0', 180000);
  Check(GPage.Text('!phanesEditor.world.composition.nodes.some(' +
    'n=>n.asset.startsWith("phanes.catalog."))') = 'true',
    'Real object edits remove every optional model from the world');
  CheckResidentStats(False);
  Check(GPage.Text('JSON.parse(phanesCatalogResidentStats).sourceBytes===0&&' +
    'JSON.parse(phanesCatalogResidentStats).closureSourceBytes===0&&' +
    'JSON.parse(phanesCatalogResidentStats).sourceNamespaces===0&&' +
    'JSON.parse(phanesCatalogResidentStats).vertices===0&&' +
    'JSON.parse(phanesCatalogResidentStats).triangles===0&&' +
    'JSON.parse(phanesCatalogResidentStats).texturePixels===0') = 'true',
    'Retirement releases all optional model residency counters');
  GPage.Screenshot(GEvidence + '/retired-phone.png');

  LWorld := World;
  LHistory := History;
  LSelection := Selection;
  Check(GPage.Number('catalogWorldErrors.length') = 0,
    'Retirement has no browser errors before reload');
  GPage.Execute('window.catalogWorldSaved=window.phanesSessionSavingRevision||0;' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSaved===true&&' +
    'window.phanesSessionSavedRevision>window.catalogWorldSaved');
  GPage.Execute('location.reload()');
  GPage.WaitFor('!!window.phanesEditor?.world&&!window.phanesRecovering&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(World = LWorld, 'Saved-session reload restores the exact current world');
  Check(History = LHistory, 'Saved-session reload restores exact edit history');
  Check(Selection = LSelection, 'Saved-session reload restores the exact selection');
  Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 0,
    'Reload does not reacquire models absent from the current world');

  LFailedWorld := World;
  LFailedHistory := History;
  LFailedSelection := Selection;
  LFuture := GPage.Text('JSON.stringify(phanesEditor.future)');
  LTarget := GPage.Text('JSON.stringify(phanesEditor.history[phanesEditor.history.length-1])');
  Check(GPage.Text('JSON.parse(' + JSString(LTarget) + ').composition.nodes.some(' +
    'n=>n.asset.startsWith("phanes.catalog."))') = 'true',
    'Undo target contains an optional model for the failure journey');
  LSettled := Trunc(GPage.Number('phanesCatalogWorldProbe.settled()'));
  GPage.Execute('phanesCatalogWorldProbe.hold()');
  GPage.Click('#interior-undo');
  GPage.WaitFor('phanesCatalogWorldProbe.count()>0&&window.phanesCatalogLoading');
  Check(World = LFailedWorld, 'Held preparation leaves the old world visible');
  Check(History = LFailedHistory, 'Held preparation leaves undo history unchanged');
  Check(Selection = LFailedSelection, 'Held preparation leaves selection unchanged');
  GPage.Click('#cancel');
  GPage.WaitFor('!window.phanesCatalogLoading');
  Check(World = LFailedWorld, 'Cancel preserves the exact old world');
  Check(History = LFailedHistory, 'Cancel preserves exact undo history');
  Check(GPage.Text('JSON.stringify(phanesEditor.future)') = LFuture,
    'Cancel preserves exact redo history');
  Check(Selection = LFailedSelection, 'Cancel preserves the exact selection');
  GPage.Execute('phanesCatalogWorldProbe.release()');
  GPage.WaitFor('phanesCatalogWorldProbe.settled()>' + IntToStr(LSettled));
  Check(GPage.Number('catalogWorldErrors.length') = 0,
    'Cancelled native fetch rejection does not escape to the page');

  LSettled := Trunc(GPage.Number('phanesCatalogWorldProbe.settled()'));
  GPage.Execute('phanesCatalogWorldProbe.hold()');
  GPage.Click('#interior-undo');
  GPage.WaitFor('phanesCatalogWorldProbe.count()>0&&window.phanesCatalogLoading');
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:1,depth:1};' +
    'phanesEditorActions.syncSelection()');
  GPage.WaitFor('!window.phanesCatalogLoading');
  Check(World = LFailedWorld, 'Selection cancellation preserves the exact old world');
  Check(History = LFailedHistory, 'Selection cancellation preserves exact undo history');
  Check(GPage.Text('JSON.stringify(phanesEditor.future)') = LFuture,
    'Selection cancellation preserves exact redo history');
  Check(Selection <> LFailedSelection,
    'Selection cancellation retains the newly chosen valid selection');
  GPage.Execute('phanesCatalogWorldProbe.release()');
  GPage.WaitFor('phanesCatalogWorldProbe.settled()>' + IntToStr(LSettled));
  Check(World = LFailedWorld, 'Released stale fetch cannot overwrite the old world');
  Check(GPage.Number('catalogWorldErrors.length') = 0,
    'Selection-cancelled native fetch rejection does not escape to the page');
  GPage.Execute('phanesEditor.selection=JSON.parse(' + JSString(LFailedSelection) + ');' +
    'phanesEditorActions.syncSelection()');
  Check(Selection = LFailedSelection, 'Failure journey restores its original selection');

  GPage.BlockURLs(['*library/*']);
  GPage.Click('#interior-undo');
  GPage.WaitFor('!window.phanesCatalogLoading&&' +
    'document.getElementById("toast").textContent.startsWith("Could not prepare")', 180000);
  Check(World = LFailedWorld, 'Failed preparation preserves the exact old world');
  Check(History = LFailedHistory, 'Failed preparation preserves exact undo history');
  Check(Selection = LFailedSelection, 'Failed preparation preserves the exact selection');

  GPage.BlockURLs([]);
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#interior-undo');
  WaitForRevision(LRevision);
  Check(World = LTarget, 'Retry acquires the optional model and publishes the exact undo target');
  Check(GPage.Text('document.getElementById("toast").hidden') = 'true',
    'Successful retry clears the previous preparation error');
  CheckResidentStats(True);
  WriteTextAtomic(GEvidence + '/resident-reacquired.json',
    GPage.Text('phanesCatalogResidentStats'));
  GPage.WaitFor('document.getElementById("toast").hidden');
  GPage.Screenshot(GEvidence + '/reacquired-phone.png');
  Check(GPage.Number('catalogWorldErrors.length') = 0, 'Catalog world journey has no browser errors');

  GPage.Click('#leave-interior');
  GPage.WaitFor('phanesEditor.interiorRoom===""');
  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4};' +
    'phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("clear",null,{editLayer:""})');
  WaitForRevision(LRevision);
  GPage.Click('#open-modules');
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:8,' +
    'selectionCells:[396,397,398,428,429,430,460,461,462]};' +
    'phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#module-build');
  WaitForRevision(LRevision);
  Check(GPage.Number('phanesEditor.world.composition.nodes.filter(' +
    'n=>n.asset==="phanes.building.modular.v1").length') = 1,
    'Actual module UI creates one world-space home');
  GPage.SetValue('module-parts', 'home-396.floor-13-13', 'change');
  GPage.SetValue('module-furniture', 'phanes.shelf.oak.v1', 'change');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#module-furnish');
  WaitForRevision(LRevision);
  LBook := GPage.Text('phanesEditor.world.composition.nodes.find(' +
    'n=>n.role==="shelf-tier"&&n.id.startsWith("home-396.")).id');
  GPage.SetValue('module-parts', LBook, 'change');
  GPage.SetValue('module-content-role', 'book', 'change');
  GPage.SetValue('module-content-count', '1');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#module-count-apply');
  WaitForRevision(LRevision);
  LBook := GPage.Text('phanesEditor.world.composition.nodes.find(' +
    'n=>n.role==="book"&&n.id.startsWith("home-396.")).id');
  if GPage.Text('phanesEditor.world.composition.nodes.find(n=>n.id===' +
    JSString(LBook) + ').asset') = BookAsset then
  begin
    GenerateReplacement(LBook, NativeBookAsset);
  end;
  GenerateReplacement(LBook, BookAsset);
  CheckResidentStats(True);
  GPage.SetValue('module-parts', LBook, 'change');
  GPage.Click('#module-focus');
  GPage.Resize(1280, 900);
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'document.getElementById("toast").hidden');
  GPage.Screenshot(GEvidence + '/modular-book-desktop.png');
  GenerateReplacement(LBook, NativeBookAsset);
  GPage.WaitFor('JSON.parse(phanesCatalogResidentStats).models===0');
  Check(GPage.Text('JSON.parse(phanesCatalogResidentStats).sourceBytes===0&&' +
    'JSON.parse(phanesCatalogResidentStats).closureSourceBytes===0&&' +
    'JSON.parse(phanesCatalogResidentStats).sourceNamespaces===0') = 'true',
    'Modular retirement releases the optional raw scene and derived model');
  LTarget := GPage.Text('JSON.stringify(phanesEditor.history[phanesEditor.history.length-1])');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#module-undo');
  WaitForRevision(LRevision);
  Check(World = LTarget, 'Modular Undo reacquires and restores the exact optional book world');
  CheckResidentStats(True);
  Check(GPage.Number('catalogWorldErrors.length') = 0,
    'Studio and modular cache journeys have no browser errors');
end;

begin
  Require(ParamCount = 3, 'Usage: catalog-world-check BROWSER URL EVIDENCE');
  GEvidence := ExpandFileName(ParamStr(3));
  ForceDirectories(GEvidence);
  GPage := TBrowserProbe.Create(ParamStr(1), GEvidence + '/profile');
  try
    try
      Run;
      WriteTextAtomic(GEvidence + '/result.txt', 'PASS ' + IntToStr(GChecks) + ' checks' + #10);
    except
      on LException: Exception do
      begin
        WriteTextAtomic(GEvidence + '/failure.txt', LException.Message + #10 +
          GPage.Text('document.body.innerText'));
        GPage.Screenshot(GEvidence + '/failure.png');
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
