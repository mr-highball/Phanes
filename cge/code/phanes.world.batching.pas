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

unit phanes.world.batching;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  CastleTransform,
  CastleScene,
  CastleShapes,
  CastleVectors,
  CastleRenderOptions,
  X3DNodes,
  phanes.world.appearance;

type
  TStaticFoliageBatch = class
  private type
    TPart = record
      FSource: TShape;
      FMatrix: TMatrix4;
      FClosureScene: TCastleScene;
    end;
    TParts = array of TPart;
    TGroup = record
      FSource: TShape;
      FShape: TShapeNode;
      FSurface: TFloatVertexAttributeNode;
    end;
  private
    FRoot: TX3DRootNode;
    FGroups: array of TGroup;
    FInstances: Integer;
    FDefaultOptions: TCastleRenderOptions;
    FClosureScene: TCastleScene;
    FClassified: Boolean;
    function Collect(const ATransform: TCastleTransform; const AParent: TMatrix4;
      const AIncludeTransform: Boolean; var AParts: TParts;
      const ADepth: Integer): Boolean;
    procedure Append(const APart: TPart);
  public
    constructor Create;
    destructor Destroy; override;
    { Add only a complete eligible static instance. False leaves it entirely
      with the caller for normal CGE reference rendering. Saved WFC placements,
      collision admission and selection ownership remain outside this cache. }
    function Add(const AReference: TCastleTransformReference): Boolean;
    function Finish(const AOwner: TComponent; const AAppearance: TWorldAppearance): TCastleScene;
    property Instances: Integer read FInstances;
  end;

implementation

uses
  Math,
  SysUtils,
  CastleImages,
  CastleBoxes,
  CastleURIUtils,
  X3DFields,
  phanes.world.shadowcache,
  phanes.world.surfaces;

const
  BatchVertexLimit = 60000;

{ Compare the complete fields of supported static material nodes, including
  texture transforms and sampling properties. Relative texture names are only
  equivalent when they resolve to the same source; two kits may both contain
  Textures/colormap.png. Unknown nodes retain separate draws. }
function SameStaticNode(const ALeft, ARight: TX3DNode;
  const ADepth: Integer = 0): Boolean;
var
  LLeft: TX3DField;
  LRight: TX3DField;
  I: Integer;
  J: Integer;
begin
  if ALeft = ARight then
  begin
    Exit(True);
  end;
  Result := False;
  if (ALeft = nil) or (ARight = nil) or (ADepth > 12) or
    (ALeft.ClassType <> ARight.ClassType) or (ALeft.FieldsCount <> ARight.FieldsCount) then
  begin
    Exit;
  end;
  if not ((ALeft is TAppearanceNode) or (ALeft is TPhysicalMaterialNode) or
    (ALeft is TMaterialNode) or (ALeft is TUnlitMaterialNode) or
    (ALeft is TImageTextureNode) or (ALeft is TTexturePropertiesNode) or
    (ALeft is TTextureTransformNode) or (ALeft is TMultiTextureTransformNode)) then
  begin
    Exit;
  end;
  for I := 0 to ALeft.FieldsCount - 1 do
  begin
    LLeft := ALeft.Fields[I];
    LRight := ARight.Fields[I];
    if (LLeft.ClassType <> LRight.ClassType) or (LLeft.X3DName <> LRight.X3DName) then
    begin
      Exit;
    end;
    if (ALeft is TPhysicalMaterialNode) and (LLeft.X3DName = 'baseColor') then
    begin
      { Base RGB moves into a constant colour at every source vertex. CGE's
        physical shader applies that colour before its base texture and light
        calculation; all other material fields still have to match exactly. }
      Continue;
    end;
    if (ALeft is TImageTextureNode) and (LLeft.X3DName = 'url') then
    begin
      if TMFString(LLeft).Count <> TMFString(LRight).Count then
      begin
        Exit;
      end;
      for J := 0 to TMFString(LLeft).Count - 1 do
      begin
        if CombineURI(ALeft.BaseUrl, TMFString(LLeft).Items[J]) <>
          CombineURI(ARight.BaseUrl, TMFString(LRight).Items[J]) then
        begin
          Exit;
        end;
      end;
    end
    else if LLeft is TSFNode then
    begin
      if not SameStaticNode(TSFNode(LLeft).Value, TSFNode(LRight).Value, ADepth + 1) then
      begin
        Exit;
      end;
    end
    else if LLeft is TMFNode then
    begin
      if TMFNode(LLeft).Count <> TMFNode(LRight).Count then
      begin
        Exit;
      end;
      for J := 0 to TMFNode(LLeft).Count - 1 do
      begin
        if not SameStaticNode(TMFNode(LLeft).Items[J], TMFNode(LRight).Items[J],
          ADepth + 1) then
        begin
          Exit;
        end;
      end;
    end
    else if not (LLeft.FastEqualsValue(LRight) or
      ((LLeft is TX3DMultField) and (TX3DMultField(LLeft).Count = 0) and
      (TX3DMultField(LRight).Count = 0))) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function TextureChannelCount(const ANode: TAbstractTextureCoordinateNode): Integer;
begin
  if ANode = nil then
  begin
    Exit(0);
  end;
  if ANode is TMultiTextureCoordinateNode then
  begin
    Exit(TMultiTextureCoordinateNode(ANode).FdTexCoord.Count);
  end;
  Result := 1;
end;

function TextureChannel(const ANode: TAbstractTextureCoordinateNode;
  const AIndex: Integer): TX3DNode;
begin
  if ANode is TMultiTextureCoordinateNode then
  begin
    Exit(TMultiTextureCoordinateNode(ANode).FdTexCoord.Items[AIndex]);
  end;
  Result := ANode;
end;

function Eligible(const AShape: TShape): Boolean;
var
  LMesh: TIndexedTriangleSetNode;
  LCount: Integer;
  LChannel: TX3DNode;
  I: Integer;
begin
  Result := False;
  if not (AShape.Geometry is TIndexedTriangleSetNode) or
    (AShape.Node = nil) or (AShape.State.LocalFog <> nil) or
    ((AShape.State.ClipPlanes <> nil) and (AShape.State.ClipPlanes.Count <> 0)) or
    ((AShape.State.Lights <> nil) and (AShape.State.Lights.Count <> 0)) or
    (AShape.AlphaChannel = acBlending) then
  begin
    Exit;
  end;
  LMesh := TIndexedTriangleSetNode(AShape.Geometry);
  if (LMesh.FdRadianceTransfer.Count <> 0) or (LMesh.FdSkinWeights0.Count <> 0) or
    (LMesh.FdSkinJoints0.Count <> 0) or (TextureChannelCount(LMesh.TexCoord) = 0) then
  begin
    { Without explicit UVs CGE can derive mapping from each source bound. A
      combined bound would change that mapping, so keep the source instance. }
    Exit;
  end;
  if AShape.State.Effects <> nil then
  begin
    for I := 0 to AShape.State.Effects.Count - 1 do
    begin
      if not (AShape.State.Effects[I] is TWorldSurfaceEffect) then
      begin
        Exit;
      end;
    end;
  end;
  if (AShape.State.Appearance <> nil) and
    ((AShape.State.Appearance.FdEffects.Count <> 0) or
    (AShape.State.Appearance.FdShaders.Count <> 0) or
    (AShape.State.Appearance.BackMaterial <> nil)) then
  begin
    Exit;
  end;
  if not (LMesh.Coord is TCoordinateNode) or not (LMesh.Normal is TNormalNode) or
    not LMesh.NormalPerVertex or (LMesh.Color <> nil) or
    (LMesh.FdAttrib.Count <> 0) or (LMesh.FdFogCoord.Value <> nil) then
  begin
    Exit;
  end;
  LCount := TCoordinateNode(LMesh.Coord).FdPoint.Count;
  if (LCount = 0) or (LCount > BatchVertexLimit) or
    (TNormalNode(LMesh.Normal).FdVector.Count <> LCount) or
    (LMesh.FdIndex.Count mod 3 <> 0) then
  begin
    Exit;
  end;
  if (LMesh.Tangent <> nil) and
    (not (LMesh.Tangent is TTangentNode) or
    (TTangentNode(LMesh.Tangent).FdVector.Count <> LCount)) then
  begin
    Exit;
  end;
  for I := 0 to TextureChannelCount(LMesh.TexCoord) - 1 do
  begin
    LChannel := TextureChannel(LMesh.TexCoord, I);
    if not (LChannel is TTextureCoordinateNode) or
      (TTextureCoordinateNode(LChannel).FdPoint.Count <> LCount) then
    begin
      Exit;
    end;
  end;
  for I := 0 to LMesh.FdIndex.Count - 1 do
  begin
    if (LMesh.FdIndex.Items[I] < 0) or (LMesh.FdIndex.Items[I] >= LCount) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function SameLayout(const ALeft, ARight: TShape): Boolean;
var
  LLeft: TIndexedTriangleSetNode;
  LRight: TIndexedTriangleSetNode;
  LField: TX3DField;
  LOther: TX3DField;
  LChannel: TTextureCoordinateNode;
  LOtherChannel: TTextureCoordinateNode;
  I: Integer;
begin
  if ALeft = ARight then
  begin
    Exit(True);
  end;
  Result := False;
  if (ALeft.Node.Shading <> ARight.Node.Shading) or
    ((ALeft.InternalShadowVolumes.BorderEdges.Count = 0) <>
    (ARight.InternalShadowVolumes.BorderEdges.Count = 0)) or
    not SameStaticNode(ALeft.State.Appearance, ARight.State.Appearance) then
  begin
    Exit;
  end;
  LLeft := TIndexedTriangleSetNode(ALeft.Geometry);
  LRight := TIndexedTriangleSetNode(ARight.Geometry);
  if (LLeft.FieldsCount <> LRight.FieldsCount) or
    ((LLeft.Tangent = nil) <> (LRight.Tangent = nil)) or
    (TextureChannelCount(LLeft.TexCoord) <> TextureChannelCount(LRight.TexCoord)) then
  begin
    Exit;
  end;
  for I := 0 to LLeft.FieldsCount - 1 do
  begin
    LField := LLeft.Fields[I];
    LOther := LRight.Fields[I];
    if (LField.X3DName <> LOther.X3DName) or (LField.ClassType <> LOther.ClassType) then
    begin
      Exit;
    end;
    if (LField.X3DName = 'coord') or (LField.X3DName = 'normal') or
      (LField.X3DName = 'tangent') or (LField.X3DName = 'texCoord') or
      (LField.X3DName = 'index') then
    begin
      Continue;
    end;
    if LField is TSFNode then
    begin
      if not SameStaticNode(TSFNode(LField).Value, TSFNode(LOther).Value) then
      begin
        Exit;
      end;
    end
    else if LField is TMFNode then
    begin
      if not LField.Equals(LOther) then
      begin
        Exit;
      end;
    end
    else if not (LField.FastEqualsValue(LOther) or
      ((LField is TX3DMultField) and (TX3DMultField(LField).Count = 0) and
      (TX3DMultField(LOther).Count = 0))) then
    begin
      Exit;
    end;
  end;
  for I := 0 to TextureChannelCount(LLeft.TexCoord) - 1 do
  begin
    LChannel := TTextureCoordinateNode(TextureChannel(LLeft.TexCoord, I));
    LOtherChannel := TTextureCoordinateNode(TextureChannel(LRight.TexCoord, I));
    if LChannel.Mapping <> LOtherChannel.Mapping then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function UniformAxes(const AMatrix: TMatrix4): Boolean;
var
  LAxes: array[0..2] of TVector3;
  LLength: Single;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    LAxes[I] := Vector3(AMatrix[I, 0], AMatrix[I, 1], AMatrix[I, 2]);
  end;
  LLength := LAxes[0].LengthSqr;
  Result := (LLength > 0) and
    (Abs(LAxes[1].LengthSqr - LLength) <= LLength * 0.00001) and
    (Abs(LAxes[2].LengthSqr - LLength) <= LLength * 0.00001) and
    (Abs(TVector3.DotProduct(LAxes[0], LAxes[1])) <= LLength * 0.00001) and
    (Abs(TVector3.DotProduct(LAxes[0], LAxes[2])) <= LLength * 0.00001) and
    (Abs(TVector3.DotProduct(LAxes[1], LAxes[2])) <= LLength * 0.00001);
end;

function HasTangentBasis(const AShape: TShape): Boolean;
var
  LMaterial: TAbstractMaterialNode;
begin
  Result := TIndexedTriangleSetNode(AShape.Geometry).Tangent <> nil;
  if AShape.State.Appearance <> nil then
  begin
    Result := Result or (AShape.State.Appearance.NormalMap <> nil);
    LMaterial := AShape.State.Appearance.Material;
    if LMaterial is TAbstractOneSidedMaterialNode then
    begin
      { CGE may generate tangents lazily for a normal-textured mesh. }
      Result := Result or (TAbstractOneSidedMaterialNode(LMaterial).NormalTexture <> nil);
    end;
  end;
end;

constructor TStaticFoliageBatch.Create;
begin
  inherited Create;
  FRoot := TX3DRootNode.Create;
  FDefaultOptions := TCastleRenderOptions.Create(nil);
end;

destructor TStaticFoliageBatch.Destroy;
begin
  FRoot.Free;
  FDefaultOptions.Free;
  inherited;
end;

function TStaticFoliageBatch.Collect(const ATransform: TCastleTransform;
  const AParent: TMatrix4; const AIncludeTransform: Boolean;
  var AParts: TParts; const ADepth: Integer): Boolean;
var
  LMatrix: TMatrix4;
  LReference: TCastleTransformReference;
  LScene: TCastleScene;
  LShapes: TShapeList;
  LPart: TPart;
  LClosureScene: TCastleScene;
  LAt: Integer;
  I: Integer;
begin
  Result := False;
  if (ATransform = nil) or (ADepth > 16) or not ATransform.Exists or
    not ATransform.Visible or not ATransform.CastShadows or not ATransform.Collides or
    not ATransform.Pickable or (ATransform.RenderLayer <> rlParent) then
  begin
    Exit;
  end;
  LMatrix := AParent;
  if AIncludeTransform then
  begin
    LMatrix := LMatrix * ATransform.Transform;
  end;
  if ATransform is TCastleTransformReference then
  begin
    LReference := TCastleTransformReference(ATransform);
    if LReference.ReferenceTransformation = rtIgnoreTranslation then
    begin
      Exit;
    end;
    Exit(Collect(LReference.Reference, LMatrix,
      LReference.ReferenceTransformation = rtDoNotIgnore, AParts, ADepth + 1));
  end;
  if ATransform is TCastleScene then
  begin
    LScene := TCastleScene(ATransform);
    if (LScene.AnimationsList.Count <> 0) or not LScene.ReceiveShadowVolumes or
      (LScene.DistanceCulling <> 0) or not LScene.RenderOptions.Equals(FDefaultOptions) then
    begin
      Exit;
    end;
    LShapes := LScene.Shapes.TraverseList(True, True);
    LClosureScene := nil;
    if LScene.InternalDetectedWholeSceneManifold then
    begin
      LClosureScene := LScene;
      for I := 1 to LShapes.Count - 1 do
      begin
        { Shared boundary vertices must undergo identical floating-point
          operations when baked. Other imported closure arrangements retain
          their complete source scene and its own shadow-volume handling. }
        if not TMatrix4.PerfectlyEquals(LShapes[I].State.Transformation.Transform,
          LShapes[0].State.Transformation.Transform) then
        begin
          Exit;
        end;
      end;
    end;
    for I := 0 to LShapes.Count - 1 do
    begin
      if not Eligible(LShapes[I]) then
      begin
        Exit;
      end;
      LPart.FSource := LShapes[I];
      LPart.FClosureScene := LClosureScene;
      LPart.FMatrix := LMatrix * LShapes[I].State.Transformation.Transform;
      if Abs(LPart.FMatrix.Determinant) < 0.00000001 then
      begin
        Exit;
      end;
      { The pinned CGE normal-map basis uses the normal matrix for both tangent
        axes. General nonuniform/sheared transforms cannot be replaced by a
        single normalized baked tangent without changing that basis. }
      if HasTangentBasis(LPart.FSource) and not UniformAxes(LPart.FMatrix) then
      begin
        Exit;
      end;
      LAt := Length(AParts);
      SetLength(AParts, LAt + 1);
      AParts[LAt] := LPart;
    end;
  end
  else if ATransform.ClassType <> TCastleTransform then
  begin
    Exit;
  end;
  for I := 0 to ATransform.Count - 1 do
  begin
    if not Collect(ATransform[I], LMatrix, True, AParts, ADepth + 1) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

procedure TStaticFoliageBatch.Append(const APart: TPart);
var
  LSource: TIndexedTriangleSetNode;
  LTarget: TIndexedTriangleSetNode;
  LShape: TShapeNode;
  LNormalMatrix: TMatrix3;
  LNormal: TVector3;
  LTangent: TVector4;
  LTangentDirection: TVector3;
  LScale: TVector3;
  LPoint: TVector3;
  LDeterminant: Single;
  LBase: Integer;
  LCount: Integer;
  LGroup: Integer;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  LSource := TIndexedTriangleSetNode(APart.FSource.Geometry);
  LCount := TCoordinateNode(LSource.Coord).FdPoint.Count;
  LGroup := -1;
  for I := 0 to High(FGroups) do
  begin
    if ((FClosureScene = nil) or (FGroups[I].FSource = APart.FSource)) and
      SameLayout(FGroups[I].FSource, APart.FSource) and
      (TCoordinateNode(TIndexedTriangleSetNode(FGroups[I].FShape.Geometry).Coord).
      FdPoint.Count + LCount <= BatchVertexLimit) then
    begin
      LGroup := I;
      Break;
    end;
  end;
  if LGroup < 0 then
  begin
    LGroup := Length(FGroups);
    SetLength(FGroups, LGroup + 1);
    LShape := TShapeNode(APart.FSource.Node.DeepCopy);
    { Imported glTF shapes carry explicit accessor bounds. Those describe one
      source mesh, so let CGE derive the new bounds from the combined vertices. }
    LShape.BBox := TBox3D.Empty;
    FRoot.AddChildren(LShape);
    FGroups[LGroup].FSource := APart.FSource;
    FGroups[LGroup].FShape := LShape;
    LTarget := TIndexedTriangleSetNode(LShape.Geometry);
    if (LShape.Appearance <> nil) and
      (LShape.Appearance.Material is TPhysicalMaterialNode) then
    begin
      TPhysicalMaterialNode(LShape.Appearance.Material).BaseColor := Vector3(1, 1, 1);
      LTarget.Color := TColorNode.Create;
      LTarget.Color.Mode := cmReplace;
      LTarget.ColorPerVertex := True;
    end;
    TCoordinateNode(LTarget.Coord).FdPoint.Items.Clear;
    TNormalNode(LTarget.Normal).FdVector.Items.Clear;
    if LTarget.Tangent <> nil then
    begin
      TTangentNode(LTarget.Tangent).FdVector.Items.Clear;
    end;
    for I := 0 to TextureChannelCount(LTarget.TexCoord) - 1 do
    begin
      TTextureCoordinateNode(TextureChannel(LTarget.TexCoord, I)).FdPoint.Items.Clear;
    end;
    LTarget.FdIndex.Items.Clear;
    FGroups[LGroup].FSurface := TFloatVertexAttributeNode.Create;
    FGroups[LGroup].FSurface.NameField := 'phanesOriginalSurface';
    FGroups[LGroup].FSurface.NumComponents := 3;
    LTarget.FdAttrib.Add(FGroups[LGroup].FSurface);
  end;
  LTarget := TIndexedTriangleSetNode(FGroups[LGroup].FShape.Geometry);
  LBase := TCoordinateNode(LTarget.Coord).FdPoint.Count;
  LDeterminant := APart.FMatrix.Determinant;
  for J := 0 to 2 do
  begin
    for I := 0 to 2 do
    begin
      LNormalMatrix[J, I] := APart.FMatrix[J, I];
    end;
    LScale.Data[J] := Vector3(APart.FMatrix[J, 0], APart.FMatrix[J, 1],
      APart.FMatrix[J, 2]).Length;
  end;
  LNormalMatrix := LNormalMatrix.Inverse(LDeterminant).Transpose;
  for I := 0 to LCount - 1 do
  begin
    LPoint := TCoordinateNode(LSource.Coord).FdPoint.Items[I];
    TCoordinateNode(LTarget.Coord).FdPoint.Items.Add(APart.FMatrix.MultPoint(LPoint));
    if LTarget.Color <> nil then
    begin
      TColorNode(LTarget.Color).FdColor.Items.Add(
        TPhysicalMaterialNode(APart.FSource.State.Appearance.Material).BaseColor);
    end;
    LNormal := (LNormalMatrix * TNormalNode(LSource.Normal).FdVector.Items[I]).Normalize;
    TNormalNode(LTarget.Normal).FdVector.Items.Add(LNormal);
    if LSource.Tangent <> nil then
    begin
      LTangent := TTangentNode(LSource.Tangent).FdVector.Items[I];
      LTangentDirection := APart.FMatrix.MultDirection(
        Vector3(LTangent.X, LTangent.Y, LTangent.Z));
      LTangentDirection := (LTangentDirection -
        LNormal * TVector3.DotProduct(LNormal, LTangentDirection)).Normalize;
      if LDeterminant < 0 then
      begin
        LTangent.W := -LTangent.W;
      end;
      TTangentNode(LTarget.Tangent).FdVector.Items.Add(Vector4(LTangentDirection, LTangent.W));
    end;
    for J := 0 to TextureChannelCount(LSource.TexCoord) - 1 do
    begin
      TTextureCoordinateNode(TextureChannel(LTarget.TexCoord, J)).FdPoint.Items.Add(
        TTextureCoordinateNode(TextureChannel(LSource.TexCoord, J)).FdPoint.Items[I]);
    end;
    for J := 0 to 2 do
    begin
      FGroups[LGroup].FSurface.FdValue.Items.Add(LPoint[J] * LScale[J]);
    end;
  end;
  for I := 0 to LSource.FdIndex.Count - 1 do
  begin
    LIndex := I;
    if LDeterminant < 0 then
    begin
      if I mod 3 = 1 then
      begin
        Inc(LIndex);
      end
      else if I mod 3 = 2 then
      begin
        Dec(LIndex);
      end;
    end;
    LTarget.FdIndex.Items.Add(LBase + LSource.FdIndex.Items[LIndex]);
  end;
end;

function TStaticFoliageBatch.Add(const AReference: TCastleTransformReference): Boolean;
var
  LParts: TParts;
  I: Integer;
begin
  LParts := nil;
  Result := (FRoot <> nil) and Collect(AReference, TMatrix4.Identity, True, LParts, 0);
  if not Result or (Length(LParts) = 0) then
  begin
    Exit(False);
  end;
  { Some imported objects close only when all their material parts are kept
    together. Mixing them into an unrelated open scene silently disables CGE
    shadow volumes. Keep one complete closure owner per such batch. }
  for I := 0 to High(LParts) do
  begin
    if (LParts[I].FClosureScene <> LParts[0].FClosureScene) or
      (FClassified and (FClosureScene <> LParts[I].FClosureScene)) then
    begin
      Exit(False);
    end;
  end;
  FClosureScene := LParts[0].FClosureScene;
  FClassified := True;
  for I := 0 to High(LParts) do
  begin
    Append(LParts[I]);
  end;
  Inc(FInstances);
end;

function TStaticFoliageBatch.Finish(const AOwner: TComponent;
  const AAppearance: TWorldAppearance): TCastleScene;
var
  LRoot: TX3DRootNode;
begin
  Result := nil;
  if (FRoot = nil) or (FInstances = 0) then
  begin
    Exit;
  end;
  Result := TStaticShadowScene.Create(AOwner);
  try
    LRoot := FRoot;
    FRoot := nil;
    Result.Load(LRoot, True);
    Result.PreciseCollisions := True;
    ApplyWorldSurface(Result, AAppearance, True);
  except
    Result.Free;
    raise;
  end;
end;

end.
