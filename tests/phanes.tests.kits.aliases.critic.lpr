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

program PhanesTestsKitsAliasesCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  phanes.tools.files,
  phanes.tools.kits;

var
  GFixtureRoot: String;
  GOriginalModel: TBytes;
  GTexture: TBytes;
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

procedure Put32(var ABytes: TBytes; const AOffset: Integer; const AValue: Cardinal);
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    ABytes[AOffset + I] := (AValue shr (8 * I)) and 255;
  end;
end;

function WithImage(const AUri: String): TBytes;
var
  LModel: TJSONObject;
  LJSON: UTF8String;
  LOldLength: Integer;
  LTail: Integer;
begin
  Result := nil;
  LModel := GLBJSON(GOriginalModel);
  try
    if LModel.Find('images') = nil then
    begin
      LModel.Add('images', TJSONArray.Create);
    end;
    LModel.Arrays['images'].Add(TJSONObject.Create(['uri', AUri]));
    LJSON := LModel.AsJSON;
    while Length(LJSON) mod 4 <> 0 do
    begin
      LJSON := LJSON + ' ';
    end;
    LOldLength := Little32(GOriginalModel, 12);
    LTail := Length(GOriginalModel) - 20 - LOldLength;
    SetLength(Result, 20 + Length(LJSON) + LTail);
    Move(GOriginalModel[0], Result[0], 20);
    Put32(Result, 8, Length(Result));
    Put32(Result, 12, Length(LJSON));
    Move(LJSON[1], Result[20], Length(LJSON));
    if LTail > 0 then
    begin
      Move(GOriginalModel[20 + LOldLength], Result[20 + Length(LJSON)], LTail);
    end;
  finally
    LModel.Free;
  end;
end;

function RunCase(const AName, AUri, AFrom, ATo: String; const AExpected: Boolean;
  const AMode: String = ''): String;
var
  LArchive: String;
  LBefore: UTF8String;
  LZip: TZipper;
  LStreams: TList;
  LStream: TMemoryStream;
  LLock: TJSONObject;
  LKit: TJSONObject;
  LAliases: TJSONArray;
  LInventory: TJSONObject;
  LAsset: TJSONObject;
  LDependency: TJSONObject;
  LModel: TBytes;
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
  Require(not DirectoryExists(Result), 'Expected fresh alias fixture');
  LArchive := SafeChild(Result, 'build/asset-research/probe.zip');
  ForceDirectories(ExtractFileDir(LArchive));
  LBefore := '{"version":2,"assets":[],"marker":"unchanged on rejection"}' + #10;
  WriteText(SafeChild(Result, 'data/asset-inventory.json'), LBefore);
  LModel := WithImage(AUri);
  LZip := TZipper.Create;
  LStreams := TList.Create;
  try
    LZip.FileName := LArchive;
    Add('License.txt', TextBytes('CC0 original synthetic license notice'));
    Add('Models/a.glb', LModel);
    Add('Models/Textures/atlas.png', GTexture);
    Add('Outside/not-selected.png', GTexture);
    if AMode = 'collision' then
    begin
      Add('Models/atlas.png', GTexture);
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
  LLock := TJSONObject.Create(['version', 1]);
  try
    LLock.Add('kits', TJSONArray.Create);
    LKit := TJSONObject.Create(['id', 'probe', 'storage', 'library', 'theme', 'nature',
      'license', 'CC0-1.0', 'author', 'Synthetic critic fixture',
      'page', 'https://example.invalid/probe', 'archiveUrl', 'https://example.invalid/probe.zip',
      'archiveSha256', HashFile(LArchive), 'modelPrefix', 'Models/']);
    LLock.Arrays['kits'].Add(LKit);
    LAliases := TJSONArray.Create;
    LKit.Add('dependencyAliases', LAliases);
    LAliases.Add(TJSONObject.Create(['from', AFrom, 'to', ATo]));
    if AMode = 'chain' then
    begin
      LAliases.Add(TJSONObject.Create(['from', ATo, 'to', 'second.png']));
    end;
    if AMode = 'duplicate' then
    begin
      LAliases.Add(TJSONObject.Create(['from', AFrom, 'to', UpperCase(ATo)]));
    end;
    if AMode = 'fanout' then
    begin
      LAliases.Add(TJSONObject.Create(['from', AFrom, 'to', 'second.png']));
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
      AName + ': inventory preservation');
    Check(not DirectoryExists(SafeChild(Result, 'assets/library/kits/probe')),
      AName + ': no partial publication');
  end
  else if LAccepted then
  begin
    LInventory := LoadJSON(SafeChild(Result, 'data/asset-inventory.json'));
    try
      Check(LInventory.Arrays['assets'].Count = 1, AName + ': aliases are not extra models');
      LAsset := LInventory.Arrays['assets'].Objects[0];
      Check(LAsset.Strings['id'] = 'probe/a', AName + ': original model ID');
      Check(LAsset.Strings['sha256'] = HashBytes(LModel), AName + ': original model hash');
      Check(HashFile(SafeChild(Result, 'assets/library/kits/probe/a.glb')) = HashBytes(LModel),
        AName + ': original model bytes unchanged');
      Check(HashFile(SafeChild(Result, 'assets/library/kits/probe/Textures/atlas.png')) =
        HashBytes(GTexture), AName + ': original texture bytes unchanged');
      Check(HashFile(SafeChild(Result, 'assets/library/kits/probe/' + ATo)) =
        HashBytes(GTexture), AName + ': alias exact copy');
      Check(LAsset.Arrays['dependencies'].Count = 1, AName + ': dependency count');
      LDependency := LAsset.Arrays['dependencies'].Objects[0];
      Check(LDependency.Strings['path'] = ATo, AName + ': exact dependency path');
      Check(LDependency.Strings['sourcePath'] = AFrom, AName + ': exact source path');
      Check(LDependency.Strings['sha256'] = HashBytes(GTexture), AName + ': dependency hash');
      Check(LDependency.Int64s['bytes'] = Length(GTexture), AName + ': dependency byte size');
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
    { This reaches the existing verifier join; these are not physical profiles. }
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

procedure CheckVerifier(const ARoot, AMode: String);
var
  LBefore: UTF8String;
  LLockBefore: UTF8String;
  LSubmitted: UTF8String;
  LDocument: TJSONObject;
  LLock: TJSONObject;
  LDependency: TJSONObject;
  LModified: TBytes;
  LSource: String;
  LRejected: Boolean;
  LError: String;
begin
  LBefore := ReadText(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLockBefore := ReadText(SafeChild(ARoot, 'data/kits.lock.json'));
  LDocument := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  try
    LDependency := LDocument.Arrays['assets'].Objects[0].Arrays['dependencies'].Objects[0];
    if AMode = 'omit-source-metadata' then
    begin
      LDependency.Delete('sourcePath');
    end;
    if AMode = 'omit-lock-aliases' then
    begin
      LLock.Arrays['kits'].Objects[0].Delete('dependencyAliases');
    end;
    if (AMode = 'changed-original') or (AMode = 'changed-alias') then
    begin
      LModified := Copy(GTexture);
      LModified[High(LModified)] := LModified[High(LModified)] xor 1;
      LSource := 'Textures/atlas.png';
      if AMode = 'changed-alias' then
      begin
        LSource := 'atlas.png';
      end;
      WriteBytes(SafeChild(ARoot, 'assets/library/kits/probe/' + LSource), LModified);
    end;
    if (AMode = 'noncanonical-source') or (AMode = 'wrong-source-case') then
    begin
      LSource := 'Textures/../Textures/atlas.png';
      if AMode = 'wrong-source-case' then
      begin
        LSource := 'Textures/ATLAS.PNG';
      end;
      LLock.Arrays['kits'].Objects[0].Arrays['dependencyAliases'].Objects[0].Strings['from'] :=
        LSource;
      LDependency.Strings['sourcePath'] := LSource;
    end;
    WriteText(SafeChild(ARoot, 'data/asset-inventory.json'), LDocument.AsJSON);
    WriteText(SafeChild(ARoot, 'data/kits.lock.json'), LLock.AsJSON);
  finally
    LLock.Free;
    LDocument.Free;
  end;
  LSubmitted := ReadText(SafeChild(ARoot, 'data/asset-inventory.json'));
  LRejected := False;
  LError := '';
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
    Check(ReadText(SafeChild(ARoot, 'data/asset-inventory.json')) = LSubmitted,
      'Verifier ' + AMode + ': must not rewrite inventory');
  finally
    WriteText(SafeChild(ARoot, 'data/asset-inventory.json'), LBefore);
    WriteText(SafeChild(ARoot, 'data/kits.lock.json'), LLockBefore);
    WriteBytes(SafeChild(ARoot, 'assets/library/kits/probe/Textures/atlas.png'), GTexture);
    WriteBytes(SafeChild(ARoot, 'assets/library/kits/probe/atlas.png'), GTexture);
  end;
  WriteLn('VERIFY ', AMode, ' rejected=', LRejected, ' ', LError);
end;

procedure RunAll;
var
  LRoot: String;
  LScratch: String;
  LGuid: TGUID;
  LPositive: String;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  LRoot := ExpandFileName(ParamStr(1));
  LScratch := SafeChild(LRoot, 'build/tests/kits-aliases-critic');
  if ParamCount = 2 then
  begin
    LScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture identifier');
  GFixtureRoot := SafeChild(LScratch, 'run-' + GUIDToString(LGuid));
  Require(not DirectoryExists(GFixtureRoot), 'Expected fresh fixture root');
  WriteLn('Fixture root: ', GFixtureRoot);
  GOriginalModel := ReadBytes(SafeChild(LRoot, 'cge/data/kits/nature-kit/flower_redA.glb'));
  GTexture := ReadBytes(SafeChild(LRoot, 'cge/data/kits/castle-kit/Textures/colormap.png'));
  LPositive := RunCase('explicit-positive', 'atlas.png', 'Textures/atlas.png', 'atlas.png', True);
  RunCase('nested-positive', 'nested/atlas.png', 'Textures/atlas.png', 'nested/atlas.png', True);
  RunCase('fanout-positive', 'atlas.png', 'Textures/atlas.png', 'atlas.png', True, 'fanout');
  RunCase('missing-source', 'atlas.png', 'Textures/missing.png', 'atlas.png', False);
  RunCase('source-case', 'atlas.png', 'Textures/ATLAS.PNG', 'atlas.png', False);
  RunCase('target-case', 'ATLAS.PNG', 'Textures/atlas.png', 'atlas.png', False);
  RunCase('target-collision', 'atlas.png', 'Textures/atlas.png', 'atlas.png', False, 'collision');
  RunCase('duplicate-target', 'atlas.png', 'Textures/atlas.png', 'atlas.png', False, 'duplicate');
  RunCase('source-chain', 'atlas.png', 'Textures/atlas.png', 'atlas.png', False, 'chain');
  RunCase('self-alias', 'Textures/atlas.png', 'Textures/atlas.png', 'Textures/atlas.png', False);
  RunCase('source-parent', 'atlas.png', 'Textures/../Textures/atlas.png', 'atlas.png', False);
  RunCase('target-parent', 'atlas.png', 'Textures/atlas.png', 'nested/../atlas.png', False);
  RunCase('source-outside', 'atlas.png', '../Outside/not-selected.png', 'atlas.png', False);
  RunCase('target-model-glb', 'alias.glb', 'Textures/atlas.png', 'alias.glb', False);
  RunCase('target-model-gltf', 'alias.gltf', 'Textures/atlas.png', 'alias.gltf', False);
  PreparePalette(LPositive);
  VerifyKits(LPositive);
  Check(True, 'Intact alias baseline verifies');
  CheckVerifier(LPositive, 'changed-original');
  CheckVerifier(LPositive, 'changed-alias');
  CheckVerifier(LPositive, 'omit-source-metadata');
  CheckVerifier(LPositive, 'omit-lock-aliases');
  CheckVerifier(LPositive, 'noncanonical-source');
  CheckVerifier(LPositive, 'wrong-source-case');
  WriteLn('RESULT ', GChecks, ' independent alias checks, failures=', GFailures);
  Require(GFailures = 0, 'Independent dependency alias checks failed');
end;

begin
  RunAll;
end.
