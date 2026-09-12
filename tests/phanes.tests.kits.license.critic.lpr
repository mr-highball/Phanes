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

program PhanesTestsKitsLicenseCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  phanes.tools.files,
  phanes.tools.kits,
  phanes.tools.catalog;

const
  FixturePage = 'https://opengameart.org/content/phanes-synthetic-critic-fixture';
  FixtureArchive = 'https://opengameart.org/sites/default/files/critic-fixture.zip';
  CreatorTag = '<meta name="dcterms.creator" content="quaternius" />';
  LicenseStart = '<div class="field field-name-field-art-licenses field-type-taxonomy">';
  LicenseLink = '<a href=''https://creativecommons.org/publicdomain/zero/1.0/''>CC0</a>';
  FilesStart = '<div class="field field-name-field-art-files field-type-file">';
  ArchiveLink = '<a href="' + FixtureArchive + '">Original archive</a>';
  FixtureHTML = '<!doctype html><html><head>' + CreatorTag + '</head><body>' + #13#10 +
    LicenseStart + '<div>License(s): ' + LicenseLink + '</div></div>' + #13#10 +
    FilesStart + ArchiveLink + '</div><p>Synthetic offline fixture.</p></body></html>';

type
  TPackageProbe = class
  public
    FCount: Integer;
    procedure CreateStream(ASender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
  end;

var
  GRoot: String;
  GFixtureRoot: String;
  GModel: TBytes;
  GChecks: Integer;
  GFailures: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    Inc(GFailures);
    WriteLn('FAIL ', AMessage);
  end;
end;

function TextBytes(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

function Replace(const AText, AOld, ANew: String): String;
begin
  Result := StringReplace(AText, AOld, ANew, [rfReplaceAll]);
end;

function RunImportCase(const AName, AHTML: String; const AExpected: Boolean;
  const AMode: String = ''): String;
var
  LArchive: String;
  LBefore: UTF8String;
  LZip: TZipper;
  LStreams: TList;
  LStream: TMemoryStream;
  LLock: TJSONObject;
  LKit: TJSONObject;
  LEvidence: TJSONObject;
  LInventory: TJSONObject;
  LAsset: TJSONObject;
  LAccepted: Boolean;
  LError: String;
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
  Result := SafeChild(GFixtureRoot, AName);
  Require(not DirectoryExists(Result), 'Fixture root must be fresh');
  LArchive := SafeChild(Result, 'build/asset-research/probe.zip');
  ForceDirectories(ExtractFileDir(LArchive));
  LBefore := '{"version":2,"assets":[],"marker":"keep previous inventory"}' + #10;
  WriteText(SafeChild(Result, 'data/asset-inventory.json'), LBefore);
  LZip := TZipper.Create;
  LStreams := TList.Create;
  try
    LZip.FileName := LArchive;
    Add('Models/a.glb', GModel);
    if AMode = 'bundled-inside' then
    begin
      Add('Models/License.txt', TextBytes('CC0 bundled notice'));
    end;
    if AMode = 'bundled-outside' then
    begin
      Add('Elsewhere/lIcEnSe.MD', TextBytes('A conflicting bundled notice'));
    end;
    if AMode = 'collision' then
    begin
      Add('Models/sourcelicense.HTML', TextBytes('An original archive file'));
    end;
    LZip.ZipAllFiles;
  finally
    LZip.Free;
    for I := 0 to LStreams.Count - 1 do
    begin
      TObject(LStreams[I]).Free;
    end;
    LStreams.Free;
  end;
  { Both network inputs exist at the real importer's cache paths. Even the
    mismatch case must reject cached bytes, never contact this synthetic URL. }
  WriteText(SafeChild(Result, 'build/asset-research/probe-license.html'), UTF8String(AHTML));
  LLock := TJSONObject.Create(['version', 1]);
  try
    LLock.Add('kits', TJSONArray.Create);
    LKit := TJSONObject.Create(['id', 'probe', 'storage', 'library', 'theme', 'nature',
      'license', 'CC0-1.0', 'author', 'Quaternius', 'page', FixturePage,
      'archiveUrl', FixtureArchive, 'archiveSha256', HashFile(LArchive),
      'modelPrefix', 'Models/']);
    LLock.Arrays['kits'].Add(LKit);
    if AMode <> 'omitted' then
    begin
      LEvidence := TJSONObject.Create(['mode', 'oga-submission.v1', 'url', FixturePage,
        'sha256', HashFile(SafeChild(Result, 'build/asset-research/probe-license.html'))]);
      LKit.Add('licenseEvidence', LEvidence);
      if AMode = 'hash-mismatch' then
      begin
        LEvidence.Strings['sha256'] := StringOfChar('0', 64);
      end;
      if AMode = 'both-fields' then
      begin
        LKit.Add('licensePath', 'License.txt');
      end;
      if AMode = 'wrong-mode' then
      begin
        LEvidence.Strings['mode'] := 'unreviewed-source.v1';
      end;
      if AMode = 'wrong-page' then
      begin
        LEvidence.Strings['url'] := FixturePage + '-other';
      end;
      if AMode = 'http' then
      begin
        LEvidence.Strings['url'] := Replace(FixturePage, 'https:', 'http:');
      end;
    end;
    WriteText(SafeChild(Result, 'data/kits.lock.json'), LLock.AsJSON);
  finally
    LLock.Free;
  end;
  LAccepted := False;
  LError := '';
  try
    ImportKits(Result);
    LAccepted := True;
  except
    on LException: Exception do
    begin
      LError := LException.Message;
    end;
  end;
  WriteLn('CASE ', AName, ' accepted=', LAccepted, ' expected=', AExpected, ' ', LError);
  Check(LAccepted = AExpected, AName + ': admission result');
  if not AExpected then
  begin
    Check(ReadText(SafeChild(Result, 'data/asset-inventory.json')) = LBefore,
      AName + ': old inventory preservation');
    Check(not DirectoryExists(SafeChild(Result, 'assets/library/kits/probe')),
      AName + ': rejection must not publish kit');
  end
  else if LAccepted then
  begin
    LInventory := LoadJSON(SafeChild(Result, 'data/asset-inventory.json'));
    try
      Check(LInventory.Arrays['assets'].Count = 1, AName + ': model count');
      LAsset := LInventory.Arrays['assets'].Objects[0];
      Check(LAsset.Strings['id'] = 'probe/a', AName + ': original model identity');
      Check(LAsset.Strings['sha256'] = HashBytes(GModel), AName + ': source model hash');
      Check(HashFile(SafeChild(Result, 'assets/library/kits/probe/a.glb')) = HashBytes(GModel),
        AName + ': published model bytes');
      Check(LAsset.Strings['licenseFile'] = 'SourceLicense.html', AName + ': explicit filename');
      Check(LAsset.Strings['licenseSha256'] = HashBytes(TextBytes(UTF8String(AHTML))),
        AName + ': original evidence hash');
      Check(ReadText(SafeChild(Result, 'assets/library/kits/probe/SourceLicense.html')) =
        UTF8String(AHTML), AName + ': exact HTML bytes including line endings');
      Check(not FileExists(SafeChild(Result, 'assets/library/kits/probe/License.txt')),
        AName + ': no invented archive notice');
      Check(LAsset.Strings['source'] = FixturePage, AName + ': source association');
      Check(LAsset.Objects['licenseEvidence'].Strings['mode'] = 'oga-submission.v1',
        AName + ': evidence recipe');
      Check(LAsset.Objects['licenseEvidence'].Strings['url'] = FixturePage,
        AName + ': evidence origin');
      Check(LAsset.Objects['licenseEvidence'].Strings['sha256'] = LAsset.Strings['licenseSha256'],
        AName + ': evidence binding');
    finally
      LInventory.Free;
    end;
  end;
end;

procedure PreparePalette(const ARoot: String);
const
  CKinds: array[0..8] of String = ('cabin', 'castle', 'modern', 'scifi',
    'tree', 'shrub', 'flowers', 'crop', 'rock');
var
  LPalette: TJSONObject;
  I: Integer;
begin
  LPalette := TJSONObject.Create;
  try
    LPalette.Add('assets', TJSONArray.Create);
    { Reach the existing palette join without asserting physical role admission. }
    for I := 0 to High(CKinds) do
    begin
      LPalette.Arrays['assets'].Add(TJSONObject.Create([
        'id', 'probe/a', 'kind', CKinds[I], 'width', 1]));
    end;
    WriteText(SafeChild(ARoot, 'data/palette.json'), LPalette.AsJSON);
  finally
    LPalette.Free;
  end;
end;

procedure VerifyMutation(const ARoot, AMode: String);
var
  LBefore: UTF8String;
  LLockBefore: UTF8String;
  LHTMLBefore: UTF8String;
  LSubmitted: UTF8String;
  LDocument: TJSONObject;
  LEntry: TJSONObject;
  LRejected: Boolean;
  LError: String;
begin
  LBefore := ReadText(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLockBefore := ReadText(SafeChild(ARoot, 'data/kits.lock.json'));
  LHTMLBefore := ReadText(SafeChild(ARoot, 'assets/library/kits/probe/SourceLicense.html'));
  if AMode = 'changed-snapshot' then
  begin
    WriteText(SafeChild(ARoot, 'assets/library/kits/probe/SourceLicense.html'), LHTMLBefore + ' ');
  end
  else
  begin
    LDocument := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
    try
      LEntry := LDocument.Arrays['assets'].Objects[0];
      if AMode = 'omitted-evidence' then
      begin
        LEntry.Delete('licenseEvidence');
      end;
      if AMode = 'changed-origin' then
      begin
        LEntry.Objects['licenseEvidence'].Strings['url'] := FixturePage + '-other';
      end;
      if AMode = 'changed-file' then
      begin
        WriteText(SafeChild(ARoot, 'assets/library/kits/probe/Other.html'), LHTMLBefore);
        LEntry.Strings['licenseFile'] := 'Other.html';
      end;
      if AMode = 'changed-source' then
      begin
        LEntry.Strings['source'] := FixturePage + '-other';
      end;
      WriteText(SafeChild(ARoot, 'data/asset-inventory.json'), LDocument.AsJSON);
    finally
      LDocument.Free;
    end;
  end;
  LRejected := False;
  LError := '';
  LSubmitted := ReadText(SafeChild(ARoot, 'data/asset-inventory.json'));
  try
    try
      VerifyKits(ARoot);
    except
      on LException: Exception do
      begin
        LRejected := True;
        LError := LException.Message;
      end;
    end;
    Check(LRejected, 'Verifier ' + AMode + ': must reject');
    Check(ReadText(SafeChild(ARoot, 'data/kits.lock.json')) = LLockBefore,
      'Verifier ' + AMode + ': must preserve lock');
    Check(ReadText(SafeChild(ARoot, 'data/asset-inventory.json')) = LSubmitted,
      'Verifier ' + AMode + ': must not rewrite rejected inventory');
  finally
    WriteText(SafeChild(ARoot, 'data/asset-inventory.json'), LBefore);
    WriteText(SafeChild(ARoot, 'assets/library/kits/probe/SourceLicense.html'), LHTMLBefore);
  end;
  WriteLn('VERIFY ', AMode, ' rejected=', LRejected, ' ', LError);
end;

procedure CheckFailedReimport(const ARoot: String);
var
  LLockBefore: UTF8String;
  LBefore: UTF8String;
  LBadHTML: UTF8String;
  LLock: TJSONObject;
  LRejected: Boolean;
begin
  LLockBefore := ReadText(SafeChild(ARoot, 'data/kits.lock.json'));
  LBefore := ReadText(SafeChild(ARoot, 'data/asset-inventory.json'));
  LBadHTML := UTF8String(Replace(FixtureHTML, 'content="quaternius"', 'content="other"'));
  WriteText(SafeChild(ARoot, 'build/asset-research/probe-license.html'), LBadHTML);
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  try
    LLock.Arrays['kits'].Objects[0].Objects['licenseEvidence'].Strings['sha256'] :=
      HashBytes(TextBytes(LBadHTML));
    WriteText(SafeChild(ARoot, 'data/kits.lock.json'), LLock.AsJSON);
  finally
    LLock.Free;
  end;
  LRejected := False;
  try
    try
      ImportKits(ARoot);
    except
      on LException: Exception do
      begin
        LRejected := True;
        WriteLn('REIMPORT rejected: ', LException.Message);
      end;
    end;
    Check(LRejected, 'Reimport rejects new conflicting evidence');
    Check(ReadText(SafeChild(ARoot, 'data/asset-inventory.json')) = LBefore,
      'Reimport retains complete previous valid inventory');
    Check(ReadText(SafeChild(ARoot, 'assets/library/kits/probe/SourceLicense.html')) = FixtureHTML,
      'Reimport retains existing published provenance');
    Check(HashFile(SafeChild(ARoot, 'assets/library/kits/probe/a.glb')) = HashBytes(GModel),
      'Reimport retains existing published source');
  finally
    WriteText(SafeChild(ARoot, 'data/kits.lock.json'), LLockBefore);
    WriteText(SafeChild(ARoot, 'build/asset-research/probe-license.html'), FixtureHTML);
  end;
end;

procedure TPackageProbe.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  AStream := TMemoryStream.Create;
end;

procedure TPackageProbe.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LBytes: TBytes;
begin
  LBytes := nil;
  try
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      AStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    Inc(FCount);
    Check((AItem.ArchiveFileName = 'a.glb') or (AItem.ArchiveFileName = 'SourceLicense.html'),
      'Package contains only original model and exact creator evidence');
    if AItem.ArchiveFileName = 'a.glb' then
    begin
      Check(HashBytes(LBytes) = HashBytes(GModel), 'Packaged model bytes');
    end
    else
    begin
      Check(HashBytes(LBytes) = HashBytes(TextBytes(FixtureHTML)), 'Packaged exact HTML bytes');
    end;
  finally
    FreeAndNil(AStream);
  end;
end;

procedure CheckPackage(const ARoot: String);
var
  LIndex: TJSONObject;
  LPackage: TJSONObject;
  LZip: TUnZipper;
  LProbe: TPackageProbe;
begin
  PackageCatalog(ARoot);
  LIndex := LoadJSON(SafeChild(ARoot, 'build/web/data/library-packages.json'));
  LZip := TUnZipper.Create;
  LProbe := TPackageProbe.Create;
  try
    Check(LIndex.Arrays['packages'].Count = 1, 'One optional package');
    LPackage := LIndex.Arrays['packages'].Objects[0];
    LZip.FileName := SafeChild(SafeChild(ARoot, 'build/web'), LPackage.Strings['url']);
    Check(HashFile(LZip.FileName) = LPackage.Strings['sha256'], 'Package index hash');
    LZip.OnCreateStream := LProbe.CreateStream;
    LZip.OnDoneStream := LProbe.DoneStream;
    LZip.UnZipAllFiles;
    Check(LProbe.FCount = 2, 'Exact two-file package closure');
  finally
    LProbe.Free;
    LZip.Free;
    LIndex.Free;
  end;
end;

procedure RunAll;
var
  LScratch: String;
  LGuid: TGUID;
  LPositive: String;
  LHTML: String;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  GRoot := ExpandFileName(ParamStr(1));
  LScratch := SafeChild(GRoot, 'build/tests/kits-license-critic');
  if ParamCount = 2 then
  begin
    LScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture identifier');
  GFixtureRoot := SafeChild(LScratch, 'run-' + GUIDToString(LGuid));
  Require(not DirectoryExists(GFixtureRoot), 'Expected fresh fixture root');
  WriteLn('Fixture root: ', GFixtureRoot);
  GModel := ReadBytes(SafeChild(GRoot, 'cge/data/kits/nature-kit/flower_redA.glb'));
  LPositive := RunImportCase('creator-positive', FixtureHTML, True);
  RunImportCase('wrong-author', Replace(FixtureHTML, 'content="quaternius"',
    'content="someone-else"'), False);
  RunImportCase('wrong-archive', Replace(FixtureHTML, FixtureArchive,
    FixtureArchive + '-other'), False);
  RunImportCase('wrong-license', Replace(FixtureHTML, LicenseLink,
    '<a href="https://creativecommons.org/licenses/by/4.0/">CC BY</a>'), False);
  RunImportCase('cc0-outside-field', Replace(FixtureHTML, LicenseLink, 'No license') +
    LicenseLink, False);
  RunImportCase('missing-field', Replace(FixtureHTML, LicenseStart, '<div>'), False);
  RunImportCase('hash-mismatch', FixtureHTML, False, 'hash-mismatch');
  RunImportCase('omitted-evidence', FixtureHTML, False, 'omitted');
  RunImportCase('manifest-conflict', FixtureHTML, False, 'both-fields');
  RunImportCase('bundled-inside', FixtureHTML, False, 'bundled-inside');
  RunImportCase('bundled-outside', FixtureHTML, False, 'bundled-outside');
  RunImportCase('casefolded-collision', FixtureHTML, False, 'collision');
  RunImportCase('unknown-adapter', FixtureHTML, False, 'wrong-mode');
  RunImportCase('wrong-page', FixtureHTML, False, 'wrong-page');
  RunImportCase('http-evidence', FixtureHTML, False, 'http');
  { Comments are not author declarations, license fields or downloadable links. }
  LHTML := Replace(FixtureHTML, CreatorTag, '<!-- ' + CreatorTag + ' -->' +
    '<meta name="dcterms.creator" content="someone-else" />');
  RunImportCase('commented-author', LHTML, False);
  LHTML := Replace(FixtureHTML, ArchiveLink, '<!-- ' + ArchiveLink + ' -->' +
    '<a href="https://opengameart.org/sites/default/files/other.zip">Other archive</a>');
  RunImportCase('commented-archive', LHTML, False);
  LHTML := Replace(FixtureHTML, LicenseLink, '<!-- ' + LicenseLink + ' -->' +
    '<a href="https://creativecommons.org/licenses/by/4.0/">CC BY</a>');
  RunImportCase('commented-license', LHTML, False);
  LHTML := Replace(FixtureHTML, LicenseLink, '<script type="text/plain">' + LicenseLink +
    '</script><a href="https://creativecommons.org/licenses/by/4.0/">CC BY</a>');
  RunImportCase('inert-script-license', LHTML, False);
  LHTML := Replace(FixtureHTML, LicenseLink, 'No license');
  LHTML := Replace(LHTML, FilesStart, LicenseLink + FilesStart);
  RunImportCase('license-after-closed-field', LHTML, False);
  PreparePalette(LPositive);
  VerifyKits(LPositive);
  Check(True, 'Intact creator evidence verifies');
  VerifyMutation(LPositive, 'changed-snapshot');
  VerifyMutation(LPositive, 'omitted-evidence');
  VerifyMutation(LPositive, 'changed-origin');
  VerifyMutation(LPositive, 'changed-file');
  VerifyMutation(LPositive, 'changed-source');
  CheckFailedReimport(LPositive);
  CheckPackage(LPositive);
  WriteLn('RESULT ', GChecks, ' independent license checks, failures=', GFailures);
  Require(GFailures = 0, 'Independent creator evidence checks failed');
end;

begin
  RunAll;
end.
