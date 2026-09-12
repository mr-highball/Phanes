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

program PhanesTestsDerivedCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  Process,
  {$IFNDEF WINDOWS}BaseUnix,{$ENDIF}
  phanes.tools.files,
  phanes.tools.obj,
  phanes.tools.derived;

const
  FixturePage = 'https://opengameart.org/content/phanes-derived-critic';
  FixtureArchive = 'https://opengameart.org/sites/default/files/phanes-derived-critic.zip';
  FixtureHTML = '<!doctype html><html><head>' +
    '<meta name="dcterms.creator" content="quaternius" /></head><body>' + #13#10 +
    '<div class="field field-name-field-art-licenses field-type-taxonomy">' +
    '<div>License(s): <a href="https://creativecommons.org/publicdomain/zero/1.0/">' +
    'CC0</a></div></div><div class="field field-name-field-art-files field-type-file">' +
    '<a href="' + FixtureArchive + '">Original archive</a></div>' +
    '<p>Synthetic offline fixture.</p></body></html>';
  FixtureNotice = 'Synthetic original fixture notice. CC0 1.0 Universal.'#13#10;
  FixtureMTL = '# Original material bytes'#13#10'newmtl red'#13#10 +
    'Kd 0.125 0.25 0.5'#13#10'Ns 200'#13#10'illum 2'#13#10;
  FixtureAlpha = 'mtllib shared.mtl'#10'o alpha source'#10'usemtl red'#10 +
    'v 0 0 0'#10'v 2 0 0'#10'v 0 2 0'#10'vn 0 0 2'#10'f 1//1 2//1 3//1'#10;
  FixtureBeta = 'mtllib shared.mtl'#10'g beta source'#10'usemtl red'#10 +
    'v 0 0 0'#10'v 2 0 0'#10'v 2 2 1'#10'v 0 2 0'#10 +
    'vn 0 0 2'#10'f 1//1 2//1 3//1 4//1'#10;

type
  TFixture = class
    FRoot: String;
    FKit: TJSONObject;
    FInventory: TJSONArray;
    FAlpha: TBytes;
    FBeta: TBytes;
    FMTL: TBytes;
    FNotice: TBytes;
    FOutputA: TBytes;
    FOutputB: TBytes;
    FExternal: Boolean;
    constructor Create(const AName: String; const AExternal: Boolean = False;
      const AArchiveMode: String = ''; const AHTML: String = FixtureHTML);
    destructor Destroy; override;
    function Published: String;
    procedure Archive(const AMode: String);
    procedure Import;
    procedure Verify;
  end;

var
  GScratch: String;
  GChecks: Integer;
  GFailures: Integer;
  GCases: Integer;
  GCase: String;
  GMessages: TJSONArray;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    Inc(GFailures);
    GMessages.Add(GCase + ': ' + AMessage);
    WriteLn('FAIL ', GCase, ': ', AMessage);
  end;
end;

function Bytes(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
  begin
    Move(AText[1], Result[0], Length(Result));
  end;
end;

function Changed(const AText, AOld, ANew: String): String;
begin
  Result := StringReplace(AText, AOld, ANew, [rfReplaceAll]);
end;

function ModelPin(const AId, AName, APath, ARecipe: String;
  const AOriginal, AMTL, AOutput: TBytes): TJSONObject;
begin
  Result := TJSONObject.Create(['id', AId, 'name', AName, 'path', APath,
    'objSha256', HashBytes(AOriginal), 'objBytes', Length(AOriginal),
    'mtlPath', 'models/shared.mtl', 'mtlSha256', HashBytes(AMTL), 'mtlBytes', Length(AMTL),
    'recipe', ARecipe, 'sha256', HashBytes(AOutput), 'bytes', Length(AOutput)]);
end;

constructor TFixture.Create(const AName: String; const AExternal: Boolean;
  const AArchiveMode, AHTML: String);
var
  LEvidence: TJSONObject;
  LModels: TJSONArray;
begin
  inherited Create;
  Inc(GCases);
  GCase := AName;
  { Keep nested hash-named original paths below native Windows path limits. }
  FRoot := SafeChild(GScratch, Format('%.3d', [GCases]));
  Require(not DirectoryExists(FRoot), 'Fixture directory must be fresh');
  Require(ForceDirectories(FRoot), 'Cannot create fixture');
  FExternal := AExternal;
  FAlpha := Bytes(FixtureAlpha);
  FBeta := Bytes(FixtureBeta);
  FMTL := Bytes(FixtureMTL);
  FNotice := Bytes(FixtureNotice);
  if FExternal then
  begin
    FNotice := Bytes(AHTML);
  end;
  LEvidence := nil;
  try
    FOutputA := ConvertStaticOBJ('alpha.obj', 'shared.mtl', FAlpha, FMTL, LEvidence);
  finally
    LEvidence.Free;
  end;
  LEvidence := nil;
  try
    FOutputB := ConvertSurfaceOBJ('beta.obj', 'shared.mtl', FBeta, FMTL, LEvidence);
  finally
    LEvidence.Free;
  end;
  LModels := TJSONArray.Create;
  LModels.Add(ModelPin('alpha', 'Alpha fixture', 'models/alpha.obj',
    'phanes.obj.matte.v1', FAlpha, FMTL, FOutputA));
  LModels.Add(ModelPin('beta', 'Beta fixture', 'models/beta.obj',
    'phanes.obj.surface.v1', FBeta, FMTL, FOutputB));
  FKit := TJSONObject.Create(['id', 'critic-derived', 'sourceMode', 'derived.obj.v1',
    'storage', 'library', 'license', 'CC0-1.0', 'page', FixturePage,
    'archiveUrl', FixtureArchive, 'archiveSha256', StringOfChar('0', 64),
    'author', 'Quaternius', 'theme', 'synthetic', 'licenseSha256', HashBytes(FNotice),
    'licenseBytes', Length(FNotice), 'models', LModels]);
  if FExternal then
  begin
    FKit.Add('licenseEvidence', TJSONObject.Create(['mode', 'oga-submission.v1',
      'url', FixturePage, 'sha256', HashBytes(FNotice), 'bytes', Length(FNotice)]));
    WriteBytes(SafeChild(FRoot, 'build/asset-research/derived/' + HashBytes(FNotice) + '.html'),
      FNotice);
  end else
  begin
    FKit.Add('licensePath', 'source/License.txt');
  end;
  FInventory := TJSONArray.Create;
  FInventory.Add(TJSONObject.Create(['id', 'untouched/keep', 'kit', 'untouched',
    'sentinel', 'outside derived selection']));
  Archive(AArchiveMode);
end;

destructor TFixture.Destroy;
begin
  FInventory.Free;
  FKit.Free;
  inherited Destroy;
end;

function TFixture.Published: String;
begin
  Result := SafeChild(FRoot, 'assets/library/kits/' + FKit.Strings['id']);
end;

procedure TFixture.Archive(const AMode: String);
var
  LZip: TZipper;
  LStreams: TList;
  LStream: TMemoryStream;
  LPath: String;
  LHash: String;
  I: Integer;

  procedure Add(const APath: String; const ABytes: TBytes);
  begin
    LStream := TMemoryStream.Create;
    LStreams.Add(LStream);
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
    LStream.Position := 0;
    LZip.Entries.AddFileEntry(LStream, APath);
  end;

begin
  LPath := SafeChild(FRoot, 'archive-fixture.zip');
  LZip := TZipper.Create;
  LStreams := TList.Create;
  try
    LZip.FileName := LPath;
    if AMode = 'wrong-case' then
    begin
      Add('models/Alpha.obj', FAlpha);
    end else
    begin
      Add('models/alpha.obj', FAlpha);
    end;
    if AMode <> 'missing-beta' then
    begin
      Add('models/beta.obj', FBeta);
    end;
    Add('models/shared.mtl', FMTL);
    if AMode = 'duplicate-alpha' then
    begin
      Add('models/alpha.obj', FAlpha);
    end;
    if AMode = 'case-alias-alpha' then
    begin
      Add('models/ALPHA.obj', FAlpha);
    end;
    if not FExternal and (AMode <> 'missing-notice') then
    begin
      Add('source/License.txt', FNotice);
    end;
    if AMode = 'conflicting-notice' then
    begin
      Add('unselected/deep/License_Standard.txt', Bytes('Original conflicting CC0 notice'));
    end;
    if AMode = 'licence-conflict' then
    begin
      Add('unselected/Licence.md', Bytes('Original conflicting CC0 notice'));
    end;
    Add('unselected/readme.txt', Bytes('Unused original archive member must not be published.'));
    LZip.ZipAllFiles;
  finally
    for I := 0 to LStreams.Count - 1 do
    begin
      TObject(LStreams[I]).Free;
    end;
    LStreams.Free;
    LZip.Free;
  end;
  LHash := HashFile(LPath);
  FKit.Strings['archiveSha256'] := LHash;
  CopyFileBytes(LPath, SafeChild(FRoot, 'build/asset-research/derived/' + LHash + '.zip'));
end;

procedure TFixture.Import;
begin
  ImportDerivedKit(FRoot, FKit, FInventory);
end;

procedure TFixture.Verify;
begin
  VerifyDerivedKit(FRoot, FKit, FInventory);
end;

function FilesFingerprint(const ADirectory: String): String;
var
  LFiles: TStringList;
  LText: String;

  procedure Walk(const APath, APrefix: String);
  var
    LEntry: TSearchRec;
    LRelative: String;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, LEntry) <> 0 then
    begin
      Exit;
    end;
    try
      repeat
        if (LEntry.Name = '.') or (LEntry.Name = '..') then
        begin
          Continue;
        end;
        Require((LEntry.Attr and faSymLink) = 0, 'Fingerprint does not follow fixture links');
        LRelative := APrefix + LEntry.Name;
        if (LEntry.Attr and faDirectory) <> 0 then
        begin
          Walk(SafeChild(APath, LEntry.Name), LRelative + '/');
        end else
        begin
          LFiles.Add(LRelative + ':' + HashFile(SafeChild(APath, LEntry.Name)));
        end;
      until FindNext(LEntry) <> 0;
    finally
      FindClose(LEntry);
    end;
  end;

begin
  LFiles := TStringList.Create;
  LFiles.Sorted := True;
  LFiles.UseLocale := False;
  LFiles.CaseSensitive := True;
  try
    if DirectoryExists(ADirectory) then
    begin
      Walk(ADirectory, '');
    end;
    LText := LFiles.Text;
    Result := HashBytes(Bytes(LText));
  finally
    LFiles.Free;
  end;
end;

procedure Rejected(const AFixture: TFixture; const AOperation: String;
  const AAbsent: Boolean = True);
var
  LBefore: String;
  LRejected: Boolean;
  LReason: String;
begin
  LBefore := AFixture.FInventory.AsJSON;
  LRejected := False;
  LReason := '';
  try
    if AOperation = 'check' then
    begin
      CheckDerivedKit(AFixture.FKit);
    end else if AOperation = 'verify' then
    begin
      AFixture.Verify;
    end else
    begin
      AFixture.Import;
    end;
  except
    on LException: Exception do
    begin
      LRejected := True;
      LReason := LException.Message;
      Check(not (LException is EAccessViolation), 'Rejection must be a validation exception');
    end;
  end;
  Check(LRejected, AOperation + ' rejects malformed/conflicting fixture: ' + LReason);
  Check(AFixture.FInventory.AsJSON = LBefore, 'Rejected operation preserves all inventory rows');
  if AAbsent then
  begin
    Check(not DirectoryExists(AFixture.Published), 'Rejected import publishes no kit directory');
  end;
end;

procedure Positive(const AExternal: Boolean);
var
  LFixture: TFixture;
  LInventory: TJSONArray;
  LPin: TJSONObject;
  LRow: TJSONObject;
  LEvidence: TJSONObject;
  LBefore: String;
  LName: String;
  I: Integer;
begin
  LName := 'bundled-positive';
  if AExternal then
  begin
    LName := 'creator-positive';
  end;
  LFixture := TFixture.Create(LName, AExternal);
  LInventory := nil;
  try
    CheckDerivedKit(LFixture.FKit);
    LFixture.Import;
    Check(LFixture.FInventory.Count = 3, 'Exactly two derived inventory rows appended');
    Check(LFixture.FInventory.Objects[0].Strings['sentinel'] = 'outside derived selection',
      'Unrelated inventory row retained');
    Check(DirectoryExists(LFixture.Published), 'Complete immutable kit published');
    for I := 0 to 1 do
    begin
      LPin := LFixture.FKit.Arrays['models'].Objects[I];
      LRow := LFixture.FInventory.Objects[I + 1];
      Check(LRow.Strings['id'] = 'critic-derived/' + LPin.Strings['id'], 'Explicit output ID');
      Check(LRow.Strings['sha256'] = LPin.Strings['sha256'], 'Derived output SHA separate');
      Check(LRow.Strings['sourceSha256'] = LPin.Strings['objSha256'], 'Original OBJ pin retained');
      Check(LRow.Strings['sourceArchiveSha256'] = LFixture.FKit.Strings['archiveSha256'],
        'Original archive pin retained');
      Check(LRow.Strings['materialSha256'] = HashBytes(LFixture.FMTL), 'Original MTL pin retained');
      Check(LRow.Strings['sourceMember'] = LPin.Strings['path'],
        'Exact original OBJ member retained');
      Check(LRow.Strings['materialMember'] = 'models/shared.mtl',
        'Exact original MTL member retained');
      Check(LRow.Strings['sourceMode'] = 'derived.obj.v1', 'Source/derivation mode distinct');
      Check(LRow.Strings['derivationRecipe'] = LPin.Strings['recipe'], 'Exact recipe retained');
      Check(not LRow.Booleans['animationPreserved'], 'No claimed animation preservation');
      Check(LRow.Strings['review'] = 'inventory-only', 'No implicit runtime admission');
      Check(LRow.Strings['storage'] = 'library', 'Optional library storage');
      Check(LRow.Arrays['dependencies'].Count = 0, 'No inferred external dependencies');
      Check(HashFile(SafeChild(LFixture.Published, LPin.Strings['id'] + '.glb')) =
        LPin.Strings['sha256'], 'Output bytes match exact explicit pin');
      Check(HashFile(SafeChild(LFixture.Published,
        'Original/' + LPin.Strings['objSha256'] + '.obj')) = LPin.Strings['objSha256'],
        'Unmodified original OBJ retained');
      LEvidence := LoadJSON(SafeChild(LFixture.Published,
        'Provenance/' + LPin.Strings['id'] + '.json'));
      try
        Check(LEvidence.Strings['objSha256'] = LPin.Strings['objSha256'],
          'Per-model provenance OBJ');
        Check(LEvidence.Strings['mtlSha256'] = HashBytes(LFixture.FMTL),
          'Per-model provenance MTL');
        Check(LEvidence.Strings['outputSha256'] = LPin.Strings['sha256'],
          'Per-model provenance output');
      finally
        LEvidence.Free;
      end;
    end;
    Check(HashFile(SafeChild(LFixture.Published, 'Original/' + HashBytes(LFixture.FMTL) + '.mtl')) =
      HashBytes(LFixture.FMTL), 'Shared original MTL retains CRLF bytes');
    LName := 'License.txt';
    if AExternal then
    begin
      LName := 'SourceLicense.html';
      Check(LFixture.FInventory.Objects[1].Objects['licenseEvidence'].AsJSON =
        LFixture.FKit.Objects['licenseEvidence'].AsJSON, 'Explicit creator evidence retained');
      Check(LFixture.FInventory.Objects[1].Strings['licenseFile'] = LName, 'Creator notice origin');
    end;
    Check(HashFile(SafeChild(LFixture.Published, LName)) = HashBytes(LFixture.FNotice),
      'Original notice bytes retained');
    Check(not FileExists(SafeChild(LFixture.Published, 'readme.txt')),
      'Unselected archive text omitted');
    LBefore := FilesFingerprint(LFixture.Published);
    LFixture.Verify;
    Check(FilesFingerprint(LFixture.Published) = LBefore, 'Regeneration verification is read-only');
    LInventory := TJSONArray.Create;
    LInventory.Add(LFixture.FInventory[0].Clone);
    ImportDerivedKit(LFixture.FRoot, LFixture.FKit, LInventory);
    Check(LInventory.AsJSON = LFixture.FInventory.AsJSON,
      'Immutable reimport reproduces exact rows');
    Check(FilesFingerprint(LFixture.Published) = LBefore,
      'Immutable reimport preserves exact bytes');
  finally
    LInventory.Free;
    LFixture.Free;
  end;
end;

procedure LockCases;
var
  LFixture: TFixture;
  LPin: TJSONObject;
  I: Integer;
begin
  for I := 0 to 21 do
  begin
    LFixture := TFixture.Create('invalid-lock-' + IntToStr(I));
    try
      LPin := LFixture.FKit.Arrays['models'].Objects[0];
      case I of
        0: LFixture.FKit.Strings['sourceMode'] := 'derived.obj.v2';
        1: LFixture.FKit.Strings['storage'] := 'core';
        2: LFixture.FKit.Strings['license'] := 'CC-BY-4.0';
        3: LFixture.FKit.Strings['id'] := '../escape';
        4: LPin.Strings['id'] := 'Alpha';
        5: LFixture.FKit.Arrays['models'].Objects[1].Strings['id'] := 'alpha';
        6: LFixture.FKit.Arrays['models'].Objects[1].Strings['path'] := 'models/alpha.obj';
        7: LPin.Strings['path'] := 'models/../alpha.obj';
        8: LPin.Strings['path'] := 'models\alpha.obj';
        9: LPin.Strings['mtlPath'] := 'other/shared.mtl';
        10: LPin.Strings['recipe'] := 'phanes.obj.unreviewed.v1';
        11: LFixture.FKit.Strings['archiveUrl'] := 'http://example.invalid/archive.zip';
        12: LPin.Strings['sha256'] := StringOfChar('G', 64);
        13:
          begin
            LPin.Delete('bytes');
            LPin.Add('bytes', 100.0);
          end;
        14:
          begin
            LPin.Delete('objBytes');
            LPin.Add('objBytes', '123');
          end;
        15: LPin.Int64s['mtlBytes'] := 0;
        16: LPin.Int64s['bytes'] := 32 * 1024 * 1024 + 1;
        17: LFixture.FKit.Add('dependencyAliases', TJSONArray.Create);
        18: LFixture.FKit.Add('sources', TJSONArray.Create);
        19: LFixture.FKit.Arrays['models'].Add(TJSONNull.Create);
        20:
          begin
            LFixture.FKit.Delete('licenseBytes');
            LFixture.FKit.Add('licenseBytes', False);
          end;
        21: LFixture.FKit.Strings['licensePath'] := 'models/alpha.obj';
      end;
      Rejected(LFixture, 'check');
    finally
      LFixture.Free;
    end;
  end;
end;

procedure ImportFailures;
const
  Modes: array[0..4] of String = ('wrong-case', 'missing-beta', 'duplicate-alpha',
    'case-alias-alpha', 'missing-notice');
var
  LFixture: TFixture;
  LPin: TJSONObject;
  LPath: String;
  LValue: TBytes;
  I: Integer;
begin
  for I := 0 to High(Modes) do
  begin
    LFixture := TFixture.Create('archive-' + Modes[I], False, Modes[I]);
    try
      Rejected(LFixture, 'import');
    finally
      LFixture.Free;
    end;
  end;
  for I := 0 to 5 do
  begin
    LFixture := TFixture.Create('pin-mismatch-' + IntToStr(I));
    try
      LPin := LFixture.FKit.Arrays['models'].Objects[1];
      case I of
        0: LPin.Strings['sha256'] := StringOfChar('0', 64);
        1: LPin.Strings['objSha256'] := StringOfChar('0', 64);
        2: LPin.Strings['mtlSha256'] := StringOfChar('0', 64);
        3: LPin.Int64s['objBytes'] := LPin.Int64s['objBytes'] + 1;
        4: LPin.Strings['recipe'] := 'phanes.obj.matte.v1';
        5:
          begin
            LPath := SafeChild(LFixture.FRoot, 'build/asset-research/derived/' +
              LFixture.FKit.Strings['archiveSha256'] + '.zip');
            LValue := ReadBytes(LPath);
            LValue[High(LValue)] := LValue[High(LValue)] xor 1;
            WriteBytes(LPath, LValue);
          end;
      end;
      Rejected(LFixture, 'import');
    finally
      LFixture.Free;
    end;
  end;
end;

procedure PublishedFailures;
var
  LFixture: TFixture;
  LPin: TJSONObject;
  LPath: String;
  LRelative: String;
  LOld: TBytes;
  LValue: TBytes;
  LBefore: String;
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    LFixture := TFixture.Create('published-tamper-' + IntToStr(I));
    try
      LFixture.Import;
      LPin := LFixture.FKit.Arrays['models'].Objects[0];
      case I of
        0: LRelative := 'alpha.glb';
        1: LRelative := 'Original/' + LPin.Strings['objSha256'] + '.obj';
        2: LRelative := 'Original/' + LPin.Strings['mtlSha256'] + '.mtl';
        3: LRelative := 'Provenance/alpha.json';
        4: LRelative := 'KitProvenance.json';
        5: LRelative := 'License.txt';
        6: LRelative := 'unlisted.txt';
      end;
      LPath := SafeChild(LFixture.Published, LRelative);
      if I = 6 then
      begin
        WriteBytes(LPath, Bytes('unlisted source'));
      end else
      begin
        LOld := ReadBytes(LPath);
        LValue := Copy(LOld, 0, Length(LOld));
        LValue[High(LValue)] := LValue[High(LValue)] xor 1;
        WriteBytes(LPath, LValue);
      end;
      LBefore := FilesFingerprint(LFixture.Published);
      Rejected(LFixture, 'verify', False);
      Rejected(LFixture, 'import', False);
      Check(FilesFingerprint(LFixture.Published) = LBefore,
        'Rejected existing destination is never overwritten/repaired');
    finally
      LFixture.Free;
    end;
  end;
  for I := 0 to 5 do
  begin
    LFixture := TFixture.Create('published-lock-change-' + IntToStr(I));
    try
      LFixture.Import;
      LBefore := FilesFingerprint(LFixture.Published);
      case I of
        0: LFixture.FKit.Strings['author'] := 'Changed author';
        1: LFixture.FKit.Arrays['models'].Objects[0].Strings['name'] := 'Changed display name';
        2: LFixture.FKit.Strings['page'] := 'https://example.invalid/changed-origin';
        3: LFixture.FKit.Arrays['models'].Objects[0].Strings['id'] := 'new-id';
        4: LFixture.FKit.Arrays['models'].Exchange(0, 1);
        5: LFixture.FKit.Add('unreviewedMetadata', 'changed immutable lock');
      end;
      Rejected(LFixture, 'verify', False);
      Rejected(LFixture, 'import', False);
      Check(FilesFingerprint(LFixture.Published) = LBefore, 'Immutable snapshot bytes retained');
    finally
      LFixture.Free;
    end;
  end;
end;

procedure InventoryFailures;
var
  LFixture: TFixture;
  LRow: TJSONObject;
  I: Integer;
begin
  for I := 0 to 11 do
  begin
    LFixture := TFixture.Create('inventory-tamper-' + IntToStr(I));
    try
      LFixture.Import;
      LRow := LFixture.FInventory.Objects[1];
      case I of
        0: LRow.Strings['sourceSha256'] := StringOfChar('0', 64);
        1: LRow.Strings['sourceArchiveSha256'] := StringOfChar('0', 64);
        2: LRow.Strings['sourceMember'] := 'models/elsewhere.obj';
        3: LRow.Strings['materialMember'] := 'models/elsewhere.mtl';
        4: LRow.Strings['derivationRecipe'] := 'phanes.obj.surface.v1';
        5: LRow.Booleans['animationPreserved'] := True;
        6: LFixture.FInventory.Add(LRow.Clone);
        7: LFixture.FInventory.Delete(1);
        8: LRow.Strings['storage'] := 'core';
        9: LRow.Add('inventedField', 7);
        10: LFixture.FInventory.Add(TJSONNull.Create);
        11: LFixture.FInventory.Add(TJSONString.Create('not an inventory record'));
      end;
      Rejected(LFixture, 'verify', False);
    finally
      LFixture.Free;
    end;
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
    'Link and target must remain within fresh scratch');
  Require(not DirectoryExists(ALink) and not FileExists(ALink), 'Link location must be fresh');
  {$IFDEF WINDOWS}
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
    Require(LProcess.ExitStatus = 0, 'Cannot create junction fixture');
  finally
    LProcess.Free;
  end;
  {$ELSE}
  Require(fpSymlink(PChar(ATarget), PChar(ALink)) = 0, 'Cannot create symlink fixture');
  {$ENDIF}
  Require(DirectoryExists(ALink), 'Fixture link must resolve');
end;

procedure RelocateFixture(const ASource, ATarget: String);
begin
  Require((Pos(IncludeTrailingPathDelimiter(GScratch), ExpandFileName(ASource)) = 1) and
    (Pos(IncludeTrailingPathDelimiter(GScratch), ExpandFileName(ATarget)) = 1),
    'Rename source/target must remain within fresh scratch');
  Require(not DirectoryExists(ATarget) and not FileExists(ATarget), 'Rename target must be fresh');
  Require(RenameFile(ASource, ATarget), 'Cannot rename owned fixture for adversarial check');
end;

procedure LinkAndClosureCases;
var
  LFixture: TFixture;
  LPath: String;
  LTarget: String;
  LBefore: String;
  LRejected: Boolean;
  I: Integer;
begin
  for I := 0 to 4 do
  begin
    LFixture := TFixture.Create('filesystem-link-' + IntToStr(I));
    try
      LTarget := SafeChild(LFixture.FRoot, 'target');
      if I <= 2 then
      begin
        Require(ForceDirectories(LTarget), 'Cannot create isolated link target');
      end;
      case I of
        0:
          begin
            LPath := SafeChild(LFixture.FRoot, 'linked-root');
            DirectoryLink(LPath, LFixture.FRoot);
            LBefore := LFixture.FInventory.AsJSON;
            LRejected := False;
            try
              ImportDerivedKit(LPath, LFixture.FKit, LFixture.FInventory);
            except
              on LException: Exception do
              begin
                LRejected := True;
                Check(not (LException is EAccessViolation), 'Linked root rejects cleanly');
              end;
            end;
            Check(LRejected, 'Importer rejects linked root before publication');
            Check(LBefore = LFixture.FInventory.AsJSON, 'Linked root leaves inventory unchanged');
            Check(not DirectoryExists(LFixture.Published), 'Linked root publishes nothing');
          end;
        1:
          begin
            DirectoryLink(SafeChild(LFixture.FRoot, 'assets'), LTarget);
            Rejected(LFixture, 'import');
          end;
        2:
          begin
            DirectoryLink(SafeChild(LFixture.FRoot, 'build/asset-staging'), LTarget);
            Rejected(LFixture, 'import');
          end;
        3:
          begin
            LFixture.Import;
            LPath := SafeChild(LFixture.Published, 'Original');
            RelocateFixture(LPath, LTarget);
            DirectoryLink(LPath, LTarget);
            Rejected(LFixture, 'verify', False);
          end;
        4:
          begin
            LFixture.Import;
            LPath := LFixture.Published;
            RelocateFixture(LPath, LTarget);
            DirectoryLink(LPath, LTarget);
            Rejected(LFixture, 'verify', False);
          end;
      end;
    finally
      LFixture.Free;
    end;
  end;
  for I := 0 to 2 do
  begin
    LFixture := TFixture.Create('closure-case-' + IntToStr(I));
    try
      LFixture.Import;
      case I of
        0:
          begin
            LPath := SafeChild(LFixture.Published, 'alpha.glb');
            LTarget := SafeChild(LFixture.FRoot, 'temporary-case.glb');
            RelocateFixture(LPath, LTarget);
            RelocateFixture(LTarget, SafeChild(LFixture.Published, 'ALPHA.glb'));
          end;
        1:
          begin
            RelocateFixture(SafeChild(LFixture.Published, 'beta.glb'),
              SafeChild(LFixture.FRoot, 'removed-beta.glb'));
          end;
        2: Require(ForceDirectories(SafeChild(LFixture.Published, 'ExtraDirectory')),
          'Cannot create extra unadmitted directory');
      end;
      Rejected(LFixture, 'verify', False);
      Rejected(LFixture, 'import', False);
    finally
      LFixture.Free;
    end;
  end;
end;

procedure CreatorFailures;
var
  LFixture: TFixture;
  LHTML: String;
  LMode: String;
  LPath: String;
  I: Integer;
begin
  for I := 0 to 10 do
  begin
    LHTML := FixtureHTML;
    LMode := '';
    case I of
      0: LHTML := Changed(LHTML, 'content="quaternius"', 'content="different-author"');
      1: LHTML := Changed(LHTML, 'href="' + FixtureArchive,
        'href="https://example.invalid/wrong.zip');
      2: LHTML := Changed(LHTML, 'field-name-field-art-licenses', 'unrelated-widget');
      3: LHTML := Changed(LHTML, 'publicdomain/zero/1.0/', 'licenses/by/4.0/');
      4: LMode := 'conflicting-notice';
      5: LMode := 'licence-conflict';
    end;
    LFixture := TFixture.Create('creator-refusal-' + IntToStr(I), True, LMode, LHTML);
    try
      case I of
        6: LFixture.FKit.Add('licensePath', 'source/License.txt');
        7: LFixture.FKit.Objects['licenseEvidence'].Strings['sha256'] := StringOfChar('0', 64);
        8: LFixture.FKit.Objects['licenseEvidence'].Strings['url'] :=
          'https://example.invalid/wrong';
        9: LFixture.FKit.Objects['licenseEvidence'].Int64s['bytes'] := Length(LFixture.FNotice) + 1;
        10:
          begin
            LPath := SafeChild(LFixture.FRoot, 'build/asset-research/derived/' +
              LFixture.FKit.Strings['licenseSha256'] + '.html');
            WriteBytes(LPath, Bytes('not the pinned creator evidence'));
          end;
      end;
      Rejected(LFixture, 'import');
    finally
      LFixture.Free;
    end;
  end;
  LFixture := TFixture.Create('creator-published-notice-tamper', True);
  try
    LFixture.Import;
    WriteBytes(SafeChild(LFixture.Published, 'SourceLicense.html'), Bytes('CC0 unrelated page'));
    Rejected(LFixture, 'verify', False);
  finally
    LFixture.Free;
  end;
end;

procedure Run;
var
  LRoot: String;
  LGuid: TGUID;
  LReport: TJSONObject;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root [scratch root]');
  LRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(LRoot, 'build/tests/derived-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fixture ID');
  GScratch := SafeChild(GScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Scratch directory must be fresh');
  Require(ForceDirectories(GScratch), 'Cannot create scratch directory');
  GMessages := TJSONArray.Create;
  LReport := nil;
  try
    Positive(False);
    Positive(True);
    LockCases;
    ImportFailures;
    PublishedFailures;
    InventoryFailures;
    LinkAndClosureCases;
    CreatorFailures;
    LReport := TJSONObject.Create(['checks', GChecks, 'failures', GFailures,
      'fixtures', GCases, 'scratch', GScratch, 'networkRequired', False]);
    LReport.Add('messages', GMessages);
    GMessages := nil;
    WriteTextAtomic(SafeChild(GScratch, 'evidence.json'), LReport.FormatJSON);
    WriteLn(GChecks, ' checks, ', GFailures, ' failures, ', GCases, ' fixtures');
    WriteLn('Evidence: ', SafeChild(GScratch, 'evidence.json'));
  finally
    LReport.Free;
    GMessages.Free;
  end;
end;

begin
  Run;
  if GFailures <> 0 then
  begin
    Halt(1);
  end;
end.
