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
unit phanes.tests.contents;
{$mode delphi}
{$H+}

interface

function RunContentChecks: Integer;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.contents.types,
  phanes.composition.contents.validate,
  phanes.composition.contents.generate;

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

procedure AddNode(var ADocument: TCompositionDocument; const AId, AParent, ARole: String;
  const AKind: TCompositionKind);
var
  LNode: TCompositionNode;
  LCount: Integer;
begin
  LNode := Default(TCompositionNode);
  LNode.FId := AId;
  LNode.FParentId := AParent;
  LNode.FRole := ARole;
  LNode.FName := UnicodeString(AId);
  LNode.FKind := AKind;
  if AKind = ckObject then
  begin
    LNode.FAssetId := 'fixture.' + ARole;
  end;
  LCount := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, LCount + 1);
  ADocument.FNodes[LCount] := LNode;
end;

function Asset(const AId, ARole: String; const AWidth, ADepth, AHeight: Integer): TContentAsset;
begin
  Result.FId := AId;
  Result.FName := UnicodeString(AId);
  Result.FRole := ARole;
  Result.FWidth := AWidth;
  Result.FDepth := ADepth;
  Result.FHeight := AHeight;
  Result.FSingleInstance := True;
end;

procedure Fixture(out ABase: TCompositionDocument; out ARequest: TContentRequest);
var
  I: Integer;
begin
  ABase := Default(TCompositionDocument);
  ABase.FRevision := 12;
  AddNode(ABase, 'world', '', 'world', ckContainer);
  AddNode(ABase, 'bay5', 'world', 'bay', ckContainer);
  AddNode(ABase, 'lab', 'bay5', 'laboratory', ckContainer);
  AddNode(ABase, 'shelf-unit', 'lab', 'shelf-unit', ckObject);
  AddNode(ABase, 'shelf2', 'shelf-unit', 'shelf-tier', ckSurface);
  AddNode(ABase, 'shelf4', 'shelf-unit', 'shelf-tier', ckSurface);
  AddNode(ABase, 'snail', 'shelf2', 'ornament', ckObject);
  ABase.FNodes[6].FSupportId := 'shelf2';
  ABase.FNodes[6].FAssetId := 'fixture.snail-amber';
  ARequest := Default(TContentRequest);
  ARequest.FSurfaceId := 'shelf4';
  ARequest.FScopeId := 'shelf4';
  ARequest.FExpectedRevision := 12;
  ARequest.FSeed := 29;
  ARequest.FSurfaceWidth := 1000;
  ARequest.FSurfaceDepth := 300;
  ARequest.FHeadroom := 320;
  SetLength(ARequest.FSlots, 4);
  for I := 0 to 3 do
  begin
    ARequest.FSlots[I].FObjectId := 'shelf4-item' + IntToStr(I);
    ARequest.FSlots[I].FX := -300 + I * 200;
    ARequest.FSlots[I].FWidth := 180;
    ARequest.FSlots[I].FDepth := 260;
    ARequest.FSlots[I].FHeight := 300;
    ARequest.FSlots[I].FAllowedRoles := ['book', 'ornament'];
    ARequest.FSlots[I].FAllowEmpty := True;
  end;
  SetLength(ARequest.FAssets, 4);
  ARequest.FAssets[0] := Asset('fixture.book-sage', 'book', 40, 160, 230);
  ARequest.FAssets[1] := Asset('fixture.book-clay', 'book', 55, 180, 245);
  ARequest.FAssets[2] := Asset('fixture.snail-blue', 'ornament', 120, 120, 140);
  ARequest.FAssets[3] := Asset('fixture.oversized-book', 'book', 80, 200, 600);
  SetLength(ARequest.FQuotas, 2);
  ARequest.FQuotas[0].FRole := 'book';
  ARequest.FQuotas[0].FMinimum := 3;
  ARequest.FQuotas[0].FMaximum := 3;
  ARequest.FQuotas[1].FRole := 'ornament';
  ARequest.FQuotas[1].FMaximum := 0;
end;

function CountRole(const ADocument: TCompositionDocument; const ASurface, ARole: String): Integer;
var
  LNode: TCompositionNode;
begin
  Result := 0;
  for LNode in ADocument.FNodes do
  begin
    if (LNode.FSupportId = ASurface) and (LNode.FRole = ARole) then
    begin
      Inc(Result);
    end;
  end;
end;

function RunContentChecks: Integer;
var
  LBase: TCompositionDocument;
  LRequest: TContentRequest;
  LResult: TCompositionDocument;
  LReplay: TCompositionDocument;
  LBad: TCompositionDocument;
  LSaved: TCompositionDocument;
  LIndex: TCompositionIndex;
  LFirst: String;
  LVariants: String;
  LSignature: String;
  LNodeIndex: Integer;
  LSlotIndex: Integer;
  LAssetId: String;
  I: Integer;
  J: Integer;
begin
  GChecks := 0;
  Fixture(LBase, LRequest);
  Check(ValidateContentRequest(LBase, LRequest, GReason), 'Valid measured shelf request');
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'WFC generates shelf contents');
  Check((LRequest.FAssets[0].FId = 'fixture.book-sage') and
    (LRequest.FAssets[3].FId = 'fixture.oversized-book'), 'Solver preserves input catalog records');
  Check(LResult.FRevision = 13, 'One content transaction');
  Check(CountRole(LResult, 'shelf4', 'book') = 3, 'Exactly three individual book anchors');
  Check(CountRole(LResult, 'shelf4', 'ornament') = 0, 'Zero ornament quota');
  Check(CountRole(LResult, 'shelf2', 'ornament') = 1, 'Other shelf independent of quotas');
  for I := 0 to High(LBase.FNodes) do
  begin
    Check(SameNode(LBase.FNodes[I], LResult.FNodes[I]), 'Surrounding hierarchy preserved');
  end;
  Check(ValidateContentResult(LResult, LRequest, GReason), 'Independent decoded validation');
  Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Deterministic replay solve');
  Check(Length(LResult.FNodes) = Length(LReplay.FNodes), 'Replay size');
  for I := 0 to High(LResult.FNodes) do
  begin
    Check(SameNode(LResult.FNodes[I], LReplay.FNodes[I]), 'Replay retains IDs and choices');
  end;
  LFirst := '';
  LVariants := '';
  for I := 1 to 32 do
  begin
    LRequest.FSeed := I;
    Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Bounded seeded content solve');
    Check(CountRole(LReplay, 'shelf4', 'book') = 3, 'Seeded exact quota');
    LSignature := '';
    for J := Length(LBase.FNodes) to High(LReplay.FNodes) do
    begin
      LSignature := LSignature + LReplay.FNodes[J].FId + LReplay.FNodes[J].FAssetId;
      Check(LReplay.FNodes[J].FAssetId <> 'fixture.oversized-book', 'Headroom excludes tall book');
    end;
    if I = 1 then
    begin
      LFirst := LSignature;
    end
    else if LFirst <> LSignature then
    begin
      LVariants := 'varied';
    end;
  end;
  Check(LVariants <> '', 'Seeded choices vary without weakening counts');

  { Replace a single ornament; the populated other shelf is not part of its graph. }
  LBase := CopyDocument(LResult);
  LRequest.FExpectedRevision := LBase.FRevision;
  LRequest.FSurfaceId := 'shelf2';
  LRequest.FScopeId := 'snail';
  SetLength(LRequest.FSlots, 1);
  LRequest.FSlots[0].FObjectId := 'snail';
  LRequest.FSlots[0].FX := 0;
  LRequest.FSlots[0].FAllowedRoles := ['ornament'];
  SetLength(LRequest.FQuotas, 1);
  LRequest.FQuotas[0].FRole := 'ornament';
  LRequest.FQuotas[0].FMinimum := 1;
  LRequest.FQuotas[0].FMaximum := 1;
  SetLength(LRequest.FAssets, 1);
  LRequest.FAssets[0] := Asset('fixture.snail-blue', 'ornament', 120, 120, 140);
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Replace only ceramic snail');
  for I := 0 to High(LBase.FNodes) do
  begin
    if LBase.FNodes[I].FId <> 'snail' then
    begin
      Check(SameNode(LBase.FNodes[I], LResult.FNodes[I]), 'Single item edit preserves all neighbors');
    end;
  end;
  Check(LResult.FNodes[6].FId = 'snail', 'Replacement keeps persistent identity');
  Check(LResult.FNodes[6].FAssetId = 'fixture.snail-blue', 'Replacement chooses requested asset');

  LSaved := CopyDocument(LResult);
  LBase.FNodes[4].FLocked := True;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Locked surface rejects replacement');
  Check(SameNode(LResult.FNodes[6], LSaved.FNodes[6]), 'Failed solve leaves prior output intact');
  LBase.FNodes[4].FLocked := False;
  LRequest.FExpectedRevision := 0;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Stale content request rejected');

  Fixture(LBase, LRequest);
  LRequest.FQuotas[0].FMinimum := 4;
  LRequest.FQuotas[0].FMaximum := 4;
  LRequest.FSlots[0].FAllowedRoles := ['ornament'];
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Quota impossible with eligible slots');
  Check(LResult.FRevision = LSaved.FRevision, 'Unsatisfied quota preserves revision');
  Fixture(LBase, LRequest);
  LRequest.FSlots[1].FX := LRequest.FSlots[0].FX;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Overlapping usable volumes rejected');
  Fixture(LBase, LRequest);
  LRequest.FSlots[0].FX := High(Integer);
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Overflow-size coordinates rejected');
  Fixture(LBase, LRequest);
  LRequest.FAssets[0].FSingleInstance := False;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Grouped books are not single books');
  Fixture(LBase, LRequest);
  LRequest.FSlots[0].FObjectId := 'snail';
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Slot cannot borrow other shelf identity');
  Fixture(LBase, LRequest);
  LRequest.FScopeId := 'shelf2';
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Unrelated scope rejected');
  Fixture(LBase, LRequest);
  LRequest.FAssets[1].FId := LRequest.FAssets[0].FId;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Duplicate asset IDs rejected');

  Fixture(LBase, LRequest);
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Fresh result for forged-result checks');
  LBad := CopyDocument(LResult);
  LBad.FNodes[7].FAssetId := 'fixture.oversized-book';
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator rejects oversized forged choice');
  LBad := CopyDocument(LResult);
  LBad.FNodes[7].FX := 700;
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator rejects shifted object');
  LBad := CopyDocument(LResult);
  LBad.FNodes[7].FRole := 'ornament';
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator rejects forged role');
  LBad := CopyDocument(LResult);
  SetLength(LBad.FNodes, Length(LBad.FNodes) - 1);
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator independently counts missing book');
  LBad := CopyDocument(LResult);
  AddNode(LBad, 'hidden-book', 'shelf4', 'book', ckObject);
  LBad.FNodes[High(LBad.FNodes)].FSupportId := 'shelf4';
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator rejects unaccounted extra book');

  LBase := CopyDocument(LResult);
  LRequest.FExpectedRevision := LBase.FRevision;
  LIndex := TCompositionIndex.Create(LBase.FNodes);
  try
    LNodeIndex := 7;
    LBase.FNodes[LNodeIndex].FLocked := True;
    Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Locked book is a frozen WFC domain');
    Check(SameNode(LBase.FNodes[LNodeIndex],
      LReplay.FNodes[LIndex.Find(LBase.FNodes[LNodeIndex].FId)]), 'Locked book preserved exactly');
    LRequest.FScopeId := LBase.FNodes[8].FId;
    LRequest.FSeed := 17;
    Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Only one book is editable');
    for I := 0 to High(LBase.FNodes) do
    begin
      if I <> 8 then
      begin
        Check(SameNode(LBase.FNodes[I], LReplay.FNodes[I]), 'Single book scope preserves other items');
      end;
    end;
  finally
    LIndex.Free;
  end;

  LSlotIndex := ContentSlotIndex(LRequest.FSlots, LBase.FNodes[8].FId);
  LAssetId := 'fixture.book-sage';
  if LBase.FNodes[8].FAssetId = LAssetId then
  begin
    LAssetId := 'fixture.book-clay';
  end;
  LRequest.FSlots[LSlotIndex].FAllowedAssets := [LAssetId];
  Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Per-item asset restriction solves');
  Check(LReplay.FNodes[8].FAssetId = LAssetId, 'Per-item choice is enforced');
  for I := 0 to High(LBase.FNodes) do
  begin
    if I <> 8 then
    begin
      Check(SameNode(LBase.FNodes[I], LReplay.FNodes[I]), 'Asset filter preserves other shelf items');
    end;
  end;
  LBad := CopyDocument(LReplay);
  LBad.FNodes[8].FAssetId := LBase.FNodes[8].FAssetId;
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator enforces per-slot asset filter');

  Fixture(LBase, LRequest);
  SetLength(LRequest.FSlots, 1);
  LRequest.FSlots[0].FX := 0;
  LRequest.FSlots[0].FWidth := 80;
  LRequest.FSlots[0].FDepth := 220;
  LRequest.FSlots[0].FQuarterTurn := 1;
  LRequest.FSlots[0].FAllowEmpty := False;
  SetLength(LRequest.FAssets, 1);
  LRequest.FAssets[0] := Asset('fixture.flat-book', 'book', 200, 60, 20);
  LRequest.FQuotas[0].FMinimum := 1;
  LRequest.FQuotas[0].FMaximum := 1;
  Check(GenerateContents(LBase, LRequest, LReplay, GReason), 'Quarter-turn swaps footprint axes');
  LRequest.FSlots[0].FQuarterTurn := 0;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Unrotated wide object does not fit');

  Fixture(LBase, LRequest);
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Nested-support baseline');
  LBase := CopyDocument(LResult);
  AddNode(LBase, 'item-top', LBase.FNodes[7].FId, 'top', ckSurface);
  LRequest.FExpectedRevision := LBase.FRevision;
  LRequest.FScopeId := LBase.FNodes[7].FId;
  Check(not GenerateContents(LBase, LRequest, LReplay, GReason),
    'Non-leaf support assembly requires a complete envelope');
  LSlotIndex := ContentSlotIndex(LRequest.FSlots, LBase.FNodes[7].FId);
  LAssetId := 'fixture.book-sage';
  if LBase.FNodes[7].FAssetId = LAssetId then
  begin
    LAssetId := 'fixture.book-clay';
  end;
  LRequest.FSlots[LSlotIndex].FAllowedAssets := [LAssetId];
  Check(not GenerateContents(LBase, LRequest, LReplay, GReason),
    'Replacing nested support requires an assembly geometry adapter');

  Fixture(LBase, LRequest);
  Check(GenerateContents(LBase, LRequest, LBase, GReason), 'Output can alias baseline');
  Check((LBase.FRevision = 13) and (CountRole(LBase, 'shelf4', 'book') = 3),
    'Aliased commit retains valid contents');
  LSaved := CopyDocument(LBase);
  Check(not GenerateContents(LBase, LRequest, LBase, GReason), 'Stale alias rejects without clearing');
  Check((LBase.FRevision = LSaved.FRevision) and
    (Length(LBase.FNodes) = Length(LSaved.FNodes)), 'Alias failure preserves baseline');

  Fixture(LBase, LRequest);
  LBad := CopyDocument(LBase);
  LBad.FNodes[5].FKind := ckContainer;
  Check(not ValidateContentResult(LBad, LRequest, GReason), 'Validator requires a real surface');
  LRequest.FSlots[0].FHeight := 0;
  Check(not ValidateContentResult(LBase, LRequest, GReason), 'Validator rejects invalid request geometry');
  Result := GChecks;
end;

end.
