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
program PhanesAudioLoadProbe;

{$mode delphi}
{$H+}

uses
  JS, Web;

var
  GStart: TJSFunction;
  GStop: TJSFunction;
  GStats: TJSObject;
  GEvents: TJSArray;
  GNext: Integer;

function Started(AWhen: JSValue): JSValue;
var
  LNode: TJSObject;
  LContext: TJSObject;
  LRow: TJSObject;
begin
  asm
    LNode = this;
  end;
  LContext := TJSObject(LNode['context']);
  Inc(GNext);
  LNode['phanesProbeVoiceId'] := GNext;
  LRow := TJSObject.new;
  LRow['kind'] := 'start';
  LRow['id'] := GNext;
  LRow['when'] := AWhen;
  LRow['now'] := LContext['currentTime'];
  LRow['wall'] := window.performance.now;
  GEvents.push(LRow);
  Result := GStart.apply(LNode, [AWhen]);
end;

function Stopped(AWhen: JSValue): JSValue;
var
  LNode: TJSObject;
  LContext: TJSObject;
  LRow: TJSObject;
begin
  asm
    LNode = this;
  end;
  LContext := TJSObject(LNode['context']);
  LRow := TJSObject.new;
  LRow['kind'] := 'stop';
  LRow['id'] := LNode['phanesProbeVoiceId'];
  LRow['when'] := AWhen;
  LRow['now'] := LContext['currentTime'];
  LRow['wall'] := window.performance.now;
  GEvents.push(LRow);
  Result := GStop.apply(LNode, [AWhen]);
end;

var
  LPrototype: TJSObject;
begin
  GStats := TJSObject.new;
  GEvents := TJSArray.new;
  GStats['events'] := GEvents;
  TJSObject(window)['phanesAudioLoadProbe'] := GStats;
  LPrototype := TJSObject(TJSObject(TJSObject(window)['AudioScheduledSourceNode'])['prototype']);
  GStart := TJSFunction(LPrototype['start']);
  GStop := TJSFunction(LPrototype['stop']);
  LPrototype['start'] := @Started;
  LPrototype['stop'] := @Stopped;
end.
