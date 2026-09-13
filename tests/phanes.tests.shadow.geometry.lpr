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
program PhanesTestsShadowGeometry;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  CastleScene,
  CastleTransform,
  CastleShapes,
  CastleShapeInternalShadowVolumes,
  CastleVectors,
  X3DNodes,
  phanes.world.shadowcache;

const
  ShadowCacheByteLimit = 16 * 1024 * 1024;
  FiniteVerticesPerOpenTriangle = 24;
  BytesPerFacingValue = SizeOf(Boolean);
  BoundaryAcceptedTriangles = ShadowCacheByteLimit div
    (FiniteVerticesPerOpenTriangle * SizeOf(TVector4) + BytesPerFacingValue);

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function ScalarKey(const AValue: Single): String;
var
  LBits: Cardinal;
begin
  if AValue = 0 then
  begin
    Exit('00000000');
  end;
  Move(AValue, LBits, SizeOf(LBits));
  Result := IntToHex(LBits, 8);
end;

function PointKey(const APoint: TVector4): String;
begin
  Result := ScalarKey(APoint.X) + ScalarKey(APoint.Y) +
    ScalarKey(APoint.Z) + ScalarKey(APoint.W);
end;

function EdgeKey(const AFirst, ASecond: TVector4): String;
begin
  Result := PointKey(AFirst) + '/' + PointKey(ASecond);
end;

procedure IncludeDirectedEdge(const AEdges: TStringList;
  const AFirst, ASecond: TVector4);
var
  LReverseIndex: Integer;
begin
  LReverseIndex := AEdges.IndexOf(EdgeKey(ASecond, AFirst));
  if LReverseIndex >= 0 then
  begin
    AEdges.Delete(LReverseIndex);
  end
  else
  begin
    AEdges.Add(EdgeKey(AFirst, ASecond));
  end;
end;

procedure IncludeTriangleEdges(const AEdges: TStringList;
  const AList: TVector4List);
var
  I: Integer;
begin
  Check(AList.Count mod 3 = 0, 'Geometry list must contain complete triangles');
  for I := 0 to AList.Count div 3 - 1 do
  begin
    IncludeDirectedEdge(AEdges, AList[I * 3], AList[I * 3 + 1]);
    IncludeDirectedEdge(AEdges, AList[I * 3 + 1], AList[I * 3 + 2]);
    IncludeDirectedEdge(AEdges, AList[I * 3 + 2], AList[I * 3]);
  end;
end;

procedure CheckClosedFinite(const AGeometry: TStaticShadowGeometry);
var
  LEdges: TStringList;
begin
  LEdges := TStringList.Create;
  try
    LEdges.UseLocale := False;
    LEdges.CaseSensitive := True;
    IncludeTriangleEdges(LEdges, AGeometry.Cap);
    IncludeTriangleEdges(LEdges, AGeometry.Sides);
    IncludeTriangleEdges(LEdges, AGeometry.EndCap);
    Check(LEdges.Count = 0,
      'Source, side and translated end-cap directed edges must cancel exactly');
  finally
    LEdges.Free;
  end;
end;

procedure AddCube(const AMesh: TIndexedTriangleSetNode;
  const AOffset: TVector3);
const
  FaceVertex: array[0..35] of Integer = (
    0, 3, 2, 0, 2, 1,
    4, 5, 6, 4, 6, 7,
    0, 4, 7, 0, 7, 3,
    1, 2, 6, 1, 6, 5,
    0, 1, 5, 0, 5, 4,
    3, 7, 6, 3, 6, 2);
  CubePoint: array[0..7, 0..2] of Single = (
    (-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
    (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1));
var
  LVertex: Integer;
  LPointIndex: Integer;
begin
  for LVertex := 0 to High(FaceVertex) do
  begin
    LPointIndex := FaceVertex[LVertex];
    AMesh.FdIndex.Items.Add(TCoordinateNode(AMesh.Coord).FdPoint.Count);
    TCoordinateNode(AMesh.Coord).FdPoint.Items.Add(Vector3(
      CubePoint[LPointIndex, 0] + AOffset.X,
      CubePoint[LPointIndex, 1] + AOffset.Y,
      CubePoint[LPointIndex, 2] + AOffset.Z));
  end;
end;

function CubeScene(const ATwoSolids: Boolean): TCastleScene;
var
  LRoot: TX3DRootNode;
  LShape: TShapeNode;
  LMesh: TIndexedTriangleSetNode;
begin
  LRoot := TX3DRootNode.Create;
  LShape := TShapeNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := TCoordinateNode.Create;
  LShape.Geometry := LMesh;
  LRoot.AddChildren(LShape);
  AddCube(LMesh, Vector3(0, 0, 0));
  if ATwoSolids then
  begin
    { A disconnected pair is closed and non-convex as a complete shape. }
    AddCube(LMesh, Vector3(3.25, 0.4, -0.6));
  end;
  Result := TCastleScene.Create(nil);
  Result.Load(LRoot, True);
end;

function ClosePoint(const ALeft, ARight: TVector4;
  const AEpsilon: Single = 1.0E-5): Boolean;
begin
  Result := (Abs(ALeft.X - ARight.X) <= AEpsilon) and
    (Abs(ALeft.Y - ARight.Y) <= AEpsilon) and
    (Abs(ALeft.Z - ARight.Z) <= AEpsilon) and
    (Abs(ALeft.W - ARight.W) <= AEpsilon);
end;

procedure CheckGeometryCase(const AShape: TShape; const ATransform: TMatrix4;
  const ALight: TVector4; const ADistance: Single);
var
  LInfinite: TStaticShadowGeometry;
  LFinite: TStaticShadowGeometry;
  LScaledLight: TStaticShadowGeometry;
  LExtrusion: TVector3;
  LExpected: TVector4;
  LLength: Single;
  I: Integer;

  function QuadContains(const AOffset: Integer; const APoint: TVector4): Boolean;
  var
    J: Integer;
  begin
    for J := 0 to 5 do
    begin
      if ClosePoint(LFinite.Sides[AOffset + J], APoint,
        Max(1.0E-5, ADistance * 1.0E-6)) then
      begin
        Exit(True);
      end;
    end;
    Result := False;
  end;

begin
  LInfinite := TStaticShadowGeometry.Create(AShape, ATransform, ALight, True);
  LFinite := TStaticShadowGeometry.Create(AShape, ATransform, ALight, True,
    ADistance);
  LScaledLight := TStaticShadowGeometry.Create(AShape, ATransform, ALight * 37,
    True, ADistance);
  try
    Check(LInfinite.EndCap.Count = 0, 'Default distance retains no finite end cap');
    Check(LFinite.Cap.Count = LInfinite.Cap.Count,
      'Finite distance leaves the source cap unchanged');
    Check(LFinite.EndCap.Count = LFinite.Cap.Count,
      'Finite distance emits one reversed end-cap triangle per source triangle');
    Check(LFinite.Sides.Count = LInfinite.Sides.Count * 2,
      'Finite side triangles expand to six-vertex quads');
    Check(LFinite.Sides.Count = LScaledLight.Sides.Count,
      'Scaled light retains finite side topology');
    Check(LFinite.Cap.Count = LScaledLight.Cap.Count,
      'Scaled light retains source-cap topology');
    Check(LFinite.Sides.Count > 0, 'Finite fixture must exercise silhouette sides');
    for I := 0 to LInfinite.Sides.Count div 3 - 1 do
    begin
      Check(PointKey(LInfinite.Sides[I * 3 + 2]) = PointKey(ALight),
        'Default distance retains the original homogeneous infinite endpoint');
    end;
    for I := 0 to LFinite.Sides.Count - 1 do
    begin
      Check(LFinite.Sides[I].W = 1,
        'Every finite side vertex must be positional');
    end;
    LExtrusion := LFinite.EndCap[2].XYZ - LFinite.Cap[0].XYZ;
    for I := 0 to LFinite.Cap.Count div 3 - 1 do
    begin
      LExpected := Vector4(LFinite.Cap[I * 3 + 2].XYZ + LExtrusion, 1);
      Check(ClosePoint(LFinite.EndCap[I * 3], LExpected),
        'End cap starts with translated source triangle last vertex');
      LExpected := Vector4(LFinite.Cap[I * 3 + 1].XYZ + LExtrusion, 1);
      Check(ClosePoint(LFinite.EndCap[I * 3 + 1], LExpected),
        'End cap retains translated reverse winding');
      LExpected := Vector4(LFinite.Cap[I * 3].XYZ + LExtrusion, 1);
      Check(ClosePoint(LFinite.EndCap[I * 3 + 2], LExpected),
        'End cap ends with translated source triangle first vertex');
    end;
    for I := 0 to LFinite.Sides.Count div 6 - 1 do
    begin
      Check(LFinite.Sides[I * 6].W = 1, 'Finite side source is positional');
      Check(LFinite.Sides[I * 6 + 2].W = 1, 'Finite side endpoint is positional');
      Check(QuadContains(I * 6, Vector4(LFinite.Sides[I * 6].XYZ + LExtrusion, 1)),
        'Finite side includes the translated first source endpoint');
      Check(QuadContains(I * 6, Vector4(LFinite.Sides[I * 6 + 1].XYZ + LExtrusion, 1)),
        'Finite side includes the translated second source endpoint');
      LLength := LExtrusion.Length;
      Check(Abs(LLength - ADistance) <= Max(1.0E-5, ADistance * 1.0E-5),
        'Finite side has requested normalized directional length');
    end;
    for I := 0 to LFinite.Sides.Count - 1 do
    begin
      Check(ClosePoint(LFinite.Sides[I], LScaledLight.Sides[I],
        Max(2.0E-4, ADistance * 1.0E-6)),
        'Finite side is independent of light-vector magnitude');
    end;
    for I := 0 to LFinite.EndCap.Count - 1 do
    begin
      Check(ClosePoint(LFinite.EndCap[I], LScaledLight.EndCap[I],
        Max(2.0E-4, ADistance * 1.0E-6)),
        'Finite end cap is independent of light-vector magnitude');
    end;
    CheckClosedFinite(LFinite);
  finally
    LScaledLight.Free;
    LFinite.Free;
    LInfinite.Free;
  end;
end;

procedure GeometryCases;
var
  LScene: TCastleScene;
  LShape: TShape;
  LTransform: TCastleTransform;
  LMatrix: TMatrix4;
  LCase: Integer;
begin
  for LCase := 0 to 1 do
  begin
    LScene := CubeScene(LCase = 1);
    LTransform := TCastleTransform.Create(nil);
    try
      LShape := LScene.Shapes.TraverseList(True, True)[0];
      Check(LShape.InternalShadowVolumes.BorderEdges.Count = 0,
        'Cube geometry must be independently closed');
      LTransform.Translation := Vector3(11.25 * LCase, -3.5, 7.75);
      LTransform.Rotation := Vector4(1, 2, -1, 0.63);
      LTransform.Scale := Vector3(1.7, 0.65, 2.2);
      LMatrix := LTransform.Transform * LShape.State.Transformation.Transform;
      CheckGeometryCase(LShape, LMatrix, Vector4(0.43, -1, 0.27, 0), 37.5);
      LTransform.Translation := Vector3(-103.5, 28.25, 407.75);
      LTransform.Rotation := Vector4(-2, 1, 3, 1.17);
      LTransform.Scale := Vector3(-0.8, 1.25, 0.55);
      LMatrix := LTransform.Transform * LShape.State.Transformation.Transform;
      CheckGeometryCase(LShape, LMatrix, Vector4(-0.2, 0.8, -0.51, 0), 4096);
    finally
      LTransform.Free;
      LScene.Free;
    end;
  end;
end;

procedure ExpectArgumentError(const AShape: TShape; const ALight: TVector4;
  const ADistance: Single; const AMessage: String);
var
  LGeometry: TStaticShadowGeometry;
  LRejected: Boolean;
begin
  LGeometry := nil;
  LRejected := False;
  try
    LGeometry := TStaticShadowGeometry.Create(AShape, TMatrix4.Identity,
      ALight, True, ADistance);
  except
    on EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  LGeometry.Free;
  Check(LRejected, AMessage);
end;

procedure InvalidCases;
var
  LScene: TCastleScene;
  LShape: TShape;
begin
  LScene := CubeScene(False);
  try
    LShape := LScene.Shapes.TraverseList(True, True)[0];
    ExpectArgumentError(LShape, Vector4(0, 1, 0, 1), 10,
      'Positional light must reject');
    ExpectArgumentError(LShape, Vector4(0, 0, 0, 0), 0,
      'Zero directional light must reject');
    ExpectArgumentError(LShape, Vector4(NaN, 1, 0, 0), 10,
      'Non-finite directional light must reject');
    ExpectArgumentError(LShape, Vector4(0, 1, 0, 0), -1,
      'Negative finite distance must reject');
    ExpectArgumentError(LShape, Vector4(0, 1, 0, 0), NaN,
      'NaN finite distance must reject');
    ExpectArgumentError(LShape, Vector4(0, 1, 0, 0), Infinity,
      'Infinite finite distance must reject');
  finally
    LScene.Free;
  end;
end;

function TriangleSoup(const ATriangleCount: Integer): TCastleScene;
var
  LRoot: TX3DRootNode;
  LShape: TShapeNode;
  LMesh: TIndexedTriangleSetNode;
  LX: Single;
  LY: Single;
  I: Integer;
begin
  LRoot := TX3DRootNode.Create;
  LShape := TShapeNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LMesh.Coord := TCoordinateNode.Create;
  LShape.Geometry := LMesh;
  LRoot.AddChildren(LShape);
  for I := 0 to ATriangleCount - 1 do
  begin
    LX := (I mod 256) * 4;
    LY := (I div 256) * 4;
    LMesh.FdIndex.Items.Add(TCoordinateNode(LMesh.Coord).FdPoint.Count);
    TCoordinateNode(LMesh.Coord).FdPoint.Items.Add(Vector3(LX, LY, 0));
    LMesh.FdIndex.Items.Add(TCoordinateNode(LMesh.Coord).FdPoint.Count);
    TCoordinateNode(LMesh.Coord).FdPoint.Items.Add(Vector3(LX + 1, LY, 0));
    LMesh.FdIndex.Items.Add(TCoordinateNode(LMesh.Coord).FdPoint.Count);
    TCoordinateNode(LMesh.Coord).FdPoint.Items.Add(Vector3(LX, LY + 1, 0));
  end;
  Result := TCastleScene.Create(nil);
  Result.Load(LRoot, True);
end;

procedure CapacityCase(const ATriangleCount: Integer;
  const AExpectedAccepted: Boolean);
var
  LScene: TCastleScene;
  LShape: TShape;
  LGeometry: TStaticShadowGeometry;
  LAccepted: Boolean;
begin
  LScene := TriangleSoup(ATriangleCount);
  LGeometry := nil;
  try
    LShape := LScene.Shapes.TraverseList(True, True)[0];
    Check(LShape.InternalShadowVolumes.BorderEdges.Count = ATriangleCount * 3,
      'Capacity fixture requires three distinct border edges per triangle');
    LAccepted := True;
    try
      LGeometry := TStaticShadowGeometry.Create(LShape, TMatrix4.Identity,
        Vector4(0, 0, 1, 0), True, 10);
    except
      on EStaticShadowCapacity do
      begin
        LAccepted := False;
      end;
    end;
    Check(LAccepted = AExpectedAccepted,
      'Finite temporary capacity boundary result changed');
  finally
    LGeometry.Free;
    LScene.Free;
  end;
end;

procedure CapacityCases;
begin
  Check(BoundaryAcceptedTriangles *
    (FiniteVerticesPerOpenTriangle * SizeOf(TVector4) + BytesPerFacingValue) <=
    ShadowCacheByteLimit, 'Accepted capacity arithmetic exceeds 16 MiB');
  Check((BoundaryAcceptedTriangles + 1) *
    (FiniteVerticesPerOpenTriangle * SizeOf(TVector4) + BytesPerFacingValue) >
    ShadowCacheByteLimit, 'Rejected capacity arithmetic does not exceed 16 MiB');
  CapacityCase(BoundaryAcceptedTriangles, True);
  CapacityCase(BoundaryAcceptedTriangles + 1, False);
end;

{ Splitting a closed model into material shapes must not introduce internal
  shadow surfaces. Compare actual emitted triangles after cancelling exact
  opposite windings, against the same model without material boundaries. }
procedure SharedBorderCase;
var
  LWhole: TCastleScene;
  LSplit: TCastleScene;
  LRoot: TX3DRootNode;
  LMesh: TIndexedTriangleSetNode;
  LNode: TShapeNode;
  LTriangles: TTrianglesShadowCastersList;
  LGeometry: TStaticShadowGeometry;
  LTransform: TCastleTransform;
  LUnmatched: TStringList;
  LShapes: TShapeList;
  I: Integer;
  J: Integer;

  function TriangleKey(const A, B, C: TVector4): String;
  var
    LA: String;
    LB: String;
    LC: String;
  begin
    LA := PointKey(A);
    LB := PointKey(B);
    LC := PointKey(C);
    if (LA <= LB) and (LA <= LC) then
    begin
      Result := LA + '/' + LB + '/' + LC
    end
    else if LB <= LC then
    begin
      Result := LB + '/' + LC + '/' + LA
    end
    else
    begin
      Result := LC + '/' + LA + '/' + LB;
    end;
  end;

  procedure IncludeSides(const ASides: TVector4List; const AReverse: Boolean);
  var
    LFirst: TVector4;
    LSecond: TVector4;
    LThird: TVector4;
    LIndex: Integer;
    K: Integer;
  begin
    for K := 0 to ASides.Count div 3 - 1 do
    begin
      LFirst := ASides[K * 3];
      LSecond := ASides[K * 3 + 1 + Ord(AReverse)];
      LThird := ASides[K * 3 + 2 - Ord(AReverse)];
      LIndex := LUnmatched.IndexOf(TriangleKey(LFirst, LThird, LSecond));
      if LIndex >= 0 then
      begin
        LUnmatched.Delete(LIndex)
      end
      else
      begin
        LUnmatched.Add(TriangleKey(LFirst, LSecond, LThird));
      end;
    end;
  end;

begin
  LWhole := CubeScene(False);
  LSplit := nil;
  LTransform := TCastleTransform.Create(nil);
  LUnmatched := TStringList.Create;
  try
    LUnmatched.CaseSensitive := True;
    LUnmatched.UseLocale := False;
    LTransform.Translation := Vector3(10.25, 0.004, -17.2);
    LTransform.Rotation := Vector4(1, 2, -1, 0.63);
    LTransform.Scale := Vector3(1.7, 0.65, 2.2);
    LTriangles := LWhole.Shapes.TraverseList(True, True)[0].
      InternalShadowVolumes.TrianglesListShadowCasters;
    LRoot := TX3DRootNode.Create;
    for I := 0 to LTriangles.Count - 1 do
    begin
      LMesh := TIndexedTriangleSetNode.Create;
      LMesh.Coord := TCoordinateNode.Create;
      for J := 0 to 2 do
      begin
        TCoordinateNode(LMesh.Coord).FdPoint.Items.Add(LTriangles[I].Data[J]);
        LMesh.FdIndex.Items.Add(J);
      end;
      LNode := TShapeNode.Create;
      LNode.Geometry := LMesh;
      LRoot.AddChildren(LNode);
    end;
    LSplit := TCastleScene.Create(nil);
    LSplit.Load(LRoot, True);
    LShapes := LSplit.Shapes.TraverseList(True, True);
    Check(LShapes.Count = 12, 'Closed cube must have twelve separate triangle shapes');
    for I := 0 to LShapes.Count - 1 do
    begin
      LGeometry := TStaticShadowGeometry.Create(LShapes[I], LTransform.Transform,
        Vector4(-0.6, -1, -0.45, 0), True, 512);
      try
        IncludeSides(LGeometry.Sides, False);
      finally
        LGeometry.Free;
      end;
    end;
    LGeometry := TStaticShadowGeometry.Create(LWhole.Shapes.TraverseList(True, True)[0],
      LTransform.Transform, Vector4(-0.6, -1, -0.45, 0), False, 512);
    try
      IncludeSides(LGeometry.Sides, True);
    finally
      LGeometry.Free;
    end;
    WriteLn('sharedBorderUnmatchedTriangles=', LUnmatched.Count);
    Check(LUnmatched.Count = 0,
      'Material boundaries must not leave unmatched finite shadow triangles');
  finally
    LUnmatched.Free;
    LTransform.Free;
    LSplit.Free;
    LWhole.Free;
  end;
end;

begin
  try
    SharedBorderCase;
    GeometryCases;
    InvalidCases;
    CapacityCases;
    WriteLn('checks=', GChecks, ' failures=0 boundaryTriangles=',
      BoundaryAcceptedTriangles);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
