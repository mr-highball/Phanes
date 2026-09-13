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

unit phanes.tools.derived;

{$mode delphi}
{$H+}

interface

uses
  FPJSON;

procedure CheckDerivedKit(const AKit: TJSONObject);
procedure ImportDerivedKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
procedure VerifyDerivedKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);

implementation

uses
  Classes,
  SysUtils,
  Zipper,
  phanes.tools.files,
  phanes.tools.kits,
  phanes.tools.obj;

const
  DerivedKitLimit = 512 * 1024 * 1024;
  DerivedFileLimit = 20000;

procedure HashValue(const AValue: String);
var
  I: Integer;
begin
  Require(Length(AValue) = 64, 'Expected derived-source SHA-256');
  for I := 1 to Length(AValue) do
  begin
    Require(AValue[I] in ['0'..'9', 'a'..'f'], 'Noncanonical derived-source SHA-256');
  end;
end;

procedure Identifier(const AValue: String);
var
  I: Integer;
begin
  Require((Length(AValue) > 0) and (Length(AValue) <= 120), 'Invalid derived identifier');
  for I := 1 to Length(AValue) do
  begin
    Require(AValue[I] in ['a'..'z', '0'..'9', '-', '_'], 'Noncanonical derived identifier');
  end;
end;

function RequiredString(const AObject: TJSONObject; const AName: String): String;
begin
  Require(AObject.Find(AName) is TJSONString, 'Expected string field: ' + AName);
  Result := AObject.Strings[AName];
  Require(Result <> '', 'Empty derived field: ' + AName);
end;

function RequiredSize(const AObject: TJSONObject; const AName: String;
  const AMaximum: Int64): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue is TJSONNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64, ntQWord]),
    'Expected integer byte count: ' + AName);
  Result := LValue.AsInt64;
  Require((Result > 0) and (Result <= AMaximum), 'Derived byte count exceeds bounds');
end;

procedure LocalChain(const APath: String);
var
  LPath: String;
  LParent: String;
  LAttributes: LongInt;
begin
  LPath := ExpandFileName(APath);
  repeat
    LAttributes := FileGetAttr(LPath);
    if LAttributes >= 0 then
    begin
      Require((LAttributes and faSymLink) = 0, 'Derived path contains a filesystem link');
    end;
    LParent := ExtractFileDir(LPath);
    if (LParent = LPath) or (LParent = '') then
    begin
      Break;
    end;
    LPath := LParent;
  until False;
end;

procedure CheckDerivedKit(const AKit: TJSONObject);
var
  LModels: TJSONArray;
  LPin: TJSONObject;
  LIds: TStringList;
  LPaths: TStringList;
  LPath: String;
  LMTL: String;
  LName: String;
  LTotal: Int64;
  I: Integer;
begin
  Require(RequiredString(AKit, 'sourceMode') = 'derived.obj.v1', 'Unknown derived source mode');
  Identifier(RequiredString(AKit, 'id'));
  Require(Pos('_', AKit.Strings['id']) = 0, 'Kit identifiers allow hyphens only');
  Require(RequiredString(AKit, 'storage') = 'library', 'Derived kits must remain optional');
  Require(RequiredString(AKit, 'license') = 'CC0-1.0', 'Unsupported derived source license');
  Require((AKit.Find('sources') = nil) and (AKit.Find('modelPrefix') = nil) and
    (AKit.Find('modelFormat') = nil) and (AKit.Find('dependencyAliases') = nil),
    'Derived source modes cannot be mixed');
  HashValue(RequiredString(AKit, 'archiveSha256'));
  HashValue(RequiredString(AKit, 'licenseSha256'));
  Require(Copy(RequiredString(AKit, 'archiveUrl'), 1, 8) = 'https://', 'Expected original HTTPS archive');
  Require(Copy(RequiredString(AKit, 'page'), 1, 8) = 'https://', 'Expected original HTTPS source page');
  RequiredString(AKit, 'author');
  RequiredString(AKit, 'theme');
  RequiredSize(AKit, 'licenseBytes', 2 * 1024 * 1024);
  if AKit.Find('licenseEvidence') <> nil then
  begin
    Require((AKit.Find('licenseEvidence') is TJSONObject) and
      (AKit.Find('licensePath') = nil), 'Choose bundled or creator-page notice explicitly');
    Require(RequiredString(AKit.Objects['licenseEvidence'], 'mode') = 'oga-submission.v1',
      'Unsupported derived creator evidence adapter');
    Require(RequiredString(AKit.Objects['licenseEvidence'], 'url') = AKit.Strings['page'],
      'Creator evidence must be the pinned original source page');
    Require(RequiredString(AKit.Objects['licenseEvidence'], 'sha256') =
      AKit.Strings['licenseSha256'], 'Creator evidence hash binding differs');
    Require(RequiredSize(AKit.Objects['licenseEvidence'], 'bytes', 2 * 1024 * 1024) =
      AKit.Int64s['licenseBytes'], 'Creator evidence byte binding differs');
  end else
  begin
    CheckArchivePath(RequiredString(AKit, 'licensePath'));
    Require(AKit.Int64s['licenseBytes'] <= 1024 * 1024, 'Bundled notice exceeds byte bound');
  end;
  Require(AKit.Find('models') is TJSONArray, 'Expected explicit derived model selection');
  LModels := AKit.Arrays['models'];
  Require((LModels.Count > 0) and (LModels.Count <= 5000), 'Derived model count outside bounds');
  LIds := TStringList.Create;
  LPaths := TStringList.Create;
  LIds.Sorted := True;
  LIds.CaseSensitive := False;
  LPaths.Sorted := True;
  LPaths.CaseSensitive := False;
  LTotal := 0;
  try
    for I := 0 to LModels.Count - 1 do
    begin
      Require(LModels[I] is TJSONObject, 'Expected derived model object');
      LPin := LModels.Objects[I];
      LName := RequiredString(LPin, 'id');
      Identifier(LName);
      Require(LIds.IndexOf(LName) < 0, 'Duplicate derived model identifier');
      LIds.Add(LName);
      Require(Length(RequiredString(LPin, 'name')) <= 240, 'Derived display name is too long');
      LPath := RequiredString(LPin, 'path');
      LMTL := RequiredString(LPin, 'mtlPath');
      CheckArchivePath(LPath);
      CheckArchivePath(LMTL);
      Require((LowerCase(ExtractFileExt(LPath)) = '.obj') and
        (LowerCase(ExtractFileExt(LMTL)) = '.mtl'), 'Expected OBJ and MTL source members');
      Require(ExtractFilePath(LPath) = ExtractFilePath(LMTL),
        'First derived recipe requires MTL in the original OBJ directory');
      Require(LPaths.IndexOf(LPath) < 0, 'Duplicate original OBJ selection');
      LPaths.Add(LPath);
      Require((LPath <> AKit.Get('licensePath', '')) and
        (LMTL <> AKit.Get('licensePath', '')), 'Source notice cannot be a model dependency');
      HashValue(RequiredString(LPin, 'objSha256'));
      HashValue(RequiredString(LPin, 'mtlSha256'));
      HashValue(RequiredString(LPin, 'sha256'));
      Inc(LTotal, RequiredSize(LPin, 'objBytes', StaticOBJInputLimit));
      Inc(LTotal, RequiredSize(LPin, 'mtlBytes', StaticOBJInputLimit));
      Inc(LTotal, RequiredSize(LPin, 'bytes', StaticOBJOutputLimit));
      Require(LTotal <= DerivedKitLimit, 'Declared derived selection exceeds cumulative budget');
      LName := RequiredString(LPin, 'recipe');
      Require((LName = StaticOBJRecipe) or (LName = SurfaceOBJRecipe),
        'Unsupported pinned conversion recipe');
    end;
  finally
    LPaths.Free;
    LIds.Free;
  end;
end;

type
  TBoundedMemoryStream = class(TMemoryStream)
    FLimit: Int64;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

  TDerivedKit = class
  private
    FRoot: String;
    FKit: TJSONObject;
    FStage: String;
    FPublished: String;
    FReadRoot: String;
    FNoticeFile: String;
    FWrite: Boolean;
    FFiles: TStringList;
    FSourcePins: TStringList;
    FTotal: Int64;
    FRows: TJSONArray;
    procedure Remember(const APath: String; const ABytes: TBytes);
    procedure SourcePin(const APath, AHash, ATarget: String; const ABytes: Int64);
    procedure CreateStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure Extract;
    procedure CreatorNotice;
    procedure Prepare;
    procedure CheckClosure(const ADirectory, ARelative: String; var ACount: Integer);
    procedure CheckPublished;
    function AssetRow(const APin, ADerivation, AModel: TJSONObject): TJSONObject;
  public
    constructor Create(const ARoot: String; const AKit: TJSONObject; const AWrite: Boolean);
    destructor Destroy; override;
    procedure Import(const AInventory: TJSONArray);
    procedure Verify(const AInventory: TJSONArray);
  end;

function TBoundedMemoryStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Require((ACount >= 0) and (Position <= FLimit - ACount),
    'Decompressed source exceeds pinned byte bound');
  Result := inherited Write(ABuffer, ACount);
end;

constructor TDerivedKit.Create(const ARoot: String; const AKit: TJSONObject;
  const AWrite: Boolean);
var
  LGuid: TGUID;
begin
  inherited Create;
  CheckDerivedKit(AKit);
  FRoot := ExpandFileName(ARoot);
  FKit := AKit;
  FWrite := AWrite;
  FNoticeFile := 'License.txt';
  if FKit.Find('licenseEvidence') <> nil then
  begin
    FNoticeFile := 'SourceLicense.html';
  end;
  FPublished := SafeChild(FRoot, 'assets/library/kits/' + AKit.Strings['id']);
  LocalChain(FRoot);
  LocalChain(FPublished);
  FFiles := TStringList.Create;
  FFiles.Sorted := True;
  FFiles.CaseSensitive := True;
  FFiles.UseLocale := False;
  FSourcePins := TStringList.Create;
  FSourcePins.Sorted := True;
  FSourcePins.CaseSensitive := True;
  FSourcePins.UseLocale := False;
  FRows := TJSONArray.Create;
  if FWrite then
  begin
    CreateGUID(LGuid);
    FStage := SafeChild(FRoot, 'build/asset-staging/' + GUIDToString(LGuid));
    LocalChain(FStage);
    Require(not DirectoryExists(FStage) and not FileExists(FStage), 'Expected fresh derived stage');
    Require(ForceDirectories(FStage), 'Cannot create derived stage');
    FReadRoot := FStage;
  end else
  begin
    Require(DirectoryExists(FPublished), 'Missing published derived kit');
    FReadRoot := FPublished;
  end;
end;

destructor TDerivedKit.Destroy;
var
  I: Integer;
begin
  FRows.Free;
  if FFiles <> nil then
  begin
    for I := 0 to FFiles.Count - 1 do
    begin
      FFiles.Objects[I].Free;
    end;
  end;
  FFiles.Free;
  if FSourcePins <> nil then
  begin
    for I := 0 to FSourcePins.Count - 1 do
    begin
      FSourcePins.Objects[I].Free;
    end;
  end;
  FSourcePins.Free;
  inherited Destroy;
end;

procedure TDerivedKit.Remember(const APath: String; const ABytes: TBytes);
var
  LHash: String;
  LPin: TJSONObject;
  LPath: String;
  I: Integer;
begin
  CheckArchivePath(APath);
  LHash := HashBytes(ABytes);
  I := FFiles.IndexOf(APath);
  if I >= 0 then
  begin
    LPin := TJSONObject(FFiles.Objects[I]);
    Require((LPin.Strings['sha256'] = LHash) and (LPin.Int64s['bytes'] = Length(ABytes)),
      'Derived files collide with different bytes');
    Exit;
  end;
  Require(FFiles.Count < DerivedFileLimit, 'Derived file count exceeds budget');
  Inc(FTotal, Length(ABytes));
  Require(FTotal <= DerivedKitLimit, 'Derived stage exceeds cumulative byte budget');
  LPin := TJSONObject.Create(['sha256', LHash, 'bytes', Length(ABytes)]);
  FFiles.AddObject(APath, LPin);
  LPath := SafeChild(FReadRoot, APath);
  if FWrite then
  begin
    WriteBytes(LPath, ABytes);
  end else
  begin
    CheckExactFilePath(FReadRoot, APath);
    LocalChain(LPath);
    Require(not DirectoryExists(LPath) and (FileByteCount(LPath) = Length(ABytes)) and
      (HashFile(LPath) = LHash), 'Published derived bytes differ: ' + APath);
  end;
end;

procedure TDerivedKit.SourcePin(const APath, AHash, ATarget: String; const ABytes: Int64);
var
  LPin: TJSONObject;
  I: Integer;
begin
  I := FSourcePins.IndexOf(APath);
  if I >= 0 then
  begin
    LPin := TJSONObject(FSourcePins.Objects[I]);
    Require((LPin.Strings['sha256'] = AHash) and (LPin.Int64s['bytes'] = ABytes) and
      (LPin.Strings['target'] = ATarget), 'Conflicting original source member pins');
  end else
  begin
    FSourcePins.AddObject(APath, TJSONObject.Create([
      'sha256', AHash, 'bytes', ABytes, 'target', ATarget]));
  end;
end;

procedure TDerivedKit.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LPin: TJSONObject;
  LStream: TBoundedMemoryStream;
  I: Integer;
begin
  I := FSourcePins.IndexOf(AItem.ArchiveFileName);
  Require(I >= 0, 'Unexpected extracted derived source');
  LPin := TJSONObject(FSourcePins.Objects[I]);
  Require(AItem.Size = LPin.Int64s['bytes'], 'Original archive member size differs from pin');
  LStream := TBoundedMemoryStream.Create;
  LStream.FLimit := LPin.Int64s['bytes'];
  AStream := LStream;
end;

procedure TDerivedKit.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LBytes: TBytes;
  LPin: TJSONObject;
  I: Integer;
begin
  try
    I := FSourcePins.IndexOf(AItem.ArchiveFileName);
    Require(I >= 0, 'Unknown completed derived source');
    LPin := TJSONObject(FSourcePins.Objects[I]);
    Require(AStream.Size = LPin.Int64s['bytes'], 'Original extracted byte count differs');
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    AStream.ReadBuffer(LBytes[0], Length(LBytes));
    Require(HashBytes(LBytes) = LPin.Strings['sha256'], 'Original source hash differs');
    Remember(LPin.Strings['target'], LBytes);
  finally
    FreeAndNil(AStream);
  end;
end;

procedure TDerivedKit.Extract;
var
  LArchive: String;
  LZip: TUnZipper;
  LSelected: TStringList;
  LNames: TStringList;
  LName: String;
  LPin: TJSONObject;
  LBytes: TBytes;
  I: Integer;
begin
  if not FWrite then
  begin
    for I := 0 to FSourcePins.Count - 1 do
    begin
      LPin := TJSONObject(FSourcePins.Objects[I]);
      LName := LPin.Strings['target'];
      CheckExactFilePath(FReadRoot, LName);
      LocalChain(SafeChild(FReadRoot, LName));
      Require(FileByteCount(SafeChild(FReadRoot, LName)) = LPin.Int64s['bytes'],
        'Retained original size differs');
      LBytes := ReadBytes(SafeChild(FReadRoot, LName));
      Require(HashBytes(LBytes) = LPin.Strings['sha256'], 'Retained original hash differs');
      Remember(LName, LBytes);
    end;
    Exit;
  end;
  LArchive := SafeChild(FRoot, 'build/asset-research/derived/' +
    FKit.Strings['archiveSha256'] + '.zip');
  LocalChain(LArchive);
  FetchPinned(FKit.Strings['archiveUrl'], LArchive, FKit.Strings['archiveSha256']);
  LZip := TUnZipper.Create;
  LSelected := TStringList.Create;
  LNames := TStringList.Create;
  LNames.Sorted := True;
  LNames.CaseSensitive := False;
  LSelected.Sorted := True;
  LSelected.CaseSensitive := True;
  LSelected.UseLocale := False;
  try
    LZip.FileName := LArchive;
    LZip.Examine;
    Require(LZip.Entries.Count <= DerivedFileLimit, 'Original archive entry count exceeds budget');
    for I := 0 to LZip.Entries.Count - 1 do
    begin
      LName := LZip.Entries[I].ArchiveFileName;
      if FSourcePins.IndexOf(LName) >= 0 then
      begin
        CheckArchivePath(LName);
        Require(not LZip.Entries[I].IsLink and not LZip.Entries[I].IsDirectory,
          'Selected original must be a regular archive file');
        Require(LNames.IndexOf(LName) < 0, 'Duplicate/case-colliding original member');
        LNames.Add(LName);
        LSelected.Add(LName);
        LPin := TJSONObject(FSourcePins.Objects[FSourcePins.IndexOf(LName)]);
        Require(LZip.Entries[I].Size = LPin.Int64s['bytes'], 'Pinned member size differs');
      end else
      begin
        { Case-different selected members are never accepted as aliases. }
        for LName in FSourcePins do
        begin
          Require(not SameText(LName, LZip.Entries[I].ArchiveFileName),
            'Original member case differs from selection');
        end;
      end;
    end;
    Require(LSelected.Count = FSourcePins.Count, 'Missing original selected source member');
    LZip.OnCreateStream := CreateStream;
    LZip.OnDoneStream := DoneStream;
    LZip.UnZipFiles(LSelected);
  finally
    LNames.Free;
    LSelected.Free;
    LZip.Free;
  end;
end;

procedure TDerivedKit.CreatorNotice;
var
  LArchive: String;
  LCache: String;
  LZip: TUnZipper;
  LBytes: TBytes;
  LName: String;
  LExtension: String;
  LText: UTF8String;
  I: Integer;
begin
  LArchive := SafeChild(FRoot, 'build/asset-research/derived/' +
    FKit.Strings['archiveSha256'] + '.zip');
  LocalChain(LArchive);
  FetchPinned(FKit.Strings['archiveUrl'], LArchive, FKit.Strings['archiveSha256']);
  LZip := TUnZipper.Create;
  try
    LZip.FileName := LArchive;
    LZip.Examine;
    Require(LZip.Entries.Count <= DerivedFileLimit, 'Creator archive entry count exceeds bound');
    for I := 0 to LZip.Entries.Count - 1 do
    begin
      LName := LowerCase(ExtractFileName(LZip.Entries[I].ArchiveFileName));
      LExtension := ExtractFileExt(LName);
      Require(not (((Pos('license', LName) > 0) or (Pos('licence', LName) > 0)) and
        ((LExtension = '.txt') or (LExtension = '.md'))),
        'Creator-page evidence cannot replace a bundled notice');
    end;
  finally
    LZip.Free;
  end;
  if FWrite then
  begin
    LCache := SafeChild(FRoot, 'build/asset-research/derived/' +
      FKit.Strings['licenseSha256'] + '.html');
    LocalChain(LCache);
    FetchPinned(FKit.Objects['licenseEvidence'].Strings['url'], LCache,
      FKit.Strings['licenseSha256']);
  end else
  begin
    LCache := SafeChild(FReadRoot, FNoticeFile);
    CheckExactFilePath(FReadRoot, FNoticeFile);
    LocalChain(LCache);
  end;
  Require(FileByteCount(LCache) = FKit.Int64s['licenseBytes'], 'Creator notice byte count differs');
  LBytes := ReadBytes(LCache);
  Require(HashBytes(LBytes) = FKit.Strings['licenseSha256'], 'Creator notice hash differs');
  SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
  CheckCreatorEvidence(FKit, LText);
  Remember(FNoticeFile, LBytes);
end;

function TDerivedKit.AssetRow(const APin, ADerivation, AModel: TJSONObject): TJSONObject;
begin
  Result := TJSONObject.Create(['id', FKit.Strings['id'] + '/' + APin.Strings['id'],
    'kit', FKit.Strings['id'], 'name', APin.Strings['name'],
    'theme', FKit.Strings['theme'], 'suggestedRole', SuggestRole(APin.Strings['name']),
    'review', 'inventory-only', 'storage', 'library', 'format', 'glb',
    'url', 'kits/' + FKit.Strings['id'] + '/' + APin.Strings['id'] + '.glb',
    'sha256', APin.Strings['sha256'], 'bytes', APin.Int64s['bytes'],
    'license', 'CC0-1.0', 'source', FKit.Strings['page'],
    'licenseSha256', FKit.Strings['licenseSha256'],
    'sourceMode', 'derived.obj.v1', 'sourceArchiveSha256', FKit.Strings['archiveSha256'],
    'sourceMember', APin.Strings['path'], 'sourceSha256', APin.Strings['objSha256'],
    'materialMember', APin.Strings['mtlPath'], 'materialSha256', APin.Strings['mtlSha256'],
    'derivationRecipe', APin.Strings['recipe'],
    'sourceRepresentation', 'obj-static-mesh', 'animationPreserved', False,
    'derivationFile', 'Provenance/' + APin.Strings['id'] + '.json',
    'coordinatePolicy', ADerivation.Strings['coordinatePolicy'],
    'sourceUnits', ADerivation.Strings['units']]);
  Result.Add('meshLocalBounds', MeshBounds(AModel));
  Result.Add('dependencies', TJSONArray.Create);
  if FKit.Find('licenseEvidence') <> nil then
  begin
    Result.Add('licenseFile', FNoticeFile);
    Result.Add('licenseEvidence', FKit.Objects['licenseEvidence'].Clone);
  end;
end;

procedure TDerivedKit.Prepare;
var
  LModels: TStringList;
  LPin: TJSONObject;
  LKitEvidence: TJSONObject;
  LEvidence: TJSONObject;
  LModel: TJSONObject;
  LOBJ: TBytes;
  LMTL: TBytes;
  LOutput: TBytes;
  LText: UTF8String;
  I: Integer;
begin
  LModels := TStringList.Create;
  LModels.Sorted := True;
  LModels.CaseSensitive := True;
  LModels.UseLocale := False;
  try
    if FKit.Find('licenseEvidence') = nil then
    begin
      SourcePin(FKit.Strings['licensePath'], FKit.Strings['licenseSha256'],
        FNoticeFile, FKit.Int64s['licenseBytes']);
    end else
    begin
      CreatorNotice;
    end;
    for I := 0 to FKit.Arrays['models'].Count - 1 do
    begin
      LPin := FKit.Arrays['models'].Objects[I];
      LModels.AddObject(LPin.Strings['id'], LPin);
      SourcePin(LPin.Strings['path'], LPin.Strings['objSha256'],
        'Original/' + LPin.Strings['objSha256'] + '.obj', LPin.Int64s['objBytes']);
      SourcePin(LPin.Strings['mtlPath'], LPin.Strings['mtlSha256'],
        'Original/' + LPin.Strings['mtlSha256'] + '.mtl', LPin.Int64s['mtlBytes']);
    end;
    Extract;
    Require(Pos('CC0', ReadText(SafeChild(FReadRoot, FNoticeFile))) > 0,
      'Original archive notice does not contain CC0');
    LKitEvidence := TJSONObject.Create(['format', 'phanes.derived.kit/v1', 'kit', FKit.Clone]);
    try
      LText := LKitEvidence.AsJSON + #10;
      Remember('KitProvenance.json', BytesOf(LText));
    finally
      LKitEvidence.Free;
    end;
    for I := 0 to LModels.Count - 1 do
    begin
      LPin := TJSONObject(LModels.Objects[I]);
      LOBJ := ReadBytes(SafeChild(FReadRoot, 'Original/' + LPin.Strings['objSha256'] + '.obj'));
      LMTL := ReadBytes(SafeChild(FReadRoot, 'Original/' + LPin.Strings['mtlSha256'] + '.mtl'));
      LEvidence := nil;
      LModel := nil;
      try
        if LPin.Strings['recipe'] = StaticOBJRecipe then
        begin
          LOutput := ConvertStaticOBJ(ExtractFileName(LPin.Strings['path']),
            ExtractFileName(LPin.Strings['mtlPath']), LOBJ, LMTL, LEvidence);
        end else
        begin
          LOutput := ConvertSurfaceOBJ(ExtractFileName(LPin.Strings['path']),
            ExtractFileName(LPin.Strings['mtlPath']), LOBJ, LMTL, LEvidence);
        end;
        Require((HashBytes(LOutput) = LPin.Strings['sha256']) and
          (Length(LOutput) = LPin.Int64s['bytes']), 'Derived output differs from explicit pin');
        Remember(LPin.Strings['id'] + '.glb', LOutput);
        LText := LEvidence.AsJSON + #10;
        Remember('Provenance/' + LPin.Strings['id'] + '.json', BytesOf(LText));
        LModel := GLBJSON(LOutput);
        FRows.Add(AssetRow(LPin, LEvidence, LModel));
      finally
        LModel.Free;
        LEvidence.Free;
      end;
    end;
  finally
    LModels.Free;
  end;
end;

procedure TDerivedKit.CheckClosure(const ADirectory, ARelative: String; var ACount: Integer);
var
  LSearch: TSearchRec;
  LRelative: String;
  LFull: String;
  LPin: TJSONObject;
  I: Integer;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, LSearch) <> 0 then
  begin
    Exit;
  end;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
      begin
        Continue;
      end;
      Require((LSearch.Attr and faSymLink) = 0, 'Derived kit contains a filesystem link');
      LRelative := ARelative + LSearch.Name;
      LFull := SafeChild(ADirectory, LSearch.Name);
      if (LSearch.Attr and faDirectory) <> 0 then
      begin
        Require((ARelative = '') and
          ((LSearch.Name = 'Original') or (LSearch.Name = 'Provenance')),
          'Unexpected derived directory');
        CheckClosure(LFull, LRelative + '/', ACount);
      end else
      begin
        I := FFiles.IndexOf(LRelative);
        Require(I >= 0, 'Unlisted derived file: ' + LRelative);
        LPin := TJSONObject(FFiles.Objects[I]);
        Require((FileByteCount(LFull) = LPin.Int64s['bytes']) and
          (HashFile(LFull) = LPin.Strings['sha256']), 'Derived file closure differs');
        Inc(ACount);
        Require(ACount <= DerivedFileLimit, 'Derived file closure count exceeds bound');
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

procedure TDerivedKit.CheckPublished;
var
  LCount: Integer;
begin
  LocalChain(FPublished);
  Require(DirectoryExists(FPublished), 'Expected published derived directory');
  LCount := 0;
  CheckClosure(FPublished, '', LCount);
  Require(LCount = FFiles.Count, 'Published derived file closure is incomplete');
end;

procedure TDerivedKit.Import(const AInventory: TJSONArray);
var
  LCount: Integer;
  I: Integer;
begin
  Prepare;
  LCount := 0;
  CheckClosure(FStage, '', LCount);
  Require(LCount = FFiles.Count, 'Staged derived file closure is incomplete');
  LocalChain(FPublished);
  if DirectoryExists(FPublished) then
  begin
    CheckPublished;
  end else
  begin
    Require(not FileExists(FPublished), 'Derived destination already exists as a file');
    Require(ForceDirectories(ExtractFileDir(FPublished)), 'Cannot create derived kit parent');
    Require(RenameFile(FStage, FPublished), 'Cannot publish complete derived kit stage');
  end;
  for I := 0 to FRows.Count - 1 do
  begin
    AInventory.Add(FRows[I].Clone);
  end;
  WriteLn(FKit.Strings['id'], ': imported ', FRows.Count, ' pinned derived models.');
end;

procedure TDerivedKit.Verify(const AInventory: TJSONArray);
var
  LExpected: TStringList;
  LRow: TJSONObject;
  LExpectedRow: TJSONObject;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  Prepare;
  CheckPublished;
  LExpected := TStringList.Create;
  LExpected.Sorted := True;
  LExpected.CaseSensitive := True;
  LExpected.UseLocale := False;
  LCount := 0;
  try
    for I := 0 to FRows.Count - 1 do
    begin
      LExpected.AddObject(FRows.Objects[I].Strings['id'], FRows.Objects[I]);
    end;
    for I := 0 to AInventory.Count - 1 do
    begin
      LRow := AInventory.Objects[I];
      if LRow.Get('kit', '') <> FKit.Strings['id'] then
      begin
        Continue;
      end;
      J := LExpected.IndexOf(LRow.Strings['id']);
      Require(J >= 0, 'Unlisted or repeated derived inventory model');
      LExpectedRow := TJSONObject(LExpected.Objects[J]);
      Require(LRow.AsJSON = LExpectedRow.AsJSON, 'Derived inventory row differs from source pins');
      LExpected.Delete(J);
      Inc(LCount);
    end;
    Require((LCount = FRows.Count) and (LExpected.Count = 0),
      'Derived inventory is missing selected sources');
  finally
    LExpected.Free;
  end;
end;

procedure ImportDerivedKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
var
  LImporter: TDerivedKit;
  LStart: Integer;
begin
  LStart := AInventory.Count;
  LImporter := TDerivedKit.Create(ARoot, AKit, True);
  try
    try
      LImporter.Import(AInventory);
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

procedure VerifyDerivedKit(const ARoot: String; const AKit: TJSONObject;
  const AInventory: TJSONArray);
var
  LVerifier: TDerivedKit;
begin
  LVerifier := TDerivedKit.Create(ARoot, AKit, False);
  try
    LVerifier.Verify(AInventory);
  finally
    LVerifier.Free;
  end;
end;

end.
