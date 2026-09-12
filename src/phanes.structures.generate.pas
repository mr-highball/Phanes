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

unit phanes.structures.generate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function EditSupportedBuilding(const ARequest: TWorldRequest;
  out AWorld: TWorld; out AReason: String): Boolean;

implementation

uses
  phanes.composition.types,
  phanes.composition.document,
  phanes.groundworks.assembly,
  phanes.structures.support;

function EditSupportedBuilding(const ARequest: TWorldRequest;
  out AWorld: TWorld; out AReason: String): Boolean;
var
  LCandidate: TWorld;
  LCommitted: TCompositionDocument;
  LIndex: TCompositionIndex;
  LAssembly: TGroundworkAssembly;
  LProfile: TSupportedBuilding;
  LPreviousProfile: TSupportedBuilding;
  LNode: TCompositionNode;
  LPlotId: String;
  LBuildingId: String;
  LAt: Integer;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  AWorld := Default(TWorld);
  if not ValidateGroundworks(ARequest.FPrevious, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(ARequest.FPrevious.FComposition.FNodes);
  try
    LAt := LIndex.Find(ARequest.FObjectId);
    LPlotId := GroundworkOwner(ARequest.FPrevious.FComposition, LIndex, LAt);
    if (LPlotId = '') or
      ((ARequest.FObjectId <> LPlotId) and (ARequest.FObjectId <> LPlotId + '.deck') and
      (ARequest.FObjectId <> LPlotId + '.deck.building')) then
    begin
      AReason := 'Choose the plot or its building to place a supported shell.';
      Exit;
    end;
    if not ReadGroundwork(ARequest.FPrevious, LPlotId, LAssembly, AReason) then
    begin
      Exit;
    end;
    LBuildingId := LPlotId + '.deck.building';
    LAt := LIndex.Find(LBuildingId);
    LCandidate := ARequest.FPrevious;
    LCandidate.FComposition := CopyDocument(ARequest.FPrevious.FComposition);
    if ARequest.FOperation = 'remove-building' then
    begin
      if LAt < 0 then
      begin
        AReason := 'This plot has no building to remove.';
        Exit;
      end;
      LCount := 0;
      for I := 0 to High(ARequest.FPrevious.FComposition.FNodes) do
      begin
        if not InCompositionScope(ARequest.FPrevious.FComposition, LIndex, I, LBuildingId) then
        begin
          LCandidate.FComposition.FNodes[LCount] := ARequest.FPrevious.FComposition.FNodes[I];
          Inc(LCount);
        end;
      end;
      SetLength(LCandidate.FComposition.FNodes, LCount);
    end
    else if ARequest.FOperation = 'place-building' then
    begin
      if not SupportedBuilding(ARequest.FBuildingAsset, LProfile) then
      begin
        AReason := 'Choose an admitted building for this deck.';
        Exit;
      end;
      if LAt >= 0 then
      begin
        LNode := LCandidate.FComposition.FNodes[LAt];
        if LNode.FAssetId = LProfile.FAssetId then
        begin
          AReason := 'This building is already placed.';
          Exit;
        end;
        if SupportedBuilding(LNode.FAssetId, LPreviousProfile) and
          ((LNode.FName = '') or (LNode.FName = UnicodeString(LPreviousProfile.FName))) then
        begin
          LNode.FName := UnicodeString(LProfile.FName);
        end;
      end
      else
      begin
        LAt := Length(LCandidate.FComposition.FNodes);
        SetLength(LCandidate.FComposition.FNodes, LAt + 1);
        LNode := Default(TCompositionNode);
        LNode.FId := LBuildingId;
        LNode.FParentId := LPlotId + '.deck';
        LNode.FSupportId := LNode.FParentId;
        LNode.FKind := ckContainer;
        LNode.FRole := 'building';
        LNode.FName := UnicodeString(LProfile.FName);
        LNode.FQuarterTurn := LAssembly.FGeometry.FQuarterTurn;
      end;
      LNode.FAssetId := LProfile.FAssetId;
      LNode.FSeed := ARequest.FSeed;
      LCandidate.FComposition.FNodes[LAt] := LNode;
    end
    else
    begin
      AReason := 'Choose placement or removal for a supported building.';
      Exit;
    end;
    { Full candidate admission also rejects incompatible retained rooms. Commit
      enforces all ancestor, support and descendant locks before publishing once. }
    if not ValidateGroundworks(LCandidate, AReason) or
      not CommitComposition(ARequest.FPrevious.FComposition, LCandidate.FComposition,
        LPlotId + '.deck', ARequest.FPrevious.FComposition.FRevision, LCommitted, AReason) then
    begin
      Exit;
    end;
    LCandidate.FComposition := LCommitted;
    LCandidate.FSeed := ARequest.FSeed;
    AWorld := LCandidate;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

end.
