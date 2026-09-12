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
program PhanesFloorTests;
{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  phanes.composition.contents.types,
  phanes.spaces.floor.types,
  phanes.spaces.floor.validate,
  phanes.spaces.floor.generate,
  phanes.tests.floor.critic;

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

procedure AddAsset(var ARequest: TFloorRequest; const AId, ARole: String;
  const AWidth, ADepth, AHeight, AFront: Integer);
var
  LIndex: Integer;
begin
  LIndex := Length(ARequest.FAssets);
  SetLength(ARequest.FAssets, LIndex + 1);
  ARequest.FAssets[LIndex].FContent.FId := AId;
  ARequest.FAssets[LIndex].FContent.FRole := ARole;
  ARequest.FAssets[LIndex].FContent.FWidth := AWidth;
  ARequest.FAssets[LIndex].FContent.FDepth := ADepth;
  ARequest.FAssets[LIndex].FContent.FHeight := AHeight;
  ARequest.FAssets[LIndex].FContent.FSingleInstance := True;
  ARequest.FAssets[LIndex].FAllowedTurns := 15;
  ARequest.FAssets[LIndex].FFrontQuarterTurn := AFront;
  ARequest.FAssets[LIndex].FNeedsApproach := True;
end;

procedure AddQuota(var ARequest: TFloorRequest; const ARole: String; const ACount: Integer);
var
  LIndex: Integer;
begin
  LIndex := Length(ARequest.FQuotas);
  SetLength(ARequest.FQuotas, LIndex + 1);
  ARequest.FQuotas[LIndex].FRole := ARole;
  ARequest.FQuotas[LIndex].FMinimum := ACount;
  ARequest.FQuotas[LIndex].FMaximum := ACount;
end;

function Room(const AProgram: Integer): TFloorRequest;
begin
  Result := Default(TFloorRequest);
  Result.FScopeId := 'world.building.bay-5.room.floor';
  Result.FSeed := 42;
  Result.FWidth := 4500;
  Result.FDepth := 4500;
  Result.FHeight := 2700;
  Result.FPitch := 750;
  Result.FPlayerRadius := 280;
  Result.FDoorWidth := 1200;
  Result.FMaxBacktracks := 512;
  if AProgram = 0 then
  begin
    { Synthetic admission fixtures use conservative millimetre envelopes based
      on independent source measurements. They are not runtime catalog entries. }
    AddAsset(Result, 'fixture.sink', 'sink', 544, 464, 896, 0);
    AddAsset(Result, 'fixture.toilet', 'toilet', 516, 788, 745, 0);
    AddAsset(Result, 'fixture.shower', 'shower', 1124, 1164, 2189, 0);
    AddQuota(Result, 'sink', 1);
    AddQuota(Result, 'toilet', 1);
    AddQuota(Result, 'shower', 1);
    Result.FServices := ['water', 'drain'];
    Result.FAssets[0].FRequiredServices := ['water', 'drain'];
    Result.FAssets[1].FRequiredServices := ['water', 'drain'];
    Result.FAssets[2].FRequiredServices := ['water', 'drain'];
  end
  else
  begin
    Result.FWidth := 6000;
    Result.FDepth := 5250;
    AddAsset(Result, 'fixture.bench', 'bench', 1932, 1028, 750, 0);
    AddAsset(Result, 'fixture.console', 'console', 1050, 450, 1275, 2);
    AddAsset(Result, 'fixture.stool', 'seat', 400, 400, 450, 0);
    AddQuota(Result, 'bench', 2);
    AddQuota(Result, 'console', 1);
    AddQuota(Result, 'seat', 1);
    Result.FServices := ['power'];
    Result.FAssets[1].FRequiredServices := ['power'];
  end;
end;

function Signature(const ALayout: TFloorLayout): String;
var
  LPlacement: TFloorPlacement;
begin
  Result := '';
  for LPlacement in ALayout.FPlacements do
  begin
    Result := Result + LPlacement.FId + ':' + LPlacement.FAssetId + ':' +
      IntToStr(LPlacement.FCellX) + ':' + IntToStr(LPlacement.FCellZ) + ':' +
      IntToStr(LPlacement.FQuarterTurn) + ';';
  end;
end;

function CopyLayout(const ALayout: TFloorLayout): TFloorLayout;
begin
  Result := ALayout;
  Result.FPlacements := Copy(ALayout.FPlacements, 0, Length(ALayout.FPlacements));
  Result.FFreeCells := Copy(ALayout.FFreeCells, 0, Length(ALayout.FFreeCells));
end;

procedure RebuildFree(const ARequest: TFloorRequest; var ALayout: TFloorLayout);
var
  LPlacement: TFloorPlacement;
  LAsset: TFloorAsset;
  LColumns: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  LColumns := ARequest.FWidth div ARequest.FPitch;
  SetLength(ALayout.FFreeCells, LColumns * (ARequest.FDepth div ARequest.FPitch));
  for I := 0 to High(ALayout.FFreeCells) do
  begin
    ALayout.FFreeCells[I] := True;
  end;
  for LPlacement in ALayout.FPlacements do
  begin
    LAsset := ARequest.FAssets[FloorAssetIndex(ARequest.FAssets, LPlacement.FAssetId)];
    LWidth := Ceil(LAsset.FContent.FWidth / ARequest.FPitch);
    LDepth := Ceil(LAsset.FContent.FDepth / ARequest.FPitch);
    if Odd(LPlacement.FQuarterTurn) then
    begin
      LWidth := Ceil(LAsset.FContent.FDepth / ARequest.FPitch);
      LDepth := Ceil(LAsset.FContent.FWidth / ARequest.FPitch);
    end;
    for LZ := LPlacement.FCellZ to LPlacement.FCellZ + LDepth - 1 do
    begin
      for LX := LPlacement.FCellX to LPlacement.FCellX + LWidth - 1 do
      begin
        ALayout.FFreeCells[LZ * LColumns + LX] := False;
      end;
    end;
  end;
end;

procedure GenerationChecks;
var
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LRepeat: TFloorLayout;
  LBase: TFloorLayout;
  LFirst: String;
  LVariation: Boolean;
  LCounts: array[0..3] of Integer;
  LPlacement: TFloorPlacement;
  LAssetIndex: Integer;
  LExpectedFootprint: Integer;
  LOccupied: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LProgram: Integer;
  LSeed: Integer;
  I: Integer;
begin
  for LProgram := 0 to 1 do
  begin
    LVariation := False;
    LFirst := '';
    for LSeed := 0 to 23 do
    begin
      LRequest := Room(LProgram);
      LRequest.FSeed := Cardinal(LSeed);
      if LSeed = 23 then
      begin
        LRequest.FSeed := High(Cardinal);
      end;
      Check(GenerateFloor(LRequest, LLayout, GReason), 'Solve program ' +
        IntToStr(LProgram) + ' seed ' + IntToStr(LSeed));
      Check(ValidateFloorLayout(LRequest, LLayout, GReason), 'Independent decoded floor validation');
      for I := 0 to 3 do
      begin
        LCounts[I] := 0;
      end;
      LExpectedFootprint := 0;
      for LPlacement in LLayout.FPlacements do
      begin
        LAssetIndex := FloorAssetIndex(LRequest.FAssets, LPlacement.FAssetId);
        Check(LAssetIndex >= 0, 'Real admitted instance');
        Inc(LCounts[LAssetIndex]);
        LWidth := Ceil(LRequest.FAssets[LAssetIndex].FContent.FWidth / LRequest.FPitch);
        LDepth := Ceil(LRequest.FAssets[LAssetIndex].FContent.FDepth / LRequest.FPitch);
        Inc(LExpectedFootprint, LWidth * LDepth);
      end;
      for I := 0 to High(LRequest.FQuotas) do
      begin
        Check(LCounts[I] = LRequest.FQuotas[I].FMinimum, 'Count instances, not footprint tiles');
      end;
      LOccupied := 0;
      for I := 0 to High(LLayout.FFreeCells) do
      begin
        if not LLayout.FFreeCells[I] then
        begin
          Inc(LOccupied);
        end;
      end;
      Check(LOccupied = LExpectedFootprint, 'Every rectangle has exactly its complete occupied area');
      if LSeed = 0 then
      begin
        LFirst := Signature(LLayout);
      end
      else
      begin
        LVariation := LVariation or (LFirst <> Signature(LLayout));
      end;
      if LSeed < 3 then
      begin
        Check(GenerateFloor(LRequest, LRepeat, GReason), 'Repeat seeded solve');
        Check(Signature(LLayout) = Signature(LRepeat), 'Seeded floor determinism');
        Check((LLayout.FDecisions = LRepeat.FDecisions) and
          (LLayout.FBacktracks = LRepeat.FBacktracks), 'Deterministic search transcript counts');
      end;
    end;
    Check(LVariation, 'Room program produces different layouts across seeds');
    LBase := CopyLayout(LLayout);
    LRequest.FFixed := Copy(LLayout.FPlacements, 0, Length(LLayout.FPlacements));
    for I := 1 to 4 do
    begin
      LRequest.FSeed := Cardinal(I * 991);
      Check(GenerateFloor(LRequest, LRepeat, GReason),
        'Preserve occupied furniture under another seed');
      Check(Signature(LRepeat) = Signature(LBase), 'All preserved IDs, assets and poses retained');
    end;
  end;
end;

procedure RejectionChecks;
var
  LRequest: TFloorRequest;
  LOriginal: TFloorRequest;
  LBase: TFloorLayout;
  LBad: TFloorLayout;
  LCommitted: TFloorLayout;
  LBefore: String;
  I: Integer;

  procedure RejectRequest(const AMessage: String);
  begin
    Check(not GenerateFloor(LRequest, LCommitted, GReason), AMessage);
    Check(Signature(LCommitted) = LBefore, 'Rejected generation preserves committed output');
  end;

begin
  LOriginal := Room(0);
  Check(GenerateFloor(LOriginal, LBase, GReason), 'Baseline for rejection checks');
  LCommitted := CopyLayout(LBase);
  LBefore := Signature(LCommitted);
  LBad := CopyLayout(LBase);
  LBad.FPlacements[0].FAssetId := 'unknown';
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Unknown asset rejected');
  LBad := CopyLayout(LBase);
  LBad.FPlacements[0].FQuarterTurn := 4;
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Invalid orientation rejected');
  LBad := CopyLayout(LBase);
  LBad.FPlacements[0].FCellX := 6;
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Out-of-room anchor rejected');
  LBad := CopyLayout(LBase);
  LBad.FPlacements[0].FCellX := 5;
  LBad.FPlacements[0].FCellZ := 5;
  LBad.FPlacements[0].FAssetId := 'fixture.shower';
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Truncated multi-cell fixture rejected');
  LBad := CopyLayout(LBase);
  LBad.FPlacements[1].FId := LBad.FPlacements[0].FId;
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Duplicate stable identity rejected');
  LBad := CopyLayout(LBase);
  LBad.FPlacements[1].FCellX := LBad.FPlacements[0].FCellX;
  LBad.FPlacements[1].FCellZ := LBad.FPlacements[0].FCellZ;
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Overlapping footprint rejected');
  LBad := CopyLayout(LBase);
  SetLength(LBad.FPlacements, 2);
  RebuildFree(LOriginal, LBad);
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Missing required fixture rejected');
  LBad := CopyLayout(LBase);
  LBad.FFreeCells[0] := not LBad.FFreeCells[0];
  Check(not ValidateFloorLayout(LOriginal, LBad, GReason), 'Invented free-floor cell rejected');
  LRequest := Room(0);
  LRequest.FFixed := Copy(LBase.FPlacements, 0, Length(LBase.FPlacements));
  LBad := CopyLayout(LBase);
  LBad.FPlacements[0].FId := 'changed';
  Check(not ValidateFloorLayout(LRequest, LBad, GReason), 'Preserved identity cannot be renamed');
  LRequest.FFixed[0].FCellX := 3;
  LRequest.FFixed[0].FCellZ := 5;
  RejectRequest('Fixed doorway obstruction rejected atomically');
  LRequest := Room(0);
  LRequest.FServices := nil;
  RejectRequest('Required water and drain service capability absent');
  LRequest := Room(0);
  LRequest.FHeight := 1800;
  RejectRequest('Required shower cannot fit available height');
  LRequest := Room(0);
  LRequest.FWidth := High(Integer);
  RejectRequest('Extreme room dimensions rejected before allocation');
  LRequest := Room(0);
  LRequest.FPitch := 0;
  RejectRequest('Zero floor pitch rejected before division');
  LRequest := Room(0);
  LRequest.FPitch := 560;
  RejectRequest('Point-connected but player-width pitch rejected');
  LRequest := Room(0);
  LRequest.FPitch := 751;
  RejectRequest('Half-millimetre anchor arithmetic excluded by even pitch contract');
  LRequest := Room(0);
  LRequest.FDoorWidth := 559;
  RejectRequest('Narrow doorway rejected');
  LRequest := Room(0);
  LRequest.FDoorX := High(Integer);
  RejectRequest('Overflow-sized doorway offset rejected');
  LRequest := Room(0);
  LRequest.FQuotas[0].FMaximum := -1;
  RejectRequest('Negative quota rejected');
  LRequest := Room(0);
  LRequest.FQuotas[1].FRole := 'sink';
  RejectRequest('Duplicate role quota rejected');
  LRequest := Room(0);
  LRequest.FAssets[1].FContent.FId := LRequest.FAssets[0].FContent.FId;
  RejectRequest('Duplicate catalog identity rejected');
  LRequest := Room(0);
  LRequest.FAssets[0].FContent.FWidth := High(Integer);
  RejectRequest('Unbounded fixture dimensions rejected');
  LRequest := Room(0);
  LRequest.FAssets[0].FAllowedTurns := 0;
  RejectRequest('Empty orientation contract rejected');
  LRequest := Room(0);
  LRequest.FAssets[0].FFrontQuarterTurn := -1;
  RejectRequest('Invalid service front rejected');
  LRequest := Room(1);
  LRequest.FWidth := 12000;
  LRequest.FDepth := 12000;
  RejectRequest('Joint token and floor-area work bound rejects costly request before graph creation');
  LRequest := Room(0);
  LRequest.FAssets[0].FContent.FSingleInstance := False;
  RejectRequest('Grouped meshes cannot represent an independently editable fixture');
  LRequest := Room(0);
  LRequest.FFixed := Copy(LBase.FPlacements, 0, Length(LBase.FPlacements));
  LRequest.FFixed[1].FCellX := LRequest.FFixed[0].FCellX;
  LRequest.FFixed[1].FCellZ := LRequest.FFixed[0].FCellZ;
  RejectRequest('Conflicting preserved footprints rejected');
  for I := 0 to 3 do
  begin
    LRequest := Room(0);
    LRequest.FAssets[0].FAllowedTurns := 1 shl I;
    Check(GenerateFloor(LRequest, LCommitted, GReason), 'Only admitted turn solves');
    Check(ValidateFloorLayout(LRequest, LCommitted, GReason), 'Rotated operating face is reachable');
  end;
end;

procedure GeometryChecks;
var
  LBounds: TFloorRectangle;
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LPlacement: TFloorPlacement;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  LBounds.FMinX := -500;
  LBounds.FMaxX := 500;
  LBounds.FMinZ := -500;
  LBounds.FMaxZ := 500;
  Check(not FloorSegmentClear(-1000, 0, 1000, 0, 280, LBounds), 'Swept segment crosses furniture');
  Check(not FloorSegmentClear(0, 0, 0, 0, 280, LBounds), 'Standing inside furniture rejected');
  Check(FloorSegmentClear(-1000, 780, 1000, 780, 280, LBounds), 'Exact parallel clearance admitted');
  Check(not FloorSegmentClear(-1000, 779.9, 1000, 779.9, 280, LBounds),
    'Sub-millimetre clearance shortfall rejected');
  Check(FloorSegmentClear(700, 700, 700, 700, 280, LBounds), 'Rounded corner disk clears at diagonal');
  Check(not FloorSegmentClear(697, 697, 697, 697, 280, LBounds), 'Disk clips rectangle corner');
  for I := 0 to 3 do
  begin
    LRequest := Room(1);
    LPlacement := Default(TFloorPlacement);
    LPlacement.FCellX := 2;
    LPlacement.FCellZ := 2;
    LPlacement.FQuarterTurn := I;
    FloorApproachCell(LRequest, LPlacement, LRequest.FAssets[1], LX, LZ);
    case I of
      0:
      begin
        Check((LX = 2) and (LZ = 1), 'Console raw -Z operating face');
      end;
      1:
      begin
        Check((LX = 1) and (LZ = 2), 'Console operating face rotates to -X');
      end;
      2:
      begin
        Check((LX = 2) and (LZ = 3), 'Console operating face rotates to +Z');
      end;
      3:
      begin
        Check((LX = 3) and (LZ = 2), 'Console operating face rotates to +X');
      end;
    end;
  end;
  LRequest := Room(0);
  LRequest.FAssets := nil;
  LRequest.FQuotas := nil;
  LRequest.FWidth := 12000;
  LRequest.FDepth := 12000;
  Check(GenerateFloor(LRequest, LLayout, GReason), 'Large empty floor fits the joint work allowance');
  Check(Length(LLayout.FFreeCells) = 256, 'The local work cap does not replace area with catalog size');
  LRequest.FWidth := 4501;
  LRequest.FDepth := 4503;
  for I := -1 to 1 do
  begin
    LRequest.FDoorX := I * 1600;
    Check(GenerateFloor(LRequest, LLayout, GReason), 'Odd room size and off-centre doorway');
    Check(ValidateFloorLayout(LRequest, LLayout, GReason), 'Physical doorway jamb clearance');
  end;
end;

begin
  GenerationChecks;
  RejectionChecks;
  GeometryChecks;
  WriteLn(GChecks, ' WFC floor placement checks passed');
  WriteLn(RunFloorCriticChecks, ' independent floor critic checks passed');
end.
