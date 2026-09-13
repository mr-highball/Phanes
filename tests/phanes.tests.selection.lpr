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


program PhanesSelectionTests;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, phanes.selection.grid, phanes.world.types,
  phanes.world.selection, phanes.world.generate, phanes.world.edit.validate,
  phanes.composition.types
  {$ifdef PAS2JS}
  , JS, Web
  {$endif}
  ;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create('Check ' + IntToStr(GChecks) + ': ' + AMessage);
  end;
end;

function Cells(const AValues: array of Integer): TSelectionCells;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
  begin
    Result[I] := AValues[I];
  end;
end;

function EmptyRequest: TWorldRequest;
var
  I: Integer;
  J: Integer;
begin
  Result := Default(TWorldRequest);
  Result.FSize := 4;
  Result.FSeed := 100;
  Result.FX := 1;
  Result.FZ := 1;
  Result.FWidth := 2;
  Result.FDepth := 2;
  Result.FPrevious.FSize := 4;
  Result.FPrevious.FAppearanceSeed := 99;
  Result.FPrevious.FComposition := InitialWorldComposition(99);
  SetLength(Result.FAssets, 6);
  Result.FAssets[0].FId := 'nature-kit/tree_oak';
  Result.FAssets[0].FKind := 'tree';
  Result.FAssets[1].FId := 'nature-kit/flower_redA';
  Result.FAssets[1].FKind := 'flowers';
  Result.FAssets[2].FId := 'cabin';
  Result.FAssets[2].FKind := 'cabin';
  Result.FAssets[3].FId := 'nature-kit/plant_bush';
  Result.FAssets[3].FKind := 'shrub';
  Result.FAssets[4].FId := 'nature-kit/crops_wheatStageB';
  Result.FAssets[4].FKind := 'wheat';
  Result.FAssets[5].FId := 'nature-kit/rock_largeA';
  Result.FAssets[5].FKind := 'rock';
  for I := 0 to 4 do
  begin
    SetLength(Result.FPrevious.FLayers[I], Sqr(LayerSize(4, I)));
    for J := 0 to High(Result.FPrevious.FLayers[I]) do
    begin
      Result.FPrevious.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        Result.FPrevious.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
end;

procedure CheckMasks;
var
  LRequest: TWorldRequest;
  LWorld: TWorld;
  LBad: TWorld;
  LReason: String;
  I: Integer;
  J: Integer;
  LAllowed: Boolean;
begin
  LRequest := EmptyRequest;
  LRequest.FSelectionScale := 1;
  LRequest.FSelectionCells := Cells([5, 10]);
  LRequest.FOperation := 'asset';
  LRequest.FEditLayer := 'foliage';
  LRequest.FExactAsset := 'nature-kit/tree_oak';
  Check(ValidateSelection(LRequest, LReason), LReason);
  Check(GenerateWorld(LRequest, LWorld, LReason), LReason);
  for I := 0 to 63 do
  begin
    LAllowed := ((I mod 8 div 2 = 1) and (I div 8 div 2 = 1)) or
      ((I mod 8 div 2 = 2) and (I div 8 div 2 = 2));
    Check((LWorld.FLayers[4][I] = 'nature-kit/tree_oak') = LAllowed,
      'Two separate islands preserve their bounding-box holes');
  end;
  LRequest.FSelectionScale := 2;
  LRequest.FSelectionCells := Cells([18, 45]);
  Check(GenerateWorld(LRequest, LWorld, LReason), LReason);
  for I := 0 to 4 do
  begin
    for J := 0 to High(LWorld.FLayers[I]) do
    begin
      LAllowed := ((I = 2) or (I = 4)) and ((J = 18) or (J = 45));
      Check(LAllowed or (LWorld.FLayers[I][J] = LRequest.FPrevious.FLayers[I][J]),
        'Fine-mask edit preserves every other layer and cell');
    end;
  end;
  LBad := LWorld;
  LBad.FLayers[4] := Copy(LWorld.FLayers[4], 0, Length(LWorld.FLayers[4]));
  LBad.FLayers[4][19] := 'nature-kit/tree_oak';
  Check(not ValidateRegionalEdit(LRequest, LBad, LReason),
    'Independent oracle rejects a mutated cell inside a bounding-box hole');
  LBad := LWorld;
  Inc(LBad.FAppearanceSeed);
  Check(not ValidateRegionalEdit(LRequest, LBad, LReason), 'Appearance identity preserved');
  LRequest.FSelectionCells := Cells([18, 18]);
  Check(not ValidateSelection(LRequest, LReason), 'Duplicates rejected');
  LRequest.FSelectionCells := Cells([45, 18]);
  Check(not ValidateSelection(LRequest, LReason), 'Unsorted indices rejected');
  LRequest.FSelectionCells := nil;
  Check(not ValidateSelection(LRequest, LReason), 'Empty explicit mask cannot fall back to rectangle');
  LRequest.FSelectionCells := Cells([18, 45]);
  LRequest.FEditLayer := 'buildings';
  Check(not ValidateSelection(LRequest, LReason), 'Fine selection cannot authorize a coarse layer');
  LRequest.FEditLayer := 'foliage';
  LRequest.FExactAsset := 'unknown';
  Check(not ValidateSelection(LRequest, LReason), 'Unknown exact item rejected');
  LRequest := EmptyRequest;
  LRequest.FSelectionScale := 1;
  LRequest.FSelectionCells := Cells([5, 10]);
  LRequest.FOperation := 'tree';
  LRequest.FEditLayer := 'foliage';
  SetLength(LRequest.FAssetChoices, 1);
  LRequest.FAssetChoices[0] := 'nature-kit/tree_oak';
  Check(GenerateWorld(LRequest, LWorld, LReason), 'A chosen catalog group is admitted: ' + LReason);
  Check(LWorld.FLayers[4][18] = 'nature-kit/tree_oak', 'Only models from the displayed group are generated');
  LRequest.FPrevious := Default(TWorld);
  Check(not ValidateSelection(LRequest, LReason), 'Mask without preservation baseline rejected');
  LRequest := EmptyRequest;
  LRequest.FPrevious := Default(TWorld);
  LRequest.FOperation := 'create';
  LRequest.FX := 0;
  LRequest.FZ := 0;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  Check(GenerateWorld(LRequest, LWorld, LReason), 'Ordinary new-world generation remains available: ' + LReason);
end;

procedure CheckPlotHole;
var
  LRequest: TWorldRequest;
  LPlot: TWorld;
  LWorld: TWorld;
  LReason: String;
  I: Integer;
begin
  LRequest := EmptyRequest;
  LRequest.FOperation := 'foundation';
  LRequest.FGroundworkTurn := -1;
  Check(GenerateWorld(LRequest, LPlot, LReason), 'Create plot fixture: ' + LReason);
  LRequest.FPrevious := LPlot;
  LRequest.FOperation := 'clear';
  LRequest.FX := 0;
  LRequest.FZ := 0;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  LRequest.FSelectionScale := 1;
  LRequest.FSelectionCells := Cells([0, 1, 2, 3, 4, 7, 8, 11, 12, 13, 14, 15]);
  Check(GenerateWorld(LRequest, LWorld, LReason), 'A clear ring preserves the plot in its hole: ' + LReason);
  Check(Length(LWorld.FComposition.FNodes) = Length(LPlot.FComposition.FNodes), 'No nested plot object removed');
  for I := 0 to High(LPlot.FComposition.FNodes) do
  begin
    Check(SameNode(LPlot.FComposition.FNodes[I], LWorld.FComposition.FNodes[I]), 'Plot node data preserved');
  end;
  LRequest.FSelectionCells := Cells([0, 1, 2, 3, 4, 5, 7, 8, 11, 12, 13, 14, 15]);
  Check(not GenerateWorld(LRequest, LWorld, LReason), 'Partial plot coverage cannot erase supports');
  LRequest.FSelectionScale := 2;
  LRequest.FEditLayer := 'foliage';
  SetLength(LRequest.FSelectionCells, 64);
  for I := 0 to 63 do
  begin
    LRequest.FSelectionCells[I] := I;
  end;
  Check(GenerateWorld(LRequest, LWorld, LReason), 'Even all fine cells cannot authorize plot removal: ' + LReason);
  Check(Length(LWorld.FComposition.FNodes) = Length(LPlot.FComposition.FNodes), 'Fine clear retains the full plot');
end;

procedure CheckBrush;
var
  LBits: TSelectionBits;
  LPoints: TSelectionPoints;
  LA: TSelectionPoint;
  LB: TSelectionPoint;
  I: Integer;
begin
  SetLength(LBits, 64);
  LA.FX := 0.5;
  LA.FZ := 2.5;
  LB.FX := 7.5;
  LB.FZ := 2.5;
  PaintSelection(LBits, 8, LA, LB, 0.5);
  for I := 0 to 63 do
  begin
    Check(LBits[I] = (I div 8 = 2), 'Sparse brush stroke remains continuous and one cell wide');
  end;
  LBits := nil;
  SetLength(LBits, 64);
  SetLength(LPoints, 6);
  LPoints[0].FX := 1;
  LPoints[0].FZ := 1;
  LPoints[1].FX := 5;
  LPoints[1].FZ := 1;
  LPoints[2].FX := 5;
  LPoints[2].FZ := 2;
  LPoints[3].FX := 2;
  LPoints[3].FZ := 2;
  LPoints[4].FX := 2;
  LPoints[4].FZ := 5;
  LPoints[5].FX := 1;
  LPoints[5].FZ := 5;
  LassoSelection(LBits, 8, LPoints);
  for I := 0 to 63 do
  begin
    Check(LBits[I] = (((I div 8 = 1) and (I mod 8 >= 1) and (I mod 8 < 5)) or
      ((I mod 8 = 1) and (I div 8 >= 1) and (I div 8 < 5))), 'Concave lasso excludes its cutout');
  end;
  LBits := nil;
  SetLength(LBits, 64);
  LassoSelection(LBits, 8, LPoints, True);
  for I := 0 to 63 do
  begin
    Check(LBits[I] = (((I div 8 = 1) and (I mod 8 >= 1) and (I mod 8 < 5)) or
      ((I mod 8 = 1) and (I div 8 >= 1) and (I div 8 < 5))),
      'Touched-cell lasso keeps aligned boundaries and the concave cutout');
  end;
  LBits := nil;
  SetLength(LBits, 64);
  SetLength(LPoints, 3);
  LPoints[0].FX := 2.1;
  LPoints[0].FZ := 3.1;
  LPoints[1].FX := 2.2;
  LPoints[1].FZ := 3.1;
  LPoints[2].FX := 2.1;
  LPoints[2].FZ := 3.2;
  LassoSelection(LBits, 8, LPoints, True);
  for I := 0 to 63 do
  begin
    Check(LBits[I] = (I = 26), 'A sub-cell first-person lasso selects only its touched cell');
  end;
  LBits := nil;
  SetLength(LBits, 64);
  for I := 0 to 2 do
  begin
    LPoints[I] := LPoints[0];
  end;
  LassoSelection(LBits, 8, LPoints, True);
  Check((Length(SelectionCells(LBits)) = 1) and LBits[26],
    'A coincident-point outline behaves as a tap');
  LBits := nil;
  SetLength(LBits, 64);
  LPoints[1].FX := 4.9;
  LassoSelection(LBits, 8, LPoints, True);
  Check((Length(SelectionCells(LBits)) = 3) and LBits[26] and LBits[27] and LBits[28],
    'An out-and-back line selects only the cells crossed');
  LBits := nil;
  SetLength(LBits, 64);
  LPoints[0].FX := 1 - 2E-13;
  LPoints[0].FZ := 0;
  LPoints[1].FX := 1 + 2E-13;
  LPoints[1].FZ := 3;
  LPoints[2].FX := 1 - 2E-13;
  LPoints[2].FZ := 3;
  LassoSelection(LBits, 8, LPoints, True);
  Check(not LBits[1] and LBits[9] and LBits[17],
    'A nearly parallel edge retains its true grid-boundary crossing');
end;

begin
  CheckMasks;
  CheckPlotHole;
  CheckBrush;
  WriteLn(GChecks, ' selection checks passed');
  {$ifdef PAS2JS}
  TJSObject(window)['phanesSelectionChecks'] := GChecks;
  {$endif}
end.
