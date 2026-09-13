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
program PhanesCatalogRegionalBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

const
  AssetCount = 18;
  AssetIds: array[0..AssetCount - 1] of String = (
    'phanes.catalog.tree.forest-canopy.v1',
    'phanes.catalog.tree.autumn.v1',
    'phanes.catalog.tree.birch.v1',
    'phanes.catalog.tree.island-palm.v1',
    'phanes.catalog.shrub.leafy-bush.v1',
    'phanes.catalog.shrub.broadleaf.v1',
    'phanes.catalog.shrub.berry-bush.v1',
    'phanes.catalog.shrub.forest-plant.v1',
    'phanes.catalog.flowers.cactus-bloom.v1',
    'phanes.catalog.flowers.cactus-cluster.v1',
    'phanes.catalog.flowers.wildflowers.v1',
    'phanes.catalog.flowers.flower-patch.v1',
    'phanes.catalog.wheat.corn.v1',
    'phanes.catalog.wheat.rice.v1',
    'phanes.catalog.wheat.grain.v1',
    'phanes.catalog.rock.granite.v1',
    'phanes.catalog.rock.mossy.v1',
    'phanes.catalog.rock.forest-stones.v1');
  Roles: array[0..AssetCount - 1] of String = (
    'tree', 'tree', 'tree', 'tree',
    'shrub', 'shrub', 'shrub', 'shrub',
    'flowers', 'flowers', 'flowers', 'flowers',
    'wheat', 'wheat', 'wheat',
    'rock', 'rock', 'rock');
  Categories: array[0..AssetCount - 1] of String = (
    'forest', 'forest', 'forest', 'forest',
    'forest', 'forest', 'forest', 'forest',
    'flowers', 'flowers', 'flowers', 'flowers',
    'field', 'field', 'field',
    'forest', 'forest', 'forest');
  FineCells: array[0..AssetCount - 1] of Integer = (
    0, 1, 8, 9, 16, 17, 24, 25, 32, 33, 40, 41, 48, 49, 56, 54, 55, 62);
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

function World: String;
begin
  Result := GPage.Text('JSON.stringify(phanesEditor.world)');
end;

function History: String;
begin
  Result := GPage.Text('JSON.stringify(phanesEditor.history)');
end;

procedure WaitForRevision(const ARevision: Integer);
begin
  GPage.WaitFor('phanesSceneVersion>' + IntToStr(ARevision) +
    '&&!phanesEditor.worker&&!window.phanesCatalogLoading&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
end;

procedure SelectFineCell(const AWorldSize, AFineCell: Integer);
var
  LFineSize: Integer;
  LFineX: Integer;
  LFineZ: Integer;
begin
  LFineSize := AWorldSize * 2;
  LFineX := AFineCell mod LFineSize;
  LFineZ := AFineCell div LFineSize;
  GPage.Execute('phanesEditor.selection={x:' + IntToStr(LFineX div 2) +
    ',z:' + IntToStr(LFineZ div 2) +
    ',width:1,depth:1,selectionScale:2,selectionCells:[' +
    IntToStr(AFineCell) + ']};phanesEditorActions.syncSelection()');
end;

procedure CloseCatalog;
begin
  while GPage.Text('document.getElementById("catalog-browser").hidden') <> 'true' do
  begin
    GPage.Click('#catalog-back');
  end;
end;

procedure ChooseCatalogAsset(const ACategory, ARole, AAsset: String);
begin
  CloseCatalog;
  GPage.Click('[data-intent="' + ACategory + '"]');
  GPage.Click('[data-catalog-group="' + ARole + '"]');
  GPage.Click('[data-catalog-asset="' + AAsset + '"]');
  Check(GPage.Text('document.getElementById("catalog-choice").textContent.includes(' +
    JSString(AAsset) + ')||document.querySelector("[data-catalog-asset=' +
    QuotedStr(AAsset) + ']").getAttribute("aria-pressed")==="true"') = 'true',
    'Catalog category and group expose ' + AAsset);
end;

procedure ApplyAsset(const AIndex: Integer);
var
  LBeforeLayers: String;
  LBeforeNodes: String;
  LRevision: Integer;
  LFine: Integer;
begin
  LFine := FineCells[AIndex];
  SelectFineCell(4, LFine);
  LBeforeLayers := GPage.Text('JSON.stringify(phanesEditor.world.layers.map(' +
    '(l,li)=>l.map((v,i)=>(li===2||li===4)&&i===' + IntToStr(LFine) + '?null:v)))');
  LBeforeNodes := GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes)');
  ChooseCatalogAsset(Categories[AIndex], Roles[AIndex], AssetIds[AIndex]);
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#catalog-apply');
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.layers[4][' + IntToStr(LFine) + ']') =
    AssetIds[AIndex], 'Applied vegetation contains ' + AssetIds[AIndex]);
  Check(GPage.Text('phanesEditor.world.layers[2][' + IntToStr(LFine) + ']') =
    Roles[AIndex], 'Applied ecology records role ' + Roles[AIndex]);
  Check(GPage.Text('JSON.stringify(phanesEditor.world.layers.map(' +
    '(l,li)=>l.map((v,i)=>(li===2||li===4)&&i===' + IntToStr(LFine) + '?null:v)))') =
    LBeforeLayers, 'Apply preserves every unaffected layer cell');
  Check(GPage.Text('JSON.stringify(phanesEditor.world.composition.nodes)') =
    LBeforeNodes, 'Apply preserves the complete composition exactly');
end;

procedure FocusRole(const ACoarse: Integer; const AName: String);
var
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  LX := (ACoarse mod 4) * 16 - 24;
  LZ := (ACoarse div 4) * 16 - 24;
  I := 0;
  while ((FineCells[I] mod 8 div 2) + (FineCells[I] div 8 div 2) * 4) <> ACoarse do
  begin
    Inc(I);
  end;
  GPage.Execute('(()=>{const p=phanesRegionalCapturePlacement(phanesEditor.world,' +
    IntToStr(FineCells[I]) + ');Object.assign(phanesEditor,{panX:' + IntToStr(LX) +
    ',panZ:' + IntToStr(LZ) + ',panY:p.ground+1.5,zoom:2.2,yaw:-2.35,pitch:0});' +
    'phanesEditorActions.setCamera("orbit")})()');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'document.getElementById("toast").hidden');
  GPage.Screenshot(GEvidence + '/' + AName + '-models.png', True);
end;

procedure CaptureEachModel;
var
  I: Integer;
begin
  for I := 0 to AssetCount - 1 do
  begin
    SelectFineCell(4, FineCells[I]);
    GPage.Execute('(()=>{const p=phanesRegionalCapturePlacement(phanesEditor.world,' +
      IntToStr(FineCells[I]) + ');Object.assign(phanesEditor,{panX:p.x,panY:p.y,' +
      'panZ:p.z,yaw:-2.35,pitch:0,zoom:Math.min(12,80/Math.max(3.5,p.extent*3))});' +
      'phanesEditorActions.setCamera("orbit")})()');
    GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
    GPage.Screenshot(GEvidence + '/model-' + Format('%.2d', [I + 1]) + '.png', True);
  end;
end;

procedure CheckAllResident;
begin
  Check(GPage.Text('(()=>{const s=JSON.parse(phanesCatalogResidentStats);return ' +
    's.models===18&&s.sourceBytes===1104190&&s.closureSourceBytes===1217856&&' +
    's.sourceNamespaces===5&&s.vertices===22714&&' +
    's.triangles===7922&&s.texturePixels===786432&&s.sourceLimit===16777216&&' +
    's.vertexLimit===250000&&s.triangleLimit===50000&&' +
    's.texturePixelLimit===4194304&&s.modelLimit===32})()') = 'true',
    'All 18 models publish exact distinct-profile residency totals');
  Check(GPage.Text('(()=>{const ids=JSON.parse(phanesCatalogReadyIds);return ' +
    IntToStr(AssetCount) + '===ids.length&&' +
    '[' + JSString(AssetIds[0]) + ',' + JSString(AssetIds[1]) + ',' +
    JSString(AssetIds[2]) + ',' + JSString(AssetIds[3]) + ',' +
    JSString(AssetIds[4]) + ',' + JSString(AssetIds[5]) + ',' +
    JSString(AssetIds[6]) + ',' + JSString(AssetIds[7]) + ',' +
    JSString(AssetIds[8]) + ',' + JSString(AssetIds[9]) + ',' +
    JSString(AssetIds[10]) + ',' + JSString(AssetIds[11]) + ',' +
    JSString(AssetIds[12]) + ',' + JSString(AssetIds[13]) + ',' +
    JSString(AssetIds[14]) + ',' + JSString(AssetIds[15]) + ',' +
    JSString(AssetIds[16]) + ',' + JSString(AssetIds[17]) +
    '].every(id=>ids.includes(id))})()') = 'true',
    'Ready set contains every admitted regional model');
  Check(GPage.Text('(()=>{const b=JSON.parse(phanesAssetBounds||"{}");return [' +
    JSString(AssetIds[0]) + ',' + JSString(AssetIds[1]) + ',' +
    JSString(AssetIds[2]) + ',' + JSString(AssetIds[3]) + ',' +
    JSString(AssetIds[4]) + ',' + JSString(AssetIds[5]) + ',' +
    JSString(AssetIds[6]) + ',' + JSString(AssetIds[7]) + ',' +
    JSString(AssetIds[8]) + ',' + JSString(AssetIds[9]) + ',' +
    JSString(AssetIds[10]) + ',' + JSString(AssetIds[11]) + ',' +
    JSString(AssetIds[12]) + ',' + JSString(AssetIds[13]) + ',' +
    JSString(AssetIds[14]) + ',' + JSString(AssetIds[15]) + ',' +
    JSString(AssetIds[16]) + ',' + JSString(AssetIds[17]) +
    '].every(id=>b[id]&&b[id].size.every(v=>Number.isFinite(v)&&v>0))})()') =
    'true', 'Every regional model builds finite positive rendered geometry bounds');
end;

procedure Run;
var
  LProbe: UTF8String;
  I: Integer;
  LRevision: Integer;
  LWorld: String;
  LPrior: String;
  LHistory: String;
  LDistantWorld: String;
begin
  LProbe := ReadText('build/catalog-regional-browser-units/phanes.tests.catalog.regional.probe.js');
  if (Length(LProbe) >= 3) and (Ord(LProbe[1]) = $EF) and
    (Ord(LProbe[2]) = $BB) and (Ord(LProbe[3]) = $BF) then
  begin
    Delete(LProbe, 1, 3);
  end;
  GPage.InstallScript('(()=>{' + String(LProbe) + #10 + 'rtl.run();})();');
  GPage.InstallScript('window.catalogRegionalErrors=[];window.catalogRegionalWarnings=[];' +
    'window.catalogRegionalConsoleErrors=[];const regionalWarn=console.warn;' +
    'const regionalError=console.error;' +
    'console.warn=(...a)=>{catalogRegionalWarnings.push(a.map(String).join(" "));' +
    'regionalWarn.apply(console,a)};' +
    'console.error=(...a)=>{catalogRegionalConsoleErrors.push(a.map(String).join(" "));' +
    'regionalError.apply(console,a)};' +
    'addEventListener("error",e=>catalogRegionalErrors.push(e.message));' +
    'addEventListener("unhandledrejection",e=>catalogRegionalErrors.push(String(e.reason)))');
  GPage.Resize(1280, 900);
  GPage.Navigate(ParamStr(2));
  GPage.WaitFor('document.body.dataset.startupState==="ready"&&' +
    '!!window.phanesCatalogRuntime&&typeof phanesCatalogResidentStats==="string"', 180000);
  GPage.SetValue('region-size', '4');
  GPage.Click('#create-world');
  GPage.WaitFor('!!phanesEditor.world&&!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(GPage.Number('phanesEditor.palette.assets.length') = 37,
    'Actual catalog exposes 19 core and 18 optional regional choices');
  Check(GPage.Text('!phanesEditor.world.composition.nodes.some(' +
    'n=>n.asset.startsWith("phanes.catalog."))&&!phanesEditor.world.layers[4].some(' +
    'v=>v.startsWith("phanes.catalog."))') = 'true',
    'New Create intentionally publishes a core-only world');
  Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 0,
    'Core-only creation has no optional residency');

  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,' +
    'selectionScale:1,selectionCells:[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]};' +
    'phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("clear",null,{editLayer:""})');
  WaitForRevision(LRevision);
  GPage.Execute('phanesEditor.selection={x:0,z:3,width:1,depth:1,' +
    'selectionScale:1,selectionCells:[12]};phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("field",null,{editLayer:"terrain"})');
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.layers[0][12]') = 'field',
    'Crop showcase cell is prepared as validated dry field terrain');

  for I := 0 to AssetCount - 1 do
  begin
    ApplyAsset(I);
    case I of
      3: FocusRole(0, 'trees');
      7: FocusRole(4, 'shrubs');
      11: FocusRole(8, 'flowers');
      14: FocusRole(12, 'crops');
      17: FocusRole(15, 'rocks');
    end;
  end;
  CheckAllResident;
  CaptureEachModel;
  WriteTextAtomic(GEvidence + '/resident-all.json', GPage.Text('phanesCatalogResidentStats'));

  GPage.Execute('Object.assign(phanesEditor,{panX:0,panZ:0,zoom:1});' +
    'phanesEditorActions.setCamera("top")');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion');
  GPage.Screenshot(GEvidence + '/all-regional-desktop.png');
  LWorld := World;
  LPrior := GPage.Text('JSON.stringify(phanesEditor.history[phanesEditor.history.length-1])');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#undo');
  WaitForRevision(LRevision);
  Check(World = LPrior, 'Desktop Undo restores the exact prior regional world');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#redo');
  WaitForRevision(LRevision);
  Check(World = LWorld, 'Desktop Redo restores the exact all-model world');

  GPage.Resize(390, 844, 2);
  SelectFineCell(4, FineCells[AssetCount - 1]);
  ChooseCatalogAsset('forest', 'rock', AssetIds[AssetCount - 1]);
  LPrior := World;
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#catalog-apply');
  WaitForRevision(LRevision);
  Check(GPage.Text('phanesEditor.world.layers[4][' +
    IntToStr(FineCells[AssetCount - 1]) + ']') = AssetIds[AssetCount - 1],
    'Phone category, group, item and Apply publish the chosen model');
  LWorld := World;
  GPage.Screenshot(GEvidence + '/all-regional-phone.png');
  GPage.Execute('document.getElementById("catalog-choice").scrollIntoView({block:"center"})');
  GPage.Screenshot(GEvidence + '/catalog-controls-phone.png');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#undo');
  WaitForRevision(LRevision);
  Check(World = LPrior, 'Phone Undo restores the exact prior regional world');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#redo');
  WaitForRevision(LRevision);
  Check(World = LWorld, 'Phone Redo restores the exact all-model world');

  LHistory := History;
  WriteTextAtomic(GEvidence + '/console-before-reload.json',
    GPage.Text('JSON.stringify({errors:catalogRegionalErrors,' +
    'consoleErrors:catalogRegionalConsoleErrors,warnings:catalogRegionalWarnings})'));
  Check(GPage.Number('catalogRegionalErrors.length') = 0,
    'All-model publication has no browser errors before reload');
  Check(GPage.Number('catalogRegionalConsoleErrors.length') = 0,
    'All-model publication has no console errors before reload');
  Check(GPage.Text('!catalogRegionalWarnings.some(m=>' +
    '/texture|material|resource|gltf|model/i.test(m))') = 'true',
    'All-model publication has no model resource warnings before reload');
  GPage.Execute('window.catalogRegionalSaved=window.phanesSessionSavingRevision||0;' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSaved===true&&' +
    'window.phanesSessionSavedRevision>window.catalogRegionalSaved');
  GPage.Execute('location.reload()');
  GPage.WaitFor('!!window.phanesEditor?.world&&!window.phanesRecovering&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  Check(World = LWorld, 'Saved-session reload restores the exact all-model world');
  Check(History = LHistory, 'Saved-session reload restores exact all-model history');
  CheckAllResident;

  GPage.Execute('phanesEditor.selection={x:0,z:0,width:4,depth:4,' +
    'selectionScale:1,selectionCells:[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]};' +
    'phanesEditorActions.syncSelection()');
  GPage.SetValue('selection-layer', 'foliage', 'change');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#clear-region');
  WaitForRevision(LRevision);
  GPage.WaitFor('JSON.parse(phanesCatalogResidentStats).models===0');
  Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).length===0&&' +
    'JSON.parse(phanesCatalogResidentStats).sourceBytes===0') = 'true',
    'Real foliage Clear retires every optional regional model');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#undo');
  WaitForRevision(LRevision);
  Check(World = LWorld, 'Undo reacquires and restores the exact all-model world');
  CheckAllResident;

  CloseCatalog;
  GPage.Resize(1280, 900);
  GPage.SetValue('region-size', '16');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  { The initial Create is exercised through its actual button above. Once a
    world is published the welcome form intentionally stays hidden, so the
    distant lifetime scenario uses the same validated public generation path. }
  GPage.Execute('phanesEditorActions.generate("create")');
  WaitForRevision(LRevision);
  Check(GPage.Number('phanesEditor.world.size') = 16,
    'Validated creation API starts the bounded distant-streaming world');
  Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 0,
    'Large core-only world retires the prior regional batch');
  Check(GPage.Text('!JSON.parse(phanesAssetBounds||"{}")[' + JSString(AssetIds[0]) + ']') =
    'true', 'Retirement removes stale regional template diagnostics');
  GPage.Execute('Object.assign(phanesEditor,{panX:0,panY:0,panZ:0,zoom:1});' +
    'phanesEditorActions.setCamera("top")');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'window.phanesPendingChunks===0', 180000);
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,' +
    'selectionScale:1,selectionCells:[17]};phanesEditorActions.syncSelection()');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Execute('phanesEditorActions.generate("clear",null,{editLayer:""})');
  WaitForRevision(LRevision);
  SelectFineCell(16, 66);
  ChooseCatalogAsset('forest', 'tree', AssetIds[0]);
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#catalog-apply');
  WaitForRevision(LRevision);
  LDistantWorld := World;
  Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 1,
    'Distant optional model remains resident before its chunk streams');
  Check(GPage.Text('!JSON.parse(phanesAssetBounds||"{}")[' + JSString(AssetIds[0]) + ']') =
    'true', 'Distant publication prepares resources without building a detailed template');
  GPage.Execute('Object.assign(phanesEditor,{panX:-104,panZ:-104,zoom:1});' +
    'phanesEditorActions.setCamera("top")');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'window.phanesPendingChunks===0&&!!JSON.parse(phanesAssetBounds||"{}")[' +
    JSString(AssetIds[0]) + ']', 180000);
  Check(GPage.Text('JSON.parse(phanesAssetBounds)[' + JSString(AssetIds[0]) +
    '].size.every(v=>Number.isFinite(v)&&v>0)') = 'true',
    'Streaming the distant chunk builds finite optional geometry bounds');
  GPage.Execute('Object.assign(phanesEditor,{panX:0,panZ:0});' +
    'phanesEditorActions.syncCamera()');
  GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&' +
    'window.phanesPendingChunks===0', 180000);
  Check(World = LDistantWorld, 'Streaming away preserves the exact distant optional world');
  Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 1,
    'Streaming away keeps the distant optional model pinned');
  SelectFineCell(16, 66);
  GPage.SetValue('selection-layer', 'foliage', 'change');
  LRevision := Trunc(GPage.Number('phanesSceneVersion'));
  GPage.Click('#clear-region');
  WaitForRevision(LRevision);
  GPage.WaitFor('JSON.parse(phanesCatalogResidentStats).models===0');
  Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).length===0') = 'true',
    'Removing the distant object retires its pinned model');
  Check(GPage.Number('catalogRegionalErrors.length') = 0,
    'Regional publication and streaming journey has no browser errors');
  Check(GPage.Number('catalogRegionalConsoleErrors.length') = 0,
    'Regional recovery and streaming journey has no console errors');
  Check(GPage.Text('!catalogRegionalWarnings.some(m=>' +
    '/texture|material|resource|gltf|model/i.test(m))') = 'true',
    'Regional recovery and streaming journey has no model resource warnings');
  WriteTextAtomic(GEvidence + '/console-final.json',
    GPage.Text('JSON.stringify({errors:catalogRegionalErrors,' +
    'consoleErrors:catalogRegionalConsoleErrors,warnings:catalogRegionalWarnings})'));
end;

begin
  Require(ParamCount = 3, 'Usage: catalog-regional-browser BROWSER URL EVIDENCE');
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
