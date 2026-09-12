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
unit phanes.composition.contents.generate;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.contents.types;

function GenerateContents(const ABaseline: TCompositionDocument;
  const ARequest: TContentRequest; var ACommitted: TCompositionDocument;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  wfc,
  phanes.composition.document,
  phanes.composition.contents.assembly,
  phanes.composition.contents.validate;

function GenerateContents(const ABaseline: TCompositionDocument;
  const ARequest: TContentRequest; var ACommitted: TCompositionDocument;
  out AReason: String): Boolean;
var
  LGraph: TGraph;
  LIndex: TCompositionIndex;
  LAssemblies: TContentAssemblies;
  LBounds: TContentBounds;
  LHasChildren: Boolean;
  LLockedChild: Boolean;
  LPoseChanges: Boolean;
  LCandidateReason: String;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LRoles: TGraphValues;
  LLooks: TGraphValues;
  LAllowedRoles: TGraphValues;
  LAllowedLooks: TGraphValues;
  LValue: String;
  LOther: String;
  LRole: String;
  LChosen: String;
  LEditable: array of Boolean;
  LProtectedStates: array of Byte;
  LRemove: array of Boolean;
  LCandidate: TCompositionDocument;
  LNode: TCompositionNode;
  LSlot: TContentSlot;
  LAsset: TContentAsset;
  LSurface: Integer;
  LOld: Integer;
  LAssetIndex: Integer;
  LOldAssetIndex: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;

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
      LDependency := LIndex.Find(ABaseline.FNodes[ANode].FParentId);
      Result := (LDependency >= 0) and Protected(LDependency);
    end;
    if not Result then
    begin
      LDependency := LIndex.Find(ABaseline.FNodes[ANode].FSupportId);
      Result := (LDependency >= 0) and Protected(LDependency);
    end;
    LProtectedStates[ANode] := 1;
    if Result then
    begin
      LProtectedStates[ANode] := 2;
    end;
  end;

  function SupportsAvoidRequestedRoots(const AObjectId: String;
    const AAsset: TContentAsset): Boolean;
  var
    LSupport: TContentSupport;
  begin
    { Reserve all requested root identities before choosing appearances. A
      support key is a single segment, so supports belonging to distinct
      roots cannot collide with each other, but may collide with a root. }
    for LSupport in AAsset.FSupports do
    begin
      if ContentSlotIndex(ARequest.FSlots, AObjectId + '.' + LSupport.FKey) >= 0 then
      begin
        Exit(False);
      end;
    end;
    Result := True;
  end;

  procedure AddUnique(var AValues: TGraphValues; const AValue: String);
  var
    LExisting: String;
  begin
    for LExisting in AValues do
    begin
      if LExisting = AValue then
      begin
        Exit;
      end;
    end;
    AValues := AValues + [AValue];
  end;

begin
  Result := False;
  if not ValidateContentRequest(ABaseline, ARequest, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ABaseline.FNodes);
  LGraph := TGraph.Create;
  LAssemblies := nil;
  try
    LAssemblies := TContentAssemblies.Create(ABaseline, ARequest.FAssets);
    LSurface := LIndex.Find(ARequest.FSurfaceId);
    SetLength(LEditable, Length(ARequest.FSlots));
    SetLength(LProtectedStates, Length(ABaseline.FNodes));
    SetLength(LRemove, Length(ABaseline.FNodes));
    LRoles := ['vacant'];
    LLooks := ['vacant'];
    for I := 0 to High(ARequest.FAssets) do
    begin
      LAsset := ARequest.FAssets[I];
      AddUnique(LRoles, 'role:' + LAsset.FRole);
      LLooks := LLooks + ['asset:' + LAsset.FId];
    end;
    for I := 0 to High(ARequest.FQuotas) do
    begin
      AddUnique(LRoles, 'role:' + ARequest.FQuotas[I].FRole);
    end;
    { Each graph cell is one explicit object anchor, not a footprint voxel.
      These slots already have disjoint usable volumes. Their linear ordering is
      an index only, so all neighbours are compatible. Physical placement comes
      from the reviewed local slots, not from imaginary adjacency in this line. }
    LGraph.Seed := ARequest.FSeed;
    LGraph.Reshape(Length(ARequest.FSlots), 1, 1);
    LGraph.WrapNeighbors := False;
    LGraph.CurrentPass := 'contents';
    LGraph.PassMode := gpmOverlay;
    for LValue in LRoles do
    begin
      LGraph.AddValue(LValue);
    end;
    for LValue in LRoles do
    begin
      for LOther in LRoles do
      begin
        LGraph.Rules[LValue].NewRule([gdEast, gdWest], LOther);
      end;
    end;
    for I := 0 to High(ARequest.FQuotas) do
    begin
      LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('count-' + IntToStr(I),
        ['role:' + ARequest.FQuotas[I].FRole], ARequest.FQuotas[I].FMinimum,
        ARequest.FQuotas[I].FMaximum));
    end;
    LGraph.SwitchToPass('appearance');
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('vacant').RequireMappedFromPass('contents',
      MakeGraphPassCellQuery(['vacant']));
    for I := 0 to High(ARequest.FAssets) do
    begin
      LAsset := ARequest.FAssets[I];
      LGraph.AddValue('asset:' + LAsset.FId).RequireMappedFromPass('contents',
        MakeGraphPassCellQuery(['role:' + LAsset.FRole]));
    end;
    for LValue in LLooks do
    begin
      for LOther in LLooks do
      begin
        LGraph.Rules[LValue].NewRule([gdEast, gdWest], LOther);
      end;
    end;
    for I := 0 to High(ARequest.FSlots) do
    begin
      LSlot := ARequest.FSlots[I];
      LOld := LIndex.Find(LSlot.FObjectId);
      LHasChildren := (LOld >= 0) and LAssemblies.HasChildren(LSlot.FObjectId);
      LLockedChild := LHasChildren and LAssemblies.HasLockedDescendant(LSlot.FObjectId);
      LPoseChanges := (LOld >= 0) and ((ABaseline.FNodes[LOld].FX <> LSlot.FX) or
        (ABaseline.FNodes[LOld].FY <> 0) or (ABaseline.FNodes[LOld].FZ <> LSlot.FZ) or
        (ABaseline.FNodes[LOld].FQuarterTurn <> LSlot.FQuarterTurn));
      if LOld >= 0 then
      begin
        LEditable[I] := InCompositionScope(ABaseline, LIndex, LOld, ARequest.FScopeId) and
          not Protected(LOld);
      end
      else
      begin
        LEditable[I] := InCompositionScope(ABaseline, LIndex, LSurface, ARequest.FScopeId) and
          not Protected(LSurface);
      end;
      LAllowedRoles := nil;
      LAllowedLooks := nil;
      if LSlot.FAllowEmpty and (LSlot.FObjectId <> ARequest.FScopeId) and
        (not LHasChildren or (not LLockedChild and
        ContentRoleAllowed(ARequest.FRemovableAssemblyRoles, ABaseline.FNodes[LOld].FRole))) then
      begin
        LAllowedRoles := ['vacant'];
        LAllowedLooks := ['vacant'];
      end;
      for J := 0 to High(ARequest.FAssets) do
      begin
        LAsset := ARequest.FAssets[J];
        if not SupportsAvoidRequestedRoots(LSlot.FObjectId, LAsset) or
          not ContentSupportsAvailable(ABaseline, LSlot.FObjectId, LAsset, LCandidateReason) then
        begin
          Continue;
        end;
        if LHasChildren then
        begin
          if (LPoseChanges and (LLockedChild or not ARequest.FAllowAssemblyMoves)) or
            (LLockedChild and (LAsset.FId <> ABaseline.FNodes[LOld].FAssetId)) then
          begin
            Continue;
          end;
          if not LAssemblies.Bounds(LSlot.FObjectId, LAsset.FId,
            LBounds, LCandidateReason) then
          begin
            Continue;
          end;
          LBounds := TransformContentBounds(LBounds, 0, 0, 0, LSlot.FQuarterTurn);
          if not ContentBoundsFit(LBounds, LSlot.FWidth, LSlot.FDepth, LSlot.FHeight) then
          begin
            Continue;
          end;
        end;
        LWidth := LAsset.FWidth;
        LDepth := LAsset.FDepth;
        if Odd(LSlot.FQuarterTurn) then
        begin
          LWidth := LAsset.FDepth;
          LDepth := LAsset.FWidth;
        end;
        if ContentRoleAllowed(LSlot.FAllowedRoles, LAsset.FRole) and
          ((Length(LSlot.FAllowedAssets) = 0) or
          ContentRoleAllowed(LSlot.FAllowedAssets, LAsset.FId)) and
          (LWidth <= LSlot.FWidth) and (LDepth <= LSlot.FDepth) and
          (LAsset.FHeight <= LSlot.FHeight) then
        begin
          AddUnique(LAllowedRoles, 'role:' + LAsset.FRole);
          LAllowedLooks := LAllowedLooks + ['asset:' + LAsset.FId];
        end;
      end;
      if not LEditable[I] then
      begin
        LChosen := 'vacant';
        LRole := 'vacant';
        if LOld >= 0 then
        begin
          LChosen := 'asset:' + ABaseline.FNodes[LOld].FAssetId;
          LRole := 'role:' + ABaseline.FNodes[LOld].FRole;
        end;
        if not ContentRoleAllowed(LAllowedLooks, LChosen) or
          not ContentRoleAllowed(LAllowedRoles, LRole) then
        begin
          AReason := 'A preserved item conflicts with the requested contents: ' + LSlot.FObjectId;
          Exit;
        end;
        LAllowedRoles := [LRole];
        LAllowedLooks := [LChosen];
      end;
      if (Length(LAllowedRoles) = 0) or (Length(LAllowedLooks) = 0) then
      begin
        AReason := 'No admitted item fits the usable space at ' + LSlot.FObjectId;
        if LHasChildren then
        begin
          AReason := 'No compatible choice preserves the supported contents, placement and ' +
            'locks at ' + LSlot.FObjectId;
        end;
        Exit;
      end;
      LGraph.PassGraph[0].SetAllowedValues(I, 0, 0, LAllowedRoles);
      LGraph.PassGraph[1].SetAllowedValues(I, 0, 0, LAllowedLooks);
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 2048;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'These contents did not resolve within the search allowance. ' +
        'Try fewer required items or a larger usable space.';
      Exit;
    end;
    LCandidate := CopyDocument(ABaseline);
    for I := 0 to High(ARequest.FSlots) do
    begin
      if not LEditable[I] then
      begin
        Continue;
      end;
      LSlot := ARequest.FSlots[I];
      LOld := LIndex.Find(LSlot.FObjectId);
      LChosen := LGraph.PassGraph[1].Entry[I, 0, 0].Value;
      if LChosen = 'vacant' then
      begin
        if LOld >= 0 then
        begin
          for J := 0 to High(ABaseline.FNodes) do
          begin
            if InCompositionScope(ABaseline, LIndex, J, LSlot.FObjectId) then
            begin
              LRemove[J] := True;
            end;
          end;
        end;
        Continue;
      end;
      LAssetIndex := ContentAssetIndex(ARequest.FAssets, Copy(LChosen, 7, Length(LChosen)));
      if LAssetIndex < 0 then
      begin
        AReason := 'Unknown content choice returned by the solver.';
        Exit;
      end;
      LAsset := ARequest.FAssets[LAssetIndex];
      LNode := Default(TCompositionNode);
      if LOld >= 0 then
      begin
        LNode := ABaseline.FNodes[LOld];
        LOldAssetIndex := ContentAssetIndex(ARequest.FAssets, LNode.FAssetId);
        if (LOldAssetIndex >= 0) and
          (LNode.FName = ARequest.FAssets[LOldAssetIndex].FName) then
        begin
          LNode.FName := LAsset.FName;
        end;
      end
      else
      begin
        LNode.FId := LSlot.FObjectId;
        LNode.FName := LAsset.FName;
        LNode.FKind := ckObject;
        LNode.FParentId := ARequest.FSurfaceId;
        LNode.FSupportId := ARequest.FSurfaceId;
      end;
      if (LNode.FAssetId <> LAsset.FId) or (LNode.FX <> LSlot.FX) or
        (LNode.FZ <> LSlot.FZ) or (LNode.FY <> 0) or
        (LNode.FQuarterTurn <> LSlot.FQuarterTurn) then
      begin
        LNode.FSeed := ARequest.FSeed;
      end;
      LNode.FAssetId := LAsset.FId;
      LNode.FRole := LAsset.FRole;
      LNode.FX := LSlot.FX;
      LNode.FY := 0;
      LNode.FZ := LSlot.FZ;
      LNode.FQuarterTurn := LSlot.FQuarterTurn;
      if LOld >= 0 then
      begin
        LCandidate.FNodes[LOld] := LNode;
      end
      else
      begin
        LCount := Length(LCandidate.FNodes);
        SetLength(LCandidate.FNodes, LCount + 1);
        LCandidate.FNodes[LCount] := LNode;
      end;
      if not EnsureContentSupports(LCandidate, LNode, LAsset, AReason) then
      begin
        Exit;
      end;
    end;
    J := 0;
    for I := 0 to High(LCandidate.FNodes) do
    begin
      if (I < Length(LRemove)) and LRemove[I] then
      begin
        Continue;
      end;
      LCandidate.FNodes[J] := LCandidate.FNodes[I];
      Inc(J);
    end;
    SetLength(LCandidate.FNodes, J);
    Result := ValidateContentResult(LCandidate, ARequest, AReason) and
      CommitComposition(ABaseline, LCandidate, ARequest.FScopeId,
        ARequest.FExpectedRevision, ACommitted, AReason);
  finally
    LAssemblies.Free;
    LGraph.Free;
    LIndex.Free;
  end;
end;

end.
