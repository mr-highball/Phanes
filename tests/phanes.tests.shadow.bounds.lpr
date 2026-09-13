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

program PhanesTestsShadowBounds;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  CastleBoxes,
  CastleVectors,
  phanes.world.shadowbounds;

var
  GChecks: Integer;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Corner(const ABox: TBox3D; const AIndex: Integer): TVector3;
begin
  Result := Vector3(ABox.Data[(AIndex shr 0) and 1][0],
    ABox.Data[(AIndex shr 1) and 1][1], ABox.Data[(AIndex shr 2) and 1][2]);
end;

function IsPowerOfTwo(const AValue: Single): Boolean;
var
  LBits: Cardinal;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (AValue > 0) and ((LBits and $7F800000) <> $7F800000) and
    ((LBits and $007FFFFF) = 0);
end;

function FiniteValue(const AValue: Double): Boolean;
begin
  Result := not IsNan(AValue) and not IsInfinite(AValue);
end;

procedure CheckEndpointWitness(const ABox: TBox3D; const ACamera,
  ACameraDirection, AShadowDirection: TVector3; const ADistance, AFar: Single);
var
  LCameraUnit: TVector3Double;
  LShadowUnit: TVector3Double;
  LExtrusion: TVector3;
  LEndpoint: TVector3;
  LEndpointMin: Double;
  LEndpointMax: Double;
  LDepth: Double;
  LSeparated: Boolean;
  LAxis: Integer;
  LCornerIndex: Integer;
begin
  LCameraUnit := Vector3Double(ACameraDirection);
  LCameraUnit := LCameraUnit / LCameraUnit.Length;
  LShadowUnit := Vector3Double(AShadowDirection);
  LShadowUnit := LShadowUnit / LShadowUnit.Length;
  LExtrusion := Vector3(LShadowUnit * ADistance);
  LSeparated := False;
  for LAxis := 0 to 2 do
  begin
    if LShadowUnit[LAxis] = 0 then
    begin
      Continue;
    end;
    LEndpointMin := Infinity;
    LEndpointMax := -Infinity;
    for LCornerIndex := 0 to 7 do
    begin
      LEndpoint := Corner(ABox, LCornerIndex) + LExtrusion;
      LEndpointMin := Min(LEndpointMin, LEndpoint[LAxis]);
      LEndpointMax := Max(LEndpointMax, LEndpoint[LAxis]);
    end;
    if ((LShadowUnit[LAxis] > 0) and
      (LEndpointMin > ABox.Data[1][LAxis])) or
      ((LShadowUnit[LAxis] < 0) and
      (LEndpointMax < ABox.Data[0][LAxis])) then
    begin
      LSeparated := True;
    end;
  end;
  Require(LSeparated,
    'Actual rounded endpoint box has no correctly oriented separating axis');
  for LCornerIndex := 0 to 7 do
  begin
    LEndpoint := Corner(ABox, LCornerIndex) + LExtrusion;
    LDepth := TVector3Double.DotProduct(Vector3Double(LEndpoint) -
      Vector3Double(ACamera), LCameraUnit);
    Require(FiniteValue(LDepth) and (LDepth < AFar),
      'Actual Single endpoint is clipped by derived far plane');
    LDepth := TVector3Double.DotProduct(Vector3Double(Corner(ABox, LCornerIndex)) -
      Vector3Double(ACamera), LCameraUnit);
    Require(FiniteValue(LDepth) and (LDepth < AFar),
      'Receiver corner is clipped by derived far plane');
  end;
end;

procedure CheckBox(const ABox: TBox3D);
const
  CCameraDirections: array[0..3] of TVector3 = (
    (X: 1; Y: 0; Z: 0), (X: 0; Y: -3; Z: 0),
    (X: -0.6; Y: -1; Z: -0.45), (X: 1; Y: 2; Z: 3));
  CShadowDirections: array[0..7] of TVector3 = (
    (X: 1; Y: 0; Z: 0), (X: -1; Y: 0; Z: 0),
    (X: 0; Y: 1; Z: 0), (X: 0; Y: 0; Z: -1),
    (X: -0.6; Y: -1; Z: -0.45), (X: 1; Y: 2; Z: 3),
    (X: -0.0000001; Y: 0; Z: 1),
    (X: 1.0E-20; Y: 2.0E-20; Z: -1.0E-20));
var
  LCamera: TVector3;
  LDistance: Single;
  LScaledDistance: Single;
  LPreviousDistance: Single;
  LFar: Single;
  LScaledFar: Single;
  LShadowIndex: Integer;
  LCameraIndex: Integer;
begin
  for LShadowIndex := 0 to High(CShadowDirections) do
  begin
    LPreviousDistance := 0;
    for LCameraIndex := 0 to High(CCameraDirections) do
    begin
      LCamera := Corner(ABox, LCameraIndex) + Vector3(12, -7, 43);
      FiniteDirectionalShadowBounds(ABox, LCamera,
        CCameraDirections[LCameraIndex], CShadowDirections[LShadowIndex],
        LDistance, LFar);
      Require(IsPowerOfTwo(LDistance), 'Extrusion distance is not a finite power of two');
      Require(FiniteValue(LFar) and (LFar > 0),
        'Far bound must be positive and finite');
      if LCameraIndex > 0 then
      begin
        Require(LDistance = LPreviousDistance,
          'Camera movement changed cached extrusion');
      end;
      LPreviousDistance := LDistance;
      CheckEndpointWitness(ABox, LCamera, CCameraDirections[LCameraIndex],
        CShadowDirections[LShadowIndex], LDistance, LFar);
      FiniteDirectionalShadowBounds(ABox, LCamera,
        CCameraDirections[LCameraIndex], CShadowDirections[LShadowIndex] * 8,
        LScaledDistance, LScaledFar);
      Require(LScaledDistance = LDistance,
        'Exact power-of-two direction scaling changed extrusion distance');
      CheckEndpointWitness(ABox, LCamera, CCameraDirections[LCameraIndex],
        CShadowDirections[LShadowIndex] * 8, LScaledDistance, LScaledFar);
    end;
  end;
end;

procedure RequireRejected(const ABox: TBox3D; const ACamera,
  ACameraDirection, AShadowDirection: TVector3; const AMessage: String);
var
  LDistance: Single;
  LFar: Single;
  LRejected: Boolean;
begin
  LRejected := False;
  try
    FiniteDirectionalShadowBounds(ABox, ACamera, ACameraDirection,
      AShadowDirection, LDistance, LFar);
  except
    on EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  Require(LRejected, AMessage);
end;

procedure CheckInvalid;
var
  LBox: TBox3D;
begin
  LBox.Data[0] := Vector3(-1, -1, -1);
  LBox.Data[1] := Vector3(1, 1, 1);
  RequireRejected(LBox, TVector3.Zero, TVector3.Zero, Vector3(1, 0, 0),
    'Zero camera direction was accepted');
  RequireRejected(LBox, Vector3(NaN, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0),
    'Nonfinite camera position was accepted');
  RequireRejected(LBox, TVector3.Zero, Vector3(NaN, 0, -1), Vector3(1, 0, 0),
    'Nonfinite camera direction was accepted');
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), TVector3.Zero,
    'Zero shadow direction was accepted');
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(NaN, 0, 1),
    'NaN shadow direction was accepted');
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(Infinity, 0, 1),
    'Infinite shadow direction was accepted');
  LBox.Data[1].X := NaN;
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(1, 0, 0),
    'NaN bound was accepted');
  LBox.Data[1] := Vector3(1, 1, 1);
  LBox.Data[0].X := 2;
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(1, 0, 0),
    'Reversed bound was accepted');
  LBox.Data[0] := Vector3(-1.0E30, -1, -1);
  LBox.Data[1] := Vector3(1.0E30, 1, 1);
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(1, 0, 0),
    'Finite inputs beyond the supported distance limit were accepted');
  LBox.Data[0] := Vector3(-3.0E38, -1, -1);
  LBox.Data[1] := Vector3(3.0E38, 1, 1);
  RequireRejected(LBox, TVector3.Zero, Vector3(0, 0, -1), Vector3(1, 0, 0),
    'Reachable near-maximum Single bounds were accepted');
end;

var
  LBox: TBox3D;
begin
  try
    LBox.Data[0] := Vector3(-6, -0.2, -6);
    LBox.Data[1] := Vector3(6, 2, 6);
    CheckBox(LBox);
    LBox.Data[0] := Vector3(100000, -40000, 61000);
    LBox.Data[1] := Vector3(100000.125, -39999.875, 61000.125);
    CheckBox(LBox);
    LBox.Data[0] := Vector3(-2000, -130, -9000);
    LBox.Data[1] := Vector3(8000, 370, 2000);
    CheckBox(LBox);
    LBox.Data[0] := Vector3(-500, 17, -0.0001);
    LBox.Data[1] := Vector3(500, 17.0001, 0.0001);
    CheckBox(LBox);
    LBox.Data[0] := Vector3(-0.00001, -0.00001, -0.00001);
    LBox.Data[1] := Vector3(0.00001, 0.00001, 0.00001);
    CheckBox(LBox);
    CheckInvalid;
    WriteLn('PASS finite bounds: ', GChecks, ' independent endpoint/far/stability checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
