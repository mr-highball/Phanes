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
unit phanes.tests.composition.wire;
{$mode delphi}
{$H+}
{$codepage utf8}

interface

function RunCompositionWireChecks: Integer;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.wire;

function RunCompositionWireChecks: Integer;
const
  CSingle = '{"format":"phanes.composition","version":1,"units":"millimetres",' +
    '"revision":17,"nodes":[{"id":"root","parent":"","support":"","name":"World",' +
    '"role":"world","asset":"","kind":"container","x":0,"y":0,"z":0,' +
    '"quarterTurn":0,"seed":4294967295,"locked":false}]}';
var
  LBase: TCompositionDocument;
  LRead: TCompositionDocument;
  LText: TCompositionJSONText;
  LReason: String;
  LChecks: Integer;
  LInvalidNameRejected: Boolean;
  I: Integer;

  procedure Check(const ACondition: Boolean; const AMessage: String);
  begin
    Inc(LChecks);
    if not ACondition then
    begin
      raise Exception.Create(AMessage + ': ' + LReason);
    end;
  end;

  procedure Rejected(const AText: TCompositionJSONText; const AMessage: String);
  begin
    Check(not ReadCompositionJSON(AText, LRead, LReason), AMessage);
    Check((LRead.FRevision = 17) and (Length(LRead.FNodes) = 3) and
      SameNode(LRead.FNodes[2], LBase.FNodes[2]), 'Rejected load preserves existing document');
  end;

begin
  LChecks := 0;
  LBase := Default(TCompositionDocument);
  LBase.FRevision := 17;
  SetLength(LBase.FNodes, 3);
  LBase.FNodes[0].FId := 'world';
  LBase.FNodes[0].FName := 'World';
  LBase.FNodes[0].FRole := 'world';
  LBase.FNodes[0].FKind := ckContainer;
  LBase.FNodes[0].FSeed := High(Cardinal);
  LBase.FNodes[1].FId := 'shelf2';
  LBase.FNodes[1].FParentId := 'world';
  LBase.FNodes[1].FKind := ckSurface;
  LBase.FNodes[1].FName := 'Shelf "2" / café — 雲' + #10 + #9 + '\archive';
  LBase.FNodes[1].FRole := 'shelf-tier';
  LBase.FNodes[1].FX := -230;
  LBase.FNodes[1].FY := 1250;
  LBase.FNodes[1].FQuarterTurn := 3;
  LBase.FNodes[1].FLocked := True;
  LBase.FNodes[2].FId := 'snail';
  LBase.FNodes[2].FParentId := 'shelf2';
  LBase.FNodes[2].FSupportId := 'shelf2';
  LBase.FNodes[2].FKind := ckObject;
  LBase.FNodes[2].FRole := 'ornament';
  LBase.FNodes[2].FAssetId := 'fixture.snail';
  LBase.FNodes[2].FName := 'Ceramic snail';
  LBase.FNodes[2].FZ := Low(Integer);
  LBase.FNodes[2].FX := High(Integer);
  LText := CompositionJSON(LBase);
  Check(ReadCompositionJSON(LText, LRead, LReason), 'Composition save/load');
  Check(LRead.FRevision = LBase.FRevision, 'Wire revision survives');
  for I := 0 to High(LBase.FNodes) do
  begin
    Check(SameNode(LBase.FNodes[I], LRead.FNodes[I]), 'All node fields survive at ' + IntToStr(I));
  end;
  LRead.FNodes[2].FName := 'Independent';
  Check(LBase.FNodes[2].FName = 'Ceramic snail', 'Loaded document does not alias source');
  Check(ReadCompositionJSON(LText, LRead, LReason), 'Reload before rejection checks');
  Rejected('', 'Empty input');
  Rejected('{', 'Malformed JSON');
  Rejected(CSingle + '{}', 'Trailing second document');
  Rejected(StringReplace(CSingle, '"version":', 'version:', []), 'Unquoted key');
  Rejected(StringReplace(CSingle, '"version":1,', '"version":1,,', []), 'Extra comma');
  Rejected(StringReplace(CSingle, '"version":1,', '"version":1,"version":1,', []),
    'Duplicate member is rejected on both runtimes');
  Rejected(StringReplace(CSingle, '"version":1,', '"version":1,"\u0076ersion":1,', []),
    'Escaped duplicate member is rejected');
  Rejected('null', 'Null document');
  Rejected('[]', 'Array instead of document');
  Rejected(StringReplace(CSingle, '"version":1', '"version":2', []), 'Unsupported version');
  Rejected(StringReplace(CSingle, '"millimetres"', '"metres"', []), 'Wrong units');
  Rejected(StringReplace(CSingle, '"revision":17', '"revision":1.5', []), 'Fractional revision');
  Rejected(StringReplace(CSingle, '4294967295', '4294967296', []), 'Seed overflow');
  Rejected(StringReplace(CSingle, '4294967295', '-1', []), 'Negative seed');
  Rejected(StringReplace(CSingle, '"x":0', '"x":2147483648', []), 'Coordinate overflow');
  Rejected(StringReplace(CSingle, '"x":0', '"x":"0"', []), 'Numeric text not coerced');
  Rejected(StringReplace(CSingle, '"quarterTurn":0', '"quarterTurn":4', []), 'Rotation outside range');
  Rejected(StringReplace(CSingle, '"locked":false', '"locked":0', []), 'Numeric lock not coerced');
  Rejected(StringReplace(CSingle, '"support"', '"missingSupport"', []), 'Missing required support field');
  Rejected(StringReplace(CSingle, '"container"', '"unknown"', []), 'Unknown node kind');
  Rejected(StringReplace(CSingle, '"role":"world"', '"role":"\u96f2"', []),
    'Semantic code cannot undergo native ANSI conversion');
  Rejected(StringReplace(CSingle, '"name":"World"', '"name":"\udc00"', []),
    'Isolated low surrogate rejected before native replacement');
  Rejected(StringReplace(CSingle, '"name":"World"', '"name":"\ud800"', []),
    'Isolated high surrogate rejected');
  Rejected(StringReplace(CSingle, '"name":"World"', '"name":"\ud800x"', []),
    'Interrupted surrogate pair rejected');
  Rejected(StringReplace(LText, '"snail"', '"shelf2"', []), 'Duplicate identity rejected after parsing');
  Rejected(StringReplace(LText, '"world"', '"snail"', [rfReplaceAll]), 'Root and dependency corruption');
  Rejected(StringOfChar('[', 17) + StringOfChar(']', 17), 'Excessive JSON depth preflight');

  Check(ReadCompositionJSON(CSingle, LRead, LReason), 'Independent format fixture accepted');
  Check((LRead.FNodes[0].FSeed = High(Cardinal)) and (LRead.FRevision = 17), 'Unsigned seed retained');
  Check(ReadCompositionJSON(StringReplace(CSingle, '"name":"World"',
    '"name":"\ud83d\udc0c"', []), LRead, LReason), 'Supplementary snail label accepted');
  Check((Length(LRead.FNodes[0].FName) = 2) and
    (Ord(LRead.FNodes[0].FName[1]) = $D83D) and
    (Ord(LRead.FNodes[0].FName[2]) = $DC0C), 'Supplementary label retains exact surrogate pair');
  LRead.FNodes[0].FName := UnicodeChar($DC00);
  LInvalidNameRejected := False;
  try
    CompositionJSON(LRead);
  except
    on LException: Exception do
    begin
      LInvalidNameRejected := True;
    end;
  end;
  Check(LInvalidNameRejected, 'Writer rejects isolated surrogate in display name');
  LRead := CopyDocument(LBase);
  Check(ReadCompositionJSON(CompositionJSON(LRead), LRead, LReason), 'Load can replace its own save');
  Check(SameNode(LBase.FNodes[1], LRead.FNodes[1]), 'Unicode, escapes and lock remain exact');
  Result := LChecks;
end;

end.
