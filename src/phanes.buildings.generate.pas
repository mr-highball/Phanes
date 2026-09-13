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
unit phanes.buildings.generate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function GenerateModularBuilding(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  SysUtils, Math, wfc, phanes.composition.types, phanes.composition.document,
  phanes.selection.grid, phanes.world.height, phanes.buildings.types,
  phanes.buildings.validate, phanes.buildings.furniture,
  phanes.composition.contents.types, phanes.composition.contents.generate;

const
  CTokens: array[0..11] of String = ('void', 'floor.oak', 'floor.stone', 'opening',
    'wall.plaster', 'wall.timber', 'window.plaster', 'window.timber',
    'door.closed.plaster', 'door.closed.timber', 'door.open.plaster', 'door.open.timber');

procedure PutNode(var ADocument: TCompositionDocument; const ANode: TCompositionNode);
var
  I: Integer;
begin
  for I := 0 to High(ADocument.FNodes) do
  begin
    if ADocument.FNodes[I].FId = ANode.FId then
    begin
      ADocument.FNodes[I] := ANode;
      Exit;
    end;
  end;
  I := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, I + 1);
  ADocument.FNodes[I] := ANode;
end;

function PopulateFloors(const ARequest: TWorldRequest; const ARoot: String;
  var AWorld: TWorld; out AReason: String): Boolean;
const
  CMixed: array[0..3] of String = ('phanes.table.oak.v1', 'phanes.chair.sage.v1',
    'phanes.shelf.oak.v1', 'plants');
var
  LIndex: TCompositionIndex;
  LFloors: TStringArray;
  LRequest: TWorldRequest;
  LTrial: TWorld;
  LId: String;
  LAt: Integer;
  LParent: Integer;
  LTarget: Integer;
  LPlaced: Integer;
  LRandom: Double;
  I: Integer;
  J: Integer;

  function NextRandom(const ALimit: Integer): Integer;
  begin
    { Exact integer arithmetic below JavaScript's 53-bit limit, shared by
      native and browser builds; never touch the application's global RNG. }
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
  AReason := 'Choose furniture to add; batch population never clears existing items.';
  if (ARequest.FContentAsset = '') or (ARequest.FContentAsset = 'empty') then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    LFloors := nil;
    for I := 0 to High(ARequest.FSelectionCells) do
    begin
      LId := ModuleFloorId(ARoot, ARequest.FSelectionCells[I] mod (ARequest.FSize * 8),
        ARequest.FSelectionCells[I] div (ARequest.FSize * 8));
      LAt := LIndex.Find(LId);
      if (LAt < 0) or (LIndex.Find(LId + '.furnishing') >= 0) then
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
  LTarget := (Length(LFloors) * ARequest.FModuleDensity + 99) div 100;
  LRandom := ARequest.FSeed;
  for I := High(LFloors) downto 1 do
  begin
    J := NextRandom(I + 1);
    LId := LFloors[I];
    LFloors[I] := LFloors[J];
    LFloors[J] := LId;
  end;
  LPlaced := 0;
  LRequest := ARequest;
  LRequest.FOperation := 'module-furnish';
  LRequest.FSelectionScale := 0;
  LRequest.FSelectionCells := nil;
  LRequest.FModulePose := True;
  LRequest.FModuleX := 0;
  LRequest.FModuleZ := 0;
  for I := 0 to High(LFloors) do
  begin
    LRequest.FPrevious := AWorld;
    LRequest.FObjectId := LFloors[I];
    LRequest.FContentAsset := ARequest.FContentAsset;
    if ARequest.FContentAsset = 'mixed' then
    begin
      LRequest.FContentAsset := CMixed[NextRandom(Length(CMixed))];
    end;
    LRequest.FModuleTurn := NextRandom(4);
    { Each candidate uses the existing furniture WFC solve and physical access
      validator. Incompatible tiles are skipped, not allowed to reject the
      whole batch. Only the final world is published, as one undo operation. }
    if GenerateModularBuilding(LRequest, LTrial, AReason) then
    begin
      AWorld := LTrial;
      AWorld.FComposition.FRevision := ARequest.FPrevious.FComposition.FRevision;
      Inc(LPlaced);
      if LPlaced = LTarget then
      begin
        Break;
      end;
    end;
  end;
  Result := LPlaced > 0;
  AReason := 'No selected empty floor can fit this furniture while keeping access clear.';
  if Result then
  begin
    AReason := 'Added ' + IntToStr(LPlaced) + ' of ' + IntToStr(LTarget) +
      ' targeted furnishings. Existing items and walking access were preserved.';
  end;
end;

function GenerateModularBuilding(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
var
  LBefore: TModularBuilding;
  LIndex: TCompositionIndex;
  LCandidate: TWorld;
  LCommitted: TCompositionDocument;
  LRoot: TCompositionNode;
  LNode: TCompositionNode;
  LBits: TSelectionBits;
  LCells: TSelectionCells;
  LId: String;
  LScope: String;
  LPopulationMessage: String;
  LToken: String;
  LMinX: Integer;
  LMinZ: Integer;
  LMaxX: Integer;
  LMaxZ: Integer;
  LSide: Integer;
  LWidth: Integer;
  LDepth: Integer;
  LX: Integer;
  LZ: Integer;
  LGX: Integer;
  LGZ: Integer;
  LAt: Integer;
  LOld: Integer;
  LCount: Integer;
  LVertical: Boolean;
  LFirst: Boolean;
  LSecond: Boolean;
  LWasBoundary: Boolean;
  LHasEntry: Boolean;
  LEntryX: Integer;
  LEntryZ: Integer;
  LHeight: TWorldHeight;
  LMinimum: Double;
  LMaximum: Double;
  LDatum: Double;
  LGraph: TGraph;
  LAllowed: TGraphValues;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LConnectivity: TGraphConnectivityValues;
  LGraphRoot: TGraphPosition;
  LContents: TContentRequest;
  I: Integer;
  J: Integer;

  function HasFloor(const AX, AZ: Integer): Boolean;
  begin
    Result := (AX >= 0) and (AZ >= 0) and (AX < LSide) and (AZ < LSide) and
      LBits[AZ * LSide + AX];
  end;

  function Compatible(const ALeft, ARight: String): Boolean;
  begin
    Result := True;
    { The stone floor uses plaster reveals; timber floor can meet either finish.
      Complete reciprocal rules keep this material relation real at every shared
      edge. Corners are inert and cannot satisfy the access graph. }
    if ((ALeft = 'floor.stone') and (Pos('.timber', ARight) > 0)) or
      ((ARight = 'floor.stone') and (Pos('.timber', ALeft) > 0)) then
    begin
      Result := False;
    end;
  end;

  function Part(const AX, AZ: Integer): TCompositionNode;
  begin
    Result := Default(TCompositionNode);
    Result.FParentId := LRoot.FId;
    Result.FSeed := ARequest.FSeed;
    if Odd(AX) and Odd(AZ) then
    begin
      Result.FId := ModuleFloorId(LRoot.FId, LMinX + AX div 2, LMinZ + AZ div 2);
      Result.FKind := ckSurface;
      Result.FRole := 'floor-tile';
      Result.FName := 'Floor';
    end
    else
    begin
      Result.FId := ModuleEdgeId(LRoot.FId, LMinX + AX div 2, LMinZ + AZ div 2, not Odd(AX));
      Result.FKind := ckObject;
      Result.FRole := 'wall-module';
      Result.FName := 'Wall';
      Result.FQuarterTurn := Ord(not Odd(AX));
    end;
    Result.FX := (LMinX * 2 + AX) * 1000 - ARequest.FSize * 8000;
    Result.FZ := (LMinZ * 2 + AZ) * 1000 - ARequest.FSize * 8000;
  end;

begin
  Result := False;
  AWorld := Default(TWorld);
  if ARequest.FPrevious.FComposition.FRevision = High(Integer) then
  begin
    AReason := 'This document has reached its revision limit.';
    Exit;
  end;
  LCandidate := ARequest.FPrevious;
  LCandidate.FDecisions := 0;
  LCandidate.FPropagations := 0;
  LCandidate.FBacktracks := 0;
  LCandidate.FComposition := CopyDocument(ARequest.FPrevious.FComposition);
  LBefore := Default(TModularBuilding);
  LSide := ARequest.FSize * 8;
  LBefore.FSide := LSide;
  LIndex := TCompositionIndex.Create(ARequest.FPrevious.FComposition.FNodes);
  try
    if ARequest.FOperation = 'module-build' then
    begin
      LRoot := Default(TCompositionNode);
      LRoot.FId := 'home-' + IntToStr(ARequest.FSelectionCells[0]);
      I := 1;
      while LIndex.Find(LRoot.FId) >= 0 do
      begin
        LRoot.FId := 'home-' + IntToStr(ARequest.FSelectionCells[0]) + '-' + IntToStr(I);
        Inc(I);
      end;
      LRoot.FParentId := 'world';
      LRoot.FKind := ckContainer;
      LRoot.FRole := 'modular-building';
      LRoot.FAssetId := ModularBuildingAsset;
      LRoot.FName := 'Home';
      LRoot.FSeed := ARequest.FSeed;
      LScope := 'world';
    end
    else
    begin
      LAt := LIndex.Find(ARequest.FObjectId);
      LId := ModularOwner(ARequest.FPrevious.FComposition, LIndex, LAt);
      if (LId = '') or not ReadModularBuilding(ARequest.FPrevious, LId, LBefore, AReason) then
      begin
        AReason := 'Select a modular building or one of its parts.';
        Exit;
      end;
      LRoot := LBefore.FRoot;
      LScope := LRoot.FId;
      if ARequest.FOperation = 'module-populate' then
      begin
        if not PopulateFloors(ARequest, LRoot.FId, LCandidate, AReason) then
        begin
          Exit;
        end;
        LPopulationMessage := AReason;
      end
      else if ARequest.FOperation = 'module-furnish' then
      begin
        if not BuildingFloorRequest(LCandidate.FComposition, ARequest.FObjectId,
          LContents, AReason, ARequest.FContentAsset) then
        begin
          Exit;
        end;
        LContents.FSeed := ARequest.FSeed;
        if ARequest.FModulePose then
        begin
          if (Abs(ARequest.FModuleX) > 750) or (Abs(ARequest.FModuleZ) > 750) or
            (ARequest.FModuleX mod 250 <> 0) or (ARequest.FModuleZ mod 250 <> 0) or
            (ARequest.FModuleTurn < 0) or (ARequest.FModuleTurn > 3) then
          begin
            AReason := 'Choose a furnishing position and rotation within this floor tile.';
            Exit;
          end;
          LContents.FSlots[0].FX := ARequest.FModuleX;
          LContents.FSlots[0].FZ := ARequest.FModuleZ;
          LContents.FSlots[0].FWidth := 2000 - Abs(ARequest.FModuleX) * 2;
          LContents.FSlots[0].FDepth := 2000 - Abs(ARequest.FModuleZ) * 2;
          LContents.FSlots[0].FQuarterTurn := ARequest.FModuleTurn;
          LContents.FAllowAssemblyMoves := True;
        end;
        if ARequest.FContentAsset = 'empty' then
        begin
          LContents.FRemovableAssemblyRoles := LContents.FSlots[0].FAllowedRoles;
          SetLength(LContents.FQuotas, Length(LContents.FSlots[0].FAllowedRoles));
          for I := 0 to High(LContents.FQuotas) do
          begin
            LContents.FQuotas[I].FRole := LContents.FSlots[0].FAllowedRoles[I];
            LContents.FQuotas[I].FMinimum := 0;
            LContents.FQuotas[I].FMaximum := 0;
          end;
        end
        else
        begin
          LContents.FSlots[0].FAllowEmpty := False;
          LContents.FSlots[0].FAllowedAssets := [ARequest.FContentAsset];
          if ARequest.FContentAsset = 'plants' then
          begin
            LContents.FSlots[0].FAllowedAssets :=
              ['phanes.plant.fern.v1', 'phanes.plant.moon.v1'];
          end;
        end;
        if not GenerateContents(LCandidate.FComposition, LContents, LCommitted, AReason) then
        begin
          Exit;
        end;
        LCandidate.FComposition := LCommitted;
        LCandidate.FComposition.FRevision := ARequest.FPrevious.FComposition.FRevision;
      end
      else if (ARequest.FOperation = 'module-edge') or (ARequest.FOperation = 'module-toggle') then
      begin
        LNode := ARequest.FPrevious.FComposition.FNodes[LAt];
        LToken := ModuleToken(LNode.FAssetId);
        AReason := 'Select a wall or door.';
        if not ModuleIsEdge(LToken) then
        begin
          Exit;
        end;
        if ARequest.FOperation = 'module-toggle' then
        begin
          AReason := 'This part is not an operable door.';
          if not ModuleIsDoor(LToken) then
          begin
            Exit;
          end;
          if Pos('door.closed.', LToken) = 1 then
          begin
            LToken := StringReplace(LToken, 'door.closed.', 'door.open.', []);
          end
          else
          begin
            LToken := StringReplace(LToken, 'door.open.', 'door.closed.', []);
          end;
        end
        else
        begin
          AReason := 'Choose a wall, window, door or passage.';
          if ARequest.FContentAsset = 'opening' then
          begin
            LToken := 'opening';
          end
          else if (ARequest.FContentAsset = 'wall') or (ARequest.FContentAsset = 'window') then
          begin
            LToken := ARequest.FContentAsset + '.plaster';
          end
          else if ARequest.FContentAsset = 'door' then
          begin
            LToken := 'door.closed.plaster';
          end
          else
          begin
            Exit;
          end;
        end;
        LNode.FAssetId := ModuleAsset(LToken);
        PutNode(LCandidate.FComposition, LNode);
      end
      else if ARequest.FOperation = 'module-lock' then
      begin
        { Lock/unlock is an explicit metadata operation on exactly one selected
          object. It cannot alter geometry or unlock a protected ancestor. }
        LNode := ARequest.FPrevious.FComposition.FNodes[LAt];
        I := LIndex.Find(LNode.FParentId);
        while I >= 0 do
        begin
          if ARequest.FPrevious.FComposition.FNodes[I].FLocked then
          begin
            AReason := 'Unlock the containing space first.';
            Exit;
          end;
          I := LIndex.Find(ARequest.FPrevious.FComposition.FNodes[I].FParentId);
        end;
        LNode.FLocked := not LNode.FLocked;
        PutNode(LCandidate.FComposition, LNode);
        if not ValidateModularBuildings(LCandidate, AReason) then
        begin
          Exit;
        end;
        Inc(LCandidate.FComposition.FRevision);
        AWorld := LCandidate;
        Exit(True);
      end
      else if ARequest.FOperation = 'module-remove' then
      begin
        LCount := 0;
        for I := 0 to High(LCandidate.FComposition.FNodes) do
        begin
          if ModularOwner(ARequest.FPrevious.FComposition, LIndex, I) <> LRoot.FId then
          begin
            LCandidate.FComposition.FNodes[LCount] := LCandidate.FComposition.FNodes[I];
            Inc(LCount);
          end;
        end;
        SetLength(LCandidate.FComposition.FNodes, LCount);
        LScope := 'world';
      end
      else if ARequest.FOperation <> 'module-extend' then
      begin
        AReason := 'Choose a supported modular edit.';
        Exit;
      end;
    end;

    if (ARequest.FOperation = 'module-build') or (ARequest.FOperation = 'module-extend') then
    begin
      SetLength(LBits, Sqr(LSide));
      for I := 0 to High(LBefore.FFloors) do
      begin
        LBits[LBefore.FFloors[I]] := True;
      end;
      for I := 0 to High(ARequest.FSelectionCells) do
      begin
        LBits[ARequest.FSelectionCells[I]] := True;
      end;
      LCells := SelectionCells(LBits);
      LMinX := LSide;
      LMinZ := LSide;
      LMaxX := -1;
      LMaxZ := -1;
      for I := 0 to High(LCells) do
      begin
        LMinX := Min(LMinX, LCells[I] mod LSide);
        LMaxX := Max(LMaxX, LCells[I] mod LSide);
        LMinZ := Min(LMinZ, LCells[I] div LSide);
        LMaxZ := Max(LMaxZ, LCells[I] div LSide);
      end;
      AReason := 'Choose up to 256 floor tiles within a 64 metre span for one building.';
      if (Length(LCells) = 0) or (Length(LCells) > ModuleMaximumFloors) or
        (LMaxX - LMinX >= ModuleMaximumSide) or (LMaxZ - LMinZ >= ModuleMaximumSide) then
      begin
        Exit;
      end;
      if ARequest.FOperation = 'module-build' then
      begin
        LHeight := TWorldHeight.Create(ARequest.FPrevious);
        try
          LDatum := -1E20;
          for I := 0 to High(LCells) do
          begin
            LX := LCells[I] mod LSide;
            LZ := LCells[I] div LSide;
            LHeight.Bounds(LX * 2 - ARequest.FSize * 8, LZ * 2 - ARequest.FSize * 8,
              LX * 2 + 2 - ARequest.FSize * 8, LZ * 2 + 2 - ARequest.FSize * 8,
              LMinimum, LMaximum);
            LDatum := Max(LDatum, LMaximum);
          end;
          LRoot.FY := Ceil((LDatum + 0.18) * 1000);
        finally
          LHeight.Free;
        end;
        PutNode(LCandidate.FComposition, LRoot);
      end;
      LWidth := (LMaxX - LMinX + 1) * 2 + 1;
      LDepth := (LMaxZ - LMinZ + 1) * 2 + 1;
      LGraph := TGraph.Create;
      try
        { Odd/odd cells are real 2 m floor modules. Mixed-parity cells are their
          ONE shared wall/door/window edge; even/even corners are inert.
          Painted floors and existing modules are exact caller domains. The
          only automatic repair is an unlocked former perimeter edge joining
          an extension; that shared seam becomes a passage. }
        LGraph.Reshape(LWidth, LDepth, 1);
        LGraph.Seed := ARequest.FSeed;
        LGraph.WrapNeighbors := False;
        LGraph.PassMode := gpmOverlay;
        for I := 0 to High(CTokens) do
        begin
          LGraph.AddValue(CTokens[I]);
        end;
        for I := 0 to High(CTokens) do
        begin
          for J := 0 to High(CTokens) do
          begin
            if Compatible(CTokens[I], CTokens[J]) then
            begin
              LGraph.Rules[CTokens[I]].NewRule([gdNorth, gdEast, gdSouth, gdWest], CTokens[J]);
            end;
          end;
        end;
        LHasEntry := False;
        LEntryX := -1;
        LEntryZ := -1;
        for LGZ := 0 to LDepth - 1 do
        begin
          for LGX := 0 to LWidth - 1 do
          begin
            LAllowed := ['void'];
            LX := LMinX + LGX div 2;
            LZ := LMinZ + LGZ div 2;
            LNode := Part(LGX, LGZ);
            LOld := LIndex.Find(LNode.FId);
            if Odd(LGX) and Odd(LGZ) then
            begin
              if HasFloor(LX, LZ) then
              begin
                LAllowed := ['floor.oak', 'floor.stone'];
                if LOld >= 0 then
                begin
                  LAllowed := [ModuleToken(ARequest.FPrevious.FComposition.FNodes[LOld].FAssetId)];
                end;
              end;
            end
            else if Odd(LGX) <> Odd(LGZ) then
            begin
              LVertical := not Odd(LGX);
              LFirst := HasFloor(LX, LZ);
              LSecond := HasFloor(LX - Ord(LVertical), LZ - Ord(not LVertical));
              if LFirst or LSecond then
              begin
                LAllowed := ['wall.plaster', 'wall.timber', 'window.plaster', 'window.timber'];
                if LFirst and LSecond then
                begin
                  LAllowed := ['opening'];
                end;
                if LOld >= 0 then
                begin
                  LWasBoundary := ModuleFloorAt(LBefore, LX, LZ) <>
                    ModuleFloorAt(LBefore, LX - Ord(LVertical), LZ - Ord(not LVertical));
                  if not (LWasBoundary and LFirst and LSecond) or
                    ARequest.FPrevious.FComposition.FNodes[LOld].FLocked then
                  begin
                    LAllowed := [ModuleToken(ARequest.FPrevious.FComposition.FNodes[LOld].FAssetId)];
                  end;
                  if (LFirst <> LSecond) and ModuleIsPassage(LAllowed[0]) then
                  begin
                    LHasEntry := True;
                  end;
                end
                else if (LFirst <> LSecond) and (LEntryX < 0) and
                  (LNode.FX > -ARequest.FSize * 8000 + 6000) and
                  (LNode.FX < ARequest.FSize * 8000 - 6000) and
                  (LNode.FZ > -ARequest.FSize * 8000 + 6000) and
                  (LNode.FZ < ARequest.FSize * 8000 - 6000) then
                begin
                  LEntryX := LGX;
                  LEntryZ := LGZ;
                end;
              end;
            end;
            LGraph.SetAllowedValues(LGX, LGZ, 0, LAllowed);
          end;
        end;
        if not LHasEntry then
        begin
          AReason := 'Preserved walls leave no place for an exterior entrance. Select a wall for a door.';
          if LEntryX < 0 then
          begin
            Exit;
          end;
          LGraph.SetAllowedValues(LEntryX, LEntryZ, 0, ['door.closed.plaster']);
        end;
        LGraphRoot.X := (LCells[0] mod LSide - LMinX) * 2 + 1;
        LGraphRoot.Y := (LCells[0] div LSide - LMinZ) * 2 + 1;
        LGraphRoot.Z := 0;
        LConnectivity := nil;
        for I := 0 to High(CTokens) do
        begin
          if ModuleIsFloor(CTokens[I]) or ModuleIsPassage(CTokens[I]) then
          begin
            LCount := Length(LConnectivity);
            SetLength(LConnectivity, LCount + 1);
            LConnectivity[LCount] := MakeGraphConnectivityValue(CTokens[I],
              [gdNorth, gdEast, gdSouth, gdWest], ModuleIsFloor(CTokens[I]));
          end;
        end;
        LGraph.RequireConnectivity(MakeGraphConnectivityConstraint('all-floor-access',
          LGraphRoot, [], LConnectivity, False));
        if ARequest.FOperation = 'module-build' then
        begin
          LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('daylight',
            ['window.plaster', 'window.timber'], 1, ModuleMaximumFloors * 4));
        end;
        LOptions := DefaultGraphSolveOptions;
        LOptions.MaxBacktracks := 20000;
        if not LGraph.TrySolve(LOptions, LReport) then
        begin
          AReason := 'The selected floors and protected walls did not resolve within the search limit. ' +
            'Join the painted area to the building or make a doorway through its boundary.';
          Exit;
        end;
        for LGZ := 0 to LDepth - 1 do
        begin
          for LGX := 0 to LWidth - 1 do
          begin
            LToken := LGraph.Entry[LGX, LGZ, 0].Value;
            if LToken = 'void' then
            begin
              Continue;
            end;
            LNode := Part(LGX, LGZ);
            LOld := LIndex.Find(LNode.FId);
            if LOld >= 0 then
            begin
              LNode := ARequest.FPrevious.FComposition.FNodes[LOld];
            end;
            LNode.FAssetId := ModuleAsset(LToken);
            PutNode(LCandidate.FComposition, LNode);
          end;
        end;
        for I := 0 to High(LReport.Passes) do
        begin
          Inc(LCandidate.FDecisions, LReport.Passes[I].Decisions);
          Inc(LCandidate.FPropagations, LReport.Passes[I].Propagations);
          Inc(LCandidate.FBacktracks, LReport.Passes[I].Backtracks);
        end;
      finally
        LGraph.Free;
      end;
    end;
    if not ValidateModularBuildings(LCandidate, AReason) or
      not CommitComposition(ARequest.FPrevious.FComposition, LCandidate.FComposition,
        LScope, ARequest.FPrevious.FComposition.FRevision, LCommitted, AReason) then
    begin
      Exit;
    end;
    LCandidate.FComposition := LCommitted;
    LCandidate.FSeed := ARequest.FSeed;
    AWorld := LCandidate;
    Result := True;
    if ARequest.FOperation = 'module-populate' then
    begin
      AReason := LPopulationMessage;
    end;
  finally
    LIndex.Free;
  end;
end;

end.
