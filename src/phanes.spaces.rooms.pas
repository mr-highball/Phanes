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

unit phanes.spaces.rooms;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.spaces.floor.types;

{ These routines admit one room and its complete contents. The caller separately
  admits its bay, enclosure, portals and services before publishing a world. }
function ReadProgramRoom(const ADocument: TCompositionDocument; const ARoomId: String;
  out ARequest: TFloorRequest; out ALayout: TFloorLayout; out AReason: String): Boolean;
function ValidateProgramRoom(const ADocument: TCompositionDocument; const ARoomId: String;
  out AReason: String): Boolean;
function GenerateProgramRoom(const ABaseline: TCompositionDocument;
  const ARoomId, AProgramId: String; const ASeed: Cardinal;
  const AExpectedRevision: Integer; const AReplace: Boolean;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Math,
  phanes.composition.document,
  phanes.composition.contents.types,
  phanes.composition.contents.assembly,
  phanes.composition.contents.generate,
  phanes.composition.contents.validate,
  phanes.interiors.surfaces,
  phanes.spaces.programs,
  phanes.spaces.floor.validate,
  phanes.spaces.floor.generate;

function ReadProgramRoom(const ADocument: TCompositionDocument; const ARoomId: String;
  out ARequest: TFloorRequest; out ALayout: TFloorLayout; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LPlacement: TFloorPlacement;
  LRoom: Integer;
  LAsset: Integer;
  LColumns: Integer;
  LRows: Integer;
  LSpanX: Integer;
  LSpanZ: Integer;
  LX: Integer;
  LZ: Integer;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  ARequest := Default(TFloorRequest);
  ALayout := Default(TFloorLayout);
  if not ValidateComposition(ADocument, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    LRoom := LIndex.Find(ARoomId);
    AReason := 'Choose an existing room.';
    if LRoom < 0 then
    begin
      Exit;
    end;
    if not RoomProgramRequest(ADocument.FNodes[LRoom], ARequest, AReason) then
    begin
      Exit;
    end;
    LColumns := ARequest.FWidth div ARequest.FPitch;
    LRows := ARequest.FDepth div ARequest.FPitch;
    SetLength(ALayout.FFreeCells, LColumns * LRows);
    for I := 0 to High(ALayout.FFreeCells) do
    begin
      ALayout.FFreeCells[I] := True;
    end;
    for I := 0 to High(ADocument.FNodes) do
    begin
      LNode := ADocument.FNodes[I];
      if LNode.FParentId <> ARoomId then
      begin
        Continue;
      end;
      AReason := 'A room directly owns grounded, individually admitted furniture: ' + LNode.FId;
      LAsset := FloorAssetIndex(ARequest.FAssets, LNode.FAssetId);
      if (LNode.FKind <> ckObject) or (LNode.FSupportId <> '') or
        (LNode.FY <> 0) or (LAsset < 0) or
        (Abs(Double(LNode.FX)) > ARequest.FWidth) or
        (Abs(Double(LNode.FZ)) > ARequest.FDepth) then
      begin
        Exit;
      end;
      if LNode.FRole <> ARequest.FAssets[LAsset].FContent.FRole then
      begin
        Exit;
      end;
      FloorSpan(ARequest, ARequest.FAssets[LAsset], LNode.FQuarterTurn, LSpanX, LSpanZ);
      { Decode the saved millimetre pose, never infer it from the instance ID.
        IDs remain stable if a later explicit movement workflow changes poses. }
      LX := LNode.FX + LColumns * (ARequest.FPitch div 2) -
        LSpanX * (ARequest.FPitch div 2);
      LZ := LNode.FZ + LRows * (ARequest.FPitch div 2) -
        LSpanZ * (ARequest.FPitch div 2);
      if (LX < 0) or (LZ < 0) or (LX > ARequest.FWidth) or
        (LZ > ARequest.FDepth) or (LX mod ARequest.FPitch <> 0) or
        (LZ mod ARequest.FPitch <> 0) then
      begin
        AReason := 'A saved furniture pose does not fit this room program floor: ' + LNode.FId;
        Exit;
      end;
      LPlacement := Default(TFloorPlacement);
      LPlacement.FId := LNode.FId;
      LPlacement.FAssetId := LNode.FAssetId;
      LPlacement.FQuarterTurn := LNode.FQuarterTurn;
      LPlacement.FCellX := LX div ARequest.FPitch;
      LPlacement.FCellZ := LZ div ARequest.FPitch;
      if (LPlacement.FCellX + LSpanX > LColumns) or
        (LPlacement.FCellZ + LSpanZ > LRows) then
      begin
        Exit;
      end;
      LCount := Length(ALayout.FPlacements);
      SetLength(ALayout.FPlacements, LCount + 1);
      ALayout.FPlacements[LCount] := LPlacement;
      for LZ := LPlacement.FCellZ to LPlacement.FCellZ + LSpanZ - 1 do
      begin
        for LX := LPlacement.FCellX to LPlacement.FCellX + LSpanX - 1 do
        begin
          ALayout.FFreeCells[LZ * LColumns + LX] := False;
        end;
      end;
    end;
    Result := ValidateFloorLayout(ARequest, ALayout, AReason);
  finally
    LIndex.Free;
  end;
end;

function ValidateProgramRoom(const ADocument: TCompositionDocument; const ARoomId: String;
  out AReason: String): Boolean;
var
  LRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LIndex: TCompositionIndex;
  LAssemblies: TContentAssemblies;
  LAssets: TContentAssets;
  LBounds: TContentBounds;
  LFloorBounds: TFloorRectangle;
  LContentRequest: TContentRequest;
  LSupport: TContentSupport;
  LNode: TCompositionNode;
  LRoot: Integer;
  LAsset: Integer;
  LSurface: Integer;
  I: Integer;
begin
  Result := False;
  if not ReadProgramRoom(ADocument, ARoomId, LRequest, LLayout, AReason) then
  begin
    Exit;
  end;
  LAssets := RoomAssemblyAssets;
  if not ValidateContentAssets(LAssets, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  LAssemblies := TContentAssemblies.Create(ADocument, LAssets);
  try
    for I := 0 to High(LLayout.FPlacements) do
    begin
      LRoot := LIndex.Find(LLayout.FPlacements[I].FId);
      LNode := ADocument.FNodes[LRoot];
      LAsset := FloorAssetIndex(LRequest.FAssets, LNode.FAssetId);
      for LSupport in LRequest.FAssets[LAsset].FContent.FSupports do
      begin
        LSurface := LIndex.Find(LNode.FId + '.' + LSupport.FKey);
        AReason := 'A furnished room must retain each editable furniture support: ' + LNode.FId;
        if (LSurface < 0) or (ADocument.FNodes[LSurface].FParentId <> LNode.FId) then
        begin
          Exit;
        end;
      end;
      if not LAssemblies.Bounds(LNode.FId, '', LBounds, AReason) then
      begin
        Exit;
      end;
      LBounds := TransformContentBounds(LBounds, LNode.FX, LNode.FY, LNode.FZ,
        LNode.FQuarterTurn);
      if not ContentBoundsFit(LBounds, LRequest.FWidth, LRequest.FDepth, LRequest.FHeight) then
      begin
        AReason := 'The complete furniture and its contents exceed the room volume: ' + LNode.FId;
        Exit;
      end;
      LFloorBounds := FloorBounds(LRequest, LLayout.FPlacements[I], LRequest.FAssets[LAsset]);
      { Usable supports on these profiles lie within the base footprint.
        Reject any whole assembly that could intrude into the floor reservation
        used for circulation, rather than validating only the furniture mesh. }
      if (LBounds.FMinX < LFloorBounds.FMinX) or (LBounds.FMaxX > LFloorBounds.FMaxX) or
        (LBounds.FMinZ < LFloorBounds.FMinZ) or (LBounds.FMaxZ > LFloorBounds.FMaxZ) then
      begin
        AReason := 'Supported contents leave their complete floor reservation: ' + LNode.FId;
        Exit;
      end;
    end;
    for I := 0 to High(ADocument.FNodes) do
    begin
      LNode := ADocument.FNodes[I];
      if not InCompositionScope(ADocument, LIndex, I, ARoomId) then
      begin
        Continue;
      end;
      if LNode.FKind = ckSurface then
      begin
        if not SurfaceRequest(ADocument, LNode.FId, LContentRequest, AReason) or
          not ValidateContentResult(ADocument, LContentRequest, AReason) then
        begin
          Exit;
        end;
      end;
    end;
    AReason := '';
    Result := True;
  finally
    LAssemblies.Free;
    LIndex.Free;
  end;
end;

function PopulateNewSupports(var ADocument: TCompositionDocument;
  const AObjectId: String; const ASeed: Cardinal; out AReason: String): Boolean;
var
  LRequest: TContentRequest;
  LCandidate: TCompositionDocument;
  LSurfaceIds: array of String;
  LNode: TCompositionNode;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  LSurfaceIds := nil;
  for I := 0 to High(ADocument.FNodes) do
  begin
    LNode := ADocument.FNodes[I];
    if (LNode.FParentId = AObjectId) and (LNode.FKind = ckSurface) then
    begin
      LCount := Length(LSurfaceIds);
      SetLength(LSurfaceIds, LCount + 1);
      LSurfaceIds[LCount] := LNode.FId;
    end;
  end;
  for I := 0 to High(LSurfaceIds) do
  begin
    if not SurfaceRequest(ADocument, LSurfaceIds[I], LRequest, AReason) then
    begin
      Exit;
    end;
    LRequest.FSeed := Cardinal((Int64(ASeed) + I) mod 4294967296);
    for J := 0 to High(LRequest.FQuotas) do
    begin
      LCount := 0;
      if LRequest.FQuotas[J].FRole = 'book' then
      begin
        LCount := 2;
        if LSurfaceIds[I] = AObjectId + '.tier-2' then
        begin
          LCount := 0;
        end
        else if LSurfaceIds[I] = AObjectId + '.tier-4' then
        begin
          LCount := 3;
        end;
      end
      else if (LRequest.FQuotas[J].FRole = 'ornament') and
        (LSurfaceIds[I] = AObjectId + '.tier-2') then
      begin
        LCount := 1;
      end;
      LRequest.FQuotas[J].FMinimum := LCount;
      LRequest.FQuotas[J].FMaximum := LCount;
    end;
    if not GenerateContents(ADocument, LRequest, LCandidate, AReason) then
    begin
      Exit;
    end;
    ADocument := LCandidate;
  end;
  Result := True;
end;

function GenerateProgramRoom(const ABaseline: TCompositionDocument;
  const ARoomId, AProgramId: String; const ASeed: Cardinal;
  const AExpectedRevision: Integer; const AReplace: Boolean;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
var
  LRequest: TFloorRequest;
  LPreviousRequest: TFloorRequest;
  LLayout: TFloorLayout;
  LPreviousLayout: TFloorLayout;
  LCandidate: TCompositionDocument;
  LIndex: TCompositionIndex;
  LAssemblies: TContentAssemblies;
  LRemove: array of Boolean;
  LNewObjects: array of String;
  LAssets: TContentAssets;
  LNode: TCompositionNode;
  LAnchorId: String;
  LRoom: Integer;
  LRoot: Integer;
  LAsset: Integer;
  LCount: Integer;
  LRetain: Boolean;
  LX: Integer;
  LZ: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  LNewObjects := nil;
  AReason := 'The room changed before this request could be applied.';
  if AExpectedRevision <> ABaseline.FRevision then
  begin
    Exit;
  end;
  if not ValidateProgramRoom(ABaseline, ARoomId, AReason) or
    not ReadProgramRoom(ABaseline, ARoomId, LPreviousRequest, LPreviousLayout, AReason) then
  begin
    Exit;
  end;
  LCandidate := CopyDocument(ABaseline);
  LIndex := TCompositionIndex.Create(ABaseline.FNodes);
  LAssets := RoomAssemblyAssets;
  LAssemblies := TContentAssemblies.Create(ABaseline, LAssets);
  try
    LRoom := LIndex.Find(ARoomId);
    LNode := LCandidate.FNodes[LRoom];
    AReason := 'Changing the room purpose requires an explicit replacement of its contents.';
    if (LNode.FAssetId <> AProgramId) and not AReplace then
    begin
      Exit;
    end;
    if LNode.FName = RoomProgramName(LNode.FAssetId) then
    begin
      LNode.FName := RoomProgramName(AProgramId);
    end;
    LNode.FAssetId := AProgramId;
    LNode.FSeed := ASeed;
    if not RoomProgramRequest(LNode, LRequest, AReason) then
    begin
      Exit;
    end;
    LCandidate.FNodes[LRoom] := LNode;
    SetLength(LRemove, Length(ABaseline.FNodes));
    for I := 0 to High(LPreviousLayout.FPlacements) do
    begin
      LRoot := LIndex.Find(LPreviousLayout.FPlacements[I].FId);
      LRetain := not AReplace and (ABaseline.FNodes[LRoot].FLocked or
        LAssemblies.HasChildren(ABaseline.FNodes[LRoot].FId) or
        LAssemblies.HasLockedDescendant(ABaseline.FNodes[LRoot].FId));
      if LRetain then
      begin
        LCount := Length(LRequest.FFixed);
        SetLength(LRequest.FFixed, LCount + 1);
        LRequest.FFixed[LCount] := LPreviousLayout.FPlacements[I];
      end
      else
      begin
        for J := 0 to High(ABaseline.FNodes) do
        begin
          if InCompositionScope(ABaseline, LIndex, J, ABaseline.FNodes[LRoot].FId) then
          begin
            LRemove[J] := True;
          end;
        end;
      end;
    end;
    { Reserve complete generated root namespaces before solving. A preserved
      unrelated node may own a future root, shelf, surface or item identity.
      Exclude that new anchor so WFC can choose another legal arrangement. }
    for LZ := 0 to LRequest.FDepth div LRequest.FPitch - 1 do
    begin
      for LX := 0 to LRequest.FWidth div LRequest.FPitch - 1 do
      begin
        LAnchorId := ARoomId + '.item-' + IntToStr(LX) + '-' + IntToStr(LZ);
        for J := 0 to High(ABaseline.FNodes) do
        begin
          if not LRemove[J] and ((ABaseline.FNodes[J].FId = LAnchorId) or
            (Pos(LAnchorId + '.', ABaseline.FNodes[J].FId) = 1)) then
          begin
            LRequest.FUnavailableNewIds := LRequest.FUnavailableNewIds + [LAnchorId];
            Break;
          end;
        end;
      end;
    end;
    if not GenerateFloor(LRequest, LLayout, AReason) then
    begin
      Exit;
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
    { Fixed roots retain all descendant records, including display names and
      seeds. New supports are created only for newly generated furniture. }
    for I := 0 to High(LLayout.FPlacements) do
    begin
      LRoot := LIndex.Find(LLayout.FPlacements[I].FId);
      if (LRoot >= 0) and not LRemove[LRoot] then
      begin
        AReason := 'A generated fixture identity already belongs to a preserved node.';
        LRetain := False;
        for J := 0 to High(LRequest.FFixed) do
        begin
          LRetain := LRetain or (LRequest.FFixed[J].FId = LLayout.FPlacements[I].FId);
        end;
        if not LRetain then
        begin
          Exit;
        end;
        Continue;
      end;
      LAsset := FloorAssetIndex(LRequest.FAssets, LLayout.FPlacements[I].FAssetId);
      LNode := Default(TCompositionNode);
      LNode.FId := LLayout.FPlacements[I].FId;
      LNode.FParentId := ARoomId;
      LNode.FKind := ckObject;
      LNode.FAssetId := LLayout.FPlacements[I].FAssetId;
      LNode.FRole := LRequest.FAssets[LAsset].FContent.FRole;
      LNode.FName := LRequest.FAssets[LAsset].FContent.FName;
      LNode.FQuarterTurn := LLayout.FPlacements[I].FQuarterTurn;
      LNode.FSeed := ASeed;
      FloorPose(LRequest, LLayout.FPlacements[I], LRequest.FAssets[LAsset], LNode.FX, LNode.FZ);
      LCount := Length(LCandidate.FNodes);
      SetLength(LCandidate.FNodes, LCount + 1);
      LCandidate.FNodes[LCount] := LNode;
      if not EnsureContentSupports(LCandidate, LNode, LRequest.FAssets[LAsset].FContent, AReason) then
      begin
        Exit;
      end;
      LCount := Length(LNewObjects);
      SetLength(LNewObjects, LCount + 1);
      LNewObjects[LCount] := LNode.FId;
    end;
    LCandidate.FRevision := 0;
    for I := 0 to High(LNewObjects) do
    begin
      if not PopulateNewSupports(LCandidate, LNewObjects[I],
        Cardinal((Int64(ASeed) + I) mod 4294967296), AReason) then
      begin
        Exit;
      end;
    end;
    LCandidate.FRevision := ABaseline.FRevision;
    if not ValidateProgramRoom(LCandidate, ARoomId, AReason) then
    begin
      Exit;
    end;
    Result := CommitComposition(ABaseline, LCandidate, ARoomId,
      AExpectedRevision, ACommitted, AReason);
  finally
    LAssemblies.Free;
    LIndex.Free;
  end;
end;

end.
