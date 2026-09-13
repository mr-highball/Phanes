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

program PhanesRecoveryStorageBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils,
  FPJSON,
  JSONParser,
  phanes.tools.browser,
  phanes.tools.files;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GEvidence: TJSONObject;
  GChecks: TJSONArray;

function NormalJSON(const AText: String): String;
var
  LValue: TJSONData;
begin
  LValue := GetJSON(AText, True);
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

function ReadStored: String;
begin
  Result := GPage.Text('phanesRecoveryStorage.readStored()');
  Require((Result <> '') and (Result <> 'null'), 'Missing actual recovery record');
end;

function LiveCore: String;
begin
  Result := GPage.Text('JSON.stringify({world:phanesEditor.world,' +
    'history:phanesEditor.history,future:phanesEditor.future,' +
    'selection:phanesEditor.selection,camera:{camera:phanesEditor.camera,' +
    'zoom:phanesEditor.zoom,yaw:phanesEditor.yaw,pitch:phanesEditor.pitch,' +
    'x:phanesEditor.x,y:phanesEditor.y,z:phanesEditor.z,panX:phanesEditor.panX,' +
    'panY:phanesEditor.panY,panZ:phanesEditor.panZ}})');
end;

function StoredCore(const AStored: String): String;
var
  LRecord: TJSONObject;
  LCore: TJSONObject;
begin
  LRecord := TJSONObject(GetJSON(AStored, True));
  try
    LCore := TJSONObject.Create;
    try
      LCore.Add('world', LRecord.Find('world').Clone);
      LCore.Add('history', LRecord.Find('history').Clone);
      LCore.Add('future', LRecord.Find('future').Clone);
      LCore.Add('selection', LRecord.Find('selection').Clone);
      LCore.Add('camera', LRecord.Find('camera').Clone);
      Result := LCore.AsJSON;
    finally
      LCore.Free;
    end;
  finally
    LRecord.Free;
  end;
end;

procedure CreateBaseline;
var
  LStored: String;
begin
  GPage.WaitFor('document.body.dataset.startupState==="ready"', 180000);
  GPage.SetValue('region-size', '4');
  GPage.Click('#create-world');
  GPage.WaitFor('phanesEditor.world && !phanesEditor.worker && ' +
    'Number(document.body.dataset.renderedRevision)===phanesSceneVersion', 180000);
  GPage.WaitFor('window.phanesSessionSaved===true && ' +
    'window.phanesSessionSavedRevision===window.phanesSessionSavingRevision', 30000);
  LStored := ReadStored;
  Check(NormalJSON(StoredCore(LStored)) = NormalJSON(LiveCore),
    'A complete good checkpoint exists in native IndexedDB');
  WriteText(GOutput + '/baseline.json', UTF8String(LStored));
end;

procedure QueuedSaveCase;
var
  LBeforeRevision: Double;
  LLive: String;
  LStored: String;
begin
  LBeforeRevision := GPage.Number('phanesSessionSavedRevision');
  GPage.Execute('phanesRecoveryStorage.armQueuedSave();' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('phanesRecoveryStorage.stats.secondSaveRequests===1 && ' +
    'window.phanesSessionSaved===true && ' +
    'window.phanesSessionSavedRevision===window.phanesSessionSavingRevision && ' +
    'window.phanesSessionSavedRevision>=' + FloatToStr(LBeforeRevision + 2), 30000);
  LLive := LiveCore;
  LStored := ReadStored;
  Check(GPage.Number('phanesRecoveryStorage.stats.queuedMutations') = 1,
    'The session changed after the first native put request started');
  Check(GPage.Number('phanesRecoveryStorage.stats.secondSaveRequests') = 1,
    'A second save was requested while the first transaction was in flight');
  Check(NormalJSON(StoredCore(LStored)) = NormalJSON(LLive),
    'The follow-up transaction commits the latest exact world, history, future and selection');
  Check(GPage.Text('JSON.stringify(phanesEditor.selection)') =
    '{"x":1,"z":2,"width":2,"depth":1}',
    'The persisted checkpoint includes the selection changed during the first save');
  WriteText(GOutput + '/committed-latest.json', UTF8String(LStored));
end;

procedure ReadFailureCase;
var
  LBaseline: String;
  LMessage: String;
  LStored: String;
begin
  LBaseline := ReadStored;
  GPage.Execute('phanesRecoveryStorage.prepareReadFailure();location.reload()');
  GPage.WaitFor('document.body.dataset.rendererState==="failed"', 180000);
  LMessage := GPage.Text('document.getElementById("recovery-message").textContent');
  Check(GPage.Text('sessionStorage.getItem("phanes-storage-read-aborts")') = '1',
    'The fixture aborted the real readonly transaction after its native get request');
  Check(Pos('could not be read', LMessage) > 0,
    'Read failure explains that the saved workspace could not be read');
  Check(GPage.Text('!document.getElementById("recover-renderer").hidden') = 'true',
    'Read failure offers the visible recovery retry action');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Read transaction failure is handled without an uncaught browser error');
  LStored := ReadStored;
  Check(NormalJSON(LStored) = NormalJSON(LBaseline),
    'The complete good database checkpoint survives the failed read transaction');
  GPage.Screenshot(GOutput + '/read-failed.png');
  GPage.Click('#recover-renderer');
  GPage.WaitFor('document.body.dataset.rendererState==="ready" && ' +
    'phanesEditor.world && !phanesRecovering', 180000);
  Check(NormalJSON(LiveCore) = NormalJSON(StoredCore(LBaseline)),
    'Retry restores the exact world, history, future, selection and camera');
  Check(NormalJSON(ReadStored) = NormalJSON(LBaseline),
    'Successful retry leaves the original checkpoint bytes logically unchanged');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Read failure and retry leave no uncaught browser errors');
end;

procedure LateReadAbortCase;
var
  LBaseline: String;
begin
  LBaseline := ReadStored;
  GPage.Execute('phanesRecoveryStorage.prepareLateReadAbort();location.reload()');
  GPage.WaitFor('sessionStorage.getItem("phanes-storage-read-late-aborts")==="1"', 30000);
  Sleep(1500);
  Check(GPage.Text('document.body.dataset.rendererState==="failed"') = 'true',
    'Aborting the readonly transaction after get success enters a failed recovery state');
  Check(GPage.Text('document.getElementById("recovery-message").textContent.includes(' +
    '"could not be read")') = 'true',
    'Late read-transaction abort gives a useful read failure explanation');
  Check(GPage.Text('!document.getElementById("recover-renderer").hidden') = 'true',
    'Late read-transaction abort offers a visible recovery retry action');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Late read-transaction abort is handled without an uncaught browser error');
  Check(NormalJSON(ReadStored) = NormalJSON(LBaseline),
    'Late read-transaction abort preserves the complete good checkpoint');
  GPage.Click('#recover-renderer');
  GPage.WaitFor('document.body.dataset.rendererState==="ready" && ' +
    'phanesEditor.world && !phanesRecovering', 180000);
  Check(NormalJSON(LiveCore) = NormalJSON(StoredCore(LBaseline)),
    'Retry after late transaction abort restores the exact retained session');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Late transaction abort and retry leave no uncaught browser errors');
end;

procedure SynchronousReadFailureCase;
var
  LBaseline: String;
begin
  LBaseline := ReadStored;
  GPage.Execute('phanesRecoveryStorage.prepareSynchronousReadFailure();location.reload()');
  GPage.WaitFor('sessionStorage.getItem("phanes-storage-read-throws")==="1"', 30000);
  Sleep(500);
  Check(GPage.Text('document.body.dataset.rendererState==="failed"') = 'true',
    'Synchronous saved-data get failure enters a failed recovery state');
  Check(GPage.Text('!document.getElementById("recover-renderer").hidden') = 'true',
    'Synchronous saved-data get failure offers a visible retry action');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Synchronous saved-data get failure is caught by the recovery controller');
  Check(NormalJSON(ReadStored) = NormalJSON(LBaseline),
    'Synchronous saved-data get failure preserves the complete good checkpoint');
  GPage.Click('#recover-renderer');
  GPage.WaitFor('document.body.dataset.rendererState==="ready" && ' +
    'phanesEditor.world && !phanesRecovering', 180000);
  Check(NormalJSON(LiveCore) = NormalJSON(StoredCore(LBaseline)),
    'Retry after synchronous get failure restores the exact retained session');
  Check(GPage.Text('phanesRecoveryStorage.errors.length===0') = 'true',
    'Synchronous get failure and retry leave no uncaught browser errors');
end;

procedure SizePreflightCase;
var
  LBaseline: String;
  LFailedLive: String;
  LStored: String;
begin
  LBaseline := ReadStored;
  GPage.Execute('phanesRecoveryStorage.inflateHistory();' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('document.body.dataset.recoverySave==="failed"', 30000);
  LFailedLive := LiveCore;
  Check(GPage.Text('window.phanesSessionSaved===false') = 'true',
    'The oversized current session is not advertised as saved');
  Check(GPage.Text('document.getElementById("toast").textContent.includes(' +
    '"Recovery storage")') = 'true',
    'Size-preflight failure gives useful storage and portable-save guidance');
  LStored := ReadStored;
  Check(NormalJSON(LStored) = NormalJSON(LBaseline),
    'Size-preflight failure preserves the complete prior IndexedDB checkpoint');
  Check(NormalJSON(LiveCore) = NormalJSON(LFailedLive),
    'Size-preflight failure preserves exact live world, history, future and selection state');
  GPage.Screenshot(GOutput + '/size-preflight-failed.png');
  GPage.Execute('phanesRecoveryStorage.deflateHistory();' +
    'window.dispatchEvent(new Event("pagehide"))');
  GPage.WaitFor('window.phanesSessionSaved===true && ' +
    'window.phanesSessionSavedRevision===window.phanesSessionSavingRevision && ' +
    'document.body.dataset.recoverySave==="saved"', 30000);
  LStored := ReadStored;
  Check(NormalJSON(StoredCore(LStored)) = NormalJSON(LiveCore),
    'After resolving the size cause, retry commits the exact current session');
  WriteText(GOutput + '/committed-after-size-retry.json', UTF8String(LStored));
end;

procedure Run;
var
  LCase: String;
  LGuid: TGuid;
  LProbe: UTF8String;
  LProfile: String;
begin
  Require(ParamCount = 5,
    'Usage: recovery-storage BROWSER URL EVIDENCE COMPILED-PROBE CASE');
  LCase := ParamStr(5);
  Require((LCase = 'queued-save') or (LCase = 'read-failure') or
    (LCase = 'read-late-abort') or (LCase = 'read-sync-throw') or
    (LCase = 'size-preflight'), 'Unknown recovery storage case');
  GOutput := ExpandFileName(ParamStr(3));
  Require(not DirectoryExists(GOutput), 'Use a fresh evidence directory');
  ForceDirectories(GOutput);
  CreateGUID(LGuid);
  LProfile := GOutput + '/profile-' + GUIDToString(LGuid);
  GEvidence := TJSONObject.Create(['case', LCase, 'url', ParamStr(2),
    'probeSha256', HashFile(ParamStr(4)),
    'driverBinarySha256', HashFile(ParamStr(0)),
    'method', 'Pascal WFC CDP with native IndexedDB transactions',
    'faultScope', 'Deterministic test injection; no OS or browser quota fault is claimed']);
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
      GPage.Resize(1280, 900);
      GPage.Navigate(ParamStr(2));
      CreateBaseline;
      if LCase = 'queued-save' then
      begin
        QueuedSaveCase;
      end
      else if LCase = 'read-failure' then
      begin
        ReadFailureCase;
      end
      else if LCase = 'read-late-abort' then
      begin
        LateReadAbortCase;
      end
      else if LCase = 'read-sync-throw' then
      begin
        SynchronousReadFailureCase;
      end
      else
      begin
        SizePreflightCase;
      end;
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
