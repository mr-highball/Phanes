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

unit phanes.tools.catalog;

{$mode delphi}
{$H+}

interface

procedure PackageCatalog(const ARoot: String);
procedure SummarizeCatalog(const ARoot: String);

implementation

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  phanes.tools.files;

procedure SummarizeCatalog(const ARoot: String);
var
  LInventory: TJSONObject;
  LLock: TJSONObject;
  LPalette: TJSONObject;
  LResult: TJSONObject;
  LKits: TJSONArray;
  LHashes: TStringList;
  LAsset: TJSONObject;
  LRow: TJSONObject;
  LCount: Integer;
  LBytes: Int64;
  LTotalBytes: Int64;
  I: Integer;
  J: Integer;
begin
  LInventory := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LPalette := LoadJSON(SafeChild(ARoot, 'data/palette.json'));
  LResult := TJSONObject.Create(['version', 1, 'baselineModels', 905,
    'baselineKits', 6, 'acceptedApproximateFactor', 9,
    'inventorySha256', HashFile(SafeChild(ARoot, 'data/asset-inventory.json')),
    'counting', 'Exact file hashes only; geometry families and playable admission remain separate']);
  LHashes := TStringList.Create;
  LKits := TJSONArray.Create;
  LResult.Add('kits', LKits);
  try
    LHashes.Sorted := True;
    LHashes.Duplicates := dupIgnore;
    LTotalBytes := 0;
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LCount := 0;
      LBytes := 0;
      for J := 0 to LInventory.Arrays['assets'].Count - 1 do
      begin
        LAsset := LInventory.Arrays['assets'].Objects[J];
        if LAsset.Strings['kit'] = LLock.Arrays['kits'].Objects[I].Strings['id'] then
        begin
          Inc(LCount);
          Inc(LBytes, LAsset.Int64s['bytes']);
          LHashes.Add(LAsset.Strings['sha256']);
        end;
      end;
      Inc(LTotalBytes, LBytes);
      LRow := TJSONObject.Create([
        'id', LLock.Arrays['kits'].Objects[I].Strings['id'],
        'storage', LLock.Arrays['kits'].Objects[I].Get('storage', 'core'),
        'models', LCount, 'modelBytes', LBytes,
        'source', LLock.Arrays['kits'].Objects[I].Strings['page']]);
      LKits.Add(LRow);
    end;
    LResult.Add('importedModels', LInventory.Arrays['assets'].Count);
    LResult.Add('distinctFileHashes', LHashes.Count);
    LResult.Add('duplicateFileHashes', LInventory.Arrays['assets'].Count - LHashes.Count);
    LResult.Add('modelBytes', LTotalBytes);
    LResult.Add('regionalChoices', LPalette.Arrays['assets'].Count);
    WriteTextAtomic(SafeChild(ARoot, 'data/catalog-summary.json'), LResult.FormatJSON + #10);
    WriteLn('Catalog: ', LKits.Count, ' kits; ', LInventory.Arrays['assets'].Count,
      ' models; ', LHashes.Count, ' distinct file hashes.');
  finally
    LHashes.Free;
    LResult.Free;
    LLock.Free;
    LPalette.Free;
    LInventory.Free;
  end;
end;

procedure PublishCatalogFiles(const ARoot: String);
var
  LInventory: TJSONObject;
  LLock: TJSONObject;
  LIndex: TJSONObject;
  LKits: TJSONArray;
  LKit: TJSONObject;
  LManifest: TJSONObject;
  LModels: TJSONArray;
  LModel: TJSONObject;
  LAsset: TJSONObject;
  LFiles: TJSONArray;
  LFile: TJSONObject;
  LBlobs: TStringList;
  LPaths: TStringList;
  LRoot: String;
  LPath: String;
  LRelative: String;
  LManifestPath: String;
  LManifestHash: String;
  LLicensePath: String;
  LLicenseHash: String;
  LTotalBytes: Int64;
  LModelBytes: Int64;
  I: Integer;
  J: Integer;
  K: Integer;

  function Blob(const ABase, APath, AHash: String): TJSONObject;
  var
    LSource: String;
    LTarget: String;
    LUrl: String;
    LBytes: TBytes;
    LIndex: Integer;
    LSize: Int64;
    LInput: TFileStream;
  begin
    LUrl := 'library/blobs/' + AHash;
    LSource := SafeChild(ABase, APath);
    LIndex := LBlobs.IndexOf(AHash);
    if LIndex < 0 then
    begin
      LBytes := ReadBytes(LSource);
      Require(HashBytes(LBytes) = AHash, 'Catalog blob source changed');
      LTarget := SafeChild(ARoot, 'build/web/' + LUrl);
      if not FileExists(LTarget) then
      begin
        WriteBytes(LTarget, LBytes);
      end;
      Require(HashFile(LTarget) = AHash, 'Published catalog blob changed');
      Inc(LTotalBytes, Length(LBytes));
      LBlobs.Add(AHash);
      LSize := Length(LBytes);
    end
    else
    begin
      LInput := TFileStream.Create(LSource, fmOpenRead or fmShareDenyWrite);
      try
        LSize := LInput.Size;
      finally
        LInput.Free;
      end;
    end;
    Result := TJSONObject.Create(['path', APath, 'url', LUrl, 'sha256', AHash, 'bytes', LSize]);
  end;

begin
  LInventory := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LIndex := TJSONObject.Create(['version', 1, 'recipe', 'phanes.catalog.files.v1',
    'inventorySha256', HashFile(SafeChild(ARoot, 'data/asset-inventory.json')),
    'sourceLockSha256', HashFile(SafeChild(ARoot, 'data/kits.lock.json'))]);
  LKits := TJSONArray.Create;
  LIndex.Add('kits', LKits);
  LBlobs := TStringList.Create;
  LBlobs.Sorted := True;
  LBlobs.CaseSensitive := True;
  LTotalBytes := 0;
  try
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LKit := LLock.Arrays['kits'].Objects[I];
      if LKit.Get('storage', 'core') <> 'library' then
      begin
        Continue;
      end;
      LRoot := SafeChild(ARoot, 'assets/library/kits/' + LKit.Strings['id']);
      LManifest := TJSONObject.Create(['version', 1, 'kit', LKit.Strings['id'],
        'inventorySha256', LIndex.Strings['inventorySha256'],
        'author', LKit.Strings['author'], 'source', LKit.Strings['page'],
        'license', LKit.Strings['license']]);
      LModels := TJSONArray.Create;
      LManifest.Add('models', LModels);
      LPaths := TStringList.Create;
      LPaths.Sorted := True;
      LPaths.CaseSensitive := True;
      LPaths.UseLocale := False;
      LLicensePath := '';
      LLicenseHash := '';
      try
        for J := 0 to LInventory.Arrays['assets'].Count - 1 do
        begin
          LAsset := LInventory.Arrays['assets'].Objects[J];
          if LAsset.Strings['kit'] <> LKit.Strings['id'] then
          begin
            Continue;
          end;
          LRelative := Copy(LAsset.Strings['url'],
            Length('kits/' + LKit.Strings['id'] + '/') + 1, MaxInt);
          LModel := TJSONObject.Create(['id', LAsset.Strings['id'],
            'name', LAsset.Strings['name'], 'format', LAsset.Strings['format'],
            'path', LRelative, 'sha256', LAsset.Strings['sha256']]);
          LModels.Add(LModel);
          LFiles := TJSONArray.Create;
          LModel.Add('files', LFiles);
          LFile := Blob(LRoot, LRelative, LAsset.Strings['sha256']);
          LModelBytes := LFile.Int64s['bytes'];
          LFiles.Add(LFile);
          LPaths.Clear;
          LPaths.Add(LRelative);
          for K := 0 to LAsset.Arrays['dependencies'].Count - 1 do
          begin
            LPath := LAsset.Arrays['dependencies'].Objects[K].Strings['path'];
            if LPaths.IndexOf(LPath) >= 0 then
            begin
              Continue;
            end;
            LPaths.Add(LPath);
            LFile := Blob(LRoot, LPath, LAsset.Arrays['dependencies'].Objects[K].Strings['sha256']);
            Inc(LModelBytes, LFile.Int64s['bytes']);
            LFiles.Add(LFile);
          end;
          LModel.Add('downloadBytes', LModelBytes);
          LLicensePath := LAsset.Get('licenseFile', 'License.txt');
          LLicenseHash := LAsset.Strings['licenseSha256'];
        end;
        Require(LModels.Count > 0, 'Cannot publish empty catalog file manifest');
        LManifest.Add('notice', Blob(LRoot, LLicensePath, LLicenseHash));
        LManifestPath := SafeChild(ARoot,
          'build/catalog-packages/' + LKit.Strings['id'] + '-files.json');
        WriteTextAtomic(LManifestPath, LManifest.FormatJSON + #10);
        LManifestHash := HashFile(LManifestPath);
        LRelative := 'library/catalog/' + LKit.Strings['id'] + '-' + LManifestHash + '.json';
        WriteBytes(SafeChild(ARoot, 'build/web/' + LRelative), ReadBytes(LManifestPath));
        LKits.Add(TJSONObject.Create(['id', LKit.Strings['id'], 'models', LModels.Count,
          'url', LRelative, 'sha256', LManifestHash, 'bytes', Length(ReadBytes(LManifestPath))]));
      finally
        LPaths.Free;
        LManifest.Free;
      end;
    end;
    LIndex.Add('uniqueFiles', LBlobs.Count);
    LIndex.Add('uniqueBytes', LTotalBytes);
    WriteTextAtomic(SafeChild(ARoot, 'build/web/data/library-files.json'), LIndex.FormatJSON + #10);
    WriteLn('Published ', LBlobs.Count, ' shared catalog files in ', LKits.Count,
      ' lazy manifests; ', LTotalBytes, ' unique source bytes.');
  finally
    LBlobs.Free;
    LIndex.Free;
    LLock.Free;
    LInventory.Free;
  end;
end;
procedure PackageCatalog(const ARoot: String);
var
  LInventory: TJSONObject;
  LLock: TJSONObject;
  LResult: TJSONObject;
  LPackages: TJSONArray;
  LKit: TJSONObject;
  LAsset: TJSONObject;
  LFiles: TStringList;
  LStreams: TList;
  LInput: TFileStream;
  LZip: TZipper;
  LEntry: TZipFileEntry;
  LPath: String;
  LKitRoot: String;
  LTemporary: String;
  LHash: String;
  LFinal: String;
  LRelative: String;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LInventory := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LResult := TJSONObject.Create(['version', 1, 'recipe', 'phanes.catalog.package.v1',
    'inventorySha256', HashFile(SafeChild(ARoot, 'data/asset-inventory.json'))]);
  LPackages := TJSONArray.Create;
  LResult.Add('packages', LPackages);
  try
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LKit := LLock.Arrays['kits'].Objects[I];
      if LKit.Get('storage', 'core') <> 'library' then
      begin
        Continue;
      end;
      LKitRoot := SafeChild(ARoot, 'assets/library/kits/' + LKit.Strings['id']);
      LFiles := TStringList.Create;
      LStreams := TList.Create;
      LZip := TZipper.Create;
      try
        LFiles.Sorted := True;
        LFiles.CaseSensitive := True;
        LFiles.UseLocale := False;
        LFiles.Duplicates := dupIgnore;
        for J := 0 to LInventory.Arrays['assets'].Count - 1 do
        begin
          LAsset := LInventory.Arrays['assets'].Objects[J];
          if LAsset.Strings['kit'] <> LKit.Strings['id'] then
          begin
            Continue;
          end;
          LRelative := Copy(LAsset.Strings['url'],
            Length('kits/' + LKit.Strings['id'] + '/') + 1, MaxInt);
          LPath := SafeChild(LKitRoot, LRelative);
          Require(HashFile(LPath) = LAsset.Strings['sha256'], 'Packaging changed model');
          Require(HashFile(SafeChild(LKitRoot, LAsset.Get('licenseFile', 'License.txt'))) =
            LAsset.Strings['licenseSha256'], 'Packaging changed license');
          LFiles.Add(LAsset.Get('licenseFile', 'License.txt'));
          LFiles.Add(LRelative);
          for K := 0 to LAsset.Arrays['dependencies'].Count - 1 do
          begin
            LRelative := LAsset.Arrays['dependencies'].Objects[K].Strings['path'];
            Require(HashFile(SafeChild(LKitRoot, LRelative)) =
              LAsset.Arrays['dependencies'].Objects[K].Strings['sha256'],
              'Packaging changed model dependency');
            LFiles.Add(LRelative);
          end;
        end;
        Require(LFiles.Count > 1, 'Cannot package an empty kit');
        LTemporary := SafeChild(ARoot, 'build/catalog-packages/' + LKit.Strings['id'] + '.zip');
        ForceDirectories(ExtractFileDir(LTemporary));
        LZip.FileName := LTemporary;
        for J := 0 to LFiles.Count - 1 do
        begin
          { Disk-backed zipper entries refresh file metadata during ZipAllFiles.
            Borrowed streams keep our fixed archive metadata and bound memory:
            compression reads one stream at a time rather than copying the kit. }
          LInput := TFileStream.Create(SafeChild(LKitRoot, LFiles[J]),
            fmOpenRead or fmShareDenyWrite);
          LStreams.Add(LInput);
          LEntry := LZip.Entries.AddFileEntry(LInput, LFiles[J]);
          LEntry.DateTime := EncodeDate(1980, 1, 1);
          LEntry.OS := 0;
          LEntry.Attributes := faArchive;
        end;
        LZip.ZipAllFiles;
        LHash := HashFile(LTemporary);
        LRelative := 'library/' + LKit.Strings['id'] + '-' + LHash + '.zip';
        LFinal := SafeChild(ARoot, 'build/web/' + LRelative);
        if not FileExists(LFinal) then
        begin
          CopyFileBytes(LTemporary, LFinal);
        end;
        Require(HashFile(LFinal) = LHash, 'Published package hash mismatch');
        LPackages.Add(TJSONObject.Create(['kit', LKit.Strings['id'], 'url', LRelative,
          'sha256', LHash, 'bytes', FileByteCount(LFinal), 'files', LFiles.Count]));
      finally
        LZip.Free;
        for J := 0 to LStreams.Count - 1 do
        begin
          TStream(LStreams[J]).Free;
        end;
        LStreams.Free;
        LFiles.Free;
      end;
    end;
    WriteTextAtomic(SafeChild(ARoot, 'build/web/data/library-packages.json'),
      LResult.FormatJSON + #10);
    WriteLn('Packaged ', LPackages.Count, ' optional kits outside the Castle startup archive.');
    PublishCatalogFiles(ARoot);
  finally
    LResult.Free;
    LLock.Free;
    LInventory.Free;
  end;
end;

end.
