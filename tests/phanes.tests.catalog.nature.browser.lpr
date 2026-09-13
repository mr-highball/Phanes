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
program PhanesNatureBrowser;

{$mode delphi}
{$H+}

uses SysUtils, phanes.tools.files, phanes.tools.browser;

const
  CIds: array[0..4] of String = (
    'phanes.catalog.nature.4525e6ffdf690745.v1',
    'phanes.catalog.nature.93df7a744a5b4764.v1',
    'phanes.catalog.nature.83e208f06f34c3da.v1',
    'phanes.catalog.nature.d5717c9c8dcd53a6.v1',
    'phanes.catalog.nature.20fc243cebe55603.v1');
  CCategories: array[0..4] of String = ('forest', 'forest', 'flowers', 'forest', 'field');
  CRoles: array[0..4] of String = ('tree', 'shrub', 'flowers', 'rock', 'wheat');
var
  GPage: TBrowserProbe;
  GOutput: String;
  GBefore: String;
  GAfter: String;
  GChecks: Integer;
  I: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage + ': ' + GPage.Text('document.getElementById("toast").textContent'));
  Inc(GChecks);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

procedure Click(const ASelector: String);
begin
  GPage.Execute('document.querySelector(' + QuotedStr(ASelector) + ').scrollIntoView({block:"center"})');
  GPage.Click(ASelector);
end;

procedure Settled;
begin
  GPage.WaitFor('!phanesEditor.worker&&!phanesCatalogLoading&&document.body.dataset.lastSolve&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 90000);
  Check(GPage.Text('document.body.dataset.lastSolve') = 'passed', 'Operation committed and rendered');
end;

procedure SelectCenter;
begin
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1,selectionScale:2,selectionCells:[27]};' +
    'phanesEditorActions.syncSelection()');
end;

begin
  Require(ParamCount = 3, 'Usage: nature-browser BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
      GPage.InstallScript('window.natureErrors=[];addEventListener("error",e=>natureErrors.push(e.message));' +
        'addEventListener("unhandledrejection",e=>natureErrors.push(String(e.reason)))');
      GPage.Resize(1440, 960);
      GPage.Navigate(ParamStr(2));
      GPage.WaitFor('document.body.dataset.startupState==="ready"&&!document.getElementById("create-world").disabled', 180000);
      GPage.SetValue('region-size', '4');
      GPage.SetValue('world-seed', '731');
      GPage.Execute('document.body.dataset.lastSolve=""');
      Click('#create-world');
      Settled;
      Check(GPage.Number('phanesEditor.palette.assets.filter(a=>a.id.startsWith("phanes.catalog.nature.")).length') = 237,
        'Landscape palette exposes the entire nature batch');
      Check(GPage.Number('JSON.parse(phanesCatalogResidentStats).models') = 0,
        'Creation keeps optional models unloaded');
      GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection();' +
        'document.body.dataset.lastSolve="";phanesEditorActions.generate("clear",null,{editLayer:""})');
      Settled;
      for I := 0 to High(CIds) do
      begin
        while GPage.Text('document.getElementById("catalog-browser").hidden') <> 'true' do
        begin
          Click('#catalog-back');
        end;
        if I = High(CIds) then
        begin
          GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection();' +
            'document.body.dataset.lastSolve="";phanesEditorActions.generate("field",null,{editLayer:"terrain"})');
          Settled;
        end;
        SelectCenter;
        Click('[data-intent="' + CCategories[I] + '"]');
        GPage.SetValue('catalog-search', CIds[I], 'input');
        Check(GPage.Number('document.querySelectorAll("[data-catalog-asset]").length') = 1,
          'Search finds the exact nature model');
        Click('[data-catalog-asset="' + CIds[I] + '"]');
        GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
        GPage.Execute('document.body.dataset.lastSolve=""');
        Click('#catalog-apply');
        Settled;
        Check(GPage.Text('phanesEditor.world.layers[4][27]') = CIds[I], 'Selected landscape cell uses exact model');
        Check(GPage.Text('phanesEditor.world.layers[2][27]') = CRoles[I], 'Ecology records the matching role');
        Check(GPage.Text('JSON.parse(phanesCatalogReadyIds).includes(' + QuotedStr(CIds[I]) + ')') = 'true',
          'Renderer loaded and admitted the source model');
        GPage.Execute('Object.assign(phanesEditor,{panX:-4,panZ:-4,zoom:3,yaw:-2.35,pitch:0});' +
          'phanesEditorActions.setCamera("orbit")');
        GPage.WaitFor('phanesRenderedCameraVersion===phanesCameraVersion&&document.getElementById("toast").hidden');
        GPage.Screenshot(GOutput + '/desktop-' + CRoles[I] + '.png');
        if I = High(CIds) then
        begin
          GAfter := GPage.Text('JSON.stringify(phanesEditor.world)');
          GPage.Resize(390, 844);
          GPage.Execute('document.getElementById("catalog-search").scrollIntoView({block:"center"})');
          GPage.Screenshot(GOutput + '/phone-catalog.png');
          Check(GPage.Text('document.documentElement.scrollWidth<=innerWidth') = 'true', 'Phone catalog has no horizontal overflow');
          Click('#undo');
          GPage.WaitFor('!phanesCatalogLoading&&Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
          Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GBefore, 'Undo restores the previous model');
          Click('#redo');
          GPage.WaitFor('!phanesCatalogLoading&&Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
          Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GAfter, 'Redo restores the nature placement');
        end;
      end;
      while GPage.Text('document.getElementById("catalog-browser").hidden') <> 'true' do
      begin
        Click('#catalog-back');
      end;
      GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};phanesEditorActions.syncSelection()');
      Click('[data-intent="forest"]');
      Click('[data-catalog-group="rock"]');
      Click('[data-catalog-group-choice="rock"]');
      GPage.Execute('document.body.dataset.lastSolve=""');
      Click('#catalog-apply');
      Settled;
      Check(GPage.Text('(()=>{const ids=[18,19,26,27].map(i=>phanesEditor.world.layers[4][i]);' +
        'return new Set(ids).size>1&&new Set(ids).size<=8})()') = 'true',
        'Phone group placement renders a bounded mix of rocks');
      Check(GPage.Number('natureErrors.length') = 0, 'No browser runtime errors');
      WriteTextAtomic(GOutput + '/result.txt', 'PASS ' + IntToStr(GChecks) + ' checks');
    except
      on LException: Exception do
      begin
        WriteTextAtomic(GOutput + '/failure.txt', LException.Message);
        GPage.Screenshot(GOutput + '/failure.png');
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
