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

unit phanes.tests.terrain.critic;

{$mode delphi}
{$H+}

interface

function RunTerrainCriticChecks: Integer;

implementation

uses
  Math,
  SysUtils,
  phanes.terrain.types,
  phanes.terrain.validate,
  phanes.terrain.generate,
  phanes.terrain.surface;

type
  TOraclePoint = record
    FX: Double;
    FZ: Double;
    FH: Double;
  end;
  TOraclePolygon = array of TOraclePoint;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create('Independent terrain critic regression: ' + AMessage);
  end;
end;

function Field(const AColumns, ARows, ASpacing, AOrigin: Integer): TTerrainField;
begin
  Result := Default(TTerrainField);
  Result.FSpec.FVersion := TerrainFieldVersion;
  Result.FSpec.FColumns := AColumns;
  Result.FSpec.FRows := ARows;
  Result.FSpec.FSpacing := ASpacing;
  Result.FSpec.FOriginX := AOrigin;
  Result.FSpec.FOriginZ := AOrigin;
  Result.FSpec.FLevelStep := 1000;
  Result.FSpec.FMinimumLevel := 0;
  Result.FSpec.FMaximumLevel := 1;
  Result.FSpec.FMaximumRise := 1;
  Result.FSeed := 123;
  SetLength(Result.FLevels, AColumns * ARows);
end;

function Request(const AField: TTerrainField): TTerrainRequest;
begin
  Result := Default(TTerrainRequest);
  Result.FSpec := AField.FSpec;
  Result.FSeed := 987;
  Result.FWidth := AField.FSpec.FColumns - 1;
  Result.FDepth := AField.FSpec.FRows - 1;
  Result.FMaxBacktracks := 64;
end;

procedure AppendPoint(var APolygon: TOraclePolygon; const APoint: TOraclePoint);
var
  LCount: Integer;
begin
  LCount := Length(APolygon);
  SetLength(APolygon, LCount + 1);
  APolygon[LCount] := APoint;
end;

function PlaneDistance(const APoint: TOraclePoint; const AAxis: Integer;
  const ABound: Double; const AKeepGreater: Boolean): Double;
begin
  if AAxis = 0 then
  begin
    Result := APoint.FX - ABound;
  end
  else
  begin
    Result := APoint.FZ - ABound;
  end;
  if not AKeepGreater then
  begin
    Result := -Result;
  end;
end;

function ClipPolygon(const APolygon: TOraclePolygon; const AAxis: Integer;
  const ABound: Double; const AKeepGreater: Boolean): TOraclePolygon;
var
  LPrevious: TOraclePoint;
  LCurrent: TOraclePoint;
  LCrossing: TOraclePoint;
  LPreviousDistance: Double;
  LCurrentDistance: Double;
  LT: Double;
  LPreviousInside: Boolean;
  LCurrentInside: Boolean;
  I: Integer;
begin
  Result := nil;
  if Length(APolygon) = 0 then
  begin
    Exit;
  end;
  LPrevious := APolygon[High(APolygon)];
  LPreviousDistance := PlaneDistance(LPrevious, AAxis, ABound, AKeepGreater);
  LPreviousInside := LPreviousDistance >= -1E-12;
  for I := 0 to High(APolygon) do
  begin
    LCurrent := APolygon[I];
    LCurrentDistance := PlaneDistance(LCurrent, AAxis, ABound, AKeepGreater);
    LCurrentInside := LCurrentDistance >= -1E-12;
    if LPreviousInside <> LCurrentInside then
    begin
      LT := LPreviousDistance / (LPreviousDistance - LCurrentDistance);
      LCrossing.FX := LPrevious.FX + LT * (LCurrent.FX - LPrevious.FX);
      LCrossing.FZ := LPrevious.FZ + LT * (LCurrent.FZ - LPrevious.FZ);
      LCrossing.FH := LPrevious.FH + LT * (LCurrent.FH - LPrevious.FH);
      AppendPoint(Result, LCrossing);
    end;
    if LCurrentInside then
    begin
      AppendPoint(Result, LCurrent);
    end;
    LPrevious := LCurrent;
    LPreviousDistance := LCurrentDistance;
    LPreviousInside := LCurrentInside;
  end;
end;

function Vertex(const AField: TTerrainField; const AX, AZ: Integer): TOraclePoint;
begin
  Result.FX := AX;
  Result.FZ := AZ;
  Result.FH := Double(AField.FLevels[AZ * AField.FSpec.FColumns + AX]) *
    AField.FSpec.FLevelStep / 1000;
end;

procedure OracleBounds(const AField: TTerrainField;
  const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMinimum, AMaximum, ADX, ADZ: Double);
var
  LTriangle: TOraclePolygon;
  LClipped: TOraclePolygon;
  LX: Integer;
  LZ: Integer;
  LTriangleIndex: Integer;
  LDeterminant: Double;
  LDX: Double;
  LDZ: Double;
  I: Integer;
begin
  AMinimum := 1E30;
  AMaximum := -1E30;
  ADX := 0;
  ADZ := 0;
  SetLength(LTriangle, 3);
  { Enumerate every triangle, then use generic half-plane clipping. This does
    not reuse the implementation's cell range, diagonal intersections, affine
    height routine or gradient-selection predicates. Grid coordinates retain
    the exact intended millimetre geometry at large world origins. }
  for LZ := 0 to AField.FSpec.FRows - 2 do
  begin
    for LX := 0 to AField.FSpec.FColumns - 2 do
    begin
      for LTriangleIndex := 0 to 1 do
      begin
        LTriangle[0] := Vertex(AField, LX + LTriangleIndex, LZ + LTriangleIndex);
        LTriangle[1] := Vertex(AField, LX + 1, LZ);
        LTriangle[2] := Vertex(AField, LX, LZ + 1);
        LClipped := ClipPolygon(LTriangle, 0, AMinX, True);
        LClipped := ClipPolygon(LClipped, 0, AMaxX, False);
        LClipped := ClipPolygon(LClipped, 1, AMinZ, True);
        LClipped := ClipPolygon(LClipped, 1, AMaxZ, False);
        if Length(LClipped) = 0 then
        begin
          Continue;
        end;
        LDeterminant := (LTriangle[1].FX - LTriangle[0].FX) *
          (LTriangle[2].FZ - LTriangle[0].FZ) -
          (LTriangle[2].FX - LTriangle[0].FX) *
          (LTriangle[1].FZ - LTriangle[0].FZ);
        LDX := ((LTriangle[1].FH - LTriangle[0].FH) *
          (LTriangle[2].FZ - LTriangle[0].FZ) -
          (LTriangle[2].FH - LTriangle[0].FH) *
          (LTriangle[1].FZ - LTriangle[0].FZ)) / LDeterminant;
        LDZ := ((LTriangle[1].FX - LTriangle[0].FX) *
          (LTriangle[2].FH - LTriangle[0].FH) -
          (LTriangle[2].FX - LTriangle[0].FX) *
          (LTriangle[1].FH - LTriangle[0].FH)) / LDeterminant;
        ADX := Max(ADX, Abs(LDX) * 1000 / AField.FSpec.FSpacing);
        ADZ := Max(ADZ, Abs(LDZ) * 1000 / AField.FSpec.FSpacing);
        for I := 0 to High(LClipped) do
        begin
          AMinimum := Min(AMinimum, LClipped[I].FH);
          AMaximum := Max(AMaximum, LClipped[I].FH);
        end;
      end;
    end;
  end;
  Check(AMinimum <= AMaximum, 'oracle intersects the query');
end;

procedure CompareBounds(const AField: TTerrainField; const ASurface: TTerrainSurface;
  const AMinU, AMinV, AMaxU, AMaxV: Double);
var
  LMinX: Double;
  LMinZ: Double;
  LMaxX: Double;
  LMaxZ: Double;
  LMinimum: Double;
  LMaximum: Double;
  LDX: Double;
  LDZ: Double;
  LOracleMinimum: Double;
  LOracleMaximum: Double;
  LOracleDX: Double;
  LOracleDZ: Double;
begin
  LMinX := (Double(AField.FSpec.FOriginX) + AMinU * AField.FSpec.FSpacing) / 1000;
  LMinZ := (Double(AField.FSpec.FOriginZ) + AMinV * AField.FSpec.FSpacing) / 1000;
  LMaxX := (Double(AField.FSpec.FOriginX) + AMaxU * AField.FSpec.FSpacing) / 1000;
  LMaxZ := (Double(AField.FSpec.FOriginZ) + AMaxV * AField.FSpec.FSpacing) / 1000;
  OracleBounds(AField, AMinU, AMinV, AMaxU, AMaxV,
    LOracleMinimum, LOracleMaximum, LOracleDX, LOracleDZ);
  ASurface.Bounds(LMinX, LMinZ, LMaxX, LMaxZ, LMinimum, LMaximum, LDX, LDZ);
  Check(LMinimum <= LOracleMinimum + 1E-10, 'minimum conservatively encloses exact polygon');
  Check(LMaximum >= LOracleMaximum - 1E-10, 'maximum conservatively encloses exact polygon');
  Check(Abs(LMinimum - LOracleMinimum) < 1E-6, 'minimum bound remains tight');
  Check(Abs(LMaximum - LOracleMaximum) < 1E-6, 'maximum bound remains tight');
  Check(LDX + 1E-10 >= LOracleDX, 'all incident X gradients enclosed');
  Check(LDZ + 1E-10 >= LOracleDZ, 'all incident Z gradients enclosed');
  Check(Abs(LDX - LOracleDX) < 1E-7, 'X gradient bound remains tight');
  Check(Abs(LDZ - LOracleDZ) < 1E-7, 'Z gradient bound remains tight');
  if (AMinU = AMaxU) and (AMinV = AMaxV) then
  begin
    Check(Abs(ASurface.Height(LMinX, LMinZ) - LOracleMinimum) < 1E-7,
      'point sampler agrees with independently clipped triangle');
  end;
end;

procedure GeometryChecks;
var
  LField: TTerrainField;
  LSurface: TTerrainSurface;
  LPattern: Integer;
  LX: Integer;
  LZ: Integer;
  LIndex: Integer;
  LOrigin: Integer;
  LSpacing: Integer;
  I: Integer;
begin
  for LPattern := 0 to 15 do
  begin
    LField := Field(2, 2, 333, -1494);
    for I := 0 to 3 do
    begin
      LField.FLevels[I] := (LPattern shr I) and 1;
    end;
    LSurface := TTerrainSurface.Create(LField);
    try
      CompareBounds(LField, LSurface, 0, 0, 1, 1);
      CompareBounds(LField, LSurface, 0.1, 0.1, 0.8, 0.6);
      CompareBounds(LField, LSurface, 0.2, 0.8, 0.2, 0.8);
      CompareBounds(LField, LSurface, 0.5, 0, 0.5, 1);
      CompareBounds(LField, LSurface, 0, 0.5, 1, 0.5);
      CompareBounds(LField, LSurface, 1, 1, 1, 1);
      CompareBounds(LField, LSurface, 0, 0, 0, 0);
    finally
      LSurface.Free;
    end;
  end;

  { All four directions around a non-square field, clipped multi-cell areas,
    grid lines, isolated grid vertices and a peak inside the rectangle. }
  LField := Field(5, 4, 750, -5000);
  LField.FSpec.FMinimumLevel := -2;
  LField.FSpec.FMaximumLevel := 2;
  LField.FSpec.FMaximumRise := 4;
  for LZ := 0 to 3 do
  begin
    for LX := 0 to 4 do
    begin
      LField.FLevels[LZ * 5 + LX] := ((LX * 3 + LZ * 2 + LX * LZ) mod 5) - 2;
    end;
  end;
  LSurface := TTerrainSurface.Create(LField);
  try
    CompareBounds(LField, LSurface, 0, 0, 4, 3);
    for I := 0 to 50 do
    begin
      CompareBounds(LField, LSurface, Double(I mod 11) / 10,
        Double(I mod 7) / 10, 2 + Double(I mod 19) / 10,
        1 + Double(I mod 17) / 10);
    end;
    for LZ := 0 to 3 do
    begin
      for LX := 0 to 4 do
      begin
        CompareBounds(LField, LSurface, LX, LZ, LX, LZ);
      end;
    end;
  finally
    LSurface.Free;
  end;

  { Retain the actual decimal-origin crease failure and its transposed case.
    Both one-sided derivatives belong to a zero-area query on a shared edge. }
  for LOrigin := -1500 to -1480 do
  begin
    for LSpacing := 250 to 280 do
    begin
      LField := Field(3, 3, LSpacing, LOrigin);
      for LZ := 0 to 2 do
      begin
        for LX := 0 to 2 do
        begin
          LIndex := LZ * 3 + LX;
          LField.FLevels[LIndex] := Ord((LX > 0) and (LZ > 0));
        end;
      end;
      LSurface := TTerrainSurface.Create(LField);
      try
        CompareBounds(LField, LSurface, 1, 1.5, 1, 1.5);
        CompareBounds(LField, LSurface, 1.5, 1, 1.5, 1);
      finally
        LSurface.Free;
      end;
    end;
  end;

  { The highest admitted local slope at both extreme frame origins. Compare
    intended rational-millimetre geometry, not another call to Height. }
  for I := 0 to 1 do
  begin
    if I = 0 then
    begin
      LOrigin := -4096000;
    end
    else
    begin
      LOrigin := 4095750;
    end;
    LField := Field(2, 2, 250, LOrigin);
    LField.FSpec.FLevelStep := 8000;
    LField.FSpec.FMinimumLevel := -32;
    LField.FSpec.FMaximumLevel := 32;
    LField.FSpec.FMaximumRise := 64;
    LField.FLevels[0] := -32;
    LField.FLevels[1] := 32;
    LField.FLevels[2] := 32;
    LField.FLevels[3] := -32;
    LSurface := TTerrainSurface.Create(LField);
    try
      for LIndex := 0 to 10 do
      begin
        CompareBounds(LField, LSurface, Double(LIndex) / 10, 0.25,
          Double(LIndex) / 10, 0.25);
      end;
      CompareBounds(LField, LSurface, 0.1, 0.1, 0.8, 0.6);
    finally
      LSurface.Free;
    end;
  end;
end;

procedure ImmutabilityAndQueryChecks;
var
  LField: TTerrainField;
  LCopy: TTerrainField;
  LSpec: TTerrainSpec;
  LSurface: TTerrainSurface;
  LMinimum: Double;
  LMaximum: Double;
  LDX: Double;
  LDZ: Double;
  LRejected: Boolean;
  I: Integer;
begin
  LField := Field(2, 2, 1000, 0);
  LField.FLevels[1] := 1;
  LCopy := CopyTerrainField(LField);
  LSurface := TTerrainSurface.Create(LField);
  try
    LField.FLevels[1] := 0;
    LField.FSpec.FSpacing := 2000;
    Check(LCopy.FLevels[1] = 1, 'CopyTerrainField detaches the source array');
    Check(Abs(LSurface.Height(1, 0) - 1) < 1E-10, 'surface owns copied heights');
    LSpec := LSurface.Spec;
    LSpec.FSpacing := 999;
    Check(LSurface.Spec.FSpacing = 1000, 'surface specification property copies records');
    LCopy.FLevels[1] := 0;
    Check(Abs(LSurface.Height(1, 0) - 1) < 1E-10, 'surface ignores every caller alias');
    for I := 0 to 4 do
    begin
      LRejected := False;
      try
        case I of
          0:
          begin
            LMinimum := LSurface.Height(-1E-12, 0);
          end;
          1:
          begin
            LMinimum := LSurface.Height(1 + 1E-12, 0);
          end;
          2:
          begin
            LMinimum := LSurface.Height(NaN, 0);
          end;
          3:
          begin
            LMinimum := LSurface.Height(0, Infinity);
          end;
          4:
          begin
            LSurface.Bounds(0.5, 0, 0.4, 1, LMinimum, LMaximum, LDX, LDZ);
          end;
        end;
      except
        on LException: EArgumentException do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'invalid/outside queries reject without extrapolation');
    end;
  finally
    LSurface.Free;
  end;
end;

procedure GenerationChecks;
var
  LBase: TTerrainField;
  LOutput: TTerrainField;
  LOriginal: TTerrainField;
  LTampered: TTerrainField;
  LRequest: TTerrainRequest;
  LReason: String;
  LBefore: TTerrainSurface;
  LAfter: TTerrainSurface;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  LBase := Field(2, 2, 1000, 0);
  LBase.FSpec.FMinimumLevel := 4;
  LBase.FSpec.FMaximumLevel := 6;
  LBase.FSpec.FMaximumRise := 2;
  LRequest := Request(LBase);
  SetLength(LRequest.FDomains, 4);
  for I := 0 to 3 do
  begin
    LRequest.FDomains[I].FMinimum := 4 + (I mod 3);
    LRequest.FDomains[I].FMaximum := LRequest.FDomains[I].FMinimum;
  end;
  LOutput := Default(TTerrainField);
  Check(GenerateTerrain(LRequest, LOutput, LReason), 'fresh nonzero palette resolves: ' + LReason);
  for I := 0 to 3 do
  begin
    Check(LOutput.FLevels[I] = 4 + (I mod 3), 'fresh boundary vertices follow caller domains');
  end;
  Check(ValidateTerrainResult(LRequest, LOutput, LReason), 'fresh result validates');

  LBase := Field(5, 5, 1000, 0);
  LBase.FSeed := 123;
  LBase.FDecisions := 71;
  LBase.FPropagations := 93;
  LBase.FBacktracks := 4;
  LOriginal := CopyTerrainField(LBase);
  LRequest := Request(LBase);
  LRequest.FHasPrevious := True;
  LRequest.FPrevious := CopyTerrainField(LBase);
  LRequest.FX := 1;
  LRequest.FZ := 1;
  LRequest.FWidth := 2;
  LRequest.FDepth := 2;
  SetLength(LRequest.FDomains, 25);
  for I := 0 to 24 do
  begin
    LRequest.FDomains[I].FMinimum := 0;
    LRequest.FDomains[I].FMaximum := 1;
  end;
  LRequest.FDomains[12].FMinimum := 1;
  Check(GenerateTerrain(LRequest, LOutput, LReason), 'single interior vertex resolves: ' + LReason);
  Check(LOutput.FLevels[12] = 1, 'interior forced domain applied');
  for I := 0 to 24 do
  begin
    if I <> 12 then
    begin
      Check(LOutput.FLevels[I] = 0, 'exact selection ring and outside vertices preserved');
    end;
  end;
  Check(SameTerrainField(LBase, LOriginal), 'normal solve preserves caller baseline');
  Check(SameTerrainField(LRequest.FPrevious, LOriginal), 'normal solve preserves request baseline');
  LBefore := TTerrainSurface.Create(LBase);
  LAfter := TTerrainSurface.Create(LOutput);
  try
    for LZ := 0 to 8 do
    begin
      for LX := 0 to 8 do
      begin
        if (LX <= 2) or (LX >= 6) or (LZ <= 2) or (LZ >= 6) then
        begin
          Check(Abs(LBefore.Height(Double(LX) / 2, Double(LZ) / 2) -
            LAfter.Height(Double(LX) / 2, Double(LZ) / 2)) < 1E-12,
            'continuous outside surface and boundary remain identical');
        end;
      end;
    end;
  finally
    LAfter.Free;
    LBefore.Free;
  end;
  LTampered := CopyTerrainField(LOutput);
  LTampered.FLevels[6] := 1;
  Check(not ValidateTerrainResult(LRequest, LTampered, LReason),
    'independent result rejects ring edit');
  LTampered := CopyTerrainField(LOutput);
  LTampered.FSeed := LBase.FSeed;
  Check(not ValidateTerrainResult(LRequest, LTampered, LReason),
    'changed result requires new seed');

  { The output may alias the request's managed baseline. Successful staging
    must read all pins before publication; failed staging preserves everything. }
  Check(GenerateTerrain(LRequest, LRequest.FPrevious, LReason), 'aliased changed solve resolves');
  Check(LRequest.FPrevious.FLevels[12] = 1, 'aliased output receives selected change');
  Check(SameTerrainField(LBase, LOriginal), 'aliased success leaves other owners unchanged');
  LRequest.FPrevious := CopyTerrainField(LOriginal);
  SetLength(LRequest.FProtected, 25);
  LRequest.FProtected[12] := True;
  LOutput := CopyTerrainField(LOutput);
  LTampered := CopyTerrainField(LOutput);
  Check(not GenerateTerrain(LRequest, LOutput, LReason), 'contradictory protected domain rejects');
  Check(SameTerrainField(LOutput, LTampered), 'failure preserves complete prior output');
  Check(not GenerateTerrain(LRequest, LRequest.FPrevious, LReason),
    'aliased contradiction rejects');
  Check(SameTerrainField(LRequest.FPrevious, LOriginal), 'aliased failure preserves baseline');

  LRequest := Request(LOriginal);
  LRequest.FHasPrevious := True;
  LRequest.FPrevious := CopyTerrainField(LOriginal);
  LRequest.FWidth := 1;
  Check(GenerateTerrain(LRequest, LOutput, LReason), 'one-cell strip is admitted unchanged');
  Check(SameTerrainField(LOutput, LOriginal), 'unchanged solve preserves seed and all counters');
  LTampered := CopyTerrainField(LOutput);
  Inc(LTampered.FDecisions);
  Check(not ValidateTerrainResult(LRequest, LTampered, LReason),
    'unchanged counter rewrite rejects');
  LTampered := CopyTerrainField(LOutput);
  LTampered.FSeed := LRequest.FSeed;
  Check(not ValidateTerrainResult(LRequest, LTampered, LReason), 'unchanged seed rewrite rejects');
  Inc(LRequest.FSpec.FOriginX);
  Check(not GenerateTerrain(LRequest, LOutput, LReason), 'local frame change rejects');
  Check(SameTerrainField(LOutput, LOriginal), 'frame refusal preserves prior output');
end;

procedure AdmissionChecks;
var
  LField: TTerrainField;
  LRequest: TTerrainRequest;
  LReason: String;
  {$ifdef PAS2JS}
  LRejected: Boolean;
  {$endif}
  I: Integer;
begin
  for I := 0 to 10 do
  begin
    LField := Field(2, 2, 1000, 0);
    case I of
      0:
      begin
        LField.FSpec.FColumns := High(Integer);
      end;
      1:
      begin
        LField.FSpec.FRows := 1;
      end;
      2:
      begin
        LField.FSpec.FOriginX := High(Integer);
      end;
      3:
      begin
        LField.FSpec.FOriginZ := -4096001;
      end;
      4:
      begin
        LField.FSpec.FSpacing := 249;
      end;
      5:
      begin
        LField.FSpec.FLevelStep := High(Integer);
      end;
      6:
      begin
        LField.FSpec.FMaximumRise := 2;
      end;
      7:
      begin
        LField.FSpec.FMinimumLevel := Low(Integer);
      end;
      8:
      begin
        LField.FLevels[0] := High(Integer);
      end;
      9:
      begin
        LField.FDecisions := -1;
      end;
      10:
      begin
        SetLength(LField.FLevels, 3);
      end;
    end;
    Check(not ValidateTerrainField(LField, LReason), 'malformed field fails bounded admission');
  end;
  for I := 0 to 5 do
  begin
    LField := Field(3, 3, 1000, 0);
    LRequest := Request(LField);
    case I of
      0:
      begin
        LRequest.FX := High(Integer);
      end;
      1:
      begin
        LRequest.FDepth := High(Integer);
      end;
      2:
      begin
        LRequest.FMaxBacktracks := 4097;
      end;
      3:
      begin
        SetLength(LRequest.FDomains, 8);
      end;
      4:
      begin
        SetLength(LRequest.FProtected, 9);
      end;
      5:
      begin
        LRequest.FWidth := 1;
      end;
    end;
    Check(not ValidateTerrainRequest(LRequest, LReason),
      'malformed request fails bounded admission');
  end;
  {$ifdef PAS2JS}
  for I := 0 to 8 do
  begin
    LField := Field(2, 2, 1000, 0);
    asm
      switch (I) {
        case 0: LField.FSpec.FSpacing = NaN; break;
        case 1: LField.FLevels[0] = NaN; break;
        case 2: LField.FLevels[0] = 0.5; break;
        case 3: LField.FSeed = -1; break;
        case 4: LField.FSeed = 4294967296; break;
        case 5: LField.FDecisions = Infinity; break;
        case 6: LField.FLevels = {}; break;
        case 7: delete LField.FLevels[0]; break;
        case 8: LField.FSpec.FColumns = '2'; break;
      }
    end;
    Check(not ValidateTerrainField(LField, LReason), 'hostile JS scalar/array field rejects');
  end;
  for I := 0 to 5 do
  begin
    LField := Field(2, 2, 1000, 0);
    LRequest := Request(LField);
    SetLength(LRequest.FDomains, 4);
    asm
      switch (I) {
        case 0: LRequest.FHasPrevious = 0; break;
        case 1: LRequest.FWidth = 0.5; break;
        case 2: LRequest.FDomains[0].FMaximum = NaN; break;
        case 3: LRequest.FDomains = {}; break;
        case 4: LRequest.FProtected = [false,false,false,1]; break;
        case 5: LRequest.FSeed = Infinity; break;
      }
    end;
    Check(not ValidateTerrainRequest(LRequest, LReason), 'hostile JS request scalar/array rejects');
  end;
  LField := Field(2, 2, 1000, 0);
  LRequest := Request(LField);
  SetLength(LRequest.FDomains, 4);
  for I := 0 to 12 do
  begin
    LRejected := False;
    { Plain malformed records exercise the JavaScript boundary without
      corrupting the Pascal fixture's own record allocation/assignment. }
    asm
      var hostile = Object.assign({}, LRequest);
      hostile.FDomains = LRequest.FDomains.slice();
      hostile.FPrevious = Object.assign({}, LRequest.FPrevious);
      switch (I) {
        case 0: hostile.FDomains[0] = null; break;
        case 1: delete hostile.FDomains[0]; break;
        case 2: hostile.FDomains[0] = []; break;
        case 3: hostile.FSpec = null; break;
        case 4: hostile.FSpec = []; break;
        case 5: delete hostile.FSpec; break;
        case 6: hostile.FPrevious = null; break;
        case 7: hostile.FPrevious.FLevels = null; break;
        case 8: hostile.FPrevious.FLevels = {}; break;
        case 9: hostile = null; break;
        case 10: hostile = []; break;
        case 11: hostile.FPrevious = []; break;
        case 12: hostile.FDomains[0] = 'interval'; break;
      }
      LRejected = !pas['phanes.terrain.validate'].ValidateTerrainRequest(hostile, {
        get: function () { return ''; },
        set: function () {}
      });
    end;
    Check(LRejected, 'malformed nested JS records return false without throwing');
  end;
  {$endif}
end;

procedure AdmittedSizeChecks;
var
  LField: TTerrainField;
  LOutput: TTerrainField;
  LReplay: TTerrainField;
  LRequest: TTerrainRequest;
  LReason: String;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  { Actually solve both maximum dimensions and maximum value count. The
    larger combined benchmark belongs in the separate timing probe; these
    inexpensive regressions protect admitted limits in every ordinary run. }
  LField := Field(97, 97, 250, -4096000);
  LField.FSpec.FMinimumLevel := -7;
  LField.FSpec.FMaximumLevel := -7;
  LField.FSpec.FMaximumRise := 0;
  LRequest := Request(LField);
  Check(GenerateTerrain(LRequest, LOutput, LReason), 'maximum frame singleton solve: ' + LReason);
  Check(Length(LOutput.FLevels) = 9409, 'maximum frame decodes every vertex');
  Check(ValidateTerrainResult(LRequest, LOutput, LReason), 'maximum frame independently admitted');
  for I := 0 to High(LOutput.FLevels) do
  begin
    Check(LOutput.FLevels[I] = -7, 'singleton level preserved at maximum dimensions');
  end;

  LField := Field(7, 5, 250, 0);
  LField.FSpec.FMinimumLevel := -32;
  LField.FSpec.FMaximumLevel := 32;
  LField.FSpec.FMaximumRise := 2;
  LRequest := Request(LField);
  LRequest.FSeed := High(Cardinal);
  Check(GenerateTerrain(LRequest, LOutput, LReason), '65-level solve at maximum seed: ' + LReason);
  Check(GenerateTerrain(LRequest, LReplay, LReason), '65-level seeded replay resolves');
  Check(SameTerrainField(LOutput, LReplay), 'seed replay preserves decoded values and metrics');
  for LZ := 0 to 4 do
  begin
    for LX := 0 to 6 do
    begin
      I := LZ * 7 + LX;
      Check((LOutput.FLevels[I] >= -32) and (LOutput.FLevels[I] <= 32),
        'independent range oracle accepts decoded large palette');
      if LX > 0 then
      begin
        Check(Abs(LOutput.FLevels[I] - LOutput.FLevels[I - 1]) <= 2,
          'independent horizontal adjacency oracle');
      end;
      if LZ > 0 then
      begin
        Check(Abs(LOutput.FLevels[I] - LOutput.FLevels[I - 7]) <= 2,
          'independent vertical adjacency oracle');
      end;
    end;
  end;
end;

function RunTerrainCriticChecks: Integer;
begin
  GChecks := 0;
  GeometryChecks;
  ImmutabilityAndQueryChecks;
  GenerationChecks;
  AdmissionChecks;
  AdmittedSizeChecks;
  Result := GChecks;
end;

end.
