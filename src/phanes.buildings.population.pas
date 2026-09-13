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
unit phanes.buildings.population;
{$mode delphi}
{$H+}
interface
uses phanes.world.types;
function PopulateCatalogFloors(const ARequest: TWorldRequest; const ARoot: String;
  var AWorld: TWorld; out AReason: String): Boolean;
implementation
uses SysUtils, Math, phanes.composition.types, phanes.composition.document,
  phanes.composition.contents.types, phanes.composition.contents.generate,
  phanes.buildings.types, phanes.buildings.validate, phanes.buildings.furniture,
  phanes.buildings.catalog;
function PopulateCatalogFloors(const ARequest: TWorldRequest; const ARoot: String;
  var AWorld: TWorld; out AReason: String): Boolean;
const
  CMaximumItems = 512;
  CMaximumPerFloor = 128;
var
  LIds: TContentNames;
  LFloors: TContentNames;
  LAssets: TContentAssets;
  LIndex: TCompositionIndex;
  LContents: TContentRequest;
  LCommitted: TCompositionDocument;
  LTrial: TWorld;
  LSlot: TContentSlot;
  LId: String;
  LRandom: Double;
  LArea: Double;
  LFloorArea: Double;
  LTarget: Double;
  LWidth: Integer;
  LDepth: Integer;
  LColumns: Integer;
  LRows: Integer;
  LCount: Integer;
  LPlaced: Integer;
  LAt: Integer;
  LParent: Integer;
  LChoice: Integer;
  LCell: Integer;
  LX: Integer;
  LZ: Integer;
  I: Integer;
  J: Integer;
  function NextRandom(const ALimit: Integer): Integer;
  begin
    LRandom := LRandom * 1664525 + 1013904223;
    LRandom := LRandom - Floor(LRandom / 4294967296.0) * 4294967296.0;
    Result := Floor(LRandom / 4294967296.0 * ALimit);
  end;
begin
  Result := False;
  AReason := 'Choose a density between 1 and 100 percent.';
  if (ARequest.FModuleDensity < 1) or (ARequest.FModuleDensity > 100) then
  begin
    Exit;
  end;
  LRandom := ARequest.FSeed;
  if Pos('category:', ARequest.FContentAsset) = 1 then
  begin
    LIds := FloorCatalogIds(Copy(ARequest.FContentAsset, 10, MaxInt));
  end else
  begin
    SetLength(LIds, 1);
    LIds[0] := ARequest.FContentAsset;
  end;
  AReason := 'Choose a category or a specific model.';
  if Length(LIds) = 0 then
  begin
    Exit;
  end;
  for I := High(LIds) downto 1 do
  begin
    J := NextRandom(I + 1);
    LId := LIds[I];
    LIds[I] := LIds[J];
    LIds[J] := LId;
  end;
  { Three optional sources keep category mixtures within the existing texture
    and source residency limits. Every exact catalog choice remains available. }
  SetLength(LAssets, Min(3, Length(LIds)));
  LWidth := 0;
  LDepth := 0;
  for I := 0 to High(LAssets) do
  begin
    if not FloorCatalogAsset(LIds[I], LAssets[I]) then
    begin
      Exit;
    end;
    LWidth := Max(LWidth, LAssets[I].FWidth);
    LDepth := Max(LDepth, LAssets[I].FDepth);
  end;
  LColumns := 1760 div (LWidth + 10);
  LRows := 1760 div (LDepth + 10);
  { A wide furnishing may still fit centred on a whole two-metre tile. }
  if (LColumns = 0) and (LWidth <= 2000) then
  begin
    LColumns := 1;
  end;
  if (LRows = 0) and (LDepth <= 2000) then
  begin
    LRows := 1;
  end;
  AReason := 'This choice needs more floor space than is available.';
  if (LColumns = 0) or (LRows = 0) then
  begin
    Exit;
  end;
  LFloors := nil;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    for I := 0 to High(ARequest.FSelectionCells) do
    begin
      LId := ModuleFloorId(ARoot, ARequest.FSelectionCells[I] mod (ARequest.FSize * 8),
        ARequest.FSelectionCells[I] div (ARequest.FSize * 8));
      LAt := LIndex.Find(LId);
      if (LAt < 0) or FloorHasContents(AWorld.FComposition, LId) or
        ContentRoleAllowed(LFloors, LId) then
      begin
        Continue;
      end;
      LParent := LAt;
      while (LParent >= 0) and not AWorld.FComposition.FNodes[LParent].FLocked do
      begin
        LParent := LIndex.Find(AWorld.FComposition.FNodes[LParent].FParentId);
      end;
      if LParent >= 0 then
      begin
        Continue;
      end;
      SetLength(LFloors, Length(LFloors) + 1);
      LFloors[High(LFloors)] := LId;
    end;
  finally
    LIndex.Free;
  end;
  AReason := 'Paint empty, unlocked floors in the selected home first.';
  if Length(LFloors) = 0 then
  begin
    Exit;
  end;
  for I := High(LFloors) downto 1 do
  begin
    J := NextRandom(I + 1);
    LId := LFloors[I];
    LFloors[I] := LFloors[J];
    LFloors[J] := LId;
  end;
  LTarget := Length(LFloors) * 4000000.0 * ARequest.FModuleDensity / 100;
  LArea := 0;
  LPlaced := 0;
  for I := 0 to High(LFloors) do
  begin
    if (LArea >= LTarget) or (LPlaced >= CMaximumItems) then
    begin
      Break;
    end;
    if not BuildingFloorRequest(AWorld.FComposition, LFloors[I], LContents, AReason) then
    begin
      Continue;
    end;
    LContents.FAssets := LAssets;
    LContents.FSlots := nil;
    LContents.FSeed := ARequest.FSeed;
    LFloorArea := 0;
    LCount := Min(CMaximumPerFloor, (CMaximumItems - LPlaced) div (Length(LFloors) - I));
    LCount := Min(LCount, LColumns * LRows);
    { Non-overlapping measured boxes are the WFC slots. Fill toward the requested
      footprint area, not a count of tiles. Floor/operation caps bound browser work. }
    for J := 0 to LCount - 1 do
    begin
      LChoice := (J + I) mod Length(LAssets);
      LCell := J * (LColumns * LRows) div LCount;
      LX := LCell mod LColumns;
      LZ := LCell div LColumns;
      LSlot := Default(TContentSlot);
      LSlot.FObjectId := LFloors[I] + '.scatter.' + IntToStr(J);
      LSlot.FX := (2 * LX - LColumns + 1) * (LWidth + 10) div 2;
      LSlot.FZ := (2 * LZ - LRows + 1) * (LDepth + 10) div 2;
      LSlot.FWidth := LWidth;
      LSlot.FDepth := LDepth;
      LSlot.FHeight := 2800;
      LSlot.FAllowedRoles := [LAssets[LChoice].FRole];
      LSlot.FAllowedAssets := [LAssets[LChoice].FId];
      LSlot.FAllowEmpty := False;
      SetLength(LContents.FSlots, J + 1);
      LContents.FSlots[J] := LSlot;
      LFloorArea := LFloorArea + Double(LAssets[LChoice].FWidth) * LAssets[LChoice].FDepth;
      if LFloorArea >= (LTarget - LArea) / (Length(LFloors) - I) then
      begin
        Break;
      end;
    end;
    if not GenerateContents(AWorld.FComposition, LContents, LCommitted, AReason) then
    begin
      Continue;
    end;
    LTrial := AWorld;
    LTrial.FComposition := LCommitted;
    LTrial.FComposition.FRevision := AWorld.FComposition.FRevision;
    { Preserve physical doorway and wall checks; a blocked floor is skipped. }
    if not ValidateModularBuildings(LTrial, AReason) then
    begin
      Continue;
    end;
    AWorld := LTrial;
    Inc(LPlaced, Length(LContents.FSlots));
    LArea := LArea + LFloorArea;
  end;
  Result := LPlaced > 0;
  AReason := 'No selected floor can fit these items while keeping access clear. ' + AReason;
  if Result then
  begin
    AReason := 'Added ' + IntToStr(LPlaced) + ' items · ' +
      FormatFloat('0.0', LArea * 100 / (Length(LFloors) * 4000000.0)) +
      '% floor-area coverage (target ' + IntToStr(ARequest.FModuleDensity) +
      '%). Access and item limits may reduce coverage.';
  end;
end;
end.
