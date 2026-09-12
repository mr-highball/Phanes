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

unit phanes.ui.activation;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartAuthoringActivation;

implementation

uses
  JS, Web;

type
  TMutationCallback = procedure(const ARecords: TJSArray; const AObserver: TJSObject) of object;

  TButtonMutationObserver = class external name 'MutationObserver'(TJSObject)
    constructor new(const ACallback: TMutationCallback);
    procedure observe(const ATarget, AOptions: TJSObject);
    function takeRecords: TJSArray;
  end;

  TButtonBinding = record
    FButton: TJSHTMLButtonElement;
  end;

  TConsumedPointer = record
    FId: Integer;
    FStart: Double;
    FUntilPointer: Double;
    FUntilTouch: Double;
    FTouch: Boolean;
  end;

  TAuthoringActivation = class
  private
    FButtons: array of TButtonBinding;
    FConsumedPointers: array[0..15] of TConsumedPointer;
    FNextPointer: Integer;
    FActive: Integer;
    FPointer: Integer;
    FStartX: Double;
    FStartY: Double;
    FCancelled: Boolean;
    FWorld: JSValue;
    FWorker: JSValue;
    FJob: JSValue;
    FScene: JSValue;
    FCamera: JSValue;
    FEditing: JSValue;
    FObserver: TButtonMutationObserver;
    procedure Mutated(const ARecords: TJSArray; const AObserver: TJSObject);
    function FindButton(const AElement: TJSElement): Integer;
    function PointerEvent(AEvent: TJSEvent): Boolean;
    function ClickEvent(AEvent: TJSEvent): Boolean;
    function Cancel(AEvent: TJSEvent): Boolean;
  public
    constructor Create;
  end;

var
  GActivation: TAuthoringActivation;

constructor TAuthoringActivation.Create;
var
  LButtons: TJSNodeList;
  LOptions: TJSObject;
  I: Integer;
begin
  FActive := -1;
  FPointer := -1;
  FNextPointer := 0;
  for I := 0 to High(FConsumedPointers) do
  begin
    FConsumedPointers[I].FId := -1;
  end;
  LButtons := document.querySelectorAll(
    '#tools-toggle, [data-authoring-tool], [data-landform]');
  SetLength(FButtons, LButtons.length);
  for I := 0 to High(FButtons) do
  begin
    FButtons[I].FButton := TJSHTMLButtonElement(LButtons[I]);
  end;
  window.addEventListener('pointerdown', @PointerEvent, True);
  window.addEventListener('click', @ClickEvent, True);
  window.addEventListener('mousedown', @ClickEvent, True);
  window.addEventListener('mouseup', @ClickEvent, True);
  window.addEventListener('pointermove', @PointerEvent, True);
  window.addEventListener('pointerup', @PointerEvent, True);
  window.addEventListener('pointercancel', @PointerEvent, True);
  window.addEventListener('lostpointercapture', @PointerEvent, True);
  window.addEventListener('blur', @Cancel);
  window.addEventListener('contextmenu', @Cancel, True);
  window.addEventListener('scroll', @Cancel, True);
  document.addEventListener('visibilitychange', @Cancel);
  FObserver := TButtonMutationObserver.new(@Mutated);
  LOptions := TJSObject.new;
  LOptions['attributes'] := True;
  LOptions['subtree'] := True;
  LOptions['attributeFilter'] := TJSArray.new('disabled', 'hidden');
  FObserver.observe(document.body, LOptions);
end;

procedure TAuthoringActivation.Mutated(const ARecords: TJSArray; const AObserver: TJSObject);
var
  LTarget: TJSElement;
  I: Integer;
begin
  if FActive < 0 then
  begin
    Exit;
  end;
  for I := 0 to ARecords.length - 1 do
  begin
    LTarget := TJSElement(TJSObject(ARecords[I])['target']);
    if LTarget.contains(FButtons[FActive].FButton) then
    begin
      FCancelled := True;
    end;
  end;
end;

function TAuthoringActivation.FindButton(const AElement: TJSElement): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FButtons) do
  begin
    if FButtons[I].FButton.contains(AElement) then
    begin
      Exit(I);
    end;
  end;
  Result := -1;
end;

function TAuthoringActivation.Cancel(AEvent: TJSEvent): Boolean;
begin
  FActive := -1;
  FPointer := -1;
  Result := True;
end;

function TAuthoringActivation.PointerEvent(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LIndex: Integer;
  LBounds: TJSDOMRect;
  LButton: TJSHTMLButtonElement;
  LHit: TJSElement;
  LState: TJSObject;
  LTime: Double;
  I: Integer;
begin
  Result := True;
  LPointer := TJSPointerEvent(AEvent);
  LTime := Double(TJSObject(AEvent)['timeStamp']);
  if AEvent._type = 'pointerdown' then
  begin
    LIndex := FindButton(TJSElement(AEvent.target));
    { Pen IDs can persist and touch IDs can be reused. Close the earlier
      ownership interval even when the next gesture targets an unbound control.
      Native compatibility events retain the originating event timestamp. }
    for I := 0 to High(FConsumedPointers) do
    begin
      if (FConsumedPointers[I].FId = LPointer.pointerId) and
        (LTime < FConsumedPointers[I].FUntilPointer) then
      begin
        FConsumedPointers[I].FUntilPointer := LTime;
      end;
      if LPointer.isPrimary and (LPointer.pointerType = 'touch') and
        (LTime < FConsumedPointers[I].FUntilTouch) then
      begin
        FConsumedPointers[I].FUntilTouch := LTime;
      end;
    end;
    { A second finger cancels a pending activation rather than choosing either
      finger as the winner. Mouse input keeps its normal click behavior. }
    if FActive >= 0 then
    begin
      FCancelled := True;
      Exit;
    end;
    if not LPointer.isPrimary or
      ((LPointer.pointerType <> 'touch') and (LPointer.pointerType <> 'pen')) or
      (LPointer.button <> 0) then
    begin
      Exit;
    end;
    if LIndex < 0 then
    begin
      Exit;
    end;
    FActive := LIndex;
    FPointer := LPointer.pointerId;
    FStartX := LPointer.clientX;
    FStartY := LPointer.clientY;
    FCancelled := FButtons[LIndex].FButton.disabled;
    { Retain recent consumed identities even across a later touch or mouse
      gesture, so a delayed compatibility click cannot replay an old action. }
    FConsumedPointers[FNextPointer].FId := LPointer.pointerId;
    FConsumedPointers[FNextPointer].FStart := LTime;
    FConsumedPointers[FNextPointer].FUntilPointer := 1.0e300;
    FConsumedPointers[FNextPointer].FUntilTouch := 1.0e300;
    FConsumedPointers[FNextPointer].FTouch := LPointer.pointerType = 'touch';
    FNextPointer := (FNextPointer + 1) mod 16;
    FObserver.takeRecords;
    LState := TJSObject(TJSObject(window)['phanesEditor']);
    FWorld := LState['world'];
    FWorker := LState['worker'];
    FJob := LState['job'];
    FEditing := LState['editing'];
    FScene := TJSObject(window)['phanesSceneVersion'];
    FCamera := TJSObject(window)['phanesCameraVersion'];
    Exit;
  end;
  if (FActive < 0) or (LPointer.pointerId <> FPointer) then
  begin
    Exit;
  end;
  if (AEvent._type = 'pointercancel') or (AEvent._type = 'lostpointercapture') then
  begin
    Cancel(AEvent);
    Exit;
  end;
  if Sqr(LPointer.clientX - FStartX) + Sqr(LPointer.clientY - FStartY) > 144 then
  begin
    FCancelled := True;
  end;
  if AEvent._type <> 'pointerup' then
  begin
    Exit;
  end;
  Mutated(FObserver.takeRecords, nil);
  LState := TJSObject(TJSObject(window)['phanesEditor']);
  FCancelled := FCancelled or (FWorld <> LState['world']) or
    (FWorker <> LState['worker']) or (FJob <> LState['job']) or
    (FEditing <> LState['editing']) or
    (FScene <> TJSObject(window)['phanesSceneVersion']) or
    (FCamera <> TJSObject(window)['phanesCameraVersion']);
  LIndex := FActive;
  FActive := -1;
  FPointer := -1;
  LButton := FButtons[LIndex].FButton;
  if FCancelled or LButton.disabled or not document.documentElement.contains(LButton) then
  begin
    Exit;
  end;
  LBounds := LButton.getBoundingClientRect;
  LHit := document.elementFromPoint(Round(LPointer.clientX), Round(LPointer.clientY));
  if (LBounds.width <= 0) or (LBounds.height <= 0) or
    (LPointer.clientX < LBounds.left) or (LPointer.clientX > LBounds.right) or
    (LPointer.clientY < LBounds.top) or (LPointer.clientY > LBounds.bottom) or
    (LHit = nil) or not LButton.contains(LHit) then
  begin
    Exit;
  end;
  { The pointer pair is the activation. Keep existing button actions and
    keyboard semantics, and record ownership before a callback can change UI. }
  LButton.click;
end;

function TAuthoringActivation.ClickEvent(AEvent: TJSEvent): Boolean;
var
  LType: JSValue;
  LCapabilities: JSValue;
  LDuplicate: Boolean;
  I: Integer;
  LTime: Double;
begin
  Result := True;
  if not AEvent.isTrusted or (TJSMouseEvent(AEvent).detail = 0) then
  begin
    Exit;
  end;
  LType := TJSObject(AEvent)['pointerType'];
  LTime := Double(TJSObject(AEvent)['timeStamp']);
  LDuplicate := False;
  if (LType = 'touch') or (LType = 'pen') then
  begin
    for I := 0 to High(FConsumedPointers) do
    begin
      LDuplicate := LDuplicate or
        ((TJSObject(AEvent)['pointerId'] = FConsumedPointers[I].FId) and
        (LTime >= FConsumedPointers[I].FStart) and
        (LTime < FConsumedPointers[I].FUntilPointer));
    end;
  end;
  { Older compatibility MouseEvents expose touch provenance but no pointer
    identity. Never suppress a real mouse or a keyboard activation. }
  LCapabilities := TJSObject(AEvent)['sourceCapabilities'];
  if not isDefined(LType) and isObject(LCapabilities) and not isNull(LCapabilities) then
  begin
    if TJSObject(LCapabilities)['firesTouchEvents'] = True then
    begin
      for I := 0 to High(FConsumedPointers) do
      begin
        LDuplicate := LDuplicate or (FConsumedPointers[I].FTouch and
          (LTime >= FConsumedPointers[I].FStart) and
          (LTime < FConsumedPointers[I].FUntilTouch));
      end;
    end;
  end;
  if LDuplicate then
  begin
    AEvent.preventDefault;
    AEvent.stopImmediatePropagation;
  end;
end;

procedure StartAuthoringActivation;
begin
  GActivation := TAuthoringActivation.Create;
end;

end.
