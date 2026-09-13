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

program PhanesWorker;

{$mode delphi}
{$H+}

uses
  JS,
  WebOrWorker,
  WebWorker,
  SysUtils,
  phanes.world.types,
  phanes.world.wire,
  phanes.world.generate,
  phanes.landforms.types,
  phanes.terrain.types,
  phanes.session.wire;

function Receive(AEvent: TJSEvent): Boolean;
var
  LRequest: TJSObject;
  LResponse: TJSObject;
  LWorld: TWorld;
  LParsed: TWorldRequest;
  LReason: String;
  LSuccess: Boolean;
begin
  Result := True;
  LRequest := TJSObject(TJSMessageEvent(AEvent).Data);
  LResponse := TJSObject.new;
  LResponse['job'] := 0;
  try
    if isObject(LRequest) and (LRequest <> nil) and not isArray(LRequest) then
    begin
      LResponse['job'] := LRequest['job'];
    end;
    if LRequest['operation'] = 'restore-session' then
    begin
      LResponse['session'] := ValidateSession(TJSObject(LRequest['session']),
        TJSArray(LRequest['assets']));
      LResponse['interiorAssets'] := InteriorCatalogJSON;
      LResponse['success'] := True;
      Self_.postMessage(LResponse);
      Exit;
    end;
    LParsed := ReadRequest(LRequest);
    LSuccess := GenerateWorld(LParsed, LWorld, LReason);
    LResponse['success'] := LSuccess;
    LResponse['message'] := LReason;
    if LSuccess then
    begin
      LResponse['unchanged'] := IsLandformOperation(LParsed.FOperation) and
        (LWorld.FRelativeElevation = LParsed.FPrevious.FRelativeElevation) and
        SameTerrainField(LWorld.FElevation, LParsed.FPrevious.FElevation);
      LResponse['world'] := WorldJSON(LWorld);
      LResponse['interiorAssets'] := InteriorCatalogJSON;
    end;
  except
    on LException: Exception do
    begin
      LResponse['success'] := False;
      LResponse['message'] := LException.Message;
    end;
    else
    begin
      LResponse['success'] := False;
      LResponse['message'] := 'The world request could not be read.';
    end;
  end;
  Self_.postMessage(LResponse);
end;

begin
  Self_.addEventListener('message', @Receive);
end.
