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
program PhanesPopulationBrowser;
{$mode delphi}
{$H+}
uses SysUtils, phanes.tools.browser, phanes.tools.files;
var
  GPage: TBrowserProbe;
  GOutput, GView, GBefore, GAfter: String;
  GChecks, GViewport: Integer;
  GSample: Integer;
  GAsset: String;
const
  BatchSamples: array[0..2] of String = (
    'phanes.catalog.batch.29126d7453aa558d.v1',
    'phanes.catalog.batch.a5b74fed5d9ab924.v1',
    'phanes.catalog.batch.08f8aa7805e15d20.v1');
  EquipmentSamples: array[0..2] of String = (
    'phanes.catalog.batch.equipment.bb1a8ac28be7dff7.v1',
    'phanes.catalog.batch.equipment.946d29dc06e1d673.v1',
    'phanes.catalog.batch.equipment.45af32c4a86be7bf.v1');
  FurnitureSamples: array[0..2] of String = (
    'phanes.catalog.batch.furniture.a76f7625ef68f50c.v1',
    'phanes.catalog.batch.furniture.9ca990f39492d5fd.v1',
    'phanes.catalog.batch.furniture.8d80612348f95207.v1');
procedure Check(const ACondition: Boolean; const ALabel: String);
begin
  Require(ACondition, ALabel + ': ' + GPage.Text('document.getElementById("toast").textContent'));
  Inc(GChecks);
  WriteLn('PASS ', GView, ' ', ALabel);
  Flush(Output);
end;
procedure Click(const ASelector: String);
begin
  GPage.Execute('document.querySelector(' + QuotedStr(ASelector) + ').scrollIntoView({block:"center"})');
  GPage.Click(ASelector);
end;
procedure Settled;
begin
  GPage.WaitFor('!phanesEditor.worker&&!phanesCatalogLoading&&!!document.body.dataset.lastSolve&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion',180000);
  Check(GPage.Text('document.body.dataset.lastSolve')='passed','Operation committed and rendered');
end;
procedure Floors;
begin
  GPage.Execute('(()=>{const cells=[];for(let z=12;z<16;z++)for(let x=12;x<16;x++)cells.push(z*32+x);' +
    'phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:8,selectionCells:cells};phanesEditorActions.syncSelection()})()');
end;
begin
  Require((ParamCount=3) or (ParamCount=4),
    'Usage: population-browser BROWSER URL EVIDENCE [--catalog-batch|--catalog-equipment|--catalog-furniture|--catalog-density]');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  for GViewport := 0 to 1 do
  begin
    if GViewport = 0 then
    begin
      GView := 'desktop';
    end else
    begin
      GView := 'phone';
    end;
    GPage := TBrowserProbe.Create(ParamStr(1),GOutput + '/' + GView + '-profile');
    try
      try
        GPage.InstallScript('window.populationErrors=[];addEventListener("error",e=>populationErrors.push(e.message));' +
          'addEventListener("unhandledrejection",e=>populationErrors.push(String(e.reason)))');
        if GViewport = 0 then
        begin
          GPage.Resize(1440, 960);
        end else
        begin
          GPage.Resize(390, 844);
        end;
        GPage.Navigate(ParamStr(2));
        GPage.WaitFor('document.body?.dataset.startupState==="ready"&&!document.getElementById("create-world").disabled',180000);
        GPage.SetValue('region-size','4');
        GPage.SetValue('world-seed','731');
        GPage.Execute('document.body.dataset.lastSolve=""');
        Click('#create-world');
        Settled;
        GPage.Execute('phanesEditor.selection={x:1,z:1,width:2,depth:2};phanesEditorActions.syncSelection();' +
          'document.body.dataset.lastSolve="";phanesEditorActions.generate("clear",null,{editLayer:""})');
        Settled;
        Click('#open-modules');
        Floors;
        GPage.Execute('document.body.dataset.lastSolve=""');
        Click('#module-build');
        Settled;
        Click('#module-paint');
        Floors;
        Check(GPage.Text('document.getElementById("module-populate").disabled')='false',
          'Painted floors enable Populate while Draw floors is active');
        GPage.SetValue('module-population-category','Food','change');
        Check(GPage.Number('document.querySelectorAll("#module-population-category option").length')=14,
          'Top-level picker contains categories only');
        GPage.SetValue('module-furniture-category','Kitchen','change');
        Check(GPage.Number('document.querySelectorAll("#module-furniture [data-batch-model]").length')>0,
          'Single-floor picker also filters by category');
        GPage.SetValue('module-population-furniture','phanes.catalog.batch.0ecae365dba6d4b8.v1','change');
        GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:8,selectionCells:[13*32+13]};phanesEditorActions.syncSelection()');
        GPage.SetValue('module-density','25','change');
        Check(Pos('target 25%',GPage.Text('document.getElementById("module-population-hint").textContent'))>0,
          'Density previews floor-area coverage');
        GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
        GPage.Execute('document.body.dataset.lastSolve=""');
        Click('#module-populate');
        Settled;
        Check(GPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.asset==="phanes.catalog.batch.0ecae365dba6d4b8.v1").length')>1,
          'Several exact lollipops populate one floor');
        Check(Pos('floor-area coverage',GPage.Text('document.getElementById("toast").textContent'))>0,
          'Result reports achieved coverage');
        Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).includes("phanes.catalog.batch.0ecae365dba6d4b8.v1")')='true',
          'Actual lollipop source is rendered');
        GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
        GPage.Screenshot(GOutput + '/' + GView + '-populated.png');
        Click('#module-undo');
        GPage.WaitFor('!phanesCatalogLoading&&Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        Check(GPage.Text('JSON.stringify(phanesEditor.world)')=GBefore,'One undo restores the entire previous world');
        Click('#module-redo');
        GPage.WaitFor('!phanesCatalogLoading&&Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
        Check(GPage.Text('JSON.stringify(phanesEditor.world)')=GAfter,'One redo restores the entire population');
        Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth')='true','No horizontal page overflow');
        Check(GPage.Number('populationErrors.length')=0,'No browser runtime errors');
        if (ParamStr(4) = '--catalog-batch') or (ParamStr(4) = '--catalog-equipment') or
          (ParamStr(4) = '--catalog-furniture') or (ParamStr(4) = '--catalog-density') then
        begin
          for GSample := 0 to High(BatchSamples) do
          begin
            Click('#module-undo');
            GPage.WaitFor('!phanesCatalogLoading&&Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
            Click('#module-paint');
            Floors;
            GAsset := BatchSamples[GSample];
            if ParamStr(4) = '--catalog-equipment' then
            begin
              GAsset := EquipmentSamples[GSample];
            end else if ParamStr(4) = '--catalog-furniture' then
            begin
              GAsset := FurnitureSamples[GSample];
            end;
            if ParamStr(4) = '--catalog-density' then
            begin
              if GSample = 0 then
              begin
                GAsset := 'category:Food';
              end else if GSample = 1 then
              begin
                GAsset := 'category:Kitchen';
              end else
              begin
                GAsset := 'phanes.catalog.batch.0ecae365dba6d4b8.v1';
              end;
              if GSample <> 1 then
              begin
                GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:8,selectionCells:[13*32+13]};phanesEditorActions.syncSelection()');
              end;
            end;
            GPage.Execute('(()=>{const c=document.getElementById("module-population-category");' +
              'for(const o of c.options){c.value=o.value;c.dispatchEvent(new Event("change"));' +
              'if([...document.getElementById("module-population-furniture").options].some(x=>x.value===' +
              QuotedStr(GAsset) + '))return}throw Error("Model not found in any category")})()');
            Check(GPage.Number('document.querySelectorAll("#module-population-furniture [data-batch-model]").length')>0,
              'Search exposes matching catalog choices');
            Check(GPage.Number('document.querySelectorAll("#module-population-furniture [data-batch-model]").length')<500,
              'Category narrows the batch');
            GPage.SetValue('module-population-search', '', 'input');
            GPage.SetValue('module-population-furniture', GAsset, 'change');
            GPage.Execute('document.body.dataset.lastSolve=""');
            Click('#module-populate');
            Settled;
            if Pos('category:', GAsset) = 1 then
            begin
              Check(GPage.Number('new Set(phanesEditor.world.composition.nodes.filter(n=>n.id.includes(".scatter.")).map(n=>n.asset)).size')>1,
                'Category population produces several model types');
              Check(GPage.Text('phanesEditor.world.composition.nodes.filter(n=>n.id.includes(".scatter.")).every(n=>JSON.parse(phanesCatalogReadyIds).includes(n.asset))')='true',
                'Category models are actually rendered');
            end else
            begin
              Check(GPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.asset===' + QuotedStr(GAsset) + ').length')>0,
                'Density places exact catalog models');
              Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).includes(' + QuotedStr(GAsset) + ')')='true',
                'Renderer admitted the actual source model');
            end;
            if (ParamStr(4) = '--catalog-density') and (GSample <> 1) then
            begin
              GPage.Execute('(()=>{const s=document.getElementById("module-parts");s.value=phanesEditor.world.composition.nodes.find(n=>n.id.includes(".scatter.")).parent;s.dispatchEvent(new Event("change"))})()');
            end;
            Click('#module-focus');
            GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&document.getElementById("toast").hidden');
            GPage.Screenshot(GOutput + '/' + GView + '-catalog-' + IntToStr(GSample) + '.png');
            Check(GPage.Number('populationErrors.length')=0,'Catalog models render without browser errors');
          end;
        end;
      except
        on E: Exception do
        begin
          WriteTextAtomic(GOutput + '/' + GView + '-failure.txt',E.Message);
          GPage.Screenshot(GOutput + '/' + GView + '-failure.png');
          raise;
        end;
      end;
    finally
      GPage.Free;
    end;
  end;
  WriteTextAtomic(GOutput + '/result.txt','PASS ' + IntToStr(GChecks) + ' checks');
end.
