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

unit phanes.terrain.wire;

{$mode delphi}
{$H+}

interface

uses
  phanes.terrain.types;

type
  TTerrainJSONText = {$ifdef PAS2JS}String{$else}UTF8String{$endif};

function TerrainJSON(const AField: TTerrainField): TTerrainJSONText;
function ReadTerrainJSON(const AText: TTerrainJSONText; var AField: TTerrainField;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Math,
  phanes.terrain.validate
  {$ifdef PAS2JS}
  , JS
  {$else}
  , fpjson, jsonparser, jsonscanner
  {$endif}
  ;

const
  TerrainJSONMaximumLength = 262144;
  TerrainJSONMemberCount = 18;

{$ifdef PAS2JS}
type
  TWireValue = JSValue;
  TWireObject = TJSObject;
  TWireArray = TJSArray;
{$else}
type
  TWireValue = TJSONData;
  TWireObject = TJSONObject;
  TWireArray = TJSONArray;
{$endif}

procedure CheckTerrainJSONText(const AText: TTerrainJSONText);
var
  LInString: Boolean;
  LEscaped: Boolean;
  LDepth: Integer;
  LMembers: Integer;
  I: Integer;
begin
  if (Length(AText) = 0) or (Length(AText) > TerrainJSONMaximumLength) then
  begin
    raise Exception.Create('Terrain JSON must contain at most 256 KiB of text.');
  end;
  LInString := False;
  LEscaped := False;
  LDepth := 0;
  LMembers := 0;
  for I := 1 to Length(AText) do
  begin
    if LInString then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if AText[I] = '\' then
      begin
        LEscaped := True;
      end
      else if AText[I] = '"' then
      begin
        LInString := False;
      end;
      Continue;
    end;
    case AText[I] of
      '"':
        begin
          LInString := True;
        end;
      '{', '[':
        begin
          Inc(LDepth);
          if LDepth > 4 then
          begin
            raise Exception.Create('Terrain JSON nesting is too deep.');
          end;
        end;
      '}', ']':
        begin
          Dec(LDepth);
          if LDepth < 0 then
          begin
            raise Exception.Create('Terrain JSON has unmatched delimiters.');
          end;
        end;
      ':':
        begin
          Inc(LMembers);
        end;
      '.', 'e', 'E':
        begin
          { The format uses exact integer tokens. Disallow decimal/exponent
            notation before either parser can round or underflow a token. }
          raise Exception.Create('Terrain numbers require exact integer notation.');
        end;
    end;
  end;
  { All eighteen members are required and individually read below. Counting
    raw colons as well as parsed members rejects duplicate-key ambiguity
    between parsers that retain duplicates and parsers that overwrite them.
    Nested object members are never valid in this flat versioned contract. }
  if LInString or (LDepth <> 0) or (LMembers <> TerrainJSONMemberCount) then
  begin
    raise Exception.Create('Terrain JSON requires exactly eighteen unique members.');
  end;
end;

function FieldValue(const AObject: TWireObject; const AName: String): TWireValue;
begin
  {$ifdef PAS2JS}
  Result := AObject[AName];
  {$else}
  Result := AObject.Find(AName);
  {$endif}
end;

function NumberValue(const AValue: TWireValue; const AMinimum, AMaximum: Double): Double;
begin
  {$ifdef PAS2JS}
  if not isInteger(AValue) then
  {$else}
  if (AValue = nil) or (AValue.JSONType <> jtNumber) then
  {$endif}
  begin
    raise Exception.Create('Terrain values must be integers.');
  end;
  {$ifdef PAS2JS}
  Result := Double(AValue);
  {$else}
  Result := AValue.AsFloat;
  {$endif}
  if IsNan(Result) or IsInfinite(Result) or (Frac(Result) <> 0) or
    (Result < AMinimum) or (Result > AMaximum) then
  begin
    raise Exception.Create('Terrain integer is outside the supported range.');
  end;
end;

function IntegerField(const AObject: TWireObject; const AName: String;
  const AMinimum, AMaximum: Double): Double;
begin
  Result := NumberValue(FieldValue(AObject, AName), AMinimum, AMaximum);
end;

function TextField(const AObject: TWireObject; const AName: String): String;
var
  LValue: TWireValue;
begin
  LValue := FieldValue(AObject, AName);
  {$ifdef PAS2JS}
  if not isString(LValue) then
  {$else}
  if (LValue = nil) or (LValue.JSONType <> jtString) then
  {$endif}
  begin
    raise Exception.Create('Terrain metadata must be text.');
  end;
  {$ifdef PAS2JS}
  Result := String(LValue);
  {$else}
  Result := LValue.AsString;
  {$endif}
end;

function ReadTerrainJSON(const AText: TTerrainJSONText; var AField: TTerrainField;
  out AReason: String): Boolean;
var
  LParsed: TWireValue;
  LRoot: TWireObject;
  LValues: TWireArray;
  LValue: TWireValue;
  LCandidate: TTerrainField;
  LCount: Integer;
  I: Integer;
  {$ifndef PAS2JS}
  LParser: TJSONParser;
  {$endif}
begin
  Result := False;
  AReason := '';
  {$ifndef PAS2JS}
  LParsed := nil;
  {$endif}
  try
    try
      CheckTerrainJSONText(AText);
      {$ifdef PAS2JS}
      LParsed := TJSJSON.parse(AText);
      if not isObject(LParsed) or (LParsed = nil) or isArray(LParsed) then
      {$else}
      LParser := TJSONParser.Create(AText, [joUTF8, joStrict]);
      try
        LParsed := LParser.Parse;
      finally
        LParser.Free;
      end;
      if (LParsed = nil) or (LParsed.JSONType <> jtObject) then
      {$endif}
      begin
        raise Exception.Create('Terrain JSON must be an object.');
      end;
      LRoot := TWireObject(LParsed);
      {$ifdef PAS2JS}
      LCount := Length(TJSObject.keys(LRoot));
      {$else}
      LCount := LRoot.Count;
      {$endif}
      if LCount <> TerrainJSONMemberCount then
      begin
        raise Exception.Create('Terrain JSON member set is incomplete or ambiguous.');
      end;
      if (TextField(LRoot, 'format') <> 'phanes.terrain') or
        (TextField(LRoot, 'units') <> 'millimetres') or
        (TextField(LRoot, 'triangulation') <> 'x-z') then
      begin
        raise Exception.Create('Unsupported terrain format, units or triangulation.');
      end;
      LCandidate := Default(TTerrainField);
      LCandidate.FSpec.FVersion := Trunc(IntegerField(LRoot, 'version', 1, 1));
      LCandidate.FSpec.FColumns := Trunc(IntegerField(LRoot, 'columns', 2, 97));
      LCandidate.FSpec.FRows := Trunc(IntegerField(LRoot, 'rows', 2, 97));
      LCandidate.FSpec.FOriginX := Trunc(IntegerField(LRoot, 'originX', -4096000, 4096000));
      LCandidate.FSpec.FOriginZ := Trunc(IntegerField(LRoot, 'originZ', -4096000, 4096000));
      LCandidate.FSpec.FSpacing := Trunc(IntegerField(LRoot, 'spacing', 250, 32000));
      LCandidate.FSpec.FLevelStep := Trunc(IntegerField(LRoot, 'levelStep', 1, 8000));
      LCandidate.FSpec.FMinimumLevel := Trunc(IntegerField(LRoot, 'minimumLevel', -1024, 1024));
      LCandidate.FSpec.FMaximumLevel := Trunc(IntegerField(LRoot, 'maximumLevel', -1024, 1024));
      LCandidate.FSpec.FMaximumRise := Trunc(IntegerField(LRoot, 'maximumRise', 0, 64));
      LCandidate.FSeed := Cardinal(Trunc(IntegerField(LRoot, 'seed', 0, 4294967295)));
      LCandidate.FDecisions := Trunc(IntegerField(LRoot, 'decisions', 0, High(Integer)));
      LCandidate.FPropagations := Trunc(IntegerField(LRoot, 'propagations', 0, High(Integer)));
      LCandidate.FBacktracks := Trunc(IntegerField(LRoot, 'backtracks', 0, High(Integer)));
      if not ValidateTerrainSpec(LCandidate.FSpec, AReason) then
      begin
        Exit;
      end;
      LValue := FieldValue(LRoot, 'levels');
      {$ifdef PAS2JS}
      if not isArray(LValue) then
      {$else}
      if (LValue = nil) or (LValue.JSONType <> jtArray) then
      {$endif}
      begin
        raise Exception.Create('Terrain levels must be an array.');
      end;
      LValues := TWireArray(LValue);
      {$ifdef PAS2JS}
      LCount := LValues.Length;
      {$else}
      LCount := LValues.Count;
      {$endif}
      if LCount <> LCandidate.FSpec.FColumns * LCandidate.FSpec.FRows then
      begin
        raise Exception.Create('Terrain levels do not match the saved vertex frame.');
      end;
      SetLength(LCandidate.FLevels, LCount);
      for I := 0 to LCount - 1 do
      begin
        LCandidate.FLevels[I] := Trunc(NumberValue(LValues[I],
          LCandidate.FSpec.FMinimumLevel, LCandidate.FSpec.FMaximumLevel));
      end;
      if not ValidateTerrainField(LCandidate, AReason) then
      begin
        Exit;
      end;
      AField := LCandidate;
      Result := True;
    except
      on LException: Exception do
      begin
        AReason := LException.Message;
      end;
      {$ifdef PAS2JS}
      else
      begin
        AReason := 'Malformed terrain JSON.';
      end;
      {$endif}
    end;
  finally
    {$ifndef PAS2JS}
    LParsed.Free;
    {$endif}
  end;
end;

function TerrainJSON(const AField: TTerrainField): TTerrainJSONText;
var
  LReason: String;
  I: Integer;
begin
  if not ValidateTerrainField(AField, LReason) then
  begin
    raise Exception.Create('Cannot serialize terrain: ' + LReason);
  end;
  { All strings are fixed ASCII metadata; all variable values are admitted
    integers. This canonical writer is identical on native, WASM and pas2js. }
  Result := '{"format":"phanes.terrain","version":1,"units":"millimetres",' +
    '"triangulation":"x-z","columns":' + IntToStr(AField.FSpec.FColumns) +
    ',"rows":' + IntToStr(AField.FSpec.FRows) +
    ',"originX":' + IntToStr(AField.FSpec.FOriginX) +
    ',"originZ":' + IntToStr(AField.FSpec.FOriginZ) +
    ',"spacing":' + IntToStr(AField.FSpec.FSpacing) +
    ',"levelStep":' + IntToStr(AField.FSpec.FLevelStep) +
    ',"minimumLevel":' + IntToStr(AField.FSpec.FMinimumLevel) +
    ',"maximumLevel":' + IntToStr(AField.FSpec.FMaximumLevel) +
    ',"maximumRise":' + IntToStr(AField.FSpec.FMaximumRise) +
    ',"seed":' + IntToStr(AField.FSeed) +
    ',"decisions":' + IntToStr(AField.FDecisions) +
    ',"propagations":' + IntToStr(AField.FPropagations) +
    ',"backtracks":' + IntToStr(AField.FBacktracks) + ',"levels":[';
  for I := 0 to High(AField.FLevels) do
  begin
    if I > 0 then
    begin
      Result := Result + ',';
    end;
    Result := Result + IntToStr(AField.FLevels[I]);
  end;
  Result := Result + ']}';
end;

end.
