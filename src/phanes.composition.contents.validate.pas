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
unit phanes.composition.contents.validate;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.contents.types;

function ValidateContentRequest(const ABaseline: TCompositionDocument;
  const ARequest: TContentRequest; out AReason: String): Boolean;
function ValidateContentResult(const ADocument: TCompositionDocument;
  const ARequest: TContentRequest; out AReason: String): Boolean;

implementation

uses
  SysUtils,
  phanes.composition.document,
  phanes.composition.contents.assembly;

function ValidDimension(const AValue: Integer): Boolean;
begin
  Result := (AValue > 0) and (AValue <= 1000000);
end;

function ValidObjectId(const AId: String): Boolean;
var
  I: Integer;
begin
  Result := (Length(AId) > 0) and (Length(AId) <= 128);
  for I := 1 to Length(AId) do
  begin
    if not (AId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '.', '_']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidateContentRequest(const ABaseline: TCompositionDocument;
  const ARequest: TContentRequest; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAssemblies: TContentAssemblies;
  LBounds: TContentBounds;
  LSurface: Integer;
  LScope: Integer;
  LNode: Integer;
  LSlot: TContentSlot;
  LRole: String;
  I: Integer;
  J: Integer;
begin
  Result := False;
  if not ValidateComposition(ABaseline, AReason) then
  begin
    Exit;
  end;
  AReason := 'The contents request is stale.';
  if ABaseline.FRevision <> ARequest.FExpectedRevision then
  begin
    Exit;
  end;
  if not ValidateContentAssets(ARequest.FAssets, AReason) then
  begin
    Exit;
  end;
  AReason := 'Surface dimensions and local content limits are invalid.';
  if not ValidDimension(ARequest.FSurfaceWidth) or
    not ValidDimension(ARequest.FSurfaceDepth) or not ValidDimension(ARequest.FHeadroom) or
    (Length(ARequest.FSlots) < 1) or (Length(ARequest.FSlots) > 256) or
    (Length(ARequest.FAssets) < 1) or (Length(ARequest.FAssets) > 128) or
    (Length(ARequest.FQuotas) > 32) then
  begin
    Exit;
  end;
  LAssemblies := nil;
  LIndex := TCompositionIndex.Create(ABaseline.FNodes);
  try
    LAssemblies := TContentAssemblies.Create(ABaseline, ARequest.FAssets);
    LSurface := LIndex.Find(ARequest.FSurfaceId);
    LScope := LIndex.Find(ARequest.FScopeId);
    AReason := 'Select an existing surface, its container, or one of its contents.';
    if (LSurface < 0) or (LScope < 0) then
    begin
      Exit;
    end;
    if (ABaseline.FNodes[LSurface].FKind <> ckSurface) or
      (not InCompositionScope(ABaseline, LIndex, LSurface, ARequest.FScopeId) and
      (ABaseline.FNodes[LScope].FParentId <> ARequest.FSurfaceId)) then
    begin
      Exit;
    end;
    for I := 0 to High(ARequest.FSlots) do
    begin
      LSlot := ARequest.FSlots[I];
      AReason := 'Invalid content slot: ' + LSlot.FObjectId;
      if not ValidObjectId(LSlot.FObjectId) or not ValidDimension(LSlot.FWidth) or
        not ValidDimension(LSlot.FDepth) or not ValidDimension(LSlot.FHeight) or
        (LSlot.FQuarterTurn < 0) or (LSlot.FQuarterTurn > 3) or
        (Length(LSlot.FAllowedRoles) = 0) or
        (Abs(Double(LSlot.FX)) * 2 + LSlot.FWidth > ARequest.FSurfaceWidth) or
        (Abs(Double(LSlot.FZ)) * 2 + LSlot.FDepth > ARequest.FSurfaceDepth) or
        (LSlot.FHeight > ARequest.FHeadroom) then
      begin
        Exit;
      end;
      for LRole in LSlot.FAllowedRoles do
      begin
        if LRole = '' then
        begin
          Exit;
        end;
      end;
      for J := 0 to I - 1 do
      begin
        if (ARequest.FSlots[J].FObjectId = LSlot.FObjectId) or
          ((Abs(Double(LSlot.FX) - ARequest.FSlots[J].FX) * 2 <
          LSlot.FWidth + ARequest.FSlots[J].FWidth) and
          (Abs(Double(LSlot.FZ) - ARequest.FSlots[J].FZ) * 2 <
          LSlot.FDepth + ARequest.FSlots[J].FDepth)) then
        begin
          AReason := 'Content slots overlap or share an object ID: ' + LSlot.FObjectId;
          Exit;
        end;
      end;
      LNode := LIndex.Find(LSlot.FObjectId);
      if LNode >= 0 then
      begin
        AReason := 'A content slot refers to a different container or support: ' + LSlot.FObjectId;
        if (ABaseline.FNodes[LNode].FKind <> ckObject) or
          (ABaseline.FNodes[LNode].FParentId <> ARequest.FSurfaceId) or
          (ABaseline.FNodes[LNode].FSupportId <> ARequest.FSurfaceId) then
        begin
          Exit;
        end;
        if LAssemblies.HasChildren(LSlot.FObjectId) and
          not LAssemblies.Bounds(LSlot.FObjectId, '', LBounds, AReason) then
        begin
          Exit;
        end;
      end;
    end;
    for I := 0 to High(ABaseline.FNodes) do
    begin
      if (ABaseline.FNodes[I].FParentId = ARequest.FSurfaceId) or
        (ABaseline.FNodes[I].FSupportId = ARequest.FSurfaceId) then
      begin
        AReason := 'Include all supported contents before solving this surface: ' +
          ABaseline.FNodes[I].FId;
        if ContentSlotIndex(ARequest.FSlots, ABaseline.FNodes[I].FId) < 0 then
        begin
          Exit;
        end;
      end;
    end;
    for I := 0 to High(ARequest.FQuotas) do
    begin
      AReason := 'Invalid or duplicate per-surface count: ' + ARequest.FQuotas[I].FRole;
      if (ARequest.FQuotas[I].FRole = '') or (ARequest.FQuotas[I].FMinimum < 0) or
        (ARequest.FQuotas[I].FMaximum < ARequest.FQuotas[I].FMinimum) or
        (ARequest.FQuotas[I].FMaximum > Length(ARequest.FSlots)) then
      begin
        Exit;
      end;
      for J := 0 to I - 1 do
      begin
        if ARequest.FQuotas[J].FRole = ARequest.FQuotas[I].FRole then
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

function ValidateContentResult(const ADocument: TCompositionDocument;
  const ARequest: TContentRequest; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAssemblies: TContentAssemblies;
  LBounds: TContentBounds;
  LNode: TCompositionNode;
  LSlot: TContentSlot;
  LAsset: TContentAsset;
  LNodeIndex: Integer;
  LAssetIndex: Integer;
  LCount: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LValidationRequest: TContentRequest;
  I: Integer;
  J: Integer;
begin
  Result := False;
  LValidationRequest := ARequest;
  LValidationRequest.FExpectedRevision := ADocument.FRevision;
  if not ValidateContentRequest(ADocument, LValidationRequest, AReason) then
  begin
    Exit;
  end;
  LAssemblies := nil;
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    LAssemblies := TContentAssemblies.Create(ADocument, ARequest.FAssets);
    { Decode acceptance from instance records and measurements, never from WFC
      domains, mapped values, or the solver's quota report. }
    for I := 0 to High(ARequest.FSlots) do
    begin
      LSlot := ARequest.FSlots[I];
      LNodeIndex := LIndex.Find(LSlot.FObjectId);
      AReason := 'A required content slot is empty: ' + LSlot.FObjectId;
      if LNodeIndex < 0 then
      begin
        if not LSlot.FAllowEmpty then
        begin
          Exit;
        end;
        Continue;
      end;
      LNode := ADocument.FNodes[LNodeIndex];
      AReason := 'Invalid supported item placement: ' + LNode.FId;
      if (LNode.FKind <> ckObject) or (LNode.FParentId <> ARequest.FSurfaceId) or
        (LNode.FSupportId <> ARequest.FSurfaceId) or (LNode.FY <> 0) or
        (LNode.FX <> LSlot.FX) or (LNode.FZ <> LSlot.FZ) or
        (LNode.FQuarterTurn <> LSlot.FQuarterTurn) then
      begin
        Exit;
      end;
      LAssetIndex := ContentAssetIndex(ARequest.FAssets, LNode.FAssetId);
      AReason := 'Unadmitted content asset: ' + LNode.FAssetId;
      if LAssetIndex < 0 then
      begin
        Exit;
      end;
      LAsset := ARequest.FAssets[LAssetIndex];
      LWidth := LAsset.FWidth;
      LDepth := LAsset.FDepth;
      if Odd(LNode.FQuarterTurn) then
      begin
        LWidth := LAsset.FDepth;
        LDepth := LAsset.FWidth;
      end;
      AReason := 'Content does not fit its role or usable volume: ' + LNode.FId;
      if not LAsset.FSingleInstance or (LNode.FRole <> LAsset.FRole) or
        not ContentRoleAllowed(LSlot.FAllowedRoles, LNode.FRole) or
        ((Length(LSlot.FAllowedAssets) > 0) and
        not ContentRoleAllowed(LSlot.FAllowedAssets, LAsset.FId)) or
        (LWidth > LSlot.FWidth) or (LDepth > LSlot.FDepth) or
        (LAsset.FHeight > LSlot.FHeight) then
      begin
        Exit;
      end;
      if not LAssemblies.Bounds(LNode.FId, '', LBounds, AReason) then
      begin
        Exit;
      end;
      LBounds := TransformContentBounds(LBounds, 0, 0, 0, LNode.FQuarterTurn);
      if not ContentBoundsFit(LBounds, LSlot.FWidth, LSlot.FDepth, LSlot.FHeight) then
      begin
        AReason := 'The complete content assembly exceeds its reserved volume: ' + LNode.FId;
        Exit;
      end;
    end;
    for I := 0 to High(ADocument.FNodes) do
    begin
      LNode := ADocument.FNodes[I];
      if ((LNode.FParentId = ARequest.FSurfaceId) or
        (LNode.FSupportId = ARequest.FSurfaceId)) and
        (ContentSlotIndex(ARequest.FSlots, LNode.FId) < 0) then
      begin
        AReason := 'An unaccounted item occupies this surface: ' + LNode.FId;
        Exit;
      end;
    end;
    for I := 0 to High(ARequest.FQuotas) do
    begin
      LCount := 0;
      for J := 0 to High(ADocument.FNodes) do
      begin
        LNode := ADocument.FNodes[J];
        if (LNode.FSupportId = ARequest.FSurfaceId) and
          (LNode.FRole = ARequest.FQuotas[I].FRole) then
        begin
          Inc(LCount);
        end;
      end;
      if (LCount < ARequest.FQuotas[I].FMinimum) or
        (LCount > ARequest.FQuotas[I].FMaximum) then
      begin
        AReason := 'Required count was not met on this surface: ' + ARequest.FQuotas[I].FRole;
        Exit;
      end;
    end;
    AReason := '';
    Result := True;
  finally
    LAssemblies.Free;
    LIndex.Free;
  end;
end;

end.
