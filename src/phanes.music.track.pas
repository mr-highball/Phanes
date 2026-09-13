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

unit phanes.music.track;

{$mode delphi}
{$H+}

interface

uses
  phanes.music.types;

type
  TMusicTrackPlan = record
    FPhases: TMusicValues;
    FBpm: Double;
    FSeconds: Double;
  end;

function PlanMusicTrack(const ARequest: TMusicRequest): TMusicTrackPlan;
function ExtendMusicTrack(const ARequest: TMusicRequest; const APrefix: TMusicValues;
  const ACount: Integer): TMusicTrackPlan;
function TrackPhaseName(const APhase: Integer): String;
function FeaturedTrackStyle(const ARequest: TMusicRequest; const AIndex: Integer): Integer;
procedure ShapeTrackSection(const APhase, AIndex, ACount: Integer; var ASection: TMusicSection);

implementation

uses
  SysUtils,
  Math,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_graph;

function TrackPhaseName(const APhase: Integer): String;
const
  CNames: array[0..4] of String = ('Arrival', 'Drift', 'Flow', 'Crest', 'Landing');
begin
  if (APhase < 0) or (APhase > High(CNames)) then
  begin
    raise Exception.Create('Unknown track movement');
  end;
  Result := CNames[APhase];
end;

function ExtendMusicTrack(const ARequest: TMusicRequest; const APrefix: TMusicValues;
  const ACount: Integer): TMusicTrackPlan;
var
  LModel: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LValidation: TWfcSequenceGraphValidationReport;
  LSequence: TWfcGeneratedSequence;
  LCount: Integer;
  I: Integer;
begin
  Result := Default(TMusicTrackPlan);
  Result.FBpm := MusicTempo(ARequest);
  // Complete eight-bar phrases exceed five minutes before the final release tail.
  LCount := ACount;
  if (LCount < 4) or (LCount > 40) or (Length(APrefix) >= LCount) then
  begin
    raise Exception.Create('Invalid bounded track extension');
  end;
  SetLength(LSamples, 3);
  // Authored macro forms constrain the journey; score-derived WFC supplies every phrase.
  LSamples[0] := MakeWfcSequenceSample(['0', '1', '1', '2', '2', '3', '2', '1', '2', '4']);
  LSamples[1] := MakeWfcSequenceSample(['0', '2', '1', '2', '3', '3', '2', '3', '2', '4']);
  LSamples[2] := MakeWfcSequenceSample(['0', '1', '2', '3', '1', '1', '2', '3', '4']);
  LModel := LearnSequenceModelCorpus(LSamples, 2);
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(LCount, 1, 1);
    LGraph.Seed := ARequest.FSeed;
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    ApplySequenceModelToGraph(LModel, LGraph, wseWhole);
    IntersectSequenceAllowedTokens(LModel, LGraph, 0, '0');
    IntersectSequenceAllowedTokens(LModel, LGraph, LCount - 1, '4');
    for I := 1 to LCount - 2 do
    begin
      IntersectSequenceAllowedTokens(LModel, LGraph, I, ['1', '2', '3']);
    end;
    for I := 0 to High(APrefix) do
    begin
      IntersectSequenceAllowedTokens(LModel, LGraph, I, IntToStr(APrefix[I]));
    end;
    if LCount div 3 >= Length(APrefix) then
    begin
      IntersectSequenceAllowedTokens(LModel, LGraph, LCount div 3, '1');
    end;
    if (LCount * 2) div 3 >= Length(APrefix) then
    begin
      IntersectSequenceAllowedTokens(LModel, LGraph, (LCount * 2) div 3, '3');
    end;
    LOptions := DefaultGraphSolveOptions;
    if not LGraph.TrySolve(LOptions, LReport) or
      not CaptureSolvedSequence(LModel, LGraph, wseWhole, LSequence, LValidation) then
    begin
      raise Exception.Create('Track form search exhausted');
    end;
    SetLength(Result.FPhases, LCount);
    for I := 0 to LCount - 1 do
    begin
      Result.FPhases[I] := StrToInt(LSequence.Tokens[I]);
    end;
    Result.FSeconds := LCount * MusicBeats * 60 / Result.FBpm;
  finally
    LGraph.Free;
    LModel.Free;
  end;
end;

function PlanMusicTrack(const ARequest: TMusicRequest): TMusicTrackPlan;
begin
  Result := ExtendMusicTrack(ARequest, nil,
    Ceil(304 * MusicTempo(ARequest) / (MusicBeats * 60)) + Integer(ARequest.FSeed mod 3));
end;

function FeaturedTrackStyle(const ARequest: TMusicRequest; const AIndex: Integer): Integer;
var
  LWeights: TMusicWeights;
  LActive: TMusicValues;
  I: Integer;
begin
  LWeights := MusicWeights(ARequest);
  LActive := nil;
  for I := 0 to MusicStyleCount - 1 do
  begin
    if LWeights[I] > 0 then
    begin
      SetLength(LActive, Length(LActive) + 1);
      LActive[High(LActive)] := I;
    end;
  end;
  if AIndex < 0 then
  begin
    raise Exception.Create('Negative track section');
  end;
  Result := LActive[AIndex mod Length(LActive)];
end;

procedure ShapeTrackSection(const APhase, AIndex, ACount: Integer; var ASection: TMusicSection);
var
  LOutput: TMusicEvents;
  LEvent: TMusicEvent;
  LGain: Double;
  LKeep: Boolean;
  I: Integer;
  J: Integer;
begin
  TrackPhaseName(APhase);
  LOutput := nil;
  for J := 0 to High(ASection.FEvents) do
  begin
    LEvent := ASection.FEvents[J];
    LGain := 1;
    LKeep := True;
    case APhase of
      0:
      begin
        LGain := 0.4 + 0.6 * LEvent.FBeat / MusicBeats;
        LKeep := (LEvent.FVoice < 3) or (LEvent.FBeat >= 24);
      end;
      1:
      begin
        LGain := 0.75;
        LKeep := (LEvent.FVoice <> 5) and ((LEvent.FVoice <> 4) or
          (Trunc(LEvent.FBeat) mod 4 = 1));
      end;
      3:
      begin
        LGain := 1.12;
      end;
      4:
      begin
        LGain := 1 - 0.85 * LEvent.FBeat / MusicBeats;
        LKeep := (LEvent.FVoice < 3) or (LEvent.FBeat < 16);
      end;
    end;
    if LKeep then
    begin
      LEvent.FVelocity := Min(1, LEvent.FVelocity * LGain);
      // Last release lands inside the composed track; delay supplies its natural tail.
      if AIndex = ACount - 1 then
      begin
        LEvent.FDuration := Min(LEvent.FDuration, MusicBeats - LEvent.FBeat);
      end;
      I := Length(LOutput);
      SetLength(LOutput, I + 1);
      LOutput[I] := LEvent;
    end;
  end;
  ASection.FEvents := LOutput;
end;

end.
