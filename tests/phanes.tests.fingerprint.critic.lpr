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

program PhanesTestsFingerprintCritic;

{$mode delphi}
{$H+}

uses
  SysUtils,
  FPJSON,
  CastleScene,
  CastleVectors,
  phanes.tools.files,
  phanes.tools.fingerprint;

const
  Points = '0 0 0, 2 0 0, 0 1 0, 0 0 1';
  Faces = '0 1 2 -1 0 3 1 -1';

var
  GScratch: String;
  GChecks: Integer;
  GFailures: Integer;

procedure Check(const ACondition: Boolean; const AName: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    Inc(GFailures);
    WriteLn('FAIL ', AName);
  end;
end;

function Shape(const APoints, AFaces, AColor: String): String;
begin
  Result := '<Shape><Appearance><Material diffuseColor="' + AColor + '"/></Appearance>' +
    '<IndexedFaceSet coordIndex="' + AFaces + '"><Coordinate point="' + APoints +
    '"/></IndexedFaceSet></Shape>';
end;

function HashFileScene(const APath: String): String;
var
  LScene: TCastleScene;
begin
  LScene := TCastleScene.Create(nil);
  try
    LScene.Load(APath);
    Result := StaticGeometryHash(LScene);
    WriteLn('MODEL ', APath, ' triangles=', LScene.TrianglesCount, ' hash=', Result);
  finally
    LScene.Free;
  end;
end;

function SourceBufferViewHash(const ABytes: TBytes; const AModel: TJSONObject;
  const AView: Integer): String;
var
  LJSONLength: LongWord;
  LStart: Integer;
  LCount: Integer;
  LView: TJSONObject;
  LBytes: TBytes;
begin
  { This raw source check is deliberately independent of CGE's triangulation
    and the fingerprint implementation. These pinned fixtures use one GLB BIN
    chunk and tightly stored, unsparse positions/indices. }
  Require(Length(ABytes) >= 28, 'GLB fixture header is complete');
  Move(ABytes[12], LJSONLength, SizeOf(LJSONLength));
  LView := AModel.Arrays['bufferViews'].Objects[AView];
  Require(LView.Get('buffer', 0) = 0, 'Fixture view uses first buffer');
  LStart := 28 + Integer(LJSONLength) + LView.Get('byteOffset', 0);
  LCount := LView.Integers['byteLength'];
  Require((LStart >= 28) and (LCount > 0) and
    (LStart + LCount <= Length(ABytes)), 'Fixture buffer view is bounded');
  LBytes := Copy(ABytes, LStart, LCount);
  Result := HashBytes(LBytes);
end;

procedure CheckSourceRecolors(const APathA, APathB: String);
var
  LBytesA: TBytes;
  LBytesB: TBytes;
  LModelA: TJSONObject;
  LModelB: TJSONObject;
  LNodeA: TJSONObject;
  LNodeB: TJSONObject;
  I: Integer;
begin
  LBytesA := ReadBytes(APathA);
  LBytesB := ReadBytes(APathB);
  LModelA := ModelJSON(LBytesA, '.glb');
  LModelB := ModelJSON(LBytesB, '.glb');
  try
    Check(HashBytes(LBytesA) <> HashBytes(LBytesB), 'Actual source bytes differ');
    Check(LModelA.Arrays['accessors'].AsJSON = LModelB.Arrays['accessors'].AsJSON,
      'Actual source accessor layouts are identical');
    Check(SourceBufferViewHash(LBytesA, LModelA, 0) =
      SourceBufferViewHash(LBytesB, LModelB, 0), 'Actual source positions match exactly');
    for I := 3 to 4 do
    begin
      Check(SourceBufferViewHash(LBytesA, LModelA, I) =
        SourceBufferViewHash(LBytesB, LModelB, I), 'Actual source index lists match exactly');
    end;
    Check(LModelA.Arrays['nodes'].Count = LModelB.Arrays['nodes'].Count,
      'Actual source transform counts match');
    for I := 0 to LModelA.Arrays['nodes'].Count - 1 do
    begin
      LNodeA := LModelA.Arrays['nodes'].Objects[I];
      LNodeB := LModelB.Arrays['nodes'].Objects[I];
      Check((LNodeA.Arrays['translation'].AsJSON = LNodeB.Arrays['translation'].AsJSON) and
        (LNodeA.Arrays['rotation'].AsJSON = LNodeB.Arrays['rotation'].AsJSON) and
        (LNodeA.Arrays['scale'].AsJSON = LNodeB.Arrays['scale'].AsJSON),
        'Actual source node transforms match exactly');
    end;
    Check(HashFileScene(APathA) = HashFileScene(APathB), 'Actual source recolors group together');
  finally
    LModelA.Free;
    LModelB.Free;
  end;
end;

function HashScene(const AName, ABody: String; const AExternalTransform: Boolean = False;
  const AExternalNonuniform: Boolean = False): String;
var
  LPath: String;
  LScene: TCastleScene;
begin
  LPath := SafeChild(GScratch, AName + '.x3d');
  WriteText(LPath, UTF8String('<?xml version="1.0" encoding="UTF-8"?>' +
    '<X3D profile="Interchange" version="3.3"><Scene>' + ABody + '</Scene></X3D>'));
  LScene := TCastleScene.Create(nil);
  try
    LScene.Load(LPath);
    if AExternalTransform then
    begin
      LScene.Translation := Vector3(32, -16, 8);
      LScene.Scale := Vector3(4, 4, 4);
      if AExternalNonuniform then
      begin
        LScene.Scale := Vector3(4, 2, 4);
      end;
    end;
    try
      Result := StaticGeometryHash(LScene);
    except
      on LException: Exception do
      begin
        Result := 'REJECTED';
        WriteLn('REJECT ', AName, ': ', LException.Message);
      end;
    end;
    WriteLn('CASE ', AName, ' triangles=', LScene.TrianglesCount, ' hash=', Result);
  finally
    LScene.Free;
  end;
end;

procedure RunAll;
var
  LRoot: String;
  LGuid: TGUID;
  LBase: String;
  LShape: String;
  LPathA: String;
  LPathB: String;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  LRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(LRoot, 'build/tests/fingerprint-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture identifier');
  GScratch := SafeChild(GScratch, 'run-' + GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Expected fresh fingerprint fixture root');
  LShape := Shape(Points, Faces, '0.2 0.5 0.8');
  LBase := HashScene('base', LShape);
  Check(Length(LBase) = 64, 'Baseline SHA-256');
  Check(HashScene('repeat', LShape) = LBase, 'Repeated scene is deterministic');
  Check(HashScene('material', Shape(Points, Faces, '0.9 0.1 0.3')) = LBase,
    'Scalar material does not change geometry group');
  Check(HashScene('triangle-order', Shape(Points, '0 3 1 -1 0 1 2 -1', '1 0 0')) = LBase,
    'Triangle order does not change geometry group');
  Check(HashScene('winding', Shape(Points, '2 1 0 -1 1 3 0 -1', '1 0 0')) = LBase,
    'Reversed winding does not change geometry group');
  Check(HashScene('vertex-order', Shape('0 0 1, 0 1 0, 2 0 0, 0 0 0',
    '3 2 1 -1 3 0 2 -1', '1 0 0')) = LBase, 'Vertex numbering is irrelevant');
  Check(HashScene('split-shapes', Shape(Points, '0 1 2 -1', '1 0 0') +
    Shape(Points, '0 3 1 -1', '0 1 0')) = LBase, 'Material/shape partitions are irrelevant');
  Check(HashScene('translated-scaled', '<Transform translation="32 -16 8" scale="4 4 4">' +
    LShape + '</Transform>') = LBase, 'Authored translation/uniform scale normalized');
  Check(HashScene('external-translated-scaled', LShape, True) = LBase,
    'TCastleScene translation/uniform scale uses same fingerprint frame');
  Check(HashScene('external-nonuniform', LShape, True, True) =
    HashScene('internal-nonuniform', '<Transform translation="32 -16 8" scale="4 2 4">' +
    LShape + '</Transform>'), 'External nonuniform scale agrees with authored geometry');
  Check(HashScene('external-nonuniform-repeat', LShape, True, True) <> LBase,
    'External nonuniform scale remains significant');
  Check(HashScene('nonuniform', '<Transform scale="2 1 1">' + LShape + '</Transform>') <>
    LBase, 'Aspect-ratio change produces another group');
  Check(HashScene('shape-change', Shape('0 0 0, 2 0 0, 0 0.75 0, 0 0 1', Faces, '1 0 0')) <>
    LBase, 'Changed visible geometry produces another group');
  Check(HashScene('multiplicity', Shape(Points, Faces + ' 0 1 2 -1', '1 0 0')) <>
    LBase, 'Repeated triangle multiplicity remains significant');
  Check(HashScene('unused-coordinate', Shape(Points + ', 100 200 300', Faces, '1 0 0')) = LBase,
    'Unused coordinate cannot alter a visible triangle-soup fingerprint');
  Check(HashScene('inactive-shape', LShape + '<Switch whichChoice="-1">' +
    Shape('100 0 0, 200 0 0, 100 200 0', '0 1 2 -1', '1 0 0') + '</Switch>') = LBase,
    'Inactive geometry does not affect current pose');
  Check(HashScene('empty', '') = 'REJECTED', 'Empty scene rejects');
  LPathA := SafeChild(LRoot, 'cge/data/kits/nature-kit/tree_thin.glb');
  LPathB := SafeChild(LRoot, 'cge/data/kits/nature-kit/tree_thin_fall.glb');
  CheckSourceRecolors(LPathA, LPathB);
  WriteLn('RESULT ', GChecks, ' independent fingerprint checks, failures=', GFailures);
  Require(GFailures = 0, 'Independent fingerprint checks failed');
end;

begin
  RunAll;
end.
