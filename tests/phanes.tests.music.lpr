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

program PhanesMusicTests;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  phanes.tools.files,
  phanes.music.types,
  phanes.music.generate,
  phanes.tests.tracks;

var
  GCorpus: TJSONObject;
  GReferences: TMusicReferences;
  GGenerator: TMusicGenerator;
  GOther: TMusicGenerator;
  GRequest: TMusicRequest;
  GSection: TMusicSection;
  GPrevious: TMusicSection;
  GDeterministic: TMusicSection;
  GCoverage: array[0..3] of TStringList;
  GRecord: TJSONObject;
  GSample: TJSONObject;
  GEvidence: TJSONObject;
  GLanes: TJSONArray;
  GStates: TJSONArray;
  GStarted: QWord;
  I: Integer;
  J: Integer;
  K: Integer;
  GLane: Integer;

begin
  GStarted := GetTickCount64;
  GCorpus := LoadJSON('data/music/corpus.json');
  SetLength(GReferences, GCorpus.Arrays['references'].Count);
  for I := 0 to High(GReferences) do
  begin
    GRecord := GCorpus.Arrays['references'].Objects[I];
    GReferences[I].FId := GRecord.Strings['id'];
    GReferences[I].FTitle := GRecord.Strings['title'];
    SetLength(GReferences[I].FSamples, GRecord.Arrays['samples'].Count);
    for J := 0 to High(GReferences[I].FSamples) do
    begin
      GSample := GRecord.Arrays['samples'].Objects[J];
      for GLane := 0 to MusicLaneCount - 1 do
      begin
        SetLength(GReferences[I].FSamples[J][GLane], MusicBeats);
        for K := 0 to MusicBeats - 1 do
        begin
          GReferences[I].FSamples[J][GLane][K] := GSample.Arrays[MusicLaneName(GLane)].Integers[K];
        end;
      end;
    end;
  end;
  GCorpus.Free;
  GGenerator := TMusicGenerator.Create(GReferences);
  GOther := TMusicGenerator.Create(GReferences);
  GRequest := Default(TMusicRequest);
  GRequest.FSeed := 731;
  GRequest.FBlendStyle := 4;
  GRequest.FBlend := 50;
  GSection := GGenerator.Generate(GRequest);
  GDeterministic := GOther.Generate(GRequest);
  for GLane := 0 to MusicLaneCount - 1 do
  begin
    GCoverage[GLane] := TStringList.Create;
    GCoverage[GLane].Sorted := True;
    GCoverage[GLane].Duplicates := dupIgnore;
    for K := 0 to MusicBeats - 1 do
    begin
      Require(GSection.FLanes[GLane][K] = GDeterministic.FLanes[GLane][K], 'Music is not deterministic');
    end;
  end;
  GOther.Free;
  for I := 0 to High(GReferences) do
  begin
    if I <> 0 then
    begin
      GPrevious := GSection;
      GRequest.FIndex := I;
      GSection := GGenerator.Generate(GRequest);
      for GLane := 0 to MusicLaneCount - 1 do
      begin
        Require(GSection.FLanes[GLane][0] = GPrevious.FLanes[GLane][31], 'Music seam was not preserved');
      end;
    end;
    for GLane := 0 to MusicLaneCount - 1 do
    begin
      GCoverage[GLane].Add(GSection.FFocus[GLane]);
    end;
  end;
  for GLane := 0 to MusicLaneCount - 1 do
  begin
    Require(GCoverage[GLane].Count = Length(GReferences), 'Not every music source contributes');
    GRequest.FLocks[GLane] := True;
  end;
  GPrevious := GSection;
  Inc(GRequest.FIndex);
  GSection := GGenerator.Generate(GRequest);
  for GLane := 0 to MusicLaneCount - 1 do
  begin
    for K := 0 to MusicBeats - 1 do
    begin
      Require(GSection.FLanes[GLane][K] = GPrevious.FLanes[GLane][K], 'Music lock was not preserved');
    end;
  end;
  for I := 0 to MusicStyleCount - 1 do
  begin
    GRequest.FStyle := I;
    GRequest.FBlend := 0;
    GSection := GGenerator.Generate(GRequest);
    Require(GSection.FBpm = MusicStyle(I).FBpm, 'Style tempo does not match');
    WriteLn(MusicStyle(I).FName, ': ', Length(GSection.FEvents), ' arranged events');
  end;
  GEvidence := TJSONObject.Create(['references', Length(GReferences), 'styles', MusicStyleCount,
    'sections', Length(GReferences), 'milliseconds', GetTickCount64 - GStarted,
    'deterministic', True, 'sourceAnchorsValidated', True, 'seamsValidated', True, 'locksValidated', True]);
  GLanes := TJSONArray.Create;
  GStates := TJSONArray.Create;
  for GLane := 0 to MusicLaneCount - 1 do
  begin
    GLanes.Add(GCoverage[GLane].Count);
    GStates.Add(GGenerator.ModelStateCount(GLane));
    GCoverage[GLane].Free;
  end;
  GEvidence.Add('referencesPerLane', GLanes);
  GEvidence.Add('learnedStatesPerLane', GStates);
  WriteText('build/music-evidence.json', GEvidence.FormatJSON + #10);
  WriteLn(GEvidence.AsJSON);
  GEvidence.Free;
  GGenerator.Free;
  RunTrackTests(GReferences);
end.
