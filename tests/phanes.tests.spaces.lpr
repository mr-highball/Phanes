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

program PhanesSpacesTests;
{$mode delphi}
{$H+}

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire,
  phanes.composition.contents.types,
  phanes.composition.contents.generate,
  phanes.interiors.surfaces,
  phanes.spaces.programs,
  phanes.spaces.rooms,
  phanes.spaces.plans,
  phanes.tests.spaces.critic,
  phanes.spaces.floor.types;

var
  GChecks: Integer;
  GCriticChecks: Integer;
  GReason: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage + ': ' + GReason);
  end;
end;

function Fixture: TCompositionDocument;
var
  LNode: TCompositionNode;
  I: Integer;
begin
  Result := Default(TCompositionDocument);
  Result.FRevision := 12;
  SetLength(Result.FNodes, 5);
  LNode := Default(TCompositionNode);
  LNode.FId := 'world';
  LNode.FName := 'World';
  LNode.FRole := 'world';
  LNode.FKind := ckContainer;
  Result.FNodes[0] := LNode;
  for I := 0 to 1 do
  begin
    LNode := Default(TCompositionNode);
    LNode.FId := 'bay-' + IntToStr(5 + I);
    LNode.FParentId := 'world';
    LNode.FRole := 'bay';
    LNode.FName := 'Bay ' + UnicodeString(IntToStr(5 + I));
    LNode.FWidth := 3000;
    LNode.FDepth := 3900;
    LNode.FHeight := 2700;
    LNode.FX := I * 5000;
    Result.FNodes[1 + I * 2] := LNode;
    LNode.FId := LNode.FId + '.room';
    LNode.FParentId := Result.FNodes[1 + I * 2].FId;
    LNode.FRole := 'room';
    LNode.FName := 'Empty room';
    LNode.FAssetId := EmptyRoomProgram;
    LNode.FX := 0;
    Result.FNodes[2 + I * 2] := LNode;
  end;
end;

function FindRole(const ADocument: TCompositionDocument; const ARoom, ARole: String): Integer;
var
  LIndex: TCompositionIndex;
  I: Integer;
begin
  Result := -1;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    for I := 0 to High(ADocument.FNodes) do
    begin
      if (ADocument.FNodes[I].FRole = ARole) and
        InCompositionScope(ADocument, LIndex, I, ARoom) then
      begin
        Exit(I);
      end;
    end;
  finally
    LIndex.Free;
  end;
end;

procedure TestPrograms;
var
  LEmpty: TCompositionDocument;
  LDocument: TCompositionDocument;
  LReloaded: TCompositionDocument;
  LChanged: TCompositionDocument;
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LRequest: TContentRequest;
  LFloor: TFloorRequest;
  LLayout: TFloorLayout;
  LBefore: String;
  LShelf: String;
  LSurface: String;
  LSnail: String;
  LCount: Integer;
  LSeed: Cardinal;
  I: Integer;
  J: Integer;
begin
  LEmpty := Fixture;
  Check(ValidateProgramRoom(LEmpty, 'bay-5.room', GReason), 'Empty room');
  for I := 0 to 31 do
  begin
    LSeed := I;
    if I = 31 then
    begin
      LSeed := High(Cardinal);
    end;
    Check(GenerateProgramRoom(LEmpty, 'bay-5.room', LaboratoryProgram, LSeed,
      12, True, LDocument, GReason), 'Generate laboratory ' + IntToStr(I));
    Check(LDocument.FRevision = 13, 'One laboratory transaction');
    Check(ValidateProgramRoom(LDocument, 'bay-5.room', GReason), 'Validate complete laboratory');
    Check(GenerateProgramRoom(LDocument, 'bay-6.room', BathroomProgram, LSeed,
      13, True, LChanged, GReason), 'Generate neighboring bathroom');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      for J := 0 to High(LDocument.FNodes) do
      begin
        LNode := LDocument.FNodes[J];
        if Pos('bay-6.room', LNode.FId) <> 1 then
        begin
          Check(SameNode(LNode, LChanged.FNodes[LIndex.Find(LNode.FId)]),
            'Neighbor generation preserves ' + LNode.FId);
        end;
      end;
    finally
      LIndex.Free;
    end;
    Check(ReadProgramRoom(LChanged, 'bay-6.room', LFloor, LLayout, GReason), 'Read bathroom');
    Check(Length(LLayout.FPlacements) = 3, 'Three bathroom fixture instances');
    LBefore := CompositionJSON(LChanged);
    Check(ReadCompositionJSON(LBefore, LReloaded, GReason), 'Restore composition v2');
    Check(CompositionJSON(LReloaded) = LBefore, 'Exact restored program document');
    Check(ValidateProgramRoom(LReloaded, 'bay-5.room', GReason), 'Restored lab geometry');
    Check(ValidateProgramRoom(LReloaded, 'bay-6.room', GReason), 'Restored bath geometry');
    LDocument := LChanged;
  end;

  LShelf := LDocument.FNodes[FindRole(LDocument, 'bay-5.room', 'bookcase')].FId;
  LSurface := LShelf + '.tier-4';
  LCount := 0;
  for I := 0 to High(LDocument.FNodes) do
  begin
    LNode := LDocument.FNodes[I];
    if (LNode.FParentId = LSurface) and (LNode.FRole = 'book') then
    begin
      Inc(LCount);
    end;
  end;
  Check(LCount = 3, 'Shelf four has three separate books');
  LSurface := LShelf + '.tier-2';
  LSnail := '';
  for I := 0 to High(LDocument.FNodes) do
  begin
    LNode := LDocument.FNodes[I];
    if (LNode.FParentId = LSurface) and (LNode.FRole = 'ornament') then
    begin
      Check(LSnail = '', 'Shelf two has one snail');
      LSnail := LNode.FId;
    end;
  end;
  Check(LSnail <> '', 'Shelf two has a ceramic snail');

  Check(GenerateProgramRoom(LDocument, 'bay-5.room', LaboratoryProgram, 875, 14,
    False, LChanged, GReason), 'Reimagine furnished lab');
  LIndex := TCompositionIndex.Create(LChanged.FNodes);
  try
    for I := 0 to High(LDocument.FNodes) do
    begin
      LNode := LDocument.FNodes[I];
      if (Pos(LShelf, LNode.FId) = 1) or (Pos('bay-6', LNode.FId) = 1) then
      begin
        Check(SameNode(LNode, LChanged.FNodes[LIndex.Find(LNode.FId)]),
          'Reimagine preserves shelf subtree and neighbor');
      end;
    end;
  finally
    LIndex.Free;
  end;
  LBefore := CompositionJSON(LChanged);
  Check(not GenerateProgramRoom(LDocument, 'bay-5.room', BathroomProgram, 2, 14,
    False, LChanged, GReason), 'Purpose switch must be explicit');
  Check(CompositionJSON(LChanged) = LBefore, 'Rejected switch preserves result');
  Check(not GenerateProgramRoom(LDocument, 'bay-5.room', BathroomProgram, 2, 13,
    True, LChanged, GReason), 'Stale generation rejects');
  Check(CompositionJSON(LChanged) = LBefore, 'Stale generation preserves result');

  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LDocument.FNodes[LIndex.Find(LSnail)].FLocked := True;
  finally
    LIndex.Free;
  end;
  Check(not GenerateProgramRoom(LDocument, 'bay-5.room', BathroomProgram, 9, 14,
    True, LChanged, GReason), 'Purpose replacement protects locked snail');
  Check(CompositionJSON(LChanged) = LBefore, 'Locked replacement preserves result');
  Check(GenerateProgramRoom(LDocument, 'bay-5.room', LaboratoryProgram, 11, 14,
    False, LChanged, GReason), 'Surrounding reimagine retains locked contents');

  LReloaded := CopyDocument(LDocument);
  LIndex := TCompositionIndex.Create(LReloaded.FNodes);
  try
    LReloaded.FNodes[LIndex.Find(LSnail)].FAssetId := 'unknown.snail';
  finally
    LIndex.Free;
  end;
  Check(not ValidateProgramRoom(LReloaded, 'bay-5.room', GReason), 'Unknown nested geometry rejects');
  LReloaded := CopyDocument(LDocument);
  LIndex := TCompositionIndex.Create(LReloaded.FNodes);
  try
    LReloaded.FNodes[LIndex.Find(LSnail)].FX := 30000;
  finally
    LIndex.Free;
  end;
  Check(not ValidateProgramRoom(LReloaded, 'bay-5.room', GReason), 'Off-support nested geometry rejects');

  Check(SurfaceRequest(LDocument, LSurface, LRequest, GReason), 'Build shelf content request');
  LRequest.FScopeId := LSnail;
  for I := 0 to High(LRequest.FSlots) do
  begin
    if LRequest.FSlots[I].FObjectId = LSnail then
    begin
      LRequest.FSlots[I].FAllowedAssets := ['phanes.snail.azure.v1'];
    end;
  end;
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LDocument.FNodes[LIndex.Find(LSnail)].FLocked := False;
  finally
    LIndex.Free;
  end;
  Check(GenerateContents(LDocument, LRequest, LChanged, GReason), 'Change only the ceramic snail');
  Check(ValidateProgramRoom(LChanged, 'bay-5.room', GReason), 'Changed snail remains room-admitted');
  Check(ValidateProgramRoom(LChanged, 'bay-6.room', GReason), 'Neighbor remains admitted');
end;

procedure TestPlans;
const
  CProfiles: array[0..2] of String = (CabinTwoBays, CabinFourBays, CabinSixBays);
var
  LEmpty: TCompositionDocument;
  LDocument: TCompositionDocument;
  LChanged: TCompositionDocument;
  LBad: TCompositionDocument;
  LIndex: TCompositionIndex;
  LRoomId: String;
  LBefore: String;
  LNode: TCompositionNode;
  I: Integer;
  J: Integer;
begin
  LEmpty := Default(TCompositionDocument);
  SetLength(LEmpty.FNodes, 2);
  LEmpty.FNodes[0].FId := 'world';
  LEmpty.FNodes[0].FRole := 'world';
  LEmpty.FNodes[0].FName := 'World';
  LEmpty.FNodes[1].FId := 'cabin';
  LEmpty.FNodes[1].FParentId := 'world';
  LEmpty.FNodes[1].FRole := 'building';
  LEmpty.FNodes[1].FAssetId := 'cabin';
  LEmpty.FNodes[1].FName := 'Cabin';
  for I := 0 to 2 do
  begin
    Check(CreateCabinPlan(LEmpty, 'cabin', CProfiles[I], 25, 0, LDocument, GReason),
      'Create plan ' + CProfiles[I]);
    Check(LDocument.FRevision = 1, 'Plan creation consumes one revision');
    Check(ValidateCabinPlan(LDocument, 'cabin.plan', GReason), 'Empty plan admission');
    for J := 1 to (I + 1) * 2 do
    begin
      LRoomId := 'cabin.plan.bay-' + IntToStr(J) + '.room';
      if Odd(J) then
      begin
        Check(GenerateProgramRoom(LDocument, LRoomId, LaboratoryProgram, 75 + J,
          LDocument.FRevision, True, LChanged, GReason), 'Lab fits plan bay');
      end
      else
      begin
        Check(GenerateProgramRoom(LDocument, LRoomId, BathroomProgram, 75 + J,
          LDocument.FRevision, True, LChanged, GReason), 'Bathroom fits plan bay');
      end;
      LDocument := CopyDocument(LChanged);
      Check(ValidateCabinPlan(LDocument, 'cabin.plan', GReason), 'Whole furnished plan admission');
    end;
    LBad := CopyDocument(LDocument);
    LIndex := TCompositionIndex.Create(LBad.FNodes);
    try
      Inc(LBad.FNodes[LIndex.Find('cabin.plan.bay-1')].FDepth);
    finally
      LIndex.Free;
    end;
    Check(not ValidateCabinPlan(LBad, 'cabin.plan', GReason), 'Forged bay depth rejects');
    LBad := CopyDocument(LDocument);
    LIndex := TCompositionIndex.Create(LBad.FNodes);
    try
      LBad.FNodes[LIndex.Find('cabin.plan.bay-1')].FX := 2700;
    finally
      LIndex.Free;
    end;
    Check(not ValidateCabinPlan(LBad, 'cabin.plan', GReason), 'Overlapping sibling bay rejects');
  end;
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LDocument.FNodes[LIndex.Find('cabin.plan.bay-5')].FName := 'Research bay';
    LDocument.FNodes[LIndex.Find('cabin.plan.bay-5.room')].FName := 'Biology laboratory';
  finally
    LIndex.Free;
  end;
  Check(ValidateCabinPlan(LDocument, 'cabin.plan', GReason), 'Names remain independent of geometry');
  LBefore := CompositionJSON(LChanged);
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    J := FindRole(LDocument, 'cabin.plan.bay-5.room', 'ornament');
    LDocument.FNodes[J].FLocked := True;
  finally
    LIndex.Free;
  end;
  Check(not CreateCabinPlan(LDocument, 'cabin', CabinTwoBays, 5,
    LDocument.FRevision, LChanged, GReason), 'Changing whole plan protects locked descendant');
  Check(CompositionJSON(LChanged) = LBefore, 'Failed plan replacement preserves caller result');
  LBad := CopyDocument(LDocument);
  LNode := Default(TCompositionNode);
  LNode.FId := 'cabin.studio';
  LNode.FParentId := 'cabin';
  LNode.FRole := 'studio';
  LNode.FAssetId := 'phanes.room.studio.v1';
  SetLength(LBad.FNodes, Length(LBad.FNodes) + 1);
  LBad.FNodes[High(LBad.FNodes)] := LNode;
  Check(not ValidateCabinPlan(LBad, 'cabin.plan', GReason), 'Studio cannot overlap room plan');
end;

procedure TestReservedNamespaces;
const
  CSuffixes: array[0..3] of String = ('', '.tier-1', '.tier-2.item-0', '.top');
var
  LDocument: TCompositionDocument;
  LChanged: TCompositionDocument;
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LBefore: String;
  I: Integer;
begin
  for I := 0 to High(CSuffixes) do
  begin
    LDocument := Fixture;
    LNode := Default(TCompositionNode);
    LNode.FId := 'bay-5.room.item-0-0' + CSuffixes[I];
    LNode.FParentId := 'world';
    LNode.FRole := 'unrelated-marker';
    LNode.FName := 'Keep this identity';
    SetLength(LDocument.FNodes, Length(LDocument.FNodes) + 1);
    LDocument.FNodes[High(LDocument.FNodes)] := LNode;
    Check(GenerateProgramRoom(LDocument, 'bay-5.room', LaboratoryProgram, 0, 12,
      True, LChanged, GReason), 'WFC avoids reserved root/support namespace');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      Check(SameNode(LNode, LChanged.FNodes[LIndex.Find(LNode.FId)]),
        'Reserved outside node stays exact');
    finally
      LIndex.Free;
    end;
    Check(ValidateProgramRoom(LChanged, 'bay-5.room', GReason), 'Alternative layout validates');
  end;
  LDocument := Fixture;
  Check(GenerateProgramRoom(LDocument, 'bay-5.room', LaboratoryProgram, 7, 12,
    True, LDocument, GReason), 'Aliased output success');
  Check(LDocument.FRevision = 13, 'Aliased output revision');
  LBefore := CompositionJSON(LDocument);
  Check(not GenerateProgramRoom(LDocument, 'bay-5.room', BathroomProgram, 7, 12,
    True, LDocument, GReason), 'Aliased stale output rejects');
  Check(CompositionJSON(LDocument) = LBefore, 'Aliased rejection preserves complete document');
end;

begin
  TestPrograms;
  TestPlans;
  TestReservedNamespaces;
  WriteLn('PASS: ', GChecks, ' named-room composition checks');
  GCriticChecks := RunSpaceCriticChecks;
  WriteLn('PASS: ', GCriticChecks, ' independent named-room critic checks');
end.
