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

program PhanesTestsBatching;
{$mode delphi}
{$H+}
uses
  SysUtils, Classes, Math, FPJSON, JSONParser,
  CastleTransform, CastleScene, CastleShapes, CastleVectors, CastleBoxes, CastleURIUtils,
  X3DNodes, phanes.world.batching, phanes.world.appearance, phanes.scene.picking,
  phanes.structures.scene;
var
  GChecks: Integer;
  GAssets: Integer;
  GPalette: TJSONObject;
  GText: TStringList;
  GAsset: TJSONObject;
  GOwner: TComponent;
  GScene: TCastleScene;
  GOriginal: TCastleTransform;
  GReference: TCastleTransformReference;
  GBatch: TStaticFoliageBatch;
  GCombined: TCastleScene;
  GBounds: TBox3D;
  GOther: TBox3D;
  GRayOriginal: TRayCollision;
  GRayCombined: TRayCollision;
  GOrigin: TVector3;
  GPoint: TVector3;
  GMaxError: Double;
  GBeforeVertices: Integer;
  GShapes: TShapeList;
  GUnsupported: TCastleSphere;
  I: Integer;
  J: Integer;
  K: Integer;
  X: Integer;
  Z: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;
function Vertices(const AScene: TCastleScene): Integer;
var
  LShapes: TShapeList;
  I: Integer;
begin
  Result := 0;
  LShapes := AScene.Shapes.TraverseList(True, True);
  for I := 0 to LShapes.Count - 1 do
  begin
    Inc(Result, TCoordinateNode(TIndexedTriangleSetNode(LShapes[I].Geometry).Coord).FdPoint.Count);
  end;
end;

function ShadowTriangles(const AScene: TCastleScene): Integer;
var
  LShapes: TShapeList;
  LWhole: Boolean;
  I: Integer;
begin
  Result := 0;
  LWhole := AScene.InternalDetectedWholeSceneManifold;
  LShapes := AScene.Shapes.TraverseList(True, True);
  for I := 0 to LShapes.Count - 1 do
  begin
    if LWhole or (LShapes[I].InternalShadowVolumes.BorderEdges.Count = 0) then
    begin
      Inc(Result, LShapes[I].InternalShadowVolumes.TrianglesListShadowCasters.Count);
    end;
  end;
end;

procedure CabinGeometry;
var
  LOwner: TComponent;
  LBefore: TCastleTransform;
  LAfter: TCastleTransform;
  LOriginalHit: TRayCollision;
  LBatchHit: TRayCollision;
  LOrigin: TVector3;
  LDirection: TVector3;
  LX: Integer;
  LY: Integer;
  LAxis: Integer;
  LError: Double;

  procedure KeepGeometry(const ARoot: TCastleTransform; const AOriginal: Boolean);
  var
    I: Integer;
  begin
    for I := ARoot.Count - 1 downto 0 do
    begin
      if (AOriginal and (ARoot[I].ClassName = 'TCabinBatch')) or
        (not AOriginal and (ARoot[I].ClassName = 'TCabinBox') and not ARoot[I].Visible) then
      begin
        ARoot.Remove(ARoot[I]);
      end
      else
      begin
        ARoot[I].Visible := True;
        KeepGeometry(ARoot[I], AOriginal);
      end;
    end;
  end;

begin
  LOwner := TComponent.Create(nil);
  LError := 0;
  try
    LBefore := CreateCabinShell(LOwner, SolveWorldAppearance(731));
    LAfter := CreateCabinShell(LOwner, SolveWorldAppearance(731));
    KeepGeometry(LBefore, True);
    KeepGeometry(LAfter, False);
    for LAxis := 0 to 2 do
    begin
      LDirection := TVector3.Zero;
      LDirection.Data[LAxis] := -1;
      for LY := 0 to 50 do
      begin
        for LX := 0 to 70 do
        begin
          LOrigin := TVector3.Zero;
          LOrigin.Data[LAxis] := 20;
          LOrigin.Data[(LAxis + 1) mod 3] := -6 + (LX + 0.31) / 71 * 12;
          LOrigin.Data[(LAxis + 2) mod 3] := -6 + (LY + 0.39) / 51 * 12;
          LOriginalHit := VisibleRayCollision(LBefore, LOrigin, LDirection);
          LBatchHit := VisibleRayCollision(LAfter, LOrigin, LDirection);
          try
            Check((LOriginalHit = nil) = (LBatchHit = nil), 'Cabin silhouette survives batching');
            if LOriginalHit <> nil then
            begin
              LError := Max(LError, Abs(LOriginalHit.Distance - LBatchHit.Distance));
              Check(Abs(LOriginalHit.Distance - LBatchHit.Distance) < 0.002,
                'Cabin walls, openings and trim retain actual CGE contact');
            end;
          finally
            LOriginalHit.Free;
            LBatchHit.Free;
          end;
        end;
      end;
    end;
    WriteLn('PASS cabin actual geometry; maximum ray error ', LError * 1000:0:6, ' mm');
  finally
    LOwner.Free;
  end;
end;

procedure MaterialSharing;
var
  LOwner: TComponent;
  LFirst: TCastleScene;
  LSecond: TCastleScene;
  LCombined: TCastleScene;
  LBatch: TStaticFoliageBatch;
  LReference: TCastleTransformReference;
  LMaterial: TPhysicalMaterialNode;
  LTexture: TImageTextureNode;
  LShape: TShape;
  LShapes: Integer;
  LCase: Integer;
  LMesh: TIndexedTriangleSetNode;
  LColors: TColorNode;
  I: Integer;
begin
  for LCase := 0 to 7 do
  begin
    LOwner := TComponent.Create(nil);
    LBatch := TStaticFoliageBatch.Create;
    try
      LFirst := TCastleScene.Create(LOwner);
      LFirst.Load('cge/data/kits/nature-kit/plant_bush.glb');
      LTexture := TImageTextureNode.Create;
      LTexture.BaseUrl := FilenameToUriSafe(ExpandFileName(
        'cge/data/kits/city-kit-suburban/model.glb'));
      LTexture.SetUrl(['Textures/colormap.png']);
      TPhysicalMaterialNode(LFirst.Shapes.TraverseList(True, True)[0].
        State.Appearance.Material).BaseTexture := LTexture;
      LSecond := TCastleScene.Create(LOwner);
      LSecond.Load(TX3DRootNode(LFirst.RootNode.DeepCopy), True);
      LShapes := LFirst.Shapes.TraverseList(True, True).Count;
      Check(LShapes = 1, 'Cross-source material fixture contains a single material');
      LShape := LSecond.Shapes.TraverseList(True, True)[0];
      LMaterial := TPhysicalMaterialNode(LShape.State.Appearance.Material);
      LTexture := TImageTextureNode(LMaterial.BaseTexture);
      case LCase of
        1:
        begin
          LMaterial.Roughness := LMaterial.Roughness + 0.1;
        end;
        2:
        begin
          LTexture.RepeatS := not LTexture.RepeatS;
        end;
        3:
        begin
          { Identical URL text from another kit is not the same texture. }
          LTexture.BaseUrl := FilenameToUriSafe(ExpandFileName(
            'cge/data/kits/castle-kit/model.glb'));
          LTexture.SetUrl(['Textures/colormap.png']);
        end;
        4:
        begin
          TTextureCoordinateNode(TMultiTextureCoordinateNode(
            TIndexedTriangleSetNode(LShape.Geometry).TexCoord).FdTexCoord.Items[0]).
            Mapping := 'different_channel';
        end;
        5:
        begin
          TIndexedTriangleSetNode(LShape.Geometry).Solid := False;
        end;
        6:
        begin
          LMaterial.NormalScale := LMaterial.NormalScale + 0.1;
        end;
        7:
        begin
          LMaterial.BaseColor := Vector3(0.91, 0.23, 0.47);
        end;
      end;
      LReference := TCastleTransformReference.Create(LOwner);
      LReference.Reference := LFirst;
      Check(LBatch.Add(LReference), 'First static source admitted');
      LReference.Reference := LSecond;
      LReference.Translation := Vector3(8, 0, 0);
      Check(LBatch.Add(LReference), 'Second static source admitted');
      LCombined := LBatch.Finish(LOwner, SolveWorldAppearance(731));
      if (LCase = 0) or (LCase = 7) then
      begin
        Check(LCombined.Shapes.TraverseList(True, True).Count = LShapes,
          'Equal material fields from distinct sources share one draw');
      end
      else
      begin
        Check(LCombined.Shapes.TraverseList(True, True).Count = LShapes * 2,
          'Material, sampler, resolved URL and geometry distinctions retain separate draws: ' +
          IntToStr(LCase));
      end;
      Check(Vertices(LCombined) = Vertices(LFirst) + Vertices(LSecond),
        'Material matching never drops geometry');
      if LCase = 7 then
      begin
        LMesh := TIndexedTriangleSetNode(LCombined.Shapes.TraverseList(True, True)[0].Geometry);
        LColors := TColorNode(LMesh.Color);
        Check(LColors.FdColor.Count = Vertices(LCombined), 'Every vertex retains its base RGB');
        for I := 0 to LColors.FdColor.Count - 1 do
        begin
          if I < Vertices(LFirst) then
          begin
            LMaterial := TPhysicalMaterialNode(LFirst.Shapes.TraverseList(True, True)[0].
              State.Appearance.Material);
          end
          else
          begin
            LMaterial := TPhysicalMaterialNode(LSecond.Shapes.TraverseList(True, True)[0].
              State.Appearance.Material);
          end;
          Check(TVector3.PerfectlyEquals(LColors.FdColor.Items[I], LMaterial.BaseColor),
            'Packing preserves the exact source base colour at each vertex');
        end;
      end;
    finally
      LBatch.Free;
      LOwner.Free;
    end;
  end;
end;
begin
  GMaxError := 0;
  MaterialSharing;
  GAssets := 0;
  GText := TStringList.Create;
  GText.LoadFromFile('data/palette.json');
  GPalette := TJSONObject(GetJSON(GText.Text));
  try
    for I := 0 to GPalette.Arrays['assets'].Count - 1 do
    begin
      GAsset := GPalette.Arrays['assets'].Objects[I];
      if (GAsset.Get('kind', '') <> 'tree') and
        (GAsset.Get('kind', '') <> 'shrub') and
        (GAsset.Get('kind', '') <> 'flowers') and
        (GAsset.Get('kind', '') <> 'wheat') and
        (GAsset.Get('kind', '') <> 'rock') then
      begin
        Continue;
      end;
      Check(Pos('/', GAsset.Strings['id']) > 0, 'Foliage fixture requires a raw asset');
      GOwner := TComponent.Create(nil);
      GBatch := TStaticFoliageBatch.Create;
      try
        GScene := TCastleScene.Create(GOwner);
        GScene.Load('cge/data/kits/' + GAsset.Strings['id'] + '.glb');
        GScene.PreciseCollisions := True;
        GBeforeVertices := Vertices(GScene);
        GOriginal := TCastleTransform.Create(GOwner);
        for J := 0 to 3 do
        begin
          GReference := TCastleTransformReference.Create(GOwner);
          GReference.Reference := GScene;
          GReference.ReferenceTransformation := rtDoNotIgnore;
          GReference.Translation := Vector3(J * 8 - 12, J * 0.3, (J mod 2) * 8 - 4);
          GReference.Rotation := Vector4(0, 1, 0, J * Pi / 2);
          GReference.Scale := Vector3(1 + J * 0.2, 1 + J * 0.3, 1 + J * 0.1);
          GShapes := GScene.Shapes.TraverseList(True, True);
          for K := 0 to GShapes.Count - 1 do
          begin
            if TIndexedTriangleSetNode(GShapes[K].Geometry).Tangent <> nil then
            begin
              if J <> 0 then
              begin
                Check(not GBatch.Add(GReference),
                  'Nonuniform tangent basis uses unchanged scene rendering');
              end;
              GReference.Scale := Vector3(1 + J * 0.2, 1 + J * 0.2, 1 + J * 0.2);
              Break;
            end;
          end;
          GOriginal.Add(GReference);
          Check(GBatch.Add(GReference), 'Eligible foliage: ' + GAsset.Strings['id']);
        end;
        Check(not GBatch.Add(nil), 'Nil instance falls back without changing the staged batch');
        GUnsupported := TCastleSphere.Create(GOwner);
        GReference := TCastleTransformReference.Create(GOwner);
        GReference.Reference := GUnsupported;
        Check(not GBatch.Add(GReference), 'Unsupported primitive falls back without losing prior placements');
        Check(GBatch.Instances = 4, 'Rejected instances do not enter the batch');
        GCombined := GBatch.Finish(GOwner, SolveWorldAppearance(731));
        Check(GCombined <> nil, 'Batch scene produced');
        Check(GCombined.CastShadows, 'Foliage still casts shadows');
        Check(GCombined.ReceiveShadowVolumes, 'Foliage still receives shadows');
        Check(Vertices(GScene) = GBeforeVertices, 'Source mesh remains intact');
        Check(Vertices(GCombined) = GBeforeVertices * 4, 'No geometry removed by batching');
        Check(ShadowTriangles(GCombined) = ShadowTriangles(GScene) * 4,
          'Complete source shadow-volume eligibility survives every placement');
        GBounds := GOriginal.BoundingBox;
        GOther := GCombined.BoundingBox;
        for J := 0 to 1 do
        begin
          for K := 0 to 2 do
          begin
            if J = 0 then
            begin
              Check(GOther.Data[J][K] >= GBounds.Data[J][K] - 0.002,
                'Batched mesh stays inside original conservative lower bounds');
            end
            else
            begin
              Check(GOther.Data[J][K] <= GBounds.Data[J][K] + 0.002,
                'Batched mesh stays inside original conservative upper bounds');
            end;
          end;
        end;
        for Z := 0 to 20 do
        begin
          for X := 0 to 40 do
          begin
            GOrigin := Vector3(GBounds.Data[0].X + (X + 0.37) / 41 * GBounds.SizeX,
              GBounds.Data[1].Y + 10,
              GBounds.Data[0].Z + (Z + 0.41) / 21 * GBounds.SizeZ);
            GRayOriginal := VisibleRayCollision(GOriginal, GOrigin, Vector3(0, -1, 0));
            GRayCombined := VisibleRayCollision(GCombined, GOrigin, Vector3(0, -1, 0));
            try
              if (GRayOriginal = nil) <> (GRayCombined = nil) then
              begin
                WriteLn('Ray mismatch ', GAsset.Strings['id'], ' ', GOrigin.ToString,
                  ' original=', GRayOriginal <> nil, ' batch=', GRayCombined <> nil,
                  ' original bounds=', GBounds.ToString, ' batch bounds=', GOther.ToString);
              end;
              Check((GRayOriginal = nil) = (GRayCombined = nil),
                'Actual CGE reference and batch ray hit agree');
              if GRayOriginal <> nil then
              begin
                GMaxError := Max(GMaxError, Abs(GRayOriginal.Distance - GRayCombined.Distance));
                Check(Abs(GRayOriginal.Distance - GRayCombined.Distance) < 0.002,
                  'Actual CGE surface hit preserved');
              end;
            finally
              GRayOriginal.Free;
              GRayCombined.Free;
            end;
          end;
        end;
        GShapes := GCombined.Shapes.TraverseList(True, True);
        for J := 0 to GShapes.Count - 1 do
        begin
          for K := 0 to TNormalNode(TIndexedTriangleSetNode(GShapes[J].Geometry).Normal).
            FdVector.Count - 1 do
          begin
            GPoint := TNormalNode(TIndexedTriangleSetNode(GShapes[J].Geometry).Normal).
              FdVector.Items[K];
            Check(not IsNan(GPoint.X) and not IsInfinite(GPoint.X) and
              (Abs(GPoint.Length - 1) < 0.0001), 'Batched normals remain finite unit vectors');
          end;
        end;
        Inc(GAssets);
        WriteLn('PASS ', GAsset.Strings['id']);
      finally
        GBatch.Free;
        GOwner.Free;
      end;
    end;
    CabinGeometry;
    WriteLn('PASS ', GChecks, ' checks across ', GAssets, ' foliage assets and cabin; maximum foliage ray error ',
      GMaxError * 1000:0:6, ' mm');
  finally
    GPalette.Free;
    GText.Free;
  end;
end.
