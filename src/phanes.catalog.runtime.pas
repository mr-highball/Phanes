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
unit phanes.catalog.runtime;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartCatalogRuntime;

implementation

uses
  JS, Web, SysUtils, phanes.catalog.fetch, phanes.catalog.admission;

type
  TPublicationActions = class external name 'Object'(TJSObject)
    procedure updateControls;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TCatalogRuntime = class
  private
    FFetcher: TCatalogFetcher;
    FRequest: Integer;
    FMessage: Integer;
    FWorldRevision: Integer;
    FSelection: String;
    FStarted: Double;
    FBusy: Boolean;
    FCommitting: Boolean;
    FTimer: Integer;
    function SelectionStamp: String;
    function RequiredIds(const AWorld: TJSObject): TOptionalAssetIds;
    function IsPrepared(const AId: String): Boolean;
    procedure CheckRequest(const ARequest: Integer);
    procedure SetBusy(const AValue: Boolean);
    procedure CheckContext;
    function Stage(const AAdmission: TOptionalAssetAdmission;
      const ABundle: TJSObject; const ARequest: Integer): Boolean; async;
    function Event(AEvent: TJSEvent): Boolean;
  public
    constructor Create;
    procedure Cancel;
    function Publish(const AWorld: TJSObject; const ACommit: TJSFunction): Boolean; async;
  end;

var
  GRuntime: TCatalogRuntime;

function Browser: TJSObject;
begin
  Result := TJSObject(window);
end;

function Actions: TPublicationActions;
begin
  Result := TPublicationActions(Browser['phanesEditorActions']);
end;

constructor TCatalogRuntime.Create;
var
  LBridge: TJSObject;
begin
  inherited Create;
  FFetcher := TCatalogFetcher.Create('data/library-files.json', 16 * 1024 * 1024);
  Browser['phanesCatalogRequestId'] := 0;
  Browser['phanesCatalogStageRevision'] := 0;
  Browser['phanesCatalogStageAck'] := 0;
  Browser['phanesCatalogStageError'] := '';
  Browser['phanesCatalogLoading'] := False;
  LBridge := TJSObject.new;
  LBridge['publish'] := @Publish;
  LBridge['cancel'] := @Cancel;
  Browser['phanesCatalogRuntime'] := LBridge;
  document.addEventListener('visibilitychange', @Event);
  document.addEventListener('freeze', @Event);
  window.addEventListener('pagehide', @Event);
  window.addEventListener('phanes-startup-failed', @Event);
end;

function TCatalogRuntime.SelectionStamp: String;
var
  LState: TJSObject;
  LParts: TJSArray;
begin
  LState := TJSObject(Browser['phanesEditor']);
  LParts := TJSArray.new;
  LParts.push(LState['selection']);
  LParts.push(LState['interiorRoom']);
  LParts.push(LState['interiorSelected']);
  LParts.push(Browser['phanesGroundworkSelection']);
  LParts.push(Browser['phanesModularSelected']);
  Result := TJSJSON.stringify(LParts);
end;

function TCatalogRuntime.RequiredIds(const AWorld: TJSObject): TOptionalAssetIds;
var
  LSeen: TJSObject;
  LComposition: TJSObject;
  LNodes: TJSArray;
  LLayers: TJSArray;
  LValues: TJSArray;
  LIds: TOptionalAssetIds;
  LLayer: Integer;
  I: Integer;
  procedure Include(const AId: String; const ADomain: TOptionalAssetDomain);
  var
    LAdmission: TOptionalAssetAdmission;
  begin
    if Pos('phanes.catalog.', AId) <> 1 then
    begin
      Exit;
    end;
    if not OptionalAssetAdmission(AId, LAdmission) or
      ((LAdmission.FDomain <> ADomain) and
      not ((ADomain = oadInterior) and (LAdmission.FDomain = oadFurnishing))) then
    begin
      raise Exception.Create('This catalog item is not admitted for this placement: ' + AId);
    end;
    if not LSeen.hasOwnProperty(AId) then
    begin
      LSeen[AId] := True;
      SetLength(LIds, Length(LIds) + 1);
      LIds[High(LIds)] := AId;
    end;
  end;
begin
  SetLength(LIds, 0);
  LSeen := TJSObject.new;
  LComposition := TJSObject(AWorld['composition']);
  if (LComposition = nil) or not TJSArray.isArray(LComposition['nodes']) then
  begin
    raise Exception.Create('World has no validated composition');
  end;
  LNodes := TJSArray(LComposition['nodes']);
  for I := 0 to LNodes.length - 1 do
  begin
    Include(String(TJSObject(LNodes[I])['asset']), oadInterior);
  end;
  if not TJSArray.isArray(AWorld['layers']) then
  begin
    raise Exception.Create('World has no validated regional layers');
  end;
  LLayers := TJSArray(AWorld['layers']);
  if LLayers.length <> 5 then
  begin
    raise Exception.Create('World has incomplete regional layers');
  end;
  for LLayer := 0 to 4 do
  begin
    if not TJSArray.isArray(LLayers[LLayer]) then
    begin
      raise Exception.Create('World has an invalid regional layer');
    end;
    LValues := TJSArray(LLayers[LLayer]);
    for I := 0 to LValues.length - 1 do
    begin
      if (LLayer <> 4) and (Pos('phanes.catalog.', String(LValues[I])) = 1) then
      begin
        raise Exception.Create('This catalog item requires an ecological placement');
      end;
      Include(String(LValues[I]), oadRegional);
    end;
  end;
  Result := LIds;
end;

function TCatalogRuntime.IsPrepared(const AId: String): Boolean;
var
  LReady: TJSArray;
begin
  Result := False;
  if not isString(Browser['phanesCatalogReadyIds']) then
  begin
    Exit;
  end;
  LReady := TJSArray(TJSJSON.parse(String(Browser['phanesCatalogReadyIds'])));
  Result := LReady.indexOf(AId) >= 0;
end;

procedure TCatalogRuntime.CheckRequest(const ARequest: Integer);
begin
  if (ARequest <> FRequest) or
    (FWorldRevision <> Integer(Browser['phanesSceneVersion'])) or
    (FSelection <> SelectionStamp) then
  begin
    raise Exception.Create('The world or selection changed while loading');
  end;
  if window.performance.now - FStarted > 180000 then
  begin
    raise Exception.Create('Optional models took too long to prepare; please retry');
  end;
  if Browser['phanesWorldSuspended'] = True then
  begin
    raise Exception.Create('Model loading was interrupted while the view was suspended');
  end;
end;

procedure TCatalogRuntime.SetBusy(const AValue: Boolean);
begin
  if FTimer <> 0 then
  begin
    window.clearInterval(FTimer);
    FTimer := 0;
  end;
  FBusy := AValue;
  Browser['phanesCatalogLoading'] := AValue;
  if AValue then
  begin
    FTimer := window.setInterval(@CheckContext, 100);
  end;
  Actions.updateControls;
end;

procedure TCatalogRuntime.CheckContext;
begin
  if FBusy and not FCommitting and
    ((FWorldRevision <> Integer(Browser['phanesSceneVersion'])) or
    (FSelection <> SelectionStamp) or document.hidden or
    (Browser['phanesWorldSuspended'] = True)) then
  begin
    Cancel;
  end;
end;

procedure TCatalogRuntime.Cancel;
begin
  if FCommitting then
  begin
    Exit;
  end;
  Inc(FRequest);
  Browser['phanesCatalogRequestId'] := FRequest;
  FFetcher.Cancel;
  Browser['phanesCatalogStage'] := nil;
  if FBusy then
  begin
    TJSHTMLElement(document.getElementById('status')).textContent := 'World unchanged';
    SetBusy(False);
  end;
end;

function TCatalogRuntime.Event(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if document.hidden or (AEvent._type = 'phanes-startup-failed') or
    (AEvent._type = 'freeze') or (AEvent._type = 'pagehide') then
  begin
    Cancel;
  end;
end;

function TCatalogRuntime.Stage(const AAdmission: TOptionalAssetAdmission;
  const ABundle: TJSObject; const ARequest: Integer): Boolean;
var
  LMessage: TJSObject;
  LRevision: Integer;
  LWait: JSValue;
begin
  CheckRequest(ARequest);
  if String(ABundle['manifestSha256']) <> AAdmission.FManifestSha256 then
  begin
    raise Exception.Create('The catalog source revision changed; this item needs readmission');
  end;
  Inc(FMessage);
  LRevision := FMessage;
  LMessage := TJSObject.new;
  LMessage['request'] := ARequest;
  LMessage['asset'] := AAdmission.FId;
  LMessage['bundle'] := ABundle;
  Browser['phanesCatalogStage'] := LMessage;
  Browser['phanesCatalogStageRevision'] := LRevision;
  repeat
    CheckRequest(ARequest);
    if Browser['phanesCatalogStageAck'] = LRevision then
    begin
      if String(Browser['phanesCatalogStageError']) <> '' then
      begin
        raise Exception.Create(String(Browser['phanesCatalogStageError']));
      end;
      Break;
    end;
    LWait := await(JSValue, TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
      begin
        window.setTimeout(procedure
          begin
            AResolve(True);
          end, 25);
      end));
  until False;
  CheckRequest(ARequest);
  Browser['phanesCatalogStage'] := nil;
  Result := True;
end;

function TCatalogRuntime.Publish(const AWorld: TJSObject;
  const ACommit: TJSFunction): Boolean;
var
  LRequest: Integer;
  LIds: TOptionalAssetIds;
  LId: String;
  LAdmission: TOptionalAssetAdmission;
  LBundle: TJSObject;
  LStaged: Boolean;
begin
  Result := False;
  Cancel;
  LRequest := FRequest;
  FWorldRevision := Integer(Browser['phanesSceneVersion']);
  FSelection := SelectionStamp;
  FStarted := window.performance.now;
  try
    LIds := RequiredIds(AWorld);
    if Length(LIds) > 0 then
    begin
      SetBusy(True);
    end;
    for LId in LIds do
    begin
      CheckRequest(LRequest);
      if IsPrepared(LId) then
      begin
        Continue;
      end;
      OptionalAssetAdmission(LId, LAdmission);
      TJSHTMLElement(document.getElementById('status')).textContent :=
        'Loading ' + String(LAdmission.FName) + '…';
      LBundle := await(FFetcher.FetchModel(LAdmission.FKitId, LAdmission.FModelId));
      try
        LStaged := await(Stage(LAdmission, LBundle, LRequest));
      finally
        FFetcher.Release(String(LBundle['lease']));
      end;
    end;
    CheckRequest(LRequest);
    FCommitting := True;
    try
      ACommit.call(nil);
    finally
      FCommitting := False;
    end;
    Result := True;
  except
    on LException: Exception do
    begin
      if LRequest = FRequest then
      begin
        Actions.notify('Could not prepare this world: ' + LException.Message, True);
        TJSHTMLElement(document.getElementById('status')).textContent := 'World unchanged';
      end;
    end
    else
    begin
      { Fetch rejects with JavaScript TypeError/DOMException objects, which are
        not Pascal Exception descendants. Cancellation rejects too; superseded
        requests remain silent and must not change the replacement's controls. }
      if LRequest = FRequest then
      begin
        Actions.notify('Could not prepare this world: the optional model download failed. Please retry.', True);
        TJSHTMLElement(document.getElementById('status')).textContent := 'World unchanged';
      end;
    end;
  end;
  if LRequest = FRequest then
  begin
    Browser['phanesCatalogStage'] := nil;
    SetBusy(False);
  end;
end;

procedure StartCatalogRuntime;
begin
  GRuntime := TCatalogRuntime.Create;
end;

end.
