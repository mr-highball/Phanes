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
unit phanes.world.placement;

{$mode delphi}
{$H+}

interface

function VegetationScale(const AIndex, AClusterIndex: Integer): Double;
function PlacementQuarterTurn(const AIndex, AClusterIndex: Integer): Integer;
function RockFootprint(const AAssetId: String; out AHalfX, AHalfZ: Double): Boolean;
function RockBlocks(const AAssetId: String; const AIndex: Integer;
  const AX, AZ, ARadius: Double): Boolean;
function TreeCollisionRadius(const AAssetId: String): Double;

implementation

uses
  Math, phanes.catalog.regional;

function VegetationScale(const AIndex, AClusterIndex: Integer): Double;
begin
  Result := 0.85 + ((AIndex * 17 + AClusterIndex * 13) mod 31) / 100;
end;

function PlacementQuarterTurn(const AIndex, AClusterIndex: Integer): Integer;
begin
  Result := (AIndex * 7 + AClusterIndex) mod 4;
end;

function TreeCollisionRadius(const AAssetId: String): Double;
var
  LRegional: TRegionalAssetAdmission;
begin
  if RegionalAssetAdmission(AAssetId, LRegional) and (LRegional.FRole = 'tree') then
  begin
    { A conservative circle contains the complete centered canopy rectangle.
      It remains valid at every admitted quarter turn and placement jitter. }
    Exit(Sqrt(Sqr(LRegional.FWidth / 2000) + Sqr(LRegional.FDepth / 2000)));
  end;
  { Measured normalized scene triangles through 2/0.85 metres, including
    triangle/height-plane intersections. Multiplication by the actual jitter
    then covers a two-metre player band at every admitted scale. Values round
    outward to millimetres. Oak includes roots; autumn includes low branches.
    Pine's dense low crown is closed, retaining a clear view around the tree.
    Fantasy tree has a single mixed primitive, so its entire low envelope is used. }
  if AAssetId = 'nature-kit/tree_oak' then
  begin
    Exit(1.566);
  end;
  if AAssetId = 'nature-kit/tree_pineRoundA' then
  begin
    Exit(2.401);
  end;
  if AAssetId = 'nature-kit/tree_default_fall' then
  begin
    Exit(0.973);
  end;
  if AAssetId = 'fantasy-town-kit/tree' then
  begin
    Exit(1.078);
  end;
  Result := 4;
end;

function RockFootprint(const AAssetId: String; out AHalfX, AHalfZ: Double): Boolean;
var
  LRegional: TRegionalAssetAdmission;
begin
  if RegionalAssetAdmission(AAssetId, LRegional) and (LRegional.FRole = 'rock') then
  begin
    AHalfX := LRegional.FWidth / 2000;
    AHalfZ := LRegional.FDepth / 2000;
    Exit(True);
  end;
  { Parent-local CGE bounds after centering and physical normalization, before
    placement jitter/yaw. Millimetre outward rounding covers float conversion.
    The renderer verifies these bounds when admitting a changed source model.
    These conservative rectangles include the entire rock, not only its feet. }
  Result := True;
  if AAssetId = 'nature-kit/rock_largeA' then
  begin
    AHalfX := 1.392;
    AHalfZ := 1.800;
  end
  else if AAssetId = 'space-kit/rock_crystals' then
  begin
    AHalfX := 1.600;
    AHalfZ := 1.508;
  end
  else
  begin
    AHalfX := 0;
    AHalfZ := 0;
    Result := False;
  end;
end;

function RockBlocks(const AAssetId: String; const AIndex: Integer;
  const AX, AZ, ARadius: Double): Boolean;
var
  LHalfX: Double;
  LHalfZ: Double;
  LSwap: Double;
  LScale: Double;
  LDX: Double;
  LDZ: Double;
begin
  if not RockFootprint(AAssetId, LHalfX, LHalfZ) then
  begin
    { Unknown future rock geometry is not safe to walk through. Catalog
      admission must supply and verify its profile before it is playable. }
    Exit(True);
  end;
  LScale := VegetationScale(AIndex, 0);
  if Odd(PlacementQuarterTurn(AIndex, 0)) then
  begin
    LSwap := LHalfX;
    LHalfX := LHalfZ;
    LHalfZ := LSwap;
  end;
  LDX := Max(0, Abs(AX) - LHalfX * LScale);
  LDZ := Max(0, Abs(AZ) - LHalfZ * LScale);
  Result := Sqr(LDX) + Sqr(LDZ) <= Sqr(ARadius);
end;

end.
