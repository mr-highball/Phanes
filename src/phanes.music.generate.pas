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

unit phanes.music.generate;

{$mode delphi}
{$H+}

interface

uses
  wfc,
  wfc_sequence,
  phanes.music.types;

type
  TMusicGenerator = class
  private
    FReferences: TMusicReferences;
    FModels: array[0..MusicLaneCount - 1] of TWfcSequenceModel;
    FPairModel: TWfcSequenceModel;
    FIntervalModel: TWfcSequenceModel;
    FPrevious: TMusicSection;
    FHasPrevious: Boolean;
    function SolveLane(const ARequest: TMusicRequest; const ALane, ASource: Integer): TMusicValues;
    procedure LearnVoices;
    procedure ConfigureLane(const AGraph: TGraph; const ARequest: TMusicRequest;
      const ALane, ASource: Integer);
    procedure SolveVoices(const ARequest: TMusicRequest; const AHarmonySource,
      AMelodySource: Integer; var ASection: TMusicSection);
  public
    constructor Create(const AReferences: TMusicReferences);
    destructor Destroy; override;
    function Generate(const ARequest: TMusicRequest): TMusicSection;
    procedure Restore(const ASection: TMusicSection);
    function ModelStateCount(const ALane: Integer): Integer;
  end;

procedure ArrangeMusic(const ARequest: TMusicRequest; var ASection: TMusicSection);
procedure ValidateMusic(const ASection: TMusicSection);

implementation

uses
  SysUtils,
  Math,
  wfc_model,
  wfc_sequence_learn,
  wfc_sequence_graph;

procedure Ensure(const ACondition: Boolean; const AReason: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AReason);
  end;
end;

constructor TMusicGenerator.Create(const AReferences: TMusicReferences);
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LReference: TMusicReference;
  LSample: TMusicLanes;
  LLane: Integer;
  LIndex: Integer;
  I: Integer;
begin
  inherited Create;
  Ensure(Length(AReferences) >= 100, 'Music requires at least 100 references');
  FReferences := AReferences;
  for LLane := 0 to MusicLaneCount - 1 do
  begin
    LSamples := nil;
    for LReference in AReferences do
    begin
      Ensure(Length(LReference.FSamples) > 0, 'Reference has no music samples');
      for LSample in LReference.FSamples do
      begin
        Ensure(Length(LSample[LLane]) = MusicBeats, 'Music sample must span 32 beats');
        SetLength(LTokens, MusicBeats);
        for I := 0 to MusicBeats - 1 do
        begin
          Ensure((LSample[LLane][I] >= 0) and
            (((LLane <= 1) and (LSample[LLane][I] <= 6)) or
             ((LLane = 2) and (LSample[LLane][I] <= 15)) or
             ((LLane = 3) and (LSample[LLane][I] <= 3))), 'Music sample token out of range');
          LTokens[I] := IntToStr(LSample[LLane][I]);
        end;
        LIndex := Length(LSamples);
        SetLength(LSamples, LIndex + 1);
        LSamples[LIndex] := MakeWfcSequenceSample(Copy(LTokens));
      end;
    end;
    { All references train every dimension. An order-two state retains one
      preceding token; source anchors later force different corpus excerpts
      into each dimension while WFC resolves the surrounding context. }
    FModels[LLane] := LearnSequenceModelCorpus(LSamples, 2);
  end;
  LearnVoices;
end;

procedure TMusicGenerator.LearnVoices;
var
  LPairs: TWfcSequenceSamples;
  LIntervals: TWfcSequenceSamples;
  LPairTokens: TWfcModelTokens;
  LIntervalTokens: TWfcModelTokens;
  LReference: TMusicReference;
  LSample: TMusicLanes;
  LIndex: Integer;
  I: Integer;
begin
  LPairs := nil;
  LIntervals := nil;
  for LReference in FReferences do
  begin
    for LSample in LReference.FSamples do
    begin
      SetLength(LPairTokens, MusicBeats);
      SetLength(LIntervalTokens, MusicBeats);
      for I := 0 to MusicBeats - 1 do
      begin
        LPairTokens[I] := IntToStr(LSample[0][I]) + ':' + IntToStr(LSample[1][I]);
        LIntervalTokens[I] := IntToStr((LSample[1][I] - LSample[0][I] + 7) mod 7);
      end;
      LIndex := Length(LPairs);
      SetLength(LPairs, LIndex + 1);
      SetLength(LIntervals, LIndex + 1);
      LPairs[LIndex] := MakeWfcSequenceSample(Copy(LPairTokens));
      LIntervals[LIndex] := MakeWfcSequenceSample(Copy(LIntervalTokens));
    end;
  end;
  FPairModel := LearnSequenceModelCorpus(LPairs, 1);
  FIntervalModel := LearnSequenceModelCorpus(LIntervals, 2);
end;

destructor TMusicGenerator.Destroy;
var
  I: Integer;
begin
  for I := 0 to MusicLaneCount - 1 do
  begin
    FModels[I].Free;
  end;
  FPairModel.Free;
  FIntervalModel.Free;
  inherited Destroy;
end;

procedure TMusicGenerator.ConfigureLane(const AGraph: TGraph;
  const ARequest: TMusicRequest; const ALane, ASource: Integer);
var
  LTokens: TWfcModelTokens;
  LSample: TMusicLanes;
  I: Integer;
begin
  ApplySequenceModelToGraph(FModels[ALane], AGraph, wseFragment);
  if ARequest.FLocks[ALane] and FHasPrevious then
  begin
    SetLength(LTokens, MusicBeats);
    for I := 0 to MusicBeats - 1 do
    begin
      LTokens[I] := IntToStr(FPrevious.FLanes[ALane][I]);
    end;
    IntersectSequenceLockedSpan(FModels[ALane], AGraph, 0, LTokens);
    Exit;
  end;
  LSample := FReferences[ASource].FSamples[ARequest.FIndex mod
    Length(FReferences[ASource].FSamples)];
  SetLength(LTokens, 4);
  for I := 0 to 3 do
  begin
    LTokens[I] := IntToStr(LSample[ALane][I + 4]);
  end;
  IntersectSequenceLockedSpan(FModels[ALane], AGraph, 4, LTokens);
  if FHasPrevious then
  begin
    IntersectSequenceAllowedTokens(FModels[ALane], AGraph, 0,
      IntToStr(FPrevious.FLanes[ALane][MusicBeats - 1]));
  end;
end;

procedure TMusicGenerator.SolveVoices(const ARequest: TMusicRequest;
  const AHarmonySource, AMelodySource: Integer; var ASection: TMusicSection);
var
  LGraph: TGraph;
  LRules: TWfcSequenceProjectionRules;
  LAllowed: TWfcModelTokens;
  LToken: String;
  LInterval: Integer;
  LOptions: TGraphNegotiationOptions;
  LReport: TGraphNegotiationReport;
  LSequence: TWfcGeneratedSequence;
  LValidation: TWfcSequenceGraphValidationReport;
  LLane: Integer;
  I: Integer;
  J: Integer;
begin
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(MusicBeats, 1, 1);
    LGraph.Seed := (ARequest.FSeed + Cardinal(ARequest.FIndex * 131)) and $7FFFFFFF;
    LGraph.WrapNeighbors := False;
    LGraph.CurrentPass := 'harmony';
    LGraph.PassMode := gpmOverlay;
    ConfigureLane(LGraph, ARequest, 0, AHarmonySource);
    LGraph.SwitchToPass('melody');
    LGraph.PassMode := gpmOverlay;
    ConfigureLane(LGraph, ARequest, 1, AMelodySource);
    LGraph.SwitchToPass('voice-pairs');
    LGraph.PassMode := gpmOverlay;
    ApplySequenceModelToGraph(FPairModel, LGraph, wseFragment);
    { Pair values retain correlation: two independent OR lists would lose the
      relationship between the provider notes. The downstream interval model
      then constrains changes in that relative relationship over time. }
    for LLane := 0 to 1 do
    begin
      SetLength(LRules, FPairModel.PublicTokenCount);
      for I := 0 to FPairModel.PublicTokenCount - 1 do
      begin
        LToken := FPairModel.PublicTokenAt(I);
        LRules[I] := MakeWfcSequenceProjectionRule(LToken, [Copy(LToken, 1 + LLane * 2, 1)]);
      end;
      RequireSequenceProjectionMapFromPass(FPairModel, FModels[LLane], LGraph,
        MusicLaneName(LLane), LRules);
    end;
    LGraph.SwitchToPass('voice-intervals');
    LGraph.PassMode := gpmOverlay;
    ApplySequenceModelToGraph(FIntervalModel, LGraph, wseFragment);
    SetLength(LRules, FIntervalModel.PublicTokenCount);
    for I := 0 to FIntervalModel.PublicTokenCount - 1 do
    begin
      LAllowed := nil;
      LInterval := StrToInt(FIntervalModel.PublicTokenAt(I));
      for J := 0 to FPairModel.PublicTokenCount - 1 do
      begin
        LToken := FPairModel.PublicTokenAt(J);
        if (StrToInt(Copy(LToken, 3, 1)) - StrToInt(Copy(LToken, 1, 1)) + 7) mod 7 = LInterval then
        begin
          SetLength(LAllowed, Length(LAllowed) + 1);
          LAllowed[High(LAllowed)] := LToken;
        end;
      end;
      LRules[I] := MakeWfcSequenceProjectionRule(FIntervalModel.PublicTokenAt(I), LAllowed);
    end;
    RequireSequenceProjectionMapFromPass(FIntervalModel, FPairModel, LGraph, 'voice-pairs', LRules);
    LOptions.SolveOptions := DefaultGraphSolveOptions;
    LOptions.SolveOptions.MaxBacktracks := 512;
    LOptions.MaxPassBacktracks := 64;
    Ensure(LGraph.TrySolveNegotiated(LOptions, LReport), 'Music voice relationship search exhausted');
    for LLane := 0 to 1 do
    begin
      Ensure(CaptureSolvedSequence(FModels[LLane], LGraph.PassGraph[LLane], wseFragment,
        LSequence, LValidation), 'Invalid solved music voice');
      SetLength(ASection.FLanes[LLane], MusicBeats);
      for I := 0 to MusicBeats - 1 do
      begin
        ASection.FLanes[LLane][I] := StrToInt(LSequence.Tokens[I]);
      end;
    end;
    Ensure(CaptureSolvedSequence(FPairModel, LGraph.PassGraph[2], wseFragment,
      LSequence, LValidation), 'Invalid learned voice pair');
    for I := 0 to MusicBeats - 1 do
    begin
      Ensure(LSequence.Tokens[I] = IntToStr(ASection.FLanes[0][I]) + ':' +
        IntToStr(ASection.FLanes[1][I]), 'Voice pair projection mismatch');
    end;
    Ensure(CaptureSolvedSequence(FIntervalModel, LGraph.PassGraph[3], wseFragment,
      LSequence, LValidation), 'Invalid learned voice interval sequence');
    for I := 0 to MusicBeats - 1 do
    begin
      Ensure(StrToInt(LSequence.Tokens[I]) =
        (ASection.FLanes[1][I] - ASection.FLanes[0][I] + 7) mod 7, 'Voice interval mismatch');
    end;
  finally
    LGraph.Free;
  end;
end;

function TMusicGenerator.ModelStateCount(const ALane: Integer): Integer;
begin
  Result := FModels[ALane].StateCount;
end;

procedure TMusicGenerator.Restore(const ASection: TMusicSection);
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LTokens: TWfcModelTokens;
  LLane: Integer;
  I: Integer;
begin
  ValidateMusic(ASection);
  for LLane := 0 to MusicLaneCount - 1 do
  begin
    LGraph := TGraph.Create;
    try
      LGraph.Reshape(MusicBeats, 1, 1);
      LGraph.WrapNeighbors := False;
      ApplySequenceModelToGraph(FModels[LLane], LGraph, wseFragment);
      SetLength(LTokens, MusicBeats);
      for I := 0 to MusicBeats - 1 do
      begin
        LTokens[I] := IntToStr(ASection.FLanes[LLane][I]);
      end;
      IntersectSequenceLockedSpan(FModels[LLane], LGraph, 0, LTokens);
      LOptions := DefaultGraphSolveOptions;
      Ensure(LGraph.TrySolve(LOptions, LReport), 'Restored music does not follow the learned corpus');
    finally
      LGraph.Free;
    end;
  end;
  FPrevious := ASection;
  FHasPrevious := True;
end;

function TMusicGenerator.SolveLane(const ARequest: TMusicRequest;
  const ALane, ASource: Integer): TMusicValues;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LSequence: TWfcGeneratedSequence;
  LValidation: TWfcSequenceGraphValidationReport;
  LAnchor: TWfcModelTokens;
  LSample: TMusicLanes;
  I: Integer;
begin
  if ARequest.FLocks[ALane] and FHasPrevious then
  begin
    Exit(Copy(FPrevious.FLanes[ALane]));
  end;
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(MusicBeats, 1, 1);
    LGraph.Seed := (ARequest.FSeed + Cardinal(ARequest.FIndex * 131 + ALane * 17)) and $7FFFFFFF;
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    ApplySequenceModelToGraph(FModels[ALane], LGraph, wseFragment);
    LSample := FReferences[ASource].FSamples[ARequest.FIndex mod
      Length(FReferences[ASource].FSamples)];
    SetLength(LAnchor, 4);
    for I := 0 to 3 do
    begin
      LAnchor[I] := IntToStr(LSample[ALane][I + 4]);
    end;
    IntersectSequenceLockedSpan(FModels[ALane], LGraph, 4, LAnchor);
    if FHasPrevious then
    begin
      IntersectSequenceAllowedTokens(FModels[ALane], LGraph, 0,
        IntToStr(FPrevious.FLanes[ALane][MusicBeats - 1]));
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 512;
    Ensure(LGraph.TrySolve(LOptions, LReport), 'Music search exhausted in ' + MusicLaneName(ALane));
    Ensure(CaptureSolvedSequence(FModels[ALane], LGraph, wseFragment, LSequence, LValidation),
      'Music sequence failed independent transition validation');
    SetLength(Result, MusicBeats);
    for I := 0 to MusicBeats - 1 do
    begin
      Result[I] := StrToInt(LSequence.Tokens[I]);
    end;
    for I := 0 to 3 do
    begin
      Ensure(Result[I + 4] = LSample[ALane][I + 4], 'Music source anchor was not retained');
    end;
  finally
    LGraph.Free;
  end;
end;

function TMusicGenerator.Generate(const ARequest: TMusicRequest): TMusicSection;
var
  LLane: Integer;
  LSource: Integer;
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  I: Integer;
  LVoiceSources: array[0..1] of Integer;
  LWeights: TMusicWeights;
  LConnected: Integer;
  LFirstConnected: Integer;
begin
  Ensure((ARequest.FIndex >= 0) and (ARequest.FIndex <= 1000000), 'Music section index out of range');
  Ensure((ARequest.FBlend >= 0) and (ARequest.FBlend <= 100), 'Music blend out of range');
  MusicStyle(ARequest.FStyle);
  MusicStyle(ARequest.FBlendStyle);
  LWeights := MusicWeights(ARequest);
  Result := Default(TMusicSection);
  Result.FIndex := ARequest.FIndex;
  for LLane := 0 to MusicLaneCount - 1 do
  begin
    { Each unlocked lane visits every source once per N sections. Different
      offsets deliberately combine four sources in a section; the complete
      corpus supplies the frequencies and legal adjacent pairs around them. }
    LSource := (Integer(ARequest.FSeed mod Cardinal(Length(FReferences))) +
      ARequest.FIndex + LLane * 31 + ARequest.FStyle * 17) mod Length(FReferences);
    if LLane <= 1 then
    begin
      LVoiceSources[LLane] := LSource;
    end
    else
    begin
      Result.FLanes[LLane] := SolveLane(ARequest, LLane, LSource);
    end;
    Result.FFocus[LLane] := FReferences[LSource].FId;
    if ARequest.FLocks[LLane] and FHasPrevious then
    begin
      Result.FFocus[LLane] := FPrevious.FFocus[LLane];
    end;
  end;
  SolveVoices(ARequest, LVoiceSources[0], LVoiceSources[1], Result);
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(8, 1, 1);
    LGraph.Seed := (ARequest.FSeed + Cardinal(ARequest.FIndex * 113)) and $7FFFFFFF;
    LConnected := 0;
    LFirstConnected := -1;
    for I := 0 to MusicStyleCount - 1 do
    begin
      if LWeights[I] > 0 then
      begin
        LGraph.AddValue(IntToStr(I), LWeights[I]);
        Inc(LConnected);
        if LFirstConnected < 0 then
        begin
          LFirstConnected := I;
        end;
      end;
    end;
    if ARequest.FHasFeaturedStyle then
    begin
      Ensure((ARequest.FFeaturedStyle >= 0) and (ARequest.FFeaturedStyle < MusicStyleCount),
        'Track featured style is out of range');
      Ensure(LWeights[ARequest.FFeaturedStyle] > 0, 'Track features a disconnected style');
      LGraph.SetAllowedValues(4, 0, 0, IntToStr(ARequest.FFeaturedStyle));
    end
    else if LConnected = 2 then
    begin
      LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('blend-presence',
        [IntToStr(LFirstConnected)], 1, 7));
    end;
    LOptions := DefaultGraphSolveOptions;
    Ensure(LGraph.TrySolve(LOptions, LReport), 'Music style arrangement search exhausted');
    SetLength(Result.FStyles, 8);
    for I := 0 to 7 do
    begin
      Result.FStyles[I] := StrToInt(LGraph.Entry[I, 0, 0].Value);
    end;
  finally
    LGraph.Free;
  end;
  ArrangeMusic(ARequest, Result);
  ValidateMusic(Result);
  FPrevious := Result;
  FHasPrevious := True;
end;

procedure ArrangeMusic(const ARequest: TMusicRequest; var ASection: TMusicSection);
const
  CScales: array[0..3, 0..6] of Integer = ((0, 2, 4, 5, 7, 9, 11),
    (0, 2, 3, 5, 7, 8, 10), (0, 2, 3, 5, 7, 9, 10), (0, 2, 4, 6, 7, 9, 11));
var
  LStyle: TMusicStyle;
  LPrimary: TMusicStyle;
  LSecondary: TMusicStyle;
  LRoot: Integer;
  LDegree: Integer;
  LMask: Integer;
  LIntensity: Double;
  LBeat: Integer;
  LStep: Integer;
  I: Integer;
  J: Integer;
  LEvent: TMusicEvent;

  function Pitch(const ADegree, AOctave: Integer): Integer;
  var
    LNormalized: Integer;
  begin
    LNormalized := ((ADegree mod 7) + 7) mod 7;
    Result := 12 * AOctave + CScales[LPrimary.FMode, LNormalized];
    if ADegree >= 7 then
    begin
      Inc(Result, 12);
    end;
  end;

  procedure Add(const ABeat, ADuration: Double; const APitch, AVoice: Integer;
    const AVelocity: Double);
  var
    LIndex: Integer;
  begin
    LIndex := Length(ASection.FEvents);
    SetLength(ASection.FEvents, LIndex + 1);
    ASection.FEvents[LIndex].FBeat := ABeat;
    ASection.FEvents[LIndex].FDuration := ADuration;
    ASection.FEvents[LIndex].FPitch := APitch;
    ASection.FEvents[LIndex].FVoice := AVoice;
    ASection.FEvents[LIndex].FVelocity := AVelocity;
    ASection.FEvents[LIndex].FStyle := ASection.FStyles[LBeat div 4];
  end;

begin
  LPrimary := MusicStyle(MusicDominantStyle(ARequest));
  ASection.FBpm := MusicTempo(ARequest);
  for LBeat := 0 to MusicBeats - 1 do
  begin
    LStyle := MusicStyle(ASection.FStyles[LBeat div 4]);
    LRoot := ASection.FLanes[0][(LBeat div 4) * 4];
    LIntensity := 0.7 + ASection.FLanes[3][LBeat] * 0.1;
    if LBeat mod LStyle.FPadBeats = 0 then
    begin
      for I := 0 to 3 do
      begin
        Add(LBeat, LStyle.FPadBeats * 0.95, Pitch(LRoot + I * 2, 4), 0, 0.14 * LIntensity);
      end;
    end;
    if LBeat mod LStyle.FBassStride = 0 then
    begin
      Add(LBeat, Min(1.6, LStyle.FBassStride * 0.7), Pitch(LRoot, 2), 2, 0.48);
    end;
    LMask := ASection.FLanes[2][LBeat];
    for LStep := 0 to 3 do
    begin
      if ((LMask and (1 shl LStep)) <> 0) and
        ((LBeat * 4 + LStep) mod LStyle.FLeadStride = 0) then
      begin
        LDegree := ASection.FLanes[1][LBeat];
        { The learned highest voice becomes a scale-degree contour. Strong
          beats are harmonized to the current triad; this is an explicit,
          lossy arrangement transform, not an unchanged learned performance. }
        if (LBeat mod 4 = 0) and (LStep = 0) then
        begin
          LDegree := LRoot + 2 * ((LDegree + 7 - LRoot) mod 3);
        end
        else
        begin
          LDegree := LDegree + LStyle.FArpeggio * LStep;
        end;
        Add(LBeat + LStep * 0.25, 0.3 + LStyle.FLeadStride * 0.12,
          Pitch(LDegree, 5), 1, 0.34 * LIntensity);
      end;
    end;
    case LStyle.FDrums of
      1:
      begin
        if LBeat mod 4 = 0 then
        begin
          Add(LBeat, 0.4, 40, 3, 0.5);
        end;
        if LBeat mod 2 = 1 then
        begin
          Add(LBeat + 0.5, 0.1, 90, 4, 0.16);
        end;
      end;
      2, 3, 4:
      begin
        if (LStyle.FDrums = 3) or (LBeat mod 4 = 0) or (LBeat mod 4 = 2) then
        begin
          Add(LBeat, 0.4, 38, 3, 0.6);
        end;
        Add(LBeat + 0.5, 0.12, 92, 4, 0.2);
        if LBeat mod 2 = 1 then
        begin
          Add(LBeat, 0.2, 60, 5, 0.25);
        end;
        if LStyle.FDrums = 4 then
        begin
          Add(LBeat + 0.75, 0.13, 42, 3, 0.28);
          Add(LBeat + 0.25, 0.06, 96, 4, 0.13);
        end;
      end;
    end;
  end;
  for I := 1 to High(ASection.FEvents) do
  begin
    LEvent := ASection.FEvents[I];
    J := I - 1;
    while (J >= 0) and (ASection.FEvents[J].FBeat > LEvent.FBeat) do
    begin
      ASection.FEvents[J + 1] := ASection.FEvents[J];
      Dec(J);
    end;
    ASection.FEvents[J + 1] := LEvent;
  end;
end;

procedure ValidateMusic(const ASection: TMusicSection);
var
  LEvent: TMusicEvent;
  I: Integer;
  LValue: Integer;
begin
  Ensure((ASection.FBpm >= 60) and (ASection.FBpm <= 160), 'Music tempo out of range');
  Ensure(Length(ASection.FStyles) = 8, 'Music arrangement must contain eight bars');
  for I := 0 to MusicLaneCount - 1 do
  begin
    Ensure(Length(ASection.FLanes[I]) = MusicBeats, 'Incomplete music lane');
    for LValue in ASection.FLanes[I] do
    begin
      Ensure((LValue >= 0) and (((I <= 1) and (LValue <= 6)) or
        ((I = 2) and (LValue <= 15)) or ((I = 3) and (LValue <= 3))), 'Music value out of range');
    end;
  end;
  Ensure((Length(ASection.FEvents) > 0) and (Length(ASection.FEvents) < 1024),
    'Music event budget exceeded');
  for LEvent in ASection.FEvents do
  begin
    Ensure((LEvent.FBeat >= 0) and (LEvent.FBeat < MusicBeats) and
      (LEvent.FDuration > 0) and (LEvent.FDuration <= 8) and
      (LEvent.FPitch >= 12) and (LEvent.FPitch <= 108) and
      (LEvent.FVoice >= 0) and (LEvent.FVoice <= 5) and
      (LEvent.FVelocity > 0) and (LEvent.FVelocity <= 1), 'Invalid arranged music event');
  end;
end;

end.
