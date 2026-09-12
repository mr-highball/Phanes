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

unit phanes.navigation.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartNavigationUI;

implementation

uses
  JS, Web, SysUtils, Math, Types;

type
  TNavigationState = class external name 'Object'(TJSObject)
    world: TJSObject;
    worker: TJSObject;
    camera: String;
    editing: Boolean;
    interiorRoom: String;
    yaw: Double;
    pitch: Double;
    x: Double;
    y: Double;
    z: Double;
  end;

  TNavigationActions = class external name 'Object'(TJSObject)
    procedure syncCamera;
    procedure syncSelection;
    procedure cancelPointer;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TNavigationUI = class
  private
    FState: TNavigationState;
    FActions: TNavigationActions;
    FKeys: TJSObject;
    FPointers: TJSObject;
    FLastTime: Double;
    FLastInput: String;
    FLastCamera: String;
    FToolsHidden: Boolean;
    function Click(AEvent: TJSEvent): Boolean;
    function Key(AEvent: TJSEvent): Boolean;
    function MoveButton(AEvent: TJSEvent): Boolean;
    function Clear(AEvent: TJSEvent): Boolean;
    function IsHeld(const AKey: String): Boolean;
    function Blocked: Boolean;
    procedure Frame(const ATime: Double);
    procedure SetEditing(const AEditing: Boolean);
  public
    constructor Create;
    procedure Refresh;
    procedure RestoreTools(const AHidden: Boolean);
    function ActivePointerCount: Integer;
    function CanGenerate(const AOperation: String): Boolean;
  end;

var
  GNavigation: TNavigationUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

constructor TNavigationUI.Create;
var
  LButtons: TJSNodeList;
  LButton: TJSHTMLElement;
  LBridge: TJSObject;
  I: Integer;
begin
  inherited Create;
  FState := TNavigationState(TJSObject(window)['phanesEditor']);
  FActions := TNavigationActions(TJSObject(window)['phanesEditorActions']);
  FKeys := TJSObject.new;
  FPointers := TJSObject.new;
  FLastTime := window.performance.now;
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  LBridge['restoreTools'] := @RestoreTools;
  LBridge['canGenerate'] := @CanGenerate;
  LBridge['activePointerCount'] := @ActivePointerCount;
  TJSObject(window)['phanesNavigationUI'] := LBridge;
  Element('tools-toggle').addEventListener('click', @Click);
  Element('mobile-save-world').addEventListener('click', @Click);
  Element('edit-toggle').addEventListener('click', @Click);
  document.addEventListener('keydown', @Key);
  document.addEventListener('keyup', @Key);
  document.addEventListener('visibilitychange', @Clear);
  document.addEventListener('freeze', @Clear);
  window.addEventListener('blur', @Clear);
  LButtons := document.querySelectorAll('[data-move]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLElement(LButtons[I]);
    LButton.addEventListener('pointerdown', @MoveButton);
    LButton.addEventListener('pointerup', @MoveButton);
    LButton.addEventListener('pointercancel', @MoveButton);
    LButton.addEventListener('lostpointercapture', @MoveButton);
    LButton.addEventListener('contextmenu', @MoveButton);
    LButton.addEventListener('blur', @Clear);
    LButton.setAttribute('aria-description', 'Hold Space or Enter, or use ' +
      UpperCase(LButton.getAttribute('data-move')) + ' to move.');
  end;
  Refresh;
  window.requestAnimationFrame(procedure(ATime: Double)
begin
  Frame(ATime);
end);
end;

function TNavigationUI.Blocked: Boolean;
begin
  Result := document.hidden or Boolean(TJSObject(window)['phanesRecovering']) or
    (FState.worker <> nil) or
    Boolean(TJSObject(window)['phanesAuthoringBusy']) or
    Element('audio-panel').classList.contains('audio-visible') or
    not Element('style-panel').hidden or
    Assigned(document.querySelector('dialog[open]'));
end;

function TNavigationUI.Clear(AEvent: TJSEvent): Boolean;
begin
  FKeys := TJSObject.new;
  FPointers := TJSObject.new;
  Result := True;
end;

function TNavigationUI.Key(AEvent: TJSEvent): Boolean;
var
  LKey: String;
  LTarget: TJSElement;
begin
  Result := True;
  LKey := LowerCase(TJSKeyboardEvent(AEvent).key);
  if (AEvent._type = 'keydown') and (LKey = 'escape') and not Blocked then
  begin
    Clear(nil);
    FActions.cancelPointer;
    Element('tools-toggle').focus;
    Exit;
  end;
  if AEvent._type = 'keyup' then
  begin
    FKeys[LKey] := False;
    JSDelete(FPointers, 'key:' + LKey);
    Exit;
  end;
  LTarget := TJSElement(AEvent.target);
  if Blocked or (LTarget.closest('input,textarea,select,[contenteditable="true"]') <> nil) then
  begin
    Exit;
  end;
  LTarget := LTarget.closest('[data-move]');
  if (LTarget <> nil) and ((LKey = ' ') or (LKey = 'enter')) then
  begin
    AEvent.preventDefault;
    FPointers['key:' + LKey] := LTarget.getAttribute('data-move');
    Exit;
  end;
  FKeys[LKey] := True;
end;

function TNavigationUI.MoveButton(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LButton: TJSHTMLElement;
  LId: String;
begin
  Result := True;
  AEvent.preventDefault;
  if AEvent._type = 'contextmenu' then
  begin
    Exit;
  end;
  LPointer := TJSPointerEvent(AEvent);
  LButton := TJSHTMLElement(AEvent.currentTarget);
  LId := IntToStr(LPointer.pointerId);
  if (AEvent._type = 'pointerdown') and not Blocked then
  begin
    LButton.setPointerCapture(LPointer.pointerId);
    FPointers[LId] := LButton.getAttribute('data-move');
  end else
  begin
    JSDelete(FPointers, LId);
  end;
end;

function TNavigationUI.IsHeld(const AKey: String): Boolean;
var
  LIds: TStringDynArray;
  I: Integer;
begin
  Result := FKeys[AKey] = True;
  LIds := TJSObject.keys(FPointers);
  for I := 0 to High(LIds) do
  begin
    Result := Result or (FPointers[LIds[I]] = AKey);
  end;
end;

function TNavigationUI.ActivePointerCount: Integer;
begin
  Result := Length(TJSObject.keys(FPointers));
end;

procedure TNavigationUI.Frame(const ATime: Double);
var
  LSeconds: Double;
  LForward: Double;
  LStrafe: Double;
  LRise: Double;
  LSpeed: Double;
  LLength: Double;
  LInput: TJSObject;
  LWire: String;
begin
  LSeconds := Min(0.05, Max(0, (ATime - FLastTime) / 1000));
  FLastTime := ATime;
  if Blocked then
  begin
    Clear(nil);
  end;
  LForward := Ord(IsHeld('w')) - Ord(IsHeld('s'));
  LStrafe := Ord(IsHeld('d')) - Ord(IsHeld('a'));
  LRise := Ord(IsHeld('e')) - Ord(IsHeld('q'));
  LInput := TJSObject.new;
  LInput['forward'] := LForward;
  LInput['strafe'] := LStrafe;
  LInput['run'] := IsHeld('shift');
  LInput['yaw'] := FState.yaw;
  LInput['pitch'] := FState.pitch;
  LWire := TJSJSON.stringify(LInput);
  if LWire <> FLastInput then
  begin
    FLastInput := LWire;
    TJSObject(window)['phanesMoveInput'] := LWire;
  end;
  if (FState.camera = 'fly') and ((LForward <> 0) or (LStrafe <> 0) or (LRise <> 0)) then
  begin
    LSpeed := 10 * LSeconds;
    if IsHeld('shift') then
    begin
      LSpeed := LSpeed * 3;
    end;
    LLength := Max(1, Sqrt(Sqr(LForward) + Sqr(LStrafe) + Sqr(LRise)));
    LSpeed := LSpeed / LLength;
    FState.x := FState.x + (Sin(FState.yaw) * LForward + Cos(FState.yaw) * LStrafe) * LSpeed;
    FState.z := FState.z + (-Cos(FState.yaw) * LForward + Sin(FState.yaw) * LStrafe) * LSpeed;
    FState.y := Max(1, FState.y + LRise * LSpeed);
    FActions.syncCamera;
  end;
  window.requestAnimationFrame(procedure(ATime: Double)
begin
  Frame(ATime);
end);
end;

procedure TNavigationUI.SetEditing(const AEditing: Boolean);
begin
  if Boolean(TJSObject(window)['phanesRecovering']) then
  begin
    Exit;
  end;
  Clear(nil);
  FActions.cancelPointer;
  FState.editing := AEditing;
  FToolsHidden := not AEditing;
  FActions.syncSelection;
  Refresh;
  FActions.syncCamera;
end;

function TNavigationUI.Click(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if TJSElement(AEvent.currentTarget).id = 'mobile-save-world' then
  begin
    if (FState.world <> nil) and not Boolean(TJSObject(window)['phanesRecovering']) then
    begin
      Element('save-world').click;
    end;
    Exit;
  end;
  if TJSElement(AEvent.currentTarget).id = 'edit-toggle' then
  begin
    SetEditing(not FState.editing);
  end else
  begin
    FToolsHidden := not FToolsHidden;
    Refresh;
    FActions.syncCamera;
  end;
end;

procedure TNavigationUI.RestoreTools(const AHidden: Boolean);
begin
  FToolsHidden := AHidden;
  Clear(nil);
  Refresh;
end;

procedure TNavigationUI.Refresh;
var
  LFly: Boolean;
  LWalk: Boolean;
  LEditing: String;
  LCanEdit: Boolean;
begin
  LFly := FState.camera = 'fly';
  LWalk := FState.camera = 'walk';
  if FLastCamera <> FState.camera then
  begin
    FLastCamera := FState.camera;
    Clear(nil);
  end;
  LCanEdit := FState.editing and (FState.world <> nil) and (FState.worker = nil);
  TJSHTMLButtonElement(Element('mobile-save-world')).disabled := (FState.world = nil) or
    (FState.worker <> nil) or Boolean(TJSObject(window)['phanesRecovering']);
  TJSHTMLButtonElement(Element('reimagine')).disabled := not LCanEdit;
  TJSHTMLButtonElement(Element('clear-region')).disabled := not LCanEdit;
  Element('walk-controls').hidden := not (LFly or LWalk);
  Element('fly-controls').hidden := not LFly;
  TJSHTMLElement(document.querySelector('.zoom-controls')).hidden := LFly or LWalk;
  if FState.editing then
  begin
    document.body.classList.remove('exploring');
  end else
  begin
    document.body.classList.add('exploring');
  end;
  if FToolsHidden then
  begin
    document.body.classList.add('tools-collapsed');
  end else
  begin
    document.body.classList.remove('tools-collapsed');
  end;
  document.body.setAttribute('data-camera', FState.camera);
  Element('tools-toggle').hidden := FState.world = nil;
  Element('tools-toggle').setAttribute('aria-expanded', LowerCase(BoolToStr(not FToolsHidden, True)));
  if FToolsHidden then
  begin
    Element('tools-toggle').textContent := 'Tools';
  end else
  begin
    Element('tools-toggle').textContent := 'Hide tools';
  end;
  LEditing := 'Explore';
  if not FState.editing then
  begin
    LEditing := 'Create';
    Element('edit-toggle').setAttribute('data-glyph', 'emergence');
  end else
  begin
    Element('edit-toggle').setAttribute('data-glyph', 'explore');
  end;
  Element('edit-toggle').textContent := LEditing;
  Element('edit-toggle').setAttribute('aria-pressed', LowerCase(BoolToStr(not FState.editing, True)));
  if LFly then
  begin
    Element('interaction-hint').textContent := 'Movement pad to fly · drag to look · Rise / Descend';
  end else if LWalk then
  begin
    Element('interaction-hint').textContent := 'Movement pad to walk · drag to look';
  end;
end;

function TNavigationUI.CanGenerate(const AOperation: String): Boolean;
begin
  if Boolean(TJSObject(window)['phanesRecovering']) then
  begin
    Exit(False);
  end;
  Result := FState.editing or (AOperation = 'module-toggle') or
    (AOperation = 'create') or (AOperation = 'restore') or
    ((AOperation = 'create-interior') and Boolean(TJSObject(window)['phanesEnteringInterior']));
  if not Result then
  begin
    FActions.notify('Switch to Create to apply changes. You can browse while exploring.', False);
  end;
end;

procedure StartNavigationUI;
begin
  GNavigation := TNavigationUI.Create;
end;

end.
