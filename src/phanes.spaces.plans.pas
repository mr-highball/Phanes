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

unit phanes.spaces.plans;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.document;

const
  CabinTwoBays = 'phanes.plan.cabin.two-bays.v1';
  CabinFourBays = 'phanes.plan.cabin.four-bays.v1';
  CabinSixBays = 'phanes.plan.cabin.six-bays.v1';

function CabinPlanRows(const AProfile: String): Integer;
function CabinBay(const APlan: TCompositionNode; const ANumber: Integer): TCompositionNode;
function SpacePlanOwner(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANode: Integer): String;
function ValidateCabinPlan(const ADocument: TCompositionDocument; const APlanId: String;
  out AReason: String): Boolean;
function CreateCabinPlan(const ABaseline: TCompositionDocument; const ABuildingId, AProfile: String;
  const ASeed: Cardinal; const AExpectedRevision: Integer;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;

implementation

uses
  SysUtils,
  phanes.spaces.programs,
  phanes.spaces.rooms;

function CabinPlanRows(const AProfile: String): Integer;
begin
  Result := 0;
  if AProfile = CabinTwoBays then
  begin
    Result := 1;
  end
  else if AProfile = CabinFourBays then
  begin
    Result := 2;
  end
  else if AProfile = CabinSixBays then
  begin
    Result := 3;
  end;
end;

function CabinBay(const APlan: TCompositionNode; const ANumber: Integer): TCompositionNode;
var
  LRows: Integer;
  LRow: Integer;
begin
  Result := Default(TCompositionNode);
  LRows := CabinPlanRows(APlan.FAssetId);
  if (LRows = 0) or (ANumber < 1) or (ANumber > LRows * 2) then
  begin
    Exit;
  end;
  LRow := (ANumber - 1) mod LRows;
  Result.FId := APlan.FId + '.bay-' + IntToStr(ANumber);
  Result.FParentId := APlan.FId;
  Result.FKind := ckContainer;
  Result.FRole := 'bay';
  Result.FAssetId := 'phanes.space.bay.v1';
  Result.FName := 'Bay ' + UnicodeString(IntToStr(ANumber));
  Result.FWidth := (9200 - (LRows - 1) * 100) div LRows;
  Result.FDepth := 3900;
  Result.FHeight := 2700;
  Result.FZ := -4600 + Result.FWidth div 2 + LRow * (Result.FWidth + 100);
  Result.FX := -2700;
  Result.FQuarterTurn := 1;
  if ANumber > LRows then
  begin
    Result.FX := 2700;
    Result.FQuarterTurn := 3;
  end;
  Result.FSeed := APlan.FSeed;
end;

function SpacePlanOwner(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANode: Integer): String;
var
  LCurrent: Integer;
  LDepth: Integer;
begin
  Result := '';
  LCurrent := ANode;
  for LDepth := 0 to 127 do
  begin
    if (LCurrent < 0) or (LCurrent >= Length(ADocument.FNodes)) then
    begin
      Exit;
    end;
    if ADocument.FNodes[LCurrent].FRole = 'floor-plan' then
    begin
      Exit(ADocument.FNodes[LCurrent].FId);
    end;
    LCurrent := AIndex.Find(ADocument.FNodes[LCurrent].FParentId);
  end;
end;

function SameGeometry(const ANode, AProfile: TCompositionNode): Boolean;
begin
  Result := (ANode.FId = AProfile.FId) and (ANode.FParentId = AProfile.FParentId) and
    (ANode.FSupportId = AProfile.FSupportId) and (ANode.FKind = AProfile.FKind) and
    (ANode.FRole = AProfile.FRole) and (ANode.FAssetId = AProfile.FAssetId) and
    (ANode.FX = AProfile.FX) and (ANode.FY = AProfile.FY) and
    (ANode.FZ = AProfile.FZ) and (ANode.FQuarterTurn = AProfile.FQuarterTurn) and
    (ANode.FWidth = AProfile.FWidth) and (ANode.FDepth = AProfile.FDepth) and
    (ANode.FHeight = AProfile.FHeight);
end;

function ValidateCabinPlan(const ADocument: TCompositionDocument; const APlanId: String;
  out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LPlan: TCompositionNode;
  LBay: TCompositionNode;
  LRoom: TCompositionNode;
  LPlanIndex: Integer;
  LBuilding: Integer;
  LFound: Integer;
  LRows: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  if not ValidateComposition(ADocument, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    AReason := 'Select a complete, admitted cabin floor plan.';
    LPlanIndex := LIndex.Find(APlanId);
    if LPlanIndex < 0 then
    begin
      Exit;
    end;
    LPlan := ADocument.FNodes[LPlanIndex];
    LBuilding := LIndex.Find(LPlan.FParentId);
    LRows := CabinPlanRows(LPlan.FAssetId);
    if (LRows = 0) or (LBuilding < 0) or (LPlan.FId <> LPlan.FParentId + '.plan') or
      (LPlan.FRole <> 'floor-plan') or (LPlan.FKind <> ckContainer) or
      (LPlan.FSupportId <> '') or (LPlan.FX <> 0) or (LPlan.FY <> 80) or
      (LPlan.FZ <> 0) or (LPlan.FQuarterTurn <> 0) or
      (LPlan.FWidth <> 9400) or (LPlan.FDepth <> 9400) or (LPlan.FHeight <> 2700) then
    begin
      Exit;
    end;
    if (ADocument.FNodes[LBuilding].FKind <> ckContainer) or
      (ADocument.FNodes[LBuilding].FRole <> 'building') or
      (ADocument.FNodes[LBuilding].FAssetId <> 'cabin') or
      HasCompositionExtent(ADocument.FNodes[LBuilding]) then
    begin
      Exit;
    end;
    LCount := 0;
    for I := 0 to High(ADocument.FNodes) do
    begin
      if ADocument.FNodes[I].FParentId = LPlan.FParentId then
      begin
        Inc(LCount);
      end;
    end;
    AReason := 'A cabin contains one complete interior; studios and room plans cannot overlap.';
    if LCount <> 1 then
    begin
      Exit;
    end;
    LCount := 0;
    for I := 0 to High(ADocument.FNodes) do
    begin
      if ADocument.FNodes[I].FParentId = APlanId then
      begin
        Inc(LCount);
      end;
    end;
    AReason := 'The plan must retain all bays and their shared clear corridor.';
    if LCount <> LRows * 2 then
    begin
      Exit;
    end;
    for I := 1 to LRows * 2 do
    begin
      LBay := CabinBay(LPlan, I);
      LFound := LIndex.Find(LBay.FId);
      if LFound < 0 then
      begin
        Exit;
      end;
      if not SameGeometry(ADocument.FNodes[LFound], LBay) then
      begin
        Exit;
      end;
      LRoom := Default(TCompositionNode);
      LRoom.FId := LBay.FId + '.room';
      LRoom.FParentId := LBay.FId;
      LRoom.FKind := ckContainer;
      LRoom.FRole := 'room';
      LRoom.FWidth := LBay.FWidth;
      LRoom.FDepth := LBay.FDepth;
      LRoom.FHeight := LBay.FHeight;
      LFound := LIndex.Find(LRoom.FId);
      if LFound < 0 then
      begin
        Exit;
      end;
      LRoom.FAssetId := ADocument.FNodes[LFound].FAssetId;
      if not SameGeometry(ADocument.FNodes[LFound], LRoom) then
      begin
        Exit;
      end;
      LCount := 0;
      for J := 0 to High(ADocument.FNodes) do
      begin
        if ADocument.FNodes[J].FParentId = LBay.FId then
        begin
          Inc(LCount);
        end;
      end;
      if (LCount <> 1) or not ValidateProgramRoom(ADocument, LRoom.FId, AReason) then
      begin
        Exit;
      end;
    end;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

function CreateCabinPlan(const ABaseline: TCompositionDocument; const ABuildingId, AProfile: String;
  const ASeed: Cardinal; const AExpectedRevision: Integer;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
var
  LCandidate: TCompositionDocument;
  LIndex: TCompositionIndex;
  LPlan: TCompositionNode;
  LBay: TCompositionNode;
  LRoom: TCompositionNode;
  LBuilding: Integer;
  LCount: Integer;
  LRows: Integer;
  I: Integer;

  procedure Append(const ANode: TCompositionNode);
  var
    LNext: Integer;
  begin
    LNext := Length(LCandidate.FNodes);
    SetLength(LCandidate.FNodes, LNext + 1);
    LCandidate.FNodes[LNext] := ANode;
  end;

begin
  Result := False;
  AReason := 'The building changed before this floor plan could be applied.';
  if AExpectedRevision <> ABaseline.FRevision then
  begin
    Exit;
  end;
  if not ValidateComposition(ABaseline, AReason) then
  begin
    Exit;
  end;
  LRows := CabinPlanRows(AProfile);
  LIndex := TCompositionIndex.Create(ABaseline.FNodes);
  try
    LBuilding := LIndex.Find(ABuildingId);
    AReason := 'Choose a cabin and an admitted floor plan.';
    if (LBuilding < 0) or (LRows = 0) then
    begin
      Exit;
    end;
    if (ABaseline.FNodes[LBuilding].FRole <> 'building') or
      (ABaseline.FNodes[LBuilding].FKind <> ckContainer) or
      (ABaseline.FNodes[LBuilding].FAssetId <> 'cabin') then
    begin
      Exit;
    end;
    LCandidate := CopyDocument(ABaseline);
    LCount := 0;
    for I := 0 to High(ABaseline.FNodes) do
    begin
      if (I = LBuilding) or not InCompositionScope(ABaseline, LIndex, I, ABuildingId) then
      begin
        LCandidate.FNodes[LCount] := ABaseline.FNodes[I];
        Inc(LCount);
      end;
    end;
    SetLength(LCandidate.FNodes, LCount);
    LPlan := Default(TCompositionNode);
    LPlan.FId := ABuildingId + '.plan';
    LPlan.FParentId := ABuildingId;
    LPlan.FKind := ckContainer;
    LPlan.FRole := 'floor-plan';
    LPlan.FAssetId := AProfile;
    LPlan.FName := 'Rooms';
    LPlan.FY := 80;
    LPlan.FWidth := 9400;
    LPlan.FDepth := 9400;
    LPlan.FHeight := 2700;
    LPlan.FSeed := ASeed;
    Append(LPlan);
    for I := 1 to LRows * 2 do
    begin
      LBay := CabinBay(LPlan, I);
      Append(LBay);
      LRoom := Default(TCompositionNode);
      LRoom.FId := LBay.FId + '.room';
      LRoom.FParentId := LBay.FId;
      LRoom.FKind := ckContainer;
      LRoom.FRole := 'room';
      LRoom.FName := RoomProgramName(EmptyRoomProgram);
      LRoom.FAssetId := EmptyRoomProgram;
      LRoom.FWidth := LBay.FWidth;
      LRoom.FDepth := LBay.FDepth;
      LRoom.FHeight := LBay.FHeight;
      LRoom.FSeed := ASeed;
      Append(LRoom);
    end;
    if not ValidateCabinPlan(LCandidate, LPlan.FId, AReason) then
    begin
      Exit;
    end;
    Result := CommitComposition(ABaseline, LCandidate, ABuildingId,
      AExpectedRevision, ACommitted, AReason);
  finally
    LIndex.Free;
  end;
end;

end.

