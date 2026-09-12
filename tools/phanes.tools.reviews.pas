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

unit phanes.tools.reviews;

{$mode delphi}
{$H+}

interface

uses
  Classes;

function ReviewFileHash(const APath: String): String;
function CheckReviewGate(const ARoot: String; const AMessages: TStrings): Boolean;

implementation

uses
  SysUtils,
  FPJSON,
  phanes.tools.files;

function ReviewFileHash(const APath: String): String;
var
  LText: UTF8String;
  LBytes: TBytes;
  LExtension: String;
begin
  LExtension := LowerCase(ExtractFileExt(APath));
  if (LExtension = '.pas') or (LExtension = '.lpr') or (LExtension = '.md') or
    (LExtension = '.json') or (LExtension = '.yml') or (LExtension = '.yaml') or
    (LExtension = '.ps1') or (LExtension = '.sh') or (LExtension = '.js') or
    (LExtension = '.cjs') or (LExtension = '.mjs') or (LExtension = '.html') or
    (LExtension = '.css') or (LExtension = '.xml') then
  begin
    // Authored text has LF in Git. Local CRLF checkout policy must not invalidate a review.
    LText := StringReplace(ReadText(APath), #13#10, #10, [rfReplaceAll]);
    SetLength(LBytes, Length(LText));
    if Length(LText) > 0 then
    begin
      Move(LText[1], LBytes[0], Length(LText));
    end;
    Result := HashBytes(LBytes);
  end
  else
  begin
    Result := HashFile(APath);
  end;
end;

function RequiredText(const AObject: TJSONObject; const AKey: String): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Require((LValue <> nil) and (LValue.JSONType = jtString), 'Missing text: ' + AKey);
  Result := Trim(LValue.AsString);
  Require(Result <> '', 'Empty text: ' + AKey);
end;

function ObjectField(const AObject: TJSONObject; const AKey: String): TJSONObject;
begin
  Require(AObject.Find(AKey) is TJSONObject, 'Missing object: ' + AKey);
  Result := AObject.Objects[AKey];
end;

function ArrayField(const AObject: TJSONObject; const AKey: String): TJSONArray;
begin
  Require(AObject.Find(AKey) is TJSONArray, 'Missing array: ' + AKey);
  Result := AObject.Arrays[AKey];
end;

procedure RequireCanonicalPath(const APath: String);
begin
  Require((APath <> '') and (Pos('\', APath) = 0) and (Pos('//', APath) = 0) and
    (Pos('/../', '/' + APath + '/') = 0) and (Pos('/./', '/' + APath + '/') = 0),
    'Use canonical repository paths: ' + APath);
end;

procedure CheckFeature(const ARoot: String; const AFeature: TJSONObject);
const
  CCategories: array[0..3] of String = (
    'intuitiveness', 'accuracy', 'wowFactor', 'thinkingOutOfTheBox');
var
  LReport: TJSONObject;
  LGrades: TJSONObject;
  LCategory: TJSONObject;
  LFiles: TJSONObject;
  LInputs: TJSONArray;
  LSeen: TStringList;
  LPath: String;
  LGrade: String;
  LDecision: String;
  LKey: String;
  I: Integer;
begin
  LKey := RequiredText(AFeature, 'id');
  RequiredText(AFeature, 'scope');
  if (AFeature.Find('review') = nil) or (AFeature.Find('review').JSONType = jtNull) then
  begin
    raise Exception.Create('Independent critic review is pending');
  end;
  LPath := RequiredText(AFeature, 'review');
  RequireCanonicalPath(LPath);
  Require(Copy(LPath, 1, 8) = 'reviews/', 'Review must be retained under reviews/');
  LReport := LoadJSON(SafeChild(SafeChild(ARoot, 'reviews'), Copy(LPath, 9, MaxInt)));
  LSeen := TStringList.Create;
  try
    LSeen.CaseSensitive := True;
    Require(LReport.Get('schemaVersion', 0) = 1, 'Unsupported review schema');
    Require(RequiredText(LReport, 'feature') = LKey, 'Review belongs to another feature');
    Require(RequiredText(LReport, 'scope') = RequiredText(AFeature, 'scope'),
      'Review scope changed; request a new critic review');
    Require(RequiredText(LReport, 'criticAgent') <> RequiredText(LReport, 'builderAgent'),
      'Builder cannot be its own critic');
    RequiredText(LReport, 'reviewedAt');
    LDecision := RequiredText(LReport, 'decision');
    Require(LDecision = 'pass', 'Critic decision is ' + LDecision);
    LGrades := ObjectField(LReport, 'grades');
    Require(LGrades.Count = Length(CCategories), 'Exactly four category grades are required');
    for I := 0 to High(CCategories) do
    begin
      LCategory := ObjectField(LGrades, CCategories[I]);
      LGrade := RequiredText(LCategory, 'grade');
      RequiredText(LCategory, 'evidence');
      Require((LGrade = 'B+') or (LGrade = 'A-') or (LGrade = 'A'),
        CCategories[I] + ' is ' + LGrade + '; at least B+ is required');
    end;
    Require(ArrayField(LReport, 'blockingFindings').Count = 0,
      'Unresolved blocking findings prevent passing');
    RequiredText(LReport, 'verification');
    LInputs := ArrayField(AFeature, 'inputs');
    Require(LInputs.Count > 0, 'Feature has no declared review inputs');
    LFiles := ObjectField(LReport, 'reviewedFiles');
    Require(LFiles.Count = LInputs.Count, 'Reviewed file set differs from the feature inputs');
    for I := 0 to LInputs.Count - 1 do
    begin
      Require(LInputs[I].JSONType = jtString, 'Review input must be a path');
      LPath := LInputs.Strings[I];
      RequireCanonicalPath(LPath);
      Require(LSeen.IndexOf(LPath) < 0, 'Duplicate review input: ' + LPath);
      LSeen.Add(LPath);
      Require(RequiredText(LFiles, LPath) = ReviewFileHash(SafeChild(ARoot, LPath)),
        'Reviewed file changed: ' + LPath + '; request a new critic review');
    end;
  finally
    LSeen.Free;
    LReport.Free;
  end;
end;

function CheckReviewGate(const ARoot: String; const AMessages: TStrings): Boolean;
var
  LRegistry: TJSONObject;
  LFeatures: TJSONArray;
  LFeature: TJSONObject;
  LSeen: TStringList;
  LId: String;
  I: Integer;
begin
  Result := True;
  LRegistry := LoadJSON(SafeChild(ARoot, 'reviews/features.json'));
  LSeen := TStringList.Create;
  try
    LSeen.CaseSensitive := True;
    Require(LRegistry.Get('schemaVersion', 0) = 1, 'Unsupported feature registry schema');
    LFeatures := ArrayField(LRegistry, 'features');
    Require(LFeatures.Count > 0, 'No features registered for critic review');
    for I := 0 to LFeatures.Count - 1 do
    begin
      Require(LFeatures[I] is TJSONObject, 'Feature must be an object');
      LFeature := LFeatures.Objects[I];
      LId := RequiredText(LFeature, 'id');
      Require(LSeen.IndexOf(LId) < 0, 'Duplicate feature: ' + LId);
      LSeen.Add(LId);
      try
        CheckFeature(ARoot, LFeature);
        AMessages.Add('PASS ' + LId + ': every category is at least B+; reviewed files match');
      except
        on LException: Exception do
        begin
          Result := False;
          AMessages.Add('HOLD ' + LId + ': ' + LException.Message);
        end;
      end;
    end;
  finally
    LSeen.Free;
    LRegistry.Free;
  end;
end;

end.
