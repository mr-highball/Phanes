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

program PhanesTestsOBJCritic;

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

function SameJSON(const ALeft, ARight: TJSONData): Boolean; forward;

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

function Convert(const AOBJ, AMTL: UTF8String; out AEvidence: TJSONObject): TBytes;
var
  LOBJ: TBytes;
  LMTL: TBytes;
  LOBJHash: String;
  LMTLHash: String;
begin
  LOBJ := Bytes(AOBJ);
  LMTL := Bytes(AMTL);
  LOBJHash := HashBytes(LOBJ);
  LMTLHash := HashBytes(LMTL);
  Result := ConvertStaticOBJ('source.obj', 'source.mtl', LOBJ, LMTL, AEvidence);
  Check(HashBytes(LOBJ) = LOBJHash, 'OBJ input bytes preserved');
  Check(HashBytes(LMTL) = LMTLHash, 'MTL input bytes preserved');
  Need(AEvidence <> nil, 'successful derivation evidence');
  Check(AEvidence.Strings['recipe'] = 'phanes.obj.matte.v1', 'named material adaptation');
  Check(AEvidence.Strings['objSha256'] = LOBJHash, 'original OBJ evidence binding');
  Check(AEvidence.Strings['mtlSha256'] = LMTLHash, 'original MTL evidence binding');
  Check(AEvidence.Strings['outputSha256'] = HashBytes(Result), 'derived GLB evidence binding');
  Check(AEvidence.Strings['sourceName'] = 'source.obj', 'source name retained');
  Check(AEvidence.Strings['materialName'] = 'source.mtl', 'material name retained');
  Check(AEvidence.Strings['coordinatePolicy'] = 'source-identity', 'coordinate policy');
  Check(AEvidence.Strings['units'] = 'unspecified', 'no invented source metre units');
  Check(AEvidence.Strings['normalPolicy'] = 'normalized', 'normal policy');
  Check(AEvidence.Strings['uvPolicy'] = 'v-flipped', 'UV policy');
end;

procedure Reject(const ALabel, AOBJ, AMTL: UTF8String;
  const ASourceName: String = 'source.obj'; const AMaterialName: String = 'source.mtl');
var
  LOBJ: TBytes;
  LMTL: TBytes;
  LOBJHash: String;
  LMTLHash: String;
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LRefused: Boolean;
begin
  LOBJ := Bytes(AOBJ);
  LMTL := Bytes(AMTL);
  LOBJHash := HashBytes(LOBJ);
  LMTLHash := HashBytes(LMTL);
  LEvidence := nil;
  LRefused := False;
  try
    try
      LOutput := ConvertStaticOBJ(ASourceName, AMaterialName, LOBJ, LMTL, LEvidence);
      Check(Length(LOutput) = 0, ALabel + ' produced bytes for rejected input');
    except
      on LException: Exception do
      begin
        LRefused := True;
        Check(not (LException is EAccessViolation), ALabel + ' safe validation exception');
        Check(LException.Message <> '', ALabel + ' actionable refusal reason');
      end;
    end;
    Check(LRefused, ALabel + ' rejects');
    Check(LEvidence = nil, ALabel + ' clears out evidence on failure');
    Check(HashBytes(LOBJ) = LOBJHash, ALabel + ' preserves OBJ input');
    Check(HashBytes(LMTL) = LMTLHash, ALabel + ' preserves MTL input');
  finally
    LEvidence.Free;
  end;
end;

procedure CheckEvidence(const ADecoded: TDecodedGLB; const AEvidence: TJSONObject);
var
  LExpected: TJSONObject;
  I: Integer;
begin
  Check(AEvidence.Integers['triangleCount'] = Length(ADecoded.FTriangles),
    'evidence triangle count reflects decoded mesh');
  Check(AEvidence.Integers['vertexCount'] = Length(ADecoded.FTriangles) * 3,
    'evidence emitted corner count');
  LExpected := AEvidence.Clone as TJSONObject;
  try
    LExpected.Delete('outputSha256');
    Check(SameJSON(ADecoded.FDocument.Objects['asset'].Objects['extras'], LExpected),
      'GLB extras retain the same complete source derivation');
  finally
    LExpected.Free;
  end;
  Need(ADecoded.FDocument.Arrays['materials'].Count = AEvidence.Arrays['materials'].Count,
    'every admitted source material is retained');
  for I := 0 to AEvidence.Arrays['materials'].Count - 1 do
  begin
    Check(SameJSON(ADecoded.FDocument.Arrays['materials'].Objects[I].Objects['extras'],
      AEvidence.Arrays['materials'].Objects[I]), 'per-material original source parameters');
  end;
end;

function MakeCorner(const AX, AY, AZ, ANX, ANY, ANZ, AU, AV: Double;
  const AHasUV: Boolean): TCorner;
begin
  Result.FPosition := Vector(AX, AY, AZ);
  Result.FNormal := Vector(ANX, ANY, ANZ);
  Result.FUV[0] := AU;
  Result.FUV[1] := AV;
  Result.FHasUV := AHasUV;
end;

function SameCorner(const ALeft, ARight: TCorner): Boolean;
var
  I: Integer;
begin
  Result := ALeft.FHasUV = ARight.FHasUV;
  for I := 0 to 2 do
  begin
    Result := Result and Near(ALeft.FPosition[I], ARight.FPosition[I]) and
      Near(ALeft.FNormal[I], ARight.FNormal[I]);
  end;
  if ALeft.FHasUV then
  begin
    for I := 0 to 1 do
    begin
      Result := Result and Near(ALeft.FUV[I], ARight.FUV[I]);
    end;
  end;
end;

function SameOrientedTriangle(const ALeft, ARight: TTriangle): Boolean;
var
  LMatch: Boolean;
  LRotation: Integer;
  I: Integer;
begin
  Result := False;
  for LRotation := 0 to 2 do
  begin
    LMatch := ALeft.FMaterial = ARight.FMaterial;
    for I := 0 to 2 do
    begin
      LMatch := LMatch and SameCorner(ALeft.FCorners[(I + LRotation) mod 3],
        ARight.FCorners[I]);
    end;
    Result := Result or LMatch;
  end;
end;

procedure MatchTriangles(const AActual, AExpected: TTriangles);
var
  LUsed: array of Boolean;
  LMatch: Boolean;
  LFound: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
  LRotation: Integer;
begin
  Need(Length(AActual) = Length(AExpected), 'exact triangle tuple count');
  SetLength(LUsed, Length(AActual));
  for I := 0 to High(AExpected) do
  begin
    LFound := -1;
    for J := 0 to High(AActual) do
    begin
      for LRotation := 0 to 2 do
      begin
        LMatch := not LUsed[J] and (AActual[J].FMaterial = AExpected[I].FMaterial);
        for K := 0 to 2 do
        begin
          LMatch := LMatch and SameCorner(AActual[J].FCorners[(K + LRotation) mod 3],
            AExpected[I].FCorners[K]);
        end;
        if LMatch then
        begin
          LFound := J;
        end;
      end;
    end;
    Check(LFound >= 0, 'oriented corner tuple with exact material preserved');
    if LFound >= 0 then
    begin
      LUsed[LFound] := True;
    end;
  end;
end;

procedure BasicAndProvenance;
var
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LParameters: TJSONObject;
  LMaterial: TJSONObject;
  LExpected: TTriangles;
  LOBJ: UTF8String;
begin
  LOBJ := 'o Fruit specimen'#10'g skin detail'#10's off'#10 + BasicOBJ;
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(LOBJ, ConventionalMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    CheckEvidence(LDecoded, LEvidence);
    Check(LEvidence.Integers['sourceFaceCount'] = 1, 'source face count retained');
    Need(LEvidence.Arrays['sourceMetadata'].Count = 3, 'three original metadata directives');
    Check(LEvidence.Arrays['sourceMetadata'].Objects[0].Integers['line'] = 1,
      'original metadata line number');
    Check(LEvidence.Arrays['sourceMetadata'].Objects[0].Strings['value'] = 'Fruit specimen',
      'whole original object label');
    Check(LEvidence.Arrays['sourceMetadata'].Objects[1].Strings['directive'] = 'g',
      'group metadata retained');
    Check(LEvidence.Arrays['sourceMetadata'].Objects[2].Strings['value'] = 'off',
      'smoothing metadata retained with explicit normals');
    Need(LEvidence.Arrays['materials'].Count = 1, 'one source material');
    LParameters := LEvidence.Arrays['materials'].Objects[0].Objects['sourceParameters'];
    Check(LParameters.Count = 8, 'only eight actually supplied source parameters');
    Check(Near(LParameters.Floats['Ns'], 250), 'original shininess retained separately');
    Check(Near(LParameters.Floats['Ni'], 1.45), 'original IOR retained separately');
    Check(Near(LParameters.Arrays['Ks'].Floats[2], 0.6), 'original specular retained separately');
    Check(LParameters.Integers['illum'] = 2, 'original illumination retained separately');
    LMaterial := LDecoded.FDocument.Arrays['materials'].Objects[0];
    Check(LMaterial.Get('doubleSided', False), 'declared double-sided adaptation');
    Check(LMaterial.Get('alphaMode', 'OPAQUE') = 'OPAQUE', 'opaque adaptation');
    LMaterial := LMaterial.Objects['pbrMetallicRoughness'];
    Check(Near(LMaterial.Floats['metallicFactor'], 0), 'matte recipe metal zero');
    Check(Near(LMaterial.Floats['roughnessFactor'], 0.72), 'matte recipe roughness');
    Check(Near(LMaterial.Arrays['baseColorFactor'].Floats[0], 0.125), 'Kd red retained linearly');
    Check(Near(LMaterial.Arrays['baseColorFactor'].Floats[2], 0.5), 'Kd blue retained linearly');
    SetLength(LExpected, 1);
    LExpected[0].FMaterial := 'red';
    LExpected[0].FCorners[0] := MakeCorner(0, 0, 0, 0, 0, 1, 0, 0, False);
    LExpected[0].FCorners[1] := MakeCorner(2, 0, 0, 0, 0, 1, 0, 0, False);
    LExpected[0].FCorners[2] := MakeCorner(0, 2, 0, 0, 0, 1, 0, 0, False);
    MatchTriangles(LDecoded.FTriangles, LExpected);
    LParameters := LDecoded.FDocument.Arrays['meshes'].Objects[0].Arrays['primitives'].
      Objects[0].Objects['extras'].Arrays['sourceFaces'].Objects[0];
    Check(LParameters.Integers['line'] = 10, 'emitted face retains original line number');
    Check((LParameters.Integers['firstVertex'] = 0) and
      (LParameters.Integers['vertexCount'] = 3), 'emitted face corner range provenance');
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

procedure SeamAndMaterialOwnership;
const
  COBJ = 'mtllib source.mtl'#10'v 0 0 0'#10'v 2 0 0'#10'v 2 2 0'#10'v 0 2 0'#10+
    'vt 0 0'#10'vt 1 0'#10'vt 1 1'#10'vt 0.25 0.75'#10'vt 0.75 0.25'#10+
    'vt -2 3'#10'vn 0 0 2'#10'vn 0 3 4'#10'usemtl red'#10+
    'f 1/1/1 2/2/1 3/3/1'#10'usemtl blue'#10'f -4/4/2 -2/5/2 -1/6/2'#10;
var
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LExpected: TTriangles;
begin
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(COBJ, BasicMTL + 'newmtl blue'#10'Kd 0.6 0.4 0.2'#10, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    CheckEvidence(LDecoded, LEvidence);
    SetLength(LExpected, 2);
    LExpected[0].FMaterial := 'red';
    LExpected[0].FCorners[0] := MakeCorner(0, 0, 0, 0, 0, 1, 0, 1, True);
    LExpected[0].FCorners[1] := MakeCorner(2, 0, 0, 0, 0, 1, 1, 1, True);
    LExpected[0].FCorners[2] := MakeCorner(2, 2, 0, 0, 0, 1, 1, 0, True);
    LExpected[1].FMaterial := 'blue';
    LExpected[1].FCorners[0] := MakeCorner(0, 0, 0, 0, 0.6, 0.8, 0.25, 0.25, True);
    LExpected[1].FCorners[1] := MakeCorner(2, 2, 0, 0, 0.6, 0.8, 0.75, 0.75, True);
    LExpected[1].FCorners[2] := MakeCorner(0, 2, 0, 0, 0.6, 0.8, -2, -2, True);
    MatchTriangles(LDecoded.FTriangles, LExpected);
    Check(LEvidence.Arrays['materials'].Objects[0].Objects['sourceParameters'].Count = 1,
      'unspecified source material fields are not invented');
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

function SameJSON(const ALeft, ARight: TJSONData): Boolean;
var
  LOther: TJSONData;
  I: Integer;
begin
  Result := (ALeft <> nil) and (ARight <> nil) and (ALeft.JSONType = ARight.JSONType);
  if not Result then
  begin
    Exit;
  end;
  if ALeft.JSONType = jtObject then
  begin
    Result := ALeft.Count = ARight.Count;
    for I := 0 to ALeft.Count - 1 do
    begin
      LOther := TJSONObject(ARight).Find(TJSONObject(ALeft).Names[I]);
      Result := Result and SameJSON(ALeft.Items[I], LOther);
    end;
  end
  else if ALeft.JSONType = jtArray then
  begin
    Result := ALeft.Count = ARight.Count;
    if Result then
    begin
      for I := 0 to ALeft.Count - 1 do
      begin
        Result := Result and SameJSON(ALeft.Items[I], ARight.Items[I]);
      end;
    end;
  end
  else if ALeft.JSONType = jtNumber then
  begin
    Result := ALeft.AsFloat = ARight.AsFloat;
  end
  else
  begin
    Result := ALeft.AsJSON = ARight.AsJSON;
  end;
end;

procedure PolygonProjectedCase(const APoints: TVectors; const APositiveNormal: TVector;
  const ADrop: Integer);
var
  LOBJ: UTF8String;
  LFace: String;
  LArea: Double;
  LTriangleArea: Double;
  LSum: Double;
  LNormal: TVector;
  LAxes: array[0..1] of Integer;
  LIndices: array[0..2] of Integer;
  LEdges: array of array of Integer;
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LMatch: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
  LPoint: Integer;
begin
  LOBJ := 'mtllib source.mtl'#10'usemtl red'#10;
  LFace := 'f';
  LArea := 0;
  J := 0;
  for I := 0 to 2 do
  begin
    if I <> ADrop then
    begin
      LAxes[J] := I;
      Inc(J);
    end;
  end;
  for I := 0 to High(APoints) do
  begin
    LOBJ := LOBJ + Format('v %.9f %.9f %.9f'#10,
      [APoints[I][0], APoints[I][1], APoints[I][2]], GFormat);
    LFace := LFace + ' ' + IntToStr(I + 1) + '//1';
    J := (I + 1) mod Length(APoints);
    LArea := LArea + APoints[I][LAxes[0]] * APoints[J][LAxes[1]] -
      APoints[J][LAxes[0]] * APoints[I][LAxes[1]];
  end;
  LArea := LArea / 2;
  LNormal := APositiveNormal;
  if LArea < 0 then
  begin
    for I := 0 to 2 do
    begin
      LNormal[I] := -LNormal[I];
    end;
  end;
  LOBJ := LOBJ + Format('vn %.9f %.9f %.9f'#10,
    [LNormal[0], LNormal[1], LNormal[2]], GFormat) + LFace + #10;
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(LOBJ, BasicMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    CheckEvidence(LDecoded, LEvidence);
    Check(Length(LDecoded.FTriangles) = Length(APoints) - 2,
      'simple polygon has n-2 triangles');
    Check(LEvidence.Integers['sourceFaceCount'] = 1, 'one original polygon face');
    SetLength(LEdges, Length(APoints), Length(APoints));
    LSum := 0;
    for I := 0 to High(LDecoded.FTriangles) do
    begin
      Check(LDecoded.FTriangles[I].FMaterial = 'red', 'polygon material preserved');
      for J := 0 to 2 do
      begin
        LIndices[J] := -1;
        for LPoint := 0 to High(APoints) do
        begin
          LMatch := True;
          for K := 0 to 2 do
          begin
            LMatch := LMatch and Near(LDecoded.FTriangles[I].FCorners[J].FPosition[K],
              APoints[LPoint][K]);
          end;
          if LMatch then
          begin
            Need(LIndices[J] < 0, 'unambiguous polygon source position');
            LIndices[J] := LPoint;
          end;
        end;
        Need(LIndices[J] >= 0, 'triangulation emits only original corners');
        for K := 0 to 2 do
        begin
          Check(Near(LDecoded.FTriangles[I].FCorners[J].FNormal[K], LNormal[K]),
            'polygon normal preserved');
        end;
      end;
      LTriangleArea := ((APoints[LIndices[1]][LAxes[0]] - APoints[LIndices[0]][LAxes[0]]) *
        (APoints[LIndices[2]][LAxes[1]] - APoints[LIndices[0]][LAxes[1]]) -
        (APoints[LIndices[1]][LAxes[1]] - APoints[LIndices[0]][LAxes[1]]) *
        (APoints[LIndices[2]][LAxes[0]] - APoints[LIndices[0]][LAxes[0]])) / 2;
      Check(LTriangleArea * LArea > 0, 'polygon triangle winding and nonzero area');
      LSum := LSum + LTriangleArea;
      for J := 0 to 2 do
      begin
        K := (J + 1) mod 3;
        Inc(LEdges[LIndices[J]][LIndices[K]]);
        Dec(LEdges[LIndices[K]][LIndices[J]]);
      end;
    end;
    Check(Abs(LSum - LArea) <= 0.00001, 'independent polygon area coverage');
    for I := 0 to High(APoints) do
    begin
      J := (I + 1) mod Length(APoints);
      Check(LEdges[I][J] = 1, 'each original oriented polygon boundary occurs once');
      Dec(LEdges[I][J]);
      Inc(LEdges[J][I]);
    end;
    for I := 0 to High(APoints) do
    begin
      for J := 0 to High(APoints) do
      begin
        Check(LEdges[I][J] = 0, 'all internal polygon edges cancel');
      end;
    end;
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

procedure PolygonCase(const APoints: TVectors);
begin
  PolygonProjectedCase(APoints, Vector(0, 0, 1), 2);
end;

procedure PolygonCoverage;
var
  LPoints: TVectors;
  LReverse: TVectors;
  I: Integer;
begin
  SetLength(LPoints, 6);
  LPoints[0] := Vector(0, 0, 0);
  LPoints[1] := Vector(3, 0, 0);
  LPoints[2] := Vector(3, 1, 0);
  LPoints[3] := Vector(1, 1, 0);
  LPoints[4] := Vector(1, 3, 0);
  LPoints[5] := Vector(0, 3, 0);
  PolygonCase(LPoints);
  SetLength(LReverse, Length(LPoints));
  for I := 0 to High(LPoints) do
  begin
    LReverse[I] := LPoints[High(LPoints) - I];
  end;
  PolygonCase(LReverse);
  SetLength(LPoints, 4);
  LPoints[0] := Vector(999996, 999996, -1000000);
  LPoints[1] := Vector(1000000, 999996, -1000000);
  LPoints[2] := Vector(1000000, 1000000, -1000000);
  LPoints[3] := Vector(999996, 1000000, -1000000);
  PolygonCase(LPoints);
  SetLength(LPoints, 64);
  for I := 0 to High(LPoints) do
  begin
    LPoints[I] := Vector(Cos(I * 2 * Pi / 64) * 3, Sin(I * 2 * Pi / 64) * 3, 0);
  end;
  PolygonCase(LPoints);
  SetLength(LPoints, 5);
  LPoints[0] := Vector(0, 0, 0);
  LPoints[1] := Vector(2, 0, 0);
  LPoints[2] := Vector(4, 0, 0);
  LPoints[3] := Vector(4, 4, 3);
  LPoints[4] := Vector(0, 4, 3);
  PolygonProjectedCase(LPoints, Vector(0, -0.6, 0.8), 2);
  SetLength(LPoints, 4);
  LPoints[0] := Vector(0, 0, 0);
  LPoints[1] := Vector(0, 2, 0);
  LPoints[2] := Vector(0, 2, 3);
  LPoints[3] := Vector(0, 0, 3);
  PolygonProjectedCase(LPoints, Vector(1, 0, 0), 0);
  LPoints[1] := Vector(2, 0, 0);
  LPoints[2] := Vector(2, 0, 3);
  PolygonProjectedCase(LPoints, Vector(0, -1, 0), 1);
end;

procedure MixedUVPresence;
const
  COBJ = 'mtllib source.mtl'#10'usemtl red'#10+
    'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10'vt 0 0'#10'vn 0 0 1'#10+
    'f 1//1 2//1 3//1'#10'f 1/1/1 2/1/1 3/1/1'#10;
var
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LExpected: TTriangles;
  I: Integer;
begin
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(COBJ, BasicMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    CheckEvidence(LDecoded, LEvidence);
    SetLength(LExpected, 2);
    for I := 0 to 1 do
    begin
      LExpected[I].FMaterial := 'red';
      LExpected[I].FCorners[0] := MakeCorner(0, 0, 0, 0, 0, 1, 0, 1, I = 1);
      LExpected[I].FCorners[1] := MakeCorner(2, 0, 0, 0, 0, 1, 0, 1, I = 1);
      LExpected[I].FCorners[2] := MakeCorner(0, 2, 0, 0, 0, 1, 0, 1, I = 1);
    end;
    MatchTriangles(LDecoded.FTriangles, LExpected);
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

procedure MalformedSource;
const
  CBadFaces: array[0..9] of String = (
    'f 0//1 2//1 3//1', 'f 1//1 2//1 4//1', 'f -4//1 -2//1 -1//1',
    'f 1 2 3', 'f 1//1 2//1 3', 'f 1/1/1 2//1 3//1',
    'f 1//2 2//1 3//1', 'f 1//1 1//1 3//1', 'f 1//1 2//1',
    'f 1//1/7 2//1 3//1');
  CBadOBJFields: array[0..9] of String = (
    'l 1 2', 'p 1', 'curv 0 1 1 2 3', 'surf 0 1 0 1 1 2 3',
    'cstype bezier', 'vp 0 0 0', 'v 0 0 0 1 0 0', 'vt 0 0 1',
    'unknown_field 1', 'mtllib source.mtl');
var
  LPrefix: String;
  I: Integer;
begin
  LPrefix := Copy(BasicOBJ, 1, Pos('f 1//1', BasicOBJ) - 1);
  for I := 0 to High(CBadFaces) do
  begin
    Reject('invalid corner form ' + IntToStr(I), LPrefix + CBadFaces[I] + #10, BasicMTL);
  end;
  for I := 0 to High(CBadOBJFields) do
  begin
    Reject('unsupported OBJ token ' + IntToStr(I), BasicOBJ + CBadOBJFields[I] + #10, BasicMTL);
  end;
  Reject('missing material reference',
    StringReplace(BasicOBJ, 'source.mtl', 'other.mtl', []), BasicMTL);
  Reject('undeclared material', StringReplace(BasicOBJ, 'usemtl red', 'usemtl blue', []), BasicMTL);
  Reject('absent mtllib', StringReplace(BasicOBJ, 'mtllib source.mtl'#10, '', []), BasicMTL);
  Reject('empty OBJ', '', BasicMTL);
  Reject('empty MTL', BasicOBJ, '');
  Reject('OBJ control byte', BasicOBJ + #0, BasicMTL);
  Reject('OBJ non-ASCII byte', BasicOBJ + '# ' + #$C3#$A9 + #10, BasicMTL);
  Reject('source traversal', BasicOBJ, BasicMTL, '../source.obj');
  Reject('source backslash traversal', BasicOBJ, BasicMTL, '..\source.obj');
  Reject('source absolute path', BasicOBJ, BasicMTL, '/source.obj');
  Reject('source network URI', BasicOBJ, BasicMTL, 'https://example.invalid/source.obj');
  Reject('source wrong extension', BasicOBJ, BasicMTL, 'source.fbx');
  Reject('material traversal', BasicOBJ, BasicMTL, 'source.obj', '../source.mtl');
end;

procedure MaterialRejections;
const
  CBadFields: array[0..19] of String = (
    'map_Kd diffuse.png', 'map_d alpha.png', 'bump normal.png', 'map_bump normal.png',
    'Pr 0.5', 'Pm 0.2', 'Tr 0', 'Tf 0 0 0', 'sharpness 60', 'unknown 0',
    'd 0.99', 'illum 0', 'illum 3', 'Ns -1', 'Ns 1001', 'Ni 0.99',
    'Ni 2.51', 'Ks 1.01 0 0', 'Ka -0.1 0 0', 'Ke 0.001 0 0');
  CBadColors: array[0..5] of String = (
    'Kd -0.01 0 0', 'Kd 1.01 0 0', 'Kd nan 0 0', 'Kd inf 0 0',
    'Kd spectral source.rfl', 'Kd xyz 0.1 0.2 0.3');
var
  I: Integer;
begin
  for I := 0 to High(CBadFields) do
  begin
    Reject('forbidden MTL field ' + IntToStr(I), BasicOBJ, BasicMTL + CBadFields[I] + #10);
  end;
  for I := 0 to High(CBadColors) do
  begin
    Reject('invalid source color ' + IntToStr(I), BasicOBJ, 'newmtl red'#10 + CBadColors[I] + #10);
  end;
  Reject('material missing Kd', BasicOBJ, 'newmtl red'#10'Ns 10'#10);
  Reject('duplicate Kd', BasicOBJ, BasicMTL + 'Kd 0.125 0.25 0.5'#10);
  Reject('duplicate newmtl', BasicOBJ, BasicMTL + BasicMTL);
  Reject('duplicate conventional parameter', BasicOBJ, ConventionalMTL + 'Ns 250'#10);
  Reject('extra color component', BasicOBJ, 'newmtl red'#10'Kd 0 0 0 1'#10);
  Reject('fractional illumination code', BasicOBJ, BasicMTL + 'illum 1.5'#10);
  Reject('embedded MTL NUL', BasicOBJ, BasicMTL + #0);
end;

procedure GeometryRejections;
const
  CPrefix = 'mtllib source.mtl'#10'usemtl red'#10'vn 0 0 1'#10;
var
  LOBJ: UTF8String;
  LFace: String;
  I: Integer;
begin
  Reject('collinear face', CPrefix + 'v 0 0 0'#10'v 1 0 0'#10'v 2 0 0'#10+
    'f 1//1 2//1 3//1'#10, BasicMTL);
  Reject('bow tie polygon', CPrefix + 'v 0 0 0'#10'v 2 2 0'#10'v 0 2 0'#10+
    'v 2 0 0'#10'f 1//1 2//1 3//1 4//1'#10, BasicMTL);
  Reject('nonplanar polygon', CPrefix + 'v 0 0 0'#10'v 2 0 0'#10'v 2 2 0.1'#10+
    'v 0 2 0'#10'f 1//1 2//1 3//1 4//1'#10, BasicMTL);
  Reject('position beyond bound',
    StringReplace(BasicOBJ, 'v 2 0 0', 'v 1000001 0 0', []), BasicMTL);
  Reject('NaN position', StringReplace(BasicOBJ, 'v 2 0 0', 'v nan 0 0', []), BasicMTL);
  Reject('infinite position', StringReplace(BasicOBJ, 'v 2 0 0', 'v 1e9999 0 0', []), BasicMTL);
  Reject('zero normal', StringReplace(BasicOBJ, 'vn 0 0 1', 'vn 0 0 0', []), BasicMTL);
  Reject('normal below length bound',
    StringReplace(BasicOBJ, 'vn 0 0 1', 'vn 0 0 1e-13', []), BasicMTL);
  Reject('normal beyond component bound',
    StringReplace(BasicOBJ, 'vn 0 0 1', 'vn 0 0 1000001', []), BasicMTL);
  Reject('UV beyond bound', CPrefix + 'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10+
    'vt 65537 0'#10'f 1/1/1 2/1/1 3/1/1'#10, BasicMTL);
  Reject('NaN UV', CPrefix + 'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10+
    'vt nan 0'#10'f 1/1/1 2/1/1 3/1/1'#10, BasicMTL);
  LOBJ := CPrefix;
  LFace := 'f';
  for I := 0 to 64 do
  begin
    LOBJ := LOBJ + Format('v %.9f %.9f 0'#10,
      [Cos(I * 2 * Pi / 65), Sin(I * 2 * Pi / 65)], GFormat);
    LFace := LFace + ' ' + IntToStr(I + 1) + '//1';
  end;
  Reject('65-corner polygon exceeds bound', LOBJ + LFace + #10, BasicMTL);
end;

procedure WorkAndTextBounds;
var
  LText: UTF8String;
  LLines: TStringList;
  I: Integer;
begin
  Reject('oversized comment line', BasicOBJ + '#' + StringOfChar('x', 4096) + #10, BasicMTL);
  LLines := TStringList.Create;
  try
    for I := 0 to 200000 do
    begin
      LLines.Add('v 0 0 0');
    end;
    Reject('200001 positions exceed bound', BasicOBJ + LLines.Text, BasicMTL);
    LLines.Clear;
    for I := 0 to 256 do
    begin
      LLines.Add('newmtl material-' + IntToStr(I));
      LLines.Add('Kd 0.1 0.2 0.3');
    end;
    Reject('257 materials exceed bound', BasicOBJ, LLines.Text);
    LLines.Clear;
    for I := 0 to 100000 do
    begin
      LLines.Add('f 1//1 2//1 3//1');
    end;
    LText := Copy(BasicOBJ, 1, Pos('f 1//1', BasicOBJ) - 1) + LLines.Text;
    Reject('100001 faces exceed bound', LText, BasicMTL);
  finally
    LLines.Free;
  end;
  LText := StringOfChar(' ', 32 * 1024 * 1024 + 1);
  Reject('OBJ above 32 MiB', LText, BasicMTL);
  Reject('MTL above 32 MiB', BasicOBJ, LText);
end;

procedure DeterminismAndPureBytes;
var
  LFirst: TBytes;
  LSecond: TBytes;
  LFirstEvidence: TJSONObject;
  LSecondEvidence: TJSONObject;
  LOldDirectory: String;
  LOldDecimal: Char;
  LOldRandSeed: LongInt;
  LDirectory: String;
begin
  LFirstEvidence := nil;
  LSecondEvidence := nil;
  LOldDirectory := GetCurrentDir;
  LOldDecimal := DefaultFormatSettings.DecimalSeparator;
  LOldRandSeed := RandSeed;
  try
    LFirst := Convert(BasicOBJ, ConventionalMTL, LFirstEvidence);
    LDirectory := SafeChild(GScratch, 'different-working-directory');
    ForceDirectories(LDirectory);
    WriteText(SafeChild(LDirectory, 'source.obj'), 'These disk bytes must never be read.');
    WriteText(SafeChild(LDirectory, 'source.mtl'), 'Invalid disk material must never be read.');
    Need(SetCurrentDir(LDirectory), 'change fixture working directory');
    DefaultFormatSettings.DecimalSeparator := ',';
    RandSeed := 314159;
    LSecond := Convert(BasicOBJ, ConventionalMTL, LSecondEvidence);
    Check(HashBytes(LFirst) = HashBytes(LSecond),
      'same input yields exact GLB under changed cwd/locale/seed');
    Check(SameJSON(LFirstEvidence, LSecondEvidence),
      'same input yields identical derivation evidence');
    WriteBytes(SafeChild(GScratch, 'basic.glb'), LFirst);
    WriteText(SafeChild(GScratch, 'basic-derivation.json'), LFirstEvidence.FormatJSON);
  finally
    RandSeed := LOldRandSeed;
    DefaultFormatSettings.DecimalSeparator := LOldDecimal;
    SetCurrentDir(LOldDirectory);
    LSecondEvidence.Free;
    LFirstEvidence.Free;
  end;
end;

procedure OracleCorruptionControls;
const
  COBJ = 'mtllib source.mtl'#10'usemtl red'#10+
    'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10'vt 0 0'#10'vn 0 0 1'#10+
    'f 1/1/1 2/1/1 3/1/1'#10;
var
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  LExpected: TTriangle;
  LChanged: TTriangle;
begin
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(COBJ, BasicMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    Need(Length(LDecoded.FTriangles) = 1, 'one oracle control triangle');
    LExpected.FMaterial := 'red';
    LExpected.FCorners[0] := MakeCorner(0, 0, 0, 0, 0, 1, 0, 1, True);
    LExpected.FCorners[1] := MakeCorner(2, 0, 0, 0, 0, 1, 0, 1, True);
    LExpected.FCorners[2] := MakeCorner(0, 2, 0, 0, 0, 1, 0, 1, True);
    Check(SameOrientedTriangle(LDecoded.FTriangles[0], LExpected),
      'uncorrupted direct tuple oracle accepts');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FCorners[0].FPosition[0] := LChanged.FCorners[0].FPosition[0] + 0.125;
    Check(not SameOrientedTriangle(LChanged, LExpected), 'position corruption detected');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FCorners[0].FNormal[0] := 0.5;
    Check(not SameOrientedTriangle(LChanged, LExpected), 'normal corruption detected');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FCorners[0].FUV[1] := 0;
    Check(not SameOrientedTriangle(LChanged, LExpected), 'missing V flip detected');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FCorners[0].FHasUV := False;
    Check(not SameOrientedTriangle(LChanged, LExpected), 'lost UV presence detected');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FMaterial := 'blue';
    Check(not SameOrientedTriangle(LChanged, LExpected), 'material reassignment detected');
    LChanged := LDecoded.FTriangles[0];
    LChanged.FCorners[0] := LDecoded.FTriangles[0].FCorners[1];
    LChanged.FCorners[1] := LDecoded.FTriangles[0].FCorners[0];
    Check(not SameOrientedTriangle(LChanged, LExpected), 'reversed winding detected');
    Check(SameOrientedTriangle(LDecoded.FTriangles[0], LExpected),
      'oracle mutation controls preserve original decoded sample');
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

procedure LegalBoundaries;
var
  LOBJ: UTF8String;
  LMTL: UTF8String;
  LOutput: TBytes;
  LEvidence: TJSONObject;
  LDecoded: TDecodedGLB;
  I: Integer;
begin
  LOBJ := StringReplace(BasicOBJ, 'vn 0 0 1', 'vn 0 0 0.000000000002', []);
  LOBJ := StringReplace(LOBJ, #10, #13#10, [rfReplaceAll]);
  LOBJ := LOBJ + '#' + StringOfChar('x', 4095) + #13#10;
  LMTL := BasicMTL + 'Ns 1000'#10'Ni 2.5'#10'illum 1'#10;
  for I := 1 to 255 do
  begin
    LMTL := LMTL + 'newmtl unused-' + IntToStr(I) + #10'Kd 0.2 0.3 0.4'#10;
  end;
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(LOBJ, LMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    CheckEvidence(LDecoded, LEvidence);
    Check(LEvidence.Arrays['materials'].Count = 256, '256 material boundary accepted');
    Check(Near(LDecoded.FTriangles[0].FCorners[0].FNormal[2], 1),
      'small admitted normal normalized');
    Check(Length(LDecoded.FTriangles) = 1, 'CRLF and exact 4096-byte comment accepted');
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
  LOBJ := 'mtllib source.mtl'#10'usemtl red'#10'v 0 0 0'#10'v 2 0 0'#10+
    'v 0 2 0'#10'vn 0 0 1'#10'vt -65536 65536'#10'f 1/1/1 2/1/1 3/1/1'#10;
  LEvidence := nil;
  LDecoded := nil;
  try
    LOutput := Convert(LOBJ, BasicMTL, LEvidence);
    LDecoded := TDecodedGLB.Create(LOutput);
    Check(Near(LDecoded.FTriangles[0].FCorners[0].FUV[0], -65536),
      'negative UV boundary retained');
    Check(Near(LDecoded.FTriangles[0].FCorners[0].FUV[1], -65535),
      'positive UV boundary flipped once');
  finally
    LDecoded.Free;
    LEvidence.Free;
  end;
end;

procedure RunCase(const AName: String; const AProcedure: TCaseProcedure);
var
  LBefore: Integer;
begin
  GCase := AName;
  LBefore := GFailures;
  try
    AProcedure;
  except
    on LException: Exception do
    begin
      Check(False, 'unexpected exception: ' + LException.ClassName + ': ' + LException.Message);
    end;
  end;
  if GFailures = LBefore then
  begin
    WriteLn('PASS ', AName);
  end;
end;

procedure Run;
var
  LRoot: String;
  LGuid: TGUID;
  LReport: TJSONObject;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root [scratch root]');
  LRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(LRoot, 'build/tests/obj-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture ID');
  GScratch := SafeChild(GScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Fixture directory must be new');
  ForceDirectories(GScratch);
  GFormat := DefaultFormatSettings;
  GFormat.DecimalSeparator := '.';
  GFailureMessages := TJSONArray.Create;
  LReport := nil;
  try
    RunCase('basic source and adaptation provenance', BasicAndProvenance);
    RunCase('independent seam and material oracle', SeamAndMaterialOwnership);
    RunCase('polygon geometry and source boundaries', PolygonCoverage);
    RunCase('UV absence versus explicit zero', MixedUVPresence);
    RunCase('malformed source and path rejection', MalformedSource);
    RunCase('material feature rejection', MaterialRejections);
    RunCase('geometry and numeric rejection', GeometryRejections);
    RunCase('bounded work and text', WorkAndTextBounds);
    RunCase('deterministic pure byte conversion', DeterminismAndPureBytes);
    RunCase('oracle corruption controls', OracleCorruptionControls);
    RunCase('legal source boundaries', LegalBoundaries);
    LReport := TJSONObject.Create(['checks', GChecks, 'failures', GFailures,
      'scratch', GScratch, 'recipe', 'phanes.obj.matte.v1']);
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
