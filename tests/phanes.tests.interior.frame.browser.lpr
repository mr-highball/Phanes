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
program PhanesTestsInteriorFrameBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils, phanes.tools.browser, phanes.tools.files;

const
  Acknowledged =
    'Number(document.body.dataset.renderedInteriorVersion)===phanesInteriorVersion&&' +
    'document.body.dataset.renderedInterior===phanesEditor.interiorRoom&&' +
    'Number(document.body.dataset.renderedInteriorScene)===phanesSceneVersion&&' +
    'phanesRenderedCameraVersion===phanesCameraVersion';
  FrameGate =
    '(()=>{const raf=requestAnimationFrame.bind(window);' +
    'window.frameRegression={hold:false,pending:[],frames:[],picks:[],errors:[]};' +
    'window.requestAnimationFrame=cb=>raf(t=>{' +
    'if(frameRegression.hold)frameRegression.pending.push(cb);else cb(t)});' +
    'window.resumeFrameRegression=()=>{frameRegression.hold=false;' +
    'const q=frameRegression.pending.splice(0);for(const cb of q)raf(cb)};' +
    'addEventListener("error",e=>frameRegression.errors.push(e.message));' +
    'addEventListener("unhandledrejection",e=>' +
    'frameRegression.errors.push(String(e.reason)));})();';
  Snapshot =
    'JSON.stringify({viewport:frameRegressionViewport,' +
    'selected:phanesEditor.interiorSelected,interior:phanesInteriorVersion,' +
    'renderedInterior:Number(document.body.dataset.renderedInteriorVersion),' +
    'settings:JSON.parse(phanesInterior),camera:phanesCameraVersion,' +
    'renderedCamera:phanesRenderedCameraVersion,pose:JSON.parse(phanesCamera),' +
    'frames:frameRegression.frames,picks:frameRegression.picks,' +
    'errors:frameRegression.errors,pending:frameRegression.pending.length})';

var
  GPage: TBrowserProbe;
  GOutput: String;
  GChecks: Integer;
  GViewport: String;
  GWorld: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Require(ACondition, AMessage);
  Inc(GChecks);
  WriteLn('PASS ', GViewport, ' ', AMessage);
  Flush(Output);
end;

procedure Capture(const AName: String);
var
  LStem: String;
begin
  LStem := GOutput + '/' + GViewport + '-' + AName;
  WriteTextAtomic(LStem + '.json', GPage.Text(Snapshot));
  GPage.Screenshot(LStem + '.png');
end;

procedure CheckWorld(const AContext: String);
begin
  Check(GPage.Text('JSON.stringify(phanesEditor.world)') = GWorld,
    AContext + ' preserves the exact world');
end;

procedure PauseFrames;
begin
  GPage.Execute('frameRegression.hold=true');
  GPage.WaitFor('frameRegression.pending.length>0');
end;

procedure PrepareTarget(const ARole: String);
begin
  GPage.Execute('window.frameRegressionTarget=phanesEditor.world.composition.nodes.find(' +
    'n=>n.role===''' + ARole + '''&&!!n.support);' +
    'if(!frameRegressionTarget)throw Error("Missing supported ' + ARole + '");' +
    'window.frameRegressionParent=frameRegressionTarget.parent;' +
    'phanesInteriorUI.choose(frameRegressionTarget.id,false)');
  GPage.WaitFor(Acknowledged);
end;

procedure CheckStableFrame(const ARole, ALabel: String);
var
  LDelayedArguments: String;
  LDelayedCamera: String;
  LNormalArguments: String;
  LNormalCamera: String;
begin
  PrepareTarget(ARole);
  GPage.Execute('frameRegression.frames=[]');
  PauseFrames;
  GPage.Click('#interior-frame');
  Check(GPage.Text('phanesRenderedCameraVersion===phanesCameraVersion') = 'true',
    ALabel + ' old camera-only readiness passes while rendering is paused');
  Check(GPage.Text(
    'Number(document.body.dataset.renderedInteriorVersion)<phanesInteriorVersion') = 'true',
    ALabel + ' exact interior acknowledgement remains pending');
  GPage.Click('#interior-parent');
  GPage.Execute('resumeFrameRegression()');
  GPage.WaitFor(Acknowledged);
  LDelayedArguments := GPage.Text('JSON.stringify(frameRegression.frames.at(-1).args)');
  LDelayedCamera := GPage.Text('phanesCamera');
  Check(LDelayedArguments <> '', ALabel + ' delayed frame reports its target bounds');
  CheckWorld(ALabel + ' delayed frame');
  Capture(ALabel + '-delayed');

  PrepareTarget(ARole);
  GPage.Execute('frameRegression.frames=[]');
  GPage.Click('#interior-frame');
  GPage.WaitFor(Acknowledged);
  LNormalArguments := GPage.Text('JSON.stringify(frameRegression.frames.at(-1).args)');
  LNormalCamera := GPage.Text('phanesCamera');
  Check(LDelayedArguments = LNormalArguments,
    ALabel + ' delayed and normally acknowledged frame arguments are exact');
  Check(LDelayedCamera = LNormalCamera,
    ALabel + ' delayed and normally acknowledged full camera poses are exact');
  CheckWorld(ALabel + ' normal frame');
  Capture(ALabel + '-acknowledged');
end;

procedure CheckFruitPick;
var
  LX: Double;
  LY: Double;
begin
  GPage.Click('#interior-parent');
  GPage.WaitFor(Acknowledged);
  LX := GPage.Number(
    '(()=>{const b=document.getElementById("castle-canvas").getBoundingClientRect();' +
    'return b.x+b.width/2})()');
  LY := GPage.Number(
    '(()=>{const b=document.getElementById("castle-canvas").getBoundingClientRect();' +
    'return b.y+b.height/2})()');
  GPage.ClickAt(LX, LY);
  GPage.WaitFor('phanesEditor.interiorSelected===frameRegressionTarget.id');
  Check(GPage.Text('phanesEditor.interiorSelected===frameRegressionTarget.id') = 'true',
    'real center canvas click selects the framed fruit');
  CheckWorld('fruit center pick');
end;

procedure RunViewport(const AWidth, AHeight: Integer; const ALabel: String);
begin
  GViewport := ALabel;
  GPage.Resize(AWidth, AHeight);
  GPage.Navigate(ParamStr(2));
  { A fresh navigation may also restore the preceding viewport's saved world.
    Engine startup alone does not mean the editor has finished that work. }
  GPage.WaitFor('document.body&&document.body.dataset.startupState==="ready"&&' +
    'document.getElementById("create-world")&&' +
    '!document.getElementById("create-world").disabled', 180000);
  GPage.Execute('window.frameRegressionViewport="' + ALabel + '"');
  GPage.SetValue('region-size', '4');
  GPage.SetValue('world-seed', '732');
  GPage.Click('#create-world');
  GPage.WaitFor('!!phanesEditor.world&&!phanesEditor.worker&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  GPage.Execute('phanesEditor.selection={x:1,z:1,width:1,depth:1};' +
    'phanesEditorActions.syncSelection();window.frameRegressionScene=phanesSceneVersion;' +
    'phanesEditorActions.generate("cabin")');
  GPage.WaitFor('phanesSceneVersion>frameRegressionScene&&!phanesEditor.worker&&' +
    '!phanesCatalogLoading&&' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  GPage.Click('#open-interior');
  GPage.WaitFor('phanesEditor.interiorRoom==="building-1-1.studio"&&' + Acknowledged);
  GPage.Execute('const framed=phanesInteriorFrame,picked=phanesInteriorPicked;' +
    'window.phanesInteriorFrame=function(...args){frameRegression.frames.push({' +
    'selected:phanesEditor.interiorSelected,args});return framed.apply(this,args)};' +
    'window.phanesInteriorPicked=function(...args){frameRegression.picks.push(args);' +
    'return picked.apply(this,args)}');
  GWorld := GPage.Text('JSON.stringify(phanesEditor.world)');

  CheckStableFrame('fruit', 'fruit');
  CheckFruitPick;
  CheckStableFrame('book', 'book');
  Check(GPage.Number('frameRegression.errors.length') = 0,
    'browser reports no runtime errors');
  CheckWorld('complete viewport case');
  Capture('complete');
end;

procedure Run;
begin
  { Keep viewport fixtures independent: session restoration has separate
    coverage and can otherwise reopen the preceding fixture's interior panel. }
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile-desktop');
  GPage.InstallScript(FrameGate);
  RunViewport(1440, 960, 'desktop-1440x960');
  FreeAndNil(GPage);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile-phone');
  GPage.InstallScript(FrameGate);
  RunViewport(390, 844, 'phone-390x844');
end;

begin
  Require(ParamCount = 3,
    'Usage: phanes.tests.interior.frame.browser BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  try
    try
      Run;
      WriteTextAtomic(GOutput + '/result.txt',
        'PASS ' + IntToStr(GChecks) + ' checks');
    except
      on LException: Exception do
      begin
        WriteTextAtomic(GOutput + '/failure.txt', LException.Message);
        if Assigned(GPage) then
        begin
          Capture('failure');
        end;
        raise;
      end;
    end;
  finally
    GPage.Free;
  end;
end.
