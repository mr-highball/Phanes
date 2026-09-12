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

unit phanes.buildings.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartBuildingUI;

implementation

uses
  JS, Web, SysUtils, Math, phanes.world.types, phanes.world.wire,
  phanes.composition.types, phanes.composition.document, phanes.buildings.types,
  phanes.buildings.validate, phanes.buildings.geometry,
  phanes.composition.contents.types, phanes.interiors.surfaces;

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
    procedure syncSelection;
    procedure syncCamera;
    procedure cancelPointer;
    procedure setCamera(const AMode: String);
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TBuildingUI = class
  private
    FState: TEditorState;
    FActions: TEditorActions;
    FWorld: TWorld;
    FIndex: TCompositionIndex;
    FActive: Boolean;
    FPicking: Boolean;
    FCutaway: Boolean;
    FRoot: String;
    FSelected: String;
    FNearby: String;
    FNext: String;
    FSeenWorld: TJSObject;
    FNextNearby: Double;
    FDisplayedCount: Integer;
    function Click(AEvent: TJSEvent): Boolean;
    function Protected(const AId: String): Boolean;
    procedure Paint;
    procedure SelectParts;
    procedure SelectPart(const AId: String);
    procedure Picked(const AId: String; const AVersion: Integer);
    procedure Request(const AOperation, AId, AContent: String);
    procedure RenderLists;
    procedure Nearby(const ATime: Double);
    procedure Focus(const AId: String = '');
    procedure Frame(const AId: String; const AX, AY, AZ, ASize: Double);
    procedure RenderContents;
  public
    constructor Create;
    procedure OnWorld;
    procedure Refresh;
    function Snapshot: TJSObject;
    procedure RestoreCheckpoint(const AValue: TJSObject);
  end;

var
  GBuildingUI: TBuildingUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

procedure Enable(const AId: String; const AEnabled: Boolean);
begin
  TJSHTMLButtonElement(Element(AId)).disabled := not AEnabled;
end;

constructor TBuildingUI.Create;
var
  LBridge: TJSObject;
  LButtons: TJSNodeList;
  I: Integer;
begin
  FState := TEditorState(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  FIndex := TCompositionIndex.Create(nil);
  LButtons := document.querySelectorAll('[data-module-action]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButtons[I].addEventListener('click', @Click);
  end;
  Element('module-homes').addEventListener('change', @Click);
  Element('module-parts').addEventListener('change', @Click);
  Element('module-cutaway').addEventListener('change', @Click);
  Element('module-content-role').addEventListener('change', @Click);
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  LBridge['onWorld'] := @OnWorld;
  LBridge['snapshot'] := @Snapshot;
  LBridge['restoreCheckpoint'] := @RestoreCheckpoint;
  TJSObject(window)['phanesBuildingUI'] := LBridge;
  TJSObject(window)['phanesModularPicked'] := @Picked;
  TJSObject(window)['phanesModularFrame'] := @Frame;
  TJSObject(window)['phanesModularFrameVersion'] := 0;
  TJSObject(window)['phanesModularZoomLimit'] := 12;
  TJSObject(window)['phanesModularPicking'] := False;
  TJSObject(window)['phanesModularCutaway'] := False;
  TJSObject(window)['phanesModularSelected'] := '';
  Refresh;
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Nearby(ATime);
    end);
end;

function TBuildingUI.Protected(const AId: String): Boolean;
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

procedure TBuildingUI.OnWorld;
var
  LOldCount: Integer;
  I: Integer;
begin
  if FState.world = FSeenWorld then
  begin
    Exit;
  end;
  LOldCount := Length(FWorld.FComposition.FNodes);
  FSeenWorld := FState.world;
  FWorld := ReadWorld(FState.world);
  FIndex.Free;
  FIndex := TCompositionIndex.Create(FWorld.FComposition.FNodes);
  if (FNext = 'module-build') and (Length(FWorld.FComposition.FNodes) > LOldCount) then
  begin
    for I := High(FWorld.FComposition.FNodes) downto 0 do
    begin
      if FWorld.FComposition.FNodes[I].FAssetId = ModularBuildingAsset then
      begin
        FRoot := FWorld.FComposition.FNodes[I].FId;
        FSelected := FRoot;
        SelectParts;
        FCutaway := True;
        Break;
      end;
    end;
  end;
  FNext := '';
  if FIndex.Find(FRoot) < 0 then
  begin
    FRoot := '';
  end;
  if FIndex.Find(FSelected) < 0 then
  begin
    FSelected := FRoot;
  end;
  RenderLists;
end;

procedure TBuildingUI.RenderLists;
var
  LOption: TJSHTMLOptionElement;
  LNode: TCompositionNode;
  LToken: String;
  LPosition: String;
  LPlaced: Integer;
  I: Integer;
begin
  Element('module-homes').innerHTML := '<option value="">Choose a home</option>';
  Element('module-parts').innerHTML := '<option value="">Select a wall or floor in the view</option>';
  for I := 0 to High(FWorld.FComposition.FNodes) do
  begin
    LNode := FWorld.FComposition.FNodes[I];
    if LNode.FAssetId = ModularBuildingAsset then
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := LNode.FId;
      LOption.textContent := String(LNode.FName) + ' · ' + LNode.FId;
      Element('module-homes').appendChild(LOption);
    end;
    if (ModularOwner(FWorld.FComposition, FIndex, I) = FRoot) and
      (LNode.FId <> FRoot) and (FRoot <> '') then
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := LNode.FId;
      LToken := StringReplace(ModuleToken(LNode.FAssetId), '.', ' · ', [rfReplaceAll]);
      if LToken = '' then
      begin
        LToken := String(LNode.FName);
      end;
      LOption.textContent := LToken + ' (' + IntToStr(LNode.FX div 1000) + ', ' +
        IntToStr(LNode.FZ div 1000) + ' m)';
      if LNode.FLocked then
      begin
        LOption.textContent := LOption.textContent + ' · locked';
      end;
      Element('module-parts').appendChild(LOption);
    end;
  end;
  TJSHTMLSelectElement(Element('module-homes')).value := FRoot;
  TJSHTMLSelectElement(Element('module-parts')).value := FSelected;
  TJSHTMLSelectElement(Element('module-position')).value := '0,0';
  TJSHTMLSelectElement(Element('module-turn')).value := '0';
  LPlaced := FIndex.Find(FSelected + '.furnishing');
  if LPlaced >= 0 then
  begin
    LPosition :=
      IntToStr(FWorld.FComposition.FNodes[LPlaced].FX) + ',' +
      IntToStr(FWorld.FComposition.FNodes[LPlaced].FZ);
    if Element('module-position').querySelector('option[value="' + LPosition + '"]') = nil then
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := LPosition;
      LOption.textContent := 'Saved position · ' + LPosition + ' mm';
      Element('module-position').appendChild(LOption);
    end;
    TJSHTMLSelectElement(Element('module-position')).value := LPosition;
    TJSHTMLSelectElement(Element('module-turn')).value :=
      IntToStr(FWorld.FComposition.FNodes[LPlaced].FQuarterTurn);
    TJSHTMLSelectElement(Element('module-furniture')).value :=
      FWorld.FComposition.FNodes[LPlaced].FAssetId;
  end;
  RenderContents;
end;

procedure TBuildingUI.RenderContents;
var
  LRequest: TContentRequest;
  LReason: String;
  LOption: TJSHTMLOptionElement;
  LRole: String;
  LAllowed: Boolean;
  LCapacity: Integer;
  I: Integer;
  J: Integer;
begin
  LRole := TJSHTMLSelectElement(Element('module-content-role')).value;
  Element('module-contents').hidden :=
    not SurfaceRequest(FWorld.FComposition, FSelected, LRequest, LReason);
  Element('module-content-role').innerHTML := '';
  if Element('module-contents').hidden then
  begin
    Exit;
  end;
  for I := 0 to High(LRequest.FQuotas) do
  begin
    LAllowed := False;
    for J := 0 to High(LRequest.FSlots) do
    begin
      LAllowed := LAllowed or ContentRoleAllowed(LRequest.FSlots[J].FAllowedRoles,
        LRequest.FQuotas[I].FRole);
    end;
    if not LAllowed then
    begin
      Continue;
    end;
    LOption := TJSHTMLOptionElement(document.createElement('option'));
    LOption.value := LRequest.FQuotas[I].FRole;
    LOption.textContent := LRequest.FQuotas[I].FRole;
    Element('module-content-role').appendChild(LOption);
  end;
  if TJSHTMLSelectElement(Element('module-content-role')).querySelector(
    'option[value="' + LRole + '"]') <> nil then
  begin
    TJSHTMLSelectElement(Element('module-content-role')).value := LRole;
  end;
  if Length(LRequest.FQuotas) > 0 then
  begin
    LCapacity := 0;
    for I := 0 to High(LRequest.FSlots) do
    begin
      if ContentRoleAllowed(LRequest.FSlots[I].FAllowedRoles,
        TJSHTMLSelectElement(Element('module-content-role')).value) then
      begin
        Inc(LCapacity);
      end;
    end;
    Element('module-content-count').setAttribute('max', IntToStr(Min(6, LCapacity)));
    TJSHTMLInputElement(Element('module-content-count')).value := '0';
    for I := 0 to High(LRequest.FQuotas) do
    begin
      if LRequest.FQuotas[I].FRole = TJSHTMLSelectElement(Element('module-content-role')).value then
      begin
        TJSHTMLInputElement(Element('module-content-count')).value :=
          IntToStr(LRequest.FQuotas[I].FMinimum);
      end;
    end;
  end;
  FDisplayedCount := StrToInt(TJSHTMLInputElement(Element('module-content-count')).value);
end;

procedure TBuildingUI.SelectParts;
begin
  FPicking := True;
  TJSHTMLElement(document.querySelector('[data-authoring-tool="point"]')).click;
end;

procedure TBuildingUI.SelectPart(const AId: String);
var
  LRoot: String;
begin
  LRoot := ModularOwner(FWorld.FComposition, FIndex, FIndex.Find(AId));
  if LRoot = '' then
  begin
    Exit;
  end;
  FRoot := LRoot;
  FSelected := AId;
  SelectParts;
  RenderLists;
  Refresh;
end;

procedure TBuildingUI.Picked(const AId: String; const AVersion: Integer);
begin
  if FActive and FPicking and FState.editing and (FState.worker = nil) and
    (AVersion = Integer(TJSObject(window)['phanesPickVersion'])) then
  begin
    if AId = '' then
    begin
      FActions.notify('Tap a part. Use the cutaway to reach parts inside.', False);
    end
    else
    begin
      SelectPart(AId);
    end;
  end;
end;

procedure TBuildingUI.Paint;
begin
  FPicking := False;
  FActions.cancelPointer;
  TJSHTMLSelectElement(Element('selection-scale')).value := '8';
  Element('selection-scale').dispatchEvent(TJSEvent.new('change'));
  TJSHTMLElement(document.querySelector('[data-authoring-tool="box"]')).click;
  FActions.notify('Draw a footprint with Box, Brush or Lasso. Imagine or Extend applies it.', False);
  Refresh;
end;

procedure TBuildingUI.Focus(const AId: String);
var
  LTarget: String;
begin
  LTarget := AId;
  if LTarget = '' then
  begin
    LTarget := FSelected;
  end;
  if LTarget = '' then
  begin
    LTarget := FRoot;
  end;
  TJSObject(window)['phanesModularFrameTarget'] := LTarget;
  TJSObject(window)['phanesModularFrameVersion'] :=
    Integer(TJSObject(window)['phanesModularFrameVersion']) + 1;
end;

procedure TBuildingUI.Frame(const AId: String; const AX, AY, AZ, ASize: Double);
var
  LAt: Integer;
  LFacing: Integer;
  LSupport: Integer;
  LTurn: Integer;
  LRole: String;
begin
  if not FActive or (FState.interiorRoom <> '') or (FState.worker <> nil) or
    ((AId <> FSelected) and (AId <> FRoot)) then
  begin
    Exit;
  end;
  FState.panX := AX;
  FState.panY := AY;
  FState.panZ := AZ;
  FState.zoom := EnsureRange(FWorld.FSize * 16 / (Max(0.16, ASize) * 1.8),
    0.4, FWorld.FSize * 128);
  FState.yaw := -0.4;
  FState.pitch := 0.15;
  LAt := FIndex.Find(AId);
  if LAt >= 0 then
  begin
    LRole := FWorld.FComposition.FNodes[LAt].FRole;
    LFacing := LAt;
    LSupport := FIndex.Find(FWorld.FComposition.FNodes[LAt].FSupportId);
    if (LSupport >= 0) and (FWorld.FComposition.FNodes[LSupport].FRole <> 'floor-tile') then
    begin
      { Small props face their support; floor furnishings retain their own facing. }
      LFacing := LSupport;
    end;
    LTurn := 0;
    while LFacing >= 0 do
    begin
      Inc(LTurn, FWorld.FComposition.FNodes[LFacing].FQuarterTurn);
      LFacing := FIndex.Find(FWorld.FComposition.FNodes[LFacing].FParentId);
    end;
    if (ASize < 1) or (LRole = 'bookcase') then
    begin
      FState.yaw := LTurn * Pi / 2;
      FState.pitch := -0.1;
    end;
    if (LRole = 'plate') or (LRole = 'plate-well') or (LRole = 'bread') or
      (LRole = 'fruit') or (LRole = 'cheese') or (LRole = 'tabletop') or
      (LRole = 'bench-top') then
    begin
      FState.yaw := LTurn * Pi / 2 + 0.35;
      FState.pitch := 0.4;
    end;
  end;
  FActions.setCamera('orbit');
  FActions.syncCamera;
end;

procedure TBuildingUI.Request(const AOperation, AId, AContent: String);
var
  LOptions: TJSObject;
  LBuilding: TModularBuilding;
  LReason: String;
  LEdge: TBuildingEdge;
  LCount: Integer;
  LCapacity: Integer;
  LPosition: String;
  LComma: Integer;
  I: Integer;
begin
  if FState.worker <> nil then
  begin
    Exit;
  end;
  if (AOperation = 'module-toggle') and
    ((FState.camera = 'walk') or (FState.camera = 'fly')) and
    ReadModularBuilding(FWorld, ModularOwner(FWorld.FComposition, FIndex,
      FIndex.Find(AId)), LBuilding, LReason) then
  begin
    for I := 0 to High(LBuilding.FEdges) do
    begin
      LEdge := LBuilding.FEdges[I];
      if (LEdge.FNode.FId = AId) and
        (Abs(FState.y - LBuilding.FRoot.FY / 1000 - 1.68) < 2) and
        ModuleDoorSweepBlocks(LEdge, FState.x, FState.z, 0.3) then
      begin
        FActions.notify('Step back from the door so it has room to swing.', False);
        Exit;
      end;
    end;
  end;
  LOptions := TJSObject.new;
  LOptions['objectId'] := AId;
  LOptions['contentAsset'] := AContent;
  if AOperation = 'module-furnish' then
  begin
    LPosition := TJSHTMLSelectElement(Element('module-position')).value;
    LComma := Pos(',', LPosition);
    LOptions['moduleX'] := StrToInt(Copy(LPosition, 1, LComma - 1));
    LOptions['moduleZ'] := StrToInt(Copy(LPosition, LComma + 1, Length(LPosition)));
    LOptions['moduleTurn'] := StrToInt(TJSHTMLSelectElement(Element('module-turn')).value);
  end;
  if (AOperation = 'contents-count') or (AOperation = 'contents') then
  begin
    LCapacity := StrToInt(Element('module-content-count').getAttribute('max'));
    if not TryStrToInt(TJSHTMLInputElement(Element('module-content-count')).value, LCount) or
      (LCount < 0) or (LCount > LCapacity) then
    begin
      FActions.notify('Choose a whole number from 0 to ' + IntToStr(LCapacity) + '.', True);
      Exit;
    end;
    if (AOperation = 'contents-count') or (LCount <> FDisplayedCount) then
    begin
      LOptions['contentCount'] := LCount;
      LOptions['contentRole'] := TJSHTMLSelectElement(Element('module-content-role')).value;
    end;
    FActions.generate('contents', nil, LOptions);
    Exit;
  end;
  FNext := AOperation;
  FActions.generate(AOperation, nil, LOptions);
end;

function TBuildingUI.Click(AEvent: TJSEvent): Boolean;
var
  LTarget: TJSHTMLElement;
  LAction: String;
  LParent: Integer;
  I: Integer;
begin
  Result := True;
  LTarget := TJSHTMLElement(AEvent.currentTarget);
  LAction := LTarget.getAttribute('data-module-action');
  if (FState.world = nil) or (FState.worker <> nil) then
  begin
    Exit;
  end;
  if LTarget.id = 'module-content-role' then
  begin
    RenderContents;
  end
  else if LTarget.id = 'module-homes' then
  begin
    SelectPart(TJSHTMLSelectElement(LTarget).value);
  end
  else if LTarget.id = 'module-parts' then
  begin
    SelectPart(TJSHTMLSelectElement(LTarget).value);
  end
  else if LTarget.id = 'module-cutaway' then
  begin
    FCutaway := TJSHTMLInputElement(LTarget).checked;
  end
  else if LAction = 'open' then
  begin
    if document.body.getAttribute('data-groundworks') = 'true' then
    begin
      Element('leave-groundworks').click;
    end;
    FActive := True;
    FCutaway := True;
    Paint;
  end
  else if LAction = 'leave' then
  begin
    FActive := False;
    FPicking := False;
    FState.zoom := Min(12, FState.zoom);
    FActions.syncCamera;
    TJSHTMLSelectElement(Element('selection-scale')).value := '1';
    Element('selection-scale').dispatchEvent(TJSEvent.new('change'));
  end
  else if LAction = 'paint' then
  begin
    Paint;
  end
  else if LAction = 'select' then
  begin
    SelectParts;
  end
  else if LAction = 'focus' then
  begin
    Focus;
  end
  else if LAction = 'overview' then
  begin
    SelectPart(FRoot);
    Focus(FRoot);
  end
  else if LAction = 'build' then
  begin
    Request('module-build', '', '');
  end
  else if LAction = 'extend' then
  begin
    Request('module-extend', FRoot, '');
  end
  else if (LAction = 'wall') or (LAction = 'window') or
    (LAction = 'door') or (LAction = 'opening') then
  begin
    Request('module-edge', FSelected, LAction);
  end
  else if LAction = 'toggle' then
  begin
    Request('module-toggle', FSelected, '');
  end
  else if LAction = 'nearby' then
  begin
    Request('module-toggle', FNearby, '');
  end
  else if LAction = 'lock' then
  begin
    Request('module-lock', FSelected, '');
  end
  else if LAction = 'furnish' then
  begin
    Request('module-furnish', FSelected,
      TJSHTMLSelectElement(Element('module-furniture')).value);
  end
  else if LAction = 'contents' then
  begin
    Request('contents', FSelected, '');
  end
  else if LAction = 'count' then
  begin
    Request('contents-count', FSelected, '');
  end
  else if LAction = 'closer' then
  begin
    for I := 0 to High(FWorld.FComposition.FNodes) do
    begin
      if FWorld.FComposition.FNodes[I].FParentId = FSelected then
      begin
        SelectPart(FWorld.FComposition.FNodes[I].FId);
        Focus;
        Break;
      end;
    end;
  end
  else if LAction = 'up' then
  begin
    LParent := FIndex.Find(FSelected);
    if LParent >= 0 then
    begin
      SelectPart(FWorld.FComposition.FNodes[LParent].FParentId);
      Focus;
    end;
  end
  else if LAction = 'undo' then
  begin
    Element('undo').click;
  end
  else if LAction = 'redo' then
  begin
    Element('redo').click;
  end;
  Refresh;
end;

procedure TBuildingUI.Nearby(const ATime: Double);
var
  LNode: TCompositionNode;
  LAt: Integer;
  LDistance: Double;
  LBest: Double;
  I: Integer;
begin
  if ATime < FNextNearby then
  begin
    window.requestAnimationFrame(procedure(ANextTime: Double)
      begin
        Nearby(ANextTime);
      end);
    Exit;
  end;
  FNextNearby := ATime + 120;
  FNearby := '';
  LBest := Sqr(2.5);
  if not document.hidden and (FState.interiorRoom = '') and
    ((FState.camera = 'walk') or (FState.camera = 'fly')) and (FState.worker = nil) then
  begin
    for I := 0 to High(FWorld.FComposition.FNodes) do
    begin
      LNode := FWorld.FComposition.FNodes[I];
      if not ModuleIsDoor(ModuleToken(LNode.FAssetId)) or Protected(LNode.FId) then
      begin
        Continue;
      end;
      LAt := FIndex.Find(LNode.FParentId);
      if (LAt < 0) or
        (Abs(FState.y - FWorld.FComposition.FNodes[LAt].FY / 1000 - 1.68) > 2) then
      begin
        Continue;
      end;
      LDistance := Sqr(FState.x - LNode.FX / 1000) + Sqr(FState.z - LNode.FZ / 1000);
      if LDistance < LBest then
      begin
        LBest := LDistance;
        FNearby := LNode.FId;
        Element('module-nearby').textContent := 'Open door';
        if Pos('door.open.', ModuleToken(LNode.FAssetId)) = 1 then
        begin
          Element('module-nearby').textContent := 'Close door';
        end;
      end;
    end;
  end;
  Element('module-nearby').hidden := FNearby = '';
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Nearby(ATime);
    end);
end;

procedure TBuildingUI.Refresh;
var
  LAt: Integer;
  LToken: String;
  LReady: Boolean;
  LMask: Boolean;
  LChildren: Boolean;
  I: Integer;
begin
  LReady := (FState.world <> nil) and (FState.worker = nil) and FState.editing;
  if (FState.interiorRoom <> '') or (document.body.getAttribute('data-groundworks') = 'true') then
  begin
    FActive := False;
    FPicking := False;
  end;
  Element('module-tools').hidden := not FActive or (FState.interiorRoom <> '');
  document.body.setAttribute('data-modular', LowerCase(BoolToStr(FActive, True)));
  TJSObject(window)['phanesModularPicking'] := FActive and FPicking and LReady;
  TJSObject(window)['phanesModularCutaway'] := FActive and FCutaway and
    FState.editing and (FState.camera <> 'walk');
  TJSObject(window)['phanesModularSelected'] := '';
  TJSObject(window)['phanesModularZoomLimit'] := 12;
  if FActive and FState.editing then
  begin
    TJSObject(window)['phanesModularSelected'] := FSelected;
    TJSObject(window)['phanesModularZoomLimit'] := Max(12, FWorld.FSize * 128);
  end;
  TJSHTMLInputElement(Element('module-cutaway')).checked := FCutaway;
  Element('module-paint').setAttribute('aria-pressed', LowerCase(BoolToStr(not FPicking, True)));
  Element('module-select').setAttribute('aria-pressed', LowerCase(BoolToStr(FPicking, True)));
  Enable('open-modules', LReady and (FState.interiorRoom = ''));
  Enable('module-paint', LReady);
  Enable('module-select', LReady);
  LMask := (FState.selection <> nil) and (FState.selection['selectionScale'] = 8) and
    isArray(FState.selection['selectionCells']);
  if LMask then
  begin
    LMask := TJSArray(FState.selection['selectionCells']).Length > 0;
  end;
  Enable('module-build', LReady and LMask);
  Enable('module-extend', LReady and LMask and (FRoot <> '') and not Protected(FRoot));
  Enable('module-focus', (FRoot <> '') and (FState.worker = nil));
  Enable('module-overview', (FRoot <> '') and (FState.worker = nil));
  LAt := FIndex.Find(FSelected);
  LToken := '';
  if LAt >= 0 then
  begin
    LToken := ModuleToken(FWorld.FComposition.FNodes[LAt].FAssetId);
  end;
  Enable('module-wall', LReady and ModuleIsEdge(LToken) and not Protected(FSelected));
  Enable('module-window', LReady and ModuleIsEdge(LToken) and not Protected(FSelected));
  Enable('module-door', LReady and ModuleIsEdge(LToken) and not Protected(FSelected));
  Enable('module-opening', LReady and ModuleIsEdge(LToken) and not Protected(FSelected));
  Enable('module-toggle', LReady and ModuleIsDoor(LToken) and not Protected(FSelected));
  Enable('module-lock', LReady and (LAt >= 0));
  Element('module-furnish-controls').hidden := not ModuleIsFloor(LToken);
  Enable('module-furnish', LReady and ModuleIsFloor(LToken) and not Protected(FSelected));
  LChildren := False;
  for I := 0 to High(FWorld.FComposition.FNodes) do
  begin
    LChildren := LChildren or (FWorld.FComposition.FNodes[I].FParentId = FSelected);
  end;
  Enable('module-closer', LReady and (LAt >= 0) and LChildren);
  Element('module-edge-controls').hidden := not ModuleIsEdge(LToken);
  Enable('module-up', LReady and (FSelected <> FRoot));
  Enable('module-count-apply', LReady and not Protected(FSelected));
  Enable('module-contents-imagine', LReady and not Protected(FSelected));
  Element('module-lock').textContent := 'Lock this part';
  if (LAt >= 0) and FWorld.FComposition.FNodes[LAt].FLocked then
  begin
    Element('module-lock').textContent := 'Unlock this part';
  end;
  Element('module-toggle').textContent := 'Open door';
  if Pos('door.open.', LToken) = 1 then
  begin
    Element('module-toggle').textContent := 'Close door';
  end;
  Element('module-choice').textContent := 'Draw land to create a home, or choose an existing home.';
  if FSelected <> '' then
  begin
    Element('module-choice').textContent := StringReplace(LToken, '.', ' · ', [rfReplaceAll]);
    if LToken = '' then
    begin
      if FSelected = FRoot then
      begin
        Element('module-choice').textContent := 'Home selected · paint adjoining land to extend it.';
      end
      else if LAt >= 0 then
      begin
        Element('module-choice').textContent := String(FWorld.FComposition.FNodes[LAt].FName);
      end;
    end;
  end;
  Enable('module-undo', not TJSHTMLButtonElement(Element('undo')).disabled);
  Enable('module-redo', not TJSHTMLButtonElement(Element('redo')).disabled);
  if FActive and FPicking and LReady then
  begin
    Element('interaction-hint').textContent := 'Tap a part to choose it · drag to look';
  end;
end;

function TBuildingUI.Snapshot: TJSObject;
begin
  Result := TJSObject.new;
  Result['active'] := FActive;
  Result['picking'] := FPicking;
  Result['cutaway'] := FCutaway;
  Result['root'] := FRoot;
  Result['selected'] := FSelected;
end;

procedure TBuildingUI.RestoreCheckpoint(const AValue: TJSObject);
begin
  if AValue = nil then
  begin
    Exit;
  end;
  FActive := AValue['active'] = True;
  FPicking := AValue['picking'] = True;
  FCutaway := AValue['cutaway'] = True;
  FRoot := String(AValue['root']);
  FSelected := String(AValue['selected']);
  if FActive and FPicking then
  begin
    SelectParts;
  end;
  RenderLists;
  Refresh;
end;

procedure StartBuildingUI;
begin
  GBuildingUI := TBuildingUI.Create;
end;

end.
