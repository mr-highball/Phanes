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
program PhanesRecoveryEntryProbe;

{$mode delphi}
{$H+}

uses
  JS, Web;

var
  GPost: TJSFunction;
  GTerminate: TJSFunction;
  GHeldWorker: TJSWorker;
  GResponse: TJSObject;
  GArmed: Boolean;
  GBridge: TJSObject;

procedure PostMessage(AValue, ATransfer: JSValue);
var
  LRequest: TJSObject;
  LWorker: TJSWorker;
begin
  if GArmed and isObject(AValue) and (AValue <> nil) and
    (TJSObject(AValue)['operation'] = 'create-interior') then
  begin
    GArmed := False;
    GHeldWorker := TJSWorker(JSThis);
    LRequest := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
    GBridge['held'] := True;
    { Resolve the actual request on a separate native Worker, retaining its
      valid response while the application's original Worker stays pending.
      A later dispatch to the terminated original EventTarget is deterministic
      stale-event injection, not a claim about browser event delivery. }
    LWorker := TJSWorker.new('world-worker.js');
    LWorker.addEventListener('message', TJSEventHandler(function(AEvent: TJSEvent): Boolean
      begin
        GResponse := TJSObject(TJSMessageEvent(AEvent).data);
        GBridge['responseReady'] := True;
        GBridge['responseSuccess'] := GResponse['success'];
        LWorker.terminate;
        Result := True;
      end));
    GPost.apply(LWorker, [LRequest]);
    Exit;
  end;
  if isDefined(ATransfer) then
  begin
    GPost.apply(JSThis, [AValue, ATransfer]);
  end else
  begin
    GPost.apply(JSThis, [AValue]);
  end;
end;

procedure Terminate;
begin
  if JSThis = GHeldWorker then
  begin
    GBridge['terminated'] := True;
    window.sessionStorage.setItem('phanes-entry-test-terminated', 'true');
  end;
  GTerminate.apply(JSThis, []);
end;

procedure Arm;
begin
  GArmed := True;
  GResponse := nil;
  GBridge['held'] := False;
  GBridge['terminated'] := False;
  GBridge['responseReady'] := False;
  GBridge['responseSuccess'] := False;
  window.sessionStorage.removeItem('phanes-entry-test-terminated');
end;

procedure EmitLate;
var
  LEvent: TJSEvent;
begin
  if (GResponse = nil) or (GHeldWorker = nil) or
    not Boolean(GBridge['terminated']) then
  begin
    raise TJSError.new('A resolved, cancelled entry is required');
  end;
  LEvent := TJSEvent.new('message');
  TJSObject(LEvent)['data'] := GResponse;
  GHeldWorker.dispatchEvent(LEvent);
  GBridge['lateDispatched'] := True;
end;

var
  GPrototype: TJSObject;
begin
  GBridge := TJSObject.new;
  GBridge['arm'] := @Arm;
  GBridge['emitLate'] := @EmitLate;
  TJSObject(window)['phanesRecoveryEntry'] := GBridge;
  GPrototype := TJSObject(TJSObject(TJSObject(window)['Worker'])['prototype']);
  GPost := TJSFunction(GPrototype['postMessage']);
  GTerminate := TJSFunction(GPrototype['terminate']);
  GPrototype['postMessage'] := @PostMessage;
  GPrototype['terminate'] := @Terminate;
end.
