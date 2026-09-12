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

program PhanesTestsPagesCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  phanes.tools.files,
  phanes.tools.pages;

type
  TMutation = (pmIndexVersionString, pmIndexVersionFraction, pmManifestVersionString,
    pmCountString, pmCountFraction, pmByteString, pmByteFraction, pmByteZero,
    pmByteOverflow, pmInventoryBinding, pmLockBinding, pmBlobHash, pmBlobURL,
    pmManifestURL, pmMissingModel, pmDuplicateModel, pmUnknownModel, pmModelPath,
    pmModelHash, pmModelFormat, pmModelDownloadBytes, pmOmittedDependency,
    pmExtraDependency, pmDuplicateDependency, pmNoticeSubstitution, pmPublisher,
    pmSource, pmLicense, pmExtraKit, pmDuplicateKit, pmUnknownBlob,
    pmMissingIndex, pmExistingExtraFile, pmExistingChangedFile, pmInventoryVersion,
    pmLockVersion, pmUniqueFilesString, pmUniqueBytesWrong, pmModelName,
    pmDependencyCase, pmNoticePath, pmNullModels, pmNullNotice,
    pmInventoryVersionString, pmLockVersionFraction);

  TFixture = class
  public
    FRoot: String;
    FWeb: String;
    FInventory: TJSONObject;
    FLock: TJSONObject;
    FManifest: TJSONObject;
    FIndex: TJSONObject;
    FBlobPath: String;
    FPointer: UTF8String;
    FReport: UTF8String;
    FStage: String;
    FCase: String;
    constructor Create(const AName: String);
    destructor Destroy; override;
    procedure Save;
    procedure Baseline;
    procedure ExpectReject(const AName: String; const ABudget: Int64 = PagesByteBudget);
    function Blob(const APath: String; const AText: UTF8String): TJSONObject;
  end;

const
  MutationNames: array[TMutation] of String = (
    'string index version', 'fractional index version', 'string manifest version',
    'string model count', 'fractional model count', 'string byte count',
    'fractional byte count', 'zero byte count', 'overflow byte count',
    'stale inventory', 'stale lock', 'changed blob bytes', 'blob path escape',
    'manifest URL escape', 'omitted inventory model', 'duplicated model identity',
    'unknown model identity', 'model local path escape', 'model hash substitution',
    'model format substitution', 'wrong model download bytes', 'missing dependency',
    'invented dependency', 'duplicated dependency path', 'substituted notice',
    'wrong publisher', 'wrong publisher source', 'wrong license',
    'missing optional kit', 'duplicate optional kit', 'missing referenced blob',
    'missing entry point', 'extra immutable output file', 'changed immutable output bytes',
    'unknown inventory version', 'unknown source lock version', 'string unique file count',
    'wrong unique byte total', 'changed model name', 'dependency path case',
    'notice path substitution', 'null models array', 'null notice object',
    'string inventory version', 'fractional source lock version');

var
  GChecks: Integer;
  GFailures: Integer;
  GScratch: String;
  GCaseCount: Integer;

procedure Check(const ACondition: Boolean; const AName: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    Inc(GFailures);
    WriteLn('FAIL ', AName);
  end;
end;

procedure Put(const AObject: TJSONObject; const AKey: String; const AValue: TJSONData);
begin
  if AObject.Find(AKey) <> nil then
  begin
    AObject.Delete(AKey);
  end;
  AObject.Add(AKey, AValue);
end;

function BytesOf(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

function TFixture.Blob(const APath: String; const AText: UTF8String): TJSONObject;
var
  LBytes: TBytes;
  LHash: String;
begin
  LBytes := BytesOf(AText);
  LHash := HashBytes(LBytes);
  WriteBytes(SafeChild(FWeb, 'library/blobs/' + LHash), LBytes);
  Result := TJSONObject.Create(['path', APath, 'sha256', LHash,
    'bytes', Length(LBytes), 'url', 'library/blobs/' + LHash]);
end;

constructor TFixture.Create(const AName: String);
var
  LFiles: TJSONArray;
  LDependencies: TJSONArray;
  LBuffer: TJSONObject;
  LImage: TJSONObject;
  LNotice: TJSONObject;
  LModelFile: TJSONObject;
  LName: String;
  LBytes: Int64;
  I: Integer;
begin
  inherited Create;
  Inc(GCaseCount);
  FCase := AName;
  FRoot := SafeChild(GScratch, 'case-' + IntToStr(GCaseCount));
  Require(not DirectoryExists(FRoot), 'Fixture must start fresh');
  FWeb := SafeChild(FRoot, 'build/web');
  FInventory := TJSONObject.Create(['version', 2]);
  FInventory.Add('assets', TJSONArray.Create);
  FLock := TJSONObject.Create(['version', 1]);
  FLock.Add('kits', TJSONArray.Create([
    TJSONObject.Create(['id', 'fixture', 'storage', 'library', 'publisher', 'Fixture Artist',
      'author', 'Fixture Artist', 'page', 'https://example.invalid/fixture',
      'license', 'CC0-1.0'])]));
  FManifest := TJSONObject.Create(['version', 1, 'kit', 'fixture',
    'author', 'Fixture Artist', 'source', 'https://example.invalid/fixture',
    'license', 'CC0-1.0', 'inventorySha256', '']);
  FManifest.Add('models', TJSONArray.Create);
  FIndex := TJSONObject.Create(['version', 1, 'recipe', 'phanes.catalog.files.v1',
    'inventorySha256', '', 'sourceLockSha256', '', 'uniqueFiles', 5, 'uniqueBytes', 0]);
  FIndex.Add('kits', TJSONArray.Create([TJSONObject.Create(['id', 'fixture', 'models', 2,
    'url', '', 'sha256', '', 'bytes', 1])]));
  LBuffer := Blob('shared.bin', 'ABC');
  LImage := Blob('textures/shared.png', 'PNG fixture bytes');
  LNotice := Blob('License.txt', 'Fixture assets are CC0.');
  FManifest.Add('notice', LNotice.Clone);
  LBytes := LBuffer.Int64s['bytes'] + LImage.Int64s['bytes'] + LNotice.Int64s['bytes'];
  try
    for I := 0 to 1 do
    begin
      LName := 'one';
      if I = 1 then
      begin
        LName := 'two';
      end;
      LModelFile := Blob(LName + '.gltf', UTF8String('{"asset":{"version":"2.0"},' +
        '"extras":{"name":"' + LName + '"},' +
        '"buffers":[{"uri":"shared.bin","byteLength":3}],' +
        '"images":[{"uri":"textures/shared.png"}]}'));
      Inc(LBytes, LModelFile.Int64s['bytes']);
      if I = 0 then
      begin
        FBlobPath := LModelFile.Strings['url'];
      end;
      LDependencies := TJSONArray.Create([LBuffer.Clone, LImage.Clone]);
      FInventory.Arrays['assets'].Add(TJSONObject.Create(['id', 'fixture/' + LName,
        'kit', 'fixture', 'name', LName, 'format', 'gltf', 'storage', 'library',
        'url', 'kits/fixture/' + LName + '.gltf', 'sha256', LModelFile.Strings['sha256'],
        'bytes', LModelFile.Int64s['bytes'], 'license', 'CC0-1.0',
        'licenseFile', 'License.txt', 'licenseSha256', LNotice.Strings['sha256'],
        'dependencies', LDependencies]));
      LFiles := TJSONArray.Create([LModelFile, LBuffer.Clone, LImage.Clone]);
      FManifest.Arrays['models'].Add(TJSONObject.Create(['id', 'fixture/' + LName,
        'name', LName, 'format', 'gltf', 'path', LName + '.gltf',
        'sha256', LModelFile.Strings['sha256'],
        'downloadBytes', LModelFile.Int64s['bytes'] + LBuffer.Int64s['bytes'] +
          LImage.Int64s['bytes'], 'files', LFiles]));
    end;
  finally
    LNotice.Free;
    LImage.Free;
    LBuffer.Free;
  end;
  FIndex.Int64s['uniqueBytes'] := LBytes;
  WriteText(SafeChild(FWeb, 'index.html'), '<!doctype html><title>Fixture</title>');
  WriteText(SafeChild(FWeb, 'app.js'), 'fixture');
  WriteText(SafeChild(FWeb, 'empty.txt'), '');
  WriteText(SafeChild(FWeb, '.nojekyll'), '');
  WriteText(SafeChild(FWeb, 'library/unused.zip'), 'obsolete bulk package');
  WriteText(SafeChild(FWeb, 'library/catalog/obsolete.json'), '{}');
  WriteText(SafeChild(FWeb, 'library/blobs/obsolete'), 'unreferenced bytes');
  WriteText(SafeChild(FWeb, 'data/library-packages.json'), '{"obsolete":true}');
  Save;
end;

destructor TFixture.Destroy;
begin
  FIndex.Free;
  FManifest.Free;
  FLock.Free;
  FInventory.Free;
  inherited Destroy;
end;

procedure TFixture.Save;
var
  LBytes: TBytes;
  LHash: String;
  LKit: TJSONObject;
begin
  WriteTextAtomic(SafeChild(FRoot, 'data/asset-inventory.json'), FInventory.FormatJSON);
  WriteTextAtomic(SafeChild(FRoot, 'data/kits.lock.json'), FLock.FormatJSON);
  CopyFileBytes(SafeChild(FRoot, 'data/asset-inventory.json'),
    SafeChild(FWeb, 'data/asset-inventory.json'));
  CopyFileBytes(SafeChild(FRoot, 'data/kits.lock.json'), SafeChild(FWeb, 'data/kits.lock.json'));
  FManifest.Strings['inventorySha256'] := HashFile(SafeChild(FRoot, 'data/asset-inventory.json'));
  FIndex.Strings['inventorySha256'] := FManifest.Strings['inventorySha256'];
  FIndex.Strings['sourceLockSha256'] := HashFile(SafeChild(FRoot, 'data/kits.lock.json'));
  LBytes := BytesOf(UTF8String(FManifest.FormatJSON));
  LHash := HashBytes(LBytes);
  LKit := FIndex.Arrays['kits'].Objects[0];
  LKit.Strings['sha256'] := LHash;
  LKit.Strings['url'] := 'library/catalog/fixture-' + LHash + '.json';
  LKit.Int64s['bytes'] := Length(LBytes);
  WriteBytes(SafeChild(FWeb, LKit.Strings['url']), LBytes);
  WriteTextAtomic(SafeChild(FWeb, 'data/library-files.json'), FIndex.FormatJSON);
end;

procedure TFixture.Baseline;
var
  LReport: TJSONObject;
begin
  StagePages(FRoot);
  FPointer := ReadText(SafeChild(FRoot, 'build/pages-site-path.txt'));
  FReport := ReadText(SafeChild(FRoot, 'build/pages-evidence.json'));
  FStage := SafeChild(FRoot, Trim(String(FPointer)));
  LReport := LoadJSON(SafeChild(FRoot, 'build/pages-evidence.json'));
  try
    Check(LReport.Integers['files'] = 13, FCase + ': exact shared closure count');
    Check(FileExists(SafeChild(FStage, '.nojekyll')), FCase + ': hidden ordinary file retained');
    Check(FileByteCount(SafeChild(FStage, 'empty.txt')) = 0, FCase + ': empty ordinary file retained');
    Check(not FileExists(SafeChild(FStage, 'library/unused.zip')), FCase + ': bulk ZIP excluded');
    Check(not FileExists(SafeChild(FStage, 'library/catalog/obsolete.json')),
      FCase + ': stale manifest excluded');
    Check(not FileExists(SafeChild(FStage, 'library/blobs/obsolete')), FCase + ': stale blob excluded');
    Check(not FileExists(SafeChild(FStage, 'data/library-packages.json')),
      FCase + ': unavailable bulk index excluded');
  finally
    LReport.Free;
  end;
end;

procedure TFixture.ExpectReject(const AName: String; const ABudget: Int64);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    StagePages(FRoot, ABudget);
  except
    on LException: Exception do
    begin
      LRejected := True;
      WriteLn('REJECT ', AName, ': ', LException.Message);
    end;
  end;
  Check(LRejected, AName + ': rejected');
  Check(ReadText(SafeChild(FRoot, 'build/pages-site-path.txt')) = FPointer,
    AName + ': previous pointer retained');
  Check(ReadText(SafeChild(FRoot, 'build/pages-evidence.json')) = FReport,
    AName + ': previous report retained');
end;

procedure MutationCase(const AKind: TMutation);
var
  LFixture: TFixture;
  LModel: TJSONObject;
  LFile: TJSONObject;
  LKit: TJSONObject;
  LExtra: TJSONObject;
begin
  LFixture := TFixture.Create(MutationNames[AKind]);
  try
    LFixture.Baseline;
    LModel := LFixture.FManifest.Arrays['models'].Objects[0];
    LFile := LModel.Arrays['files'].Objects[0];
    LKit := LFixture.FIndex.Arrays['kits'].Objects[0];
    case AKind of
      pmIndexVersionString: Put(LFixture.FIndex, 'version', TJSONString.Create('1'));
      pmIndexVersionFraction: Put(LFixture.FIndex, 'version', TJSONFloatNumber.Create(1.25));
      pmManifestVersionString: Put(LFixture.FManifest, 'version', TJSONString.Create('1'));
      pmCountString: Put(LKit, 'models', TJSONString.Create('2'));
      pmCountFraction: Put(LKit, 'models', TJSONFloatNumber.Create(2.5));
      pmByteString: Put(LFile, 'bytes', TJSONString.Create(IntToStr(LFile.Int64s['bytes'])));
      pmByteFraction: Put(LFile, 'bytes', TJSONFloatNumber.Create(LFile.Int64s['bytes'] + 0.5));
      pmByteZero: LFile.Int64s['bytes'] := 0;
      pmByteOverflow: Put(LFile, 'bytes', TJSONQWordNumber.Create(High(QWord)));
      pmMissingModel:
      begin
        LFixture.FManifest.Arrays['models'].Delete(1);
        LKit.Integers['models'] := 1;
      end;
      pmDuplicateModel:
      begin
        LFixture.FManifest.Arrays['models'].Delete(1);
        LFixture.FManifest.Arrays['models'].Add(LModel.Clone);
      end;
      pmUnknownModel: LModel.Strings['id'] := 'fixture/unknown';
      pmModelPath: LModel.Strings['path'] := '../one.gltf';
      pmModelHash: LModel.Strings['sha256'] := StringOfChar('0', 64);
      pmModelFormat: LModel.Strings['format'] := 'glb';
      pmModelDownloadBytes: LModel.Int64s['downloadBytes'] := 1;
      pmOmittedDependency: LModel.Arrays['files'].Delete(1);
      pmExtraDependency:
      begin
        LExtra := LFixture.Blob('unrelated.bin', 'not part of the original model');
        LModel.Arrays['files'].Add(LExtra);
      end;
      pmDuplicateDependency: LModel.Arrays['files'].Add(LFile.Clone);
      pmNoticeSubstitution:
      begin
        LExtra := LFixture.Blob('License.txt', 'Unrelated substituted notice');
        Put(LFixture.FManifest, 'notice', LExtra);
      end;
      pmPublisher: LFixture.FManifest.Strings['author'] := 'Unrelated Publisher';
      pmSource: LFixture.FManifest.Strings['source'] := 'https://example.invalid/other';
      pmLicense: LFixture.FManifest.Strings['license'] := 'Unrelated-License';
      pmExtraKit:
      begin
        LExtra := TJSONObject(LFixture.FLock.Arrays['kits'].Objects[0].Clone);
        LExtra.Strings['id'] := 'missing-kit';
        LFixture.FLock.Arrays['kits'].Add(LExtra);
      end;
      pmDuplicateKit: LFixture.FIndex.Arrays['kits'].Add(LKit.Clone);
      pmInventoryVersion: LFixture.FInventory.Integers['version'] := 99;
      pmLockVersion: LFixture.FLock.Integers['version'] := 99;
      pmUniqueFilesString: Put(LFixture.FIndex, 'uniqueFiles', TJSONString.Create('5'));
      pmUniqueBytesWrong: LFixture.FIndex.Int64s['uniqueBytes'] := 1;
      pmModelName: LModel.Strings['name'] := 'Invented alternate name';
      pmDependencyCase: LModel.Arrays['files'].Objects[1].Strings['path'] := 'SHARED.bin';
      pmNoticePath: LFixture.FManifest.Objects['notice'].Strings['path'] := '../License.txt';
      pmNullModels: Put(LFixture.FManifest, 'models', TJSONNull.Create);
      pmNullNotice: Put(LFixture.FManifest, 'notice', TJSONNull.Create);
      pmInventoryVersionString: Put(LFixture.FInventory, 'version', TJSONString.Create('2'));
      pmLockVersionFraction: Put(LFixture.FLock, 'version', TJSONFloatNumber.Create(1.25));
    end;
    LFixture.Save;
    case AKind of
      pmInventoryBinding: LFixture.FIndex.Strings['inventorySha256'] := StringOfChar('0', 64);
      pmLockBinding: LFixture.FIndex.Strings['sourceLockSha256'] := StringOfChar('0', 64);
      pmBlobHash: WriteText(SafeChild(LFixture.FWeb, LFixture.FBlobPath), 'corrupted');
      pmBlobURL:
      begin
        LFile.Strings['url'] := 'library/blobs/../../index.html';
        LFixture.Save;
      end;
      pmManifestURL: LKit.Strings['url'] := 'library/catalog/../../index.html';
      pmUnknownBlob: Require(DeleteFile(SafeChild(LFixture.FWeb, LFixture.FBlobPath)),
        'Cannot remove owned fixture blob');
      pmMissingIndex: Require(DeleteFile(SafeChild(LFixture.FWeb, 'index.html')),
        'Cannot remove owned fixture entry point');
      pmExistingExtraFile: WriteText(SafeChild(LFixture.FStage, 'extra.txt'), 'unexpected');
      pmExistingChangedFile: WriteText(SafeChild(LFixture.FStage, 'app.js'), 'tampered');
    end;
    WriteTextAtomic(SafeChild(LFixture.FWeb, 'data/library-files.json'), LFixture.FIndex.FormatJSON);
    LFixture.ExpectReject(MutationNames[AKind]);
  finally
    LFixture.Free;
  end;
end;

procedure PositiveCases;
var
  LFixture: TFixture;
  LReport: TJSONObject;
  LByteCount: Int64;
  LOldStage: String;
  LNewPointer: UTF8String;
begin
  LFixture := TFixture.Create('positive publication');
  try
    LFixture.Baseline;
    StagePages(LFixture.FRoot);
    Check(ReadText(SafeChild(LFixture.FRoot, 'build/pages-site-path.txt')) = LFixture.FPointer,
      'Unchanged source reuses exact immutable path');
    Check(ReadText(SafeChild(LFixture.FRoot, 'build/pages-evidence.json')) = LFixture.FReport,
      'Unchanged source reuses exact report');
    LReport := LoadJSON(SafeChild(LFixture.FRoot, 'build/pages-evidence.json'));
    try
      LByteCount := LReport.Int64s['bytes'];
    finally
      LReport.Free;
    end;
    StagePages(LFixture.FRoot, LByteCount);
    Check(ReadText(SafeChild(LFixture.FRoot, 'build/pages-site-path.txt')) = LFixture.FPointer,
      'Exact byte budget passes without changing content identity');
    LFixture.FReport := ReadText(SafeChild(LFixture.FRoot, 'build/pages-evidence.json'));
    LFixture.ExpectReject('one byte over budget', LByteCount - 1);
    LFixture.ExpectReject('zero budget', 0);
    LFixture.ExpectReject('negative budget', -1);
    LFixture.ExpectReject('over maximum budget', PagesByteBudget + 1);
    LOldStage := LFixture.FStage;
    WriteText(SafeChild(LFixture.FWeb, 'app.js'), 'new content');
    StagePages(LFixture.FRoot);
    LNewPointer := ReadText(SafeChild(LFixture.FRoot, 'build/pages-site-path.txt'));
    Check(LNewPointer <> LFixture.FPointer, 'Changed source publishes a new immutable path');
    Check(ReadText(SafeChild(LOldStage, 'app.js')) = 'fixture', 'Old published bytes preserved');
    Check(ReadText(SafeChild(LFixture.FRoot, Trim(String(LNewPointer)) + '/app.js')) =
      'new content', 'New output contains exact changed bytes');
  finally
    LFixture.Free;
  end;
end;

function ShellLiteral(const AText: String): String;
begin
  Result := '''' + StringReplace(AText, '''', '''''', [rfReplaceAll]) + '''';
end;

procedure DirectoryLink(const ALink, ATarget: String);
{$IFDEF WINDOWS}
var
  LProcess: TProcess;
{$ENDIF}
begin
  Require((Pos(IncludeTrailingPathDelimiter(GScratch), ExpandFileName(ALink)) = 1) and
    (Pos(IncludeTrailingPathDelimiter(GScratch), ExpandFileName(ATarget)) = 1),
    'Link fixture must remain inside its fresh scratch directory');
  {$IFDEF WINDOWS}
  { A directory junction does not require developer mode/admin symlink rights.
    The fixed native PowerShell operation receives correctly quoted literals. }
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := 'powershell.exe';
    LProcess.Parameters.Add('-NoProfile');
    LProcess.Parameters.Add('-NonInteractive');
    LProcess.Parameters.Add('-Command');
    LProcess.Parameters.Add('New-Item -ItemType Junction -Path ' + ShellLiteral(ALink) +
      ' -Target ' + ShellLiteral(ATarget) + ' -ErrorAction Stop | Out-Null');
    LProcess.Options := [poUsePipes, poWaitOnExit, poNoConsole];
    LProcess.Execute;
    Require(LProcess.ExitStatus = 0, 'Could not create Windows junction fixture');
  finally
    LProcess.Free;
  end;
  {$ELSE}
  Require(fpSymlink(PChar(ATarget), PChar(ALink)) = 0, 'Could not create symlink fixture');
  {$ENDIF}
  Require(DirectoryExists(ALink), 'Created fixture link is not accessible');
end;

procedure LinkCases;
var
  LFixture: TFixture;
  LLink: String;
  LTarget: String;
  I: Integer;
begin
  for I := 0 to 4 do
  begin
    LFixture := TFixture.Create('link boundary ' + IntToStr(I));
    try
      LFixture.Baseline;
      if I = 0 then
      begin
        LLink := SafeChild(LFixture.FRoot, 'build/web/assets');
        LTarget := SafeChild(LFixture.FRoot, 'outside-web');
        ForceDirectories(LTarget);
        WriteText(SafeChild(LTarget, 'hidden.txt'), 'must not be followed');
        DirectoryLink(LLink, LTarget);
      end
      else if I = 1 then
      begin
        LLink := SafeChild(LFixture.FRoot, 'build');
        LTarget := SafeChild(LFixture.FRoot, 'linked-build');
        Require(RenameFile(LLink, LTarget), 'Cannot relocate owned build fixture');
        DirectoryLink(LLink, LTarget);
      end
      else if I = 2 then
      begin
        LLink := SafeChild(LFixture.FRoot, 'build/pages');
        LTarget := SafeChild(LFixture.FRoot, 'linked-pages');
        Require(RenameFile(LLink, LTarget), 'Cannot relocate owned Pages fixture');
        DirectoryLink(LLink, LTarget);
        WriteText(SafeChild(LFixture.FWeb, 'app.js'), 'forces a new stage');
      end
      else if I = 3 then
      begin
        LTarget := LFixture.FRoot;
        LLink := SafeChild(GScratch, 'root-link-' + IntToStr(GCaseCount));
        DirectoryLink(LLink, LTarget);
        LFixture.FRoot := LLink;
      end
      else
      begin
        LLink := SafeChild(LFixture.FRoot, 'data');
        LTarget := SafeChild(LFixture.FRoot, 'linked-data');
        Require(RenameFile(LLink, LTarget), 'Cannot relocate owned metadata fixture');
        DirectoryLink(LLink, LTarget);
      end;
      LFixture.ExpectReject('link boundary ' + IntToStr(I));
    finally
      LFixture.Free;
    end;
  end;
end;

procedure RuntimeCases;
var
  LFixture: TFixture;
  LBinding: TJSONObject;
  LManifest: TJSONObject;
  LFiles: TJSONArray;
  LFile: TJSONObject;
  LParts: TJSONArray;
  LPart: TJSONObject;
  LSource: TBytes;
  LBytes: TBytes;
  LHash: String;
  LName: String;
  LStage: String;
  LSwap: TJSONData;
  LCase: Integer;
  I: Integer;
  J: Integer;
begin
  for LCase := 0 to 13 do
  begin
    LFixture := TFixture.Create('runtime ' + IntToStr(LCase));
    LManifest := TJSONObject.Create(['version', 1, 'partBytes', 524288]);
    try
      LFixture.Save;
      LFixture.Baseline;
      LFiles := TJSONArray.Create;
      LManifest.Add('files', LFiles);
      for I := 0 to 1 do
      begin
        LName := 'phanes.wasm';
        if I = 1 then
        begin
          LName := 'phanes_data.zip';
        end;
        SetLength(LSource, 1048578);
        FillChar(LSource[0], 524288, $11 + I);
        FillChar(LSource[524288], 524288, $22);
        FillChar(LSource[1048576], 2, $33);
        WriteBytes(SafeChild(LFixture.FWeb, LName), LSource);
        LFile := TJSONObject.Create(['path', LName, 'bytes', Length(LSource),
          'sha256', HashBytes(LSource)]);
        LFiles.Add(LFile);
        LParts := TJSONArray.Create;
        LFile.Add('parts', LParts);
        for J := 0 to 2 do
        begin
          SetLength(LBytes, 524288);
          if J = 2 then
          begin
            SetLength(LBytes, 2);
          end;
          Move(LSource[J * 524288], LBytes[0], Length(LBytes));
          LHash := HashBytes(LBytes);
          LPart := TJSONObject.Create(['url', 'runtime/parts/' + LHash + '.part',
            'bytes', Length(LBytes), 'sha256', LHash]);
          LParts.Add(LPart);
          WriteBytes(SafeChild(LFixture.FWeb, LPart.Strings['url']), LBytes);
        end;
      end;
      WriteText(SafeChild(LFixture.FWeb, 'runtime/parts/stale.part'), 'stale');
      LParts := LFiles.Objects[0].Arrays['parts'];
      case LCase of
        1:
          begin
            LParts.Objects[2].Integers['bytes'] := 3;
          end;
        2:
          begin
            LSwap := LParts.Extract(0);
            LParts.Insert(1, LSwap);
          end;
        3:
          begin
            LParts.Objects[0].Strings['sha256'] := 'unknown';
          end;
        4:
          begin
            DeleteFile(SafeChild(LFixture.FWeb, LParts.Objects[0].Strings['url']));
          end;
        5:
          begin
            WriteText(SafeChild(LFixture.FWeb, 'phanes.wasm'), 'changed source');
          end;
        6:
          begin
            LFiles.Objects[1].Strings['path'] := 'phanes.wasm';
          end;
        7:
          begin
            LParts.Objects[0].Strings['url'] := '../escape';
          end;
        8:
          begin
            WriteText(SafeChild(LFixture.FWeb, LParts.Objects[0].Strings['url']), 'corrupt');
          end;
      end;
      if LCase <> 9 then
      begin
        WriteText(SafeChild(LFixture.FWeb, 'data/runtime-parts.json'), LManifest.FormatJSON);
        WriteText(SafeChild(LFixture.FWeb, 'phanes.js'), 'Compiled host fixture');
        if LCase <> 12 then
        begin
          LBinding := TJSONObject.Create(['version', 1, 'hostSha256',
            HashFile(SafeChild(LFixture.FWeb, 'phanes.js')), 'manifestSha256',
            HashFile(SafeChild(LFixture.FWeb, 'data/runtime-parts.json'))]);
          try
            WriteText(SafeChild(LFixture.FWeb, 'data/runtime-host.json'), LBinding.FormatJSON);
          finally
            LBinding.Free;
          end;
        end;
        if LCase = 10 then
        begin
          WriteText(SafeChild(LFixture.FWeb, 'phanes.js'), 'Stale compiled host');
        end else if LCase = 11 then
        begin
          WriteText(SafeChild(LFixture.FWeb, 'data/runtime-parts.json'),
            LManifest.FormatJSON + ' ');
        end else if LCase = 13 then
        begin
          DeleteFile(SafeChild(LFixture.FWeb, 'data/runtime-parts.json'));
          Require(RenameFile(SafeChild(LFixture.FWeb, 'runtime'),
            SafeChild(LFixture.FRoot, 'removed-runtime')), 'Relocate owned fixture parts');
        end;
      end;
      if LCase = 0 then
      begin
        StagePages(LFixture.FRoot);
        LStage := SafeChild(LFixture.FRoot,
          Trim(String(ReadText(SafeChild(LFixture.FRoot, 'build/pages-site-path.txt')))));
        Check(not FileExists(SafeChild(LStage, 'phanes.wasm')), 'Runtime source WASM excluded');
        Check(not FileExists(SafeChild(LStage, 'phanes_data.zip')), 'Runtime source ZIP excluded');
        Check(not FileExists(SafeChild(LStage, 'runtime/parts/stale.part')), 'Stale part excluded');
        Check(FileExists(SafeChild(LStage, LParts.Objects[2].Strings['url'])),
          'Verified final short part included');
        Check(FileExists(SafeChild(LStage, 'data/runtime-parts.json')), 'Current manifest included');
      end else
      begin
        LFixture.ExpectReject('runtime mutation ' + IntToStr(LCase));
      end;
    finally
      LManifest.Free;
      LFixture.Free;
    end;
  end;
end;


procedure Run;
var
  LRoot: String;
  LGuid: TGUID;
  LMutation: TMutation;
  LEvidence: TJSONObject;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  LRoot := ExpandFileName(ParamStr(1));
  { Keep this scratch prefix short: immutable output adds two full hashes to
    some Windows paths. Each run still owns a complete fresh GUID directory. }
  GScratch := SafeChild(LRoot, 'build/p');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture ID');
  GScratch := SafeChild(GScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Expected a fresh fixture directory');
  ForceDirectories(GScratch);
  PositiveCases;
  RuntimeCases;
  for LMutation := Low(TMutation) to High(TMutation) do
  begin
    MutationCase(LMutation);
  end;
  LinkCases;
  LEvidence := TJSONObject.Create(['checks', GChecks, 'failures', GFailures,
    'cases', GCaseCount, 'scratch', GScratch]);
  try
    WriteTextAtomic(SafeChild(GScratch, 'evidence.json'), LEvidence.FormatJSON + #10);
  finally
    LEvidence.Free;
  end;
  WriteLn('PAGES CRITIC ', GChecks, ' checks; ', GFailures, ' failures; ', GScratch);
  if GFailures <> 0 then
  begin
    Halt(1);
  end;
end;

begin
  Run;
end.
