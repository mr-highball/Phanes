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
unit phanes.tests.extents;
{$mode delphi}
{$H+}

interface

function RunExtentChecks: Integer;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire;

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

function Fixture: TCompositionDocument;
begin
  Result := Default(TCompositionDocument);
  Result.FRevision := 7;
  SetLength(Result.FNodes, 5);
  Result.FNodes[0].FId := 'world';
  Result.FNodes[0].FRole := 'world';
  Result.FNodes[0].FName := 'World';
  Result.FNodes[1].FId := 'floor';
  Result.FNodes[1].FParentId := 'world';
  Result.FNodes[1].FRole := 'floor-plan';
  Result.FNodes[1].FName := 'Floor';
  Result.FNodes[1].FWidth := 9400;
  Result.FNodes[1].FDepth := 9400;
  Result.FNodes[1].FHeight := 2700;
  Result.FNodes[2].FId := 'bay5';
  Result.FNodes[2].FParentId := 'floor';
  Result.FNodes[2].FRole := 'bay';
  Result.FNodes[2].FName := 'Bay 5';
  Result.FNodes[2].FWidth := 4200;
  Result.FNodes[2].FDepth := 3200;
  Result.FNodes[2].FHeight := 2700;
  Result.FNodes[2].FX := 2500;
  Result.FNodes[3].FId := 'room';
  Result.FNodes[3].FParentId := 'bay5';
  Result.FNodes[3].FRole := 'laboratory';
  Result.FNodes[3].FName := 'Laboratory';
  Result.FNodes[3].FWidth := 4000;
  Result.FNodes[3].FDepth := 3000;
  Result.FNodes[3].FHeight := 2600;
  Result.FNodes[4].FId := 'table';
  Result.FNodes[4].FParentId := 'room';
  Result.FNodes[4].FRole := 'table';
  Result.FNodes[4].FAssetId := 'fixture.table';
  Result.FNodes[4].FKind := ckObject;
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

procedure StructureChecks;
var
  LBase: TCompositionDocument;
  LCandidate: TCompositionDocument;
  LOutput: TCompositionDocument;
  I: Integer;
begin
  LBase := Fixture;
  Check(ValidateComposition(LBase, GReason), 'Nested explicit floor, bay and room fit');
  for I := 0 to 2 do
  begin
    LCandidate := CopyDocument(LBase);
    case I of
      0:
      begin
        Inc(LCandidate.FNodes[3].FWidth);
      end;
      1:
      begin
        Inc(LCandidate.FNodes[3].FDepth);
      end;
      2:
      begin
        Inc(LCandidate.FNodes[3].FHeight);
      end;
    end;
    Check(not SameNode(LBase.FNodes[3], LCandidate.FNodes[3]), 'Extent is part of node equality');
    Check(CommitComposition(LBase, LCandidate, 'room', 7, LOutput, GReason),
      'A fitting unlocked volume can change in scope');
    Check(LOutput.FRevision = 8, 'Volume edit commits one revision');
    Check(not SameNode(LOutput.FNodes[3], LBase.FNodes[3]), 'Committed extent remains explicit');
    Check(SameNode(LBase.FNodes[4], LOutput.FNodes[4]), 'Unmoved contents retain their records');
  end;
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[3].FWidth := 0;
  Check(not ValidateComposition(LCandidate, GReason), 'Partial extent rejected');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[3].FHeight := -1;
  Check(not ValidateComposition(LCandidate, GReason), 'Negative extent rejected');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[4].FWidth := 1;
  LCandidate.FNodes[4].FDepth := 1;
  LCandidate.FNodes[4].FHeight := 1;
  Check(not ValidateComposition(LCandidate, GReason), 'Extents cannot resize catalog objects');
  LCandidate.FNodes[4].FKind := ckSurface;
  Check(not ValidateComposition(LCandidate, GReason), 'Extents cannot resize catalog supports');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[2].FX := 2601;
  Check(not ValidateComposition(LCandidate, GReason), 'Full bay boundary, not centre, must fit');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[3].FQuarterTurn := 1;
  Check(not ValidateComposition(LCandidate, GReason), 'Rotated room depth exceeds bay');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[3].FWidth := 4001;
  LCandidate.FNodes[3].FX := 99;
  Check(ValidateComposition(LCandidate, GReason), 'Half-millimetre edge inside bay');
  LCandidate.FNodes[3].FX := 100;
  Check(not ValidateComposition(LCandidate, GReason), 'Half-millimetre protrusion rejected');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[3].FY := 101;
  Check(not ValidateComposition(LCandidate, GReason), 'Ceiling crossing rejected');
  LCandidate.FNodes[3].FY := -1;
  Check(not ValidateComposition(LCandidate, GReason), 'Floor crossing rejected');

  LOutput := CopyDocument(LBase);
  LBase.FNodes[4].FLocked := True;
  LCandidate := CopyDocument(LBase);
  Dec(LCandidate.FNodes[3].FWidth);
  Check(not CommitComposition(LBase, LCandidate, 'room', 7, LOutput, GReason),
    'Ancestor volume is a protected physical dependency of locked contents');
  LBase.FNodes[4].FLocked := False;
  Check(SameDocument(LOutput, LBase), 'Rejected resize preserves all output fields');
  LCandidate := CopyDocument(LBase);
  LCandidate.FNodes[2].FWidth := 3000;
  Check(not CommitComposition(LBase, LCandidate, 'bay5', 7, LOutput, GReason),
    'Shrinking a bay cannot leave an oversized child room');
  Check(SameDocument(LOutput, LBase), 'Failed geometric commit is atomic');
  LCandidate := CopyDocument(LBase);
  Dec(LCandidate.FNodes[2].FHeight);
  Check(not CommitComposition(LBase, LCandidate, 'room', 7, LOutput, GReason),
    'Local room edit cannot resize its external bay');
end;

procedure WireChecks;
var
  LBase: TCompositionDocument;
  LRead: TCompositionDocument;
  LLegacy: TCompositionDocument;
  LText: TCompositionJSONText;
  LVersionOne: TCompositionJSONText;
  LBad: TCompositionJSONText;
  I: Integer;

  procedure Rejected(const AText: TCompositionJSONText; const AMessage: String);
  begin
    Check(not ReadCompositionJSON(AText, LRead, GReason), AMessage);
    Check(SameDocument(LRead, LBase), 'Rejected extent import preserves complete prior snapshot');
  end;

begin
  LBase := Fixture;
  LRead := CopyDocument(LBase);
  LText := CompositionJSON(LBase);
  Check(Pos('"version":2', StringReplace(LText, ' ', '', [rfReplaceAll])) > 0,
    'Explicit volumes use composition version 2');
  Check(ReadCompositionJSON(LText, LRead, GReason), 'Read explicit volumes');
  Check(SameDocument(LBase, LRead), 'All volume and legacy fields round trip');
  Check(CompositionJSON(LRead) = LText, 'Canonical version 2 round trip');
  LBad := StringReplace(LText, '"version":2', '"version":1', [rfReplaceAll]);
  LBad := StringReplace(LBad, '"version" : 2', '"version" : 1', [rfReplaceAll]);
  Rejected(LBad, 'Version 1 cannot silently discard volume fields');
  LBad := StringReplace(LText, '"width":9400', '"width":9400.5', [rfReplaceAll]);
  LBad := StringReplace(LBad, '"width" : 9400', '"width" : 9400.5', [rfReplaceAll]);
  Rejected(LBad, 'Fractional volume dimensions rejected');
  LBad := StringReplace(LText, '"width":9400', '"width":2147483648', [rfReplaceAll]);
  LBad := StringReplace(LBad, '"width" : 9400', '"width" : 2147483648', [rfReplaceAll]);
  Rejected(LBad, 'Out-of-range volume dimensions rejected');
  LBad := StringReplace(LText, '"width":9400', '"width":null', [rfReplaceAll]);
  LBad := StringReplace(LBad, '"width" : 9400', '"width" : null', [rfReplaceAll]);
  Rejected(LBad, 'Null dimensions are not absent implicit geometry');
  LBad := StringReplace(LText, '"width":9400', '"width":0', [rfReplaceAll]);
  LBad := StringReplace(LBad, '"width" : 9400', '"width" : 0', [rfReplaceAll]);
  Rejected(LBad, 'Version 2 all-or-none dimensions enforced');
  LBad := StringReplace(LText, '"depth"', '"missingDepth"', [rfReplaceAll]);
  Rejected(LBad, 'Every version 2 node needs all three extent fields');

  LLegacy := CopyDocument(LBase);
  for I := 0 to High(LLegacy.FNodes) do
  begin
    LLegacy.FNodes[I].FWidth := 0;
    LLegacy.FNodes[I].FDepth := 0;
    LLegacy.FNodes[I].FHeight := 0;
  end;
  LVersionOne := CompositionJSON(LLegacy);
  Check(Pos('"version":1', StringReplace(LVersionOne, ' ', '', [rfReplaceAll])) > 0,
    'Legacy implicit profiles retain version 1');
  Check(Pos('"width"', LVersionOne) = 0, 'Legacy exports do not gain extent fields');
  Check(ReadCompositionJSON(LVersionOne, LRead, GReason), 'Read legacy composition after schema extension');
  Check(SameDocument(LLegacy, LRead), 'Legacy import preserves implicit geometry');
  Check(CompositionJSON(LRead) = LVersionOne, 'Legacy export text remains canonical and exact');
end;

function RunExtentChecks: Integer;
begin
  GChecks := 0;
  StructureChecks;
  WireChecks;
  Result := GChecks;
end;

end.
