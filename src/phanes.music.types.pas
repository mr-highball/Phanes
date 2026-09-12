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

unit phanes.music.types;

{$mode delphi}
{$H+}

interface

const
  MusicBeats = 32;
  MusicLaneCount = 4;
  MusicStyleCount = 10;

type
  TMusicValues = array of Integer;
  TMusicLanes = array[0..MusicLaneCount - 1] of TMusicValues;
  TMusicSamples = array of TMusicLanes;

  TMusicReference = record
    FId: String;
    FTitle: String;
    FSamples: TMusicSamples;
  end;

  TMusicReferences = array of TMusicReference;
  TMusicWeights = array[0..MusicStyleCount - 1] of Integer;

  TMusicRequest = record
    FSeed: Cardinal;
    FIndex: Integer;
    FStyle: Integer;
    FBlendStyle: Integer;
    FBlend: Integer;
    FLocks: array[0..MusicLaneCount - 1] of Boolean;
    FWeights: TMusicWeights;
    FTempo: Integer;
    FMinimumSections: Integer;
    FFeaturedStyle: Integer;
    FHasFeaturedStyle: Boolean;
  end;

  TMusicStyle = record
    FName: String;
    FBpm: Integer;
    FMode: Integer;
    FLeadStride: Integer;
    FArpeggio: Integer;
    FBassStride: Integer;
    FDrums: Integer;
    FPadBeats: Integer;
    FBrightness: Integer;
  end;

  TMusicEvent = record
    FBeat: Double;
    FDuration: Double;
    FPitch: Integer;
    FVoice: Integer;
    FVelocity: Double;
    FStyle: Integer;
  end;

  TMusicEvents = array of TMusicEvent;

  TMusicSection = record
    FIndex: Integer;
    FBpm: Double;
    FLanes: TMusicLanes;
    FStyles: TMusicValues;
    FFocus: array[0..MusicLaneCount - 1] of String;
    FEvents: TMusicEvents;
  end;

function MusicLaneName(const ALane: Integer): String;
function MusicStyle(const AIndex: Integer): TMusicStyle;
function MusicWeights(const ARequest: TMusicRequest): TMusicWeights;
function MusicTempo(const ARequest: TMusicRequest): Double;
function MusicDominantStyle(const ARequest: TMusicRequest): Integer;

implementation

uses
  SysUtils;

function MusicLaneName(const ALane: Integer): String;
begin
  case ALane of
    0: Result := 'harmony';
    1: Result := 'melody';
    2: Result := 'rhythm';
    3: Result := 'density';
    else
    begin
      raise Exception.Create('Unknown music lane');
    end;
  end;
end;

function MusicStyle(const AIndex: Integer): TMusicStyle;
const
  CNames: array[0..9] of String = ('Cloud Garden', 'Glass Tides', 'Velvet Circuit',
    'Lunar Steps', 'Prism Current', 'Slow Aurora', 'Liquid Machines', 'Neon Bloom',
    'Weightless Transit', 'Dawn Spiral');
  CBpm: array[0..9] of Integer = (72, 88, 102, 116, 128, 80, 124, 118, 136, 110);
  CModes: array[0..9] of Integer = (3, 2, 1, 1, 2, 0, 1, 0, 3, 2);
  CLeadStride: array[0..9] of Integer = (4, 2, 1, 2, 1, 4, 2, 1, 1, 2);
  CArpeggio: array[0..9] of Integer = (0, 1, 0, -1, 2, 1, -2, 1, 2, -1);
  CBassStride: array[0..9] of Integer = (8, 4, 2, 1, 1, 8, 2, 1, 2, 4);
  CDrums: array[0..9] of Integer = (0, 1, 2, 3, 3, 0, 4, 2, 4, 1);
  CPadBeats: array[0..9] of Integer = (8, 4, 4, 8, 4, 8, 4, 4, 8, 4);
  CBrightness: array[0..9] of Integer = (700, 1800, 2200, 1200, 3200, 550, 1400, 2600, 2100, 1700);
begin
  if (AIndex < 0) or (AIndex >= MusicStyleCount) then
  begin
    raise Exception.Create('Unknown music style');
  end;
  Result.FName := CNames[AIndex];
  Result.FBpm := CBpm[AIndex];
  Result.FMode := CModes[AIndex];
  Result.FLeadStride := CLeadStride[AIndex];
  Result.FArpeggio := CArpeggio[AIndex];
  Result.FBassStride := CBassStride[AIndex];
  Result.FDrums := CDrums[AIndex];
  Result.FPadBeats := CPadBeats[AIndex];
  Result.FBrightness := CBrightness[AIndex];
end;

function MusicWeights(const ARequest: TMusicRequest): TMusicWeights;
var
  LTotal: Integer;
  I: Integer;
begin
  Result := ARequest.FWeights;
  LTotal := 0;
  for I := 0 to MusicStyleCount - 1 do
  begin
    if (Result[I] < 0) or (Result[I] > 100) then
    begin
      raise Exception.Create('Style connection strength must be between 0 and 100');
    end;
    Inc(LTotal, Result[I]);
  end;
  if LTotal = 0 then
  begin
    MusicStyle(ARequest.FStyle);
    MusicStyle(ARequest.FBlendStyle);
    if (ARequest.FBlend < 0) or (ARequest.FBlend > 100) then
    begin
      raise Exception.Create('Music blend out of range');
    end;
    Result[ARequest.FStyle] := 100 - ARequest.FBlend;
    Inc(Result[ARequest.FBlendStyle], ARequest.FBlend);
  end;
end;

function MusicTempo(const ARequest: TMusicRequest): Double;
var
  LWeights: TMusicWeights;
  LTotal: Integer;
  I: Integer;
begin
  LWeights := MusicWeights(ARequest);
  LTotal := 0;
  Result := 0;
  for I := 0 to MusicStyleCount - 1 do
  begin
    Inc(LTotal, LWeights[I]);
    Result := Result + MusicStyle(I).FBpm * LWeights[I];
  end;
  Result := Result / LTotal;
  if ARequest.FTempo <> 0 then
  begin
    if (ARequest.FTempo < 60) or (ARequest.FTempo > 160) then
    begin
      raise Exception.Create('Track tempo must be between 60 and 160 BPM');
    end;
    Result := ARequest.FTempo;
  end;
end;

function MusicDominantStyle(const ARequest: TMusicRequest): Integer;
var
  LWeights: TMusicWeights;
  I: Integer;
begin
  LWeights := MusicWeights(ARequest);
  Result := 0;
  for I := 1 to MusicStyleCount - 1 do
  begin
    if LWeights[I] > LWeights[Result] then
    begin
      Result := I;
    end;
  end;
end;

end.
