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

program PhanesTestsKitsCritic;

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
  GRoot: String;
  GModelA: TBytes;
  GModelB: TBytes;
  GExtra: TBytes;
  GDependencyEntry: String;
  GDependencyBytes: TBytes;
  GPreseedEntry: String;
  GModelFormat: String;
  GFixtureRoot: String;
  GScratch: String;
  GGuid: TGUID;
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  Require(ACondition, AMessage);
end;

procedure Put32(var ABytes: TBytes; const AOffset: Integer; const AValue: Cardinal);
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    ABytes[AOffset + I] := (AValue shr (I * 8)) and 255;
  end;
end;

function WithDependency(const ABytes: TBytes; const AGroup, AUri: String): TBytes;
var
  LModel: TJSONObject;
  LArray: TJSONArray;
  LDependency: TJSONObject;
  LJSON: UTF8String;
  LOldLength: Integer;
  LNewLength: Integer;
  LTailLength: Integer;
begin
  Result := nil;
  LModel := GLBJSON(ABytes);
  try
    if LModel.Find(AGroup) = nil then
    begin
      LModel.Add(AGroup, TJSONArray.Create);
    end;
    LArray := LModel.Arrays[AGroup];
    LDependency := TJSONObject.Create(['uri', AUri]);
    if AGroup = 'buffers' then
    begin
      LDependency.Add('byteLength', 4);
    end;
    LArray.Add(LDependency);
    LJSON := LModel.AsJSON;
    while (Length(LJSON) mod 4) <> 0 do
    begin
      LJSON := LJSON + ' ';
    end;
    LOldLength := Little32(ABytes, 12);
    LNewLength := Length(LJSON);
    LTailLength := Length(ABytes) - 20 - LOldLength;
    SetLength(Result, 20 + LNewLength + LTailLength);
    Move(ABytes[0], Result[0], 20);
    Put32(Result, 8, Length(Result));
    Put32(Result, 12, LNewLength);
    Move(LJSON[1], Result[20], LNewLength);
    if LTailLength > 0 then
    begin
      Move(ABytes[20 + LOldLength], Result[20 + LNewLength], LTailLength);
    end;
  finally
    LModel.Free;
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

procedure RunCase(const AName, AFirst, ASecond, APrefix: String;
  const AExpectAccepted: Boolean; const ABlockLast: Boolean = False);
var
  LRoot: String;
  LArchive: String;
  LOldInventory: UTF8String;
  LZip: TZipper;
  LStreams: TList;
  LStream: TMemoryStream;
  LLock: TJSONObject;
  LInventory: TJSONObject;
  LKit: TJSONObject;
  LAssets: TJSONArray;
  LError: String;
  LAccepted: Boolean;
  LMismatches: Integer;
  LPublished: String;
  LUri: String;
  LExpectedFirst: String;
  LExpectedSecond: String;
  LExpectedModels: Integer;
  LExpectedDependencies: Integer;
  LDependency: TJSONObject;
  I: Integer;
  J: Integer;

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
  LRoot := SafeChild(GFixtureRoot, AName);
  Require(not DirectoryExists(LRoot), 'Fixture already exists; use another numbered root');
  LArchive := SafeChild(LRoot, 'build/asset-research/probe.zip');
  ForceDirectories(ExtractFileDir(LArchive));
  LOldInventory := '{"version":1,"assets":[],"marker":"preserve"}' + #10;
  WriteText(SafeChild(LRoot, 'data/asset-inventory.json'), LOldInventory);
  LZip := TZipper.Create;
  LStreams := TList.Create;
  try
    LZip.FileName := LArchive;
    Add(AFirst, GModelA);
    if ASecond <> '' then
    begin
      Add(ASecond, GModelB);
    end;
    Add('License.txt', TextBytes('Creative Commons CC0 1.0 Universal'));
    Add('Models/README.txt', GExtra);
    Add('Other/README.txt', GExtra);
    if GDependencyEntry <> '' then
    begin
      Add(GDependencyEntry, GDependencyBytes);
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
    LAssets := TJSONArray.Create;
    LLock.Add('kits', LAssets);
    LKit := TJSONObject.Create(['id', 'probe', 'storage', 'library',
      'theme', 'nature', 'license', 'CC0-1.0', 'author', 'Synthetic critic fixture',
      'page', 'https://example.invalid/probe',
      'archiveUrl', 'https://example.invalid/probe.zip',
      'archiveSha256', HashFile(LArchive)]);
    if APrefix <> '<automatic>' then
    begin
      LKit.Add('modelPrefix', APrefix);
    end;
    if GModelFormat <> '' then
    begin
      LKit.Add('modelFormat', GModelFormat);
    end;
    LAssets.Add(LKit);
    WriteText(SafeChild(LRoot, 'data/kits.lock.json'), LLock.AsJSON);
  finally
    LLock.Free;
  end;
  if ABlockLast then
  begin
    ForceDirectories(SafeChild(LRoot, 'assets/library/kits/probe/z.glb'));
  end;
  if GPreseedEntry <> '' then
  begin
    { This old deterministic staging location must never supply bytes absent
      from the pinned archive, even after a previous failed extraction. }
    WriteBytes(SafeChild(LRoot, 'build/asset-staging/probe/' + HashFile(LArchive) +
      '/' + GPreseedEntry), GDependencyBytes);
  end;
  LAccepted := False;
  LError := '';
  try
    ImportKits(LRoot);
    LAccepted := True;
  except
    on LException: Exception do
    begin
      LError := LException.Message;
    end;
  end;
  WriteLn('CASE ', AName, ' accepted=', LAccepted, ' error=', LError);
  Check(LAccepted = AExpectAccepted, AName + ': unexpected import result: ' + LError);
  if not LAccepted then
  begin
    Check(ReadText(SafeChild(LRoot, 'data/asset-inventory.json')) = LOldInventory,
      AName + ': failure changed inventory');
    Check(DirectoryExists(SafeChild(LRoot, 'assets/library/kits/probe')) = ABlockLast,
      AName + ': failure published a kit');
    Check(not FileExists(SafeChild(LRoot, 'assets/library/kits/probe/a.glb')),
      AName + ': failure published an early file');
  end;
  if LAccepted then
  begin
    LInventory := LoadJSON(SafeChild(LRoot, 'data/asset-inventory.json'));
    try
      LMismatches := 0;
      LAssets := LInventory.Arrays['assets'];
      LExpectedModels := 1;
      if ASecond <> '' then
      begin
        Inc(LExpectedModels);
      end;
      Check(LAssets.Count = LExpectedModels, AName + ': wrong model count');
      LExpectedFirst := 'kits/probe/' + Copy(AFirst, Length(APrefix) + 1, MaxInt);
      LExpectedSecond := 'kits/probe/' + Copy(ASecond, Length(APrefix) + 1, MaxInt);
      for I := 0 to LAssets.Count - 1 do
      begin
        for J := 0 to I - 1 do
        begin
          Check(LAssets.Objects[I].Strings['id'] <> LAssets.Objects[J].Strings['id'],
            AName + ': duplicated model identity');
        end;
        LUri := LAssets.Objects[I].Strings['url'];
        LPublished := SafeChild(SafeChild(LRoot, 'assets/library'), LUri);
        if HashFile(LPublished) <> LAssets.Objects[I].Strings['sha256'] then
        begin
          Inc(LMismatches);
        end;
        Check((LUri = LExpectedFirst) or ((ASecond <> '') and (LUri = LExpectedSecond)),
          AName + ': wrong original model path');
        if LUri = LExpectedFirst then
        begin
          Check(HashFile(LPublished) = HashBytes(GModelA), AName + ': changed first source');
        end
        else
        begin
          Check(HashFile(LPublished) = HashBytes(GModelB), AName + ': changed second source');
        end;
        Check(LAssets.Objects[I].Strings['id'] =
          'probe/' + ChangeFileExt(Copy(LUri, Length('kits/probe/') + 1, MaxInt), ''),
          AName + ': lost nested model identity');
        Check(LAssets.Objects[I].Strings['format'] = Copy(ExtractFileExt(LUri), 2, MaxInt),
          AName + ': wrong format metadata');
        Check(HashFile(SafeChild(LRoot, 'assets/library/kits/probe/License.txt')) =
          LAssets.Objects[I].Strings['licenseSha256'], AName + ': wrong license hash');
        LExpectedDependencies := 0;
        if (LUri = LExpectedFirst) and (GDependencyEntry <> '') then
        begin
          LExpectedDependencies := 1;
        end;
        Check(LAssets.Objects[I].Arrays['dependencies'].Count = LExpectedDependencies,
          AName + ': wrong dependency count');
        for J := 0 to LAssets.Objects[I].Arrays['dependencies'].Count - 1 do
        begin
          LDependency := LAssets.Objects[I].Arrays['dependencies'].Objects[J];
          Check(LDependency.Strings['path'] =
            Copy(GDependencyEntry, Length(APrefix) + 1, MaxInt),
            AName + ': wrong dependency identity');
          Check(LDependency.Strings['sha256'] = HashBytes(GDependencyBytes),
            AName + ': wrong original dependency hash');
          Check(LDependency.Int64s['bytes'] = Length(GDependencyBytes),
            AName + ': wrong dependency size');
          Check(HashFile(SafeChild(LRoot, 'assets/library/kits/probe/' +
            LDependency.Strings['path'])) = HashBytes(GDependencyBytes),
            AName + ': changed published dependency bytes');
        end;
      end;
      Check(LMismatches = 0, AName + ': inventory and published bytes differ');
    finally
      LInventory.Free;
    end;
  end;
end;

procedure CheckDuplicateManifest;
var
  LRoot: String;
  LLock: TJSONObject;
  LBefore: UTF8String;
  LAccepted: Boolean;
  LError: String;
begin
  LRoot := SafeChild(GFixtureRoot, 'nested-positive');
  LBefore := ReadText(SafeChild(LRoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(LRoot, 'data/kits.lock.json'));
  try
    LLock.Arrays['kits'].Add(LLock.Arrays['kits'].Items[0].Clone);
    WriteText(SafeChild(LRoot, 'data/kits.lock.json'), LLock.AsJSON);
  finally
    LLock.Free;
  end;
  LAccepted := False;
  LError := '';
  try
    ImportKits(LRoot);
    LAccepted := True;
  except
    on LException: Exception do
    begin
      LError := LException.Message;
    end;
  end;
  WriteLn('CASE duplicate-kit-manifest accepted=', LAccepted, ' error=', LError);
  Check(not LAccepted, 'Duplicate kit manifest accepted');
  Check(LBefore = ReadText(SafeChild(LRoot, 'data/asset-inventory.json')),
    'Duplicate manifest changed inventory');
end;

procedure CheckVerifierCorruption(const AFixture, ARelativeFile: String);
const
  CKinds: array[0..8] of String = ('cabin', 'castle', 'modern', 'scifi',
    'tree', 'shrub', 'flowers', 'crop', 'rock');
var
  LRoot: String;
  LInventory: TJSONObject;
  LPalette: TJSONObject;
  LAssets: TJSONArray;
  LModelId: String;
  LPath: String;
  LBefore: UTF8String;
  LOriginal: TBytes;
  LTampered: TBytes;
  LRejected: Boolean;
  LError: String;
  I: Integer;
begin
  LRoot := SafeChild(GFixtureRoot, AFixture);
  LBefore := ReadText(SafeChild(LRoot, 'data/asset-inventory.json'));
  LInventory := LoadJSON(SafeChild(LRoot, 'data/asset-inventory.json'));
  try
    LModelId := LInventory.Arrays['assets'].Objects[0].Strings['id'];
  finally
    LInventory.Free;
  end;
  LPalette := TJSONObject.Create;
  try
    { These rows reach the existing verifier join. They do not claim that this
      tiny fixture model is physically admitted for any regional role. }
    LAssets := TJSONArray.Create;
    LPalette.Add('assets', LAssets);
    for I := Low(CKinds) to High(CKinds) do
    begin
      LAssets.Add(TJSONObject.Create(['id', LModelId, 'kind', CKinds[I], 'width', 1]));
    end;
    WriteText(SafeChild(LRoot, 'data/palette.json'), LPalette.AsJSON);
  finally
    LPalette.Free;
  end;
  VerifyKits(LRoot);
  Check(True, 'Intact baseline verifies');
  LPath := SafeChild(LRoot, 'assets/library/kits/probe/' + ARelativeFile);
  LOriginal := ReadBytes(LPath);
  LTampered := Copy(LOriginal);
  Require(Length(LTampered) > 0, 'Expected nonempty corruption fixture');
  LTampered[High(LTampered)] := LTampered[High(LTampered)] xor 1;
  WriteBytes(LPath, LTampered);
  LRejected := False;
  LError := '';
  try
    try
      VerifyKits(LRoot);
    except
      on LException: Exception do
      begin
        LRejected := True;
        LError := LException.Message;
      end;
    end;
  finally
    WriteBytes(LPath, LOriginal);
  end;
  Check(LRejected, 'Verifier accepted corrupted ' + ARelativeFile);
  Check(ReadText(SafeChild(LRoot, 'data/asset-inventory.json')) = LBefore,
    'Verifier changed inventory');
  WriteLn('VERIFY ', ARelativeFile, ' rejected=', LRejected,
    ' inventoryPreserved=TRUE error=', LError);
end;

procedure CheckGLTF;
const
  CModel = '{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],' +
    '"nodes":[{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],' +
    '"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3",' +
    '"min":[0,0,0],"max":[1,1,0]}],"bufferViews":[{"buffer":0,"byteLength":36}],' +
    '"buffers":[{"uri":"../Buffers/triangle.bin","byteLength":36}]}';
begin
  GExtra := TextBytes('Synthetic non-model archive member');
  GPreseedEntry := '';
  GModelFormat := 'gltf2';
  GDependencyEntry := 'Models/Buffers/triangle.bin';
  SetLength(GDependencyBytes, 36);
  FillChar(GDependencyBytes[0], Length(GDependencyBytes), 0);
  Put32(GDependencyBytes, 12, $3F800000);
  Put32(GDependencyBytes, 28, $3F800000);
  GModelA := TextBytes(CModel);
  RunCase('gltf-external-positive', 'Models/sub/triangle.gltf', '', 'Models/', True);
  GModelB := ReadBytes(SafeChild(GRoot, 'cge/data/kits/nature-kit/flower_redA.glb'));
  RunCase('gltf-mixed-positive', 'Models/sub/triangle.gltf', 'Models/sub/flower.glb',
    'Models/', True);
  GModelA := TextBytes(StringReplace(CModel, '"version":"2.0"', '"version":"1.0"', []));
  RunCase('gltf-version-negative', 'Models/sub/triangle.gltf', '', 'Models/', False);
end;

begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  GRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(GRoot, 'build/tests/kits-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(GGuid) = 0, 'Cannot create fresh fixture identifier');
  GFixtureRoot := SafeChild(GScratch, 'run-' + GUIDToString(GGuid));
  Require(not DirectoryExists(GFixtureRoot), 'Expected fresh fixture root');
  WriteLn('Fixture root: ', GFixtureRoot);
  GModelA := ReadBytes(SafeChild(GRoot, 'cge/data/kits/nature-kit/flower_redA.glb'));
  GModelB := ReadBytes(SafeChild(GRoot, 'cge/data/kits/nature-kit/flower_purpleA.glb'));
  GExtra := TextBytes('Synthetic non-model archive member');
  RunCase('nested-positive', 'Models/left/a.glb', 'Models/right/a.glb', 'Models/', True);
  RunCase('dot-alias', 'Models/a.glb', 'Models/./a.glb', 'Models/', False);
  RunCase('parent-alias', 'Models/a.glb', 'Models/sub/../a.glb', 'Models/', False);
  RunCase('root-glb', 'a.glb', '', '', True);
  RunCase('empty-selection', 'Models/a.glb', '', 'Other/', False);
  RunCase('fragment-prefix', 'Models/a.glb', '', 'Models/a', False);
  RunCase('partial-publication', 'Models/a.glb', 'Models/z.glb', 'Models/', False, True);
  CheckDuplicateManifest;
  GModelA := WithDependency(GModelB, 'images', 'missing.png');
  RunCase('missing-image', 'Models/a.glb', '', 'Models/', False);
  GModelA := WithDependency(GModelB, 'buffers', 'missing.bin');
  RunCase('missing-buffer', 'Models/a.glb', '', 'Models/', False);
  GDependencyBytes := ReadBytes(SafeChild(GRoot,
    'cge/data/kits/castle-kit/Textures/colormap.png'));
  GDependencyEntry := 'Models/Textures/atlas.png';
  GModelA := WithDependency(GModelB, 'images', '../Textures/atlas.png');
  RunCase('parent-image-positive', 'Models/sub/a.glb', '', 'Models/', True);
  GModelA := WithDependency(GModelB, 'images', '../Textures/ATLAS.PNG');
  RunCase('case-mismatched-image', 'Models/sub/a.glb', '', 'Models/', False);
  GDependencyBytes := TextBytes('1234');
  GDependencyEntry := 'Models/Buffers/payload.bin';
  GModelA := WithDependency(GModelB, 'buffers', '../Buffers/payload.bin');
  RunCase('parent-buffer-positive', 'Models/sub/a.glb', '', 'Models/', True);
  GDependencyEntry := '';
  GModelA := WithDependency(GModelB, 'images', '../../outside.png');
  RunCase('escaping-image', 'Models/sub/a.glb', '', 'Models/', False);
  GDependencyBytes := ReadBytes(SafeChild(GRoot,
    'cge/data/kits/castle-kit/Textures/colormap.png'));
  GPreseedEntry := 'Textures/atlas.png';
  GModelA := WithDependency(GModelB, 'images', '../Textures/atlas.png');
  RunCase('stale-stage-image', 'Models/sub/a.glb', '', 'Models/', False);
  CheckGLTF;
  CheckVerifierCorruption('parent-image-positive', 'Textures/atlas.png');
  CheckVerifierCorruption('parent-buffer-positive', 'Buffers/payload.bin');
  CheckVerifierCorruption('parent-image-positive', 'License.txt');
  CheckVerifierCorruption('gltf-external-positive', 'Buffers/triangle.bin');
  WriteLn('PASS ', GChecks, ' independent kit importer/verifier checks');
end.
