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
unit phanes.interiors.generate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.composition.types,
  phanes.composition.contents.types;

function RoomId(const AX, AZ: Integer): String;
function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;
function GenerateInterior(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
function ValidateInteriors(const AWorld: TWorld; out AReason: String): Boolean;
function ReconcileInteriors(const ARequest: TWorldRequest; var AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Math,
  wfc,
  phanes.world.height,
  phanes.world.selection,
  phanes.structures.support,
  phanes.groundworks.assembly,
  phanes.composition.document,
  phanes.composition.contents.generate,
  phanes.composition.contents.validate,
  phanes.interiors.catalog,
  phanes.interiors.profiles,
  phanes.interiors.validate;

function RoomId(const AX, AZ: Integer): String;
begin
  Result := 'building-' + IntToStr(AX) + '-' + IntToStr(AZ) + '.studio';
end;

procedure AppendNode(var ADocument: TCompositionDocument; const ANode: TCompositionNode);
var
  LCount: Integer;
begin
  LCount := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, LCount + 1);
  ADocument.FNodes[LCount] := ANode;
end;

function NewNode(const AId, AParent, ARole: String; const AKind: TCompositionKind): TCompositionNode;
begin
  Result := Default(TCompositionNode);
  Result.FId := AId;
  Result.FParentId := AParent;
  Result.FRole := ARole;
  Result.FName := UnicodeString(AId);
  Result.FKind := AKind;
end;

function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;
begin
  Result := phanes.interiors.validate.SurfaceRequest(ADocument, ASurfaceId, ARequest, AReason);
end;

function FurnitureCompatible(const AValue, ANeighbor: String;
  const ADirection: TGraphDirection): Boolean;
begin
  Result := True;
  if (AValue = 'table') and (ADirection = gdWest) then
  begin
    Exit(ANeighbor = 'chair-west');
  end;
  if (AValue = 'table') and (ADirection = gdEast) then
  begin
    Exit(ANeighbor = 'chair-east');
  end;
  if (AValue = 'chair-west') and (ADirection = gdEast) then
  begin
    Exit(ANeighbor = 'table');
  end;
  if (AValue = 'chair-east') and (ADirection = gdWest) then
  begin
    Exit(ANeighbor = 'table');
  end;
end;

function PopulateRoom(var ADocument: TCompositionDocument; const ARoomId: String;
  const ASeed: Cardinal; out AReason: String): Boolean;
var
  LGraph: TGraph;
  LDocumentIndex: TCompositionIndex;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LValues: TGraphValues;
  LAllowed: TGraphValues;
  LValue: String;
  LOther: String;
  LDirection: TGraphDirection;
  LNode: TCompositionNode;
  LSurface: TCompositionNode;
  LAsset: TInteriorAsset;
  LContentRequest: TContentRequest;
  LNewDocument: TCompositionDocument;
  LRoot: TGraphPosition;
  LSurfaceIds: array of String;
  LX: Integer;
  LZ: Integer;
  LTier: Integer;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  LGraph := TGraph.Create;
  try
    { A four by four floor graph includes a clear aisle between the back-row
      bookcase and the table row. Furniture anchors alone would incorrectly
      treat the two metres of clear floor between them as blocked.
      Two reciprocal chair sockets belong to one table. }
    LGraph.Reshape(4, 4, 1);
    LGraph.Seed := ASeed;
    LGraph.CurrentPass := 'furniture';
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    LValues := ['empty', 'table', 'chair-west', 'chair-east', 'bookcase'];
    for LValue in LValues do
    begin
      LGraph.AddValue(LValue);
    end;
    for LValue in LValues do
    begin
      for LOther in LValues do
      begin
        for LDirection := gdNorth to gdWest do
        begin
          if FurnitureCompatible(LValue, LOther, LDirection) and
            FurnitureCompatible(LOther, LValue, InverseOfDir(LDirection)) then
          begin
            { The local predicate describes an outgoing furniture socket.
              WFC rule keys describe the incoming neighbor direction. }
            LGraph.Rules[LValue].NewRule([InverseOfDir(LDirection)], LOther);
          end;
        end;
      end;
    end;
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('worktable', ['table'], 1, 1));
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('two-seats',
      ['chair-west', 'chair-east'], 2, 2));
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('bookcase', ['bookcase'], 1, 1));
    LRoot.X := 1;
    LRoot.Y := 3;
    LRoot.Z := 0;
    LGraph.RequireConnectivity(MakeGraphConnectivityConstraint('door-and-free-floor', LRoot, [],
      [MakeGraphConnectivityValue('empty', [gdNorth, gdEast, gdSouth, gdWest])], True));
    for LZ := 0 to 3 do
    begin
      for LX := 0 to 3 do
      begin
        LAllowed := ['empty'];
        if LZ = 0 then
        begin
          LAllowed := LAllowed + ['bookcase'];
        end
        else if LZ = 2 then
        begin
          if (LX = 1) or (LX = 2) then
          begin
            LAllowed := LAllowed + ['table'];
          end;
          if LX < 3 then
          begin
            LAllowed := LAllowed + ['chair-west'];
          end;
          if LX > 0 then
          begin
            LAllowed := LAllowed + ['chair-east'];
          end;
        end;
        LGraph.SetAllowedValues(LX, LZ, 0, LAllowed);
      end;
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 512;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'The interior did not resolve within this search allowance.';
      Exit;
    end;
    for LZ := 0 to 3 do
    begin
      for LX := 0 to 3 do
      begin
        LValue := LGraph.Entry[LX, LZ, 0].Value;
        if LValue = 'empty' then
        begin
          Continue;
        end;
        { Stable furniture IDs refer to physical anchor groups, independently
          of the extra traversable cells used by the local floor solver. }
        LNode := NewNode(ARoomId + '.furniture-' + IntToStr((LZ div 2) * 4 + LX),
          ARoomId, LValue, ckObject);
        LNode.FX := -3300 + LX * 2200;
        LNode.FZ := -3200 + (LZ div 2) * 2500;
        LNode.FSeed := ASeed;
        if LValue = 'table' then
        begin
          LNode.FAssetId := 'phanes.table.oak.v1';
        end
        else if LValue = 'bookcase' then
        begin
          LNode.FAssetId := 'phanes.shelf.oak.v1';
        end
        else
        begin
          LNode.FAssetId := 'phanes.chair.sage.v1';
          LNode.FRole := 'chair';
          if LValue = 'chair-west' then
          begin
            Inc(LNode.FX, 950);
            LNode.FQuarterTurn := 1;
          end
          else
          begin
            Dec(LNode.FX, 950);
            LNode.FQuarterTurn := 3;
          end;
        end;
        InteriorAsset(LNode.FAssetId, LAsset);
        LNode.FName := LAsset.FName;
        AppendNode(ADocument, LNode);
        if LValue = 'bookcase' then
        begin
          for LTier := 1 to 4 do
          begin
            LSurface := NewNode(LNode.FId + '.tier-' + IntToStr(LTier),
              LNode.FId, 'shelf-tier', ckSurface);
            LSurface.FName := 'Shelf ' + UnicodeString(IntToStr(LTier));
            LSurface.FAssetId := 'phanes.support.shelf.v1';
            LSurface.FY := 260 + (LTier - 1) * 480;
            AppendNode(ADocument, LSurface);
            LCount := Length(LSurfaceIds);
            SetLength(LSurfaceIds, LCount + 1);
            LSurfaceIds[LCount] := LSurface.FId;
          end;
        end
        else if LValue = 'table' then
        begin
          LSurface := NewNode(LNode.FId + '.top', LNode.FId, 'tabletop', ckSurface);
          LSurface.FName := 'Tabletop';
          LSurface.FAssetId := 'phanes.support.table.v1';
          LSurface.FY := 750;
          AppendNode(ADocument, LSurface);
          LCount := Length(LSurfaceIds);
          SetLength(LSurfaceIds, LCount + 1);
          LSurfaceIds[LCount] := LSurface.FId;
        end;
      end;
    end;
    for I := 0 to High(LSurfaceIds) do
    begin
      if not SurfaceRequest(ADocument, LSurfaceIds[I], LContentRequest, AReason) then
      begin
        Exit;
      end;
      LContentRequest.FSeed := Cardinal((Int64(ASeed) + I) mod 4294967296);
      if Pos('.tier-', LSurfaceIds[I]) > 0 then
      begin
        LTier := StrToInt(Copy(LSurfaceIds[I], Length(LSurfaceIds[I]), 1));
        LCount := 2;
        if LTier = 3 then
        begin
          LCount := 1;
        end
        else if LTier = 4 then
        begin
          LCount := 3;
        end;
        if LTier = 2 then
        begin
          LContentRequest.FQuotas[1].FMinimum := 1;
          LContentRequest.FQuotas[1].FMaximum := 1;
        end
        else
        begin
          LContentRequest.FQuotas[0].FMinimum := LCount;
          LContentRequest.FQuotas[0].FMaximum := LCount;
        end;
      end
      else
      begin
        LContentRequest.FQuotas[2].FMinimum := 2;
        LContentRequest.FQuotas[2].FMaximum := 2;
        LContentRequest.FQuotas[3].FMinimum := 2;
        LContentRequest.FQuotas[3].FMaximum := 2;
      end;
      if not GenerateContents(ADocument, LContentRequest, LNewDocument, AReason) then
      begin
        Exit;
      end;
      ADocument := LNewDocument;
    end;
    { Each plate owns its actual inner support. Populate those local graphs
      after the tabletop graph, retaining every plate and cutlery identity. }
    LSurfaceIds := nil;
    LDocumentIndex := TCompositionIndex.Create(ADocument.FNodes);
    try
      for I := 0 to High(ADocument.FNodes) do
      begin
        if (ADocument.FNodes[I].FAssetId = 'phanes.support.plate.v1') and
          InCompositionScope(ADocument, LDocumentIndex, I, ARoomId) then
        begin
          LCount := Length(LSurfaceIds);
          SetLength(LSurfaceIds, LCount + 1);
          LSurfaceIds[LCount] := ADocument.FNodes[I].FId;
        end;
      end;
    finally
      LDocumentIndex.Free;
    end;
    for I := 0 to High(LSurfaceIds) do
    begin
      if not SurfaceRequest(ADocument, LSurfaceIds[I], LContentRequest, AReason) then
      begin
        Exit;
      end;
      LContentRequest.FSeed := Cardinal((Int64(ASeed) + 100 + I) mod 4294967296);
      for LCount := 4 to 6 do
      begin
        LContentRequest.FQuotas[LCount].FMinimum := 1;
        LContentRequest.FQuotas[LCount].FMaximum := 1;
      end;
      if not GenerateContents(ADocument, LContentRequest, LNewDocument, AReason) then
      begin
        Exit;
      end;
      ADocument := LNewDocument;
    end;
    Result := True;
  finally
    LGraph.Free;
  end;
end;

function ValidateInteriors(const AWorld: TWorld; out AReason: String): Boolean;
begin
  Result := ValidateGroundworks(AWorld, AReason);
end;

function ReconcileInteriors(const ARequest: TWorldRequest; var AWorld: TWorld;
  out AReason: String): Boolean;
var
  LCandidate: TCompositionDocument;
  LCommitted: TCompositionDocument;
  LIndex: TCompositionIndex;
  LRemove: array of Boolean;
  LX: Integer;
  LZ: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  LCandidate := CopyDocument(ARequest.FPrevious.FComposition);
  LIndex := TCompositionIndex.Create(LCandidate.FNodes);
  try
    SetLength(LRemove, Length(LCandidate.FNodes));
    for I := 0 to High(LCandidate.FNodes) do
    begin
      if (LCandidate.FNodes[I].FRole = 'plot') and (ARequest.FOperation = 'clear') then
      begin
        LX := (LCandidate.FNodes[I].FX + AWorld.FSize * 8000) div 16000 - 1;
        LZ := (LCandidate.FNodes[I].FZ + AWorld.FSize * 8000) div 16000 - 1;
        LCount := SelectedRegionCount(ARequest, LX, LZ, 2, 2);
        if LCount = 0 then
        begin
          Continue;
        end;
        if LCount <> 4 then
        begin
          AReason := 'Select the complete 2 x 2 plot to clear its supports.';
          Exit;
        end;
        for J := 0 to High(LCandidate.FNodes) do
        begin
          if InCompositionScope(LCandidate, LIndex, J, LCandidate.FNodes[I].FId) then
          begin
            LRemove[J] := True;
          end;
        end;
        Continue;
      end;
      if (LCandidate.FNodes[I].FKind <> ckContainer) or
        (LCandidate.FNodes[I].FRole <> 'building') or
        (LCandidate.FNodes[I].FParentId <> 'world') then
      begin
        Continue;
      end;
      LX := Floor(LCandidate.FNodes[I].FX / 16000 + AWorld.FSize / 2);
      LZ := Floor(LCandidate.FNodes[I].FZ / 16000 + AWorld.FSize / 2);
      if AWorld.FLayers[3][LZ * AWorld.FSize + LX] = LCandidate.FNodes[I].FAssetId then
      begin
        Continue;
      end;
      if not SelectedCell(ARequest, 1, LX, LZ) then
      begin
        AReason := 'A regional edit cannot remove a furnished building outside its selection.';
        Exit;
      end;
      { A removed building takes its owned interior with it. Commit rejects
        protected descendants; the editor retains the full world for undo. }
      for J := 0 to High(LCandidate.FNodes) do
      begin
        if InCompositionScope(LCandidate, LIndex, J, LCandidate.FNodes[I].FId) then
        begin
          LRemove[J] := True;
        end;
      end;
    end;
    LCount := 0;
    for I := 0 to High(LCandidate.FNodes) do
    begin
      if not LRemove[I] then
      begin
        LCandidate.FNodes[LCount] := LCandidate.FNodes[I];
        Inc(LCount);
      end;
    end;
    SetLength(LCandidate.FNodes, LCount);
    if LCount = Length(ARequest.FPrevious.FComposition.FNodes) then
    begin
      AWorld.FComposition := LCandidate;
      Exit(True);
    end;
    if not CommitComposition(ARequest.FPrevious.FComposition, LCandidate, 'world',
      ARequest.FPrevious.FComposition.FRevision, LCommitted, AReason) then
    begin
      Exit;
    end;
    AWorld.FComposition := LCommitted;
    Result := True;
  finally
    LIndex.Free;
  end;
end;


function GenerateInterior(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
var
  LDocument: TCompositionDocument;
  LCommitted: TCompositionDocument;
  LNode: TCompositionNode;
  LRoom: TCompositionNode;
  LIndex: TCompositionIndex;
  LScopeId: String;
  LContents: TContentRequest;
  LSurfaceId: String;
  LSelected: Integer;
  LCell: Integer;
  LSlot: Integer;
  LExisting: Integer;
  LPreviousCount: Integer;
  LProtectedCount: Integer;
  LAllowed: TContentNames;
  LMatched: Boolean;
  LAssetIndex: Integer;
  LProfile: TBuildingInterior;
  I: Integer;
  J: Integer;
begin
  Result := False;
  AWorld := Default(TWorld);
  LDocument := CopyDocument(ARequest.FPrevious.FComposition);
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    if ARequest.FOperation = 'create-interior' then
    begin
      AReason := 'Select one house or cabin to create its interior.';
      LSelected := LIndex.Find(ARequest.FObjectId);
      LScopeId := 'world';
      if ARequest.FObjectId <> '' then
      begin
        if (LSelected < 0) or
          (SupportedBuildingOwner(LDocument, LIndex, LSelected) <> ARequest.FObjectId) then
        begin
          Exit;
        end;
        LNode := LDocument.FNodes[LSelected];
        if not BuildingInterior(LNode.FAssetId, LProfile) then
        begin
          Exit;
        end;
        LScopeId := LNode.FId;
      end
      else
      begin
        if (ARequest.FWidth <> 1) or (ARequest.FDepth <> 1) then
        begin
          Exit;
        end;
        LCell := ARequest.FZ * ARequest.FSize + ARequest.FX;
        if not BuildingInterior(ARequest.FPrevious.FLayers[3][LCell], LProfile) then
        begin
          Exit;
        end;
        LNode := NewNode('building-' + IntToStr(ARequest.FX) + '-' + IntToStr(ARequest.FZ),
          'world', 'building', ckContainer);
        LNode.FName := UnicodeString(LProfile.FName);
        LNode.FAssetId := ARequest.FPrevious.FLayers[3][LCell];
        LNode.FX := Round((ARequest.FX + 0.5 - ARequest.FSize / 2) * 16000);
        LNode.FZ := Round((ARequest.FZ + 0.5 - ARequest.FSize / 2) * 16000);
        LNode.FY := Round(WorldBuildingDatum(ARequest.FPrevious, ARequest.FX, ARequest.FZ) * 1000);
        AppendNode(LDocument, LNode);
      end;
      if LIndex.Find(LNode.FId + '.studio') >= 0 then
      begin
        AReason := 'This building already has an interior.';
        Exit;
      end;
      if LIndex.Find(LNode.FId + '.plan') >= 0 then
      begin
        AReason := 'This building already has a room plan. Open its rooms to furnish them.';
        Exit;
      end;
      LRoom := NewNode(LNode.FId + '.studio', LNode.FId, 'studio', ckContainer);
      LRoom.FName := 'Studio';
      LRoom.FAssetId := LProfile.FRoomAssetId;
      LRoom.FY := LProfile.FFloor;
      AppendNode(LDocument, LRoom);
      { Private contents solves use private revisions; only the final atomic
        building transaction consumes the public world's next revision. }
      LDocument.FRevision := 0;
      if not PopulateRoom(LDocument, LRoom.FId, ARequest.FSeed, AReason) then
      begin
        Exit;
      end;
      LDocument.FRevision := ARequest.FPrevious.FComposition.FRevision;
      if not CommitComposition(ARequest.FPrevious.FComposition, LDocument, LScopeId,
        LDocument.FRevision, LCommitted, AReason) then
      begin
        Exit;
      end;
    end
    else
    begin
      LSelected := LIndex.Find(ARequest.FObjectId);
      AReason := 'Select an existing interior item or support surface.';
      if LSelected < 0 then
      begin
        Exit;
      end;
      LSurfaceId := ARequest.FObjectId;
      if LDocument.FNodes[LSelected].FKind = ckObject then
      begin
        LSurfaceId := LDocument.FNodes[LSelected].FSupportId;
      end;
      if not SurfaceRequest(LDocument, LSurfaceId, LContents, AReason) then
      begin
        Exit;
      end;
      LContents.FScopeId := ARequest.FObjectId;
      LContents.FSeed := ARequest.FSeed;
      if ARequest.FContentAsset <> '' then
      begin
        LSlot := ContentSlotIndex(LContents.FSlots, ARequest.FObjectId);
        if LSlot < 0 then
        begin
          AReason := 'Choose an individual item before choosing its appearance.';
          Exit;
        end;
        LContents.FSlots[LSlot].FAllowedAssets := [ARequest.FContentAsset];
        LAssetIndex := ContentAssetIndex(LContents.FAssets, ARequest.FContentAsset);
        if LAssetIndex < 0 then
        begin
          AReason := 'Choose an admitted item.';
          Exit;
        end;
        if LContents.FAssets[LAssetIndex].FRole <> LDocument.FNodes[LSelected].FRole then
        begin
          for I := 0 to High(LContents.FQuotas) do
          begin
            if LContents.FQuotas[I].FRole = LDocument.FNodes[LSelected].FRole then
            begin
              Dec(LContents.FQuotas[I].FMinimum);
              Dec(LContents.FQuotas[I].FMaximum);
            end;
            if LContents.FQuotas[I].FRole = LContents.FAssets[LAssetIndex].FRole then
            begin
              Inc(LContents.FQuotas[I].FMinimum);
              Inc(LContents.FQuotas[I].FMaximum);
            end;
          end;
        end;
      end;
      if (ARequest.FContentAsset = '') and
        (LDocument.FNodes[LSelected].FKind = ckObject) then
      begin
        LSlot := ContentSlotIndex(LContents.FSlots, ARequest.FObjectId);
        LAllowed := nil;
        for I := 0 to High(LContents.FAssets) do
        begin
          if (LContents.FAssets[I].FRole = LDocument.FNodes[LSelected].FRole) and
            (LContents.FAssets[I].FId <> LDocument.FNodes[LSelected].FAssetId) then
          begin
            LAllowed := LAllowed + [LContents.FAssets[I].FId];
          end;
        end;
        if (LSlot < 0) or (Length(LAllowed) = 0) then
        begin
          AReason := 'This item has no other admitted appearance yet.';
          Exit;
        end;
        LContents.FSlots[LSlot].FAllowedAssets := LAllowed;
      end;
      if ARequest.FContentCount >= 0 then
      begin
        if LDocument.FNodes[LSelected].FKind <> ckSurface then
        begin
          AReason := 'Choose a whole surface to change its item counts.';
          Exit;
        end;
        LMatched := False;
        for I := 0 to High(LContents.FQuotas) do
        begin
          if LContents.FQuotas[I].FRole = ARequest.FContentRole then
          begin
            LMatched := True;
            LPreviousCount := LContents.FQuotas[I].FMinimum;
            if ARequest.FContentCount < LContents.FQuotas[I].FMinimum then
            begin
              LContents.FRemovableAssemblyRoles := [ARequest.FContentRole];
            end;
            LContents.FQuotas[I].FMinimum := ARequest.FContentCount;
            LContents.FQuotas[I].FMaximum := ARequest.FContentCount;
          end;
        end;
        if not LMatched then
        begin
          AReason := 'Choose an admitted contents category.';
          Exit;
        end;
        LProtectedCount := 0;
        for I := 0 to High(LContents.FSlots) do
        begin
          LExisting := LIndex.Find(LContents.FSlots[I].FObjectId);
          if (LExisting < 0) or
            (LDocument.FNodes[LExisting].FRole <> ARequest.FContentRole) then
          begin
            Continue;
          end;
          for J := 0 to High(LDocument.FNodes) do
          begin
            if LDocument.FNodes[J].FLocked and
              InCompositionScope(LDocument, LIndex, J, LDocument.FNodes[LExisting].FId) then
            begin
              Inc(LProtectedCount);
              Break;
            end;
          end;
        end;
        if ARequest.FContentCount < LProtectedCount then
        begin
          AReason := 'Keep at least ' + IntToStr(LProtectedCount) + ' ' +
            ARequest.FContentRole + ' item(s): an item or its contents is locked. ' +
            'Unlock it before reducing this count.';
          Exit;
        end;
        { A count action changes occupancy, not appearances. Keep existing
          items in their slots; only the requested category may lose items
          when its count is explicitly reduced. }
        for I := 0 to High(LContents.FSlots) do
        begin
          LExisting := LIndex.Find(LContents.FSlots[I].FObjectId);
          if LExisting < 0 then
          begin
            Continue;
          end;
          LContents.FSlots[I].FAllowedAssets := [LDocument.FNodes[LExisting].FAssetId];
          LContents.FSlots[I].FAllowEmpty :=
            (LDocument.FNodes[LExisting].FRole = ARequest.FContentRole) and
            (ARequest.FContentCount < LPreviousCount);
        end;
      end;
      if not GenerateContents(LDocument, LContents, LCommitted, AReason) then
      begin
        Exit;
      end;
    end;
    AWorld := ARequest.FPrevious;
    AWorld.FSeed := ARequest.FSeed;
    AWorld.FComposition := LCommitted;
    Result := ValidateInteriors(AWorld, AReason);
  finally
    LIndex.Free;
  end;
end;

end.
