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
unit phanes.spaces.floor.validate;
{$mode delphi}
{$H+}

interface

uses
  phanes.spaces.floor.types;

function ValidateFloorRequest(const ARequest: TFloorRequest; out AReason: String): Boolean;
function ValidateFloorLayout(const ARequest: TFloorRequest; const ALayout: TFloorLayout;
  out AReason: String): Boolean;
function FloorSegmentClear(const AX1, AZ1, AX2, AZ2, ARadius: Double;
  const ABounds: TFloorRectangle): Boolean;
function FloorEntryClear(const ARequest: TFloorRequest;
  const ABounds: TFloorRectangle): Boolean;

implementation

uses
  SysUtils,
  Math,
  phanes.composition.contents.types;

function IdentityValid(const AId: String; const AMaximum: Integer): Boolean;
var
  I: Integer;
begin
  Result := (Length(AId) > 0) and (Length(AId) <= AMaximum);
  if not Result then
  begin
    Exit;
  end;
  for I := 1 to Length(AId) do
  begin
    Result := Result and (AId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-', '_']);
  end;
end;

function WholeInRange(const AValue, AMinimum, AMaximum: Double): Boolean;
begin
  { pas2js uses JavaScript numbers even for Pascal Integer record fields. }
  Result := not IsNan(AValue) and not IsInfinite(AValue) and
    (AValue >= AMinimum) and (AValue <= AMaximum) and (Frac(AValue) = 0);
end;

function ValidateFloorRequest(const ARequest: TFloorRequest; out AReason: String): Boolean;
var
  LColumns: Integer;
  LRows: Integer;
  LTokens: Integer;
  LSpanX: Integer;
  LSpanZ: Integer;
  LQuota: Integer;
  LAsset: TFloorAsset;
  LService: String;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := False;
  AReason := 'The room requires a valid identity and bounded millimetre dimensions.';
  if not IdentityValid(ARequest.FScopeId, 96) or
    not WholeInRange(ARequest.FSeed, 0, 4294967295.0) or
    not WholeInRange(ARequest.FWidth, 1000, 64000) or
    not WholeInRange(ARequest.FDepth, 1000, 64000) or
    not WholeInRange(ARequest.FHeight, 1000, 12000) then
  begin
    Exit;
  end;
  AReason := 'Floor pitch must be even, at most 2000 mm, and exceed the player diameter by 20 mm.';
  if not WholeInRange(ARequest.FPlayerRadius, 100, 1000) or
    not WholeInRange(ARequest.FPitch, ARequest.FPlayerRadius * 2 + 20, 2000) or
    Odd(ARequest.FPitch) then
  begin
    Exit;
  end;
  LColumns := ARequest.FWidth div ARequest.FPitch;
  LRows := ARequest.FDepth div ARequest.FPitch;
  AReason := 'One room floor supports 2 to 32 cells per side and at most 256 cells.';
  if (LColumns < 2) or (LRows < 2) or (LColumns > 32) or (LRows > 32) or
    (LColumns * LRows > 256) then
  begin
    Exit;
  end;
  AReason := 'The doorway must fit the wall and provide the player diameter plus 20 mm.';
  if not WholeInRange(ARequest.FDoorWidth, ARequest.FPlayerRadius * 2 + 20, ARequest.FWidth) or
    not WholeInRange(ARequest.FDoorX, -64000, 64000) or
    (Abs(Double(ARequest.FDoorX)) + ARequest.FDoorWidth / 2 > ARequest.FWidth / 2) then
  begin
    Exit;
  end;
  AReason := 'The floor request exceeds its catalog, quota, service or search allowance.';
  if (Length(ARequest.FAssets) > 32) or (Length(ARequest.FQuotas) > 32) or
    (Length(ARequest.FServices) > 16) or (Length(ARequest.FFixed) > LColumns * LRows) or
    (Length(ARequest.FUnavailableNewIds) > LColumns * LRows) or
    not WholeInRange(ARequest.FMaxBacktracks, 0, 4096) then
  begin
    Exit;
  end;
  for LService in ARequest.FServices do
  begin
    AReason := 'Room service names must be valid identifiers.';
    if not IdentityValid(LService, 64) then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(ARequest.FUnavailableNewIds) do
  begin
    AReason := 'Reserved new fixture identities must be valid and unique.';
    if not IdentityValid(ARequest.FUnavailableNewIds[I], 128) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      if ARequest.FUnavailableNewIds[J] = ARequest.FUnavailableNewIds[I] then
      begin
        Exit;
      end;
    end;
  end;
  for I := 0 to High(ARequest.FQuotas) do
  begin
    AReason := 'Each furniture role requires unique, bounded instance quotas.';
    if not IdentityValid(ARequest.FQuotas[I].FRole, 64) or
      not WholeInRange(ARequest.FQuotas[I].FMinimum, 0, LColumns * LRows) or
      not WholeInRange(ARequest.FQuotas[I].FMaximum,
      ARequest.FQuotas[I].FMinimum, LColumns * LRows) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      if ARequest.FQuotas[J].FRole = ARequest.FQuotas[I].FRole then
      begin
        Exit;
      end;
    end;
  end;
  LTokens := 1;
  for I := 0 to High(ARequest.FAssets) do
  begin
    LAsset := ARequest.FAssets[I];
    AReason := 'Each fixture must represent one object with unique identity, ' +
      'measured bounds and orientations.';
    if not IdentityValid(LAsset.FContent.FId, 128) or
      not IdentityValid(LAsset.FContent.FRole, 64) or
      not LAsset.FContent.FSingleInstance or
      not WholeInRange(LAsset.FContent.FWidth, 1, 64000) or
      not WholeInRange(LAsset.FContent.FDepth, 1, 64000) or
      not WholeInRange(LAsset.FContent.FHeight, 1, 12000) or
      not WholeInRange(LAsset.FAllowedTurns, 1, 15) or
      not WholeInRange(LAsset.FFrontQuarterTurn, 0, 3) or
      (Length(LAsset.FRequiredServices) > 16) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      if ARequest.FAssets[J].FContent.FId = LAsset.FContent.FId then
      begin
        Exit;
      end;
    end;
    for LService in LAsset.FRequiredServices do
    begin
      AReason := 'Fixture service names must be valid identifiers.';
      if not IdentityValid(LService, 64) then
      begin
        Exit;
      end;
    end;
    LQuota := -1;
    for J := 0 to High(ARequest.FQuotas) do
    begin
      if ARequest.FQuotas[J].FRole = LAsset.FContent.FRole then
      begin
        LQuota := J;
      end;
    end;
    AReason := 'Every admitted fixture role needs an explicit instance quota.';
    if LQuota < 0 then
    begin
      Exit;
    end;
    if FloorAssetAvailable(ARequest, I) and (ARequest.FQuotas[LQuota].FMaximum > 0) then
    begin
      for K := 0 to 3 do
      begin
        if (LAsset.FAllowedTurns and (1 shl K)) <> 0 then
        begin
          FloorSpan(ARequest, LAsset, K, LSpanX, LSpanZ);
          if (LSpanX <= LColumns) and (LSpanZ <= LRows) then
          begin
            Inc(LTokens, LSpanX * LSpanZ);
          end;
        end;
      end;
    end;
  end;
  { Retain separate token and combined area/compatibility allowances even with
    bulk rule construction. Neither a small floor nor a small catalog alone
    establishes bounded practical work. This is a structural allowance, not a
    wall-clock response-time guarantee. }
  AReason := 'This local room exceeds its footprint work allowance; ' +
    'narrow eligible shapes or divide the room.';
  if (LTokens > 128) or (Double(LColumns) * LRows * LTokens * LTokens > 100000) then
  begin
    Exit;
  end;
  for I := 0 to High(ARequest.FFixed) do
  begin
    AReason := 'A preserved fixture needs a unique valid identity, asset and admitted floor pose.';
    J := FloorAssetIndex(ARequest.FAssets, ARequest.FFixed[I].FAssetId);
    if not IdentityValid(ARequest.FFixed[I].FId, 128) or (J < 0) or
      not WholeInRange(ARequest.FFixed[I].FQuarterTurn, 0, 3) or
      not WholeInRange(ARequest.FFixed[I].FCellX, 0, LColumns - 1) or
      not WholeInRange(ARequest.FFixed[I].FCellZ, 0, LRows - 1) then
    begin
      Exit;
    end;
    if not FloorAssetAvailable(ARequest, J) or
      ((ARequest.FAssets[J].FAllowedTurns and (1 shl ARequest.FFixed[I].FQuarterTurn)) = 0) then
    begin
      Exit;
    end;
    FloorSpan(ARequest, ARequest.FAssets[J], ARequest.FFixed[I].FQuarterTurn, LSpanX, LSpanZ);
    if (ARequest.FFixed[I].FCellX + LSpanX > LColumns) or
      (ARequest.FFixed[I].FCellZ + LSpanZ > LRows) then
    begin
      Exit;
    end;
    for K := 0 to I - 1 do
    begin
      if ARequest.FFixed[K].FId = ARequest.FFixed[I].FId then
      begin
        Exit;
      end;
    end;
  end;
  AReason := '';
  Result := True;
end;

function PointSegmentDistanceSquared(const AX, AZ, AX1, AZ1, AX2, AZ2: Double): Double;
var
  LLengthSquared: Double;
  LFraction: Double;
begin
  LLengthSquared := Sqr(AX2 - AX1) + Sqr(AZ2 - AZ1);
  LFraction := 0;
  if LLengthSquared > 0 then
  begin
    LFraction := EnsureRange(((AX - AX1) * (AX2 - AX1) +
      (AZ - AZ1) * (AZ2 - AZ1)) / LLengthSquared, 0.0, 1.0);
  end;
  Result := Sqr(AX - AX1 - LFraction * (AX2 - AX1)) +
    Sqr(AZ - AZ1 - LFraction * (AZ2 - AZ1));
end;

function SegmentDistanceSquared(const AX1, AZ1, AX2, AZ2,
  AOtherX1, AOtherZ1, AOtherX2, AOtherZ2: Double): Double;
var
  LDenominator: Double;
  LFirst: Double;
  LSecond: Double;
begin
  LDenominator := (AX2 - AX1) * (AOtherZ2 - AOtherZ1) -
    (AZ2 - AZ1) * (AOtherX2 - AOtherX1);
  if Abs(LDenominator) > 0.0000001 then
  begin
    LFirst := ((AOtherX1 - AX1) * (AOtherZ2 - AOtherZ1) -
      (AOtherZ1 - AZ1) * (AOtherX2 - AOtherX1)) / LDenominator;
    LSecond := ((AOtherX1 - AX1) * (AZ2 - AZ1) -
      (AOtherZ1 - AZ1) * (AX2 - AX1)) / LDenominator;
    if (LFirst >= 0) and (LFirst <= 1) and (LSecond >= 0) and (LSecond <= 1) then
    begin
      Exit(0);
    end;
  end;
  Result := Min(Min(PointSegmentDistanceSquared(AX1, AZ1,
    AOtherX1, AOtherZ1, AOtherX2, AOtherZ2),
    PointSegmentDistanceSquared(AX2, AZ2, AOtherX1, AOtherZ1, AOtherX2, AOtherZ2)),
    Min(PointSegmentDistanceSquared(AOtherX1, AOtherZ1, AX1, AZ1, AX2, AZ2),
    PointSegmentDistanceSquared(AOtherX2, AOtherZ2, AX1, AZ1, AX2, AZ2)));
end;

function FloorSegmentClear(const AX1, AZ1, AX2, AZ2, ARadius: Double;
  const ABounds: TFloorRectangle): Boolean;

  function Inside(const AX, AZ: Double): Boolean;
  begin
    Result := (AX >= ABounds.FMinX) and (AX <= ABounds.FMaxX) and
      (AZ >= ABounds.FMinZ) and (AZ <= ABounds.FMaxZ);
  end;

  function EdgeClear(const AX, AZ, AOtherX, AOtherZ: Double): Boolean;
  begin
    Result := SegmentDistanceSquared(AX1, AZ1, AX2, AZ2,
      AX, AZ, AOtherX, AOtherZ) >= Sqr(ARadius);
  end;

begin
  Result := (ARadius > 0) and (ABounds.FMinX <= ABounds.FMaxX) and
    (ABounds.FMinZ <= ABounds.FMaxZ) and not Inside(AX1, AZ1) and not Inside(AX2, AZ2) and
    EdgeClear(ABounds.FMinX, ABounds.FMinZ, ABounds.FMaxX, ABounds.FMinZ) and
    EdgeClear(ABounds.FMaxX, ABounds.FMinZ, ABounds.FMaxX, ABounds.FMaxZ) and
    EdgeClear(ABounds.FMaxX, ABounds.FMaxZ, ABounds.FMinX, ABounds.FMaxZ) and
    EdgeClear(ABounds.FMinX, ABounds.FMaxZ, ABounds.FMinX, ABounds.FMinZ);
end;

function FloorEntryClear(const ARequest: TFloorRequest;
  const ABounds: TFloorRectangle): Boolean;
var
  LX: Integer;
  LZ: Integer;
  LEntryX: Double;
  LEntryZ: Double;
begin
  FloorEntryCell(ARequest, LX, LZ);
  LEntryX := (LX + 0.5 - (ARequest.FWidth div ARequest.FPitch) / 2) * ARequest.FPitch;
  LEntryZ := (LZ + 0.5 - (ARequest.FDepth div ARequest.FPitch) / 2) * ARequest.FPitch;
  { Enter on the door centreline, then turn inside the first floor row.
    The validator also checks these swept segments against the split door wall. }
  Result := FloorSegmentClear(ARequest.FDoorX, ARequest.FDepth / 2 +
    ARequest.FPlayerRadius + 1, ARequest.FDoorX, LEntryZ,
    ARequest.FPlayerRadius, ABounds) and
    FloorSegmentClear(ARequest.FDoorX, LEntryZ, LEntryX, LEntryZ,
    ARequest.FPlayerRadius, ABounds);
end;

function ValidateFloorLayout(const ARequest: TFloorRequest; const ALayout: TFloorLayout;
  out AReason: String): Boolean;
var
  LColumns: Integer;
  LRows: Integer;
  LSpanX: Integer;
  LSpanZ: Integer;
  LAssetIndex: Integer;
  LCounts: array of Integer;
  LOwners: array of Integer;
  LReached: array of Boolean;
  LQueue: array of Integer;
  LBounds: array of TFloorRectangle;
  LWall: TFloorRectangle;
  LPlacement: TFloorPlacement;
  LAsset: TFloorAsset;
  LHead: Integer;
  LTail: Integer;
  LCell: Integer;
  LNext: Integer;
  LX: Integer;
  LZ: Integer;
  LTargetX: Integer;
  LTargetZ: Integer;
  LFound: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;

  function SegmentClear(const AFrom, ATo: Integer): Boolean;
  var
    LBoundsIndex: Integer;
    LFromX: Double;
    LFromZ: Double;
    LToX: Double;
    LToZ: Double;
  begin
    LFromX := (AFrom mod LColumns + 0.5 - LColumns / 2) * ARequest.FPitch;
    LFromZ := (AFrom div LColumns + 0.5 - LRows / 2) * ARequest.FPitch;
    LToX := (ATo mod LColumns + 0.5 - LColumns / 2) * ARequest.FPitch;
    LToZ := (ATo div LColumns + 0.5 - LRows / 2) * ARequest.FPitch;
    Result := (Min(LFromX, LToX) >= -ARequest.FWidth / 2 + ARequest.FPlayerRadius) and
      (Max(LFromX, LToX) <= ARequest.FWidth / 2 - ARequest.FPlayerRadius) and
      (Min(LFromZ, LToZ) >= -ARequest.FDepth / 2 + ARequest.FPlayerRadius) and
      (Max(LFromZ, LToZ) <= ARequest.FDepth / 2 - ARequest.FPlayerRadius);
    for LBoundsIndex := 0 to High(LBounds) do
    begin
      Result := Result and FloorSegmentClear(LFromX, LFromZ, LToX, LToZ,
        ARequest.FPlayerRadius, LBounds[LBoundsIndex]);
    end;
  end;

begin
  Result := False;
  if not ValidateFloorRequest(ARequest, AReason) then
  begin
    Exit;
  end;
  LColumns := ARequest.FWidth div ARequest.FPitch;
  LRows := ARequest.FDepth div ARequest.FPitch;
  AReason := 'The floor result has an invalid number of fixtures or floor cells.';
  if (Length(ALayout.FPlacements) > LColumns * LRows) or
    (Length(ALayout.FFreeCells) <> LColumns * LRows) then
  begin
    Exit;
  end;
  SetLength(LOwners, LColumns * LRows);
  SetLength(LCounts, Length(ARequest.FQuotas));
  SetLength(LBounds, Length(ALayout.FPlacements));
  for I := 0 to High(LOwners) do
  begin
    LOwners[I] := -1;
  end;
  for I := 0 to High(ALayout.FPlacements) do
  begin
    LPlacement := ALayout.FPlacements[I];
    LAssetIndex := FloorAssetIndex(ARequest.FAssets, LPlacement.FAssetId);
    AReason := 'A generated fixture has an invalid identity, asset or orientation.';
    if not IdentityValid(LPlacement.FId, 128) or (LAssetIndex < 0) or
      not WholeInRange(LPlacement.FQuarterTurn, 0, 3) or
      not WholeInRange(LPlacement.FCellX, 0, LColumns - 1) or
      not WholeInRange(LPlacement.FCellZ, 0, LRows - 1) then
    begin
      Exit;
    end;
    LAsset := ARequest.FAssets[LAssetIndex];
    if ContentRoleAllowed(ARequest.FUnavailableNewIds, LPlacement.FId) then
    begin
      LFound := False;
      for J := 0 to High(ARequest.FFixed) do
      begin
        LFound := LFound or (ARequest.FFixed[J].FId = LPlacement.FId);
      end;
      AReason := 'A new fixture uses a reserved document identity.';
      if not LFound then
      begin
        Exit;
      end;
    end;
    if not FloorAssetAvailable(ARequest, LAssetIndex) or
      ((LAsset.FAllowedTurns and (1 shl LPlacement.FQuarterTurn)) = 0) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      AReason := 'Fixture instance identities must be unique.';
      if ALayout.FPlacements[J].FId = LPlacement.FId then
      begin
        Exit;
      end;
    end;
    FloorSpan(ARequest, LAsset, LPlacement.FQuarterTurn, LSpanX, LSpanZ);
    AReason := 'A complete furniture footprint must fit the room floor.';
    if (LPlacement.FCellX + LSpanX > LColumns) or (LPlacement.FCellZ + LSpanZ > LRows) then
    begin
      Exit;
    end;
    for LZ := LPlacement.FCellZ to LPlacement.FCellZ + LSpanZ - 1 do
    begin
      for LX := LPlacement.FCellX to LPlacement.FCellX + LSpanX - 1 do
      begin
        LCell := LZ * LColumns + LX;
        AReason := 'Furniture footprint reservations overlap.';
        if LOwners[LCell] >= 0 then
        begin
          Exit;
        end;
        LOwners[LCell] := I;
      end;
    end;
    LBounds[I] := FloorBounds(ARequest, LPlacement, LAsset);
    AReason := 'A measured furniture envelope crosses the room walls or doorway approach.';
    if (LBounds[I].FMinX < -ARequest.FWidth / 2) or
      (LBounds[I].FMaxX > ARequest.FWidth / 2) or
      (LBounds[I].FMinZ < -ARequest.FDepth / 2) or
      (LBounds[I].FMaxZ > ARequest.FDepth / 2) or
      not FloorEntryClear(ARequest, LBounds[I]) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      AReason := 'Measured furniture envelopes intersect.';
      if (LBounds[I].FMinX < LBounds[J].FMaxX) and
        (LBounds[I].FMaxX > LBounds[J].FMinX) and
        (LBounds[I].FMinZ < LBounds[J].FMaxZ) and
        (LBounds[I].FMaxZ > LBounds[J].FMinZ) then
      begin
        Exit;
      end;
    end;
    for J := 0 to High(ARequest.FQuotas) do
    begin
      if ARequest.FQuotas[J].FRole = LAsset.FContent.FRole then
      begin
        Inc(LCounts[J]);
      end;
    end;
  end;
  for I := 0 to High(ARequest.FQuotas) do
  begin
    AReason := 'The room does not meet its fixture instance counts for ' +
      ARequest.FQuotas[I].FRole + '.';
    if (LCounts[I] < ARequest.FQuotas[I].FMinimum) or
      (LCounts[I] > ARequest.FQuotas[I].FMaximum) then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(ARequest.FFixed) do
  begin
    LFound := False;
    for J := 0 to High(ALayout.FPlacements) do
    begin
      if ALayout.FPlacements[J].FId = ARequest.FFixed[I].FId then
      begin
        LFound := (ALayout.FPlacements[J].FAssetId = ARequest.FFixed[I].FAssetId) and
          (ALayout.FPlacements[J].FCellX = ARequest.FFixed[I].FCellX) and
          (ALayout.FPlacements[J].FCellZ = ARequest.FFixed[I].FCellZ) and
          (ALayout.FPlacements[J].FQuarterTurn = ARequest.FFixed[I].FQuarterTurn);
      end;
    end;
    AReason := 'A preserved fixture was removed, renamed, moved or replaced.';
    if not LFound then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(LOwners) do
  begin
    AReason := 'The reported walking floor disagrees with the decoded furniture footprints.';
    if ALayout.FFreeCells[I] <> (LOwners[I] < 0) then
    begin
      Exit;
    end;
  end;
  { Validate the actual player disk swept through the doorway, including both
    jamb endpoints. Abstract free-cell connectivity alone does not prove this. }
  LWall.FMinX := -ARequest.FWidth / 2;
  LWall.FMaxX := ARequest.FDoorX - ARequest.FDoorWidth / 2;
  LWall.FMinZ := ARequest.FDepth / 2;
  LWall.FMaxZ := LWall.FMinZ;
  AReason := 'The player cannot clear the doorway jambs.';
  if not FloorEntryClear(ARequest, LWall) then
  begin
    Exit;
  end;
  LWall.FMinX := ARequest.FDoorX + ARequest.FDoorWidth / 2;
  LWall.FMaxX := ARequest.FWidth / 2;
  if not FloorEntryClear(ARequest, LWall) then
  begin
    Exit;
  end;
  SetLength(LReached, Length(LOwners));
  SetLength(LQueue, Length(LOwners));
  FloorEntryCell(ARequest, LX, LZ);
  LCell := LZ * LColumns + LX;
  AReason := 'The entry cell is obstructed.';
  if (LOwners[LCell] >= 0) or not SegmentClear(LCell, LCell) then
  begin
    Exit;
  end;
  LQueue[0] := LCell;
  LReached[LCell] := True;
  LHead := 0;
  LTail := 1;
  while LHead < LTail do
  begin
    LCell := LQueue[LHead];
    Inc(LHead);
    LX := LCell mod LColumns;
    LZ := LCell div LColumns;
    for K := 0 to 3 do
    begin
      LTargetX := LX;
      LTargetZ := LZ;
      case K of
        0:
        begin
          Inc(LTargetX);
        end;
        1:
        begin
          Dec(LTargetX);
        end;
        2:
        begin
          Inc(LTargetZ);
        end;
        3:
        begin
          Dec(LTargetZ);
        end;
      end;
      if (LTargetX < 0) or (LTargetX >= LColumns) or
        (LTargetZ < 0) or (LTargetZ >= LRows) then
      begin
        Continue;
      end;
      LNext := LTargetZ * LColumns + LTargetX;
      if not LReached[LNext] and (LOwners[LNext] < 0) and SegmentClear(LCell, LNext) then
      begin
        LReached[LNext] := True;
        LQueue[LTail] := LNext;
        Inc(LTail);
      end;
    end;
  end;
  for I := 0 to High(LOwners) do
  begin
    AReason := 'Some free floor has no connected route with the requested player clearance.';
    if (LOwners[I] < 0) and not LReached[I] then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(ALayout.FPlacements) do
  begin
    LPlacement := ALayout.FPlacements[I];
    LAsset := ARequest.FAssets[FloorAssetIndex(ARequest.FAssets, LPlacement.FAssetId)];
    if LAsset.FNeedsApproach then
    begin
      FloorApproachCell(ARequest, LPlacement, LAsset, LX, LZ);
      AReason := 'The operating side of a fixture has no reachable standing space.';
      if (LX < 0) or (LX >= LColumns) or (LZ < 0) or (LZ >= LRows) then
      begin
        Exit;
      end;
      if not LReached[LZ * LColumns + LX] then
      begin
        Exit;
      end;
    end;
  end;
  AReason := '';
  Result := True;
end;

end.
