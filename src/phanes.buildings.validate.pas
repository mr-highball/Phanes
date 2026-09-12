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
unit phanes.buildings.validate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.buildings.types;

function ReadModularBuilding(const AWorld: TWorld; const AId: String;
  out ABuilding: TModularBuilding; out AReason: String): Boolean;
function ValidateModularBuildings(const AWorld: TWorld; out AReason: String): Boolean;

implementation

uses
  Math, SysUtils, phanes.composition.types, phanes.composition.document,
  phanes.selection.grid, phanes.world.height, phanes.world.elevation,
  phanes.buildings.access, phanes.buildings.furniture, phanes.buildings.geometry;

function ReadModularBuilding(const AWorld: TWorld; const AId: String;
  out ABuilding: TModularBuilding; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAt: Integer;
  LNode: TCompositionNode;
  LToken: String;
  LBits: TSelectionBits;
  LEdge: TBuildingEdge;
  LCount: Integer;
  LX: Integer;
  LZ: Integer;
  LHalf: Integer;
  LMinX: Integer;
  LMaxX: Integer;
  LMinZ: Integer;
  LMaxZ: Integer;
  LVisited: TSelectionBits;
  LQueue: TSelectionCells;
  LHead: Integer;
  LTail: Integer;
  LCell: Integer;
  LNext: Integer;
  LEdgeIndex: Integer;
  LEntrances: Integer;
  LDoors: Integer;
  I: Integer;
  J: Integer;

  function EdgeBetween(const AX, AZ, ADirection: Integer): Integer;
  begin
    case ADirection of
      0:
      begin
        Result := ModuleEdgeAt(ABuilding, AX, AZ, False);
      end;
      1:
      begin
        Result := ModuleEdgeAt(ABuilding, AX + 1, AZ, True);
      end;
      2:
      begin
        Result := ModuleEdgeAt(ABuilding, AX, AZ + 1, False);
      end;
      else
      begin
        Result := ModuleEdgeAt(ABuilding, AX, AZ, True);
      end;
    end;
  end;

  function Neighbor(const AX, AZ, ADirection: Integer): Integer;
  var
    LNX: Integer;
    LNZ: Integer;
  begin
    LNX := AX;
    LNZ := AZ;
    case ADirection of
      0:
      begin
        Dec(LNZ);
      end;
      1:
      begin
        Inc(LNX);
      end;
      2:
      begin
        Inc(LNZ);
      end;
      3:
      begin
        Dec(LNX);
      end;
    end;
    Result := -1;
    if ModuleFloorAt(ABuilding, LNX, LNZ) then
    begin
      Result := LNZ * ABuilding.FSide + LNX;
    end;
  end;

begin
  Result := False;
  ABuilding := Default(TModularBuilding);
  ABuilding.FSide := AWorld.FSize * 8;
  LHalf := AWorld.FSize * 8000;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    AReason := 'Choose an admitted modular building.';
    LAt := LIndex.Find(AId);
    if LAt < 0 then
    begin
      Exit;
    end;
    ABuilding.FRoot := AWorld.FComposition.FNodes[LAt];
    LNode := ABuilding.FRoot;
    if (LNode.FParentId <> 'world') or (LNode.FSupportId <> '') or
      (LNode.FKind <> ckContainer) or (LNode.FRole <> 'modular-building') or
      (LNode.FAssetId <> ModularBuildingAsset) or (LNode.FX <> 0) or (LNode.FZ <> 0) or
      (LNode.FQuarterTurn <> 0) or HasCompositionExtent(LNode) or
      (LNode.FY < Round(WorldStandingMinimumMetres * 1000)) or (LNode.FY > 100000) then
    begin
      Exit;
    end;
    SetLength(LBits, Sqr(ABuilding.FSide));
    LMinX := ABuilding.FSide;
    LMinZ := ABuilding.FSide;
    LMaxX := -1;
    LMaxZ := -1;
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LNode := AWorld.FComposition.FNodes[I];
      if (LNode.FId = AId) or (ModularOwner(AWorld.FComposition, LIndex, I) <> AId) then
      begin
        Continue;
      end;
      AReason := 'A modular part has invalid ownership or geometry: ' + LNode.FId;
      LToken := ModuleToken(LNode.FAssetId);
      if LToken = '' then
      begin
        { Furniture and its complete support subtree have a separate admission
          below. A direct unknown building child cannot bypass that check. }
        Continue;
      end;
      if (LNode.FParentId <> AId) or (LNode.FSupportId <> '') or
        (LNode.FY <> 0) or HasCompositionExtent(LNode) then
      begin
        Exit;
      end;
      LToken := ModuleToken(LNode.FAssetId);
      if ModuleIsFloor(LToken) then
      begin
        LX := (LNode.FX + LHalf - 1000) div 2000;
        LZ := (LNode.FZ + LHalf - 1000) div 2000;
        if (LX < 0) or (LZ < 0) or (LX >= ABuilding.FSide) or (LZ >= ABuilding.FSide) or
          (LNode.FX <> LX * 2000 + 1000 - LHalf) or
          (LNode.FZ <> LZ * 2000 + 1000 - LHalf) or
          (LNode.FId <> ModuleFloorId(AId, LX, LZ)) or (LNode.FKind <> ckSurface) or
          (LNode.FRole <> 'floor-tile') or (LNode.FQuarterTurn <> 0) or
          LBits[LZ * ABuilding.FSide + LX] then
        begin
          Exit;
        end;
        LBits[LZ * ABuilding.FSide + LX] := True;
        LCount := Length(ABuilding.FFloorNodes);
        SetLength(ABuilding.FFloorNodes, LCount + 1);
        ABuilding.FFloorNodes[LCount] := LNode;
        LMinX := Min(LMinX, LX);
        LMaxX := Max(LMaxX, LX);
        LMinZ := Min(LMinZ, LZ);
        LMaxZ := Max(LMaxZ, LZ);
      end
      else if ModuleIsEdge(LToken) then
      begin
        LEdge := Default(TBuildingEdge);
        LEdge.FVertical := LNode.FQuarterTurn = 1;
        LX := (LNode.FX + LHalf - Ord(not LEdge.FVertical) * 1000) div 2000;
        LZ := (LNode.FZ + LHalf - Ord(LEdge.FVertical) * 1000) div 2000;
        if (LX < 0) or (LZ < 0) or (LX > ABuilding.FSide) or (LZ > ABuilding.FSide) or
          (LNode.FX <> LX * 2000 + Ord(not LEdge.FVertical) * 1000 - LHalf) or
          (LNode.FZ <> LZ * 2000 + Ord(LEdge.FVertical) * 1000 - LHalf) or
          (LNode.FQuarterTurn > 1) or (LNode.FKind <> ckObject) or
          (LNode.FRole <> 'wall-module') or
          (LNode.FId <> ModuleEdgeId(AId, LX, LZ, LEdge.FVertical)) or
          (ModuleEdgeAt(ABuilding, LX, LZ, LEdge.FVertical) >= 0) then
        begin
          Exit;
        end;
        LEdge.FX := LX;
        LEdge.FZ := LZ;
        LEdge.FNode := LNode;
        LCount := Length(ABuilding.FEdges);
        SetLength(ABuilding.FEdges, LCount + 1);
        ABuilding.FEdges[LCount] := LEdge;
      end
      else
      begin
        Exit;
      end;
    end;
    ABuilding.FFloors := SelectionCells(LBits);
    AReason := 'A modular building needs 1 to 256 floor tiles within a 64 metre span.';
    if (Length(ABuilding.FFloors) = 0) or
      (Length(ABuilding.FFloors) > ModuleMaximumFloors) or
      (LMaxX - LMinX >= ModuleMaximumSide) or (LMaxZ - LMinZ >= ModuleMaximumSide) then
    begin
      Exit;
    end;
    AReason := 'Every wall must border a floor; every floor edge needs an explicit wall or opening.';
    for I := 0 to High(ABuilding.FEdges) do
    begin
      LEdge := ABuilding.FEdges[I];
      if ModuleIsDoor(ModuleToken(LEdge.FNode.FAssetId)) then
      begin
        for J := 0 to High(ABuilding.FEdges) do
        begin
          if (J <> I) and ModuleDoorSweepMeetsEdge(LEdge, ABuilding.FEdges[J]) then
          begin
            AReason := 'This door would swing into another wall or door. Choose a different edge.';
            Exit;
          end;
        end;
      end;
      if not ModuleFloorAt(ABuilding, LEdge.FX, LEdge.FZ) and
        not ModuleFloorAt(ABuilding, LEdge.FX - Ord(LEdge.FVertical),
          LEdge.FZ - Ord(not LEdge.FVertical)) then
      begin
        Exit;
      end;
    end;
    LEntrances := 0;
    LDoors := 0;
    for I := 0 to High(ABuilding.FFloors) do
    begin
      LX := ABuilding.FFloors[I] mod ABuilding.FSide;
      LZ := ABuilding.FFloors[I] div ABuilding.FSide;
      for J := 0 to 3 do
      begin
        LEdgeIndex := EdgeBetween(LX, LZ, J);
        if LEdgeIndex < 0 then
        begin
          Exit;
        end;
        LToken := ModuleToken(ABuilding.FEdges[LEdgeIndex].FNode.FAssetId);
        AReason := 'Stone flooring requires compatible plaster wall reveals.';
        LAt := LIndex.Find(ModuleFloorId(AId, LX, LZ));
        if (ModuleToken(AWorld.FComposition.FNodes[LAt].FAssetId) = 'floor.stone') and
          (Pos('.timber', LToken) > 0) then
        begin
          Exit;
        end;
        if ModuleIsDoor(LToken) then
        begin
          Inc(LDoors);
        end;
        if (Neighbor(LX, LZ, J) < 0) and ModuleIsPassage(LToken) then
        begin
          Inc(LEntrances);
        end;
      end;
    end;
    AReason := 'Keep at least one exterior doorway or passage into this building.';
    if LEntrances = 0 then
    begin
      Exit;
    end;
    { Independently flood the decoded floor and shared edges. Closed doors
      are traversable in the architectural graph because players can open them;
      runtime collision still blocks their leaf until it is open. }
    SetLength(LVisited, Length(LBits));
    SetLength(LQueue, Length(ABuilding.FFloors));
    LQueue[0] := ABuilding.FFloors[0];
    LVisited[LQueue[0]] := True;
    LTail := 1;
    LHead := 0;
    while LHead < LTail do
    begin
      LCell := LQueue[LHead];
      Inc(LHead);
      LX := LCell mod ABuilding.FSide;
      LZ := LCell div ABuilding.FSide;
      for J := 0 to 3 do
      begin
        LNext := Neighbor(LX, LZ, J);
        if (LNext < 0) or LVisited[LNext] then
        begin
          Continue;
        end;
        LEdgeIndex := EdgeBetween(LX, LZ, J);
        if ModuleIsPassage(ModuleToken(ABuilding.FEdges[LEdgeIndex].FNode.FAssetId)) then
        begin
          LVisited[LNext] := True;
          LQueue[LTail] := LNext;
          Inc(LTail);
        end;
      end;
    end;
    AReason := 'A wall would seal off part of the building. Add a door or passage first.';
    if LTail <> Length(ABuilding.FFloors) then
    begin
      Exit;
    end;
    Result := ValidateBuildingFurniture(AWorld.FComposition, ABuilding, AReason);
  finally
    LIndex.Free;
  end;
end;

function ValidateModularBuildings(const AWorld: TWorld; out AReason: String): Boolean;
var
  LBuilding: TModularBuilding;
  LHeight: TWorldHeight;
  LOccupied: array of Integer;
  LMinimum: Double;
  LMaximum: Double;
  LCell: Integer;
  LX: Integer;
  LZ: Integer;
  LSide: Integer;
  LFound: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
  LNeighbor: Integer;
  LNX: Integer;
  LNZ: Integer;
begin
  LFound := False;
  for I := 0 to High(AWorld.FComposition.FNodes) do
  begin
    if (AWorld.FComposition.FNodes[I].FId = 'world') and
      (AWorld.FComposition.FNodes[I].FAssetId <> '') then
    begin
      AReason := 'The world root cannot claim an asset or module profile.';
      Exit(False);
    end;
    if (AWorld.FComposition.FNodes[I].FAssetId = ModularBuildingAsset) or
      (AWorld.FComposition.FNodes[I].FRole = 'modular-building') then
    begin
      LFound := True;
    end;
  end;
  if not LFound then
  begin
    AReason := '';
    Exit(True);
  end;
  Result := False;
  LSide := AWorld.FSize * 8;
  SetLength(LOccupied, Sqr(LSide));
  for I := 0 to High(LOccupied) do
  begin
    LOccupied[I] := -1;
  end;
  LHeight := TWorldHeight.Create(AWorld);
  try
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      if (AWorld.FComposition.FNodes[I].FAssetId <> ModularBuildingAsset) and
        (AWorld.FComposition.FNodes[I].FRole <> 'modular-building') then
      begin
        Continue;
      end;
      if not ReadModularBuilding(AWorld, AWorld.FComposition.FNodes[I].FId, LBuilding, AReason) then
      begin
        Exit;
      end;
      for J := 0 to High(LBuilding.FFloors) do
      begin
        LCell := LBuilding.FFloors[J];
        LX := LCell mod LSide;
        LZ := LCell div LSide;
        AReason := 'Buildings cannot occupy the same floor area.';
        if LOccupied[LCell] >= 0 then
        begin
          Exit;
        end;
        AReason := 'Leave one floor tile between separate buildings, or extend the same building.';
        for K := 0 to 8 do
        begin
          LNX := LX + K mod 3 - 1;
          LNZ := LZ + K div 3 - 1;
          if (LNX < 0) or (LNZ < 0) or (LNX >= LSide) or (LNZ >= LSide) then
          begin
            Continue;
          end;
          LNeighbor := LOccupied[LNZ * LSide + LNX];
          if (LNeighbor >= 0) and (LNeighbor <> I) then
          begin
            Exit;
          end;
        end;
        LOccupied[LCell] := I;
        AReason := 'Choose dry land clear of existing exterior buildings.';
        if (AWorld.FLayers[0][(LZ div 8) * AWorld.FSize + LX div 8] = 'water') or
          (AWorld.FLayers[3][(LZ div 8) * AWorld.FSize + LX div 8] <> 'empty') then
        begin
          Exit;
        end;
        LHeight.Bounds(LX * 2 - AWorld.FSize * 8, LZ * 2 - AWorld.FSize * 8,
          LX * 2 + 2 - AWorld.FSize * 8, LZ * 2 + 2 - AWorld.FSize * 8, LMinimum, LMaximum);
        AReason := 'This floor would be buried or too high above its foundation. Choose a gentler site.';
        if (LBuilding.FRoot.FY / 1000 - 0.16 < LMaximum - 0.50) or
          (LBuilding.FRoot.FY / 1000 > LMinimum + 2.0) then
        begin
          Exit;
        end;
      end;
    end;
    Result := ValidateBuildingAccess(AWorld, AReason);
  finally
    LHeight.Free;
  end;
end;

end.
