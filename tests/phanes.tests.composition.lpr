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
program PhanesCompositionTests;
{$mode delphi}
{$H+}

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.tests.contents,
  phanes.tests.assemblies,
  phanes.tests.extents,
  phanes.tests.composition.wire;

var
  GChecks: Integer;
  GBase: TCompositionDocument;
  GCandidate: TCompositionDocument;
  GResult: TCompositionDocument;
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
  LNode.FName := UnicodeString(AId);
  LNode.FRole := ARole;
  LNode.FKind := AKind;
  if AKind = ckObject then
  begin
    LNode.FAssetId := 'fixture.' + ARole;
  end;
  LCount := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, LCount + 1);
  ADocument.FNodes[LCount] := LNode;
end;

procedure Baseline;
begin
  GBase := Default(TCompositionDocument);
  GBase.FRevision := 8;
  AddNode(GBase, 'world', '', 'world', ckContainer);
  AddNode(GBase, 'bay5', 'world', 'bay', ckContainer);
  AddNode(GBase, 'lab', 'bay5', 'laboratory', ckContainer);
  AddNode(GBase, 'shelf-unit', 'lab', 'shelf-unit', ckObject);
  AddNode(GBase, 'shelf2', 'shelf-unit', 'shelf-tier', ckSurface);
  AddNode(GBase, 'shelf4', 'shelf-unit', 'shelf-tier', ckSurface);
  AddNode(GBase, 'snail', 'shelf2', 'ornament', ckObject);
  GBase.FNodes[6].FSupportId := 'shelf2';
  AddNode(GBase, 'book1', 'shelf4', 'book', ckObject);
  AddNode(GBase, 'book2', 'shelf4', 'book', ckObject);
  AddNode(GBase, 'book3', 'shelf4', 'book', ckObject);
  GBase.FNodes[7].FSupportId := 'shelf4';
  GBase.FNodes[8].FSupportId := 'shelf4';
  GBase.FNodes[9].FSupportId := 'shelf4';
  Check(ValidateComposition(GBase, GReason), 'Valid named nested fixture');
  GCandidate := CopyDocument(GBase);
end;

procedure Run;
var
  I: Integer;
  LSwap: TCompositionNode;
begin
  Baseline;
  GCandidate.FNodes[6].FAssetId := 'fixture.ceramic-snail-blue';
  Check(CommitComposition(GBase, GCandidate, 'snail', 8, GResult, GReason), 'Replace only snail');
  Check(GResult.FRevision = 9, 'One atomic revision increment');
  for I := 0 to High(GBase.FNodes) do
  begin
    if I <> 6 then
    begin
      Check(SameNode(GBase.FNodes[I], GResult.FNodes[I]), 'Neighbor byte fields preserved');
    end;
  end;
  GResult.FNodes[7].FName := 'Independent snapshot';
  Check(GBase.FNodes[7].FName = 'book1', 'Commit does not alias baseline node array');
  Check(GCandidate.FNodes[7].FName = 'book1', 'Commit does not alias candidate node array');
  Check(not CommitComposition(GBase, GCandidate, 'snail', 7, GResult, GReason), 'Stale request rejected');
  Check((GResult.FRevision = 9) and (GResult.FNodes[7].FName = 'Independent snapshot'),
    'Rejected transaction preserves its previous output');

  Baseline;
  GCandidate.FNodes[7].FAssetId := 'fixture.other-book';
  Check(not CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Other shelf unchanged');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FParentId := 'shelf4';
  Check(not CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Object cannot escape scope');
  GCandidate := CopyDocument(GBase);
  SetLength(GCandidate.FNodes, 9);
  Check(not CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Other shelf deletion rejected');
  GCandidate := CopyDocument(GBase);
  AddNode(GCandidate, 'new-book', 'shelf4', 'book', ckObject);
  Check(not CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Other shelf insertion rejected');
  GCandidate := CopyDocument(GBase);
  AddNode(GCandidate, 'second-snail', 'shelf2', 'ornament', ckObject);
  GCandidate.FNodes[10].FSupportId := 'shelf2';
  Check(CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Scoped insertion accepted');

  Baseline;
  GBase.FNodes[4].FLocked := True;
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FAssetId := 'fixture.other-snail';
  Check(not CommitComposition(GBase, GCandidate, 'shelf-unit', 8, GResult, GReason), 'Ancestor lock protects contents');
  GCandidate := CopyDocument(GBase);
  AddNode(GCandidate, 'new-snail', 'shelf2', 'ornament', ckObject);
  Check(not CommitComposition(GBase, GCandidate, 'shelf-unit', 8, GResult, GReason), 'Lock rejects extra contents');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[4].FLocked := False;
  Check(not CommitComposition(GBase, GCandidate, 'world', 8, GResult, GReason), 'Generator cannot remove lock');

  Baseline;
  GCandidate.FNodes[6].FId := 'book1';
  Check(not ValidateComposition(GCandidate, GReason), 'Duplicate identity rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FParentId := 'missing';
  Check(not ValidateComposition(GCandidate, GReason), 'Orphan rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FSupportId := 'missing';
  Check(not ValidateComposition(GCandidate, GReason), 'Missing support rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FSupportId := 'lab';
  Check(not ValidateComposition(GCandidate, GReason), 'Support must be a surface');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[4].FParentId := 'snail';
  Check(not ValidateComposition(GCandidate, GReason), 'Ownership cycle rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[3].FSupportId := 'shelf2';
  Check(not ValidateComposition(GCandidate, GReason), 'Combined support ownership cycle rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[2].FParentId := '';
  Check(not ValidateComposition(GCandidate, GReason), 'Second root rejected');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[6].FQuarterTurn := 4;
  Check(not ValidateComposition(GCandidate, GReason), 'Transform domain checked');

  Baseline;
  LSwap := GCandidate.FNodes[0];
  GCandidate.FNodes[0] := GCandidate.FNodes[9];
  GCandidate.FNodes[9] := LSwap;
  Check(CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason), 'Storage order is not identity');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[5].FName := 'Upper display';
  Check(CommitComposition(GBase, GCandidate, 'shelf4', 8, GResult, GReason), 'Rename keeps stable shelf identity');
  Check(GResult.FNodes[7].FParentId = 'shelf4', 'Books retain renamed parent');

  Baseline;
  GCandidate.FRevision := 7;
  Check(not CommitComposition(GBase, GCandidate, 'snail', 8, GResult, GReason),
    'Candidate must name the same baseline revision');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[4].FParentId := 'lab';
  Check(not CommitComposition(GBase, GCandidate, 'shelf2', 8, GResult, GReason),
    'Selected scope cannot reparent itself');

  Baseline;
  AddNode(GBase, 'outside-display', 'world', 'ornament', ckObject);
  GBase.FNodes[10].FSupportId := 'shelf4';
  GBase.FNodes[10].FLocked := True;
  Check(ValidateComposition(GBase, GReason), 'Outside support reference fixture');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[5].FX := 100;
  Check(not CommitComposition(GBase, GCandidate, 'shelf4', 8, GResult, GReason),
    'Support movement cannot move unchanged outside locked object');
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[5].FName := 'Named tier';
  Check(CommitComposition(GBase, GCandidate, 'shelf4', 8, GResult, GReason),
    'Harmless support label change does not invalidate geometry');

  Baseline;
  GBase.FNodes[7].FLocked := True;
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[5].FX := 100;
  Check(not CommitComposition(GBase, GCandidate, 'shelf-unit', 8, GResult, GReason),
    'Wider regeneration cannot indirectly move a locked book');

  Baseline;
  GBase.FNodes[5].FLocked := True;
  AddNode(GBase, 'outside-object', 'world', 'ornament', ckObject);
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[10].FSupportId := 'shelf4';
  Check(not CommitComposition(GBase, GCandidate, 'world', 8, GResult, GReason),
    'Support reference cannot insert contents onto locked shelf');
  GCandidate := CopyDocument(GBase);
  AddNode(GCandidate, 'new-supported-object', 'world', 'ornament', ckObject);
  GCandidate.FNodes[11].FSupportId := 'shelf4';
  Check(not CommitComposition(GBase, GCandidate, 'world', 8, GResult, GReason),
    'New supported object cannot bypass ownership lock');
  GBase.FNodes[10].FSupportId := 'shelf4';
  GCandidate := CopyDocument(GBase);
  GCandidate.FNodes[10].FAssetId := 'fixture.other';
  Check(not CommitComposition(GBase, GCandidate, 'world', 8, GResult, GReason),
    'Surface lock freezes already supported contents');

  Baseline;
  GCandidate.FNodes[6].FName := 'New snail';
  Check(not CommitComposition(GBase, GCandidate, 'snail', 7, GBase, GReason),
    'Rejected aliased output is safe');
  Check((Length(GBase.FNodes) = 10) and (GBase.FRevision = 8), 'Aliased baseline retained');
  Check(CommitComposition(GBase, GCandidate, 'snail', 8, GBase, GReason), 'Aliased commit accepted');
  Check((GBase.FRevision = 9) and (GBase.FNodes[6].FName = 'New snail'), 'Aliased revision staged');
  Baseline;
  GCandidate.FNodes[6].FName := 'Candidate alias';
  Check(CommitComposition(GBase, GCandidate, 'snail', 8, GCandidate, GReason),
    'Output may alias candidate');
  Check((GBase.FRevision = 8) and (GCandidate.FRevision = 9), 'Candidate alias leaves base intact');

  GBase := Default(TCompositionDocument);
  AddNode(GBase, 'n0', '', 'world', ckContainer);
  for I := 1 to 129 do
  begin
    AddNode(GBase, 'n' + IntToStr(I), 'n' + IntToStr(I - 1), 'container', ckContainer);
  end;
  Check(not ValidateComposition(GBase, GReason), 'Root-first depth bound enforced');
  for I := 0 to 64 do
  begin
    LSwap := GBase.FNodes[I];
    GBase.FNodes[I] := GBase.FNodes[129 - I];
    GBase.FNodes[129 - I] := LSwap;
  end;
  Check(not ValidateComposition(GBase, GReason), 'Leaf-first depth bound agrees');
  GBase := Default(TCompositionDocument);
  AddNode(GBase, 'n0', '', 'world', ckContainer);
  for I := 1 to 128 do
  begin
    AddNode(GBase, 'n' + IntToStr(I), 'n' + IntToStr(I - 1), 'container', ckContainer);
  end;
  Check(ValidateComposition(GBase, GReason), 'Exact maximum hierarchy depth accepted');
end;

begin
  Run;
  WriteLn(GChecks, ' composition document checks passed');
  WriteLn(RunContentChecks, ' WFC content checks passed');
  WriteLn(RunAssemblyChecks, ' nested assembly checks passed');
  WriteLn(RunExtentChecks, ' explicit container volume checks passed');
  WriteLn(RunCompositionWireChecks, ' composition wire checks passed');
end.
