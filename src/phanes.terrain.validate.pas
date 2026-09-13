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

unit phanes.terrain.validate;

{$mode delphi}
{$H+}

interface

uses
  phanes.terrain.types;

function ValidateTerrainSpec(const ASpec: TTerrainSpec; out AReason: String): Boolean;
function ValidateTerrainField(const AField: TTerrainField; out AReason: String): Boolean;
function ValidateTerrainRequest(const ARequest: TTerrainRequest; out AReason: String): Boolean;
function ValidateTerrainResult(const ARequest: TTerrainRequest; const AField: TTerrainField;
  out AReason: String): Boolean;

implementation

uses
  SysUtils
  {$ifdef PAS2JS}
  , JS
  {$endif}
  ;

{$ifdef PAS2JS}
function TerrainRecord(const AValue: JSValue): Boolean;
begin
  Result := isObject(AValue) and (AValue <> nil) and not isArray(AValue);
end;
{$endif}

function ValidateTerrainSpec(const ASpec: TTerrainSpec; out AReason: String): Boolean;
begin
  Result := False;
  {$ifdef PAS2JS}
  AReason := 'Terrain frame fields must be finite integers.';
  if not TerrainRecord(ASpec) then
  begin
    Exit;
  end;
  if not isInteger(ASpec.FVersion) or not isInteger(ASpec.FColumns) or
    not isInteger(ASpec.FRows) or not isInteger(ASpec.FOriginX) or
    not isInteger(ASpec.FOriginZ) or not isInteger(ASpec.FSpacing) or
    not isInteger(ASpec.FLevelStep) or not isInteger(ASpec.FMinimumLevel) or
    not isInteger(ASpec.FMaximumLevel) or not isInteger(ASpec.FMaximumRise) then
  begin
    Exit;
  end;
  {$endif}
  AReason := 'Unsupported terrain field version.';
  if ASpec.FVersion <> TerrainFieldVersion then
  begin
    Exit;
  end;
  AReason := 'A terrain field needs 2 to 97 vertices per side.';
  if (ASpec.FColumns < 2) or (ASpec.FColumns > 97) or
    (ASpec.FRows < 2) or (ASpec.FRows > 97) then
  begin
    Exit;
  end;
  AReason := 'Terrain vertex spacing must be between 250 and 32000 millimetres.';
  if (ASpec.FSpacing < 250) or (ASpec.FSpacing > 32000) then
  begin
    Exit;
  end;
  AReason := 'The entire terrain frame must lie within 4096 metres of the origin.';
  if (ASpec.FOriginX < -TerrainMaximumCoordinateMm) or
    (ASpec.FOriginX > TerrainMaximumCoordinateMm) or
    (ASpec.FOriginZ < -TerrainMaximumCoordinateMm) or
    (ASpec.FOriginZ > TerrainMaximumCoordinateMm) then
  begin
    Exit;
  end;
  if (ASpec.FOriginX + (ASpec.FColumns - 1) * ASpec.FSpacing > TerrainMaximumCoordinateMm) or
    (ASpec.FOriginZ + (ASpec.FRows - 1) * ASpec.FSpacing > TerrainMaximumCoordinateMm) then
  begin
    Exit;
  end;
  AReason := 'Terrain needs 1 to 65 ordered elevation levels between -1024 and 1024.';
  if (ASpec.FMinimumLevel < -1024) or (ASpec.FMaximumLevel > 1024) or
    (ASpec.FMinimumLevel > ASpec.FMaximumLevel) or
    (ASpec.FMaximumLevel - ASpec.FMinimumLevel > 64) then
  begin
    Exit;
  end;
  AReason := 'Terrain elevation steps must be 1 to 8000 millimetres and heights within 512 metres.';
  if (ASpec.FLevelStep < 1) or (ASpec.FLevelStep > 8000) then
  begin
    Exit;
  end;
  if (Abs(ASpec.FMinimumLevel * ASpec.FLevelStep) > TerrainMaximumElevationMm) or
    (Abs(ASpec.FMaximumLevel * ASpec.FLevelStep) > TerrainMaximumElevationMm) then
  begin
    Exit;
  end;
  AReason := 'Terrain maximum rise must be a nonnegative number of available levels.';
  if (ASpec.FMaximumRise < 0) or
    (ASpec.FMaximumRise > ASpec.FMaximumLevel - ASpec.FMinimumLevel) then
  begin
    Exit;
  end;
  AReason := '';
  Result := True;
end;

function ValidateTerrainField(const AField: TTerrainField; out AReason: String): Boolean;
var
  LX: Integer;
  LZ: Integer;
  LIndex: Integer;
  LValue: Integer;
begin
  Result := False;
  {$ifdef PAS2JS}
  AReason := 'A terrain field must be a record.';
  if not TerrainRecord(AField) then
  begin
    Exit;
  end;
  {$endif}
  if not ValidateTerrainSpec(AField.FSpec, AReason) then
  begin
    Exit;
  end;
  {$ifdef PAS2JS}
  AReason := 'Terrain heights require an array; seed and solver counters require finite integers.';
  if not isArray(AField.FLevels) or not isInteger(AField.FSeed) or
    (Double(AField.FSeed) < 0) or (Double(AField.FSeed) > 4294967295) or
    not isInteger(AField.FDecisions) or not isInteger(AField.FPropagations) or
    not isInteger(AField.FBacktracks) or (AField.FDecisions > High(Integer)) or
    (AField.FPropagations > High(Integer)) or (AField.FBacktracks > High(Integer)) then
  begin
    Exit;
  end;
  {$endif}
  AReason := 'The terrain elevation array does not match its vertex frame.';
  if Length(AField.FLevels) <> AField.FSpec.FColumns * AField.FSpec.FRows then
  begin
    Exit;
  end;
  AReason := 'Terrain solver counters cannot be negative.';
  if (AField.FDecisions < 0) or (AField.FPropagations < 0) or (AField.FBacktracks < 0) then
  begin
    Exit;
  end;
  { Independent decoded checks: no graph, token decoder or rule builder is
    involved. Validate ranges before subtraction so malformed integers cannot
    wrap the neighbor difference on native targets. }
  for LIndex := 0 to High(AField.FLevels) do
  begin
    LValue := AField.FLevels[LIndex];
    {$ifdef PAS2JS}
    if not isInteger(LValue) then
    begin
      AReason := 'Terrain vertex levels must be finite integers.';
      Exit;
    end;
    {$endif}
    if (LValue < AField.FSpec.FMinimumLevel) or (LValue > AField.FSpec.FMaximumLevel) then
    begin
      AReason := 'A terrain vertex is outside the admitted elevation levels.';
      Exit;
    end;
  end;
  for LZ := 0 to AField.FSpec.FRows - 1 do
  begin
    for LX := 0 to AField.FSpec.FColumns - 1 do
    begin
      LIndex := LZ * AField.FSpec.FColumns + LX;
      LValue := AField.FLevels[LIndex];
      AReason := 'Adjacent terrain vertices exceed the maximum rise.';
      if (LX > 0) and (Abs(LValue - AField.FLevels[LIndex - 1]) > AField.FSpec.FMaximumRise) then
      begin
        Exit;
      end;
      if (LZ > 0) and
        (Abs(LValue - AField.FLevels[LIndex - AField.FSpec.FColumns]) > AField.FSpec.FMaximumRise) then
      begin
        Exit;
      end;
    end;
  end;
  AReason := '';
  Result := True;
end;

function ValidateTerrainRequest(const ARequest: TTerrainRequest; out AReason: String): Boolean;
var
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  {$ifdef PAS2JS}
  AReason := 'Terrain requests need request and previous-field records.';
  if not TerrainRecord(ARequest) then
  begin
    Exit;
  end;
  if not TerrainRecord(ARequest.FPrevious) then
  begin
    Exit;
  end;
  if not isArray(ARequest.FPrevious.FLevels) then
  begin
    Exit;
  end;
  {$endif}
  if not ValidateTerrainSpec(ARequest.FSpec, AReason) then
  begin
    Exit;
  end;
  {$ifdef PAS2JS}
  AReason := 'Terrain request fields need finite integers, Boolean preservation and vertex arrays.';
  if not isInteger(ARequest.FSeed) or (Double(ARequest.FSeed) < 0) or
    (Double(ARequest.FSeed) > 4294967295) or not isInteger(ARequest.FX) or
    not isInteger(ARequest.FZ) or not isInteger(ARequest.FWidth) or
    not isInteger(ARequest.FDepth) or not isInteger(ARequest.FMaxBacktracks) or
    not isBoolean(ARequest.FHasPrevious) or not isArray(ARequest.FDomains) or
    not isArray(ARequest.FProtected) then
  begin
    Exit;
  end;
  {$endif}
  AReason := 'Terrain selection must be a nonempty cell rectangle inside the field.';
  if (ARequest.FX < 0) or (ARequest.FZ < 0) or
    (ARequest.FWidth < 1) or (ARequest.FDepth < 1) or
    (ARequest.FWidth >= ARequest.FSpec.FColumns) or
    (ARequest.FDepth >= ARequest.FSpec.FRows) or
    (ARequest.FX > ARequest.FSpec.FColumns - 1 - ARequest.FWidth) or
    (ARequest.FZ > ARequest.FSpec.FRows - 1 - ARequest.FDepth) then
  begin
    Exit;
  end;
  AReason := 'Terrain search allowance must be between zero and 4096 backtracks.';
  if (ARequest.FMaxBacktracks < 0) or (ARequest.FMaxBacktracks > 4096) then
  begin
    Exit;
  end;
  LCount := ARequest.FSpec.FColumns * ARequest.FSpec.FRows;
  AReason := 'Terrain domains must cover every vertex when supplied.';
  if (Length(ARequest.FDomains) <> 0) and (Length(ARequest.FDomains) <> LCount) then
  begin
    Exit;
  end;
  AReason := 'Terrain protection must cover every vertex when supplied.';
  if (Length(ARequest.FProtected) <> 0) and (Length(ARequest.FProtected) <> LCount) then
  begin
    Exit;
  end;
  {$ifdef PAS2JS}
  AReason := 'Terrain vertex protection values must be Boolean.';
  for I := 0 to High(ARequest.FProtected) do
  begin
    if not isBoolean(ARequest.FProtected[I]) then
    begin
      Exit;
    end;
  end;
  {$endif}
  for I := 0 to High(ARequest.FDomains) do
  begin
    AReason := 'Terrain domains must be nonempty ordered intervals within the field levels.';
    {$ifdef PAS2JS}
    if not TerrainRecord(ARequest.FDomains[I]) then
    begin
      Exit;
    end;
    if not isInteger(ARequest.FDomains[I].FMinimum) or
      not isInteger(ARequest.FDomains[I].FMaximum) then
    begin
      Exit;
    end;
    {$endif}
    if (ARequest.FDomains[I].FMinimum < ARequest.FSpec.FMinimumLevel) or
      (ARequest.FDomains[I].FMaximum > ARequest.FSpec.FMaximumLevel) or
      (ARequest.FDomains[I].FMinimum > ARequest.FDomains[I].FMaximum) then
    begin
      Exit;
    end;
  end;
  if ARequest.FHasPrevious then
  begin
    if not ValidateTerrainField(ARequest.FPrevious, AReason) then
    begin
      AReason := 'Invalid previous terrain: ' + AReason;
      Exit;
    end;
    AReason := 'A terrain repair must keep its saved frame and elevation contract.';
    if not SameTerrainSpec(ARequest.FSpec, ARequest.FPrevious.FSpec) then
    begin
      Exit;
    end;
  end
  else
  begin
    AReason := 'Creating terrain requires the whole field selection and no saved or protected vertices.';
    if (ARequest.FX <> 0) or (ARequest.FZ <> 0) or
      (ARequest.FWidth <> ARequest.FSpec.FColumns - 1) or
      (ARequest.FDepth <> ARequest.FSpec.FRows - 1) or
      (Length(ARequest.FPrevious.FLevels) <> 0) or (Length(ARequest.FProtected) <> 0) then
    begin
      Exit;
    end;
  end;
  AReason := '';
  Result := True;
end;

function ValidateTerrainResult(const ARequest: TTerrainRequest; const AField: TTerrainField;
  out AReason: String): Boolean;
var
  LX: Integer;
  LZ: Integer;
  LIndex: Integer;
  LPreserved: Boolean;
  LChanged: Boolean;
begin
  Result := False;
  if not ValidateTerrainRequest(ARequest, AReason) or
    not ValidateTerrainField(AField, AReason) then
  begin
    Exit;
  end;
  AReason := 'The terrain result changed its requested frame.';
  if not SameTerrainSpec(ARequest.FSpec, AField.FSpec) then
  begin
    Exit;
  end;
  LChanged := not ARequest.FHasPrevious;
  for LZ := 0 to AField.FSpec.FRows - 1 do
  begin
    for LX := 0 to AField.FSpec.FColumns - 1 do
    begin
      LIndex := LZ * AField.FSpec.FColumns + LX;
      if ARequest.FHasPrevious then
      begin
        LChanged := LChanged or (AField.FLevels[LIndex] <> ARequest.FPrevious.FLevels[LIndex]);
      end;
      if Length(ARequest.FDomains) > 0 then
      begin
        AReason := 'A terrain result violates its caller elevation interval.';
        if (AField.FLevels[LIndex] < ARequest.FDomains[LIndex].FMinimum) or
          (AField.FLevels[LIndex] > ARequest.FDomains[LIndex].FMaximum) then
        begin
          Exit;
        end;
      end;
      { Spell out preservation independently from the solver helper. A shared
        definition of the field does not mean sharing its acceptance logic. }
      LPreserved := (LX <= ARequest.FX) or (LZ <= ARequest.FZ) or
        (LX >= ARequest.FX + ARequest.FWidth) or (LZ >= ARequest.FZ + ARequest.FDepth);
      if Length(ARequest.FProtected) > 0 then
      begin
        LPreserved := LPreserved or ARequest.FProtected[LIndex];
      end;
      if ARequest.FHasPrevious and LPreserved then
      begin
        AReason := 'A terrain repair changed a protected or outside-surface vertex.';
        if AField.FLevels[LIndex] <> ARequest.FPrevious.FLevels[LIndex] then
        begin
          Exit;
        end;
      end;
    end;
  end;
  AReason := 'An unchanged terrain result must preserve the complete saved field.';
  if not LChanged and not SameTerrainField(AField, ARequest.FPrevious) then
  begin
    Exit;
  end;
  AReason := 'A changed terrain result must use the requested seed.';
  if LChanged and (AField.FSeed <> ARequest.FSeed) then
  begin
    Exit;
  end;
  AReason := '';
  Result := True;
end;

end.
