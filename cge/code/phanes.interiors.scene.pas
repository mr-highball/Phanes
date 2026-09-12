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
unit phanes.interiors.scene;
{$mode delphi}
{$H+}

interface

uses
  Classes,
  CastleTransform,
  CastleScene,
  CastleVectors,
  CastleBoxes,
  phanes.composition.types,
  phanes.composition.document,
  phanes.spaces.geometry;

type
  TInteriorAssetLoader = function(const AId: String): TCastleScene of object;

  TInteriorScene = class(TCastleTransform)
  private
    FDocument: TCompositionDocument;
    FIndex: TCompositionIndex;
    FRoomId: String;
    FInstances: array of TCastleTransform;
    FCache: TStringList;
    FCacheOwner: TComponent;
    FLoadAsset: TInteriorAssetLoader;
    FOutline: TCastleTransform;
    FOutlineBounds: TBox3D;
    FOutlineStroke: Single;
    FIsPlan: Boolean;
    FRoomWidth: Single;
    FRoomDepth: Single;
    FWalls: TSpaceWalls;
    FFullWalls: TCastleTransform;
    FCutWalls: TCastleTransform;
    function Model(const AId: String): TCastleTransform;
    function Instance(const ANode: Integer): TCastleTransform;
    procedure BuildPlanWalls(const APlan: TCompositionNode);
  public
    constructor CreateInterior(const AOwner, ACacheOwner: TComponent;
      const ACache: TStringList; const ALoadAsset: TInteriorAssetLoader;
      const ADocument: TCompositionDocument; const ARoomId: String);
    destructor Destroy; override;
    function BoundsFor(const AId: String): TBox3D;
    function Pick(const AOrigin, ADirection: TVector3): String;
    function CanStand(const AX, AZ: Double): Boolean;
    function FindStanding(var AX, AZ: Double): Boolean;
    procedure SetWalkView(const AWalking: Boolean);
    procedure Select(const AId: String);
    procedure UpdateSelectionStroke(const AThickness: Single);
    property SelectionBounds: TBox3D read FOutlineBounds;
  end;

function CreateInteriorModel(const AId: String; const ACacheOwner: TComponent;
  const ACache: TStringList; const ALoadAsset: TInteriorAssetLoader): TCastleTransform;

implementation

uses
  SysUtils,
  Math,
  CastleColors,
  CastleShapes,
  CastleRenderOptions,
  X3DNodes,
  X3DFields,
  phanes.scene.picking,
  phanes.interiors.materials,
  phanes.composition.contents.types,
  phanes.composition.contents.assembly,
  phanes.interiors.food.scene,
  phanes.interiors.catalog,
  phanes.interiors.profiles;

procedure BoxPart(const AParent: TCastleTransform; const ASize, APosition: TVector3;
  const AColor: TVector3; const ADetail: Integer = 0);
var
  LPart: TCastleBox;
begin
  LPart := TCastleBox.Create(AParent);
  LPart.Size := ASize;
  LPart.Translation := APosition;
  LPart.Color := Vector4(AColor.X, AColor.Y, AColor.Z, 1);
  LPart.Material := pmPhysical;
  LPart.PreciseCollisions := True;
  if ADetail > 0 then
  begin
    LPart.SetEffects([InteriorDetail(ADetail)]);
  end;
  AParent.Add(LPart);
end;

procedure OvalPart(const AParent: TCastleTransform; const ASize, APosition,
  AColor: TVector3);
var
  LPart: TCastleSphere;
begin
  LPart := TCastleSphere.Create(AParent);
  LPart.Radius := 1;
  LPart.Slices := 32;
  LPart.Stacks := 20;
  if Max(ASize.X, Max(ASize.Y, ASize.Z)) < 0.005 then
  begin
    LPart.Slices := 8;
    LPart.Stacks := 6;
  end;
  LPart.PreciseCollisions := True;
  LPart.Scale := ASize;
  LPart.Translation := APosition;
  LPart.Color := Vector4(AColor.X, AColor.Y, AColor.Z, 1);
  LPart.Material := pmPhysical;
  LPart.SetEffects([InteriorDetail(InteriorCeramic)]);
  AParent.Add(LPart);
end;

procedure PlatePart(const AParent: TCastleTransform; const AColor: TVector3);
const
  { The underside foot reaches the support plane while the inner well remains
    at 6 mm. The rim height is not the food's contact height. }
  CRadii: array[0..10] of Single =
    (0, 0.085, 0.105, 0.12, 0.13, 0.13, 0.060, 0.055, 0.045, 0.040, 0);
  CHeights: array[0..10] of Single =
    (0.006, 0.006, 0.008, 0.019, 0.024, 0.005, 0.003, 0, 0, 0.003, 0.003);
var
  LPoints: TCoordinateNode;
  LMesh: TIndexedTriangleSetNode;
  LMaterial: TPhysicalMaterialNode;
  LAppearance: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
  LScene: TCastleScene;
  LAngle: Single;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  LPoints := TCoordinateNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := LPoints;
  for J := 0 to High(CRadii) do
  begin
    for I := 0 to 64 do
    begin
      LAngle := I / 64 * 2 * Pi;
      LPoints.FdPoint.Items.Add(Vector3(Cos(LAngle) * CRadii[J],
        CHeights[J], Sin(LAngle) * CRadii[J]));
    end;
  end;
  for J := 0 to High(CRadii) - 1 do
  begin
    for I := 0 to 63 do
    begin
      LIndex := J * 65 + I;
      LMesh.FdIndex.Items.Add(LIndex);
      LMesh.FdIndex.Items.Add(LIndex + 1);
      LMesh.FdIndex.Items.Add(LIndex + 65);
      LMesh.FdIndex.Items.Add(LIndex + 1);
      LMesh.FdIndex.Items.Add(LIndex + 66);
      LMesh.FdIndex.Items.Add(LIndex + 65);
    end;
  end;
  LMaterial := TPhysicalMaterialNode.Create;
  LMaterial.BaseColor := AColor;
  LMaterial.Metallic := 0;
  LMaterial.Roughness := 0.25;
  LAppearance := TAppearanceNode.Create;
  LAppearance.Material := LMaterial;
  LShape := TShapeNode.Create;
  LShape.Geometry := LMesh;
  LShape.Appearance := LAppearance;
  LRoot := TX3DRootNode.Create;
  LRoot.AddChildren(LShape);
  LScene := TCastleScene.Create(AParent);
  LScene.Load(LRoot, True);
  LScene.PreciseCollisions := True;
  LScene.SetEffects([InteriorDetail(InteriorCeramic)]);
  AParent.Add(LScene);
end;

function CreateInteriorModel(const AId: String; const ACacheOwner: TComponent;
  const ACache: TStringList; const ALoadAsset: TInteriorAssetLoader): TCastleTransform;
var
  LDefinition: TInteriorAsset;
  LRaw: TCastleScene;
  LReference: TCastleTransformReference;
  LBounds: TBox3D;
  LColor: TVector3;
  LAccent: TVector3;
  LScale: Single;
  LAngle: Single;
  LRadius: Single;
  LIndex: Integer;
  I: Integer;
begin
  LIndex := ACache.IndexOf('interior:' + AId);
  if LIndex >= 0 then
  begin
    Exit(TCastleTransform(ACache.Objects[LIndex]));
  end;
  if not InteriorAsset(AId, LDefinition) then
  begin
    raise Exception.Create('Unadmitted interior model: ' + AId);
  end;
  Result := TCastleTransform.Create(ACacheOwner);
  LColor := Vector3(LDefinition.FRed, LDefinition.FGreen, LDefinition.FBlue);
  LAccent := Vector3(0.83, 0.70, 0.42);
  if Pos('kit-', LDefinition.FShape) = 1 then
  begin
    if LDefinition.FShape = 'kit-bookcase' then
    begin
      LRaw := ALoadAsset('furniture-kit/bookcaseOpen');
      LScale := 2;
    end
    else if LDefinition.FShape = 'kit-chair' then
    begin
      LRaw := ALoadAsset('furniture-kit/chair');
      LScale := 2;
    end
    else if LDefinition.FShape = 'kit-fixture' then
    begin
      LRaw := ALoadAsset(LDefinition.FSourcePath);
      LScale := LDefinition.FUniformScale;
    end
    else
    begin
      LRaw := ALoadAsset('furniture-kit/table');
      LScale := 0.75 / LRaw.BoundingBox.SizeY;
    end;
    LBounds := LRaw.BoundingBox;
    LRaw.PreciseCollisions := True;
    LReference := TCastleTransformReference.Create(Result);
    LReference.Reference := LRaw;
    LReference.Scale := Vector3(LScale, LScale, LScale);
    LReference.Translation := Vector3(-LBounds.Center.X * LScale,
      -LBounds.Data[0].Y * LScale, -LBounds.Center.Z * LScale);
    Result.Add(LReference);
  end
  else if LDefinition.FShape = 'potted-plant' then
  begin
    OvalPart(Result, Vector3(0.22, 0.22, 0.22), Vector3(0, 0.22, 0),
      Vector3(0.65, 0.53, 0.40));
    OvalPart(Result, Vector3(0.195, 0.025, 0.195), Vector3(0, 0.42, 0),
      Vector3(0.16, 0.13, 0.10));
    BoxPart(Result, Vector3(0.018, 0.75, 0.018), Vector3(0, 0.795, 0), LColor);
    for I := 0 to 9 do
    begin
      LAngle := I * 2.39996;
      LRadius := 0.12 + (I mod 3) * 0.045;
      OvalPart(Result, Vector3(0.16, 0.075, 0.09),
        Vector3(Cos(LAngle) * LRadius, 0.52 + I * 0.083, Sin(LAngle) * LRadius),
        Vector3(LColor.X * (0.8 + I * 0.025), LColor.Y, LColor.Z));
    end;
  end
  else if LDefinition.FShape = 'book' then
  begin
    BoxPart(Result, Vector3(0.042, 0.242, 0.181), Vector3(0, 0.125, 0),
      Vector3(0.84, 0.80, 0.66));
    BoxPart(Result, Vector3(0.003, 0.25, 0.19), Vector3(-0.0225, 0.125, 0), LColor, InteriorCloth);
    BoxPart(Result, Vector3(0.003, 0.25, 0.19), Vector3(0.0225, 0.125, 0), LColor, InteriorCloth);
    BoxPart(Result, Vector3(0.048, 0.25, 0.007), Vector3(0, 0.125, 0.091), LColor, InteriorCloth);
    for I := 0 to 3 do
    begin
      BoxPart(Result, Vector3(0.042, 0.002, 0.001),
        Vector3(0, 0.025 + I * 0.065, 0.0945), LAccent);
    end;
    BoxPart(Result, Vector3(0.023, 0.055, 0.001), Vector3(0, 0.145, 0.0945), LAccent);
  end
  else if LDefinition.FShape = 'snail' then
  begin
    OvalPart(Result, Vector3(0.065, 0.012, 0.025), Vector3(0, 0.012, 0), LColor);
    OvalPart(Result, Vector3(0.014, 0.018, 0.015), Vector3(0.051, 0.03, 0), LColor);
    OvalPart(Result, Vector3(0.036, 0.04, 0.035), Vector3(-0.015, 0.05, 0), LColor);
    for I := 0 to 47 do
    begin
      LAngle := I / 47 * Pi * 4.5;
      LRadius := 0.029 * (1 - I / 56);
      OvalPart(Result, Vector3(0.0024, 0.0024, 0.0024),
        Vector3(-0.015 + Cos(LAngle) * LRadius, 0.05 + Sin(LAngle) * LRadius, 0.035),
        Vector3(LColor.X * 0.65, LColor.Y * 0.65, LColor.Z * 0.65));
    end;
    for I := 0 to 1 do
    begin
      OvalPart(Result, Vector3(0.0025, 0.017, 0.0025),
        Vector3(0.053, 0.05, -0.008 + I * 0.016), LColor);
      OvalPart(Result, Vector3(0.004, 0.004, 0.004),
        Vector3(0.053, 0.067, -0.008 + I * 0.016), LColor);
    end;
  end
  else if LDefinition.FShape = 'plate' then
  begin
    PlatePart(Result, LColor);
  end
  else if (LDefinition.FShape = 'bread') or (LDefinition.FShape = 'apple') or
    (LDefinition.FShape = 'pear') or (LDefinition.FShape = 'cheese') or
    (LDefinition.FShape = 'herb-cheese') then
  begin
    CreateFoodModel(Result, LDefinition.FShape, LColor);
  end
  else if LDefinition.FShape = 'fork' then
  begin
    BoxPart(Result, Vector3(0.01, 0.004, 0.145), Vector3(0, 0.003, -0.0225), LColor, InteriorMetal);
    BoxPart(Result, Vector3(0.028, 0.004, 0.015), Vector3(0, 0.003, 0.055), LColor, InteriorMetal);
    for I := 0 to 3 do
    begin
      BoxPart(Result, Vector3(0.004, 0.004, 0.033),
        Vector3(-0.012 + I * 0.008, 0.003, 0.0785), LColor, InteriorMetal);
    end;
  end;
  ACache.AddObject('interior:' + AId, Result);
end;

function TInteriorScene.Model(const AId: String): TCastleTransform;
begin
  Result := CreateInteriorModel(AId, FCacheOwner, FCache, FLoadAsset);
end;

function TInteriorScene.Instance(const ANode: Integer): TCastleTransform;
var
  LParent: TCastleTransform;
  LParentIndex: Integer;
  LReference: TCastleTransformReference;
begin
  if FInstances[ANode] <> nil then
  begin
    Exit(FInstances[ANode]);
  end;
  if FDocument.FNodes[ANode].FId = FRoomId then
  begin
    FInstances[ANode] := Self;
    Exit(Self);
  end;
  LParentIndex := FIndex.Find(FDocument.FNodes[ANode].FParentId);
  LParent := Instance(LParentIndex);
  Result := TCastleTransform.Create(Self);
  Result.Translation := Vector3(FDocument.FNodes[ANode].FX / 1000,
    FDocument.FNodes[ANode].FY / 1000, FDocument.FNodes[ANode].FZ / 1000);
  Result.Rotation := Vector4(0, 1, 0, FDocument.FNodes[ANode].FQuarterTurn * Pi / 2);
  LParent.Add(Result);
  FInstances[ANode] := Result;
  if FDocument.FNodes[ANode].FKind = ckObject then
  begin
    LReference := TCastleTransformReference.Create(Self);
    LReference.Reference := Model(FDocument.FNodes[ANode].FAssetId);
    Result.Add(LReference);
  end;
end;

procedure TInteriorScene.BuildPlanWalls(const APlan: TCompositionNode);
var
  LWall: TSpaceWall;
  LSize: TVector3;
  LPosition: TVector3;
  I: Integer;
begin
  FWalls := CabinPlanWalls(APlan);
  FFullWalls := TCastleTransform.Create(Self);
  FCutWalls := TCastleTransform.Create(Self);
  Add(FFullWalls);
  Add(FCutWalls);
  for I := 0 to High(FWalls) do
  begin
    LWall := FWalls[I];
    LSize := Vector3((LWall.FMaxX - LWall.FMinX) / 1000,
      (LWall.FTop - LWall.FBottom) / 1000, (LWall.FMaxZ - LWall.FMinZ) / 1000);
    LPosition := Vector3((LWall.FMinX + LWall.FMaxX) / 2000,
      (LWall.FBottom + LWall.FTop) / 2000, (LWall.FMinZ + LWall.FMaxZ) / 2000);
    BoxPart(FFullWalls, LSize, LPosition, Vector3(0.68, 0.72, 0.67), InteriorPlaster);
    if LWall.FBottom = 0 then
    begin
      LSize.Y := 0.75;
      LPosition.Y := 0.375;
      BoxPart(FCutWalls, LSize, LPosition, Vector3(0.68, 0.72, 0.67), InteriorPlaster);
      LSize.Y := 0.018;
      LPosition.Y := 0.759;
      BoxPart(FCutWalls, LSize, LPosition, Vector3(0.26, 0.39, 0.34), InteriorWood);
    end;
  end;
  SetWalkView(False);
end;

procedure TInteriorScene.SetWalkView(const AWalking: Boolean);
begin
  if FFullWalls <> nil then
  begin
    FFullWalls.Exists := AWalking;
    FCutWalls.Exists := not AWalking;
  end;
end;

constructor TInteriorScene.CreateInterior(const AOwner, ACacheOwner: TComponent;
  const ACache: TStringList; const ALoadAsset: TInteriorAssetLoader;
  const ADocument: TCompositionDocument; const ARoomId: String);
var
  I: Integer;
  LFloor: TCastleBox;
  LFootprints: TInteriorFootprints;
  LParent: Integer;
  LBounds: TBox3D;
  LLocal: TContentBounds;
  LProfile: TBuildingInterior;
  LRoom: Integer;
  LWallX: Single;
  LWallZ: Single;
begin
  inherited Create(AOwner);
  FDocument := CopyDocument(ADocument);
  FRoomId := ARoomId;
  FIndex := TCompositionIndex.Create(FDocument.FNodes);
  FCache := ACache;
  FCacheOwner := ACacheOwner;
  FLoadAsset := ALoadAsset;
  SetLength(FInstances, Length(FDocument.FNodes));
  if FIndex.Find(FRoomId) < 0 then
  begin
    raise Exception.Create('Interior room was not found.');
  end;
  FIsPlan := FDocument.FNodes[FIndex.Find(FRoomId)].FRole = 'floor-plan';
  LRoom := FIndex.Find(FRoomId);
  LParent := FIndex.Find(FDocument.FNodes[LRoom].FParentId);
  if (LParent < 0) or not BuildingInterior(FDocument.FNodes[LParent].FAssetId, LProfile) then
  begin
    raise Exception.Create('The building has no admitted interior profile.');
  end;
  FRoomWidth := LProfile.FWidth / 1000;
  FRoomDepth := LProfile.FDepth / 1000;
  LWallX := FRoomWidth / 2 - 0.05;
  LWallZ := FRoomDepth / 2 - 0.05;
  if FIsPlan then
  begin
    BuildPlanWalls(FDocument.FNodes[FIndex.Find(FRoomId)]);
  end
  else
  begin
    FFullWalls := TCastleTransform.Create(Self);
    FCutWalls := TCastleTransform.Create(Self);
    Add(FFullWalls);
    Add(FCutWalls);
    BoxPart(FCutWalls, Vector3(FRoomWidth, 2.7, 0.10), Vector3(0, 1.35, -LWallZ),
      Vector3(0.70, 0.70, 0.60), InteriorPlaster);
    BoxPart(FCutWalls, Vector3(0.10, 1.05, FRoomDepth), Vector3(-LWallX, 0.525, 0),
      Vector3(0.64, 0.65, 0.55), InteriorPlaster);
    { Walking uses an enclosed room; orbit retains its useful authoring cutaway. }
    BoxPart(FFullWalls, Vector3(FRoomWidth, 2.7, 0.10), Vector3(0, 1.35, -LWallZ),
      Vector3(0.70, 0.70, 0.60), InteriorPlaster);
    BoxPart(FFullWalls, Vector3(FRoomWidth, 2.7, 0.10), Vector3(0, 1.35, LWallZ),
      Vector3(0.70, 0.70, 0.60), InteriorPlaster);
    for I := 0 to 1 do
    begin
      BoxPart(FFullWalls, Vector3(0.10, 1, FRoomDepth), Vector3((I * 2 - 1) * LWallX, 0.5, 0),
        Vector3(0.64, 0.65, 0.55), InteriorPlaster);
      BoxPart(FFullWalls, Vector3(0.10, 0.65, FRoomDepth), Vector3((I * 2 - 1) * LWallX, 2.375, 0),
        Vector3(0.64, 0.65, 0.55), InteriorPlaster);
      BoxPart(FFullWalls, Vector3(0.10, 1.05, FRoomDepth / 2 - 1.2),
        Vector3((I * 2 - 1) * LWallX, 1.525, -(FRoomDepth / 4 + 0.6)),
        Vector3(0.64, 0.65, 0.55), InteriorPlaster);
      BoxPart(FFullWalls, Vector3(0.10, 1.05, FRoomDepth / 2 - 1.2),
        Vector3((I * 2 - 1) * LWallX, 1.525, FRoomDepth / 4 + 0.6),
        Vector3(0.64, 0.65, 0.55), InteriorPlaster);
      BoxPart(FFullWalls, Vector3(0.20, 0.08, 2.4),
        Vector3((I * 2 - 1) * (LWallX - 0.03), 1.02, 0),
        Vector3(0.34, 0.31, 0.24), InteriorWood);
    end;
    BoxPart(FFullWalls, Vector3(FRoomWidth, 0.12, FRoomDepth), Vector3(0, 2.76, 0),
      Vector3(0.86, 0.83, 0.74), InteriorPlaster);
    BoxPart(FFullWalls, Vector3(0.16, 0.16, FRoomDepth), Vector3(0, 2.64, 0),
      Vector3(0.42, 0.36, 0.27), InteriorWood);
    BoxPart(FFullWalls, Vector3(1.2, 2.2, 0.06), Vector3(0, 1.1, LWallZ - 0.08),
      Vector3(0.38, 0.35, 0.28), InteriorWood);
    SetWalkView(False);
    BoxPart(Self, Vector3(FRoomWidth - 0.1, 0.12, 0.08), Vector3(0, 0.06, -LWallZ + 0.09),
      Vector3(0.22, 0.29, 0.25));
  end;
  for I := 0 to High(FDocument.FNodes) do
  begin
    if InCompositionScope(FDocument, FIndex, I, FRoomId) then
    begin
      Instance(I);
    end;
  end;
  LFootprints := nil;
  for I := 0 to High(FDocument.FNodes) do
  begin
    LParent := FIndex.Find(FDocument.FNodes[I].FParentId);
    if (FInstances[I] <> nil) and (FDocument.FNodes[I].FKind = ckObject) and
      ((FDocument.FNodes[I].FParentId = FRoomId) or
      (FIsPlan and (LParent >= 0) and (FDocument.FNodes[LParent].FRole = 'room'))) then
    begin
      { BoundingBox includes the object's pose in its immediate parent.
        Resolve the remaining local frames explicitly: viewport world transforms
        are unavailable while this scene is still being constructed. }
      LBounds := FInstances[I].BoundingBox;
      LLocal := Default(TContentBounds);
      LLocal.FEmpty := LBounds.IsEmpty;
      LLocal.FMinX := LBounds.Data[0].X * 1000;
      LLocal.FMinY := LBounds.Data[0].Y * 1000;
      LLocal.FMinZ := LBounds.Data[0].Z * 1000;
      LLocal.FMaxX := LBounds.Data[1].X * 1000;
      LLocal.FMaxY := LBounds.Data[1].Y * 1000;
      LLocal.FMaxZ := LBounds.Data[1].Z * 1000;
      while (LParent >= 0) and (FDocument.FNodes[LParent].FId <> FRoomId) do
      begin
        LLocal := TransformContentBounds(LLocal, FDocument.FNodes[LParent].FX,
          FDocument.FNodes[LParent].FY, FDocument.FNodes[LParent].FZ,
          FDocument.FNodes[LParent].FQuarterTurn);
        LParent := FIndex.Find(FDocument.FNodes[LParent].FParentId);
      end;
      if not LLocal.FEmpty then
      begin
        LBounds.Data[0] := Vector3(LLocal.FMinX / 1000, LLocal.FMinY / 1000,
          LLocal.FMinZ / 1000);
        LBounds.Data[1] := Vector3(LLocal.FMaxX / 1000, LLocal.FMaxY / 1000,
          LLocal.FMaxZ / 1000);
        SetLength(LFootprints, Length(LFootprints) + 1);
        LFootprints[High(LFootprints)] := LBounds;
      end;
    end;
  end;
  LFloor := TCastleBox.Create(Self);
  LFloor.Size := Vector3(FRoomWidth, 0.08, FRoomDepth);
  LFloor.Translation := Vector3(0, -0.04, 0);
  LFloor.Color := Vector4(0.39, 0.30, 0.21, 1);
  LFloor.Material := pmPhysical;
  LFloor.SetEffects([InteriorDetail(InteriorWood), InteriorFloorDetail(LFootprints)]);
  Add(LFloor);
end;

destructor TInteriorScene.Destroy;
begin
  FIndex.Free;
  inherited Destroy;
end;

function TInteriorScene.BoundsFor(const AId: String): TBox3D;
var
  LNode: Integer;
  LProfile: TContentSupport;
  LHalfWidth: Single;
  LHalfDepth: Single;
  LHeight: Single;
  I: Integer;
  J: Integer;
begin
  Result := TBox3D.Empty;
  LNode := FIndex.Find(AId);
  if (LNode < 0) or (FInstances[LNode] = nil) then
  begin
    Exit;
  end;
  if (FDocument.FNodes[LNode].FKind = ckContainer) and
    HasCompositionExtent(FDocument.FNodes[LNode]) then
  begin
    LHalfWidth := FDocument.FNodes[LNode].FWidth / 2000;
    LHalfDepth := FDocument.FNodes[LNode].FDepth / 2000;
    LHeight := FDocument.FNodes[LNode].FHeight / 1000;
  end
  else if FDocument.FNodes[LNode].FKind = ckSurface then
  begin
    LHalfWidth := 0.36;
    LHalfDepth := 0.21;
    LHeight := 0.32;
    if (FDocument.FNodes[LNode].FRole = 'tabletop') or
      (FDocument.FNodes[LNode].FRole = 'bench-top') then
    begin
      LHalfWidth := 0.75;
      LHalfDepth := 0.4;
      LHeight := 0.15;
    end;
    if FDocument.FNodes[LNode].FRole = 'plate-well' then
    begin
      LProfile := InteriorPlateSupport;
      LHalfWidth := LProfile.FWidth / 2000;
      LHalfDepth := LProfile.FDepth / 2000;
      LHeight := LProfile.FHeadroom / 1000;
    end;
  end
  else
  begin
    Exit(FInstances[LNode].WorldBoundingBox);
  end;
  for I := 0 to 1 do
  begin
    for J := 0 to 1 do
    begin
      Result.Include(FInstances[LNode].LocalToWorld(Vector3(
        (I * 2 - 1) * LHalfWidth, 0, (J * 2 - 1) * LHalfDepth)));
      Result.Include(FInstances[LNode].LocalToWorld(Vector3(
        (I * 2 - 1) * LHalfWidth, LHeight, (J * 2 - 1) * LHalfDepth)));
    end;
  end;
end;

function TInteriorScene.Pick(const AOrigin, ADirection: TVector3): String;
var
  LCollision: TRayCollision;
  LPathIndex: Integer;
  LClosest: Integer;
  LPoint: TVector3;
  LLocal: TVector3;
  I: Integer;
begin
  Result := '';
  LCollision := VisibleRayCollision(Self, AOrigin, ADirection);
  if LCollision = nil then
  begin
    Exit;
  end;
  try
    Result := FRoomId;
    if FIsPlan then
    begin
      LPoint := AOrigin + ADirection.Normalize * LCollision.Distance;
      for I := 0 to High(FDocument.FNodes) do
      begin
        if (FInstances[I] <> nil) and (FDocument.FNodes[I].FRole = 'room') then
        begin
          LLocal := FInstances[I].WorldToLocal(LPoint);
          if (Abs(LLocal.X) <= FDocument.FNodes[I].FWidth / 2000) and
            (Abs(LLocal.Z) <= FDocument.FNodes[I].FDepth / 2000) and
            (LLocal.Y >= -0.05) and (LLocal.Y <= FDocument.FNodes[I].FHeight / 1000) then
          begin
            Result := FDocument.FNodes[I].FId;
            Break;
          end;
        end;
      end;
    end;
    LClosest := High(Integer);
    { RayCollision chooses the first visible geometry, including walls.
      Its path runs from the hit geometry outward to owning transforms.
      Select the innermost placed object on that path. A shelf's empty
      bounding volume must not hide its contents or select an occluded prop. }
    for I := 0 to High(FDocument.FNodes) do
    begin
      if (FInstances[I] = nil) or (FDocument.FNodes[I].FKind <> ckObject) then
      begin
        Continue;
      end;
      LPathIndex := LCollision.IndexOfItem(FInstances[I]);
      if (LPathIndex >= 0) and (LPathIndex < LClosest) then
      begin
        LClosest := LPathIndex;
        Result := FDocument.FNodes[I].FId;
      end;
    end;
  finally
    LCollision.Free;
  end;
end;

function TInteriorScene.FindStanding(var AX, AZ: Double): Boolean;
var
  LX: Double;
  LZ: Double;
  LColumn: Integer;
  LRow: Integer;
  LColumns: Integer;
  LRows: Integer;
begin
  if CanStand(AX, AZ) then
  begin
    Exit(True);
  end;
  LX := 0;
  LZ := FRoomDepth / 2 - 0.9;
  if CanStand(LX, LZ) then
  begin
    AX := LX;
    AZ := LZ;
    Exit(True);
  end;
  { A furnished entrance or a room-plan partition may obstruct that first
    position. Search a bounded floor grid and admit every candidate against
    the same walls and furniture used by ordinary walking. }
  LColumns := Max(1, Ceil(FRoomWidth / 0.25));
  LRows := Max(1, Ceil(FRoomDepth / 0.25));
  for LRow := 0 to LRows do
  begin
    LZ := (0.5 - LRow / LRows) * (FRoomDepth - 0.8);
    for LColumn := 0 to LColumns do
    begin
      LX := (LColumn / LColumns - 0.5) * (FRoomWidth - 0.8);
      if CanStand(LX, LZ) then
      begin
        AX := LX;
        AZ := LZ;
        Exit(True);
      end;
    end;
  end;
  Result := False;
end;

function TInteriorScene.CanStand(const AX, AZ: Double): Boolean;
var
  LBounds: TBox3D;
  LX: Double;
  LZ: Double;
  LParent: Integer;
  I: Integer;
begin
  if IsNan(AX) or IsInfinite(AX) or IsNan(AZ) or IsInfinite(AZ) then
  begin
    Exit(False);
  end;
  Result := (Abs(AX) < FRoomWidth / 2 - 0.38) and
    (Abs(AZ) < FRoomDepth / 2 - 0.38);
  if FIsPlan then
  begin
    Result := (Abs(AX) <= 4.42) and (Abs(AZ) <= 4.42);
    for I := 0 to High(FWalls) do
    begin
      if SpaceWallBlocks(FWalls[I], AX * 1000, AZ * 1000, 280, 1850) then
      begin
        Exit(False);
      end;
    end;
  end;
  if not Result then
  begin
    Exit;
  end;
  for I := 0 to High(FDocument.FNodes) do
  begin
    LParent := FIndex.Find(FDocument.FNodes[I].FParentId);
    if (FInstances[I] <> nil) and (FDocument.FNodes[I].FKind = ckObject) and
      ((FDocument.FNodes[I].FParentId = FRoomId) or
      (FIsPlan and (LParent >= 0) and (FDocument.FNodes[LParent].FRole = 'room'))) then
    begin
      LBounds := BoundsFor(FDocument.FNodes[I].FId);
      LX := Max(LBounds.Data[0].X - AX, Max(AX - LBounds.Data[1].X, 0));
      LZ := Max(LBounds.Data[0].Z - AZ, Max(AZ - LBounds.Data[1].Z, 0));
      if (FIsPlan and (LX * LX + LZ * LZ < Sqr(0.28))) or
        (not FIsPlan and (AX > LBounds.Data[0].X - 0.28) and
        (AX < LBounds.Data[1].X + 0.28) and (AZ > LBounds.Data[0].Z - 0.28) and
        (AZ < LBounds.Data[1].Z + 0.28)) then
      begin
        Exit(False);
      end;
    end;
  end;
end;

function InteriorSelectionInk(const AColour: TVector4): TEffectNode;
var
  LFragment: TEffectPartNode;
begin
  Result := TEffectNode.Create;
  Result.Language := slGLSL;
  Result.AddCustomField(TSFVec4f.Create(Result, True, 'phanesInteriorInk', AColour));
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  LFragment.Contents :=
    'uniform vec4 phanesInteriorInk;' + LineEnding +
    'void PLUG_fragment_end(inout vec4 c) { c=phanesInteriorInk; }';
  Result.SetParts([LFragment]);
end;

procedure TInteriorScene.Select(const AId: String);
begin
  FreeAndNil(FOutline);
  FOutlineBounds := BoundsFor(AId);
  FOutlineStroke := 0;
  if FOutlineBounds.IsEmpty then
  begin
    Exit;
  end;
  FOutline := TCastleTransform.Create(Self);
  FOutline.Pickable := False;
  FOutline.Collides := False;
  Add(FOutline);
  UpdateSelectionStroke(0.00035);
end;

procedure TInteriorScene.UpdateSelectionStroke(const AThickness: Single);
var
  LBounds: TBox3D;
  LExpanded: TBox3D;
  LColor: TVector4;
  LSize: TVector3;
  LCorner: TVector3;
  LSegment: TVector3;
  LThickness: Single;
  LStroke: Single;
  LPadding: Single;
  I: Integer;
  J: Integer;
  K: Integer;
  LPass: Integer;
  LEdgeIndex: Integer;

  procedure Mark(const ASize, APosition: TVector3);
  var
    LPart: TCastleBox;
  begin
    if LEdgeIndex < FOutline.Count then
    begin
      LPart := TCastleBox(FOutline[LEdgeIndex]);
    end
    else
    begin
      LPart := TCastleBox.Create(FOutline);
      LPart.Color := LColor;
      LPart.Material := pmUnlit;
      LPart.SetEffects([InteriorSelectionInk(LColor)]);
      LPart.CastShadows := False;
      FOutline.Add(LPart);
    end;
    Inc(LEdgeIndex);
    LPart.Size := ASize;
    LPart.Translation := APosition;
  end;

begin
  if (FOutline = nil) or FOutlineBounds.IsEmpty then
  begin
    Exit;
  end;
  LThickness := Max(0.00005, AThickness);
  if Abs(LThickness - FOutlineStroke) <= Max(0.000001, FOutlineStroke * 0.04) then
  begin
    Exit;
  end;
  FOutlineStroke := LThickness;
  LBounds := FOutlineBounds;
  LSize := LBounds.Size;
  LEdgeIndex := 0;
  { Short corner brackets retain the selected volume without bars crossing
    small object silhouettes. Separate light/dark contours retain contrast on
    ceramic and timber; their display ink still uses ordinary depth testing. }
  for LPass := 0 to 1 do
  begin
    LColor := Vector4(0.98, 0.86, 0.52, 1);
    LStroke := LThickness;
    LPadding := LThickness * 1.2;
    if LPass = 1 then
    begin
      LColor := Vector4(0.035, 0.065, 0.075, 1);
      LStroke := LThickness * 0.55;
      LPadding := LPadding + LThickness * 0.9;
    end;
    LExpanded := LBounds;
    LExpanded.Data[0] := LBounds.Data[0] - Vector3(LPadding, LPadding, LPadding);
    LExpanded.Data[1] := LBounds.Data[1] + Vector3(LPadding, LPadding, LPadding);
    LSegment := LExpanded.Size * 0.2;
    for I := 0 to 1 do
    begin
      for J := 0 to 1 do
      begin
        for K := 0 to 1 do
        begin
          LCorner := Vector3(LExpanded.Data[I].X, LExpanded.Data[J].Y, LExpanded.Data[K].Z);
          Mark(Vector3(LSegment.X, LStroke, LStroke),
            LCorner + Vector3((1 - 2 * I) * LSegment.X / 2, 0, 0));
          Mark(Vector3(LStroke, LSegment.Y, LStroke),
            LCorner + Vector3(0, (1 - 2 * J) * LSegment.Y / 2, 0));
          Mark(Vector3(LStroke, LStroke, LSegment.Z),
            LCorner + Vector3(0, 0, (1 - 2 * K) * LSegment.Z / 2));
        end;
      end;
    end;
  end;
end;

end.
