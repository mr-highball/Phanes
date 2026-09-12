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
unit phanes.composition.wire;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types;

type
  TCompositionJSONText = {$ifdef PAS2JS}String{$else}UTF8String{$endif};

{ Version 2 adds explicit container volumes. Legacy documents without extents
  still serialize as version 1. Catalog geometry and generation requests retain
  separate contracts; this is not a world snapshot. }
function CompositionJSON(const ADocument: TCompositionDocument): TCompositionJSONText;
function ReadCompositionJSON(const AText: TCompositionJSONText; var ADocument: TCompositionDocument;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Classes,
  Math,
  phanes.composition.document
  {$ifdef PAS2JS}
  , JS
  {$else}
  , fpjson, jsonparser, jsonscanner
  {$endif}
  ;

type
  {$ifdef PAS2JS}
  TWireObject = TJSObject;
  TWireArray = TJSArray;
  TWireValue = JSValue;
  {$else}
  TWireObject = TJSONObject;
  TWireArray = TJSONArray;
  TWireValue = TJSONData;
  {$endif}

function ObjectValue(const AValue: TWireValue): TWireObject;
begin
  {$ifdef PAS2JS}
  if not isObject(AValue) or (AValue = nil) or isArray(AValue) then
  {$else}
  if (AValue = nil) or (AValue.JSONType <> jtObject) then
  {$endif}
  begin
    raise Exception.Create('Expected a composition object.');
  end;
  Result := TWireObject(AValue);
end;

function FieldValue(const AObject: TWireObject; const AKey: String): TWireValue;
begin
  {$ifdef PAS2JS}
  Result := AObject[AKey];
  {$else}
  Result := AObject.Find(AKey);
  {$endif}
end;

function HasField(const AObject: TWireObject; const AKey: String): Boolean;
begin
  {$ifdef PAS2JS}
  Result := jsTypeOf(AObject[AKey]) <> 'undefined';
  {$else}
  Result := AObject.Find(AKey) <> nil;
  {$endif}
end;

function TextField(const AObject: TWireObject; const AKey: String;
  const AMaximum: Integer): UnicodeString;
var
  LValue: TWireValue;
begin
  LValue := FieldValue(AObject, AKey);
  {$ifdef PAS2JS}
  if not isString(LValue) then
  {$else}
  if (LValue = nil) or (LValue.JSONType <> jtString) then
  {$endif}
  begin
    raise Exception.Create('Expected text for ' + AKey);
  end;
  {$ifdef PAS2JS}
  Result := String(LValue);
  {$else}
  Result := UTF8Decode(LValue.AsString);
  {$endif}
  if Length(Result) > AMaximum then
  begin
    raise Exception.Create('Text is too long for ' + AKey);
  end;
end;

function IntegerField(const AObject: TWireObject; const AKey: String;
  const AMinimum, AMaximum: Double): Double;
var
  LValue: TWireValue;
begin
  LValue := FieldValue(AObject, AKey);
  {$ifdef PAS2JS}
  if not isInteger(LValue) then
  {$else}
  if (LValue = nil) or (LValue.JSONType <> jtNumber) then
  {$endif}
  begin
    raise Exception.Create('Expected an integer for ' + AKey);
  end;
  {$ifdef PAS2JS}
  Result := Double(LValue);
  {$else}
  Result := LValue.AsFloat;
  {$endif}
  if IsNan(Result) or IsInfinite(Result) or (Result < AMinimum) or
    (Result > AMaximum) or (Frac(Result) <> 0) then
  begin
    raise Exception.Create('Invalid integer for ' + AKey);
  end;
end;

function CodeField(const AObject: TWireObject; const AKey: String;
  const AMaximum: Integer): String;
var
  LText: UnicodeString;
  I: Integer;
begin
  LText := TextField(AObject, AKey, AMaximum);
  for I := 1 to Length(LText) do
  begin
    if Ord(LText[I]) > 127 then
    begin
      raise Exception.Create('Semantic codes must be ASCII: ' + AKey);
    end;
  end;
  Result := String(LText);
end;

function BooleanField(const AObject: TWireObject; const AKey: String): Boolean;
var
  LValue: TWireValue;
begin
  LValue := FieldValue(AObject, AKey);
  {$ifdef PAS2JS}
  if not isBoolean(LValue) then
  {$else}
  if (LValue = nil) or (LValue.JSONType <> jtBoolean) then
  {$endif}
  begin
    raise Exception.Create('Expected true or false for ' + AKey);
  end;
  {$ifdef PAS2JS}
  Result := Boolean(LValue);
  {$else}
  Result := LValue.AsBoolean;
  {$endif}
end;

procedure TextMember(const AObject: TWireObject; const AKey: String; const AValue: UnicodeString);
var
  I: Integer;
begin
  if AKey <> 'name' then
  begin
    for I := 1 to Length(AValue) do
    begin
      if Ord(AValue[I]) > 127 then
      begin
        raise Exception.Create('Semantic codes must be ASCII: ' + AKey);
      end;
    end;
  end;
  {$ifdef PAS2JS}
  AObject[AKey] := AValue;
  {$else}
  AObject.Add(AKey, UTF8Encode(AValue));
  {$endif}
end;

procedure IntegerMember(const AObject: TWireObject; const AKey: String; const AValue: Double);
begin
  {$ifdef PAS2JS}
  AObject[AKey] := AValue;
  {$else}
  AObject.Add(AKey, Int64(Trunc(AValue)));
  {$endif}
end;

function NewObject: TWireObject;
begin
  {$ifdef PAS2JS}
  Result := TJSObject.new;
  {$else}
  Result := TJSONObject.Create;
  {$endif}
end;

function WireSize(const AText: TCompositionJSONText): Integer;
{$ifdef PAS2JS}
var
  I: Integer;
  LCode: Integer;
{$endif}
begin
  {$ifdef PAS2JS}
  Result := 0;
  I := 1;
  while (I <= Length(AText)) and (Result <= 16777216) do
  begin
    LCode := Ord(AText[I]);
    if LCode < $80 then
    begin
      Inc(Result);
    end
    else if LCode < $800 then
    begin
      Inc(Result, 2);
    end
    else if (LCode >= $D800) and (LCode <= $DBFF) and (I < Length(AText)) and
      (Ord(AText[I + 1]) >= $DC00) and (Ord(AText[I + 1]) <= $DFFF) then
    begin
      Inc(Result, 4);
      Inc(I);
    end
    else
    begin
      Inc(Result, 3);
    end;
    Inc(I);
  end;
  {$else}
  Result := Length(AText);
  {$endif}
end;

procedure CheckUnicodeScalars(const AText: UnicodeString);
var
  I: Integer;
  LCode: Integer;
begin
  I := 1;
  while I <= Length(AText) do
  begin
    LCode := Ord(AText[I]);
    if (LCode >= $D800) and (LCode <= $DBFF) then
    begin
      Inc(I);
      if (I > Length(AText)) or (Ord(AText[I]) < $DC00) or (Ord(AText[I]) > $DFFF) then
      begin
        raise Exception.Create('Unpaired Unicode surrogate in composition text.');
      end;
    end
    else if (LCode >= $DC00) and (LCode <= $DFFF) then
    begin
      raise Exception.Create('Unpaired Unicode surrogate in composition text.');
    end;
    Inc(I);
  end;
end;

procedure CheckJSONUnicode(const AText: TCompositionJSONText);
var
  LText: UnicodeString;
  LQuoted: Boolean;
  LPendingHigh: Boolean;
  LCode: Integer;
  LDigit: Integer;
  I: Integer;
  J: Integer;
begin
  {$ifdef PAS2JS}
  LText := AText;
  {$else}
  LText := UTF8Decode(AText);
  if UTF8Encode(LText) <> AText then
  begin
    raise Exception.Create('Composition input must be valid UTF-8.');
  end;
  {$endif}
  CheckUnicodeScalars(LText);
  LQuoted := False;
  LPendingHigh := False;
  I := 1;
  { Check escaped UTF-16 before JSON parsing: the native parser may replace
    an isolated low surrogate with a question mark, hiding the invalid input. }
  while I <= Length(LText) do
  begin
    if not LQuoted then
    begin
      LQuoted := LText[I] = '"';
    end
    else if LText[I] = '"' then
    begin
      if LPendingHigh then
      begin
        raise Exception.Create('Unpaired Unicode escape in composition text.');
      end;
      LQuoted := False;
    end
    else
    begin
      LCode := Ord(LText[I]);
      if LText[I] = '\' then
      begin
        Inc(I);
        if I > Length(LText) then
        begin
          raise Exception.Create('Incomplete JSON escape.');
        end;
        LCode := Ord(LText[I]);
        if LText[I] = 'u' then
        begin
          if I + 4 > Length(LText) then
          begin
            raise Exception.Create('Incomplete Unicode escape.');
          end;
          LCode := 0;
          for J := 1 to 4 do
          begin
            Inc(I);
            LDigit := Pos(LowerCase(String(LText[I])), '0123456789abcdef') - 1;
            if LDigit < 0 then
            begin
              raise Exception.Create('Invalid Unicode escape.');
            end;
            LCode := LCode * 16 + LDigit;
          end;
        end;
      end;
      if LPendingHigh then
      begin
        if (LCode < $DC00) or (LCode > $DFFF) then
        begin
          raise Exception.Create('Unpaired Unicode escape in composition text.');
        end;
        LPendingHigh := False;
      end
      else if (LCode >= $DC00) and (LCode <= $DFFF) then
      begin
        raise Exception.Create('Unpaired Unicode escape in composition text.');
      end
      else
      begin
        LPendingHigh := (LCode >= $D800) and (LCode <= $DBFF);
      end;
    end;
    Inc(I);
  end;
end;

function CompositionJSON(const ADocument: TCompositionDocument): TCompositionJSONText;
const
  CKindNames: array[TCompositionKind] of String = ('container', 'surface', 'object');
var
  LRoot: TWireObject;
  LNodes: TWireArray;
  LObject: TWireObject;
  LNode: TCompositionNode;
  LReason: String;
  LVersion: Integer;
  I: Integer;
begin
  if not ValidateComposition(ADocument, LReason) or (Length(ADocument.FNodes) > 65536) then
  begin
    raise Exception.Create('Cannot save composition: ' + LReason);
  end;
  LVersion := 1;
  for I := 0 to High(ADocument.FNodes) do
  begin
    if HasCompositionExtent(ADocument.FNodes[I]) then
    begin
      LVersion := 2;
      Break;
    end;
  end;
  LRoot := NewObject;
  try
    TextMember(LRoot, 'format', 'phanes.composition');
    IntegerMember(LRoot, 'version', LVersion);
    TextMember(LRoot, 'units', 'millimetres');
    IntegerMember(LRoot, 'revision', ADocument.FRevision);
    {$ifdef PAS2JS}
    LNodes := TJSArray.new;
    LRoot['nodes'] := LNodes;
    {$else}
    LNodes := TJSONArray.Create;
    LRoot.Add('nodes', LNodes);
    {$endif}
    for I := 0 to High(ADocument.FNodes) do
    begin
      LNode := ADocument.FNodes[I];
      CheckUnicodeScalars(LNode.FName);
      if (Length(LNode.FName) > 4096) or (Length(LNode.FRole) > 256) or
        (Length(LNode.FAssetId) > 512) then
      begin
        raise Exception.Create('Cannot save oversized composition metadata: ' + LNode.FId);
      end;
      LObject := NewObject;
      {$ifdef PAS2JS}
      LNodes.Push(LObject);
      {$else}
      LNodes.Add(LObject);
      {$endif}
      TextMember(LObject, 'id', UnicodeString(LNode.FId));
      TextMember(LObject, 'parent', UnicodeString(LNode.FParentId));
      TextMember(LObject, 'support', UnicodeString(LNode.FSupportId));
      TextMember(LObject, 'name', LNode.FName);
      TextMember(LObject, 'role', UnicodeString(LNode.FRole));
      TextMember(LObject, 'asset', UnicodeString(LNode.FAssetId));
      TextMember(LObject, 'kind', UnicodeString(CKindNames[LNode.FKind]));
      IntegerMember(LObject, 'x', LNode.FX);
      IntegerMember(LObject, 'y', LNode.FY);
      IntegerMember(LObject, 'z', LNode.FZ);
      IntegerMember(LObject, 'quarterTurn', LNode.FQuarterTurn);
      if LVersion = 2 then
      begin
        IntegerMember(LObject, 'width', LNode.FWidth);
        IntegerMember(LObject, 'depth', LNode.FDepth);
        IntegerMember(LObject, 'height', LNode.FHeight);
      end;
      IntegerMember(LObject, 'seed', LNode.FSeed);
      {$ifdef PAS2JS}
      LObject['locked'] := LNode.FLocked;
      {$else}
      LObject.Add('locked', LNode.FLocked);
      {$endif}
    end;
    {$ifdef PAS2JS}
    Result := TJSJSON.stringify(LRoot);
    {$else}
    Result := LRoot.AsJSON;
    {$endif}
    if WireSize(Result) > 16777216 then
    begin
      raise Exception.Create('Composition exceeds the current save size limit.');
    end;
  finally
    {$ifndef PAS2JS}
    LRoot.Free;
    {$endif}
  end;
end;

procedure CheckInputSizeAndDepth(const AText: TCompositionJSONText);
var
  LQuoted: Boolean;
  LEscaped: Boolean;
  LDepth: Integer;
  LKeyStart: Integer;
  LKey: String;
  LKeys: array[1..16] of TStringList;
  LExpectKey: array[1..16] of Boolean;
  LIsKey: Boolean;
  I: Integer;

  function DecodeKey(const AQuoted: TCompositionJSONText): String;
  var
    LText: UnicodeString;
    J: Integer;
    {$ifndef PAS2JS}
    LData: TJSONData;
    {$endif}
  begin
    {$ifdef PAS2JS}
    LText := String(TJSJSON.parse(AQuoted));
    {$else}
    LData := GetJSON(AQuoted, True);
    try
      LText := UTF8Decode(LData.AsString);
    finally
      LData.Free;
    end;
    {$endif}
    for J := 1 to Length(LText) do
    begin
      if Ord(LText[J]) > 127 then
      begin
        raise Exception.Create('Composition field names must be ASCII.');
      end;
    end;
    Result := String(LText);
  end;
begin
  if (Length(AText) = 0) or (WireSize(AText) > 16777216) then
  begin
    raise Exception.Create('Composition text is empty or exceeds the current size limit.');
  end;
  CheckJSONUnicode(AText);
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  LIsKey := False;
  LKeyStart := 0;
  for I := 1 to 16 do
  begin
    LKeys[I] := nil;
    LExpectKey[I] := False;
  end;
  try
    for I := 1 to Length(AText) do
    begin
      if LQuoted then
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
          LQuoted := False;
          if LIsKey then
          begin
            LKey := DecodeKey(Copy(AText, LKeyStart, I - LKeyStart + 1));
            if (LKeys[LDepth].Count >= 64) or (LKeys[LDepth].IndexOf(LKey) >= 0) then
            begin
              raise Exception.Create('Duplicate or excessive composition object fields.');
            end;
            LKeys[LDepth].Add(LKey);
            LExpectKey[LDepth] := False;
          end;
        end;
      end
      else if (LDepth > 0) and LExpectKey[LDepth] and
        not (AText[I] in [' ', #9, #10, #13, '"', '}']) then
      begin
        raise Exception.Create('Composition field names must be quoted.');
      end
      else if AText[I] = '"' then
      begin
        LQuoted := True;
        LKeyStart := I;
        LIsKey := (LDepth > 0) and LExpectKey[LDepth];
      end
      else if AText[I] in ['{', '['] then
      begin
        Inc(LDepth);
        if LDepth > 16 then
        begin
          raise Exception.Create('Composition JSON nesting exceeds the format limit.');
        end;
        LExpectKey[LDepth] := AText[I] = '{';
        if LExpectKey[LDepth] then
        begin
          LKeys[LDepth] := TStringList.Create;
          LKeys[LDepth].CaseSensitive := True;
          LKeys[LDepth].Sorted := True;
        end;
      end
      else if AText[I] in ['}', ']'] then
      begin
        if LDepth <= 0 then
        begin
          raise Exception.Create('Unbalanced composition JSON.');
        end;
        LKeys[LDepth].Free;
        LKeys[LDepth] := nil;
        LExpectKey[LDepth] := False;
        Dec(LDepth);
      end
      else if (AText[I] = ',') and (LDepth > 0) and (LKeys[LDepth] <> nil) then
      begin
        LExpectKey[LDepth] := True;
      end;
    end;
  finally
    for I := 1 to 16 do
    begin
      LKeys[I].Free;
    end;
  end;
end;

function ReadCompositionJSON(const AText: TCompositionJSONText; var ADocument: TCompositionDocument;
  out AReason: String): Boolean;
var
  LParsed: TWireValue;
  LRoot: TWireObject;
  LNodes: TWireArray;
  LObject: TWireObject;
  LValue: TWireValue;
  LCandidate: TCompositionDocument;
  LKind: String;
  LCount: Integer;
  LVersion: Integer;
  {$ifndef PAS2JS}
  LParser: TJSONParser;
  {$endif}
  I: Integer;
begin
  Result := False;
  AReason := '';
  {$ifndef PAS2JS}
  LParsed := nil;
  {$endif}
  try
    try
      CheckInputSizeAndDepth(AText);
      {$ifdef PAS2JS}
      LParsed := TJSJSON.parse(AText);
      {$else}
      LParser := TJSONParser.Create(AText, [joUTF8, joStrict]);
      try
        LParsed := LParser.Parse;
      finally
        LParser.Free;
      end;
      {$endif}
      LRoot := ObjectValue(LParsed);
      LVersion := Trunc(IntegerField(LRoot, 'version', 1, 2));
      if (TextField(LRoot, 'format', 64) <> 'phanes.composition') or
        (TextField(LRoot, 'units', 32) <> 'millimetres') then
      begin
        raise Exception.Create('Unsupported composition format, version or units.');
      end;
      LCandidate := Default(TCompositionDocument);
      LCandidate.FRevision := Trunc(IntegerField(LRoot, 'revision', 0, High(Integer)));
      LValue := FieldValue(LRoot, 'nodes');
      {$ifdef PAS2JS}
      if not isArray(LValue) then
      {$else}
      if (LValue = nil) or (LValue.JSONType <> jtArray) then
      {$endif}
      begin
        raise Exception.Create('Composition nodes must be an array.');
      end;
      LNodes := TWireArray(LValue);
      {$ifdef PAS2JS}
      LCount := LNodes.Length;
      {$else}
      LCount := LNodes.Count;
      {$endif}
      if (LCount < 1) or (LCount > 65536) then
      begin
        raise Exception.Create('Composition node count is outside the supported range.');
      end;
      SetLength(LCandidate.FNodes, LCount);
      for I := 0 to LCount - 1 do
      begin
        LObject := ObjectValue(LNodes[I]);
        LCandidate.FNodes[I].FId := CodeField(LObject, 'id', 128);
        LCandidate.FNodes[I].FParentId := CodeField(LObject, 'parent', 128);
        LCandidate.FNodes[I].FSupportId := CodeField(LObject, 'support', 128);
        LCandidate.FNodes[I].FName := TextField(LObject, 'name', 4096);
        LCandidate.FNodes[I].FRole := CodeField(LObject, 'role', 256);
        LCandidate.FNodes[I].FAssetId := CodeField(LObject, 'asset', 512);
        LKind := CodeField(LObject, 'kind', 16);
        if LKind = 'container' then
        begin
          LCandidate.FNodes[I].FKind := ckContainer;
        end
        else if LKind = 'surface' then
        begin
          LCandidate.FNodes[I].FKind := ckSurface;
        end
        else if LKind = 'object' then
        begin
          LCandidate.FNodes[I].FKind := ckObject;
        end
        else
        begin
          raise Exception.Create('Unknown composition node kind.');
        end;
        LCandidate.FNodes[I].FX := Trunc(IntegerField(LObject, 'x', Low(Integer), High(Integer)));
        LCandidate.FNodes[I].FY := Trunc(IntegerField(LObject, 'y', Low(Integer), High(Integer)));
        LCandidate.FNodes[I].FZ := Trunc(IntegerField(LObject, 'z', Low(Integer), High(Integer)));
        LCandidate.FNodes[I].FQuarterTurn := Trunc(IntegerField(LObject, 'quarterTurn', 0, 3));
        if LVersion = 2 then
        begin
          LCandidate.FNodes[I].FWidth := Trunc(IntegerField(LObject, 'width', 0, High(Integer)));
          LCandidate.FNodes[I].FDepth := Trunc(IntegerField(LObject, 'depth', 0, High(Integer)));
          LCandidate.FNodes[I].FHeight := Trunc(IntegerField(LObject, 'height', 0, High(Integer)));
        end
        else if HasField(LObject, 'width') or HasField(LObject, 'depth') or
          HasField(LObject, 'height') then
        begin
          raise Exception.Create('Explicit container extents require composition version 2.');
        end;
        LCandidate.FNodes[I].FSeed := Trunc(IntegerField(LObject, 'seed', 0, 4294967295));
        LCandidate.FNodes[I].FLocked := BooleanField(LObject, 'locked');
      end;
      if not ValidateComposition(LCandidate, AReason) then
      begin
        Exit;
      end;
      ADocument := LCandidate;
      Result := True;
    except
      on LException: Exception do
      begin
        AReason := LException.Message;
      end;
      {$ifdef PAS2JS}
      else
      begin
        AReason := 'Malformed composition JSON.';
      end;
      {$endif}
    end;
  finally
    {$ifndef PAS2JS}
    LParsed.Free;
    {$endif}
  end;
end;

end.
