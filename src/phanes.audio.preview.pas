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

unit phanes.audio.preview;

{$mode delphi}
{$H+}

interface

uses
  JS,
  WebAudio;

function RenderMusicPreview(const ASections: TJSArray): TJSPromise;
function AudioWave(const ABuffer: TJSAudioBuffer): TJSArrayBuffer;

implementation

uses
  SysUtils,
  Math,
  phanes.music.types,
  phanes.music.wire,
  phanes.audio.synth;

function RenderMusicPreview(const ASections: TJSArray): TJSPromise;
var
  LContext: TJSOfflineAudioContext;
  LSynth: TPhanesSynth;
  LSection: TMusicSection;
  LDuration: Double;
  LStart: Double;
  LSeconds: Double;
  LEvent: TMusicEvent;
  LTasks: TJSArray;
  I: Integer;

  procedure Schedule(const AIndex: Integer; const AStart: Double);
  var
    LPart: TMusicSection;
    LNote: TMusicEvent;
    LBeatSeconds: Double;
  begin
    LPart := ReadMusicSection(TJSObject(ASections[AIndex]));
    LBeatSeconds := 60 / LPart.FBpm;
    for LNote in LPart.FEvents do
    begin
      LSynth.Tone(AStart + LNote.FBeat * LBeatSeconds, LNote.FDuration * LBeatSeconds,
        LNote.FPitch, LNote.FVoice, LNote.FStyle, LNote.FVelocity);
    end;
  end;

  procedure ScheduleFollowing(const AIndex: Integer; const AStart: Double);
  begin
    // Yield offline rendering before each movement. Future filters and oscillators
    // need not process silence for the preceding several minutes of the track.
    LTasks.push(LContext.suspend(AStart - 0.1)._then(function(AValue: JSValue): JSValue
      begin
        Schedule(AIndex, AStart);
        Result := LContext.resume;
      end));
  end;
begin
  if not TJSArray.isArray(ASections) or (ASections.Length < 1) or (ASections.Length > 32) then
  begin
    raise Exception.Create('A listening render contains one to 32 phrases');
  end;
  LDuration := 2;
  for I := 0 to ASections.Length - 1 do
  begin
    LSection := ReadMusicSection(TJSObject(ASections[I]));
    if (LSection.FBpm < 60) or (LSection.FBpm > 160) then
    begin
      raise Exception.Create('Invalid preview tempo');
    end;
    LDuration := LDuration + MusicBeats * 60 / LSection.FBpm;
  end;
  if LDuration > 720 then
  begin
    raise Exception.Create('A listening render cannot exceed twelve minutes');
  end;
  LContext := TJSOfflineAudioContext.new(2, Ceil(LDuration * 44100), 44100);
  LSynth := TPhanesSynth.Create(LContext, 32768);
  LSynth.Volumes(0.65, 0);
  LTasks := TJSArray.new;
  LTasks.push(nil);
  LStart := 0.05;
  for I := 0 to ASections.Length - 1 do
  begin
    LSection := ReadMusicSection(TJSObject(ASections[I]));
    LSeconds := 60 / LSection.FBpm;
    for LEvent in LSection.FEvents do
    begin
      if (LEvent.FDuration <= 0) or (LEvent.FDuration > 8) or
        (LEvent.FBeat < 0) or (LEvent.FBeat >= MusicBeats) or
        (LEvent.FVelocity <= 0) or (LEvent.FVelocity > 1) then
      begin
        raise Exception.Create('Invalid listening preview event');
      end;
    end;
    if I = 0 then
    begin
      Schedule(I, LStart);
    end
    else
    begin
      ScheduleFollowing(I, LStart);
    end;
    LStart := LStart + MusicBeats * LSeconds;
  end;
  LTasks[0] := LContext.startRendering;
  Result := TJSPromise.all(LTasks)._then(function(AValues: JSValue): JSValue
    begin
      Result := TJSArray(AValues)[0];
    end);
end;

function AudioWave(const ABuffer: TJSAudioBuffer): TJSArrayBuffer;
var
  LView: TJSDataView;
  LChannel: TJSFloat32Array;
  LSample: Double;
  LOffset: Integer;
  I: Integer;
  J: Integer;
begin
  Result := TJSArrayBuffer.new(44 + ABuffer.length_ * 4);
  LView := TJSDataView.new(Result);
  LView.setUint32(0, $52494646, False);
  LView.setUint32(4, Result.byteLength - 8, True);
  LView.setUint32(8, $57415645, False);
  LView.setUint32(12, $666D7420, False);
  LView.setUint32(16, 16, True);
  LView.setUint16(20, 1, True);
  LView.setUint16(22, 2, True);
  LView.setUint32(24, Round(ABuffer.sampleRate), True);
  LView.setUint32(28, Round(ABuffer.sampleRate) * 4, True);
  LView.setUint16(32, 4, True);
  LView.setUint16(34, 16, True);
  LView.setUint32(36, $64617461, False);
  LView.setUint32(40, ABuffer.length_ * 4, True);
  for J := 0 to 1 do
  begin
    LChannel := ABuffer.getChannelData(J);
    for I := 0 to ABuffer.length_ - 1 do
    begin
      LSample := Max(-1, Min(1, LChannel[I]));
      LOffset := 44 + I * 4 + J * 2;
      LView.setInt16(LOffset, Round(LSample * 32767), True);
    end;
  end;
end;

end.
