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

unit phanes.world.terrain;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  CastleScene,
  CastleVectors,
  phanes.world.landscape;

type
  TWorldTerrainScene = class(TCastleScene);

function BuildTerrain(const AOwner: TComponent; const ALandscape: TLandscape;
  const AChunkX, AChunkZ: Integer; const ADetail: Boolean): TCastleScene;
function TerrainColour(const ALandscape: TLandscape; const AX, AZ: Double): TVector3;

implementation

uses
  Math,
  CastleColors,
  CastleRenderOptions,
  X3DNodes,
  phanes.groundworks.geometry;

function KindColour(const AKind: String): TVector3;
begin
  Result := Vector3(0.23, 0.32, 0.115);
  if AKind = 'forest' then
  begin
    Result := Vector3(0.115, 0.21, 0.105);
  end
  else if AKind = 'field' then
  begin
    Result := Vector3(0.43, 0.32, 0.13);
  end
  else if AKind = 'stone' then
  begin
    Result := Vector3(0.34, 0.34, 0.29);
  end
  else if AKind = 'water' then
  begin
    Result := Vector3(0.29, 0.29, 0.19);
  end;
end;

function TerrainColour(const ALandscape: TLandscape; const AX, AZ: Double): TVector3;
var
  LX: Double;
  LZ: Double;
  LTX: Double;
  LTZ: Double;
  LNoise: Double;
  LColour: TVector3;
  I: Integer;
  J: Integer;
begin
  LX := Floor(AX / WorldCellMetres - 0.5) * WorldCellMetres + WorldCellMetres / 2;
  LZ := Floor(AZ / WorldCellMetres - 0.5) * WorldCellMetres + WorldCellMetres / 2;
  LTX := (AX - LX) / WorldCellMetres;
  LTZ := (AZ - LZ) / WorldCellMetres;
  Result := Vector3(0, 0, 0);
  for J := 0 to 1 do
  begin
    for I := 0 to 1 do
    begin
      LColour := KindColour(ALandscape.Kind(LX + I * WorldCellMetres, LZ + J * WorldCellMetres));
      Result := Result + LColour * (Abs(1 - I - LTX) * Abs(1 - J - LTZ));
    end;
  end;
  // Continuous multi-scale colour detail, authored independently of WFC terrain roles.
  LNoise := 0.92 + 0.10 * Sin(AX * 1.71 + Sin(AZ * 2.13)) +
    0.07 * Cos(AZ * 0.43 + Sin(AX * 0.55));
  Result := Result * LNoise;
  if ALandscape.SoilHeight(AX, AZ) < 0.8 then
  begin
    Result := Result * 0.55 + Vector3(0.22, 0.19, 0.115);
  end;
end;

function BuildTerrain(const AOwner: TComponent; const ALandscape: TLandscape;
  const AChunkX, AChunkZ: Integer; const ADetail: Boolean): TCastleScene;
var
  LRoot: TX3DRootNode;
  LShape: TShapeNode;
  LMesh: TIndexedTriangleSetNode;
  LPoints: TCoordinateNode;
  LNormals: TNormalNode;
  LColours: TColorNode;
  LUV: TTextureCoordinateNode;
  LTexture: TImageTextureNode;
  LMaterial: TPhysicalMaterialNode;
  LAppearance: TAppearanceNode;
  LStep: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LX: Double;
  LZ: Double;
  LX0: Double;
  LZ0: Double;
  LIndex: Integer;
  LSite: Integer;
  LLocalU: Double;
  LLocalV: Double;
  LPatchX: Double;
  LPatchZ: Double;
  LSubdivisions: Integer;
  LSubX: Integer;
  LSubZ: Integer;
  LSpacing: Double;
  LFarVertices: array of Integer;
  I: Integer;
  J: Integer;

  function ContactHeight(const AX, AZ: Double): Double;
  begin
    Result := ALandscape.Modular.SoilHeight(AX, AZ, ALandscape.BaseHeight(AX, AZ));
  end;

  function BaseNormal(const AX, AZ: Double): TVector3;
  var
    LHalf: Double;
    LLeft: Double;
    LRight: Double;
    LNear: Double;
    LFar: Double;
    LDX: Double;
    LDZ: Double;
  begin
    LHalf := ALandscape.World.FSize * 8;
    LLeft := Max(-LHalf, AX - 0.1);
    LRight := Min(LHalf, AX + 0.1);
    LNear := Max(-LHalf, AZ - 0.1);
    LFar := Min(LHalf, AZ + 0.1);
    { Stored fields have no implicit extrapolation. One-sided edge probes
      keep normals inside the saved frame; geometry uses its exact vertices. }
    LDX := (ContactHeight(LRight, AZ) - ContactHeight(LLeft, AZ)) /
      (LRight - LLeft);
    LDZ := (ContactHeight(AX, LFar) - ContactHeight(AX, LNear)) /
      (LFar - LNear);
    Result := Vector3(-LDX, 1, -LDZ).Normalize;
  end;

  procedure PatchPoint(const AX, AZ: Double);
  var
    LHalf: Double;
    LLeft: Double;
    LRight: Double;
    LNear: Double;
    LFar: Double;
    LDX: Double;
    LDZ: Double;
  begin
    LHalf := ALandscape.World.FSize * 8;
    LLeft := Max(-LHalf, AX - 0.1);
    LRight := Min(LHalf, AX + 0.1);
    LNear := Max(-LHalf, AZ - 0.1);
    LFar := Min(LHalf, AZ + 0.1);
    LDX := (ALandscape.SoilPatchHeight(LRight, AZ, LPatchX, LPatchZ) -
      ALandscape.SoilPatchHeight(LLeft, AZ, LPatchX, LPatchZ)) / (LRight - LLeft);
    LDZ := (ALandscape.SoilPatchHeight(AX, LFar, LPatchX, LPatchZ) -
      ALandscape.SoilPatchHeight(AX, LNear, LPatchX, LPatchZ)) / (LFar - LNear);
    LPoints.FdPoint.Items.Add(Vector3(AX,
      ALandscape.SoilPatchHeight(AX, AZ, LPatchX, LPatchZ), AZ));
    LNormals.FdVector.Items.Add(Vector3(-LDX, 1, -LDZ).Normalize);
    LColours.FdColor.Items.Add(TerrainColour(ALandscape, AX, AZ));
    LUV.FdPoint.Items.Add(Vector2(AX / 6, AZ / 6));
  end;

  function FarVertex(const AX, AZ: Integer): Integer;
  var
    LSlot: Integer;
    LWorldX: Double;
    LWorldZ: Double;
  begin
    LSlot := AZ * (LWidth * 4 + 1) + AX;
    if LFarVertices[LSlot] <> 0 then
    begin
      Exit(LFarVertices[LSlot] - 1);
    end;
    LWorldX := LX0 + AX;
    LWorldZ := LZ0 + AZ;
    Result := LPoints.FdPoint.Items.Count;
    LPoints.FdPoint.Items.Add(Vector3(LWorldX, ContactHeight(LWorldX, LWorldZ), LWorldZ));
    LNormals.FdVector.Items.Add(BaseNormal(LWorldX, LWorldZ));
    LColours.FdColor.Items.Add(TerrainColour(ALandscape, LWorldX, LWorldZ));
    LUV.FdPoint.Items.Add(Vector2(LWorldX / 6, LWorldZ / 6));
    LFarVertices[LSlot] := Result + 1;
  end;

  procedure FarTriangle(const ACenter, AX1, AZ1, AX2, AZ2: Integer);
  begin
    LMesh.FdIndex.Items.Add(ACenter);
    LMesh.FdIndex.Items.Add(FarVertex(AX1, AZ1));
    LMesh.FdIndex.Items.Add(FarVertex(AX2, AZ2));
  end;

  procedure FarTile(const AX, AZ: Integer);
  var
    LCenter: Integer;
    LX: Integer;
    LZ: Integer;
    K: Integer;
  begin
    if ALandscape.NeedsDetailedTerrain(LX0 + AX, LZ0 + AZ,
      LX0 + AX + 4, LZ0 + AZ + 4) then
    begin
      for LZ := AZ to AZ + 3 do
      begin
        for LX := AX to AX + 3 do
        begin
          FarTriangle(FarVertex(LX, LZ), LX, LZ + 1, LX + 1, LZ);
          FarTriangle(FarVertex(LX + 1, LZ), LX, LZ + 1, LX + 1, LZ + 1);
        end;
      end;
      Exit;
    end;
    { Every tile edge has the same metre vertices as a detailed neighbor,
      including transitions inside a chunk. The center fan stays within each
      saved anti-diagonal plane. Only the legacy analytic component introduces
      a bounded distant interpolation error (25mm policy); nonlinear blends
      use the exact detailed topology above. Shared indices avoid duplicate
      boundary storage. }
    LCenter := FarVertex(AX + 2, AZ + 2);
    for K := 0 to 3 do
    begin
      FarTriangle(LCenter, AX, AZ + K, AX, AZ + K + 1);
      FarTriangle(LCenter, AX + K, AZ + 4, AX + K + 1, AZ + 4);
      FarTriangle(LCenter, AX + 4, AZ + 4 - K, AX + 4, AZ + 3 - K);
      FarTriangle(LCenter, AX + 4 - K, AZ, AX + 3 - K, AZ);
    end;
  end;

begin
  LStep := 4;
  if ADetail then
  begin
    LStep := 1;
  end;
  LX0 := (AChunkX * WorldChunkCells - ALandscape.World.FSize / 2) * WorldCellMetres;
  LZ0 := (AChunkZ * WorldChunkCells - ALandscape.World.FSize / 2) * WorldCellMetres;
  if ALandscape.Modular.Signature(LX0, LZ0,
    LX0 + WorldChunkCells * WorldCellMetres, LZ0 + WorldChunkCells * WorldCellMetres) <> '' then
  begin
    LStep := 1;
  end;
  { Contact terrain survives placement LOD. A plot may cross into a neighboring
    chunk whose props are distant; its landing must retain the same soil mesh.
    Only chunks containing a persistent plot keep this metre grid at distance. }
  if LStep > 1 then
  begin
    for J := 0 to WorldChunkCells - 1 do
    begin
      for I := 0 to WorldChunkCells - 1 do
      begin
        if ALandscape.GroundworkAt(LX0 + (I + 0.5) * WorldCellMetres,
          LZ0 + (J + 0.5) * WorldCellMetres) >= 0 then
        begin
          LStep := 1;
        end;
      end;
    end;
  end;
  LWidth := Round(Min(WorldChunkCells, ALandscape.World.FSize - AChunkX * WorldChunkCells) *
    WorldCellMetres) div LStep;
  LDepth := Round(Min(WorldChunkCells, ALandscape.World.FSize - AChunkZ * WorldChunkCells) *
    WorldCellMetres) div LStep;
  LPoints := TCoordinateNode.Create;
  LNormals := TNormalNode.Create;
  LColours := TColorNode.Create;
  LUV := TTextureCoordinateNode.Create;
  LColours.Mode := cmModulate;
  if LStep = 4 then
  begin
    SetLength(LFarVertices, (LWidth * 4 + 1) * (LDepth * 4 + 1));
  end;
  for J := 0 to LDepth do
  begin
    for I := 0 to LWidth do
    begin
      LX := LX0 + I * LStep;
      LZ := LZ0 + J * LStep;
      LPoints.FdPoint.Items.Add(Vector3(LX, ContactHeight(LX, LZ), LZ));
      LNormals.FdVector.Items.Add(BaseNormal(LX, LZ));
      LColours.FdColor.Items.Add(TerrainColour(ALandscape, LX, LZ));
      LUV.FdPoint.Items.Add(Vector2(LX / 6, LZ / 6));
      if LStep = 4 then
      begin
        LFarVertices[J * 4 * (LWidth * 4 + 1) + I * 4] :=
          LPoints.FdPoint.Items.Count;
      end;
    end;
  end;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := LPoints;
  LMesh.Normal := LNormals;
  LMesh.Color := LColours;
  LMesh.TexCoord := LUV;
  for J := 0 to LDepth - 1 do
  begin
    for I := 0 to LWidth - 1 do
    begin
      if LStep = 4 then
      begin
        FarTile(I * 4, J * 4);
        Continue;
      end;
      LPatchX := LX0 + (I + 0.5) * LStep;
      LPatchZ := LZ0 + (J + 0.5) * LStep;
      LSite := ALandscape.GroundworkAt(LPatchX, LPatchZ);
      if (LSite < 0) and ALandscape.Modular.ClearsVegetation(LPatchX, LPatchZ, 6.8) then
      begin
        { Quarter-metre contact triangles retain the graded foundation apron
          in both detailed and distant chunks. Door edits reuse this mesh. }
        LSpacing := 0.25;
        for LSubZ := 0 to 3 do
        begin
          for LSubX := 0 to 3 do
          begin
            LX := LPatchX - 0.5 + LSubX * LSpacing;
            LZ := LPatchZ - 0.5 + LSubZ * LSpacing;
            LIndex := LPoints.FdPoint.Items.Count;
            PatchPoint(LX, LZ);
            PatchPoint(LX, LZ + LSpacing);
            PatchPoint(LX + LSpacing, LZ);
            PatchPoint(LX + LSpacing, LZ + LSpacing);
            LMesh.FdIndex.Items.Add(LIndex);
            LMesh.FdIndex.Items.Add(LIndex + 1);
            LMesh.FdIndex.Items.Add(LIndex + 2);
            LMesh.FdIndex.Items.Add(LIndex + 2);
            LMesh.FdIndex.Items.Add(LIndex + 1);
            LMesh.FdIndex.Items.Add(LIndex + 3);
          end;
        end;
        Continue;
      end;
      if LSite >= 0 then
      begin
        GroundworkToLocal(ALandscape.Groundwork(LSite).FGeometry, LPatchX, LPatchZ,
          LLocalU, LLocalV);
        if (Abs(LLocalU) < 1) and (LLocalV > 8) and (LLocalV < 16) then
        begin
          { Separate edges preserve retained cuts and the ramp underside step.
            The curved landing needs 12.5cm triangles: metre-wide chords could
            put the rendered surface nearly 3cm above the standing height. }
          LSubdivisions := 1;
          if LLocalV > 14 then
          begin
            LSubdivisions := 8;
          end;
          LSpacing := 1 / LSubdivisions;
          for LSubZ := 0 to LSubdivisions - 1 do
          begin
            for LSubX := 0 to LSubdivisions - 1 do
            begin
              LX := LPatchX - 0.5 + LSubX * LSpacing;
              LZ := LPatchZ - 0.5 + LSubZ * LSpacing;
              LIndex := LPoints.FdPoint.Items.Count;
              PatchPoint(LX, LZ);
              PatchPoint(LX, LZ + LSpacing);
              PatchPoint(LX + LSpacing, LZ);
              PatchPoint(LX + LSpacing, LZ + LSpacing);
              LMesh.FdIndex.Items.Add(LIndex);
              LMesh.FdIndex.Items.Add(LIndex + 1);
              LMesh.FdIndex.Items.Add(LIndex + 2);
              LMesh.FdIndex.Items.Add(LIndex + 2);
              LMesh.FdIndex.Items.Add(LIndex + 1);
              LMesh.FdIndex.Items.Add(LIndex + 3);
            end;
          end;
          Continue;
        end;
      end;
      LIndex := J * (LWidth + 1) + I;
      LMesh.FdIndex.Items.Add(LIndex);
      LMesh.FdIndex.Items.Add(LIndex + LWidth + 1);
      LMesh.FdIndex.Items.Add(LIndex + 1);
      LMesh.FdIndex.Items.Add(LIndex + 1);
      LMesh.FdIndex.Items.Add(LIndex + LWidth + 1);
      LMesh.FdIndex.Items.Add(LIndex + LWidth + 2);
    end;
  end;
  LMaterial := TPhysicalMaterialNode.Create;
  LMaterial.BaseColor := Vector3(1, 1, 1);
  LTexture := TImageTextureNode.Create;
  LTexture.SetUrl(['castle-data:/materials/leafy-grass-diffuse.jpg']);
  LMaterial.BaseTexture := LTexture;
  LTexture := TImageTextureNode.Create;
  LTexture.SetUrl(['castle-data:/materials/leafy-grass-normal.jpg']);
  LMaterial.NormalTexture := LTexture;
  LMaterial.NormalScale := 0.55;
  LMaterial.Metallic := 0;
  LMaterial.Roughness := 0.94;
  LAppearance := TAppearanceNode.Create;
  LAppearance.Material := LMaterial;
  LShape := TShapeNode.Create;
  LShape.Geometry := LMesh;
  LShape.Appearance := LAppearance;
  LRoot := TX3DRootNode.Create;
  LRoot.AddChildren(LShape);
  Result := TWorldTerrainScene.Create(AOwner);
  { This open contact mesh receives building shadows. It cannot form a closed
    stencil volume; avoid constructing silhouettes for thousands of soil faces. }
  Result.CastShadows := False;
  Result.Load(LRoot, True);
  Result.PreciseCollisions := True;
end;

end.
