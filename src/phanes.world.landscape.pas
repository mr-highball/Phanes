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

unit phanes.world.landscape;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.world.height,
  phanes.buildings.landscape,
  phanes.groundworks.assembly;

const
  WorldCellMetres = 16.0;
  WorldAssetScale = 2.0;
  PlayerEyeMetres = 1.68;
  PlayerRadiusMetres = 0.28;
  PlayerWalkMetresPerSecond = 3.2;
  PlayerRunMetresPerSecond = 5.6;
  WorldChunkCells = 4;
  DistantTerrainMaximumErrorMetres = 0.025;

type
  TLandscape = class
  private
    FWorld: TWorld;
    FHeight: TWorldHeight;
    FModular: TModularLandscape;
    FGroundworks: array of TGroundworkAssembly;
    FGroundworkCells: array of Integer;
    FGroundworkSignatures: array of String;
    procedure BuildGroundworks;
    function TerrainContactHeight(const AX, AZ: Double): Double;
  public
    destructor Destroy; override;
    procedure SetWorld(const AWorld: TWorld);
    function Cell(const AX, AZ: Double): Integer;
    function Height(const AX, AZ: Double): Double;
    function BaseHeight(const AX, AZ: Double): Double;
    function SoilHeight(const AX, AZ: Double): Double;
    function SoilPatchHeight(const AX, AZ, APatchX, APatchZ: Double): Double;
    function NeedsDetailedTerrain(const AMinX, AMinZ, AMaxX, AMaxZ: Double): Boolean;
    function GroundworkAt(const AX, AZ: Double): Integer;
    function GroundworkCount: Integer;
    function Groundwork(const AIndex: Integer): TGroundworkAssembly;
    function Kind(const AX, AZ: Double): String;
    function CanStand(const AX, AZ: Double): Boolean;
    function FindStanding(var AX, AZ: Double): Boolean;
    procedure Move(var AX, AZ: Double; const ADX, ADZ: Double);
    function ChunkSignature(const AX, AZ: Integer): String;
    property World: TWorld read FWorld;
    property Elevation: TWorldHeight read FHeight;
    property Modular: TModularLandscape read FModular;
  end;

implementation

uses
  Math,
  SysUtils,
  phanes.groundworks.geometry,
  phanes.structures.support,
  phanes.world.elevation,
  phanes.terrain.types,
  phanes.world.placement;

function Smooth(const AValue: Double): Double;
var
  LValue: Double;
begin
  LValue := Max(0, Min(1, AValue));
  Result := LValue * LValue * (3 - 2 * LValue);
end;

procedure TLandscape.BuildGroundworks;
var
  LAssembly: TGroundworkAssembly;
  LReason: String;
  LCount: Integer;
  LX: Integer;
  LZ: Integer;
  LSignature: String;
  I: Integer;
  J: Integer;
begin
  FGroundworks := nil;
  FGroundworkSignatures := nil;
  SetLength(FGroundworkCells, Sqr(FWorld.FSize));
  for I := 0 to High(FGroundworkCells) do
  begin
    FGroundworkCells[I] := -1;
  end;
  for I := 0 to High(FWorld.FComposition.FNodes) do
  begin
    if FWorld.FComposition.FNodes[I].FRole <> 'plot' then
    begin
      Continue;
    end;
    if not ReadGroundwork(FWorld, FWorld.FComposition.FNodes[I].FId, LAssembly, LReason) then
    begin
      raise Exception.Create('Cannot construct groundwork landscape: ' + LReason);
    end;
    LCount := Length(FGroundworks);
    SetLength(FGroundworks, LCount + 1);
    SetLength(FGroundworkSignatures, LCount + 1);
    FGroundworks[LCount] := LAssembly;
    LSignature := LAssembly.FId + ':' + IntToStr(Ord(LAssembly.FPurpose)) + ':' +
      IntToStr(Ord(LAssembly.FBody)) + ':' + IntToStr(LAssembly.FGeometry.FDeckY) + ':' +
      IntToStr(LAssembly.FGeometry.FBottomY) + ':' + IntToStr(LAssembly.FGeometry.FToeY) + ':' +
      IntToStr(LAssembly.FGeometry.FQuarterTurn) + ':' + LAssembly.FBuildingAsset;
    for J := 0 to 15 do
    begin
      LSignature := LSignature + ':' + IntToStr(Ord(LAssembly.FMaterials[J]));
    end;
    FGroundworkSignatures[LCount] := LSignature;
    for LZ := LAssembly.FGeometry.FCellZ to LAssembly.FGeometry.FCellZ + 1 do
    begin
      for LX := LAssembly.FGeometry.FCellX to LAssembly.FGeometry.FCellX + 1 do
      begin
        FGroundworkCells[LZ * FWorld.FSize + LX] := LCount;
      end;
    end;
  end;
end;

destructor TLandscape.Destroy;
begin
  FModular.Free;
  FHeight.Free;
  inherited Destroy;
end;

procedure TLandscape.SetWorld(const AWorld: TWorld);
var
  LPrepared: TLandscape;
begin
  LPrepared := TLandscape.Create;
  try
    LPrepared.FWorld := AWorld;
    LPrepared.FWorld.FElevation := CopyTerrainField(AWorld.FElevation);
    LPrepared.FHeight := TWorldHeight.Create(LPrepared.FWorld);
    LPrepared.BuildGroundworks;
    LPrepared.FModular := TModularLandscape.Create(LPrepared.FWorld);
    { Failed field or groundwork admission leaves the active landscape and its
      cached provider intact. Only a fully prepared candidate is published. }
    FHeight.Free;
    FHeight := LPrepared.FHeight;
    LPrepared.FHeight := nil;
    FWorld := LPrepared.FWorld;
    FGroundworks := LPrepared.FGroundworks;
    FGroundworkCells := LPrepared.FGroundworkCells;
    FGroundworkSignatures := LPrepared.FGroundworkSignatures;
    FModular.Free;
    FModular := LPrepared.FModular;
    LPrepared.FModular := nil;
  finally
    LPrepared.Free;
  end;
end;

function TLandscape.GroundworkCount: Integer;
begin
  Result := Length(FGroundworks);
end;

function TLandscape.Groundwork(const AIndex: Integer): TGroundworkAssembly;
begin
  Result := FGroundworks[AIndex];
end;

function TLandscape.GroundworkAt(const AX, AZ: Double): Integer;
var
  LCell: Integer;
begin
  LCell := Cell(AX, AZ);
  if LCell < 0 then
  begin
    Exit(-1);
  end;
  Result := FGroundworkCells[LCell];
end;

function TLandscape.Height(const AX, AZ: Double): Double;
var
  LSite: Integer;
begin
  LSite := FModular.At(AX, AZ);
  if LSite >= 0 then
  begin
    Exit(FModular.FloorHeight(LSite));
  end;
  LSite := GroundworkAt(AX, AZ);
  if LSite >= 0 then
  begin
    Exit(GroundworkSurfaceHeight(FGroundworks[LSite].FGeometry, AX, AZ, FHeight));
  end;
  Result := TerrainContactHeight(AX, AZ);
end;

function TLandscape.TerrainContactHeight(const AX, AZ: Double): Double;
var
  LX: Double;
  LZ: Double;
  LRight: Double;
  LFar: Double;
  LU: Double;
  LV: Double;
  L00: Double;
  L01: Double;
  L10: Double;
  L11: Double;
  LScale: Double;
begin
  LScale := 1;
  if FModular.ClearsVegetation(Floor(AX) + 0.5, Floor(AZ) + 0.5, 6.8) then
  begin
    LScale := 4;
  end;
  { Standing follows the rendered metre triangles, or quarter-metre triangles
    on a modular apron. Nonlinear shore/pad blends must be sampled at vertices
    before interpolation; evaluating the smooth function at the contact point
    can otherwise place the player far above or below the visible triangle. }
  LX := Floor(AX * LScale) / LScale;
  LZ := Floor(AZ * LScale) / LScale;
  LRight := Min(FWorld.FSize * 8, LX + 1 / LScale);
  LFar := Min(FWorld.FSize * 8, LZ + 1 / LScale);
  LU := (AX - LX) * LScale;
  LV := (AZ - LZ) * LScale;
  L00 := FModular.SoilHeight(LX, LZ, BaseHeight(LX, LZ));
  if (LU = 0) and (LV = 0) then
  begin
    Exit(L00);
  end;
  L01 := FModular.SoilHeight(LX, LFar, BaseHeight(LX, LFar));
  L10 := FModular.SoilHeight(LRight, LZ, BaseHeight(LRight, LZ));
  if LU + LV <= 1 then
  begin
    Result := L00 + (L10 - L00) * LU + (L01 - L00) * LV;
  end
  else
  begin
    L11 := FModular.SoilHeight(LRight, LFar, BaseHeight(LRight, LFar));
    Result := L11 + (L01 - L11) * (1 - LU) + (L10 - L11) * (1 - LV);
  end;
end;

function TLandscape.SoilHeight(const AX, AZ: Double): Double;
var
  LSite: Integer;
begin
  LSite := GroundworkAt(AX, AZ);
  if LSite >= 0 then
  begin
    Exit(GroundworkSoilHeight(FGroundworks[LSite].FGeometry, AX, AZ, FHeight));
  end;
  Result := TerrainContactHeight(AX, AZ);
end;

function TLandscape.SoilPatchHeight(const AX, AZ, APatchX, APatchZ: Double): Double;
var
  LSite: Integer;
begin
  LSite := GroundworkAt(APatchX, APatchZ);
  if LSite >= 0 then
  begin
    Exit(GroundworkSoilPatch(FGroundworks[LSite].FGeometry, AX, AZ, APatchX, APatchZ, FHeight));
  end;
  Result := TerrainContactHeight(AX, AZ);
end;

function TLandscape.NeedsDetailedTerrain(const AMinX, AMinZ, AMaxX, AMaxZ: Double): Boolean;
var
  LMinX: Integer;
  LMinZ: Integer;
  LMaxX: Integer;
  LMaxZ: Integer;
  LCenterX: Double;
  LCenterZ: Double;
  LRadius: Double;
  LWater: Boolean;
  I: Integer;
  J: Integer;
begin
  { Whole four-metre tiles touching a nonlinear shoreline or building pad
    keep the canonical metre mesh at distance. Plot and modular chunks have
    their own denser contact policy and never enter this distant path. }
  LMinX := Max(-1, Floor((AMinX - 11) / 16 + FWorld.FSize / 2));
  LMinZ := Max(-1, Floor((AMinZ - 11) / 16 + FWorld.FSize / 2));
  LMaxX := Min(FWorld.FSize, Floor((AMaxX + 11) / 16 + FWorld.FSize / 2));
  LMaxZ := Min(FWorld.FSize, Floor((AMaxZ + 11) / 16 + FWorld.FSize / 2));
  for J := LMinZ to LMaxZ do
  begin
    for I := LMinX to LMaxX do
    begin
      LWater := (I < 0) or (J < 0) or (I >= FWorld.FSize) or (J >= FWorld.FSize);
      LRadius := 0;
      if not LWater then
      begin
        LWater := FWorld.FLayers[0][J * FWorld.FSize + I] = 'water';
        if FWorld.FLayers[3][J * FWorld.FSize + I] <> 'empty' then
        begin
          LRadius := 8;
        end;
      end;
      if LWater then
      begin
        LRadius := 11;
      end;
      LCenterX := (I + 0.5 - FWorld.FSize / 2) * 16;
      LCenterZ := (J + 0.5 - FWorld.FSize / 2) * 16;
      if (LRadius > 0) and (AMinX < LCenterX + LRadius) and
        (AMaxX > LCenterX - LRadius) and (AMinZ < LCenterZ + LRadius) and
        (AMaxZ > LCenterZ - LRadius) then
      begin
        Exit(True);
      end;
    end;
  end;
  Result := False;
end;

function TLandscape.Cell(const AX, AZ: Double): Integer;
var
  LX: Integer;
  LZ: Integer;
begin
  LX := Floor(AX / WorldCellMetres + FWorld.FSize / 2);
  LZ := Floor(AZ / WorldCellMetres + FWorld.FSize / 2);
  if (LX < 0) or (LX >= FWorld.FSize) or (LZ < 0) or (LZ >= FWorld.FSize) then
  begin
    Exit(-1);
  end;
  Result := LZ * FWorld.FSize + LX;
end;

function TLandscape.Kind(const AX, AZ: Double): String;
var
  LCell: Integer;
begin
  LCell := Cell(AX, AZ);
  if LCell < 0 then
  begin
    Exit('water');
  end;
  Result := FWorld.FLayers[0][LCell];
end;

function TLandscape.BaseHeight(const AX, AZ: Double): Double;
var
  LX: Integer;
  LZ: Integer;
  LIndex: Integer;
  LCenterX: Double;
  LCenterZ: Double;
  LDistance: Double;
  LWeight: Double;
  LWater: Double;
  LFoundationWeight: Double;
  LFoundationHeight: Double;
  LIsWater: Boolean;
  I: Integer;
  J: Integer;
begin
  Result := FHeight.Height(AX, AZ);
  LX := Floor(AX / WorldCellMetres + FWorld.FSize / 2);
  LZ := Floor(AZ / WorldCellMetres + FWorld.FSize / 2);
  LWater := 0;
  LFoundationWeight := 0;
  LFoundationHeight := 0;
  for J := LZ - 1 to LZ + 1 do
  begin
    for I := LX - 1 to LX + 1 do
    begin
      LIndex := J * FWorld.FSize + I;
      LCenterX := (I + 0.5 - FWorld.FSize / 2) * WorldCellMetres;
      LCenterZ := (J + 0.5 - FWorld.FSize / 2) * WorldCellMetres;
      LDistance := Max(Abs(AX - LCenterX), Abs(AZ - LCenterZ));
      LIsWater := (I < 0) or (J < 0) or (I >= FWorld.FSize) or (J >= FWorld.FSize);
      if not LIsWater then
      begin
        LIsWater := FWorld.FLayers[0][LIndex] = 'water';
      end;
      if LIsWater then
      begin
        LWater := Min(1, LWater + 1 - Smooth((LDistance - 5) / 6));
      end
      else if FWorld.FLayers[3][LIndex] <> 'empty' then
      begin
        // Level the complete building footprint, smoothly meeting neighboring terrain.
        LWeight := 1 - Smooth((LDistance - 6.8) / 1.2);
        if LWeight > LFoundationWeight then
        begin
          LFoundationWeight := LWeight;
          LFoundationHeight := FHeight.Height(LCenterX, LCenterZ);
        end;
      end;
    end;
  end;
  Result := Result * (1 - LWater) - LWater * 1.2;
  Result := Result * (1 - LFoundationWeight) + LFoundationHeight * LFoundationWeight;
end;

function TLandscape.CanStand(const AX, AZ: Double): Boolean;
var
  LCell: Integer;
  LX: Double;
  LZ: Double;
  LCenterX: Double;
  LCenterZ: Double;
  LSide: Integer;
  LIndex: Integer;
  LValue: String;
  LRadius: Double;
  LSite: Integer;
  LCellX: Integer;
  LCellZ: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  if (Abs(AX) > FWorld.FSize * 8 - PlayerRadiusMetres) or
    (Abs(AZ) > FWorld.FSize * 8 - PlayerRadiusMetres) then
  begin
    Exit;
  end;
  LCell := Cell(AX, AZ);
  if (LCell < 0) or (Kind(AX, AZ) = 'water') or
    (Height(AX, AZ) < WorldStandingMinimumMetres) then
  begin
    Exit;
  end;
  LCellX := LCell mod FWorld.FSize;
  LCellZ := LCell div FWorld.FSize;
  if not FModular.AllowsStanding(AX, AZ, PlayerRadiusMetres) then
  begin
    Exit;
  end;
  { A regional cache avoids scanning all composition nodes on every movement
    sample. Adjacent cells include rail end caps beyond the plot boundary. }
  for J := Max(0, LCellZ - 1) to Min(FWorld.FSize - 1, LCellZ + 1) do
  begin
    for I := Max(0, LCellX - 1) to Min(FWorld.FSize - 1, LCellX + 1) do
    begin
      LSite := FGroundworkCells[J * FWorld.FSize + I];
      if (LSite >= 0) and not GroundworkAllowsStanding(FGroundworks[LSite].FGeometry,
        AX, AZ, PlayerRadiusMetres) then
      begin
        Exit;
      end;
      if LSite >= 0 then
      begin
        GroundworkToLocal(FGroundworks[LSite].FGeometry, AX, AZ, LX, LZ);
        if not BuildingAllowsStanding(FGroundworks[LSite].FBuildingAsset,
          LX, LZ, PlayerRadiusMetres) then
        begin
          Exit;
        end;
      end;
    end;
  end;
  if FWorld.FLayers[3][LCell] <> 'empty' then
  begin
    LX := (LCell mod FWorld.FSize + 0.5 - FWorld.FSize / 2) * WorldCellMetres;
    LZ := (LCell div FWorld.FSize + 0.5 - FWorld.FSize / 2) * WorldCellMetres;
    // Admitted exterior facades are closed. Conservative proxies include overhang clearance.
    LRadius := 6.05;
    if FWorld.FLayers[3][LCell] = 'cabin' then
    begin
      LRadius := 5.10;
    end;
    if FWorld.FLayers[3][LCell] = 'keep' then
    begin
      LRadius := 7.05;
    end;
    if FWorld.FLayers[3][LCell] = 'rocket' then
    begin
      LRadius := 3.65;
    end;
    if (Abs(AX - LX) < LRadius + PlayerRadiusMetres) and
      (Abs(AZ - LZ) < LRadius + PlayerRadiusMetres) then
    begin
      Exit;
    end;
  end;
  LSide := FWorld.FSize * 2;
  for J := Floor(AZ / 8 + LSide / 2) - 1 to Floor(AZ / 8 + LSide / 2) + 1 do
  begin
    for I := Floor(AX / 8 + LSide / 2) - 1 to Floor(AX / 8 + LSide / 2) + 1 do
    begin
      if (I < 0) or (J < 0) or (I >= LSide) or (J >= LSide) then
      begin
        Continue;
      end;
      LIndex := J * LSide + I;
      LValue := FWorld.FLayers[2][LIndex];
      LCenterX := (I + 0.5 - LSide / 2) * 8;
      LCenterZ := (J + 0.5 - LSide / 2) * 8;
      if FModular.ClearsVegetation(LCenterX, LCenterZ, 4) then
      begin
        Continue;
      end;
      if LValue = 'rock' then
      begin
        if RockBlocks(FWorld.FLayers[4][LIndex], LIndex, AX - LCenterX,
          AZ - LCenterZ, PlayerRadiusMetres) then
        begin
          Exit;
        end;
        Continue;
      end;
      LRadius := 0;
      if LValue = 'tree' then
      begin
        LRadius := TreeCollisionRadius(FWorld.FLayers[4][LIndex]) * VegetationScale(LIndex, 0);
      end;
      if LRadius = 0 then
      begin
        Continue;
      end;
      if Sqr(AX - LCenterX) + Sqr(AZ - LCenterZ) < Sqr(LRadius + PlayerRadiusMetres) then
      begin
        Exit;
      end;
    end;
  end;
  Result := True;
end;

function TLandscape.FindStanding(var AX, AZ: Double): Boolean;
var
  LX: Double;
  LZ: Double;
  LBest: Double;
  LBestX: Double;
  LBestZ: Double;
  LDistance: Double;
  I: Integer;
  J: Integer;
begin
  Result := CanStand(AX, AZ);
  if Result then
  begin
    Exit;
  end;
  LBest := 1E30;
  LBestX := AX;
  LBestZ := AZ;
  for J := 0 to FWorld.FSize * 8 - 1 do
  begin
    for I := 0 to FWorld.FSize * 8 - 1 do
    begin
      LX := I * 2 + 1 - FWorld.FSize * 8;
      LZ := J * 2 + 1 - FWorld.FSize * 8;
      LDistance := Sqr(LX - AX) + Sqr(LZ - AZ);
      if (LDistance < LBest) and CanStand(LX, LZ) then
      begin
        LBest := LDistance;
        LBestX := LX;
        LBestZ := LZ;
        Result := True;
      end;
    end;
  end;
  if not Result then
  begin
    Exit;
  end;
  AX := LBestX;
  AZ := LBestZ;
end;

procedure TLandscape.Move(var AX, AZ: Double; const ADX, ADZ: Double);
var
  LSteps: Integer;
  LStepX: Double;
  LStepZ: Double;
  I: Integer;

  function StepAllowance(const AX0, AZ0, AX1, AZ1: Double): Double;
  begin
    Result := 0.02;
    if (FModular.At(AX0, AZ0) >= 0) or (FModular.At(AX1, AZ1) >= 0) then
    begin
      Result := 0.18;
    end;
  end;
begin
  // Substeps prevent tunneling even at the maximum clamped frame interval.
  LSteps := Max(1, Ceil(Sqrt(Sqr(ADX) + Sqr(ADZ)) / 0.12));
  LStepX := ADX / LSteps;
  LStepZ := ADZ / LSteps;
  for I := 1 to LSteps do
  begin
    if CanStand(AX + LStepX, AZ) and
      (Abs(Height(AX + LStepX, AZ) - Height(AX, AZ)) <=
      Abs(LStepX) * 0.75 + StepAllowance(AX, AZ, AX + LStepX, AZ)) then
    begin
      AX := AX + LStepX;
    end;
    if CanStand(AX, AZ + LStepZ) and
      (Abs(Height(AX, AZ + LStepZ) - Height(AX, AZ)) <=
      Abs(LStepZ) * 0.75 + StepAllowance(AX, AZ, AX, AZ + LStepZ)) then
    begin
      AZ := AZ + LStepZ;
    end;
  end;
end;

function TLandscape.ChunkSignature(const AX, AZ: Integer): String;
var
  LX: Integer;
  LZ: Integer;
  LSide: Integer;
  LScale: Integer;
  LSite: Integer;
  I: Integer;
begin
  Result := IntToStr(FWorld.FSize) + ':';
  Result := Result + FModular.Signature(AX * 64 - FWorld.FSize * 8,
    AZ * 64 - FWorld.FSize * 8, (AX + 1) * 64 - FWorld.FSize * 8,
    (AZ + 1) * 64 - FWorld.FSize * 8);
  if FHeight.HasField then
  begin
    Result := Result + 'height-v1:' + BoolToStr(FWorld.FRelativeElevation, True) + ':' +
      IntToStr(FWorld.FElevation.FSpec.FLevelStep) + ':';
    LSide := FWorld.FElevation.FSpec.FColumns;
    { Shared vertices on every edge and the grading/normal halo influence a
      chunk even when the five categorical layer arrays did not change. }
    for LZ := Max(0, (AZ * WorldChunkCells - 1) * 2) to
      Min(LSide - 1, ((AZ + 1) * WorldChunkCells + 1) * 2) do
    begin
      for LX := Max(0, (AX * WorldChunkCells - 1) * 2) to
        Min(LSide - 1, ((AX + 1) * WorldChunkCells + 1) * 2) do
      begin
        Result := Result + IntToStr(FWorld.FElevation.FLevels[LZ * LSide + LX]) + ',';
      end;
    end;
  end;
  // A one-cell halo covers terrain interpolation and leveled foundations at borders.
  for I := 0 to 4 do
  begin
    LScale := 1;
    if (I = 2) or (I = 4) then
    begin
      LScale := 2;
    end;
    LSide := FWorld.FSize * LScale;
    for LZ := Max(0, (AZ * WorldChunkCells - 1) * LScale) to
      Min(LSide - 1, ((AZ + 1) * WorldChunkCells + 1) * LScale - 1) do
    begin
      for LX := Max(0, (AX * WorldChunkCells - 1) * LScale) to
        Min(LSide - 1, ((AX + 1) * WorldChunkCells + 1) * LScale - 1) do
      begin
        Result := Result + FWorld.FLayers[I][LZ * LSide + LX] + '|';
        if I = 0 then
        begin
          LSite := FGroundworkCells[LZ * LSide + LX];
          if LSite >= 0 then
          begin
            Result := Result + FGroundworkSignatures[LSite] + '|';
          end;
        end;
      end;
    end;
  end;
end;

end.
