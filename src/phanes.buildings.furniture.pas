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

unit phanes.buildings.furniture;

{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types, phanes.composition.contents.types, phanes.buildings.types;

function BuildingFurnitureAssets: TContentAssets;
function BuildingFloorRequest(const ADocument: TCompositionDocument; const AId: String;
  out ARequest: TContentRequest; out AReason: String; const AExtraAsset: String = ''): Boolean;
function ValidateBuildingFurniture(const ADocument: TCompositionDocument;
  var ABuilding: TModularBuilding; out AReason: String): Boolean;
function FurnitureBlocks(const ANode: TCompositionNode; const AX, AZ, ARadius: Double): Boolean;
function FloorHasContents(const ADocument: TCompositionDocument; const AId: String): Boolean;

implementation

uses
  Math, SysUtils, phanes.composition.document, phanes.composition.contents.validate,
  phanes.composition.contents.assembly, phanes.interiors.catalog,
  phanes.interiors.surfaces, phanes.spaces.programs, phanes.buildings.geometry;

function BuildingFurnitureAssets: TContentAssets;
const
  CIds: array[0..3] of String = ('phanes.table.oak.v1', 'phanes.chair.sage.v1',
    'phanes.plant.fern.v1', 'phanes.plant.moon.v1');
var
  LAt: Integer;
  I: Integer;
begin
  Result := RoomAssemblyAssets;
  LAt := Length(Result);
  SetLength(Result, LAt + Length(CIds));
  for I := 0 to High(CIds) do
  begin
    InteriorAssemblyAsset(CIds[I], Result[LAt + I]);
  end;
end;

function FloorHasContents(const ADocument: TCompositionDocument; const AId: String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ADocument.FNodes) do
  begin
    if ADocument.FNodes[I].FParentId = AId then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function BuildingFloorRequest(const ADocument: TCompositionDocument; const AId: String;
  out ARequest: TContentRequest; out AReason: String; const AExtraAsset: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAt: Integer;
  LObject: Integer;
  LAsset: TInteriorAsset;
  LSlot: TContentSlot;
  LSlots: TContentSlots;
  I: Integer;

  procedure AddBatchAsset(const AAssetId: String);
  var
    LAsset: TInteriorAsset;
    LCount: Integer;
    J: Integer;
  begin
    if (Pos('phanes.catalog.batch.', AAssetId) <> 1) or
      not InteriorAsset(AAssetId, LAsset) then
    begin
      Exit;
    end;
    for J := 0 to High(ARequest.FAssets) do
    begin
      if ARequest.FAssets[J].FId = AAssetId then
      begin
        Exit;
      end;
    end;
    LCount := Length(ARequest.FAssets);
    SetLength(ARequest.FAssets, LCount + 1);
    ARequest.FAssets[LCount].FId := AAssetId;
    ARequest.FAssets[LCount].FName := LAsset.FName;
    ARequest.FAssets[LCount].FRole := LAsset.FRole;
    ARequest.FAssets[LCount].FWidth := LAsset.FWidth;
    ARequest.FAssets[LCount].FDepth := LAsset.FDepth;
    ARequest.FAssets[LCount].FHeight := LAsset.FHeight;
    ARequest.FAssets[LCount].FSingleInstance := True;
  end;
begin
  Result := False;
  ARequest := Default(TContentRequest);
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    AReason := 'Choose a modular floor tile for furniture or plants.';
    LAt := LIndex.Find(AId);
    if (LAt < 0) or not ModuleIsFloor(ModuleToken(ADocument.FNodes[LAt].FAssetId)) then
    begin
      Exit;
    end;
    ARequest.FSurfaceId := AId;
    ARequest.FScopeId := AId;
    ARequest.FExpectedRevision := ADocument.FRevision;
    ARequest.FSurfaceWidth := 2000;
    ARequest.FSurfaceDepth := 2000;
    ARequest.FHeadroom := 2800;
    ARequest.FAssets := BuildingFurnitureAssets;
    { The full browser catalog is not a solver domain. Admit only this choice
      and the floor's existing props, keeping ordinary requests small. }
    AddBatchAsset(AExtraAsset);
    for I := 0 to High(ADocument.FNodes) do
    begin
      if ADocument.FNodes[I].FParentId = AId then
      begin
        AddBatchAsset(ADocument.FNodes[I].FAssetId);
      end;
    end;
    SetLength(ARequest.FSlots, 1);
    ARequest.FSlots[0].FObjectId := AId + '.furnishing';
    ARequest.FSlots[0].FWidth := 2000;
    ARequest.FSlots[0].FDepth := 2000;
    ARequest.FSlots[0].FHeight := 2800;
    ARequest.FSlots[0].FAllowedRoles := ['table', 'bookcase', 'chair', 'bench',
      'plant', 'sink', 'toilet', 'shower', 'console', 'ornament'];
    ARequest.FSlots[0].FAllowEmpty := True;
    LObject := LIndex.Find(ARequest.FSlots[0].FObjectId);
    if LObject >= 0 then
    begin
      if (Abs(ADocument.FNodes[LObject].FX) > 750) or
        (Abs(ADocument.FNodes[LObject].FZ) > 750) or
        (ADocument.FNodes[LObject].FX mod 250 <> 0) or
        (ADocument.FNodes[LObject].FZ mod 250 <> 0) then
      begin
        AReason := 'A furnishing position is outside its admitted floor grid.';
        Exit;
      end;
      ARequest.FSlots[0].FX := ADocument.FNodes[LObject].FX;
      ARequest.FSlots[0].FZ := ADocument.FNodes[LObject].FZ;
      ARequest.FSlots[0].FWidth := 2000 - Abs(ARequest.FSlots[0].FX) * 2;
      ARequest.FSlots[0].FDepth := 2000 - Abs(ARequest.FSlots[0].FZ) * 2;
      ARequest.FSlots[0].FQuarterTurn := ADocument.FNodes[LObject].FQuarterTurn;
    end;
    { Packed props retain individual identities and measured, non-overlapping
      bounds. Reconstruct them from saved nodes; no transient grid is required. }
    LSlots := nil;
    for I := 0 to High(ADocument.FNodes) do
    begin
      if (ADocument.FNodes[I].FParentId <> AId) or
        (ADocument.FNodes[I].FId = AId + '.furnishing') then
      begin
        Continue;
      end;
      if not InteriorAsset(ADocument.FNodes[I].FAssetId, LAsset) then
      begin
        AReason := 'Unadmitted floor contents.';
        Exit;
      end;
      LSlot := ARequest.FSlots[0];
      LSlot.FObjectId := ADocument.FNodes[I].FId;
      LSlot.FX := ADocument.FNodes[I].FX;
      LSlot.FZ := ADocument.FNodes[I].FZ;
      LSlot.FQuarterTurn := ADocument.FNodes[I].FQuarterTurn;
      LSlot.FWidth := LAsset.FWidth;
      LSlot.FDepth := LAsset.FDepth;
      if Odd(LSlot.FQuarterTurn) then
      begin
        LSlot.FWidth := LAsset.FDepth;
        LSlot.FDepth := LAsset.FWidth;
      end;
      SetLength(LSlots, Length(LSlots) + 1);
      LSlots[High(LSlots)] := LSlot;
    end;
    if Length(LSlots) > 0 then
    begin
      if LObject >= 0 then
      begin
        SetLength(LSlots, Length(LSlots) + 1);
        LSlots[High(LSlots)] := ARequest.FSlots[0];
      end;
      ARequest.FSlots := LSlots;
    end;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

function FurnitureBlocks(const ANode: TCompositionNode; const AX, AZ, ARadius: Double): Boolean;
var
  LAsset: TInteriorAsset;
  LHalfX: Double;
  LHalfZ: Double;
  LDX: Double;
  LDZ: Double;
begin
  Result := False;
  if not InteriorAsset(ANode.FAssetId, LAsset) then
  begin
    Exit;
  end;
  LHalfX := LAsset.FWidth / 2000;
  LHalfZ := LAsset.FDepth / 2000;
  if Odd(ANode.FQuarterTurn) then
  begin
    LHalfX := LAsset.FDepth / 2000;
    LHalfZ := LAsset.FWidth / 2000;
  end;
  LDX := Max(0, Abs(AX - ANode.FX / 1000) - LHalfX);
  LDZ := Max(0, Abs(AZ - ANode.FZ / 1000) - LHalfZ);
  Result := Sqr(LDX) + Sqr(LDZ) < Sqr(ARadius);
end;

function ValidateBuildingFurniture(const ADocument: TCompositionDocument;
  var ABuilding: TModularBuilding; out AReason: String): Boolean;
var
  LRequest: TContentRequest;
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LParent: TCompositionNode;
  LAsset: TInteriorAsset;
  LBoxes: TModuleBoxes;
  LBox: TModuleBox;
  LEdge: TBuildingEdge;
  LX: Double;
  LZ: Double;
  LHalfX: Double;
  LHalfZ: Double;
  LAt: Integer;
  LAncestor: Integer;
  LDocuments: array of TCompositionDocument;
  LHasChildren: array of Boolean;
  LFloor: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := False;
  ABuilding.FFurnishings := nil;
  if not ValidateComposition(ADocument, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    SetLength(LDocuments, Length(ADocument.FNodes));
    SetLength(LHasChildren, Length(ADocument.FNodes));
    for I := 0 to High(ADocument.FNodes) do
    begin
      LAt := LIndex.Find(ADocument.FNodes[I].FParentId);
      if LAt >= 0 then
      begin
        LHasChildren[LAt] := True;
      end;
    end;
    for I := 0 to High(ABuilding.FFloorNodes) do
    begin
      LFloor := LIndex.Find(ABuilding.FFloorNodes[I].FId);
      if not LHasChildren[LFloor] then
      begin
        Continue;
      end;
      { Structural admission already checks empty floor modules. Validate each
        populated support with its complete subtree and unchanged ancestors;
        scanning the whole world for every empty tile multiplied admission cost.
        Cross-floor support references remain invalid in this local document. }
      LDocuments[LFloor].FRevision := ADocument.FRevision;
      SetLength(LDocuments[LFloor].FNodes, 3);
      LDocuments[LFloor].FNodes[0] := ADocument.FNodes[LIndex.Find('world')];
      LDocuments[LFloor].FNodes[1] := ABuilding.FRoot;
      LDocuments[LFloor].FNodes[2] := ADocument.FNodes[LFloor];
      for J := 0 to High(ADocument.FNodes) do
      begin
        if (J <> LFloor) and InCompositionScope(ADocument, LIndex, J,
          ABuilding.FFloorNodes[I].FId) then
        begin
          LCount := Length(LDocuments[LFloor].FNodes);
          SetLength(LDocuments[LFloor].FNodes, LCount + 1);
          LDocuments[LFloor].FNodes[LCount] := ADocument.FNodes[J];
        end;
      end;
      if not BuildingFloorRequest(LDocuments[LFloor], ABuilding.FFloorNodes[I].FId,
        LRequest, AReason) or not ValidateContentResult(LDocuments[LFloor], LRequest, AReason) then
      begin
        Exit;
      end;
    end;
    for I := 0 to High(ADocument.FNodes) do
    begin
      LNode := ADocument.FNodes[I];
      if (ModularOwner(ADocument, LIndex, I) <> ABuilding.FRoot.FId) or
        (LNode.FId = ABuilding.FRoot.FId) or (ModuleToken(LNode.FAssetId) <> '') then
      begin
        Continue;
      end;
      LAt := LIndex.Find(LNode.FParentId);
      AReason := 'A furnishing must belong to an admitted floor support.';
      LAncestor := LAt;
      while (LAncestor >= 0) and not ModuleIsFloor(ModuleToken(ADocument.FNodes[LAncestor].FAssetId)) do
      begin
        LAncestor := LIndex.Find(ADocument.FNodes[LAncestor].FParentId);
      end;
      if LAncestor < 0 then
      begin
        Exit;
      end;
      if LNode.FKind = ckSurface then
      begin
        if not SurfaceRequest(LDocuments[LAncestor], LNode.FId, LRequest, AReason) or
          not ValidateContentResult(LDocuments[LAncestor], LRequest, AReason) then
        begin
          Exit;
        end;
      end;
      if not ModuleIsFloor(ModuleToken(ADocument.FNodes[LAt].FAssetId)) then
      begin
        Continue;
      end;
      LParent := ADocument.FNodes[LAt];
      if not InteriorAsset(LNode.FAssetId, LAsset) then
      begin
        Exit;
      end;
      LNode.FX := LNode.FX + LParent.FX;
      LNode.FZ := LNode.FZ + LParent.FZ;
      LHalfX := LAsset.FWidth / 2000;
      LHalfZ := LAsset.FDepth / 2000;
      if Odd(LNode.FQuarterTurn) then
      begin
        LHalfX := LAsset.FDepth / 2000;
        LHalfZ := LAsset.FWidth / 2000;
      end;
      for J := 0 to High(ABuilding.FEdges) do
      begin
        LEdge := ABuilding.FEdges[J];
        if ModuleIsDoor(ModuleToken(LEdge.FNode.FAssetId)) and
          ModuleDoorSweepBlocks(LEdge, LNode.FX / 1000, LNode.FZ / 1000,
            Sqrt(Sqr(LHalfX) + Sqr(LHalfZ))) then
        begin
          AReason := 'This furnishing would block a swinging door. Move it away from the opening.';
          Exit;
        end;
        LBoxes := ModuleBoxes(ModuleToken(LEdge.FNode.FAssetId));
        for K := 0 to High(LBoxes) do
        begin
          LBox := LBoxes[K];
          if LBox.FY - LBox.FHeight / 2 >= LAsset.FHeight / 1000 then
          begin
            Continue;
          end;
          LX := LBox.FX;
          LZ := LBox.FZ;
          if LEdge.FVertical then
          begin
            LX := LBox.FZ;
            LZ := -LBox.FX;
            LBox.FWidth := LBoxes[K].FDepth;
            LBox.FDepth := LBoxes[K].FWidth;
          end;
          LX := LX + LEdge.FNode.FX / 1000;
          LZ := LZ + LEdge.FNode.FZ / 1000;
          if (Abs(LNode.FX / 1000 - LX) < LHalfX + LBox.FWidth / 2) and
            (Abs(LNode.FZ / 1000 - LZ) < LHalfZ + LBox.FDepth / 2) then
          begin
            AReason := 'This furnishing would meet a wall or door. Choose a floor tile with more room.';
            Exit;
          end;
        end;
      end;
      LAt := Length(ABuilding.FFurnishings);
      SetLength(ABuilding.FFurnishings, LAt + 1);
      ABuilding.FFurnishings[LAt] := LNode;
    end;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

end.
