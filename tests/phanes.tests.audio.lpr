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

program PhanesAudioBrowserTests;

{$mode delphi}
{$H+}

uses
  JS,
  Web,
  WebOrWorker,
  SysUtils;

var
  GWorker: TJSWorker;
  GCorpus: TJSObject;
  GQueue: TJSArray;
  GStatus: TJSObject;
  GStep: Integer;
  GBase: String;
  GLoad: TJSXMLHttpRequest;
  GPlan: String;

function Request(const ACommand: String; const AIndex: Integer = 0): TJSObject;
begin
  Result := TJSObject.new;
  Result['command'] := ACommand;
  Result['seed'] := 911 + AIndex * 104729;
  Result['index'] := AIndex;
  Result['tempo'] := 60;
  Result['style'] := 5;
  Result['blendStyle'] := 4;
  Result['blend'] := 30;
  Result['weights'] := TJSArray.new(0, 0, 0, 0, 0, 60, 40, 0, 0, 0);
  Result['locks'] := TJSArray.new(False, False, False, False);
  if ACommand = 'initialize' then
  begin
    Result['corpus'] := GCorpus;
  end;
end;

procedure Add(const AName: String; const AMessage: TJSObject; const AExpected: Boolean);
var
  LRow: TJSObject;
begin
  LRow := TJSObject.new;
  LRow['name'] := AName;
  LRow['message'] := AMessage;
  LRow['expected'] := AExpected;
  GQueue.push(LRow);
end;

procedure Finish(const APassed: Boolean; const AReason: String);
begin
  GStatus['completed'] := True;
  GStatus['passed'] := APassed;
  GStatus['message'] := AReason;
  if GWorker <> nil then
  begin
    GWorker.terminate;
  end;
end;

procedure SendNext;
var
  LMessage: TJSObject;
begin
  if GStep >= GQueue.Length then
  begin
    Finish(True, IntToStr(GStep) + ' Pascal worker protocol checks passed');
    Exit;
  end;
  LMessage := TJSObject(TJSObject(GQueue[GStep])['message']);
  LMessage['job'] := GStep;
  GWorker.postMessage(LMessage);
end;

function Receive(AEvent: TJSEvent): Boolean;
var
  LMessage: TJSObject;
  LRow: TJSObject;
  LRequest: TJSObject;
  LTrack: TJSObject;
  LCount: Integer;
  I: Integer;
begin
  Result := True;
  LMessage := TJSObject(TJSMessageEvent(AEvent).Data);
  LRow := TJSObject(GQueue[GStep]);
  if not isBoolean(LMessage['success']) or
    (Boolean(LMessage['success']) <> Boolean(LRow['expected'])) or
    (Integer(LMessage['job']) <> GStep) then
  begin
    Finish(False, String(LRow['name']) + ': ' + TJSJSON.stringify(LMessage));
    Exit;
  end;
  TJSArray(GStatus['checks']).push(LRow['name']);
  if (String(LRow['name']) = 'lower minimum keeps plan') or
    (String(LRow['name']) = 'equal minimum keeps plan') then
  begin
    if TJSJSON.stringify(LMessage['phases']) <> GPlan then
    begin
      Finish(False, 'An idempotent extension changed the admitted plan');
      Exit;
    end;
  end;
  if GStep = 7 then
  begin
    LTrack := TJSObject(LMessage['track']);
    if Double(LTrack['seconds']) < 300 then
    begin
      Finish(False, 'Track shorter than five minutes');
      Exit;
    end;
    LCount := TJSArray(LTrack['phases']).Length;
    GPlan := TJSJSON.stringify(LTrack['phases']);
    Add('future index rejected', Request('track-next', 1), False);
    Add('first track section', Request('track-next'), True);
    Add('duplicate rejected', Request('track-next'), False);
    LRequest := Request('track-next', 1);
    LRequest['locks'] := TJSArray.new(True, False, False, False);
    Add('changed locks require new track', LRequest, False);
    LRequest := Request('extend-track', 1);
    LRequest['minimumSections'] := 6;
    Add('lower minimum keeps plan', LRequest, True);
    LRequest := Request('extend-track', 1);
    LRequest['minimumSections'] := LCount;
    Add('equal minimum keeps plan', LRequest, True);
    LRequest := Request('extend-track', 2);
    LRequest['minimumSections'] := LCount + 4;
    Add('wrong extension index rejected', LRequest, False);
    LRequest := Request('extend-track', 1);
    LRequest['minimumSections'] := LCount + 4;
    LRequest['locks'] := TJSArray.new(True, False, False, False);
    Add('changed extension locks rejected', LRequest, False);
    LRequest := Request('extend-track', 1);
    LRequest['minimumSections'] := LCount + 4;
    Add('monotonic extension accepted', LRequest, True);
    LCount := LCount + 4;
    for I := 1 to LCount - 1 do
    begin
      Add('section ' + IntToStr(I), Request('track-next', I), True);
    end;
    Add('exhausted track rejected', Request('track-next', LCount), False);
    Add('initialize resets track', Request('initialize'), True);
    Add('stale plan rejected', Request('track-next'), False);
  end;
  Inc(GStep);
  SendNext;
end;

function Loaded(AEvent: TJSProgressEvent): Boolean;
var
  LRequest: TJSObject;
begin
  Result := True;
  if GLoad.status <> 200 then
  begin
    Finish(False, 'Could not load music test corpus');
    Exit;
  end;
  GCorpus := TJSObject(TJSJSON.parse(GLoad.responseText));
  GWorker := TJSWorker.new(GBase + 'phanes.music.worker.js');
  GWorker.addEventListener('message', @Receive);
  Add('initialize', Request('initialize'), True);
  Add('next before track', Request('track-next'), False);
  LRequest := Request('begin-track');
  LRequest['tempo'] := '120';
  Add('bad tempo type', LRequest, False);
  LRequest := Request('begin-track');
  LRequest['weights'] := TJSObject.new;
  Add('bad weights type', LRequest, False);
  LRequest := Request('begin-track');
  LRequest['weights'] := TJSArray.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  Add('no connected styles', LRequest, False);
  LRequest := Request('begin-track');
  LRequest['tempo'] := 161;
  Add('out of range tempo', LRequest, False);
  Add('explicit pair ignores disconnected legacy setting', Request('next'), True);
  Add('begin valid track', Request('begin-track'), True);
  SendNext;
end;

begin
  GStatus := TJSObject.new;
  GStatus['completed'] := False;
  GStatus['checks'] := TJSArray.new;
  TJSObject(window)['phanesAudioTests'] := GStatus;
  GQueue := TJSArray.new;
  GBase := String(TJSObject(window)['phanesTestBase']);
  GLoad := TJSXMLHttpRequest.new;
  GLoad.open('GET', GBase + 'data/music/corpus.json', True);
  GLoad.onload := @Loaded;
  GLoad.send;
  window.setTimeout(procedure
    begin
      if not Boolean(GStatus['completed']) then
      begin
        Finish(False, 'Music protocol test timed out');
      end;
    end, 120000);
end.
