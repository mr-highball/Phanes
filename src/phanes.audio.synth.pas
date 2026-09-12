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

unit phanes.audio.synth;

{$mode delphi}
{$H+}

interface

uses
  JS,
  Web,
  WebAudio;

type
  TPhanesSynth = class
  private
    FContext: TJSBaseAudioContext;
    FMusic: TJSGainNode;
    FMusicOutput: TJSGainNode;
    FEffects: TJSGainNode;
    FEcho: TJSDelayNode;
    FNoise: TJSAudioBuffer;
    FNodes: TJSArray;
    FVoiceLimit: Integer;
  public
    constructor Create(const AContext: TJSBaseAudioContext; const AVoiceLimit: Integer = 128);
    function Tone(const ATime, ADuration: Double; const APitch, AVoice, AStyle: Integer;
      const AVelocity: Double; const AEffect: Boolean = False): Boolean;
    procedure Volumes(const AMusic, AEffects: Double);
    procedure StopMusic;
    procedure CancelFutureMusic(const AFrom: Double);
    function ActiveVoices: Integer;
    function ScheduledVoices: Integer;
  end;

implementation

uses
  Math,
  phanes.music.types;

constructor TPhanesSynth.Create(const AContext: TJSBaseAudioContext; const AVoiceLimit: Integer);
var
  LMaster: TJSDynamicsCompressorNode;
  LEchoGain: TJSGainNode;
  LEchoFilter: TJSBiquadFilterNode;
  LNoiseData: TJSFloat32Array;
  LRandom: Cardinal;
  I: Integer;
begin
  inherited Create;
  FContext := AContext;
  FVoiceLimit := AVoiceLimit;
  FNodes := TJSArray.new;
  FMusic := FContext.createGain;
  FMusicOutput := FContext.createGain;
  FEffects := FContext.createGain;
  LMaster := FContext.createDynamicsCompressor;
  LMaster.threshold.value := -14;
  LMaster.ratio.value := 4;
  LMaster.attack.value := 0.005;
  LMaster.release.value := 0.15;
  FMusic.connect(FMusicOutput);
  FMusicOutput.connect(LMaster);
  FEffects.connect(LMaster);
  LMaster.connect(FContext.destination);
  FEcho := FContext.createDelay(1);
  FEcho.delayTime.value := 0.375;
  LEchoGain := FContext.createGain;
  LEchoGain.gain.value := 0.23;
  LEchoFilter := FContext.createBiquadFilter;
  LEchoFilter.type_ := 'lowpass';
  LEchoFilter.frequency.value := 1800;
  FMusic.connect(FEcho);
  FEcho.connect(LEchoFilter);
  LEchoFilter.connect(LEchoGain);
  LEchoGain.connect(FMusicOutput);
  LEchoGain.connect(FEcho);
  FNoise := FContext.createBuffer(1, Trunc(FContext.sampleRate), FContext.sampleRate);
  LNoiseData := FNoise.getChannelData(0);
  LRandom := 731;
  for I := 0 to LNoiseData.Length - 1 do
  begin
    LRandom := (LRandom * 1664525 + 1013904223) and $7FFFFFFF;
    LNoiseData[I] := LRandom / $40000000 - 1;
  end;
  Volumes(0.3, 0.4);
end;

procedure TPhanesSynth.Volumes(const AMusic, AEffects: Double);
begin
  FMusicOutput.gain.setTargetAtTime(Max(0, Min(1, AMusic)), FContext.currentTime, 0.035);
  FEffects.gain.setTargetAtTime(Max(0, Min(1, AEffects)), FContext.currentTime, 0.015);
end;

function TPhanesSynth.ActiveVoices: Integer;
var
  LRow: TJSObject;
  I: Integer;
begin
  Result := 0;
  for I := 0 to FNodes.Length - 1 do
  begin
    LRow := TJSObject(FNodes[I]);
    if (Double(LRow['start']) <= FContext.currentTime) and
      (Double(LRow['end']) >= FContext.currentTime) then
    begin
      Inc(Result);
    end;
  end;
end;

function TPhanesSynth.ScheduledVoices: Integer;
begin
  Result := FNodes.Length;
end;

procedure TPhanesSynth.StopMusic;
var
  LRow: TJSObject;
  I: Integer;
begin
  for I := 0 to FNodes.Length - 1 do
  begin
    LRow := TJSObject(FNodes[I]);
    if not Boolean(LRow['effect']) then
    begin
      TJSGainNode(LRow['gain']).gain.cancelScheduledValues(FContext.currentTime);
      TJSGainNode(LRow['gain']).gain.setTargetAtTime(0.0001, FContext.currentTime, 0.015);
      TJSAudioScheduledSourceNode(LRow['source']).stop(FContext.currentTime + 0.08);
    end;
  end;
end;

procedure TPhanesSynth.CancelFutureMusic(const AFrom: Double);
var
  LRow: TJSObject;
  I: Integer;
begin
  for I := FNodes.Length - 1 downto 0 do
  begin
    LRow := TJSObject(FNodes[I]);
    if not Boolean(LRow['effect']) and (Double(LRow['start']) >= AFrom - 0.00001) then
    begin
      { These voices have not sounded. Their replacements use the new beat
        clock; already sounding envelopes and echo tails remain untouched. }
      TJSGainNode(LRow['gain']).gain.cancelScheduledValues(0);
      TJSGainNode(LRow['gain']).gain.setValueAtTime(0, FContext.currentTime);
      TJSAudioScheduledSourceNode(LRow['source']).stop(FContext.currentTime);
      FNodes.splice(I, 1);
    end;
  end;
end;

function TPhanesSynth.Tone(const ATime, ADuration: Double;
  const APitch, AVoice, AStyle: Integer; const AVelocity: Double; const AEffect: Boolean): Boolean;
var
  LEnvelope: TJSGainNode;
  LFilter: TJSBiquadFilterNode;
  LPan: TJSStereoPannerNode;
  LOscillator: TJSOscillatorNode;
  LNoiseSource: TJSAudioBufferSourceNode;
  LSource: TJSAudioScheduledSourceNode;
  LStyle: TMusicStyle;
  LAttack: Double;
  LRelease: Double;
  LLevel: Double;
  LStart: Double;
  LEnd: Double;
  LRow: TJSObject;
begin
  Result := False;
  if FNodes.Length >= FVoiceLimit then
  begin
    Exit;
  end;
  LStyle := MusicStyle(AStyle);
  LStart := Max(ATime, FContext.currentTime);
  LEnvelope := FContext.createGain;
  LFilter := FContext.createBiquadFilter;
  LFilter.type_ := 'lowpass';
  LFilter.frequency.value := LStyle.FBrightness;
  LFilter.Q.value := 0.7;
  LPan := FContext.createStereoPanner;
  LPan.pan.value := 0;
  LAttack := 0.008;
  LRelease := 0.12;
  LLevel := AVelocity * 0.32;
  if AVoice >= 4 then
  begin
    LNoiseSource := FContext.createBufferSource;
    LNoiseSource.buffer := FNoise;
    LSource := LNoiseSource;
    LFilter.type_ := 'highpass';
    LFilter.frequency.value := 4500;
    if AVoice = 5 then
    begin
      LFilter.frequency.value := 1500;
    end;
    if AVoice = 6 then
    begin
      LFilter.type_ := 'lowpass';
      LFilter.frequency.value := 650;
    end;
    LAttack := 0.002;
    LRelease := 0.04;
  end
  else
  begin
    LOscillator := FContext.createOscillator;
    LOscillator.type_ := 'triangle';
    LOscillator.frequency.value := 440 * Power(2, (APitch - 69) / 12);
    LSource := LOscillator;
    case AVoice of
      0:
      begin
        LOscillator.type_ := 'sawtooth';
        LOscillator.detune.value := (APitch mod 3 - 1) * 5;
        LAttack := 0.65;
        LRelease := 0.9;
        LPan.pan.value := (APitch mod 5 - 2) * 0.19;
        LFilter.frequency.value := LStyle.FBrightness * 0.7;
      end;
      1:
      begin
        if AStyle mod 2 = 0 then
        begin
          LOscillator.type_ := 'sine';
        end;
        LPan.pan.value := (APitch mod 7 - 3) * 0.1;
        LRelease := 0.45;
      end;
      2:
      begin
        LOscillator.type_ := 'sawtooth';
        LFilter.frequency.setValueAtTime(600, LStart);
        LFilter.frequency.exponentialRampToValueAtTime(160, LStart + 0.25);
        LLevel := LLevel * 0.8;
      end;
      3:
      begin
        LOscillator.type_ := 'sine';
        LOscillator.frequency.setValueAtTime(125, LStart);
        LOscillator.frequency.exponentialRampToValueAtTime(42, LStart + 0.15);
        LAttack := 0.003;
        LRelease := 0.08;
        LLevel := LLevel * 1.6;
      end;
    end;
  end;
  LEnd := LStart + Max(LAttack + 0.01, ADuration);
  LEnvelope.gain.setValueAtTime(0.0001, LStart);
  LEnvelope.gain.linearRampToValueAtTime(LLevel, LStart + LAttack);
  LEnvelope.gain.exponentialRampToValueAtTime(Max(0.0002, LLevel * 0.6), LEnd);
  LEnvelope.gain.exponentialRampToValueAtTime(0.0001, LEnd + LRelease);
  LSource.connect(LFilter);
  LFilter.connect(LEnvelope);
  LEnvelope.connect(LPan);
  if AEffect then
  begin
    LPan.connect(FEffects);
  end
  else
  begin
    LPan.connect(FMusic);
  end;
  LRow := TJSObject.new;
  LRow['source'] := LSource;
  LRow['gain'] := LEnvelope;
  LRow['effect'] := AEffect;
  LRow['start'] := LStart;
  LRow['end'] := LEnd + LRelease;
  FNodes.push(LRow);
  LSource.onended := function(AEvent: TJSEvent): Boolean
    var
      LIndex: Integer;
    begin
      Result := True;
      LSource.disconnect;
      LFilter.disconnect;
      LEnvelope.disconnect;
      LPan.disconnect;
      LIndex := FNodes.indexOf(LRow);
      if LIndex >= 0 then
      begin
        FNodes.splice(LIndex, 1);
      end;
    end;
  LSource.start(LStart);
  LSource.stop(LEnd + LRelease + 0.02);
  Result := True;
end;

end.
