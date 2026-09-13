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

unit phanes.world.validate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateWorld(const AWorld: TWorld; const AAssets: TAssets;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  phanes.catalog.regional,
  phanes.world.height,
  phanes.composition.document,
  phanes.interiors.generate;

function ValidateWorldAt(const AWorld: TWorld; const AAssets: TAssets; const AHeight: TWorldHeight;
  out AReason: String): Boolean;
var
  LLayer: Integer;
  LSize: Integer;
  LX: Integer;
  LZ: Integer;
  LIndex: Integer;
  LParent: Integer;
  LTerrain: String;
  LArchitecture: String;
  LEcology: String;
  LAppearance: String;
  LRegional: TRegionalAssetAdmission;
begin
  Result := False;
  for LIndex := 0 to High(AAssets) do
  begin
    if Pos('phanes.catalog.', AAssets[LIndex].FId) = 1 then
    begin
      if not RegionalAssetAdmission(AAssets[LIndex].FId, LRegional) or
        (AAssets[LIndex].FKind <> LRegional.FRole) or (AAssets[LIndex].FCluster <> 1) then
      begin
        AReason := 'A regional catalog item differs from its admitted role or placement count.';
        Exit;
      end;
    end;
  end;
  if not ValidateComposition(AWorld.FComposition, AReason) then
  begin
    Exit;
  end;
  AReason := 'The world composition must have its canonical root frame.';
  for LIndex := 0 to High(AWorld.FComposition.FNodes) do
  begin
    if AWorld.FComposition.FNodes[LIndex].FParentId = '' then
    begin
      if (AWorld.FComposition.FNodes[LIndex].FId <> 'world') or
        (AWorld.FComposition.FNodes[LIndex].FRole <> 'world') or
        (AWorld.FComposition.FNodes[LIndex].FX <> 0) or
        (AWorld.FComposition.FNodes[LIndex].FY <> 0) or
        (AWorld.FComposition.FNodes[LIndex].FZ <> 0) or
        (AWorld.FComposition.FNodes[LIndex].FQuarterTurn <> 0) then
      begin
        Exit;
      end;
    end;
  end;
  AReason := 'World dimensions are outside the supported working range.';
  if (AWorld.FSize < 4) or (AWorld.FSize > 48) then
  begin
    Exit;
  end;

  for LLayer := 0 to 4 do
  begin
    LSize := LayerSize(AWorld.FSize, LLayer);
    if Length(AWorld.FLayers[LLayer]) <> LSize * LSize then
    begin
      AReason := 'Incomplete ' + LayerName(LLayer) + ' output.';
      Exit;
    end;
  end;

  { This decoder checks support and cross-layer meaning directly from the
    output. It does not call the functions that construct solver rules. }
  for LIndex := 0 to AWorld.FSize * AWorld.FSize - 1 do
  begin
    LTerrain := AWorld.FLayers[0][LIndex];
    LArchitecture := AWorld.FLayers[1][LIndex];
    if (LTerrain <> 'water') and (LTerrain <> 'meadow') and
      (LTerrain <> 'forest') and (LTerrain <> 'field') and (LTerrain <> 'stone') then
    begin
      AReason := 'Unknown terrain value.';
      Exit;
    end;
    if (LArchitecture <> 'empty') and (LTerrain <> 'meadow') and
      (LTerrain <> 'field') and (LTerrain <> 'stone') then
    begin
      AReason := 'A structure has no clear, dry foundation.';
      Exit;
    end;
    LAppearance := AWorld.FLayers[3][LIndex];
    if ((LArchitecture = 'empty') and (LAppearance <> 'empty')) or
      ((LArchitecture <> 'empty') and (AssetKind(AAssets, LAppearance) <> LArchitecture)) then
    begin
      AReason := 'A building asset does not match its structural intent.';
      Exit;
    end;
    LX := LIndex mod AWorld.FSize;
    LZ := LIndex div AWorld.FSize;
    if (LArchitecture <> 'empty') and not AHeight.DryBuildingDatum(LX, LZ) then
    begin
      AReason := 'A saved building is below safe standing height. ' +
        'Its terrain label does not provide a dry floor.';
      Exit;
    end;
    if LTerrain = 'water' then
    begin
      if ((LX > 0) and (AWorld.FLayers[0][LIndex - 1] = 'forest')) or
        ((LX + 1 < AWorld.FSize) and (AWorld.FLayers[0][LIndex + 1] = 'forest')) or
        ((LZ > 0) and (AWorld.FLayers[0][LIndex - AWorld.FSize] = 'forest')) or
        ((LZ + 1 < AWorld.FSize) and (AWorld.FLayers[0][LIndex + AWorld.FSize] = 'forest')) then
      begin
        AReason := 'Forest needs a meadow transition at the water edge.';
        Exit;
      end;
    end;
  end;

  LSize := AWorld.FSize * 2;
  for LIndex := 0 to LSize * LSize - 1 do
  begin
    LX := LIndex mod LSize;
    LZ := LIndex div LSize;
    LParent := (LZ div 2) * AWorld.FSize + LX div 2;
    LTerrain := AWorld.FLayers[0][LParent];
    LEcology := AWorld.FLayers[2][LIndex];
    if LEcology <> 'empty' then
    begin
      if (LTerrain = 'water') or (AWorld.FLayers[1][LParent] <> 'empty') then
      begin
        AReason := 'Vegetation overlaps water or a building footprint.';
        Exit;
      end;
      if ((LEcology = 'wheat') and (LTerrain <> 'field')) or
        ((LEcology = 'tree') and (LTerrain <> 'forest') and (LTerrain <> 'meadow')) or
        ((LEcology = 'flowers') and (LTerrain <> 'meadow') and (LTerrain <> 'field')) then
      begin
        AReason := 'Vegetation does not match the supporting terrain.';
        Exit;
      end;
    end;
    LAppearance := AWorld.FLayers[4][LIndex];
    if ((LEcology = 'empty') and (LAppearance <> 'empty')) or
      ((LEcology <> 'empty') and (AssetKind(AAssets, LAppearance) <> LEcology)) then
    begin
      AReason := 'A nature asset does not match its ecological intent.';
      Exit;
    end;
  end;

  if not ValidateInteriors(AWorld, AReason) then
  begin
    Exit;
  end;
  AReason := 'World layers and composition passed validation.';
  Result := True;
end;

function ValidateWorld(const AWorld: TWorld; const AAssets: TAssets;
  out AReason: String): Boolean;
var
  LHeight: TWorldHeight;
begin
  Result := False;
  if not ValidateWorldHeight(AWorld, AReason) then
  begin
    Exit;
  end;
  LHeight := TWorldHeight.Create(AWorld);
  try
    Result := ValidateWorldAt(AWorld, AAssets, LHeight, AReason);
  finally
    LHeight.Free;
  end;
end;

end.
