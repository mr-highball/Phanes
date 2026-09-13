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

program PhanesTestsCollectionsCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  phanes.tools.files,
  phanes.tools.kits,
  phanes.tools.collections,
  phanes.tools.sourcehtml,
  phanes.tools.catalog;

const
  FixtureKit = 'critic-collection';
  FAQURL = 'https://www.thebasemesh.com/faq';
  ModelText = '{"asset":{"version":"2.0"},"buffers":[{"uri":"model.bin","byteLength":36}],' +
    '"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36}],' +
    '"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3",' +
    '"min":[0,0,0],"max":[1,1,0]}],' +
    '"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],' +
    '"images":[{"uri":"texture.png"}],"nodes":[{"mesh":0}],' +
    '"scenes":[{"nodes":[0]}],"scene":0}';

type
  TFixture = class
  public
    FRoot: String;
    FKit: TJSONObject;
    FFAQ: String;
    constructor Create(const AName, AMode: String);
    destructor Destroy; override;
    procedure SaveLock;
  end;

var
  GScratch: String;
  GChecks: Integer;
  GFailures: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    Inc(GFailures);
    WriteLn('FAIL ', AMessage);
  end;
end;

function TextBytes(const AText: String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

function Page(const ACanonical, ABody: String): String;
begin
  Result := '<html><head><link rel="canonical" href="' + ACanonical +
    '"/></head><body>' + ABody + '</body></html>';
end;

procedure SourceArchive(const ARoot, AId, AMode: String; const ASource: TJSONObject);
var
  LZip: TZipper;
  LStreams: TList;
  LStream: TMemoryStream;
  LArchive: String;
  LModel: String;
  LBytes: TBytes;
  LHash: String;
  LPage: String;
  LPagePath: String;
  LRawPath: String;
  LName: String;
  LSourceIsLast: Boolean;
  I: Integer;

  procedure Add(const AName: String; const ABytes: TBytes);
  var
    LEntry: TZipFileEntry;
  begin
    LStream := TMemoryStream.Create;
    LStreams.Add(LStream);
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
    LStream.Position := 0;
    LEntry := LZip.Entries.AddFileEntry(LStream, AName);
    LEntry.DateTime := EncodeDate(1980, 1, 1);
    LEntry.OS := 0;
    LEntry.Attributes := faArchive;
  end;

begin
  LSourceIsLast := AId = 'bravo';
  LModel := ModelText;
  if LSourceIsLast and (AMode = 'cross-source-dependency') then
  begin
    LModel := StringReplace(LModel, 'texture.png', '../alpha/texture.png', [rfReplaceAll]);
  end;
  LArchive := SafeChild(ARoot, 'archive-' + AId + '.zip');
  LZip := TZipper.Create;
  LStreams := TList.Create;
  try
    LZip.FileName := LArchive;
    Add('model.gltf', TextBytes(LModel));
    Add('model.obj', TextBytes('unselected format copy'));
    LBytes := nil;
    SetLength(LBytes, 36);
    LBytes[14] := $80;
    LBytes[15] := $3F;
    LBytes[30] := $80;
    LBytes[31] := $3F;
    Add('model.bin', LBytes);
    if not (LSourceIsLast and ((AMode = 'missing-dependency') or
      (AMode = 'stale-stage') or (AMode = 'cross-source-dependency'))) then
    begin
      LName := 'texture.png';
      if LSourceIsLast and (AMode = 'dependency-case') then
      begin
        LName := 'Texture.png';
      end;
      Add(LName, TextBytes('source-owned texture bytes ' + AId));
    end;
    if LSourceIsLast and (AMode = 'duplicate-archive-case') then
    begin
      Add('TEXTURE.PNG', TextBytes('second case collision'));
    end;
    if LSourceIsLast and (AMode = 'bundled-notice') then
    begin
      Add('elsewhere/License_Standard.txt', TextBytes('CC-BY-4.0'));
    end;
    LZip.ZipAllFiles;
  finally
    LZip.Free;
    for I := 0 to LStreams.Count - 1 do
    begin
      TStream(LStreams[I]).Free;
    end;
    LStreams.Free;
  end;
  LHash := HashFile(LArchive);
  if LSourceIsLast and (AMode = 'bad-second-archive') then
  begin
    LHash := StringOfChar('0', 64);
  end;
  WriteBytes(SafeChild(ARoot, 'build/asset-research/collections/' + LHash + '.zip'),
    ReadBytes(LArchive));
  ASource.Add('archiveSha256', LHash);
  ASource.Add('models', TJSONArray.Create([TJSONObject.Create(['path', 'model.gltf',
    'sha256', HashBytes(TextBytes(LModel)), 'bytes', Length(LModel)])]));
  if LSourceIsLast and (AMode = 'bad-second-model') then
  begin
    ASource.Arrays['models'].Objects[0].Strings['sha256'] := StringOfChar('0', 64);
  end;
  LPage := Page(ASource.Strings['page'], '<a href="' + ASource.Strings['archiveUrl'] + '">ZIP</a>');
  if LSourceIsLast and (AMode = 'wrong-page-link') then
  begin
    LPage := Page(ASource.Strings['page'],
      '<a href="https://www.thebasemesh.com/_files/archives/wrong.zip">ZIP</a>');
  end;
  LRawPath := SafeChild(ARoot, 'page-' + AId + '.html');
  LPagePath := 'assets/provenance/' + FixtureKit + '/' + AId + '.html.zlib';
  WriteBytes(LRawPath, TextBytes(LPage));
  CompressSourceEvidence(LRawPath, SafeChild(ARoot, LPagePath));
  ASource.Add('pageSha256', HashBytes(TextBytes(LPage)));
  ASource.Add('pageEvidence', LPagePath);
  ASource.Add('pageEvidenceSha256', HashFile(SafeChild(ARoot, LPagePath)));
  if LSourceIsLast and (AMode = 'stale-stage') then
  begin
    WriteBytes(SafeChild(ARoot, 'build/asset-staging/' + LHash + '/bravo/texture.png'),
      TextBytes('stale source-owned texture'));
  end;
end;

constructor TFixture.Create(const AName, AMode: String);
var
  LGuid: TGUID;
  LSources: TJSONArray;
  LSource: TJSONObject;
  LFAQPath: String;
  LPalette: TJSONObject;
  LPaletteAssets: TJSONArray;
  LId: String;
  I: Integer;
begin
  inherited Create;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fixture identifier');
  FRoot := SafeChild(GScratch, AName + '-' + GUIDToString(LGuid));
  Require(not DirectoryExists(FRoot), 'Expected fresh collection fixture root');
  FKit := TJSONObject.Create(['id', FixtureKit, 'name', 'Synthetic collection',
    'publisher', 'The Base Mesh', 'author', 'The Base Mesh and contributors',
    'page', 'https://www.thebasemesh.com/model-library', 'theme', 'fixture',
    'sourceMode', 'collection.v1', 'sourceAdapter', 'basemesh.v1',
    'storage', 'library', 'license', 'CC0-1.0']);
  FFAQ := Page(FAQURL, '<div role="listitem">' +
    '<h2>Can I use these Assets in commercial works?</h2>' +
    '<p>You certainly can as these models are under the CC0 licence.</p>' +
    '<a href="https://creativecommons.org/publicdomain/zero/1.0/">CC0</a></div>');
  LFAQPath := 'assets/provenance/' + FixtureKit + '/faq.html.zlib';
  WriteBytes(SafeChild(FRoot, 'faq.html'), TextBytes(FFAQ));
  CompressSourceEvidence(SafeChild(FRoot, 'faq.html'), SafeChild(FRoot, LFAQPath));
  FKit.Add('licenseEvidence', TJSONObject.Create(['mode', 'basemesh.faq.v1', 'url', FAQURL,
    'path', LFAQPath, 'sha256', HashBytes(TextBytes(FFAQ)),
    'compressedSha256', HashFile(SafeChild(FRoot, LFAQPath))]));
  LSources := TJSONArray.Create;
  FKit.Add('sources', LSources);
  for I := 0 to 1 do
  begin
    LId := 'alpha';
    if I = 1 then
    begin
      LId := 'bravo';
    end;
    LSource := TJSONObject.Create(['id', LId, 'name', LId,
      'page', 'https://www.thebasemesh.com/asset/' + LId,
      'archiveUrl', 'https://www.thebasemesh.com/_files/archives/' + LId + '.zip?dn=' + LId + '.zip',
      'modelPrefix', '', 'modelFormat', 'gltf2']);
    LSources.Add(LSource);
    SourceArchive(FRoot, LId, AMode, LSource);
  end;
  if AMode = 'duplicate-source' then
  begin
    LSources.Objects[1].Strings['id'] := 'alpha';
  end;
  if AMode = 'reserved-source' then
  begin
    LSources.Objects[1].Strings['id'] := 'provenance';
  end;
  if AMode = 'mixed-mode' then
  begin
    FKit.Add('archiveUrl', 'https://www.thebasemesh.com/_files/archives/other.zip');
  end;
  if AMode = 'unsupported-version' then
  begin
    FKit.Strings['sourceMode'] := 'collection.v99';
  end;
  if AMode = 'unsafe-member' then
  begin
    LSources.Objects[0].Arrays['models'].Objects[0].Strings['path'] := '../model.gltf';
  end;
  if AMode = 'format-collision' then
  begin
    LSource := TJSONObject(LSources.Objects[0].Arrays['models'].Objects[0].Clone);
    LSource.Strings['path'] := 'model.glb';
    LSources.Objects[0].Arrays['models'].Add(LSource);
  end;
  if AMode = 'unsupported-alias' then
  begin
    LSources.Objects[0].Add('dependencyAliases', TJSONArray.Create);
  end;
  if AMode = 'fractional-bytes' then
  begin
    LSource := LSources.Objects[0].Arrays['models'].Objects[0];
    I := LSource.Integers['bytes'];
    LSource.Delete('bytes');
    LSource.Add('bytes', I + 0.25);
  end;
  if AMode = 'string-bytes' then
  begin
    LSource := LSources.Objects[0].Arrays['models'].Objects[0];
    I := LSource.Integers['bytes'];
    LSource.Delete('bytes');
    LSource.Add('bytes', IntToStr(I));
  end;
  WriteText(SafeChild(FRoot, 'data/asset-inventory.json'),
    '{"version":2,"assets":[],"sentinel":"old inventory"}' + #10);
  LPaletteAssets := TJSONArray.Create;
  LPalette := TJSONObject.Create;
  LPalette.Add('assets', LPaletteAssets);
  try
    { The shared verifier requires nine regional role labels. These synthetic
      references all point to one admitted fixture file; no runtime palette is
      copied or modified and no placement readiness is implied. }
    for I := 0 to 8 do
    begin
      LPaletteAssets.Add(TJSONObject.Create(['id', FixtureKit + '/alpha/model',
        'kind', 'fixture-role-' + IntToStr(I), 'width', 1]));
    end;
    WriteTextAtomic(SafeChild(FRoot, 'data/palette.json'), LPalette.FormatJSON + #10);
  finally
    LPalette.Free;
  end;
  SaveLock;
end;

destructor TFixture.Destroy;
begin
  FKit.Free;
  inherited Destroy;
end;

procedure TFixture.SaveLock;
var
  LLock: TJSONObject;
begin
  LLock := TJSONObject.Create(['version', 1]);
  LLock.Add('kits', TJSONArray.Create([FKit.Clone]));
  try
    WriteTextAtomic(SafeChild(FRoot, 'data/kits.lock.json'), LLock.FormatJSON + #10);
  finally
    LLock.Free;
  end;
end;

function TryImport(const AFixture: TFixture): Boolean;
begin
  Result := True;
  try
    ImportKits(AFixture.FRoot);
  except
    on LException: Exception do
    begin
      Result := False;
      WriteLn('REJECT import: ', LException.Message);
    end;
  end;
end;

function TryVerify(const AFixture: TFixture): Boolean;
begin
  Result := True;
  try
    VerifyKits(AFixture.FRoot);
  except
    on LException: Exception do
    begin
      Result := False;
      WriteLn('REJECT verify: ', LException.Message);
    end;
  end;
end;

procedure ImportCase(const AMode: String; const AExpected: Boolean);
var
  LFixture: TFixture;
  LBefore: String;
  LAccepted: Boolean;
  LInventory: TJSONObject;
  LAsset: TJSONObject;
  LPublished: String;
  I: Integer;
begin
  LFixture := TFixture.Create(AMode, AMode);
  try
    LBefore := HashFile(SafeChild(LFixture.FRoot, 'data/asset-inventory.json'));
    LAccepted := TryImport(LFixture);
    Check(LAccepted = AExpected, AMode + ' import acceptance');
    LPublished := SafeChild(LFixture.FRoot, 'assets/library/kits/' + FixtureKit);
    if not LAccepted then
    begin
      Check(HashFile(SafeChild(LFixture.FRoot, 'data/asset-inventory.json')) = LBefore,
        AMode + ' exact prior inventory preserved');
      Check(not DirectoryExists(LPublished), AMode + ' no partially published collection');
      Exit;
    end;
    LInventory := LoadJSON(SafeChild(LFixture.FRoot, 'data/asset-inventory.json'));
    try
      Check(LInventory.Arrays['assets'].Count = 2, AMode + ' two models, not four format copies');
      for I := 0 to 1 do
      begin
        LAsset := LInventory.Arrays['assets'].Objects[I];
        Check(LAsset.Strings['sourceId'] = LFixture.FKit.Arrays['sources'].Objects[I].Strings['id'],
          AMode + ' source namespace');
        Check(LAsset.Strings['sourceMember'] = 'model.gltf', AMode + ' original member');
        Check(LAsset.Arrays['dependencies'].Count = 2, AMode + ' exact external closure');
        Check(LAsset.Arrays['dependencies'].Objects[0].Strings['path'] =
          LAsset.Strings['sourceId'] + '/texture.png', AMode + ' source-owned texture');
        Check(not FileExists(SafeChild(LPublished, LAsset.Strings['sourceId'] + '/model.obj')),
          AMode + ' unselected format excluded');
        Check(HashFile(SafeChild(LPublished, 'Provenance/' + LAsset.Strings['sourceId'] +
          '.html.zlib')) = LFixture.FKit.Arrays['sources'].Objects[I].Strings['pageEvidenceSha256'],
          AMode + ' exact compressed source evidence');
      end;
      Check(HashFile(SafeChild(LPublished, 'SourceLicense.html')) =
        HashBytes(TextBytes(LFixture.FFAQ)), AMode + ' common exact FAQ once');
      Check(HashFile(SafeChild(LPublished, 'SourceLicense.html.zlib')) =
        LFixture.FKit.Objects['licenseEvidence'].Strings['compressedSha256'],
        AMode + ' retained exact common compressed evidence');
      Check(not FileExists(SafeChild(LPublished, 'alpha/SourceLicense.html')),
        AMode + ' no per-model FAQ copy');
      Check(TryVerify(LFixture), AMode + ' full shared verifier positive');
    finally
      LInventory.Free;
    end;
  finally
    LFixture.Free;
  end;
end;

procedure VerifyCase(const AMode: String);
var
  LFixture: TFixture;
  LInventory: TJSONObject;
  LRows: TJSONArray;
  LModel: TJSONObject;
  LPath: String;
  LByteCount: Integer;
begin
  LFixture := TFixture.Create('verify-' + AMode, 'valid');
  try
    Require(TryImport(LFixture), 'Verification fixture baseline must import');
    LInventory := LoadJSON(SafeChild(LFixture.FRoot, 'data/asset-inventory.json'));
    try
      LRows := LInventory.Arrays['assets'];
      LModel := LRows.Objects[0];
      if AMode = 'unknown-source' then
      begin
        LModel.Strings['sourceId'] := 'unknown';
      end;
      if AMode = 'swapped-source' then
      begin
        LModel.Strings['sourceId'] := 'bravo';
      end;
      if AMode = 'member-case' then
      begin
        LModel.Strings['sourceMember'] := 'MODEL.gltf';
      end;
      if AMode = 'omitted-model' then
      begin
        LRows.Delete(1);
      end;
      if AMode = 'duplicate-model' then
      begin
        LRows.Add(LRows.Objects[0].Clone);
      end;
      if AMode = 'dependency-hash' then
      begin
        LModel.Arrays['dependencies'].Objects[0].Strings['sha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'texture-bytes' then
      begin
        WriteBytes(SafeChild(LFixture.FRoot,
          'assets/library/kits/' + FixtureKit + '/alpha/texture.png'), TextBytes('changed'));
      end;
      if AMode = 'source-page-bytes' then
      begin
        WriteBytes(SafeChild(LFixture.FRoot,
          'assets/library/kits/' + FixtureKit + '/Provenance/alpha.html.zlib'), TextBytes('changed'));
      end;
      if AMode = 'faq-bytes' then
      begin
        WriteBytes(SafeChild(LFixture.FRoot,
          'assets/library/kits/' + FixtureKit + '/SourceLicense.html'), TextBytes('changed'));
      end;
      if AMode = 'source-page-hash' then
      begin
        LFixture.FKit.Arrays['sources'].Objects[0].Strings['pageSha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'source-archive-link' then
      begin
        LFixture.FKit.Arrays['sources'].Objects[0].Strings['archiveUrl'] :=
          'https://www.thebasemesh.com/_files/archives/wrong.zip';
      end;
      if AMode = 'faq-raw-hash' then
      begin
        LFixture.FKit.Objects['licenseEvidence'].Strings['sha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'faq-compressed-hash' then
      begin
        LFixture.FKit.Objects['licenseEvidence'].Strings['compressedSha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'faq-compressed-bytes' then
      begin
        WriteBytes(SafeChild(LFixture.FRoot,
          'assets/library/kits/' + FixtureKit + '/SourceLicense.html.zlib'), TextBytes('changed'));
      end;
      if AMode = 'source-evidence-hash' then
      begin
        LFixture.FKit.Arrays['sources'].Objects[0].Strings['pageEvidenceSha256'] :=
          StringOfChar('0', 64);
      end;
      if AMode = 'source-archive-pin' then
      begin
        LFixture.FKit.Arrays['sources'].Objects[0].Strings['archiveSha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'source-archive-row' then
      begin
        LModel.Strings['sourceArchiveSha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'source-page-row' then
      begin
        LModel.Strings['sourcePageSha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'faq-path' then
      begin
        LFixture.FKit.Objects['licenseEvidence'].Strings['path'] :=
          'assets/provenance/' + FixtureKit + '/another.html.zlib';
      end;
      if AMode = 'page-evidence-path' then
      begin
        LFixture.FKit.Arrays['sources'].Objects[0].Strings['pageEvidence'] :=
          LFixture.FKit.Arrays['sources'].Objects[1].Strings['pageEvidence'];
      end;
      if AMode = 'fractional-inventory-bytes' then
      begin
        LByteCount := LModel.Integers['bytes'];
        LModel.Delete('bytes');
        LModel.Add('bytes', LByteCount + 0.25);
      end;
      if AMode = 'string-inventory-bytes' then
      begin
        LByteCount := LModel.Integers['bytes'];
        LModel.Delete('bytes');
        LModel.Add('bytes', IntToStr(LByteCount));
      end;
      if AMode = 'format' then
      begin
        LModel.Strings['format'] := 'glb';
      end;
      if AMode = 'storage' then
      begin
        LModel.Strings['storage'] := 'core';
      end;
      if AMode = 'license' then
      begin
        LModel.Strings['license'] := 'CC-BY-4.0';
      end;
      LPath := SafeChild(LFixture.FRoot, 'data/asset-inventory.json');
      WriteTextAtomic(LPath, LInventory.FormatJSON + #10);
      LFixture.SaveLock;
      Check(not TryVerify(LFixture), AMode + ' verification rejects');
    finally
      LInventory.Free;
    end;
  finally
    LFixture.Free;
  end;
end;

procedure PackageExclusions(const AFixture: TFixture);
var
  LIndex: TJSONObject;
  LManifest: TJSONObject;
  LFiles: TJSONArray;
  LZip: TUnZipper;
  LRelative: String;
  I: Integer;
  J: Integer;
begin
  LIndex := LoadJSON(SafeChild(AFixture.FRoot, 'build/web/data/library-files.json'));
  try
    Check(LIndex.Arrays['kits'].Count = 1, 'Two distributions remain one published kit');
    LManifest := LoadJSON(SafeChild(AFixture.FRoot,
      'build/web/' + LIndex.Arrays['kits'].Objects[0].Strings['url']));
    try
      Check(LManifest.Objects['notice'].Strings['path'] = 'SourceLicense.html',
        'Runtime notice uses common original raw FAQ');
      Check(LManifest.Arrays['models'].Count = 2, 'Two original models in fine manifest');
      for I := 0 to LManifest.Arrays['models'].Count - 1 do
      begin
        LFiles := LManifest.Arrays['models'].Objects[I].Arrays['files'];
        Check(LFiles.Count = 3, 'Fine manifest includes only model and two dependencies');
        for J := 0 to LFiles.Count - 1 do
        begin
          LRelative := LFiles.Objects[J].Strings['path'];
          Check((Pos('Provenance/', LRelative) = 0) and (Pos('.zlib', LRelative) = 0),
            'Fine file closure excludes developer evidence');
        end;
      end;
    finally
      LManifest.Free;
    end;
  finally
    LIndex.Free;
  end;
  LIndex := LoadJSON(SafeChild(AFixture.FRoot, 'build/web/data/library-packages.json'));
  LZip := TUnZipper.Create;
  try
    LZip.FileName := SafeChild(AFixture.FRoot,
      'build/web/' + LIndex.Arrays['packages'].Objects[0].Strings['url']);
    LZip.Examine;
    Check(LZip.Entries.Count = 7, 'Kit package has six source files and one notice');
    for I := 0 to LZip.Entries.Count - 1 do
    begin
      LRelative := LZip.Entries[I].ArchiveFileName;
      Check((Pos('Provenance/', LRelative) = 0) and (Pos('.zlib', LRelative) = 0),
        'Kit ZIP excludes developer evidence');
    end;
  finally
    LZip.Free;
    LIndex.Free;
  end;
end;

procedure TransactionCases;
var
  LFixture: TFixture;
  LRows: TJSONArray;
  LBefore: String;
  LAccepted: Boolean;
  LArray: TJSONArray;
  LIndexHash: String;
begin
  LFixture := TFixture.Create('direct-rollback', 'bad-second-model');
  LRows := TJSONArray.Create([TJSONObject.Create(['kit', 'unrelated', 'sentinel', 123])]);
  try
    LBefore := LRows.AsJSON;
    LAccepted := True;
    try
      ImportCollectionKit(LFixture.FRoot, LFixture.FKit, LRows);
    except
      on LException: Exception do
      begin
        LAccepted := False;
      end;
    end;
    Check(not LAccepted, 'Direct collection operation rejects second source failure');
    Check(LRows.AsJSON = LBefore, 'Direct operation rolls back appended rows exactly');
  finally
    LRows.Free;
    LFixture.Free;
  end;
  LFixture := TFixture.Create('stable-reimport', 'valid');
  try
    Require(TryImport(LFixture), 'Reimport baseline');
    LBefore := HashFile(SafeChild(LFixture.FRoot, 'data/asset-inventory.json'));
    LArray := TJSONArray.Create;
    LArray.Add(LFixture.FKit.Arrays['sources'].Objects[1].Clone);
    LArray.Add(LFixture.FKit.Arrays['sources'].Objects[0].Clone);
    LFixture.FKit.Delete('sources');
    LFixture.FKit.Add('sources', LArray);
    LFixture.SaveLock;
    Check(TryImport(LFixture), 'Reordered sources reimport successfully');
    Check(HashFile(SafeChild(LFixture.FRoot, 'data/asset-inventory.json')) = LBefore,
      'Source order does not alter canonical inventory bytes');
    PackageCatalog(LFixture.FRoot);
    PackageExclusions(LFixture);
    LIndexHash := HashFile(SafeChild(LFixture.FRoot, 'build/web/data/library-files.json'));
    PackageCatalog(LFixture.FRoot);
    Check(HashFile(SafeChild(LFixture.FRoot, 'build/web/data/library-files.json')) = LIndexHash,
      'Collection package/manifest publication repeats exactly');
    LFixture.FKit.Arrays['sources'].Objects[0].Arrays['models'].Objects[0].Strings['sha256'] :=
      StringOfChar('0', 64);
    LFixture.SaveLock;
    Check(not TryImport(LFixture), 'Changed source fails reimport');
    Check(HashFile(SafeChild(LFixture.FRoot, 'data/asset-inventory.json')) = LBefore,
      'Failed reimport preserves old inventory bytes');
    Check(HashFile(SafeChild(LFixture.FRoot,
      'assets/library/kits/' + FixtureKit + '/alpha/model.gltf')) = HashBytes(TextBytes(ModelText)),
      'Failed reimport preserves published source model');
  finally
    LFixture.Free;
  end;
end;

procedure DeclaredBudgetCase;
var
  LFixture: TFixture;
  LModels: TJSONArray;
  LAccepted: Boolean;
  I: Integer;
begin
  LFixture := TFixture.Create('declared-budget', 'valid');
  try
    LModels := TJSONArray.Create;
    for I := 0 to 32 do
    begin
      LModels.Add(TJSONObject.Create(['path', 'model-' + IntToStr(I) + '.gltf',
        'sha256', StringOfChar('0', 64), 'bytes', 32 * 1024 * 1024]));
    end;
    LFixture.FKit.Arrays['sources'].Objects[0].Delete('models');
    LFixture.FKit.Arrays['sources'].Objects[0].Add('models', LModels);
    LAccepted := True;
    try
      CheckCollectionKit(LFixture.FKit);
    except
      on LException: Exception do
      begin
        LAccepted := False;
      end;
    end;
    Check(not LAccepted, 'Aggregate declared byte bound rejects without archive processing');
    Check(not DirectoryExists(SafeChild(LFixture.FRoot, 'build/asset-staging')),
      'Declared bound creates no extraction stage');
  finally
    LFixture.Free;
  end;
end;

procedure Run;
var
  LRoot: String;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  LRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(LRoot, 'build/tests/collections-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  ImportCase('valid', True);
  ImportCase('duplicate-source', False);
  ImportCase('reserved-source', False);
  ImportCase('mixed-mode', False);
  ImportCase('unsupported-version', False);
  ImportCase('unsafe-member', False);
  ImportCase('format-collision', False);
  ImportCase('unsupported-alias', False);
  ImportCase('missing-dependency', False);
  ImportCase('cross-source-dependency', False);
  ImportCase('dependency-case', False);
  ImportCase('duplicate-archive-case', False);
  ImportCase('bundled-notice', False);
  ImportCase('bad-second-archive', False);
  ImportCase('bad-second-model', False);
  ImportCase('wrong-page-link', False);
  ImportCase('stale-stage', False);
  ImportCase('fractional-bytes', False);
  ImportCase('string-bytes', False);
  VerifyCase('unknown-source');
  VerifyCase('swapped-source');
  VerifyCase('member-case');
  VerifyCase('omitted-model');
  VerifyCase('duplicate-model');
  VerifyCase('dependency-hash');
  VerifyCase('texture-bytes');
  VerifyCase('source-page-bytes');
  VerifyCase('faq-bytes');
  VerifyCase('source-page-hash');
  VerifyCase('source-archive-link');
  VerifyCase('faq-raw-hash');
  VerifyCase('faq-compressed-hash');
  VerifyCase('faq-compressed-bytes');
  VerifyCase('source-evidence-hash');
  VerifyCase('source-archive-pin');
  VerifyCase('source-archive-row');
  VerifyCase('source-page-row');
  VerifyCase('faq-path');
  VerifyCase('page-evidence-path');
  VerifyCase('fractional-inventory-bytes');
  VerifyCase('string-inventory-bytes');
  VerifyCase('format');
  VerifyCase('storage');
  VerifyCase('license');
  TransactionCases;
  DeclaredBudgetCase;
  WriteLn('RESULT ', GChecks, ' independent collection checks, failures=', GFailures);
  Require(GFailures = 0, 'Independent collection checks failed');
end;

begin
  Run;
end.
