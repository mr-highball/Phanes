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

unit phanes.tools.midi;

{$mode delphi}
{$H+}

interface

uses
  SysUtils,
  FPJSON;

type
  TMidiNote = record
    FStart: Int64;
    FStop: Int64;
    FPitch: Integer;
    FVelocity: Integer;
  end;

  TMidiNotes = array of TMidiNote;

  TMidiScore = record
    FPpq: Integer;
    FNotes: TMidiNotes;
  end;

function ReadMidi(const ABytes: TBytes): TMidiScore;
function ScoreIdentity(const AScore: TMidiScore): String;
function ExtractSamples(const AScore: TMidiScore): TJSONObject;

implementation

uses
  Classes,
  Math,
  phanes.tools.files;

type
  TNoteIndices = array of Integer;

  TMidiReader = class
  private
    FBytes: TBytes;
    FOffset: Integer;
    FEnd: Integer;
    FScore: TMidiScore;
    function ReadByte: Byte;
    function Big16: Word;
    function Big32: Cardinal;
    function VariableInteger: Cardinal;
    procedure ReadTrack;
  public
    function Run(const ABytes: TBytes): TMidiScore;
  end;

function TMidiReader.ReadByte: Byte;
begin
  Require(FOffset < FEnd, 'Truncated MIDI event');
  Result := FBytes[FOffset];
  Inc(FOffset);
end;

function TMidiReader.Big16: Word;
begin
  Result := ReadByte;
  Result := (Result shl 8) or ReadByte;
end;

function TMidiReader.Big32: Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 3 do
  begin
    Result := (Result shl 8) or ReadByte;
  end;
end;

function TMidiReader.VariableInteger: Cardinal;
var
  I: Integer;
  LByte: Byte;
begin
  Result := 0;
  for I := 0 to 3 do
  begin
    LByte := ReadByte;
    Result := (Result shl 7) or (LByte and 127);
    if LByte < 128 then
    begin
      Exit;
    end;
  end;
  raise Exception.Create('Oversized MIDI variable integer');
end;

procedure TMidiReader.ReadTrack;
var
  LLength: Cardinal;
  LTick: Int64;
  LRunning: Byte;
  LStatus: Byte;
  LKey: Byte;
  LValue: Byte;
  LKind: Integer;
  LChannel: Integer;
  LSize: Cardinal;
  LIndex: Integer;
  LActive: array[0..15, 0..127] of TNoteIndices;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  FEnd := Length(FBytes);
  Require(Big32 = $4D54726B, 'Missing MIDI track header');
  LLength := Big32;
  Require(LLength <= Cardinal(FEnd - FOffset), 'Truncated MIDI track');
  FEnd := FOffset + Integer(LLength);
  LTick := 0;
  LRunning := 0;
  while FOffset < FEnd do
  begin
    Inc(LTick, VariableInteger);
    Require(LTick <= 1000000000000, 'MIDI time exceeds supported extent');
    LStatus := ReadByte;
    if LStatus < 128 then
    begin
      Require(LRunning <> 0, 'MIDI running status is missing');
      Dec(FOffset);
      LStatus := LRunning;
    end
    else if LStatus < 240 then
    begin
      LRunning := LStatus;
    end;
    if LStatus = 255 then
    begin
      ReadByte;
      LSize := VariableInteger;
      Require(LSize <= Cardinal(FEnd - FOffset), 'Truncated MIDI meta event');
      Inc(FOffset, Integer(LSize));
    end
    else if (LStatus = 240) or (LStatus = 247) then
    begin
      LSize := VariableInteger;
      Require(LSize <= Cardinal(FEnd - FOffset), 'Truncated MIDI system event');
      Inc(FOffset, Integer(LSize));
      LRunning := 0;
    end
    else if (LStatus >= 128) and (LStatus < 240) then
    begin
      LKind := LStatus shr 4;
      LChannel := LStatus and 15;
      LKey := ReadByte;
      LValue := 0;
      if (LKind <> 12) and (LKind <> 13) then
      begin
        LValue := ReadByte;
      end;
      Require((LKey < 128) and (LValue < 128), 'Invalid MIDI channel data');
      if (LChannel <> 9) and (LKind = 9) and (LValue > 0) then
      begin
        LIndex := Length(FScore.FNotes);
        Require(LIndex < 200000, 'MIDI exceeds 200000 note gates');
        SetLength(FScore.FNotes, LIndex + 1);
        FScore.FNotes[LIndex].FStart := LTick;
        FScore.FNotes[LIndex].FStop := 0;
        FScore.FNotes[LIndex].FPitch := LKey;
        FScore.FNotes[LIndex].FVelocity := LValue;
        I := Length(LActive[LChannel, LKey]);
        SetLength(LActive[LChannel, LKey], I + 1);
        LActive[LChannel, LKey][I] := LIndex;
      end
      else if (LChannel <> 9) and ((LKind = 8) or ((LKind = 9) and (LValue = 0))) then
      begin
        I := Length(LActive[LChannel, LKey]);
        if I > 0 then
        begin
          FScore.FNotes[LActive[LChannel, LKey][0]].FStop := LTick;
          for J := 1 to I - 1 do
          begin
            LActive[LChannel, LKey][J - 1] := LActive[LChannel, LKey][J];
          end;
          SetLength(LActive[LChannel, LKey], I - 1);
        end;
      end;
    end
    else
    begin
      raise Exception.Create('Unsupported MIDI event');
    end;
  end;
  for I := 0 to 15 do
  begin
    for J := 0 to 127 do
    begin
      for K in LActive[I, J] do
      begin
        FScore.FNotes[K].FStop := LTick;
      end;
    end;
  end;
end;

function TMidiReader.Run(const ABytes: TBytes): TMidiScore;
var
  LHeaderLength: Cardinal;
  LTracks: Integer;
  LNote: TMidiNote;
  LCount: Integer;
  I: Integer;
begin
  FBytes := ABytes;
  FOffset := 0;
  FEnd := Length(FBytes);
  Require(Big32 = $4D546864, 'Missing MIDI header');
  LHeaderLength := Big32;
  Require((LHeaderLength >= 6) and (LHeaderLength <= Cardinal(FEnd - FOffset)),
    'Invalid MIDI header length');
  Require(Big16 <= 1, 'Only MIDI formats 0/1 are supported');
  LTracks := Big16;
  FScore.FPpq := Big16;
  Require((LTracks > 0) and (FScore.FPpq > 0) and (FScore.FPpq < 32768),
    'MIDI requires tracks and a positive PPQ timebase');
  FOffset := 8 + Integer(LHeaderLength);
  for I := 0 to LTracks - 1 do
  begin
    ReadTrack;
  end;
  LCount := 0;
  for LNote in FScore.FNotes do
  begin
    if LNote.FStop > LNote.FStart then
    begin
      FScore.FNotes[LCount] := LNote;
      Inc(LCount);
    end;
  end;
  SetLength(FScore.FNotes, LCount);
  Require(LCount >= 12, 'Reference needs at least twelve pitched note gates');
  Result := FScore;
end;

function ReadMidi(const ABytes: TBytes): TMidiScore;
var
  LReader: TMidiReader;
begin
  LReader := TMidiReader.Create;
  try
    Result := LReader.Run(ABytes);
  finally
    LReader.Free;
  end;
end;

function FractionText(const ANumerator: Int64; const ADenominator: Integer): String;
var
  LA: Int64;
  LB: Int64;
  LTemp: Int64;
begin
  LA := ANumerator;
  LB := ADenominator;
  while LB <> 0 do
  begin
    LTemp := LA mod LB;
    LA := LB;
    LB := LTemp;
  end;
  Result := IntToStr(ANumerator div LA) + '/' + IntToStr(ADenominator div LA);
end;

function ScoreIdentity(const AScore: TMidiScore): String;
var
  LFirst: Int64;
  LBase: Integer;
  LNote: TMidiNote;
  LRows: TStringList;
  LText: UTF8String;
  LBytes: TBytes;
begin
  LFirst := High(Int64);
  LBase := 127;
  for LNote in AScore.FNotes do
  begin
    LFirst := Min(LFirst, LNote.FStart);
    LBase := Min(LBase, LNote.FPitch);
  end;
  LRows := TStringList.Create;
  try
    LRows.Sorted := True;
    LRows.CaseSensitive := True;
    LRows.Duplicates := dupIgnore;
    LRows.LineBreak := #10;
    for LNote in AScore.FNotes do
    begin
      LRows.Add(FractionText(LNote.FStart - LFirst, AScore.FPpq) + ':' +
        FractionText(LNote.FStop - LNote.FStart, AScore.FPpq) + ':' +
        IntToStr(LNote.FPitch - LBase));
    end;
    LText := LRows.Text;
    SetLength(LBytes, Length(LText));
    Move(LText[1], LBytes[0], Length(LText));
    Result := HashBytes(LBytes);
  finally
    LRows.Free;
  end;
end;

function ExtractSamples(const AScore: TMidiScore): TJSONObject;
const
  CScales: array[0..1, 0..6] of Integer = ((0, 2, 4, 5, 7, 9, 11),
    (0, 2, 3, 5, 7, 8, 10));
var
  LHistogram: array[0..11] of Double;
  LNote: TMidiNote;
  LRoot: Integer;
  LMode: Integer;
  LBestRoot: Integer;
  LBestMode: Integer;
  LFit: Double;
  LBestFit: Double;
  LFirst: Int64;
  LLast: Int64;
  LTicks: Int64;
  LWindows: array[0..2] of Int64;
  LWindow: Integer;
  LStartBeat: Int64;
  LBegin: Int64;
  LEnd: Int64;
  LHigh: Integer;
  LLow: Integer;
  LSounding: Integer;
  LMask: Integer;
  LSubbeat: Integer;
  LHasOnset: Boolean;
  LSamples: TJSONArray;
  LSample: TJSONObject;
  LMelody: TJSONArray;
  LHarmony: TJSONArray;
  LRhythm: TJSONArray;
  LDensity: TJSONArray;
  I: Integer;
  J: Integer;

  function Degree(const APitch: Integer): Integer;
  var
    LPitchClass: Integer;
    LDistance: Integer;
    LBest: Integer;
    K: Integer;
  begin
    LPitchClass := ((APitch - LBestRoot) mod 12 + 12) mod 12;
    LBest := 13;
    Result := 0;
    for K := 0 to 6 do
    begin
      LDistance := Abs(CScales[LBestMode, K] - LPitchClass);
      LDistance := Min(LDistance, 12 - LDistance);
      if LDistance < LBest then
      begin
        LBest := LDistance;
        Result := K;
      end;
    end;
  end;

begin
  for I := 0 to 11 do
  begin
    LHistogram[I] := 0;
  end;
  LFirst := High(Int64);
  LLast := 0;
  for LNote in AScore.FNotes do
  begin
    LHistogram[LNote.FPitch mod 12] := LHistogram[LNote.FPitch mod 12] +
      Min(LNote.FStop - LNote.FStart, Int64(4) * AScore.FPpq);
    LFirst := Min(LFirst, LNote.FStart);
    LLast := Max(LLast, LNote.FStop);
  end;
  LBestFit := -1;
  LBestRoot := 0;
  LBestMode := 0;
  for LRoot := 0 to 11 do
  begin
    for LMode := 0 to 1 do
    begin
      LFit := LHistogram[LRoot] * 0.15 + LHistogram[(LRoot + 7) mod 12] * 0.05;
      for I := 0 to 6 do
      begin
        LFit := LFit + LHistogram[(LRoot + CScales[LMode, I]) mod 12];
      end;
      if LFit > LBestFit then
      begin
        LBestFit := LFit;
        LBestRoot := LRoot;
        LBestMode := LMode;
      end;
    end;
  end;
  LTicks := Max(Int64(16), ((LLast - LFirst) * 4 + AScore.FPpq div 2) div AScore.FPpq);
  LWindows[0] := 0;
  LWindows[1] := Max(Int64(0), LTicks div 2 - 64) div 4;
  LWindows[2] := Max(Int64(0), LTicks - 128) div 4;
  Result := TJSONObject.Create(['estimatedTonic', LBestRoot, 'estimatedMode', LBestMode]);
  LSamples := TJSONArray.Create;
  Result.Add('samples', LSamples);
  for LWindow := 0 to 2 do
  begin
    LStartBeat := LWindows[LWindow];
    if (LWindow > 0) and (LStartBeat = LWindows[LWindow - 1]) then
    begin
      Continue;
    end;
    LSample := TJSONObject.Create(['startBeat', LStartBeat]);
    LMelody := TJSONArray.Create;
    LHarmony := TJSONArray.Create;
    LRhythm := TJSONArray.Create;
    LDensity := TJSONArray.Create;
    LSample.Add('melody', LMelody);
    LSample.Add('harmony', LHarmony);
    LSample.Add('rhythm', LRhythm);
    LSample.Add('density', LDensity);
    LHigh := LBestRoot + 60;
    LLow := LBestRoot + 48;
    LHasOnset := False;
    for I := 0 to 31 do
    begin
      LBegin := LFirst + (LStartBeat + I) * AScore.FPpq;
      LEnd := LBegin + AScore.FPpq;
      LSounding := 0;
      LMask := 0;
      for J := 0 to High(AScore.FNotes) do
      begin
        LNote := AScore.FNotes[J];
        if (LNote.FStart < LEnd) and (LNote.FStop > LBegin) then
        begin
          if LSounding = 0 then
          begin
            LHigh := LNote.FPitch;
            LLow := LNote.FPitch;
          end
          else
          begin
            LHigh := Max(LHigh, LNote.FPitch);
            LLow := Min(LLow, LNote.FPitch);
          end;
          Inc(LSounding);
          if LNote.FStart >= LBegin then
          begin
            LSubbeat := Min(Int64(3), ((LNote.FStart - LBegin) * 4 +
              AScore.FPpq div 2) div AScore.FPpq);
            LMask := LMask or (1 shl LSubbeat);
          end;
        end;
      end;
      LMelody.Add(Degree(LHigh));
      LHarmony.Add(Degree(LLow));
      LRhythm.Add(LMask);
      LDensity.Add(Min(3, LSounding div 3));
      LHasOnset := LHasOnset or (LMask <> 0);
    end;
    if LHasOnset then
    begin
      LSamples.Add(LSample);
    end
    else
    begin
      LSample.Free;
    end;
  end;
  Require(LSamples.Count > 0, 'Reference has no sampled note onsets');
end;

end.
