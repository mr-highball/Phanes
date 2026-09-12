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

unit phanes.groundworks.geometry;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.world.height;

const
  GroundworkPlotHalfMetres = 16.0;
  GroundworkDeckHalfMetres = 8.0;
  GroundworkRampLengthMetres = 6.0;
  GroundworkRampHalfWidthMetres = 1.0;
  GroundworkLandingLengthMetres = 2.0;
  GroundworkSlabMetres = 0.18;
  GroundworkMaximumExposureMetres = 4.5;
  GroundworkMaximumCutMetres = 0.5;
  GroundworkMaximumGrade = 0.6;
  GroundworkApproachApronMetres = 0.28;
  GroundworkRailHalfMetres = 0.04;

type
  TGroundworkPurpose = (gpFoundation, gpLaunchPad);
  TGroundworkBody = (gbPlinth, gbPiers);

  { Immutable v1 geometry. All stored positions/elevations use millimetres.
    Quarter turns follow CGE: +Z becomes +X on a positive turn about +Y.
    Appearance and substructure identity do not change this support boundary. }
  TGroundworkGeometry = record
    FCellX: Integer;
    FCellZ: Integer;
    FX: Integer;
    FZ: Integer;
    FDeckY: Integer;
    FBottomY: Integer;
    FToeY: Integer;
    FQuarterTurn: Integer;
  end;

function GroundworkContext(const AWorld: TWorld; const ACellX, ACellZ: Integer;
  out AReason: String): Boolean;
function PlanGroundworkGeometry(const AWorld: TWorld; const ACellX, ACellZ, ATurn: Integer;
  var AGeometry: TGroundworkGeometry; out AReason: String): Boolean;
function ValidateGroundworkGeometry(const AWorld: TWorld; const AGeometry: TGroundworkGeometry;
  out AReason: String): Boolean;
procedure GroundworkToWorld(const AGeometry: TGroundworkGeometry; const AU, AV: Double;
  out AX, AZ: Double);
procedure GroundworkToLocal(const AGeometry: TGroundworkGeometry; const AX, AZ: Double;
  out AU, AV: Double);
function GroundworkHasSurface(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double): Boolean;
function GroundworkSurfaceHeight(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double; const AHeight: TWorldHeight = nil): Double;
function GroundworkSoilHeight(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double; const AHeight: TWorldHeight = nil): Double;
function GroundworkAllowsStanding(const AGeometry: TGroundworkGeometry;
  const AX, AZ, ARadius: Double): Boolean;
function GroundworkSoilPatch(const AGeometry: TGroundworkGeometry;
  const AX, AZ, APatchX, APatchZ: Double; const AHeight: TWorldHeight = nil): Double;

implementation

uses
  Math,
  SysUtils,
  phanes.world.elevation;

function GroundworkContext(const AWorld: TWorld; const ACellX, ACellZ: Integer;
  out AReason: String): Boolean;
var
  LX: Integer;
  LZ: Integer;
  LLayer: Integer;
  LIndex: Integer;
begin
  Result := False;
  AReason := '';
  if (AWorld.FSize < 4) or (AWorld.FSize > 48) then
  begin
    AReason := 'Groundworks require a world between 4 and 48 regional cells wide.';
    Exit;
  end;
  for LLayer := 0 to 4 do
  begin
    if Length(AWorld.FLayers[LLayer]) <> Sqr(LayerSize(AWorld.FSize, LLayer)) then
    begin
      AReason := 'Groundworks require complete regional layers.';
      Exit;
    end;
  end;
  { One clear cell around the visible 2 x 2 selection makes the admitted terrain
    field exact through the player's boundary apron. World-edge water counts.
    This initial profile restriction is not a statement of WFC impossibility. }
  if (ACellX < 1) or (ACellZ < 1) or
    (ACellX > AWorld.FSize - 3) or (ACellZ > AWorld.FSize - 3) then
  begin
    AReason := 'Leave one regional cell between this 2 x 2 plot and the world edge.';
    Exit;
  end;
  for LZ := ACellZ - 1 to ACellZ + 2 do
  begin
    for LX := ACellX - 1 to ACellX + 2 do
    begin
      LIndex := LZ * AWorld.FSize + LX;
      if AWorld.FLayers[0][LIndex] = 'water' then
      begin
        AReason := 'This groundwork profile needs dry land throughout the plot and its one-cell border.';
        Exit;
      end;
      if (AWorld.FLayers[3][LIndex] <> 'empty') or
        (AWorld.FLayers[1][LIndex] <> 'empty') then
      begin
        AReason := 'Clear regional buildings from the plot and its one-cell border first.';
        Exit;
      end;
    end;
  end;
  for LZ := ACellZ * 2 to ACellZ * 2 + 3 do
  begin
    for LX := ACellX * 2 to ACellX * 2 + 3 do
    begin
      LIndex := LZ * AWorld.FSize * 2 + LX;
      if (AWorld.FLayers[2][LIndex] <> 'empty') or
        (AWorld.FLayers[4][LIndex] <> 'empty') then
      begin
        AReason := 'Clear foliage and rocks from the selected 2 x 2 plot before adding groundworks.';
        Exit;
      end;
    end;
  end;
  { Composition-aware overlap/halo checks belong to the assembly adapter, which
    knows admitted plot profiles. This routine only certifies regional context. }
  Result := True;
end;

procedure GroundworkToWorld(const AGeometry: TGroundworkGeometry; const AU, AV: Double;
  out AX, AZ: Double);
begin
  case AGeometry.FQuarterTurn of
    0:
      begin
        AX := AU;
        AZ := AV;
      end;
    1:
      begin
        AX := AV;
        AZ := -AU;
      end;
    2:
      begin
        AX := -AU;
        AZ := -AV;
      end;
    3:
      begin
        AX := -AV;
        AZ := AU;
      end;
    else
      raise EArgumentException.Create('Groundwork orientation must be a quarter turn from 0 to 3.');
  end;
  AX := AX + AGeometry.FX / 1000;
  AZ := AZ + AGeometry.FZ / 1000;
end;

procedure GroundworkToLocal(const AGeometry: TGroundworkGeometry; const AX, AZ: Double;
  out AU, AV: Double);
var
  LX: Double;
  LZ: Double;
begin
  LX := AX - AGeometry.FX / 1000;
  LZ := AZ - AGeometry.FZ / 1000;
  case AGeometry.FQuarterTurn of
    0:
      begin
        AU := LX;
        AV := LZ;
      end;
    1:
      begin
        AU := -LZ;
        AV := LX;
      end;
    2:
      begin
        AU := -LX;
        AV := -LZ;
      end;
    3:
      begin
        AU := LZ;
        AV := -LX;
      end;
    else
      raise EArgumentException.Create('Groundwork orientation must be a quarter turn from 0 to 3.');
  end;
end;

procedure LocalTerrainBounds(const AGeometry: TGroundworkGeometry;
  const AMinU, AMinV, AMaxU, AMaxV: Double; const AHeight: TWorldHeight;
  out AMinimum, AMaximum: Double);
var
  LX1: Double;
  LZ1: Double;
  LX2: Double;
  LZ2: Double;
begin
  GroundworkToWorld(AGeometry, AMinU, AMinV, LX1, LZ1);
  GroundworkToWorld(AGeometry, AMaxU, AMaxV, LX2, LZ2);
  AHeight.Bounds(Min(LX1, LX2), Min(LZ1, LZ2),
    Max(LX1, LX2), Max(LZ1, LZ2), AMinimum, AMaximum);
end;

function GroundworkHasSurface(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double): Boolean;
var
  LU: Double;
  LV: Double;
begin
  GroundworkToLocal(AGeometry, AX, AZ, LU, LV);
  Result := ((Abs(LU) <= GroundworkDeckHalfMetres) and
    (Abs(LV) <= GroundworkDeckHalfMetres)) or
    ((Abs(LU) <= GroundworkRampHalfWidthMetres) and
    (LV >= GroundworkDeckHalfMetres) and (LV <= GroundworkPlotHalfMetres));
end;

function GroundworkSurfaceHeight(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double; const AHeight: TWorldHeight): Double;
var
  LU: Double;
  LV: Double;
  LWeight: Double;
  LToe: Double;
begin
  Result := TerrainBaseHeight(AX, AZ);
  if AHeight <> nil then
  begin
    Result := AHeight.Height(AX, AZ);
  end;
  GroundworkToLocal(AGeometry, AX, AZ, LU, LV);
  if (Abs(LU) <= GroundworkDeckHalfMetres) and
    (Abs(LV) <= GroundworkDeckHalfMetres) then
  begin
    Exit(AGeometry.FDeckY / 1000);
  end;
  if (Abs(LU) > GroundworkRampHalfWidthMetres) or
    (LV < GroundworkDeckHalfMetres) or (LV >= GroundworkPlotHalfMetres) then
  begin
    Exit;
  end;
  LToe := AGeometry.FToeY / 1000;
  if LV <= GroundworkDeckHalfMetres + GroundworkRampLengthMetres then
  begin
    LWeight := (LV - GroundworkDeckHalfMetres) / GroundworkRampLengthMetres;
    Exit(AGeometry.FDeckY / 1000 * (1 - LWeight) + LToe * LWeight);
  end;
  { The entire outer edge meets the original terrain, not merely its midpoint.
    Both terrain value and derivative agree at the plot boundary. }
  LWeight := (LV - GroundworkDeckHalfMetres - GroundworkRampLengthMetres) /
    GroundworkLandingLengthMetres;
  LWeight := LWeight * LWeight * (3 - 2 * LWeight);
  Result := LToe * (1 - LWeight) + Result * LWeight;
end;

function GroundworkSoilHeight(const AGeometry: TGroundworkGeometry;
  const AX, AZ: Double; const AHeight: TWorldHeight): Double;
var
  LU: Double;
  LV: Double;
begin
  Result := TerrainBaseHeight(AX, AZ);
  if AHeight <> nil then
  begin
    Result := AHeight.Height(AX, AZ);
  end;
  GroundworkToLocal(AGeometry, AX, AZ, LU, LV);
  if (Abs(LU) > GroundworkRampHalfWidthMetres) or
    (LV < GroundworkDeckHalfMetres) or (LV >= GroundworkPlotHalfMetres) then
  begin
    Exit;
  end;
  if LV < GroundworkDeckHalfMetres + GroundworkRampLengthMetres then
  begin
    Result := Min(Result, GroundworkSurfaceHeight(AGeometry, AX, AZ, AHeight) - GroundworkSlabMetres);
  end
  else
  begin
    Result := GroundworkSurfaceHeight(AGeometry, AX, AZ, AHeight);
  end;
end;

function GroundworkAllowsStanding(const AGeometry: TGroundworkGeometry;
  const AX, AZ, ARadius: Double): Boolean;
var
  LU: Double;
  LV: Double;

  function HitsRail(const AU1, AV1, AU2, AV2: Double): Boolean;
  var
    LNearestU: Double;
    LNearestV: Double;
  begin
    LNearestU := Max(Min(AU1, AU2) - GroundworkRailHalfMetres,
      Min(Max(AU1, AU2) + GroundworkRailHalfMetres, LU));
    LNearestV := Max(Min(AV1, AV2) - GroundworkRailHalfMetres,
      Min(Max(AV1, AV2) + GroundworkRailHalfMetres, LV));
    Result := Sqr(LU - LNearestU) + Sqr(LV - LNearestV) <= Sqr(ARadius);
  end;

begin
  Result := False;
  if IsNan(AX) or IsNan(AZ) or IsInfinite(AX) or IsInfinite(AZ) or
    IsNan(ARadius) or IsInfinite(ARadius) or (ARadius < 0) or (ARadius > 1) then
  begin
    Exit;
  end;
  GroundworkToLocal(AGeometry, AX, AZ, LU, LV);
  { These seven axis-aligned rail segments are also the renderer's guard
    boundaries. Expand the complete square-ended rail/post rectangles by the
    player circle, including diagonal approaches to the landing exit posts.
    The pier underside requires visible infill. }
  Result := not (HitsRail(-8, -8, -8, 8) or HitsRail(8, -8, 8, 8) or
    HitsRail(-8, -8, 8, -8) or HitsRail(-8, 8, -1, 8) or HitsRail(1, 8, 8, 8) or
    HitsRail(-1, 8, -1, 16) or HitsRail(1, 8, 1, 16));
end;

function GroundworkSoilPatch(const AGeometry: TGroundworkGeometry;
  const AX, AZ, APatchX, APatchZ: Double; const AHeight: TWorldHeight): Double;
var
  LU: Double;
  LV: Double;
  LPatchU: Double;
  LPatchV: Double;
  LWeight: Double;
  LSurface: Double;
begin
  Result := TerrainBaseHeight(AX, AZ);
  if AHeight <> nil then
  begin
    Result := AHeight.Height(AX, AZ);
  end;
  GroundworkToLocal(AGeometry, APatchX, APatchZ, LPatchU, LPatchV);
  if (Abs(LPatchU) >= 1) or (LPatchV <= 8) or (LPatchV >= 16) then
  begin
    Exit;
  end;
  GroundworkToLocal(AGeometry, AX, AZ, LU, LV);
  if LPatchV < 14 then
  begin
    LWeight := (LV - 8) / 6;
    LSurface := (AGeometry.FDeckY * (1 - LWeight) + AGeometry.FToeY * LWeight) / 1000;
    Exit(Min(Result, LSurface - GroundworkSlabMetres));
  end;
  LWeight := Max(0, Min(1, (LV - 14) / 2));
  LWeight := LWeight * LWeight * (3 - 2 * LWeight);
  Result := AGeometry.FToeY / 1000 * (1 - LWeight) + Result * LWeight;
end;

function ValidateGroundworkGeometryAt(const AWorld: TWorld; const AGeometry: TGroundworkGeometry;
  const AHeight: TWorldHeight; out AReason: String): Boolean;
var
  LLow: Double;
  LHigh: Double;
  LToeX: Double;
  LToeZ: Double;
  LTop: Double;
  LToe: Double;
  LStart: Double;
  LEnd: Double;
  LRampLow: Double;
  LRampHigh: Double;
  LU: Double;
  LV: Double;
  LForwardDerivative: Double;
  LLateralDerivative: Double;
  LLandingDerivative: Double;
  LX1: Double;
  LZ1: Double;
  LX2: Double;
  LZ2: Double;
  LDX: Double;
  LDZ: Double;
  I: Integer;
  J: Integer;
begin
  Result := False;
  if not GroundworkContext(AWorld, AGeometry.FCellX, AGeometry.FCellZ, AReason) then
  begin
    Exit;
  end;
  if (AGeometry.FQuarterTurn < 0) or (AGeometry.FQuarterTurn > 3) or
    (AGeometry.FX <> (AGeometry.FCellX + 1) * 16000 - AWorld.FSize * 8000) or
    (AGeometry.FZ <> (AGeometry.FCellZ + 1) * 16000 - AWorld.FSize * 8000) then
  begin
    AReason := 'The groundwork frame does not match its selected 2 x 2 plot.';
    Exit;
  end;
  LTop := AGeometry.FDeckY / 1000;
  LToe := AGeometry.FToeY / 1000;
  LocalTerrainBounds(AGeometry, -8, -8, 8, 8, AHeight, LLow, LHigh);
  if (LTop < LHigh + 0.199999) or (LTop > LHigh + 0.201001) or
    (AGeometry.FBottomY / 1000 > LLow - 0.099999) or
    (AGeometry.FBottomY / 1000 < LLow - 0.101001) then
  begin
    AReason := 'Deck and substructure elevations do not meet the admitted terrain envelope.';
    Exit;
  end;
  if (LTop - LLow > GroundworkMaximumExposureMetres) or
    (LTop < WorldStandingMinimumMetres + 0.001) then
  begin
    AReason := 'This plot needs taller supports than this groundwork profile admits.';
    Exit;
  end;
  GroundworkToWorld(AGeometry, 0, 14, LToeX, LToeZ);
  if Abs(LToe - AHeight.Height(LToeX, LToeZ)) > 0.000501 then
  begin
    AReason := 'The access toe must meet the measured terrain to the nearest millimetre.';
    Exit;
  end;
  if (LToe < WorldStandingMinimumMetres + 0.001) or
    (Abs(LTop - LToe) / GroundworkRampLengthMetres > GroundworkMaximumGrade) then
  begin
    AReason := 'This access direction is submerged or too steep for the current walking profile.';
    Exit;
  end;
  { Check the complete landing and radius apron. Subdivision tightens the
    conservative sine intervals; it never substitutes point samples for bounds. }
  for I := 0 to 11 do
  begin
    for J := 0 to 10 do
    begin
      LU := -1.28 + I * (2.56 / 12);
      LV := 14 + J * (2.28 / 11);
      LocalTerrainBounds(AGeometry, LU, LV, LU + 2.56 / 12, LV + 2.28 / 11,
        AHeight, LLow, LHigh);
      if LLow < WorldStandingMinimumMetres + 0.001 then
      begin
        AReason := 'The full access landing and player clearance must remain above water.';
        Exit;
      end;
    end;
  end;
  { Bound both one-sided field slopes over the entire landing and apron.
    A two-metre smoothstep has ds/dv <= .75. Toe rounding <= .000501m;
    lateral distance on the graded surface <= 1m. }
  GroundworkToWorld(AGeometry, -1.28, 14, LX1, LZ1);
  GroundworkToWorld(AGeometry, 1.28, 16.28, LX2, LZ2);
  AHeight.GradientBounds(Min(LX1, LX2), Min(LZ1, LZ2),
    Max(LX1, LX2), Max(LZ1, LZ2), LDX, LDZ);
  LForwardDerivative := LDZ;
  LLateralDerivative := LDX;
  if Odd(AGeometry.FQuarterTurn) then
  begin
    LForwardDerivative := LDX;
    LLateralDerivative := LDZ;
  end;
  LLandingDerivative := 0.75 * (2 * LForwardDerivative + LLateralDerivative + 0.000501) +
    LForwardDerivative;
  if Sqrt(Sqr(LLandingDerivative) + Sqr(LLateralDerivative)) > GroundworkMaximumGrade then
  begin
    AReason := 'The landing gradient exceeds the current walking profile.';
    Exit;
  end;
  { Whole ramp rectangles prove both excavation and exposed support limits.
    A planar ramp's extrema occur at its longitudinal endpoints. }
  for I := 0 to 7 do
  begin
    for J := 0 to 23 do
    begin
      LU := -1 + I * 0.25;
      LV := 8 + J * 0.25;
      LocalTerrainBounds(AGeometry, LU, LV, LU + 0.25, LV + 0.25, AHeight, LLow, LHigh);
      LStart := LTop + (LToe - LTop) * ((LV - 8) / 6);
      LEnd := LTop + (LToe - LTop) * ((LV + 0.25 - 8) / 6);
      LRampLow := Min(LStart, LEnd);
      LRampHigh := Max(LStart, LEnd);
      if LHigh - LRampLow + GroundworkSlabMetres > GroundworkMaximumCutMetres then
      begin
        AReason := 'This ramp direction would excavate more than half a metre of terrain.';
        Exit;
      end;
      if LRampHigh - LLow > GroundworkMaximumExposureMetres then
      begin
        AReason := 'This ramp direction would need unsupported height beyond the profile.';
        Exit;
      end;
    end;
  end;
  { Landing cut/fill <= |toe-base| and the expression is a convex blend.
    The global derivative envelope proves < .43m throughout the landing. }
  if 2 * LForwardDerivative + LLateralDerivative + 0.000501 > GroundworkMaximumCutMetres then
  begin
    AReason := 'Landing grading exceeds the profile allowance.';
    Exit;
  end;
  AReason := '';
  Result := True;
end;

function PlanGroundworkGeometryAt(const AWorld: TWorld; const ACellX, ACellZ, ATurn: Integer;
  const AHeight: TWorldHeight; var AGeometry: TGroundworkGeometry; out AReason: String): Boolean;
var
  LCandidate: TGroundworkGeometry;
  LLow: Double;
  LHigh: Double;
  LX: Double;
  LZ: Double;
begin
  Result := False;
  if not GroundworkContext(AWorld, ACellX, ACellZ, AReason) then
  begin
    Exit;
  end;
  if (ATurn < 0) or (ATurn > 3) then
  begin
    AReason := 'Choose one of the four cardinal access directions.';
    Exit;
  end;
  LCandidate := Default(TGroundworkGeometry);
  LCandidate.FCellX := ACellX;
  LCandidate.FCellZ := ACellZ;
  LCandidate.FX := (ACellX + 1) * 16000 - AWorld.FSize * 8000;
  LCandidate.FZ := (ACellZ + 1) * 16000 - AWorld.FSize * 8000;
  LCandidate.FQuarterTurn := ATurn;
  LocalTerrainBounds(LCandidate, -8, -8, 8, 8, AHeight, LLow, LHigh);
  LCandidate.FDeckY := Ceil((LHigh + 0.2) * 1000);
  LCandidate.FBottomY := Floor((LLow - 0.1) * 1000);
  GroundworkToWorld(LCandidate, 0, 14, LX, LZ);
  LCandidate.FToeY := Round(AHeight.Height(LX, LZ) * 1000);
  if not ValidateGroundworkGeometryAt(AWorld, LCandidate, AHeight, AReason) then
  begin
    Exit;
  end;
  AGeometry := LCandidate;
  Result := True;
end;

function ValidateGroundworkGeometry(const AWorld: TWorld; const AGeometry: TGroundworkGeometry;
  out AReason: String): Boolean;
var
  LHeight: TWorldHeight;
begin
  Result := False;
  if not ValidateWorldHeight(AWorld, AReason) then
  begin
    Exit;
  end;
  LHeight := TWorldHeight.Create(AWorld);
  try
    Result := ValidateGroundworkGeometryAt(AWorld, AGeometry, LHeight, AReason);
  finally
    LHeight.Free;
  end;
end;

function PlanGroundworkGeometry(const AWorld: TWorld; const ACellX, ACellZ, ATurn: Integer;
  var AGeometry: TGroundworkGeometry; out AReason: String): Boolean;
var
  LHeight: TWorldHeight;
begin
  Result := False;
  if not ValidateWorldHeight(AWorld, AReason) then
  begin
    Exit;
  end;
  LHeight := TWorldHeight.Create(AWorld);
  try
    Result := PlanGroundworkGeometryAt(AWorld, ACellX, ACellZ, ATurn, LHeight, AGeometry, AReason);
  finally
    LHeight.Free;
  end;
end;

end.
