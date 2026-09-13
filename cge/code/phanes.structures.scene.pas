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

unit phanes.structures.scene;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  CastleTransform,
  phanes.world.appearance;

function CreateCabinShell(const AOwner: TComponent;
  const AAppearance: TWorldAppearance): TCastleTransform;
procedure UpdateCabinAppearance(const ARoot: TCastleTransform;
  const AAppearance: TWorldAppearance);

implementation

uses
  Math,
  SysUtils,
  CastleVectors,
  CastleRenderOptions,
  CastleScene,
  CastleTriangles,
  X3DNodes,
  phanes.structures.dimensions,
  phanes.interiors.materials;

type
  TCabinBox = class(TCastleBox)
  public
    FBaseColor: TVector4;
    FDetail: Integer;
    function CopySurface: TPhysicalMaterialNode;
  end;

  TCabinGable = class(TCastleScene)
  public
    FSurface: TPhysicalMaterialNode;
  end;

  TCabinBatch = class(TCastleScene)
  public
    FBaseColor: TVector4;
    FSurface: TPhysicalMaterialNode;
  end;

  TCabinBuilder = class
  private type
    TBoxGroup = record
      FColor: TVector4;
      FDetail: Integer;
      FRoot: TX3DRootNode;
      FMesh: TIndexedTriangleSetNode;
      FSurface: TPhysicalMaterialNode;
      FOriginal: TFloatVertexAttributeNode;
    end;
  private
    FRoot: TCastleTransform;
    FAppearance: TWorldAppearance;
    FGroups: array of TBoxGroup;
    FBatchGroup: Integer;
    FBatchMatrix: TMatrix4;
    FBatchColor: TVector3;
    procedure BatchTriangle(AShape: TObject; const APosition, ANormal: TTriangle3;
      const ATexCoord: TTriangle4; const AFace: TFaceIndex);
    procedure CollectBoxes(const ARoot: TCastleTransform; const AParent: TMatrix4);
    procedure BatchBoxes;
    function Box(const AParent: TCastleTransform; const ASize, APosition, AColor: TVector3;
      const ADetail: Integer; const AAlpha: Single = 1): TCabinBox;
    procedure WindowWall(const AYaw: Single; const AWindowWidth: Single);
    procedure Gable(const AZ: Single);
  public
    constructor Create(const ARoot: TCastleTransform; const AAppearance: TWorldAppearance);
    procedure Build;
  end;

procedure UpdateCabinAppearance(const ARoot: TCastleTransform;
  const AAppearance: TWorldAppearance);
var
  LColor: TVector4;
  I: Integer;
begin
  if ARoot is TCabinBox then
  begin
    LColor := TCabinBox(ARoot).FBaseColor;
    TCabinBox(ARoot).Color := Vector4(LColor.X * AAppearance.FTint.FR,
      LColor.Y * AAppearance.FTint.FG, LColor.Z * AAppearance.FTint.FB, LColor.W);
  end
  else if ARoot is TCabinGable then
  begin
    TCabinGable(ARoot).FSurface.BaseColor := Vector3(0.33 * AAppearance.FTint.FR,
      0.40 * AAppearance.FTint.FG, 0.31 * AAppearance.FTint.FB);
  end
  else if ARoot is TCabinBatch then
  begin
    LColor := TCabinBatch(ARoot).FBaseColor;
    TCabinBatch(ARoot).FSurface.BaseColor := Vector3(LColor.X * AAppearance.FTint.FR,
      LColor.Y * AAppearance.FTint.FG, LColor.Z * AAppearance.FTint.FB);
  end;
  for I := 0 to ARoot.Count - 1 do
  begin
    UpdateCabinAppearance(ARoot[I], AAppearance);
  end;
end;

constructor TCabinBuilder.Create(const ARoot: TCastleTransform;
  const AAppearance: TWorldAppearance);
begin
  inherited Create;
  FRoot := ARoot;
  FAppearance := AAppearance;
end;

function TCabinBox.CopySurface: TPhysicalMaterialNode;
begin
  Result := TPhysicalMaterialNode(ShapeNode.Appearance.Material.DeepCopy);
end;

function TCabinBuilder.Box(const AParent: TCastleTransform;
  const ASize, APosition, AColor: TVector3; const ADetail: Integer;
  const AAlpha: Single): TCabinBox;
var
  LPart: TCabinBox;
begin
  LPart := TCabinBox.Create(AParent);
  LPart.FBaseColor := Vector4(AColor.X, AColor.Y, AColor.Z, AAlpha);
  LPart.FDetail := ADetail;
  LPart.Size := ASize;
  LPart.Translation := APosition;
  LPart.Color := Vector4(AColor.X * FAppearance.FTint.FR,
    AColor.Y * FAppearance.FTint.FG, AColor.Z * FAppearance.FTint.FB, AAlpha);
  LPart.Material := pmPhysical;
  LPart.PreciseCollisions := True;
  LPart.SetEffects([InteriorDetail(ADetail, True)]);
  AParent.Add(LPart);
  Result := LPart;
end;

procedure TCabinBuilder.BatchTriangle(AShape: TObject;
  const APosition, ANormal: TTriangle3; const ATexCoord: TTriangle4;
  const AFace: TFaceIndex);
var
  LNormal: TVector3;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  { The cabin kit uses rigid rotations/translations. Bake only these static
    boxes; glass stays in its separate, sorted transparent draw. Preserve each
    box's original material coordinates while removing its per-frame draw. }
  LNormal := FBatchMatrix.MultDirection(APosition.Normal).Normalize;
  for I := 0 to 2 do
  begin
    LIndex := TCoordinateNode(FGroups[FBatchGroup].FMesh.Coord).FdPoint.Count;
    TCoordinateNode(FGroups[FBatchGroup].FMesh.Coord).FdPoint.Items.Add(
      FBatchMatrix.MultPoint(APosition.Data[I]));
    TNormalNode(FGroups[FBatchGroup].FMesh.Normal).FdVector.Items.Add(LNormal);
    TColorNode(FGroups[FBatchGroup].FMesh.Color).FdColor.Items.Add(FBatchColor);
    FGroups[FBatchGroup].FMesh.FdIndex.Items.Add(LIndex);
    for J := 0 to 2 do
    begin
      FGroups[FBatchGroup].FOriginal.FdValue.Items.Add(APosition.Data[I][J]);
    end;
  end;
end;

procedure TCabinBuilder.CollectBoxes(const ARoot: TCastleTransform; const AParent: TMatrix4);
var
  LPart: TCabinBox;
  LMatrix: TMatrix4;
  LShape: TShapeNode;
  LSurface: TAppearanceNode;
  I: Integer;
begin
  LMatrix := AParent * ARoot.Transform;
  if ARoot is TCabinBox then
  begin
    LPart := TCabinBox(ARoot);
    if LPart.FBaseColor.W < 1 then
    begin
      Exit;
    end;
    FBatchGroup := -1;
    for I := 0 to High(FGroups) do
    begin
      if FGroups[I].FDetail = LPart.FDetail then
      begin
        FBatchGroup := I;
        Break;
      end;
    end;
    if FBatchGroup < 0 then
    begin
      FBatchGroup := Length(FGroups);
      SetLength(FGroups, FBatchGroup + 1);
      FGroups[FBatchGroup].FColor := Vector4(1, 1, 1, 1);
      FGroups[FBatchGroup].FDetail := LPart.FDetail;
      FGroups[FBatchGroup].FRoot := TX3DRootNode.Create;
      LShape := TShapeNode.Create;
      FGroups[FBatchGroup].FRoot.AddChildren(LShape);
      FGroups[FBatchGroup].FMesh := TIndexedTriangleSetNode.Create;
      LShape.Geometry := FGroups[FBatchGroup].FMesh;
      FGroups[FBatchGroup].FMesh.Coord := TCoordinateNode.Create;
      FGroups[FBatchGroup].FMesh.Normal := TNormalNode.Create;
      FGroups[FBatchGroup].FMesh.Color := TColorNode.Create;
      { All opaque cabin boxes share the primitive's physical material defaults.
        Keep their authored colour at each vertex and the changeable world tint
        in the shared material; finish kind still separates shader groups. }
      FGroups[FBatchGroup].FMesh.Color.Mode := cmModulate;
      FGroups[FBatchGroup].FOriginal := TFloatVertexAttributeNode.Create;
      FGroups[FBatchGroup].FOriginal.NameField := 'phanesOriginalSurface';
      FGroups[FBatchGroup].FOriginal.NumComponents := 3;
      FGroups[FBatchGroup].FMesh.FdAttrib.Add(FGroups[FBatchGroup].FOriginal);
      FGroups[FBatchGroup].FSurface := LPart.CopySurface;
      FGroups[FBatchGroup].FSurface.BaseColor := Vector3(FAppearance.FTint.FR,
        FAppearance.FTint.FG, FAppearance.FTint.FB);
      LSurface := TAppearanceNode.Create;
      LSurface.Material := FGroups[FBatchGroup].FSurface;
      LShape.Appearance := LSurface;
    end;
    FBatchMatrix := LMatrix;
    FBatchColor := Vector3(LPart.FBaseColor.X, LPart.FBaseColor.Y, LPart.FBaseColor.Z);
    LPart.ColliderMesh(BatchTriangle);
    { Keep named doorway measurements and collision bounds intact. Only the
      visual submission moves into the immutable material group. }
    LPart.Visible := False;
    Exit;
  end;
  for I := 0 to ARoot.Count - 1 do
  begin
    CollectBoxes(ARoot[I], LMatrix);
  end;
end;

procedure TCabinBuilder.BatchBoxes;
var
  LScene: TCabinBatch;
  LRoot: TX3DRootNode;
  I: Integer;
begin
  try
    CollectBoxes(FRoot, TMatrix4.Identity);
    for I := 0 to High(FGroups) do
    begin
      LScene := TCabinBatch.Create(FRoot);
      LScene.FBaseColor := FGroups[I].FColor;
      LScene.FSurface := FGroups[I].FSurface;
      LRoot := FGroups[I].FRoot;
      FGroups[I].FRoot := nil;
      LScene.Load(LRoot, True);
      LScene.PreciseCollisions := True;
      LScene.SetEffects([InteriorDetail(FGroups[I].FDetail, True, True)]);
      FRoot.Add(LScene);
    end;
  finally
    for I := 0 to High(FGroups) do
    begin
      FGroups[I].FRoot.Free;
    end;
  end;
end;

procedure TCabinBuilder.WindowWall(const AYaw: Single; const AWindowWidth: Single);
const
  CSill = 0.95;
  COpeningHeight = 1.10;
var
  LWall: TCastleTransform;
  LSide: Single;
  LColor: TVector3;
  LWood: TVector3;
  I: Integer;
begin
  LWall := TCastleTransform.Create(FRoot);
  LWall.Rotation := Vector4(0, 1, 0, AYaw);
  FRoot.Add(LWall);
  LSide := (CabinOuterMetres - AWindowWidth) * 0.5;
  LColor := Vector3(0.58, 0.61, 0.52);
  LWood := Vector3(0.20, 0.25, 0.19);
  for I := 0 to 1 do
  begin
    Box(LWall, Vector3(LSide, CabinWallHeightMetres, CabinWallMetres),
      Vector3((I * 2 - 1) * (AWindowWidth + LSide) * 0.5,
      CabinFloorMetres + CabinWallHeightMetres * 0.5, 4.85), LColor, InteriorPlaster);
    Box(LWall, Vector3(0.09, COpeningHeight + 0.16, 0.37),
      Vector3((I * 2 - 1) * (AWindowWidth * 0.5 + 0.015),
      CabinFloorMetres + CSill + COpeningHeight * 0.5, 4.85), LWood, InteriorWood);
  end;
  Box(LWall, Vector3(AWindowWidth, CSill, CabinWallMetres),
    Vector3(0, CabinFloorMetres + CSill * 0.5, 4.85), LColor, InteriorPlaster);
  Box(LWall, Vector3(AWindowWidth, CabinWallHeightMetres - CSill - COpeningHeight,
    CabinWallMetres), Vector3(0, CabinFloorMetres +
    (CabinWallHeightMetres + CSill + COpeningHeight) * 0.5, 4.85),
    LColor, InteriorPlaster);
  for I := 0 to 1 do
  begin
    Box(LWall, Vector3(AWindowWidth + 0.18, 0.09, 0.42),
      Vector3(0, CabinFloorMetres + CSill + I * COpeningHeight, 4.88),
      LWood, InteriorWood);
  end;
  Box(LWall, Vector3(AWindowWidth - 0.07, COpeningHeight - 0.07, 0.018),
    Vector3(0, CabinFloorMetres + CSill + COpeningHeight * 0.5, 4.87),
    Vector3(0.23, 0.44, 0.48), InteriorCeramic, 0.42);
  Box(LWall, Vector3(0.055, COpeningHeight, 0.05),
    Vector3(0, CabinFloorMetres + CSill + COpeningHeight * 0.5, 4.90),
    LWood, InteriorWood);
end;

procedure TCabinBuilder.Gable(const AZ: Single);
const
  CIndices: array[0..23] of Integer =
    (0, 1, 2, 5, 4, 3, 0, 3, 4, 0, 4, 1, 1, 4, 5, 1, 5, 2, 2, 5, 3, 2, 3, 0);
var
  LPoints: TCoordinateNode;
  LMesh: TIndexedTriangleSetNode;
  LMaterial: TPhysicalMaterialNode;
  LSurface: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
  LScene: TCabinGable;
  LY: Single;
  LZ: Single;
  I: Integer;
begin
  LY := CabinFloorMetres + CabinWallHeightMetres;
  LPoints := TCoordinateNode.Create;
  for I := 0 to 1 do
  begin
    LZ := AZ + (1 - I * 2) * CabinWallMetres * 0.5;
    LPoints.FdPoint.Items.Add(Vector3(-5, LY, LZ));
    LPoints.FdPoint.Items.Add(Vector3(5, LY, LZ));
    LPoints.FdPoint.Items.Add(Vector3(0, LY + CabinRoofRiseMetres, LZ));
  end;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := LPoints;
  for I := Low(CIndices) to High(CIndices) do
  begin
    LMesh.FdIndex.Items.Add(CIndices[I]);
  end;
  LMaterial := TPhysicalMaterialNode.Create;
  LMaterial.BaseColor := Vector3(0.33 * FAppearance.FTint.FR,
    0.40 * FAppearance.FTint.FG, 0.31 * FAppearance.FTint.FB);
  LMaterial.Metallic := 0;
  LMaterial.Roughness := 0.70;
  LSurface := TAppearanceNode.Create;
  LSurface.Material := LMaterial;
  LShape := TShapeNode.Create;
  LShape.Geometry := LMesh;
  LShape.Appearance := LSurface;
  LRoot := TX3DRootNode.Create;
  LRoot.AddChildren(LShape);
  LScene := TCabinGable.Create(FRoot);
  LScene.Load(LRoot, True);
  LScene.FSurface := LMaterial;
  LScene.PreciseCollisions := True;
  LScene.SetEffects([InteriorDetail(InteriorWood, True)]);
  FRoot.Add(LScene);
end;

procedure TCabinBuilder.Build;
var
  LRoof: TCastleTransform;
  LRoofRun: Single;
  LRoofDrop: Single;
  LSide: Single;
  LWallColor: TVector3;
  LWood: TVector3;
  I: Integer;
  J: Integer;
begin
  LWallColor := Vector3(0.58, 0.61, 0.52);
  LWood := Vector3(0.20, 0.25, 0.19);
  Box(FRoot, Vector3(CabinOuterMetres, CabinFloorMetres, CabinOuterMetres),
    Vector3(0, CabinFloorMetres * 0.5, 0), Vector3(0.34, 0.28, 0.19), InteriorWood);
  WindowWall(Pi * 0.5, 2.2);
  WindowWall(Pi, 2.8);
  WindowWall(Pi * 1.5, 2.2);
  LSide := (CabinOuterMetres - CabinDoorWidthMetres) * 0.5;
  for I := 0 to 1 do
  begin
    Box(FRoot, Vector3(LSide, CabinWallHeightMetres, CabinWallMetres),
      Vector3((I * 2 - 1) * (CabinDoorWidthMetres + LSide) * 0.5,
      CabinFloorMetres + CabinWallHeightMetres * 0.5, 4.85), LWallColor, InteriorPlaster);
    Box(FRoot, Vector3(0.10, CabinDoorHeightMetres + 0.10, 0.40),
      Vector3((I * 2 - 1) * (CabinDoorWidthMetres * 0.5 + 0.05),
      CabinFloorMetres + CabinDoorHeightMetres * 0.5, 4.90),
      LWood, InteriorWood).Name := 'CabinDoorJamb' + IntToStr(I);
    for J := 0 to 1 do
    begin
      Box(FRoot, Vector3(0.16, CabinWallHeightMetres, 0.16),
        Vector3((I * 2 - 1) * 4.98, CabinFloorMetres + CabinWallHeightMetres * 0.5,
        (J * 2 - 1) * 4.98), LWood, InteriorWood);
    end;
  end;
  Box(FRoot, Vector3(CabinDoorWidthMetres,
    CabinWallHeightMetres - CabinDoorHeightMetres, CabinWallMetres),
    Vector3(0, CabinFloorMetres +
    (CabinWallHeightMetres + CabinDoorHeightMetres) * 0.5, 4.85),
    LWallColor, InteriorPlaster);
  Box(FRoot, Vector3(CabinDoorWidthMetres + 0.20, 0.10, 0.40),
    Vector3(0, CabinFloorMetres + CabinDoorHeightMetres + 0.05, 4.90),
    LWood, InteriorWood).Name := 'CabinDoorHeader';
  { The closed door is measured separately from the facade and its opening.
    Doorway traversal is a later interaction; no collision-free opening is claimed. }
  Box(FRoot, Vector3(CabinDoorWidthMetres - 0.045, CabinDoorHeightMetres - 0.025, 0.065),
    Vector3(0, CabinFloorMetres + CabinDoorHeightMetres * 0.5, 4.92),
    Vector3(0.22, 0.33, 0.29), InteriorWood).Name := 'CabinDoor';
  for I := 0 to 1 do
  begin
    Box(FRoot, Vector3(0.88, 0.73, 0.025),
      Vector3(0, CabinFloorMetres + 0.50 + I * 0.96, 4.96),
      Vector3(0.28, 0.38, 0.32), InteriorWood);
  end;
  Box(FRoot, Vector3(0.035, 0.18, 0.04),
    Vector3(0.43, CabinFloorMetres + 1.03, 5.0), Vector3(0.72, 0.60, 0.31), InteriorMetal);
  Gable(-4.85);
  Gable(4.85);
  LRoofRun := CabinOuterMetres * 0.5 + CabinRoofOverhangMetres;
  LRoofDrop := CabinRoofRiseMetres * LRoofRun / (CabinOuterMetres * 0.5);
  for I := 0 to 1 do
  begin
    LRoof := TCastleTransform.Create(FRoot);
    LRoof.Translation := Vector3((I * 2 - 1) * LRoofRun * 0.5,
      CabinFloorMetres + CabinWallHeightMetres + CabinRoofRiseMetres - LRoofDrop * 0.5, 0);
    LRoof.Rotation := Vector4(0, 0, 1, (1 - I * 2) * ArcTan2(LRoofDrop, LRoofRun));
    FRoot.Add(LRoof);
    Box(LRoof, Vector3(Sqrt(Sqr(LRoofRun) + Sqr(LRoofDrop)), 0.12,
      CabinOuterMetres + CabinRoofOverhangMetres * 2), Vector3(0, 0, 0),
      Vector3(0.16, 0.27, 0.24), InteriorMetal);
    for J := -10 to 10 do
    begin
      Box(LRoof, Vector3(Sqrt(Sqr(LRoofRun) + Sqr(LRoofDrop)), 0.028, 0.022),
        Vector3(0, 0.074, J * 0.52), Vector3(0.12, 0.21, 0.18), InteriorMetal);
    end;
    for J := 0 to 1 do
    begin
      Box(LRoof, Vector3(Sqrt(Sqr(LRoofRun) + Sqr(LRoofDrop)), 0.10, 0.06),
        Vector3(0, -0.005, (J * 2 - 1) * 5.27), LWood, InteriorWood);
    end;
  end;
end;

function CreateCabinShell(const AOwner: TComponent;
  const AAppearance: TWorldAppearance): TCastleTransform;
var
  LBuilder: TCabinBuilder;
begin
  Result := TCastleTransform.Create(AOwner);
  LBuilder := TCabinBuilder.Create(Result, AAppearance);
  try
    LBuilder.Build;
    LBuilder.BatchBoxes;
  finally
    LBuilder.Free;
  end;
end;

end.
