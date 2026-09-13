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

unit phanes.world.shadowcache;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  CastleScene,
  CastleShapes,
  CastleVectors,
  CastleTransform,
  CastleRenderPrimitives;

type
  EStaticShadowCapacity = class(Exception);

  { An opaque directional-light volume in world coordinates. The cap is kept
    separate because its depth rule and necessity depend on the current camera.
    No GL resource is created by this geometry builder. }
  TStaticShadowGeometry = class
  private
    FSides: TVector4List;
    FCap: TVector4List;
    FEndCap: TVector4List;
  public
    constructor Create(const AShape: TShape; const ATransform: TMatrix4;
      const ALight: TVector4; const AWholeSceneManifold: Boolean;
      const AFiniteDistance: Single = 0);
    destructor Destroy; override;
    property Sides: TVector4List read FSides;
    property Cap: TVector4List read FCap;
    property EndCap: TVector4List read FEndCap;
  end;

  { Used only for Phanes' immutable, opaque batches. Any scene mutation retires
    the cache; unhandled rendering modes use the ordinary engine path. }
  TStaticShadowScene = class(TCastleScene)
  private type
    TEntry = record
      FShape: TShape;
      FTransform: TMatrix4;
      FPrepared: Boolean;
      FBytes: Integer;
      FSides: TCastleRenderUnlitMesh;
      FCap: TCastleRenderUnlitMesh;
      FEndCap: TCastleRenderUnlitMesh;
    end;
  private
    FEntries: array of TEntry;
    FLight: TVector4;
    FDistance: Single;
    FWhole: Boolean;
    FDirty: Boolean;
    FBuildCount: Integer;
    FExhausted: Boolean;
    procedure ClearEntry(const AIndex: Integer);
    procedure ClearCache;
    function PrepareEntry(const AIndex: Integer; const AShape: TShape;
      const ATransform: TMatrix4; const ALight: TVector4;
      const AWhole: Boolean; const AFiniteDistance: Single): Boolean;
  protected
    procedure LocalRenderShadowVolume(const AParams: TRenderParams;
      const ARenderer: TBaseShadowVolumeRenderer); override;
  public
    destructor Destroy; override;
    procedure VisibleChangeHere(const AChanges: TVisibleChanges); override;
    procedure ChangedAll(const AOnlyAdditions: Boolean = False); override;
    procedure GLContextClose; override;
    property ShadowCacheBuildCount: Integer read FBuildCount;
  end;

implementation

uses
  Math,
  CastleImages,
  CastleGLUtils,
  CastleTriangles,
  CastleBoxes,
  CastleRenderContext,
  CastleRenderOptions,
  CastleInternalGLShadowVolumes,
  CastleShapeInternalShadowVolumes;

const
  { This is an optional acceleration cache shared by all resident chunks.
    Exhausting it preserves the normal engine rendering path. }
  ShadowCacheByteLimit = 16 * 1024 * 1024;

var
  GShadowCacheBytes: Integer;

constructor TStaticShadowGeometry.Create(const AShape: TShape;
  const ATransform: TMatrix4; const ALight: TVector4;
  const AWholeSceneManifold: Boolean; const AFiniteDistance: Single);
var
  LTriangles: TTrianglesShadowCastersList;
  LEdges: TEdgeList;
  LFacing: array of Boolean;
  LTriangle: TTriangle3;
  LPlane: TVector4;
  LEdge: TEdge;
  LSideCapacity: Int64;
  LCapCapacity: Int64;
  LEndCapCapacity: Int64;
  LFiniteLight: TVector3Double;
  LExtrusion: TVector3;
  I: Integer;
  J: Integer;

  procedure AddSide(const AEdge: TEdge; const AReverse: Boolean);
  var
    LFirst: Integer;
    LSecond: Integer;
    LSource: TTriangle3;
    LFirstPoint: TVector3;
    LSecondPoint: TVector3;
  begin
    LFirst := AEdge.VertexIndex;
    LSecond := (LFirst + 1) mod 3;
    if AReverse then
    begin
      LFirst := LSecond;
      LSecond := AEdge.VertexIndex;
    end;
    LSource := LTriangles.Items[AEdge.Triangles[0]];
    LFirstPoint := ATransform.MultPoint(LSource.Data[LFirst]);
    LSecondPoint := ATransform.MultPoint(LSource.Data[LSecond]);
    FSides.Add(Vector4(LFirstPoint, 1));
    FSides.Add(Vector4(LSecondPoint, 1));
    if AFiniteDistance > 0 then
    begin
      { Match the ordinary renderer's orientation-independent diagonal.
        Reversed shared borders must emit exactly opposite triangle sets,
        including when Single endpoint rounding makes the quad nonplanar. }
      if (LFirstPoint.X < LSecondPoint.X) or
        ((LFirstPoint.X = LSecondPoint.X) and (LFirstPoint.Y < LSecondPoint.Y)) or
        ((LFirstPoint.X = LSecondPoint.X) and (LFirstPoint.Y = LSecondPoint.Y) and
          (LFirstPoint.Z <= LSecondPoint.Z)) then
      begin
        FSides.Add(Vector4(LSecondPoint + LExtrusion, 1));
        FSides.Add(Vector4(LFirstPoint, 1));
        FSides.Add(Vector4(LSecondPoint + LExtrusion, 1));
        FSides.Add(Vector4(LFirstPoint + LExtrusion, 1));
      end
      else
      begin
        FSides.Add(Vector4(LFirstPoint + LExtrusion, 1));
        FSides.Add(Vector4(LSecondPoint, 1));
        FSides.Add(Vector4(LSecondPoint + LExtrusion, 1));
        FSides.Add(Vector4(LFirstPoint + LExtrusion, 1));
      end;
    end
    else
    begin
      FSides.Add(ALight);
    end;
  end;

begin
  inherited Create;
  FSides := TVector4List.Create;
  FCap := TVector4List.Create;
  FEndCap := TVector4List.Create;
  if ALight.W <> 0 then
  begin
    raise EArgumentException.Create('Static shadow geometry requires a directional light.');
  end;
  if IsNan(AFiniteDistance) or IsInfinite(AFiniteDistance) or
    (AFiniteDistance < 0) then
  begin
    raise EArgumentException.Create('Static shadow distance must be finite and nonnegative.');
  end;
  if IsNan(ALight.X) or IsNan(ALight.Y) or IsNan(ALight.Z) or
    IsInfinite(ALight.X) or IsInfinite(ALight.Y) or IsInfinite(ALight.Z) then
  begin
    raise EArgumentException.Create('Static directional light must be finite.');
  end;
  LFiniteLight := Vector3Double(ALight.XYZ);
  if (LFiniteLight.Length = 0) or IsNan(LFiniteLight.Length) or
    IsInfinite(LFiniteLight.Length) then
  begin
    raise EArgumentException.Create('Static directional light must be nonzero.');
  end;
  LExtrusion := Vector3(LFiniteLight * (AFiniteDistance / LFiniteLight.Length));
  if (AShape.InternalShadowVolumes.BorderEdges.Count <> 0) and
    not AWholeSceneManifold then
  begin
    Exit;
  end;
  LTriangles := AShape.InternalShadowVolumes.TrianglesListShadowCasters;
  { Bound temporary storage before allocating it. Use wide arithmetic before
    multiplication, and preallocate exactly these conservative capacities so
    dynamic-list growth cannot overshoot the temporary budget. }
  LCapCapacity := Int64(LTriangles.Count) * 3;
  if AFiniteDistance > 0 then
  begin
    LEndCapCapacity := LCapCapacity;
    LSideCapacity := (Int64(AShape.InternalShadowVolumes.ManifoldEdges.Count) +
      AShape.InternalShadowVolumes.BorderEdges.Count) * 6;
  end
  else
  begin
    LEndCapCapacity := 0;
    LSideCapacity := (Int64(AShape.InternalShadowVolumes.ManifoldEdges.Count) +
      AShape.InternalShadowVolumes.BorderEdges.Count) * 3;
  end;
  if (LCapCapacity + LEndCapCapacity + LSideCapacity) * SizeOf(TVector4) +
    Int64(LTriangles.Count) * SizeOf(Boolean) > ShadowCacheByteLimit then
  begin
    raise EStaticShadowCapacity.Create('Static shadow geometry exceeds its temporary budget.');
  end;
  FCap.Capacity := Integer(LCapCapacity);
  FEndCap.Capacity := Integer(LEndCapCapacity);
  FSides.Capacity := Integer(LSideCapacity);
  SetLength(LFacing, LTriangles.Count);
  for I := 0 to LTriangles.Count - 1 do
  begin
    for J := 0 to 2 do
    begin
      LTriangle.Data[J] := ATransform.MultPoint(LTriangles.Items[I].Data[J]);
    end;
    LPlane := LTriangle.Plane;
    LFacing[I] := (LPlane.X * ALight.X + LPlane.Y * ALight.Y +
      LPlane.Z * ALight.Z + LPlane.W * ALight.W) > 0;
    if LFacing[I] then
    begin
      for J := 0 to 2 do
      begin
        FCap.Add(Vector4(LTriangle.Data[J], 1));
      end;
      if AFiniteDistance > 0 then
      begin
        for J := 2 downto 0 do
        begin
          FEndCap.Add(Vector4(LTriangle.Data[J] + LExtrusion, 1));
        end;
      end;
    end;
  end;

  { CGE supplies the adjacency and cross-material closure classification.
    Each lit/unlit boundary becomes a triangle to homogeneous infinity.
    A boundary across material shapes stays separate, matching the engine's
    handling of both consistently and oppositely wound shared edges. }
  LEdges := AShape.InternalShadowVolumes.ManifoldEdges;
  for I := 0 to LEdges.Count - 1 do
  begin
    LEdge := LEdges.Items[I];
    if LFacing[LEdge.Triangles[0]] <> LFacing[LEdge.Triangles[1]] then
    begin
      AddSide(LEdge, LFacing[LEdge.Triangles[0]]);
    end;
  end;
  LEdges := AShape.InternalShadowVolumes.BorderEdges;
  for I := 0 to LEdges.Count - 1 do
  begin
    LEdge := LEdges.Items[I];
    if LFacing[LEdge.Triangles[0]] then
    begin
      AddSide(LEdge, True);
    end;
  end;
end;

destructor TStaticShadowGeometry.Destroy;
begin
  FreeAndNil(FSides);
  FreeAndNil(FCap);
  FreeAndNil(FEndCap);
  inherited;
end;

procedure TStaticShadowScene.ClearEntry(const AIndex: Integer);
begin
  FreeAndNil(FEntries[AIndex].FSides);
  FreeAndNil(FEntries[AIndex].FCap);
  FreeAndNil(FEntries[AIndex].FEndCap);
  Dec(GShadowCacheBytes, FEntries[AIndex].FBytes);
  FEntries[AIndex].FBytes := 0;
  FEntries[AIndex].FPrepared := False;
end;

procedure TStaticShadowScene.ClearCache;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
  begin
    ClearEntry(I);
  end;
  FEntries := nil;
  FDirty := True;
end;

destructor TStaticShadowScene.Destroy;
begin
  ClearCache;
  inherited;
end;

procedure TStaticShadowScene.VisibleChangeHere(const AChanges: TVisibleChanges);
begin
  if AChanges <> [] then
  begin
    FDirty := True;
  end;
  inherited;
end;

procedure TStaticShadowScene.ChangedAll(const AOnlyAdditions: Boolean);
begin
  FDirty := True;
  inherited;
end;

procedure TStaticShadowScene.GLContextClose;
begin
  { VBOs belong to this GL context. Recreate them lazily after restoration. }
  ClearCache;
  inherited;
end;

function TStaticShadowScene.PrepareEntry(const AIndex: Integer;
  const AShape: TShape; const ATransform: TMatrix4; const ALight: TVector4;
  const AWhole: Boolean; const AFiniteDistance: Single): Boolean;
var
  LGeometry: TStaticShadowGeometry;
  LBytes: Int64;
begin
  if FEntries[AIndex].FPrepared and
    (FEntries[AIndex].FShape = AShape) and
    CompareMem(@FEntries[AIndex].FTransform, @ATransform, SizeOf(ATransform)) then
  begin
    Exit(True);
  end;
  ClearEntry(AIndex);
  try
    LGeometry := TStaticShadowGeometry.Create(AShape, ATransform, ALight, AWhole,
      AFiniteDistance);
  except
    on EStaticShadowCapacity do
    begin
      Exit(False);
    end;
  end;
  try
    LBytes := (Int64(LGeometry.Sides.Count) + LGeometry.Cap.Count +
      LGeometry.EndCap.Count) * SizeOf(TVector4);
    if LBytes > ShadowCacheByteLimit - GShadowCacheBytes then
    begin
      Exit(False);
    end;
    try
      if LGeometry.Sides.Count > 0 then
      begin
        FEntries[AIndex].FSides := TCastleRenderUnlitMesh.Create(False);
        FEntries[AIndex].FSides.SetVertexes(LGeometry.Sides, False);
      end;
      if LGeometry.Cap.Count > 0 then
      begin
        FEntries[AIndex].FCap := TCastleRenderUnlitMesh.Create(False);
        FEntries[AIndex].FCap.SetVertexes(LGeometry.Cap, False);
      end;
      if LGeometry.EndCap.Count > 0 then
      begin
        FEntries[AIndex].FEndCap := TCastleRenderUnlitMesh.Create(False);
        FEntries[AIndex].FEndCap.SetVertexes(LGeometry.EndCap, False);
      end;
      FEntries[AIndex].FShape := AShape;
      FEntries[AIndex].FTransform := ATransform;
      FEntries[AIndex].FBytes := Integer(LBytes);
      Inc(GShadowCacheBytes, Integer(LBytes));
      FEntries[AIndex].FPrepared := True;
      Inc(FBuildCount);
      Result := True;
    except
      ClearEntry(AIndex);
      raise;
    end;
  finally
    { CGE's VBO owns the uploaded copy. Keep no duplicate CPU vertex list. }
    LGeometry.Free;
  end;
end;

procedure TStaticShadowScene.LocalRenderShadowVolume(const AParams: TRenderParams;
  const ARenderer: TBaseShadowVolumeRenderer);
var
  LRenderer: TGLShadowVolumeRenderer;
  LShapes: TShapeList;
  LWhole: Boolean;
  LLight: TVector4;
  LMatrix: TMatrix4;
  LMvp: TMatrix4;
  LBox: TBox3D;
  LDepth: TDepthFunction;
  LDistance: Single;
  I: Integer;
begin
  { Point lights, child transforms, animation and distance culling retain the
    engine implementation. The cache never replaces editable door/furniture
    scenes or their independent visibility semantics. }
  if not (ARenderer is TGLShadowVolumeRenderer) or (Count <> 0) or
    (AnimationsList.Count <> 0) or (DistanceCulling <> 0) or
    (RenderOptions.Mode <> rmFull) then
  begin
    inherited;
    Exit;
  end;
  LRenderer := TGLShadowVolumeRenderer(ARenderer);
  LLight := LRenderer.LightPosition;
  LDistance := LRenderer.DirectionalShadowDistance;
  if LRenderer.DebugRender or (LLight.W <> 0) or
    IsNan(LLight.X) or IsNan(LLight.Y) or IsNan(LLight.Z) or
    IsInfinite(LLight.X) or IsInfinite(LLight.Y) or IsInfinite(LLight.Z) or
    ((LLight.X = 0) and (LLight.Y = 0) and (LLight.Z = 0)) or
    IsNan(LDistance) or IsInfinite(LDistance) or (LDistance < 0) then
  begin
    inherited;
    Exit;
  end;
  if not CheckVisible or not CastShadows or
    (RenderOptions.WireframeEffect = weWireframeOnly) then
  begin
    Exit;
  end;
  LShapes := Shapes.TraverseList(True, True);
  for I := 0 to LShapes.Count - 1 do
  begin
    if LShapes[I].AlphaChannel = acBlending then
    begin
      inherited;
      Exit;
    end;
  end;
  LWhole := RenderOptions.WholeSceneManifold or InternalDetectedWholeSceneManifold;
  if FDirty or (Length(FEntries) <> LShapes.Count) or (FWhole <> LWhole) or
    not CompareMem(@FLight, @LLight, SizeOf(LLight)) or
    (FDistance <> LDistance) then
  begin
    ClearCache;
    SetLength(FEntries, LShapes.Count);
    FLight := LLight;
    FDistance := LDistance;
    FWhole := LWhole;
    FDirty := False;
    FExhausted := False;
  end;
  LBox := LocalBoundingBox.Transform(AParams.Transformation^.Transform);
  if not LRenderer.GetCasterShadowPossiblyVisible(LBox) then
  begin
    Exit;
  end;
  if FExhausted then
  begin
    inherited;
    Exit;
  end;
  { Stage all entries before drawing any of them. If the bounded cache cannot
    admit this scene, fall back once without partially drawing its stencil. }
  for I := 0 to LShapes.Count - 1 do
  begin
    LMatrix := AParams.Transformation^.Transform * LShapes[I].State.Transformation.Transform;
    if not PrepareEntry(I, LShapes[I], LMatrix, LLight, LWhole, LDistance) then
    begin
      ClearCache;
      SetLength(FEntries, LShapes.Count);
      FDirty := False;
      FExhausted := True;
      inherited;
      Exit;
    end;
  end;
  LMvp := RenderContext.ProjectionMatrix * AParams.RenderingCamera.CurrentMatrix;
  for I := 0 to LShapes.Count - 1 do
  begin
    LBox := LShapes[I].BoundingBox.Transform(AParams.Transformation^.Transform);
    LRenderer.InitCaster(LBox);
    if not LWhole and not LRenderer.CasterShadowPossiblyVisible then
    begin
      Continue;
    end;
    if LRenderer.ZFailAndLightCap and (FEntries[I].FCap <> nil) then
    begin
      LDepth := RenderContext.DepthFunc;
      try
        RenderContext.DepthFunc := dfNever;
        FEntries[I].FCap.ModelViewProjection := LMvp;
        FEntries[I].FCap.Render(pmTriangles);
      finally
        RenderContext.DepthFunc := LDepth;
      end;
    end;
    if FEntries[I].FSides <> nil then
    begin
      FEntries[I].FSides.ModelViewProjection := LMvp;
      FEntries[I].FSides.Render(pmTriangles);
    end;
    { Finite directional volumes are closed under the ordinary depth rule in
      both z-pass and z-fail. Only the source cap keeps CGE's dfNever rule. }
    if FEntries[I].FEndCap <> nil then
    begin
      FEntries[I].FEndCap.ModelViewProjection := LMvp;
      FEntries[I].FEndCap.Render(pmTriangles);
    end;
  end;
end;

end.
