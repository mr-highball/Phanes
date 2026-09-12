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

unit phanes.world.generate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function GenerateWorld(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  wfc,
  wfc_lattice,
  phanes.composition.types,
  phanes.interiors.generate,
  phanes.groundworks.generate,
  phanes.structures.generate,
  phanes.buildings.types,
  phanes.buildings.generate,
  phanes.landforms.world,
  phanes.landforms.types,
  phanes.spaces.world,
  phanes.world.elevation,
  phanes.world.selection,
  phanes.world.edit.validate,
  phanes.world.height,
  phanes.terrain.types,
  phanes.world.validate;

procedure AddEcology(const AGraph: TGraph; const AKind: String;
  const AWeight: Integer; const ATerrain: TGraphValues);
begin
  AGraph.AddValue(AKind, AWeight)
    .RequireMappedFromPass('terrain', MakeGraphPassCellQuery(ATerrain))
    .RequireMappedFromPass('architecture', MakeGraphPassCellQuery(['empty']));
end;

procedure DefinePasses(const AGraph: TGraph; const ARequest: TWorldRequest);
var
  LLayouts: TWfcLatticeLayouts;
  LLayer: Integer;
  LSize: Integer;
  LPitch: Integer;
  LAsset: TAsset;
  LBuilding: Boolean;
begin
  { Terrain cells span 8 x 8 world units. Architecture reads the whole cell.
    Ecology has four 4 x 4 cells inside each terrain cell. The last two passes
    choose real kit objects consistent with those structural/ecological roles.
    All constraints here are authored, not learned from the downloaded art. }
  AGraph.CurrentPass := 'terrain';
  AGraph.PassMode := gpmOverlay;
  AGraph.AddValue('meadow', 10).NewRule([gdNorth, gdEast, gdSouth, gdWest],
    ['water', 'meadow', 'forest', 'field', 'stone']);
  AGraph.AddValue('forest', 5).NewRule([gdNorth, gdEast, gdSouth, gdWest],
    ['forest', 'meadow', 'field', 'stone']);
  AGraph.AddValue('water', 1).NewRule([gdNorth, gdEast, gdSouth, gdWest],
    ['water', 'meadow', 'field', 'stone']);
  AGraph.AddValue('field', 2).NewRule([gdNorth, gdEast, gdSouth, gdWest],
    ['water', 'meadow', 'forest', 'field', 'stone']);
  AGraph.AddValue('stone', 1).NewRule([gdNorth, gdEast, gdSouth, gdWest],
    ['water', 'meadow', 'forest', 'field', 'stone']);

  AGraph.SwitchToPass('architecture');
  AGraph.PassMode := gpmOverlay;
  AGraph.AddValue('empty', 65);
  for LAsset in ARequest.FAssets do
  begin
    LBuilding := (LAsset.FKind = 'cabin') or (LAsset.FKind = 'castle') or
      (LAsset.FKind = 'modern') or (LAsset.FKind = 'scifi');
    if LBuilding then
    begin
      AGraph.AddValue(LAsset.FKind, 2)
        .RequireMappedFromPass('terrain', MakeGraphPassCellQuery(['meadow', 'field', 'stone']));
    end;
  end;

  AGraph.SwitchToPass('ecology');
  AGraph.PassMode := gpmOverlay;
  AGraph.AddValue('empty', 5);
  AddEcology(AGraph, 'tree', 8, ['forest', 'meadow']);
  AddEcology(AGraph, 'shrub', 4, ['forest', 'meadow', 'field', 'stone']);
  AddEcology(AGraph, 'flowers', 5, ['meadow', 'field']);
  AddEcology(AGraph, 'rock', 2, ['forest', 'meadow', 'field', 'stone']);
  AddEcology(AGraph, 'wheat', 8, ['field']);

  for LLayer := 3 to 4 do
  begin
    AGraph.SwitchToPass(LayerName(LLayer));
    AGraph.PassMode := gpmOverlay;
    if LLayer = 3 then
    begin
      AGraph.AddValue('empty').RequireMappedFromPass('architecture',
        MakeGraphPassCellQuery(['empty']));
    end
    else
    begin
      AGraph.AddValue('empty').RequireMappedFromPass('ecology',
        MakeGraphPassCellQuery(['empty']));
    end;
    for LAsset in ARequest.FAssets do
    begin
      { The first world uses the already downloaded core kit. Explicit regional
        edits can choose the expanded catalog and prepare its sources on demand. }
      if (ARequest.FOperation = 'create') and (Pos('phanes.catalog.', LAsset.FId) = 1) then
      begin
        Continue;
      end;
      LBuilding := (LAsset.FKind = 'cabin') or (LAsset.FKind = 'castle') or
        (LAsset.FKind = 'modern') or (LAsset.FKind = 'scifi');
      if LBuilding = (LLayer = 3) then
      begin
        if LLayer = 3 then
        begin
          AGraph.AddValue(LAsset.FId).RequireMappedFromPass('architecture',
            MakeGraphPassCellQuery([LAsset.FKind]));
        end
        else
        begin
          AGraph.AddValue(LAsset.FId).RequireMappedFromPass('ecology',
            MakeGraphPassCellQuery([LAsset.FKind]));
        end;
      end;
    end;
  end;

  SetLength(LLayouts, 5);
  for LLayer := 0 to 4 do
  begin
    LSize := LayerSize(ARequest.FSize, LLayer);
    LPitch := 8;
    if (LLayer = 2) or (LLayer = 4) then
    begin
      LPitch := 4;
    end;
    LLayouts[LLayer] := MakeWfcLatticeLayout(LSize, LSize, 1,
      MakeWfcLatticeVector(0, 0, 0), MakeWfcLatticeVector(LPitch, LPitch, 1), False);
  end;
  AGraph.ConfigurePassLayouts(LLayouts);
end;

procedure ApplyIntent(const AGraph: TGraph; const ARequest: TWorldRequest;
  const AHeight: TWorldHeight);
var
  LLayer: Integer;
  LX: Integer;
  LZ: Integer;
  LSize: Integer;
  LPass: TGraph;
  LOperation: String;
  LHasPrevious: Boolean;
  LInSelection: Boolean;
  LChoices: TGraphValues;
  I: Integer;
begin
  LHasPrevious := ARequest.FPrevious.FSize = ARequest.FSize;
  LOperation := ARequest.FOperation;
  if LOperation = 'asset' then
  begin
    LOperation := AssetKind(ARequest.FAssets, ARequest.FExactAsset);
  end;
  SetLength(LChoices, Length(ARequest.FAssetChoices));
  for I := 0 to High(LChoices) do
  begin
    LChoices[I] := ARequest.FAssetChoices[I];
  end;
  for LLayer := 0 to 4 do
  begin
    LPass := AGraph.PassGraph[LLayer];
    LSize := LayerSize(ARequest.FSize, LLayer);
    for LZ := 0 to LSize - 1 do
    begin
      for LX := 0 to LSize - 1 do
      begin
        LInSelection := SelectedCell(ARequest, LLayer, LX, LZ);
        if LHasPrevious and not LInSelection then
        begin
          { Outside the requested region every pass is an exact caller domain.
            Failed edits are discarded by the owner; the baseline is untouched. }
          LPass.SetAllowedValues(LX, LZ, 0, ARequest.FPrevious.FLayers[LLayer][LZ * LSize + LX]);
          Continue;
        end;
        if LLayer = 0 then
        begin
          if LHasPrevious and (LOperation = 'reimagine') then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, ARequest.FPrevious.FLayers[0][LZ * LSize + LX]);
          end
          else if (LOperation = 'forest') or (LOperation = 'water') or
            (LOperation = 'field') or (LOperation = 'stone') then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, LOperation);
          end
          else if LOperation <> 'create' then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'meadow');
          end
          else if (LX = 0) or (LZ = 0) or (LX = LSize - 1) or (LZ = LSize - 1) then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'water');
          end
          else if (LX = 1) or (LZ = 1) or (LX = LSize - 2) or (LZ = LSize - 2) then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'meadow');
          end
          else if LX < LSize div 3 then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, ['forest', 'meadow']);
          end
          else
          begin
            LPass.SetAllowedValues(LX, LZ, 0, ['meadow', 'field', 'stone']);
          end;
        end;
        if LLayer = 1 then
        begin
          if not AHeight.DryBuildingDatum(LX, LZ) then
          begin
            { Apply physical admissibility as a caller domain before search.
              Explicit building requests are checked before graph construction. }
            LPass.SetAllowedValues(LX, LZ, 0, 'empty');
            Continue;
          end;
          if LOperation = 'rocket' then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'scifi');
          end
          else if (LOperation = 'cabin') or (LOperation = 'castle') or
            (LOperation = 'modern') or (LOperation = 'scifi') then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, LOperation);
          end
          else if (LOperation <> 'create') and (LOperation <> 'reimagine') then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'empty');
          end;
        end;
        if LLayer = 2 then
        begin
          if (LOperation = 'tree') or (LOperation = 'shrub') or
            (LOperation = 'rock') or (LOperation = 'wheat') then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, LOperation);
          end
          else if LOperation = 'forest' then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, ['tree', 'shrub']);
          end
          else if LOperation = 'flowers' then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'flowers');
          end
          else if LOperation = 'field' then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, ['wheat', 'flowers']);
          end
          else if (LOperation = 'clear') or IsGroundworkCreation(LOperation) then
          begin
            LPass.SetAllowedValues(LX, LZ, 0, 'empty');
          end;
        end;
        if (LLayer = 3) and (LOperation = 'rocket') then
        begin
          LPass.SetAllowedValues(LX, LZ, 0, 'rocket');
        end;
        if (ARequest.FExactAsset <> '') and
          (((LLayer = 3) and (ARequest.FEditLayer = 'buildings')) or
           ((LLayer = 4) and (ARequest.FEditLayer = 'foliage'))) then
        begin
          LPass.SetAllowedValues(LX, LZ, 0, ARequest.FExactAsset);
        end;
        if (Length(LChoices) > 0) and
          (((LLayer = 3) and (ARequest.FEditLayer = 'buildings')) or
           ((LLayer = 4) and (ARequest.FEditLayer = 'foliage'))) then
        begin
          LPass.SetAllowedValues(LX, LZ, 0, LChoices);
        end;
      end;
    end;
  end;
end;

function GenerateWorldAt(const ARequest: TWorldRequest; const AHeight: TWorldHeight;
  const AHeightContext: TWorld; out AWorld: TWorld; out AReason: String): Boolean;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LLayer: Integer;
  LSize: Integer;
  LX: Integer;
  LZ: Integer;
begin
  AWorld := Default(TWorld);
  Result := False;
  if (ARequest.FOperation <> 'create') and (ARequest.FOperation <> 'restore') and
    (ARequest.FOperation <> 'reimagine') and (ARequest.FOperation <> 'clear') and
    (ARequest.FOperation <> 'forest') and (ARequest.FOperation <> 'flowers') and
    (ARequest.FOperation <> 'field') and (ARequest.FOperation <> 'water') and
    (ARequest.FOperation <> 'meadow') and (ARequest.FOperation <> 'stone') and
    (ARequest.FOperation <> 'tree') and (ARequest.FOperation <> 'shrub') and
    (ARequest.FOperation <> 'rock') and (ARequest.FOperation <> 'wheat') and
    (ARequest.FOperation <> 'asset') and
    (ARequest.FOperation <> 'cabin') and (ARequest.FOperation <> 'castle') and
    (ARequest.FOperation <> 'modern') and (ARequest.FOperation <> 'scifi') and
    (ARequest.FOperation <> 'rocket') and
    (ARequest.FOperation <> 'place-building') and (ARequest.FOperation <> 'remove-building') and
    (ARequest.FOperation <> 'create-interior') and (ARequest.FOperation <> 'contents') and
    not IsGroundworkCreation(ARequest.FOperation) and (ARequest.FOperation <> 'groundwork') and
    not IsSpaceOperation(ARequest.FOperation) and not IsBuildingOperation(ARequest.FOperation) and
    not IsLandformOperation(ARequest.FOperation) then
  begin
    AReason := 'Choose a supported world operation.';
    Exit;
  end;
  if (ARequest.FSize < 4) or (ARequest.FSize > 48) then
  begin
    AReason := 'Choose a working region between 4 and 48 cells per side.';
    Exit;
  end;
  if (ARequest.FX < 0) or (ARequest.FZ < 0) or (ARequest.FWidth < 1) or
    (ARequest.FDepth < 1) or (ARequest.FWidth > ARequest.FSize) or
    (ARequest.FDepth > ARequest.FSize) or (ARequest.FX > ARequest.FSize - ARequest.FWidth) or
    (ARequest.FZ > ARequest.FSize - ARequest.FDepth) then
  begin
    AReason := 'The selection must fit inside the world.';
    Exit;
  end;
  if ARequest.FPrevious.FSize <> 0 then
  begin
    if not ValidateWorld(ARequest.FPrevious, ARequest.FAssets, AReason) then
    begin
      Exit;
    end;
  end;
  if not ValidateSelection(ARequest, AReason) then
  begin
    Exit;
  end;

  if IsLandformOperation(ARequest.FOperation) then
  begin
    Result := GenerateLandform(ARequest, AWorld, AReason);
    Exit;
  end;

  if IsBuildingOperation(ARequest.FOperation) then
  begin
    if ARequest.FPrevious.FSize <> ARequest.FSize then
    begin
      AReason := 'Create a world before drawing a building.';
      Exit;
    end;
    Result := GenerateModularBuilding(ARequest, AWorld, AReason) and
      ValidateWorld(AWorld, ARequest.FAssets, AReason);
    Exit;
  end;

  if ARequest.FOperation = 'restore' then
  begin
    AReason := 'Choose a saved world with matching dimensions to restore.';
    if ARequest.FPrevious.FSize = ARequest.FSize then
    begin
      AWorld := ARequest.FPrevious;
      Result := True;
      AReason := 'Saved world validated and restored exactly.';
    end;
    Exit;
  end;

  if IsGroundworkCreation(ARequest.FOperation) or (ARequest.FOperation = 'groundwork') then
  begin
    if ARequest.FPrevious.FSize <> ARequest.FSize then
    begin
      AReason := 'Create a world before adding or editing groundworks.';
      Exit;
    end;
    if IsGroundworkCreation(ARequest.FOperation) and
      ((ARequest.FWidth <> 2) or (ARequest.FDepth <> 2) or
       (SelectedRegionCount(ARequest, ARequest.FX, ARequest.FZ, 2, 2) <> 4)) then
    begin
      AReason := 'Select a complete 2 x 2 plot for this groundwork.';
      Exit;
    end;
    if ARequest.FOperation = 'groundwork' then
    begin
      Result := EditGroundwork(ARequest, AWorld, AReason) and
        ValidateWorld(AWorld, ARequest.FAssets, AReason);
      Exit;
    end;
  end;

  if (ARequest.FOperation = 'place-building') or (ARequest.FOperation = 'remove-building') then
  begin
    if ARequest.FPrevious.FSize <> ARequest.FSize then
    begin
      AReason := 'Create a world and plot before placing a building.';
      Exit;
    end;
    Result := EditSupportedBuilding(ARequest, AWorld, AReason) and
      ValidateWorld(AWorld, ARequest.FAssets, AReason);
    Exit;
  end;

  if IsSpaceOperation(ARequest.FOperation) then
  begin
    if ARequest.FPrevious.FSize <> ARequest.FSize then
    begin
      AReason := 'Create a world before shaping its rooms.';
      Exit;
    end;
    Result := EditSpaces(ARequest, AWorld, AReason);
    Exit;
  end;

  if (ARequest.FOperation = 'create-interior') or (ARequest.FOperation = 'contents') then
  begin
    if ARequest.FPrevious.FSize <> ARequest.FSize then
    begin
      AReason := 'Create a world before furnishing an interior.';
      Exit;
    end;
    Result := GenerateInterior(ARequest, AWorld, AReason) and
      ValidateWorld(AWorld, ARequest.FAssets, AReason);
    Exit;
  end;

  if (ARequest.FOperation = 'cabin') or (ARequest.FOperation = 'castle') or
    (ARequest.FOperation = 'modern') or (ARequest.FOperation = 'scifi') or
    (ARequest.FOperation = 'rocket') or (ARequest.FEditLayer = 'buildings') then
  begin
    for LZ := ARequest.FZ to ARequest.FZ + ARequest.FDepth - 1 do
    begin
      for LX := ARequest.FX to ARequest.FX + ARequest.FWidth - 1 do
      begin
        if SelectedCell(ARequest, 1, LX, LZ) and not AHeight.DryBuildingDatum(LX, LZ) then
        begin
          AReason := 'Part of this selection is below safe building height. ' +
            'Choose higher ground or a smaller selection. Your world is unchanged.';
          Exit;
        end;
      end;
    end;
  end;

  LGraph := TGraph.Create;
  try
    LGraph.Seed := ARequest.FSeed;
    LGraph.Reshape(ARequest.FSize, ARequest.FSize, 1);
    DefinePasses(LGraph, ARequest);
    ApplyIntent(LGraph, ARequest, AHeight);
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 256;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'The selection could not satisfy the ' + LayerName(LReport.FailedPassIndex) +
        ' constraints within this search. ' +
        'Try a larger region or leave a meadow transition beside water. Your world is unchanged.';
      Exit;
    end;
    AWorld.FSize := ARequest.FSize;
    AWorld.FSeed := ARequest.FSeed;
    AWorld.FAppearanceSeed := ARequest.FSeed;
    AWorld.FElevation := CopyTerrainField(AHeightContext.FElevation);
    AWorld.FRelativeElevation := AHeightContext.FRelativeElevation;
    if ARequest.FPrevious.FSize = ARequest.FSize then
    begin
      AWorld.FAppearanceSeed := ARequest.FPrevious.FAppearanceSeed;
    end
    else
    begin
      AWorld.FDecisions := AWorld.FElevation.FDecisions;
      AWorld.FPropagations := AWorld.FElevation.FPropagations;
      AWorld.FBacktracks := AWorld.FElevation.FBacktracks;
    end;
    AWorld.FComposition := InitialWorldComposition(ARequest.FSeed);
    if ARequest.FPrevious.FSize = ARequest.FSize then
    begin
      AWorld.FComposition := CopyDocument(ARequest.FPrevious.FComposition);
    end;
    for LLayer := 0 to 4 do
    begin
      LSize := LayerSize(ARequest.FSize, LLayer);
      SetLength(AWorld.FLayers[LLayer], LSize * LSize);
      for LZ := 0 to LSize - 1 do
      begin
        for LX := 0 to LSize - 1 do
        begin
          AWorld.FLayers[LLayer][LZ * LSize + LX] := LGraph.PassGraph[LLayer].Entry[LX, LZ, 0].Value;
        end;
      end;
      Inc(AWorld.FDecisions, LReport.Passes[LLayer].Decisions);
      Inc(AWorld.FPropagations, LReport.Passes[LLayer].Propagations);
      Inc(AWorld.FBacktracks, LReport.Passes[LLayer].Backtracks);
    end;
    if (ARequest.FPrevious.FSize = ARequest.FSize) and
      not ReconcileInteriors(ARequest, AWorld, AReason) then
    begin
      Exit;
    end;
    if IsGroundworkCreation(ARequest.FOperation) and
      not AttachGroundwork(ARequest, AWorld, AReason) then
    begin
      Exit;
    end;
    Result := ValidateWorld(AWorld, ARequest.FAssets, AReason);
    if Result and (ARequest.FPrevious.FSize = ARequest.FSize) and
      not IsGroundworkCreation(ARequest.FOperation) then
    begin
      Result := ValidateRegionalEdit(ARequest, AWorld, AReason);
    end;
  finally
    LGraph.Free;
  end;
end;

function GenerateWorld(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
var
  LContext: TWorld;
  LHeight: TWorldHeight;
begin
  Result := False;
  AWorld := Default(TWorld);
  LContext := Default(TWorld);
  LContext.FSize := ARequest.FSize;
  if ARequest.FPrevious.FSize = ARequest.FSize then
  begin
    LContext.FElevation := ARequest.FPrevious.FElevation;
    LContext.FRelativeElevation := ARequest.FPrevious.FRelativeElevation;
  end
  else if (ARequest.FOperation = 'create') and (ARequest.FPrevious.FSize = 0) then
  begin
    if not GenerateInitialLandform(ARequest.FSize, ARequest.FSeed,
      LContext.FElevation, AReason) then
    begin
      Exit;
    end;
  end;
  if not ValidateWorldHeight(LContext, AReason) then
  begin
    Exit;
  end;
  LHeight := TWorldHeight.Create(LContext);
  try
    Result := GenerateWorldAt(ARequest, LHeight, LContext, AWorld, AReason);
  finally
    LHeight.Free;
  end;
end;

end.
