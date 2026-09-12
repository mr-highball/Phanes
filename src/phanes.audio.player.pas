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

unit phanes.audio.player;

{$mode delphi}
{$H+}

interface

procedure StartAudioUI;

implementation

uses
  JS,
  Web,
  WebOrWorker,
  WebAudio,
  SysUtils,
  Math,
  phanes.music.types,
  phanes.audio.synth,
  phanes.audio.dimension,
  phanes.audio.preview;

type
  TAudioPlayer = class
  private
    FContext: TJSAudioContext;
    FSynth: TPhanesSynth;
    FEffectsContext: TJSAudioContext;
    FEffectsSynth: TPhanesSynth;
    FCorpus: TJSObject;
    FWorker: TJSWorker;
    FCurrent: TJSObject;
    FQueued: TJSObject;
    FResumeSection: TJSObject;
    FStats: TJSObject;
    FJob: Integer;
    FIndex: Integer;
    FEvent: Integer;
    FPending: Boolean;
    FEnabled: Boolean;
    FStart: Double;
    FRendered: String;
    FWasSolving: Boolean;
    FCamera: String;
    FMoveX: Double;
    FMoveZ: Double;
    FStepTime: Double;
    FSelection: Integer;
    FSelectionTime: Double;
    FTrack: TJSObject;
    FTrackSeeds: TJSUint32Array;
    FTrackId: String;
    FTrackStart: Double;
    FQueuedStart: Double;
    FNextVisual: Double;
    FTempoAt: Double;
    FTempoBpm: Double;
    FTempoStart: Double;
    FDeferredTempo: Double;
    FPlanMinimum: Integer;
    FPlanTempo: Double;
    FExtendingPlan: Boolean;
    procedure FreshTrack;
    procedure ScheduleSection(const ASection: TJSObject; const AStart: Double;
      const AFromBeat: Double = 0; const ABpm: Double = 0);
    procedure ChangeTempo(const ABpm: Double);
    procedure CommitTempo;
    procedure EnsureContext;
    procedure BeginWorker;
    procedure RequestSection;
    procedure Restart;
    procedure SetStatus(const AText: String);
    procedure ShowSection;
    procedure ApplyVolumes;
    procedure Tick;
    procedure InteractionFeedback;
    function Toggle(AEvent: TJSEvent): Boolean;
    function Evolve(AEvent: TJSEvent): Boolean;
    function VolumeChanged(AEvent: TJSEvent): Boolean;
    function Feedback(AEvent: TJSEvent): Boolean;
    function Receive(AEvent: TJSEvent): Boolean;
    function WorkerError(AEvent: TJSEvent): Boolean;
    function Visibility(AEvent: TJSEvent): Boolean;
    function OpenPanel(AEvent: TJSEvent): Boolean;
    function ClosePanel(AEvent: TJSEvent): Boolean;
    function PanelKey(AEvent: TJSEvent): Boolean;
    function ExportPhrase(AEvent: TJSEvent): Boolean;
  public
    constructor Create;
  end;

var
  GPlayer: TAudioPlayer;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

procedure TAudioPlayer.SetStatus(const AText: String);
begin
  Element('music-status').textContent := AText;
  FStats['status'] := AText;
end;

procedure TAudioPlayer.EnsureContext;
begin
  if FContext = nil then
  begin
    FContext := TJSAudioContext.new;
    FSynth := TPhanesSynth.Create(FContext, 4096);
    FEffectsContext := TJSAudioContext.new;
    FEffectsSynth := TPhanesSynth.Create(FEffectsContext);
    FContext.suspend;
    ApplyVolumes;
  end;
  FEffectsContext.resume;
  if FEnabled then
  begin
    FContext.resume;
  end;
end;

procedure TAudioPlayer.ApplyVolumes;
var
  LMusic: Double;
begin
  if FSynth = nil then
  begin
    Exit;
  end;
  LMusic := 0;
  if FEnabled then
  begin
    LMusic := StrToIntDef(TJSHTMLInputElement(Element('music-volume')).value, 30) / 100;
  end;
  FSynth.Volumes(LMusic, 0);
  FEffectsSynth.Volumes(0,
    StrToIntDef(TJSHTMLInputElement(Element('effects-volume')).value, 40) / 100);
end;

function TAudioPlayer.VolumeChanged(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  ApplyVolumes;
end;

procedure TAudioPlayer.BeginWorker;
var
  LMessage: TJSObject;
begin
  if (FCorpus = nil) or not FEnabled then
  begin
    Exit;
  end;
  if FWorker <> nil then
  begin
    FWorker.terminate;
  end;
  FWorker := TJSWorker.new('phanes.music.worker.js');
  FStats['workerStarts'] := Integer(FStats['workerStarts']) + 1;
  FWorker.addEventListener('message', @Receive);
  FWorker.addEventListener('error', @WorkerError);
  Inc(FJob);
  LMessage := TJSObject.new;
  LMessage['job'] := FJob;
  LMessage['command'] := 'initialize';
  LMessage['corpus'] := FCorpus;
  LMessage['previous'] := FResumeSection;
  FPending := True;
  FWorker.postMessage(LMessage);
  SetStatus('Finding a new musical possibility...');
end;

procedure TAudioPlayer.RequestSection;
var
  LMessage: TJSObject;
  LLocks: TJSArray;
  I: Integer;
begin
  if FPending or (FWorker = nil) or not FEnabled then
  begin
    Exit;
  end;
  if (FTrack <> nil) and
    (FIndex >= TJSArray(FTrack['phases']).Length) then
  begin
    Exit;
  end;
  if FTrackSeeds = nil then
  begin
    FreshTrack;
  end;
  Inc(FJob);
  LMessage := TJSObject.new;
  LMessage['job'] := FJob;
  if FTrack = nil then
  begin
    LMessage['command'] := 'begin-track';
  end
  else if FPlanTempo > 0 then
  begin
    LMessage['command'] := 'extend-track';
    FExtendingPlan := True;
  end else
  begin
    LMessage['command'] := 'track-next';
  end;
  LMessage['seed'] := FTrackSeeds[FIndex] and $7FFFFFFF;
  LMessage['index'] := FIndex;
  LMessage['style'] := StrToIntDef(TJSHTMLSelectElement(Element('music-style')).value, 0);
  LMessage['blendStyle'] := StrToIntDef(TJSHTMLSelectElement(Element('music-blend-style')).value, 4);
  LMessage['blend'] := StrToIntDef(TJSHTMLInputElement(Element('music-blend')).value, 30);
  LMessage['weights'] := MusicDimensionWeights;
  LMessage['minimumSections'] := FPlanMinimum;
  if MusicDimensionTempo > 0 then
  begin
    LMessage['tempo'] := MusicDimensionTempo;
  end;
  LLocks := TJSArray.new;
  for I := 0 to MusicLaneCount - 1 do
  begin
    LLocks.push(TJSHTMLInputElement(Element('music-lock-' + IntToStr(I))).checked);
  end;
  LMessage['locks'] := LLocks;
  FPending := True;
  FWorker.postMessage(LMessage);
end;

procedure TAudioPlayer.FreshTrack;
var
  I: Integer;
begin
  FTrackSeeds := TJSUint32Array.new(40);
  window.crypto.getRandomValues(FTrackSeeds);
  FTrackId := '';
  for I := 0 to 3 do
  begin
    FTrackId := FTrackId + IntToHex(FTrackSeeds[I], 8);
  end;
  FTrack := nil;
  FTrackStart := 0;
  FPlanMinimum := 0;
  FIndex := 0;
  FStats['track'] := nil;
  FStats['section'] := nil;
  FStats['trackId'] := FTrackId;
  FStats['error'] := nil;
end;

procedure TAudioPlayer.ShowSection;
var
  LFocus: TJSArray;
  LReferences: TJSArray;
  LReference: TJSObject;
  LDescription: String;
  I: Integer;
  J: Integer;
begin
  FStats['section'] := FCurrent;
  LFocus := TJSArray(FCurrent['focus']);
  LReferences := TJSArray(FCorpus['references']);
  LDescription := '';
  for I := 0 to LFocus.Length - 1 do
  begin
    for J := 0 to LReferences.Length - 1 do
    begin
      LReference := TJSObject(LReferences[J]);
      if String(LReference['id']) = String(LFocus[I]) then
      begin
        if LDescription <> '' then
        begin
          LDescription := LDescription + ' / ';
        end;
        LDescription := LDescription + MusicLaneName(I) + ': ' + String(LReference['title']);
        Break;
      end;
    end;
  end;
  Element('music-sources').textContent := LDescription;
  SetStatus('Movement ' + IntToStr(Integer(FCurrent['index']) + 1) + ' of ' +
    IntToStr(TJSArray(FTrack['phases']).Length) + ' / ' +
    IntToStr(Round(Double(FCurrent['bpm']))) + ' BPM');
end;

function TAudioPlayer.Receive(AEvent: TJSEvent): Boolean;
var
  LMessage: TJSObject;
  LTempo: Double;
begin
  Result := True;
  LMessage := TJSObject(TJSMessageEvent(AEvent).Data);
  if Integer(LMessage['job']) <> FJob then
  begin
    Exit;
  end;
  FPending := False;
  if not isBoolean(LMessage['success']) or not Boolean(LMessage['success']) then
  begin
    if FExtendingPlan then
    begin
      FExtendingPlan := False;
      FPlanTempo := 0;
      FPlanMinimum := 0;
      FStats['tempoPending'] := FTempoAt > 0;
      SetStatus('The current music is preserved · ' + String(LMessage['message']));
      if FQueued = nil then
      begin
        RequestSection;
      end;
      Exit;
    end;
    SetStatus(String(LMessage['message']) + '. Evolve to try a fresh phrase.');
    FStats['error'] := LMessage['message'];
    Exit;
  end;
  if FExtendingPlan then
  begin
    FExtendingPlan := False;
    FStats['planExtensions'] := Integer(FStats['planExtensions']) + 1;
    FTrack['phases'] := LMessage['phases'];
    LTempo := FPlanTempo;
    FPlanTempo := 0;
    FPlanMinimum := 0;
    ChangeTempo(LTempo);
    if FQueued = nil then
    begin
      RequestSection;
    end;
    Exit;
  end;
  if isBoolean(LMessage['ready']) and Boolean(LMessage['ready']) then
  begin
    FStats['references'] := LMessage['references'];
    FStats['states'] := LMessage['states'];
    RequestSection;
  end
  else if isObject(LMessage['track']) and (LMessage['track'] <> nil) then
  begin
    FTrack := TJSObject(LMessage['track']);
    FTrack['id'] := FTrackId;
    FTrack['elapsed'] := 0;
    FStats['track'] := FTrack;
    RequestSection;
  end
  else
  begin
    if isArray(LMessage['phases']) then
    begin
      FTrack['phases'] := LMessage['phases'];
    end;
    FQueued := TJSObject(LMessage['section']);
    Inc(FIndex);
    if FCurrent = nil then
    begin
      FCurrent := FQueued;
      FQueued := nil;
      FStart := FContext.currentTime + 0.75;
      if FTrackStart = 0 then
      begin
        FTrackStart := FStart;
      end;
      FEvent := 0;
      ScheduleSection(FCurrent, FStart);
      ShowSection;
      if FDeferredTempo > 0 then
      begin
        ChangeTempo(FDeferredTempo);
      end;
      RequestSection;
    end
    else
    begin
      if FTempoAt > 0 then
      begin
        FQueued['bpm'] := FTempoBpm;
        FQueuedStart := FTempoStart + MusicBeats * 60 / FTempoBpm;
      end else
      begin
        FQueued['bpm'] := FCurrent['bpm'];
        FQueuedStart := FStart + MusicBeats * 60 / Double(FCurrent['bpm']);
      end;
      ScheduleSection(FQueued, FQueuedStart);
      if FPlanTempo > 0 then
      begin
        RequestSection;
      end;
    end;
  end;
end;

function TAudioPlayer.WorkerError(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if AEvent.currentTarget <> FWorker then
  begin
    Exit;
  end;
  FPending := False;
  FExtendingPlan := False;
  FPlanTempo := 0;
  FPlanMinimum := 0;
  FDeferredTempo := 0;
  FStats['tempoPending'] := FTempoAt > 0;
  FStats['error'] := 'Music worker stopped';
  FWorker.terminate;
  FWorker := nil;
  Inc(FJob);
  SetStatus('The music generator stopped. Evolve to retry.');
end;

procedure TAudioPlayer.Restart;
begin
  FTempoAt := 0;
  FDeferredTempo := 0;
  FPlanTempo := 0;
  FPlanMinimum := 0;
  FExtendingPlan := False;
  FStats['tempoPending'] := False;
  if FCurrent <> nil then
  begin
    FResumeSection := FCurrent;
  end;
  FCurrent := nil;
  FQueued := nil;
  FEvent := 0;
  if FWorker <> nil then
  begin
    FWorker.terminate;
    FWorker := nil;
  end;
  Inc(FJob);
  FPending := False;
  FreshTrack;
  if FSynth <> nil then
  begin
    FSynth.StopMusic;
  end;
  BeginWorker;
  if not FEnabled then
  begin
    SetStatus('Your connections are ready. Play to create a new track.');
  end;
end;

function TAudioPlayer.Evolve(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if (TJSElement(AEvent.target).id = 'music-tempo') or
    (TJSElement(AEvent.target).closest('#tempo-auto') <> nil) then
  begin
    if FCurrent <> nil then
    begin
      ChangeTempo(StrToIntDef(Element('tempo-value').textContent, 100));
    end else
    begin
      FDeferredTempo := StrToIntDef(Element('tempo-value').textContent, 100);
    end;
    Exit;
  end;
  if (TJSElement(AEvent.target).id = 'music-style') or
    (TJSElement(AEvent.target).id = 'music-blend-style') or
    (TJSElement(AEvent.target).id = 'music-blend') then
  begin
    UseMusicDimensionPair;
  end;
  Restart;
end;

function TAudioPlayer.Toggle(AEvent: TJSEvent): Boolean;
var
  LRequest: TJSXMLHttpRequest;
  LReferences: TJSArray;
  LReference: TJSObject;
  LItem: TJSHTMLElement;
  LLink: TJSHTMLAnchorElement;
  I: Integer;
begin
  Result := True;
  EnsureContext;
  FEnabled := not FEnabled;
  FStats['playing'] := FEnabled;
  if not FEnabled then
  begin
    FContext.suspend;
    Element('music-toggle').textContent := 'Resume music';
    Element('music-toggle').setAttribute('data-transport', 'play');
    SetStatus('Music paused');
  end
  else
  begin
    FContext.resume;
    Element('music-toggle').textContent := 'Pause music';
    Element('music-toggle').setAttribute('data-transport', 'pause');
    if FCurrent <> nil then
    begin
      ShowSection;
      if (FQueued = nil) or (FPlanTempo > 0) then
      begin
        RequestSection;
      end;
    end
    else if FCorpus <> nil then
    begin
      BeginWorker;
    end
    else
    begin
      SetStatus('Loading the musical reference library...');
      LRequest := TJSXMLHttpRequest.new;
      LRequest.open('GET', 'data/music/corpus.json', True);
      LRequest.onload := function(AResponse: TJSProgressEvent): Boolean
        begin
          Result := True;
          if LRequest.status <> 200 then
          begin
            SetStatus('Could not load the musical reference library.');
            Exit;
          end;
          FCorpus := TJSObject(TJSJSON.parse(LRequest.responseText));
          LReferences := TJSArray(FCorpus['references']);
          Element('music-count').textContent := IntToStr(LReferences.Length) +
            ' source scores / 10 styles';
          Element('music-credits-list').textContent := '';
          for I := 0 to LReferences.Length - 1 do
          begin
            LReference := TJSObject(LReferences[I]);
            LItem := TJSHTMLElement(document.createElement('li'));
            LLink := TJSHTMLAnchorElement(document.createElement('a'));
            LLink.href := String(LReference['url']);
            LLink.target := '_blank';
            LLink.rel := 'noreferrer';
            LLink.textContent := String(LReference['title']);
            LItem.appendChild(LLink);
            LItem.appendChild(document.createTextNode(' / ' + String(LReference['composer']) +
              ' / ' + String(LReference['license'])));
            Element('music-credits-list').appendChild(LItem);
          end;
          BeginWorker;
        end;
      LRequest.onerror := function(AError: TJSProgressEvent): Boolean
        begin
          Result := True;
          SetStatus('Could not load music. Pause and resume to retry.');
        end;
      LRequest.send;
    end;
  end;
  ApplyVolumes;
  Element('music-mobile-toggle').textContent := Element('music-toggle').textContent;
  Element('music-mobile-toggle').setAttribute('data-transport',
    Element('music-toggle').getAttribute('data-transport'));
end;

procedure TAudioPlayer.ScheduleSection(const ASection: TJSObject; const AStart: Double;
  const AFromBeat: Double; const ABpm: Double);
var
  LEvents: TJSArray;
  LEvent: TJSArray;
  LSeconds: Double;
  LWhen: Double;
  I: Integer;
begin
  LSeconds := 60 / Double(ASection['bpm']);
  if ABpm > 0 then
  begin
    LSeconds := 60 / ABpm;
  end;
  LEvents := TJSArray(ASection['events']);
  for I := 0 to LEvents.Length - 1 do
  begin
    LEvent := TJSArray(LEvents[I]);
    if Double(LEvent[0]) < AFromBeat - 0.00001 then
    begin
      Continue;
    end;
    LWhen := AStart + Double(LEvent[0]) * LSeconds;
    if LWhen >= FContext.currentTime - 0.04 then
    begin
      if FSynth.Tone(LWhen, Double(LEvent[1]) * LSeconds, Integer(LEvent[2]),
        Integer(LEvent[3]), Integer(LEvent[5]), Double(LEvent[4])) then
      begin
        FStats['scheduledEvents'] := Integer(FStats['scheduledEvents']) + 1;
      end else
      begin
        FStats['droppedEvents'] := Integer(FStats['droppedEvents']) + 1;
      end;
    end
    else
    begin
      FStats['lateEvents'] := Integer(FStats['lateEvents']) + 1;
    end;
  end;
end;

procedure TAudioPlayer.CommitTempo;
var
  LNext: Double;
begin
  if (FTempoAt = 0) or (FContext.currentTime < FTempoAt) then
  begin
    Exit;
  end;
  FCurrent['bpm'] := FTempoBpm;
  FStart := FTempoStart;
  FTrack['bpm'] := FTempoBpm;
  FTrack['seconds'] := FStart - FTrackStart +
    (TJSArray(FTrack['phases']).Length - Integer(FCurrent['index'])) *
      MusicBeats * 60 / FTempoBpm;
  FStats['tempoChanges'] := Integer(FStats['tempoChanges']) + 1;
  FStats['tempoPending'] := False;
  FTempoAt := 0;
  ShowSection;
  if FDeferredTempo > 0 then
  begin
    LNext := FDeferredTempo;
    FDeferredTempo := 0;
    ChangeTempo(LNext);
  end;
end;

procedure TAudioPlayer.ChangeTempo(const ABpm: Double);
var
  LBeat: Double;
  LSeconds: Double;
  LNewStart: Double;
  LNeeded: Integer;
begin
  if (ABpm < 60) or (ABpm > 160) then
  begin
    Exit;
  end;
  if FCurrent = nil then
  begin
    FDeferredTempo := ABpm;
    Exit;
  end;
  CommitTempo;
  if FExtendingPlan then
  begin
    FPlanTempo := ABpm;
    Exit;
  end;
  FPlanTempo := 0;
  FPlanMinimum := 0;
  LSeconds := 60 / Double(FCurrent['bpm']);
  FStats['tempoPending'] := True;
  SetStatus(IntToStr(Round(ABpm)) + ' BPM on the next bar · keep listening');
  if FTempoAt > 0 then
  begin
    if FTempoAt - FContext.currentTime < 0.35 then
    begin
      { Audio for this imminent bar is already committed. Keep its clock
        intact and coalesce the latest request for the following bar. }
      FDeferredTempo := ABpm;
      Exit;
    end;
    LBeat := (FTempoAt - FStart) / LSeconds;
  end else
  begin
    LBeat := Ceil((FContext.currentTime + 0.35 - FStart) / (LSeconds * 4)) * 4;
  end;
  if LBeat >= MusicBeats then
  begin
    FDeferredTempo := ABpm;
    Exit;
  end;
  FDeferredTempo := 0;
  LNewStart := FStart + LBeat * LSeconds - LBeat * 60 / ABpm;
  LNeeded := Integer(FCurrent['index']) +
    Ceil(Max(0, 304 - (LNewStart - FTrackStart)) * ABpm / (MusicBeats * 60));
  if (LNeeded > TJSArray(FTrack['phases']).Length) and
    (FIndex + Ord(FPending) >= TJSArray(FTrack['phases']).Length) then
  begin
    FStats['tempoPending'] := False;
    SetStatus('The landing is already composed · this tempo starts with the next track');
    Exit;
  end;
  if LNeeded > TJSArray(FTrack['phases']).Length then
  begin
    if FTempoAt > 0 then
    begin
      FDeferredTempo := ABpm;
      Exit;
    end;
    { Do not alter any scheduled voice or clock until the worker has
      admitted a longer form that preserves all already composed phrases. }
    FPlanMinimum := LNeeded;
    FPlanTempo := ABpm;
    SetStatus('Preparing a longer musical journey · current music continues');
    RequestSection;
    Exit;
  end;
  FTempoAt := FStart + LBeat * LSeconds;
  FTempoBpm := ABpm;
  FTempoStart := FTempoAt - LBeat * 60 / ABpm;
  FSynth.CancelFutureMusic(FTempoAt);
  ScheduleSection(FCurrent, FTempoStart, LBeat, ABpm);
  FQueuedStart := FTempoStart + MusicBeats * 60 / ABpm;
  if FQueued <> nil then
  begin
    FQueued['bpm'] := ABpm;
    ScheduleSection(FQueued, FQueuedStart);
  end;
end;

procedure TAudioPlayer.Tick;
var
  LSeconds: Double;
  LEnd: Double;
  LRendered: String;
begin
  if window.performance.now >= FNextVisual then
  begin
    UpdateMusicDimension(FStats);
    FNextVisual := window.performance.now + 100;
  end;
  if FContext <> nil then
  begin
    FStats['audioTime'] := FContext.currentTime;
    FStats['sectionStart'] := FStart;
    FStats['queuedStart'] := FQueuedStart;
    FStats['tempoAt'] := FTempoAt;
    FStats['planPending'] := FExtendingPlan;
    if FCurrent <> nil then
    begin
      FStats['activeBpm'] := FCurrent['bpm'];
    end;
    InteractionFeedback;
    FStats['contextState'] := FContext.state;
    FStats['activeVoices'] := FSynth.ActiveVoices;
    FStats['scheduledVoices'] := FSynth.ScheduledVoices;
    LRendered := document.body.getAttribute('data-rendered-revision');
    if LRendered <> FRendered then
    begin
      FRendered := LRendered;
      FEffectsSynth.Tone(FEffectsContext.currentTime + 0.01, 0.12, 72, 1, 1, 0.4, True);
      FEffectsSynth.Tone(FEffectsContext.currentTime + 0.1, 0.15, 79, 1, 1, 0.3, True);
    end;
  end;
  if not FEnabled or (FCurrent = nil) or (FContext.state <> 'running') then
  begin
    Exit;
  end;
  CommitTempo;
  LSeconds := 60 / Double(FCurrent['bpm']);
  FTrack['elapsed'] := Max(0, Min(Double(FTrack['seconds']), FContext.currentTime - FTrackStart));
  FTrack['beat'] := Max(0, (FContext.currentTime - FStart) / LSeconds);
  FTrack['section'] := FCurrent['index'];
  FTrack['phase'] := FCurrent['phase'];
  LEnd := FStart + MusicBeats * LSeconds;
  if FContext.currentTime >= LEnd then
  begin
    if FQueued <> nil then
    begin
      FCurrent := FQueued;
      FQueued := nil;
      FStart := FQueuedStart;
      FEvent := 0;
      ShowSection;
      if FDeferredTempo > 0 then
      begin
        ChangeTempo(FDeferredTempo);
      end;
      RequestSection;
    end
    else if (FIndex >= TJSArray(FTrack['phases']).Length) and
      (FContext.currentTime >= LEnd) then
    begin
      FStats['completedTracks'] := Integer(FStats['completedTracks']) + 1;
      FStats['lastCompletedTrack'] := FTrack;
      Restart;
    end
    else if FContext.currentTime > LEnd then
    begin
      FStats['underruns'] := Integer(FStats['underruns']) + 1;
      FCurrent := nil;
      SetStatus('Preparing the next phrase...');
    end;
  end;
end;

procedure TAudioPlayer.InteractionFeedback;
var
  LEditor: TJSObject;
  LBusy: Boolean;
  LCamera: String;
  LX: Double;
  LZ: Double;
  LNow: Double;
  LSelection: Integer;
begin
  LEditor := TJSObject(TJSObject(window)['phanesEditor']);
  if LEditor = nil then
  begin
    Exit;
  end;
  LNow := FEffectsContext.currentTime;
  LBusy := isObject(LEditor['worker']) and (LEditor['worker'] <> nil);
  if LBusy and not FWasSolving then
  begin
    FEffectsSynth.Tone(LNow + 0.005, 0.14, 60, 6, 0, 0.1, True);
    FEffectsSynth.Tone(LNow + 0.08, 0.15, 72, 1, 1, 0.15, True);
  end
  else if FWasSolving and not LBusy and
    (document.body.getAttribute('data-last-solve') = 'failed') then
  begin
    FEffectsSynth.Tone(LNow + 0.005, 0.08, 62, 1, 0, 0.25, True);
    FEffectsSynth.Tone(LNow + 0.1, 0.12, 57, 1, 0, 0.2, True);
  end;
  FWasSolving := LBusy;
  LCamera := String(LEditor['camera']);
  if (FCamera <> '') and (LCamera <> FCamera) then
  begin
    FEffectsSynth.Tone(LNow + 0.005, 0.09, 67, 1, 1, 0.2, True);
  end;
  FCamera := LCamera;
  LX := Double(LEditor['x']);
  LZ := Double(LEditor['z']);
  if LCamera = 'walk' then
  begin
    if ((Abs(LX - FMoveX) + Abs(LZ - FMoveZ)) > 1.6) and (LNow - FStepTime > 0.25) then
    begin
      FEffectsSynth.Tone(LNow + 0.005, 0.035, 40, 6, 0, 0.2, True);
      FStepTime := LNow;
      FMoveX := LX;
      FMoveZ := LZ;
    end;
  end
  else
  begin
    FMoveX := LX;
    FMoveZ := LZ;
  end;
  LSelection := Integer(TJSObject(window)['phanesSelectionVersion']);
  if (LSelection <> FSelection) and (LNow - FSelectionTime > 0.14) then
  begin
    FEffectsSynth.Tone(LNow + 0.005, 0.025, 84, 1, 0, 0.1, True);
    FSelectionTime := LNow;
  end;
  FSelection := LSelection;
end;

function TAudioPlayer.Feedback(AEvent: TJSEvent): Boolean;
var
  LTarget: TJSElement;
  LButton: TJSElement;
  LPitch: Integer;
begin
  Result := True;
  LTarget := TJSElement(AEvent.target);
  LButton := LTarget.closest('button');
  if (LButton = nil) and (LTarget.id <> 'castle-canvas') then
  begin
    Exit;
  end;
  EnsureContext;
  LPitch := 79;
  if (LButton <> nil) and (LButton.id = 'undo') then
  begin
    LPitch := 64;
  end;
  FEffectsSynth.Tone(FEffectsContext.currentTime + 0.005, 0.035, LPitch, 1, 0, 0.2, True);
end;

function TAudioPlayer.Visibility(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if FContext <> nil then
  begin
    if document.hidden or (AEvent._type = 'freeze') or
      Boolean(TJSObject(window)['phanesRecovering']) then
    begin
      FContext.suspend;
      FEffectsContext.suspend;
    end
    else
    begin
      if FEnabled then
      begin
        FContext.resume;
      end;
      FEffectsContext.resume;
    end;
  end;
end;

function TAudioPlayer.OpenPanel(AEvent: TJSEvent): Boolean;
var
  LBackground: TJSNodeList;
  I: Integer;
begin
  Result := True;
  { Opening another dimension releases held movement and pending authoring
    before rendering pauses. Closing it cannot resume a former gesture. }
  window.dispatchEvent(TJSEvent.new('blur'));
  Element('audio-panel').classList.add('audio-visible');
  TJSObject(window)['phanesWorldCovered'] := True;
  Element('open-audio').setAttribute('aria-expanded', 'true');
  LBackground := document.querySelectorAll('header, main, footer');
  for I := 0 to LBackground.length - 1 do
  begin
    TJSElement(LBackground[I]).setAttribute('inert', '');
  end;
  Element('audio-panel').scrollTop := 0;
  Element('close-audio').focus;
end;

function TAudioPlayer.ClosePanel(AEvent: TJSEvent): Boolean;
var
  LBackground: TJSNodeList;
  I: Integer;
begin
  Result := True;
  Element('audio-panel').classList.remove('audio-visible');
  TJSObject(window)['phanesWorldCovered'] := False;
  LBackground := document.querySelectorAll('header, main, footer');
  for I := 0 to LBackground.length - 1 do
  begin
    TJSElement(LBackground[I]).removeAttribute('inert');
  end;
  Element('open-audio').setAttribute('aria-expanded', 'false');
  Element('open-audio').focus;
end;

function TAudioPlayer.PanelKey(AEvent: TJSEvent): Boolean;
var
  LKey: TJSKeyboardEvent;
  LCandidates: TJSNodeList;
  LFirst: TJSHTMLElement;
  LLast: TJSHTMLElement;
  LElement: TJSHTMLElement;
  I: Integer;
begin
  Result := True;
  LKey := TJSKeyboardEvent(AEvent);
  if LKey.key = 'Escape' then
  begin
    AEvent.preventDefault;
    ClosePanel(AEvent);
  end
  else if LKey.key = 'Tab' then
  begin
    LFirst := nil;
    LLast := nil;
    LCandidates := Element('audio-panel').querySelectorAll('button, input, select, summary, a[href]');
    for I := 0 to LCandidates.length - 1 do
    begin
      LElement := TJSHTMLElement(LCandidates[I]);
      if (LElement.offsetWidth > 0) and not LElement.hasAttribute('disabled') then
      begin
        if LFirst = nil then
        begin
          LFirst := LElement;
        end;
        LLast := LElement;
      end;
    end;
    if LKey.shiftKey and (document.activeElement = LFirst) then
    begin
      AEvent.preventDefault;
      LLast.focus;
    end
    else if not LKey.shiftKey and (document.activeElement = LLast) then
    begin
      AEvent.preventDefault;
      LFirst.focus;
    end;
  end;
end;

constructor TAudioPlayer.Create;
const
  CSelects: array[0..1] of String = ('music-style', 'music-blend-style');
var
  I: Integer;
  LSelect: String;
  LOption: TJSHTMLOptionElement;
begin
  inherited Create;
  FStats := TJSObject.new;
  FStats['playing'] := False;
  FStats['scheduledEvents'] := 0;
  FStats['workerStarts'] := 0;
  FStats['planExtensions'] := 0;
  FStats['droppedEvents'] := 0;
  FStats['tempoChanges'] := 0;
  FStats['tempoPending'] := False;
  FStats['lateEvents'] := 0;
  FStats['underruns'] := 0;
  FStats['completedTracks'] := 0;
  TJSObject(window)['phanesAudioState'] := FStats;
  TJSObject(window)['phanesRenderMusicPreview'] := @RenderMusicPreview;
  TJSObject(window)['phanesAudioWave'] := @AudioWave;
  for LSelect in CSelects do
  begin
    for I := 0 to MusicStyleCount - 1 do
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := IntToStr(I);
      LOption.textContent := MusicStyle(I).FName;
      Element(LSelect).appendChild(LOption);
    end;
  end;
  TJSHTMLSelectElement(Element('music-blend-style')).value := '4';
  TJSHTMLSelectElement(Element('music-style')).value := '5';
  TJSHTMLInputElement(Element('music-blend')).value := '0';
  StartMusicDimension(@Evolve);
  Element('music-toggle').addEventListener('click', @Toggle);
  Element('music-evolve').addEventListener('click', @Evolve);
  Element('music-mobile-toggle').addEventListener('click', @Toggle);
  Element('music-mobile-new').addEventListener('click', @Evolve);
  Element('music-export').addEventListener('click', @ExportPhrase);
  Element('music-volume').addEventListener('input', @VolumeChanged);
  Element('effects-volume').addEventListener('input', @VolumeChanged);
  Element('music-style').addEventListener('change', @Evolve);
  Element('music-blend-style').addEventListener('change', @Evolve);
  Element('music-blend').addEventListener('change', @Evolve);
  for I := 0 to MusicLaneCount - 1 do
  begin
    Element('music-lock-' + IntToStr(I)).addEventListener('change', @Evolve);
  end;
  Element('open-audio').addEventListener('click', @OpenPanel);
  Element('close-audio').addEventListener('click', @ClosePanel);
  Element('audio-panel').addEventListener('keydown', @PanelKey);
  document.addEventListener('click', @Feedback);
  document.addEventListener('visibilitychange', @Visibility);
  document.addEventListener('freeze', @Visibility);
  document.addEventListener('resume', @Visibility);
  Element('castle-canvas').addEventListener('webglcontextlost', @Visibility);
  window.setInterval(@Tick, 25);
end;

function TAudioPlayer.ExportPhrase(AEvent: TJSEvent): Boolean;
var
  LSections: TJSArray;
  LButton: TJSHTMLButtonElement;
begin
  Result := True;
  if FCurrent = nil then
  begin
    SetStatus('Play a phrase first, then export its sound.');
    Exit;
  end;
  LButton := TJSHTMLButtonElement(Element('music-export'));
  LButton.disabled := True;
  LSections := TJSArray.new;
  LSections.push(FCurrent);
  RenderMusicPreview(LSections)._then(function(AValue: JSValue): JSValue
    var
      LBytes: TJSArrayBuffer;
      LBlob: TJSBlob;
      LOptions: TJSBlobInit;
      LLink: TJSHTMLAnchorElement;
      LUrl: String;
    begin
      LBytes := AudioWave(TJSAudioBuffer(AValue));
      LOptions := TJSBlobInit.new;
      LOptions['type'] := 'audio/wav';
      LBlob := TJSBlob.new([LBytes], LOptions);
      LUrl := TJSURL.createObjectURL(LBlob);
      LLink := TJSHTMLAnchorElement(document.createElement('a'));
      LLink.href := LUrl;
      LLink.download := 'phanes-phrase.wav';
      LLink.click;
      window.setTimeout(procedure
        begin
          TJSURL.revokeObjectURL(LUrl);
        end, 1000);
      LButton.disabled := False;
      Result := Undefined;
    end).catch(function(AError: JSValue): JSValue
      begin
        LButton.disabled := False;
        SetStatus('The phrase could not be exported. Try again.');
        Result := Undefined;
      end);
end;

procedure StartAudioUI;
begin
  GPlayer := TAudioPlayer.Create;
end;

end.
