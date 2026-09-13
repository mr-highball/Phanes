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
  Require(ParamCount=3,'Usage: population-browser BROWSER URL EVIDENCE');
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
        GPage.SetValue('module-population-furniture','plants','change');
        GPage.SetValue('module-density','25','change');
        Check(Pos('target 4',GPage.Text('document.getElementById("module-population-hint").textContent'))>0,
          'Density previews four furnishings for sixteen empty floors');
        GBefore := GPage.Text('JSON.stringify(phanesEditor.world)');
        GPage.Execute('document.body.dataset.lastSolve=""');
        Click('#module-populate');
        Settled;
        Check(GPage.Number('phanesEditor.world.composition.nodes.filter(n=>n.id.endsWith(".furnishing")).length')=4,
          '25 percent places four actual furnishings');
        Check(Pos('Added 4 of 4',GPage.Text('document.getElementById("toast").textContent'))>0,
          'Result reports the actual placement count');
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
