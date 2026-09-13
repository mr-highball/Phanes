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

program PhanesTestsOBJSurfaceCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  FPJSON,
  JSONParser,
  phanes.tools.files,
  phanes.tools.obj;

type
  TVector = array[0..2] of Double;
  TVectors = array of TVector;
  TCorner = record
    FPosition: TVector;
    FNormal: TVector;
    FUV: array[0..1] of Double;
    FHasUV: Boolean;
  end;
  TTriangle = record
    FCorners: array[0..2] of TCorner;
    FMaterial: String;
  end;
  TTriangles = array of TTriangle;
  TCaseProcedure = procedure;
  TDecodedGLB = class
  private
    FBuffer: TBytes;
    FNodeStates: array of Byte;
    FMeshVisits: array of Integer;
    function Component(const AAccessor, AElement, AComponent: Integer): Double;
    function ElementCount(const AAccessor: Integer): Integer;
    procedure VisitNode(const AIndex: Integer);
    procedure DecodePrimitive(const APrimitive: TJSONObject);
  public
    FDocument: TJSONObject;
    FTriangles: TTriangles;
    constructor Create(const ABytes: TBytes);
    destructor Destroy; override;
  end;

const
  BasicMTL = 'newmtl red'#10'Kd 0.125 0.25 0.5'#10;
  BasicOBJ = 'mtllib source.mtl'#10'usemtl red'#10+
    'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10'vn 0 0 1'#10'f 1//1 2//1 3//1'#10;
  ConventionalMTL = 'newmtl red'#10'Ns 250'#10'Ka 0.1 0.2 0.3'#10+
    'Kd 0.125 0.25 0.5'#10'Ks 0.4 0.5 0.6'#10'Ke 0 0 0'#10+
    'Ni 1.45'#10'd 1'#10'illum 2'#10;

var
  GChecks: Integer;
  GFailures: Integer;
  GCase: String;
  GFailureMessages: TJSONArray;
  GScratch: String;
  GFormat: TFormatSettings;



procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    Inc(GFailures);
    GFailureMessages.Add(GCase + ': ' + AMessage);
    WriteLn('FAIL ', GCase, ': ', AMessage);
  end;
end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  Check(ACondition, AMessage);
  if not ACondition then
  begin
    raise Exception.Create('Cannot continue independent decoder: ' + AMessage);
  end;
end;

function Bytes(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
  begin
    Move(AText[1], Result[0], Length(Result));
  end;
end;

function Vector(const AX, AY, AZ: Double): TVector;
begin
  Result[0] := AX;
  Result[1] := AY;
  Result[2] := AZ;
end;

function ReadU32(const ABytes: TBytes; const AOffset: Integer): Cardinal;
begin
  Need((AOffset >= 0) and (Int64(AOffset) + 4 <= Length(ABytes)), 'uint32 range');
  Result := Cardinal(ABytes[AOffset]) or (Cardinal(ABytes[AOffset + 1]) shl 8) or
    (Cardinal(ABytes[AOffset + 2]) shl 16) or (Cardinal(ABytes[AOffset + 3]) shl 24);
end;

function Near(const ALeft, ARight: Double): Boolean;
begin
  Result := not IsNan(ALeft) and not IsInfinite(ALeft) and
    (Abs(ALeft - ARight) <= 0.000002);
end;

function TDecodedGLB.ElementCount(const AAccessor: Integer): Integer;
begin
  Need((AAccessor >= 0) and (AAccessor < FDocument.Arrays['accessors'].Count),
    'accessor index range');
  Result := FDocument.Arrays['accessors'].Objects[AAccessor].Integers['count'];
  Need((Result > 0) and (Result <= 600000), 'accessor count bounds');
end;

function TDecodedGLB.Component(const AAccessor, AElement, AComponent: Integer): Double;
var
  LAccessor: TJSONObject;
  LView: TJSONObject;
  LWidth: Integer;
  LDimensions: Integer;
  LStride: Integer;
  LOffset: Int64;
  LBits: Cardinal;
  LFloat: Single;
begin
  Need((AElement >= 0) and (AElement < ElementCount(AAccessor)), 'accessor element');
  LAccessor := FDocument.Arrays['accessors'].Objects[AAccessor];
  Need(LAccessor.Find('sparse') = nil, 'unexpected sparse generated accessor');
  Need(not LAccessor.Get('normalized', False), 'unexpected normalized integer accessor');
  if LAccessor.Strings['type'] = 'VEC3' then
  begin
    LDimensions := 3;
  end
  else if LAccessor.Strings['type'] = 'VEC2' then
  begin
    LDimensions := 2;
  end
  else
  begin
    Need(LAccessor.Strings['type'] = 'SCALAR', 'accessor type');
    LDimensions := 1;
  end;
  Need((AComponent >= 0) and (AComponent < LDimensions), 'accessor component');
  case LAccessor.Integers['componentType'] of
    5121:
      begin
        LWidth := 1;
      end;
    5123:
      begin
        LWidth := 2;
      end;
    5125, 5126:
      begin
        LWidth := 4;
      end;
    else
      begin
        raise Exception.Create('Unsupported generated component type');
      end;
  end;
  Need((LAccessor.Integers['bufferView'] >= 0) and
    (LAccessor.Integers['bufferView'] < FDocument.Arrays['bufferViews'].Count),
    'buffer view index');
  LView := FDocument.Arrays['bufferViews'].Objects[LAccessor.Integers['bufferView']];
  Need(LView.Integers['buffer'] = 0, 'single generated buffer');
  LStride := LView.Get('byteStride', LDimensions * LWidth);
  Need(LStride >= LDimensions * LWidth, 'accessor stride');
  LOffset := Int64(LView.Get('byteOffset', 0)) + LAccessor.Get('byteOffset', 0) +
    Int64(AElement) * LStride + AComponent * LWidth;
  Need((LOffset mod LWidth = 0) and (LOffset >= LView.Get('byteOffset', 0)) and
    (LOffset + LWidth <= Int64(LView.Get('byteOffset', 0)) + LView.Int64s['byteLength']) and
    (LOffset + LWidth <= Length(FBuffer)), 'component alignment and byte bounds');
  if LAccessor.Integers['componentType'] = 5126 then
  begin
    LBits := ReadU32(FBuffer, LOffset);
    Move(LBits, LFloat, SizeOf(LFloat));
    Result := LFloat;
  end
  else
  begin
    LBits := FBuffer[LOffset];
    if LWidth >= 2 then
    begin
      LBits := LBits or (Cardinal(FBuffer[LOffset + 1]) shl 8);
    end;
    if LWidth = 4 then
    begin
      LBits := ReadU32(FBuffer, LOffset);
    end;
    Result := LBits;
  end;
  Need(not IsNan(Result) and not IsInfinite(Result), 'finite generated component');
end;

procedure TDecodedGLB.DecodePrimitive(const APrimitive: TJSONObject);
var
  LAttributes: TJSONObject;
  LPosition: Integer;
  LNormal: Integer;
  LUV: Integer;
  LIndex: Integer;
  LCount: Integer;
  LVertex: Integer;
  LMaterial: Integer;
  LTriangle: TTriangle;
  LLength: Double;
  LMinimum: TVector;
  LMaximum: TVector;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Need(APrimitive.Get('mode', 4) = 4, 'triangle primitive');
  LAttributes := APrimitive.Objects['attributes'];
  LPosition := LAttributes.Integers['POSITION'];
  LNormal := LAttributes.Integers['NORMAL'];
  Need(ElementCount(LPosition) = ElementCount(LNormal), 'normal/position cardinality');
  Need(FDocument.Arrays['accessors'].Objects[LPosition].Strings['type'] = 'VEC3',
    'position VEC3');
  Need(FDocument.Arrays['accessors'].Objects[LNormal].Strings['type'] = 'VEC3',
    'normal VEC3');
  LUV := LAttributes.Get('TEXCOORD_0', -1);
  if LUV >= 0 then
  begin
    Need(ElementCount(LUV) = ElementCount(LPosition), 'UV/position cardinality');
  end;
  LIndex := APrimitive.Get('indices', -1);
  if LIndex >= 0 then
  begin
    LCount := ElementCount(LIndex);
  end
  else
  begin
    LCount := ElementCount(LPosition);
  end;
  Need(LCount mod 3 = 0, 'complete indexed triangles');
  LMaterial := APrimitive.Integers['material'];
  Need((LMaterial >= 0) and (LMaterial < FDocument.Arrays['materials'].Count),
    'material ownership');
  LTriangle.FMaterial := FDocument.Arrays['materials'].Objects[LMaterial].Strings['name'];
  for I := 0 to 2 do
  begin
    LMinimum[I] := Infinity;
    LMaximum[I] := NegInfinity;
  end;
  for I := 0 to LCount div 3 - 1 do
  begin
    for J := 0 to 2 do
    begin
      LVertex := I * 3 + J;
      if LIndex >= 0 then
      begin
        LVertex := Round(Component(LIndex, LVertex, 0));
      end;
      Need((LVertex >= 0) and (LVertex < ElementCount(LPosition)), 'generated index range');
      LLength := 0;
      for K := 0 to 2 do
      begin
        LTriangle.FCorners[J].FPosition[K] := Component(LPosition, LVertex, K);
        LMinimum[K] := Min(LMinimum[K], LTriangle.FCorners[J].FPosition[K]);
        LMaximum[K] := Max(LMaximum[K], LTriangle.FCorners[J].FPosition[K]);
        LTriangle.FCorners[J].FNormal[K] := Component(LNormal, LVertex, K);
        LLength := LLength + Sqr(LTriangle.FCorners[J].FNormal[K]);
      end;
      Check(Near(Sqrt(LLength), 1), 'generated unit normal');
      LTriangle.FCorners[J].FHasUV := LUV >= 0;
      if LUV >= 0 then
      begin
        for K := 0 to 1 do
        begin
          LTriangle.FCorners[J].FUV[K] := Component(LUV, LVertex, K);
        end;
      end;
    end;
    SetLength(FTriangles, Length(FTriangles) + 1);
    FTriangles[High(FTriangles)] := LTriangle;
  end;
  for I := 0 to 2 do
  begin
    Check(Near(FDocument.Arrays['accessors'].Objects[LPosition].Arrays['min'].Floats[I],
      LMinimum[I]), 'position minimum matches actual emitted corners');
    Check(Near(FDocument.Arrays['accessors'].Objects[LPosition].Arrays['max'].Floats[I],
      LMaximum[I]), 'position maximum matches actual emitted corners');
  end;
end;

procedure TDecodedGLB.VisitNode(const AIndex: Integer);
var
  LNode: TJSONObject;
  LValues: TJSONArray;
  LMesh: Integer;
  LExpected: Double;
  I: Integer;
begin
  Need((AIndex >= 0) and (AIndex < Length(FNodeStates)), 'scene node reference');
  Need(FNodeStates[AIndex] = 0, 'acyclic singly owned scene nodes');
  FNodeStates[AIndex] := 1;
  LNode := FDocument.Arrays['nodes'].Objects[AIndex];
  Need(LNode.Find('skin') = nil, 'static output has no skin');
  if LNode.Find('matrix') <> nil then
  begin
    LValues := LNode.Arrays['matrix'];
    Need(LValues.Count = 16, 'matrix size');
    for I := 0 to 15 do
    begin
      LExpected := 0;
      if I mod 5 = 0 then
      begin
        LExpected := 1;
      end;
      Need(Near(LValues.Floats[I], LExpected), 'source-identity output matrix');
    end;
  end;
  Need((LNode.Find('translation') = nil) and (LNode.Find('rotation') = nil) and
    (LNode.Find('scale') = nil), 'no implicit coordinate adaptation');
  if LNode.Find('mesh') <> nil then
  begin
    LMesh := LNode.Integers['mesh'];
    Need((LMesh >= 0) and (LMesh < Length(FMeshVisits)), 'scene mesh reference');
    Inc(FMeshVisits[LMesh]);
    for I := 0 to FDocument.Arrays['meshes'].Objects[LMesh].Arrays['primitives'].Count - 1 do
    begin
      DecodePrimitive(FDocument.Arrays['meshes'].Objects[LMesh].Arrays['primitives'].Objects[I]);
    end;
  end;
  if LNode.Find('children') <> nil then
  begin
    for I := 0 to LNode.Arrays['children'].Count - 1 do
    begin
      VisitNode(LNode.Arrays['children'].Integers[I]);
    end;
  end;
  FNodeStates[AIndex] := 2;
end;

constructor TDecodedGLB.Create(const ABytes: TBytes);
var
  LJSONLength: Integer;
  LBinStart: Integer;
  LBinLength: Integer;
  LText: UTF8String;
  LScene: TJSONObject;
  I: Integer;
begin
  inherited Create;
  Need(Length(ABytes) >= 28, 'nonempty GLB structure');
  Need(ReadU32(ABytes, 0) = $46546C67, 'GLB magic');
  Need(ReadU32(ABytes, 4) = 2, 'GLB version');
  Need(ReadU32(ABytes, 8) = Cardinal(Length(ABytes)), 'GLB total bytes');
  LJSONLength := ReadU32(ABytes, 12);
  Need((LJSONLength > 0) and (LJSONLength mod 4 = 0) and
    (Int64(LJSONLength) + 28 <= Length(ABytes)), 'JSON chunk alignment/range');
  Need(ReadU32(ABytes, 16) = $4E4F534A, 'JSON chunk type');
  SetString(LText, PAnsiChar(@ABytes[20]), LJSONLength);
  FDocument := GetJSON(LText) as TJSONObject;
  Need(FDocument.Objects['asset'].Strings['version'] = '2.0', 'glTF asset version');
  LBinStart := 20 + LJSONLength;
  LBinLength := ReadU32(ABytes, LBinStart);
  Need(ReadU32(ABytes, LBinStart + 4) = $004E4942, 'BIN chunk type');
  Need((LBinLength mod 4 = 0) and (Int64(LBinStart) + 8 + LBinLength = Length(ABytes)),
    'one bounded aligned BIN chunk');
  FBuffer := Copy(ABytes, LBinStart + 8, LBinLength);
  Need(FDocument.Arrays['buffers'].Count = 1, 'one embedded buffer');
  Need(FDocument.Arrays['buffers'].Objects[0].Find('uri') = nil, 'no external buffer URI');
  I := FDocument.Arrays['buffers'].Objects[0].Integers['byteLength'];
  Need((I > 0) and (I <= LBinLength) and (LBinLength - I <= 3), 'declared buffer length');
  while I < LBinLength do
  begin
    Check(FBuffer[I] = 0, 'zero BIN padding');
    Inc(I);
  end;
  Need((FDocument.Find('images') = nil) and (FDocument.Find('textures') = nil),
    'untextured recipe has no image dependency');
  Need(FDocument.Find('animations') = nil, 'static recipe has no animation');
  Need(FDocument.Arrays['scenes'].Count = 1, 'one generated scene');
  LScene := FDocument.Arrays['scenes'].Objects[FDocument.Get('scene', 0)];
  SetLength(FNodeStates, FDocument.Arrays['nodes'].Count);
  SetLength(FMeshVisits, FDocument.Arrays['meshes'].Count);
  for I := 0 to LScene.Arrays['nodes'].Count - 1 do
  begin
    VisitNode(LScene.Arrays['nodes'].Integers[I]);
  end;
  for I := 0 to High(FNodeStates) do
  begin
    Check(FNodeStates[I] = 2, 'every generated node is reachable');
  end;
  for I := 0 to High(FMeshVisits) do
  begin
    Check(FMeshVisits[I] = 1, 'every generated mesh occurs exactly once');
  end;
end;

destructor TDecodedGLB.Destroy;
begin
  FDocument.Free;
  inherited Destroy;
end;

type
  TSourceFace = record
    FPoints: TVectors;
    FMaterial: String;
    FLine: Integer;
    FNormal: TVector;
    FSpan: Double;
    FDeviation: Double;
  end;
  TSourceFaces = array of TSourceFace;

var
  GPositiveFaces: Integer;
  GMaximumObservedDeviation: Double;

function Dot(const ALeft, ARight: TVector): Double;
begin
  Result := ALeft[0] * ARight[0] + ALeft[1] * ARight[1] + ALeft[2] * ARight[2];
end;

function Difference(const ALeft, ARight: TVector): TVector;
var
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    Result[I] := ALeft[I] - ARight[I];
  end;
end;

function Cross(const ALeft, ARight: TVector): TVector;
begin
  Result[0] := ALeft[1] * ARight[2] - ALeft[2] * ARight[1];
  Result[1] := ALeft[2] * ARight[0] - ALeft[0] * ARight[2];
  Result[2] := ALeft[0] * ARight[1] - ALeft[1] * ARight[0];
end;

function UnitVector(const AValue: TVector): TVector;
var
  LLength: Double;
  I: Integer;
begin
  LLength := Sqrt(Dot(AValue, AValue));
  Need(LLength > 0, 'nonzero independent vector');
  for I := 0 to 2 do
  begin
    Result[I] := AValue[I] / LLength;
  end;
end;

procedure MeasureFace(var AFace: TSourceFace);
var
  LMinimum: TVector;
  LMaximum: TVector;
  LNormal: TVector;
  LDelta: Double;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Need(Length(AFace.FPoints) >= 3, 'independent source polygon');
  LMinimum := AFace.FPoints[0];
  LMaximum := LMinimum;
  LNormal := Vector(0, 0, 0);
  { Newell's coordinate-sum expression is independent of the converter's
    origin-shifted edge cross products. All fixture positions are exactly
    representable in float32. }
  for I := 0 to High(AFace.FPoints) do
  begin
    J := (I + 1) mod Length(AFace.FPoints);
    LNormal[0] := LNormal[0] + (AFace.FPoints[I][1] - AFace.FPoints[J][1]) *
      (AFace.FPoints[I][2] + AFace.FPoints[J][2]);
    LNormal[1] := LNormal[1] + (AFace.FPoints[I][2] - AFace.FPoints[J][2]) *
      (AFace.FPoints[I][0] + AFace.FPoints[J][0]);
    LNormal[2] := LNormal[2] + (AFace.FPoints[I][0] - AFace.FPoints[J][0]) *
      (AFace.FPoints[I][1] + AFace.FPoints[J][1]);
    for K := 0 to 2 do
    begin
      if AFace.FPoints[I][K] < LMinimum[K] then
      begin
        LMinimum[K] := AFace.FPoints[I][K];
      end;
      if AFace.FPoints[I][K] > LMaximum[K] then
      begin
        LMaximum[K] := AFace.FPoints[I][K];
      end;
    end;
  end;
  AFace.FNormal := UnitVector(LNormal);
  AFace.FSpan := 0;
  for K := 0 to 2 do
  begin
    if LMaximum[K] - LMinimum[K] > AFace.FSpan then
    begin
      AFace.FSpan := LMaximum[K] - LMinimum[K];
    end;
  end;
  AFace.FDeviation := 0;
  for I := 0 to High(AFace.FPoints) do
  begin
    LDelta := Abs(Dot(Difference(AFace.FPoints[I], AFace.FPoints[0]),
      AFace.FNormal)) / AFace.FSpan;
    if LDelta > AFace.FDeviation then
    begin
      AFace.FDeviation := LDelta;
    end;
  end;
end;

function BuildSource(var AFaces: TSourceFaces): UTF8String;
var
  LLine: Integer;
  LIndex: Integer;
  LFace: String;
  LNormal: TVector;
  I: Integer;
  J: Integer;
begin
  Result := 'mtllib source.mtl'#10;
  LLine := 1;
  LIndex := 0;
  for I := 0 to High(AFaces) do
  begin
    Result := Result + 'usemtl ' + AFaces[I].FMaterial + #10;
    Inc(LLine);
    LFace := 'f';
    for J := 0 to High(AFaces[I].FPoints) do
    begin
      Inc(LIndex);
      Result := Result + Format('v %.15f %.15f %.15f'#10,
        [AFaces[I].FPoints[J][0], AFaces[I].FPoints[J][1], AFaces[I].FPoints[J][2]], GFormat);
      { Distinct explicit source normals and UVs expose corner reassignment,
        even when multiple triangles reuse the same geometric position. }
      LNormal := Vector(J + 1, 2, 3);
      Result := Result + Format('vn %.9f %.9f %.9f'#10,
        [LNormal[0], LNormal[1], LNormal[2]], GFormat);
      Result := Result + Format('vt %.9f %.9f'#10, [J / 8, -J / 4], GFormat);
      LFace := LFace + ' ' + IntToStr(LIndex) + '/' + IntToStr(LIndex) + '/' + IntToStr(LIndex);
      Inc(LLine, 3);
    end;
    Inc(LLine);
    AFaces[I].FLine := LLine;
    Result := Result + LFace + #10;
  end;
end;

function Materials: UTF8String;
begin
  Result := BasicMTL + 'newmtl blue'#10'Kd 0.6 0.4 0.2'#10;
end;

procedure CheckSurface(const AInput: TSourceFaces; const AFixedQuadChoice: Boolean = False);
var
  LFaces: TSourceFaces;
  LOBJ: TBytes;
  LMTL: TBytes;
  LOutput: TBytes;
  LRepeat: TBytes;
  LEvidence: TJSONObject;
  LRepeatedEvidence: TJSONObject;
  LPlanarEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LPlanarDecoded: TDecodedGLB;
  LPrimitive: TJSONObject;
  LEmbeddedEvidence: TJSONObject;
  LSegments: TJSONArray;
  LSegment: TJSONObject;
  LSeen: array of Boolean;
  LEdges: array of array of Integer;
  LIndices: array[0..2] of Integer;
  LTriangleBase: Integer;
  LStart: Integer;
  LCount: Integer;
  LFound: Integer;
  LNonplanar: Integer;
  LTriangleCount: Integer;
  LMaximum: Double;
  LNormal: TVector;
  LMatch: Boolean;
  LRefused: Boolean;
  LOriginalHash: String;
  LOldDirectory: String;
  LOldDecimal: Char;
  LOldRandom: LongInt;
  LAlternate: String;
  LExpectedQuad: array[0..5] of Integer;
  I: Integer;
  J: Integer;
  K: Integer;
  L: Integer;
  LCorner: Integer;
  LVertex: Integer;
begin
  LFaces := Copy(AInput, 0, Length(AInput));
  LNonplanar := 0;
  LTriangleCount := 0;
  LMaximum := 0;
  for I := 0 to High(LFaces) do
  begin
    MeasureFace(LFaces[I]);
    if LFaces[I].FDeviation > 0.00001 then
    begin
      Inc(LNonplanar);
    end;
    if LFaces[I].FDeviation > LMaximum then
    begin
      LMaximum := LFaces[I].FDeviation;
    end;
    Inc(LTriangleCount, Length(LFaces[I].FPoints) - 2);
  end;
  LOBJ := Bytes(BuildSource(LFaces));
  LMTL := Bytes(Materials);
  LOriginalHash := HashBytes(LOBJ);
  LEvidence := nil;
  LRepeatedEvidence := nil;
  LPlanarEvidence := nil;
  LDecoded := nil;
  LPlanarDecoded := nil;
  try
    LOutput := ConvertSurfaceOBJ('source.obj', 'source.mtl', LOBJ, LMTL, LEvidence);
    Need(LEvidence <> nil, 'surface evidence returned');
    LDecoded := TDecodedGLB.Create(LOutput);
    Check(LEvidence.Strings['recipe'] = 'phanes.obj.surface.v1', 'separate topology recipe');
    Check(LEvidence.Strings['surfacePolicy'] = 'projected-ear-clipping',
      'explicit topology policy');
    Check(LEvidence.Strings['objSha256'] = LOriginalHash, 'original source hash');
    Check(LEvidence.Strings['mtlSha256'] = HashBytes(LMTL), 'original material hash');
    Check(LEvidence.Strings['outputSha256'] = HashBytes(LOutput), 'derived output hash');
    LEmbeddedEvidence := TJSONObject(LEvidence.Clone);
    try
      LEmbeddedEvidence.Delete('outputSha256');
      Check(LDecoded.FDocument.Objects['asset'].Objects['extras'].AsJSON =
        LEmbeddedEvidence.AsJSON, 'embedded derivation retains complete surface evidence');
    finally
      LEmbeddedEvidence.Free;
    end;
    Check(LEvidence.Strings['coordinatePolicy'] = 'source-identity', 'no vertex flattening');
    Check(LEvidence.Strings['units'] = 'unspecified', 'no invented units');
    Check(LEvidence.Integers['nonplanarFaces'] = LNonplanar, 'nonplanar face aggregate');
    Check(Abs(LEvidence.Floats['maximumPlaneDeviationRatio'] - LMaximum) <= 1e-10,
      'independent Newell first-corner deviation aggregate');
    Check(LEvidence.Integers['triangleCount'] = LTriangleCount, 'all source faces triangulated');
    Need(Length(LDecoded.FTriangles) = LTriangleCount, 'decoded triangle count');
    Check(LEvidence.Integers['sourceFaceCount'] = Length(LFaces), 'no skipped source faces');
    SetLength(LSeen, Length(LFaces));
    LTriangleBase := 0;
    LExpectedQuad[0] := 3;
    LExpectedQuad[1] := 0;
    LExpectedQuad[2] := 1;
    LExpectedQuad[3] := 1;
    LExpectedQuad[4] := 2;
    LExpectedQuad[5] := 3;
    for I := 0 to LDecoded.FDocument.Arrays['meshes'].Objects[0].Arrays['primitives'].Count - 1 do
    begin
      LPrimitive := LDecoded.FDocument.Arrays['meshes'].Objects[0].Arrays['primitives'].Objects[I];
      LSegments := LPrimitive.Objects['extras'].Arrays['sourceFaces'];
      LVertex := 0;
      for J := 0 to LSegments.Count - 1 do
      begin
        LSegment := LSegments.Objects[J];
        LFound := -1;
        for K := 0 to High(LFaces) do
        begin
          if LFaces[K].FLine = LSegment.Integers['line'] then
          begin
            LFound := K;
          end;
        end;
        Need((LFound >= 0) and not LSeen[LFound], 'unique source line owns emitted face');
        LSeen[LFound] := True;
        Check(Abs(LSegment.Floats['planeDeviationRatio'] - LFaces[LFound].FDeviation) <= 1e-10,
          'independent per-face deviation');
        Check(LSegment.Integers['firstVertex'] = LVertex, 'source face ranges are contiguous');
        LCount := LSegment.Integers['vertexCount'];
        Check(LCount = (Length(LFaces[LFound].FPoints) - 2) * 3, 'source face corner count');
        LStart := LTriangleBase + LVertex div 3;
        SetLength(LEdges, 0);
        SetLength(LEdges, Length(LFaces[LFound].FPoints), Length(LFaces[LFound].FPoints));
        for K := 0 to LCount div 3 - 1 do
        begin
          Check(LDecoded.FTriangles[LStart + K].FMaterial = LFaces[LFound].FMaterial,
            'original face material retained');
          for LCorner := 0 to 2 do
          begin
            LIndices[LCorner] := -1;
            for L := 0 to High(LFaces[LFound].FPoints) do
            begin
              LMatch := Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FPosition[0],
                  LFaces[LFound].FPoints[L][0]) and
                Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FPosition[1],
                  LFaces[LFound].FPoints[L][1]) and
                Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FPosition[2],
                  LFaces[LFound].FPoints[L][2]);
              if LMatch then
              begin
                Need(LIndices[LCorner] < 0, 'unambiguous unchanged XYZ correspondence');
                LIndices[LCorner] := L;
              end;
            end;
            Need(LIndices[LCorner] >= 0, 'every output corner retains original 3D position');
            L := LIndices[LCorner];
            LNormal := UnitVector(Vector(L + 1, 2, 3));
            Check(Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FNormal[0], LNormal[0]) and
              Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FNormal[1], LNormal[1]) and
              Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FNormal[2], LNormal[2]),
              'source corner normal retained and normalized');
            Check(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FHasUV and
              Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FUV[0], L / 8) and
              Near(LDecoded.FTriangles[LStart + K].FCorners[LCorner].FUV[1], 1 + L / 4),
              'source corner UV retained with one V flip');
            if AFixedQuadChoice then
            begin
              Check(L = LExpectedQuad[K * 3 + LCorner], 'declared first-ear quad diagonal');
            end;
          end;
          LNormal := Cross(Difference(LFaces[LFound].FPoints[LIndices[1]],
            LFaces[LFound].FPoints[LIndices[0]]),
            Difference(LFaces[LFound].FPoints[LIndices[2]], LFaces[LFound].FPoints[LIndices[0]]));
          Check(Dot(LNormal, LFaces[LFound].FNormal) > Sqr(LFaces[LFound].FSpan) * 1e-12,
            'triangle geometric normal agrees with original mean normal');
          for LCorner := 0 to 2 do
          begin
            L := (LCorner + 1) mod 3;
            Inc(LEdges[LIndices[LCorner]][LIndices[L]]);
            Dec(LEdges[LIndices[L]][LIndices[LCorner]]);
          end;
        end;
        for K := 0 to High(LFaces[LFound].FPoints) do
        begin
          L := (K + 1) mod Length(LFaces[LFound].FPoints);
          Check(LEdges[K][L] = 1, 'oriented source polygon boundary retained');
          Dec(LEdges[K][L]);
          Inc(LEdges[L][K]);
        end;
        for K := 0 to High(LEdges) do
        begin
          for L := 0 to High(LEdges[K]) do
          begin
            Check(LEdges[K][L] = 0, 'all internal surface edges cancel');
          end;
        end;
        Inc(LVertex, LCount);
      end;
      Inc(LTriangleBase, LVertex div 3);
    end;
    for I := 0 to High(LSeen) do
    begin
      Check(LSeen[I], 'every source face has visible output');
    end;
    Check(LTriangleBase = Length(LDecoded.FTriangles), 'no unowned output triangles');
    LOldDirectory := GetCurrentDir;
    LOldDecimal := DefaultFormatSettings.DecimalSeparator;
    LOldRandom := RandSeed;
    LAlternate := SafeChild(GScratch, 'alternate');
    ForceDirectories(LAlternate);
    try
      Need(SetCurrentDir(LAlternate), 'alternate surface conversion cwd');
      DefaultFormatSettings.DecimalSeparator := ',';
      RandSeed := 987654;
      LRepeat := ConvertSurfaceOBJ('source.obj', 'source.mtl', LOBJ, LMTL, LRepeatedEvidence);
    finally
      RandSeed := LOldRandom;
      DefaultFormatSettings.DecimalSeparator := LOldDecimal;
      SetCurrentDir(LOldDirectory);
    end;
    Check(HashBytes(LRepeat) = HashBytes(LOutput), 'repeat chooses identical surface and GLB');
    Check(LRepeatedEvidence.AsJSON = LEvidence.AsJSON, 'repeat derivation evidence unchanged');
    Check(HashBytes(LOBJ) = LOriginalHash, 'surface conversion preserves original input');
    if LNonplanar > 0 then
    begin
      LRefused := False;
      try
        LRepeat := ConvertStaticOBJ('source.obj', 'source.mtl', LOBJ, LMTL, LPlanarEvidence);
      except
        on LException: Exception do
        begin
          LRefused := True;
        end;
      end;
      Check(LRefused and (LPlanarEvidence = nil), 'planar API keeps refusing nonplanar source');
    end
    else
    begin
      LRepeat := ConvertStaticOBJ('source.obj', 'source.mtl', LOBJ, LMTL, LPlanarEvidence);
      LPlanarDecoded := TDecodedGLB.Create(LRepeat);
      Need(Length(LPlanarDecoded.FTriangles) = Length(LDecoded.FTriangles),
        'planar sources keep identical triangle count in both recipes');
      Check(LPlanarEvidence.Strings['recipe'] = 'phanes.obj.matte.v1', 'planar recipe retained');
      Check(LPlanarEvidence.Find('surfacePolicy') = nil,
        'surface metadata does not leak to planar API');
      for I := 0 to High(LDecoded.FTriangles) do
      begin
        for J := 0 to 2 do
        begin
          for K := 0 to 2 do
          begin
            Check(Near(LPlanarDecoded.FTriangles[I].FCorners[J].FPosition[K],
              LDecoded.FTriangles[I].FCorners[J].FPosition[K]),
              'same planar source keeps same emitted corners');
          end;
        end;
      end;
    end;
    Inc(GPositiveFaces, Length(LFaces));
    if LMaximum > GMaximumObservedDeviation then
    begin
      GMaximumObservedDeviation := LMaximum;
    end;
    WriteBytes(SafeChild(GScratch, GCase + '.glb'), LOutput);
    WriteText(SafeChild(GScratch, GCase + '.json'), LEvidence.FormatJSON);
  finally
    LPlanarDecoded.Free;
    LDecoded.Free;
    LPlanarEvidence.Free;
    LRepeatedEvidence.Free;
    LEvidence.Free;
  end;
end;

procedure RejectSurface(const AInput: TSourceFaces; const AReason: String);
var
  LFaces: TSourceFaces;
  LOBJ: TBytes;
  LMTL: TBytes;
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LRefused: Boolean;
  LHash: String;
begin
  LFaces := Copy(AInput, 0, Length(AInput));
  LOBJ := Bytes(BuildSource(LFaces));
  LMTL := Bytes(Materials);
  LHash := HashBytes(LOBJ);
  LEvidence := nil;
  LRefused := False;
  try
    try
      LOutput := ConvertSurfaceOBJ('source.obj', 'source.mtl', LOBJ, LMTL, LEvidence);
      Check(Length(LOutput) = 0, 'invalid surface publishes no bytes');
    except
      on LException: Exception do
      begin
        LRefused := True;
        Check(not (LException is EAccessViolation), 'surface rejection is a validation exception');
        Check((AReason = '') or (Pos(AReason, LowerCase(LException.Message)) > 0),
          'rejection reaches intended geometry boundary: ' + LException.Message);
      end;
    end;
    Check(LRefused, 'invalid surface rejected');
    Check(LEvidence = nil, 'failed surface has nil evidence');
    Check(HashBytes(LOBJ) = LHash, 'failed surface preserves original bytes');
  finally
    LEvidence.Free;
  end;
end;

function WarpedQuad: TSourceFaces;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0].FMaterial := 'red';
  SetLength(Result[0].FPoints, 4);
  Result[0].FPoints[0] := Vector(0, 0, 0);
  Result[0].FPoints[1] := Vector(2, 0, 0);
  Result[0].FPoints[2] := Vector(2, 2, 1);
  Result[0].FPoints[3] := Vector(0, 2, 0);
end;

procedure PositiveSurfaces;
var
  LFaces: TSourceFaces;
  LOld: TVector;
  LNormalA: TVector;
  LNormalB: TVector;
  LAngle: Double;
  I: Integer;
begin
  GCase := 'warped-quad';
  LFaces := WarpedQuad;
  CheckSurface(LFaces, True);
  GCase := 'below-planarity-classification';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[2][2] := 1 / 65536;
  CheckSurface(LFaces, True);
  GCase := 'above-planarity-classification';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[2][2] := 1 / 16384;
  CheckSurface(LFaces, True);
  GCase := 'reversed-quad';
  LFaces := WarpedQuad;
  for I := 0 to 1 do
  begin
    LOld := LFaces[0].FPoints[I];
    LFaces[0].FPoints[I] := LFaces[0].FPoints[3 - I];
    LFaces[0].FPoints[3 - I] := LOld;
  end;
  CheckSurface(LFaces, True);
  GCase := 'vertical-warp';
  LFaces := WarpedQuad;
  for I := 0 to 3 do
  begin
    LOld := LFaces[0].FPoints[I];
    LFaces[0].FPoints[I] := Vector(LOld[2], LOld[0], LOld[1]);
  end;
  CheckSurface(LFaces, True);
  GCase := 'canted-warp';
  LFaces := WarpedQuad;
  for I := 0 to 3 do
  begin
    LOld := LFaces[0].FPoints[I];
    LFaces[0].FPoints[I] := Vector(LOld[0] + LOld[2], LOld[1] + LOld[0], LOld[2] + LOld[1]);
  end;
  CheckSurface(LFaces);
  GCase := 'concave-warp';
  SetLength(LFaces[0].FPoints, 6);
  LFaces[0].FPoints[0] := Vector(0, 0, 0);
  LFaces[0].FPoints[1] := Vector(3, 0, 0.25);
  LFaces[0].FPoints[2] := Vector(3, 1, 0);
  LFaces[0].FPoints[3] := Vector(1, 1, 0.5);
  LFaces[0].FPoints[4] := Vector(1, 3, 0.25);
  LFaces[0].FPoints[5] := Vector(0, 3, 0);
  CheckSurface(LFaces);
  GCase := 'mixed-planar-nonplanar';
  SetLength(LFaces, 2);
  LFaces[1].FMaterial := 'blue';
  SetLength(LFaces[1].FPoints, 3);
  LFaces[1].FPoints[0] := Vector(10, 0, 0);
  LFaces[1].FPoints[1] := Vector(12, 0, 0);
  LFaces[1].FPoints[2] := Vector(10, 2, 0);
  CheckSurface(LFaces);
  GCase := 'sharp-retained-saddle';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[0][2] := 3;
  LFaces[0].FPoints[1][2] := -3;
  LFaces[0].FPoints[2][2] := 3;
  LFaces[0].FPoints[3][2] := -3;
  CheckSurface(LFaces, True);
  LNormalA := UnitVector(Cross(Difference(LFaces[0].FPoints[0], LFaces[0].FPoints[3]),
    Difference(LFaces[0].FPoints[1], LFaces[0].FPoints[3])));
  LNormalB := UnitVector(Cross(Difference(LFaces[0].FPoints[2], LFaces[0].FPoints[1]),
    Difference(LFaces[0].FPoints[3], LFaces[0].FPoints[1])));
  LAngle := ArcCos(Dot(LNormalA, LNormalB)) * 180 / Pi;
  Check(LAngle > 150, 'mean-normal consistency does not prohibit a sharp retained crease');
end;

procedure RejectedSurfaces;
var
  LFaces: TSourceFaces;
begin
  GCase := 'mean-normal-fold';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[1][2] := -3;
  LFaces[0].FPoints[2][2] := 3;
  LFaces[0].FPoints[3][2] := -3;
  RejectSurface(LFaces, 'fold');
  GCase := 'projected-self-intersection';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[1] := Vector(2, 2, 0);
  LFaces[0].FPoints[2] := Vector(0, 2, 0);
  LFaces[0].FPoints[3] := Vector(2, 0, 0);
  RejectSurface(LFaces, '');
  GCase := 'repeated-source-corner';
  LFaces := WarpedQuad;
  LFaces[0].FPoints[3] := LFaces[0].FPoints[0];
  RejectSurface(LFaces, '');
  GCase := 'whole-batch-refusal';
  LFaces := WarpedQuad;
  SetLength(LFaces, 2);
  LFaces[1].FMaterial := 'blue';
  SetLength(LFaces[1].FPoints, 4);
  LFaces[1].FPoints[0] := Vector(10, 0, 0);
  LFaces[1].FPoints[1] := Vector(12, 0, -3);
  LFaces[1].FPoints[2] := Vector(12, 2, 3);
  LFaces[1].FPoints[3] := Vector(10, 2, -3);
  RejectSurface(LFaces, 'fold');
end;

procedure Run;
var
  LRoot: String;
  LGuid: TGUID;
  LReport: TJSONObject;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root [scratch root]');
  LRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(LRoot, 'build/tests/obj-surface-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fixture ID');
  GScratch := SafeChild(GScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Fixture directory must be fresh');
  ForceDirectories(GScratch);
  GFormat := DefaultFormatSettings;
  GFormat.DecimalSeparator := '.';
  GFailureMessages := TJSONArray.Create;
  LReport := nil;
  try
    try
      PositiveSurfaces;
    except
      on LException: Exception do
      begin
        Check(False, 'unexpected positive surface exception: ' + LException.Message);
      end;
    end;
    try
      RejectedSurfaces;
    except
      on LException: Exception do
      begin
        Check(False, 'unexpected rejection fixture exception: ' + LException.Message);
      end;
    end;
    LReport := TJSONObject.Create(['checks', GChecks, 'failures', GFailures,
      'positiveSourceFaces', GPositiveFaces,
      'maximumObservedDeviationRatio', GMaximumObservedDeviation,
      'recipe', 'phanes.obj.surface.v1', 'scratch', GScratch]);
    LReport.Add('messages', GFailureMessages);
    GFailureMessages := nil;
    WriteTextAtomic(SafeChild(GScratch, 'evidence.json'), LReport.FormatJSON);
    WriteLn(GChecks, ' checks, ', GFailures, ' failures');
    WriteLn('Evidence: ', SafeChild(GScratch, 'evidence.json'));
  finally
    LReport.Free;
    GFailureMessages.Free;
  end;
end;

begin
  Run;
  if GFailures <> 0 then
  begin
    Halt(1);
  end;
end.
