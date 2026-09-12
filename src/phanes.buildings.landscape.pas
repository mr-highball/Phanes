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
unit phanes.buildings.landscape;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types, phanes.buildings.types;

type
  TModularCollisionEntry = record
    FBuilding: Integer;
    FPart: Integer;
    FFurniture: Boolean;
  end;

  TModularLandscape = class
  private
    FSide: Integer;
    FHalf: Double;
    FBuildings: array of TModularBuilding;
    FCells: array of Integer;
    FCollisionCells: array of array of Integer;
    FCollisionEntries: array of TModularCollisionEntry;
    function Cell(const AX, AZ: Integer): Integer;
    procedure AddCollision(const ABuilding, APart: Integer; const AFurniture: Boolean;
      const AX, AZ, AExtent: Double);
  public
    constructor Create(const AWorld: TWorld);
    function At(const AX, AZ: Double): Integer;
    function FloorHeight(const AIndex: Integer): Double;
    function SoilHeight(const AX, AZ, AUnmodified: Double): Double;
    function AllowsStanding(const AX, AZ, ARadius: Double): Boolean;
    function ClearsVegetation(const AX, AZ, ARadius: Double): Boolean;
    function Signature(const AMinX, AMinZ, AMaxX, AMaxZ: Double): String;
  end;

implementation

uses
  SysUtils, Math, phanes.buildings.validate, phanes.buildings.geometry,
  phanes.buildings.furniture;

constructor TModularLandscape.Create(const AWorld: TWorld);
var
  LBuilding: TModularBuilding;
  LReason: String;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  inherited Create;
  FSide := AWorld.FSize * 8;
  FHalf := AWorld.FSize * 8;
  for I := 0 to High(AWorld.FComposition.FNodes) do
  begin
    if AWorld.FComposition.FNodes[I].FAssetId <> ModularBuildingAsset then
    begin
      Continue;
    end;
    if not ReadModularBuilding(AWorld, AWorld.FComposition.FNodes[I].FId, LBuilding, LReason) then
    begin
      raise Exception.Create('Cannot prepare modular geometry: ' + LReason);
    end;
    if Length(FCells) = 0 then
    begin
      SetLength(FCells, Sqr(FSide));
      SetLength(FCollisionCells, Sqr(FSide));
      for J := 0 to High(FCells) do
      begin
        FCells[J] := -1;
      end;
    end;
    LAt := Length(FBuildings);
    SetLength(FBuildings, LAt + 1);
    FBuildings[LAt] := LBuilding;
    for J := 0 to High(LBuilding.FFloors) do
    begin
      FCells[LBuilding.FFloors[J]] := LAt;
    end;
    for J := 0 to High(LBuilding.FEdges) do
    begin
      if ModuleToken(LBuilding.FEdges[J].FNode.FAssetId) <> 'opening' then
      begin
        AddCollision(LAt, J, False, LBuilding.FEdges[J].FNode.FX / 1000,
          LBuilding.FEdges[J].FNode.FZ / 1000, 1.5);
      end;
    end;
    for J := 0 to High(LBuilding.FFurnishings) do
    begin
      AddCollision(LAt, J, True, LBuilding.FFurnishings[J].FX / 1000,
        LBuilding.FFurnishings[J].FZ / 1000, 2);
    end;
  end;
end;

procedure TModularLandscape.AddCollision(const ABuilding, APart: Integer;
  const AFurniture: Boolean; const AX, AZ, AExtent: Double);
var
  LEntry: Integer;
  LCell: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  LEntry := Length(FCollisionEntries);
  SetLength(FCollisionEntries, LEntry + 1);
  FCollisionEntries[LEntry].FBuilding := ABuilding;
  FCollisionEntries[LEntry].FPart := APart;
  FCollisionEntries[LEntry].FFurniture := AFurniture;
  { Conservative bins only choose candidates. The shared module/assembly
    geometry still decides collision, including a door leaf in either state. }
  for J := Max(0, Floor((AZ - AExtent + FHalf) / 2)) to
    Min(FSide - 1, Floor((AZ + AExtent + FHalf) / 2)) do
  begin
    for I := Max(0, Floor((AX - AExtent + FHalf) / 2)) to
      Min(FSide - 1, Floor((AX + AExtent + FHalf) / 2)) do
    begin
      LCell := J * FSide + I;
      LCount := Length(FCollisionCells[LCell]);
      SetLength(FCollisionCells[LCell], LCount + 1);
      FCollisionCells[LCell][LCount] := LEntry;
    end;
  end;
end;

function TModularLandscape.Cell(const AX, AZ: Integer): Integer;
begin
  Result := -1;
  if (Length(FCells) > 0) and (AX >= 0) and (AZ >= 0) and (AX < FSide) and (AZ < FSide) then
  begin
    Result := FCells[AZ * FSide + AX];
  end;
end;

function TModularLandscape.At(const AX, AZ: Double): Integer;
begin
  Result := Cell(Floor((AX + FHalf) / 2), Floor((AZ + FHalf) / 2));
end;

function TModularLandscape.FloorHeight(const AIndex: Integer): Double;
begin
  Result := FBuildings[AIndex].FRoot.FY / 1000;
end;

function TModularLandscape.SoilHeight(const AX, AZ, AUnmodified: Double): Double;
var
  LX: Integer;
  LZ: Integer;
  LAt: Integer;
  LDistance: Double;
  LBest: Double;
  LWeight: Double;
  LDatum: Double;
  LTotalWeight: Double;
  I: Integer;
  J: Integer;
begin
  Result := AUnmodified;
  if Length(FBuildings) = 0 then
  begin
    Exit;
  end;
  LX := Floor((AX + FHalf) / 2);
  LZ := Floor((AZ + FHalf) / 2);
  LBest := 0;
  LDatum := 0;
  LTotalWeight := 0;
  for J := LZ - 3 to LZ + 3 do
  begin
    for I := LX - 3 to LX + 3 do
    begin
      LAt := Cell(I, J);
      if LAt < 0 then
      begin
        Continue;
      end;
      LDistance := Sqrt(Sqr(Max(0, Abs(AX - (I * 2 + 1 - FHalf)) - 1)) +
        Sqr(Max(0, Abs(AZ - (J * 2 + 1 - FHalf)) - 1)));
      if LDistance < 0.00000001 then
      begin
        Exit(FloorHeight(LAt) - 0.16);
      end;
      LWeight := EnsureRange(1 - LDistance / 6, 0, 1);
      LWeight := LWeight * LWeight * (3 - 2 * LWeight);
      if LWeight > LBest then
      begin
        LBest := LWeight;
      end;
      { The nearest datum dominates continuously at its floor boundary.
        Ordinary weighted averages pull one foundation toward its neighbor,
        producing a discontinuity where standing height becomes the floor. }
      LWeight := LWeight / Max(0.000000000001, 1 - LWeight);
      LDatum := LDatum + (FloorHeight(LAt) - 0.16) * LWeight;
      LTotalWeight := LTotalWeight + LWeight;
    end;
  end;
  if LTotalWeight > 0 then
  begin
    Result := Result * (1 - LBest) + LDatum / LTotalWeight * LBest;
  end;
end;

function TModularLandscape.AllowsStanding(const AX, AZ, ARadius: Double): Boolean;
var
  LCell: Integer;
  LEntry: TModularCollisionEntry;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := True;
  if Length(FBuildings) = 0 then
  begin
    Exit;
  end;
  for J := Max(0, Floor((AZ - ARadius + FHalf) / 2)) to
    Min(FSide - 1, Floor((AZ + ARadius + FHalf) / 2)) do
  begin
    for I := Max(0, Floor((AX - ARadius + FHalf) / 2)) to
      Min(FSide - 1, Floor((AX + ARadius + FHalf) / 2)) do
    begin
      LCell := J * FSide + I;
      for K := 0 to High(FCollisionCells[LCell]) do
      begin
        LEntry := FCollisionEntries[FCollisionCells[LCell][K]];
        if LEntry.FFurniture then
        begin
          if FurnitureBlocks(FBuildings[LEntry.FBuilding].FFurnishings[LEntry.FPart],
            AX, AZ, ARadius) then
          begin
            Exit(False);
          end;
        end
        else if ModuleBlocks(FBuildings[LEntry.FBuilding].FEdges[LEntry.FPart],
          AX, AZ, ARadius) then
        begin
          Exit(False);
        end;
      end;
    end;
  end;
end;

function TModularLandscape.ClearsVegetation(const AX, AZ, ARadius: Double): Boolean;
var
  LX: Integer;
  LZ: Integer;
  LRadius: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  if Length(FBuildings) = 0 then
  begin
    Exit;
  end;
  LX := Floor((AX + FHalf) / 2);
  LZ := Floor((AZ + FHalf) / 2);
  LRadius := Ceil(ARadius / 2);
  for J := LZ - LRadius to LZ + LRadius do
  begin
    for I := LX - LRadius to LX + LRadius do
    begin
      if (Cell(I, J) >= 0) and
        (Sqr(Max(0, Abs(AX - (I * 2 + 1 - FHalf)) - 1)) +
        Sqr(Max(0, Abs(AZ - (J * 2 + 1 - FHalf)) - 1)) <= Sqr(ARadius)) then
      begin
        Exit(True);
      end;
    end;
  end;
end;

function TModularLandscape.Signature(const AMinX, AMinZ, AMaxX, AMaxZ: Double): String;
var
  LX: Double;
  LZ: Double;
  I: Integer;
  J: Integer;
begin
  Result := '';
  { Terrain and foliage depend on floor footprint/datum only. Door, window and
    furniture changes must not rebuild surrounding terrain chunks. }
  for I := 0 to High(FBuildings) do
  begin
    for J := 0 to High(FBuildings[I].FFloors) do
    begin
      LX := (FBuildings[I].FFloors[J] mod FSide) * 2 + 1 - FHalf;
      LZ := (FBuildings[I].FFloors[J] div FSide) * 2 + 1 - FHalf;
      if (LX >= AMinX - 8) and (LZ >= AMinZ - 8) and
        (LX <= AMaxX + 8) and (LZ <= AMaxZ + 8) then
      begin
        Result := Result + ':' + IntToStr(FBuildings[I].FFloors[J]) + ',' +
          IntToStr(FBuildings[I].FRoot.FY);
      end;
    end;
  end;
end;

end.
