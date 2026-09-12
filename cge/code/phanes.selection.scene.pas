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

unit phanes.selection.scene;

{$mode delphi}
{$H+}

interface

uses
  Classes, FPJSON, CastleScene, phanes.world.landscape;

function CreateRegionOutline(const AOwner: TComponent; const ALandscape: TLandscape;
  const ASelection: TJSONObject): TCastleScene;

implementation

uses
  Math, CastleVectors, X3DNodes, phanes.world.elevation;

function CreateRegionOutline(const AOwner: TComponent; const ALandscape: TLandscape;
  const ASelection: TJSONObject): TCastleScene;
var
  LRoot: TX3DRootNode;
  LShape: TShapeNode;
  LMesh: TIndexedTriangleSetNode;
  LPoints: TCoordinateNode;
  LMaterial: TUnlitMaterialNode;
  LX: Double;
  LZ: Double;
  LWidth: Double;
  LDepth: Double;
  LBits: array of Boolean;
  LCells: TJSONArray;
  LScale: Integer;
  LSide: Integer;
  LCellX: Integer;
  LCellZ: Integer;
  LEdgeCount: Integer;
  LSteps: Integer;
  LPitch: Double;
  I: Integer;

  procedure Point(const AX, AZ: Double);
  var
    LHalf: Double;
  begin
    LHalf := ALandscape.World.FSize * WorldCellMetres / 2;
    LPoints.FdPoint.Items.Add(Vector3(AX,
      Max(WorldWaterMetres, ALandscape.Height(EnsureRange(AX, -LHalf, LHalf),
        EnsureRange(AZ, -LHalf, LHalf))) + 0.16, AZ));
  end;

  procedure Segment(const AX, AZ, ABX, ABZ: Double);
  var
    LAt: Integer;
    LDX: Double;
    LDZ: Double;
  begin
    LAt := LPoints.FdPoint.Items.Count;
    LDX := (ABZ - AZ) * 0.08 / Hypot(ABX - AX, ABZ - AZ);
    LDZ := -(ABX - AX) * 0.08 / Hypot(ABX - AX, ABZ - AZ);
    Point(AX - LDX, AZ - LDZ);
    Point(AX + LDX, AZ + LDZ);
    Point(ABX - LDX, ABZ - LDZ);
    Point(ABX + LDX, ABZ + LDZ);
    LMesh.FdIndex.Items.Add(LAt);
    LMesh.FdIndex.Items.Add(LAt + 1);
    LMesh.FdIndex.Items.Add(LAt + 2);
    LMesh.FdIndex.Items.Add(LAt + 2);
    LMesh.FdIndex.Items.Add(LAt + 1);
    LMesh.FdIndex.Items.Add(LAt + 3);
  end;

  function Chosen(const AX, AZ: Integer): Boolean;
  begin
    Result := (AX >= 0) and (AZ >= 0) and (AX < LSide) and (AZ < LSide);
    if Result then
    begin
      Result := LBits[AZ * LSide + AX];
    end;
  end;

  procedure Edge(const AX, AZ, ABX, ABZ: Double);
  var
    J: Integer;
  begin
    for J := 0 to LSteps - 1 do
    begin
      Segment(AX + (ABX - AX) * J / LSteps, AZ + (ABZ - AZ) * J / LSteps,
        AX + (ABX - AX) * (J + 1) / LSteps, AZ + (ABZ - AZ) * (J + 1) / LSteps);
    end;
  end;

begin
  Result := TCastleScene.Create(AOwner);
  Result.Pickable := False;
  Result.Collides := False;
  Result.CastShadows := False;
  LRoot := TX3DRootNode.Create;
  LShape := TShapeNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LPoints := TCoordinateNode.Create;
  LMesh.Coord := LPoints;
  LMesh.Solid := False;
  LShape.Geometry := LMesh;
  LShape.Appearance := TAppearanceNode.Create;
  LMaterial := TUnlitMaterialNode.Create;
  LMaterial.EmissiveColor := Vector3(0.85, 0.96, 0.51);
  LShape.Appearance.Material := LMaterial;
  LRoot.AddChildren(LShape);
  if ASelection.Find('selectionCells') <> nil then
  begin
    LScale := ASelection.Get('selectionScale', 1);
    if not (LScale in [1, 2, 8]) then
    begin
      LScale := 1;
    end;
    LSide := ALandscape.World.FSize * LScale;
    SetLength(LBits, Sqr(LSide));
    LCells := ASelection.Arrays['selectionCells'];
    for I := 0 to LCells.Count - 1 do
    begin
      if (LCells.Integers[I] >= 0) and (LCells.Integers[I] < Length(LBits)) then
      begin
        LBits[LCells.Integers[I]] := True;
      end;
    end;
    LEdgeCount := 0;
    for LCellZ := 0 to LSide - 1 do
    begin
      for LCellX := 0 to LSide - 1 do
      begin
        if Chosen(LCellX, LCellZ) then
        begin
          Inc(LEdgeCount, Ord(not Chosen(LCellX - 1, LCellZ)) +
            Ord(not Chosen(LCellX + 1, LCellZ)) + Ord(not Chosen(LCellX, LCellZ - 1)) +
            Ord(not Chosen(LCellX, LCellZ + 1)));
        end;
      end;
    end;
    LPitch := WorldCellMetres / LScale;
    { Even the largest checkerboard keeps at most 32768 ribbon segments.
      Preserve every boundary; reduce height samples instead of hiding islands. }
    LSteps := EnsureRange(32768 div Max(1, LEdgeCount), 1, Round(LPitch));
    for LCellZ := 0 to LSide - 1 do
    begin
      for LCellX := 0 to LSide - 1 do
      begin
        if not Chosen(LCellX, LCellZ) then
        begin
          Continue;
        end;
        LX := (LCellX - LSide / 2) * LPitch;
        LZ := (LCellZ - LSide / 2) * LPitch;
        if not Chosen(LCellX - 1, LCellZ) then
        begin
          Edge(LX, LZ, LX, LZ + LPitch);
        end;
        if not Chosen(LCellX + 1, LCellZ) then
        begin
          Edge(LX + LPitch, LZ, LX + LPitch, LZ + LPitch);
        end;
        if not Chosen(LCellX, LCellZ - 1) then
        begin
          Edge(LX, LZ, LX + LPitch, LZ);
        end;
        if not Chosen(LCellX, LCellZ + 1) then
        begin
          Edge(LX, LZ + LPitch, LX + LPitch, LZ + LPitch);
        end;
      end;
    end;
    Result.Load(LRoot, True);
    Exit;
  end;
  { A single indexed ribbon replaces one scene/material per metre. Sampling
    at metre intervals preserves the terrain-following selection boundary. }
  LX := (ASelection.Integers['x'] - ALandscape.World.FSize / 2) * WorldCellMetres;
  LZ := (ASelection.Integers['z'] - ALandscape.World.FSize / 2) * WorldCellMetres;
  LWidth := ASelection.Integers['width'] * WorldCellMetres;
  LDepth := ASelection.Integers['depth'] * WorldCellMetres;
  for I := 0 to Round(LWidth) - 1 do
  begin
    Segment(LX + I, LZ, LX + I + 1, LZ);
    Segment(LX + I, LZ + LDepth, LX + I + 1, LZ + LDepth);
  end;
  for I := 0 to Round(LDepth) - 1 do
  begin
    Segment(LX, LZ + I, LX, LZ + I + 1);
    Segment(LX + LWidth, LZ + I, LX + LWidth, LZ + I + 1);
  end;
  Result.Load(LRoot, True);
end;

end.
