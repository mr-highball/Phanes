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


unit phanes.authoring.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartAuthoringUI;

implementation

uses
  JS, Web, SysUtils, Math, Types, phanes.selection.grid, phanes.landforms.types;

type
  TEditorState = class external name 'Object'(TJSObject)
    world: TJSObject;
    worker: TJSObject;
    selection: TJSObject;
    camera: String;
    editing: Boolean;
    interiorRoom: String;
    zoom: Double;
    yaw: Double;
    pitch: Double;
    panX: Double;
    panZ: Double;
  end;

  TEditorActions = class external name 'Object'(TJSObject)
    procedure syncSelection;
    procedure syncCamera;
    procedure pick(const AEvent: TJSObject; const AAction: String);
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TAuthoringUI = class
  private
    FState: TEditorState;
    FActions: TEditorActions;
    FCanvas: TJSHTMLElement;
    FPointer: Integer;
    FInterruptedPointer: Integer;
    FTool: String;
    FStrokeTool: String;
    FCombine: String;
    FScale: Integer;
    FRadius: Double;
    FStartX: Double;
    FStartY: Double;
    FLastX: Double;
    FLastY: Double;
    FNavigate: Boolean;
    FMoved: Boolean;
    FPoints: TSelectionPoints;
    FWorldPoints: TSelectionPoints;
    FPointIndex: Integer;
    FPickVersion: Integer;
    FSceneVersion: Integer;
    FCameraVersion: Integer;
    FPending: Boolean;
    FDeadline: Double;
    FSceneSeen: Integer;
    FWorldSize: Integer;
    function PointerEvent(AEvent: TJSEvent): Boolean;
    function PointerStarted(AEvent: TJSEvent): Boolean;
    function Changed(AEvent: TJSEvent): Boolean;
    function Wheel(AEvent: TJSEvent): Boolean;
    function Interrupted(AEvent: TJSEvent): Boolean;
    procedure Sample(const AX, AY: Double; const AFinal: Boolean);
    procedure StrokePreview;
    procedure NextPoint;
    procedure Finish;
    procedure SetCells(const ABits: TSelectionBits; const AScale: Integer);
  public
    constructor Create;
    procedure Cancel;
    procedure Refresh;
    function CompletePointPick(const AVersion: Integer): Boolean;
    procedure Picked(const AX, AZ: Double; const AVersion: Integer; const AHit: Boolean);
    function Request(const AOperation: String; const ASelection, AOptions: TJSObject): TJSObject;
  end;

var
  GAuthoring: TAuthoringUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

constructor TAuthoringUI.Create;
var
  LBridge: TJSObject;
  LButtons: TJSNodeList;
  I: Integer;
begin
  inherited Create;
  FState := TEditorState(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  FCanvas := Element('castle-canvas');
  FPointer := -1;
  FInterruptedPointer := -1;
  FTool := 'point';
  LBridge := TJSObject.new;
  LBridge['cancel'] := @Cancel;
  LBridge['completePointPick'] := @CompletePointPick;
  LBridge['refresh'] := @Refresh;
  LBridge['request'] := @Request;
  TJSObject(window)['phanesAuthoringUI'] := LBridge;
  TJSObject(window)['phanesAuthoringPicked'] := @Picked;
  TJSObject(window)['phanesAuthoringBusy'] := False;
  window.addEventListener('pointerdown', @PointerStarted, True);
  FCanvas.addEventListener('pointerdown', @PointerEvent);
  FCanvas.addEventListener('pointermove', @PointerEvent);
  FCanvas.addEventListener('pointerup', @PointerEvent);
  FCanvas.addEventListener('pointercancel', @PointerEvent);
  FCanvas.addEventListener('lostpointercapture', @PointerEvent);
  FCanvas.addEventListener('wheel', @Wheel, False);
  document.addEventListener('visibilitychange', @Interrupted);
  window.addEventListener('blur', @Interrupted);
  document.addEventListener('keydown', @Interrupted);
  LButtons := document.querySelectorAll('[data-authoring-tool]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButtons[I].addEventListener('click', @Changed);
  end;
  Element('selection-scale').addEventListener('change', @Changed);
  Element('selection-layer').addEventListener('change', @Changed);
  Element('select-all').addEventListener('click', @Changed);
  Element('selection-clear').addEventListener('click', @Changed);
  window.setInterval(procedure
    begin
      if FPending and ((window.performance.now > FDeadline) or
        (Integer(TJSObject(window)['phanesSceneVersion']) <> FSceneVersion) or
        (Integer(TJSObject(window)['phanesCameraVersion']) <> FCameraVersion)) then
      begin
        Cancel;
        FActions.notify('The view changed before selection finished. Select again.', False);
      end;
    end, 200);
  Refresh;
end;

procedure TAuthoringUI.Cancel;
begin
  FPointer := -1;
  FPending := False;
  FPoints := nil;
  FWorldPoints := nil;
  TJSObject(window)['phanesAuthoringBusy'] := False;
  TJSObject(window)['phanesPickAction'] := '';
  TJSObject(window)['phanesPickVersion'] := Integer(TJSObject(window)['phanesPickVersion']) + 1;
  Element('selection-stroke').setAttribute('points', '');
end;

function TAuthoringUI.Interrupted(AEvent: TJSEvent): Boolean;
begin
  if (AEvent._type <> 'keydown') or (TJSKeyboardEvent(AEvent).key = 'Escape') then
  begin
    Cancel;
  end;
  Result := True;
end;

procedure TAuthoringUI.Sample(const AX, AY: Double; const AFinal: Boolean);
var
  LBounds: TJSDOMRect;
  LCount: Integer;
  LPoint: TSelectionPoint;
begin
  LBounds := FCanvas.getBoundingClientRect;
  LPoint.FX := EnsureRange((AX - LBounds.left) / LBounds.width, 0, 1);
  LPoint.FZ := EnsureRange((AY - LBounds.top) / LBounds.height, 0, 1);
  LCount := Length(FPoints);
  if (LCount > 0) and not AFinal and
    (Sqr((LPoint.FX - FPoints[LCount - 1].FX) * LBounds.width) +
     Sqr((LPoint.FZ - FPoints[LCount - 1].FZ) * LBounds.height) < 144) then
  begin
    Exit;
  end;
  if (FStrokeTool = 'box') or (FStrokeTool = 'point') then
  begin
    LCount := Min(1, LCount);
  end;
  if LCount >= 256 then
  begin
    Cancel;
    FActions.notify('This stroke is too long. Use shorter strokes with Add to selection.', False);
    Exit;
  end;
  SetLength(FPoints, LCount + 1);
  FPoints[LCount] := LPoint;
  StrokePreview;
end;

procedure TAuthoringUI.StrokePreview;
var
  LText: String;
  I: Integer;
  LA: TSelectionPoint;
  LB: TSelectionPoint;

  procedure Add(const AX, AZ: Double);
  begin
    LText := LText + FloatToStr(AX * 1000) + ',' + FloatToStr(AZ * 1000) + ' ';
  end;

begin
  LText := '';
  if Length(FPoints) = 0 then
  begin
    Exit;
  end;
  LA := FPoints[0];
  LB := FPoints[High(FPoints)];
  if FStrokeTool = 'box' then
  begin
    Add(LA.FX, LA.FZ);
    Add(LB.FX, LA.FZ);
    Add(LB.FX, LB.FZ);
    Add(LA.FX, LB.FZ);
    Add(LA.FX, LA.FZ);
  end else
  begin
    for I := 0 to High(FPoints) do
    begin
      Add(FPoints[I].FX, FPoints[I].FZ);
    end;
    if FStrokeTool = 'lasso' then
    begin
      Add(LA.FX, LA.FZ);
    end;
  end;
  Element('selection-stroke').setAttribute('points', LText);
end;

function TAuthoringUI.PointerStarted(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
begin
  Result := True;
  LPointer := TJSPointerEvent(AEvent);
  FInterruptedPointer := -1;
  { A second contact anywhere interrupts painting, including a contact on the
    tools panel while the first is captured by the canvas. A primary pointer
    from another device must not restart the cancelled stroke on this event. }
  if ((FPointer >= 0) and (LPointer.pointerId <> FPointer)) or
    (FPending and not LPointer.isPrimary) then
  begin
    FInterruptedPointer := LPointer.pointerId;
    Cancel;
  end;
end;

function TAuthoringUI.PointerEvent(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LDX: Double;
  LDY: Double;
  LWasNavigate: Boolean;
  LA: TSelectionPoint;
  LB: TSelectionPoint;
begin
  Result := True;
  LPointer := TJSPointerEvent(AEvent);
  if (AEvent._type = 'pointercancel') or (AEvent._type = 'lostpointercapture') then
  begin
    if LPointer.pointerId = FPointer then
    begin
      Cancel;
    end;
    Exit;
  end;
  if AEvent._type = 'pointerdown' then
  begin
    { A touch that starts on Tools cannot grant a second finger ownership of
      a world selection. Only a fresh primary gesture may begin a stroke. }
    if not LPointer.isPrimary or (LPointer.pointerId = FInterruptedPointer) then
    begin
      Exit;
    end;
    if (FState.world = nil) or FPending or (FState.worker <> nil) then
    begin
      Exit;
    end;
    if FPointer >= 0 then
    begin
      Cancel;
      Exit;
    end;
    FPointer := LPointer.pointerId;
    FStartX := LPointer.clientX;
    FStartY := LPointer.clientY;
    FLastX := FStartX;
    FLastY := FStartY;
    FMoved := False;
    FStrokeTool := FTool;
    FNavigate := not FState.editing or (FTool = 'navigate') or (FTool = 'point') or
      (FState.interiorRoom <> '') or Boolean(TJSObject(window)['phanesGroundworkActive']) or
      Boolean(TJSObject(window)['phanesModularPicking']) or
      (LPointer.button = 2) or LPointer.altKey;
    if (LPointer.button = 2) or LPointer.altKey then
    begin
      FStrokeTool := 'navigate';
    end;
    FScale := StrToInt(TJSHTMLSelectElement(Element('selection-scale')).value);
    FRadius := StrToFloat(TJSHTMLSelectElement(Element('selection-radius')).value) / 2;
    FCombine := TJSHTMLSelectElement(Element('selection-combine')).value;
    if LPointer.shiftKey then
    begin
      FCombine := 'add';
    end;
    FSceneVersion := Integer(TJSObject(window)['phanesSceneVersion']);
    FCameraVersion := Integer(TJSObject(window)['phanesCameraVersion']);
    FPoints := nil;
    FCanvas.setPointerCapture(FPointer);
    FCanvas.focus;
    if not FNavigate then
    begin
      TJSObject(window)['phanesAuthoringBusy'] := True;
      Sample(FStartX, FStartY, True);
    end;
    AEvent.preventDefault;
    Exit;
  end;
  if LPointer.pointerId <> FPointer then
  begin
    Exit;
  end;
  if (AEvent._type = 'pointermove') and (LPointer.pointerType = 'mouse') and
    (LPointer.buttons = 0) then
  begin
    Cancel;
    Exit;
  end;
  LDX := LPointer.clientX - FLastX;
  LDY := LPointer.clientY - FLastY;
  FMoved := FMoved or (Sqr(LPointer.clientX - FStartX) + Sqr(LPointer.clientY - FStartY) >= 25);
  if AEvent._type = 'pointermove' then
  begin
    if FNavigate and FMoved then
    begin
      if FState.camera = 'top' then
      begin
        FState.panX := FState.panX - LDX * 0.12 / FState.zoom;
        FState.panZ := FState.panZ - LDY * 0.12 / FState.zoom;
      end else
      begin
        FState.yaw := FState.yaw + LDX * 0.008;
        FState.pitch := EnsureRange(FState.pitch - LDY * 0.006, -1.4, 1.4);
      end;
      FActions.syncCamera;
    end
    else if not FNavigate then
    begin
      Sample(LPointer.clientX, LPointer.clientY, False);
    end;
    FLastX := LPointer.clientX;
    FLastY := LPointer.clientY;
  end;
  if AEvent._type = 'pointerup' then
  begin
    LWasNavigate := FNavigate;
    FPointer := -1;
    if FState.editing and not FMoved and
      ((FState.interiorRoom <> '') or Boolean(TJSObject(window)['phanesGroundworkActive']) or
      Boolean(TJSObject(window)['phanesModularPicking'])) and
      (FStrokeTool <> 'navigate') then
    begin
      FActions.pick(TJSObject(AEvent), 'end');
      Exit;
    end;
    if not FState.editing or (FStrokeTool = 'navigate') or
      (LWasNavigate and FMoved) then
    begin
      Cancel;
      Exit;
    end;
    if LWasNavigate then
    begin
      FStrokeTool := 'point';
      FPoints := nil;
      FCameraVersion := Integer(TJSObject(window)['phanesCameraVersion']);
    end;
    Sample(LPointer.clientX, LPointer.clientY, True);
    if Length(FPoints) = 0 then
    begin
      Exit;
    end;
    if (FStrokeTool = 'box') and (Length(FPoints) = 2) then
    begin
      LA := FPoints[0];
      LB := FPoints[1];
      SetLength(FPoints, 4);
      FPoints[1].FX := LB.FX;
      FPoints[1].FZ := LA.FZ;
      FPoints[2] := LB;
      FPoints[3].FX := LA.FX;
      FPoints[3].FZ := LB.FZ;
    end;
    FPending := True;
    FDeadline := window.performance.now + 15000;
    TJSObject(window)['phanesAuthoringBusy'] := True;
    FPointIndex := 0;
    SetLength(FWorldPoints, Length(FPoints));
    NextPoint;
  end;
  AEvent.preventDefault;
end;

procedure TAuthoringUI.NextPoint;
begin
  if (Integer(TJSObject(window)['phanesSceneVersion']) <> FSceneVersion) or
    (Integer(TJSObject(window)['phanesCameraVersion']) <> FCameraVersion) then
  begin
    Cancel;
    Exit;
  end;
  FPickVersion := Integer(TJSObject(window)['phanesPickVersion']) + 1;
  TJSObject(window)['phanesPickX'] := FPoints[FPointIndex].FX;
  TJSObject(window)['phanesPickY'] := FPoints[FPointIndex].FZ;
  TJSObject(window)['phanesPickSceneVersion'] := FSceneVersion;
  TJSObject(window)['phanesPickCameraVersion'] := FCameraVersion;
  if FStrokeTool = 'point' then
  begin
    { A stationary point probes visible Groundworks first. Its terrain fallback
      returns here, preserving the captured fine scale and combine operation. }
    TJSObject(window)['phanesPickAction'] := 'authoring-point';
  end else
  begin
    TJSObject(window)['phanesPickAction'] := 'authoring';
  end;
  TJSObject(window)['phanesPickVersion'] := FPickVersion;
end;

function TAuthoringUI.CompletePointPick(const AVersion: Integer): Boolean;
begin
  Result := FPending and (FStrokeTool = 'point') and (AVersion = FPickVersion) and
    (String(TJSObject(window)['phanesPickAction']) = 'authoring-point') and
    (AVersion = Integer(TJSObject(window)['phanesPickVersion'])) and
    (FSceneVersion = Integer(TJSObject(window)['phanesSceneVersion'])) and
    (FCameraVersion = Integer(TJSObject(window)['phanesCameraVersion'])) and
    (FSceneVersion = Integer(TJSObject(window)['phanesPickSceneVersion'])) and
    (FCameraVersion = Integer(TJSObject(window)['phanesPickCameraVersion']));
  if not Result then
  begin
    Exit;
  end;
  FPending := False;
  FPoints := nil;
  FWorldPoints := nil;
  TJSObject(window)['phanesAuthoringBusy'] := False;
  TJSObject(window)['phanesPickAction'] := '';
  Element('selection-stroke').setAttribute('points', '');
end;

procedure TAuthoringUI.Picked(const AX, AZ: Double; const AVersion: Integer; const AHit: Boolean);
begin
  if not FPending or (AVersion <> FPickVersion) then
  begin
    Exit;
  end;
  if not AHit then
  begin
    Cancel;
    FActions.notify('Keep the whole selection on the land. Move the view to reach farther.', False);
    Exit;
  end;
  FWorldPoints[FPointIndex].FX := (AX / 16 + Integer(FState.world['size']) / 2) * FScale;
  FWorldPoints[FPointIndex].FZ := (AZ / 16 + Integer(FState.world['size']) / 2) * FScale;
  Inc(FPointIndex);
  if FPointIndex = Length(FPoints) then
  begin
    Finish;
  end else
  begin
    NextPoint;
  end;
end;

procedure TAuthoringUI.SetCells(const ABits: TSelectionBits; const AScale: Integer);
var
  LCells: TSelectionCells;
  LWire: TJSArray;
  LSize: Integer;
  LMinX: Integer;
  LMinZ: Integer;
  LMaxX: Integer;
  LMaxZ: Integer;
  I: Integer;
begin
  LSize := Integer(FState.world['size']) * AScale;
  LCells := SelectionCells(ABits);
  LWire := TJSArray.new;
  LMinX := LSize;
  LMinZ := LSize;
  LMaxX := -1;
  LMaxZ := -1;
  for I := 0 to High(LCells) do
  begin
    LWire.push(LCells[I]);
    LMinX := Min(LMinX, (LCells[I] mod LSize) div AScale);
    LMinZ := Min(LMinZ, (LCells[I] div LSize) div AScale);
    LMaxX := Max(LMaxX, (LCells[I] mod LSize) div AScale);
    LMaxZ := Max(LMaxZ, (LCells[I] div LSize) div AScale);
  end;
  FState.selection := TJSObject.new;
  FState.selection['x'] := Max(0, Min(LMinX, Integer(FState.world['size']) - 1));
  FState.selection['z'] := Max(0, Min(LMinZ, Integer(FState.world['size']) - 1));
  FState.selection['width'] := Max(1, LMaxX - LMinX + 1);
  FState.selection['depth'] := Max(1, LMaxZ - LMinZ + 1);
  FState.selection['selectionScale'] := AScale;
  FState.selection['selectionCells'] := LWire;
  FActions.syncSelection;
  Refresh;
end;

procedure TAuthoringUI.Finish;
var
  LBits: TSelectionBits;
  LOld: TJSArray;
  LOldScale: Integer;
  LSide: Integer;
  LX: Integer;
  LZ: Integer;
  LA: TSelectionPoint;
  LB: TSelectionPoint;
  I: Integer;
begin
  LSide := Integer(FState.world['size']) * FScale;
  SetLength(LBits, Sqr(LSide));
  LA := FWorldPoints[0];
  LB := FWorldPoints[High(FWorldPoints)];
  if FStrokeTool = 'point' then
  begin
    LX := EnsureRange(Floor(LB.FX), 0, LSide - 1);
    LZ := EnsureRange(Floor(LB.FZ), 0, LSide - 1);
    LBits[LZ * LSide + LX] := True;
  end
  else if (FStrokeTool = 'box') or (FStrokeTool = 'lasso') then
  begin
    LassoSelection(LBits, LSide, FWorldPoints, True);
  end else
  begin
    for I := 0 to High(FWorldPoints) do
    begin
      PaintSelection(LBits, LSide, FWorldPoints[Max(0, I - 1)], FWorldPoints[I], FRadius);
    end;
  end;
  LOld := nil;
  LOldScale := 1;
  if isArray(FState.selection['selectionCells']) then
  begin
    LOldScale := Integer(FState.selection['selectionScale']);
    LOld := TJSArray(FState.selection['selectionCells']);
  end
  else if FCombine <> 'replace' then
  begin
    LOld := TJSArray.new;
    for LZ := Integer(FState.selection['z']) to
      Integer(FState.selection['z']) + Integer(FState.selection['depth']) - 1 do
    begin
      for LX := Integer(FState.selection['x']) to
        Integer(FState.selection['x']) + Integer(FState.selection['width']) - 1 do
      begin
        LOld.push(LZ * Integer(FState.world['size']) + LX);
      end;
    end;
  end;
  if (FCombine <> 'replace') and (LOld <> nil) and (LOldScale = FScale) then
  begin
    if FCombine = 'subtract' then
    begin
      for I := 0 to High(LBits) do
      begin
        LBits[I] := not LBits[I] and (LOld.indexOf(I) >= 0);
      end;
    end else
    begin
      for I := 0 to LOld.Length - 1 do
      begin
        LBits[Integer(LOld[I])] := True;
      end;
    end;
  end;
  if (FCombine <> 'replace') and (LOld <> nil) and (LOldScale <> FScale) then
  begin
    Cancel;
    FActions.notify('The selection precision changed. Select again before combining areas.', False);
    Exit;
  end;
  Cancel;
  SetCells(LBits, FScale);
end;

function TAuthoringUI.Changed(AEvent: TJSEvent): Boolean;
var
  LTarget: TJSElement;
  LBits: TSelectionBits;
  LScale: Integer;
  I: Integer;
begin
  Result := True;
  if FState.worker <> nil then
  begin
    Exit;
  end;
  Cancel;
  LTarget := TJSElement(AEvent.currentTarget);
  if LTarget.hasAttribute('data-authoring-tool') then
  begin
    FTool := LTarget.getAttribute('data-authoring-tool');
  end;
  if FState.world <> nil then
  begin
    LScale := StrToInt(TJSHTMLSelectElement(Element('selection-scale')).value);
    if (LTarget.id = 'select-all') or (LTarget.id = 'selection-clear') or
      (LTarget.id = 'selection-scale') then
    begin
      SetLength(LBits, Sqr(Integer(FState.world['size']) * LScale));
      for I := 0 to High(LBits) do
      begin
        LBits[I] := LTarget.id = 'select-all';
      end;
      SetCells(LBits, LScale);
    end;
    if (LScale = 2) and (document.body.getAttribute('data-landforms') <> 'true') then
    begin
      TJSHTMLSelectElement(Element('selection-layer')).value := 'foliage';
    end;
  end;
  Refresh;
end;

function TAuthoringUI.Wheel(AEvent: TJSEvent): Boolean;
var
  LMaximum: Double;
begin
  Result := True;
  AEvent.preventDefault;
  if FPending or (FPointer >= 0) then
  begin
    Exit;
  end;
  LMaximum := 12;
  if isNumber(TJSObject(window)['phanesModularZoomLimit']) then
  begin
    LMaximum := Max(LMaximum, Double(TJSObject(window)['phanesModularZoomLimit']));
  end;
  if FState.interiorRoom <> '' then
  begin
    LMaximum := 64;
  end;
  FState.zoom := EnsureRange(FState.zoom * Exp(-TJSWheelEvent(AEvent).deltaY * 0.001), 0.4, LMaximum);
  FActions.syncCamera;
end;

procedure TAuthoringUI.Refresh;
var
  LButtons: TJSNodeList;
  LButton: TJSElement;
  LScale: Integer;
  LCount: Integer;
  LScene: Integer;
  LBits: TSelectionBits;
  I: Integer;
begin
  LScene := Integer(TJSObject(window)['phanesSceneVersion']);
  if FSceneSeen <> LScene then
  begin
    FSceneSeen := LScene;
    Cancel;
  end;
  Element('authoring-tools').hidden := not FState.editing or (FState.world = nil) or
    (FState.interiorRoom <> '') or Boolean(TJSObject(window)['phanesGroundworkActive']);
  LButtons := document.querySelectorAll('[data-authoring-tool]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSElement(LButtons[I]);
    TJSHTMLButtonElement(LButton).disabled := FState.worker <> nil;
    LButton.setAttribute('aria-pressed',
      LowerCase(BoolToStr(LButton.getAttribute('data-authoring-tool') = FTool, True)));
  end;
  LButtons := document.querySelectorAll('#selection-settings select, #selection-clear');
  for I := 0 to LButtons.length - 1 do
  begin
    if FState.worker <> nil then
    begin
      TJSElement(LButtons[I]).setAttribute('disabled', '');
    end else
    begin
      TJSElement(LButtons[I]).removeAttribute('disabled');
    end;
  end;
  if FState.world = nil then
  begin
    Exit;
  end;
  if FWorldSize <> Integer(FState.world['size']) then
  begin
    LScale := FWorldSize;
    FWorldSize := Integer(FState.world['size']);
    if LScale <> 0 then
    begin
      TJSHTMLSelectElement(Element('selection-scale')).value := '1';
      SetLength(LBits, Sqr(FWorldSize));
      SetCells(LBits, 1);
      Exit;
    end;
  end;
  LScale := 1;
  if isArray(FState.selection['selectionCells']) then
  begin
    LScale := Integer(FState.selection['selectionScale']);
    LCount := TJSArray(FState.selection['selectionCells']).Length;
  end else
  begin
    LCount := Integer(FState.selection['width']) * Integer(FState.selection['depth']);
  end;
  TJSHTMLSelectElement(Element('selection-scale')).value := IntToStr(LScale);
  Element('selection-size').textContent := IntToStr(LCount) + ' selected cells';
  Element('selection-description').textContent := IntToStr(16 div LScale) +
    ' m cells · browse a category, then Apply to selection';
  Element('selection-count').textContent := IntToStr(LCount) + ' selected';
  Element('selection-radius-label').hidden := FTool <> 'brush';
  if FState.editing and (FState.interiorRoom = '') and
    not Boolean(TJSObject(window)['phanesGroundworkActive']) then
  begin
    if FTool = 'point' then
    begin
      Element('interaction-hint').textContent := 'Tap land to select · drag to look · Tools to choose an item';
    end else if FTool = 'navigate' then
    begin
      Element('interaction-hint').textContent := 'Drag to look · select a tool to mark land';
    end else
    begin
      Element('interaction-hint').textContent := 'Draw on the land to select · no changes until Apply';
    end;
  end;
end;

function TAuthoringUI.Request(const AOperation: String; const ASelection, AOptions: TJSObject): TJSObject;
var
  LKeys: TStringDynArray;
  LRegional: Boolean;
  I: Integer;
begin
  Result := nil;
  if FPending or (FPointer >= 0) then
  begin
    FActions.notify('Finish selecting before applying a change.', False);
    Exit;
  end;
  Result := TJSObject.new;
  LKeys := TJSObject.keys(AOptions);
  for I := 0 to High(LKeys) do
  begin
    Result[LKeys[I]] := AOptions[LKeys[I]];
  end;
  Result['x'] := ASelection['x'];
  Result['z'] := ASelection['z'];
  Result['width'] := ASelection['width'];
  Result['depth'] := ASelection['depth'];
  LRegional := (AOperation = 'reimagine') or (AOperation = 'clear') or
    (AOperation = 'asset') or (AOperation = 'forest') or (AOperation = 'flowers') or
    (AOperation = 'field') or (AOperation = 'water') or (AOperation = 'meadow') or
    (AOperation = 'stone') or (AOperation = 'tree') or (AOperation = 'shrub') or
    (AOperation = 'wheat') or (AOperation = 'rock') or (AOperation = 'cabin') or
    (AOperation = 'castle') or (AOperation = 'modern') or (AOperation = 'scifi') or
    (AOperation = 'rocket');
  if not LRegional then
  begin
    if IsLandformOperation(AOperation) then
    begin
      Result['editLayer'] := 'terrain';
      if isArray(ASelection['selectionCells']) then
      begin
        if (ASelection['selectionScale'] = 8) or
          (TJSArray(ASelection['selectionCells']).Length = 0) then
        begin
          FActions.notify('Draw an area of land with 8 m or 16 m cells first.', False);
          Exit(nil);
        end;
        Result['selectionScale'] := ASelection['selectionScale'];
        Result['selectionCells'] := ASelection['selectionCells'];
      end;
    end;
    if (AOperation = 'module-build') or (AOperation = 'module-extend') or
      (AOperation = 'module-populate') then
    begin
      if (ASelection['selectionScale'] <> 8) or
        not isArray(ASelection['selectionCells']) or
        (TJSArray(ASelection['selectionCells']).Length = 0) then
      begin
        FActions.notify('Draw a floor area using 2 m building cells first.', False);
        Exit(nil);
      end;
      Result['editLayer'] := '';
      Result['selectionScale'] := 8;
      Result['selectionCells'] := ASelection['selectionCells'];
    end;
    Exit;
  end;
  if not isString(Result['editLayer']) then
  begin
    Result['editLayer'] := TJSHTMLSelectElement(Element('selection-layer')).value;
  end;
  if isArray(ASelection['selectionCells']) then
  begin
    if ASelection['selectionScale'] = 8 then
    begin
      FActions.notify('Use the building tools for this 2 m selection, or change selection precision.', False);
      Exit(nil);
    end;
    if TJSArray(ASelection['selectionCells']).Length = 0 then
    begin
      FActions.notify('Select some land first. Tap, brush or draw a lasso in any view.', False);
      Exit(nil);
    end;
    if (Integer(ASelection['selectionScale']) = 2) and (String(Result['editLayer']) <> 'foliage') then
    begin
      FActions.notify('This is a fine foliage selection. Choose 16 m cells to edit terrain or buildings.', False);
      Exit(nil);
    end;
    Result['selectionScale'] := ASelection['selectionScale'];
    Result['selectionCells'] := ASelection['selectionCells'];
  end;
end;

procedure StartAuthoringUI;
begin
  GAuthoring := TAuthoringUI.Create;
end;

end.
