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

unit phanes.tools.obj;

{$mode delphi}
{$H+}

interface

uses
  SysUtils,
  FPJSON;

const
  StaticOBJRecipe = 'phanes.obj.matte.v1';
  SurfaceOBJRecipe = 'phanes.obj.surface.v1';
  StaticOBJInputLimit = 32 * 1024 * 1024;
  StaticOBJOutputLimit = 32 * 1024 * 1024;
  StaticOBJChannelLimit = 200000;
  StaticOBJFaceLimit = 100000;
  StaticOBJPolygonLimit = 64;
  StaticOBJCornerLimit = 600000;
  StaticOBJTriangleLimit = 200000;
  StaticOBJMaterialLimit = 256;

{ Pure source-byte conversion. No filesystem or texture search is performed.
  The result preserves static corner geometry with normalized normals, but
  deliberately adapts opaque Phong materials to the named Phanes matte recipe.
  The source coordinate system has no inferred metre/up-axis assignment.
  The caller owns the returned evidence. On failure it is always nil. }
function ConvertStaticOBJ(const ASourceName, AMaterialName: String;
  const AOBJBytes, AMTLBytes: TBytes; out AEvidence: TJSONObject): TBytes;

{ Explicit topology adaptation for simple nonplanar source polygons. Original
  XYZ is retained; a named projected triangulation supplies the otherwise
  unspecified interior surface. This is not source-rendering equivalence. }
function ConvertSurfaceOBJ(const ASourceName, AMaterialName: String;
  const AOBJBytes, AMTLBytes: TBytes; out AEvidence: TJSONObject): TBytes;

implementation

uses
  Classes,
  Math,
  phanes.tools.files;

type
  TVector = array[0..2] of Double;
  TVectors = array of TVector;
  TPoint = array[0..1] of Double;
  TPoints = array of TPoint;
  TIndices = array of Integer;

  TCorner = record
    FPosition: Integer;
    FNormal: Integer;
    FUV: Integer;
  end;
  TCorners = array of TCorner;

  TFace = record
    FCorners: TCorners;
    FTriangles: TIndices;
    FMaterial: Integer;
    FLine: Integer;
    FPlaneDeviationRatio: Double;
  end;
  TFaces = array of TFace;

  TConverter = class
  private
    FMaterials: TJSONArray;
    FNames: TStringList;
    FMetadata: TJSONArray;
    FPositions: TVectors;
    FNormals: TVectors;
    FUVs: TVectors;
    FFaces: TFaces;
    FPositionCount: Integer;
    FNormalCount: Integer;
    FUVCount: Integer;
    FFaceCount: Integer;
    FCornerCount: Integer;
    FTriangleCount: Integer;
    FFormat: TFormatSettings;
    FMaterialName: String;
    FAdaptSurface: Boolean;
    FRecipe: String;
    function Number(const AText: String; const AMaximum: Double): Double;
    function IntegerValue(const AText: String): Integer;
    function IndexValue(const AText: String; const ACount: Integer): Integer;
    function Lines(const ABytes: TBytes): TStringList;
    function Words(const ALine: String; const AWords: TStringList): String;
    procedure ParseMaterial(const ABytes: TBytes);
    procedure ParseObject(const ABytes: TBytes);
    procedure AddVector(var AValues: TVectors; var ACount: Integer;
      const AValue: TVector);
    function ReadCorner(const AToken: String): TCorner;
    procedure Triangulate(var AFace: TFace);
    function BuildGLB(const AEvidence: TJSONObject): TBytes;
  public
    constructor Create(const AMaterialName: String; const AAdaptSurface: Boolean);
    destructor Destroy; override;
    function Run(const ASourceName: String; const AOBJBytes, AMTLBytes: TBytes;
      out AEvidence: TJSONObject): TBytes;
  end;

procedure CheckName(const AName, AExtension: String);
var
  I: Integer;
begin
  Require((Length(AName) > Length(AExtension)) and (Length(AName) <= 240) and
    (Trim(AName) = AName) and (AName[Length(AName)] <> '.') and
    (LowerCase(ExtractFileExt(AName)) = AExtension), 'Expected source basename');
  for I := 1 to Length(AName) do
  begin
    Require((Ord(AName[I]) >= 32) and (Ord(AName[I]) <= 126) and
      not (AName[I] in ['/', '\', ':', '<', '>', '"', '|', '?', '*']),
      'Invalid source basename');
  end;
end;

constructor TConverter.Create(const AMaterialName: String; const AAdaptSurface: Boolean);
begin
  inherited Create;
  FMaterialName := AMaterialName;
  FAdaptSurface := AAdaptSurface;
  if FAdaptSurface then
  begin
    FRecipe := SurfaceOBJRecipe;
  end else
  begin
    FRecipe := StaticOBJRecipe;
  end;
  FMaterials := TJSONArray.Create;
  FMetadata := TJSONArray.Create;
  FNames := TStringList.Create;
  FNames.CaseSensitive := True;
  FNames.UseLocale := False;
  FFormat := DefaultFormatSettings;
  FFormat.DecimalSeparator := '.';
  FFormat.ThousandSeparator := #0;
end;

destructor TConverter.Destroy;
begin
  FNames.Free;
  FMetadata.Free;
  FMaterials.Free;
  inherited Destroy;
end;

function TConverter.Number(const AText: String; const AMaximum: Double): Double;
var
  I: Integer;
  LSingle: Single;
begin
  Require((AText <> '') and (Length(AText) <= 80), 'Invalid numeric token length');
  for I := 1 to Length(AText) do
  begin
    Require(AText[I] in ['0'..'9', '+', '-', '.', 'e', 'E'], 'Invalid numeric token');
  end;
  Require(TryStrToFloat(AText, Result, FFormat) and not IsNan(Result) and
    not IsInfinite(Result) and (Abs(Result) <= AMaximum), 'Number outside finite bounds');
  LSingle := Result;
  Require(not IsNan(LSingle) and not IsInfinite(LSingle), 'Number cannot be float32');
end;

function TConverter.IntegerValue(const AText: String): Integer;
var
  I: Integer;
  LValue: Int64;
begin
  Require((AText <> '') and (Length(AText) <= 12), 'Invalid integer token');
  for I := 1 to Length(AText) do
  begin
    Require((AText[I] in ['0'..'9']) or ((I = 1) and (AText[I] in ['-', '+'])),
      'Expected decimal integer');
  end;
  Require(TryStrToInt64(AText, LValue) and (LValue >= Low(Integer)) and
    (LValue <= High(Integer)), 'Integer outside bounds');
  Result := LValue;
end;

function TConverter.IndexValue(const AText: String; const ACount: Integer): Integer;
var
  LValue: Integer;
begin
  LValue := IntegerValue(AText);
  Require(LValue <> 0, 'OBJ indices cannot be zero');
  if LValue > 0 then
  begin
    Require(LValue <= ACount, 'Forward or out-of-range OBJ index');
    Result := LValue - 1;
  end else
  begin
    Require(Int64(LValue) >= -Int64(ACount), 'Relative OBJ index outside current channel');
    Result := ACount + LValue;
  end;
end;

function TConverter.Lines(const ABytes: TBytes): TStringList;
var
  LText: String;
  LLineLength: Integer;
  LLineCount: Integer;
  I: Integer;
begin
  Require((Length(ABytes) > 0) and (Length(ABytes) <= StaticOBJInputLimit),
    'OBJ/MTL input exceeds byte budget or is empty');
  LLineLength := 0;
  LLineCount := 1;
  for I := 0 to High(ABytes) do
  begin
    Require((ABytes[I] in [9, 10, 13]) or
      ((ABytes[I] >= 32) and (ABytes[I] <= 126)), 'Only ASCII OBJ/MTL source is admitted');
    if ABytes[I] in [10, 13] then
    begin
      LLineLength := 0;
      Inc(LLineCount);
      Require(LLineCount <= 2000000, 'Source line count exceeds budget');
    end else
    begin
      Inc(LLineLength);
      Require(LLineLength <= 4096, 'Source line exceeds 4096 bytes');
    end;
  end;
  SetString(LText, PAnsiChar(@ABytes[0]), Length(ABytes));
  Result := TStringList.Create;
  Result.Text := LText;
end;

function TConverter.Words(const ALine: String; const AWords: TStringList): String;
var
  LLine: String;
  LComment: Integer;
begin
  LLine := ALine;
  LComment := Pos('#', LLine);
  if LComment > 0 then
  begin
    SetLength(LLine, LComment - 1);
  end;
  LLine := Trim(LLine);
  AWords.Clear;
  ExtractStrings([' ', #9], [], PChar(LLine), AWords);
  if AWords.Count = 0 then
  begin
    Exit('');
  end;
  Result := Trim(Copy(LLine, Length(AWords[0]) + 1, MaxInt));
end;

procedure TConverter.ParseMaterial(const ABytes: TBytes);
var
  LLines: TStringList;
  LWords: TStringList;
  LValue: String;
  LToken: String;
  LParameters: TJSONObject;
  LArray: TJSONArray;
  LNumber: Double;
  LInteger: Integer;
  I: Integer;
  J: Integer;
begin
  LLines := Lines(ABytes);
  LWords := TStringList.Create;
  LParameters := nil;
  try
    for I := 0 to LLines.Count - 1 do
    begin
      LValue := Words(LLines[I], LWords);
      if LWords.Count = 0 then
      begin
        Continue;
      end;
      LToken := LWords[0];
      if LToken = 'newmtl' then
      begin
        Require((LValue <> '') and (Length(LValue) <= 240), 'Invalid material name');
        Require(FNames.IndexOf(LValue) < 0, 'Duplicate material name');
        Require(FNames.Count < StaticOBJMaterialLimit, 'Material count exceeds budget');
        if LParameters <> nil then
        begin
          Require(LParameters.Find('Kd') <> nil, 'Every material needs explicit Kd');
        end;
        FNames.Add(LValue);
        LParameters := TJSONObject.Create;
        FMaterials.Add(TJSONObject.Create(['name', LValue, 'sourceParameters', LParameters]));
        Continue;
      end;
      Require(LParameters <> nil, 'Material field before newmtl');
      Require(LParameters.Find(LToken) = nil, 'Duplicate material field: ' + LToken);
      if (LToken = 'Ka') or (LToken = 'Kd') or (LToken = 'Ks') or (LToken = 'Ke') then
      begin
        Require(LWords.Count = 4, 'Expected material RGB triplet');
        LArray := TJSONArray.Create;
        LParameters.Add(LToken, LArray);
        for J := 1 to 3 do
        begin
          LNumber := Number(LWords[J], 1);
          Require(LNumber >= 0, 'Negative material color');
          if LToken = 'Ke' then
          begin
            Require(LNumber = 0, 'Emissive material needs another recipe');
          end;
          LArray.Add(LNumber);
        end;
      end else
      if (LToken = 'Ns') or (LToken = 'Ni') or (LToken = 'd') then
      begin
        Require(LWords.Count = 2, 'Expected material scalar');
        LNumber := Number(LValue, 1000);
        Require(LNumber >= 0, 'Negative material scalar');
        if LToken = 'Ni' then
        begin
          Require((LNumber >= 1) and (LNumber <= 2.5), 'IOR outside admitted source range');
        end;
        if LToken = 'd' then
        begin
          Require(LNumber = 1, 'Transparent material needs another recipe');
        end;
        LParameters.Add(LToken, LNumber);
      end else
      if LToken = 'illum' then
      begin
        Require(LWords.Count = 2, 'Expected illumination integer');
        LInteger := IntegerValue(LValue);
        Require((LInteger = 1) or (LInteger = 2), 'Unsupported illumination model');
        LParameters.Add(LToken, LInteger);
      end else
      begin
        raise Exception.Create('Unsupported MTL field: ' + LToken);
      end;
    end;
    Require(LParameters <> nil, 'No material definitions');
    Require(LParameters.Find('Kd') <> nil, 'Every material needs explicit Kd');
  finally
    LWords.Free;
    LLines.Free;
  end;
end;

procedure TConverter.AddVector(var AValues: TVectors; var ACount: Integer;
  const AValue: TVector);
var
  LCapacity: Integer;
  LSingle: Single;
  I: Integer;
begin
  Require(ACount < StaticOBJChannelLimit, 'OBJ channel exceeds record budget');
  if ACount = Length(AValues) then
  begin
    LCapacity := Min(StaticOBJChannelLimit, Max(256, ACount * 2));
    SetLength(AValues, LCapacity);
  end;
  for I := 0 to 2 do
  begin
    { Validate topology in the representation that the GLB will actually store. }
    LSingle := AValue[I];
    AValues[ACount][I] := LSingle;
  end;
  Inc(ACount);
end;

function TConverter.ReadCorner(const AToken: String): TCorner;
var
  LFirst: Integer;
  LSecond: Integer;
  I: Integer;
begin
  LFirst := 0;
  LSecond := 0;
  for I := 1 to Length(AToken) do
  begin
    if AToken[I] = '/' then
    begin
      if LFirst = 0 then
      begin
        LFirst := I;
      end else
      begin
        Require(LSecond = 0, 'Too many corner index channels');
        LSecond := I;
      end;
    end;
  end;
  Require((LFirst > 1) and (LSecond > LFirst) and (LSecond < Length(AToken)),
    'Every face corner requires an explicit normal');
  Result.FPosition := IndexValue(Copy(AToken, 1, LFirst - 1), FPositionCount);
  Result.FNormal := IndexValue(Copy(AToken, LSecond + 1, MaxInt), FNormalCount);
  if LSecond = LFirst + 1 then
  begin
    Result.FUV := -1;
  end else
  begin
    Result.FUV := IndexValue(Copy(AToken, LFirst + 1, LSecond - LFirst - 1), FUVCount);
  end;
end;

function Cross2(const AFirst, ASecond, AThird: TPoint): Double;
begin
  Result := (ASecond[0] - AFirst[0]) * (AThird[1] - AFirst[1]) -
    (ASecond[1] - AFirst[1]) * (AThird[0] - AFirst[0]);
end;

function OnSegment(const AFirst, ASecond, APoint: TPoint;
  const AAreaEpsilon, ALengthEpsilon: Double): Boolean;
begin
  Result := (Abs(Cross2(AFirst, ASecond, APoint)) <= AAreaEpsilon) and
    (APoint[0] >= Min(AFirst[0], ASecond[0]) - ALengthEpsilon) and
    (APoint[0] <= Max(AFirst[0], ASecond[0]) + ALengthEpsilon) and
    (APoint[1] >= Min(AFirst[1], ASecond[1]) - ALengthEpsilon) and
    (APoint[1] <= Max(AFirst[1], ASecond[1]) + ALengthEpsilon);
end;

function Intersects(const AFirst, ASecond, AThird, AFourth: TPoint;
  const AAreaEpsilon, ALengthEpsilon: Double): Boolean;
var
  LFirst: Double;
  LSecond: Double;
  LThird: Double;
  LFourth: Double;
begin
  LFirst := Cross2(AFirst, ASecond, AThird);
  LSecond := Cross2(AFirst, ASecond, AFourth);
  LThird := Cross2(AThird, AFourth, AFirst);
  LFourth := Cross2(AThird, AFourth, ASecond);
  Result := (((LFirst > AAreaEpsilon) and (LSecond < -AAreaEpsilon)) or
    ((LFirst < -AAreaEpsilon) and (LSecond > AAreaEpsilon))) and
    (((LThird > AAreaEpsilon) and (LFourth < -AAreaEpsilon)) or
    ((LThird < -AAreaEpsilon) and (LFourth > AAreaEpsilon)));
  Result := Result or OnSegment(AFirst, ASecond, AThird, AAreaEpsilon, ALengthEpsilon) or
    OnSegment(AFirst, ASecond, AFourth, AAreaEpsilon, ALengthEpsilon) or
    OnSegment(AThird, AFourth, AFirst, AAreaEpsilon, ALengthEpsilon) or
    OnSegment(AThird, AFourth, ASecond, AAreaEpsilon, ALengthEpsilon);
end;

procedure TConverter.Triangulate(var AFace: TFace);
var
  LPoints: TPoints;
  LRemaining: TIndices;
  LMinimum: TVector;
  LMaximum: TVector;
  LNormal: TVector;
  LOrigin: TVector;
  LFirst: TVector;
  LSecond: TVector;
  LThird: TVector;
  LTriangleNormal: TVector;
  LSpan: Double;
  LLength: Double;
  LDistance: Double;
  LAreaEpsilon: Double;
  LLengthEpsilon: Double;
  LArea: Double;
  LSign: Double;
  LTriangleArea: Double;
  LTotalArea: Double;
  LCount: Integer;
  LDrop: Integer;
  LAxis: Integer;
  LPrevious: Integer;
  LCurrent: Integer;
  LNext: Integer;
  LOther: Integer;
  LRemainingCount: Integer;
  LWritten: Integer;
  LEar: Boolean;
  LFound: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LCount := Length(AFace.FCorners);
  AFace.FPlaneDeviationRatio := 0;
  Require((LCount >= 3) and (LCount <= StaticOBJPolygonLimit), 'Polygon corner budget');
  LOrigin := FPositions[AFace.FCorners[0].FPosition];
  LMinimum := LOrigin;
  LMaximum := LOrigin;
  FillChar(LNormal, SizeOf(LNormal), 0);
  for I := 0 to LCount - 1 do
  begin
    LFirst := FPositions[AFace.FCorners[I].FPosition];
    LSecond := FPositions[AFace.FCorners[(I + 1) mod LCount].FPosition];
    for J := 0 to 2 do
    begin
      LMinimum[J] := Min(LMinimum[J], LFirst[J]);
      LMaximum[J] := Max(LMaximum[J], LFirst[J]);
      LFirst[J] := LFirst[J] - LOrigin[J];
      LSecond[J] := LSecond[J] - LOrigin[J];
    end;
    LNormal[0] := LNormal[0] + LFirst[1] * LSecond[2] - LFirst[2] * LSecond[1];
    LNormal[1] := LNormal[1] + LFirst[2] * LSecond[0] - LFirst[0] * LSecond[2];
    LNormal[2] := LNormal[2] + LFirst[0] * LSecond[1] - LFirst[1] * LSecond[0];
  end;
  LSpan := Max(LMaximum[0] - LMinimum[0],
    Max(LMaximum[1] - LMinimum[1], LMaximum[2] - LMinimum[2]));
  Require(LSpan > 0, 'Zero-sized polygon');
  { Tolerances are relative to this polygon after float32 representation.
    Plane distance permits 1e-5 of its extent; projected edge/area predicates
    use 1e-9 / 1e-12. They are part of recipe v1, not adaptive retry knobs. }
  LLengthEpsilon := LSpan * 1e-9;
  LAreaEpsilon := Sqr(LSpan) * 1e-12;
  LLength := Sqrt(Sqr(LNormal[0]) + Sqr(LNormal[1]) + Sqr(LNormal[2]));
  Require(LLength > LAreaEpsilon, 'Degenerate or self-cancelling polygon');
  LDrop := 0;
  for I := 1 to 2 do
  begin
    if Abs(LNormal[I]) > Abs(LNormal[LDrop]) then
    begin
      LDrop := I;
    end;
  end;
  SetLength(LPoints, LCount);
  for I := 0 to LCount - 1 do
  begin
    LFirst := FPositions[AFace.FCorners[I].FPosition];
    LDistance := 0;
    LAxis := 0;
    for J := 0 to 2 do
    begin
      LDistance := LDistance + (LFirst[J] - LOrigin[J]) * LNormal[J] / LLength;
      if J <> LDrop then
      begin
        LPoints[I][LAxis] := LFirst[J] - LOrigin[J];
        Inc(LAxis);
      end;
    end;
    AFace.FPlaneDeviationRatio := Max(AFace.FPlaneDeviationRatio, Abs(LDistance) / LSpan);
    if not FAdaptSurface then
    begin
      Require(Abs(LDistance) <= LSpan * 1e-5,
        'Nonplanar polygon needs another recipe at source line ' + IntToStr(AFace.FLine));
    end;
  end;
  LArea := 0;
  for I := 0 to LCount - 1 do
  begin
    LNext := (I + 1) mod LCount;
    LArea := LArea + LPoints[I][0] * LPoints[LNext][1] -
      LPoints[I][1] * LPoints[LNext][0];
    for J := I + 1 to LCount - 1 do
    begin
      Require((Abs(LPoints[I][0] - LPoints[J][0]) > LLengthEpsilon) or
        (Abs(LPoints[I][1] - LPoints[J][1]) > LLengthEpsilon), 'Repeated polygon corner');
      K := (J + 1) mod LCount;
      if (LNext <> J) and (K <> I) then
      begin
        Require(not Intersects(LPoints[I], LPoints[LNext], LPoints[J], LPoints[K],
          LAreaEpsilon, LLengthEpsilon), 'Self-intersecting polygon');
      end;
    end;
  end;
  Require(Abs(LArea) > LAreaEpsilon, 'Zero-area projected polygon');
  if LArea > 0 then
  begin
    LSign := 1;
  end else
  begin
    LSign := -1;
  end;
  SetLength(LRemaining, LCount);
  SetLength(AFace.FTriangles, (LCount - 2) * 3);
  for I := 0 to LCount - 1 do
  begin
    LRemaining[I] := I;
  end;
  LRemainingCount := LCount;
  LWritten := 0;
  LTotalArea := 0;
  while LRemainingCount > 3 do
  begin
    LFound := False;
    for I := 0 to LRemainingCount - 1 do
    begin
      LPrevious := LRemaining[(I + LRemainingCount - 1) mod LRemainingCount];
      LCurrent := LRemaining[I];
      LNext := LRemaining[(I + 1) mod LRemainingCount];
      LTriangleArea := Cross2(LPoints[LPrevious], LPoints[LCurrent], LPoints[LNext]);
      if LTriangleArea * LSign <= LAreaEpsilon then
      begin
        Continue;
      end;
      LEar := True;
      for J := 0 to LRemainingCount - 1 do
      begin
        LOther := LRemaining[J];
        if (LOther = LPrevious) or (LOther = LCurrent) or (LOther = LNext) then
        begin
          Continue;
        end;
        if (Cross2(LPoints[LPrevious], LPoints[LCurrent], LPoints[LOther]) * LSign >=
          -LAreaEpsilon) and
          (Cross2(LPoints[LCurrent], LPoints[LNext], LPoints[LOther]) * LSign >=
          -LAreaEpsilon) and
          (Cross2(LPoints[LNext], LPoints[LPrevious], LPoints[LOther]) * LSign >=
          -LAreaEpsilon) then
        begin
          LEar := False;
          Break;
        end;
      end;
      if not LEar then
      begin
        Continue;
      end;
      AFace.FTriangles[LWritten] := LPrevious;
      AFace.FTriangles[LWritten + 1] := LCurrent;
      AFace.FTriangles[LWritten + 2] := LNext;
      Inc(LWritten, 3);
      LTotalArea := LTotalArea + LTriangleArea;
      for J := I to LRemainingCount - 2 do
      begin
        LRemaining[J] := LRemaining[J + 1];
      end;
      Dec(LRemainingCount);
      LFound := True;
      Break;
    end;
    Require(LFound, 'Polygon has no nondegenerate ear');
  end;
  LTriangleArea := Cross2(LPoints[LRemaining[0]], LPoints[LRemaining[1]],
    LPoints[LRemaining[2]]);
  Require(LTriangleArea * LSign > LAreaEpsilon, 'Degenerate final polygon triangle');
  for I := 0 to 2 do
  begin
    AFace.FTriangles[LWritten + I] := LRemaining[I];
  end;
  LTotalArea := LTotalArea + LTriangleArea;
  Require(Abs(LTotalArea - LArea) <= LAreaEpsilon * LCount * 4,
    'Triangulation does not preserve polygon area');
  if FAdaptSurface then
  begin
    { Projection determines a concrete surface; it never moves source corners.
      A face that folds back against its own mean normal is rejected instead of
      hiding the fold behind a plausible two-dimensional boundary. }
    for I := 0 to Length(AFace.FTriangles) div 3 - 1 do
    begin
      LFirst := FPositions[AFace.FCorners[AFace.FTriangles[I * 3]].FPosition];
      LSecond := FPositions[AFace.FCorners[AFace.FTriangles[I * 3 + 1]].FPosition];
      LThird := FPositions[AFace.FCorners[AFace.FTriangles[I * 3 + 2]].FPosition];
      for J := 0 to 2 do
      begin
        LSecond[J] := LSecond[J] - LFirst[J];
        LThird[J] := LThird[J] - LFirst[J];
      end;
      LTriangleNormal[0] := LSecond[1] * LThird[2] - LSecond[2] * LThird[1];
      LTriangleNormal[1] := LSecond[2] * LThird[0] - LSecond[0] * LThird[2];
      LTriangleNormal[2] := LSecond[0] * LThird[1] - LSecond[1] * LThird[0];
      LDistance := 0;
      for J := 0 to 2 do
      begin
        LDistance := LDistance + LTriangleNormal[J] * LNormal[J] / LLength;
      end;
      Require(LDistance > LAreaEpsilon, 'Source polygon folds against its mean normal');
    end;
  end;
end;

procedure TConverter.ParseObject(const ABytes: TBytes);
var
  LLines: TStringList;
  LWords: TStringList;
  LValue: String;
  LToken: String;
  LVector: TVector;
  LLength: Double;
  LSingle: Single;
  LCurrentMaterial: Integer;
  LHasLibrary: Boolean;
  LFace: TFace;
  LHasUV: Boolean;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  LLines := Lines(ABytes);
  LWords := TStringList.Create;
  LCurrentMaterial := -1;
  LHasLibrary := False;
  try
    for I := 0 to LLines.Count - 1 do
    begin
      LValue := Words(LLines[I], LWords);
      if LWords.Count = 0 then
      begin
        Continue;
      end;
      LToken := LWords[0];
      if (LToken = 'v') or (LToken = 'vn') or (LToken = 'vt') then
      begin
        FillChar(LVector, SizeOf(LVector), 0);
        if LToken = 'vt' then
        begin
          Require(LWords.Count = 3, 'Only explicit 2D texture coordinates are admitted');
          for J := 0 to 1 do
          begin
            LVector[J] := Number(LWords[J + 1], 65536);
          end;
          AddVector(FUVs, FUVCount, LVector);
        end else
        begin
          Require(LWords.Count = 4, 'Expected explicit XYZ vector without extra fields');
          for J := 0 to 2 do
          begin
            LVector[J] := Number(LWords[J + 1], 1e6);
          end;
          if LToken = 'vn' then
          begin
            LLength := Sqrt(Sqr(LVector[0]) + Sqr(LVector[1]) + Sqr(LVector[2]));
            Require(LLength > 1e-12, 'Zero-length normal');
            for J := 0 to 2 do
            begin
              LSingle := LVector[J] / LLength;
              LVector[J] := LSingle;
            end;
            AddVector(FNormals, FNormalCount, LVector);
          end else
          begin
            AddVector(FPositions, FPositionCount, LVector);
          end;
        end;
      end else
      if LToken = 'mtllib' then
      begin
        Require(not LHasLibrary and (LValue = FMaterialName), 'Exact single MTL binding required');
        LHasLibrary := True;
      end else
      if LToken = 'usemtl' then
      begin
        Require(LHasLibrary, 'usemtl before mtllib');
        LCurrentMaterial := FNames.IndexOf(LValue);
        Require(LCurrentMaterial >= 0, 'Undefined material: ' + LValue);
      end else
      if (LToken = 'o') or (LToken = 'g') or (LToken = 's') then
      begin
        Require(Length(LValue) <= 1024, 'Source metadata name too long');
        if LToken = 's' then
        begin
          Require(LWords.Count = 2, 'Invalid smoothing declaration');
          if (LValue <> 'off') and (LValue <> 'on') then
          begin
            Require(IntegerValue(LValue) >= 0, 'Invalid smoothing group');
          end;
        end;
        Require(FMetadata.Count < StaticOBJFaceLimit, 'Source metadata count exceeds budget');
        FMetadata.Add(TJSONObject.Create(['line', I + 1, 'directive', LToken, 'value', LValue]));
      end else
      if LToken = 'f' then
      begin
        Require(LCurrentMaterial >= 0, 'Face requires a declared material');
        Require(FFaceCount < StaticOBJFaceLimit, 'Face count exceeds budget');
        LCount := LWords.Count - 1;
        Require((LCount >= 3) and (LCount <= StaticOBJPolygonLimit), 'Polygon corner budget');
        Require(FCornerCount <= StaticOBJCornerLimit - LCount, 'Corner count exceeds budget');
        Require(FTriangleCount <= StaticOBJTriangleLimit - (LCount - 2),
          'Triangle count exceeds budget');
        SetLength(LFace.FCorners, LCount);
        LFace.FMaterial := LCurrentMaterial;
        LFace.FLine := I + 1;
        LHasUV := False;
        for J := 0 to LCount - 1 do
        begin
          LFace.FCorners[J] := ReadCorner(LWords[J + 1]);
          if J = 0 then
          begin
            LHasUV := LFace.FCorners[J].FUV >= 0;
          end else
          begin
            Require((LFace.FCorners[J].FUV >= 0) = LHasUV, 'Mixed UV presence within face');
          end;
        end;
        Triangulate(LFace);
        if FFaceCount = Length(FFaces) then
        begin
          SetLength(FFaces, Min(StaticOBJFaceLimit, Max(256, FFaceCount * 2)));
        end;
        FFaces[FFaceCount] := LFace;
        { Dynamic arrays in records share storage. Reset the temporary before
          another source face can overwrite the retained corner tuples. }
        LFace.FCorners := nil;
        LFace.FTriangles := nil;
        Inc(FFaceCount);
        Inc(FCornerCount, LCount);
        Inc(FTriangleCount, LCount - 2);
      end else
      begin
        raise Exception.Create('Unsupported OBJ directive: ' + LToken);
      end;
    end;
    Require(LHasLibrary and (FFaceCount > 0), 'No admitted material-bound faces');
  finally
    LWords.Free;
    LLines.Free;
  end;
end;

procedure Write32(const AStream: TStream; const AValue: Cardinal);
var
  LBytes: array[0..3] of Byte;
begin
  LBytes[0] := AValue and $ff;
  LBytes[1] := (AValue shr 8) and $ff;
  LBytes[2] := (AValue shr 16) and $ff;
  LBytes[3] := (AValue shr 24) and $ff;
  AStream.WriteBuffer(LBytes, 4);
end;

procedure WriteSingle(const AStream: TStream; const AValue: Double);
var
  LValue: Single;
  LBits: Cardinal;
begin
  LValue := AValue;
  Move(LValue, LBits, SizeOf(LBits));
  Write32(AStream, LBits);
end;

function VectorJSON(const AValue: TVector): TJSONArray;
begin
  Result := TJSONArray.Create([AValue[0], AValue[1], AValue[2]]);
end;

function TConverter.BuildGLB(const AEvidence: TJSONObject): TBytes;
var
  LDocument: TJSONObject;
  LMaterials: TJSONArray;
  LPrimitives: TJSONArray;
  LViews: TJSONArray;
  LAccessors: TJSONArray;
  LBoundsMin: TVector;
  LBoundsMax: TVector;
  LPrimitive: TJSONObject;
  LAttributes: TJSONObject;
  LAccessor: TJSONObject;
  LSegments: TJSONArray;
  LBinary: TMemoryStream;
  LOutput: TMemoryStream;
  LJSON: UTF8String;
  LView: Integer;
  LPositionAccessor: Integer;
  LNormalAccessor: Integer;
  LUVAccessor: Integer;
  LOffset: Integer;
  LVertexCount: Integer;
  LFirstVertex: Integer;
  LStride: Integer;
  LCorner: TCorner;
  LColor: TJSONArray;
  LHasUV: Boolean;
  LWantUV: Boolean;
  LTotalBytes: Int64;
  I: Integer;
  J: Integer;
  K: Integer;
  L: Integer;
  LUVGroup: Integer;
begin
  Result := nil;
  LDocument := TJSONObject.Create;
  LBinary := TMemoryStream.Create;
  LOutput := TMemoryStream.Create;
  try
    LDocument.Add('asset', TJSONObject.Create(['version', '2.0',
      'generator', FRecipe, 'extras', AEvidence.Clone]));
    LDocument.Add('scene', 0);
    LDocument.Add('scenes', TJSONArray.Create([
      TJSONObject.Create(['nodes', TJSONArray.Create([0])])]));
    LDocument.Add('nodes', TJSONArray.Create([
      TJSONObject.Create(['mesh', 0, 'name', AEvidence.Strings['sourceName']])]));
    LMaterials := TJSONArray.Create;
    LDocument.Add('materials', LMaterials);
    for I := 0 to FMaterials.Count - 1 do
    begin
      LColor := FMaterials.Objects[I].Objects['sourceParameters'].Arrays['Kd'];
      LMaterials.Add(TJSONObject.Create(['name', FMaterials.Objects[I].Strings['name'],
        'doubleSided', True, 'alphaMode', 'OPAQUE',
        'pbrMetallicRoughness', TJSONObject.Create([
          'baseColorFactor', TJSONArray.Create([LColor.Floats[0], LColor.Floats[1],
            LColor.Floats[2], 1.0]), 'metallicFactor', 0.0, 'roughnessFactor', 0.72]),
        'extras', FMaterials.Objects[I].Clone]));
    end;
    LPrimitives := TJSONArray.Create;
    LDocument.Add('meshes', TJSONArray.Create([
      TJSONObject.Create(['primitives', LPrimitives])]));
    LViews := TJSONArray.Create;
    LDocument.Add('bufferViews', LViews);
    LAccessors := TJSONArray.Create;
    LDocument.Add('accessors', LAccessors);
    for I := 0 to FMaterials.Count - 1 do
    begin
      { Separate the absent-UV and explicit-UV faces. Never invent a channel or
        merge a valid zero UV with absent attributes. Material declaration order
        and original face order make this emission deterministic. }
      for LUVGroup := 0 to 1 do
      begin
        LWantUV := LUVGroup = 1;
        LVertexCount := 0;
        LOffset := LBinary.Position;
        LSegments := TJSONArray.Create;
        LPrimitive := TJSONObject.Create(['mode', 4, 'material', I,
          'extras', TJSONObject.Create(['sourceFaces', LSegments])]);
        for J := 0 to 2 do
        begin
          LBoundsMin[J] := Infinity;
          LBoundsMax[J] := NegInfinity;
        end;
        try
          for J := 0 to FFaceCount - 1 do
          begin
            LHasUV := FFaces[J].FCorners[0].FUV >= 0;
            if (FFaces[J].FMaterial <> I) or (LHasUV <> LWantUV) then
            begin
              Continue;
            end;
            LFirstVertex := LVertexCount;
            for K := 0 to High(FFaces[J].FTriangles) do
            begin
              LCorner := FFaces[J].FCorners[FFaces[J].FTriangles[K]];
              for L := 0 to 2 do
              begin
                WriteSingle(LBinary, FPositions[LCorner.FPosition][L]);
                LBoundsMin[L] := Min(LBoundsMin[L], FPositions[LCorner.FPosition][L]);
                LBoundsMax[L] := Max(LBoundsMax[L], FPositions[LCorner.FPosition][L]);
              end;
              for L := 0 to 2 do
              begin
                WriteSingle(LBinary, FNormals[LCorner.FNormal][L]);
              end;
              if LWantUV then
              begin
                WriteSingle(LBinary, FUVs[LCorner.FUV][0]);
                WriteSingle(LBinary, 1 - FUVs[LCorner.FUV][1]);
              end;
              Inc(LVertexCount);
            end;
            LSegments.Add(TJSONObject.Create(['line', FFaces[J].FLine,
              'firstVertex', LFirstVertex, 'vertexCount', LVertexCount - LFirstVertex]));
            if FAdaptSurface then
            begin
              LSegments.Objects[LSegments.Count - 1].Add('planeDeviationRatio',
                FFaces[J].FPlaneDeviationRatio);
            end;
          end;
          if LVertexCount = 0 then
          begin
            Continue;
          end;
          if LWantUV then
          begin
            LStride := 32;
          end else
          begin
            LStride := 24;
          end;
          LView := LViews.Count;
          LViews.Add(TJSONObject.Create(['buffer', 0, 'byteOffset', LOffset,
            'byteLength', LVertexCount * LStride, 'byteStride', LStride, 'target', 34962]));
          LPositionAccessor := LAccessors.Count;
          LAccessors.Add(TJSONObject.Create(['bufferView', LView, 'byteOffset', 0,
            'componentType', 5126, 'count', LVertexCount, 'type', 'VEC3',
            'min', VectorJSON(LBoundsMin), 'max', VectorJSON(LBoundsMax)]));
          LNormalAccessor := LAccessors.Count;
          LAccessors.Add(TJSONObject.Create(['bufferView', LView, 'byteOffset', 12,
            'componentType', 5126, 'count', LVertexCount, 'type', 'VEC3']));
          LAttributes := TJSONObject.Create(['POSITION', LPositionAccessor,
            'NORMAL', LNormalAccessor]);
          LPrimitive.Add('attributes', LAttributes);
          if LWantUV then
          begin
            LUVAccessor := LAccessors.Count;
            LAccessor := TJSONObject.Create(['bufferView', LView, 'byteOffset', 24,
              'componentType', 5126, 'count', LVertexCount, 'type', 'VEC2']);
            LAccessors.Add(LAccessor);
            LAttributes.Add('TEXCOORD_0', LUVAccessor);
          end;
          LPrimitives.Add(LPrimitive);
          LPrimitive := nil;
        finally
          LPrimitive.Free;
        end;
      end;
    end;
    LDocument.Add('buffers', TJSONArray.Create([
      TJSONObject.Create(['byteLength', LBinary.Size])]));
    LJSON := LDocument.AsJSON;
    while Length(LJSON) mod 4 <> 0 do
    begin
      LJSON := LJSON + ' ';
    end;
    LTotalBytes := 12 + 8 + Int64(Length(LJSON)) + 8 + LBinary.Size;
    Require(LTotalBytes <= StaticOBJOutputLimit, 'Derived GLB exceeds output budget');
    Write32(LOutput, $46546c67);
    Write32(LOutput, 2);
    Write32(LOutput, LTotalBytes);
    Write32(LOutput, Length(LJSON));
    Write32(LOutput, $4e4f534a);
    LOutput.WriteBuffer(LJSON[1], Length(LJSON));
    Write32(LOutput, LBinary.Size);
    Write32(LOutput, $004e4942);
    LBinary.Position := 0;
    LOutput.CopyFrom(LBinary, LBinary.Size);
    SetLength(Result, LOutput.Size);
    LOutput.Position := 0;
    LOutput.ReadBuffer(Result[0], Length(Result));
  finally
    LOutput.Free;
    LBinary.Free;
    LDocument.Free;
  end;
end;

function TConverter.Run(const ASourceName: String; const AOBJBytes, AMTLBytes: TBytes;
  out AEvidence: TJSONObject): TBytes;
var
  LEvidence: TJSONObject;
  LNonplanar: Integer;
  LMaximumDeviation: Double;
  I: Integer;
begin
  AEvidence := nil;
  Result := nil;
  ParseMaterial(AMTLBytes);
  ParseObject(AOBJBytes);
  LEvidence := TJSONObject.Create(['recipe', FRecipe,
    'objSha256', HashBytes(AOBJBytes), 'mtlSha256', HashBytes(AMTLBytes),
    'sourceName', ASourceName, 'materialName', FMaterialName,
    'coordinatePolicy', 'source-identity', 'units', 'unspecified',
    'normalPolicy', 'normalized', 'uvPolicy', 'v-flipped',
    'sourceFaceCount', FFaceCount, 'triangleCount', FTriangleCount,
    'vertexCount', FTriangleCount * 3, 'materials', FMaterials.Clone,
    'sourceMetadata', FMetadata.Clone]);
  try
    if FAdaptSurface then
    begin
      LNonplanar := 0;
      LMaximumDeviation := 0;
      for I := 0 to FFaceCount - 1 do
      begin
        if FFaces[I].FPlaneDeviationRatio > 1e-5 then
        begin
          Inc(LNonplanar);
        end;
        LMaximumDeviation := Max(LMaximumDeviation, FFaces[I].FPlaneDeviationRatio);
      end;
      LEvidence.Add('surfacePolicy', 'projected-ear-clipping');
      LEvidence.Add('nonplanarFaces', LNonplanar);
      LEvidence.Add('maximumPlaneDeviationRatio', LMaximumDeviation);
    end;
    Result := BuildGLB(LEvidence);
    LEvidence.Add('outputSha256', HashBytes(Result));
    AEvidence := LEvidence;
    LEvidence := nil;
  finally
    LEvidence.Free;
  end;
end;

function ConvertStaticOBJ(const ASourceName, AMaterialName: String;
  const AOBJBytes, AMTLBytes: TBytes; out AEvidence: TJSONObject): TBytes;
var
  LConverter: TConverter;
begin
  AEvidence := nil;
  Result := nil;
  CheckName(ASourceName, '.obj');
  CheckName(AMaterialName, '.mtl');
  LConverter := TConverter.Create(AMaterialName, False);
  try
    Result := LConverter.Run(ASourceName, AOBJBytes, AMTLBytes, AEvidence);
  finally
    LConverter.Free;
  end;
end;

function ConvertSurfaceOBJ(const ASourceName, AMaterialName: String;
  const AOBJBytes, AMTLBytes: TBytes; out AEvidence: TJSONObject): TBytes;
var
  LConverter: TConverter;
begin
  AEvidence := nil;
  Result := nil;
  CheckName(ASourceName, '.obj');
  CheckName(AMaterialName, '.mtl');
  LConverter := TConverter.Create(AMaterialName, True);
  try
    Result := LConverter.Run(ASourceName, AOBJBytes, AMTLBytes, AEvidence);
  finally
    LConverter.Free;
  end;
end;

end.
