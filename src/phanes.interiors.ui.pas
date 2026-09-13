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
unit phanes.interiors.ui;
{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartInteriorUI;
procedure OpenSupportedInterior(const ABuildingId: String);

implementation

uses
  JS,
  Web,
  WebOrWorker,
  SysUtils,
  Classes,
  Types,
  Math,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire,
  phanes.composition.contents.types,
  phanes.interiors.catalog,
  phanes.catalog.furniture,
  phanes.interiors.profiles,
  phanes.spaces.programs;

type
  TSpaceDialog = class external name 'HTMLDialogElement'(TJSHTMLElement)
    procedure showModal;
    procedure close;
  end;

  TEditorState = class external name 'Object'(TJSObject)
    world: TJSObject;
    worker: TJSObject;
    selection: TJSObject;
    history: TJSArray;
    future: TJSArray;
    interiorRoom: String;
    interiorSelected: String;
    camera: String;
    editing: Boolean;
    panX: Double;
    panY: Double;
    panZ: Double;
    zoom: Double;
    x: Double;
    y: Double;
    z: Double;
    yaw: Double;
    pitch: Double;
  end;

  TEditorActions = class external name 'Object'(TJSObject)
    procedure generate(const AOperation: String; const AImported, AOptions: TJSObject);
    procedure setCamera(const AMode: String);
    procedure syncSelection;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TInteriorUI = class
  private
    FState: TEditorState;
    FActions: TEditorActions;
    FDocument: TCompositionDocument;
    FIndex: TCompositionIndex;
    FAssets: TContentAssets;
    FPreviousCamera: TJSObject;
    FFrameVersion: Integer;
    FFrameTargetId: String;
    FRenderedSelection: String;
    FDirty: Boolean;
    FLayoutBuilding: String;
    FEntryPending: Boolean;
    FEntrySelection: TJSObject;
    FNearbyId: String;
    FDisplayedCount: Integer;
    FChoiceNode: String;
    procedure EntryTick;
    function EnterNearby(AEvent: TJSEvent): Boolean;
    function Selected: Integer;
    function Children(const AId: String): TIntegerDynArray;
    function RoomId: String;
    function SelectedProgramRoom: Integer;
    function ProtectedBy(const AIndex: Integer): Integer;
    function EditProtectedBy(const AIndex: Integer): Integer;
    procedure SendSelection(const AFrame: Boolean = False);
    procedure RenderPath(const AIndex: Integer);
    procedure RenderSelection(const AIndex: Integer);
    procedure RenderChoices(const AIndex: Integer);
    function ChoicesChanged(AEvent: TJSEvent): Boolean;
    procedure RefreshCount;
    function ReadCount(const AOptions: TJSObject; const AOnlyChanged: Boolean = False): Boolean;
    function Click(AEvent: TJSEvent): Boolean;
    function NameKey(AEvent: TJSEvent): Boolean;
    procedure Request(const AOperation: String; const AOptions: TJSObject = nil);
    procedure OpenRoom(const AId: String);
    procedure ShowLayouts;
  public
    constructor Create;
    procedure Refresh;
    procedure OnWorld;
    procedure OpenSelected;
    procedure OpenBuilding(const AId: String);
    procedure Leave;
    function Snapshot: TJSObject;
    procedure CancelEntry;
    procedure RestoreCheckpoint(const AValue: TJSObject);
    procedure Choose(const AId: String; const AFrame: Boolean = False);
    procedure ResetCamera;
    procedure NavigationBlocked;
    procedure Picked(const AId: String; const AVersion: Integer);
    procedure Frame(const AX, AY, AZ, ASize: Double);
    procedure Rendered(const ARoomId: String; const AVersion, ASceneVersion: Integer);
  end;

const
  CActionIds: array[0..20] of String =
    ('open-interior', 'leave-interior', 'interior-parent', 'interior-frame',
    'interior-reimagine', 'interior-undo', 'interior-redo', 'interior-export',
    'content-less', 'content-more', 'apply-content-count',
    'design-rooms', 'interior-layout', 'space-layout-cancel', 'interior-space-rename',
    'space-layout-two', 'space-layout-four', 'space-layout-six',
    'space-program-lab', 'space-program-bath', 'space-program-empty');
  CCountControls: array[0..3] of String =
    ('interior-count', 'content-less', 'content-more', 'apply-content-count');
  CCameraFields: array[0..10] of String =
    ('camera', 'zoom', 'yaw', 'pitch', 'x', 'y', 'z', 'panX', 'panY', 'panZ', 'editing');

var
  GInterior: TInteriorUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

function Input(const AId: String): TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(Element(AId));
end;

procedure Disable(const AId: String; const ADisabled: Boolean);
begin
  TJSHTMLButtonElement(Element(AId)).disabled := ADisabled;
end;

function Pressed(const AValue: Boolean): String;
begin
  if AValue then
  begin
    Exit('true');
  end;
  Result := 'false';
end;

constructor TInteriorUI.Create;
var
  LBridge: TJSObject;
  LId: String;
begin
  inherited Create;
  FState := TEditorState(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  FAssets := InteriorContentAssets;
  FIndex := TCompositionIndex.Create(FDocument.FNodes);
  for LId in CActionIds do
  begin
    Element(LId).addEventListener('click', @Click);
  end;
  Input('interior-space-name').addEventListener('keydown', @NameKey);
  Element('interior-category').addEventListener('change', @ChoicesChanged);
  Element('interior-group').addEventListener('change', @ChoicesChanged);
  Element('interior-search').addEventListener('input', @ChoicesChanged);
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  LBridge['onWorld'] := @OnWorld;
  LBridge['openSelected'] := @OpenSelected;
  LBridge['openBuilding'] := @OpenBuilding;
  LBridge['leave'] := @Leave;
  LBridge['snapshot'] := @Snapshot;
  LBridge['cancelEntry'] := @CancelEntry;
  LBridge['restoreCheckpoint'] := @RestoreCheckpoint;
  LBridge['choose'] := @Choose;
  LBridge['resetCamera'] := @ResetCamera;
  TJSObject(window)['phanesInteriorUI'] := LBridge;
  Element('enter-nearby').addEventListener('click', @EnterNearby);
  window.setInterval(@EntryTick, 200);
  TJSObject(window)['phanesInteriorPicked'] := @Picked;
  TJSObject(window)['phanesInteriorFrame'] := @Frame;
  TJSObject(window)['phanesInteriorRendered'] := @Rendered;
  TJSObject(window)['phanesInteriorNavigationBlocked'] := @NavigationBlocked;
  Refresh;
end;

function TInteriorUI.Selected: Integer;
begin
  Result := FIndex.Find(FState.interiorSelected);
end;

function TInteriorUI.Children(const AId: String): TIntegerDynArray;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FDocument.FNodes) do
  begin
    if FDocument.FNodes[I].FParentId = AId then
    begin
      Result := Result + [I];
    end;
  end;
end;

function TInteriorUI.RoomId: String;
var
  LBuilding: String;
begin
  LBuilding := 'building-' + IntToStr(Integer(FState.selection['x'])) + '-' +
    IntToStr(Integer(FState.selection['z']));
  Result := LBuilding + '.studio';
  if FIndex.Find(LBuilding + '.plan') >= 0 then
  begin
    Result := LBuilding + '.plan';
  end;
end;

function TInteriorUI.SelectedProgramRoom: Integer;
var
  LSelected: Integer;
begin
  Result := -1;
  LSelected := Selected;
  if LSelected < 0 then
  begin
    Exit;
  end;
  if FDocument.FNodes[LSelected].FRole = 'room' then
  begin
    Exit(LSelected);
  end;
  if FDocument.FNodes[LSelected].FRole = 'bay' then
  begin
    Result := FIndex.Find(FDocument.FNodes[LSelected].FId + '.room');
  end;
end;

function TInteriorUI.ProtectedBy(const AIndex: Integer): Integer;
var
  LParent: Integer;
  LSupport: Integer;
begin
  Result := -1;
  if AIndex < 0 then
  begin
    Exit;
  end;
  if FDocument.FNodes[AIndex].FLocked then
  begin
    Exit(AIndex);
  end;
  LParent := FIndex.Find(FDocument.FNodes[AIndex].FParentId);
  LSupport := FIndex.Find(FDocument.FNodes[AIndex].FSupportId);
  Result := ProtectedBy(LParent);
  if (Result < 0) and (LSupport <> LParent) then
  begin
    Result := ProtectedBy(LSupport);
  end;
end;

function TInteriorUI.EditProtectedBy(const AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := ProtectedBy(AIndex);
  if (Result >= 0) or (AIndex < 0) or (FDocument.FNodes[AIndex].FKind <> ckObject) then
  begin
    Exit;
  end;
  for I := 0 to High(FDocument.FNodes) do
  begin
    if FDocument.FNodes[I].FLocked and
      InCompositionScope(FDocument, FIndex, I, FDocument.FNodes[AIndex].FId) then
    begin
      Exit(I);
    end;
  end;
end;

function ContentRoleLabel(const ARole: String): String;
begin
  Result := UpperCase(Copy(ARole, 1, 1)) + Copy(ARole, 2, Length(ARole)) + 's';
  if ARole = 'bread' then
  begin
    Result := 'Bread';
  end
  else if ARole = 'fruit' then
  begin
    Result := 'Fruit';
  end
  else if ARole = 'cheese' then
  begin
    Result := 'Cheese';
  end;
end;

procedure TInteriorUI.Request(const AOperation: String; const AOptions: TJSObject);
var
  LOptions: TJSObject;
begin
  LOptions := AOptions;
  if LOptions = nil then
  begin
    LOptions := TJSObject.new;
  end;
  FActions.generate(AOperation, nil, LOptions);
end;

procedure TInteriorUI.SendSelection(const AFrame: Boolean);
var
  LSettings: TJSObject;
begin
  if AFrame then
  begin
    Inc(FFrameVersion);
    FFrameTargetId := FState.interiorSelected;
  end;
  LSettings := TJSObject.new;
  LSettings['roomId'] := FState.interiorRoom;
  LSettings['selectedId'] := FState.interiorSelected;
  LSettings['frameVersion'] := FFrameVersion;
  { Selection may change before Castle consumes this request. Preserve the
    object chosen by the most recent explicit framing action. }
  LSettings['frameTargetId'] := FFrameTargetId;
  TJSObject(window)['phanesInterior'] := TJSJSON.stringify(LSettings);
  TJSObject(window)['phanesInteriorVersion'] :=
    Integer(TJSObject(window)['phanesInteriorVersion']) + 1;
end;

procedure TInteriorUI.Choose(const AId: String; const AFrame: Boolean);
begin
  if FIndex.Find(AId) < 0 then
  begin
    Exit;
  end;
  FState.interiorSelected := AId;
  SendSelection(AFrame);
  Refresh;
  Element('interior-title').focus;
end;

function TInteriorUI.Snapshot: TJSObject;
begin
  Result := TJSObject.new;
  Result['room'] := FState.interiorRoom;
  Result['selected'] := FState.interiorSelected;
  Result['previousCamera'] := FPreviousCamera;
end;

procedure TInteriorUI.RestoreCheckpoint(const AValue: TJSObject);
begin
  if (AValue = nil) or (String(AValue['room']) = '') then
  begin
    Exit;
  end;
  if (FIndex.Find(String(AValue['room'])) < 0) or
    (FIndex.Find(String(AValue['selected'])) < 0) then
  begin
    raise Exception.Create('The saved interior is no longer present.');
  end;
  FPreviousCamera := TJSObject(AValue['previousCamera']);
  FState.interiorRoom := String(AValue['room']);
  FState.interiorSelected := String(AValue['selected']);
  document.body.setAttribute('data-interior', 'true');
  Element('interior-tools').hidden := False;
  SendSelection;
  Refresh;
end;

procedure TInteriorUI.Leave;
var
  LKey: String;
begin
  FState.interiorRoom := '';
  FState.interiorSelected := '';
  document.body.setAttribute('data-interior', 'false');
  Element('interior-tools').hidden := True;
  if FPreviousCamera <> nil then
  begin
    for LKey in CCameraFields do
    begin
      FState[LKey] := FPreviousCamera[LKey];
    end;
    FPreviousCamera := nil;
  end;
  SendSelection;
  FActions.setCamera(FState.camera);
  Refresh;
  if document.body.getAttribute('data-groundworks') = 'true' then
  begin
    if Element('groundwork-inside').hidden then
    begin
      Element('groundwork-title').focus;
    end
    else
    begin
      Element('groundwork-inside').focus;
    end;
  end
  else
  begin
    Element('open-interior').focus;
  end;
end;

procedure TInteriorUI.NavigationBlocked;
begin
  FActions.setCamera('fly');
  FActions.notify('No clear floor space here. Use Fly or move furniture to make room.', False);
end;

procedure TInteriorUI.ResetCamera;
var
  LRoom: Integer;
  LBuilding: Integer;
  LProfile: TBuildingInterior;
begin
  FState.panX := 0;
  FState.panY := 0.8;
  FState.panZ := 0;
  FState.zoom := 1.2;
  FState.x := 0;
  FState.y := 1.68;
  FState.z := 3.8;
  LRoom := FIndex.Find(FState.interiorRoom);
  if LRoom >= 0 then
  begin
    LBuilding := FIndex.Find(FDocument.FNodes[LRoom].FParentId);
    if (LBuilding >= 0) and BuildingInterior(FDocument.FNodes[LBuilding].FAssetId, LProfile) then
    begin
      FState.z := LProfile.FDepth / 2000 - 0.9;
    end;
  end;
  FState.yaw := -0.4;
  FState.pitch := 0;
  FActions.setCamera('orbit');
end;

procedure TInteriorUI.OpenSelected;
var
  LId: String;
begin
  LId := RoomId;
  if FIndex.Find(LId) < 0 then
  begin
    Request('create-interior');
    Exit;
  end;
  OpenRoom(LId);
end;

procedure TInteriorUI.OpenBuilding(const AId: String);
var
  LOptions: TJSObject;
begin
  if FIndex.Find(AId + '.plan') >= 0 then
  begin
    OpenRoom(AId + '.plan');
    Exit;
  end;
  if FIndex.Find(AId + '.studio') < 0 then
  begin
    LOptions := TJSObject.new;
    LOptions['objectId'] := AId;
    Request('create-interior', LOptions);
    Exit;
  end;
  OpenRoom(AId + '.studio');
end;

procedure TInteriorUI.ShowLayouts;
var
  LRoot: Integer;
  LBuilding: Integer;
  LBlocked: Boolean;
  LButtons: TJSNodeList;
  I: Integer;
begin
  if FState.worker <> nil then
  begin
    Exit;
  end;
  FLayoutBuilding := '';
  LRoot := FIndex.Find(FState.interiorRoom);
  if LRoot < 0 then
  begin
    LRoot := FIndex.Find(RoomId);
  end;
  if LRoot >= 0 then
  begin
    FLayoutBuilding := FDocument.FNodes[LRoot].FParentId;
  end;
  Element('space-layout-description').textContent :=
    'Choose a layout, then shape each bay independently.';
  LBlocked := False;
  LBuilding := FIndex.Find(FLayoutBuilding);
  if LBuilding >= 0 then
  begin
    Element('space-layout-description').textContent :=
      'This replaces the current interior, including its furniture and contents. You can undo the change.';
    LBlocked := ProtectedBy(LBuilding) >= 0;
    for I := 0 to High(FDocument.FNodes) do
    begin
      if FDocument.FNodes[I].FLocked and
        InCompositionScope(FDocument, FIndex, I, FLayoutBuilding) then
      begin
        LBlocked := True;
      end;
    end;
    if LBlocked then
    begin
      Element('space-layout-description').textContent :=
        'This interior contains protected items. Keep its layout to preserve them.';
    end;
  end;
  LButtons := Element('space-layout-dialog').querySelectorAll('[data-plan-profile]');
  for I := 0 to LButtons.length - 1 do
  begin
    TJSHTMLButtonElement(LButtons[I]).disabled := LBlocked;
  end;
  TSpaceDialog(Element('space-layout-dialog')).showModal;
end;

procedure TInteriorUI.OpenRoom(const AId: String);
var
  LKey: String;
begin
  if FState.interiorRoom = '' then
  begin
    FPreviousCamera := TJSObject.new;
    for LKey in CCameraFields do
    begin
      FPreviousCamera[LKey] := FState[LKey];
    end;
  end;
  FState.interiorRoom := AId;
  FState.interiorSelected := AId;
  document.body.setAttribute('data-interior', 'true');
  Element('interior-tools').hidden := False;
  SendSelection;
  ResetCamera;
  if FEntryPending then
  begin
    FState.selection := FEntrySelection;
    FEntrySelection := nil;
    FEntryPending := False;
    TJSObject(window)['phanesEnteringInterior'] := False;
    { Start slightly below the horizon so furniture and the path ahead occupy
      the initial view. Saved poses and exterior return poses stay explicit. }
    FState.pitch := -0.12;
    FState.yaw := 0;
    FActions.setCamera('walk');
  end;
  Refresh;
end;

procedure TInteriorUI.CancelEntry;
begin
  if FEntryPending then
  begin
    FState.selection := FEntrySelection;
    FEntrySelection := nil;
    FEntryPending := False;
    TJSObject(window)['phanesEnteringInterior'] := False;
    FActions.syncSelection;
  end;
end;

procedure TInteriorUI.EntryTick;
var
  LCandidate: TJSObject;
  LVisible: Boolean;
begin
  if FEntryPending and (FState.worker = nil) and
    not Boolean(TJSObject(window)['phanesCatalogLoading']) then
  begin
    CancelEntry;
  end;
  LVisible := (FState.world <> nil) and
    ((FState.camera = 'walk') or (FState.camera = 'fly')) and
    not Boolean(TJSObject(window)['phanesRecovering']);
  FNearbyId := '';
  Element('enter-nearby').textContent := 'Enter house';
  if LVisible and (FState.interiorRoom = '') and
    isString(TJSObject(window)['phanesNearbyInterior']) then
  begin
    LCandidate := TJSObject(TJSJSON.parse(String(TJSObject(window)['phanesNearbyInterior'])));
    FNearbyId := String(LCandidate['id']);
    if isString(LCandidate['label']) then
    begin
      Element('enter-nearby').textContent := String(LCandidate['label']);
    end;
  end;
  Element('enter-nearby').hidden := not LVisible or
    ((FState.interiorRoom = '') and (FNearbyId = ''));
  if FState.interiorRoom <> '' then
  begin
    Element('enter-nearby').textContent := 'Return outside';
  end;
  TJSHTMLButtonElement(Element('enter-nearby')).disabled :=
    (FState.worker <> nil) or FEntryPending;
end;

function TInteriorUI.EnterNearby(AEvent: TJSEvent): Boolean;
var
  LCandidate: TJSObject;
begin
  Result := True;
  EntryTick;
  if Boolean(TJSObject(window)['phanesRecovering']) or (FState.worker <> nil) or
    FEntryPending then
  begin
    Exit;
  end;
  if FState.interiorRoom <> '' then
  begin
    Leave;
    Exit;
  end;
  if FNearbyId = '' then
  begin
    Exit;
  end;
  LCandidate := TJSObject(TJSJSON.parse(String(TJSObject(window)['phanesNearbyInterior'])));
  FEntryPending := True;
  FEntrySelection := FState.selection;
  TJSObject(window)['phanesEnteringInterior'] := True;
  if (FIndex.Find(FNearbyId + '.studio') >= 0) or
    (FIndex.Find(FNearbyId + '.plan') >= 0) or (LCandidate['supported'] = True) then
  begin
    OpenBuilding(FNearbyId);
  end else
  begin
    FState.selection := TJSObject.new;
    FState.selection['x'] := LCandidate['x'];
    FState.selection['z'] := LCandidate['z'];
    FState.selection['width'] := 1;
    FState.selection['depth'] := 1;
    OpenSelected;
  end;
end;

procedure TInteriorUI.OnWorld;
var
  LFormerParent: String;
  LFormerBuilding: String;
  LReplacement: String;
  LRoot: Integer;
  LSelected: Integer;
  LReason: String;
begin
  LFormerBuilding := '';
  LRoot := FIndex.Find(FState.interiorRoom);
  if LRoot >= 0 then
  begin
    LFormerBuilding := FDocument.FNodes[LRoot].FParentId;
  end;
  LSelected := Selected;
  if LSelected >= 0 then
  begin
    LFormerParent := FDocument.FNodes[LSelected].FParentId;
  end;
  if not ReadCompositionJSON(TJSJSON.stringify(FState.world['composition']),
    FDocument, LReason) then
  begin
    raise Exception.Create('The interior document could not be displayed: ' + LReason);
  end;
  FIndex.Free;
  FIndex := TCompositionIndex.Create(FDocument.FNodes);
  FDirty := True;
  if (FState.interiorRoom <> '') and (FIndex.Find(FState.interiorRoom) < 0) then
  begin
    LReplacement := LFormerBuilding + '.studio';
    if FIndex.Find(LReplacement) < 0 then
    begin
      LReplacement := LFormerBuilding + '.plan';
    end;
    if (LFormerBuilding <> '') and (FIndex.Find(LReplacement) >= 0) then
    begin
      { Undoing an interior-layout replacement should keep the player inside
        the same cabin, with their original return-to-world camera retained. }
      OpenRoom(LReplacement);
    end
    else
    begin
      Leave;
    end;
  end
  else if (FState.interiorRoom <> '') and (Selected < 0) then
  begin
    if FIndex.Find(LFormerParent) >= 0 then
    begin
      FState.interiorSelected := LFormerParent;
    end
    else
    begin
      FState.interiorSelected := FState.interiorRoom;
    end;
  end;
  if FState.interiorRoom <> '' then
  begin
    SendSelection;
  end;
  Refresh;
end;

procedure TInteriorUI.RenderPath(const AIndex: Integer);
var
  LPath: TIntegerDynArray;
  LCurrent: Integer;
  LButton: TJSHTMLElement;
  I: Integer;
begin
  LCurrent := AIndex;
  LPath := nil;
  while LCurrent >= 0 do
  begin
    LPath := [LCurrent] + LPath;
    if FDocument.FNodes[LCurrent].FId = FState.interiorRoom then
    begin
      Break;
    end;
    LCurrent := FIndex.Find(FDocument.FNodes[LCurrent].FParentId);
  end;
  Element('interior-path').textContent := '';
  for I := 0 to High(LPath) do
  begin
    LCurrent := LPath[I];
    LButton := TJSHTMLElement(document.createElement('button'));
    LButton.textContent := String(FDocument.FNodes[LCurrent].FName);
    LButton.title := LButton.textContent;
    LButton.setAttribute('data-node', FDocument.FNodes[LCurrent].FId);
    if LCurrent = AIndex then
    begin
      LButton.setAttribute('aria-current', 'location');
    end;
    LButton.addEventListener('click', @Click);
    Element('interior-path').appendChild(LButton);
  end;
end;

procedure TInteriorUI.RefreshCount;
var
  LNode: Integer;
  LCount: Integer;
  LOther: Integer;
  LCapacity: Integer;
  LRole: String;
  LPlural: String;
  LButtons: TJSNodeList;
  LButton: TJSHTMLElement;
  I: Integer;
begin
  LNode := Selected;
  if (LNode < 0) or (FDocument.FNodes[LNode].FKind <> ckSurface) then
  begin
    Exit;
  end;
  LRole := Input('interior-role').value;
  LCount := 0;
  LOther := 0;
  for I in Children(FDocument.FNodes[LNode].FId) do
  begin
    if FDocument.FNodes[I].FRole = LRole then
    begin
      Inc(LCount);
    end
    else
    begin
      Inc(LOther);
    end;
  end;
  LCapacity := 4 - LOther;
  if FDocument.FNodes[LNode].FRole = 'bench-top' then
  begin
    LCapacity := 6 - LOther;
  end;
  if FDocument.FNodes[LNode].FRole = 'tabletop' then
  begin
    LCapacity := 2;
  end;
  if FDocument.FNodes[LNode].FRole = 'plate-well' then
  begin
    LCapacity := 1;
  end;
  Input('interior-count').max := IntToStr(LCapacity);
  Input('interior-count').value := IntToStr(LCount);
  FDisplayedCount := LCount;
  LPlural := LowerCase(ContentRoleLabel(LRole));
  if FDocument.FNodes[LNode].FRole = 'plate-well' then
  begin
    LPlural := 'portion of ' + LPlural;
  end;
  Element('interior-capacity').textContent := 'Room for up to ' + IntToStr(LCapacity) +
    ' ' + LPlural + '. Set 0 to remove them. Other contents stay as they are.';
  LButtons := Element('interior-roles').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLElement(LButtons[I]);
    LButton.setAttribute('aria-pressed', Pressed(LButton.getAttribute('data-role') = LRole));
  end;
end;

function TInteriorUI.ReadCount(const AOptions: TJSObject; const AOnlyChanged: Boolean): Boolean;
var
  LCount: Integer;
begin
  Result := TryStrToInt(Input('interior-count').value, LCount);
  if not Result or (LCount < 0) or
    (LCount > StrToIntDef(Input('interior-count').max, 0)) then
  begin
    FActions.notify('Choose a whole number within this surface capacity.', True);
    Exit(False);
  end;
  if not AOnlyChanged or (LCount <> FDisplayedCount) then
  begin
    AOptions['contentRole'] := Input('interior-role').value;
    AOptions['contentCount'] := LCount;
  end;
end;

function TInteriorUI.ChoicesChanged(AEvent: TJSEvent): Boolean;
var
  LNode: Integer;
begin
  Result := True;
  if TJSHTMLElement(AEvent.currentTarget).id = 'interior-category' then
  begin
    TJSHTMLSelectElement(Element('interior-group')).value := '';
  end;
  LNode := Selected;
  if LNode >= 0 then
  begin
    RenderChoices(LNode);
    Refresh;
  end;
end;

procedure TInteriorUI.RenderChoices(const AIndex: Integer);
var
  LNode: TCompositionNode;
  LSupport: Integer;
  LCategories: TStringList;
  LGroups: TStringList;
  LCategory: String;
  LGroup: String;
  LCategoryFilter: String;
  LGroupFilter: String;
  LSearch: String;
  LButton: TJSHTMLElement;
  LCount: Integer;
  I: Integer;

  function Allowed(const AAsset: TContentAsset): Boolean;
  begin
    Result := AAsset.FRole = LNode.FRole;
    if (LSupport >= 0) and ((FDocument.FNodes[LSupport].FRole = 'shelf-tier') or
      (FDocument.FNodes[LSupport].FRole = 'bench-top')) then
    begin
      Result := (AAsset.FRole = 'book') or (AAsset.FRole = 'ornament');
    end;
  end;

  procedure Options(const AId, ALabel: String; const AValues: TStringList;
    var AValue: String);
  var
    LSelect: TJSHTMLSelectElement;
    LOption: TJSHTMLOptionElement;
    J: Integer;
  begin
    LSelect := TJSHTMLSelectElement(Element(AId));
    LSelect.textContent := '';
    LOption := TJSHTMLOptionElement(document.createElement('option'));
    LOption.value := '';
    LOption.textContent := ALabel;
    LSelect.appendChild(LOption);
    for J := 0 to AValues.Count - 1 do
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := AValues[J];
      LOption.textContent := AValues[J];
      LSelect.appendChild(LOption);
    end;
    if AValues.IndexOf(AValue) < 0 then
    begin
      AValue := '';
    end;
    LSelect.value := AValue;
  end;

begin
  LNode := FDocument.FNodes[AIndex];
  Element('interior-looks').textContent := '';
  Element('interior-catalog').hidden := (LNode.FKind <> ckObject) or
    (LNode.FSupportId = '');
  if Element('interior-catalog').hidden then
  begin
    Exit;
  end;
  if FChoiceNode <> LNode.FId then
  begin
    FChoiceNode := LNode.FId;
    TJSHTMLSelectElement(Element('interior-category')).value := '';
    TJSHTMLSelectElement(Element('interior-group')).value := '';
    Input('interior-search').value := '';
  end;
  LSupport := FIndex.Find(LNode.FSupportId);
  LCategoryFilter := TJSHTMLSelectElement(Element('interior-category')).value;
  LGroupFilter := TJSHTMLSelectElement(Element('interior-group')).value;
  LSearch := LowerCase(Trim(Input('interior-search').value));
  LCategories := TStringList.Create;
  LGroups := TStringList.Create;
  try
    for I := 0 to High(FAssets) do
    begin
      if Allowed(FAssets[I]) then
      begin
        InteriorContentGroup(FAssets[I].FId, LCategory, LGroup);
        if LCategories.IndexOf(LCategory) < 0 then
        begin
          LCategories.Add(LCategory);
        end;
      end;
    end;
    Options('interior-category', 'All compatible categories', LCategories, LCategoryFilter);
    for I := 0 to High(FAssets) do
    begin
      if Allowed(FAssets[I]) then
      begin
        InteriorContentGroup(FAssets[I].FId, LCategory, LGroup);
        if ((LCategoryFilter = '') or (LCategoryFilter = LCategory)) and
          (LGroups.IndexOf(LGroup) < 0) then
        begin
          LGroups.Add(LGroup);
        end;
      end;
    end;
    Options('interior-group', 'All groups', LGroups, LGroupFilter);
    LCount := 0;
    for I := 0 to High(FAssets) do
    begin
      if not Allowed(FAssets[I]) then
      begin
        Continue;
      end;
      InteriorContentGroup(FAssets[I].FId, LCategory, LGroup);
      if ((LCategoryFilter <> '') and (LCategoryFilter <> LCategory)) or
        ((LGroupFilter <> '') and (LGroupFilter <> LGroup)) or
        ((LSearch <> '') and (Pos(LSearch, LowerCase(String(FAssets[I].FName) +
        ' ' + LCategory + ' ' + LGroup)) = 0)) then
      begin
        Continue;
      end;
      LButton := TJSHTMLElement(document.createElement('button'));
      LButton.textContent := String(FAssets[I].FName);
      LButton.setAttribute('data-asset', FAssets[I].FId);
      LButton.setAttribute('aria-pressed', Pressed(FAssets[I].FId = LNode.FAssetId));
      LButton.addEventListener('click', @Click);
      Element('interior-looks').appendChild(LButton);
      Inc(LCount);
    end;
    if LCount = 0 then
    begin
      Element('interior-choice-count').textContent := 'No matches. Try another name or group.';
    end else
    begin
      Element('interior-choice-count').textContent := 'Matching choices: ' +
        IntToStr(LCount) + '. Selecting one replaces only this object.';
    end;
  finally
    LGroups.Free;
    LCategories.Free;
  end;
end;

procedure TInteriorUI.RenderSelection(const AIndex: Integer);
var
  LFurniture: TFurnitureProfile;
  LParent: Integer;
  LNode: TCompositionNode;
  LContents: TIntegerDynArray;
  LRoles: TContentNames;
  LRole: String;
  LButton: TJSHTMLElement;
  LLabel: TJSHTMLElement;
  LDetail: TJSHTMLElement;
  LCount: Integer;
  LProtectedBy: Integer;
  I: Integer;
  J: Integer;
begin
  LNode := FDocument.FNodes[AIndex];
  RenderPath(AIndex);
  Element('interior-title').textContent := String(LNode.FName);
  Element('interior-layout').hidden := (LNode.FId <> FState.interiorRoom) or
    (LNode.FAssetId = 'phanes.room.house-studio.v1');
  Element('interior-space-name-tools').removeAttribute('open');
  Element('interior-space-name-tools').hidden := not
    ((LNode.FRole = 'bay') or (LNode.FRole = 'room') or (LNode.FRole = 'floor-plan'));
  if not Element('interior-space-name-tools').hidden then
  begin
    Input('interior-space-name').value := String(LNode.FName);
  end;
  Element('interior-space-programs').hidden := SelectedProgramRoom < 0;
  LContents := Children(LNode.FId);
  if LNode.FKind = ckSurface then
  begin
    Element('interior-description').textContent := IntToStr(Length(LContents)) +
      ' individual items · choose a count or open an item.';
  end
  else if (LNode.FKind = ckObject) and (LNode.FSupportId <> '') then
  begin
    Element('interior-description').textContent :=
      'One object. Its neighbours stay where you placed them.';
    if Length(LContents) > 0 then
    begin
      Element('interior-description').textContent :=
        'Open its surface to shape the contents. Changing this object keeps what it supports.';
    end;
  end
  else if LNode.FRole = 'bookcase' then
  begin
    Element('interior-description').textContent := 'Four real shelf tiers. Open one to shape its contents.';
  end
  else if (LNode.FRole = 'room') or (LNode.FRole = 'bay') then
  begin
    Element('interior-description').textContent :=
      FormatFloat('0.0', LNode.FWidth / 1000) + ' × ' +
      FormatFloat('0.0', LNode.FDepth / 1000) +
      ' metres. Choose a purpose or open something inside.';
  end
  else if LNode.FRole = 'floor-plan' then
  begin
    Element('interior-description').textContent :=
      'Pick a bay in the view or below. Give it a purpose, then shape the details.';
  end
  else
  begin
    Element('interior-description').textContent :=
      'Choose something here, or tap it in the room. Look closer to inspect the details.';
  end;
  LProtectedBy := EditProtectedBy(AIndex);
  if LProtectedBy >= 0 then
  begin
    Element('interior-description').textContent := 'Protected by ' +
      String(FDocument.FNodes[LProtectedBy].FName) + '. Its arrangement stays as saved.';
  end;
  Element('interior-children').textContent := '';
  if (LNode.FRole = 'plate') and (Length(LContents) = 0) then
  begin
    { Older saves may contain a leaf plate. Make its optional food support
      discoverable without requiring an appearance change or import migration. }
    LButton := TJSHTMLElement(document.createElement('button'));
    LButton.id := 'interior-prepare-plate';
    LButton.textContent := 'Prepare this plate for food';
    LButton.addEventListener('click', @Click);
    Element('interior-children').appendChild(LButton);
  end;
  for I := 0 to High(LContents) do
  begin
    J := LContents[I];
    LButton := TJSHTMLElement(document.createElement('button'));
    LButton.setAttribute('data-node', FDocument.FNodes[J].FId);
    LLabel := TJSHTMLElement(document.createElement('span'));
    LLabel.textContent := String(FDocument.FNodes[J].FName);
    LDetail := TJSHTMLElement(document.createElement('small'));
    LCount := Length(Children(FDocument.FNodes[J].FId));
    if LCount > 0 then
    begin
      LDetail.textContent := IntToStr(LCount) + ' inside';
    end
    else
    begin
      LDetail.textContent := FDocument.FNodes[J].FRole;
    end;
    LButton.appendChild(LLabel);
    LButton.appendChild(LDetail);
    LButton.addEventListener('click', @Click);
    Element('interior-children').appendChild(LButton);
  end;
  Element('interior-count-tools').hidden := LNode.FKind <> ckSurface;
  if LNode.FKind = ckSurface then
  begin
    LRoles := ['book', 'ornament'];
    if LNode.FRole = 'tabletop' then
    begin
      LRoles := ['plate', 'fork'];
      LParent := FIndex.Find(LNode.FParentId);
      if (LParent >= 0) and FurnitureProfile(FDocument.FNodes[LParent].FAssetId,
        LFurniture) then
      begin
        LRoles := LFurniture.FFloor.FContent.FSupports[0].FAllowedRoles;
      end;
    end;
    if LNode.FRole = 'plate-well' then
    begin
      LRoles := ['bread', 'fruit', 'cheese'];
    end;
    LRole := Input('interior-role').value;
    if not ContentRoleAllowed(LRoles, LRole) then
    begin
      Input('interior-role').value := LRoles[0];
    end;
    Element('interior-roles').textContent := '';
    for I := 0 to High(LRoles) do
    begin
      LButton := TJSHTMLElement(document.createElement('button'));
      LButton.setAttribute('data-role', LRoles[I]);
      LButton.textContent := ContentRoleLabel(LRoles[I]);
      LButton.addEventListener('click', @Click);
      Element('interior-roles').appendChild(LButton);
    end;
    RefreshCount;
  end;
  RenderChoices(AIndex);
end;

procedure TInteriorUI.Refresh;
var
  LBusy: Boolean;
  LSingleCabin: Boolean;
  LSingleHouse: Boolean;
  LProfile: TBuildingInterior;
  LLocked: Boolean;
  LEditable: Boolean;
  LNode: Integer;
  LRoom: Integer;
  LReplaceLocked: Boolean;
  LCount: Integer;
  LButtons: TJSNodeList;
  LButton: TJSHTMLButtonElement;
  LArray: TJSArray;
  LId: String;
  I: Integer;
begin
  LBusy := FState.worker <> nil;
  LSingleCabin := False;
  LSingleHouse := False;
  if (FState.world <> nil) and (Integer(FState.selection['width']) = 1) and
    (Integer(FState.selection['depth']) = 1) then
  begin
    LArray := TJSArray(TJSArray(FState.world['layers'])[3]);
    LSingleHouse := BuildingInterior(String(LArray[Integer(FState.selection['z']) *
      Integer(FState.world['size']) + Integer(FState.selection['x'])]), LProfile);
    LSingleCabin := LSingleHouse and LProfile.FHasRoomPlans;
  end;
  Disable('open-interior', not LSingleHouse or LBusy);
  Disable('design-rooms', not LSingleCabin or LBusy);
  if FIndex.Find(RoomId) >= 0 then
  begin
    Element('open-interior').textContent := 'Open interior';
  end
  else
  begin
    Element('open-interior').textContent := 'Furnish interior';
  end;
  if LSingleCabin then
  begin
    Element('interior-entry-hint').textContent :=
      'Furnish a studio or design separate rooms, down to each shelf and object.';
  end
  else if LSingleHouse then
  begin
    Element('interior-entry-hint').textContent :=
      'Create a furnished room, then shape its shelves and objects. Enter from nearby to explore.';
  end
  else
  begin
    Element('interior-entry-hint').textContent := 'Select one house or cabin to furnish its interior.';
  end;
  if FState.interiorRoom = '' then
  begin
    Exit;
  end;
  LNode := Selected;
  if LNode < 0 then
  begin
    Exit;
  end;
  if FDirty or (FRenderedSelection <> FState.interiorSelected) then
  begin
    FDirty := False;
    FRenderedSelection := FState.interiorSelected;
    RenderSelection(LNode);
  end;
  LCount := 0;
  for I := 0 to High(FAssets) do
  begin
    if FAssets[I].FRole = FDocument.FNodes[LNode].FRole then
    begin
      Inc(LCount);
    end;
  end;
  LEditable := (FDocument.FNodes[LNode].FKind = ckSurface) or
    ((FDocument.FNodes[LNode].FKind = ckObject) and
    (FDocument.FNodes[LNode].FSupportId <> '') and (LCount > 1));
  LLocked := EditProtectedBy(LNode) >= 0;
  LRoom := SelectedProgramRoom;
  LReplaceLocked := LLocked;
  Element('interior-reimagine').textContent := 'Reimagine';
  if LRoom >= 0 then
  begin
    LLocked := ProtectedBy(LRoom) >= 0;
    LEditable := FDocument.FNodes[LRoom].FAssetId <> EmptyRoomProgram;
    Element('interior-reimagine').textContent := 'Reimagine this room';
    LReplaceLocked := LLocked;
    for I := 0 to High(FDocument.FNodes) do
    begin
      if FDocument.FNodes[I].FLocked and
        InCompositionScope(FDocument, FIndex, I, FDocument.FNodes[LRoom].FId) then
      begin
        LReplaceLocked := True;
      end;
    end;
  end;
  LButtons := Element('interior-space-programs').querySelectorAll('[data-room-program]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLButtonElement(LButtons[I]);
    LButton.setAttribute('aria-pressed', 'false');
    LButton.disabled := LBusy or LReplaceLocked or (LRoom < 0);
    if LRoom >= 0 then
    begin
      LButton.setAttribute('aria-pressed', Pressed(
        LButton.getAttribute('data-room-program') = FDocument.FNodes[LRoom].FAssetId));
      LButton.disabled := LButton.disabled or (LButton.getAttribute('aria-pressed') = 'true');
    end;
  end;
  Disable('interior-layout', LBusy);
  Disable('interior-space-rename', LBusy or (ProtectedBy(LNode) >= 0));
  Input('interior-space-name').disabled := LBusy or (ProtectedBy(LNode) >= 0);
  if Element('interior-prepare-plate') <> nil then
  begin
    Disable('interior-prepare-plate', LBusy or LLocked);
  end;
  Disable('interior-reimagine', LBusy or not LEditable or LLocked);
  Disable('interior-parent', LBusy or (FState.interiorSelected = FState.interiorRoom));
  Disable('interior-frame', LBusy);
  Disable('leave-interior', LBusy);
  Disable('interior-undo', LBusy or (FState.history.length = 0));
  Disable('interior-redo', LBusy or (FState.future.length = 0));
  Disable('interior-export', LBusy);
  LButtons := Element('interior-looks').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLButtonElement(LButtons[I]);
    LButton.disabled := LBusy or LLocked or
      (LButton.getAttribute('data-asset') = FDocument.FNodes[LNode].FAssetId);
  end;
  LButtons := Element('interior-roles').querySelectorAll('button');
  for I := 0 to LButtons.length - 1 do
  begin
    TJSHTMLButtonElement(LButtons[I]).disabled := LBusy or LLocked;
  end;
  for LId in CCountControls do
  begin
    Disable(LId, LBusy or LLocked);
  end;
end;

function TInteriorUI.NameKey(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if TJSKeyboardEvent(AEvent).key = 'Enter' then
  begin
    AEvent.preventDefault;
    Element('interior-space-rename').click;
  end;
end;

function TInteriorUI.Click(AEvent: TJSEvent): Boolean;
var
  LButton: TJSHTMLElement;
  LOptions: TJSObject;
  LNode: Integer;
  LId: String;
begin
  Result := True;
  LButton := TJSHTMLElement(AEvent.currentTarget);
  LId := LButton.id;
  if LButton.hasAttribute('data-node') then
  begin
    Choose(LButton.getAttribute('data-node'));
    Exit;
  end;
  if LButton.hasAttribute('data-role') then
  begin
    Input('interior-role').value := LButton.getAttribute('data-role');
    RefreshCount;
    Exit;
  end;
  LOptions := TJSObject.new;
  LOptions['objectId'] := FState.interiorSelected;
  if LButton.hasAttribute('data-plan-profile') then
  begin
    LOptions['objectId'] := FLayoutBuilding;
    LOptions['planProfile'] := LButton.getAttribute('data-plan-profile');
    TSpaceDialog(Element('space-layout-dialog')).close;
    Request('create-plan', LOptions);
    Exit;
  end;
  if LButton.hasAttribute('data-room-program') then
  begin
    LNode := SelectedProgramRoom;
    if LNode >= 0 then
    begin
      LOptions['objectId'] := FDocument.FNodes[LNode].FId;
      LOptions['roomProgram'] := LButton.getAttribute('data-room-program');
      Request('room-purpose', LOptions);
    end;
    Exit;
  end;
  if LButton.hasAttribute('data-asset') then
  begin
    LOptions['contentAsset'] := LButton.getAttribute('data-asset');
    Request('contents', LOptions);
    Exit;
  end;
  case LId of
    'design-rooms', 'interior-layout':
    begin
      ShowLayouts;
    end;
    'space-layout-cancel':
    begin
      TSpaceDialog(Element('space-layout-dialog')).close;
    end;
    'interior-space-rename':
    begin
      LOptions['spaceName'] := Input('interior-space-name').value;
      Request('rename-space', LOptions);
    end;
    'open-interior':
    begin
      OpenSelected;
    end;
    'leave-interior':
    begin
      Leave;
    end;
    'interior-parent':
    begin
      LNode := Selected;
      if LNode >= 0 then
      begin
        Choose(FDocument.FNodes[LNode].FParentId);
      end;
    end;
    'interior-frame':
    begin
      SendSelection(True);
    end;
    'interior-reimagine':
    begin
      LNode := SelectedProgramRoom;
      if LNode >= 0 then
      begin
        LOptions['objectId'] := FDocument.FNodes[LNode].FId;
        Request('room-reimagine', LOptions);
      end
      else
      begin
        LNode := Selected;
        { The prominent Reimagine action must honor the count the player has
          just entered, including zero. Both surface actions use one contract. }
        if (LNode >= 0) and (FDocument.FNodes[LNode].FKind = ckSurface) and
          not ReadCount(LOptions, True) then
        begin
          Exit;
        end;
        Request('contents', LOptions);
      end;
    end;
    'interior-prepare-plate':
    begin
      LNode := Selected;
      if (LNode >= 0) and (FDocument.FNodes[LNode].FRole = 'plate') then
      begin
        LOptions['contentAsset'] := FDocument.FNodes[LNode].FAssetId;
        Request('contents', LOptions);
      end;
    end;
    'interior-undo':
    begin
      Element('undo').click;
    end;
    'interior-redo':
    begin
      Element('redo').click;
    end;
    'interior-export':
    begin
      Element('save-world').click;
    end;
    'content-less':
    begin
      Input('interior-count').value := IntToStr(Max(0,
        StrToIntDef(Input('interior-count').value, 0) - 1));
    end;
    'content-more':
    begin
      Input('interior-count').value := IntToStr(Min(StrToInt(Input('interior-count').max),
        StrToIntDef(Input('interior-count').value, 0) + 1));
    end;
    'apply-content-count':
    begin
      if not ReadCount(LOptions) then
      begin
        Exit;
      end;
      Request('contents', LOptions);
    end;
  end;
end;

procedure TInteriorUI.Picked(const AId: String; const AVersion: Integer);
begin
  if (AVersion = Integer(TJSObject(window)['phanesPickVersion'])) and
    (String(TJSObject(window)['phanesPickAction']) = 'end') and
    (Integer(TJSObject(window)['phanesPickSceneVersion']) =
      Integer(TJSObject(window)['phanesSceneVersion'])) and
    (Integer(TJSObject(window)['phanesPickCameraVersion']) =
      Integer(TJSObject(window)['phanesCameraVersion'])) and
    (FState.worker = nil) and (FState.interiorRoom <> '') and
    FState.editing and (AId <> '') then
  begin
    Choose(AId);
  end;
end;

procedure TInteriorUI.Frame(const AX, AY, AZ, ASize: Double);
var
  LNode: Integer;
  LFacing: Integer;
  LTurn: Integer;
  LRole: String;
begin
  if FState.interiorRoom = '' then
  begin
    Exit;
  end;
  FState.panX := AX;
  FState.panY := AY;
  FState.panZ := AZ;
  FState.zoom := Max(0.4, Min(64, 11 / (ASize * 1.8)));
  LNode := FIndex.Find(FFrameTargetId);
  if LNode < 0 then
  begin
    LNode := Selected;
  end;
  if LNode >= 0 then
  begin
    LRole := FDocument.FNodes[LNode].FRole;
    LFacing := LNode;
    if FDocument.FNodes[LNode].FSupportId <> '' then
    begin
      LFacing := FIndex.Find(FDocument.FNodes[LNode].FSupportId);
    end;
    LTurn := 0;
    while (LFacing >= 0) and (FDocument.FNodes[LFacing].FId <> FState.interiorRoom) do
    begin
      LTurn := (LTurn + FDocument.FNodes[LFacing].FQuarterTurn) mod 4;
      LFacing := FIndex.Find(FDocument.FNodes[LFacing].FParentId);
    end;
    if ASize < 1 then
    begin
      { Face the support in plan coordinates, including bay and furniture turns.
        A prop's own decorative rotation must not aim the eye through a post. }
      FState.yaw := LTurn * Pi / 2;
      FState.pitch := -0.37;
    end;
    if LRole = 'bookcase' then
    begin
      FState.yaw := LTurn * Pi / 2;
      FState.pitch := -0.1;
    end;
    if FDocument.FNodes[LNode].FKind = ckContainer then
    begin
      FState.yaw := -0.4;
      FState.pitch := 0.15;
    end;
    if (LRole = 'plate') or (LRole = 'plate-well') or (LRole = 'bread') or
      (LRole = 'fruit') or (LRole = 'cheese') or (LRole = 'tabletop') or
      (LRole = 'bench-top') then
    begin
      FState.yaw := LTurn * Pi / 2 + 0.35;
      { Orbit's elevation is 0.65 + pitch; use a view from above the food. }
      FState.pitch := 0.40;
    end;
  end;
  FActions.setCamera('orbit');
end;

procedure TInteriorUI.Rendered(const ARoomId: String;
  const AVersion, ASceneVersion: Integer);
begin
  document.body.setAttribute('data-rendered-interior', ARoomId);
  document.body.setAttribute('data-rendered-interior-version', IntToStr(AVersion));
  document.body.setAttribute('data-rendered-interior-scene', IntToStr(ASceneVersion));
end;

procedure StartInteriorUI;
begin
  GInterior := TInteriorUI.Create;
end;

procedure OpenSupportedInterior(const ABuildingId: String);
begin
  GInterior.OpenBuilding(ABuildingId);
end;

end.
