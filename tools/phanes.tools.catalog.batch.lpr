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
program PhanesCatalogBatch;

{$mode delphi}
{$H+}

uses Classes, SysUtils, Math, FPJSON, phanes.tools.files,
  phanes.catalog.admission;

var
  GGeometry: TJSONObject;
  GGeometryIndex: TStringList;
  GVerified: TStringList;
  GExisting: TStringList;
  GProfiles: TStringList;
  GRows: TJSONArray;
  GSite: String;
  GPassed: Integer;
  GFailed: Integer;
  GExistingCount: Integer;
  GNature: Boolean;
  GEquipment: Boolean;
  GFurniture: Boolean;

function Quoted(const AText: String): String;
begin
  Result := QuotedStr(AText);
end;

function Matches(const AText: String; const AWords: array of String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AWords) do
  begin
    if Pos(AWords[I], AText) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function NameMatches(const AText: String; const AWords: array of String): Boolean;
var
  LTokens: String;
  I: Integer;
begin
  { Split delimiters and CamelCase before matching whole words: vegetable is
    food, while Table_Long, BedKing and SmallSofa are furniture names. }
  LTokens := ' ';
  for I := 1 to Length(AText) do
  begin
    if not (AText[I] in ['a'..'z', 'A'..'Z']) then
    begin
      LTokens := LTokens + ' ';
    end else
    begin
      if (I > 1) and (AText[I] in ['A'..'Z']) and
        (AText[I - 1] in ['a'..'z']) then
      begin
        LTokens := LTokens + ' ';
      end;
      LTokens := LTokens + LowerCase(AText[I]);
    end;
  end;
  LTokens := LTokens + ' ';
  for I := 0 to High(AWords) do
  begin
    if Pos(' ' + AWords[I] + ' ', LTokens) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure FurnitureSize(const AName: String; out ACategory: String;
  out ATarget: Double);
begin
  Require(not NameMatches(AName, ['table', 'kitchentable', 'desk', 'shelf', 'shelves', 'bookcase',
    'bookshelf', 'counter', 'workbench', 'sink']),
    'requires editable furniture supports or plumbing placement');
  Require(not NameMatches(AName, ['bed', 'bunk', 'king', 'large', 'big', 'long']),
    'requires a larger furniture footprint');
  ACategory := '';
  ATarget := 0;
  if NameMatches(AName, ['sofa', 'couch']) then
  begin
    ACategory := 'Sofas';
    ATarget := 1.7;
  end else if NameMatches(AName, ['bench']) then
  begin
    ACategory := 'Benches';
    ATarget := 1.5;
  end else if NameMatches(AName, ['cabinet', 'kitchencabinet', 'dresser', 'wardrobe']) then
  begin
    ACategory := 'Cabinets';
    ATarget := 1.2;
  end else if NameMatches(AName, ['chair', 'armchair', 'stool', 'ottoman']) then
  begin
    ACategory := 'Seating';
    ATarget := 0.9;
  end;
  Require(ACategory <> '', 'outside the compact freestanding furniture categories');
end;

function VerifiedBytes(const AFile: TJSONObject): TBytes;
var
  LHash: String;
begin
  LHash := AFile.Get('sha256', '');
  Result := ReadBytes(SafeChild(GSite, AFile.Get('url', '')));
  Require(Length(Result) = AFile.Get('bytes', Int64(0)), 'published byte length mismatch');
  if GVerified.IndexOf(LHash) < 0 then
  begin
    Require(HashBytes(Result) = LHash, 'published source hash mismatch');
    GVerified.Add(LHash);
  end;
end;

function Big32(const ABytes: TBytes; const AOffset: Integer): Cardinal;
begin
  Require((AOffset >= 0) and (AOffset + 4 <= Length(ABytes)), 'truncated PNG');
  Result := (Cardinal(ABytes[AOffset]) shl 24) or
    (Cardinal(ABytes[AOffset + 1]) shl 16) or
    (Cardinal(ABytes[AOffset + 2]) shl 8) or ABytes[AOffset + 3];
end;

function PNGPixels(const ABytes: TBytes; const AOffset: Integer): Int64;
begin
  Require((AOffset >= 0) and (AOffset + 24 <= Length(ABytes)), 'truncated image');
  Require((Big32(ABytes, AOffset) = $89504E47) and
    (Big32(ABytes, AOffset + 4) = $0D0A1A0A), 'texture needs unsupported image measurement');
  Result := Int64(Big32(ABytes, AOffset + 16)) * Big32(ABytes, AOffset + 20);
  Require((Result > 0) and (Result <= 1048576), 'texture exceeds one megapixel batch budget');
end;

function MeasureTextures(const AModel, AJSON: TJSONObject;
  const ABytes: TBytes): Integer;
var
  LImages: TJSONArray;
  LFiles: TJSONArray;
  LImage: TJSONObject;
  LView: TJSONObject;
  LPath: String;
  LBytes: TBytes;
  LFound: Boolean;
  LOffset: Integer;
  I: Integer;
  J: Integer;
begin
  Result := 0;
  LImages := AJSON.Get('images', TJSONArray(nil));
  if LImages = nil then
  begin
    Exit;
  end;
  LFiles := AModel.Arrays['files'];
  for I := 0 to LImages.Count - 1 do
  begin
    LImage := LImages.Objects[I];
    if LImage.Find('bufferView') <> nil then
    begin
      Require(AModel.Get('format', '') = 'glb', 'external buffer image requires additional measurement');
      LView := AJSON.Arrays['bufferViews'].Objects[LImage.Integers['bufferView']];
      Require(LView.Get('buffer', 0) = 0, 'unsupported image buffer');
      LOffset := 20 + Integer(Little32(ABytes, 12));
      Require(Little32(ABytes, LOffset + 4) = $004E4942, 'missing GLB binary chunk');
      Inc(Result, PNGPixels(ABytes, LOffset + 8 + LView.Get('byteOffset', 0)));
    end else
    begin
      LPath := StringReplace(ExtractFilePath(AModel.Get('path', '')) +
        LImage.Get('uri', ''), '\', '/', [rfReplaceAll]);
      LFound := False;
      for J := 0 to LFiles.Count - 1 do
      begin
        if LFiles.Objects[J].Get('path', '') = LPath then
        begin
          LBytes := VerifiedBytes(LFiles.Objects[J]);
          Inc(Result, PNGPixels(LBytes, 0));
          LFound := True;
          Break;
        end;
      end;
      Require(LFound, 'texture URI cannot be resolved from published closure');
    end;
  end;
  Require(Result <= 1048576, 'combined textures exceed batch budget');
end;

procedure Attempt(const AKit, AModel: TJSONObject);
var
  LRow: TJSONObject;
  LGeometry: TJSONObject;
  LJSON: TJSONObject;
  LFile: TJSONObject;
  LBytes: TBytes;
  LId: String;
  LName: String;
  LRole: String;
  LCategory: String;
  LScale: Double;
  LTarget: Double;
  LHorizontalLimit: Integer;
  LSize: array[0..2] of Double;
  LDimensions: array[0..2] of Integer;
  LPixels: Integer;
  LTriangles: Integer;
  LAt: Integer;
  I: Integer;
begin
  LRow := TJSONObject.Create;
  GRows.Add(LRow);
  LRow.Add('sourceId', AModel.Get('id', ''));
  LRow.Add('sourceSha256', AModel.Get('sha256', ''));
  LRow.Add('kit', AKit.Get('id', ''));
  if GExisting.IndexOf(AModel.Get('id', '')) >= 0 then
  begin
    LRow.Add('status', 'existing');
    LRow.Add('reason', 'already integrated; existing profile preserved');
    Inc(GExistingCount);
    Exit;
  end;
  try
    LName := LowerCase(AModel.Get('name', ''));
    if GNature then
    begin
      Require(not Matches(LName, ['bridge', 'building', 'character', 'fence',
        'flag', 'ladder', 'platform', 'patch-', 'petal', 'rockpath', 'laetiporus',
        'trunk', 'log', 'stump', 'branch', 'leaf', 'leaves']),
        'requires structural, attached-part or terrain-patch placement');
      LRole := '';
      if Pos('crops-pack', AKit.Get('id', '')) > 0 then
      begin
        Require(Pos('_crop', LName) = 0, 'harvested produce belongs in the props catalog');
        LRole := 'wheat';
      end else if Matches(LName, ['tree', 'pine', 'birch', 'palm', 'willow', 'oak', 'spruce']) then
      begin
        LRole := 'tree';
      end else if Matches(LName, ['corn', 'wheat', 'rice']) then
      begin
        LRole := 'wheat';
      end else if Matches(LName, ['rock', 'stone', 'pebble']) then
      begin
        LRole := 'rock';
      end else if Matches(LName, ['flower', 'mushroom', 'clover']) then
      begin
        LRole := 'flowers';
      end else if Matches(LName, ['bush', 'grass', 'fern', 'plant', 'cactus']) then
      begin
        LRole := 'shrub';
      end;
      Require(LRole <> '', 'no supported outdoor nature role');
      LCategory := 'Nature';
      LTarget := 1.5;
      LHorizontalLimit := 2000;
      if LRole = 'tree' then
      begin
        LTarget := 6;
        LHorizontalLimit := 3600;
      end else if LRole = 'rock' then
      begin
        LTarget := 2.2;
        LHorizontalLimit := 2400;
      end else if LRole = 'flowers' then
      begin
        LTarget := 0.55;
        LHorizontalLimit := 700;
      end else if LRole = 'wheat' then
      begin
        LTarget := 1.2;
        LHorizontalLimit := 1200;
      end;
    end else
    begin
      Require(not Matches(LName, ['wall', 'door', 'window', 'floor', 'roof', 'stair',
        'ceiling', 'column', 'pillar', 'banner', 'curtain', 'mirror', 'picture',
        'carpet', 'rug', 'fence', 'gate', 'bridge', 'mast', 'flag', 'boat', 'ship',
        'cannon', 'palm', 'grass', 'patch', 'extractor', 'shower', 'bathtub']),
        'requires structural, wall, terrain or special placement');
      if not GFurniture then
      begin
        Require(not (NameMatches(AModel.Get('name', ''), ['table', 'kitchentable']) or
          Matches(LName, ['desk', 'shelf', 'shelves', 'bookcase',
          'cabinet', 'counter', 'bed', 'couch', 'sofa', 'sink'])),
          'requires measured furniture supports or multi-floor footprint');
      end;
      LCategory := 'Objects';
      LRole := 'ornament';
      LTarget := 0.45;
      if Matches(AKit.Get('id', ''), ['food']) or Matches(LName, ['food_', 'ingredient']) then
      begin
        LCategory := 'Food';
        LTarget := 0.22;
      end;
      if Matches(LName, ['chair', 'stool', 'armchair']) then
      begin
        LCategory := 'Seating';
        LRole := 'chair';
        LTarget := 0.9;
      end else if Matches(LName, ['barrel', 'crate', 'chest', 'basket', 'trash', 'bin']) then
      begin
        LCategory := 'Storage props';
        LTarget := 0.65;
      end else if Matches(LName, ['cactus', 'plant', 'flowerpot']) then
      begin
        LCategory := 'Plants';
        LRole := 'plant';
        LTarget := 0.6;
      end else if Matches(LName, ['lamp_standing', 'lamp-floor', 'floorlamp']) then
      begin
        LCategory := 'Lighting props';
        LTarget := 1.5;
      end;
      if GFurniture then
      begin
        FurnitureSize(AModel.Get('name', ''), LCategory, LTarget);
        LRole := 'ornament';
      end;
      if GEquipment then
      begin
        Require(not Matches(LName, ['catwalk', 'rail', 'pipe', 'conveyor', 'chandelier',
          'hanging', 'character', 'enemy', 'terrain', 'depot', 'structure', 'module',
          'stand', 'holder', 'rack', 'fire', 'flame', 'smoke', 'arrow-basic', 'arrow-rounded']),
          'requires structural, attached-part, character or effect integration');
        Require(Matches(LName, ['box', 'crate', 'cargo', 'container', 'barrel', 'bucket',
          'chest', 'locker', 'bag', 'backpack', 'pouch', 'sack', 'bottle', 'can_', 'can-',
          'canister', 'tank', 'battery', 'computer', 'terminal', 'console', 'generator',
          'reactor', 'machine', 'antenna', 'radar', 'satellite', 'drill', 'cog', 'gear',
          'radio', 'phone', 'compass', 'aidkit', 'bandage', 'healthpack', 'syringe',
          'anvil', 'axe', 'hammer', 'shovel', 'knife', 'sword', 'dagger', 'shield',
          'armor', 'helmet', 'bow', 'arrow', 'gun', 'revolver', 'shotgun', 'ammo',
          'grenade', 'mine', 'beartrap', 'key', 'padlock', 'book', 'scroll', 'parchment',
          'potion', 'crystal', 'gem', 'mineral', 'ingot', 'coin', 'crown', 'necklace',
          'ring', 'chalice', 'vase', 'pot', 'pan', 'mug', 'candle', 'lantern', 'torch',
          'statue', 'sculpture', 'skull', 'bone', 'gravestone', 'tombstone', 'cross',
          'pumpkin', 'cauldron', 'rope', 'chain', 'match', 'whetstone']),
          'outside the freestanding equipment and artifact categories');
        LCategory := 'Equipment';
        LRole := 'ornament';
        LTarget := 0.7;
        if Matches(LName, ['box', 'crate', 'cargo', 'container', 'barrel', 'bucket',
          'chest', 'locker', 'bag', 'backpack', 'pouch', 'sack']) then
        begin
          LCategory := 'Containers';
          LTarget := 0.8;
        end else if Matches(LName, ['statue', 'sculpture', 'gravestone', 'tombstone', 'cross']) then
        begin
          LCategory := 'Sculptures';
          LTarget := 1.4;
        end else if Matches(LName, ['book', 'scroll', 'parchment', 'potion', 'crystal',
          'gem', 'mineral', 'ingot', 'coin', 'crown', 'necklace', 'ring', 'chalice', 'vase',
          'candle', 'skull', 'bone', 'key', 'padlock']) then
        begin
          LCategory := 'Artifacts';
          LTarget := 0.3;
        end else if Matches(LName, ['tank', 'computer', 'terminal', 'console',
          'generator', 'reactor', 'machine', 'antenna', 'radar', 'satellite']) then
        begin
          LCategory := 'Technology';
          LTarget := 1.2;
        end;
      end;
    end;
    LAt := GGeometryIndex.IndexOf(AModel.Get('id', ''));
    Require(LAt >= 0, 'no cached geometry');
    LGeometry := TJSONObject(GGeometryIndex.Objects[LAt]);
    Require((LGeometry.Get('status', '') = 'decoded') and
      (LGeometry.Get('sha256', '') = AModel.Get('sha256', '')), 'geometry fingerprint mismatch');
    LTriangles := LGeometry.Get('triangles', 0);
    Require((LTriangles > 0) and (LTriangles <= 5000), 'outside 1..5000 triangle batch budget');
    for I := 0 to 2 do
    begin
      LSize[I] := LGeometry.Arrays['maximum'].Floats[I] - LGeometry.Arrays['minimum'].Floats[I];
      Require((LSize[I] > 0.00001) and not IsInfinite(LSize[I]) and not IsNan(LSize[I]),
        'degenerate or nonfinite bounds');
    end;
    LScale := LTarget / Max(LSize[0], Max(LSize[1], LSize[2]));
    if GNature then
    begin
      LScale := Min(LScale, (LHorizontalLimit - 2) /
        (1000 * Max(LSize[0], LSize[2])));
    end;
    for I := 0 to 2 do
    begin
      LDimensions[I] := Ceil(LSize[I] * LScale * 1000) + 1;
    end;
    if GNature then
    begin
      Require((LDimensions[0] <= LHorizontalLimit) and
        (LDimensions[2] <= LHorizontalLimit) and (LDimensions[1] <= 6010),
        'does not fit the outdoor role envelope');
    end else
    begin
      Require((LDimensions[0] <= 1800) and (LDimensions[2] <= 1800) and
        (LDimensions[1] <= 2000), 'does not fit a single floor');
    end;
    Require(AModel.Get('downloadBytes', Int64(0)) <= 4 * 1024 * 1024,
      'source closure exceeds four MiB batch budget');
    LBytes := nil;
    for I := 0 to AModel.Arrays['files'].Count - 1 do
    begin
      LFile := AModel.Arrays['files'].Objects[I];
      if LFile.Get('path', '') = AModel.Get('path', '') then
      begin
        LBytes := VerifiedBytes(LFile);
      end else
      begin
        VerifiedBytes(LFile);
      end;
    end;
    Require(Length(LBytes) > 0, 'model missing from closure');
    LJSON := ModelJSON(LBytes, '.' + AModel.Get('format', ''));
    try
      Require((LJSON.Find('animations') = nil) or (LJSON.Arrays['animations'].Count = 0),
        'animation requires separate integration');
      Require((LJSON.Find('skins') = nil) or (LJSON.Arrays['skins'].Count = 0),
        'skinned mesh requires separate integration');
      if (GNature or GEquipment or GFurniture) and (LJSON.Find('materials') <> nil) then
      begin
        for I := 0 to LJSON.Arrays['materials'].Count - 1 do
        begin
          Require(LJSON.Arrays['materials'].Objects[I].Get('alphaMode', 'OPAQUE') = 'OPAQUE',
            'masked or blended foliage needs material review');
        end;
      end;
      LPixels := MeasureTextures(AModel, LJSON, LBytes);
    finally
      LJSON.Free;
    end;
    LId := 'phanes.catalog.batch.' + Copy(HashBytes(BytesOf(AModel.Get('id', ''))), 1, 16) + '.v1';
    if GNature then
    begin
      LId := StringReplace(LId, '.batch.', '.nature.', []);
    end;
    if GEquipment then
    begin
      LId := StringReplace(LId, '.batch.', '.batch.equipment.', []);
    end;
    if GFurniture then
    begin
      LId := StringReplace(LId, '.batch.', '.batch.furniture.', []);
    end;
    Require(GProfiles.IndexOf(LId) < 0, 'asset id collision');
    GProfiles.AddObject(LId, LRow);
    LRow.Add('status', 'pass');
    if GNature then
    begin
      LRow.Add('reason', 'static geometry, published closure, texture budget and outdoor role bounds pass');
    end else
    begin
      LRow.Add('reason', 'static geometry, published closure, texture budget and single-floor bounds pass');
    end;
    LRow.Add('validation', 'mechanical; not individually visually reviewed');
    LRow.Add('assetId', LId);
    LRow.Add('name', StringReplace(StringReplace(AModel.Get('name', ''), '_', ' ',
      [rfReplaceAll]), '-', ' ', [rfReplaceAll]));
    LRow.Add('category', LCategory);
    LRow.Add('role', LRole);
    LRow.Add('uniformScale', LScale);
    LRow.Add('width', LDimensions[0]);
    LRow.Add('depth', LDimensions[2]);
    LRow.Add('height', LDimensions[1]);
    LRow.Add('triangles', LTriangles);
    LRow.Add('vertices', LTriangles * 3);
    LRow.Add('texturePixels', LPixels);
    LRow.Add('manifestSha256', AKit.Get('sha256', ''));
    Inc(GPassed);
  except
    on LException: Exception do
    begin
      LRow.Add('status', 'fail');
      LRow.Add('reason', LException.Message);
      Inc(GFailed);
    end;
  end;
end;

procedure Run;
var
  LIndex: TJSONObject;
  LManifest: TJSONObject;
  LReport: TJSONObject;
  LKit: TJSONObject;
  LRow: TJSONObject;
  LAdmission: TOptionalAssetAdmission;
  LIds: TOptionalAssetIds;
  LCode: TStringList;
  LLicense: String;
  LPrefix: String;
  LType: String;
  LIncludePath: String;
  LReportPath: String;
  I: Integer;
  J: Integer;
begin
  Require((ParamCount <= 2) and ((ParamStr(2) = '') or
    (ParamStr(2) = '--nature') or (ParamStr(2) = '--equipment') or
    (ParamStr(2) = '--furniture')),
    'Usage: catalog-batch [published-root] [--nature|--equipment|--furniture]');
  Require(not NameMatches('maki-vegetable', ['table']) and
    not NameMatches('skewer-vegetables', ['table']) and
    NameMatches('Table_Long.gltf', ['table']) and
    NameMatches('kitchentable_A', ['table', 'kitchentable']) and
    NameMatches('BedKing', ['bed']) and NameMatches('SmallSofa', ['sofa']) and
    NameMatches('kitchencabinet_corner', ['kitchencabinet']), 'name matching regression');
  GNature := ParamStr(2) = '--nature';
  GEquipment := ParamStr(2) = '--equipment';
  GFurniture := ParamStr(2) = '--furniture';
  LPrefix := 'phanes.catalog.batch.';
  LType := 'TObjectAssetAdmission';
  LIncludePath := 'src/phanes.catalog.batch.inc';
  LReportPath := 'data/catalog-integration.json';
  if GNature then
  begin
    LPrefix := 'phanes.catalog.nature.';
    LType := 'TRegionalAssetAdmission';
    LIncludePath := 'src/phanes.catalog.nature.inc';
    LReportPath := 'data/catalog-integration-nature.json';
  end;
  if GEquipment then
  begin
    LPrefix := 'phanes.catalog.batch.equipment.';
    LIncludePath := 'src/phanes.catalog.equipment.inc';
    LReportPath := 'data/catalog-integration-equipment.json';
  end;
  if GFurniture then
  begin
    LPrefix := 'phanes.catalog.batch.furniture.';
    LIncludePath := 'src/phanes.catalog.furniture.batch.inc';
    LReportPath := 'data/catalog-integration-furniture.json';
  end;
  GSite := ParamStr(1);
  if GSite = '' then
  begin
    GSite := 'build/web';
  end;
  GGeometry := LoadJSON('data/catalog-geometry.json');
  Require(GGeometry.Get('inventorySha256', '') = HashFile('data/asset-inventory.json'),
    'cached geometry does not match inventory');
  GGeometryIndex := TStringList.Create;
  GGeometryIndex.Sorted := True;
  GVerified := TStringList.Create;
  GVerified.Sorted := True;
  GExisting := TStringList.Create;
  GExisting.Sorted := True;
  GProfiles := TStringList.Create;
  GProfiles.Sorted := True;
  GRows := TJSONArray.Create;
  for I := 0 to GGeometry.Arrays['assets'].Count - 1 do
  begin
    LRow := GGeometry.Arrays['assets'].Objects[I];
    GGeometryIndex.AddObject(LRow.Get('id', ''), LRow);
  end;
  LIds := OptionalAssetIds;
  for I := 0 to High(LIds) do
  begin
    { Earlier batch ledgers remain reproducible after furniture re-screening. }
    if (Pos(LPrefix, LIds[I]) <> 1) and
      (Pos('phanes.catalog.batch.furniture.', LIds[I]) <> 1) and
      OptionalAssetAdmission(LIds[I], LAdmission) then
    begin
      GExisting.Add(LAdmission.FModelId);
    end;
  end;
  LIndex := LoadJSON(GSite + '/data/library-files.json');
  for I := 0 to LIndex.Arrays['kits'].Count - 1 do
  begin
    LKit := LIndex.Arrays['kits'].Objects[I];
    if GNature then
    begin
      if not Matches(LKit.Get('id', ''), ['mini-forest', 'nature-pack',
        'nature-megakit', 'trees-and-bushes', 'textured-trees', 'crops-pack']) then
      begin
        Continue;
      end;
    end else if GFurniture then
    begin
      if not Matches(LKit.Get('id', ''), ['furniture-bits', 'restaurant-bits',
        'house-interior', 'furniture-low-poly', 'low-poly-furniture-1',
        'dungeon-remastered', 'fantasy-props-megakit', 'sci-fi-essentials',
        'space-station-kit', 'graveyard-kit']) then
      begin
        Continue;
      end;
    end else if GEquipment then
    begin
      if not Matches(LKit.Get('id', ''), ['factory-kit', 'graveyard-kit', 'space-station-kit',
        'halloween-bits', 'space-base-bits', 'fantasy-props-megakit', 'sci-fi-essentials',
        'low-poly-rpg-pack', 'lowpoly-survival-pack']) then
      begin
        Continue;
      end;
    end else if not Matches(LKit.Get('id', ''), ['food-kit', 'low-poly-food-pack',
      'restaurant-bits', 'furniture-bits', 'house-interior', 'furniture-low-poly',
      'low-poly-furniture-1', 'pirate-kit', 'dungeon-remastered']) then
    begin
      Continue;
    end;
    Require(HashFile(SafeChild(GSite, LKit.Get('url', ''))) = LKit.Get('sha256', ''),
      'published kit manifest hash mismatch');
    LManifest := LoadJSON(SafeChild(GSite, LKit.Get('url', '')));
    try
      Require(LManifest.Get('license', '') = 'CC0-1.0', 'kit is not CC0');
      Require(LManifest.Get('inventorySha256', '') = GGeometry.Get('inventorySha256', ''),
        'manifest inventory is stale');
      for J := 0 to LManifest.Arrays['models'].Count - 1 do
      begin
        Attempt(LKit, LManifest.Arrays['models'].Objects[J]);
      end;
    finally
      LManifest.Free;
    end;
  end;
  LCode := TStringList.Create;
  LLicense := ReadText('src/phanes.catalog.objects.pas');
  LLicense := Copy(LLicense, 1, Pos('*)', LLicense) + 1);
  LCode.Add(LLicense);
  LCode.Add('{ Generated by tools/phanes.tools.catalog.batch.lpr. Do not hand edit. }');
  LCode.Add('const');
  LCode.Add('  BatchIds: array[0..' + IntToStr(GPassed - 1) + '] of String = (');
  for I := 0 to GProfiles.Count - 1 do
  begin
    if I < GProfiles.Count - 1 then
    begin
      LCode.Add('    ' + Quoted(GProfiles[I]) + ',');
    end else
    begin
      LCode.Add('    ' + Quoted(GProfiles[I]) + ');');
    end;
  end;
  LCode.Add('function BatchAdmission(const AId: String; out AAdmission: ' + LType + '): Boolean;');
  LCode.Add('var LLow, LHigh, LMiddle: Integer;');
  LCode.Add('begin');
  LCode.Add('  LLow := 0;');
  LCode.Add('  LHigh := High(BatchIds);');
  LCode.Add('  Result := False;');
  LCode.Add('  while LLow <= LHigh do');
  LCode.Add('  begin');
  LCode.Add('    LMiddle := (LLow + LHigh) div 2;');
  LCode.Add('    if BatchIds[LMiddle] < AId then LLow := LMiddle + 1');
  LCode.Add('    else if BatchIds[LMiddle] > AId then LHigh := LMiddle - 1');
  LCode.Add('    else');
  LCode.Add('    begin');
  LCode.Add('      case LMiddle of');
  for I := 0 to GProfiles.Count - 1 do
  begin
    LRow := TJSONObject(GProfiles.Objects[I]);
    LCode.Add('        ' + IntToStr(I) + ': AssignAdmission(AAdmission, AId, ' +
      Quoted(LRow.Get('kit', '')) + ', ' + Quoted(LRow.Get('sourceId', '')) + ',');
    LCode.Add('          ' + Quoted(LRow.Get('sourceSha256', '')) + ', ' +
      Quoted(LRow.Get('manifestSha256', '')) + ',');
    if GNature then
    begin
      LCode.Add('          ' + Quoted(LRow.Get('role', '')) + ', ''nature'', ' +
        Quoted(LRow.Get('name', '')) + ', ' + LRow.Find('uniformScale').AsJSON + ',');
    end else
    begin
      LCode.Add('          ' + Quoted(LRow.Get('category', '')) + ', ' +
      Quoted(LRow.Get('kit', '')) + ', ' + Quoted(LRow.Get('role', '')) + ', ' +
      Quoted(LRow.Get('name', '')) + ', ' + LRow.Find('uniformScale').AsJSON + ',');
    end;
    LCode.Add('          ' + LRow.Find('width').AsJSON + ', ' + LRow.Find('depth').AsJSON + ', ' +
      LRow.Find('height').AsJSON + ', ' + LRow.Find('triangles').AsJSON + ', ' +
      LRow.Find('vertices').AsJSON + ', ' + LRow.Find('texturePixels').AsJSON + ');');
  end;
  LCode.Add('      end;');
  LCode.Add('      Exit(True);');
  LCode.Add('    end;');
  LCode.Add('  end;');
  LCode.Add('end;');
  Require(GPassed > 0, 'batch admitted no models');
  if GEquipment then
  begin
    LCode.Text := StringReplace(StringReplace(LCode.Text, 'BatchIds', 'EquipmentIds',
      [rfReplaceAll]), 'BatchAdmission', 'EquipmentAdmission', [rfReplaceAll]);
  end;
  if GFurniture then
  begin
    LCode.Text := StringReplace(StringReplace(LCode.Text, 'BatchIds', 'FurnitureBatchIds',
      [rfReplaceAll]), 'BatchAdmission', 'FurnitureBatchAdmission', [rfReplaceAll]);
  end;
  WriteText(LIncludePath, LCode.Text);
  LReport := TJSONObject.Create;
  LReport.Add('version', 1);
  if GNature then
  begin
    LReport.Add('policy', 'static outdoor nature v1; uniform role-bounded normalization; no repairs');
  end else if GFurniture then
  begin
    LReport.Add('policy', 'static compact furniture v1; uniform category sizes; no editable supports or repairs');
  end else if GEquipment then
  begin
    LReport.Add('policy', 'static freestanding equipment v1; uniform category sizes; no repairs');
  end else
  begin
    LReport.Add('policy', 'static single-floor props v1; automatic uniform longest-axis normalization; no repairs');
  end;
  LReport.Add('inventorySha256', GGeometry.Get('inventorySha256', ''));
  LReport.Add('geometrySha256', HashFile('data/catalog-geometry.json'));
  LReport.Add('inventoryModels', GGeometry.Arrays['assets'].Count);
  LReport.Add('screened', GRows.Count);
  LReport.Add('passedNew', GPassed);
  LReport.Add('failed', GFailed);
  LReport.Add('alreadyIntegrated', GExistingCount);
  LReport.Add('outsideBatch', GGeometry.Arrays['assets'].Count - GRows.Count);
  LReport.Add('models', GRows);
  WriteText(LReportPath, LReport.FormatJSON);
  WriteLn('Screened ', GRows.Count, '; new pass ', GPassed, '; fail ', GFailed,
    '; existing ', GExistingCount);
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
