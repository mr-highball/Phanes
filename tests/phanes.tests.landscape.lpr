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

program PhanesLandscapeTests;
{$mode delphi}
{$H+}
uses
  SysUtils, Math, phanes.world.types, phanes.world.landscape, phanes.world.appearance,
  phanes.world.elevation,
  phanes.world.placement;
var
  GLandscape: TLandscape;
  GWorld: TWorld;
  GChecks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure EmptyWorld(const ASize: Integer);
var
  I: Integer;
  J: Integer;
begin
  GWorld := Default(TWorld);
  GWorld.FSize := ASize;
  for I := 0 to 4 do
  begin
    SetLength(GWorld.FLayers[I], Sqr(LayerSize(ASize, I)));
    for J := 0 to High(GWorld.FLayers[I]) do
    begin
      GWorld.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        GWorld.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
  GLandscape.SetWorld(GWorld);
end;

procedure CheckRockCollisions;
var
  LIndex: Integer;
  LX: Double;
  LZ: Double;
  LDX: Double;
  LDZ: Double;
  LSwap: Double;
  I: Integer;
  J: Integer;
begin
  for I := 0 to 3 do
  begin
    EmptyWorld(8);
    LIndex := 20 + I * 31;
    GWorld.FLayers[2][LIndex] := 'rock';
    GWorld.FLayers[4][LIndex] := 'nature-kit/rock_largeA';
    GLandscape.SetWorld(GWorld);
    LX := (LIndex mod 16 + 0.5 - 8) * 8;
    LZ := (LIndex div 16 + 0.5 - 8) * 8;
    Check(Abs(VegetationScale(LIndex, 0) - 1.15) < 0.000001,
      'Regression fixture uses maximum placed rock scale');
    LDX := -1.48;
    LDZ := -1.88;
    for J := 1 to I do
    begin
      LSwap := LDX;
      LDX := LDZ;
      LDZ := -LSwap;
    end;
    Check(not GLandscape.CanStand(LX + LDX, LZ + LDZ),
      'Measured visible mesh regression point blocks at every quarter turn');
    Check(GLandscape.CanStand(LX + 3, LZ), 'Clear space beside a boulder stays walkable');
    GWorld.FLayers[4][LIndex] := 'space-kit/rock_crystals';
    GLandscape.SetWorld(GWorld);
    Check(not GLandscape.CanStand(LX, LZ), 'Crystal center blocks');
    Check(GLandscape.CanStand(LX + 3, LZ), 'Clear space beside crystals stays walkable');
  end;
end;

procedure CheckTreeCollisions;
const
  CAssets: array[0..3] of String = ('nature-kit/tree_oak', 'nature-kit/tree_pineRoundA',
    'nature-kit/tree_default_fall', 'fantasy-town-kit/tree');
  CRadii: array[0..3] of Double = (1.566, 2.401, 0.973, 1.078);
var
  LX: Double;
  LZ: Double;
  LRadius: Double;
  I: Integer;
  J: Integer;
begin
  for I := 0 to 3 do
  begin
    for J := 0 to 30 do
    begin
      EmptyWorld(8);
      GWorld.FLayers[2][J + 48] := 'tree';
      GWorld.FLayers[4][J + 48] := CAssets[I];
      GLandscape.SetWorld(GWorld);
      LX := ((J + 48) mod 16 + 0.5 - 8) * 8;
      LZ := ((J + 48) div 16 + 0.5 - 8) * 8;
      LRadius := CRadii[I] * (0.85 + (((J + 48) * 17) mod 31) / 100);
      Check(not GLandscape.CanStand(LX + LRadius + 0.27, LZ),
        'Tree measured envelope includes player radius at every scale');
      Check(GLandscape.CanStand(LX + LRadius + 0.30, LZ),
        'Ground outside the tree envelope remains usable');
    end;
  end;
end;

procedure CheckElevation;
var
  LX: Double;
  LZ: Double;
  LLow: Double;
  LHigh: Double;
  LHeight: Double;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
  L: Integer;
begin
  Check(Abs(BuildingDatum(48, 43, 9) + 1.237868440) < 0.00000001,
    'Independent submerged meadow regression datum');
  Check(not DryBuildingDatum(48, 43, 9), 'A dry role cannot make this datum safe');
  Check(DryBuildingDatum(8, 3, 3), 'Measured cabin fixture has dry standing height');
  TerrainHeightBounds(-400, -400, 400, 400, LLow, LHigh);
  Check((Abs(LLow + 1.3) < 0.000001) and (Abs(LHigh - 9.3) < 0.000001),
    'Whole-period bound includes extrema between corners');
  for J := 0 to 47 do
  begin
    for I := 0 to 47 do
    begin
      LX := (I + 0.5 - 24) * 16;
      LZ := (J + 0.5 - 24) * 16;
      TerrainHeightBounds(LX - 7.4, LZ - 7.4, LX + 7.4, LZ + 7.4, LLow, LHigh);
      for K := 0 to 4 do
      begin
        for L := 0 to 4 do
        begin
          LHeight := TerrainBaseHeight(LX - 7.4 + K * 3.7, LZ - 7.4 + L * 3.7);
          Check((LHeight >= LLow) and (LHeight <= LHigh),
            'Continuous support envelope bounds contain independent samples');
        end;
      end;
    end;
  end;
  TerrainHeightBounds(-10, 25, -10, 25, LLow, LHigh);
  LHeight := TerrainBaseHeight(-10, 25);
  Check((Abs(LLow - LHeight) < 0.000001) and (Abs(LHigh - LHeight) < 0.000001),
    'Point range agrees with base field');
  LRejected := False;
  try
    TerrainHeightBounds(1, 0, -1, 0, LLow, LHigh);
  except
    on LException: EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Inverted terrain bounds rejected');
  LRejected := False;
  try
    TerrainHeightBounds(0, 0, 1E100, 0, LLow, LHigh);
  except
    on LException: EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Out-of-contract range rejected before integer extrema calculation');
end;

procedure Run;
var
  LX: Double;
  LZ: Double;
  LY: Double;
  LBefore: String;
  LAfter: String;
  LNear: String;
  LAppearance: TWorldAppearance;
  LReplay: TWorldAppearance;
  I: Integer;
  J: Integer;
begin
  CheckElevation;
  CheckRockCollisions;
  CheckTreeCollisions;
  for I := 0 to 127 do
  begin
    LAppearance := SolveWorldAppearance(I);
    Check(ValidWorldAppearance(LAppearance), 'WFC appearance meets independent constraints');
    LReplay := SolveWorldAppearance(I);
    Check((LAppearance.FPalette = LReplay.FPalette) and (LAppearance.FKey = LReplay.FKey) and
      (LAppearance.FAtmosphere = LReplay.FAtmosphere) and
      (LAppearance.FFinish = LReplay.FFinish), 'Appearance replay is deterministic');
  end;
  LAppearance.FPalette := 'ochre';
  LAppearance.FKey := 'silver';
  Check(not ValidWorldAppearance(LAppearance), 'Incompatible palette/light is rejected');
  EmptyWorld(12);
  Check(GLandscape.Cell(-96, -96) = 0, 'World origin maps to first cell');
  Check(GLandscape.Cell(96, 0) = -1, 'World upper edge is exclusive');
  Check(GLandscape.Cell(0, 0) = 78, 'Metre grid selects expected cell');
  Check(not GLandscape.CanStand(95.9, 0), 'Player radius stays within map');
  Check(Abs(PlayerEyeMetres - 1.68) < 0.00001, 'Shared eye height');
  Check(GLandscape.CanStand(0, 0), 'Clear land supports walking');
  for J := -80 to 80 do
  begin
    for I := -80 to 80 do
    begin
      Check(Abs(GLandscape.Height(I, J) - GLandscape.Height(I + 0.001, J)) < 0.01,
        'Continuous terrain has no regional height jumps');
    end;
  end;
  GWorld.FLayers[3][78] := 'city-kit-suburban/building-type-a';
  GWorld.FLayers[1][78] := 'modern';
  GWorld.FLayers[0][79] := 'water';
  GLandscape.SetWorld(GWorld);
  LY := GLandscape.Height(8, 8);
  for J := 2 to 14 do
  begin
    for I := 2 to 14 do
    begin
      Check(Abs(GLandscape.Height(I, J) - LY) < 0.001,
        'Complete building foundation stays level even beside water');
    end;
  end;
  Check(not GLandscape.CanStand(8, 8), 'Closed exterior blocks player');
  Check(not GLandscape.CanStand(24, 8), 'Water blocks player');
  LX := -2;
  LZ := 8;
  GLandscape.Move(LX, LZ, 30, 0);
  Check(LX < 1.8, 'Large movement cannot tunnel through house');
  Check(GLandscape.CanStand(LX, LZ), 'Collision stops outside proxy');
  LX := 8;
  LZ := 8;
  Check(GLandscape.FindStanding(LX, LZ), 'Embedded spawn finds clear ground');
  Check(GLandscape.CanStand(LX, LZ), 'Recovered spawn is valid');
  EmptyWorld(48);
  LBefore := GLandscape.ChunkSignature(10, 10);
  LNear := GLandscape.ChunkSignature(0, 0);
  GWorld.FLayers[0][0] := 'field';
  GLandscape.SetWorld(GWorld);
  LAfter := GLandscape.ChunkSignature(10, 10);
  Check(LBefore = LAfter, 'Distant chunk retained after local edit');
  Check(LNear <> GLandscape.ChunkSignature(0, 0), 'Edited chunk invalidated');
  LNear := GLandscape.ChunkSignature(1, 0);
  GWorld.FLayers[0][3] := 'forest';
  GLandscape.SetWorld(GWorld);
  Check(LNear <> GLandscape.ChunkSignature(1, 0), 'Neighbor halo invalidated');
  EmptyWorld(4);
  for I := 0 to High(GWorld.FLayers[0]) do
  begin
    GWorld.FLayers[0][I] := 'water';
  end;
  GLandscape.SetWorld(GWorld);
  LX := 0;
  LZ := 0;
  Check(not GLandscape.FindStanding(LX, LZ), 'All-water world has no fake safe spawn');
end;

begin
  GLandscape := TLandscape.Create;
  try
    Run;
    WriteLn(GChecks, ' landscape checks passed');
  finally
    GLandscape.Free;
  end;
end.
