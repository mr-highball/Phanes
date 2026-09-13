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

unit phanes.groundworks.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartGroundworkUI;

implementation

uses
  JS,
  Web,
  SysUtils,
  Math,
  phanes.world.types,
  phanes.world.wire,
  phanes.composition.types,
  phanes.composition.document,
  phanes.groundworks.geometry,
  phanes.structures.support,
  phanes.interiors.ui,
  phanes.groundworks.assembly;

type
  TEditorState = class external name 'Object'(TJSObject)
    world: TJSObject;
    worker: TJSObject;
    selection: TJSObject;
    interiorRoom: String;
    editing: Boolean;
    camera: String;
    panX: Double;
    panY: Double;
    panZ: Double;
    zoom: Double;
    yaw: Double;
    pitch: Double;
    x: Double;
    y: Double;
    z: Double;
  end;

  TEditorActions = class external name 'Object'(TJSObject)
    procedure generate(const AOperation: String; const AImported, AOptions: TJSObject);
    procedure setCamera(const AMode: String);
    procedure syncSelection;
    procedure cancelPointer;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TAuthoringBridge = class external name 'Object'(TJSObject)
    function completePointPick(const AVersion: Integer): Boolean;
  end;

  TGroundworkUI = class
  private
    FState: TEditorState;
    FActions: TEditorActions;
    FWorld: TWorld;
    FIndex: TCompositionIndex;
    FActive: Boolean;
    FPlot: String;
    FSelected: String;
    FBody: String;
    FTurn: Integer;
    FAssembly: TGroundworkAssembly;
    FPreview: TGroundworkGeometry;
    FCanPlace: Boolean;
    FPreviewKey: String;
    FPreviewReason: String;
    FGridKey: String;
    FSelectionKey: String;
    FFrameVersion: Integer;
    FFrameId: String;
    function Click(AEvent: TJSEvent): Boolean;
    function Protected(const AId: String): Boolean;
    procedure Preview;
    procedure RenderParts;
    procedure RenderBuildings;
    procedure Frame;
    procedure Request(const AOperation, AScope, ABody: String);
    procedure SendSelection(const AFrame: Boolean = False);
    procedure FramePart(const AId: String; const AX, AY, AZ, ASize: Double);
    procedure Picked(const AId: String; const AVersion: Integer);
  public
    constructor Create;
    procedure Refresh;
    procedure OnWorld;
    procedure NormalizeSelection;
    function Snapshot: TJSObject;
    procedure RestoreCheckpoint(const AValue: TJSObject);
  end;

const
  CMaterialNames: array[TGroundworkMaterial] of String =
    ('Stone', 'Concrete', 'Ceramic', 'Steel');
  CMaterialIds: array[TGroundworkMaterial] of String =
    ('stone', 'concrete', 'ceramic', 'steel');
  CActionIds: array[0..17] of String =
    ('open-groundworks', 'leave-groundworks', 'groundwork-foundation',
    'groundwork-launch-pad', 'groundwork-plinth', 'groundwork-piers',
    'groundwork-frame', 'groundwork-walk', 'groundwork-reimagine',
    'groundwork-deck', 'groundwork-ramp', 'groundwork-undo', 'groundwork-select',
    'groundwork-inside', 'groundwork-remove-building', 'groundwork-body',
    'groundwork-building', 'groundwork-landing');
  CDirections: array[0..3] of String = ('South', 'East', 'North', 'West');
  CExistingActions: array[0..3] of String =
    ('groundwork-frame', 'groundwork-walk', 'groundwork-deck', 'groundwork-ramp');

var
  GGroundworkUI: TGroundworkUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

procedure Enable(const AId: String; const AEnabled: Boolean);
begin
  TJSHTMLButtonElement(Element(AId)).disabled := not AEnabled;
end;

constructor TGroundworkUI.Create;
var
  LBridge: TJSObject;
  LButtons: TJSNodeList;
  LId: String;
  I: Integer;
begin
  FState := TEditorState(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  FIndex := TCompositionIndex.Create(nil);
  FBody := 'plinth';
  FTurn := -1;
  for LId in CActionIds do
  begin
    Element(LId).addEventListener('click', @Click);
  end;
  LButtons := Element('groundwork-directions').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButtons[I].addEventListener('click', @Click);
  end;
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  LBridge['onWorld'] := @OnWorld;
  LBridge['normalizeSelection'] := @NormalizeSelection;
  LBridge['sendSelection'] := @SendSelection;
  LBridge['snapshot'] := @Snapshot;
  LBridge['restoreCheckpoint'] := @RestoreCheckpoint;
  TJSObject(window)['phanesGroundworkUI'] := LBridge;
  TJSObject(window)['phanesGroundworkPicked'] := @Picked;
  TJSObject(window)['phanesGroundworkFrame'] := @FramePart;
  TJSObject(window)['phanesGroundworkSelectionVersion'] := 0;
  SendSelection;
  Refresh;
end;

procedure TGroundworkUI.SendSelection(const AFrame: Boolean);
var
  LSettings: TJSObject;
  LVisible: Boolean;
  LKey: String;
begin
  if AFrame then
  begin
    Inc(FFrameVersion);
    FFrameId := FSelected;
  end;
  LVisible := FActive and FState.editing and (FState.interiorRoom = '');
  TJSObject(window)['phanesGroundworkActive'] := LVisible;
  TJSObject(window)['phanesGroundworkHasPlot'] := LVisible and (FPlot <> '');
  LKey := FSelected + ':' + BoolToStr(LVisible, True) + ':' + IntToStr(FFrameVersion);
  if LKey = FSelectionKey then
  begin
    Exit;
  end;
  FSelectionKey := LKey;
  LSettings := TJSObject.new;
  LSettings['selectedId'] := FSelected;
  LSettings['visible'] := LVisible and (FPlot <> '');
  LSettings['frameVersion'] := FFrameVersion;
  LSettings['frameId'] := FFrameId;
  TJSObject(window)['phanesGroundworkSelection'] := TJSJSON.stringify(LSettings);
  TJSObject(window)['phanesGroundworkSelectionVersion'] :=
    Integer(TJSObject(window)['phanesGroundworkSelectionVersion']) + 1;
  document.body.setAttribute('data-groundwork-selected', FSelected);
end;

procedure TGroundworkUI.Picked(const AId: String; const AVersion: Integer);
var
  LAction: String;
  LAuthoring: TAuthoringBridge;
  LPlot: String;
  LNode: Integer;
  LPlotNode: Integer;
begin
  LAction := String(TJSObject(window)['phanesPickAction']);
  if (FState.world = nil) or (FState.worker <> nil) or not FState.editing or
    (FState.interiorRoom <> '') or
    ((LAction <> 'end') and (LAction <> 'authoring-point')) or
    (AVersion <> Integer(TJSObject(window)['phanesPickVersion'])) or
    (Integer(TJSObject(window)['phanesPickSceneVersion']) <>
      Integer(TJSObject(window)['phanesSceneVersion'])) or
    (Integer(TJSObject(window)['phanesPickCameraVersion']) <>
      Integer(TJSObject(window)['phanesCameraVersion'])) then
  begin
    Exit;
  end;
  LNode := FIndex.Find(AId);
  LPlot := GroundworkOwner(FWorld.FComposition, FIndex, LNode);
  LPlotNode := FIndex.Find(LPlot);
  if (LNode < 0) or (LPlotNode < 0) then
  begin
    Exit;
  end;
  if LAction = 'authoring-point' then
  begin
    LAuthoring := TAuthoringBridge(TJSObject(window)['phanesAuthoringUI']);
    if (LAuthoring = nil) or not LAuthoring.completePointPick(AVersion) then
    begin
      Exit;
    end;
  end;
  FActive := True;
  document.body.setAttribute('data-groundworks', 'true');
  Element('groundwork-tools').hidden := False;
  FState.selection['x'] := (FWorld.FComposition.FNodes[LPlotNode].FX +
    FWorld.FSize * 8000) div 16000 - 1;
  FState.selection['z'] := (FWorld.FComposition.FNodes[LPlotNode].FZ +
    FWorld.FSize * 8000) div 16000 - 1;
  FActions.syncSelection;
  FSelected := AId;
  if AId = LPlot then
  begin
    FSelected := LPlot + '.deck';
  end;
  Refresh;
  document.body.setAttribute('data-groundwork-picked-version', IntToStr(AVersion));
  Element('groundwork-selected').focus;
end;

function TGroundworkUI.Protected(const AId: String): Boolean;
var
  LAt: Integer;
begin
  Result := False;
  LAt := FIndex.Find(AId);
  while LAt >= 0 do
  begin
    if FWorld.FComposition.FNodes[LAt].FLocked then
    begin
      Exit(True);
    end;
    LAt := FIndex.Find(FWorld.FComposition.FNodes[LAt].FParentId);
  end;
end;

function TGroundworkUI.Snapshot: TJSObject;
begin
  Result := TJSObject.new;
  Result['active'] := FActive;
  Result['selected'] := '';
  Result['plot'] := '';
  if FActive and (FIndex.Find(FPlot) >= 0) then
  begin
    Result['selected'] := FSelected;
    Result['plot'] := FPlot;
  end;
  Result['body'] := FBody;
  Result['turn'] := FTurn;
end;

procedure TGroundworkUI.RestoreCheckpoint(const AValue: TJSObject);
var
  LReason: String;
begin
  if AValue = nil then
  begin
    Exit;
  end;
  FActive := AValue['active'] = True;
  FTurn := Max(-1, Min(3, Integer(AValue['turn'])));
  FBody := 'plinth';
  if AValue['body'] = 'piers' then
  begin
    FBody := 'piers';
  end;
  document.body.setAttribute('data-groundworks', LowerCase(BoolToStr(FActive, True)));
  FPlot := String(AValue['plot']);
  if FPlot <> '' then
  begin
    if not ReadGroundwork(FWorld, FPlot, FAssembly, LReason) then
    begin
      raise Exception.Create('Saved groundwork could not be read: ' + LReason);
    end;
  end;
  NormalizeSelection;
  if FIndex.Find(String(AValue['selected'])) >= 0 then
  begin
    FSelected := String(AValue['selected']);
  end;
  Refresh;
end;

procedure TGroundworkUI.OnWorld;
begin
  FWorld := ReadWorld(FState.world);
  FIndex.Free;
  FIndex := TCompositionIndex.Create(FWorld.FComposition.FNodes);
  FPreviewKey := '';
  FGridKey := '';
end;

procedure TGroundworkUI.NormalizeSelection;
var
  LX: Integer;
  LZ: Integer;
  LCellX: Integer;
  LCellZ: Integer;
  LPlot: String;
  LReason: String;
  I: Integer;
begin
  if not FActive or (FState.world = nil) or (FState.interiorRoom <> '') then
  begin
    Exit;
  end;
  LX := Max(0, Min(FWorld.FSize - 2, Integer(FState.selection['x'])));
  LZ := Max(0, Min(FWorld.FSize - 2, Integer(FState.selection['z'])));
  LPlot := '';
  for I := 0 to High(FWorld.FComposition.FNodes) do
  begin
    if FWorld.FComposition.FNodes[I].FRole <> 'plot' then
    begin
      Continue;
    end;
    LCellX := (FWorld.FComposition.FNodes[I].FX + FWorld.FSize * 8000) div 16000 - 1;
    LCellZ := (FWorld.FComposition.FNodes[I].FZ + FWorld.FSize * 8000) div 16000 - 1;
    if (LX >= LCellX) and (LX < LCellX + 2) and (LZ >= LCellZ) and (LZ < LCellZ + 2) then
    begin
      LX := LCellX;
      LZ := LCellZ;
      LPlot := FWorld.FComposition.FNodes[I].FId;
      Break;
    end;
  end;
  { Plot mode makes a new complete footprint selection. A regional brush or
    fine foliage mask must not survive beside these replacement bounds. }
  FState.selection := TJSObject.new;
  FState.selection['x'] := LX;
  FState.selection['z'] := LZ;
  FState.selection['width'] := 2;
  FState.selection['depth'] := 2;
  if LPlot <> FPlot then
  begin
    FPlot := LPlot;
    FSelected := FPlot + '.deck';
    FGridKey := '';
  end;
  if FPlot <> '' then
  begin
    if not ReadGroundwork(FWorld, FPlot, FAssembly, LReason) then
    begin
      raise Exception.Create('The groundwork could not be displayed: ' + LReason);
    end;
    if FIndex.Find(FSelected) < 0 then
    begin
      FSelected := FPlot + '.deck';
    end;
    if FAssembly.FBody = gbPiers then
    begin
      FBody := 'piers';
    end
    else
    begin
      FBody := 'plinth';
    end;
  end;
end;

procedure TGroundworkUI.Preview;
var
  LStaged: TWorld;
  LKey: String;
  LX: Integer;
  LZ: Integer;
  LCellX: Integer;
  LCellZ: Integer;
  LLayer: Integer;
  LPitch: Integer;
  LStart: Integer;
  LAttempts: Integer;
  I: Integer;
begin
  LX := Integer(FState.selection['x']);
  LZ := Integer(FState.selection['z']);
  LKey := IntToStr(LX) + ':' + IntToStr(LZ) + ':' + IntToStr(FTurn);
  if LKey = FPreviewKey then
  begin
    Exit;
  end;
  FPreviewKey := LKey;
  FCanPlace := False;
  { Preview the deterministic terrain/contact recipe after the same regional
    clearing as placement. The worker remains the final composition/lock gate. }
  LStaged := FWorld;
  for LLayer := 0 to 4 do
  begin
    LStaged.FLayers[LLayer] := Copy(FWorld.FLayers[LLayer]);
    LPitch := LayerSize(FWorld.FSize, LLayer) div FWorld.FSize;
    for LCellZ := LZ * LPitch to (LZ + 2) * LPitch - 1 do
    begin
      for LCellX := LX * LPitch to (LX + 2) * LPitch - 1 do
      begin
        I := LCellZ * LayerSize(FWorld.FSize, LLayer) + LCellX;
        if LLayer = 0 then
        begin
          LStaged.FLayers[LLayer][I] := 'meadow';
        end
        else
        begin
          LStaged.FLayers[LLayer][I] := 'empty';
        end;
      end;
    end;
  end;
  LStart := FTurn;
  LAttempts := 1;
  if FTurn < 0 then
  begin
    LStart := (FWorld.FSeed + 1) mod 4;
    LAttempts := 4;
  end;
  for I := 0 to LAttempts - 1 do
  begin
    if PlanGroundworkGeometry(LStaged, LX, LZ, (LStart + I) mod 4,
      FPreview, FPreviewReason) then
    begin
      FCanPlace := True;
      FPreviewReason := '16 × 16 m deck · 2 m wide approach from the ' +
        LowerCase(CDirections[FPreview.FQuarterTurn]) + '.';
      Break;
    end;
  end;
end;

procedure TGroundworkUI.RenderParts;
var
  LButton: TJSHTMLElement;
  LId: String;
  LKey: String;
  LLabel: String;
  LNode: Integer;
  I: Integer;
begin
  LKey := FPlot + ':' + IntToStr(FWorld.FComposition.FRevision) + ':' + FSelected +
    ':' + BoolToStr(FState.worker <> nil, True);
  if LKey = FGridKey then
  begin
    Exit;
  end;
  FGridKey := LKey;
  LNode := FIndex.Find(FSelected);
  if LNode >= 0 then
  begin
    Element('groundwork-selected').textContent := FWorld.FComposition.FNodes[LNode].FName;
  end;
  Element('groundwork-panels').innerHTML := '';
  for I := 0 to 15 do
  begin
    if (I = 6) or (I = 9) or (I = 10) then
    begin
      Continue;
    end;
    LId := GroundworkPartId(FPlot, I);
    LButton := TJSHTMLElement(document.createElement('button'));
    LButton.setAttribute('data-groundwork-part', LId);
    LButton.setAttribute('data-material', CMaterialIds[FAssembly.FMaterials[I]]);
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(FSelected = LId, True)));
    LLabel := 'Panel ' + IntToStr(I + 1);
    if I = 5 then
    begin
      LLabel := 'Core';
      LButton.className := 'groundwork-core';
    end;
    LButton.textContent := LLabel;
    LButton.setAttribute('aria-label', LLabel + ' · ' + CMaterialNames[FAssembly.FMaterials[I]]);
    if FSelected = LId then
    begin
      Element('groundwork-selected').textContent := LLabel + ' · ' +
        CMaterialNames[FAssembly.FMaterials[I]];
    end;
    if Protected(LId) then
    begin
      LButton.setAttribute('aria-label', LButton.getAttribute('aria-label') + ' · locked');
      LButton.classList.add('locked');
    end;
    TJSHTMLButtonElement(LButton).disabled := FState.worker <> nil;
    LButton.addEventListener('click', @Click);
    Element('groundwork-panels').appendChild(LButton);
  end;
  LNode := FIndex.Find(FSelected);
  if (LNode >= 0) and ((FSelected = FPlot + '.deck') or
    (FSelected = FPlot + '.deck.ramp')) then
  begin
    Element('groundwork-selected').textContent := FWorld.FComposition.FNodes[LNode].FName;
  end;
end;

procedure TGroundworkUI.RenderBuildings;
var
  LProfile: TSupportedBuilding;
  LButton: TJSHTMLElement;
  LButtons: TJSNodeList;
  LBuildingId: String;
  LHasRoom: Boolean;
  LLocked: Boolean;
  LBusy: Boolean;
  I: Integer;
begin
  if Element('groundwork-buildings').childElementCount = 0 then
  begin
    for I := 0 to SupportedBuildingCount - 1 do
    begin
      LProfile := SupportedBuildingAt(I);
      LButton := TJSHTMLElement(document.createElement('button'));
      LButton.textContent := LProfile.FName;
      LButton.setAttribute('data-building-asset', LProfile.FAssetId);
      LButton.setAttribute('data-glyph', 'cabin');
      if I = 1 then
      begin
        LButton.setAttribute('data-glyph', 'castle');
      end
      else if I = 6 then
      begin
        LButton.setAttribute('data-glyph', 'rocket');
      end;
      LButton.addEventListener('click', @Click);
      Element('groundwork-buildings').appendChild(LButton);
    end;
  end;
  LBuildingId := FPlot + '.deck.building';
  LHasRoom := FIndex.Find(LBuildingId + '.studio') >= 0;
  LLocked := Protected(FPlot + '.deck') or Protected(LBuildingId);
  LBusy := FState.worker <> nil;
  LButtons := Element('groundwork-buildings').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLElement(LButtons[I]);
    LProfile := SupportedBuildingAt(I);
    TJSHTMLButtonElement(LButton).disabled := LBusy or LLocked or LHasRoom or
      (LProfile.FAssetId = FAssembly.FBuildingAsset);
    LButton.setAttribute('aria-pressed',
      LowerCase(BoolToStr(LProfile.FAssetId = FAssembly.FBuildingAsset, True)));
  end;
  Element('groundwork-inside').hidden :=
    not SupportedBuilding(FAssembly.FBuildingAsset, LProfile) or not LProfile.FHasStudio;
  Element('groundwork-inside').textContent := 'Furnish interior';
  if LHasRoom then
  begin
    Element('groundwork-inside').textContent := 'Open interior';
  end;
  Enable('groundwork-inside', not LBusy and (LHasRoom or not LLocked));
  Element('groundwork-remove-building').hidden := FAssembly.FBuildingAsset = '';
  for I := 0 to High(FWorld.FComposition.FNodes) do
  begin
    if InCompositionScope(FWorld.FComposition, FIndex, I, LBuildingId) and
      FWorld.FComposition.FNodes[I].FLocked then
    begin
      LLocked := True;
    end;
  end;
  Enable('groundwork-remove-building', not LBusy and not LLocked);
  Element('groundwork-building-hint').textContent :=
    'Choose a building. Its base rests on this deck; the supports remain independently editable.';
  if LHasRoom then
  begin
    Element('groundwork-building-hint').textContent :=
      'This building owns a furnished studio. Deck and support edits preserve everything inside.';
  end;
end;

procedure TGroundworkUI.Refresh;
var
  LBusy: Boolean;
  LId: String;
  LText: String;
  LButtons: TJSNodeList;
  LButton: TJSHTMLElement;
  LEditable: Boolean;
  I: Integer;
begin
  LBusy := (FState.world = nil) or (FState.worker <> nil);
  SendSelection;
  Enable('open-groundworks', not LBusy and (FState.interiorRoom = ''));
  if not FActive then
  begin
    Exit;
  end;
  Element('groundwork-new').hidden := FPlot <> '';
  Element('groundwork-existing').hidden := FPlot = '';
  Element('groundwork-title').textContent := 'A place to build.';
  if FPlot = '' then
  begin
    Preview;
    Element('groundwork-description').textContent := FPreviewReason;
    Enable('groundwork-foundation', not LBusy and FCanPlace);
    Enable('groundwork-launch-pad', not LBusy and FCanPlace);
    Enable('groundwork-reimagine', False);
  end
  else
  begin
    FBody := 'plinth';
    if FAssembly.FBody = gbPiers then
    begin
      FBody := 'piers';
    end;
    Element('groundwork-title').textContent := 'Foundation';
    if FAssembly.FPurpose = gpLaunchPad then
    begin
      Element('groundwork-title').textContent := 'Launch pad';
    end;
    Element('groundwork-description').textContent :=
      'Tap a visible part in the world, or choose it below. Drag to orbit in the angled view.';
    RenderParts;
    RenderBuildings;
    LEditable := (FSelected = FPlot + '.deck') or
      ((Pos('.deck.panel-', FSelected) > 0) and not Protected(FSelected));
    Enable('groundwork-reimagine', not LBusy and LEditable and not Protected(FSelected));
    LText := 'Reimagine this part. Other parts keep their placement.';
    if FSelected = FPlot + '.deck.core' then
    begin
      LText := 'One continuous 8 × 8 m support surface. Its shape and material stay fixed.';
    end
    else if FSelected = FPlot + '.deck.ramp' then
    begin
      LText := 'A 6 m ramp and 2 m graded landing meet the ground. Access stays fixed.';
    end
    else if FSelected = FPlot + '.deck.ramp.landing' then
    begin
      LText := 'This graded patch of terrain meets the ramp. Its contact and slope stay fixed.';
    end
    else if FSelected = FPlot + '.deck.body' then
    begin
      LText := 'Choose a solid plinth or piers below. Everything supported above stays in place.';
    end
    else if FSelected = FPlot + '.deck.building' then
    begin
      LText := 'This building rests on the deck. Choose a shell above, or open the cabin interior.';
    end;
    if Protected(FSelected) then
    begin
      LText := 'This part is locked in the saved world.';
    end;
    Element('groundwork-scope-hint').textContent := LText;
  end;
  Enable('groundwork-plinth', not LBusy and
    ((FPlot = '') or ((FBody <> 'plinth') and not Protected(FPlot + '.deck.body'))));
  Enable('groundwork-piers', not LBusy and
    ((FPlot = '') or ((FBody <> 'piers') and not Protected(FPlot + '.deck.body'))));
  Element('groundwork-plinth').setAttribute('aria-pressed', LowerCase(BoolToStr(FBody = 'plinth', True)));
  Element('groundwork-piers').setAttribute('aria-pressed', LowerCase(BoolToStr(FBody = 'piers', True)));
  for LId in CExistingActions do
  begin
    Enable(LId, not LBusy and (FPlot <> ''));
  end;
  Enable('groundwork-undo', not LBusy and not TJSHTMLButtonElement(Element('undo')).disabled);
  Enable('groundwork-body', not LBusy and (FPlot <> ''));
  Enable('groundwork-landing', not LBusy and (FPlot <> ''));
  Enable('groundwork-building', not LBusy and (FPlot <> '') and
    (FAssembly.FBuildingAsset <> ''));
  Element('groundwork-deck').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FSelected = FPlot + '.deck', True)));
  Element('groundwork-ramp').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FSelected = FPlot + '.deck.ramp', True)));
  Element('groundwork-landing').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FSelected = FPlot + '.deck.ramp.landing', True)));
  Element('groundwork-body').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FSelected = FPlot + '.deck.body', True)));
  Element('groundwork-building').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FSelected = FPlot + '.deck.building', True)));
  Enable('groundwork-select', not LBusy);
  Enable('leave-groundworks', not LBusy);
  LButtons := Element('groundwork-directions').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLElement(LButtons[I]);
    TJSHTMLButtonElement(LButton).disabled := LBusy;
    LButton.setAttribute('aria-pressed',
      LowerCase(BoolToStr(StrToInt(LButton.getAttribute('data-groundwork-turn')) = FTurn, True)));
  end;
end;

procedure TGroundworkUI.Frame;
begin
  { Bring the owning chunk back into detail before asking the renderer for
    exact part bounds. A durable selection can outlive its streamed instance. }
  FState.panX := FAssembly.FGeometry.FX / 1000;
  FState.panY := FAssembly.FGeometry.FDeckY / 1000;
  FState.panZ := FAssembly.FGeometry.FZ / 1000;
  FState.zoom := FWorld.FSize * 16 / 40;
  FState.yaw := FAssembly.FGeometry.FQuarterTurn * Pi / 2 + 0.65;
  FState.pitch := 0.08;
  FActions.setCamera('orbit');
  if FSelected <> FPlot + '.deck' then
  begin
    SendSelection(True);
  end;
end;

procedure TGroundworkUI.FramePart(const AId: String; const AX, AY, AZ, ASize: Double);
begin
  if not FActive or (FState.interiorRoom <> '') or (AId <> FSelected) then
  begin
    Exit;
  end;
  FState.panX := AX;
  FState.panY := AY;
  FState.panZ := AZ;
  FState.zoom := Max(0.4, Min(12, FWorld.FSize * 16 / (ASize * 1.8)));
  FState.yaw := FAssembly.FGeometry.FQuarterTurn * Pi / 2 + 0.65;
  FState.pitch := 0.08;
  FActions.setCamera('orbit');
end;

procedure TGroundworkUI.Request(const AOperation, AScope, ABody: String);
var
  LOptions: TJSObject;
begin
  LOptions := TJSObject.new;
  if AScope <> '' then
  begin
    LOptions['objectId'] := AScope;
  end;
  LOptions['groundworkBody'] := ABody;
  if (AOperation = 'foundation') or (AOperation = 'launch-pad') then
  begin
    LOptions['groundworkTurn'] := FPreview.FQuarterTurn;
  end;
  FActions.generate(AOperation, nil, LOptions);
end;

function TGroundworkUI.Click(AEvent: TJSEvent): Boolean;
var
  LButton: TJSHTMLElement;
  LId: String;
  LPart: String;
  LOptions: TJSObject;
  LX: Double;
  LZ: Double;
begin
  Result := True;
  LButton := TJSHTMLElement(AEvent.currentTarget);
  LId := LButton.id;
  if (FState.world = nil) or (FState.worker <> nil) then
  begin
    Exit;
  end;
  if LButton.hasAttribute('data-groundwork-part') then
  begin
    LPart := LButton.getAttribute('data-groundwork-part');
    FSelected := LPart;
    Refresh;
    Element('groundwork-selected').focus;
    Exit;
  end;
  if LButton.hasAttribute('data-building-asset') then
  begin
    LOptions := TJSObject.new;
    LOptions['objectId'] := FPlot;
    LOptions['buildingAsset'] := LButton.getAttribute('data-building-asset');
    FActions.generate('place-building', nil, LOptions);
    Exit;
  end;
  if LButton.hasAttribute('data-groundwork-turn') then
  begin
    FTurn := StrToInt(LButton.getAttribute('data-groundwork-turn'));
    Refresh;
    Exit;
  end;
  case LId of
    'groundwork-inside':
    begin
      OpenSupportedInterior(FPlot + '.deck.building');
    end;
    'groundwork-remove-building':
    begin
      Request('remove-building', FPlot, '');
    end;
    'open-groundworks':
    begin
      FActive := True;
      document.body.setAttribute('data-groundworks', 'true');
      Element('groundwork-tools').hidden := False;
      FActions.syncSelection;
      FActions.setCamera('top');
      Element('groundwork-title').focus;
    end;
    'leave-groundworks':
    begin
      FActions.cancelPointer;
      FActive := False;
      document.body.setAttribute('data-groundworks', 'false');
      Element('groundwork-tools').hidden := True;
      FActions.syncSelection;
      Element('open-groundworks').focus;
    end;
    'groundwork-foundation':
    begin
      Request('foundation', '', FBody);
    end;
    'groundwork-launch-pad':
    begin
      Request('launch-pad', '', FBody);
    end;
    'groundwork-plinth', 'groundwork-piers':
    begin
      if LId = 'groundwork-plinth' then
      begin
        FBody := 'plinth';
      end
      else
      begin
        FBody := 'piers';
      end;
      if FPlot <> '' then
      begin
        Request('groundwork', FPlot + '.deck.body', FBody);
      end;
    end;
    'groundwork-frame':
    begin
      Frame;
    end;
    'groundwork-select':
    begin
      FActions.setCamera('top');
    end;
    'groundwork-walk':
    begin
      { Start at the landing edge, inside the admitted full-radius apron.
        A point a metre farther out can be submerged even for a valid plot. }
      GroundworkToWorld(FAssembly.FGeometry, 0, GroundworkPlotHalfMetres, LX, LZ);
      FState.x := LX;
      FState.z := LZ;
      FState.y := FAssembly.FGeometry.FToeY / 1000 + 1.68;
      FState.yaw := -FAssembly.FGeometry.FQuarterTurn * Pi / 2;
      FState.pitch := 0;
      FActions.setCamera('walk');
    end;
    'groundwork-reimagine':
    begin
      Request('groundwork', FSelected, FBody);
    end;
    'groundwork-deck':
    begin
      FSelected := FPlot + '.deck';
    end;
    'groundwork-ramp':
    begin
      FSelected := FPlot + '.deck.ramp';
    end;
    'groundwork-landing':
    begin
      FSelected := FPlot + '.deck.ramp.landing';
    end;
    'groundwork-body':
    begin
      FSelected := FPlot + '.deck.body';
    end;
    'groundwork-building':
    begin
      FSelected := FPlot + '.deck.building';
    end;
    'groundwork-undo':
    begin
      Element('undo').click;
    end;
  end;
  Refresh;
end;

procedure StartGroundworkUI;
begin
  GGroundworkUI := TGroundworkUI.Create;
end;

end.
