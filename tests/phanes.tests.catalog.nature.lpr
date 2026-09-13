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
program PhanesNatureChecks;

{$mode delphi}
{$H+}

uses Classes, SysUtils, FPJSON, phanes.tools.files, phanes.catalog.regional,
  phanes.world.types, phanes.world.generate, phanes.world.validate;

var
  GChecks: Integer;
  GReason: String;
  GAssets: TAssets;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Require(AValue, AMessage + ': ' + GReason);
  Inc(GChecks);
end;

function Baseline(const ATerrain: String): TWorld;
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
        Result.FLayers[I][J] := ATerrain;
      end;
    end;
  end;
end;

function Request(const AWorld: TWorld): TWorldRequest;
begin
  Result := Default(TWorldRequest);
  Result.FPrevious := AWorld;
  Result.FAssets := GAssets;
  Result.FSize := 4;
  Result.FSeed := 101;
  Result.FOperation := 'asset';
  Result.FEditLayer := 'foliage';
  Result.FX := 1;
  Result.FZ := 1;
  Result.FWidth := 1;
  Result.FDepth := 1;
  Result.FContentCount := -1;
  Result.FGroundworkTurn := -1;
end;

procedure Run;
var
  LReport: TJSONObject;
  LPalette: TJSONObject;
  LRow: TJSONObject;
  LProfile: TRegionalAssetAdmission;
  LRequest: TWorldRequest;
  LBase: TWorld;
  LWorld: TWorld;
  LRepeat: TWorld;
  LUnique: TStringList;
  LCount: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LReport := LoadJSON('data/catalog-integration-nature.json');
  LPalette := LoadJSON('data/palette.json');
  SetLength(GAssets, LPalette.Arrays['assets'].Count);
  for I := 0 to High(GAssets) do
  begin
    LRow := LPalette.Arrays['assets'].Objects[I];
    GAssets[I].FId := LRow.Strings['id'];
    GAssets[I].FKind := LRow.Strings['kind'];
    GAssets[I].FTheme := LRow.Strings['theme'];
    GAssets[I].FCluster := LRow.Get('cluster', 1);
  end;
  LCount := 0;
  for I := 0 to LReport.Arrays['models'].Count - 1 do
  begin
    LRow := LReport.Arrays['models'].Objects[I];
    if LRow.Get('status', '') <> 'pass' then
    begin
      Continue;
    end;
    Inc(LCount);
    Check(RegionalAssetAdmission(LRow.Strings['assetId'], LProfile), 'Registry contains ledger pass');
    Check((LProfile.FModelId = LRow.Strings['sourceId']) and
      (LProfile.FSourceSha256 = LRow.Strings['sourceSha256']), 'Registry binds source identity');
    Check(AssetKind(GAssets, LProfile.FId) = LProfile.FRole, 'Palette exposes the admitted role');
    if LProfile.FRole = 'wheat' then
    begin
      LBase := Baseline('field');
    end else
    begin
      LBase := Baseline('meadow');
    end;
    LRequest := Request(LBase);
    LRequest.FExactAsset := LProfile.FId;
    Check(GenerateWorld(LRequest, LWorld, GReason), 'Exact placement solves: ' + LProfile.FModelId);
    Check(ValidateWorld(LWorld, GAssets, GReason), 'Placed world validates');
    for J := 0 to 4 do
    begin
      for K := 0 to High(LWorld.FLayers[J]) do
      begin
        if (J in [2, 4]) and (K mod 8 in [2, 3]) and (K div 8 in [2, 3]) then
        begin
          if J = 4 then
          begin
            Check(LWorld.FLayers[J][K] = LProfile.FId, 'Selected cell contains the exact model');
          end;
        end else
        begin
          Check(LWorld.FLayers[J][K] = LBase.FLayers[J][K], 'Unselected output preserved');
        end;
      end;
    end;
  end;
  Check(LCount = LReport.Integers['passedNew'], 'Every ledger pass tested');

  LRequest := Request(Baseline('meadow'));
  LRequest.FOperation := 'tree';
  LRequest.FX := 0;
  LRequest.FZ := 0;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  for I := 0 to High(GAssets) do
  begin
    if (GAssets[I].FKind = 'tree') and (Pos('phanes.catalog.nature.', GAssets[I].FId) = 1) then
    begin
      SetLength(LRequest.FAssetChoices, Length(LRequest.FAssetChoices) + 1);
      LRequest.FAssetChoices[High(LRequest.FAssetChoices)] := GAssets[I].FId;
    end;
  end;
  Check(Length(LRequest.FAssetChoices) > 8, 'Group test exercises a broad catalog');
  Check(GenerateWorld(LRequest, LWorld, GReason), 'Broad tree group solves');
  LUnique := TStringList.Create;
  LUnique.Sorted := True;
  LUnique.Duplicates := dupIgnore;
  for I := 0 to High(LWorld.FLayers[4]) do
  begin
    LUnique.Add(LWorld.FLayers[4][I]);
  end;
  Check((LUnique.Count > 1) and (LUnique.Count <= 8), 'Group uses at most eight distinct models');
  Check(GenerateWorld(LRequest, LRepeat, GReason), 'Group replays');
  for I := 0 to High(LWorld.FLayers[4]) do
  begin
    Check(LWorld.FLayers[4][I] = LRepeat.FLayers[4][I], 'Group is deterministic');
  end;
  LRequest := Request(LWorld);
  LRequest.FExactAsset := LUnique[0];
  Check(GenerateWorld(LRequest, LRepeat, GReason), 'Editing preserves previously placed batch models');
  for I := 0 to High(LWorld.FLayers[4]) do
  begin
    if not ((I mod 8 in [2, 3]) and (I div 8 in [2, 3])) then
    begin
      Check(LWorld.FLayers[4][I] = LRepeat.FLayers[4][I], 'Unselected mixture remains exact');
    end;
  end;
  WriteLn('PASS ', GChecks, ' assertions; ', LCount, ' nature models placed');
  LUnique.Free;
  LReport.Free;
  LPalette.Free;
end;

begin
  Run;
end.
