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

program PhanesRecoveryCriticProbe;

{$mode delphi}
{$H+}

uses
  JS,
  Web,
  WebOrWorker,
  SysUtils,
  phanes.session.wire,
  phanes.world.wire;

var
  GApi: TJSObject;
  GStats: TJSObject;
  GErrors: TJSArray;
  GPut: TJSFunction;
  GPost: TJSFunction;
  GTerminate: TJSFunction;
  GNow: TJSFunction;
  GAnchorClick: TJSFunction;
  GMode: String;
  GClockOffset: Double;
  GHeldWorker: TJSWorker;
  GHeldRequest: TJSObject;
  GStored: TJSObject;

function Prototype(const AName: String): TJSObject;
begin
  Result := TJSObject(TJSObject(TJSObject(window)[AName])['prototype']);
end;

procedure Count(const AName: String);
begin
  GStats[AName] := Integer(GStats[AName]) + 1;
end;

function CopyObject(const AValue: TJSObject): TJSObject;
begin
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
end;

function Put(AValue, AKey: JSValue): JSValue;
var
  LRequest: TJSIDBRequest;
  LTransaction: TJSIDBTransaction;
begin
  { Preserve the native receiver and native IDB transaction. Only the named
    recovery store is eligible; ordinary database reads are not replaced. }
  if (JSThis['name'] = 'sessions') and (GMode = 'put-throw') then
  begin
    Count('putThrows');
    raise TJSError.new('Critic injected synchronous recovery put failure');
  end;

  Result := GPut.apply(JSThis, [AValue, AKey]);
  if (JSThis['name'] = 'sessions') and (GMode = 'abort') then
  begin
    LRequest := TJSIDBRequest(Result);
    LTransaction := TJSIDBTransaction(JSThis['transaction']);
    LRequest.addEventListener('success', TJSEventHandler(
      function(AEvent: TJSEvent): Boolean
      begin
        { Abort after a successful native put request but before its containing
          transaction commits. This tests rollback of real stored bytes. }
        Count('successfulPutsBeforeAbort');
        LTransaction.abort;
        Count('transactionAborts');
        Result := True;
      end));
  end;
end;

procedure PostMessage(AValue, ATransfer: JSValue);
begin
  if (GMode = 'hold-restore') and isObject(AValue) and (AValue <> nil) and
    (TJSObject(AValue)['operation'] = 'restore-session') then
  begin
    GHeldWorker := TJSWorker(JSThis);
    GHeldRequest := CopyObject(TJSObject(AValue));
    Count('heldRestores');
    Exit;
  end;
  if isDefined(ATransfer) then
  begin
    GPost.apply(JSThis, [AValue, ATransfer]);
  end
  else
  begin
    GPost.apply(JSThis, [AValue]);
  end;
end;

procedure Terminate;
begin
  if JSThis = GHeldWorker then
  begin
    Count('heldWorkerTerminations');
  end;
  GTerminate.apply(JSThis, []);
end;

function Now: Double;
begin
  Result := Double(GNow.apply(window.performance, [])) + GClockOffset;
end;

procedure Arm(const AMode: String);
begin
  if (AMode <> '') and (AMode <> 'put-throw') and (AMode <> 'abort') then
  begin
    raise TJSError.new('Unknown critic storage fault');
  end;
  { Faults remain armed until the driver has inspected the old DB record and
    downloaded the live save. Autosave cannot erase the failed-write evidence. }
  GMode := AMode;
end;

procedure PrepareRestoreTimeout;
begin
  window.sessionStorage.setItem('phanes-critic-recovery-mode', 'hold-restore');
end;

procedure ExpireRestore;
begin
  if (GHeldWorker = nil) or (GHeldRequest = nil) then
  begin
    raise TJSError.new('No restore worker is held');
  end;
  { Artificial monotonic elapsed time, not a performance measurement. The
    normal 500 ms controller tick still executes its actual timeout branch. }
  GClockOffset := 181000;
end;

procedure ResetClock;
begin
  GClockOffset := 0;
end;

procedure EmitLate(const AKind: String);
var
  LEvent: TJSEvent;
  LResponse: TJSObject;
begin
  if (GHeldWorker = nil) or (GHeldRequest = nil) then
  begin
    raise TJSError.new('No old worker is available for a late event');
  end;
  if AKind = 'success' then
  begin
    LResponse := TJSObject.new;
    LResponse['job'] := GHeldRequest['job'];
    LResponse['session'] := ValidateSession(TJSObject(GHeldRequest['session']),
      TJSArray(GHeldRequest['assets']));
    LResponse['interiorAssets'] := InteriorCatalogJSON;
    LResponse['success'] := True;
    LEvent := TJSEvent.new('message');
    TJSObject(LEvent)['data'] := LResponse;
  end
  else if AKind = 'error' then
  begin
    LEvent := TJSEvent.new('error');
  end
  else
  begin
    raise TJSError.new('Unknown critic late event');
  end;
  { Dispatch to the old real Worker EventTarget after native termination, not
    directly to a private controller method. This is deterministic fault
    injection; it does not claim a browser spontaneously emitted this event. }
  Count('lateEvents');
  GHeldWorker.dispatchEvent(LEvent);
end;

function ReadStored: TJSPromise;
begin
  Result := TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
    var
      LOpen: TJSIDBOpenDBRequest;
    begin
      try
        LOpen := window.indexedDB.open('phanes-recovery', 1);
        LOpen.onerror := function(AEvent: TJSEvent): Boolean
          begin
            AReject(TJSError.new('Critic could not open the recovery database'));
            Result := True;
          end;
        LOpen.onsuccess := function(AEvent: TJSEvent): Boolean
          var
            LDatabase: TIDBDatabase;
            LTransaction: TJSIDBTransaction;
            LRead: TJSIDBRequest;
          begin
            Result := True;
            LDatabase := LOpen.resultAsDatabase;
            LTransaction := LDatabase.transaction(['sessions'], 'readonly');
            LRead := LTransaction.objectStore('sessions').get(
              window.sessionStorage.getItem('phanes-session-key'));
            LRead.onsuccess := function(AReadEvent: TJSEvent): Boolean
              begin
                GStored := CopyObject(TJSObject(LRead.result));
                AResolve(TJSJSON.stringify(GStored));
                Result := True;
              end;
            LRead.onerror := function(AReadEvent: TJSEvent): Boolean
              begin
                AReject(TJSError.new('Critic could not read the recovery record'));
                Result := True;
              end;
            LTransaction.addEventListener('complete', TJSEventHandler(
              function(ACompleteEvent: TJSEvent): Boolean
              begin
                LDatabase.close;
                Result := True;
              end));
          end;
      except
        on LException: Exception do
        begin
          AReject(TJSError.new(LException.Message));
        end;
      end;
    end);
end;

function ValidateExport(const AText: String): Boolean;
var
  LEnvelope: TJSObject;
  LSession: TJSObject;
  LState: TJSObject;
begin
  if GStored = nil then
  begin
    raise TJSError.new('Read an actual checkpoint before validating the export');
  end;
  LEnvelope := TJSObject(TJSJSON.parse(AText));
  if (LEnvelope['version'] <> 2) and (LEnvelope['version'] <> 3) then
  begin
    raise TJSError.new('Unexpected downloaded world envelope');
  end;
  LState := TJSObject(TJSObject(window)['phanesEditor']);
  LSession := CopyObject(GStored);
  LSession['world'] := LEnvelope['world'];
  { Neither fixture changes world size or removes its baseline room. Reuse the
    admitted stored controller context to validate the downloaded world with
    the same whole-world validator used by restore-session. The house fixture
    separately checks that the current selected object and indoor pose remain. }
  ValidateSession(LSession, TJSArray(TJSObject(LState['palette'])['assets']));
  Result := True;
end;

function WindowError(AEvent: TJSEvent): Boolean;
begin
  GErrors.push(String(TJSObject(AEvent)['message']));
  Result := True;
end;

procedure AnchorClick;
var
  LDownload: TJSObject;
begin
  if isString(JSThis['download']) and (JSThis['download'] <> '') then
  begin
    LDownload := TJSObject.new;
    LDownload['name'] := JSThis['download'];
    LDownload['href'] := JSThis['href'];
    TJSArray(GStats['downloadsIssued']).push(LDownload);
  end;
  GAnchorClick.apply(JSThis, []);
end;

procedure MakeDownloadControl;
var
  LButton: TJSHTMLButtonElement;
begin
  LButton := TJSHTMLButtonElement(document.createElement('button'));
  LButton.id := 'critic-download-control';
  LButton.textContent := 'Download fixture control';
  LButton.onclick := function(AEvent: TJSMouseEvent): Boolean
    var
      LLink: TJSHTMLAnchorElement;
      LUrl: String;
    begin
      LLink := TJSHTMLAnchorElement(document.createElement('a'));
      LUrl := TJSURL.createObjectURL(TJSBlob.new(['{"control":true}']));
      LLink.href := LUrl;
      LLink.download := 'critic-control.json';
      LLink.click;
      Result := True;
    end;
  document.body.appendChild(LButton);
end;

begin
  GApi := TJSObject.new;
  GStats := TJSObject.new;
  GStats['putThrows'] := 0;
  GStats['successfulPutsBeforeAbort'] := 0;
  GStats['transactionAborts'] := 0;
  GStats['heldRestores'] := 0;
  GStats['heldWorkerTerminations'] := 0;
  GStats['lateEvents'] := 0;
  GStats['downloadsIssued'] := TJSArray.new;
  GErrors := TJSArray.new;
  GApi['stats'] := GStats;
  GApi['errors'] := GErrors;
  GApi['arm'] := @Arm;
  GApi['readStored'] := @ReadStored;
  GApi['validateExport'] := @ValidateExport;
  GApi['prepareRestoreTimeout'] := @PrepareRestoreTimeout;
  GApi['expireRestore'] := @ExpireRestore;
  GApi['resetClock'] := @ResetClock;
  GApi['emitLate'] := @EmitLate;
  GApi['makeDownloadControl'] := @MakeDownloadControl;
  TJSObject(window)['phanesRecoveryCritic'] := GApi;
  GPut := TJSFunction(Prototype('IDBObjectStore')['put']);
  Prototype('IDBObjectStore')['put'] := @Put;
  GPost := TJSFunction(Prototype('Worker')['postMessage']);
  Prototype('Worker')['postMessage'] := @PostMessage;
  GTerminate := TJSFunction(Prototype('Worker')['terminate']);
  Prototype('Worker')['terminate'] := @Terminate;
  GNow := TJSFunction(TJSObject(window.performance)['now']);
  TJSObject(window.performance)['now'] := @Now;
  GAnchorClick := TJSFunction(Prototype('HTMLAnchorElement')['click']);
  Prototype('HTMLAnchorElement')['click'] := @AnchorClick;
  if (Pos('http', window.location.protocol) = 1) and
    (window.sessionStorage.getItem('phanes-critic-recovery-mode') = 'hold-restore') then
  begin
    GMode := 'hold-restore';
  end;
  window.addEventListener('error', @WindowError);
end.
