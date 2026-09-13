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

program PhanesTerrainChecks;
{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  phanes.terrain.types,
  phanes.terrain.validate,
  phanes.terrain.generate,
  phanes.terrain.surface,
  phanes.tests.terrain.critic;

var
  GChecks: Integer;
  GReason: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage + ': ' + GReason);
  end;
end;

function Request(const AColumns, ARows: Integer): TTerrainRequest;
begin
  Result := Default(TTerrainRequest);
  Result.FSpec.FVersion := 1;
  Result.FSpec.FColumns := AColumns;
  Result.FSpec.FRows := ARows;
  Result.FSpec.FSpacing := 1000;
  Result.FSpec.FLevelStep := 1000;
  Result.FSpec.FMinimumLevel := 0;
  Result.FSpec.FMaximumLevel := 8;
  Result.FSpec.FMaximumRise := 2;
  Result.FWidth := AColumns - 1;
  Result.FDepth := ARows - 1;
  Result.FSeed := 24719;
  Result.FMaxBacktracks := 64;
end;

function EqualLevels(const ALeft, ARight: TTerrainField): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(ALeft.FLevels) <> Length(ARight.FLevels) then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft.FLevels) do
  begin
    if ALeft.FLevels[I] <> ARight.FLevels[I] then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function ReplaySignature(const AField: TTerrainField): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AField.FLevels) do
  begin
    Result := Result + IntToStr(AField.FLevels[I]) + ',';
  end;
end;

procedure AllBinaryDomains;
var
  LRequest: TTerrainRequest;
  LField: TTerrainField;
  LBefore: TTerrainField;
  LCase: Integer;
  LCode: Integer;
  LMask: Integer;
  LRise: Integer;
  LValues: array[0..3] of Integer;
  LFeasible: Boolean;
  LFits: Boolean;
  LSolved: Boolean;
  I: Integer;
begin
  LRequest := Request(2, 2);
  LField := Default(TTerrainField);
  LRequest.FSpec.FMaximumLevel := 1;
  SetLength(LRequest.FDomains, 4);
  for LRise := 0 to 1 do
  begin
    LRequest.FSpec.FMaximumRise := LRise;
    for LCase := 0 to 80 do
    begin
      LCode := LCase;
      for I := 0 to 3 do
      begin
        case LCode mod 3 of
          0:
            begin
              LRequest.FDomains[I].FMinimum := 0;
              LRequest.FDomains[I].FMaximum := 0;
            end;
          1:
            begin
              LRequest.FDomains[I].FMinimum := 1;
              LRequest.FDomains[I].FMaximum := 1;
            end;
          2:
            begin
              LRequest.FDomains[I].FMinimum := 0;
              LRequest.FDomains[I].FMaximum := 1;
            end;
        end;
        LCode := LCode div 3;
      end;
      { Exhaustive oracle over the actual four-corner square, independent
        of WFC direction conventions, graph helpers or result validation. }
      LFeasible := False;
      for LMask := 0 to 15 do
      begin
        LFits := True;
        for I := 0 to 3 do
        begin
          LValues[I] := (LMask shr I) and 1;
          LFits := LFits and (LValues[I] >= LRequest.FDomains[I].FMinimum) and
            (LValues[I] <= LRequest.FDomains[I].FMaximum);
        end;
        LFits := LFits and (Abs(LValues[0] - LValues[1]) <= LRise) and
          (Abs(LValues[0] - LValues[2]) <= LRise) and
          (Abs(LValues[1] - LValues[3]) <= LRise) and
          (Abs(LValues[2] - LValues[3]) <= LRise);
        LFeasible := LFeasible or LFits;
      end;
      LBefore := CopyTerrainField(LField);
      LSolved := GenerateTerrain(LRequest, LField, GReason);
      Check(LSolved = LFeasible, 'Exhaustive binary square feasibility ' + IntToStr(LCase));
      if LSolved then
      begin
        Check(ValidateTerrainResult(LRequest, LField, GReason), 'Exhaustive result admitted');
      end
      else
      begin
        Check(EqualLevels(LBefore, LField) and SameTerrainSpec(LBefore.FSpec, LField.FSpec),
          'Failed exhaustive case preserves committed output');
      end;
    end;
  end;
end;

procedure Contracts;
var
  LRequest: TTerrainRequest;
  LBad: TTerrainRequest;
  LField: TTerrainField;
  LChanged: TTerrainField;
  LSurface: TTerrainSurface;
  LRejected: Boolean;
  I: Integer;
begin
  LRequest := Request(4, 3);
  LRequest.FSpec.FMinimumLevel := 2;
  LRequest.FSpec.FMaximumLevel := 5;
  Check(GenerateTerrain(LRequest, LField, GReason), 'Fresh frame with no zero level');
  for I := 0 to High(LField.FLevels) do
  begin
    Check(LField.FLevels[I] >= 2, 'Fresh boundary vertices are solved, not default zero');
  end;
  LChanged := CopyTerrainField(LField);
  LChanged.FLevels[0] := High(Integer);
  Check(not ValidateTerrainField(LChanged, GReason), 'Out of range height rejected before subtraction');
  LChanged := CopyTerrainField(LField);
  LChanged.FLevels[0] := 2;
  LChanged.FLevels[1] := 5;
  Check(not ValidateTerrainField(LChanged, GReason), 'Decoded excess rise rejected');
  LChanged := CopyTerrainField(LField);
  SetLength(LChanged.FLevels, 2);
  Check(not ValidateTerrainField(LChanged, GReason), 'Incomplete height array rejected');
  LSurface := nil;
  LRejected := False;
  try
    LSurface := TTerrainSurface.Create(LChanged);
  except
    on LException: EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  LSurface.Free;
  Check(LRejected, 'Sampling malformed field rejected at construction');

  for I := 0 to 17 do
  begin
    LBad := LRequest;
    case I of
      0:
        begin
          LBad.FSpec.FVersion := 2;
        end;
      1:
        begin
          LBad.FSpec.FColumns := 1;
        end;
      2:
        begin
          LBad.FSpec.FRows := 98;
        end;
      3:
        begin
          LBad.FSpec.FSpacing := 249;
        end;
      4:
        begin
          LBad.FSpec.FOriginX := High(Integer);
        end;
      5:
        begin
          LBad.FSpec.FOriginZ := TerrainMaximumCoordinateMm;
        end;
      6:
        begin
          LBad.FSpec.FLevelStep := 0;
        end;
      7:
        begin
          LBad.FSpec.FMinimumLevel := Low(Integer);
        end;
      8:
        begin
          LBad.FSpec.FMaximumLevel := High(Integer);
        end;
      9:
        begin
          LBad.FSpec.FMaximumRise := -1;
        end;
      10:
        begin
          LBad.FWidth := High(Integer);
        end;
      11:
        begin
          LBad.FX := High(Integer);
        end;
      12:
        begin
          LBad.FMaxBacktracks := 4097;
        end;
      13:
        begin
          SetLength(LBad.FDomains, 1);
        end;
      14:
        begin
          SetLength(LBad.FProtected, 1);
        end;
      15:
        begin
          LBad.FHasPrevious := True;
        end;
      16:
        begin
          LBad.FPrevious := LField;
        end;
      17:
        begin
          LBad.FWidth := 1;
        end;
    end;
    LChanged := CopyTerrainField(LField);
    Check(not GenerateTerrain(LBad, LChanged, GReason), 'Malformed request rejected ' + IntToStr(I));
    Check(EqualLevels(LChanged, LField), 'Malformed request leaves output intact');
  end;

  LBad := LRequest;
  SetLength(LBad.FDomains, 12);
  for I := 0 to High(LBad.FDomains) do
  begin
    LBad.FDomains[I].FMinimum := 2;
    LBad.FDomains[I].FMaximum := 5;
  end;
  LBad.FDomains[3].FMinimum := 6;
  Check(not ValidateTerrainRequest(LBad, GReason), 'Empty domain rejected');
  LBad.FDomains[3].FMinimum := 1;
  Check(not ValidateTerrainRequest(LBad, GReason), 'Out of contract domain rejected');
end;

procedure Repair;
var
  LRequest: TTerrainRequest;
  LBefore: TTerrainField;
  LAfter: TTerrainField;
  LRejected: TTerrainField;
  LOldSurface: TTerrainSurface;
  LNewSurface: TTerrainSurface;
  LX: Integer;
  LZ: Integer;
  I: Integer;
  LOutside: Boolean;
begin
  LRequest := Request(7, 7);
  LBefore := Default(TTerrainField);
  LBefore.FSpec := LRequest.FSpec;
  SetLength(LBefore.FLevels, 49);
  LRequest.FHasPrevious := True;
  LRequest.FPrevious := LBefore;
  LRequest.FX := 1;
  LRequest.FZ := 1;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  SetLength(LRequest.FProtected, 49);
  LRequest.FProtected[3 * 7 + 3] := True;
  SetLength(LRequest.FDomains, 49);
  for I := 0 to 48 do
  begin
    LRequest.FDomains[I].FMinimum := 0;
    LRequest.FDomains[I].FMaximum := 8;
  end;
  LRequest.FDomains[2 * 7 + 2].FMinimum := 2;
  LRequest.FDomains[2 * 7 + 2].FMaximum := 2;
  Check(GenerateTerrain(LRequest, LAfter, GReason), 'Repair with protected island');
  Check(LAfter.FLevels[16] = 2, 'Requested summit retained');
  Check(LAfter.FLevels[24] = 0, 'Protected interior vertex retained');
  Check(LBefore.FLevels[16] = 0, 'Baseline storage was not mutated');
  LOldSurface := TTerrainSurface.Create(LBefore);
  LNewSurface := TTerrainSurface.Create(LAfter);
  try
    for LZ := 0 to 48 do
    begin
      for LX := 0 to 48 do
      begin
        LOutside := (LX <= 8) or (LX >= 40) or (LZ <= 8) or (LZ >= 40);
        if LOutside then
        begin
          Check(Abs(LOldSurface.Height(LX / 8, LZ / 8) -
            LNewSurface.Height(LX / 8, LZ / 8)) < 1E-12,
            'Actual triangle surface preserved outside selection');
        end;
      end;
    end;
  finally
    LNewSurface.Free;
    LOldSurface.Free;
  end;
  LRejected := CopyTerrainField(LAfter);
  LRejected.FLevels[0] := 1;
  Check(not ValidateTerrainResult(LRequest, LRejected, GReason), 'Decoder detects outside change');
  LRejected := CopyTerrainField(LAfter);
  LRejected.FLevels[24] := 1;
  Check(not ValidateTerrainResult(LRequest, LRejected, GReason), 'Decoder detects protected change');
  LRejected := CopyTerrainField(LAfter);
  LRejected.FLevels[16] := 1;
  Check(not ValidateTerrainResult(LRequest, LRejected, GReason), 'Decoder detects intent violation');
  LRejected := CopyTerrainField(LAfter);
  Inc(LRejected.FSeed);
  Check(not ValidateTerrainResult(LRequest, LRejected, GReason), 'Decoder detects changed seed');

  LRequest.FDomains[0].FMinimum := 1;
  Check(not GenerateTerrain(LRequest, LRequest.FPrevious, GReason), 'Aliased conflict rejected');
  Check(EqualLevels(LRequest.FPrevious, LBefore), 'Aliased failure retains full baseline');
  LRequest.FDomains := nil;
  LRequest.FWidth := 1;
  Check(GenerateTerrain(LRequest, LAfter, GReason), 'One-cell strip is an explicit unchanged result');
  Check(SameTerrainField(LAfter, LBefore) and (Pos('no height changed', GReason) > 0),
    'No mutable vertices are reported honestly');
  LRequest.FWidth := 4;
  Check(GenerateTerrain(LRequest, LRequest.FPrevious, GReason), 'Aliased successful output admitted');
  Check(ValidateTerrainField(LRequest.FPrevious, GReason), 'Aliased output valid');
end;

procedure Surface;
var
  LRequest: TTerrainRequest;
  LField: TTerrainField;
  LSurface: TTerrainSurface;
  LMinimum: Double;
  LMaximum: Double;
  LDX: Double;
  LDZ: Double;
  LHeight: Double;
  LRejected: Boolean;
  LX: Double;
  LZ: Double;
  I: Integer;
  J: Integer;
begin
  LRequest := Request(2, 2);
  LField := Default(TTerrainField);
  LField.FSpec := LRequest.FSpec;
  LField.FLevels := [0, 1, 1, 0];
  LSurface := TTerrainSurface.Create(LField);
  try
    Check(Abs(LSurface.Height(0.5, 0.5) - 1) < 1E-12, 'Saddle follows rendered anti-diagonal');
    LSurface.Bounds(0.25, 0.25, 0.75, 0.75, LMinimum, LMaximum, LDX, LDZ);
    Check((Abs(LMinimum - 0.5) < 2 * TerrainHeightToleranceMetres) and
      (Abs(LMaximum - 1) < 2 * TerrainHeightToleranceMetres),
      'Interior diagonal extremum included in clipped bounds');
    Check((Abs(LDX - 1) < 2E-9) and (Abs(LDZ - 1) < 2E-9), 'Triangle derivative envelope');
    LField.FLevels[0] := 4;
    Check(LSurface.Height(0, 0) = 0, 'Surface owns detached immutable snapshot');
    for I := 0 to 6 do
    begin
      LX := 0;
      LZ := 0;
      case I of
        0:
          begin
            LX := -0.00001;
          end;
        1:
          begin
            LZ := 1.00001;
          end;
        2:
          begin
            LX := NaN;
          end;
        3:
          begin
            LZ := Infinity;
          end;
        4:
          begin
            LX := -Infinity;
          end;
        5:
          begin
            LX := 1E100;
          end;
        6:
          begin
            LZ := -1E100;
          end;
      end;
      LRejected := False;
      try
        LHeight := LSurface.Height(LX, LZ);
      except
        on LException: EArgumentException do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Invalid surface point rejected ' + IntToStr(I));
    end;
    LRejected := False;
    try
      LSurface.Bounds(0.9, 0, 0.1, 1, LMinimum, LMaximum, LDX, LDZ);
    except
      on LException: EArgumentException do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Inverted surface rectangle rejected');
  finally
    LSurface.Free;
  end;
  LRequest := Request(3, 3);
  LField.FSpec := LRequest.FSpec;
  LField.FLevels := [0, 1, 0, 1, 2, 1, 0, 1, 0];
  LSurface := TTerrainSurface.Create(LField);
  try
    LSurface.Bounds(0, 0, 2, 2, LMinimum, LMaximum, LDX, LDZ);
    Check(Abs(LMaximum - 2) < 2 * TerrainHeightToleranceMetres,
      'Bounds find grid peak missed by rectangle corners');
    for I := 0 to 20 do
    begin
      for J := 0 to 20 do
      begin
        LHeight := LSurface.Height(I / 10, J / 10);
        Check((LHeight >= LMinimum) and (LHeight <= LMaximum), 'Grid peak range contains surface');
      end;
    end;
  finally
    LSurface.Free;
  end;
  LRequest := Request(3, 2);
  LField.FSpec := LRequest.FSpec;
  LField.FLevels := [0, 1, 3, 0, 1, 3];
  LSurface := TTerrainSurface.Create(LField);
  try
    LSurface.Bounds(1, 0.5, 1, 0.5, LMinimum, LMaximum, LDX, LDZ);
    Check((Abs(LDX - 2) < 2E-9) and (LDZ < 2E-9), 'Point on crease includes both one-sided slopes');
    LSurface.Bounds(0, 0, 0, 0, LMinimum, LMaximum, LDX, LDZ);
    Check((Abs(LMinimum) < 2 * TerrainHeightToleranceMetres) and
      (Abs(LMaximum) < 2 * TerrainHeightToleranceMetres), 'Degenerate world corner range');
  finally
    LSurface.Free;
  end;
end;

procedure ReplayAndBounds;
var
  LRequest: TTerrainRequest;
  LField: TTerrainField;
  LAgain: TTerrainField;
  LSurface: TTerrainSurface;
  LMinimum: Double;
  LMaximum: Double;
  LDX: Double;
  LDZ: Double;
  LHeight: Double;
  LX: Double;
  LZ: Double;
  LChanged: Boolean;
  LSeed: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LRequest := Request(9, 7);
  LRequest.FSpec.FSpacing := 3000;
  LRequest.FSpec.FOriginX := -11200;
  LRequest.FSpec.FOriginZ := -850;
  Check(GenerateTerrain(LRequest, LField, GReason), 'Replay baseline');
  Check(GenerateTerrain(LRequest, LAgain, GReason), 'Replay repeated');
  Check(EqualLevels(LField, LAgain), 'Same request produces exact same heights');
  WriteLn('Terrain replay signature: ', ReplaySignature(LField));
  Check(ReplaySignature(LField) =
    '5,5,3,2,3,3,5,4,3,3,4,3,4,4,4,5,5,3,1,2,2,4,3,2,4,5,3,0,2,0,2,3,' +
    '4,2,4,4,1,3,1,0,2,3,1,3,3,0,2,2,1,0,2,1,2,2,0,0,1,2,2,1,1,0,2,',
    'Pinned native/browser/WASM replay fixture');
  LChanged := False;
  for LSeed := 1 to 12 do
  begin
    LRequest.FSeed := LSeed;
    Check(GenerateTerrain(LRequest, LAgain, GReason), 'Different seed solved');
    LChanged := LChanged or not EqualLevels(LField, LAgain);
    LSurface := TTerrainSurface.Create(LAgain);
    try
      for I := 0 to 14 do
      begin
        LX := -11.2 + I * 1.5;
        LZ := -0.85 + (I mod 7) * 2.5;
        LSurface.Bounds(LX, LZ, LX + 2.5, LZ + 2.5, LMinimum, LMaximum, LDX, LDZ);
        for J := 0 to 10 do
        begin
          for K := 0 to 10 do
          begin
            LHeight := LSurface.Height(LX + J / 4, LZ + K / 4);
            Check((LHeight >= LMinimum) and (LHeight <= LMaximum),
              'Clipped multicell bound contains independently sampled heights');
            if J < 10 then
            begin
              Check(Abs(LSurface.Height(LX + (J + 1) / 4, LZ + K / 4) -
                LHeight) <= LDX / 4 + 1E-9, 'X derivative bounds secant across creases ' +
                IntToStr(LSeed) + '/' + IntToStr(I) + '/' + IntToStr(J) + '/' + IntToStr(K) +
                ' delta=' + FloatToStr(Abs(LSurface.Height(LX + (J + 1) / 4, LZ + K / 4) -
                LHeight)) + ' bound=' + FloatToStr(LDX / 4));
            end;
            if K < 10 then
            begin
              Check(Abs(LSurface.Height(LX + J / 4, LZ + (K + 1) / 4) -
                LHeight) <= LDZ / 4 + 1E-9, 'Z derivative bounds secant across creases');
            end;
          end;
        end;
      end;
    finally
      LSurface.Free;
    end;
  end;
  Check(LChanged, 'Different seeds produce different landforms');
end;

begin
  AllBinaryDomains;
  Contracts;
  Repair;
  Surface;
  ReplayAndBounds;
  WriteLn('PASS: ', GChecks, ' terrain core checks');
  WriteLn('PASS: ', RunTerrainCriticChecks, ' independent terrain critic checks');
end.
