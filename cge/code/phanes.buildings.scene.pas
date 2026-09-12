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
unit phanes.buildings.scene;
{$mode delphi}
{$H+}

interface

uses
  Classes, CastleTransform, CastleVectors, CastleBoxes,
  phanes.world.types, phanes.world.appearance, phanes.interiors.scene;

type
  TModularScene = class(TCastleTransform)
  private
    FModels: TStringList;
    FParts: TStringList;
    FRoofs: TStringList;
    FSeen: TStringList;
    FAppearance: TWorldAppearance;
    FLoadAsset: TInteriorAssetLoader;
    FInspectionSelected: String;
    FInspectionRoot: String;
    FInspectionBounds: TBox3D;
    function Model(const AToken: String): TCastleTransform;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property AssetLoader: TInteriorAssetLoader read FLoadAsset write FLoadAsset;
    procedure Apply(const AWorld: TWorld; const AAppearance: TWorldAppearance);
    procedure View(const AEye: TVector3; const ACutaway: Boolean;
      const ASelected: String);
    function Pick(const AOrigin, ADirection: TVector3; out APoint: TVector3): String;
    function BoundsFor(const AId: String): TBox3D;
    { Caller proves no active world object uses this asset before retiring its
      raw scene. Cached references must be destroyed first. }
    procedure RetireModel(const AId: String);
  end;

implementation

uses
  SysUtils, Math, CastleScene, CastleRenderOptions, CastleColors,
  phanes.composition.types, phanes.composition.document, phanes.scene.picking,
  phanes.buildings.types, phanes.buildings.geometry, phanes.interiors.materials,
  phanes.interiors.surfaces, phanes.composition.contents.types;

type
  TModularPart = class(TCastleTransformReference)
  public
    FId: String;
    FRootId: String;
    FAssetId: String;
    FAncestors: String;
    FSupportBounds: TBox3D;
    FVisualBounds: TBox3D;
    FEdge: Boolean;
  end;

constructor TModularScene.Create(AOwner: TComponent);
begin
  inherited;
  FModels := TStringList.Create;
  FParts := TStringList.Create;
  FRoofs := TStringList.Create;
  FSeen := TStringList.Create;
  FSeen.Sorted := True;
  FInspectionBounds := TBox3D.Empty;
end;

destructor TModularScene.Destroy;
begin
  FSeen.Free;
  FRoofs.Free;
  FParts.Free;
  FModels.Free;
  inherited;
end;

function TModularScene.Model(const AToken: String): TCastleTransform;
var
  LBoxes: TModuleBoxes;
  LBox: TModuleBox;
  LPart: TCastleBox;
  LColor: TVector3;
  LDetail: Integer;
  LAt: Integer;
  I: Integer;
begin
  LAt := FModels.IndexOf(AToken);
  if LAt >= 0 then
  begin
    Exit(TCastleTransform(FModels.Objects[LAt]));
  end;
  Result := TCastleTransform.Create(Self);
  LBoxes := ModuleBoxes(AToken);
  if AToken = 'roof' then
  begin
    SetLength(LBoxes, 1);
    LBoxes[0] := Default(TModuleBox);
    LBoxes[0].FY := 2.88;
    LBoxes[0].FWidth := 2;
    LBoxes[0].FHeight := 0.16;
    LBoxes[0].FDepth := 2;
    LBoxes[0].FMaterial := mmPlaster;
  end;
  for I := 0 to High(LBoxes) do
  begin
    LBox := LBoxes[I];
    LColor := Vector3(0.71, 0.70, 0.62);
    LDetail := InteriorPlaster;
    case LBox.FMaterial of
      mmFloor:
      begin
        LColor := Vector3(0.49, 0.43, 0.34);
        LDetail := InteriorWood;
        if AToken = 'floor.stone' then
        begin
          LColor := Vector3(0.48, 0.46, 0.42);
          LDetail := InteriorPlaster;
        end;
      end;
      mmWood:
      begin
        LColor := Vector3(0.30, 0.35, 0.27);
        LDetail := InteriorWood;
      end;
      mmGlass:
      begin
        LColor := Vector3(0.79, 0.91, 0.94);
        LDetail := 0;
      end;
      mmMetal:
      begin
        LColor := Vector3(0.69, 0.55, 0.31);
        LDetail := InteriorMetal;
      end;
      mmPlaster:
      begin
        LDetail := InteriorPlaster;
      end;
    end;
    LPart := TCastleBox.Create(Result);
    LPart.Size := Vector3(LBox.FWidth, LBox.FHeight, LBox.FDepth);
    LPart.Translation := Vector3(LBox.FX, LBox.FY, LBox.FZ);
    LPart.Material := pmPhysical;
    LPart.Color := Vector4(LColor.X * FAppearance.FTint.FR,
      LColor.Y * FAppearance.FTint.FG, LColor.Z * FAppearance.FTint.FB, 1);
    if LBox.FMaterial = mmGlass then
    begin
      LPart.Color := Vector4(LColor.X, LColor.Y, LColor.Z, 0.08);
      LPart.CastShadows := False;
    end;
    LPart.PreciseCollisions := True;
    if LDetail > 0 then
    begin
      if LBox.FMaterial = mmFloor then
      begin
        LPart.SetEffects([InteriorDetail(LDetail, True),
          ModularFloorDetail(AToken = 'floor.stone')]);
      end
      else
      begin
        LPart.SetEffects([InteriorDetail(LDetail, True)]);
      end;
    end;
    Result.Add(LPart);
  end;
  FModels.AddObject(AToken, Result);
end;

procedure TModularScene.RetireModel(const AId: String);
var
  LIndex: Integer;
begin
  LIndex := FModels.IndexOf('interior:' + AId);
  if LIndex >= 0 then
  begin
    FModels.Objects[LIndex].Free;
    FModels.Delete(LIndex);
  end;
end;

procedure TModularScene.Apply(const AWorld: TWorld; const AAppearance: TWorldAppearance);
var
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LPart: TModularPart;
  LRoof: TCastleTransformReference;
  LRoot: String;
  LParent: Integer;
  LPosition: TVector3;
  LTurn: Integer;
  LSwap: Single;
  LToken: String;
  LSupport: TContentRequest;
  LSupportReason: String;
  LSupportSize: TVector3;
  LAt: Integer;
  I: Integer;
begin
  if (FAppearance.FTint.FR <> AAppearance.FTint.FR) or
    (FAppearance.FTint.FG <> AAppearance.FTint.FG) or
    (FAppearance.FTint.FB <> AAppearance.FTint.FB) then
  begin
    for I := FParts.Count - 1 downto 0 do
    begin
      FParts.Objects[I].Free;
    end;
    FParts.Clear;
    for I := FRoofs.Count - 1 downto 0 do
    begin
      FRoofs.Objects[I].Free;
    end;
    FRoofs.Clear;
    for I := FModels.Count - 1 downto 0 do
    begin
      FModels.Objects[I].Free;
    end;
    FModels.Clear;
  end;
  FAppearance := AAppearance;
  FInspectionSelected := '';
  FInspectionRoot := '';
  FInspectionBounds := TBox3D.Empty;
  FSeen.Clear;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LNode := AWorld.FComposition.FNodes[I];
      LRoot := ModularOwner(AWorld.FComposition, LIndex, I);
      if (LRoot = '') or (LRoot = LNode.FId) then
      begin
        Continue;
      end;
      FSeen.Add(LNode.FId);
      LAt := FParts.IndexOf(LNode.FId);
      if LAt < 0 then
      begin
        LPart := TModularPart.Create(Self);
        LPart.FId := LNode.FId;
        LPart.FRootId := LRoot;
        LPart.ReferenceTransformation := rtDoNotIgnore;
        Add(LPart);
        FParts.AddObject(LNode.FId, LPart);
      end
      else
      begin
        LPart := TModularPart(FParts.Objects[LAt]);
      end;
      if LPart.FAssetId <> LNode.FAssetId then
      begin
        LToken := ModuleToken(LNode.FAssetId);
        if LToken <> '' then
        begin
          LPart.Reference := Model(LToken);
        end
        else if LNode.FKind = ckObject then
        begin
          LPart.Reference := CreateInteriorModel(LNode.FAssetId, Self, FModels, FLoadAsset);
        end;
        LPart.FAssetId := LNode.FAssetId;
      end;
      LPosition := Vector3(LNode.FX / 1000, LNode.FY / 1000, LNode.FZ / 1000);
      LTurn := LNode.FQuarterTurn;
      LPart.FAncestors := ':' + LNode.FId + ':';
      LParent := LIndex.Find(LNode.FParentId);
      while LParent >= 0 do
      begin
        LPart.FAncestors := LPart.FAncestors + AWorld.FComposition.FNodes[LParent].FId + ':';
        case AWorld.FComposition.FNodes[LParent].FQuarterTurn of
          1:
          begin
            LSwap := LPosition.X;
            LPosition.X := LPosition.Z;
            LPosition.Z := -LSwap;
          end;
          2:
          begin
            LPosition.X := -LPosition.X;
            LPosition.Z := -LPosition.Z;
          end;
          3:
          begin
            LSwap := LPosition.X;
            LPosition.X := -LPosition.Z;
            LPosition.Z := LSwap;
          end;
        end;
        Inc(LTurn, AWorld.FComposition.FNodes[LParent].FQuarterTurn);
        LPosition := LPosition + Vector3(AWorld.FComposition.FNodes[LParent].FX / 1000,
          AWorld.FComposition.FNodes[LParent].FY / 1000,
          AWorld.FComposition.FNodes[LParent].FZ / 1000);
        LParent := LIndex.Find(AWorld.FComposition.FNodes[LParent].FParentId);
      end;
      LPart.Translation := LPosition;
      LPart.Rotation := Vector4(0, 1, 0, LTurn * Pi / 2);
      LPart.FEdge := LNode.FRole = 'wall-module';
      LPart.FVisualBounds := TBox3D.Empty;
      if LPart.Reference <> nil then
      begin
        { Template geometry remains available when distance culling hides this
          instance. Inspection must be able to bring a distant home into view. }
        LPart.FVisualBounds := LPart.Reference.BoundingBox.Transform(LPart.WorldTransform);
      end;
      LPart.FSupportBounds := TBox3D.Empty;
      if (LNode.FKind = ckSurface) and (ModuleToken(LNode.FAssetId) = '') and
        SurfaceRequest(AWorld.FComposition, LNode.FId, LSupport, LSupportReason) then
      begin
        { Empty shelves and tabletops still have a selectable inspection frame.
          Its extent comes from the admitted support profile, not its contents. }
        LSupportSize := Vector3(LSupport.FSurfaceWidth / 2000, 0.004,
          LSupport.FSurfaceDepth / 2000);
        if Odd(LTurn) then
        begin
          LSwap := LSupportSize.X;
          LSupportSize.X := LSupportSize.Z;
          LSupportSize.Z := LSwap;
        end;
        LPart.FSupportBounds.Data[0] := LPosition - LSupportSize;
        LPart.FSupportBounds.Data[1] := LPosition + LSupportSize;
      end;
      if LNode.FRole = 'floor-tile' then
      begin
        LAt := FRoofs.IndexOf(LNode.FId);
        if LAt < 0 then
        begin
          LRoof := TCastleTransformReference.Create(Self);
          LRoof.ReferenceTransformation := rtDoNotIgnore;
          LRoof.Reference := Model('roof');
          Add(LRoof);
          FRoofs.AddObject(LNode.FId, LRoof);
        end
        else
        begin
          LRoof := TCastleTransformReference(FRoofs.Objects[LAt]);
        end;
        LRoof.Translation := LPart.Translation;
      end;
    end;
    for I := FParts.Count - 1 downto 0 do
    begin
      if FSeen.IndexOf(FParts[I]) < 0 then
      begin
        FParts.Objects[I].Free;
        FParts.Delete(I);
      end;
    end;
    for I := FRoofs.Count - 1 downto 0 do
    begin
      if FSeen.IndexOf(FRoofs[I]) < 0 then
      begin
        FRoofs.Objects[I].Free;
        FRoofs.Delete(I);
      end;
    end;
  finally
    LIndex.Free;
  end;
end;

function ObstructsInspection(const AWall, ATarget: TBox3D;
  const AEye: TVector3): Boolean;
var
  LCorners: TBoxCorners;
  I: Integer;
begin
  Result := False;
  if AWall.IsEmpty or ATarget.IsEmpty then
  begin
    Exit;
  end;
  if AWall.SegmentCollision(AEye, ATarget.Center) then
  begin
    Exit(True);
  end;
  ATarget.Corners(LCorners);
  for I := Low(LCorners) to High(LCorners) do
  begin
    if AWall.SegmentCollision(AEye, LCorners[I]) then
    begin
      Exit(True);
    end;
  end;
end;

procedure TModularScene.View(const AEye: TVector3; const ACutaway: Boolean;
  const ASelected: String);
var
  LPart: TModularPart;
  LRoof: TCastleTransform;
  LVisible: Boolean;
  LAt: Integer;
  I: Integer;
begin
  if FInspectionSelected <> ASelected then
  begin
    FInspectionSelected := ASelected;
    FInspectionRoot := '';
    FInspectionBounds := TBox3D.Empty;
    LAt := FParts.IndexOf(ASelected);
    if LAt >= 0 then
    begin
      LPart := TModularPart(FParts.Objects[LAt]);
      if ModuleToken(LPart.FAssetId) = '' then
      begin
        FInspectionRoot := LPart.FRootId;
        FInspectionBounds := BoundsFor(ASelected);
      end;
    end;
  end;
  { Distant modules are omitted at the same physical radius as detailed props.
    Cached templates and unchanged references survive door and wall edits. }
  for I := 0 to FParts.Count - 1 do
  begin
    LPart := TModularPart(FParts.Objects[I]);
    LVisible := Sqr(LPart.Translation.X - AEye.X) +
      Sqr(LPart.Translation.Z - AEye.Z) < Sqr(160);
    { Inspection clears complete obstructing wall modules only in this home.
      Bounding envelopes deliberately include window openings: the cutaway
      reveals the full selected assembly instead of peeking through its glass.
      Saved parts and independent world collision never change. }
    if LVisible and ACutaway and LPart.FEdge and
      (LPart.FRootId = FInspectionRoot) then
    begin
      LVisible := not ObstructsInspection(LPart.FVisualBounds, FInspectionBounds, AEye);
    end;
    LPart.Exists := LVisible;
  end;
  for I := 0 to FRoofs.Count - 1 do
  begin
    LRoof := TCastleTransform(FRoofs.Objects[I]);
    LRoof.Exists := not ACutaway and
      (Sqr(LRoof.Translation.X - AEye.X) + Sqr(LRoof.Translation.Z - AEye.Z) < Sqr(160));
  end;
end;

function TModularScene.Pick(const AOrigin, ADirection: TVector3; out APoint: TVector3): String;
var
  LCollision: TRayCollision;
  I: Integer;
begin
  Result := '';
  LCollision := VisibleRayCollision(Self, AOrigin, ADirection);
  if LCollision = nil then
  begin
    Exit;
  end;
  try
    APoint := AOrigin + ADirection.Normalize * LCollision.Distance;
    for I := 0 to LCollision.Count - 1 do
    begin
      if LCollision[I].Item is TModularPart then
      begin
        Exit(TModularPart(LCollision[I].Item).FId);
      end;
    end;
  finally
    LCollision.Free;
  end;
end;

function TModularScene.BoundsFor(const AId: String): TBox3D;
var
  LPart: TModularPart;
  I: Integer;
begin
  Result := TBox3D.Empty;
  for I := 0 to FParts.Count - 1 do
  begin
    LPart := TModularPart(FParts.Objects[I]);
    if Pos(':' + AId + ':', LPart.FAncestors) > 0 then
    begin
      Result.Include(LPart.FVisualBounds);
      Result.Include(LPart.FSupportBounds);
    end;
  end;
end;

end.
