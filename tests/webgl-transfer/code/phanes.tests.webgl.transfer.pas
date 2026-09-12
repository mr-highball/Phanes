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

unit phanes.tests.webgl.transfer;

{$mode delphi}
{$H+}

interface

implementation

uses
  SysUtils,
  Math,
  JOB.JS,
  CastleWindow,
  CastleVectors,
  CastleUtils,
  CastleInternalWebGL;

var
  GWindow: TCastleWindow;
  GChecks: Integer;
  GLegacyChecks: Integer;
  GBoundaryChecks: Integer;

type
  TBoundaryInt32List = class(CastleUtils.TInt32List)
  public
    procedure InjectCount(const ACount: Integer);
  end;

  TBoundaryMatrix4List = class(TMatrix4List)
  public
    procedure InjectCount(const ACount: Integer);
  end;

procedure TBoundaryInt32List.InjectCount(const ACount: Integer);
begin
  FLength := ACount;
end;

procedure TBoundaryMatrix4List.InjectCount(const ACount: Integer);
begin
  FLength := ACount;
end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Floats(const AActual: IJSFloat32Array; const AExpected: array of Single);
var
  LBits: Cardinal;
  LValue: Single;
  LActualBits: Cardinal;
  I: Integer;
begin
  Check(AActual.Length = Length(AExpected), 'Exact float array length');
  for I := 0 to High(AExpected) do
  begin
    LValue := AActual[I];
    if IsNan(AExpected[I]) then
    begin
      Check(IsNan(LValue), 'NaN remains NaN');
    end
    else
    begin
      Move(AExpected[I], LBits, SizeOf(LBits));
      Move(LValue, LActualBits, SizeOf(LActualBits));
      Check(LBits = LActualBits, 'Exact scalar order, precision and sign');
    end;
  end;
end;

{$ifdef PHANES_WEBGL_SIGNED_RANGE_GUARD}
procedure ExpectInt32RangeError(const AList: TBoundaryInt32List;
  const ACount: Integer);
var
  LMessageMatches: Boolean;
  LRejected: Boolean;
  LResult: IJSInt32Array;
begin
  LMessageMatches := false;
  LRejected := false;
  AList.InjectCount(ACount);
  try
    try
      LResult := ListToWebGL(AList);
    except
      on LException: ERangeError do
      begin
        LRejected := true;
        LMessageMatches := LException.Message =
          'WebGL uniform array exceeds the JOB signed byte range';
      end;
    end;
  finally
    AList.InjectCount(0);
  end;
  Check(LRejected, 'Int32 list rejects the signed byte boundary before allocation');
  Check(LMessageMatches, 'Int32 boundary reports the signed JOB byte range');
end;

procedure ExpectMatrix4RangeError(const AList: TBoundaryMatrix4List;
  const ACount: Integer; const ACase: String);
var
  LMessageMatches: Boolean;
  LRejected: Boolean;
  LResult: IJSFloat32Array;
begin
  LMessageMatches := false;
  LRejected := false;
  AList.InjectCount(ACount);
  try
    try
      LResult := ListToWebGL(AList);
    except
      on LException: ERangeError do
      begin
        LRejected := true;
        LMessageMatches := LException.Message =
          'WebGL uniform array exceeds the JOB signed byte range';
      end;
    end;
  finally
    AList.InjectCount(0);
  end;
  Check(LRejected, ACase + ' rejects before allocation');
  Check(LMessageMatches, ACase + ' reports the signed JOB byte range');
end;

procedure CheckSignedByteBoundary;
const
  SignedByteMaximum = QWord($7FFFFFFF);
  SignedByteFirstInvalid = QWord($80000000);
  Int32BoundaryCount = 536870912;
  Matrix4LastValidCount = 33554431;
  Matrix4BoundaryCount = 33554432;
  Matrix4NextCount = 33554433;
var
  LInt32List: TBoundaryInt32List;
  LMatrix4List: TBoundaryMatrix4List;
begin
  { The last-valid calculation is arithmetic-only: materializing its array would
    need almost 2 GiB. The rejected cases below call the real public overloads
    with synthetic logical counts and restore them before freeing the fixtures. }
  Check(QWord(Matrix4LastValidCount) * 16 * SizeOf(Single) =
    SignedByteMaximum - 63, 'Matrix4 last-valid byte count stays signed');
  Check(QWord(Matrix4BoundaryCount) * 16 * SizeOf(Single) =
    SignedByteFirstInvalid, 'Matrix4 boundary byte count is exactly 2 GiB');
  Check(QWord(Matrix4NextCount) * 16 * SizeOf(Single) =
    SignedByteFirstInvalid + 64, 'Matrix4 next count advances by one record');
  Check(QWord(Int32BoundaryCount) * SizeOf(Int32) =
    SignedByteFirstInvalid, 'Int32 boundary byte count is exactly 2 GiB');
  Check(QWord(High(Integer)) * 16 * SizeOf(Single) = QWord($1FFFFFFFC0),
    'Wide multiplication does not wrap at the largest list count');

  LInt32List := TBoundaryInt32List.Create;
  LMatrix4List := TBoundaryMatrix4List.Create;
  try
    ExpectInt32RangeError(LInt32List, Int32BoundaryCount);
    ExpectMatrix4RangeError(LMatrix4List, Matrix4BoundaryCount,
      'Matrix4 exact signed boundary');
    ExpectMatrix4RangeError(LMatrix4List, Matrix4NextCount,
      'Matrix4 count after signed boundary');
    ExpectMatrix4RangeError(LMatrix4List, High(Integer),
      'Matrix4 largest count');
  finally
    LInt32List.Free;
    LMatrix4List.Free;
  end;
end;
{$endif}

procedure RunChecks;
var
  LM2: TMatrix2;
  LM3: TMatrix3;
  LM4: TMatrix4;
  LFloat: IJSFloat32Array;
  LKeep: IJSFloat32Array;
  LInteger: IJSInt32Array;
  LS: CastleUtils.TSingleList;
  LI: CastleUtils.TInt32List;
  LV2: TVector2List;
  LV3: TVector3List;
  LV4: TVector4List;
  LM3List: TMatrix3List;
  LM4List: TMatrix4List;
  LExpected: array of Single;
  LScalars: array[0..7] of Single;
  LBitPatterns: array[0..7] of Cardinal;
  LBeforePages: LongWord;
  LStart: QWord;
  LEnd: QWord;
  LBrowser: TJSObject;
  I: Integer;
  J: Integer;
  K: Integer;
  N: Integer;
begin
  for I := 0 to 3 do
  begin
    for J := 0 to 3 do
    begin
      LM4[I, J] := I * 7 - J * 0.125 - 3;
      if (I < 3) and (J < 3) then
      begin
        LM3[I, J] := LM4[I, J];
      end;
      if (I < 2) and (J < 2) then
      begin
        LM2[I, J] := LM4[I, J];
      end;
    end;
  end;
  Floats(MatrixToWebGL(LM2), [-3, -3.125, 4, 3.875]);
  Floats(MatrixToWebGL(LM3), [-3, -3.125, -3.25, 4, 3.875, 3.75, 11, 10.875, 10.75]);
  Floats(MatrixToWebGL(LM4), [-3, -3.125, -3.25, -3.375,
    4, 3.875, 3.75, 3.625, 11, 10.875, 10.75, 10.625, 18, 17.875, 17.75, 17.625]);
  LKeep := MatrixToWebGL(LM4);
  LM4[0, 0] := 451;
  Check(LKeep[0] = -3, 'Matrix result owns a snapshot');
  LKeep[1] := 123;
  Check(LM4[0, 1] = -3.125, 'Result writes do not mutate the Pascal source');

  LS := CastleUtils.TSingleList.Create;
  LI := CastleUtils.TInt32List.Create;
  LV2 := TVector2List.Create;
  LV3 := TVector3List.Create;
  LV4 := TVector4List.Create;
  LM3List := TMatrix3List.Create;
  LM4List := TMatrix4List.Create;
  try
    LS.Capacity := 512;
    LI.Capacity := 512;
    LV2.Capacity := 512;
    LV3.Capacity := 512;
    LV4.Capacity := 512;
    LM3List.Capacity := 512;
    LM4List.Capacity := 512;
    for N := 0 to 3 do
    begin
      case N of
        0:
        begin
          K := 0;
        end;
        1:
        begin
          K := 1;
        end;
        2:
        begin
          K := 3;
        end;
        3:
        begin
          K := 257;
        end;
      end;
      LS.Count := K;
      LI.Count := K;
      LV2.Count := K;
      LV3.Count := K;
      LV4.Count := K;
      LM3List.Count := K;
      LM4List.Count := K;
      for I := 0 to K - 1 do
      begin
        LS[I] := I * 0.25 - 37;
        LI[I] := 16777217 + I;
        LV2[I] := Vector2(I + 0.125, -I - 0.25);
        LV3[I] := Vector3(I + 0.125, -I - 0.25, I * 0.5);
        LV4[I] := Vector4(I + 0.125, -I - 0.25, I * 0.5, 1);
        LM3List[I] := LM3;
        LM4List[I] := LM4;
      end;
      SetLength(LExpected, K);
      for I := 0 to K - 1 do
      begin
        LExpected[I] := I * 0.25 - 37;
      end;
      Floats(ListToWebGL(LS), LExpected);
      LInteger := ListToWebGL(LI);
      Check(LInteger.Length = K, 'Integer array excludes unused capacity');
      for I := 0 to K - 1 do
      begin
        Check(LInteger[I] = 16777217 + I, 'Integers above float32 precision stay exact');
      end;
      for J := 2 to 4 do
      begin
        case J of
          2:
          begin
            LFloat := ListToWebGL(LV2);
          end;
          3:
          begin
            LFloat := ListToWebGL(LV3);
          end;
          4:
          begin
            LFloat := ListToWebGL(LV4);
          end;
        end;
        SetLength(LExpected, K * J);
        for I := 0 to K - 1 do
        begin
          LExpected[I * J] := I + 0.125;
          LExpected[I * J + 1] := -I - 0.25;
          if J >= 3 then
          begin
            LExpected[I * J + 2] := I * 0.5;
          end;
          if J = 4 then
          begin
            LExpected[I * J + 3] := 1;
          end;
        end;
        Floats(LFloat, LExpected);
      end;
      LFloat := ListToWebGL(LM3List);
      Check(LFloat.Length = K * 9, 'Matrix3 list length');
      for I := 0 to K * 9 - 1 do
      begin
        Check(LFloat[I] = (I mod 9 div 3) * 7 - (I mod 3) * 0.125 - 3,
          'Matrix3 list column-major order');
      end;
      LFloat := ListToWebGL(LM4List);
      Check(LFloat.Length = K * 16, 'Matrix4 list length');
      for I := 0 to K * 16 - 1 do
      begin
        if I mod 16 = 0 then
        begin
          Check(LFloat[I] = 451, 'Matrix4 list stores updated source');
        end
        else
        begin
          Check(LFloat[I] = (I mod 16 div 4) * 7 - (I mod 4) * 0.125 - 3,
            'Matrix4 list column-major order');
        end;
      end;
    end;
    LI.Count := 4;
    LI[0] := Low(Int32);
    LI[1] := High(Int32);
    LI[2] := -1;
    LI[3] := 0;
    LInteger := ListToWebGL(LI);
    Check((LInteger[0] = Low(Int32)) and (LInteger[1] = High(Int32)) and
      (LInteger[2] = -1) and (LInteger[3] = 0), 'Integer extrema');

    LBitPatterns[0] := $00000000;
    LBitPatterns[1] := $80000000;
    LBitPatterns[2] := $00000001;
    LBitPatterns[3] := $80000001;
    LBitPatterns[4] := $7F800000;
    LBitPatterns[5] := $FF800000;
    LBitPatterns[6] := $7FC00000;
    LBitPatterns[7] := $7F7FFFFF;
    Move(LBitPatterns, LScalars, SizeOf(LScalars));
    LS.Count := Length(LScalars);
    for I := 0 to High(LScalars) do
    begin
      LS[I] := LScalars[I];
    end;
    LKeep := ListToWebGL(LS);
    Floats(LKeep, LScalars);
    LS.Clear;
    Check(LKeep.Length = Length(LScalars), 'List clear leaves previous result intact');
  finally
    LS.Free;
    LI.Free;
    LV2.Free;
    LV3.Free;
    LV4.Free;
    LM3List.Free;
    LM4List.Free;
  end;
  Floats(LKeep, LScalars);
  LBeforePages := fpc_wasm32_memory_grow(1);
  Check(LBeforePages <> High(LongWord), 'WASM memory growth succeeds');
  Floats(LKeep, LScalars);
  Floats(MatrixToWebGL(LM2), [-3, -3.125, 4, 3.875]);

  GLegacyChecks := GChecks;
  if GLegacyChecks <> 9493 then
  begin
    raise Exception.CreateFmt('Legacy transfer assertion count changed: %d',
      [GLegacyChecks]);
  end;
  {$ifdef PHANES_WEBGL_SIGNED_RANGE_GUARD}
  CheckSignedByteBoundary;
  {$endif}
  GBoundaryChecks := GChecks - GLegacyChecks;

  LStart := GetTickCount64;
  for I := 0 to 1999 do
  begin
    LFloat := MatrixToWebGL(LM4);
  end;
  LEnd := GetTickCount64;
  LBrowser := TJSObject.JOBCreateGlobal('window');
  try
    LBrowser.WriteJSPropertyUtf8String('phanesTransferResult',
      '{"passed":true,"checks":' + IntToStr(GChecks) +
      ',"legacyChecks":' + IntToStr(GLegacyChecks) +
      ',"boundaryChecks":' + IntToStr(GBoundaryChecks) +
      ',"signedRangeGuard":"' +
      {$ifdef PHANES_WEBGL_SIGNED_RANGE_GUARD}
      'passed' +
      {$else}
      'skipped' +
      {$endif}
      '"' +
      ',"matrixConversions":2000,"elapsedMs":' + IntToStr(LEnd - LStart) + '}');
  finally
    LBrowser.Free;
  end;
end;

procedure InitializeApplication;
var
  LBrowser: TJSObject;
begin
  try
    RunChecks;
  except
    on LException: Exception do
    begin
      LBrowser := TJSObject.JOBCreateGlobal('window');
      try
        LBrowser.WriteJSPropertyUtf8String('phanesTransferFailure', LException.Message);
      finally
        LBrowser.Free;
      end;
      raise;
    end;
  end;
end;

initialization
  GWindow := TCastleWindow.Create(Application);
  Application.MainWindow := GWindow;
  Application.OnInitialize := InitializeApplication;
end.
