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
unit phanes.tests.floor.critic;
{$mode delphi}
{$H+}

interface

function RunFloorCriticChecks: Integer;

implementation

uses
  SysUtils,
  Math,
  phanes.spaces.floor.types,
  phanes.spaces.floor.validate,
  phanes.spaces.floor.generate;
var
  GChecks: Integer;

function BasicRequest: TFloorRequest;
begin
  Result := Default(TFloorRequest);
  Result.FScopeId := 'room';
  Result.FSeed := 42;
  Result.FWidth := 3000;
  Result.FDepth := 3000;
  Result.FHeight := 2500;
  Result.FPitch := 750;
  Result.FPlayerRadius := 280;
  Result.FDoorWidth := 1200;
  Result.FMaxBacktracks := 100;
  SetLength(Result.FAssets, 1);
  Result.FAssets[0].FContent.FId := 'stool';
  Result.FAssets[0].FContent.FRole := 'seat';
  Result.FAssets[0].FContent.FWidth := 600;
  Result.FAssets[0].FContent.FDepth := 600;
  Result.FAssets[0].FContent.FHeight := 450;
  Result.FAssets[0].FContent.FSingleInstance := True;
  Result.FAssets[0].FAllowedTurns := 15;
  SetLength(Result.FQuotas, 1);
  Result.FQuotas[0].FRole := 'seat';
  Result.FQuotas[0].FMinimum := 2;
  Result.FQuotas[0].FMaximum := 2;
end;

procedure Check(const AValue: Boolean; const AName: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create('Independent floor critic regression: ' + AName);
  end;
end;

procedure CheckSolvedFloor(const ARequest: TFloorRequest; const ACase: String);
var
  LLayout: TFloorLayout;
  LReason: String;
begin
  LLayout := Default(TFloorLayout);
  Check(GenerateFloor(ARequest, LLayout, LReason), ACase + ' resolves: ' + LReason);
  Check(Length(LLayout.FPlacements) = 2, ACase + ' counts two complete fixtures');
  Check(ValidateFloorLayout(ARequest, LLayout, LReason),
    ACase + ' independently validates decoded occupancy and access: ' + LReason);
end;

procedure WorkAdmissionChecks;
var
  LRequest: TFloorRequest;
  LReason: String;
  I: Integer;
begin
  LRequest := BasicRequest;
  SetLength(LRequest.FAssets, 20);
  for I := 0 to 19 do
  begin
    LRequest.FAssets[I] := LRequest.FAssets[0];
    LRequest.FAssets[I].FContent.FId := 'fixture-' + IntToStr(I);
  end;
  LRequest.FAssets[19].FAllowedTurns := 3;
  Check(ValidateFloorRequest(LRequest, LReason),
    '16 cells and 79 tokens fit the joint work limit');
  CheckSolvedFloor(LRequest, '16 cells and 79 tokens');
  LRequest.FAssets[19].FAllowedTurns := 7;
  Check(not ValidateFloorRequest(LRequest, LReason),
    '16 cells and 80 tokens exceed the joint work limit');
  LRequest.FWidth := 1500;
  LRequest.FDepth := 2250;
  SetLength(LRequest.FAssets, 32);
  for I := 0 to 31 do
  begin
    LRequest.FAssets[I] := LRequest.FAssets[0];
    LRequest.FAssets[I].FContent.FId := 'fixture-' + IntToStr(I);
  end;
  LRequest.FAssets[31].FAllowedTurns := 7;
  Check(ValidateFloorRequest(LRequest, LReason),
    '6 cells and 128 tokens fit the joint work limit');
  CheckSolvedFloor(LRequest, '6 cells and 128 tokens');
  LRequest.FAssets[31].FAllowedTurns := 15;
  Check(not ValidateFloorRequest(LRequest, LReason),
    '129 tokens exceed the catalog limit even in a small room');
  LRequest.FWidth := 12000;
  LRequest.FDepth := 12000;
  SetLength(LRequest.FAssets, 5);
  for I := 0 to 4 do
  begin
    LRequest.FAssets[I] := LRequest.FAssets[0];
    LRequest.FAssets[I].FContent.FId := 'fixture-' + IntToStr(I);
  end;
  LRequest.FAssets[4].FAllowedTurns := 3;
  Check(ValidateFloorRequest(LRequest, LReason),
    '256 cells and 19 tokens fit the joint work limit');
  CheckSolvedFloor(LRequest, '256 cells and 19 tokens');
end;

procedure SingleGeometryChecks;
var
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LReason: String;
  LSuccess: Boolean;
begin
  LRequest := BasicRequest;
  LLayout := Default(TFloorLayout);
  LSuccess := GenerateFloor(LRequest, LLayout, LReason);
  Check(LSuccess and (Length(LLayout.FPlacements) = 2), 'two identical individually addressable fixtures allowed');
  LRequest.FAssets[0].FContent.FSingleInstance := False;
  LSuccess := GenerateFloor(LRequest, LLayout, LReason);
  Check(not LSuccess, 'grouped mesh is not counted as one fixture');
end;
procedure FrontChecks;
var
  LRequest: TFloorRequest;
  LPlacement: TFloorPlacement;
  LAsset: TFloorAsset;
  LX: Integer;
  LZ: Integer;
  LExpectedX: Integer;
  LExpectedZ: Integer;
  LAngle: Double;
  I: Integer;
  J: Integer;
begin
  LRequest := BasicRequest;
  LPlacement := Default(TFloorPlacement);
  LPlacement.FCellX := 1;
  LPlacement.FCellZ := 1;
  LAsset := LRequest.FAssets[0];
  for I := 0 to 3 do
  begin
    for J := 0 to 3 do
    begin
      LAsset.FFrontQuarterTurn := I;
      LPlacement.FQuarterTurn := J;
      LAngle := (I + J) * Pi / 2;
      LExpectedX := 1 + Round(Sin(LAngle));
      LExpectedZ := 1 + Round(Cos(LAngle));
      FloorApproachCell(LRequest, LPlacement, LAsset, LX, LZ);
      Check((LX = LExpectedX) and (LZ = LExpectedZ),
        Format('front=%d turn=%d gives(%d,%d), expected(%d,%d)',
        [I, J, LX, LZ, LExpectedX, LExpectedZ]));
    end;
  end;
end;
procedure BlockedFrontCheck;
var
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LReason: String;
  LSuccess: Boolean;
  I: Integer;
begin
  LRequest := BasicRequest;
  SetLength(LRequest.FAssets, 2);
  LRequest.FAssets[1] := LRequest.FAssets[0];
  LRequest.FAssets[1].FContent.FId := 'obstacle';
  LRequest.FAssets[0].FNeedsApproach := True;
  LLayout := Default(TFloorLayout);
  SetLength(LLayout.FPlacements, 2);
  LLayout.FPlacements[0].FId := 'operator';
  LLayout.FPlacements[0].FAssetId := 'stool';
  LLayout.FPlacements[0].FCellX := 2;
  LLayout.FPlacements[0].FCellZ := 1;
  LLayout.FPlacements[0].FQuarterTurn := 1;
  LLayout.FPlacements[1].FId := 'blocking-object';
  LLayout.FPlacements[1].FAssetId := 'obstacle';
  LLayout.FPlacements[1].FCellX := 3;
  LLayout.FPlacements[1].FCellZ := 1;
  SetLength(LLayout.FFreeCells, 16);
  for I := 0 to 15 do
  begin
    LLayout.FFreeCells[I] := (I <> 6) and (I <> 7);
  end;
  LSuccess := ValidateFloorLayout(LRequest, LLayout, LReason);
  Check(not LSuccess, 'independent admission must reject the blocked rendered front');
end;
procedure SegmentOracleChecks;
var
  LBox: TFloorRectangle;
  LX0: Double;
  LZ0: Double;
  LX1: Double;
  LZ1: Double;
  LX: Double;
  LZ: Double;
  LDX: Double;
  LDZ: Double;
  LRadius: Double;
  LMinimum: Double;
  LExpected: Boolean;
  LActual: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LBox.FMinX := -193.5;
  LBox.FMaxX := 326.5;
  LBox.FMinZ := -206.25;
  LBox.FMaxZ := 473.75;
  for I := 0 to 63 do
  begin
    for J := 0 to 63 do
    begin
      LX0 := -1500 + (I * 713 mod 3001);
      LZ0 := -1500 + (I * 997 mod 3001);
      LX1 := -1500 + (J * 557 mod 3001);
      LZ1 := -1500 + (J * 811 mod 3001);
      LRadius := 100 + (I * 17 + J * 23) mod 400;
      LMinimum := Infinity;
      for K := 0 to 1000 do
      begin
        LX := LX0 + (LX1 - LX0) * K / 1000;
        LZ := LZ0 + (LZ1 - LZ0) * K / 1000;
        LDX := Max(0.0, Max(LBox.FMinX - LX, LX - LBox.FMaxX));
        LDZ := Max(0.0, Max(LBox.FMinZ - LZ, LZ - LBox.FMaxZ));
        LMinimum := Min(LMinimum, Sqrt(Sqr(LDX) + Sqr(LDZ)));
      end;
      { Sampled distance overestimates the true minimum by at most half a step.
        Exclude the conservative 3mm uncertainty band for this independent oracle. }
      if Abs(LMinimum - LRadius) <= 3 then
      begin
        Continue;
      end;
      LExpected := LMinimum > LRadius;
      LActual := FloorSegmentClear(LX0, LZ0, LX1, LZ1, LRadius, LBox);
      Check(LActual = LExpected, Format('segment clearance oracle %d/%d', [I, J]));
    end;
  end;
end;
function SameLayout(const ALeft, ARight: TFloorLayout): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(ALeft.FPlacements) <> Length(ARight.FPlacements)) or
    (Length(ALeft.FFreeCells) <> Length(ARight.FFreeCells)) or
    (ALeft.FDecisions <> ARight.FDecisions) or
    (ALeft.FPropagations <> ARight.FPropagations) or
    (ALeft.FBacktracks <> ARight.FBacktracks) then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft.FPlacements) do
  begin
    if (ALeft.FPlacements[I].FId <> ARight.FPlacements[I].FId) or
      (ALeft.FPlacements[I].FAssetId <> ARight.FPlacements[I].FAssetId) or
      (ALeft.FPlacements[I].FCellX <> ARight.FPlacements[I].FCellX) or
      (ALeft.FPlacements[I].FCellZ <> ARight.FPlacements[I].FCellZ) or
      (ALeft.FPlacements[I].FQuarterTurn <> ARight.FPlacements[I].FQuarterTurn) then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(ALeft.FFreeCells) do
  begin
    if ALeft.FFreeCells[I] <> ARight.FFreeCells[I] then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

procedure PreservationChecks;
var
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LBefore: TFloorLayout;
  LReason: String;
  LSuccess: Boolean;
  I: Integer;
  J: Integer;
begin
  LRequest := BasicRequest;
  LLayout := Default(TFloorLayout);
  Check(GenerateFloor(LRequest, LLayout, LReason), 'preservation baseline resolves');
  LRequest.FFixed := Copy(LLayout.FPlacements);
  for I := 0 to 63 do
  begin
    LRequest.FSeed := I;
    LSuccess := GenerateFloor(LRequest, LLayout, LReason);
    Check(LSuccess, 'fixed pose solve seed ' + IntToStr(I));
    for J := 0 to High(LRequest.FFixed) do
    begin
      Check((LLayout.FPlacements[J].FId = LRequest.FFixed[J].FId) and
        (LLayout.FPlacements[J].FAssetId = LRequest.FFixed[J].FAssetId) and
        (LLayout.FPlacements[J].FCellX = LRequest.FFixed[J].FCellX) and
        (LLayout.FPlacements[J].FCellZ = LRequest.FFixed[J].FCellZ) and
        (LLayout.FPlacements[J].FQuarterTurn = LRequest.FFixed[J].FQuarterTurn),
        'fixed placement and identity unchanged');
    end;
  end;
  LBefore := LLayout;
  LBefore.FPlacements := Copy(LLayout.FPlacements);
  LBefore.FFreeCells := Copy(LLayout.FFreeCells);
  LRequest.FPitch := 0;
  Check(not GenerateFloor(LRequest, LLayout, LReason), 'invalid request refuses');
  Check(SameLayout(LLayout, LBefore), 'invalid request retains every output field');
  LRequest.FPitch := 750;
  LRequest.FQuotas[0].FMinimum := 0;
  LRequest.FQuotas[0].FMaximum := 0;
  Check(not GenerateFloor(LRequest, LLayout, LReason), 'contradictory fixed quota refuses');
  Check(SameLayout(LLayout, LBefore), 'contradiction retains every output field');
end;
function RunFloorCriticChecks: Integer;
begin
  GChecks := 0;
  SingleGeometryChecks;
  FrontChecks;
  BlockedFrontCheck;
  SegmentOracleChecks;
  PreservationChecks;
  WorkAdmissionChecks;
  Result := GChecks;
end;

end.
