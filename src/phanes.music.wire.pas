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

unit phanes.music.wire;

{$mode delphi}
{$H+}

interface

uses
  JS,
  phanes.music.types;

function ReadMusicReferences(const ACorpus: TJSObject): TMusicReferences;
function ReadMusicRequest(const AMessage: TJSObject): TMusicRequest;
function MusicSectionJSON(const ASection: TMusicSection): TJSObject;
function ReadMusicSection(const ASection: TJSObject): TMusicSection;

implementation

uses
  SysUtils;

function ExactInteger(const AValue: JSValue; const AMinimum, AMaximum: Double): Integer;
var
  LValid: Boolean;
begin
  asm
    LValid = Number.isInteger(AValue) && AValue >= AMinimum && AValue <= AMaximum;
  end;
  if not LValid then
  begin
    raise Exception.Create('Expected bounded integer in music message');
  end;
  Result := Integer(AValue);
end;

function ReadMusicReferences(const ACorpus: TJSObject): TMusicReferences;
var
  LReferences: TJSArray;
  LReference: TJSObject;
  LSamples: TJSArray;
  LSample: TJSObject;
  LValues: TJSArray;
  I: Integer;
  J: Integer;
  LLane: Integer;
  LBeat: Integer;
begin
  LReferences := TJSArray(ACorpus['references']);
  if not TJSArray.isArray(LReferences) or (LReferences.Length < 100) or
    (LReferences.Length > 256) then
  begin
    raise Exception.Create('Music corpus needs 100 to 256 references');
  end;
  SetLength(Result, LReferences.Length);
  for I := 0 to LReferences.Length - 1 do
  begin
    LReference := TJSObject(LReferences[I]);
    Result[I].FId := String(LReference['id']);
    Result[I].FTitle := String(LReference['title']);
    LSamples := TJSArray(LReference['samples']);
    if not TJSArray.isArray(LSamples) or (LSamples.Length < 1) or (LSamples.Length > 3) then
    begin
      raise Exception.Create('Music reference needs one to three excerpts');
    end;
    SetLength(Result[I].FSamples, LSamples.Length);
    for J := 0 to LSamples.Length - 1 do
    begin
      LSample := TJSObject(LSamples[J]);
      for LLane := 0 to MusicLaneCount - 1 do
      begin
        LValues := TJSArray(LSample[MusicLaneName(LLane)]);
        if not TJSArray.isArray(LValues) or (LValues.Length <> MusicBeats) then
        begin
          raise Exception.Create('Music excerpt length must equal 32 beats');
        end;
        SetLength(Result[I].FSamples[J][LLane], MusicBeats);
        for LBeat := 0 to MusicBeats - 1 do
        begin
          Result[I].FSamples[J][LLane][LBeat] := ExactInteger(LValues[LBeat], 0, 15);
        end;
      end;
    end;
  end;
end;

function ReadMusicRequest(const AMessage: TJSObject): TMusicRequest;
var
  LLocks: TJSArray;
  LWeights: TJSArray;
  LTotal: Integer;
  I: Integer;
begin
  Result := Default(TMusicRequest);
  Result.FSeed := Cardinal(ExactInteger(AMessage['seed'], 0, $7FFFFFFF));
  Result.FIndex := ExactInteger(AMessage['index'], 0, 1000000);
  Result.FStyle := ExactInteger(AMessage['style'], 0, MusicStyleCount - 1);
  Result.FBlendStyle := ExactInteger(AMessage['blendStyle'], 0, MusicStyleCount - 1);
  Result.FBlend := ExactInteger(AMessage['blend'], 0, 100);
  if isDefined(AMessage['minimumSections']) then
  begin
    Result.FMinimumSections := ExactInteger(AMessage['minimumSections'], 0, 40);
  end;
  if isDefined(AMessage['tempo']) then
  begin
    Result.FTempo := ExactInteger(AMessage['tempo'], 60, 160);
  end;
  if isDefined(AMessage['weights']) then
  begin
    if not TJSArray.isArray(AMessage['weights']) then
    begin
      raise Exception.Create('Expected ten style connection strengths');
    end;
    LWeights := TJSArray(AMessage['weights']);
    if LWeights.Length <> MusicStyleCount then
    begin
      raise Exception.Create('Expected ten style connection strengths');
    end;
    LTotal := 0;
    for I := 0 to MusicStyleCount - 1 do
    begin
      Result.FWeights[I] := ExactInteger(LWeights[I], 0, 100);
      Inc(LTotal, Result.FWeights[I]);
    end;
    if LTotal = 0 then
    begin
      raise Exception.Create('Connect at least one style');
    end;
  end;
  LLocks := TJSArray(AMessage['locks']);
  if not TJSArray.isArray(LLocks) or (LLocks.Length <> MusicLaneCount) then
  begin
    raise Exception.Create('Music needs four lock flags');
  end;
  for I := 0 to MusicLaneCount - 1 do
  begin
    if not isBoolean(LLocks[I]) then
    begin
      raise Exception.Create('Music lock flags must be boolean');
    end;
    Result.FLocks[I] := Boolean(LLocks[I]);
  end;
end;

function ReadMusicSection(const ASection: TJSObject): TMusicSection;
var
  LLanes: TJSArray;
  LValues: TJSArray;
  LFocus: TJSArray;
  LEvents: TJSArray;
  LRow: TJSArray;
  I: Integer;
  J: Integer;
begin
  Result := Default(TMusicSection);
  Result.FIndex := ExactInteger(ASection['index'], 0, 1000000);
  Result.FBpm := Double(ASection['bpm']);
  LLanes := TJSArray(ASection['lanes']);
  LFocus := TJSArray(ASection['focus']);
  LEvents := TJSArray(ASection['events']);
  if not TJSArray.isArray(LLanes) or (LLanes.Length <> MusicLaneCount) or
    not TJSArray.isArray(LFocus) or (LFocus.Length <> MusicLaneCount) or
    not TJSArray.isArray(LEvents) or (LEvents.Length < 1) or (LEvents.Length >= 1024) then
  begin
    raise Exception.Create('Invalid saved music section');
  end;
  for I := 0 to MusicLaneCount - 1 do
  begin
    Result.FFocus[I] := String(LFocus[I]);
    LValues := TJSArray(LLanes[I]);
    if not TJSArray.isArray(LValues) or (LValues.Length <> MusicBeats) then
    begin
      raise Exception.Create('Invalid saved music lane');
    end;
    SetLength(Result.FLanes[I], MusicBeats);
    for J := 0 to MusicBeats - 1 do
    begin
      Result.FLanes[I][J] := ExactInteger(LValues[J], 0, 15);
    end;
  end;
  LValues := TJSArray(ASection['styles']);
  if not TJSArray.isArray(LValues) or (LValues.Length <> 8) then
  begin
    raise Exception.Create('Invalid saved music arrangement');
  end;
  SetLength(Result.FStyles, 8);
  for I := 0 to 7 do
  begin
    Result.FStyles[I] := ExactInteger(LValues[I], 0, MusicStyleCount - 1);
  end;
  SetLength(Result.FEvents, LEvents.Length);
  for I := 0 to LEvents.Length - 1 do
  begin
    LRow := TJSArray(LEvents[I]);
    if not TJSArray.isArray(LRow) or (LRow.Length <> 6) then
    begin
      raise Exception.Create('Invalid saved music event');
    end;
    Result.FEvents[I].FBeat := Double(LRow[0]);
    Result.FEvents[I].FDuration := Double(LRow[1]);
    Result.FEvents[I].FPitch := ExactInteger(LRow[2], 12, 108);
    Result.FEvents[I].FVoice := ExactInteger(LRow[3], 0, 5);
    Result.FEvents[I].FVelocity := Double(LRow[4]);
    Result.FEvents[I].FStyle := ExactInteger(LRow[5], 0, MusicStyleCount - 1);
  end;
end;

function MusicSectionJSON(const ASection: TMusicSection): TJSObject;
var
  LLanes: TJSArray;
  LValues: TJSArray;
  LFocus: TJSArray;
  LEvents: TJSArray;
  LEvent: TMusicEvent;
  LRow: TJSArray;
  I: Integer;
  LValue: Integer;
begin
  Result := TJSObject.new;
  Result['index'] := ASection.FIndex;
  Result['bpm'] := ASection.FBpm;
  LLanes := TJSArray.new;
  LFocus := TJSArray.new;
  for I := 0 to MusicLaneCount - 1 do
  begin
    LValues := TJSArray.new;
    for LValue in ASection.FLanes[I] do
    begin
      LValues.push(LValue);
    end;
    LLanes.push(LValues);
    LFocus.push(ASection.FFocus[I]);
  end;
  Result['lanes'] := LLanes;
  Result['focus'] := LFocus;
  LValues := TJSArray.new;
  for LValue in ASection.FStyles do
  begin
    LValues.push(LValue);
  end;
  Result['styles'] := LValues;
  LEvents := TJSArray.new;
  for LEvent in ASection.FEvents do
  begin
    LRow := TJSArray.new;
    LRow.push(LEvent.FBeat, LEvent.FDuration, LEvent.FPitch, LEvent.FVoice,
      LEvent.FVelocity, LEvent.FStyle);
    LEvents.push(LRow);
  end;
  Result['events'] := LEvents;
end;

end.
