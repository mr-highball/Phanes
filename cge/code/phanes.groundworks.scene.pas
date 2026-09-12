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

unit phanes.groundworks.scene;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  CastleTransform,
  CastleBoxes,
  phanes.groundworks.assembly,
  phanes.world.appearance,
  phanes.world.height;

type
  TGroundworkPart = class(TCastleTransform)
  public
    FObjectId: String;
  end;

function CreateGroundworkScene(const AOwner: TComponent; const AAssembly: TGroundworkAssembly;
  const AAppearance: TWorldAppearance; const AHeight: TWorldHeight): TCastleTransform;
function GroundworkBounds(const ARoot: TCastleTransform; const AId: String): TBox3D;
function CreateGroundworkOutline(const AOwner: TComponent;
  const ABounds: TBox3D): TCastleTransform;
procedure ResizeGroundworkOutline(const AOutline: TCastleTransform;
  const ABounds: TBox3D; const AThickness: Single; const AMinimum: Single = 0.025);

implementation

uses
  Math,
  CastleVectors,
  CastleScene,
  CastleRenderOptions,
  X3DFields,
  X3DNodes,
  phanes.groundworks.geometry,
  phanes.world.elevation,
  phanes.interiors.materials;

type
  TGroundworkBuilder = class
  private
    FRoot: TCastleTransform;
    FDeck: TGroundworkPart;
    FAssembly: TGroundworkAssembly;
    FAppearance: TWorldAppearance;
    FHeight: TWorldHeight;
    function Box(const AParent: TCastleTransform; const ASize, APosition, AColour: TVector3;
      const ADetail: Integer): TCastleBox;
    function Part(const AId: String): TGroundworkPart;
    function AccessHeight(const AU, AV: Double): Double;
    procedure Rail(const AParent: TCastleTransform; const AU1, AV1, AU2, AV2: Double);
    procedure AccessMesh(const AParent: TCastleTransform);
  public
    constructor Create(const ARoot: TCastleTransform; const AAssembly: TGroundworkAssembly;
      const AAppearance: TWorldAppearance; const AHeight: TWorldHeight);
    procedure Build;
  end;

function GroundworkBounds(const ARoot: TCastleTransform; const AId: String): TBox3D;
var
  I: Integer;
begin
  Result := TBox3D.Empty;
  if (ARoot = nil) or not ARoot.Exists then
  begin
    Exit;
  end;
  if (ARoot is TGroundworkPart) and (TGroundworkPart(ARoot).FObjectId = AId) then
  begin
    Exit(ARoot.WorldBoundingBox);
  end;
  for I := 0 to ARoot.Count - 1 do
  begin
    Result := GroundworkBounds(ARoot[I], AId);
    if not Result.IsEmpty then
    begin
      Exit;
    end;
  end;
end;

function OutlineInk(const AColour: TVector4): TEffectNode;
var
  LFragment: TEffectPartNode;
begin
  Result := TEffectNode.Create;
  Result.Language := slGLSL;
  Result.AddCustomField(TSFVec4f.Create(Result, True, 'phanesSelectionInk', AColour));
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  { Selection is interface feedback. Keep its display colours independent of
    atmospheric fog and tone mapping, while retaining ordinary depth testing. }
  LFragment.Contents :=
    'uniform vec4 phanesSelectionInk;' + LineEnding +
    'void PLUG_fragment_end(inout vec4 c) { c=phanesSelectionInk; }';
  Result.SetParts([LFragment]);
end;

procedure ResizeGroundworkOutline(const AOutline: TCastleTransform;
  const ABounds: TBox3D; const AThickness: Single; const AMinimum: Single);
var
  LBounds: TBox3D;
  LSize: TVector3;
  LCenter: TVector3;
  LThickness: Single;
  LEdgeWidth: Single;
  LPadding: Single;
  LColour: TVector4;
  LEdgeIndex: Integer;
  I: Integer;
  J: Integer;
  K: Integer;

  procedure Edge(const ASize, APosition: TVector3);
  var
    LEdge: TCastleBox;
  begin
    if LEdgeIndex < AOutline.Count then
    begin
      LEdge := TCastleBox(AOutline[LEdgeIndex]);
    end
    else
    begin
      LEdge := TCastleBox.Create(AOutline);
      LEdge.Material := pmUnlit;
      LEdge.Color := LColour;
      LEdge.SetEffects([OutlineInk(LColour)]);
      LEdge.CastShadows := False;
      AOutline.Add(LEdge);
    end;
    Inc(LEdgeIndex);
    LEdge.Size := ASize;
    LEdge.Translation := APosition;
  end;

begin
  if (AOutline = nil) or ABounds.IsEmpty then
  begin
    Exit;
  end;
  LEdgeIndex := 0;
  LThickness := Max(AMinimum, AThickness);
  { Two separate contours provide contrast on both pale and dark materials.
    They stay outside the admitted bounds and do not enclose/occlude each
    other's geometry as nested solid strokes at the same centre would. }
  for K := 0 to 1 do
  begin
    LPadding := Max(AMinimum, LThickness * 0.6);
    LEdgeWidth := LThickness;
    LColour := Vector4(0.98, 0.86, 0.52, 1);
    if K = 1 then
    begin
      LPadding := LPadding + LThickness * 0.9;
      LEdgeWidth := LThickness * 0.55;
      LColour := Vector4(0.035, 0.065, 0.075, 1);
    end;
    LBounds := ABounds;
    LBounds.Data[0] := LBounds.Data[0] - Vector3(LPadding, LPadding, LPadding);
    LBounds.Data[1] := LBounds.Data[1] + Vector3(LPadding, LPadding, LPadding);
    LSize := LBounds.Size;
    LCenter := LBounds.Center;
    for I := 0 to 1 do
    begin
      for J := 0 to 1 do
      begin
        Edge(Vector3(LSize.X, LEdgeWidth, LEdgeWidth),
          Vector3(LCenter.X, LBounds.Data[I].Y, LBounds.Data[J].Z));
        Edge(Vector3(LEdgeWidth, LSize.Y, LEdgeWidth),
          Vector3(LBounds.Data[I].X, LCenter.Y, LBounds.Data[J].Z));
        Edge(Vector3(LEdgeWidth, LEdgeWidth, LSize.Z),
          Vector3(LBounds.Data[I].X, LBounds.Data[J].Y, LCenter.Z));
      end;
    end;
  end;
end;

function CreateGroundworkOutline(const AOwner: TComponent;
  const ABounds: TBox3D): TCastleTransform;
begin
  Result := nil;
  if ABounds.IsEmpty then
  begin
    Exit;
  end;
  Result := TCastleTransform.Create(AOwner);
  Result.Pickable := False;
  Result.Collides := False;
  ResizeGroundworkOutline(Result, ABounds, 0.045);
end;

constructor TGroundworkBuilder.Create(const ARoot: TCastleTransform;
  const AAssembly: TGroundworkAssembly; const AAppearance: TWorldAppearance; const AHeight: TWorldHeight);
begin
  inherited Create;
  FRoot := ARoot;
  FAssembly := AAssembly;
  FAppearance := AAppearance;
  FHeight := AHeight;
end;

function TGroundworkBuilder.Part(const AId: String): TGroundworkPart;
begin
  Result := TGroundworkPart.Create(FDeck);
  Result.FObjectId := AId;
  FDeck.Add(Result);
end;

function TGroundworkBuilder.Box(const AParent: TCastleTransform;
  const ASize, APosition, AColour: TVector3; const ADetail: Integer): TCastleBox;
begin
  Result := TCastleBox.Create(AParent);
  Result.Size := ASize;
  Result.Translation := APosition;
  Result.Color := Vector4(AColour.X * FAppearance.FTint.FR,
    AColour.Y * FAppearance.FTint.FG, AColour.Z * FAppearance.FTint.FB, 1);
  Result.Material := pmPhysical;
  Result.PreciseCollisions := True;
  Result.SetEffects([InteriorDetail(ADetail)]);
  AParent.Add(Result);
end;

function TGroundworkBuilder.AccessHeight(const AU, AV: Double): Double;
var
  LX: Double;
  LZ: Double;
begin
  GroundworkToWorld(FAssembly.FGeometry, AU, AV, LX, LZ);
  Result := GroundworkSurfaceHeight(FAssembly.FGeometry, LX, LZ, FHeight) - FAssembly.FGeometry.FDeckY / 1000;
end;

procedure TGroundworkBuilder.Rail(const AParent: TCastleTransform;
  const AU1, AV1, AU2, AV2: Double);
var
  LCount: Integer;
  LU: Double;
  LV: Double;
  LNextU: Double;
  LNextV: Double;
  LY: Double;
  LNextY: Double;
  LLength: Double;
  LBeam: TCastleBox;
  LColour: TVector3;
  I: Integer;
  J: Integer;
begin
  LColour := Vector3(0.18, 0.25, 0.25);
  LCount := Ceil(Max(Abs(AU2 - AU1), Abs(AV2 - AV1)) * 2);
  for I := 0 to LCount do
  begin
    LU := AU1 + (AU2 - AU1) * I / LCount;
    LV := AV1 + (AV2 - AV1) * I / LCount;
    LY := AccessHeight(LU, LV);
    if (I mod 2 = 0) or (I = LCount) then
    begin
      Box(AParent, Vector3(0.08, 1.08, 0.08), Vector3(LU, LY + 0.54, LV),
        LColour, InteriorMetal);
    end;
    if I = LCount then
    begin
      Continue;
    end;
    LNextU := AU1 + (AU2 - AU1) * (I + 1) / LCount;
    LNextV := AV1 + (AV2 - AV1) * (I + 1) / LCount;
    LNextY := AccessHeight(LNextU, LNextV);
    LLength := Sqrt(Sqr(LNextU - LU) + Sqr(LNextV - LV) + Sqr(LNextY - LY));
    for J := 0 to 1 do
    begin
      if Abs(AU2 - AU1) > 0.001 then
      begin
        LBeam := Box(AParent, Vector3(LLength, 0.08, 0.08),
          Vector3((LU + LNextU) / 2, (LY + LNextY) / 2 + 0.52 + J * 0.52,
          (LV + LNextV) / 2), LColour, InteriorMetal);
        LBeam.Rotation := Vector4(0, 0, 1, ArcTan2(LNextY - LY, LNextU - LU));
      end
      else
      begin
        LBeam := Box(AParent, Vector3(0.08, 0.08, LLength),
          Vector3((LU + LNextU) / 2, (LY + LNextY) / 2 + 0.52 + J * 0.52,
          (LV + LNextV) / 2), LColour, InteriorMetal);
        LBeam.Rotation := Vector4(1, 0, 0, -ArcTan2(LNextY - LY, LNextV - LV));
      end;
    end;
  end;
end;

procedure TGroundworkBuilder.AccessMesh(const AParent: TCastleTransform);
var
  LMesh: TIndexedTriangleSetNode;
  LPoints: TCoordinateNode;
  LRoot: TX3DRootNode;
  LShape: TShapeNode;
  LSurface: TAppearanceNode;
  LMaterial: TPhysicalMaterialNode;
  LScene: TCastleScene;
  LTop: array[0..3] of TVector3;
  LBottom: array[0..3] of TVector3;
  LOriginal: array[0..1] of TVector3;
  LCut: array[0..1] of TVector3;
  LU: Double;
  LV: Double;
  LX: Double;
  LZ: Double;
  LPatchX: Double;
  LPatchZ: Double;
  LHeight: Double;
  LBase: Double;
  I: Integer;
  J: Integer;
  K: Integer;

  procedure Quad(const AA, AB, AC, AD: TVector3);
  var
    LAt: Integer;
  begin
    LAt := LPoints.FdPoint.Items.Count;
    LPoints.FdPoint.Items.Add(AA);
    LPoints.FdPoint.Items.Add(AB);
    LPoints.FdPoint.Items.Add(AC);
    LPoints.FdPoint.Items.Add(AD);
    LMesh.FdIndex.Items.Add(LAt);
    LMesh.FdIndex.Items.Add(LAt + 1);
    LMesh.FdIndex.Items.Add(LAt + 2);
    LMesh.FdIndex.Items.Add(LAt);
    LMesh.FdIndex.Items.Add(LAt + 2);
    LMesh.FdIndex.Items.Add(LAt + 3);
  end;

begin
  LPoints := TCoordinateNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := LPoints;
  { Separate face vertices retain deliberate hard edges. Solid fill meets the
    cut soil; top vertices use the same exact plane as the standing surface. }
  for I := 0 to 5 do
  begin
    for J := 0 to 3 do
    begin
      LU := -1;
      if (J = 1) or (J = 2) then
      begin
        LU := 1;
      end;
      LV := 8 + I;
      if J >= 2 then
      begin
        LV := LV + 1;
      end;
      GroundworkToWorld(FAssembly.FGeometry, LU, LV, LX, LZ);
      LHeight := AccessHeight(LU, LV);
      LBase := FHeight.Height(LX, LZ) - FAssembly.FGeometry.FDeckY / 1000;
      LTop[J] := Vector3(LU, LHeight, LV);
      LBottom[J] := Vector3(LU, Min(LBase - 0.1, LHeight - GroundworkSlabMetres - 0.02), LV);
    end;
    Quad(LTop[0], LTop[3], LTop[2], LTop[1]);
    Quad(LBottom[0], LBottom[1], LBottom[2], LBottom[3]);
    Quad(LTop[0], LTop[1], LBottom[1], LBottom[0]);
    Quad(LTop[3], LBottom[3], LBottom[2], LTop[2]);
    Quad(LTop[0], LBottom[0], LBottom[3], LTop[3]);
    Quad(LTop[1], LTop[2], LBottom[2], LBottom[1]);
  end;
  { Retaining faces close both sides of ramp excavation and graded landing.
    Patch-specific soil values preserve the 18cm underside step at the toe. }
  for I := 0 to 21 do
  begin
    for K := 0 to 1 do
    begin
      LU := K * 2 - 1;
      LV := 8.5 + I;
      if I >= 6 then
      begin
        LV := 14 + (I - 6 + 0.5) / 8;
      end;
      GroundworkToWorld(FAssembly.FGeometry, LU * 0.5, LV, LPatchX, LPatchZ);
      for J := 0 to 1 do
      begin
        LV := 8 + I + J;
        if I >= 6 then
        begin
          LV := 14 + (I - 6 + J) / 8;
        end;
        GroundworkToWorld(FAssembly.FGeometry, LU, LV, LX, LZ);
        LOriginal[J] := Vector3(LU,
          FHeight.Height(LX, LZ) - FAssembly.FGeometry.FDeckY / 1000, LV);
        LCut[J] := Vector3(LU, GroundworkSoilPatch(FAssembly.FGeometry, LX, LZ,
          LPatchX, LPatchZ, FHeight) - FAssembly.FGeometry.FDeckY / 1000, LV);
      end;
      if (Abs(LOriginal[0].Y - LCut[0].Y) > 0.00001) or
        (Abs(LOriginal[1].Y - LCut[1].Y) > 0.00001) then
      begin
        Quad(LOriginal[0], LOriginal[1], LCut[1], LCut[0]);
        Quad(LOriginal[1], LOriginal[0], LCut[0], LCut[1]);
      end;
    end;
  end;
  LMaterial := TPhysicalMaterialNode.Create;
  LMaterial.BaseColor := Vector3(0.44 * FAppearance.FTint.FR,
    0.49 * FAppearance.FTint.FG, 0.43 * FAppearance.FTint.FB);
  LMaterial.Metallic := 0;
  LMaterial.Roughness := 0.83;
  LSurface := TAppearanceNode.Create;
  LSurface.Material := LMaterial;
  LShape := TShapeNode.Create;
  LShape.Geometry := LMesh;
  LShape.Appearance := LSurface;
  LRoot := TX3DRootNode.Create;
  LRoot.AddChildren(LShape);
  LScene := TCastleScene.Create(AParent);
  LScene.Load(LRoot, True);
  LScene.PreciseCollisions := True;
  LScene.SetEffects([InteriorDetail(InteriorPlaster)]);
  AParent.Add(LScene);
end;

procedure TGroundworkBuilder.Build;
var
  LPart: TGroundworkPart;
  LAccess: TGroundworkPart;
  LGuard: TCastleTransform;
  LColour: TVector3;
  LHeight: Double;
  LWidth: Double;
  LX: Double;
  LZ: Double;
  LY: Double;
  LDetail: Integer;
  I: Integer;
  J: Integer;
begin
  FRoot.Translation := Vector3(FAssembly.FGeometry.FX / 1000, FAssembly.FGeometry.FDeckY / 1000,
    FAssembly.FGeometry.FZ / 1000);
  FDeck := TGroundworkPart.Create(FRoot);
  FDeck.FObjectId := FAssembly.FId + '.deck';
  FRoot.Add(FDeck);
  for I := 0 to 15 do
  begin
    if (I = 6) or (I = 9) or (I = 10) then
    begin
      Continue;
    end;
    LWidth := 4;
    LX := (I mod 4) * 4 - 6;
    LZ := (I div 4) * 4 - 6;
    if I = 5 then
    begin
      LWidth := 8;
      LX := 0;
      LZ := 0;
    end;
    LDetail := InteriorPlaster;
    case FAssembly.FMaterials[I] of
      gmStone:
        begin
          LColour := Vector3(0.38, 0.43, 0.37);
        end;
      gmConcrete:
        begin
          LColour := Vector3(0.57, 0.60, 0.53);
        end;
      gmCeramic:
        begin
          LColour := Vector3(0.25, 0.42, 0.40);
          LDetail := InteriorCeramic;
        end;
      gmSteel:
        begin
          LColour := Vector3(0.32, 0.37, 0.39);
          LDetail := InteriorMetal;
        end;
    end;
    LPart := Part(GroundworkPartId(FAssembly.FId, I));
    Box(LPart, Vector3(LWidth, GroundworkSlabMetres, LWidth),
      Vector3(LX, -GroundworkSlabMetres / 2, LZ), LColour, LDetail);
  end;
  LPart := Part(FAssembly.FId + '.deck.body');
  LHeight := (FAssembly.FGeometry.FDeckY - FAssembly.FGeometry.FBottomY) / 1000 -
    GroundworkSlabMetres;
  LColour := Vector3(0.34, 0.39, 0.34);
  if FAssembly.FBody = gbPlinth then
  begin
    Box(LPart, Vector3(16, LHeight, 16), Vector3(0, -GroundworkSlabMetres - LHeight / 2, 0),
      LColour, InteriorPlaster);
  end
  else
  begin
    for I := 0 to 2 do
    begin
      for J := 0 to 2 do
      begin
        Box(LPart, Vector3(0.55, LHeight, 0.55),
          Vector3(I * 7 - 7, -GroundworkSlabMetres - LHeight / 2, J * 7 - 7),
          LColour, InteriorPlaster);
      end;
    end;
    { Visible horizontal infill closes the non-enterable underside. Gaps are
      smaller than the standing player's body; open under-deck traversal is
      not implied by the pier recipe and single-support navigation. }
    for I := 0 to Ceil(LHeight / 0.35) do
    begin
      LY := -GroundworkSlabMetres - Min(LHeight, I * 0.35);
      for J := 0 to 1 do
      begin
        Box(LPart, Vector3(16, 0.06, 0.06), Vector3(0, LY, J * 15.94 - 7.97),
          Vector3(0.20, 0.28, 0.27), InteriorMetal);
        Box(LPart, Vector3(0.06, 0.06, 16), Vector3(J * 15.94 - 7.97, LY, 0),
          Vector3(0.20, 0.28, 0.27), InteriorMetal);
      end;
    end;
  end;
  LAccess := Part(FAssembly.FId + '.deck.ramp');
  LAccess.Rotation := Vector4(0, 1, 0, FAssembly.FGeometry.FQuarterTurn * Pi / 2);
  AccessMesh(LAccess);
  LGuard := TCastleTransform.Create(FDeck);
  LGuard.Rotation := Vector4(0, 1, 0, FAssembly.FGeometry.FQuarterTurn * Pi / 2);
  FDeck.Add(LGuard);
  Rail(LGuard, -8, -8, -8, 8);
  Rail(LGuard, 8, -8, 8, 8);
  Rail(LGuard, -8, -8, 8, -8);
  Rail(LGuard, -8, 8, -1, 8);
  Rail(LGuard, 1, 8, 8, 8);
  Rail(LAccess, -1, 8, -1, 16);
  Rail(LAccess, 1, 8, 1, 16);
end;

function CreateGroundworkScene(const AOwner: TComponent; const AAssembly: TGroundworkAssembly;
  const AAppearance: TWorldAppearance; const AHeight: TWorldHeight): TCastleTransform;
var
  LBuilder: TGroundworkBuilder;
begin
  Result := TGroundworkPart.Create(AOwner);
  TGroundworkPart(Result).FObjectId := AAssembly.FId;
  LBuilder := TGroundworkBuilder.Create(Result, AAssembly, AAppearance, AHeight);
  try
    try
      LBuilder.Build;
    except
      Result.Free;
      raise;
    end;
  finally
    LBuilder.Free;
  end;
end;

end.
