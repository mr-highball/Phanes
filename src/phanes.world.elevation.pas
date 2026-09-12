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

unit phanes.world.elevation;

{$mode delphi}
{$H+}

interface

const
  WorldWaterMetres = -0.4;
  WorldStandingMinimumMetres = 0.1;
  TerrainBoundsLimitMetres = 4096;

function TerrainBaseHeight(const AX, AZ: Double): Double;
function BuildingDatum(const ASize, AX, AZ: Integer): Double;
function DryBuildingDatum(const ASize, AX, AZ: Integer): Boolean;
procedure TerrainHeightBounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMinimum, AMaximum: Double);

implementation

uses
  Math,
  SysUtils;

function TerrainBaseHeight(const AX, AZ: Double): Double;
begin
  { The continuous landform remains independent of edit seed. This function is
    shared by generation and rendering so a dry role cannot hide a submerged
    physical building datum. It is an authored field, not WFC terrain geometry. }
  Result := 4 + 2.6 * Sin(AX * 0.035) + 1.8 * Cos(AZ * 0.041) +
    0.9 * Sin((AX + AZ) * 0.063);
end;

function BuildingDatum(const ASize, AX, AZ: Integer): Double;
begin
  Result := TerrainBaseHeight((AX + 0.5 - ASize / 2) * 16,
    (AZ + 0.5 - ASize / 2) * 16);
end;

function DryBuildingDatum(const ASize, AX, AZ: Integer): Boolean;
begin
  { Reserve one millimetre for the composition's integer elevation encoding.
    This only certifies the current level datum. Whole support envelopes,
    excavation depth and traversable approaches require additional constraints. }
  Result := BuildingDatum(ASize, AX, AZ) >= WorldStandingMinimumMetres + 0.001;
end;

procedure SineBounds(const AMinimum, AMaximum: Double;
  out ALow, AHigh: Double);
var
  LFirstPeak: Double;
  LFirstTrough: Double;
begin
  if AMaximum - AMinimum >= 2 * Pi then
  begin
    ALow := -1;
    AHigh := 1;
    Exit;
  end;
  ALow := Min(Sin(AMinimum), Sin(AMaximum));
  AHigh := Max(Sin(AMinimum), Sin(AMaximum));
  LFirstPeak := Ceil((AMinimum - Pi * 0.5) / (2 * Pi)) * (2 * Pi) + Pi * 0.5;
  LFirstTrough := Ceil((AMinimum + Pi * 0.5) / (2 * Pi)) * (2 * Pi) - Pi * 0.5;
  if LFirstPeak <= AMaximum then
  begin
    AHigh := 1;
  end;
  if LFirstTrough <= AMaximum then
  begin
    ALow := -1;
  end;
end;

procedure TerrainHeightBounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMinimum, AMaximum: Double);
var
  LLow: Double;
  LHigh: Double;
begin
  if IsNan(AMinX) or IsNan(AMinZ) or IsNan(AMaxX) or IsNan(AMaxZ) or
    IsInfinite(AMinX) or IsInfinite(AMinZ) or IsInfinite(AMaxX) or IsInfinite(AMaxZ) or
    (AMinX > AMaxX) or (AMinZ > AMaxZ) or
    (Abs(AMinX) > TerrainBoundsLimitMetres) or (Abs(AMaxX) > TerrainBoundsLimitMetres) or
    (Abs(AMinZ) > TerrainBoundsLimitMetres) or (Abs(AMaxZ) > TerrainBoundsLimitMetres) then
  begin
    raise EArgumentException.Create('Terrain bounds require an ordered rectangle within 4096 metres.');
  end;
  { Interval bounds include interior extrema; corner sampling alone misses
    them. Terms are bounded separately, so the range is conservative where
    their extrema occur at different positions. The epsilon covers rounding
    in both native and JavaScript evaluation over the supported world range. }
  SineBounds(AMinX * 0.035, AMaxX * 0.035, LLow, LHigh);
  AMinimum := 4 + 2.6 * LLow;
  AMaximum := 4 + 2.6 * LHigh;
  SineBounds(AMinZ * 0.041 + Pi * 0.5, AMaxZ * 0.041 + Pi * 0.5, LLow, LHigh);
  AMinimum := AMinimum + 1.8 * LLow;
  AMaximum := AMaximum + 1.8 * LHigh;
  SineBounds((AMinX + AMinZ) * 0.063, (AMaxX + AMaxZ) * 0.063, LLow, LHigh);
  AMinimum := AMinimum + 0.9 * LLow - 0.0000001;
  AMaximum := AMaximum + 0.9 * LHigh + 0.0000001;
end;

end.
