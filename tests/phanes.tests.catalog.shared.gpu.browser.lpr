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
program PhanesCatalogSharedGpuBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

const
  Instrumentation =
    '(()=>{' +
    'window.sharedGpuErrors=[];window.sharedGpuWarnings=[];window.sharedGpuLost=0;' +
    'const warn=console.warn,err=console.error;' +
    'console.warn=(...a)=>{sharedGpuWarnings.push(a.map(String).join(" "));warn(...a)};' +
    'console.error=(...a)=>{sharedGpuErrors.push(a.map(String).join(" "));err(...a)};' +
    'addEventListener("error",e=>sharedGpuErrors.push(e.message));' +
    'addEventListener("unhandledrejection",e=>sharedGpuErrors.push(String(e.reason)));' +
    'const rows=[],objects=new WeakMap(),contexts=new Set();' +
    'function entry(gl,t){if(!t)return null;let r=objects.get(t);' +
    'if(!r){r={id:rows.length+1,gl,deleted:false,width:0,height:0,uploads:0};objects.set(t,r);rows.push(r)}return r}' +
    'const get=HTMLCanvasElement.prototype.getContext;' +
    'HTMLCanvasElement.prototype.getContext=function(...a){const gl=get.apply(this,a);' +
    'if(gl&&(a[0]==="webgl"||a[0]==="webgl2"||a[0]==="experimental-webgl")&&!contexts.has(gl)){' +
    'contexts.add(gl);this.addEventListener("webglcontextlost",()=>{' +
    'sharedGpuLost++;for(const r of rows)if(r.gl===gl)r.deleted=true})}return gl};' +
    'for(const p of [window.WebGLRenderingContext?.prototype,window.WebGL2RenderingContext?.prototype]){' +
    'if(!p)continue;const upload=p.texImage2D,remove=p.deleteTexture;' +
    'p.texImage2D=function(...a){const out=upload.apply(this,a);' +
    'if(a[0]===this.TEXTURE_2D&&a[1]===0){const r=entry(this,this.getParameter(this.TEXTURE_BINDING_2D));' +
    'if(r){r.width=a.length>=9?a[3]:a[5]?.width;r.height=a.length>=9?a[4]:a[5]?.height;r.uploads++}}return out};' +
    'p.deleteTexture=function(t){const r=objects.get(t);if(r)r.deleted=true;return remove.call(this,t)}}' +
    'window.gpuWitnessSnapshot=()=>({liveAtlas:rows.filter(r=>!r.deleted&&r.width===1024&&r.height===1024).length,' +
    'atlasUploads:rows.filter(r=>r.width===1024&&r.height===1024).reduce((n,r)=>n+r.uploads,0),' +
    'lost:sharedGpuLost,errors:sharedGpuErrors.slice(),warnings:sharedGpuWarnings.slice(),' +
    'appearance:window.sharedGpuAppearance,textures:rows.map(({gl,...r})=>r)});' +
    'window.gpuWitnessLoseContext=()=>{for(const gl of contexts){const ext=gl.getExtension("WEBGL_lose_context");' +
    'if(ext){ext.loseContext();return true}}return false};' +
    'window.sharedGpuRevision=0;window.sharedGpuAction="";' +
    '})();';

var
  GPage: TBrowserProbe;
  GOutput: String;
  GUrl: String;
  GReport: TJSONObject;
  GChecks: Integer;
  GRevision: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  Inc(GChecks);
  WriteLn('PASS ', AMessage);
end;

procedure Action(const AAction: String);
begin
  Inc(GRevision);
  GPage.Execute('window.sharedGpuFailure="";window.sharedGpuAction=' + QuotedStr(AAction) +
    ';window.sharedGpuRevision=' + IntToStr(GRevision));
  GPage.WaitFor('window.sharedGpuDrawn===' + IntToStr(GRevision) + '||!!window.sharedGpuFailure');
  Check(GPage.Text('window.sharedGpuFailure') = '', AAction + ' acknowledged after drawing');
end;

procedure Capture(const AName: String; const AExpectedModels, AExpectedAtlas: Integer);
var
  LSnapshot: TJSONData;
begin
  Check(GPage.Number('JSON.parse(sharedGpuState).models') = AExpectedModels,
    AName + ' exact model count');
  Check(GPage.Number('gpuWitnessSnapshot().liveAtlas') = AExpectedAtlas,
    AName + ' actual live GPU atlas count');
  Check(GPage.Number('JSON.parse(sharedGpuState).textureProfilePixels') =
    AExpectedAtlas * 1024 * 1024, AName + ' profile agrees with actual GPU atlas pixels');
  Check(GPage.Number('sharedGpuErrors.length') = 0, AName + ' no runtime errors');
  LSnapshot := GPage.Evaluate('({renderer:JSON.parse(sharedGpuState),gpu:gpuWitnessSnapshot()})');
  GReport.Add(AName, LSnapshot);
  GPage.Screenshot(GOutput + '/' + AName + '.png', True);
end;

procedure BeginModels(const AShared, AAlterSampler: Boolean);
var
  LShared: String;
  LAlter: String;
begin
  GPage.Navigate(GUrl);
  GRevision := 0;
  GPage.WaitFor('!!window.sharedGpuReady&&!!window.phanesCatalogFetchProbe');
  LShared := LowerCase(BoolToStr(AShared, True));
  LAlter := LowerCase(BoolToStr(AAlterSampler, True));
  GPage.Execute('window.sharedGpuUseShared=' + LShared + ';window.sharedGpuAlterSampler=' + LAlter +
    ';window.sharedGpuFetchError="";window.sharedGpuFetchDone=false;window.sharedGpuBundles=[];' +
    '(async()=>{for(const name of ["armchair","couch","bed_single_A","bed_double_A",' +
    '"chair_A","chair_stool","table_medium","table_low"]){sharedGpuBundles.push(' +
    'await phanesCatalogFetchProbe.fetch("kaykit-furniture-bits-1-0","kaykit-furniture-bits-1-0/gltf/"+name))}' +
    'sharedGpuFetchDone=true})().catch(e=>sharedGpuFetchError=String(e))');
  GPage.WaitFor('sharedGpuFetchDone||!!sharedGpuFetchError');
  Check(GPage.Text('sharedGpuFetchError') = '', 'All eight complete closures fetched and verified');
  Action('load');
  Check(GPage.Number('JSON.parse(sharedGpuState).triangles') = 3146,
    'Real WASM scenes retain all 3146 triangles');
  GPage.Execute('for(const b of sharedGpuBundles)phanesCatalogFetchProbe.release(b.lease);' +
    'phanesCatalogFetchProbe.clear();window.sharedGpuBundles=null');
  Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0,
    'Browser file cache released after scene lease construction');
end;

var
  LUploads: Double;
begin
  Require(ParamCount = 3, 'Usage: shared-gpu-check BROWSER URL EVIDENCE');
  GUrl := ParamStr(2);
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GReport := TJSONObject.Create;
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
      GPage.InstallScript(Instrumentation);
      GPage.Resize(1000, 750);
      BeginModels(False, False);
      Capture('isolated-eight', 8, 8);
      Action('half');
      Capture('isolated-four', 4, 4);
      LUploads := GPage.Number('gpuWitnessSnapshot().atlasUploads');
      Action('reload');
      Capture('isolated-four-reloaded', 4, 4);
      Check(GPage.Number('gpuWitnessSnapshot().atlasUploads') = LUploads + 4,
        'Four isolated survivors upload four recreated GPU textures');
      Action('clear');
      Capture('isolated-clear', 0, 0);

      BeginModels(True, False);
      Capture('shared-eight', 8, 1);
      Check(GPage.Number('JSON.parse(sharedGpuState).sourceBytes') = 175004,
        'Shared renderer retains complete source bytes including notices');
      GPage.Resize(390, 844);
      GPage.Screenshot(GOutput + '/shared-eight-phone.png', True);
      GPage.Resize(1000, 750);
      Action('half');
      Capture('shared-four', 4, 1);
      LUploads := GPage.Number('gpuWitnessSnapshot().atlasUploads');
      Action('reload');
      Capture('shared-four-reloaded', 4, 1);
      Check(GPage.Number('gpuWitnessSnapshot().atlasUploads') = LUploads + 1,
        'Four shared survivors upload one recreated GPU texture');
      Check(GPage.Text('gpuWitnessLoseContext()') = 'true', 'Real context loss requested');
      GPage.WaitFor('sharedGpuLost===1');
      GReport.Add('contextLoss', GPage.Evaluate('gpuWitnessSnapshot()'));
      BeginModels(True, False);
      Capture('shared-fresh-context', 8, 1);
      Action('clear');
      Capture('shared-clear', 0, 0);

      BeginModels(True, True);
      Capture('shared-sampler-variant', 8, 2);
      Check(GPage.Number('JSON.parse(sharedGpuState).images') = 1,
        'Sampler variant still shares decoded image while requiring a distinct GPU texture');
      Action('half');
      Capture('shared-sampler-variant-released', 4, 1);
      GReport.Add('passed', True);
      GReport.Add('qualification',
        'Diagnostic WebGL upload/resource witness, not production residency or phone performance acceptance');
    except
      on LException: Exception do
      begin
        GReport.Add('failure', LException.Message);
        GReport.Add('lastState', GPage.Evaluate('({state:window.sharedGpuState,' +
          'failure:window.sharedGpuFailure,gpu:window.gpuWitnessSnapshot?.()})'));
        GPage.Screenshot(GOutput + '/failure.png', True);
        raise;
      end;
    end;
  finally
    GReport.Add('checks', GChecks);
    WriteTextAtomic(GOutput + '/evidence.json', GReport.FormatJSON);
    GReport.Free;
    GPage.Free;
  end;
end.
