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
program PhanesTestsCatalogAdmission;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, FPJSON, CastleScene, CastleBoxes,
  phanes.catalog.admission, phanes.tools.files;

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

function FindObject(const AItems: TJSONArray; const AKey,
  AValue: String): TJSONObject;
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
    'PNG field in range');
  Result := (Cardinal(ABytes[AOffset]) shl 24) or
    (Cardinal(ABytes[AOffset + 1]) shl 16) or
    (Cardinal(ABytes[AOffset + 2]) shl 8) or
    Cardinal(ABytes[AOffset + 3]);
end;

function PNGPixels(const APath: String): Integer;
var
  LBytes: TBytes;
  LHeight: Cardinal;
  LWidth: Cardinal;
begin
  LBytes := ReadBytes(APath);
  Check((Length(LBytes) >= 24) and (LBytes[0] = $89) and
    (LBytes[1] = $50) and (LBytes[2] = $4E) and (LBytes[3] = $47),
    'texture is PNG');
  LWidth := Big32(LBytes, 16);
  LHeight := Big32(LBytes, 20);
  Check((LWidth > 0) and (LHeight > 0) and
    (Int64(LWidth) * LHeight <= High(Integer)),
    'PNG pixels bounded');
  Result := Integer(LWidth * LHeight);
end;

procedure ModelCosts(const ASourcePath: String; out AVertices,
  ATexturePixels: Integer; out AHasVisibleColor: Boolean);
var
  LAccessors: TJSONArray;
  LAttributes: TJSONObject;
  LBytes: TBytes;
  LFactor: TJSONArray;
  LImages: TJSONArray;
  LMaterial: TJSONObject;
  LMesh: TJSONObject;
  LModel: TJSONObject;
  LPbr: TJSONObject;
  LPrimitive: TJSONObject;
  I: Integer;
  J: Integer;
begin
  LBytes := ReadBytes(ASourcePath);
  LModel := ModelJSON(LBytes, LowerCase(ExtractFileExt(ASourcePath)));
  try
    AVertices := 0;
    ATexturePixels := 0;
    AHasVisibleColor := False;
    LAccessors := LModel.Arrays['accessors'];
    for I := 0 to LModel.Arrays['meshes'].Count - 1 do
    begin
      LMesh := LModel.Arrays['meshes'].Objects[I];
      for J := 0 to LMesh.Arrays['primitives'].Count - 1 do
      begin
        LPrimitive := LMesh.Arrays['primitives'].Objects[J];
        LAttributes := LPrimitive.Objects['attributes'];
        Inc(AVertices, LAccessors.Objects[
          LAttributes.Integers['POSITION']].Integers['count']);
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
    LImages := TJSONArray(LModel.Find('images'));
    if LImages <> nil then
    begin
      for I := 0 to LImages.Count - 1 do
      begin
        Check(LImages.Objects[I].Find('uri') <> nil,
          'texture URI is external');
        Inc(ATexturePixels, PNGPixels(ExtractFilePath(ASourcePath) +
          LImages.Objects[I].Strings['uri']));
      end;
    end;
  finally
    LModel.Free;
  end;
end;

procedure CheckRecord(const ARoot: String; const AIndex,
  AGeometryRoot: TJSONObject; const AAdmission: TOptionalAssetAdmission;
  const AIsNew: Boolean; var ASourceBytes: Int64);
var
  LBox: TBox3D;
  LFile: TJSONObject;
  LGeometry: TJSONObject;
  LHasVisibleColor: Boolean;
  LHeight: Double;
  LKit: TJSONObject;
  LManifest: TJSONObject;
  LManifestPath: String;
  LModel: TJSONObject;
  LPublishedPath: String;
  LScene: TCastleScene;
  LSourcePath: String;
  LTexturePixels: Integer;
  LVertices: Integer;
  LWidth: Double;
  LDepth: Double;
  I: Integer;
begin
  LKit := FindObject(AIndex.Arrays['kits'], 'id', AAdmission.FKitId);
  Check(LKit <> nil, AAdmission.FId + ' kit published');
  Check(LKit.Strings['sha256'] = AAdmission.FManifestSha256,
    AAdmission.FId + ' manifest bound');
  LManifestPath := SafeChild(ARoot, 'build/web/' + LKit.Strings['url']);
  Check(HashFile(LManifestPath) = AAdmission.FManifestSha256,
    AAdmission.FId + ' manifest hash');
  LManifest := LoadJSON(LManifestPath);
  LScene := nil;
  try
    LModel := FindObject(LManifest.Arrays['models'], 'id', AAdmission.FModelId);
    Check(LModel <> nil, AAdmission.FId + ' model published');
    Check(LModel.Strings['sha256'] = AAdmission.FSourceSha256,
      AAdmission.FId + ' source bound');
    LFile := FindObject(LModel.Arrays['files'], 'path', LModel.Strings['path']);
    Check(LFile <> nil, AAdmission.FId + ' root in closure');
    LPublishedPath := SafeChild(ARoot, 'build/web/' + LFile.Strings['url']);
    Check(HashFile(LPublishedPath) = AAdmission.FSourceSha256,
      AAdmission.FId + ' published hash');
    LSourcePath := SafeChild(ARoot, 'assets/library/kits/' + AAdmission.FKitId +
      '/' + LModel.Strings['path']);
    Check(HashFile(LSourcePath) = AAdmission.FSourceSha256,
      AAdmission.FId + ' native hash');
    ModelCosts(LSourcePath, LVertices, LTexturePixels, LHasVisibleColor);
    Check(LVertices = AAdmission.FVertices, AAdmission.FId + ' vertices');
    Check(LTexturePixels = AAdmission.FTexturePixels,
      AAdmission.FId + ' texture pixels');
    if AIsNew then
    begin
      Check(LHasVisibleColor, AAdmission.FId + ' has visible source color');
    end;
    LScene := TCastleScene.Create(nil);
    LScene.Load(LSourcePath);
    Check(LScene.TrianglesCount = AAdmission.FTriangles,
      AAdmission.FId + ' Castle triangles');
    LBox := LScene.BoundingBox;
    Check(not LBox.IsEmpty, AAdmission.FId + ' bounds measured');
    LGeometry := FindObject(AGeometryRoot.Arrays['assets'], 'id',
      AAdmission.FModelId);
    Check((LGeometry <> nil) and (LGeometry.Strings['status'] = 'decoded'),
      AAdmission.FId + ' geometry decoded');
    Check(LGeometry.Integers['triangles'] = AAdmission.FTriangles,
      AAdmission.FId + ' evidence triangles');
    for I := 0 to 2 do
    begin
      Check(Abs(LBox.Data[0][I] -
        LGeometry.Arrays['minimum'].Floats[I]) < 0.000001,
        AAdmission.FId + ' minimum evidence');
      Check(Abs(LBox.Data[1][I] -
        LGeometry.Arrays['maximum'].Floats[I]) < 0.000001,
        AAdmission.FId + ' maximum evidence');
    end;
    LWidth := (LBox.Data[1].X - LBox.Data[0].X) *
      AAdmission.FUniformScale * 1000;
    LDepth := (LBox.Data[1].Z - LBox.Data[0].Z) *
      AAdmission.FUniformScale * 1000;
    LHeight := (LBox.Data[1].Y - LBox.Data[0].Y) *
      AAdmission.FUniformScale * 1000;
    Check((AAdmission.FWidth >= LWidth) and
      (AAdmission.FWidth < LWidth + 1.01),
      AAdmission.FId + ' width envelope');
    Check((AAdmission.FDepth >= LDepth) and
      (AAdmission.FDepth < LDepth + 1.01),
      AAdmission.FId + ' depth envelope');
    Check((AAdmission.FHeight >= LHeight) and
      (AAdmission.FHeight < LHeight + 1.01),
      AAdmission.FId + ' height envelope');
    if AIsNew and (AAdmission.FCategory = 'Objects') then
    begin
      Check((AAdmission.FWidth <= 150) and (AAdmission.FDepth <= 190) and
        (AAdmission.FHeight <= 270), AAdmission.FId + ' object slot cap');
    end;
    if AIsNew and (AAdmission.FCategory = 'Food') then
    begin
      Check((AAdmission.FWidth <= 50) and (AAdmission.FHeight <= 75),
        AAdmission.FId + ' plate cap');
      if AAdmission.FRole = 'bread' then
      begin
        Check(AAdmission.FDepth <= 95, AAdmission.FId + ' bread depth');
      end
      else
      begin
        Check(((AAdmission.FRole = 'fruit') or
          (AAdmission.FRole = 'cheese')) and (AAdmission.FDepth <= 50),
          AAdmission.FId + ' square plate role/depth');
      end;
    end;
    Inc(ASourceBytes, LModel.Int64s['downloadBytes'] +
      LManifest.Objects['notice'].Int64s['bytes']);
  finally
    LScene.Free;
    LManifest.Free;
  end;
end;

function SourceCost(const ARoot: String; const AIndex: TJSONObject;
  const AAdmission: TOptionalAssetAdmission): Int64;
var
  LKit: TJSONObject;
  LManifest: TJSONObject;
  LModel: TJSONObject;
begin
  LKit := FindObject(AIndex.Arrays['kits'], 'id', AAdmission.FKitId);
  Check(LKit <> nil, AAdmission.FId + ' budget kit');
  LManifest := LoadJSON(SafeChild(ARoot,
    'build/web/' + LKit.Strings['url']));
  try
    LModel := FindObject(LManifest.Arrays['models'], 'id', AAdmission.FModelId);
    Check(LModel <> nil, AAdmission.FId + ' budget model');
    Result := LModel.Int64s['downloadBytes'] +
      LManifest.Objects['notice'].Int64s['bytes'];
  finally
    LManifest.Free;
  end;
end;

procedure CheckCatalog(const ARoot: String);
var
  LAddedCount: Integer;
  LAdmission: TOptionalAssetAdmission;
  LFreshAdmission: TOptionalAssetAdmission;
  LGeometry: TJSONObject;
  LIds: TOptionalAssetIds;
  LIndex: TJSONObject;
  LInteriorBytes: Int64;
  LInteriorCount: Integer;
  LSourceBytes: Int64;
  LTexturePixels: Integer;
  LTriangles: Integer;
  LVertices: Integer;
  I: Integer;
  J: Integer;
begin
  LIds := OptionalAssetIds;
  Check(Length(LIds) = 32, 'exactly 32 optional IDs');
  for I := 0 to High(LIds) do
  begin
    for J := I + 1 to High(LIds) do
    begin
      Check(LIds[I] <> LIds[J], 'optional IDs unique');
    end;
  end;
  LAdmission.FName := 'stale';
  LAdmission.FWidth := 999;
  Check(not OptionalAssetAdmission('unknown', LAdmission), 'unknown rejected');
  Check((LAdmission.FId = '') and (LAdmission.FName = '') and
    (LAdmission.FWidth = 0), 'unknown clears record');
  LIds[0] := 'mutated';
  Check(OptionalAssetIds[0] = 'phanes.catalog.book.kaykit-single.v1',
    'ID arrays independent');
  Check(OptionalAssetAdmission('phanes.catalog.book.kaykit-single.v1',
    LAdmission), 'book resolves');
  LAdmission.FName := 'mutated';
  Check(OptionalAssetAdmission('phanes.catalog.book.kaykit-single.v1',
    LFreshAdmission) and (LFreshAdmission.FName = 'Bound book') and
    (LFreshAdmission.FWidth = 131) and (LFreshAdmission.FDepth = 183) and
    (LFreshAdmission.FHeight = 251) and (LFreshAdmission.FTriangles = 68) and
    (LFreshAdmission.FVertices = 112) and
    (LFreshAdmission.FTexturePixels = 1048576),
    'book exact and records independent');
  Check(OptionalAssetAdmission('phanes.catalog.vase.quaternius.v1',
    LFreshAdmission) and (LFreshAdmission.FWidth = 143) and
    (LFreshAdmission.FDepth = 143) and (LFreshAdmission.FHeight = 261) and
    (LFreshAdmission.FTriangles = 204) and (LFreshAdmission.FVertices = 612) and
    (LFreshAdmission.FTexturePixels = 0),
    'vase exact');
  LIndex := LoadJSON(SafeChild(ARoot, 'build/web/data/library-files.json'));
  LGeometry := LoadJSON(SafeChild(ARoot, 'data/catalog-geometry.json'));
  LInteriorCount := 0;
  LAddedCount := 0;
  LTriangles := 0;
  LVertices := 0;
  LTexturePixels := 0;
  LSourceBytes := 0;
  LInteriorBytes := 0;
  try
    LIds := OptionalAssetIds;
    for I := 0 to High(LIds) do
    begin
      Check(OptionalAssetAdmission(LIds[I], LAdmission),
        LIds[I] + ' resolves');
      Check(LAdmission.FId = LIds[I], LIds[I] + ' stable identity');
      Inc(LTriangles, LAdmission.FTriangles);
      Inc(LVertices, LAdmission.FVertices);
      Inc(LTexturePixels, LAdmission.FTexturePixels);
      Inc(LSourceBytes, SourceCost(ARoot, LIndex, LAdmission));
      if LAdmission.FDomain = oadInterior then
      begin
        Inc(LInteriorCount);
        if (I >= 2) and (I < 14) then
        begin
          Inc(LAddedCount);
        end;
        CheckRecord(ARoot, LIndex, LGeometry, LAdmission,
          (I >= 2) and (I < 14), LInteriorBytes);
      end;
    end;
  finally
    LGeometry.Free;
    LIndex.Free;
  end;
  Check((LInteriorCount = 14) and (LAddedCount = 12),
    'two retained plus twelve new interiors');
  Check(LSourceBytes = 1838347, 'verified 32-model source bytes');
  Check(LTriangles = 11623, 'verified 32-model triangles');
  Check(LVertices = 33017, 'verified 32-model vertices');
  Check(LTexturePixels = 3670016, 'verified 32-model texture pixels');
  Check((LSourceBytes <= 16 * 1024 * 1024) and (LTriangles <= 50000) and
    (LVertices <= 250000) and (LTexturePixels <= 4 * 1024 * 1024),
    'runtime budgets fit');
  WriteLn('OPTIONAL ', LSourceBytes, ' source bytes; ', LTriangles,
    ' triangles; ', LVertices, ' vertices; ', LTexturePixels,
    ' texture pixels');
  WriteLn('INTERIOR ', LInteriorCount, ' models; ', LInteriorBytes,
    ' source bytes verified');
end;

begin
  try
    Check(ParamCount = 1, 'Usage: catalog-admission-check REPOSITORY');
    CheckCatalog(ParamStr(1));
    WriteLn('PASS ', GChecks, ' optional catalog admission checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
