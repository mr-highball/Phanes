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

unit phanes.tests.assemblies;

{$mode delphi}
{$H+}

interface

function RunAssemblyChecks: Integer;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.contents.types,
  phanes.composition.contents.assembly,
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

function NodeIndex(const ADocument: TCompositionDocument; const AId: String): Integer;
var
  LIndex: TCompositionIndex;
begin
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    Result := LIndex.Find(AId);
  finally
    LIndex.Free;
  end;
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

function Asset(const AId, ARole: String; const AWidth, ADepth, AHeight: Integer): TContentAsset;
begin
  Result := Default(TContentAsset);
  Result.FId := AId;
  Result.FName := UnicodeString(AId);
  Result.FRole := ARole;
  Result.FWidth := AWidth;
  Result.FDepth := ADepth;
  Result.FHeight := AHeight;
  Result.FSingleInstance := True;
end;

procedure AddNode(var ADocument: TCompositionDocument; const AId, AParent,
  ASupport, ARole, AAsset: String; const AKind: TCompositionKind;
  const AX, AY, AZ, ATurn: Integer);
var
  LNode: TCompositionNode;
  LCount: Integer;
begin
  LNode := Default(TCompositionNode);
  LNode.FId := AId;
  LNode.FName := UnicodeString(AId);
  LNode.FParentId := AParent;
  LNode.FSupportId := ASupport;
  LNode.FRole := ARole;
  LNode.FAssetId := AAsset;
  LNode.FKind := AKind;
  LNode.FX := AX;
  LNode.FY := AY;
  LNode.FZ := AZ;
  LNode.FQuarterTurn := ATurn;
  LNode.FSeed := 773;
  LCount := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, LCount + 1);
  ADocument.FNodes[LCount] := LNode;
end;

procedure Fixture(out ABase: TCompositionDocument; out ARequest: TContentRequest);
var
  LSupport: TContentSupport;
  I: Integer;
begin
  ABase := Default(TCompositionDocument);
  ABase.FRevision := 9;
  AddNode(ABase, 'world', '', '', 'world', '', ckContainer, 0, 0, 0, 0);
  AddNode(ABase, 'bench', 'world', '', 'bench-top', '', ckSurface, 0, 0, 0, 0);
  AddNode(ABase, 'case-left', 'bench', 'bench', 'carrier', 'fixture.case-a',
    ckObject, -150, 0, 0, 0);
  AddNode(ABase, 'case-left.tray', 'case-left', '', 'tray', 'fixture.tray',
    ckSurface, 0, 20, 0, 0);
  AddNode(ABase, 'specimen', 'case-left.tray', 'case-left.tray', 'part', 'fixture.part',
    ckObject, 30, 0, 0, 1);
  AddNode(ABase, 'specimen.top', 'specimen', '', 'label-support', 'fixture.label-support',
    ckSurface, 20, 40, 0, 1);
  AddNode(ABase, 'badge', 'specimen.top', 'specimen.top', 'label', 'fixture.badge',
    ckObject, 2, 0, 0, 0);
  ARequest := Default(TContentRequest);
  ARequest.FSurfaceId := 'bench';
  ARequest.FScopeId := 'bench';
  ARequest.FExpectedRevision := ABase.FRevision;
  ARequest.FSurfaceWidth := 600;
  ARequest.FSurfaceDepth := 240;
  ARequest.FHeadroom := 240;
  ARequest.FSeed := 17;
  SetLength(ARequest.FSlots, 2);
  for I := 0 to 1 do
  begin
    ARequest.FSlots[I].FObjectId := 'case-left';
    ARequest.FSlots[I].FX := -150;
    if I = 1 then
    begin
      ARequest.FSlots[I].FObjectId := 'case-right';
      ARequest.FSlots[I].FX := 150;
    end;
    ARequest.FSlots[I].FWidth := 200;
    ARequest.FSlots[I].FDepth := 200;
    ARequest.FSlots[I].FHeight := 220;
    ARequest.FSlots[I].FAllowEmpty := True;
    ARequest.FSlots[I].FAllowedRoles := ['carrier'];
  end;
  SetLength(ARequest.FAssets, 5);
  ARequest.FAssets[0] := Asset('fixture.case-a', 'carrier', 120, 120, 20);
  ARequest.FAssets[1] := Asset('fixture.case-b', 'carrier', 120, 120, 20);
  ARequest.FAssets[2] := Asset('fixture.plain-case', 'carrier', 120, 120, 20);
  ARequest.FAssets[3] := Asset('fixture.part', 'part', 80, 30, 40);
  ARequest.FAssets[4] := Asset('fixture.badge', 'label', 8, 10, 10);
  LSupport := Default(TContentSupport);
  LSupport.FKey := 'tray';
  LSupport.FName := 'Specimen tray';
  LSupport.FRole := 'tray';
  LSupport.FAssetId := 'fixture.tray';
  LSupport.FY := 20;
  LSupport.FWidth := 140;
  LSupport.FDepth := 120;
  LSupport.FHeadroom := 200;
  LSupport.FAllowedRoles := ['part'];
  SetLength(ARequest.FAssets[0].FSupports, 1);
  ARequest.FAssets[0].FSupports[0] := LSupport;
  SetLength(ARequest.FAssets[1].FSupports, 1);
  ARequest.FAssets[1].FSupports[0] := LSupport;
  LSupport := Default(TContentSupport);
  LSupport.FKey := 'top';
  LSupport.FName := 'Label';
  LSupport.FRole := 'label-support';
  LSupport.FAssetId := 'fixture.label-support';
  LSupport.FX := 20;
  LSupport.FY := 40;
  LSupport.FQuarterTurn := 1;
  LSupport.FWidth := 20;
  LSupport.FDepth := 20;
  LSupport.FHeadroom := 20;
  LSupport.FAllowedRoles := ['label'];
  SetLength(ARequest.FAssets[3].FSupports, 1);
  ARequest.FAssets[3].FSupports[0] := LSupport;
  SetLength(ARequest.FQuotas, 1);
  ARequest.FQuotas[0].FRole := 'carrier';
  ARequest.FQuotas[0].FMinimum := 1;
  ARequest.FQuotas[0].FMaximum := 1;
end;

function RunAssemblyChecks: Integer;
var
  LBase: TCompositionDocument;
  LRequest: TContentRequest;
  LResult: TCompositionDocument;
  LSaved: TCompositionDocument;
  LReplay: TCompositionDocument;
  LReader: TContentAssemblies;
  LBounds: TContentBounds;
  LNode: TCompositionNode;
  I: Integer;
  J: Integer;
begin
  GChecks := 0;
  Fixture(LBase, LRequest);
  Check(ValidateContentResult(LBase, LRequest, GReason), 'Admit a three-object non-food assembly');
  LReader := TContentAssemblies.Create(LBase, LRequest.FAssets);
  try
    Check(LReader.Bounds('case-left', '', LBounds, GReason), 'Read full nested bounds');
    Check((LBounds.FMinX = -60) and (LBounds.FMaxX = 60) and
      (LBounds.FMinZ = -60) and (LBounds.FMaxZ = 60) and
      (LBounds.FMinY = 0) and (LBounds.FMaxY = 70), 'Independent transformed envelope dimensions');
  finally
    LReader.Free;
  end;
  for I := 0 to 31 do
  begin
    LRequest.FSeed := I;
    Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Regenerate surrounding content');
    Check(NodeIndex(LResult, 'case-left') >= 0, 'Keep occupied assembly identity');
    Check(NodeIndex(LResult, 'case-right') < 0, 'Do not move quota to an empty replacement');
    for J := 3 to 6 do
    begin
      Check(SameNode(LBase.FNodes[J], LResult.FNodes[NodeIndex(LResult, LBase.FNodes[J].FId)]),
        'Preserve each nested record and seed');
    end;
  end;
  LRequest.FSlots[0].FAllowedAssets := ['fixture.case-b'];
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Compatible parent appearance');
  Check(LResult.FNodes[2].FAssetId = 'fixture.case-b', 'Selected compatible asset published');
  LSaved := CopyDocument(LResult);
  LRequest.FSlots[0].FAllowedAssets := ['fixture.plain-case'];
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Reject loss of occupied support');
  Check(SameDocument(LResult, LSaved), 'Failed parent replacement preserves output');

  Fixture(LBase, LRequest);
  LBase.FNodes[6].FAssetId := 'unknown.geometry';
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Unknown descendant geometry rejects');
  Fixture(LBase, LRequest);
  LBase.FNodes[3].FY := 21;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Forged support contact rejects');
  Fixture(LBase, LRequest);
  AddNode(LBase, 'intruder', 'world', 'case-left.tray', 'part', 'fixture.part',
    ckObject, 0, 0, 0, 0);
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Cross-owned support rejects');
  Fixture(LBase, LRequest);
  AddNode(LBase, 'overlap', 'case-left.tray', 'case-left.tray', 'part', 'fixture.part',
    ckObject, 30, 0, 0, 1);
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Sibling assembly overlap rejects');
  Fixture(LBase, LRequest);
  LRequest.FSlots[0].FHeight := 65;
  Check(not ValidateContentResult(LBase, LRequest, GReason), 'Ancestor slot sees deepest child height');
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Domains exclude full-height overflow');
  Fixture(LBase, LRequest);
  LBase.FNodes[3].FX := 120;
  LRequest.FAssets[0].FSupports[0].FX := 120;
  LRequest.FAssets[1].FSupports[0].FX := 120;
  Check(not ValidateContentResult(LBase, LRequest, GReason), 'Historical120mm child overhang rejects');

  Fixture(LBase, LRequest);
  LBase.FNodes[6].FLocked := True;
  LRequest.FSlots[0].FAllowedAssets := ['fixture.case-b'];
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Locked child freezes parent asset');
  LRequest.FSlots[0].FAllowedAssets := nil;
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Surrounding solve retains locked assembly');
  Check(SameNode(LBase.FNodes[2], LResult.FNodes[2]), 'Locked ancestor dependency unchanged');
  LRequest.FQuotas[0].FMinimum := 0;
  LRequest.FQuotas[0].FMaximum := 0;
  LRequest.FRemovableAssemblyRoles := ['carrier'];
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Explicit removal still honors child lock');
  LBase.FNodes[6].FLocked := False;
  LRequest.FRemovableAssemblyRoles := nil;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Quota alone cannot discard an assembly');
  LRequest.FRemovableAssemblyRoles := ['carrier'];
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Explicit count reduction removes subtree');
  Check(Length(LResult.FNodes) = 2, 'All removed descendants leave together');

  Fixture(LBase, LRequest);
  LRequest.FSlots[0].FX := -130;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Ordinary regeneration cannot move assembly');
  LRequest.FAllowAssemblyMoves := True;
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Explicit compatible assembly movement');
  Check(LResult.FNodes[2].FX = -130, 'Only root moves in parent frame');
  for I := 3 to 6 do
  begin
    Check(SameNode(LBase.FNodes[I], LResult.FNodes[I]), 'Moving parent retains child local transform');
  end;
  LBase.FNodes[6].FLocked := True;
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Explicit movement cannot move locked child');

  for I := 0 to 3 do
  begin
    Fixture(LBase, LRequest);
    LBase.FNodes[2].FQuarterTurn := I;
    LRequest.FSlots[0].FQuarterTurn := I;
    for J := 0 to Length(LBase.FNodes) div 2 - 1 do
    begin
      LNode := LBase.FNodes[J];
      LBase.FNodes[J] := LBase.FNodes[High(LBase.FNodes) - J];
      LBase.FNodes[High(LBase.FNodes) - J] := LNode;
    end;
    Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Rotation and storage-order independence');
    Check(ValidateContentResult(LResult, LRequest, GReason), 'Rotated result independently admitted');
  end;

  Fixture(LBase, LRequest);
  Check(GenerateContents(LBase, LRequest, LBase, GReason), 'Nested commit may alias baseline');
  LSaved := CopyDocument(LBase);
  Check(not GenerateContents(LBase, LRequest, LBase, GReason), 'Stale nested alias rejects');
  Check(SameDocument(LBase, LSaved), 'Stale nested alias preserves every node');
  Fixture(LBase, LRequest);
  LBase.FRevision := High(Integer) - 1;
  LRequest.FExpectedRevision := LBase.FRevision;
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Use final public revision');
  Check(LResult.FRevision = High(Integer), 'One revision for entire assembly transaction');
  LRequest.FExpectedRevision := LResult.FRevision;
  Check(not GenerateContents(LResult, LRequest, LReplay, GReason), 'Exhausted revision rejects');

  Fixture(LBase, LRequest);
  SetLength(LBase.FNodes, 3);
  Check(ValidateContentResult(LBase, LRequest, GReason), 'Old leaf save need not contain optional support');
  LRequest.FSlots[0].FAllowedAssets := ['fixture.case-a'];
  Check(GenerateContents(LBase, LRequest, LResult, GReason), 'Create admitted support for leaf parent');
  Check(NodeIndex(LResult, 'case-left.tray') >= 0, 'New support has stable identity');
  AddNode(LBase, 'case-left.tray', 'world', '', 'elsewhere', '', ckSurface, 0, 0, 0, 0);
  LRequest.FScopeId := 'case-left';
  Check(not GenerateContents(LBase, LRequest, LResult, GReason), 'Support ID collision rejects');
  LRequest.FSlots[0].FAllowedAssets := nil;
  for I := 0 to 31 do
  begin
    LRequest.FSeed := I;
    Check(GenerateContents(LBase, LRequest, LResult, GReason),
      'Unavailable support candidate cannot mask a legal alternative');
    Check(LResult.FNodes[2].FAssetId = 'fixture.plain-case', 'Use collision-free candidate');
  end;
  Fixture(LBase, LRequest);
  SetLength(LBase.FNodes, 3);
  LBase.FNodes[2].FId := StringOfChar('x', 128);
  LRequest.FSlots[0].FObjectId := LBase.FNodes[2].FId;
  LRequest.FScopeId := LBase.FNodes[2].FId;
  for I := 0 to 31 do
  begin
    LRequest.FSeed := I;
    Check(GenerateContents(LBase, LRequest, LResult, GReason),
      'Long identity excludes generated support before solving');
    Check(LResult.FNodes[2].FAssetId = 'fixture.plain-case', 'Use valid leaf alternative');
  end;
  Fixture(LBase, LRequest);
  SetLength(LBase.FNodes, 2);
  LRequest.FSlots[0].FObjectId := 'case';
  LRequest.FSlots[1].FObjectId := 'case.tray';
  LRequest.FSlots[0].FAllowEmpty := False;
  LRequest.FSlots[1].FAllowEmpty := False;
  LRequest.FQuotas[0].FMinimum := 2;
  LRequest.FQuotas[0].FMaximum := 2;
  for I := 0 to 63 do
  begin
    LRequest.FSeed := I;
    Check(GenerateContents(LBase, LRequest, LResult, GReason),
      'New support candidates respect all requested root identities');
    Check(LResult.FNodes[NodeIndex(LResult, 'case')].FAssetId = 'fixture.plain-case',
      'Choose the legal parent alternative before identity mutation');
  end;
  Fixture(LBase, LRequest);
  SetLength(LRequest.FAssets[0].FSupports, 2);
  LRequest.FAssets[0].FSupports[1] := LRequest.FAssets[0].FSupports[0];
  Check(not ValidateContentAssets(LRequest.FAssets, GReason), 'Duplicate profile keys reject');
  Result := GChecks;
end;

end.
