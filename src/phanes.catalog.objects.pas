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
unit phanes.catalog.objects;

{$mode delphi}
{$H+}

interface

type
  TObjectAssetAdmission = record
    FId: String;
    FKitId: String;
    FModelId: String;
    FSourceSha256: String;
    FManifestSha256: String;
    FCategory: String;
    FSubcategory: String;
    FRole: String;
    FName: UnicodeString;
    FUniformScale: Double;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FTriangles: Integer;
    FVertices: Integer;
    FTexturePixels: Integer;
  end;

  TObjectAssetIds = array of String;

function ObjectAssetAdmission(const AId: String;
  out AAdmission: TObjectAssetAdmission): Boolean;
function ObjectAssetIds: TObjectAssetIds;

implementation

procedure ClearAdmission(out AAdmission: TObjectAssetAdmission);
begin
  AAdmission.FId := '';
  AAdmission.FKitId := '';
  AAdmission.FModelId := '';
  AAdmission.FSourceSha256 := '';
  AAdmission.FManifestSha256 := '';
  AAdmission.FCategory := '';
  AAdmission.FSubcategory := '';
  AAdmission.FRole := '';
  AAdmission.FName := '';
  AAdmission.FUniformScale := 0;
  AAdmission.FWidth := 0;
  AAdmission.FDepth := 0;
  AAdmission.FHeight := 0;
  AAdmission.FTriangles := 0;
  AAdmission.FVertices := 0;
  AAdmission.FTexturePixels := 0;
end;

procedure AssignAdmission(out AAdmission: TObjectAssetAdmission;
  const AId, AKitId, AModelId, ASourceSha256, AManifestSha256, ACategory,
  ASubcategory, ARole: String; const AName: UnicodeString;
  const AUniformScale: Double; const AWidth, ADepth, AHeight, ATriangles,
  AVertices, ATexturePixels: Integer);
begin
  AAdmission.FId := AId;
  AAdmission.FKitId := AKitId;
  AAdmission.FModelId := AModelId;
  AAdmission.FSourceSha256 := ASourceSha256;
  AAdmission.FManifestSha256 := AManifestSha256;
  AAdmission.FCategory := ACategory;
  AAdmission.FSubcategory := ASubcategory;
  AAdmission.FRole := ARole;
  AAdmission.FName := AName;
  AAdmission.FUniformScale := AUniformScale;
  AAdmission.FWidth := AWidth;
  AAdmission.FDepth := ADepth;
  AAdmission.FHeight := AHeight;
  AAdmission.FTriangles := ATriangles;
  AAdmission.FVertices := AVertices;
  AAdmission.FTexturePixels := ATexturePixels;
end;

{$I phanes.catalog.batch.inc}
{$I phanes.catalog.equipment.inc}

function ObjectAssetAdmission(const AId: String;
  out AAdmission: TObjectAssetAdmission): Boolean;
const
  RpgManifest = '364f56c56de54db636613b4e3e21dc8c0e05fe3ce7fe968316bc343e4624bb45';
  SurvivalManifest = 'e72ee77a5a9e15718d69629da9b19a2f18190273f24cf0a8810d80b04da84c05';
  FoodManifest = '1f46020e51d51be049d7f59802be822bdf1e99191fde3875136bfbed69c1b020';
begin
  ClearAdmission(AAdmission);
  Result := True;
  if AId = 'phanes.catalog.book.rpg-closed.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-rpg-pack-surface-v1',
      'quaternius-low-poly-rpg-pack-surface-v1/book1-closed-f8d45591eb',
      '5070b5179b188d785b8c2e1a295cae77bfc666d1018a1b4efa39d42bbca60f06',
      RpgManifest, 'Objects', 'Books', 'book', 'Red field journal', 0.3,
      54, 180, 241, 284, 852, 0);
  end else
  if AId = 'phanes.catalog.artifact.scroll.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-rpg-pack-surface-v1',
      'quaternius-low-poly-rpg-pack-surface-v1/scroll-fde3956939',
      '482323f3152adef12dc260bd7052fbf7f24d928d41248350539e0fdbed5caf17',
      RpgManifest, 'Objects', 'Artifacts', 'ornament', 'Bound scroll', 0.1,
      148, 26, 24, 956, 2868, 0);
  end else
  if AId = 'phanes.catalog.artifact.crystal-green.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-rpg-pack-surface-v1',
      'quaternius-low-poly-rpg-pack-surface-v1/crystal3-f7b0f73a3a',
      '4c1575e3c9af0cc59ad606889a99159e84a4e6b9d8ada5face8bbadd637bdd89',
      RpgManifest, 'Objects', 'Artifacts', 'ornament', 'Green crystal', 0.3,
      97, 85, 230, 12, 36, 0);
  end else
  if AId = 'phanes.catalog.artifact.potion-cyan.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-rpg-pack-surface-v1',
      'quaternius-low-poly-rpg-pack-surface-v1/potion10-filled-b17bd4d380',
      '56eb2f598dad037fc1fc1d041e9314361a7e2a93001e5cd0394fcc839235eb17',
      RpgManifest, 'Objects', 'Artifacts', 'ornament', 'Stoppered vial', 0.3,
      132, 114, 233, 404, 1212, 0);
  end else
  if AId = 'phanes.catalog.artifact.candle.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'graveyard-kit', 'graveyard-kit/candle',
      '4eea8c08c86daebbdddc454e89e3f75bb486ee7f82822bb1edb418db6d539f91',
      'a910c92213465f6ec89c6c532513ca36619a17b515ee256cb9fae668c38069d7',
      'Objects', 'Artifacts', 'ornament', 'Graveyard candle', 1.0,
      137, 137, 201, 54, 100, 262144);
  end else
  if AId = 'phanes.catalog.equipment.radio.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-survival-pack-surface-v1',
      'quaternius-lowpoly-survival-pack-surface-v1/radio-3e63b5b402',
      'fc1a5fb9d175bff690e429185b7eaba62877b71b748724ae707c55f915975206',
      SurvivalManifest, 'Objects', 'Equipment', 'ornament', 'Field radio', 0.085,
      144, 49, 179, 481, 1443, 0);
  end else
  if AId = 'phanes.catalog.equipment.compass.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-lowpoly-survival-pack-surface-v1',
      'quaternius-lowpoly-survival-pack-surface-v1/compass-open-31afcc6bdf',
      '8ea3e796c0905a67d0d33a6ed0019e99985bc4e8d450781214a6df7bd6fb7cd0',
      SurvivalManifest, 'Objects', 'Equipment', 'ornament', 'Open compass', 0.16,
      146, 113, 129, 656, 1968, 0);
  end else
  if AId = 'phanes.catalog.equipment.station-switch.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'space-station-kit',
      'space-station-kit/wall-switch',
      '2b297783053aa9b091972f31f5fc3892b7cb7572d017dd37fc22af9ac2640c20',
      '21aa6c2e2627b482e6f925501f83d39de062782eafcacccfc694d8dea70a8d9c',
      'Objects', 'Equipment', 'ornament', 'Station control switch', 1.0,
      101, 26, 201, 18, 28, 262144);
  end else
  if AId = 'phanes.catalog.food.bread-slice.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'food-kit', 'food-kit/bread',
      '9bd9db117db654cf1157439d1257a8fc5915ea77a94fb876a5056522b9e49f46',
      FoodManifest, 'Food', 'Bread', 'bread', 'Bread slice', 0.11,
      49, 41, 5, 116, 154, 262144);
  end else
  if AId = 'phanes.catalog.food.strawberry.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'food-kit', 'food-kit/strawberry',
      '685828642a92681b474c29abbd9cabe98c7bcade62cc50da57ec6658a5b7e8f7',
      FoodManifest, 'Food', 'Fruit', 'fruit', 'Strawberry', 0.35,
      42, 42, 64, 156, 288, 262144);
  end else
  if AId = 'phanes.catalog.food.cheese-slice.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'food-kit', 'food-kit/cheese-cut',
      '3937390f5d3cf21434844d7aab87a9c9d1ce75a38e71177959ca5cbdc7a4db14',
      FoodManifest, 'Food', 'Cheese', 'cheese', 'Cheese slice', 0.13,
      50, 35, 3, 160, 234, 262144);
  end else
  if AId = 'phanes.catalog.food.croissant.v1' then
  begin
    AssignAdmission(AAdmission, AId, 'quaternius-low-poly-food-pack-surface-v1',
      'quaternius-low-poly-food-pack-surface-v1/croissant-d2df597192',
      '22177047827f814c00132634549f2a713181854cdb70ab76bb682355418dbe9e',
      'c52176ba6699fa3362abc754f2d7d4238b0f46573b046e6cc2a4bed0329ce71f',
      'Food', 'Bread', 'bread', 'Croissant', 0.038,
      50, 28, 21, 132, 396, 0);
  end else
  begin
    Result := BatchAdmission(AId, AAdmission) or EquipmentAdmission(AId, AAdmission);
  end;
end;

function ObjectAssetIds: TObjectAssetIds;
var
  I: Integer;
begin
  SetLength(Result, 12 + Length(BatchIds) + Length(EquipmentIds));
  Result[0] := 'phanes.catalog.book.rpg-closed.v1';
  Result[1] := 'phanes.catalog.artifact.scroll.v1';
  Result[2] := 'phanes.catalog.artifact.crystal-green.v1';
  Result[3] := 'phanes.catalog.artifact.potion-cyan.v1';
  Result[4] := 'phanes.catalog.artifact.candle.v1';
  Result[5] := 'phanes.catalog.equipment.radio.v1';
  Result[6] := 'phanes.catalog.equipment.compass.v1';
  Result[7] := 'phanes.catalog.equipment.station-switch.v1';
  Result[8] := 'phanes.catalog.food.bread-slice.v1';
  Result[9] := 'phanes.catalog.food.strawberry.v1';
  Result[10] := 'phanes.catalog.food.cheese-slice.v1';
  Result[11] := 'phanes.catalog.food.croissant.v1';
  for I := 0 to High(BatchIds) do
  begin
    Result[12 + I] := BatchIds[I];
  end;
  for I := 0 to High(EquipmentIds) do
  begin
    Result[12 + Length(BatchIds) + I] := EquipmentIds[I];
  end;
end;

end.
