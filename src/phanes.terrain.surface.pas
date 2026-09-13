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

unit phanes.terrain.surface;

{$mode delphi}
{$H+}

interface

uses
  phanes.terrain.types;

const
  TerrainHeightToleranceMetres = 1E-7;

type
  { An admitted immutable snapshot. Queries are in metres, heights in metres,
    derivatives in metres/metre. There is no extrapolation outside its frame.
    Construction detaches the elevation array from caller-owned storage. }
  TTerrainSurface = class
  private
    FSpec: TTerrainSpec;
    FLevels: TTerrainLevels;
    procedure QueryCoordinates(const AX, AZ: Double; out AU, AV: Double);
    function PatchHeight(const AX, AZ: Integer; const AU, AV: Double): Double;
  public
    constructor Create(const AField: TTerrainField);
    function Height(const AX, AZ: Double): Double;
    procedure Bounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
      out AMinimum, AMaximum, AMaximumDX, AMaximumDZ: Double);
    property Spec: TTerrainSpec read FSpec;
  end;

implementation

uses
  Math,
  SysUtils,
  phanes.terrain.validate
  {$ifdef PAS2JS}
  , JS
  {$endif}
  ;

constructor TTerrainSurface.Create(const AField: TTerrainField);
var
  LReason: String;
begin
  inherited Create;
  if not ValidateTerrainField(AField, LReason) then
  begin
    raise EArgumentException.Create('Cannot construct terrain surface: ' + LReason);
  end;
  FSpec := AField.FSpec;
  FLevels := Copy(AField.FLevels, 0, Length(AField.FLevels));
end;

procedure TTerrainSurface.QueryCoordinates(const AX, AZ: Double; out AU, AV: Double);
begin
  {$ifdef PAS2JS}
  if not isNumber(AX) or not isNumber(AZ) then
  begin
    raise EArgumentException.Create('Terrain queries require numeric coordinates.');
  end;
  {$endif}
  if IsNan(AX) or IsNan(AZ) or IsInfinite(AX) or IsInfinite(AZ) or
    (AX < Double(FSpec.FOriginX) / 1000) or (AZ < Double(FSpec.FOriginZ) / 1000) or
    (AX > Double(FSpec.FOriginX + (FSpec.FColumns - 1) * FSpec.FSpacing) / 1000) or
    (AZ > Double(FSpec.FOriginZ + (FSpec.FRows - 1) * FSpec.FSpacing) / 1000) then
  begin
    raise EArgumentException.Create('Terrain queries must be finite and inside the saved frame.');
  end;
  { World comparisons above reject outside points. Clamp only the rounding
    introduced while normalizing an already-admitted point at an endpoint. }
  AU := Max(Double(0), Min(Double(FSpec.FColumns - 1),
    (AX - Double(FSpec.FOriginX) / 1000) / (Double(FSpec.FSpacing) / 1000)));
  AV := Max(Double(0), Min(Double(FSpec.FRows - 1),
    (AZ - Double(FSpec.FOriginZ) / 1000) / (Double(FSpec.FSpacing) / 1000)));
end;

function TTerrainSurface.PatchHeight(const AX, AZ: Integer; const AU, AV: Double): Double;
var
  LIndex: Integer;
  LH00: Double;
  LH10: Double;
  LH01: Double;
  LH11: Double;
begin
  LIndex := AZ * FSpec.FColumns + AX;
  LH00 := FLevels[LIndex] * FSpec.FLevelStep / 1000;
  LH10 := FLevels[LIndex + 1] * FSpec.FLevelStep / 1000;
  LH01 := FLevels[LIndex + FSpec.FColumns] * FSpec.FLevelStep / 1000;
  LH11 := FLevels[LIndex + FSpec.FColumns + 1] * FSpec.FLevelStep / 1000;
  if AU + AV <= 1 then
  begin
    Result := LH00 + (LH10 - LH00) * AU + (LH01 - LH00) * AV;
  end
  else
  begin
    Result := LH11 + (LH01 - LH11) * (1 - AU) + (LH10 - LH11) * (1 - AV);
  end;
end;

function TTerrainSurface.Height(const AX, AZ: Double): Double;
var
  LU: Double;
  LV: Double;
  LX: Integer;
  LZ: Integer;
begin
  QueryCoordinates(AX, AZ, LU, LV);
  LX := Min(FSpec.FColumns - 2, Floor(LU));
  LZ := Min(FSpec.FRows - 2, Floor(LV));
  Result := PatchHeight(LX, LZ, LU - LX, LV - LZ);
end;

procedure TTerrainSurface.Bounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMinimum, AMaximum, AMaximumDX, AMaximumDZ: Double);
const
  CCreaseTolerance = 1E-10;
var
  LMinU: Double;
  LMinV: Double;
  LMaxU: Double;
  LMaxV: Double;
  LU0: Double;
  LV0: Double;
  LU1: Double;
  LV1: Double;
  LHeight: Double;
  LScale: Double;
  LIndex: Integer;
  LX: Integer;
  LZ: Integer;

  procedure IncludePoint(const AU, AV: Double);
  begin
    if (AU < LU0) or (AU > LU1) or (AV < LV0) or (AV > LV1) then
    begin
      Exit;
    end;
    LHeight := PatchHeight(LX, LZ, AU, AV);
    AMinimum := Min(AMinimum, LHeight);
    AMaximum := Max(AMaximum, LHeight);
  end;

begin
  QueryCoordinates(AMinX, AMinZ, LMinU, LMinV);
  QueryCoordinates(AMaxX, AMaxZ, LMaxU, LMaxV);
  if (AMinX > AMaxX) or (AMinZ > AMaxZ) then
  begin
    raise EArgumentException.Create('Terrain bounds require an ordered rectangle.');
  end;
  AMinimum := TerrainMaximumElevationMm / 1000;
  AMaximum := -TerrainMaximumElevationMm / 1000;
  AMaximumDX := 0;
  AMaximumDZ := 0;
  LScale := FSpec.FLevelStep / FSpec.FSpacing;
  { Include both incident cells on a grid edge, even for a point or line.
    Normalizing decimal metre coordinates can move an exact stored crease
    a few ulps to one side. Expand only derivative admission by a tolerance;
    do not snap query points or expand the height polygon. }
  for LZ := Max(0, Ceil(LMinV - CCreaseTolerance) - 1) to
    Min(FSpec.FRows - 2, Floor(LMaxV + CCreaseTolerance)) do
  begin
    for LX := Max(0, Ceil(LMinU - CCreaseTolerance) - 1) to
      Min(FSpec.FColumns - 2, Floor(LMaxU + CCreaseTolerance)) do
    begin
      LU0 := Max(Double(0), LMinU - LX);
      LV0 := Max(Double(0), LMinV - LZ);
      LU1 := Min(Double(1), LMaxU - LX);
      LV1 := Min(Double(1), LMaxV - LZ);
      { Each clipped triangle is a convex polygon and its height is affine.
        Its extrema occur at rectangle corners or diagonal intersections.
        Sampling only the outer rectangle corners misses interior peaks. }
      IncludePoint(LU0, LV0);
      IncludePoint(LU0, LV1);
      IncludePoint(LU1, LV0);
      IncludePoint(LU1, LV1);
      IncludePoint(LU0, 1 - LU0);
      IncludePoint(LU1, 1 - LU1);
      IncludePoint(1 - LV0, LV0);
      IncludePoint(1 - LV1, LV1);
      LIndex := LZ * FSpec.FColumns + LX;
      if LU0 + LV0 <= 1 + CCreaseTolerance then
      begin
        AMaximumDX := Max(AMaximumDX, Abs(FLevels[LIndex + 1] - FLevels[LIndex]) * LScale);
        AMaximumDZ := Max(AMaximumDZ,
          Abs(FLevels[LIndex + FSpec.FColumns] - FLevels[LIndex]) * LScale);
      end;
      if LU1 + LV1 >= 1 - CCreaseTolerance then
      begin
        AMaximumDX := Max(AMaximumDX,
          Abs(FLevels[LIndex + FSpec.FColumns + 1] -
          FLevels[LIndex + FSpec.FColumns]) * LScale);
        AMaximumDZ := Max(AMaximumDZ,
          Abs(FLevels[LIndex + FSpec.FColumns + 1] - FLevels[LIndex + 1]) * LScale);
      end;
    end;
  end;
  { The extreme admitted slope can amplify cancellation near the 4096m
    coordinate limit. A tenth-micrometre outward allowance covers the bounded
    Double arithmetic without treating display geometry as contact evidence. }
  AMinimum := AMinimum - TerrainHeightToleranceMetres;
  AMaximum := AMaximum + TerrainHeightToleranceMetres;
  AMaximumDX := AMaximumDX + 1E-9;
  AMaximumDZ := AMaximumDZ + 1E-9;
end;

end.
