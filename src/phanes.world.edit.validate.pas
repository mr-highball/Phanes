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


unit phanes.world.edit.validate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateRegionalEdit(const ARequest: TWorldRequest; const AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  Math, phanes.terrain.types, phanes.composition.types, phanes.composition.document;

function ValidateRegionalEdit(const ARequest: TWorldRequest; const AWorld: TWorld;
  out AReason: String): Boolean;
var
  LAllowed: array[0..4] of array of Boolean;
  LScale: Integer;
  LSide: Integer;
  LLayer: Integer;
  LCell: Integer;
  LX: Integer;
  LZ: Integer;
  LFineX: Integer;
  LFineZ: Integer;
  LChanged: Boolean;
  LRemoved: Boolean;
  LInGroup: Boolean;
  LRoot: Integer;
  LCurrent: Integer;
  LPreviousIndex: TCompositionIndex;
  LNextIndex: TCompositionIndex;
  I: Integer;
  J: Integer;
begin
  Result := False;
  AReason := 'The edit changed data outside its authorized selection.';
  if ARequest.FPrevious.FSize = 0 then
  begin
    Exit(True);
  end;
  if (AWorld.FSize <> ARequest.FPrevious.FSize) or
    (AWorld.FAppearanceSeed <> ARequest.FPrevious.FAppearanceSeed) or
    (AWorld.FRelativeElevation <> ARequest.FPrevious.FRelativeElevation) or
    not SameTerrainField(AWorld.FElevation, ARequest.FPrevious.FElevation) then
  begin
    Exit;
  end;
  { This acceptance oracle expands the request into independent per-layer bit
    maps. It deliberately does not call the solver's selection/domain helpers. }
  LScale := Max(1, ARequest.FSelectionScale);
  for LLayer := 0 to 4 do
  begin
    LSide := AWorld.FSize;
    if (LLayer = 2) or (LLayer = 4) then
    begin
      LSide := LSide * 2;
    end;
    if (Length(AWorld.FLayers[LLayer]) <> Sqr(LSide)) or
      (Length(ARequest.FPrevious.FLayers[LLayer]) <> Sqr(LSide)) then
    begin
      Exit;
    end;
    SetLength(LAllowed[LLayer], Sqr(LSide));
    LChanged := True;
    if ARequest.FEditLayer = 'terrain' then
    begin
      LChanged := LLayer = 0;
    end
    else if (ARequest.FEditLayer = 'foliage') or (ARequest.FSelectionScale = 2) then
    begin
      LChanged := (LLayer = 2) or (LLayer = 4);
    end
    else if ARequest.FEditLayer = 'buildings' then
    begin
      LChanged := LLayer <> 0;
    end;
    if LChanged then
    begin
      if ARequest.FSelectionScale = 0 then
      begin
        for LZ := 0 to LSide - 1 do
        begin
          for LX := 0 to LSide - 1 do
          begin
            LFineX := LX * AWorld.FSize div LSide;
            LFineZ := LZ * AWorld.FSize div LSide;
            LAllowed[LLayer][LZ * LSide + LX] :=
              (LFineX >= ARequest.FX) and (LFineX < ARequest.FX + ARequest.FWidth) and
              (LFineZ >= ARequest.FZ) and (LFineZ < ARequest.FZ + ARequest.FDepth);
          end;
        end;
      end else
      begin
        for I := 0 to High(ARequest.FSelectionCells) do
        begin
          LCell := ARequest.FSelectionCells[I];
          LX := LCell mod (AWorld.FSize * LScale);
          LZ := LCell div (AWorld.FSize * LScale);
          for LFineZ := LZ * LSide div (AWorld.FSize * LScale) to
            (LZ + 1) * LSide div (AWorld.FSize * LScale) - 1 do
          begin
            for LFineX := LX * LSide div (AWorld.FSize * LScale) to
              (LX + 1) * LSide div (AWorld.FSize * LScale) - 1 do
            begin
              LAllowed[LLayer][LFineZ * LSide + LFineX] := True;
            end;
          end;
        end;
      end;
    end;
    for I := 0 to High(LAllowed[LLayer]) do
    begin
      if not LAllowed[LLayer][I] and
        (AWorld.FLayers[LLayer][I] <> ARequest.FPrevious.FLayers[LLayer][I]) then
      begin
        Exit;
      end;
      if LAllowed[LLayer][I] and (ARequest.FExactAsset <> '') and
        (((LLayer = 3) and (ARequest.FEditLayer = 'buildings')) or
         ((LLayer = 4) and (ARequest.FEditLayer = 'foliage'))) and
        (AWorld.FLayers[LLayer][I] <> ARequest.FExactAsset) then
      begin
        AReason := 'The chosen item was not placed exactly.';
        Exit;
      end;
      if LAllowed[LLayer][I] and (Length(ARequest.FAssetChoices) > 0) and
        (((LLayer = 3) and (ARequest.FEditLayer = 'buildings')) or
         ((LLayer = 4) and (ARequest.FEditLayer = 'foliage'))) then
      begin
        LInGroup := False;
        for J := 0 to High(ARequest.FAssetChoices) do
        begin
          LInGroup := LInGroup or (AWorld.FLayers[LLayer][I] = ARequest.FAssetChoices[J]);
        end;
        if not LInGroup then
        begin
          AReason := 'An item outside the chosen catalog group was generated.';
          Exit;
        end;
      end;
    end;
  end;
  LPreviousIndex := TCompositionIndex.Create(ARequest.FPrevious.FComposition.FNodes);
  LNextIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    LRemoved := False;
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      J := LPreviousIndex.Find(AWorld.FComposition.FNodes[I].FId);
      if (J < 0) or not SameNode(AWorld.FComposition.FNodes[I],
        ARequest.FPrevious.FComposition.FNodes[J]) then
      begin
        Exit;
      end;
    end;
    for I := 0 to High(ARequest.FPrevious.FComposition.FNodes) do
    begin
      if LNextIndex.Find(ARequest.FPrevious.FComposition.FNodes[I].FId) >= 0 then
      begin
        Continue;
      end;
      if ARequest.FPrevious.FComposition.FNodes[I].FLocked or
        (ARequest.FEditLayer = 'foliage') or (ARequest.FSelectionScale = 2) then
      begin
        Exit;
      end;
      LRemoved := True;
      LRoot := I;
      while ARequest.FPrevious.FComposition.FNodes[LRoot].FParentId <> 'world' do
      begin
        LCurrent := LPreviousIndex.Find(ARequest.FPrevious.FComposition.FNodes[LRoot].FParentId);
        if LCurrent < 0 then
        begin
          Exit;
        end;
        LRoot := LCurrent;
      end;
      LX := Floor(ARequest.FPrevious.FComposition.FNodes[LRoot].FX / 16000 + AWorld.FSize / 2);
      LZ := Floor(ARequest.FPrevious.FComposition.FNodes[LRoot].FZ / 16000 + AWorld.FSize / 2);
      if ARequest.FPrevious.FComposition.FNodes[LRoot].FRole = 'plot' then
      begin
        Dec(LX);
        Dec(LZ);
        if (ARequest.FOperation <> 'clear') or not LAllowed[1][LZ * AWorld.FSize + LX] or
          not LAllowed[1][LZ * AWorld.FSize + LX + 1] or
          not LAllowed[1][(LZ + 1) * AWorld.FSize + LX] or
          not LAllowed[1][(LZ + 1) * AWorld.FSize + LX + 1] then
        begin
          Exit;
        end;
      end
      else if (ARequest.FPrevious.FComposition.FNodes[LRoot].FRole <> 'building') or
        not LAllowed[1][LZ * AWorld.FSize + LX] or
        (AWorld.FLayers[3][LZ * AWorld.FSize + LX] =
        ARequest.FPrevious.FComposition.FNodes[LRoot].FAssetId) then
      begin
        Exit;
      end;
    end;
    if AWorld.FComposition.FRevision <>
      ARequest.FPrevious.FComposition.FRevision + Ord(LRemoved) then
    begin
      Exit;
    end;
  finally
    LNextIndex.Free;
    LPreviousIndex.Free;
  end;
  Result := True;
  AReason := '';
end;

end.
