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

unit phanes.tools.collections;

{$mode delphi}
{$H+}

interface

uses
  FPJSON;

procedure CheckCollectionKit(const AKit: TJSONObject);
procedure ImportCollectionKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
procedure VerifyCollectionKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);

implementation

uses
  Classes,
  SysUtils,
  Zipper,
  phanes.tools.files,
  phanes.tools.kits,
  phanes.tools.sourcehtml;

procedure CheckModelByteCount(const AValue: TJSONData);
begin
  Require((AValue is TJSONNumber) and
    (TJSONNumber(AValue).NumberType in [ntInteger, ntInt64, ntQWord]),
    'Model byte count must be a JSON integer');
  Require((AValue.AsInt64 > 0) and (AValue.AsInt64 <= 32 * 1024 * 1024),
    'Model byte count exceeds bounds');
end;

procedure CheckHash(const AHash: String);
var
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Expected source SHA-256');
  for I := 1 to Length(AHash) do
  begin
    Require(AHash[I] in ['0'..'9', 'a'..'f'], 'Noncanonical source SHA-256');
  end;
end;

function SourceMap(const AKit: TJSONObject): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.UseLocale := False;
  for I := 0 to AKit.Arrays['sources'].Count - 1 do
  begin
    Result.AddObject(AKit.Arrays['sources'].Objects[I].Strings['id'],
      AKit.Arrays['sources'].Objects[I]);
  end;
end;

procedure CheckCollectionKit(const AKit: TJSONObject);
var
  LIds: TStringList;
  LPaths: TStringList;
  LSource: TJSONObject;
  LModel: TJSONObject;
  LId: String;
  LPath: String;
  LTotal: Int64;
  LCount: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Require((AKit.Get('sourceMode', '') = 'collection.v1') and
    (AKit.Get('sourceAdapter', '') = 'basemesh.v1'), 'Unsupported collection source adapter');
  Require((AKit.Get('storage', '') = 'library') and
    (AKit.Strings['license'] = 'CC0-1.0'), 'Unsupported collection storage/license');
  Require((AKit.Find('archiveUrl') = nil) and (AKit.Find('archiveSha256') = nil) and
    (AKit.Find('modelPrefix') = nil) and (AKit.Find('modelFormat') = nil) and
    (AKit.Find('licensePath') = nil) and (AKit.Find('dependencyAliases') = nil),
    'Collection and single-archive fields cannot be combined');
  Require((AKit.Arrays['sources'].Count > 0) and (AKit.Arrays['sources'].Count <= 2000),
    'Collection source count exceeds bounds');
  CheckHash(AKit.Objects['licenseEvidence'].Strings['sha256']);
  CheckHash(AKit.Objects['licenseEvidence'].Strings['compressedSha256']);
  CheckArchivePath(AKit.Objects['licenseEvidence'].Strings['path']);
  Require(AKit.Objects['licenseEvidence'].Strings['path'] =
    'assets/provenance/' + AKit.Strings['id'] + '/faq.html.zlib',
    'Collection FAQ evidence path differs from snapshot namespace');
  LIds := TStringList.Create;
  LIds.Sorted := True;
  LIds.CaseSensitive := False;
  LPaths := TStringList.Create;
  LPaths.Sorted := True;
  LPaths.CaseSensitive := False;
  LCount := 0;
  LTotal := 0;
  try
    for I := 0 to AKit.Arrays['sources'].Count - 1 do
    begin
      LSource := AKit.Arrays['sources'].Objects[I];
      LId := LSource.Strings['id'];
      Require((LId <> '') and (Length(LId) <= 100), 'Invalid collection source ID');
      for J := 1 to Length(LId) do
      begin
        Require(LId[J] in ['a'..'z', '0'..'9', '-', '_'], 'Noncanonical collection source ID');
      end;
      Require((LIds.IndexOf(LId) < 0) and (LId <> 'provenance') and (LId <> 'faq'),
        'Duplicate/reserved collection source ID');
      LIds.Add(LId);
      Require((LSource.Get('modelPrefix', '') = '') and
        (LSource.Get('modelFormat', '') = 'gltf2') and
        (LSource.Find('dependencyAliases') = nil), 'Unsupported collection source selection');
      CheckHash(LSource.Strings['archiveSha256']);
      CheckHash(LSource.Strings['pageSha256']);
      CheckHash(LSource.Strings['pageEvidenceSha256']);
      CheckArchivePath(LSource.Strings['pageEvidence']);
      Require(LSource.Strings['pageEvidence'] =
        'assets/provenance/' + AKit.Strings['id'] + '/' + LId + '.html.zlib',
        'Source page evidence path differs from snapshot namespace');
      Require(Copy(LSource.Strings['archiveUrl'], 1, 8) = 'https://',
        'Collection archive must use HTTPS');
      Require(Copy(LSource.Strings['page'], 1, 8) = 'https://',
        'Collection page must use HTTPS');
      Require((LSource.Arrays['models'].Count > 0) and
        (LSource.Arrays['models'].Count <= 5000), 'Invalid source model count');
      LPaths.Clear;
      for J := 0 to LSource.Arrays['models'].Count - 1 do
      begin
        LModel := LSource.Arrays['models'].Objects[J];
        LPath := LModel.Strings['path'];
        CheckArchivePath(LPath);
        Require((ExtractFileExt(LPath) = '.glb') or (ExtractFileExt(LPath) = '.gltf'),
          'Collection model must be original glTF 2.0');
        Require(LPaths.IndexOf(ChangeFileExt(LPath, '')) < 0,
          'Collection model identity collision');
        LPaths.Add(ChangeFileExt(LPath, ''));
        CheckHash(LModel.Strings['sha256']);
        CheckModelByteCount(LModel.Find('bytes'));
        Require((LModel.Int64s['bytes'] > 0) and
          (LModel.Int64s['bytes'] <= 32 * 1024 * 1024), 'Source model exceeds size bounds');
        Inc(LTotal, LModel.Int64s['bytes']);
        Inc(LCount);
        Require((LTotal <= 1024 * 1024 * 1024) and (LCount <= 5000),
          'Collection declared model totals exceed bounds');
      end;
      { A source owns all of its dependency paths. Models are the exact selected
        original members; format copies and undeclared models are not counted. }
      for K := 0 to LSource.Count - 1 do
      begin
        Require(LSource.Names[K] <> 'licensePath',
          'Collection FAQ mode cannot override an archive notice');
      end;
    end;
  finally
    LPaths.Free;
    LIds.Free;
  end;
end;

function EvidenceText(const ARoot, APath, ACompressedHash, ARawHash: String): String;
var
  LPath: String;
begin
  CheckArchivePath(APath);
  LPath := SafeChild(ARoot, APath);
  CheckExactFilePath(ARoot, APath);
  Require(HashFile(LPath) = ACompressedHash, 'Compressed source evidence changed');
  Result := ReadSourceEvidence(LPath, ARawHash);
end;

function SourceDependencies(const AModel, ASource: TJSONObject;
  const AKitRoot, AModelPath: String): TJSONArray;
var
  LSourceRoot: String;
  LPath: String;
  I: Integer;
begin
  LSourceRoot := SafeChild(AKitRoot, ASource.Strings['id']);
  Result := ModelDependencies(AModel, ASource, LSourceRoot, AModelPath);
  try
    for I := 0 to Result.Count - 1 do
    begin
      LPath := Result.Objects[I].Strings['path'];
      CheckExactFilePath(LSourceRoot, LPath);
      Result.Objects[I].Strings['path'] := ASource.Strings['id'] + '/' + LPath;
    end;
  except
    Result.Free;
    raise;
  end;
end;

type
  TCollectionImporter = class
  private
    FStage: String;
    FSource: TJSONObject;
    FFiles: TStringList;
    FTotal: Int64;
    procedure CreateStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure ExtractSource(const ARoot: String; const ASource: TJSONObject);
  public
    procedure Run(const ARoot: String; const AKit: TJSONObject; const AInventory: TJSONArray);
  end;

procedure TCollectionImporter.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  Require((AItem.Size >= 0) and (AItem.Size <= 32 * 1024 * 1024),
    'Collection archive member exceeds bound');
  AStream := TMemoryStream.Create;
end;

procedure TCollectionImporter.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LBytes: TBytes;
  LRelative: String;
begin
  try
    Require(AStream.Size = AItem.Size, 'Collection extracted member size differs');
    LRelative := FSource.Strings['id'] + '/' + AItem.ArchiveFileName;
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      AStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    WriteBytes(SafeChild(FStage, LRelative), LBytes);
    FFiles.Add(LRelative);
  finally
    FreeAndNil(AStream);
  end;
end;

procedure TCollectionImporter.ExtractSource(const ARoot: String; const ASource: TJSONObject);
var
  LArchive: String;
  LZip: TUnZipper;
  LNames: TStringList;
  LFiles: TStringList;
  LModels: TStringList;
  LName: String;
  LExtension: String;
  I: Integer;
begin
  FSource := ASource;
  LArchive := SafeChild(ARoot, 'build/asset-research/collections/' +
    ASource.Strings['archiveSha256'] + '.zip');
  FetchPinned(ASource.Strings['archiveUrl'], LArchive, ASource.Strings['archiveSha256']);
  LZip := TUnZipper.Create;
  LNames := TStringList.Create;
  LNames.Sorted := True;
  LNames.CaseSensitive := False;
  LFiles := TStringList.Create;
  LFiles.Sorted := True;
  LFiles.CaseSensitive := True;
  LFiles.UseLocale := False;
  LModels := TStringList.Create;
  LModels.Sorted := True;
  LModels.CaseSensitive := True;
  try
    for I := 0 to ASource.Arrays['models'].Count - 1 do
    begin
      LModels.Add(ASource.Arrays['models'].Objects[I].Strings['path']);
    end;
    LZip.FileName := LArchive;
    LZip.Examine;
    Require(LZip.Entries.Count <= 20000, 'Collection archive entry count exceeds bound');
    for I := 0 to LZip.Entries.Count - 1 do
    begin
      LName := LZip.Entries[I].ArchiveFileName;
      LExtension := LowerCase(ExtractFileExt(LName));
      Require(not ((Copy(LowerCase(ExtractFileName(LName)), 1, 7) = 'license') and
        ((LExtension = '.txt') or (LExtension = '.md'))),
        'Collection FAQ mode cannot replace a bundled archive notice');
      if (LModels.IndexOf(LName) >= 0) or
        (LExtension = '.bin') or (LExtension = '.png') or (LExtension = '.jpg') or
        (LExtension = '.jpeg') then
      begin
        CheckArchivePath(LName);
        Require(LNames.IndexOf(LName) < 0, 'Case-folded collection archive collision');
        LNames.Add(LName);
        LFiles.Add(LName);
        Require((LZip.Entries[I].Size >= 0) and
          (LZip.Entries[I].Size <= 32 * 1024 * 1024), 'Collection member exceeds bound');
        Inc(FTotal, LZip.Entries[I].Size);
        Require((FTotal <= 1024 * 1024 * 1024) and
          (FFiles.Count + LFiles.Count <= 20000), 'Collection expansion exceeds aggregate bounds');
      end;
    end;
    for I := 0 to LModels.Count - 1 do
    begin
      Require(LFiles.IndexOf(LModels[I]) >= 0, 'Pinned original model member is absent');
    end;
    Require(LFiles.Count > 0, 'Collection source selection is empty');
    LZip.OnCreateStream := CreateStream;
    LZip.OnDoneStream := DoneStream;
    LZip.UnZipFiles(LFiles);
  finally
    LModels.Free;
    LFiles.Free;
    LNames.Free;
    LZip.Free;
  end;
end;

procedure TCollectionImporter.Run(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
var
  LSources: TStringList;
  LModels: TStringList;
  LSource: TJSONObject;
  LModelPin: TJSONObject;
  LModel: TJSONObject;
  LRow: TJSONObject;
  LBytes: TBytes;
  LFAQ: String;
  LFAQHash: String;
  LPath: String;
  LRelative: String;
  LPublished: String;
  LSourcePath: String;
  LGuid: TGUID;
  LStart: Integer;
  I: Integer;
  J: Integer;
begin
  CheckCollectionKit(AKit);
  LStart := AInventory.Count;
  LFAQ := EvidenceText(ARoot, AKit.Objects['licenseEvidence'].Strings['path'],
    AKit.Objects['licenseEvidence'].Strings['compressedSha256'],
    AKit.Objects['licenseEvidence'].Strings['sha256']);
  CheckBaseMeshFAQ(AKit, LFAQ);
  CreateGUID(LGuid);
  FStage := SafeChild(ARoot, 'build/asset-staging/' + GUIDToString(LGuid));
  Require(not DirectoryExists(FStage), 'Expected fresh collection stage');
  LPublished := SafeChild(ARoot, 'assets/library/kits/' + AKit.Strings['id']);
  FFiles := TStringList.Create;
  FFiles.Sorted := True;
  FFiles.CaseSensitive := True;
  FFiles.UseLocale := False;
  LSources := SourceMap(AKit);
  LModels := TStringList.Create;
  LModels.Sorted := True;
  LModels.CaseSensitive := True;
  LModels.UseLocale := False;
  FTotal := Length(LFAQ);
  try
    WriteBytes(SafeChild(FStage, 'SourceLicense.html'), BytesOf(LFAQ));
    LFAQHash := HashFile(SafeChild(FStage, 'SourceLicense.html'));
    Require(LFAQHash = AKit.Objects['licenseEvidence'].Strings['sha256'],
      'Collection license copy changed original bytes');
    FFiles.Add('SourceLicense.html');
    LBytes := ReadBytes(SafeChild(ARoot, AKit.Objects['licenseEvidence'].Strings['path']));
    WriteBytes(SafeChild(FStage, 'SourceLicense.html.zlib'), LBytes);
    FFiles.Add('SourceLicense.html.zlib');
    Inc(FTotal, Length(LBytes));
    for I := 0 to LSources.Count - 1 do
    begin
      LSource := TJSONObject(LSources.Objects[I]);
      CheckBaseMeshPage(LSource, EvidenceText(ARoot, LSource.Strings['pageEvidence'],
        LSource.Strings['pageEvidenceSha256'], LSource.Strings['pageSha256']));
      LRelative := 'Provenance/' + LSource.Strings['id'] + '.html.zlib';
      LBytes := ReadBytes(SafeChild(ARoot, LSource.Strings['pageEvidence']));
      Inc(FTotal, Length(LBytes));
      Require(FTotal <= 1024 * 1024 * 1024, 'Collection evidence exceeds aggregate bound');
      WriteBytes(SafeChild(FStage, LRelative), LBytes);
      FFiles.Add(LRelative);
      ExtractSource(ARoot, LSource);
      LModels.Clear;
      for J := 0 to LSource.Arrays['models'].Count - 1 do
      begin
        LModelPin := LSource.Arrays['models'].Objects[J];
        LModels.AddObject(LModelPin.Strings['path'], LModelPin);
      end;
      for J := 0 to LModels.Count - 1 do
      begin
        LModelPin := TJSONObject(LModels.Objects[J]);
        LRelative := LSource.Strings['id'] + '/' + LModels[J];
        LPath := SafeChild(FStage, LRelative);
        LBytes := ReadBytes(LPath);
        Require((HashBytes(LBytes) = LModelPin.Strings['sha256']) and
          (Length(LBytes) = LModelPin.Int64s['bytes']), 'Pinned collection model bytes differ');
        LModel := ModelJSON(LBytes, ExtractFileExt(LPath));
        try
          LRow := TJSONObject.Create([
            'id', AKit.Strings['id'] + '/' + ChangeFileExt(LRelative, ''),
            'kit', AKit.Strings['id'], 'sourceId', LSource.Strings['id'],
            'sourceMember', LModels[J], 'name', LSource.Strings['name'],
            'sourceArchiveSha256', LSource.Strings['archiveSha256'],
            'sourcePageSha256', LSource.Strings['pageSha256'],
            'theme', AKit.Strings['theme'], 'sourceCategory', LSource.Get('sourceCategory', ''),
            'suggestedRole', SuggestRole(LSource.Strings['name']), 'review', 'inventory-only',
            'storage', 'library', 'format', Copy(ExtractFileExt(LPath), 2, MaxInt),
            'url', 'kits/' + AKit.Strings['id'] + '/' + LRelative,
            'sha256', LModelPin.Strings['sha256'], 'bytes', Length(LBytes),
            'license', 'CC0-1.0', 'source', LSource.Strings['page'],
            'licenseFile', 'SourceLicense.html', 'licenseSha256', LFAQHash]);
          AInventory.Add(LRow);
          LRow.Add('meshLocalBounds', MeshBounds(LModel));
          LRow.Add('dependencies', SourceDependencies(LModel, LSource, FStage, LPath));
        finally
          LModel.Free;
        end;
      end;
      if (I + 1) mod 50 = 0 then
      begin
        WriteLn(AKit.Strings['id'], ': staged ', I + 1, ' / ', LSources.Count, ' sources');
        Flush(Output);
      end;
    end;
    if DirectoryExists(LPublished) then
    begin
      for I := 0 to FFiles.Count - 1 do
      begin
        LSourcePath := SafeChild(FStage, FFiles[I]);
        LPath := SafeChild(LPublished, FFiles[I]);
        Require(FileExists(LPath) and (not DirectoryExists(LPath)) and
          (HashFile(LSourcePath) = HashFile(LPath)),
          'Published collection differs; use a new snapshot kit ID: ' + LPath);
      end;
    end
    else
    begin
      ForceDirectories(ExtractFileDir(LPublished));
      Require(RenameFile(FStage, LPublished), 'Cannot publish complete collection stage');
    end;
    WriteLn(AKit.Strings['id'], ': imported ', AInventory.Count - LStart,
      ' original models from ', LSources.Count, ' archives.');
  finally
    LModels.Free;
    LSources.Free;
    FFiles.Free;
  end;
end;

procedure ImportCollectionKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
var
  LImporter: TCollectionImporter;
  LStart: Integer;
begin
  LStart := AInventory.Count;
  LImporter := TCollectionImporter.Create;
  try
    try
      LImporter.Run(ARoot, AKit, AInventory);
    except
      while AInventory.Count > LStart do
      begin
        AInventory.Delete(AInventory.Count - 1);
      end;
      raise;
    end;
  finally
    LImporter.Free;
  end;
end;

procedure VerifyCollectionKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
var
  LSources: TStringList;
  LExpected: TStringList;
  LSource: TJSONObject;
  LPin: TJSONObject;
  LAsset: TJSONObject;
  LModel: TJSONObject;
  LDependencies: TJSONArray;
  LRoot: String;
  LPath: String;
  LRelative: String;
  LKey: String;
  LFAQHash: String;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  CheckCollectionKit(AKit);
  LRoot := SafeChild(ARoot, 'assets/library/kits/' + AKit.Strings['id']);
  CheckExactFilePath(LRoot, 'SourceLicense.html');
  LFAQHash := HashFile(SafeChild(LRoot, 'SourceLicense.html'));
  Require(LFAQHash = AKit.Objects['licenseEvidence'].Strings['sha256'],
    'Published collection FAQ differs from source lock');
  CheckBaseMeshFAQ(AKit, ReadText(SafeChild(LRoot, 'SourceLicense.html')));
  CheckBaseMeshFAQ(AKit, EvidenceText(LRoot, 'SourceLicense.html.zlib',
    AKit.Objects['licenseEvidence'].Strings['compressedSha256'], LFAQHash));
  LSources := SourceMap(AKit);
  LExpected := TStringList.Create;
  LExpected.Sorted := True;
  LExpected.CaseSensitive := True;
  LExpected.UseLocale := False;
  try
    for I := 0 to LSources.Count - 1 do
    begin
      LSource := TJSONObject(LSources.Objects[I]);
      LPath := 'Provenance/' + LSource.Strings['id'] + '.html.zlib';
      CheckBaseMeshPage(LSource, EvidenceText(LRoot, LPath,
        LSource.Strings['pageEvidenceSha256'], LSource.Strings['pageSha256']));
      for J := 0 to LSource.Arrays['models'].Count - 1 do
      begin
        LPin := LSource.Arrays['models'].Objects[J];
        LExpected.AddObject(LSource.Strings['id'] + '/' + LPin.Strings['path'], LPin);
      end;
    end;
    LCount := 0;
    for I := 0 to AInventory.Count - 1 do
    begin
      LAsset := AInventory.Objects[I];
      if LAsset.Strings['kit'] <> AKit.Strings['id'] then
      begin
        Continue;
      end;
      Inc(LCount);
      J := LSources.IndexOf(LAsset.Strings['sourceId']);
      Require(J >= 0, 'Unknown collection inventory source');
      LSource := TJSONObject(LSources.Objects[J]);
      LRelative := LSource.Strings['id'] + '/' + LAsset.Strings['sourceMember'];
      J := LExpected.IndexOf(LRelative);
      Require((J >= 0) and (LExpected.Objects[J] <> nil), 'Unknown/duplicate original source member');
      LPin := TJSONObject(LExpected.Objects[J]);
      CheckModelByteCount(LAsset.Find('bytes'));
      LExpected.Objects[J] := nil;
      LKey := AKit.Strings['id'] + '/' + ChangeFileExt(LRelative, '');
      Require((LAsset.Strings['id'] = LKey) and
        (LAsset.Strings['url'] = 'kits/' + AKit.Strings['id'] + '/' + LRelative) and
        (LAsset.Get('storage', '') = 'library') and
        (LAsset.Strings['source'] = LSource.Strings['page']) and
        (LAsset.Strings['sourceArchiveSha256'] = LSource.Strings['archiveSha256']) and
        (LAsset.Strings['sourcePageSha256'] = LSource.Strings['pageSha256']),
        'Collection inventory source identity/path differs');
      Require((LAsset.Strings['sha256'] = LPin.Strings['sha256']) and
        (LAsset.Int64s['bytes'] = LPin.Int64s['bytes']), 'Collection inventory differs from model pin');
      Require((LAsset.Strings['license'] = 'CC0-1.0') and
        (LAsset.Get('licenseFile', '') = 'SourceLicense.html') and
        (LAsset.Strings['licenseSha256'] = LFAQHash) and
        (LAsset.Find('licenseEvidence') = nil), 'Collection inventory license binding differs');
      CheckExactFilePath(LRoot, LRelative);
      LPath := SafeChild(LRoot, LRelative);
      Require((HashFile(LPath) = LPin.Strings['sha256']) and
        (Length(ReadBytes(LPath)) = LPin.Int64s['bytes']), 'Collection source model changed');
      Require(ExtractFileExt(LPath) = '.' + LAsset.Strings['format'],
        'Collection model format differs');
      LModel := ModelJSON(ReadBytes(LPath), ExtractFileExt(LPath));
      try
        LDependencies := SourceDependencies(LModel, LSource, LRoot, LPath);
        try
          Require(LDependencies.AsJSON = LAsset.Arrays['dependencies'].AsJSON,
            'Collection model dependency source/bytes changed');
        finally
          LDependencies.Free;
        end;
      finally
        LModel.Free;
      end;
    end;
    Require(LCount = LExpected.Count, 'Collection inventory omitted pinned source models');
  finally
    LExpected.Free;
    LSources.Free;
  end;
end;

end.
