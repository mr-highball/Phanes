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

unit phanes.tests.tracks;

{$mode delphi}
{$H+}

interface

uses
  phanes.music.types;

procedure RunTrackTests(const AReferences: TMusicReferences);

implementation

uses
  Classes,
  SysUtils,
  Math,
  phanes.tools.files,
  phanes.music.generate,
  phanes.music.track;

procedure RunTrackTests(const AReferences: TMusicReferences);
var
  LRequest: TMusicRequest;
  LPlan: TMusicTrackPlan;
  LGenerator: TMusicGenerator;
  LSection: TMusicSection;
  LEvents: TStringList;
  LHashes: TStringList;
  LSeen: array[0..MusicStyleCount - 1] of Boolean;
  LAdjacent: array[0..3, 0..15, 0..15] of Boolean;
  LPairs: array[0..48] of Boolean;
  LIntervals: array[0..6, 0..6] of Boolean;
  LSample: TMusicLanes;
  LReference: TMusicReference;
  LEvent: TMusicEvent;
  LSeconds: Double;
  LHash: String;
  LPath: String;
  LStyle: Integer;
  LVariant: Integer;
  LCount: Integer;
  LPair: Integer;
  LPreviousPair: Integer;
  LInterval: Integer;
  LPreviousInterval: Integer;
  LTempo: Integer;
  LSeed: Integer;
  LPreviousPhase: Integer;
  LPhase: Integer;
  LLane: Integer;
  I: Integer;
  J: Integer;
begin
  FillChar(LAdjacent, SizeOf(LAdjacent), 0);
  FillChar(LPairs, SizeOf(LPairs), 0);
  FillChar(LIntervals, SizeOf(LIntervals), 0);
  // Independent observations from the input corpus, without solver/model capture helpers.
  for LReference in AReferences do
  begin
    for LSample in LReference.FSamples do
    begin
      for I := 1 to MusicBeats - 1 do
      begin
        for LLane := 0 to MusicLaneCount - 1 do
        begin
          LAdjacent[LLane, LSample[LLane][I - 1], LSample[LLane][I]] := True;
        end;
        LPreviousPair := LSample[0][I - 1] * 7 + LSample[1][I - 1];
        LPair := LSample[0][I] * 7 + LSample[1][I];
        LPairs[LPreviousPair] := True;
        LPairs[LPair] := True;
        LPreviousInterval := (LSample[1][I - 1] - LSample[0][I - 1] + 7) mod 7;
        LInterval := (LSample[1][I] - LSample[0][I] + 7) mod 7;
        LIntervals[LPreviousInterval, LInterval] := True;
      end;
    end;
  end;
  LRequest := Default(TMusicRequest);
  for I := 0 to MusicStyleCount - 1 do
  begin
    LRequest.FWeights[I] := 10;
  end;
  for LTempo := 60 to 160 do
  begin
    for LSeed := 0 to 2 do
    begin
      LRequest.FTempo := LTempo;
      LRequest.FSeed := LSeed;
      LPlan := PlanMusicTrack(LRequest);
      Require((LPlan.FSeconds >= 304) and (LPlan.FSeconds <= 390.001), 'Invalid track duration');
      Require(Length(LPlan.FPhases) >= MusicStyleCount, 'Not enough sections for connected groups');
      Require((LPlan.FPhases[0] = 0) and (LPlan.FPhases[High(LPlan.FPhases)] = 4),
        'Track needs arrival and landing');
      for I := 1 to High(LPlan.FPhases) do
      begin
        LPreviousPhase := LPlan.FPhases[I - 1];
        LPhase := LPlan.FPhases[I];
        Require(((LPreviousPhase in [0, 1]) and (LPhase in [1, 2])) or
          ((LPreviousPhase in [2, 3]) and (LPhase in [1, 2, 3, 4])), 'Unobserved form transition');
      end;
      FillChar(LSeen, SizeOf(LSeen), 0);
      for I := 0 to High(LPlan.FPhases) do
      begin
        LSeen[FeaturedTrackStyle(LRequest, I)] := True;
      end;
      for I := 0 to MusicStyleCount - 1 do
      begin
        Require(LSeen[I], 'Connected style excluded from track');
      end;
    end;
  end;
  WriteLn('303 track forms passed independent duration, endpoint and transition checks');
  LHashes := TStringList.Create;
  LEvents := TStringList.Create;
  LCount := 0;
  try
    for LStyle := 0 to MusicStyleCount - 1 do
    begin
      for LVariant := 0 to 1 do
      begin
        if (LVariant = 1) and not (LStyle in [1, 5, 6, 9]) then
        begin
          Continue;
        end;
        LRequest := Default(TMusicRequest);
        LRequest.FStyle := LStyle;
        LRequest.FWeights[LStyle] := 100;
        LRequest.FSeed := 701 + LVariant * 8191 + LStyle * 7919;
        LPlan := PlanMusicTrack(LRequest);
        LGenerator := TMusicGenerator.Create(AReferences);
        try
          LSeconds := 0;
          LEvents.Clear;
          for I := 0 to High(LPlan.FPhases) do
          begin
            LRequest.FIndex := I;
            LRequest.FSeed := (LRequest.FSeed + Cardinal(I * 104729 + 3571)) and $7FFFFFFF;
            LRequest.FHasFeaturedStyle := True;
            LRequest.FFeaturedStyle := FeaturedTrackStyle(LRequest, I);
            LSection := LGenerator.Generate(LRequest);
            for J := 1 to MusicBeats - 1 do
            begin
              for LLane := 0 to MusicLaneCount - 1 do
              begin
                Require(LAdjacent[LLane, LSection.FLanes[LLane][J - 1],
                  LSection.FLanes[LLane][J]], 'Generated lane uses an unobserved transition');
              end;
              LPreviousPair := LSection.FLanes[0][J - 1] * 7 + LSection.FLanes[1][J - 1];
              LPair := LSection.FLanes[0][J] * 7 + LSection.FLanes[1][J];
              Require(LPairs[LPreviousPair] and LPairs[LPair],
                'Generated simultaneous voice pair is unobserved');
              LPreviousInterval := (LSection.FLanes[1][J - 1] - LSection.FLanes[0][J - 1] + 7) mod 7;
              LInterval := (LSection.FLanes[1][J] - LSection.FLanes[0][J] + 7) mod 7;
              Require(LIntervals[LPreviousInterval, LInterval], 'Unobserved voice interval transition');
            end;
            ShapeTrackSection(LPlan.FPhases[I], I, Length(LPlan.FPhases), LSection);
            ValidateMusic(LSection);
            Require(Abs(LSection.FBpm - MusicStyle(LStyle).FBpm) < 0.001, 'Style group tempo drift');
            LSeconds := LSeconds + MusicBeats * 60 / LSection.FBpm;
            for LEvent in LSection.FEvents do
            begin
              Require(LEvent.FStyle = LStyle, 'Disconnected style became audible');
              LEvents.Add(Format('%d %.3f %.3f %d %d %.6f %d', [I, LEvent.FBeat,
                LEvent.FDuration, LEvent.FPitch, LEvent.FVoice, LEvent.FVelocity, LEvent.FStyle]));
            end;
          end;
          Require((LSeconds >= 300) and (Abs(LSeconds - LPlan.FSeconds) < 0.001),
            'Generated track duration differs from planned duration');
          LPath := 'build/track-scores/' + IntToStr(LStyle) + '-' + IntToStr(LVariant) + '.txt';
          WriteText(LPath, LEvents.Text);
          LHash := HashFile(LPath);
          Require(LHashes.IndexOf(LHash) < 0, 'Different track seeds produced duplicate event scores');
          LHashes.Add(LHash);
          Inc(LCount);
          WriteLn(MusicStyle(LStyle).FName, ' variation ', LVariant + 1, ': ',
            LSeconds:0:2, ' seconds, ', LEvents.Count, ' events, ', LHash);
        finally
          LGenerator.Free;
        end;
      end;
    end;
    WriteText('build/track-evidence.json', Format('{"fullTracks":%d,"styles":10,' +
      '"durationPlans":303,"uniqueEventScores":true,"independentCorpusTransitions":true}', [LCount]));
  finally
    LEvents.Free;
    LHashes.Free;
  end;
end;

end.
