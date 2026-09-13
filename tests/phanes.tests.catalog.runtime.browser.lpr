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
program PhanesCatalogRuntimeBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

var
  GPage: TBrowserProbe;
  GEvidence: String;
  GReport: TJSONObject;
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  Inc(GChecks);
  WriteLn('PASS ', AMessage);
end;

procedure LoadModel(const AKit, AModel, AName: String;
  const ARevision, ATriangles: Integer);
begin
  GPage.Execute('window.catalogFetchFailure="";window.phanesCatalogRendererFailure="";' +
    'phanesCatalogFetchProbe.fetch(' + QuotedStr(AKit) + ',' + QuotedStr(AModel) +
    ').then(b=>{window.phanesCatalogBundle=b;' +
    'window.phanesCatalogExpectedGeneration=b.generation;' +
    'window.phanesCatalogRequestRevision=' + IntToStr(ARevision) +
    '},e=>window.catalogFetchFailure=String(e))');
  GPage.WaitFor('window.phanesCatalogDrawnRevision===' + IntToStr(ARevision) +
    '||!!window.phanesCatalogRendererFailure||!!window.catalogFetchFailure');
  Check(GPage.Text('window.catalogFetchFailure') = '', 'verified ' + AName + ' fetch');
  Check(GPage.Text('window.phanesCatalogRendererFailure') = '', AName + ' renderer accepts bundle');
  Check(GPage.Number('phanesCatalogTriangles') = ATriangles, AName + ' triangle parity in WASM');
  GPage.Screenshot(GEvidence + '/' + AName + '.png', True);
  GReport.Add(AName, GPage.Evaluate('({triangles:phanesCatalogTriangles,' +
    'sourceBytes:phanesCatalogSourceBytes,revision:phanesCatalogDrawnRevision})'));
  GPage.Execute('window.catalogLastGeneration=phanesCatalogBundle.generation;' +
    'phanesCatalogFetchProbe.release(phanesCatalogBundle.lease);' +
    'phanesCatalogFetchProbe.clear();window.phanesCatalogBundle=null');
  Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0,
    AName + ' browser cache and bundle references released after Castle copy');
end;

begin
  Require(ParamCount = 3, 'Usage: catalog-runtime-check BROWSER URL EVIDENCE');
  GEvidence := ExpandFileName(ParamStr(3));
  ForceDirectories(GEvidence);
  GReport := TJSONObject.Create;
  GPage := TBrowserProbe.Create(ParamStr(1), GEvidence + '/profile');
  try
    try
      GPage.InstallScript('window.catalogBrowserErrors=[];window.catalogWarnings=[];' +
        'addEventListener("error",e=>catalogBrowserErrors.push(e.message));' +
        'addEventListener("unhandledrejection",e=>catalogBrowserErrors.push(String(e.reason)));' +
        'const oldWarn=console.warn;console.warn=(...a)=>{catalogWarnings.push(a.map(String).join(" "));oldWarn(...a)};');
      GPage.Resize(800, 600);
      GPage.Navigate(ParamStr(2));
      GPage.WaitFor('!!window.phanesCatalogRendererReady&&!!window.phanesCatalogFetchProbe');
      LoadModel('quaternius-low-poly-food-pack-surface-v1',
        'quaternius-low-poly-food-pack-surface-v1/soysauce-2882b4c31b', 'food', 1, 60);
      LoadModel('kaykit-furniture-bits-1-0',
        'kaykit-furniture-bits-1-0/gltf/rug_rectangle_A', 'rug', 2, 44);
      GPage.Execute('window.phanesCatalogBundle={generation:catalogLastGeneration};' +
        'window.phanesCatalogExpectedGeneration=catalogLastGeneration+1;' +
        'window.phanesCatalogRequestRevision=3');
      GPage.WaitFor('!!window.phanesCatalogRendererFailure');
      Check(GPage.Number('phanesCatalogLoadedRevision') = 2,
        'stale generation preserves previously loaded model');
      Check(GPage.Number('phanesCatalogTriangles') = 44,
        'stale generation does not replace live geometry');
      GPage.Execute('window.phanesCatalogRendererFailure="";' +
        'window.phanesCatalogBundle={generation:catalogLastGeneration,rootPath:"bad.glb",' +
        'files:[{path:"bad.glb",buffer:new TextEncoder().encode("Invalid model").buffer}]};' +
        'window.phanesCatalogExpectedGeneration=catalogLastGeneration;' +
        'window.phanesCatalogRequestRevision=4');
      GPage.WaitFor('!!window.phanesCatalogRendererFailure');
      Check(GPage.Number('phanesCatalogLoadedRevision') = 2,
        'failed decode preserves the previous model lease');
      Check(GPage.Number('phanesCatalogTriangles') = 44,
        'failed decode leaves previous geometry intact');
      GPage.Resize(390, 844);
      GPage.Screenshot(GEvidence + '/rug-phone.png', True);
      LoadModel('quaternius-low-poly-food-pack-surface-v1',
        'quaternius-low-poly-food-pack-surface-v1/soysauce-2882b4c31b', 'retry', 5, 60);
      GPage.Resize(800, 600);
      LoadModel('kaykit-furniture-bits-1-0',
        'kaykit-furniture-bits-1-0/gltf/book_single', 'book', 6, 68);
      GPage.Resize(390, 844);
      GPage.Screenshot(GEvidence + '/book-phone.png', True);
      GPage.Resize(800, 600);
      LoadModel('quaternius-furniture-low-poly-surface-v1',
        'quaternius-furniture-low-poly-surface-v1/vase2-2bf7766b41', 'vase', 7, 204);
      GPage.Resize(390, 844);
      GPage.Screenshot(GEvidence + '/vase-phone.png', True);
      GReport.Add('browserErrors', GPage.Evaluate('catalogBrowserErrors'));
      GReport.Add('warnings', GPage.Evaluate('catalogWarnings'));
      Check(GPage.Number('catalogBrowserErrors.length') = 0, 'no browser runtime errors');
      Check(GPage.Number('catalogWarnings.length') = 0, 'no texture or resource warnings');
      GReport.Add('passed', True);
    except
      on LException: Exception do
      begin
        GReport.Add('failure', LException.Message);
        GReport.Add('browserErrors', GPage.Evaluate('window.catalogBrowserErrors||[]'));
        GReport.Add('warnings', GPage.Evaluate('window.catalogWarnings||[]'));
        GPage.Screenshot(GEvidence + '/failure.png', True);
        raise;
      end;
    end;
  finally
    GReport.Add('checks', GChecks);
    WriteTextAtomic(GEvidence + '/evidence.json', GReport.FormatJSON);
    GReport.Free;
    GPage.Free;
  end;
end.
