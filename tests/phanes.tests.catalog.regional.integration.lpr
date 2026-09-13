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
program PhanesCatalogRegionalIntegration;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, FPJSON, phanes.tools.files, phanes.catalog.regional,
  phanes.catalog.admission, phanes.interiors.catalog, phanes.world.types,
  phanes.world.generate, phanes.world.validate, phanes.world.placement;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LPalette: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIds: TRegionalAssetIds;
  LProfile: TRegionalAssetAdmission;
  LOptional: TOptionalAssetAdmission;
  LInterior: TInteriorAsset;
  LRequest: TWorldRequest;
  LWorld: TWorld;
  LBad: TWorld;
  LReason: String;
  LHalfX: Double;
  LHalfZ: Double;
  LRadius: Double;
  LCell: Integer;
  LCrops: Integer;
  LOther: Integer;
  LFound: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LRequest := Default(TWorldRequest);
  LRequest.FSize := 4;
  LRequest.FSeed := 117;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  LRequest.FOperation := 'create';
  LPalette := LoadJSON('data/palette.json');
  try
    LRows := LPalette.Arrays['assets'];
    SetLength(LRequest.FAssets, LRows.Count);
    for I := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Objects[I];
      LRequest.FAssets[I].FId := LRow.Strings['id'];
      LRequest.FAssets[I].FKind := LRow.Strings['kind'];
      LRequest.FAssets[I].FTheme := LRow.Strings['theme'];
      LRequest.FAssets[I].FCluster := LRow.Get('cluster', 1);
    end;
    Check(GenerateWorld(LRequest, LWorld, LReason), 'Core-first creation: ' + LReason);
    for I := 0 to High(LWorld.FLayers[4]) do
    begin
      Check(Pos('phanes.catalog.', LWorld.FLayers[4][I]) <> 1,
        'Fresh world does not require optional downloads');
    end;

    LWorld := Default(TWorld);
    LWorld.FSize := 4;
    LWorld.FSeed := 117;
    LWorld.FComposition := InitialWorldComposition(117);
    for I := 0 to 4 do
    begin
      SetLength(LWorld.FLayers[I], Sqr(LayerSize(4, I)));
      for J := 0 to High(LWorld.FLayers[I]) do
      begin
        LWorld.FLayers[I][J] := 'empty';
        if I = 0 then
        begin
          LWorld.FLayers[I][J] := 'meadow';
        end;
      end;
    end;
    LWorld.FLayers[0][12] := 'field';
    LWorld.FLayers[0][13] := 'field';
    LWorld.FLayers[0][14] := 'field';
    Check(ValidateWorld(LWorld, LRequest.FAssets, LReason), 'Fixture baseline: ' + LReason);
    LIds := RegionalAssetIds;
    Check(Length(LIds) = 18, 'The curated regional batch contains eighteen models');
    LCrops := 0;
    LOther := 0;
    for I := 0 to High(LIds) do
    begin
      Check(RegionalAssetAdmission(LIds[I], LProfile), 'Regional profile exists');
      Check(OptionalAssetAdmission(LIds[I], LOptional) and
        (LOptional.FDomain = oadRegional), 'Runtime admission retains regional domain');
      Check(not InteriorAsset(LIds[I], LInterior), 'Regional model cannot become a shelf object');
      LFound := 0;
      for J := 0 to LRows.Count - 1 do
      begin
        LRow := LRows.Objects[J];
        if LRow.Strings['id'] = LIds[I] then
        begin
          Inc(LFound);
          Check((LRow.Strings['kind'] = LProfile.FRole) and
            (LRow.Strings['theme'] = LProfile.FTheme) and (LRow.Get('cluster', 1) = 1),
            'Palette role/theme/count match measured profile');
          Check(Abs(LRow.Floats['width'] - Max(LProfile.FWidth, LProfile.FDepth) / 2000) < 0.00001,
            'Palette width documents the physical envelope in logical units');
        end;
      end;
      Check(LFound = 1, 'Each regional model has one discoverable palette entry');
      LRadius := Sqrt(Sqr(LProfile.FWidth / 2000) + Sqr(LProfile.FDepth / 2000));
      Check(LRadius * 1.15 < 4, 'Full horizontal envelope fits ecological clearance at maximum jitter');
      if LProfile.FRole = 'tree' then
      begin
        Check(TreeCollisionRadius(LIds[I]) + 1e-9 >= LRadius,
          'Tree collision includes the complete rotated envelope');
      end;
      if LProfile.FRole = 'rock' then
      begin
        Check(RockFootprint(LIds[I], LHalfX, LHalfZ) and
          (Abs(LHalfX * 2000 - LProfile.FWidth) < 1e-6) and
          (Abs(LHalfZ * 2000 - LProfile.FDepth) < 1e-6),
          'Rock collision encloses measured bounds');
        for J := 0 to 123 do
        begin
          Check(RockBlocks(LIds[I], J, 0, 0, 0.3), 'Every rock yaw/jitter blocks its center');
          Check(not RockBlocks(LIds[I], J, 4, 4, 0.3), 'Rock collision leaves neighboring clearance');
        end;
      end;
      if LProfile.FRole = 'wheat' then
      begin
        LCell := 56 + LCrops * 2;
        Inc(LCrops);
      end
      else
      begin
        LCell := LOther;
        Inc(LOther);
      end;
      LRequest.FPrevious := LWorld;
      LRequest.FOperation := 'asset';
      LRequest.FExactAsset := LIds[I];
      LRequest.FEditLayer := 'foliage';
      LRequest.FSelectionScale := 2;
      SetLength(LRequest.FSelectionCells, 1);
      LRequest.FSelectionCells[0] := LCell;
      LRequest.FX := LCell mod 8 div 2;
      LRequest.FZ := LCell div 8 div 2;
      LRequest.FWidth := 1;
      LRequest.FDepth := 1;
      Inc(LRequest.FSeed);
      Check(GenerateWorld(LRequest, LWorld, LReason), LIds[I] + ': ' + LReason);
      Check((LWorld.FLayers[4][LCell] = LIds[I]) and
        (LWorld.FLayers[2][LCell] = LProfile.FRole), 'Exact WFC edit places the selected model and role');
      for J := 0 to 4 do
      begin
        for K := 0 to High(LWorld.FLayers[J]) do
        begin
          if ((J <> 2) and (J <> 4)) or (K <> LCell) then
          begin
            Check(LWorld.FLayers[J][K] = LRequest.FPrevious.FLayers[J][K],
              'Exact edit preserves every unaffected layer and cell');
          end;
        end;
      end;
    end;
    LBad := LWorld;
    LBad.FLayers[4] := Copy(LWorld.FLayers[4], 0, Length(LWorld.FLayers[4]));
    LBad.FLayers[4][0] := 'phanes.catalog.book.kaykit-single.v1';
    Check(not ValidateWorld(LBad, LRequest.FAssets, LReason), 'Shelf object is rejected in the regional world');
    for I := 0 to High(LRequest.FAssets) do
    begin
      if LRequest.FAssets[I].FId = LIds[0] then
      begin
        LRequest.FAssets[I].FCluster := 9;
      end;
    end;
    Check(not ValidateWorld(LWorld, LRequest.FAssets, LReason), 'Forged regional cluster count is rejected');
  finally
    LPalette.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS ', GChecks, ' regional integration checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
