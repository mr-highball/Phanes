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

unit phanes.session.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartSessionUI;

implementation

uses
  JS, Web, WebOrWorker, SysUtils;

type
  TPreparedCallback = procedure;

  TSessionDialog = class external name 'HTMLDialogElement'(TJSHTMLElement)
    open: Boolean;
    procedure showModal;
    procedure close;
  end;

  TSessionActions = class external name 'Object'(TJSObject)
    procedure publish(const AWorld: TJSObject; const ARemember: Boolean);
    function prepareWorld(const AWorld: TJSObject;
      const ACallback: TPreparedCallback): TJSPromise;
    procedure cancelSolve;
    procedure cancelPointer;
    procedure updateControls;
    procedure setCamera(const AMode: String);
    procedure syncSelection;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TSessionController = class external name 'Object'(TJSObject)
    function snapshot: TJSObject;
    procedure restoreCheckpoint(const AValue: TJSObject);
    procedure restoreTools(const AHidden: Boolean);
    procedure cancelEntry;
  end;

  TSessionUI = class
  private
    FState: TJSObject;
    FActions: TSessionActions;
    FDatabase: TIDBDatabase;
    FKey: String;
    FSaved: Boolean;
    FSaving: Boolean;
    FSaveAgain: Boolean;
    FLost: Boolean;
    FRestoring: Boolean;
    FFailed: Boolean;
    FReloaded: Boolean;
    FPending: TJSObject;
    FRawSaved: TJSObject;
    FWorker: TJSWorker;
    FRestoreStart: Double;
    FLastSave: Double;
    FRevision: Integer;
    FSaveRevision: Integer;
    FSaveWarning: Boolean;
    FStorageUnavailable: Boolean;
    function Event(AEvent: TJSEvent): Boolean;
    function Click(AEvent: TJSEvent): Boolean;
    procedure OpenDatabase;
    procedure Load;
    procedure Save;
    procedure SaveFailed;
    procedure Tick;
    procedure Lost;
    procedure Recover;
    procedure Admit;
    procedure Apply(const AValue: TJSObject; const AAssets: TJSArray);
    procedure ApplyPrepared(const AValue: TJSObject; const AAssets: TJSArray);
    procedure Message(const AText: String; const AFailed: Boolean = False);
    function Snapshot: TJSObject;
  public
    constructor Create;
  end;

const
  CCameraFields: array[0..9] of String =
    ('camera', 'zoom', 'yaw', 'pitch', 'x', 'y', 'z', 'panX', 'panY', 'panZ');

var
  GSession: TSessionUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

function Controller(const AName: String): TSessionController;
begin
  Result := TSessionController(TJSObject(window)[AName]);
end;

constructor TSessionUI.Create;
begin
  inherited Create;
  FState := TJSObject(TJSObject(window)['phanesEditor']);
  FActions := TSessionActions(TJSObject(window)['phanesEditorActions']);
  FRestoreStart := window.performance.now;
  try
    FKey := window.sessionStorage.getItem('phanes-session-key');
    if not isString(FKey) then
    begin
      FKey := '';
    end;
    FRestoring := FKey <> '';
    if FKey = '' then
    begin
      FKey := FloatToStr(TJSDate.now) + '-' + FloatToStr(Random);
      window.sessionStorage.setItem('phanes-session-key', FKey);
    end;
    FReloaded := (window.sessionStorage.getItem('phanes-recovery') = 'reload') or
      (window.sessionStorage.getItem('phanes-recovery') = 'reload-empty');
    FRestoring := FRestoring or FReloaded;
  except
    FKey := '';
    FStorageUnavailable := True;
  end;
  TJSObject(window)['phanesRecovering'] := FRestoring;
  TJSObject(window)['phanesWorldSuspended'] := document.hidden;
  Element('castle-canvas').addEventListener('webglcontextlost', @Event);
  document.addEventListener('visibilitychange', @Event);
  document.addEventListener('freeze', @Event);
  document.addEventListener('resume', @Event);
  window.addEventListener('pagehide', @Event);
  window.addEventListener('pageshow', @Event);
  window.addEventListener('phanes-world-published', @Event);
  Element('recover-renderer').addEventListener('click', @Click);
  Element('renderer-recovery').addEventListener('cancel', @Event);
  Element('recovery-export').addEventListener('click', @Click);
  OpenDatabase;
  window.setInterval(@Tick, 500);
end;

procedure TSessionUI.Message(const AText: String; const AFailed: Boolean);
begin
  Element('renderer-recovery').hidden := False;
  if not TSessionDialog(Element('renderer-recovery')).open then
  begin
    TSessionDialog(Element('renderer-recovery')).showModal;
  end;
  Element('recovery-message').textContent := AText;
  Element('recover-renderer').hidden := not AFailed;
  Element('recovery-export').hidden := (FState['world'] = nil) and (FRawSaved = nil);
  Element('recovery-export').textContent := 'Export world';
  if (FState['world'] = nil) and (FRawSaved <> nil) then
  begin
    Element('recovery-export').textContent := 'Export recovery data';
  end;
  Element('status').textContent := AText;
  document.body.setAttribute('data-renderer-state', 'recovering');
  if AFailed then
  begin
    FFailed := True;
    document.body.setAttribute('data-renderer-state', 'failed');
    Element('recover-renderer').focus;
  end;
end;

procedure TSessionUI.OpenDatabase;
var
  LRequest: TJSIDBOpenDBRequest;
begin
  try
    if FKey = '' then
    begin
      Exit;
    end;
    LRequest := window.indexedDB.open('phanes-recovery', 1);
    LRequest.onupgradeneeded := function(AEvent: TJSEvent): Boolean
      begin
        LRequest.resultAsDatabase.createObjectStore('sessions');
        Result := True;
      end;
    LRequest.onsuccess := function(AEvent: TJSEvent): Boolean
      begin
        FDatabase := LRequest.resultAsDatabase;
        Load;
        Result := True;
      end;
    LRequest.onerror := function(AEvent: TJSEvent): Boolean
      begin
        FStorageUnavailable := True;
        if FRestoring then
        begin
          Message('Saved workspace is unavailable. Retry recovery or export your world.', True);
        end;
        Result := True;
      end;
    LRequest.onblocked := function(AEvent: TJSEvent): Boolean
      begin
        FStorageUnavailable := True;
        if FRestoring then
        begin
          Message('Workspace storage is busy in another tab. Close that tab, then retry.', True);
        end;
        Result := True;
      end;
  except
    FStorageUnavailable := True;
    if FRestoring then
    begin
      Message('Workspace storage is unavailable. Retry recovery.', True);
    end;
  end;
end;

procedure TSessionUI.Load;
var
  LTransaction: TJSIDBTransaction;
  LRequest: TJSIDBRequest;
  LValue: JSValue;
  LReadFailed: Boolean;

  procedure ReadFailed;
  begin
    if not LReadFailed and not FFailed then
    begin
      LReadFailed := True;
      Message('The saved workspace could not be read. Retry recovery.', True);
    end;
  end;

begin
  if not FRestoring then
  begin
    Exit;
  end;
  Message('Restoring your workspace…');
  FRestoreStart := window.performance.now;
  LReadFailed := False;
  LValue := nil;
  try
    LTransaction := FDatabase.transaction(['sessions']);
    { A successful get request is not a completed read transaction. Keep its
      result private until completion so an abort cannot start world admission. }
    LTransaction.addEventListener('complete', TJSEventHandler(function(AEvent: TJSEvent): Boolean
      begin
        Result := True;
        if LReadFailed or FFailed or not FRestoring then
        begin
          Exit;
        end;
        if isObject(LValue) and (LValue <> nil) then
        begin
          FPending := TJSObject(LValue);
          FRawSaved := FPending;
        end else
        begin
          if FReloaded and (window.sessionStorage.getItem('phanes-recovery') <> 'reload-empty') then
          begin
            Message('No saved workspace was found for this tab.', True);
          end else
          begin
            FRestoring := False;
            TJSObject(window)['phanesRecovering'] := False;
            TSessionDialog(Element('renderer-recovery')).close;
            Element('renderer-recovery').hidden := True;
            FActions.updateControls;
          end;
        end;
      end));
    LTransaction.addEventListener('abort', TJSEventHandler(function(AEvent: TJSEvent): Boolean
      begin
        ReadFailed;
        Result := True;
      end));
    LRequest := LTransaction.objectStore('sessions').get(FKey);
    LRequest.onsuccess := function(AEvent: TJSEvent): Boolean
      begin
        LValue := LRequest.result;
        Result := True;
      end;
    LRequest.onerror := function(AEvent: TJSEvent): Boolean
      begin
        ReadFailed;
        Result := True;
      end;
  except
    { Browser storage APIs can throw JavaScript values, not Pascal Exceptions. }
    ReadFailed;
  end;
end;

function TSessionUI.Snapshot: TJSObject;
var
  LCamera: TJSObject;
  LKey: String;
begin
  Result := TJSObject.new;
  Result['format'] := 'phanes.session/v1';
  Result['world'] := FState['world'];
  Result['history'] := FState['history'];
  Result['future'] := FState['future'];
  Result['selection'] := FState['selection'];
  Result['editing'] := FState['editing'];
  LCamera := TJSObject.new;
  for LKey in CCameraFields do
  begin
    LCamera[LKey] := FState[LKey];
  end;
  Result['camera'] := LCamera;
  Result['interior'] := Controller('phanesInteriorUI').snapshot;
  Result['groundwork'] := Controller('phanesGroundworkUI').snapshot;
  Result['modular'] := Controller('phanesBuildingUI').snapshot;
  Result['landforms'] := Controller('phanesLandformUI').snapshot;
  Result['quality'] := TJSHTMLSelectElement(Element('render-quality')).value;
  Result['style'] := Controller('phanesStyleUI').snapshot;
  Result['toolsCollapsed'] := document.body.classList.contains('tools-collapsed');
end;

procedure TSessionUI.SaveFailed;
begin
  FSaving := False;
  FSaved := False;
  TJSObject(window)['phanesSessionSaved'] := False;
  document.body.setAttribute('data-recovery-save', 'failed');
  if FLost then
  begin
    Message('Could not save recovery data. Export your world before retrying.', True);
  end else if not FSaveWarning then
  begin
    FSaveWarning := True;
    FActions.notify('Recovery storage is unavailable. Export your world to keep a portable save.', True);
  end;
end;

procedure TSessionUI.Save;
var
  LTransaction: TJSIDBTransaction;
  LSnapshot: TJSObject;
  LRevision: Integer;
  LStack: TJSArray;
  LKey: String;
  I: Integer;
const
  CStacks: array[0..1] of String = ('history', 'future');
  procedure CheckWorldSize(const AWorld: TJSObject);
  begin
    if Length(TJSJSON.stringify(AWorld)) > 8 * 1024 * 1024 then
    begin
      raise Exception.Create('A world exceeds the recovery allowance.');
    end;
  end;
begin
  if FRestoring or (FState['world'] = nil) then
  begin
    Exit;
  end;
  if FDatabase = nil then
  begin
    if FStorageUnavailable or (FKey = '') then
    begin
      SaveFailed;
    end;
    Exit;
  end;
  if FSaving then
  begin
    FSaveAgain := True;
    Exit;
  end;
  LTransaction := nil;
  try
    FSaving := True;
    FSaved := False;
    TJSObject(window)['phanesSessionSaved'] := False;
    Inc(FSaveRevision);
    LRevision := FSaveRevision;
    TJSObject(window)['phanesSessionSavingRevision'] := LRevision;
    FLastSave := window.performance.now;
    LSnapshot := Snapshot;
    if Length(TJSJSON.stringify(LSnapshot)) > 32 * 1024 * 1024 then
    begin
      raise Exception.Create('The workspace exceeds the recovery allowance.');
    end;
    CheckWorldSize(TJSObject(LSnapshot['world']));
    for LKey in CStacks do
    begin
      LStack := TJSArray(LSnapshot[LKey]);
      for I := 0 to LStack.length - 1 do
      begin
        CheckWorldSize(TJSObject(LStack[I]));
      end;
    end;
    LTransaction := FDatabase.transaction(['sessions'], 'readwrite');
    LTransaction.addEventListener('complete', TJSEventHandler(function(AEvent: TJSEvent): Boolean
      begin
        FSaving := False;
        FSaved := True;
        FSaveWarning := False;
        document.body.setAttribute('data-recovery-save', 'saved');
        TJSObject(window)['phanesSessionSaved'] := True;
        TJSObject(window)['phanesSessionSavedRevision'] := LRevision;
        if FSaveAgain then
        begin
          FSaveAgain := False;
          Save;
        end else if FLost then
        begin
          Recover;
        end;
        Result := True;
      end));
    LTransaction.addEventListener('abort', TJSEventHandler(function(AEvent: TJSEvent): Boolean
      begin
        SaveFailed;
        Result := True;
      end));
    LTransaction.objectStore('sessions').put(LSnapshot, FKey);
  except
    if LTransaction <> nil then
    begin
      LTransaction.abort;
    end;
    SaveFailed;
  end;
end;

function TSessionUI.Event(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if AEvent._type = 'cancel' then
  begin
    AEvent.preventDefault;
    Exit;
  end;
  if AEvent._type = 'webglcontextlost' then
  begin
    AEvent.preventDefault;
    Lost;
    Exit;
  end;
  if AEvent._type = 'phanes-world-published' then
  begin
    window.setTimeout(procedure
      begin
        Save;
      end, 0);
    Exit;
  end;
  TJSObject(window)['phanesWorldSuspended'] := document.hidden or FLost or
    (AEvent._type = 'freeze');
  FActions.cancelPointer;
  if document.hidden or (AEvent._type = 'pagehide') or (AEvent._type = 'freeze') then
  begin
    if Boolean(TJSObject(window)['phanesEnteringInterior']) then
    begin
      FActions.cancelSolve;
      Controller('phanesInteriorUI').cancelEntry;
    end;
    Save;
  end else if FLost then
  begin
    Recover;
  end;
end;

procedure TSessionUI.Lost;
begin
  if not Boolean(FState['ready']) then
  begin
    Exit;
  end;
  FLost := True;
  TJSObject(window)['phanesRecovering'] := True;
  TJSObject(window)['phanesWorldSuspended'] := True;
  FActions.cancelSolve;
  Controller('phanesInteriorUI').cancelEntry;
  FActions.cancelPointer;
  window.dispatchEvent(TJSEvent.new('blur'));
  FActions.updateControls;
  Message('Graphics paused. Saving your place…');
  if FReloaded then
  begin
    Message('Graphics stopped again. Your saved workspace is retained. Retry when ready.', True);
    Exit;
  end;
  Save;
  Recover;
end;

procedure TSessionUI.Recover;
begin
  if document.hidden or FFailed or FSaving then
  begin
    Exit;
  end;
  if (FState['world'] <> nil) and not FSaved then
  begin
    Message('Recovery needs a saved workspace. Export your world, then retry.', True);
    Exit;
  end;
  try
    if FState['world'] = nil then
    begin
      window.sessionStorage.setItem('phanes-recovery', 'reload-empty');
    end else
    begin
      window.sessionStorage.setItem('phanes-recovery', 'reload');
    end;
    window.location.reload(False);
  except
    Message('Recovery could not restart. Export your world before refreshing.', True);
  end;
end;

procedure TSessionUI.Admit;
var
  LRequest: TJSObject;
  LWorker: TJSWorker;
begin
  if (FPending = nil) or (FWorker <> nil) or not Boolean(FState['ready']) or
    (document.body.getAttribute('data-startup-state') <> 'ready') then
  begin
    Exit;
  end;
  Message('Checking your saved world and edit history…');
  FRestoreStart := window.performance.now;
  FWorker := TJSWorker.new('world-worker.js');
  LWorker := FWorker;
  FWorker.addEventListener('message', TJSEventHandler(function(AEvent: TJSEvent): Boolean
    var
      LResponse: TJSObject;
    begin
      Result := True;
      if FFailed or (FWorker <> LWorker) then
      begin
        Exit;
      end;
      LResponse := TJSObject(TJSMessageEvent(AEvent).data);
      FWorker.terminate;
      FWorker := nil;
      FPending := nil;
      if LResponse['success'] = True then
      begin
        try
          Apply(TJSObject(LResponse['session']), TJSArray(LResponse['interiorAssets']));
        except
          on E: Exception do
          begin
            Message('Saved workspace could not be restored: ' + E.Message, True);
          end;
        end;
      end else
      begin
        Message('Saved workspace could not be validated: ' + String(LResponse['message']), True);
      end;
    end));
  FWorker.addEventListener('error', TJSEventHandler(function(AEvent: TJSEvent): Boolean
    begin
      Result := True;
      if FFailed or (FWorker <> LWorker) then
      begin
        Exit;
      end;
      FWorker.terminate;
      FWorker := nil;
      FPending := nil;
      Message('Recovery validation stopped. Your saved data is retained.', True);
      Result := True;
    end));
  LRequest := TJSObject.new;
  LRequest['operation'] := 'restore-session';
  LRequest['session'] := FPending;
  LRequest['assets'] := TJSObject(FState['palette'])['assets'];
  LRequest['job'] := 0;
  FWorker.postMessage(LRequest);
end;

procedure TSessionUI.Apply(const AValue: TJSObject; const AAssets: TJSArray);
begin
  FActions.prepareWorld(TJSObject(AValue['world']), procedure
    begin
      ApplyPrepared(AValue, AAssets);
    end)._then(function(AResult: JSValue): JSValue
    begin
      if not Boolean(AResult) then
      begin
        Message('Saved workspace catalog models could not be prepared.', True);
      end;
      Result := AResult;
    end, function(AReason: JSValue): JSValue
    begin
      Message('Saved workspace catalog models could not be prepared.', True);
      Result := AReason;
    end);
end;

procedure TSessionUI.ApplyPrepared(const AValue: TJSObject; const AAssets: TJSArray);
var
  LKey: String;
  LCamera: TJSObject;
begin
  FState['selection'] := AValue['selection'];
  FState['editing'] := AValue['editing'];
  FState['interiorAssets'] := AAssets;
  FActions.publish(TJSObject(AValue['world']), False);
  FState['history'] := AValue['history'];
  FState['future'] := AValue['future'];
  Controller('phanesGroundworkUI').restoreCheckpoint(TJSObject(AValue['groundwork']));
  if isDefined(AValue['modular']) then
  begin
    Controller('phanesBuildingUI').restoreCheckpoint(TJSObject(AValue['modular']));
  end;
  if isDefined(AValue['landforms']) then
  begin
    Controller('phanesLandformUI').restoreCheckpoint(TJSObject(AValue['landforms']));
  end;
  Controller('phanesInteriorUI').restoreCheckpoint(TJSObject(AValue['interior']));
  if isObject(AValue['style']) and (AValue['style'] <> nil) then
  begin
    Controller('phanesStyleUI').restoreCheckpoint(TJSObject(AValue['style']));
  end;
  FState['selection'] := AValue['selection'];
  Controller('phanesNavigationUI').restoreTools(AValue['toolsCollapsed'] = True);
  if (AValue['quality'] = 'balanced') or (AValue['quality'] = 'detail') or
    (AValue['quality'] = 'smooth') then
  begin
    TJSHTMLSelectElement(Element('render-quality')).value := String(AValue['quality']);
    Element('render-quality').dispatchEvent(TJSEvent.new('change'));
  end;
  LCamera := TJSObject(AValue['camera']);
  for LKey in CCameraFields do
  begin
    FState[LKey] := LCamera[LKey];
  end;
  FActions.setCamera(String(FState['camera']));
  FRevision := Integer(TJSObject(window)['phanesSceneVersion']);
  Message('Drawing your restored world…');
  FRestoreStart := window.performance.now;
end;

procedure TSessionUI.Tick;
begin
  if FRestoring and not FFailed then
  begin
    Admit;
    if (FRevision > 0) and
      (document.body.getAttribute('data-rendered-revision') = IntToStr(FRevision)) and
      (TJSObject(window)['phanesRenderedCameraVersion'] = TJSObject(window)['phanesCameraVersion']) then
    begin
      FRestoring := False;
      TJSObject(window)['phanesRecovering'] := False;
      TSessionDialog(Element('renderer-recovery')).close;
      Element('renderer-recovery').hidden := True;
      document.body.setAttribute('data-renderer-state', 'ready');
      Element('status').textContent := 'Workspace restored';
      window.sessionStorage.removeItem('phanes-recovery');
      FActions.updateControls;
    end else if (FRestoreStart > 0) and not document.hidden and
      (window.performance.now - FRestoreStart > 180000) then
    begin
      if FWorker <> nil then
      begin
        FWorker.terminate;
        FWorker := nil;
      end;
      FPending := nil;
      Message('Recovery is taking longer than expected. Your saved workspace is retained.', True);
    end;
  end else if not FLost and not document.hidden and
    (window.performance.now - FLastSave > 10000) then
  begin
    Save;
  end;
end;

function TSessionUI.Click(AEvent: TJSEvent): Boolean;
var
  LBlob: TJSBlob;
  LLink: TJSHTMLAnchorElement;
  LUrl: String;
begin
  Result := True;
  if TJSElement(AEvent.currentTarget).id = 'recovery-export' then
  begin
    if (FState['world'] = nil) and (FRawSaved <> nil) then
    begin
      LBlob := TJSBlob.new([TJSJSON.stringify(FRawSaved)]);
      LUrl := TJSURL.createObjectURL(LBlob);
      LLink := TJSHTMLAnchorElement(document.createElement('a'));
      LLink.href := LUrl;
      LLink.download := 'phanes-recovery.json';
      LLink.click;
      window.setTimeout(procedure
        begin
          TJSURL.revokeObjectURL(LUrl);
        end, 1000);
      Exit;
    end;
    { Export remains available while all editing is suspended. }
    TJSHTMLButtonElement(Element('save-world')).disabled := False;
    Element('save-world').click;
    TJSHTMLButtonElement(Element('save-world')).disabled := True;
    Exit;
  end;
  FFailed := False;
  if FRestoring then
  begin
    window.location.reload(False);
  end else
  begin
    FReloaded := False;
    Save;
    Recover;
  end;
end;

procedure StartSessionUI;
begin
  GSession := TSessionUI.Create;
end;

end.
