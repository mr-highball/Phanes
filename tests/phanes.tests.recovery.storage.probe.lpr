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

program PhanesRecoveryStorageProbe;

{$mode delphi}
{$H+}

uses
  JS,
  Web,
  WebOrWorker,
  SysUtils;

var
  GApi: TJSObject;
  GStats: TJSObject;
  GPut: TJSFunction;
  GGet: TJSFunction;
  GErrors: TJSArray;
  GQueueNextSave: Boolean;

function Prototype(const AName: String): TJSObject;
begin
  Result := TJSObject(TJSObject(TJSObject(window)[AName])['prototype']);
end;

function CopyObject(const AValue: TJSObject): TJSObject;
begin
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
end;

procedure Count(const AName: String);
begin
  GStats[AName] := Integer(GStats[AName]) + 1;
end;

function Put(AValue, AKey: JSValue): JSValue;
var
  LState: TJSObject;
  LHistory: TJSArray;
  LSelection: TJSObject;
begin
  { The first write remains a native IndexedDB request in its native
    transaction. Mutation and pagehide happen only after that request starts,
    so the controller must queue and later snapshot a second save. }
  Result := GPut.apply(JSThis, [AValue, AKey]);
  if (JSThis['name'] = 'sessions') and GQueueNextSave then
  begin
    GQueueNextSave := False;
    Count('queuedMutations');
    LState := TJSObject(TJSObject(window)['phanesEditor']);
    LHistory := TJSArray(LState['history']);
    LHistory.push(CopyObject(TJSObject(LState['world'])));
    LSelection := TJSObject.new;
    LSelection['x'] := 1;
    LSelection['z'] := 2;
    LSelection['width'] := 2;
    LSelection['depth'] := 1;
    LState['selection'] := LSelection;
    LState['yaw'] := Double(LState['yaw']) + 0.125;
    window.dispatchEvent(TJSEvent.new('pagehide'));
    Count('secondSaveRequests');
  end;
end;

function Get(AKey: JSValue): JSValue;
var
  LRequest: TJSIDBRequest;
  LTransaction: TJSIDBTransaction;
begin
  if (JSThis['name'] = 'sessions') and
    (window.sessionStorage.getItem('phanes-storage-read-fault') = 'throw-once') then
  begin
    window.sessionStorage.removeItem('phanes-storage-read-fault');
    window.sessionStorage.setItem('phanes-storage-read-throws', '1');
    raise TJSError.new('Storage probe injected synchronous get failure');
  end;
  Result := GGet.apply(JSThis, [AKey]);
  if (JSThis['name'] = 'sessions') and
    (window.sessionStorage.getItem('phanes-storage-read-fault') = 'abort-once') then
  begin
    window.sessionStorage.removeItem('phanes-storage-read-fault');
    window.sessionStorage.setItem('phanes-storage-read-aborts', '1');
    LTransaction := TJSIDBTransaction(JSThis['transaction']);
    LTransaction.abort;
  end;
  if (JSThis['name'] = 'sessions') and
    (window.sessionStorage.getItem('phanes-storage-read-fault') = 'abort-after-success-once') then
  begin
    window.sessionStorage.removeItem('phanes-storage-read-fault');
    LTransaction := TJSIDBTransaction(JSThis['transaction']);
    LRequest := TJSIDBRequest(Result);
    LRequest.addEventListener('success', TJSEventHandler(
      function(AEvent: TJSEvent): Boolean
      begin
        window.sessionStorage.setItem('phanes-storage-read-late-aborts', '1');
        LTransaction.abort;
        Result := True;
      end));
  end;
end;

procedure ArmQueuedSave;
begin
  GQueueNextSave := True;
end;

procedure PrepareReadFailure;
begin
  window.sessionStorage.setItem('phanes-storage-read-fault', 'abort-once');
  window.sessionStorage.removeItem('phanes-storage-read-aborts');
end;

procedure PrepareLateReadAbort;
begin
  window.sessionStorage.setItem('phanes-storage-read-fault', 'abort-after-success-once');
  window.sessionStorage.removeItem('phanes-storage-read-late-aborts');
end;

procedure PrepareSynchronousReadFailure;
begin
  window.sessionStorage.setItem('phanes-storage-read-fault', 'throw-once');
  window.sessionStorage.removeItem('phanes-storage-read-throws');
end;

function WindowError(AEvent: TJSEvent): Boolean;
begin
  GErrors.push(String(TJSObject(AEvent)['message']));
  Result := True;
end;

function ReadStored: TJSPromise;
begin
  Result := TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
    var
      LOpen: TJSIDBOpenDBRequest;
    begin
      LOpen := window.indexedDB.open('phanes-recovery', 1);
      LOpen.onerror := function(AEvent: TJSEvent): Boolean
        begin
          AReject(TJSError.new('Could not open the recovery database'));
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
              AResolve(TJSJSON.stringify(LRead.result));
              Result := True;
            end;
          LRead.onerror := function(AReadEvent: TJSEvent): Boolean
            begin
              AReject(TJSError.new('Could not read the recovery record'));
              Result := True;
            end;
          LTransaction.addEventListener('complete', TJSEventHandler(
            function(ACompleteEvent: TJSEvent): Boolean
            begin
              LDatabase.close;
              Result := True;
            end));
        end;
    end);
end;

procedure InflateHistory;
var
  LChunks: TJSArray;
  LWorld: TJSObject;
  LHistory: TJSArray;
  LState: TJSObject;
  I: Integer;
begin
  LState := TJSObject(TJSObject(window)['phanesEditor']);
  LHistory := TJSArray(LState['history']);
  LWorld := CopyObject(TJSObject(LState['world']));
  LChunks := TJSArray.new;
  for I := 1 to 1152 do
  begin
    LChunks.push(StringOfChar('x', 8192));
  end;
  LWorld['storageProbePadding'] := LChunks.join('');
  LHistory.push(LWorld);
  LState['selection'] := TJSObject.new;
  TJSObject(LState['selection'])['x'] := 2;
  TJSObject(LState['selection'])['z'] := 1;
  TJSObject(LState['selection'])['width'] := 1;
  TJSObject(LState['selection'])['depth'] := 2;
end;

procedure DeflateHistory;
var
  LHistory: TJSArray;
  LWorld: TJSObject;
begin
  LHistory := TJSArray(TJSObject(TJSObject(window)['phanesEditor'])['history']);
  LWorld := TJSObject(LHistory[LHistory.length - 1]);
  LWorld['storageProbePadding'] := Undefined;
end;

begin
  GApi := TJSObject.new;
  GStats := TJSObject.new;
  GStats['queuedMutations'] := 0;
  GStats['secondSaveRequests'] := 0;
  GErrors := TJSArray.new;
  GApi['stats'] := GStats;
  GApi['errors'] := GErrors;
  GApi['armQueuedSave'] := @ArmQueuedSave;
  GApi['prepareReadFailure'] := @PrepareReadFailure;
  GApi['prepareLateReadAbort'] := @PrepareLateReadAbort;
  GApi['prepareSynchronousReadFailure'] := @PrepareSynchronousReadFailure;
  GApi['readStored'] := @ReadStored;
  GApi['inflateHistory'] := @InflateHistory;
  GApi['deflateHistory'] := @DeflateHistory;
  TJSObject(window)['phanesRecoveryStorage'] := GApi;
  GPut := TJSFunction(Prototype('IDBObjectStore')['put']);
  Prototype('IDBObjectStore')['put'] := @Put;
  GGet := TJSFunction(Prototype('IDBObjectStore')['get']);
  Prototype('IDBObjectStore')['get'] := @Get;
  window.addEventListener('error', @WindowError);
end.
