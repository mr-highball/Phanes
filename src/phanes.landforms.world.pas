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

unit phanes.landforms.world;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types, phanes.terrain.types;

function GenerateLandform(const ARequest: TWorldRequest; var ACommitted: TWorld;
  out AReason: String): Boolean;

function GenerateInitialLandform(const ASize: Integer; const ASeed: Cardinal;
  var ACommitted: TTerrainField; out AReason: String): Boolean;

implementation

uses
  Math, SysUtils, phanes.world.selection, phanes.world.validate,
  phanes.world.height, phanes.terrain.generate, phanes.terrain.validate,
  phanes.composition.types, phanes.composition.document, phanes.landforms.types,
  phanes.selection.grid, phanes.landforms.validate, phanes.world.elevation;

function PaintedCell(const ARequest: TWorldRequest; const AX, AZ: Integer): Boolean;
var
  LX: Integer;
  LZ: Integer;
begin
  if ARequest.FSelectionScale = 0 then
  begin
    Exit((AX div 2 >= ARequest.FX) and (AZ div 2 >= ARequest.FZ) and
      (AX div 2 < ARequest.FX + ARequest.FWidth) and
      (AZ div 2 < ARequest.FZ + ARequest.FDepth));
  end;
  LX := AX * ARequest.FSelectionScale div 2;
  LZ := AZ * ARequest.FSelectionScale div 2;
  Result := HasSelectionCell(ARequest.FSelectionCells,
    LZ * ARequest.FSize * ARequest.FSelectionScale + LX);
end;

function EmptyOffsets(const ASize: Integer): TTerrainField;
begin
  Result := Default(TTerrainField);
  Result.FSpec.FVersion := TerrainFieldVersion;
  Result.FSpec.FColumns := ASize * 2 + 1;
  Result.FSpec.FRows := ASize * 2 + 1;
  Result.FSpec.FOriginX := -ASize * 8000;
  Result.FSpec.FOriginZ := -ASize * 8000;
  Result.FSpec.FSpacing := 8000;
  Result.FSpec.FLevelStep := 250;
  Result.FSpec.FMinimumLevel := -32;
  Result.FSpec.FMaximumLevel := 32;
  Result.FSpec.FMaximumRise := 4;
  SetLength(Result.FLevels, Sqr(Result.FSpec.FColumns));
end;

function GenerateInitialLandform(const ASize: Integer; const ASeed: Cardinal;
  var ACommitted: TTerrainField; out AReason: String): Boolean;
var
  LRequest: TTerrainRequest;
  LFrame: TTerrainField;
  I: Integer;
begin
  Result := False;
  if (ASize < 4) or (ASize > 48) then
  begin
    AReason := 'Choose a working region between 4 and 48 cells per side.';
    Exit;
  end;
  LFrame := EmptyOffsets(ASize);
  LRequest := Default(TTerrainRequest);
  LRequest.FSpec := LFrame.FSpec;
  LRequest.FSeed := ASeed;
  LRequest.FWidth := ASize * 2;
  LRequest.FDepth := ASize * 2;
  LRequest.FMaxBacktracks := 4096;
  SetLength(LRequest.FDomains, Length(LFrame.FLevels));
  { New worlds use absolute WFC heights. The initial one-to-six-metre
    interval leaves room for later valleys and peaks within the saved range.
    Cardinal rise limits connect neighbouring vertices before ecology and
    architecture choose their independently admitted support locations. }
  for I := 0 to High(LRequest.FDomains) do
  begin
    LRequest.FDomains[I].FMinimum := 4;
    LRequest.FDomains[I].FMaximum := 24;
  end;
  Result := GenerateTerrain(LRequest, ACommitted, AReason);
end;

function DetachedWorld(const AWorld: TWorld): TWorld;
var
  I: Integer;
begin
  Result := AWorld;
  Result.FElevation := CopyTerrainField(AWorld.FElevation);
  Result.FComposition := CopyDocument(AWorld.FComposition);
  for I := 0 to 4 do
  begin
    Result.FLayers[I] := Copy(AWorld.FLayers[I], 0, Length(AWorld.FLayers[I]));
  end;
  Result.FRooms := Copy(AWorld.FRooms, 0, Length(AWorld.FRooms));
  for I := 0 to High(Result.FRooms) do
  begin
    Result.FRooms[I].FFurniture := Copy(AWorld.FRooms[I].FFurniture, 0,
      Length(AWorld.FRooms[I].FFurniture));
    Result.FRooms[I].FLooks := Copy(AWorld.FRooms[I].FLooks, 0, Length(AWorld.FRooms[I].FLooks));
    Result.FRooms[I].FTableware := Copy(AWorld.FRooms[I].FTableware, 0,
      Length(AWorld.FRooms[I].FTableware));
  end;
end;

procedure ProtectBox(var ARequest: TTerrainRequest;
  const AMinX, AMinZ, AMaxX, AMaxZ: Double);
var
  LMinX: Integer;
  LMinZ: Integer;
  LMaxX: Integer;
  LMaxZ: Integer;
  LX: Integer;
  LZ: Integer;
begin
  { Pin every vertex of a triangle that can touch the occupied influence.
    The bounds include approaches and grading, not just visible model boxes. }
  LMinX := Max(0, Floor((AMinX * 1000 - ARequest.FSpec.FOriginX) / 8000));
  LMinZ := Max(0, Floor((AMinZ * 1000 - ARequest.FSpec.FOriginZ) / 8000));
  LMaxX := Min(ARequest.FSpec.FColumns - 1,
    Ceil((AMaxX * 1000 - ARequest.FSpec.FOriginX) / 8000));
  LMaxZ := Min(ARequest.FSpec.FRows - 1,
    Ceil((AMaxZ * 1000 - ARequest.FSpec.FOriginZ) / 8000));
  for LZ := LMinZ to LMaxZ do
  begin
    for LX := LMinX to LMaxX do
    begin
      ARequest.FProtected[LZ * ARequest.FSpec.FColumns + LX] := True;
    end;
  end;
end;

procedure ProtectConstruction(const AWorld: TWorld; var ARequest: TTerrainRequest);
var
  LNode: TCompositionNode;
  LX: Double;
  LZ: Double;
  LHalf: Double;
  I: Integer;
begin
  { The surrounding sea grades the outer edge independently of raw heights. }
  LHalf := AWorld.FSize * 8;
  ProtectBox(ARequest, -LHalf, -LHalf, -LHalf + 8, LHalf);
  ProtectBox(ARequest, LHalf - 8, -LHalf, LHalf, LHalf);
  ProtectBox(ARequest, -LHalf, -LHalf, LHalf, -LHalf + 8);
  ProtectBox(ARequest, -LHalf, LHalf - 8, LHalf, LHalf);
  for I := 0 to High(AWorld.FLayers[3]) do
  begin
    if AWorld.FLayers[0][I] = 'water' then
    begin
      LX := (I mod AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      LZ := (I div AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      ProtectBox(ARequest, LX - 11, LZ - 11, LX + 11, LZ + 11);
    end;
    if AWorld.FLayers[3][I] <> 'empty' then
    begin
      LX := (I mod AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      LZ := (I div AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      ProtectBox(ARequest, LX - 8, LZ - 8, LX + 8, LZ + 8);
    end;
  end;
  for I := 0 to High(AWorld.FComposition.FNodes) do
  begin
    LNode := AWorld.FComposition.FNodes[I];
    LX := LNode.FX / 1000;
    LZ := LNode.FZ / 1000;
    if (LNode.FRole = 'plot') and (LNode.FParentId = 'world') then
    begin
      ProtectBox(ARequest, LX - 16.5, LZ - 16.5, LX + 16.5, LZ + 16.5);
    end
    else if LNode.FRole = 'floor-tile' then
    begin
      ProtectBox(ARequest, LX - 9, LZ - 9, LX + 9, LZ + 9);
    end;
  end;
end;

procedure RetainPlantSupport(const AWorld: TWorld; var ARequest: TTerrainRequest);
var
  LHeight: TWorldHeight;
  LBaseMin: Double;
  LBaseMax: Double;
  LMinimum: Double;
  LMaximum: Double;
  LMinX: Double;
  LMinZ: Double;
  LLimit: Integer;
  LAt: Integer;
  LCellSide: Integer;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  LHeight := TWorldHeight.Create(AWorld);
  try
    LCellSide := AWorld.FSize * 2;
    for I := 0 to High(AWorld.FLayers[2]) do
    begin
      if (AWorld.FLayers[2][I] = 'empty') or (AWorld.FLayers[2][I] = 'rock') then
      begin
        Continue;
      end;
      LMinX := (I mod LCellSide) * 8 - AWorld.FSize * 8;
      LMinZ := (I div LCellSide) * 8 - AWorld.FSize * 8;
      LHeight.Bounds(LMinX, LMinZ, LMinX + 8, LMinZ + 8, LMinimum, LMaximum);
      LBaseMin := 0;
      if AWorld.FRelativeElevation or (AWorld.FElevation.FSpec.FVersion = 0) then
      begin
        TerrainHeightBounds(LMinX, LMinZ, LMinX + 8, LMinZ + 8, LBaseMin, LBaseMax);
      end;
      LLimit := Ceil((WorldStandingMinimumMetres - LBaseMin) * 1000 /
        ARequest.FSpec.FLevelStep);
      for LZ := I div LCellSide to I div LCellSide + 1 do
      begin
        for LX := I mod LCellSide to I mod LCellSide + 1 do
        begin
          LAt := LZ * ARequest.FSpec.FColumns + LX;
          if LMinimum < WorldStandingMinimumMetres then
          begin
            { Existing marginal supports may improve but cannot be lowered. }
            ARequest.FDomains[LAt].FMinimum := Max(ARequest.FDomains[LAt].FMinimum,
              ARequest.FPrevious.FLevels[LAt]);
          end
          else
          begin
            ARequest.FDomains[LAt].FMinimum := Max(ARequest.FDomains[LAt].FMinimum, LLimit);
          end;
        end;
      end;
    end;
  finally
    LHeight.Free;
  end;
end;

function Prepare(const ARequest: TWorldRequest; out ATerrain: TTerrainRequest;
  out AReason: String): Boolean;
var
  LSide: Integer;
  LCellSide: Integer;
  LOld: Integer;
  LSteps: Integer;
  LMean: Integer;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  Result := False;
  ATerrain := Default(TTerrainRequest);
  if not IsLandformOperation(ARequest.FOperation) or
    (ARequest.FPrevious.FSize <> ARequest.FSize) or (ARequest.FEditLayer <> 'terrain') then
  begin
    AReason := 'Create a world before shaping its land.';
    Exit;
  end;
  if not ValidateWorld(ARequest.FPrevious, ARequest.FAssets, AReason) or
    not ValidateSelection(ARequest, AReason) then
  begin
    Exit;
  end;
  if (ARequest.FX < 0) or (ARequest.FZ < 0) or (ARequest.FWidth < 1) or
    (ARequest.FDepth < 1) or (ARequest.FWidth > ARequest.FSize) or
    (ARequest.FDepth > ARequest.FSize) or
    (ARequest.FX > ARequest.FSize - ARequest.FWidth) or
    (ARequest.FZ > ARequest.FSize - ARequest.FDepth) then
  begin
    AReason := 'The terrain selection must lie inside the world.';
    Exit;
  end;
  for I := 0 to High(ARequest.FPrevious.FComposition.FNodes) do
  begin
    if (ARequest.FPrevious.FComposition.FNodes[I].FId = 'world') and
      ARequest.FPrevious.FComposition.FNodes[I].FLocked then
    begin
      AReason := 'Unlock the world before changing its terrain.';
      Exit;
    end;
  end;
  ATerrain.FPrevious := CopyTerrainField(ARequest.FPrevious.FElevation);
  if ATerrain.FPrevious.FSpec.FVersion = 0 then
  begin
    { All-zero offsets preserve the exact analytic surface, including between
      vertices. This is not a resampling or reinterpretation of the old world. }
    ATerrain.FPrevious := EmptyOffsets(ARequest.FSize);
  end;
  ATerrain.FSpec := ATerrain.FPrevious.FSpec;
  if (ARequest.FLandformAmount < ATerrain.FSpec.FLevelStep) or
    (ARequest.FLandformAmount > 8000) or
    (ARequest.FLandformAmount mod ATerrain.FSpec.FLevelStep <> 0) then
  begin
    AReason := 'Choose a height change aligned to this terrain grid, up to eight metres.';
    Exit;
  end;
  ATerrain.FHasPrevious := True;
  ATerrain.FSeed := ARequest.FSeed;
  ATerrain.FMaxBacktracks := 4096;
  ATerrain.FWidth := ATerrain.FSpec.FColumns - 1;
  ATerrain.FDepth := ATerrain.FSpec.FRows - 1;
  LSide := ATerrain.FSpec.FColumns;
  LCellSide := LSide - 1;
  LSteps := ARequest.FLandformAmount div ATerrain.FSpec.FLevelStep;
  SetLength(ATerrain.FProtected, Sqr(LSide));
  SetLength(ATerrain.FDomains, Sqr(LSide));
  for LZ := 0 to LSide - 1 do
  begin
    for LX := 0 to LSide - 1 do
    begin
      I := LZ * LSide + LX;
      { A vertex belongs to every incident terrain cell. All four cells must
        be selected; holes and outside triangles therefore stay exactly fixed. }
      ATerrain.FProtected[I] := (LX = 0) or (LZ = 0) or
        (LX = LCellSide) or (LZ = LCellSide);
      if not ATerrain.FProtected[I] then
      begin
        ATerrain.FProtected[I] :=
          not PaintedCell(ARequest, LX - 1, LZ - 1) or
          not PaintedCell(ARequest, LX, LZ - 1) or
          not PaintedCell(ARequest, LX - 1, LZ) or
          not PaintedCell(ARequest, LX, LZ);
      end;
    end;
  end;
  ProtectConstruction(ARequest.FPrevious, ATerrain);
  for I := 0 to High(ATerrain.FDomains) do
  begin
    LOld := ATerrain.FPrevious.FLevels[I];
    ATerrain.FDomains[I].FMinimum := LOld;
    ATerrain.FDomains[I].FMaximum := LOld;
    if ATerrain.FProtected[I] then
    begin
      Continue;
    end;
    if ARequest.FOperation <> 'land-raise' then
    begin
      ATerrain.FDomains[I].FMinimum := Max(ATerrain.FSpec.FMinimumLevel, LOld - LSteps);
    end;
    if ARequest.FOperation <> 'land-lower' then
    begin
      ATerrain.FDomains[I].FMaximum := Min(ATerrain.FSpec.FMaximumLevel, LOld + LSteps);
    end;
    if ARequest.FOperation = 'land-soften' then
    begin
      LMean := Round((LOld * 2 + ATerrain.FPrevious.FLevels[I - 1] +
        ATerrain.FPrevious.FLevels[I + 1] + ATerrain.FPrevious.FLevels[I - LSide] +
        ATerrain.FPrevious.FLevels[I + LSide]) / 6);
      ATerrain.FDomains[I].FMinimum := Max(ATerrain.FDomains[I].FMinimum, Min(LOld, LMean));
      ATerrain.FDomains[I].FMaximum := Min(ATerrain.FDomains[I].FMaximum, Max(LOld, LMean));
    end;
  end;
  RetainPlantSupport(ARequest.FPrevious, ATerrain);
  Result := True;
end;

function AnchorChange(var ARequest: TTerrainRequest; const AOperation: String;
  out AReason: String): Boolean;
var
  LQueue: array of Integer;
  LQueued: array of Boolean;
  LHead: Integer;
  LTail: Integer;
  LCount: Integer;
  LAt: Integer;
  LNeighbor: Integer;
  LMinimum: Integer;
  LMaximum: Integer;
  LSide: Integer;
  LAnchor: Integer;
  LBest: Integer;
  LRoom: Integer;
  LDirection: Integer;
  LRaise: Boolean;
  I: Integer;

  procedure Enqueue(const AIndex: Integer);
  begin
    if not LQueued[AIndex] then
    begin
      LQueued[AIndex] := True;
      LQueue[LTail] := AIndex;
      LTail := (LTail + 1) mod Length(LQueue);
      Inc(LCount);
    end;
  end;

begin
  Result := False;
  LSide := ARequest.FSpec.FColumns;
  SetLength(LQueue, Length(ARequest.FDomains));
  SetLength(LQueued, Length(LQueue));
  LHead := 0;
  LTail := 0;
  LCount := 0;
  for I := 0 to High(LQueue) do
  begin
    Enqueue(I);
  end;
  { Propagate interval bounds before choosing an anchor. This avoids requesting
    a rise at a saturated boundary when another selected vertex can change.
    WFC still chooses all admitted discrete heights and validates its result. }
  while LCount > 0 do
  begin
    LAt := LQueue[LHead];
    LHead := (LHead + 1) mod Length(LQueue);
    Dec(LCount);
    LQueued[LAt] := False;
    if ARequest.FDomains[LAt].FMinimum > ARequest.FDomains[LAt].FMaximum then
    begin
      AReason := 'These heights cannot join the preserved boundary. Select more land or ease the change.';
      Exit;
    end;
    for LDirection := 0 to 3 do
    begin
      LNeighbor := -1;
      case LDirection of
        0:
        begin
          if LAt mod LSide > 0 then
          begin
            LNeighbor := LAt - 1;
          end;
        end;
        1:
        begin
          if LAt mod LSide < LSide - 1 then
          begin
            LNeighbor := LAt + 1;
          end;
        end;
        2:
        begin
          if LAt >= LSide then
          begin
            LNeighbor := LAt - LSide;
          end;
        end;
        3:
        begin
          if LAt < Length(LQueue) - LSide then
          begin
            LNeighbor := LAt + LSide;
          end;
        end;
      end;
      if LNeighbor < 0 then
      begin
        Continue;
      end;
      LMinimum := Max(ARequest.FDomains[LNeighbor].FMinimum,
        ARequest.FDomains[LAt].FMinimum - ARequest.FSpec.FMaximumRise);
      LMaximum := Min(ARequest.FDomains[LNeighbor].FMaximum,
        ARequest.FDomains[LAt].FMaximum + ARequest.FSpec.FMaximumRise);
      if (LMinimum <> ARequest.FDomains[LNeighbor].FMinimum) or
        (LMaximum <> ARequest.FDomains[LNeighbor].FMaximum) then
      begin
        ARequest.FDomains[LNeighbor].FMinimum := LMinimum;
        ARequest.FDomains[LNeighbor].FMaximum := LMaximum;
        Enqueue(LNeighbor);
      end;
    end;
  end;
  LRaise := AOperation <> 'land-lower';
  LAnchor := -1;
  LBest := 0;
  for I := 0 to High(ARequest.FDomains) do
  begin
    if ARequest.FProtected[I] then
    begin
      Continue;
    end;
    if LRaise then
    begin
      LRoom := ARequest.FDomains[I].FMaximum - ARequest.FPrevious.FLevels[I];
    end
    else
    begin
      LRoom := ARequest.FPrevious.FLevels[I] - ARequest.FDomains[I].FMinimum;
    end;
    if LRoom > LBest then
    begin
      LAnchor := I;
      LBest := LRoom;
    end;
  end;
  if (AOperation = 'land-raise') or (AOperation = 'land-lower') then
  begin
    if LAnchor < 0 then
    begin
      AReason := 'No selected height can move while preserving water, structures and the boundary. Draw a wider area of dry land.';
      Exit;
    end;
    if LRaise then
    begin
      ARequest.FDomains[LAnchor].FMinimum := ARequest.FPrevious.FLevels[LAnchor] + 1;
    end
    else
    begin
      ARequest.FDomains[LAnchor].FMaximum := ARequest.FPrevious.FLevels[LAnchor] - 1;
    end;
  end;
  Result := True;
end;

function GenerateLandform(const ARequest: TWorldRequest; var ACommitted: TWorld;
  out AReason: String): Boolean;
var
  LTerrain: TTerrainRequest;
  LCandidate: TWorld;
  LField: TTerrainField;
begin
  Result := False;
  if not Prepare(ARequest, LTerrain, AReason) or
    not AnchorChange(LTerrain, ARequest.FOperation, AReason) then
  begin
    Exit;
  end;
  LField := Default(TTerrainField);
  if not GenerateTerrain(LTerrain, LField, AReason) then
  begin
    Exit;
  end;
  LCandidate := DetachedWorld(ARequest.FPrevious);
  if SameTerrainField(LField, LTerrain.FPrevious) then
  begin
    if not ValidateLandformEdit(ARequest, LCandidate, AReason) then
    begin
      Exit;
    end;
    ACommitted := LCandidate;
    AReason := 'The selected terrain already meets these constraints; no height changed.';
    Result := True;
    Exit;
  end;
  LCandidate.FElevation := LField;
  LCandidate.FRelativeElevation := ARequest.FPrevious.FRelativeElevation or
    (ARequest.FPrevious.FElevation.FSpec.FVersion = 0);
  LCandidate.FSeed := ARequest.FSeed;
  LCandidate.FDecisions := LField.FDecisions;
  LCandidate.FPropagations := LField.FPropagations;
  LCandidate.FBacktracks := LField.FBacktracks;
  if not ValidateLandformEdit(ARequest, LCandidate, AReason) then
  begin
    Exit;
  end;
  ACommitted := LCandidate;
  AReason := 'Terrain shaped. Other land and existing construction are preserved.';
  Result := True;
end;

end.
