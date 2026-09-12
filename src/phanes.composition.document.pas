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
unit phanes.composition.document;
{$mode delphi}
{$H+}

interface

uses
  Classes,
  phanes.composition.types;

type
  { A sorted ID index avoids scanning every node for each parent/support edge.
    Display order never determines persistent identity. }
  TCompositionIndex = class
  private
    FIds: TStringList;
  public
    constructor Create(const ANodes: TCompositionNodes);
    destructor Destroy; override;
    function Find(const AId: String): Integer;
  end;

function ValidateComposition(const ADocument: TCompositionDocument; out AReason: String): Boolean;
function InCompositionScope(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANodeIndex: Integer; const AScopeId: String): Boolean;
function CommitComposition(const ABaseline, ACandidate: TCompositionDocument;
  const AScopeId: String; const AExpectedRevision: Integer;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Math;

type
  TIndexEntry = class
    FIndex: Integer;
  end;

constructor TCompositionIndex.Create(const ANodes: TCompositionNodes);
var
  LEntry: TIndexEntry;
  I: Integer;
begin
  inherited Create;
  FIds := TStringList.Create;
  FIds.CaseSensitive := True;
  FIds.Sorted := False;
  for I := 0 to High(ANodes) do
  begin
    LEntry := TIndexEntry.Create;
    LEntry.FIndex := I;
    FIds.AddObject(ANodes[I].FId, LEntry);
  end;
  FIds.Sorted := True;
  for I := 1 to FIds.Count - 1 do
  begin
    if FIds[I] = FIds[I - 1] then
    begin
      raise Exception.Create('Duplicate object ID: ' + FIds[I]);
    end;
  end;
end;

destructor TCompositionIndex.Destroy;
var
  I: Integer;
  LEntry: TObject;
begin
  if FIds <> nil then
  begin
    for I := 0 to FIds.Count - 1 do
    begin
      LEntry := FIds.Objects[I];
      LEntry.Free;
    end;
    FIds.Free;
  end;
  inherited Destroy;
end;

function TCompositionIndex.Find(const AId: String): Integer;
var
  LIndex: Integer;
begin
  LIndex := FIds.IndexOf(AId);
  Result := -1;
  if LIndex >= 0 then
  begin
    Result := TIndexEntry(FIds.Objects[LIndex]).FIndex;
  end;
end;

function ValidId(const AId: String): Boolean;
var
  I: Integer;
begin
  Result := (Length(AId) > 0) and (Length(AId) <= 128);
  if not Result then
  begin
    Exit;
  end;
  for I := 1 to Length(AId) do
  begin
    if not (AId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '.', '_']) then
    begin
      Exit(False);
    end;
  end;
end;

function WholeInRange(const AValue, AMinimum, AMaximum: Double): Boolean;
begin
  Result := not IsNan(AValue) and not IsInfinite(AValue) and
    (AValue >= AMinimum) and (AValue <= AMaximum) and (Frac(AValue) = 0);
end;

function ValidateComposition(const ADocument: TCompositionDocument; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LRootCount: Integer;
  LParent: Integer;
  LSupport: Integer;
  LStates: array of Byte;
  LDepths: array of Integer;
  I: Integer;

  function ExtentFitsOwner(const ANode: Integer): Boolean;
  var
    LCurrent: Integer;
    LOwner: Integer;
    LFrame: TCompositionNode;
    LX: Double;
    LZ: Double;
    LHalfWidth: Double;
    LHalfDepth: Double;
    LBottom: Double;
    LTop: Double;
    LSwap: Double;
  begin
    Result := True;
    if not HasCompositionExtent(ADocument.FNodes[ANode]) then
    begin
      Exit;
    end;
    LX := 0;
    LZ := 0;
    LBottom := 0;
    LTop := ADocument.FNodes[ANode].FHeight;
    LHalfWidth := ADocument.FNodes[ANode].FWidth / 2;
    LHalfDepth := ADocument.FNodes[ANode].FDepth / 2;
    LCurrent := ANode;
    { Ownership was already checked for cycles/depth. Walk through implicit
      grouping frames to the nearest explicit container. Double preserves
      half-millimetre edges and all 128 signed-32-bit translations exactly. }
    while LCurrent >= 0 do
    begin
      LFrame := ADocument.FNodes[LCurrent];
      case LFrame.FQuarterTurn of
        1:
        begin
          LSwap := LX;
          LX := LZ;
          LZ := -LSwap;
        end;
        2:
        begin
          LX := -LX;
          LZ := -LZ;
        end;
        3:
        begin
          LSwap := LX;
          LX := -LZ;
          LZ := LSwap;
        end;
      end;
      if Odd(LFrame.FQuarterTurn) then
      begin
        LSwap := LHalfWidth;
        LHalfWidth := LHalfDepth;
        LHalfDepth := LSwap;
      end;
      LX := LX + LFrame.FX;
      LZ := LZ + LFrame.FZ;
      LBottom := LBottom + LFrame.FY;
      LTop := LTop + LFrame.FY;
      LOwner := LIndex.Find(LFrame.FParentId);
      if (LOwner >= 0) and HasCompositionExtent(ADocument.FNodes[LOwner]) then
      begin
        LFrame := ADocument.FNodes[LOwner];
        Result := (LX - LHalfWidth >= -LFrame.FWidth / 2) and
          (LX + LHalfWidth <= LFrame.FWidth / 2) and
          (LZ - LHalfDepth >= -LFrame.FDepth / 2) and
          (LZ + LHalfDepth <= LFrame.FDepth / 2) and
          (LBottom >= 0) and (LTop <= LFrame.FHeight);
        if not Result then
        begin
          AReason := 'Container volume leaves its bounded owner: ' +
            ADocument.FNodes[ANode].FId;
        end;
        Exit;
      end;
      LCurrent := LOwner;
    end;
  end;

  { Combined dependency edges include containment and physical support.
    Separate acyclic parent/support chains are insufficient: their union can cycle. }
  function Visit(const ANode: Integer; const ADepth: Integer): Boolean;
  var
    LDependency: Integer;
    LLongest: Integer;
  begin
    if LStates[ANode] = 2 then
    begin
      Exit(True);
    end;
    if (LStates[ANode] = 1) or (ADepth > 128) then
    begin
      AReason := 'Cyclic or excessively deep ownership/support at ' + ADocument.FNodes[ANode].FId;
      Exit(False);
    end;
    LStates[ANode] := 1;
    LLongest := 0;
    LDependency := LIndex.Find(ADocument.FNodes[ANode].FParentId);
    if (LDependency >= 0) and not Visit(LDependency, ADepth + 1) then
    begin
      Exit(False);
    end;
    if LDependency >= 0 then
    begin
      LLongest := LDepths[LDependency] + 1;
    end;
    LDependency := LIndex.Find(ADocument.FNodes[ANode].FSupportId);
    if (LDependency >= 0) and not Visit(LDependency, ADepth + 1) then
    begin
      Exit(False);
    end;
    if (LDependency >= 0) and (LDepths[LDependency] + 1 > LLongest) then
    begin
      LLongest := LDepths[LDependency] + 1;
    end;
    if LLongest > 128 then
    begin
      AReason := 'Ownership/support depth exceeds 128 at ' + ADocument.FNodes[ANode].FId;
      Exit(False);
    end;
    LDepths[ANode] := LLongest;
    LStates[ANode] := 2;
    Result := True;
  end;

begin
  Result := False;
  AReason := '';
  if not WholeInRange(ADocument.FRevision, 0, High(Integer)) or
    (Length(ADocument.FNodes) = 0) then
  begin
    AReason := 'A composition needs a nonnegative revision and a root container.';
    Exit;
  end;
  LIndex := nil;
  try
    try
      LIndex := TCompositionIndex.Create(ADocument.FNodes);
      LRootCount := 0;
      for I := 0 to High(ADocument.FNodes) do
      begin
        LNode := ADocument.FNodes[I];
        AReason := 'Invalid identity, role or transform at ' + LNode.FId;
        if not ValidId(LNode.FId) or (LNode.FRole = '') or
          not WholeInRange(Ord(LNode.FKind), Ord(Low(TCompositionKind)),
          Ord(High(TCompositionKind))) or not WholeInRange(LNode.FQuarterTurn, 0, 3) or
          not WholeInRange(LNode.FX, Low(Integer), High(Integer)) or
          not WholeInRange(LNode.FY, Low(Integer), High(Integer)) or
          not WholeInRange(LNode.FZ, Low(Integer), High(Integer)) or
          not WholeInRange(LNode.FSeed, 0, 4294967295.0) then
        begin
          Exit;
        end;
        AReason := 'Explicit extents require three positive container dimensions: ' + LNode.FId;
        if not WholeInRange(LNode.FWidth, 0, High(Integer)) or
          not WholeInRange(LNode.FDepth, 0, High(Integer)) or
          not WholeInRange(LNode.FHeight, 0, High(Integer)) then
        begin
          Exit;
        end;
        if HasCompositionExtent(LNode) and ((LNode.FKind <> ckContainer) or
          (LNode.FWidth = 0) or (LNode.FDepth = 0) or (LNode.FHeight = 0)) then
        begin
          Exit;
        end;
        if LNode.FParentId = '' then
        begin
          Inc(LRootCount);
          if (LNode.FKind <> ckContainer) or (LNode.FSupportId <> '') then
          begin
            AReason := 'The root must be an unsupported container.';
            Exit;
          end;
        end
        else
        begin
          LParent := LIndex.Find(LNode.FParentId);
          if (LParent < 0) or (LParent = I) then
          begin
            AReason := 'Missing or self parent at ' + LNode.FId;
            Exit;
          end;
        end;
        if LNode.FSupportId <> '' then
        begin
          LSupport := LIndex.Find(LNode.FSupportId);
          if (LSupport < 0) or (LSupport = I) then
          begin
            AReason := 'Missing or self support at ' + LNode.FId;
            Exit;
          end;
          if ADocument.FNodes[LSupport].FKind <> ckSurface then
          begin
            AReason := 'Support must identify an explicit surface at ' + LNode.FId;
            Exit;
          end;
        end;
        if (LNode.FKind = ckObject) and (LNode.FAssetId = '') then
        begin
          AReason := 'A placed object needs an asset or assembly ID: ' + LNode.FId;
          Exit;
        end;
      end;
      if LRootCount <> 1 then
      begin
        AReason := 'A composition must have exactly one root container.';
        Exit;
      end;
      SetLength(LStates, Length(ADocument.FNodes));
      SetLength(LDepths, Length(ADocument.FNodes));
      for I := 0 to High(ADocument.FNodes) do
      begin
        if not Visit(I, 0) then
        begin
          Exit;
        end;
      end;
      for I := 0 to High(ADocument.FNodes) do
      begin
        if not ExtentFitsOwner(I) then
        begin
          Exit;
        end;
      end;
      AReason := '';
      Result := True;
    except
      on LException: Exception do
      begin
        AReason := LException.Message;
      end;
    end;
  finally
    LIndex.Free;
  end;
end;

function InCompositionScope(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANodeIndex: Integer; const AScopeId: String): Boolean;
var
  LCurrent: Integer;
  LDepth: Integer;
begin
  Result := False;
  LCurrent := ANodeIndex;
  LDepth := 0;
  while (LCurrent >= 0) and (LCurrent < Length(ADocument.FNodes)) and (LDepth <= 128) do
  begin
    if ADocument.FNodes[LCurrent].FId = AScopeId then
    begin
      Exit(True);
    end;
    LCurrent := AIndex.Find(ADocument.FNodes[LCurrent].FParentId);
    Inc(LDepth);
  end;
end;


function CommitComposition(const ABaseline, ACandidate: TCompositionDocument;
  const AScopeId: String; const AExpectedRevision: Integer;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
var
  LBefore: TCompositionIndex;
  LAfter: TCompositionIndex;
  LCandidateIndex: Integer;
  LBaselineIndex: Integer;
  LParentIndex: Integer;
  LChanged: Boolean;
  LScopeBefore: Integer;
  LScopeAfter: Integer;
  LStaged: TCompositionDocument;
  LBoundaryStates: array of Byte;
  LProtectedStates: array of Byte;
  I: Integer;

  function Protected(const ANode: Integer): Boolean;
  var
    LDependency: Integer;
  begin
    if LProtectedStates[ANode] <> 0 then
    begin
      Exit(LProtectedStates[ANode] = 2);
    end;
    Result := ABaseline.FNodes[ANode].FLocked;
    if not Result then
    begin
      LDependency := LBefore.Find(ABaseline.FNodes[ANode].FParentId);
      Result := (LDependency >= 0) and Protected(LDependency);
    end;
    if not Result then
    begin
      LDependency := LBefore.Find(ABaseline.FNodes[ANode].FSupportId);
      Result := (LDependency >= 0) and Protected(LDependency);
    end;
    LProtectedStates[ANode] := 1;
    if Result then
    begin
      LProtectedStates[ANode] := 2;
    end;
  end;

  function ExternalReferenceChanged(const ACurrent, APrevious: String): Boolean;
  var
    LReference: Integer;
  begin
    LReference := LAfter.Find(ACurrent);
    Result := (LReference >= 0) and (ACurrent <> APrevious) and
      not InCompositionScope(ACandidate, LAfter, LReference, AScopeId);
  end;

  function DependencyChanged(const ANode: Integer): Boolean;
  var
    LNewIndex: Integer;
    LDependency: Integer;
    LComparable: TCompositionNode;
  begin
    if LBoundaryStates[ANode] <> 0 then
    begin
      Exit(LBoundaryStates[ANode] = 2);
    end;
    LNewIndex := LAfter.Find(ABaseline.FNodes[ANode].FId);
    Result := LNewIndex < 0;
    if not Result then
    begin
      LComparable := ACandidate.FNodes[LNewIndex];
      { Labels and provenance do not move supported objects. Domain adapters
        still validate physical geometry, material safety and clearance. }
      LComparable.FName := ABaseline.FNodes[ANode].FName;
      LComparable.FSeed := ABaseline.FNodes[ANode].FSeed;
      LComparable.FLocked := ABaseline.FNodes[ANode].FLocked;
      Result := not SameNode(LComparable, ABaseline.FNodes[ANode]);
    end;
    if not Result then
    begin
      LDependency := LBefore.Find(ABaseline.FNodes[ANode].FParentId);
      Result := (LDependency >= 0) and DependencyChanged(LDependency);
    end;
    if not Result then
    begin
      LDependency := LBefore.Find(ABaseline.FNodes[ANode].FSupportId);
      Result := (LDependency >= 0) and DependencyChanged(LDependency);
    end;
    LBoundaryStates[ANode] := 1;
    if Result then
    begin
      LBoundaryStates[ANode] := 2;
    end;
  end;
begin
  Result := False;
  { var deliberately permits output to alias an input snapshot. Nothing is
    written until all checks pass; rejection preserves the caller's output. }
  AReason := 'This edit is stale. The world changed while it was being generated.';
  if (ABaseline.FRevision <> AExpectedRevision) or
    (ACandidate.FRevision <> AExpectedRevision) or
    (ABaseline.FRevision = High(Integer)) then
  begin
    Exit;
  end;
  if not ValidateComposition(ABaseline, AReason) or
    not ValidateComposition(ACandidate, AReason) then
  begin
    Exit;
  end;
  LBefore := TCompositionIndex.Create(ABaseline.FNodes);
  LAfter := TCompositionIndex.Create(ACandidate.FNodes);
  try
    SetLength(LProtectedStates, Length(ABaseline.FNodes));
    LScopeBefore := LBefore.Find(AScopeId);
    LScopeAfter := LAfter.Find(AScopeId);
    if (LScopeBefore < 0) or (LScopeAfter < 0) then
    begin
      AReason := 'The selected container or object must retain its identity.';
      Exit;
    end;
    if (ABaseline.FNodes[LScopeBefore].FParentId <> ACandidate.FNodes[LScopeAfter].FParentId) or
      (ABaseline.FNodes[LScopeBefore].FSupportId <> ACandidate.FNodes[LScopeAfter].FSupportId) then
    begin
      AReason := 'Moving the selected scope between containers/supports requires a wider scope.';
      Exit;
    end;
    for I := 0 to High(ABaseline.FNodes) do
    begin
      LCandidateIndex := LAfter.Find(ABaseline.FNodes[I].FId);
      LChanged := LCandidateIndex < 0;
      if not LChanged then
      begin
        LChanged := not SameNode(ABaseline.FNodes[I], ACandidate.FNodes[LCandidateIndex]);
      end;
      if LChanged and
        (not InCompositionScope(ABaseline, LBefore, I, AScopeId) or
        Protected(I)) then
      begin
        AReason := 'Edit changed a locked or out-of-scope object: ' + ABaseline.FNodes[I].FId;
        Exit;
      end;
    end;
    for I := 0 to High(ACandidate.FNodes) do
    begin
      LBaselineIndex := LBefore.Find(ACandidate.FNodes[I].FId);
      LChanged := LBaselineIndex < 0;
      if not LChanged then
      begin
        LChanged := not SameNode(ABaseline.FNodes[LBaselineIndex], ACandidate.FNodes[I]);
      end;
      if LChanged then
      begin
        if not InCompositionScope(ACandidate, LAfter, I, AScopeId) then
        begin
          AReason := 'Edit moved or inserted an object outside its scope: ' + ACandidate.FNodes[I].FId;
          Exit;
        end;
        if LBaselineIndex < 0 then
        begin
          if ExternalReferenceChanged(ACandidate.FNodes[I].FParentId, '') or
            ExternalReferenceChanged(ACandidate.FNodes[I].FSupportId, '') then
          begin
            AReason := 'A new external dependency requires a wider scope.';
            Exit;
          end;
        end
        else if ExternalReferenceChanged(ACandidate.FNodes[I].FParentId,
          ABaseline.FNodes[LBaselineIndex].FParentId) or
          ExternalReferenceChanged(ACandidate.FNodes[I].FSupportId,
          ABaseline.FNodes[LBaselineIndex].FSupportId) then
        begin
          AReason := 'Changing an external dependency requires a wider scope.';
          Exit;
        end;
        LParentIndex := LBefore.Find(ACandidate.FNodes[I].FParentId);
        if (LParentIndex >= 0) and Protected(LParentIndex) then
        begin
          AReason := 'Edit inserted or moved contents into a locked container.';
          Exit;
        end;
        LParentIndex := LBefore.Find(ACandidate.FNodes[I].FSupportId);
        if (LParentIndex >= 0) and Protected(LParentIndex) then
        begin
          AReason := 'Edit changed contents supported by a locked surface.';
          Exit;
        end;
      end;
    end;
    SetLength(LBoundaryStates, Length(ABaseline.FNodes));
    for I := 0 to High(ABaseline.FNodes) do
    begin
      if (not InCompositionScope(ABaseline, LBefore, I, AScopeId) or
        Protected(I)) and DependencyChanged(I) then
      begin
        AReason := 'A locked or outside object depends on the changed support: ' +
          ABaseline.FNodes[I].FId;
        Exit;
      end;
    end;
    LStaged := CopyDocument(ACandidate);
    LStaged.FRevision := ABaseline.FRevision + 1;
    ACommitted := LStaged;
    AReason := '';
    Result := True;
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

end.
