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
program PhanesStartupProbe;

{$mode delphi}
{$H+}

uses
  JS, Web;

var
  GCase: String;
  GInstantiate: TJSFunction;
  GFetch: TJSFunction;
  GHistory: TJSArray;
  GRequests: TJSObject;
  GEngineParts: TJSArray;
  GTarget: String;
  GTargetCount: Integer;

function Instantiate(ABytes, AImports: JSValue): JSValue;
begin
  if GCase = 'slow-compile' then
  begin
    Exit(TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
      begin
        TJSObject(window)['phanesStartupTestResume'] := procedure
          begin
            AResolve(GInstantiate.apply(TJSObject(TJSObject(window)['WebAssembly']),
              [ABytes, AImports]));
          end;
      end));
  end;
  if GCase = 'compile-failure' then
  begin
    Exit(TJSPromise.reject(TJSError.new('Injected WebAssembly compilation failure')));
  end;
  Result := TJSPromise(GInstantiate.apply(TJSObject(TJSObject(window)['WebAssembly']),
    [ABytes, AImports]))._then(
    function(AValue: JSValue): JSValue
    var
      LExports: TJSObject;
      LInstance: TJSObject;
      LOriginalExports: TJSObject;
      LKey: String;
    begin
      LOriginalExports := TJSObject(TJSObject(TJSObject(AValue)['instance'])['exports']);
      LExports := TJSObject.new;
      for LKey in TJSObject.keys(LOriginalExports) do
      begin
        LExports[LKey] := LOriginalExports[LKey];
      end;
      LExports['_initialize'] := procedure
        begin
          if GCase = 'late-initialize' then
          begin
            TJSFunction(LOriginalExports['_initialize']).apply(nil, []);
          end;
          raise TJSError.new('Injected initialization failure');
        end;
      LInstance := TJSObject.new;
      LInstance['exports'] := LExports;
      TJSObject(AValue)['instance'] := LInstance;
      Result := AValue;
    end);
end;

function Fetch(AResource, AOptions: JSValue): JSValue;
var
  LUrl: String;
begin
  LUrl := String(AResource);
  if Pos('runtime/parts/', LUrl) > 0 then
  begin
    if not GRequests.hasOwnProperty(LUrl) then
    begin
      GRequests[LUrl] := 0;
      if Pos('asset=phanes.wasm', LUrl) > 0 then
      begin
        GEngineParts.push(LUrl);
        if GEngineParts.length = 3 then
        begin
          GTarget := LUrl;
          TJSObject(window)['phanesStartupTestTarget'] := GTarget;
        end;
      end;
    end;
    GRequests[LUrl] := Integer(GRequests[LUrl]) + 1;
    if (LUrl = GTarget) and (GTarget <> '') then
    begin
      Inc(GTargetCount);
      if (GCase = 'part-recovery') and (GTargetCount <= 2) then
      begin
        Exit(TJSPromise.reject(TJSError.new('Injected interrupted part')));
      end;
      if GCase = 'part-corrupt' then
      begin
        { Keep the real digest options. Native Fetch must reject these actual
          wrong HTTP bytes before the host sees a response. }
        Exit(GFetch.apply(window, ['runtime/test-corrupt.part', AOptions]));
      end;
      if GCase = 'part-cancel' then
      begin
        TJSFunction(TJSObject(TJSObject(window)['phanesStartup'])['fail']).apply(
          TJSObject(TJSObject(window)['phanesStartup']), ['Injected cancellation during transfer']);
        TJSObject(window)['phanesStartupTestAborted'] :=
          Boolean(TJSObject(TJSObject(AOptions)['signal'])['aborted']);
      end;
    end;
  end;
  if (GCase = 'slow-catalog') and (Pos('data/palette.json', LUrl) > 0) then
  begin
    Exit(TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
      begin
        TJSObject(window)['phanesStartupTestResume'] := procedure
          begin
            AResolve(GFetch.apply(window, [AResource, AOptions]));
          end;
      end));
  end;
  Result := GFetch.apply(window, [AResource, AOptions]);
end;

begin
  GCase := String(TJSObject(window)['phanesStartupTestCase']);
  GHistory := TJSArray.new;
  TJSObject(window)['phanesStartupTestHistory'] := GHistory;
  window.setInterval(procedure
    var
      LState: String;
    begin
      if document.body = nil then
      begin
        Exit;
      end;
      LState := document.body.getAttribute('data-startup-state');
      if (LState <> '') and ((GHistory.length = 0) or (GHistory[GHistory.length - 1] <> LState)) then
      begin
        GHistory.push(LState);
      end;
    end, 1);
  if (GCase = 'caught-initialize') or (GCase = 'compile-failure') or
    (GCase = 'slow-compile') or (GCase = 'late-initialize') then
  begin
    GInstantiate := TJSFunction(TJSObject(TJSObject(window)['WebAssembly'])['instantiate']);
    TJSObject(TJSObject(window)['WebAssembly'])['instantiate'] := @Instantiate;
  end;
  GRequests := TJSObject.new;
  GEngineParts := TJSArray.new;
  TJSObject(window)['phanesStartupTestRequests'] := GRequests;
  TJSObject(window)['phanesStartupTestEngineParts'] := GEngineParts;
  begin
    GFetch := TJSFunction(TJSObject(window)['fetch']);
    TJSObject(window)['fetch'] := @Fetch;
  end;
end.
