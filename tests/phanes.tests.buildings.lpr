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
program PhanesModularBuildingChecks;
{$mode delphi}
{$H+}
uses
  SysUtils, Math, FPJSON, phanes.tools.files, phanes.world.types,
  phanes.world.generate, phanes.world.validate, phanes.world.selection,
  phanes.composition.types, phanes.composition.document,
  phanes.buildings.types, phanes.buildings.validate;

var
  GChecks: Integer;
  GReason: String;
  GAssets: TAssets;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  Require(AValue, AMessage + ': ' + GReason);
end;

function Baseline: TWorld;
var
  I: Integer;
  J: Integer;
begin
  Result := Default(TWorld);
  Result.FSize := 4;
  Result.FSeed := 731;
  Result.FAppearanceSeed := 731;
  Result.FComposition := InitialWorldComposition(731);
  for I := 0 to 4 do
  begin
    SetLength(Result.FLayers[I], Sqr(LayerSize(4, I)));
    for J := 0 to High(Result.FLayers[I]) do
    begin
      Result.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        Result.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
end;

function Request(const AWorld: TWorld; const AOperation, AId: String): TWorldRequest;
begin
  Result := Default(TWorldRequest);
  Result.FPrevious := AWorld;
  Result.FAssets := GAssets;
  Result.FSize := AWorld.FSize;
  Result.FSeed := 101;
  Result.FOperation := AOperation;
  Result.FObjectId := AId;
  Result.FWidth := 1;
  Result.FDepth := 1;
  Result.FContentCount := -1;
  Result.FGroundworkTurn := -1;
end;

procedure SelectRect(var ARequest: TWorldRequest; const AX, AZ, AWidth, ADepth: Integer);
var
  I: Integer;
  J: Integer;
  LCount: Integer;
begin
  ARequest.FSelectionScale := 8;
  ARequest.FX := AX div 8;
  ARequest.FZ := AZ div 8;
  ARequest.FWidth := (AX + AWidth - 1) div 8 - ARequest.FX + 1;
  ARequest.FDepth := (AZ + ADepth - 1) div 8 - ARequest.FZ + 1;
  SetLength(ARequest.FSelectionCells, AWidth * ADepth);
  LCount := 0;
  for J := AZ to AZ + ADepth - 1 do
  begin
    for I := AX to AX + AWidth - 1 do
    begin
      ARequest.FSelectionCells[LCount] := J * ARequest.FSize * 8 + I;
      Inc(LCount);
    end;
  end;
end;

procedure FurnishingChecks(const ABase: TWorld; const ARoot: String);
var
  LWorld: TWorld;
  LOther: TWorld;
  LRequest: TWorldRequest;
  LFloor: String;
  LTop: String;
  LPlate: String;
  LIndex: TCompositionIndex;
  LAt: Integer;
  I: Integer;
begin
  LFloor := ModuleFloorId(ARoot, 13, 13);
  LTop := LFloor + '.furnishing.top';
  LRequest := Request(ABase, 'module-furnish', LFloor);
  LRequest.FContentAsset := 'phanes.table.oak.v1';
  Check(GenerateWorld(LRequest, LWorld, GReason), 'An ad hoc floor tile admits an oak table');
  Check(LWorld.FComposition.FRevision = ABase.FComposition.FRevision + 1,
    'Furniture publishes one atomic revision');
  LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
  try
    Check(LIndex.Find(LTop) >= 0, 'Table has an independently editable support');
    for I := 0 to High(ABase.FComposition.FNodes) do
    begin
      LAt := LIndex.Find(ABase.FComposition.FNodes[I].FId);
      Check((LAt >= 0) and SameNode(ABase.FComposition.FNodes[I], LWorld.FComposition.FNodes[LAt]),
        'Furnishing preserves every existing floor and wall');
    end;
  finally
    LIndex.Free;
  end;
  LRequest := Request(LWorld, 'contents', LTop);
  LRequest.FContentRole := 'plate';
  LRequest.FContentCount := 2;
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Two plates generated inside the real-world table');
  LRequest := Request(LWorld, 'contents', LTop);
  LRequest.FContentRole := 'fork';
  LRequest.FContentCount := 2;
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Forks have independent counts');
  LPlate := LTop + '.item-0';
  LRequest := Request(LWorld, 'contents', LPlate + '.well');
  LRequest.FContentRole := 'fruit';
  LRequest.FContentCount := 1;
  Check(GenerateWorld(LRequest, LWorld, GReason), 'A plate supports a nested fruit item');
  LRequest := Request(LWorld, 'module-extend', ARoot);
  SelectRect(LRequest, 15, 12, 2, 2);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Furnished home can extend without a separate interior');
  LIndex := TCompositionIndex.Create(LOther.FComposition.FNodes);
  try
    for I := 0 to High(LWorld.FComposition.FNodes) do
    begin
      if Pos(LFloor + '.furnishing', LWorld.FComposition.FNodes[I].FId) = 1 then
      begin
        LAt := LIndex.Find(LWorld.FComposition.FNodes[I].FId);
        Check((LAt >= 0) and SameNode(LWorld.FComposition.FNodes[I], LOther.FComposition.FNodes[LAt]),
          'Extension preserves table, forks, plates and fruit exactly');
      end;
    end;
  finally
    LIndex.Free;
  end;
  LRequest := Request(LWorld, 'module-lock', LPlate + '.well.item-1');
  Check(GenerateWorld(LRequest, LOther, GReason), 'Nested fruit can be protected');
  LRequest := Request(LOther, 'contents', LTop);
  LRequest.FContentRole := 'plate';
  LRequest.FContentCount := 0;
  Check(not GenerateWorld(LRequest, LOther, GReason), 'Plate zero respects protected fruit');
  LRequest := Request(LWorld, 'contents', LTop);
  LRequest.FContentRole := 'plate';
  LRequest.FContentCount := 0;
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Plate count zero removes plates and unprotected food');
  LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
  try
    Check(LIndex.Find(LPlate) < 0, 'Zero leaves no plate');
    Check(LIndex.Find(LPlate + '.well.item-1') < 0, 'Zero leaves no orphan fruit');
    Check(LIndex.Find(LTop + '.item-1') >= 0, 'Zero plates preserves forks');
  finally
    LIndex.Free;
  end;
  LRequest := Request(LWorld, 'module-furnish', LFloor);
  LRequest.FContentAsset := 'empty';
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Explicit clear removes the furnishing subtree');
  LRequest := Request(LWorld, 'module-furnish', LFloor);
  LRequest.FContentAsset := 'plants';
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Plants can emerge in the same ad hoc floor region');
  LRequest := Request(ABase, 'module-furnish', ModuleFloorId(ARoot, 12, 12));
  LRequest.FContentAsset := 'phanes.table.oak.v1';
  Check(not GenerateWorld(LRequest, LOther, GReason), 'Furniture cannot seal the usable entrance');
end;

procedure AccessChecks;
var
  LWorld: TWorld;
  LOther: TWorld;
  LRequest: TWorldRequest;
  LRoot: String;
  LIndex: TCompositionIndex;
  LAt: Integer;
begin
  LRequest := Request(Baseline, 'module-build', '');
  SelectRect(LRequest, 12, 12, 1, 4);
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Narrow home has an initial walking route');
  LRoot := LWorld.FComposition.FNodes[1].FId;
  LRequest := Request(LWorld, 'module-furnish', ModuleFloorId(LRoot, 12, 14));
  LRequest.FContentAsset := 'phanes.plant.fern.v1';
  Check(not GenerateWorld(LRequest, LOther, GReason), 'Centred plant cannot seal a narrow corridor');
  LRequest := Request(Baseline, 'module-build', '');
  SelectRect(LRequest, 12, 12, 3, 3);
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Offset placement fixture generated');
  LRoot := LWorld.FComposition.FNodes[1].FId;
  LRequest := Request(LWorld, 'module-furnish', ModuleFloorId(LRoot, 13, 13));
  LRequest.FContentAsset := 'phanes.plant.fern.v1';
  LRequest.FModulePose := True;
  LRequest.FModuleX := -500;
  Check(GenerateWorld(LRequest, LOther, GReason), 'Plant accepts a tile-relative placement with a walking route');
  LIndex := TCompositionIndex.Create(LOther.FComposition.FNodes);
  try
    LAt := LIndex.Find(LRequest.FObjectId + '.furnishing');
    Check((LAt >= 0) and (LOther.FComposition.FNodes[LAt].FX = -500),
      'Chosen floor-relative furnishing offset is saved');
  finally
    LIndex.Free;
  end;
  LRequest := Request(Baseline, 'module-build', '');
  SelectRect(LRequest, 12, 12, 3, 3);
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Door sweep fixture generated');
  LRoot := LWorld.FComposition.FNodes[1].FId;
  LRequest := Request(LWorld, 'module-edge', ModuleEdgeId(LRoot, 13, 13, False));
  LRequest.FContentAsset := 'door';
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Interior passage can receive an operable door');
  LRequest := Request(LWorld, 'module-furnish', ModuleFloorId(LRoot, 13, 13));
  LRequest.FContentAsset := 'phanes.chair.sage.v1';
  Check(not GenerateWorld(LRequest, LOther, GReason),
    'Chair cannot occupy intermediate door swing even when both endpoints fit');
end;

procedure Run;
var
  LBase: TWorld;
  LWorld: TWorld;
  LOther: TWorld;
  LBad: TWorld;
  LExtended: TWorld;
  LRequest: TWorldRequest;
  LBuilding: TModularBuilding;
  LIndex: TCompositionIndex;
  LDoor: String;
  LSeam: String;
  LId: String;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  LBase := Baseline;
  AccessChecks;
  Check(ValidateWorld(LBase, GAssets, GReason), 'Baseline admitted');
  LRequest := Request(LBase, 'module-build', '');
  SelectRect(LRequest, 12, 12, 3, 3);
  Check(ValidateSelection(LRequest, GReason), 'Operation-specific 2m selection admitted');
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Actual WFC modular home generated');
  LId := LWorld.FComposition.FNodes[1].FId;
  Check(ReadModularBuilding(LWorld, LId, LBuilding, GReason), 'Decoded geometry independently admitted');
  Check(Length(LBuilding.FFloors) = 9, 'Exact painted floor footprint');
  Check(LWorld.FComposition.FRevision = 1, 'One atomic composition revision');
  Check(LWorld.FDecisions > 0, 'Generation has actual WFC choices');
  FurnishingChecks(LWorld, LId);
  for I := 0 to 4 do
  begin
    Check(Length(LWorld.FLayers[I]) = Length(LBase.FLayers[I]), 'Layer dimensions preserved');
    for J := 0 to High(LBase.FLayers[I]) do
    begin
      Check(LWorld.FLayers[I][J] = LBase.FLayers[I][J], 'Generation preserves all regional cells');
    end;
  end;
  LDoor := '';
  for I := 0 to High(LBuilding.FEdges) do
  begin
    if ModuleIsDoor(ModuleToken(LBuilding.FEdges[I].FNode.FAssetId)) then
    begin
      LDoor := LBuilding.FEdges[I].FNode.FId;
    end;
  end;
  Check(LDoor <> '', 'Exterior operable entrance exists');
  LRequest := Request(LWorld, 'module-toggle', LDoor);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Door opens as an admitted state change');
  LIndex := TCompositionIndex.Create(LOther.FComposition.FNodes);
  try
    LAt := LIndex.Find(LDoor);
    Check(Pos('door.open.', ModuleToken(LOther.FComposition.FNodes[LAt].FAssetId)) = 1,
      'Open state saved on same door identity');
  finally
    LIndex.Free;
  end;
  LRequest := Request(LOther, 'module-toggle', LDoor);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Door closes');
  LRequest := Request(LWorld, 'module-extend', LId);
  SelectRect(LRequest, 15, 12, 2, 2);
  Check(GenerateWorld(LRequest, LExtended, GReason), 'Concave extension connects to original home');
  Check(ReadModularBuilding(LExtended, LId, LBuilding, GReason), 'Irregular result admitted');
  Check(Length(LBuilding.FFloors) = 13, 'Extension adds only selected cells');
  Check(not ModuleFloorAt(LBuilding, 16, 14), 'Bounding-box void remains outside');
  LIndex := TCompositionIndex.Create(LExtended.FComposition.FNodes);
  try
    LSeam := ModuleEdgeId(LId, 15, 12, True);
    LAt := LIndex.Find(LSeam);
    Check(ModuleToken(LExtended.FComposition.FNodes[LAt].FAssetId) = 'opening',
      'Shared former boundary repaired to an actual passage');
    for I := 0 to High(LWorld.FComposition.FNodes) do
    begin
      if (LWorld.FComposition.FNodes[I].FId = ModuleEdgeId(LId, 15, 12, True)) or
        (LWorld.FComposition.FNodes[I].FId = ModuleEdgeId(LId, 15, 13, True)) then
      begin
        Continue;
      end;
      LAt := LIndex.Find(LWorld.FComposition.FNodes[I].FId);
      Check((LAt >= 0) and SameNode(LWorld.FComposition.FNodes[I], LExtended.FComposition.FNodes[LAt]),
        'Every node outside the two joining seams preserved exactly');
    end;
  finally
    LIndex.Free;
  end;
  LRequest := Request(LWorld, 'module-extend', LId);
  SelectRect(LRequest, 17, 12, 1, 1);
  Check(not GenerateWorld(LRequest, LOther, GReason), 'Disconnected extension rejects');
  LRequest := Request(LWorld, 'forest', '');
  SelectRect(LRequest, 12, 12, 1, 1);
  Check(not GenerateWorld(LRequest, LOther, GReason), '2m mask cannot authorize broad regional edits');
  LBad := LWorld;
  LBad.FComposition := CopyDocument(LWorld.FComposition);
  LIndex := TCompositionIndex.Create(LBad.FComposition.FNodes);
  try
    LAt := LIndex.Find(ModuleFloorId(LId, 12, 12));
    LBad.FComposition.FNodes[LAt].FX := LBad.FComposition.FNodes[LAt].FX + 1;
  finally
    LIndex.Free;
  end;
  Check(not ValidateWorld(LBad, GAssets, GReason), 'Forged floor alignment rejected');
  LBad := LWorld;
  LBad.FComposition := CopyDocument(LWorld.FComposition);
  SetLength(LBad.FComposition.FNodes, Length(LBad.FComposition.FNodes) - 1);
  Check(not ValidateWorld(LBad, GAssets, GReason), 'Missing shared edge rejected');
  LRequest := Request(LWorld, 'module-lock', LDoor);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Selected module can be protected');
  LRequest := Request(LOther, 'module-edge', LDoor);
  LRequest.FContentAsset := 'window';
  Check(not GenerateWorld(LRequest, LBad, GReason), 'Protected door cannot become a window');
  LRequest := Request(LOther, 'module-remove', LId);
  Check(not GenerateWorld(LRequest, LBad, GReason), 'Protected descendant prevents building removal');
  LRequest := Request(LOther, 'module-lock', LDoor);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Explicit unlock retains geometry');
  LRequest := Request(LOther, 'module-remove', LId);
  Check(GenerateWorld(LRequest, LOther, GReason), 'Unprotected complete building removes atomically');
  Check(Length(LOther.FComposition.FNodes) = 1, 'No orphan modules remain');
end;

var
  LPalette: TJSONObject;
  I: Integer;
begin
  LPalette := LoadJSON('data/palette.json');
  try
    SetLength(GAssets, LPalette.Arrays['assets'].Count);
    for I := 0 to High(GAssets) do
    begin
      GAssets[I].FId := LPalette.Arrays['assets'].Objects[I].Strings['id'];
      GAssets[I].FKind := LPalette.Arrays['assets'].Objects[I].Strings['kind'];
      GAssets[I].FTheme := LPalette.Arrays['assets'].Objects[I].Strings['theme'];
    end;
  finally
    LPalette.Free;
  end;
  Run;
  WriteLn('PASS ', GChecks, ' modular structure and preservation assertions');
end.
