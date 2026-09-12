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
unit phanes.tests.spaces.critic;
{$mode delphi}
{$H+}

interface

function RunSpaceCriticChecks: Integer;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.spaces.programs,
  phanes.spaces.rooms,
  phanes.spaces.plans,
  phanes.spaces.floor.types,
  phanes.spaces.floor.validate,
  phanes.spaces.floor.generate;

function Fixture(const ARoomId: String): TCompositionDocument;
var
  LNode: TCompositionNode;
begin
  Result := Default(TCompositionDocument);
  Result.FRevision := 12;
  SetLength(Result.FNodes, 3);
  LNode := Default(TCompositionNode);
  LNode.FId := 'world';
  LNode.FRole := 'world';
  LNode.FKind := ckContainer;
  Result.FNodes[0] := LNode;
  LNode.FId := 'bay';
  LNode.FParentId := 'world';
  LNode.FRole := 'bay';
  LNode.FWidth := 3000;
  LNode.FDepth := 3900;
  LNode.FHeight := 2700;
  Result.FNodes[1] := LNode;
  LNode.FId := ARoomId;
  LNode.FParentId := 'bay';
  LNode.FRole := 'room';
  LNode.FAssetId := EmptyRoomProgram;
  LNode.FName := 'Empty room';
  Result.FNodes[2] := LNode;
end;

procedure Must(const AOkay: Boolean; const AReason: String);
begin
  if not AOkay then
  begin
    raise Exception.Create('Independent room/plan critic regression: ' + AReason);
  end;
end;

var
  GChecks: Integer;

procedure Check(const AOkay: Boolean; const AReason: String);
begin
  Inc(GChecks);
  Must(AOkay, AReason);
end;

function SameDocument(const ALeft, ARight: TCompositionDocument): Boolean;
var
  I: Integer;
begin
  Result := (ALeft.FRevision = ARight.FRevision) and
    (Length(ALeft.FNodes) = Length(ARight.FNodes));
  if not Result then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft.FNodes) do
  begin
    if not SameNode(ALeft.FNodes[I], ARight.FNodes[I]) then
    begin
      Exit(False);
    end;
  end;
end;

procedure ProgramChecks;
var
  LBase: TCompositionDocument;
  LLab: TCompositionDocument;
  LBad: TCompositionDocument;
  LChanged: TCompositionDocument;
  LBefore: TCompositionDocument;
  LIndex: TCompositionIndex;
  LReason: String;
  LRootId: String;
  LSnail: Integer;
  I: Integer;
  J: Integer;
begin
  LBase := Fixture('room');
  Check(GenerateProgramRoom(LBase, 'room', LaboratoryProgram, 0, 12, True, LLab, LReason), LReason);
  LSnail := -1;
  LRootId := '';
  for I := 0 to High(LLab.FNodes) do
  begin
    if LLab.FNodes[I].FRole = 'ornament' then
    begin
      LSnail := I;
    end;
    if LLab.FNodes[I].FRole = 'bookcase' then
    begin
      LRootId := LLab.FNodes[I].FId;
    end;
  end;
  Check((LSnail >= 0) and (LRootId <> ''), 'laboratory includes full shelf subtree');
  for I := 3 to High(LLab.FNodes) do
  begin
    for J := 0 to 3 do
    begin
      LBad := CopyDocument(LLab);
      case J of
        0:
        begin
          LBad.FNodes[I].FAssetId := 'unknown.asset';
        end;
        1:
        begin
          LBad.FNodes[I].FRole := 'unknown.role';
        end;
        2:
        begin
          LBad.FNodes[I].FX := High(Integer);
        end;
        3:
        begin
          LBad.FNodes[I].FY := High(Integer);
        end;
      end;
      Check(not ValidateProgramRoom(LBad, 'room', LReason),
        'forged descendant accepted ' + LLab.FNodes[I].FId + '/' + IntToStr(J));
    end;
  end;
  LLab.FNodes[LSnail].FLocked := True;
  LBefore := CopyDocument(LLab);
  for I := 0 to 7 do
  begin
    Check(GenerateProgramRoom(LLab, 'room', LaboratoryProgram, Cardinal(I), 13, False,
      LChanged, LReason), 'locked surrounding reimagine ' + LReason);
    Check(SameDocument(LLab, LBefore), 'generation mutated baseline');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      for J := 0 to High(LLab.FNodes) do
      begin
        if (LLab.FNodes[J].FId = LRootId) or (Pos(LRootId + '.', LLab.FNodes[J].FId) = 1) then
        begin
          Check(LIndex.Find(LLab.FNodes[J].FId) >= 0,
            'locked shelf descendant disappeared ' + LLab.FNodes[J].FId);
          Check(SameNode(LLab.FNodes[J], LChanged.FNodes[LIndex.Find(LLab.FNodes[J].FId)]),
            'locked shelf subtree changed ' + LLab.FNodes[J].FId);
        end;
      end;
    finally
      LIndex.Free;
    end;
  end;
  Check(not GenerateProgramRoom(LLab, 'room', BathroomProgram, 77, 13, True, LLab, LReason),
    'locked replacement accepted');
  Check(SameDocument(LLab, LBefore), 'failed aliased replacement changed baseline');
  LBase := Fixture('room');
  Check(GenerateProgramRoom(LBase, 'room', BathroomProgram, 1, 12, True, LBase, LReason),
    'successful aliased creation ' + LReason);
  Check((LBase.FRevision = 13) and ValidateProgramRoom(LBase, 'room', LReason),
    'successful aliased creation invalid');
  LBase := Fixture('room');
  LBase.FRevision := High(Integer) - 1;
  Check(GenerateProgramRoom(LBase, 'room', LaboratoryProgram, High(Cardinal),
    High(Integer) - 1, True, LChanged, LReason), 'last revision lab ' + LReason);
  Check(LChanged.FRevision = High(Integer), 'last revision incorrect');
  LBefore := CopyDocument(LChanged);
  Check(not GenerateProgramRoom(LChanged, 'room', BathroomProgram, 0,
    High(Integer), True, LChanged, LReason), 'exhausted revision accepted');
  Check(SameDocument(LChanged, LBefore), 'exhausted aliased result changed');
  {$ifdef PAS2JS}
  LBase := Fixture('room');
  LBefore := CopyDocument(LBase);
  for I := 0 to 3 do
  begin
    LBad := CopyDocument(LBase);
    case I of
      0:
      begin
        asm
          LBad.FNodes[2].FWidth = NaN;
        end;
      end;
      1:
      begin
        asm
          LBad.FNodes[2].FDepth = Infinity;
        end;
      end;
      2:
      begin
        asm
          LBad.FNodes[2].FHeight = 2700.5;
        end;
      end;
      3:
      begin
        asm
          LBad.FNodes[2].FSeed = 4294967296;
        end;
      end;
    end;
    Check(not GenerateProgramRoom(LBad, 'room', BathroomProgram, 0, 12, True,
      LBase, LReason), 'hostile direct input accepted');
    Check(SameDocument(LBase, LBefore), 'hostile input changed output');
  end;
  {$endif}
end;

procedure ReservedFloorChecks;
var
  LRequest: TFloorRequest;
  LChanged: TFloorRequest;
  LLayout: TFloorLayout;
  LOther: TFloorLayout;
  LNode: TCompositionNode;
  LReason: String;
  I: Integer;
begin
  LNode := Fixture('room').FNodes[2];
  LNode.FAssetId := BathroomProgram;
  Check(RoomProgramRequest(LNode, LRequest, LReason), 'bath program request ' + LReason);
  Check(GenerateFloor(LRequest, LLayout, LReason), 'floor control ' + LReason);
  LChanged := LRequest;
  LChanged.FUnavailableNewIds := [LLayout.FPlacements[0].FId];
  Check(not ValidateFloorLayout(LChanged, LLayout, LReason), 'unpinned reserved identity accepted');
  Check(GenerateFloor(LChanged, LOther, LReason), 'reserved position needs alternative ' + LReason);
  for I := 0 to High(LOther.FPlacements) do
  begin
    Check(LOther.FPlacements[I].FId <> LChanged.FUnavailableNewIds[0], 'reserved anchor generated');
  end;
  LChanged.FFixed := Copy(LLayout.FPlacements, 0, Length(LLayout.FPlacements));
  Check(GenerateFloor(LChanged, LOther, LReason), 'fixed identity may be reserved ' + LReason);
  Check(ValidateFloorLayout(LChanged, LOther, LReason), 'fixed reserved output refused');
  LChanged := LRequest;
  LChanged.FUnavailableNewIds := ['same', 'same'];
  Check(not ValidateFloorRequest(LChanged, LReason), 'duplicate reserved ids accepted');
  LChanged.FUnavailableNewIds := ['bad slash/'];
  Check(not ValidateFloorRequest(LChanged, LReason), 'invalid reserved id accepted');
  LChanged.FUnavailableNewIds := [StringOfChar('x', 129)];
  Check(not ValidateFloorRequest(LChanged, LReason), 'oversized reserved id accepted');
  SetLength(LChanged.FUnavailableNewIds, 21);
  for I := 0 to 20 do
  begin
    LChanged.FUnavailableNewIds[I] := 'id-' + IntToStr(I);
  end;
  Check(not ValidateFloorRequest(LChanged, LReason), 'reserved count exceeds floor cells');
end;

procedure PlanChecks;
const
  CProfiles: array[0..2] of String = (CabinTwoBays, CabinFourBays, CabinSixBays);
var
  LBase: TCompositionDocument;
  LPlan: TCompositionDocument;
  LChanged: TCompositionDocument;
  LBad: TCompositionDocument;
  LBefore: TCompositionDocument;
  LIndex: TCompositionIndex;
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LNode: TCompositionNode;
  LReason: String;
  LRoom: String;
  LX: Double;
  LZ: Double;
  LHalfX: Double;
  LHalfZ: Double;
  LProfile: Integer;
  LBay: Integer;
  LProgram: Integer;
  LAt: Integer;
  I: Integer;
begin
  LBase := Default(TCompositionDocument);
  SetLength(LBase.FNodes, 2);
  LBase.FNodes[0].FId := 'world';
  LBase.FNodes[0].FRole := 'world';
  LBase.FNodes[1].FId := 'cabin';
  LBase.FNodes[1].FParentId := 'world';
  LBase.FNodes[1].FRole := 'building';
  LBase.FNodes[1].FAssetId := 'cabin';
  for LProfile := 0 to 2 do
  begin
    Check(CreateCabinPlan(LBase, 'cabin', CProfiles[LProfile], 0, 0, LPlan, LReason),
      'create authored plan ' + LReason);
    Check(ValidateCabinPlan(LPlan, 'cabin.plan', LReason), 'admit plan ' + LReason);
    LIndex := TCompositionIndex.Create(LPlan.FNodes);
    try
      for LBay := 1 to (LProfile + 1) * 2 do
      begin
        LRoom := 'cabin.plan.bay-' + IntToStr(LBay);
        LAt := LIndex.Find(LRoom);
        LNode := LPlan.FNodes[LAt];
        LX := LNode.FX;
        LZ := LNode.FZ;
        LHalfX := LNode.FDepth / 2;
        LHalfZ := LNode.FWidth / 2;
        Check((LX - LHalfX >= -4650) and (LX + LHalfX <= 4650) and
          (LZ - LHalfZ >= -4600) and (LZ + LHalfZ <= 4600), 'bay physical envelope');
        Check((LX + LHalfX <= -750) or (LX - LHalfX >= 750), 'bay leaves corridor');
        LRoom := LRoom + '.room';
        for LProgram := 0 to 1 do
        begin
          LNode := LPlan.FNodes[LIndex.Find(LRoom)];
          LNode.FAssetId := BathroomProgram;
          if LProgram = 1 then
          begin
            LNode.FAssetId := LaboratoryProgram;
          end;
          Check(RoomProgramRequest(LNode, LRequest, LReason),
            'all bay size programs admit ' + LReason);
          Check(GenerateFloor(LRequest, LLayout, LReason), 'all bay size floor solve ' + LReason);
          Check(Length(LLayout.FPlacements) = 3, 'all bay size count');
        end;
        LBad := CopyDocument(LPlan);
        Inc(LBad.FNodes[LAt].FX);
        Check(not ValidateCabinPlan(LBad, 'cabin.plan', LReason), 'forged bay offset accepted');
        LBad := CopyDocument(LPlan);
        Inc(LBad.FNodes[LAt].FWidth);
        Check(not ValidateCabinPlan(LBad, 'cabin.plan', LReason), 'forged bay width accepted');
      end;
    finally
      LIndex.Free;
    end;
    LChanged := CopyDocument(LPlan);
    for I := 0 to High(LChanged.FNodes) do
    begin
      LChanged.FNodes[I].FName := 'Renamed ' + UnicodeString(IntToStr(I));
    end;
    Check(ValidateCabinPlan(LChanged, 'cabin.plan', LReason), 'display name independent of plan');
    LChanged.FNodes[High(LChanged.FNodes)].FLocked := True;
    LBefore := CopyDocument(LChanged);
    Check(not CreateCabinPlan(LChanged, 'cabin', CProfiles[(LProfile + 1) mod 3], 1,
      LChanged.FRevision, LChanged, LReason), 'locked room whole-plan replacement accepted');
    Check(SameDocument(LChanged, LBefore), 'locked aliased plan replacement mutated result');
  end;
  LNode := Fixture('room').FNodes[2];
  LNode.FWidth := 9400;
  LNode.FDepth := 9400;
  LNode.FHeight := 3500;
  for LProgram := 0 to 1 do
  begin
    LNode.FAssetId := BathroomProgram;
    if LProgram = 1 then
    begin
      LNode.FAssetId := LaboratoryProgram;
    end;
    Check(RoomProgramRequest(LNode, LRequest, LReason), 'max program admission ' + LReason);
    Check(LRequest.FPitch = 1000, 'max deterministic pitch');
    Check(GenerateFloor(LRequest, LLayout, LReason), 'max actual floor solve ' + LReason);
    Check(ValidateFloorLayout(LRequest, LLayout, LReason), 'max floor validation ' + LReason);
  end;
end;


procedure NamespaceChecks;
const
  CNames: array[0..2] of String = ('room', 'room.tier-2', 'room.tier-4');
var
  LBase: TCompositionDocument;
  LBefore: TCompositionDocument;
  LNormal: TCompositionDocument;
  LChanged: TCompositionDocument;
  LExternal: TCompositionNode;
  LIndex: TCompositionIndex;
  LReason: String;
  LCollisionId: String;
  LAt: Integer;
  LCase: Integer;
  LBooks: Integer;
  LOrnaments: Integer;
  I: Integer;
begin
  { Stable identity text is opaque. A room name containing a support key must
    not change the intended support population elsewhere in that namespace. }
  for LCase := 0 to High(CNames) do
  begin
    LBase := Fixture(CNames[LCase]);
    LBase.FNodes[2].FName := 'Custom room label';
    Check(GenerateProgramRoom(LBase, CNames[LCase], LaboratoryProgram, 0, 12,
      True, LChanged, LReason), 'named room population: ' + LReason);
    Check(ValidateProgramRoom(LChanged, CNames[LCase], LReason),
      'named room admission: ' + LReason);
    LBooks := 0;
    LOrnaments := 0;
    for I := 0 to High(LChanged.FNodes) do
    begin
      if LChanged.FNodes[I].FRole = 'book' then
      begin
        Inc(LBooks);
      end;
      if LChanged.FNodes[I].FRole = 'ornament' then
      begin
        Inc(LOrnaments);
      end;
    end;
    Check((LBooks = 9) and (LOrnaments = 1),
      'support population must not depend on ancestor identity substrings');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      LAt := LIndex.Find(CNames[LCase]);
      Check((LAt >= 0) and (LChanged.FNodes[LAt].FName = 'Custom room label'),
        'explicit program replacement retains a custom room label');
    finally
      LIndex.Free;
    end;
  end;

  LBase := Fixture('room');
  Check(GenerateProgramRoom(LBase, 'room', LaboratoryProgram, 0, 12, True,
    LNormal, LReason), 'namespace control layout: ' + LReason);
  { Discover the chosen identities from a real seed, then reserve that exact
    root, support or deeper item outside the room. The same seed must resolve
    another legal arrangement before publication, without stealing identity. }
  for LCase := 0 to 2 do
  begin
    LCollisionId := '';
    for I := 0 to High(LNormal.FNodes) do
    begin
      if ((LCase = 0) and (LNormal.FNodes[I].FKind = ckObject) and
        (LNormal.FNodes[I].FParentId = 'room')) or
        ((LCase = 1) and (LNormal.FNodes[I].FKind = ckSurface)) or
        ((LCase = 2) and (LNormal.FNodes[I].FRole = 'book')) then
      begin
        LCollisionId := LNormal.FNodes[I].FId;
        Break;
      end;
    end;
    Check(LCollisionId <> '', 'namespace collision control identity exists');
    LBase := Fixture('room');
    LExternal := Default(TCompositionNode);
    LExternal.FId := LCollisionId;
    LExternal.FParentId := 'world';
    LExternal.FRole := 'external';
    LExternal.FName := 'Unaffected external grouping';
    LExternal.FKind := ckContainer;
    LExternal.FLocked := True;
    LExternal.FX := 12345;
    SetLength(LBase.FNodes, 4);
    LBase.FNodes[3] := LExternal;
    LBefore := CopyDocument(LBase);
    Check(ValidateProgramRoom(LBase, 'room', LReason),
      'outside reserved namespace is an admitted baseline: ' + LReason);
    Check(GenerateProgramRoom(LBase, 'room', LaboratoryProgram, 0, 12, True,
      LChanged, LReason), 'reserved namespace has a same-seed alternative: ' + LReason);
    Check(SameDocument(LBase, LBefore), 'namespace resolution mutated baseline');
    Check(ValidateProgramRoom(LChanged, 'room', LReason),
      'namespace alternative independently admits: ' + LReason);
    Check(LChanged.FRevision = 13, 'namespace solve publishes one revision');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      LAt := LIndex.Find(LCollisionId);
      Check(LAt >= 0, 'preserved outside identity disappeared');
      Check(SameNode(LExternal, LChanged.FNodes[LAt]),
        'namespace resolution changed a preserved outside record');
    finally
      LIndex.Free;
    end;
  end;
end;

procedure StaleChecks;
var
  LBase: TCompositionDocument;
  LOutput: TCompositionDocument;
  LBefore: TCompositionDocument;
  LReason: String;
begin
  LBase := Fixture('room');
  LOutput := Fixture('sentinel');
  LBefore := CopyDocument(LOutput);
  Check(not GenerateProgramRoom(LBase, 'room', BathroomProgram, 1, 11, True,
    LOutput, LReason), 'stale room request rejected');
  Check(SameDocument(LOutput, LBefore), 'stale room preserves separate output');
  LBefore := CopyDocument(LBase);
  Check(not GenerateProgramRoom(LBase, 'room', BathroomProgram, 1, 13, True,
    LBase, LReason), 'future room request rejected');
  Check(SameDocument(LBase, LBefore), 'future room preserves aliased baseline');

  LBase := Default(TCompositionDocument);
  LBase.FRevision := 12;
  SetLength(LBase.FNodes, 2);
  LBase.FNodes[0].FId := 'world';
  LBase.FNodes[0].FRole := 'world';
  LBase.FNodes[1].FId := 'cabin';
  LBase.FNodes[1].FParentId := 'world';
  LBase.FNodes[1].FRole := 'building';
  LBase.FNodes[1].FAssetId := 'cabin';
  LBefore := CopyDocument(LBase);
  Check(not CreateCabinPlan(LBase, 'cabin', CabinTwoBays, 0, 11, LBase, LReason),
    'stale plan request rejected');
  Check(SameDocument(LBase, LBefore), 'stale plan preserves aliased baseline');
end;

function RunSpaceCriticChecks: Integer;
begin
  GChecks := 0;
  ProgramChecks;
  ReservedFloorChecks;
  PlanChecks;
  NamespaceChecks;
  StaleChecks;
  Result := GChecks;
end;

end.
