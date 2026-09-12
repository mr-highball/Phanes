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
program PhanesCatalogWorldProbe;

{$mode delphi}
{$H+}

uses
  JS, Web, SysUtils;

var
  GFetch: TJSFunction;
  GHolding: Boolean;
  GHeld: TJSArray;
  GSettled: Integer;
  GBridge: TJSObject;

function Fetch(const AInput, AOptions: JSValue): TJSPromise;
var
  LUrl: String;
begin
  LUrl := String(AInput);
  if not GHolding or (Pos('library', LUrl) = 0) then
  begin
    Exit(TJSPromise(GFetch.apply(window, [AInput, AOptions])));
  end;
  { Delay dispatch, preserving the original AbortSignal. Releasing an already
    cancelled request then exercises the browser's actual rejected fetch. }
  Result := TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
    var
      LRequest: TJSObject;
    begin
      LRequest := TJSObject.new;
      LRequest['input'] := AInput;
      LRequest['options'] := AOptions;
      LRequest['resolve'] := AResolve;
      LRequest['reject'] := AReject;
      GHeld.push(LRequest);
    end);
end;

procedure ReleaseOne(const ARequest: TJSObject);
begin
  TJSPromise(GFetch.apply(window, [ARequest['input'], ARequest['options']]))._then(
    function(AValue: JSValue): JSValue
    begin
      Inc(GSettled);
      TJSPromiseResolver(ARequest['resolve'])(AValue);
      Result := Undefined;
    end,
    function(AReason: JSValue): JSValue
    begin
      Inc(GSettled);
      TJSPromiseResolver(ARequest['reject'])(AReason);
      Result := Undefined;
    end);
end;

procedure Release;
var
  LRequests: TJSArray;
  I: Integer;
begin
  GHolding := False;
  LRequests := GHeld;
  GHeld := TJSArray.new;
  for I := 0 to LRequests.length - 1 do
  begin
    ReleaseOne(TJSObject(LRequests[I]));
  end;
end;

procedure Hold;
begin
  if GHeld.length <> 0 then
  begin
    raise Exception.Create('Release the previous held catalog requests first');
  end;
  GHolding := True;
end;

function Count: Integer;
begin
  Result := GHeld.length;
end;

function Settled: Integer;
begin
  Result := GSettled;
end;

begin
  GFetch := TJSFunction(TJSObject(window)['fetch']);
  GHeld := TJSArray.new;
  TJSObject(window)['fetch'] := @Fetch;
  GBridge := TJSObject.new;
  GBridge['hold'] := @Hold;
  GBridge['release'] := @Release;
  GBridge['count'] := @Count;
  GBridge['settled'] := @Settled;
  TJSObject(window)['phanesCatalogWorldProbe'] := GBridge;
end.
