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
unit phanes.spaces.floor.generate;
{$mode delphi}
{$H+}

interface

uses
  phanes.spaces.floor.types;

function GenerateFloor(const ARequest: TFloorRequest; var ACommitted: TFloorLayout;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  phanes.composition.contents.types,
  wfc,
  phanes.spaces.floor.validate;

type
  TFloorVariant = record
    FAssetIndex: Integer;
    FQuarterTurn: Integer;
    FColumns: Integer;
    FRows: Integer;
    FApproachX: Integer;
    FApproachZ: Integer;
    FFirstToken: Integer;
  end;
  TFloorVariants = array of TFloorVariant;

  TFloorToken = record
    FValue: String;
    FVariantIndex: Integer;
    FX: Integer;
    FZ: Integer;
  end;
  TFloorTokens = array of TFloorToken;

function GenerateFloor(const ARequest: TFloorRequest; var ACommitted: TFloorLayout;
  out AReason: String): Boolean;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LVariants: TFloorVariants;
  LTokens: TFloorTokens;
  LRuleMatrix: array of TGraphRules;
  LDeniedDirections: array of TGraphDirections;
  LAllowed: TGraphValues;
  LQuotaValues: TGraphValues;
  LVariant: TFloorVariant;
  LPlacement: TFloorPlacement;
  LCandidate: TFloorLayout;
  LFixedOwners: array of Integer;
  LFixedTokens: array of Integer;
  LAnchorAllowed: array of array of Boolean;
  LColumns: Integer;
  LRows: Integer;
  LRoot: TGraphPosition;
  LDirection: TGraphDirection;
  LDX: Integer;
  LDZ: Integer;
  LVariantIndex: Integer;
  LTokenIndex: Integer;
  LFixedVariant: Integer;
  LCell: Integer;
  LQuotaIndex: Integer;
  LCount: Integer;
  LX: Integer;
  LZ: Integer;
  LTurn: Integer;
  I: Integer;
  J: Integer;

  function RoleMaximum(const ARole: String): Integer;
  var
    LQuota: Integer;
  begin
    Result := 0;
    for LQuota := 0 to High(ARequest.FQuotas) do
    begin
      if ARequest.FQuotas[LQuota].FRole = ARole then
      begin
        Exit(ARequest.FQuotas[LQuota].FMaximum);
      end;
    end;
  end;

  function OutgoingCompatible(const AToken, AOther, AX, AZ: Integer): Boolean;
  var
    LToken: TFloorToken;
    LOther: TFloorToken;
    LShape: TFloorVariant;
    LNextX: Integer;
    LNextZ: Integer;
  begin
    if AToken = 0 then
    begin
      Exit(True);
    end;
    LToken := LTokens[AToken];
    LOther := LTokens[AOther];
    LShape := LVariants[LToken.FVariantIndex];
    LNextX := LToken.FX + AX;
    LNextZ := LToken.FZ + AZ;
    if (LNextX >= 0) and (LNextX < LShape.FColumns) and
      (LNextZ >= 0) and (LNextZ < LShape.FRows) then
    begin
      Exit((AOther > 0) and (LOther.FVariantIndex = LToken.FVariantIndex) and
        (LOther.FX = LNextX) and (LOther.FZ = LNextZ));
    end;
    if ARequest.FAssets[LShape.FAssetIndex].FNeedsApproach and
      (LNextX = LShape.FApproachX) and (LNextZ = LShape.FApproachZ) then
    begin
      Exit(AOther = 0);
    end;
    Result := True;
  end;

  function AnchorAllowed(const AVariant, AX, AZ: Integer): Boolean;
  var
    LShape: TFloorVariant;
    LFixture: TFloorPlacement;
    LFixtureId: String;
    LFixedIndex: Integer;
    LOwner: Integer;
    LPosition: Integer;
    LLocalX: Integer;
    LLocalZ: Integer;
  begin
    LShape := LVariants[AVariant];
    Result := False;
    if (AX + LShape.FColumns > LColumns) or (AZ + LShape.FRows > LRows) then
    begin
      Exit;
    end;
    if ARequest.FAssets[LShape.FAssetIndex].FNeedsApproach and
      ((AX + LShape.FApproachX < 0) or (AX + LShape.FApproachX >= LColumns) or
      (AZ + LShape.FApproachZ < 0) or (AZ + LShape.FApproachZ >= LRows)) then
    begin
      Exit;
    end;
    LFixture := Default(TFloorPlacement);
    LFixture.FAssetId := ARequest.FAssets[LShape.FAssetIndex].FContent.FId;
    LFixture.FCellX := AX;
    LFixture.FCellZ := AZ;
    LFixture.FQuarterTurn := LShape.FQuarterTurn;
    if not FloorEntryClear(ARequest,
      FloorBounds(ARequest, LFixture, ARequest.FAssets[LShape.FAssetIndex])) then
    begin
      Exit;
    end;
    LFixedIndex := -1;
    for LLocalZ := 0 to LShape.FRows - 1 do
    begin
      for LLocalX := 0 to LShape.FColumns - 1 do
      begin
        LPosition := (AZ + LLocalZ) * LColumns + AX + LLocalX;
        if LPosition = LRoot.Y * LColumns + LRoot.X then
        begin
          Exit;
        end;
        LOwner := LFixedOwners[LPosition];
        if LOwner >= 0 then
        begin
          if (ARequest.FFixed[LOwner].FAssetId <> LFixture.FAssetId) or
            (ARequest.FFixed[LOwner].FQuarterTurn <> LFixture.FQuarterTurn) or
            (ARequest.FFixed[LOwner].FCellX <> AX) or
            (ARequest.FFixed[LOwner].FCellZ <> AZ) then
          begin
            Exit;
          end;
          LFixedIndex := LOwner;
        end;
      end;
    end;
    { Generated identities must not steal an existing caller identity elsewhere.
      Preserved objects keep their complete identity independently of cell order. }
    if LFixedIndex < 0 then
    begin
      LFixtureId := ARequest.FScopeId + '.item-' + IntToStr(AX) + '-' + IntToStr(AZ);
      if ContentRoleAllowed(ARequest.FUnavailableNewIds, LFixtureId) then
      begin
        Exit;
      end;
      for LOwner := 0 to High(ARequest.FFixed) do
      begin
        if ARequest.FFixed[LOwner].FId = LFixtureId then
        begin
          Exit;
        end;
      end;
    end;
    Result := True;
  end;

begin
  Result := False;
  if not ValidateFloorRequest(ARequest, AReason) then
  begin
    Exit;
  end;
  LColumns := ARequest.FWidth div ARequest.FPitch;
  LRows := ARequest.FDepth div ARequest.FPitch;
  FloorEntryCell(ARequest, LX, LZ);
  LRoot.X := LX;
  LRoot.Y := LZ;
  LRoot.Z := 0;
  LCandidate := Default(TFloorLayout);
  LVariants := nil;
  SetLength(LTokens, 1);
  LTokens[0].FValue := 'free';
  LTokens[0].FVariantIndex := -1;
  for I := 0 to High(ARequest.FAssets) do
  begin
    if not FloorAssetAvailable(ARequest, I) or
      (RoleMaximum(ARequest.FAssets[I].FContent.FRole) = 0) then
    begin
      Continue;
    end;
    for LTurn := 0 to 3 do
    begin
      if (ARequest.FAssets[I].FAllowedTurns and (1 shl LTurn)) = 0 then
      begin
        Continue;
      end;
      LVariant := Default(TFloorVariant);
      LVariant.FAssetIndex := I;
      LVariant.FQuarterTurn := LTurn;
      FloorSpan(ARequest, ARequest.FAssets[I], LTurn, LVariant.FColumns, LVariant.FRows);
      if (LVariant.FColumns > LColumns) or (LVariant.FRows > LRows) then
      begin
        Continue;
      end;
      LVariant.FFirstToken := Length(LTokens);
      LPlacement := Default(TFloorPlacement);
      LPlacement.FQuarterTurn := LTurn;
      FloorApproachCell(ARequest, LPlacement, ARequest.FAssets[I],
        LVariant.FApproachX, LVariant.FApproachZ);
      LVariantIndex := Length(LVariants);
      SetLength(LVariants, LVariantIndex + 1);
      LVariants[LVariantIndex] := LVariant;
      for LZ := 0 to LVariant.FRows - 1 do
      begin
        for LX := 0 to LVariant.FColumns - 1 do
        begin
          LTokenIndex := Length(LTokens);
          SetLength(LTokens, LTokenIndex + 1);
          LTokens[LTokenIndex].FValue := 'part-' + IntToStr(LTokenIndex);
          LTokens[LTokenIndex].FVariantIndex := LVariantIndex;
          LTokens[LTokenIndex].FX := LX;
          LTokens[LTokenIndex].FZ := LZ;
        end;
      end;
    end;
  end;
  SetLength(LFixedOwners, LColumns * LRows);
  SetLength(LFixedTokens, LColumns * LRows);
  for I := 0 to High(LFixedOwners) do
  begin
    LFixedOwners[I] := -1;
    LFixedTokens[I] := -1;
  end;
  for I := 0 to High(ARequest.FFixed) do
  begin
    LFixedVariant := -1;
    for J := 0 to High(LVariants) do
    begin
      if (ARequest.FAssets[LVariants[J].FAssetIndex].FContent.FId =
        ARequest.FFixed[I].FAssetId) and
        (LVariants[J].FQuarterTurn = ARequest.FFixed[I].FQuarterTurn) then
      begin
        LFixedVariant := J;
      end;
    end;
    AReason := 'A preserved fixture is unavailable under this room program.';
    if LFixedVariant < 0 then
    begin
      Exit;
    end;
    LVariant := LVariants[LFixedVariant];
    for LZ := 0 to LVariant.FRows - 1 do
    begin
      for LX := 0 to LVariant.FColumns - 1 do
      begin
        LCell := (ARequest.FFixed[I].FCellZ + LZ) * LColumns + ARequest.FFixed[I].FCellX + LX;
        AReason := 'Preserved furniture footprints overlap.';
        if LFixedOwners[LCell] >= 0 then
        begin
          Exit;
        end;
        LFixedOwners[LCell] := I;
        LFixedTokens[LCell] := LVariant.FFirstToken + LZ * LVariant.FColumns + LX;
      end;
    end;
  end;
  SetLength(LAnchorAllowed, Length(LVariants));
  for I := 0 to High(LVariants) do
  begin
    SetLength(LAnchorAllowed[I], LColumns * LRows);
    for LZ := 0 to LRows - 1 do
    begin
      for LX := 0 to LColumns - 1 do
      begin
        LAnchorAllowed[I][LZ * LColumns + LX] := AnchorAllowed(I, LX, LZ);
      end;
    end;
  end;
  LGraph := TGraph.Create;
  try
    { Each non-free value is one offset inside a whole rectangular fixture.
      Reciprocal rules join its exact sibling offsets; boundary domains reject
      truncated rectangles. Only offset (0,0) participates in instance quotas.
      One front-edge token reserves a connected, unoccupied operating cell. }
    LGraph.Reshape(LColumns, LRows, 1);
    LGraph.Seed := ARequest.FSeed;
    LGraph.CurrentPass := 'floor';
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    for I := 0 to High(LTokens) do
    begin
      LGraph.AddValue(LTokens[I].FValue);
    end;
    SetLength(LRuleMatrix, Length(LTokens));
    SetLength(LDeniedDirections, Length(LTokens));
    for I := 0 to High(LTokens) do
    begin
      SetLength(LRuleMatrix[I], 4);
      for LDirection := gdNorth to gdWest do
      begin
        LDX := 0;
        LDZ := 0;
        case LDirection of
          gdNorth:
          begin
            LDZ := 1;
          end;
          gdEast:
          begin
            LDX := 1;
          end;
          gdSouth:
          begin
            LDZ := -1;
          end;
          gdWest:
          begin
            LDX := -1;
          end;
        else
          raise Exception.Create('Unexpected floor neighbour direction.');
        end;
        LAllowed := nil;
        for J := 0 to High(LTokens) do
        begin
          if OutgoingCompatible(I, J, LDX, LDZ) and OutgoingCompatible(J, I, -LDX, -LDZ) then
          begin
            LAllowed := LAllowed + [LTokens[J].FValue];
          end;
        end;
        LRuleMatrix[I][Ord(LDirection)].Key := InverseOfDir(LDirection);
        LRuleMatrix[I][Ord(LDirection)].Info := False;
        LRuleMatrix[I][Ord(LDirection)].Value := LAllowed;
        if Length(LAllowed) = 0 then
        begin
          Include(LDeniedDirections[I], InverseOfDir(LDirection));
        end;
      end;
    end;
    { The complete matrix is already reciprocal. Repeated NewRule calls each
      synchronize inverse rules across the whole graph and become very costly.
      Use WFC's public bulk Rules path, also used by its rule/model adapters.
      Every direction owns a detached array; an empty list must be explicitly
      denied because a legacy present-empty rule otherwise means wildcard. }
    for I := 0 to High(LTokens) do
    begin
      LGraph.Rules[LTokens[I].FValue].Rules := LRuleMatrix[I];
    end;
    for I := 0 to High(LTokens) do
    begin
      if LDeniedDirections[I] <> [] then
      begin
        LGraph.Rules[LTokens[I].FValue].DenyAll(LDeniedDirections[I]);
      end;
    end;
    for LQuotaIndex := 0 to High(ARequest.FQuotas) do
    begin
      LQuotaValues := nil;
      for I := 0 to High(LVariants) do
      begin
        if ARequest.FAssets[LVariants[I].FAssetIndex].FContent.FRole =
          ARequest.FQuotas[LQuotaIndex].FRole then
        begin
          LQuotaValues := LQuotaValues + [LTokens[LVariants[I].FFirstToken].FValue];
        end;
      end;
      if Length(LQuotaValues) = 0 then
      begin
        AReason := 'No eligible fixture supplies required role ' +
          ARequest.FQuotas[LQuotaIndex].FRole + '.';
        if ARequest.FQuotas[LQuotaIndex].FMinimum > 0 then
        begin
          Exit;
        end;
        Continue;
      end;
      LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('role-' + IntToStr(LQuotaIndex),
        LQuotaValues, ARequest.FQuotas[LQuotaIndex].FMinimum, ARequest.FQuotas[LQuotaIndex].FMaximum));
    end;
    LGraph.RequireConnectivity(MakeGraphConnectivityConstraint('entry-and-operating-floor',
      LRoot, [], [MakeGraphConnectivityValue('free', [gdNorth, gdEast, gdSouth, gdWest])], True));
    for LZ := 0 to LRows - 1 do
    begin
      for LX := 0 to LColumns - 1 do
      begin
        LCell := LZ * LColumns + LX;
        LAllowed := nil;
        if LFixedOwners[LCell] < 0 then
        begin
          LAllowed := ['free'];
        end;
        for I := 1 to High(LTokens) do
        begin
          if (LFixedTokens[LCell] >= 0) and (LFixedTokens[LCell] <> I) then
          begin
            Continue;
          end;
          if (LX >= LTokens[I].FX) and (LZ >= LTokens[I].FZ) and
            LAnchorAllowed[LTokens[I].FVariantIndex][
            (LZ - LTokens[I].FZ) * LColumns + LX - LTokens[I].FX] then
          begin
            LAllowed := LAllowed + [LTokens[I].FValue];
          end;
        end;
        AReason := 'A preserved fixture blocks the entrance or its required operating space.';
        if Length(LAllowed) = 0 then
        begin
          Exit;
        end;
        LGraph.SetAllowedValues(LX, LZ, 0, LAllowed);
      end;
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := ARequest.FMaxBacktracks;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'The room floor did not resolve within this search allowance.';
      Exit;
    end;
    SetLength(LCandidate.FFreeCells, LColumns * LRows);
    for LZ := 0 to LRows - 1 do
    begin
      for LX := 0 to LColumns - 1 do
      begin
        LCell := LZ * LColumns + LX;
        LCandidate.FFreeCells[LCell] := LGraph.Entry[LX, LZ, 0].Value = 'free';
        if LCandidate.FFreeCells[LCell] then
        begin
          Continue;
        end;
        LTokenIndex := -1;
        for I := 1 to High(LTokens) do
        begin
          if LTokens[I].FValue = LGraph.Entry[LX, LZ, 0].Value then
          begin
            LTokenIndex := I;
            Break;
          end;
        end;
        if (LTokenIndex < 0) or (LTokens[LTokenIndex].FX <> 0) or (LTokens[LTokenIndex].FZ <> 0) then
        begin
          Continue;
        end;
        LVariant := LVariants[LTokens[LTokenIndex].FVariantIndex];
        LPlacement := Default(TFloorPlacement);
        LPlacement.FAssetId := ARequest.FAssets[LVariant.FAssetIndex].FContent.FId;
        LPlacement.FCellX := LX;
        LPlacement.FCellZ := LZ;
        LPlacement.FQuarterTurn := LVariant.FQuarterTurn;
        LPlacement.FId := ARequest.FScopeId + '.item-' + IntToStr(LX) + '-' + IntToStr(LZ);
        if LFixedOwners[LCell] >= 0 then
        begin
          LPlacement.FId := ARequest.FFixed[LFixedOwners[LCell]].FId;
        end;
        LCount := Length(LCandidate.FPlacements);
        SetLength(LCandidate.FPlacements, LCount + 1);
        LCandidate.FPlacements[LCount] := LPlacement;
      end;
    end;
    for I := 0 to High(LReport.Passes) do
    begin
      Inc(LCandidate.FDecisions, LReport.Passes[I].Decisions);
      Inc(LCandidate.FPropagations, LReport.Passes[I].Propagations);
      Inc(LCandidate.FBacktracks, LReport.Passes[I].Backtracks);
    end;
    if not ValidateFloorLayout(ARequest, LCandidate, AReason) then
    begin
      Exit;
    end;
    ACommitted := LCandidate;
    Result := True;
  finally
    LGraph.Free;
  end;
end;

end.
