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
unit phanes.catalog.regional;

{$mode delphi}
{$H+}

interface

type
  TRegionalAssetAdmission = record
    FId: String;
    FKitId: String;
    FModelId: String;
    FSourceSha256: String;
    FManifestSha256: String;
    FRole: String;
    FTheme: String;
    FName: UnicodeString;
    FUniformScale: Double;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FTriangles: Integer;
    FVertices: Integer;
    FTexturePixels: Integer;
  end;

  TRegionalAssetIds = array of String;

function RegionalAssetAdmission(const AId: String;
  out AAdmission: TRegionalAssetAdmission): Boolean;
function RegionalAssetIds: TRegionalAssetIds;

implementation

procedure ClearAdmission(out AAdmission: TRegionalAssetAdmission);
begin
  AAdmission.FId := '';
  AAdmission.FKitId := '';
  AAdmission.FModelId := '';
  AAdmission.FSourceSha256 := '';
  AAdmission.FManifestSha256 := '';
  AAdmission.FRole := '';
  AAdmission.FTheme := '';
  AAdmission.FName := '';
  AAdmission.FUniformScale := 0;
  AAdmission.FWidth := 0;
  AAdmission.FDepth := 0;
  AAdmission.FHeight := 0;
  AAdmission.FTriangles := 0;
  AAdmission.FVertices := 0;
  AAdmission.FTexturePixels := 0;
end;

procedure AssignAdmission(out AAdmission: TRegionalAssetAdmission;
  const AId, AKitId, AModelId, ASourceSha256, AManifestSha256, ARole,
  ATheme: String; const AName: UnicodeString; const AUniformScale: Double;
  const AWidth, ADepth, AHeight, ATriangles, AVertices, ATexturePixels: Integer);
begin
  AAdmission.FId := AId;
  AAdmission.FKitId := AKitId;
  AAdmission.FModelId := AModelId;
  AAdmission.FSourceSha256 := ASourceSha256;
  AAdmission.FManifestSha256 := AManifestSha256;
  AAdmission.FRole := ARole;
  AAdmission.FTheme := ATheme;
  AAdmission.FName := AName;
  AAdmission.FUniformScale := AUniformScale;
  AAdmission.FWidth := AWidth;
  AAdmission.FDepth := ADepth;
  AAdmission.FHeight := AHeight;
  AAdmission.FTriangles := ATriangles;
  AAdmission.FVertices := AVertices;
  AAdmission.FTexturePixels := ATexturePixels;
end;

{$I phanes.catalog.nature.inc}

function RegionalAssetAdmission(const AId: String;
  out AAdmission: TRegionalAssetAdmission): Boolean;
const
  NatureManifest = '17604aa728e4bbce6a1c9246c38ca24cdfc350b0398c0f31f1acc2a7bee6d17b';
  CropsManifest = '18de4e803e5dd6c4bdadccf61f16b3019a454cddc250c2f67a9c83f05b3aeddf';
  MiniForestManifest = '4f3800fa25db5cba14a01929fb7bed5d09236ee469a11bc4855ef1149f0576ae';
begin
  ClearAdmission(AAdmission);
  Result := True;
  if AId = 'phanes.catalog.tree.forest-canopy.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'mini-forest', 'mini-forest/tree',
      '0075d5059c1ea855fecc1dba3c6262c3a01924c50b971ddde2eb8b0b5a62851a',
      MiniForestManifest, 'tree', 'nature', 'Forest canopy tree', 3.5,
      3246, 3090, 5894, 182, 428, 262144);
  end else
  if AId = 'phanes.catalog.tree.autumn.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'survival-kit', 'survival-kit/tree-autumn',
      '1945b56b6a17e57ade4f14716fac40d53c3c322e8855c3825d40825845bbfd92',
      'd02b4566cc5e0a36609b121f17d24784385a7a7ccc97c16f8ed076420eaa2cc9',
      'tree', 'nature', 'Autumn tree', 5.0,
      2765, 2632, 7055, 198, 348, 262144);
  end else
  if AId = 'phanes.catalog.tree.birch.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/birchtree-1-b4a09e49ec',
      '9ff06e04fbec7e9e9f844780426d64313b45a62f94a025696b6b19d4d917023f',
      NatureManifest, 'tree', 'nature', 'Birch tree', 1.4,
      2383, 3472, 5004, 1704, 5112, 0);
  end else
  if AId = 'phanes.catalog.tree.island-palm.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'pirate-kit', 'pirate-kit/palm-straight',
      'a4101242b8c825280dfb6152900285aacc091203ce7bf9c743579599f1496520',
      '9a57bad69378409efed1f840b7ca3548a46596d18c917114e360b676902b3c31',
      'tree', 'fantasy', 'Island palm', 1.4,
      3485, 3485, 5899, 338, 680, 262144);
  end else
  if AId = 'phanes.catalog.shrub.leafy-bush.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/bush-1-0cac6fca9e',
      'fc73c42bf2357d1501cc1e938cd6e944af8c98b4a52d29fe3c843ddcd9b428a7',
      NatureManifest, 'shrub', 'nature', 'Leafy bush', 1.0,
      1329, 1691, 1242, 364, 1092, 0);
  end else
  if AId = 'phanes.catalog.shrub.broadleaf.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/plant-3-d7a81a118b',
      'b66b8fdb61f889745458c24356f1d0cabd020ad5fc632bf9b13036a1d7b92f78',
      NatureManifest, 'shrub', 'nature', 'Broadleaf plant', 1.5,
      1635, 1459, 1416, 600, 1800, 0);
  end else
  if AId = 'phanes.catalog.shrub.berry-bush.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-crops-pack-surface-v1',
      'quaternius-lowpoly-crops-pack-surface-v1/bushberries-2-54b0ed2e6a',
      '7323689ffedd0a99fd04c0189e856c2b58bf353195d3bd5cf441396177c87b01',
      CropsManifest, 'shrub', 'nature', 'Berry bush', 2.0,
      1185, 1030, 1012, 140, 420, 0);
  end else
  if AId = 'phanes.catalog.shrub.forest-plant.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'mini-forest', 'mini-forest/plant',
      '4ce1784382a2c986b5a63cd4cf7fc41f8775148464021fc4e10d780cc7892789',
      MiniForestManifest, 'shrub', 'nature', 'Forest plant', 4.0,
      1586, 1722, 768, 156, 408, 262144);
  end else
  if AId = 'phanes.catalog.flowers.cactus-bloom.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/cactusflowers-3-24621032d4',
      'c28dd4abe8ead3b708e45df779e783b8f0c8778c1bf914a7f6f90c96997f2378',
      NatureManifest, 'flowers', 'nature', 'Flowering cactus', 0.6,
      287, 671, 1002, 1184, 3552, 0);
  end else
  if AId = 'phanes.catalog.flowers.cactus-cluster.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/cactusflowers-5-f92dda74ad',
      '6425b22763b7f21e1c47c9c6583ef5bc9c1f51eee8c05a1d98145e7dabd5951c',
      NatureManifest, 'flowers', 'nature', 'Flowering cactus cluster', 0.9,
      101, 661, 845, 800, 2400, 0);
  end else
  if AId = 'phanes.catalog.flowers.wildflowers.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/flowers-8ae37b9570',
      '69afeaa3ab1222b1c7292584dadb2f9cad6a0b527dc71cbc45aecf0300d36bf2',
      NatureManifest, 'flowers', 'nature', 'Wildflower cluster', 1.1,
      539, 676, 912, 408, 1224, 0);
  end else
  if AId = 'phanes.catalog.flowers.flower-patch.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-crops-pack-surface-v1',
      'quaternius-lowpoly-crops-pack-surface-v1/flowers-crop-0656354cf7',
      '3068145567c4878de3c8719c40d0186ed558aa7eba02362f759a64568e31a123',
      CropsManifest, 'flowers', 'nature', 'Low flower patch', 2.3,
      672, 674, 268, 134, 402, 0);
  end else
  if AId = 'phanes.catalog.wheat.corn.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-crops-pack-surface-v1',
      'quaternius-lowpoly-crops-pack-surface-v1/corn-3-f0ec667a85',
      '12343f794dc9dc2f9ad83a071bba35e83f0f7c6bf09060274670fb4df5f36e00',
      CropsManifest, 'wheat', 'nature', 'Mature corn', 0.95,
      641, 544, 1185, 348, 1044, 0);
  end else
  if AId = 'phanes.catalog.wheat.rice.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-crops-pack-surface-v1',
      'quaternius-lowpoly-crops-pack-surface-v1/rice-3-f2fc172818',
      '28f6c5632d35722b24a84356313f9d160ef75fb84b09b1b79c79a9441203d68a',
      CropsManifest, 'wheat', 'nature', 'Mature rice', 1.3,
      805, 310, 1000, 628, 1884, 0);
  end else
  if AId = 'phanes.catalog.wheat.grain.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-crops-pack-surface-v1',
      'quaternius-lowpoly-crops-pack-surface-v1/wheat-3-c907392cf1',
      '54705953d717f27a5e017e872d09033081d26da073f051eb3174821c77a6953b',
      CropsManifest, 'wheat', 'nature', 'Mature grain', 1.7,
      281, 414, 1181, 246, 738, 0);
  end else
  if AId = 'phanes.catalog.rock.granite.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/rock-4-5b0959d734',
      '6829ca5be9ef471059579d5fc68265d3958745d5853f247af04d77101d266cd7',
      NatureManifest, 'rock', 'nature', 'Angular rock', 1.9,
      1413, 2376, 1489, 128, 384, 0);
  end else
  if AId = 'phanes.catalog.rock.mossy.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-nature-pack-1-surface-v1',
      'quaternius-low-poly-nature-pack-1-surface-v1/rock-moss-4-14a2d1ffa3',
      'd1b6280a96477407e4963ed683151287eddea67e58a8f405791a54415ecb0afe',
      NatureManifest, 'rock', 'nature', 'Mossy rock', 1.9,
      1413, 2376, 1489, 128, 384, 0);
  end else
  if AId = 'phanes.catalog.rock.forest-stones.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'mini-forest', 'mini-forest/stones',
      'f46682b8eb8110fabe17f1da8e226bd2471046a25d907e41fd43ad9695f4c397',
      MiniForestManifest, 'rock', 'nature', 'Forest stones', 2.6,
      2351, 2216, 1181, 236, 414, 262144);
  end else
  begin
    Result := BatchAdmission(AId, AAdmission);
  end;
end;

function RegionalAssetIds: TRegionalAssetIds;
var
  I: Integer;
begin
  SetLength(Result, 18 + Length(BatchIds));
  Result[0] := 'phanes.catalog.tree.forest-canopy.v1';
  Result[1] := 'phanes.catalog.tree.autumn.v1';
  Result[2] := 'phanes.catalog.tree.birch.v1';
  Result[3] := 'phanes.catalog.tree.island-palm.v1';
  Result[4] := 'phanes.catalog.shrub.leafy-bush.v1';
  Result[5] := 'phanes.catalog.shrub.broadleaf.v1';
  Result[6] := 'phanes.catalog.shrub.berry-bush.v1';
  Result[7] := 'phanes.catalog.shrub.forest-plant.v1';
  Result[8] := 'phanes.catalog.flowers.cactus-bloom.v1';
  Result[9] := 'phanes.catalog.flowers.cactus-cluster.v1';
  Result[10] := 'phanes.catalog.flowers.wildflowers.v1';
  Result[11] := 'phanes.catalog.flowers.flower-patch.v1';
  Result[12] := 'phanes.catalog.wheat.corn.v1';
  Result[13] := 'phanes.catalog.wheat.rice.v1';
  Result[14] := 'phanes.catalog.wheat.grain.v1';
  Result[15] := 'phanes.catalog.rock.granite.v1';
  Result[16] := 'phanes.catalog.rock.mossy.v1';
  Result[17] := 'phanes.catalog.rock.forest-stones.v1';
  for I := 0 to High(BatchIds) do
  begin
    Result[18 + I] := BatchIds[I];
  end;
end;

end.
