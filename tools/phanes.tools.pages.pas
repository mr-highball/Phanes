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


unit phanes.tools.pages;

{$mode delphi}
{$H+}

interface

const
  PagesByteBudget = 900000000;

procedure StagePages(const ARoot: String; const AByteBudget: Int64 = PagesByteBudget);

implementation

uses
  Classes,
  SysUtils,
  FPJSON,
  FpSHA256,
  phanes.tools.files,
  phanes.tools.kits;

type
  TPagesStager = class
  private
    FRoot: String;
    FWeb: String;
    FFiles: TStringList;
    FInventory: TJSONObject;
    FLock: TJSONObject;
    FAssets: TStringList;
    FKits: TStringList;
    FReferences: Integer;
    FBytes: Int64;
    FBudget: Int64;
    FHasRuntimeParts: Boolean;
    procedure CheckLocalFile(const ABase, ARelative: String);
    procedure AddFile(const APath: String; const AHash: String = '';
      const ABytes: Int64 = -1);
    procedure AddBlob(const AFile: TJSONObject);
    procedure AddLibrary;
    procedure AddRuntime;
    procedure CheckModel(const AModel, AAsset: TJSONObject);
    procedure CheckManifest(const AManifest, AKit: TJSONObject);
    procedure AddWebDirectory(const ARelative: String; const ADepth: Integer);
    procedure VerifyTree(const ABase, ARelative: String; var ACount: Integer);
  public
    constructor Create(const ARoot: String; const AByteBudget: Int64);
    destructor Destroy; override;
    procedure Run;
  end;

procedure CheckHash(const AHash: String);
var
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Expected Pages SHA-256 pin');
  for I := 1 to Length(AHash) do
  begin
    Require(AHash[I] in ['0'..'9', 'a'..'f'], 'Noncanonical Pages SHA-256 pin');
  end;
end;

function IntegerField(const AObject: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Int64): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue is TJSONNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64, ntQWord]),
    'Pages ' + AName + ' must be an integer');
  Result := LValue.AsInt64;
  Require((Result >= AMinimum) and (Result <= AMaximum), 'Pages ' + AName + ' exceeds bounds');
end;

function DeclaredBytes(const AFile: TJSONObject): Int64;
begin
  Result := IntegerField(AFile, 'bytes', 1, PagesByteBudget);
end;

procedure CheckDirectory(const APath: String);
var
  LAttr: LongInt;
begin
  LAttr := FileGetAttr(APath);
  Require((LAttr >= 0) and ((LAttr and faDirectory) <> 0) and
    ((LAttr and faSymLink) = 0), 'Pages directory is missing or is a filesystem link');
end;

constructor TPagesStager.Create(const ARoot: String; const AByteBudget: Int64);
var
  LObject: TJSONObject;
  I: Integer;
begin
  inherited Create;
  FRoot := ExpandFileName(ARoot);
  FWeb := SafeChild(FRoot, 'build/web');
  CheckDirectory(FRoot);
  CheckDirectory(SafeChild(FRoot, 'build'));
  CheckDirectory(FWeb);
  if FileGetAttr(SafeChild(FRoot, 'build/pages')) >= 0 then
  begin
    CheckDirectory(SafeChild(FRoot, 'build/pages'));
  end;
  Require((AByteBudget > 0) and (AByteBudget <= PagesByteBudget),
    'Pages budget must be within the deployment limit');
  FBudget := AByteBudget;
  FFiles := TStringList.Create;
  FFiles.Sorted := True;
  FFiles.CaseSensitive := True;
  FFiles.UseLocale := False;
  CheckLocalFile(FRoot, 'data/asset-inventory.json');
  CheckLocalFile(FRoot, 'data/kits.lock.json');
  FInventory := LoadJSON(SafeChild(FRoot, 'data/asset-inventory.json'));
  FLock := LoadJSON(SafeChild(FRoot, 'data/kits.lock.json'));
  Require(IntegerField(FInventory, 'version', 2, 2) = 2, 'Unsupported Pages inventory version');
  Require(IntegerField(FLock, 'version', 1, 1) = 1, 'Unsupported Pages source-lock version');
  FAssets := TStringList.Create;
  FAssets.Sorted := True;
  FAssets.CaseSensitive := True;
  FAssets.UseLocale := False;
  FKits := TStringList.Create;
  FKits.Sorted := True;
  FKits.CaseSensitive := True;
  FKits.UseLocale := False;
  Require(FLock.Arrays['kits'].Count <= 2000, 'Pages lock count exceeds bounds');
  Require(FInventory.Arrays['assets'].Count <= 50000, 'Pages inventory count exceeds bounds');
  for I := 0 to FLock.Arrays['kits'].Count - 1 do
  begin
    LObject := FLock.Arrays['kits'].Objects[I];
    if LObject.Get('storage', 'core') = 'library' then
    begin
      Require(FKits.IndexOf(LObject.Strings['id']) < 0, 'Duplicate source kit');
      FKits.AddObject(LObject.Strings['id'], LObject);
    end;
  end;
  for I := 0 to FInventory.Arrays['assets'].Count - 1 do
  begin
    LObject := FInventory.Arrays['assets'].Objects[I];
    if LObject.Get('storage', 'core') = 'library' then
    begin
      Require(FKits.IndexOf(LObject.Strings['kit']) >= 0, 'Inventory kit is absent from lock');
      Require(FAssets.IndexOf(LObject.Strings['id']) < 0, 'Duplicate source model');
      FAssets.AddObject(LObject.Strings['id'], LObject);
    end;
  end;
end;

destructor TPagesStager.Destroy;
var
  I: Integer;
begin
  if FFiles <> nil then
  begin
    for I := 0 to FFiles.Count - 1 do
    begin
      FFiles.Objects[I].Free;
    end;
  end;
  FFiles.Free;
  FAssets.Free;
  FKits.Free;
  FInventory.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TPagesStager.CheckLocalFile(const ABase, ARelative: String);
var
  LCurrent: String;
  LParts: TStringList;
  LAttr: LongInt;
  I: Integer;
begin
  CheckArchivePath(ARelative);
  CheckExactFilePath(ABase, ARelative);
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '/';
    LParts.DelimitedText := ARelative;
    LCurrent := ABase;
    for I := -1 to LParts.Count - 1 do
    begin
      if I >= 0 then
      begin
        LCurrent := SafeChild(LCurrent, LParts[I]);
      end;
      LAttr := FileGetAttr(LCurrent);
      Require((LAttr >= 0) and ((LAttr and faSymLink) = 0),
        'Pages source contains a missing path or filesystem link');
    end;
    Require((LAttr and faDirectory) = 0, 'Pages source is not a regular file');
  finally
    LParts.Free;
  end;
end;

procedure TPagesStager.AddFile(const APath, AHash: String; const ABytes: Int64);
var
  LPath: String;
  LHash: String;
  LBytes: Int64;
  LIndex: Integer;
  LExisting: TJSONObject;
begin
  CheckLocalFile(FWeb, APath);
  LPath := SafeChild(FWeb, APath);
  LBytes := FileByteCount(LPath);
  if ABytes >= 0 then
  begin
    Require(LBytes = ABytes, 'Pages file size differs: ' + APath);
  end;
  LHash := HashFile(LPath);
  if AHash <> '' then
  begin
    CheckHash(AHash);
    Require(LHash = AHash, 'Pages file hash differs: ' + APath);
  end;
  LIndex := FFiles.IndexOf(APath);
  if LIndex >= 0 then
  begin
    LExisting := TJSONObject(FFiles.Objects[LIndex]);
    Require((LExisting.Strings['sha256'] = LHash) and
      (LExisting.Int64s['bytes'] = LBytes), 'Conflicting Pages file reference');
    Exit;
  end;
  Require(FFiles.Count < 100000, 'Pages file count exceeds bounds');
  Require((LBytes >= 0) and (LBytes <= FBudget - FBytes), 'Pages byte budget exceeded');
  Inc(FBytes, LBytes);
  FFiles.AddObject(APath, TJSONObject.Create(['path', APath, 'sha256', LHash, 'bytes', LBytes]));
end;

procedure TPagesStager.AddBlob(const AFile: TJSONObject);
var
  LHash: String;
begin
  Inc(FReferences);
  Require(FReferences <= 100000, 'Pages total file references exceed bounds');
  LHash := AFile.Strings['sha256'];
  CheckHash(LHash);
  Require(AFile.Strings['url'] = 'library/blobs/' + LHash, 'Unexpected Pages blob URL');
  AddFile(AFile.Strings['url'], LHash, DeclaredBytes(AFile));
end;

procedure TPagesStager.CheckModel(const AModel, AAsset: TJSONObject);
var
  LExpected: TStringList;
  LSeen: TStringList;
  LFile: TJSONObject;
  LSource: TJSONObject;
  LPrefix: String;
  LPath: String;
  LTotal: Int64;
  LIndex: Integer;
  I: Integer;
begin
  LPrefix := 'kits/' + AAsset.Strings['kit'] + '/';
  Require(Copy(AAsset.Strings['url'], 1, Length(LPrefix)) = LPrefix,
    'Inventory model URL differs from its kit');
  LPath := Copy(AAsset.Strings['url'], Length(LPrefix) + 1, MaxInt);
  CheckArchivePath(LPath);
  Require((AModel.Strings['id'] = AAsset.Strings['id']) and
    (AModel.Strings['name'] = AAsset.Strings['name']) and
    (AModel.Strings['path'] = LPath) and
    (AModel.Strings['format'] = AAsset.Strings['format']) and
    (AModel.Strings['sha256'] = AAsset.Strings['sha256']), 'Pages model differs from inventory');
  LExpected := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LExpected.Sorted := True;
    LExpected.CaseSensitive := True;
    LExpected.UseLocale := False;
    LSeen.Sorted := True;
    LSeen.CaseSensitive := True;
    LSeen.UseLocale := False;
    LExpected.AddObject(LPath, AAsset);
    Require(AAsset.Arrays['dependencies'].Count <= 1023, 'Inventory dependency count exceeds bounds');
    for I := 0 to AAsset.Arrays['dependencies'].Count - 1 do
    begin
      LSource := AAsset.Arrays['dependencies'].Objects[I];
      CheckArchivePath(LSource.Strings['path']);
      Require(LExpected.IndexOf(LSource.Strings['path']) < 0, 'Duplicate inventory dependency');
      LExpected.AddObject(LSource.Strings['path'], LSource);
    end;
    Require(AModel.Arrays['files'].Count = LExpected.Count, 'Pages model closure count differs');
    LTotal := 0;
    for I := 0 to AModel.Arrays['files'].Count - 1 do
    begin
      LFile := AModel.Arrays['files'].Objects[I];
      LPath := LFile.Strings['path'];
      LIndex := LExpected.IndexOf(LPath);
      Require((LIndex >= 0) and (LSeen.IndexOf(LPath) < 0), 'Unexpected/duplicate Pages model file');
      LSeen.Add(LPath);
      LSource := TJSONObject(LExpected.Objects[LIndex]);
      Require((LFile.Strings['sha256'] = LSource.Strings['sha256']) and
        (DeclaredBytes(LFile) = DeclaredBytes(LSource)), 'Pages file differs from inventory');
      Inc(LTotal, DeclaredBytes(LFile));
    end;
    Require(IntegerField(AModel, 'downloadBytes', 1, PagesByteBudget) = LTotal,
      'Pages model download byte count differs');
  finally
    LSeen.Free;
    LExpected.Free;
  end;
end;

procedure TPagesStager.CheckManifest(const AManifest, AKit: TJSONObject);
var
  LExpected: TStringList;
  LSourceKit: TJSONObject;
  LAsset: TJSONObject;
  LModel: TJSONObject;
  LIndex: Integer;
  I: Integer;
begin
  LIndex := FKits.IndexOf(AKit.Strings['id']);
  Require(LIndex >= 0, 'Pages kit is absent from the source lock');
  LSourceKit := TJSONObject(FKits.Objects[LIndex]);
  Require((AManifest.Strings['author'] = LSourceKit.Strings['author']) and
    (AManifest.Strings['source'] = LSourceKit.Strings['page']) and
    (AManifest.Strings['license'] = LSourceKit.Strings['license']),
    'Pages source/license metadata differs from the lock');
  LExpected := TStringList.Create;
  try
    LExpected.Sorted := True;
    LExpected.CaseSensitive := True;
    LExpected.UseLocale := False;
    for I := 0 to FAssets.Count - 1 do
    begin
      LAsset := TJSONObject(FAssets.Objects[I]);
      if LAsset.Strings['kit'] = AKit.Strings['id'] then
      begin
        LExpected.AddObject(LAsset.Strings['id'], LAsset);
      end;
    end;
    Require((LExpected.Count > 0) and (AManifest.Arrays['models'].Count = LExpected.Count),
      'Pages model set differs from the inventory');
    for I := 0 to AManifest.Arrays['models'].Count - 1 do
    begin
      LModel := AManifest.Arrays['models'].Objects[I];
      LIndex := LExpected.IndexOf(LModel.Strings['id']);
      Require(LIndex >= 0, 'Unexpected/duplicate Pages model ID');
      LAsset := TJSONObject(LExpected.Objects[LIndex]);
      CheckModel(LModel, LAsset);
      Require((AManifest.Objects['notice'].Strings['sha256'] = LAsset.Strings['licenseSha256']) and
        (AManifest.Objects['notice'].Strings['path'] = LAsset.Get('licenseFile', 'License.txt')),
        'Pages notice differs from the inventory');
      LExpected.Delete(LIndex);
    end;
  finally
    LExpected.Free;
  end;
end;

procedure TPagesStager.AddLibrary;
var
  LIndex: TJSONObject;
  LManifest: TJSONObject;
  LKit: TJSONObject;
  LModel: TJSONObject;
  LHash: String;
  LPath: String;
  LIds: TStringList;
  LBlobCount: Integer;
  LBlobBytes: Int64;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  AddFile('data/library-files.json');
  LIndex := LoadJSON(SafeChild(FWeb, 'data/library-files.json'));
  LIds := TStringList.Create;
  try
    Require((IntegerField(LIndex, 'version', 1, 1) = 1) and
      (LIndex.Strings['recipe'] = 'phanes.catalog.files.v1'), 'Unsupported Pages catalog index');
    Require(LIndex.Strings['inventorySha256'] =
      HashFile(SafeChild(FRoot, 'data/asset-inventory.json')), 'Pages inventory is stale');
    Require(LIndex.Strings['sourceLockSha256'] =
      HashFile(SafeChild(FRoot, 'data/kits.lock.json')), 'Pages source lock is stale');
    Require((LIndex.Arrays['kits'].Count > 0) and (LIndex.Arrays['kits'].Count = FKits.Count),
      'Pages kit count exceeds bounds');
    AddFile('data/asset-inventory.json', LIndex.Strings['inventorySha256']);
    AddFile('data/kits.lock.json', LIndex.Strings['sourceLockSha256']);
    LIds.Sorted := True;
    LIds.CaseSensitive := False;
    for I := 0 to LIndex.Arrays['kits'].Count - 1 do
    begin
      LKit := LIndex.Arrays['kits'].Objects[I];
      CheckArchivePath(LKit.Strings['id']);
      Require(Pos('/', LKit.Strings['id']) = 0, 'Pages kit ID must be a leaf');
      Require(LIds.IndexOf(LKit.Strings['id']) < 0, 'Duplicate Pages kit ID');
      LIds.Add(LKit.Strings['id']);
      LHash := LKit.Strings['sha256'];
      CheckHash(LHash);
      LPath := 'library/catalog/' + LKit.Strings['id'] + '-' + LHash + '.json';
      Require(LKit.Strings['url'] = LPath, 'Unexpected Pages manifest URL');
      AddFile(LPath, LHash, DeclaredBytes(LKit));
      LManifest := LoadJSON(SafeChild(FWeb, LPath));
      try
        Require((IntegerField(LManifest, 'version', 1, 1) = 1) and
          (LManifest.Strings['kit'] = LKit.Strings['id']) and
          (LManifest.Strings['inventorySha256'] = LIndex.Strings['inventorySha256']),
          'Pages manifest identity differs');
        Require((LManifest.Arrays['models'].Count > 0) and
          (LManifest.Arrays['models'].Count = IntegerField(LKit, 'models', 1, 50000)),
          'Pages manifest model count differs');
        CheckManifest(LManifest, LKit);
        AddBlob(LManifest.Objects['notice']);
        for J := 0 to LManifest.Arrays['models'].Count - 1 do
        begin
          LModel := LManifest.Arrays['models'].Objects[J];
          Require((LModel.Arrays['files'].Count > 0) and
            (LModel.Arrays['files'].Count <= 1024), 'Pages model file count exceeds bounds');
          for K := 0 to LModel.Arrays['files'].Count - 1 do
          begin
            AddBlob(LModel.Arrays['files'].Objects[K]);
          end;
        end;
      finally
        LManifest.Free;
      end;
    end;
    LBlobCount := 0;
    LBlobBytes := 0;
    for I := 0 to FFiles.Count - 1 do
    begin
      if Copy(FFiles[I], 1, Length('library/blobs/')) = 'library/blobs/' then
      begin
        Inc(LBlobCount);
        Inc(LBlobBytes, TJSONObject(FFiles.Objects[I]).Int64s['bytes']);
      end;
    end;
    Require((IntegerField(LIndex, 'uniqueFiles', 1, 100000) = LBlobCount) and
      (IntegerField(LIndex, 'uniqueBytes', 1, PagesByteBudget) = LBlobBytes),
      'Pages unique file totals differ from the closure');
  finally
    LIds.Free;
    LIndex.Free;
  end;
end;

procedure TPagesStager.AddRuntime;
var
  LBinding: TJSONObject;
  LManifest: TJSONObject;
  LFiles: TJSONArray;
  LParts: TJSONArray;
  LFile: TJSONObject;
  LPart: TJSONObject;
  LNames: TStringList;
  LBytes: TBytes;
  LHash: TSHA256;
  LHex: AnsiString;
  LPath: String;
  LTotal: Int64;
  LExpected: Int64;
  I: Integer;
  J: Integer;
begin
  FHasRuntimeParts := FileExists(SafeChild(FWeb, 'data/runtime-parts.json'));
  Require(FHasRuntimeParts or (not DirectoryExists(SafeChild(FWeb, 'runtime')) and
    not FileExists(SafeChild(FWeb, 'data/runtime-host.json'))),
    'Runtime parts require their current manifest');
  if not FHasRuntimeParts then
  begin
    Exit;
  end;
  LBinding := nil;
  LManifest := nil;
  LNames := TStringList.Create;
  try
    { A part publisher can run before host compilation succeeds. Admit only
      the manifest bound to the actual compiled host by the successful build. }
    AddFile('data/runtime-host.json');
    LBinding := LoadJSON(SafeChild(FWeb, 'data/runtime-host.json'));
    IntegerField(LBinding, 'version', 1, 1);
    CheckHash(LBinding.Strings['hostSha256']);
    CheckHash(LBinding.Strings['manifestSha256']);
    AddFile('phanes.js', LBinding.Strings['hostSha256']);
    AddFile('data/runtime-parts.json', LBinding.Strings['manifestSha256']);
    LManifest := LoadJSON(SafeChild(FWeb, 'data/runtime-parts.json'));
    IntegerField(LManifest, 'version', 1, 1);
    IntegerField(LManifest, 'partBytes', 524288, 524288);
    LFiles := LManifest.Arrays['files'];
    Require(LFiles.Count = 2, 'Runtime needs exactly data and engine');
    for I := 0 to LFiles.Count - 1 do
    begin
      LFile := LFiles.Objects[I];
      LPath := LFile.Strings['path'];
      Require(((LPath = 'phanes.wasm') or (LPath = 'phanes_data.zip')) and
        (LNames.IndexOf(LPath) < 0), 'Unexpected or duplicate runtime source');
      LNames.Add(LPath);
      IntegerField(LFile, 'bytes', 1, 256 * 1024 * 1024);
      CheckHash(LFile.Strings['sha256']);
      CheckLocalFile(FWeb, LPath);
      Require((HashFile(SafeChild(FWeb, LPath)) = LFile.Strings['sha256']) and
        (FileByteCount(SafeChild(FWeb, LPath)) = LFile.Int64s['bytes']),
        'Runtime source differs from manifest');
      LParts := LFile.Arrays['parts'];
      Require(LParts.Count = (LFile.Int64s['bytes'] + 524287) div 524288,
        'Runtime part count differs');
      LTotal := 0;
      LHash.Init;
      for J := 0 to LParts.Count - 1 do
      begin
        LPart := LParts.Objects[J];
        CheckHash(LPart.Strings['sha256']);
        LPath := 'runtime/parts/' + LPart.Strings['sha256'] + '.part';
        Require(LPath = LPart.Strings['url'], 'Unexpected runtime part URL');
        LExpected := 524288;
        if J = LParts.Count - 1 then
        begin
          LExpected := LFile.Int64s['bytes'] - LTotal;
        end;
        IntegerField(LPart, 'bytes', LExpected, LExpected);
        AddFile(LPath, LPart.Strings['sha256'], LExpected);
        LBytes := ReadBytes(SafeChild(FWeb, LPath));
        LHash.Update(@LBytes[0], Length(LBytes));
        Inc(LTotal, Length(LBytes));
      end;
      LHash.Final;
      LHash.OutputHexa(LHex);
      Require(LowerCase(LHex) = LFile.Strings['sha256'],
        'Ordered runtime parts do not reconstruct their source');
    end;
  finally
    LBinding.Free;
    LNames.Free;
    LManifest.Free;
  end;
end;

procedure TPagesStager.AddWebDirectory(const ARelative: String; const ADepth: Integer);
var
  LDirectory: String;
  LPath: String;
  LSearch: TSearchRec;
begin
  Require(ADepth <= 24, 'Pages directory depth exceeds bounds');
  LDirectory := FWeb;
  if ARelative <> '' then
  begin
    LDirectory := SafeChild(FWeb, ARelative);
  end;
  if FindFirst(IncludeTrailingPathDelimiter(LDirectory) + '*', faAnyFile, LSearch) = 0 then
  begin
    try
      repeat
        if (LSearch.Name = '.') or (LSearch.Name = '..') then
        begin
          Continue;
        end;
        LPath := LSearch.Name;
        if ARelative <> '' then
        begin
          LPath := ARelative + '/' + LPath;
        end;
        { Optional library bytes come only from the current verified fine-file
          closure. Bulk ZIPs and obsolete generations stay in developer output. }
        if (LPath = 'library') or (LPath = 'data/library-packages.json') or
          (LPath = 'runtime') or (FHasRuntimeParts and
          ((LPath = 'phanes.wasm') or (LPath = 'phanes_data.zip') or
           (LPath = 'data/runtime-parts.json'))) then
        begin
          Continue;
        end;
        Require((LSearch.Attr and faSymLink) = 0, 'Pages tree contains a filesystem link');
        if (LSearch.Attr and faDirectory) <> 0 then
        begin
          AddWebDirectory(LPath, ADepth + 1);
        end
        else
        begin
          AddFile(LPath);
        end;
      until FindNext(LSearch) <> 0;
    finally
      FindClose(LSearch);
    end;
  end;
end;

procedure TPagesStager.VerifyTree(const ABase, ARelative: String; var ACount: Integer);
var
  LDirectory: String;
  LPath: String;
  LSearch: TSearchRec;
  LIndex: Integer;
  LFile: TJSONObject;
begin
  LDirectory := ABase;
  if ARelative <> '' then
  begin
    LDirectory := SafeChild(ABase, ARelative);
  end;
  Require((FileGetAttr(LDirectory) and faSymLink) = 0, 'Published Pages path is a link');
  if FindFirst(IncludeTrailingPathDelimiter(LDirectory) + '*', faAnyFile, LSearch) = 0 then
  begin
    try
      repeat
        if (LSearch.Name = '.') or (LSearch.Name = '..') then
        begin
          Continue;
        end;
        LPath := LSearch.Name;
        if ARelative <> '' then
        begin
          LPath := ARelative + '/' + LPath;
        end;
        Require((LSearch.Attr and faSymLink) = 0, 'Published Pages tree contains a link');
        if (LSearch.Attr and faDirectory) <> 0 then
        begin
          Require(Length(LPath) < 2048, 'Published Pages path exceeds bounds');
          VerifyTree(ABase, LPath, ACount);
        end
        else
        begin
          LIndex := FFiles.IndexOf(LPath);
          Require(LIndex >= 0, 'Unexpected published Pages file: ' + LPath);
          LFile := TJSONObject(FFiles.Objects[LIndex]);
          CheckLocalFile(ABase, LPath);
          Require((HashFile(SafeChild(ABase, LPath)) = LFile.Strings['sha256']) and
            (FileByteCount(SafeChild(ABase, LPath)) = LFile.Int64s['bytes']),
            'Published Pages bytes changed');
          Inc(ACount);
        end;
      until FindNext(LSearch) <> 0;
    finally
      FindClose(LSearch);
    end;
  end;
end;

procedure TPagesStager.Run;
var
  LPlan: TJSONObject;
  LEntries: TJSONArray;
  LReport: TJSONObject;
  LFile: TJSONObject;
  LPlanBytes: TBytes;
  LText: String;
  LHash: String;
  LStage: String;
  LFinal: String;
  LRelative: String;
  LGuid: TGuid;
  LCount: Integer;
  I: Integer;
begin
  AddLibrary;
  AddRuntime;
  AddWebDirectory('', 0);
  Require(FFiles.IndexOf('index.html') >= 0, 'Pages entry point is missing');
  LPlan := TJSONObject.Create(['format', 'phanes.pages.plan/v1', 'bytes', FBytes]);
  LEntries := TJSONArray.Create;
  LPlan.Add('files', LEntries);
  LReport := nil;
  try
    for I := 0 to FFiles.Count - 1 do
    begin
      LEntries.Add(TJSONObject(FFiles.Objects[I]).Clone);
    end;
    LText := StringReplace(LPlan.FormatJSON, #13#10, #10, [rfReplaceAll]);
    SetLength(LPlanBytes, Length(LText));
    if Length(LText) > 0 then
    begin
      Move(LText[1], LPlanBytes[0], Length(LText));
    end;
    LHash := HashBytes(LPlanBytes);
    LRelative := 'build/pages/' + LHash;
    LFinal := SafeChild(FRoot, LRelative);
    if not DirectoryExists(LFinal) then
    begin
      CreateGUID(LGuid);
      LStage := SafeChild(FRoot, 'build/pages/stage-' + GUIDToString(LGuid));
      Require(not DirectoryExists(LStage), 'Pages stage already exists');
      ForceDirectories(LStage);
      for I := 0 to FFiles.Count - 1 do
      begin
        LFile := TJSONObject(FFiles.Objects[I]);
        CopyFileBytes(SafeChild(FWeb, LFile.Strings['path']),
          SafeChild(LStage, LFile.Strings['path']));
      end;
      LCount := 0;
      VerifyTree(LStage, '', LCount);
      Require(LCount = FFiles.Count, 'Pages staged file count differs');
      Require(RenameFile(LStage, LFinal), 'Could not publish Pages stage');
    end;
    LCount := 0;
    VerifyTree(LFinal, '', LCount);
    Require(LCount = FFiles.Count, 'Pages published file count differs');
    LReport := TJSONObject.Create(['format', 'phanes.pages.evidence/v1',
      'path', LRelative, 'planSha256', LHash, 'files', FFiles.Count,
      'bytes', FBytes, 'budgetBytes', FBudget, 'plan', LPlan.Clone]);
    WriteTextAtomic(SafeChild(FRoot, 'build/pages-evidence.json'), LReport.FormatJSON + #10);
    WriteTextAtomic(SafeChild(FRoot, 'build/pages-site-path.txt'), LRelative + #10);
    WriteLn('Pages stage: ', FFiles.Count, ' files / ', FBytes, ' bytes; ', LRelative);
  finally
    LReport.Free;
    LPlan.Free;
  end;
end;

procedure StagePages(const ARoot: String; const AByteBudget: Int64);
var
  LStager: TPagesStager;
begin
  LStager := TPagesStager.Create(ARoot, AByteBudget);
  try
    LStager.Run;
  finally
    LStager.Free;
  end;
end;

end.
