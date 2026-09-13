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

program PhanesReviewTests;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  phanes.tools.files,
  phanes.tools.reviews;

const
  Categories: array[0..3] of String = (
    'intuitiveness', 'accuracy', 'wowFactor', 'thinkingOutOfTheBox');

var
  GRoot: String;
  GRegistry: TJSONObject;
  GReport: TJSONObject;
  GFeature: TJSONObject;
  GGrades: TJSONObject;
  GMessages: TStringList;
  GCount: Integer;
  I: Integer;

procedure Fixture;
var
  LFeatures: TJSONArray;
  LFiles: TJSONObject;
  J: Integer;
begin
  FreeAndNil(GRegistry);
  FreeAndNil(GReport);
  GRegistry := TJSONObject.Create(['schemaVersion', 1]);
  LFeatures := TJSONArray.Create;
  GRegistry.Add('features', LFeatures);
  GFeature := TJSONObject.Create(['id', 'fixture', 'scope', 'Test fixture only',
    'review', 'reviews/fixture.json']);
  GFeature.Add('inputs', TJSONArray.Create(['fixture.pas']));
  LFeatures.Add(GFeature);
  GReport := TJSONObject.Create(['schemaVersion', 1, 'feature', 'fixture',
    'scope', 'Test fixture only', 'criticAgent', 'test-critic', 'builderAgent', 'test-builder',
    'reviewedAt', '2026-09-08', 'decision', 'pass', 'verification', 'Synthetic gate fixture']);
  GGrades := TJSONObject.Create;
  GReport.Add('grades', GGrades);
  for J := 0 to High(Categories) do
  begin
    GGrades.Add(Categories[J], TJSONObject.Create(['grade', 'B+', 'evidence', 'Fixture evidence']));
  end;
  GReport.Add('blockingFindings', TJSONArray.Create);
  WriteText(SafeChild(GRoot, 'fixture.pas'), 'unit fixture;' + #10);
  LFiles := TJSONObject.Create(['fixture.pas', ReviewFileHash(SafeChild(GRoot, 'fixture.pas'))]);
  GReport.Add('reviewedFiles', LFiles);
end;

procedure Expect(const AName: String; const APass: Boolean);
var
  LActual: Boolean;
begin
  WriteText(SafeChild(GRoot, 'reviews/features.json'), GRegistry.AsJSON);
  WriteText(SafeChild(GRoot, 'reviews/fixture.json'), GReport.AsJSON);
  GMessages.Clear;
  try
    LActual := CheckReviewGate(GRoot, GMessages);
  except
    on LException: Exception do
    begin
      LActual := False;
      GMessages.Add(LException.Message);
    end;
  end;
  Require(LActual = APass, AName + ': unexpected gate result: ' + GMessages.Text);
  Inc(GCount);
  WriteLn('PASS ', AName);
end;

begin
  Require(ParamCount = 1, 'Pass repository root');
  GRoot := SafeChild(ParamStr(1), 'build/review-tests');
  GMessages := TStringList.Create;
  try
    Fixture;
    Expect('B+ in every category passes', True);
    GGrades.Objects['accuracy'].Strings['grade'] := 'A';
    GGrades.Objects['wowFactor'].Strings['grade'] := 'A-';
    Expect('A and A- pass without averaging', True);
    for I := 0 to High(Categories) do
    begin
      GGrades.Objects[Categories[I]].Strings['grade'] := 'B';
      Expect(Categories[I] + ' B blocks despite other passing grades', False);
      GGrades.Objects[Categories[I]].Strings['grade'] := 'B+';
    end;
    GGrades.Objects['accuracy'].Strings['grade'] := 'A+';
    Expect('Unrecognized grade fails closed', False);
    Fixture;
    GGrades.Delete('accuracy');
    Expect('Missing grade blocks', False);
    Fixture;
    GGrades.Objects['accuracy'].Strings['evidence'] := '';
    Expect('Missing evidence blocks', False);
    Fixture;
    GReport.Strings['criticAgent'] := 'test-builder';
    Expect('Self review blocks', False);
    Fixture;
    GReport.Arrays['blockingFindings'].Add('Unresolved requirement');
    Expect('Unresolved blocker blocks', False);
    Fixture;
    GReport.Strings['decision'] := 'changes_requested';
    Expect('Critic rejection blocks despite passing grades', False);
    Fixture;
    GFeature.Delete('review');
    GFeature.Add('review', TJSONNull.Create);
    Expect('Pending review blocks', False);
    Fixture;
    WriteText(SafeChild(GRoot, 'fixture.pas'), 'unit changed;' + #10);
    Expect('Changed reviewed source blocks', False);
    Fixture;
    WriteText(SafeChild(GRoot, 'fixture.pas'), 'unit fixture;' + #13#10);
    Expect('CRLF checkout retains LF review digest', True);
    Fixture;
    GFeature.Strings['scope'] := 'Reduced scope';
    Expect('Changed scope blocks', False);
    Fixture;
    GFeature.Arrays['inputs'].Add('unreviewed.pas');
    Expect('Unreviewed input blocks', False);
    Fixture;
    GReport.Objects['reviewedFiles'].Add('extra.pas', 'anything');
    Expect('Mismatched reviewed file set blocks', False);
    Fixture;
    GFeature.Arrays['inputs'].Clear;
    GReport.Objects['reviewedFiles'].Clear;
    Expect('Empty review inputs block', False);
    Fixture;
    GFeature.Arrays['inputs'].Add('fixture.pas');
    GReport.Objects['reviewedFiles'].Add('extra.pas', 'anything');
    Expect('Duplicate input blocks', False);
    Fixture;
    GRegistry.Arrays['features'].Add(GFeature.Clone);
    Expect('Duplicate feature blocks', False);
    Fixture;
    GRegistry.Arrays['features'].Clear;
    Expect('Empty registry blocks', False);
    Fixture;
    GFeature.Arrays['inputs'].Strings[0] := '../outside.pas';
    GReport.Objects['reviewedFiles'].Delete('fixture.pas');
    GReport.Objects['reviewedFiles'].Add('../outside.pas', 'anything');
    Expect('Escaping input path blocks', False);
    Fixture;
    GFeature.Strings['review'] := 'reviews/missing.json';
    Expect('Missing report blocks', False);
    Fixture;
    WriteText(SafeChild(GRoot, 'build/temporary.json'), GReport.AsJSON);
    GFeature.Strings['review'] := 'reviews/../build/temporary.json';
    Expect('Report cannot escape reviews with forward slashes', False);
    GFeature.Strings['review'] := 'reviews/..\build/temporary.json';
    Expect('Report cannot escape reviews with mixed separators', False);
    WriteLn(GCount, ' critic gate checks passed');
  finally
    GRegistry.Free;
    GReport.Free;
    GMessages.Free;
  end;
end.
