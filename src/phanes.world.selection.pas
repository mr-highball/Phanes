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


unit phanes.world.selection;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateSelection(const ARequest: TWorldRequest; out AReason: String): Boolean;
function LayerEditable(const ARequest: TWorldRequest; const ALayer: Integer): Boolean;
function SelectedCell(const ARequest: TWorldRequest; const ALayer, AX, AZ: Integer): Boolean;
function SelectedRegionCount(const ARequest: TWorldRequest;
  const AX, AZ, AWidth, ADepth: Integer): Integer;

implementation

uses
  SysUtils, Math, phanes.selection.grid, phanes.buildings.types, phanes.landforms.types;

function LayerEditable(const ARequest: TWorldRequest; const ALayer: Integer): Boolean;
begin
  Result := True;
  if ARequest.FEditLayer = 'foliage' then
  begin
    Result := (ALayer = 2) or (ALayer = 4);
  end
  else if ARequest.FEditLayer = 'terrain' then
  begin
    Result := ALayer = 0;
  end
  else if ARequest.FEditLayer = 'buildings' then
  begin
    { A building reserves its complete ecology footprint. Terrain remains fixed. }
    Result := ALayer <> 0;
  end;
end;

function SelectedCell(const ARequest: TWorldRequest; const ALayer, AX, AZ: Integer): Boolean;
var
  LDivisor: Integer;
  LX: Integer;
  LZ: Integer;
begin
  if not LayerEditable(ARequest, ALayer) then
  begin
    Exit(False);
  end;
  LDivisor := LayerSize(ARequest.FSize, ALayer) div ARequest.FSize;
  if ARequest.FSelectionScale = 0 then
  begin
    LX := AX div LDivisor;
    LZ := AZ div LDivisor;
    Exit((LX >= ARequest.FX) and (LZ >= ARequest.FZ) and
      (LX < ARequest.FX + ARequest.FWidth) and (LZ < ARequest.FZ + ARequest.FDepth));
  end;
  { Fine masks can never authorize a coarse layer, even when their four child
    cells are all present. ValidateSelection enforces foliage-only fine edits. }
  if ARequest.FSelectionScale > LDivisor then
  begin
    Exit(False);
  end;
  LX := AX * ARequest.FSelectionScale div LDivisor;
  LZ := AZ * ARequest.FSelectionScale div LDivisor;
  Result := HasSelectionCell(ARequest.FSelectionCells,
    LZ * ARequest.FSize * ARequest.FSelectionScale + LX);
end;

function SelectedRegionCount(const ARequest: TWorldRequest;
  const AX, AZ, AWidth, ADepth: Integer): Integer;
var
  LX: Integer;
  LZ: Integer;
begin
  Result := 0;
  for LZ := AZ to AZ + ADepth - 1 do
  begin
    for LX := AX to AX + AWidth - 1 do
    begin
      if SelectedCell(ARequest, 1, LX, LZ) then
      begin
        Inc(Result);
      end;
    end;
  end;
end;

function ValidateSelection(const ARequest: TWorldRequest; out AReason: String): Boolean;
var
  LSize: Integer;
  LIndex: Integer;
  LLast: Integer;
  LMinX: Integer;
  LMinZ: Integer;
  LMaxX: Integer;
  LMaxZ: Integer;
  LKind: String;
  LExpectedKind: String;
  I: Integer;
  J: Integer;
begin
  Result := False;
  AReason := 'Choose a supported layer for this selection.';
  if (ARequest.FEditLayer <> '') and (ARequest.FEditLayer <> 'terrain') and
    (ARequest.FEditLayer <> 'foliage') and (ARequest.FEditLayer <> 'buildings') then
  begin
    Exit;
  end;
  if (ARequest.FSelectionScale > 0) and (ARequest.FPrevious.FSize <> ARequest.FSize) then
  begin
    AReason := 'A masked edit needs an existing world of the same size to preserve its surroundings.';
    Exit;
  end;
  if ARequest.FExactAsset <> '' then
  begin
    LKind := AssetKind(ARequest.FAssets, ARequest.FExactAsset);
    AReason := 'Choose a placeable item from this catalog and its matching layer.';
    if (ARequest.FOperation <> 'asset') or (LKind = '') then
    begin
      Exit;
    end;
    if (LKind = 'cabin') or (LKind = 'castle') or (LKind = 'modern') or (LKind = 'scifi') then
    begin
      if ARequest.FEditLayer <> 'buildings' then
      begin
        Exit;
      end;
    end
    else if ARequest.FEditLayer <> 'foliage' then
    begin
      Exit;
    end;
  end
  else if ARequest.FOperation = 'asset' then
  begin
    AReason := 'Choose the exact item to place.';
    Exit;
  end;
  if Length(ARequest.FAssetChoices) > 0 then
  begin
    AReason := 'The catalog group must contain compatible, distinct placeable models.';
    LExpectedKind := ARequest.FOperation;
    if LExpectedKind = 'rocket' then
    begin
      LExpectedKind := 'scifi';
    end;
    if (ARequest.FEditLayer <> 'foliage') and (ARequest.FEditLayer <> 'buildings') then
    begin
      Exit;
    end;
    if ((ARequest.FEditLayer = 'buildings') and (LExpectedKind <> 'cabin') and
      (LExpectedKind <> 'castle') and (LExpectedKind <> 'modern') and (LExpectedKind <> 'scifi')) or
      ((ARequest.FEditLayer = 'foliage') and (LExpectedKind <> 'tree') and
      (LExpectedKind <> 'shrub') and (LExpectedKind <> 'flowers') and
      (LExpectedKind <> 'wheat') and (LExpectedKind <> 'rock')) then
    begin
      Exit;
    end;
    for I := 0 to High(ARequest.FAssetChoices) do
    begin
      LKind := AssetKind(ARequest.FAssets, ARequest.FAssetChoices[I]);
      if (LKind = '') or (LKind <> LExpectedKind) or (ARequest.FExactAsset <> '') then
      begin
        Exit;
      end;
      for J := 0 to I - 1 do
      begin
        if ARequest.FAssetChoices[I] = ARequest.FAssetChoices[J] then
        begin
          Exit;
        end;
      end;
    end;
  end;
  AReason := 'Use building precision to draw floors or an extension.';
  if ((ARequest.FOperation = 'module-build') or (ARequest.FOperation = 'module-extend') or
    (ARequest.FOperation = 'module-populate')) and
    (ARequest.FSelectionScale <> 8) then
  begin
    Exit;
  end;
  AReason := 'Building precision is reserved for modular floor and extension edits.';
  if (ARequest.FSelectionScale = 8) and
    (ARequest.FOperation <> 'module-build') and (ARequest.FOperation <> 'module-extend') and
    (ARequest.FOperation <> 'module-populate') then
  begin
    Exit;
  end;
  AReason := 'The selection mask must use regional, foliage or building cells.';
  if (ARequest.FSelectionScale < 0) or
    ((ARequest.FSelectionScale > 2) and (ARequest.FSelectionScale <> 8)) then
  begin
    Exit;
  end;
  if ARequest.FSelectionScale = 0 then
  begin
    Result := Length(ARequest.FSelectionCells) = 0;
    Exit;
  end;
  if (ARequest.FOperation <> 'reimagine') and (ARequest.FOperation <> 'clear') and
    (ARequest.FOperation <> 'asset') and (ARequest.FOperation <> 'forest') and
    (ARequest.FOperation <> 'flowers') and (ARequest.FOperation <> 'field') and
    (ARequest.FOperation <> 'water') and (ARequest.FOperation <> 'meadow') and
    (ARequest.FOperation <> 'stone') and (ARequest.FOperation <> 'tree') and
    (ARequest.FOperation <> 'shrub') and (ARequest.FOperation <> 'wheat') and
    (ARequest.FOperation <> 'rock') and (ARequest.FOperation <> 'cabin') and
    (ARequest.FOperation <> 'castle') and (ARequest.FOperation <> 'modern') and
    (ARequest.FOperation <> 'scifi') and (ARequest.FOperation <> 'rocket') and
    (ARequest.FOperation <> 'module-build') and (ARequest.FOperation <> 'module-extend') and
    (ARequest.FOperation <> 'module-populate') and
    not IsLandformOperation(ARequest.FOperation) then
  begin
    AReason := 'This operation uses its own object or plot selection.';
    Exit;
  end;
  if (ARequest.FSelectionScale = 2) and (ARequest.FEditLayer <> 'foliage') and
    not IsLandformOperation(ARequest.FOperation) then
  begin
    AReason := 'Fine cells edit foliage only. Select regional cells for terrain or buildings.';
    Exit;
  end;
  LSize := ARequest.FSize * ARequest.FSelectionScale;
  AReason := 'Select at least one cell before applying a change.';
  if (Length(ARequest.FSelectionCells) = 0) or
    (Length(ARequest.FSelectionCells) > Sqr(LSize)) then
  begin
    Exit;
  end;
  LLast := -1;
  LMinX := LSize;
  LMinZ := LSize;
  LMaxX := -1;
  LMaxZ := -1;
  AReason := 'Selection cells must be unique, ordered and inside the world.';
  for I := 0 to High(ARequest.FSelectionCells) do
  begin
    LIndex := ARequest.FSelectionCells[I];
    if (LIndex <= LLast) or (LIndex >= Sqr(LSize)) then
    begin
      Exit;
    end;
    LLast := LIndex;
    LMinX := Min(LMinX, (LIndex mod LSize) div ARequest.FSelectionScale);
    LMaxX := Max(LMaxX, (LIndex mod LSize) div ARequest.FSelectionScale);
    LMinZ := Min(LMinZ, (LIndex div LSize) div ARequest.FSelectionScale);
    LMaxZ := Max(LMaxZ, (LIndex div LSize) div ARequest.FSelectionScale);
  end;
  AReason := 'The selection boundary must match its actual cells.';
  Result := (ARequest.FX = LMinX) and (ARequest.FZ = LMinZ) and
    (ARequest.FWidth = LMaxX - LMinX + 1) and (ARequest.FDepth = LMaxZ - LMinZ + 1);
  if Result then
  begin
    AReason := '';
  end;
end;

end.
