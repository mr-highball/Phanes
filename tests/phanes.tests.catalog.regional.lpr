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
program PhanesTestsCatalogRegional;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, FPJSON, CastleScene, CastleBoxes,
  phanes.catalog.regional, phanes.tools.files;

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

function FindObject(const AItems: TJSONArray; const AKey, AValue: String): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AItems.Count - 1 do
  begin
    if AItems.Objects[I].Strings[AKey] = AValue then
    begin
      Result := AItems.Objects[I];
      Exit;
    end;
  end;
end;

function Big32(const ABytes: TBytes; const AOffset: Integer): Cardinal;
begin
  Check((AOffset >= 0) and (AOffset + 4 <= Length(ABytes)),
    'PNG dimension field is in range');
  Result := (Cardinal(ABytes[AOffset]) shl 24) or
    (Cardinal(ABytes[AOffset + 1]) shl 16) or
    (Cardinal(ABytes[AOffset + 2]) shl 8) or Cardinal(ABytes[AOffset + 3]);
end;

function PNGPixels(const APath: String): Integer;
var
  LBytes: TBytes;
  LHeight: Cardinal;
  LWidth: Cardinal;
begin
  LBytes := ReadBytes(APath);
  Check((Length(LBytes) >= 24) and (LBytes[0] = $89) and (LBytes[1] = $50) and
    (LBytes[2] = $4E) and (LBytes[3] = $47), 'regional texture is a PNG');
  LWidth := Big32(LBytes, 16);
  LHeight := Big32(LBytes, 20);
  Check((LWidth > 0) and (LHeight > 0) and
    (Int64(LWidth) * LHeight <= High(Integer)), 'regional PNG pixels are bounded');
  Result := Integer(LWidth * LHeight);
end;

procedure ReadModelCosts(const ASourcePath: String; out AVertices,
  ATexturePixels: Integer; out AHasVisibleColor: Boolean);
var
  LAccessors: TJSONArray;
  LAttributes: TJSONObject;
  LBytes: TBytes;
  LImages: TJSONArray;
  LMesh: TJSONObject;
  LModel: TJSONObject;
  LMaterial: TJSONObject;
  LFactor: TJSONArray;
  LPbr: TJSONObject;
  LPositionAccessor: Integer;
  LPrimitive: TJSONObject;
  I: Integer;
  J: Integer;
begin
  LBytes := ReadBytes(ASourcePath);
  LModel := ModelJSON(LBytes, LowerCase(ExtractFileExt(ASourcePath)));
  try
    AVertices := 0;
    AHasVisibleColor := False;
    LAccessors := LModel.Arrays['accessors'];
    for I := 0 to LModel.Arrays['meshes'].Count - 1 do
    begin
      LMesh := LModel.Arrays['meshes'].Objects[I];
      for J := 0 to LMesh.Arrays['primitives'].Count - 1 do
      begin
        LPrimitive := LMesh.Arrays['primitives'].Objects[J];
        LAttributes := LPrimitive.Objects['attributes'];
        LPositionAccessor := LAttributes.Integers['POSITION'];
        Inc(AVertices, LAccessors.Objects[LPositionAccessor].Integers['count']);
        if LAttributes.Find('COLOR_0') <> nil then
        begin
          AHasVisibleColor := True;
        end;
      end;
    end;
    if LModel.Find('materials') <> nil then
    begin
      for I := 0 to LModel.Arrays['materials'].Count - 1 do
      begin
        LMaterial := LModel.Arrays['materials'].Objects[I];
        LPbr := TJSONObject(LMaterial.Find('pbrMetallicRoughness'));
        if LPbr <> nil then
        begin
          if LPbr.Find('baseColorTexture') <> nil then
          begin
            AHasVisibleColor := True;
          end;
          LFactor := TJSONArray(LPbr.Find('baseColorFactor'));
          if (LFactor <> nil) and
            ((Abs(LFactor.Floats[0] - LFactor.Floats[1]) > 0.02) or
            (Abs(LFactor.Floats[1] - LFactor.Floats[2]) > 0.02)) then
          begin
            AHasVisibleColor := True;
          end;
        end;
      end;
    end;
    ATexturePixels := 0;
    LImages := TJSONArray(LModel.Find('images'));
    if LImages <> nil then
    begin
      for I := 0 to LImages.Count - 1 do
      begin
        Check(LImages.Objects[I].Find('uri') <> nil,
          'regional fixture texture has an original relative URI');
        Inc(ATexturePixels, PNGPixels(ExtractFilePath(ASourcePath) +
          LImages.Objects[I].Strings['uri']));
      end;
    end;
  finally
    LModel.Free;
  end;
end;

procedure CheckBounds(const AAdmission: TRegionalAssetAdmission;
  const ASceneBox: TBox3D; const AGeometry: TJSONObject);
var
  LDepth: Double;
  LHeight: Double;
  LMaximumHorizontal: Integer;
  LWidth: Double;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    Check(Abs(ASceneBox.Data[0][I] - AGeometry.Arrays['minimum'].Floats[I]) < 0.000001,
      AAdmission.FId + ' native minimum matches measured geometry');
    Check(Abs(ASceneBox.Data[1][I] - AGeometry.Arrays['maximum'].Floats[I]) < 0.000001,
      AAdmission.FId + ' native maximum matches measured geometry');
  end;
  LWidth := (ASceneBox.Data[1].X - ASceneBox.Data[0].X) *
    AAdmission.FUniformScale * 1000;
  LDepth := (ASceneBox.Data[1].Z - ASceneBox.Data[0].Z) *
    AAdmission.FUniformScale * 1000;
  LHeight := (ASceneBox.Data[1].Y - ASceneBox.Data[0].Y) *
    AAdmission.FUniformScale * 1000;
  Check(AAdmission.FWidth = Ceil(LWidth), AAdmission.FId + ' width is conservative');
  Check(AAdmission.FDepth = Ceil(LDepth), AAdmission.FId + ' depth is conservative');
  Check(AAdmission.FHeight = Ceil(LHeight), AAdmission.FId + ' height is conservative');
  if AAdmission.FRole = 'tree' then
  begin
    LMaximumHorizontal := 3600;
  end else
  if AAdmission.FRole = 'shrub' then
  begin
    LMaximumHorizontal := 2000;
  end else
  if AAdmission.FRole = 'flowers' then
  begin
    LMaximumHorizontal := 700;
  end else
  if AAdmission.FRole = 'wheat' then
  begin
    LMaximumHorizontal := 1200;
  end else
  if AAdmission.FRole = 'rock' then
  begin
    LMaximumHorizontal := 2400;
  end else
  begin
    LMaximumHorizontal := 0;
  end;
  Check(LMaximumHorizontal > 0, AAdmission.FId + ' uses a regional role');
  Check(Max(AAdmission.FWidth, AAdmission.FDepth) <= LMaximumHorizontal,
    AAdmission.FId + ' full horizontal envelope fits its role maximum');
end;

procedure CheckRecord(const ARoot: String; const AIndex, AGeometryRoot: TJSONObject;
  const AAdmission: TRegionalAssetAdmission; var ASourceBytes: Int64;
  var ATriangles, AVertices, ATexturePixels: Integer);
var
  LBox: TBox3D;
  LFile: TJSONObject;
  LGeometry: TJSONObject;
  LHasVisibleColor: Boolean;
  LKit: TJSONObject;
  LManifest: TJSONObject;
  LManifestPath: String;
  LModel: TJSONObject;
  LPublishedPath: String;
  LScene: TCastleScene;
  LSourcePath: String;
  LTexturePixels: Integer;
  LVertices: Integer;
begin
  LKit := FindObject(AIndex.Arrays['kits'], 'id', AAdmission.FKitId);
  Check(LKit <> nil, AAdmission.FId + ' kit is published');
  Check(LKit.Strings['sha256'] = AAdmission.FManifestSha256,
    AAdmission.FId + ' descriptor binds its manifest');
  LManifestPath := SafeChild(ARoot, 'build/web/' + LKit.Strings['url']);
  Check(HashFile(LManifestPath) = AAdmission.FManifestSha256,
    AAdmission.FId + ' manifest bytes match');
  LManifest := LoadJSON(LManifestPath);
  LScene := nil;
  try
    LModel := FindObject(LManifest.Arrays['models'], 'id', AAdmission.FModelId);
    Check(LModel <> nil, AAdmission.FId + ' model is published');
    Check(LModel.Strings['sha256'] = AAdmission.FSourceSha256,
      AAdmission.FId + ' manifest binds its source hash');
    LFile := FindObject(LModel.Arrays['files'], 'path', LModel.Strings['path']);
    Check(LFile <> nil, AAdmission.FId + ' closure contains its root model');
    LPublishedPath := SafeChild(ARoot, 'build/web/' + LFile.Strings['url']);
    Check(HashFile(LPublishedPath) = AAdmission.FSourceSha256,
      AAdmission.FId + ' published root has its source hash');
    LSourcePath := SafeChild(ARoot, 'assets/library/kits/' + AAdmission.FKitId +
      '/' + LModel.Strings['path']);
    Check(HashFile(LSourcePath) = AAdmission.FSourceSha256,
      AAdmission.FId + ' native source has its admitted hash');
    ReadModelCosts(LSourcePath, LVertices, LTexturePixels, LHasVisibleColor);
    Check(LVertices = AAdmission.FVertices,
      AAdmission.FId + ' position vertices match');
    Check(LTexturePixels = AAdmission.FTexturePixels,
      AAdmission.FId + ' texture pixels match');
    if (AAdmission.FRole = 'tree') or (AAdmission.FRole = 'flowers') then
    begin
      Check(LHasVisibleColor,
        AAdmission.FId + ' source has texture, vertex color, or colored material');
    end;
    LScene := TCastleScene.Create(nil);
    LScene.Load(LSourcePath);
    Check(LScene.TrianglesCount = AAdmission.FTriangles,
      AAdmission.FId + ' Castle triangles match');
    LBox := LScene.BoundingBox;
    Check(not LBox.IsEmpty, AAdmission.FId + ' Castle bounds are measurable');
    LGeometry := FindObject(AGeometryRoot.Arrays['assets'], 'id', AAdmission.FModelId);
    Check((LGeometry <> nil) and (LGeometry.Strings['status'] = 'decoded'),
      AAdmission.FId + ' has decoded independent geometry evidence');
    Check(LGeometry.Integers['triangles'] = AAdmission.FTriangles,
      AAdmission.FId + ' geometry evidence triangles match');
    CheckBounds(AAdmission, LBox, LGeometry);
    Inc(ASourceBytes, LModel.Int64s['downloadBytes'] +
      LManifest.Objects['notice'].Int64s['bytes']);
    Inc(ATriangles, AAdmission.FTriangles);
    Inc(AVertices, AAdmission.FVertices);
    Inc(ATexturePixels, AAdmission.FTexturePixels);
  finally
    LScene.Free;
    LManifest.Free;
  end;
end;

procedure CheckCatalog(const ARoot: String);
var
  LAdmission: TRegionalAssetAdmission;
  LFresh: TRegionalAssetAdmission;
  LGeometry: TJSONObject;
  LIds: TRegionalAssetIds;
  LIndex: TJSONObject;
  LRoleCounts: array[0..4] of Integer;
  LSourceBytes: Int64;
  LTexturePixels: Integer;
  LTriangles: Integer;
  LVertices: Integer;
  I: Integer;
  J: Integer;
begin
  LIds := RegionalAssetIds;
  Check(Length(LIds) = 18, 'regional batch has exactly 18 models');
  for I := 0 to High(LIds) do
  begin
    for J := I + 1 to High(LIds) do
    begin
      Check(LIds[I] <> LIds[J], 'regional IDs are unique');
    end;
  end;
  LAdmission.FName := 'stale';
  Check(not RegionalAssetAdmission('unknown', LAdmission), 'unknown regional ID is rejected');
  Check((LAdmission.FName = '') and (LAdmission.FVertices = 0),
    'unknown regional ID returns a default record');
  LIds[0] := 'mutated';
  Check(RegionalAssetIds[0] = 'phanes.catalog.tree.forest-canopy.v1',
    'regional ID arrays are independent');
  Check(RegionalAssetAdmission(RegionalAssetIds[0], LAdmission),
    'regional record is available for mutation check');
  LAdmission.FName := 'mutated';
  Check(RegionalAssetAdmission(RegionalAssetIds[0], LFresh) and
    (LFresh.FName = 'Forest canopy tree'), 'regional records do not alias metadata');

  LIndex := LoadJSON(SafeChild(ARoot, 'build/web/data/library-files.json'));
  LGeometry := LoadJSON(SafeChild(ARoot, 'data/catalog-geometry.json'));
  LSourceBytes := 0;
  LTriangles := 0;
  LVertices := 0;
  LTexturePixels := 0;
  for I := 0 to 4 do
  begin
    LRoleCounts[I] := 0;
  end;
  try
    LIds := RegionalAssetIds;
    for I := 0 to High(LIds) do
    begin
      Check(RegionalAssetAdmission(LIds[I], LAdmission), LIds[I] + ' resolves');
      if LAdmission.FRole = 'tree' then
      begin
        Inc(LRoleCounts[0]);
      end else
      if LAdmission.FRole = 'shrub' then
      begin
        Inc(LRoleCounts[1]);
      end else
      if LAdmission.FRole = 'flowers' then
      begin
        Inc(LRoleCounts[2]);
      end else
      if LAdmission.FRole = 'wheat' then
      begin
        Inc(LRoleCounts[3]);
      end else
      if LAdmission.FRole = 'rock' then
      begin
        Inc(LRoleCounts[4]);
      end;
      CheckRecord(ARoot, LIndex, LGeometry, LAdmission, LSourceBytes,
        LTriangles, LVertices, LTexturePixels);
    end;
  finally
    LGeometry.Free;
    LIndex.Free;
  end;
  Check((LRoleCounts[0] = 4) and (LRoleCounts[1] = 4) and
    (LRoleCounts[2] = 4) and (LRoleCounts[3] = 3) and (LRoleCounts[4] = 3),
    'regional role counts are 4/4/4/3/3');
  Check(LTriangles <= 20000, 'regional batch stays below 20,000 triangles');
  Check(LTexturePixels <= 2 * 1024 * 1024,
    'regional batch stays below two million texture pixels');
  Check(LSourceBytes + 23480 + 51001 <= 16 * 1024 * 1024,
    'combined admission stays below 16 MiB staged source bytes');
  Check(LTriangles + 68 + 204 <= 50000,
    'combined admission stays below 50,000 triangles');
  Check(LVertices + 112 + 612 <= 250000,
    'combined admission stays below 250,000 position vertices');
  Check(LTexturePixels + 1048576 <= 4 * 1024 * 1024,
    'combined admission stays below four million texture pixels');
  Check(Length(LIds) + 2 <= 32, 'combined admission stays below 32 models');
  WriteLn('REGIONAL ', LSourceBytes, ' source bytes; ', LTriangles,
    ' triangles; ', LVertices, ' vertices; ', LTexturePixels, ' texture pixels');
end;

begin
  try
    Check(ParamCount = 1, 'Usage: catalog-regional-check REPOSITORY');
    CheckCatalog(ParamStr(1));
    WriteLn('PASS ', GChecks, ' regional catalog checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
