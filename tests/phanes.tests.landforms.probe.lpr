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

program PhanesLandformProbe;
{$mode delphi}
{$H+}
{$modeswitch externalclass}
uses
  JS, Web, SysUtils, phanes.world.types, phanes.world.wire,
  phanes.landforms.validate, phanes.session.wire;

type
  TSnapshotController = class external name 'Object'(TJSObject)
    function snapshot: TJSObject;
  end;

var
  GEvents: TJSArray;
  GFrameStartTime: Double;
  GFrameStartCount: Integer;
  GFrameStartDraws: Integer;

function StyleSnapshot: TJSObject;
begin
  Result := TJSObject(TJSFunction(TJSObject(window)['phanesStyleProbeSnapshot']).call(window));
end;

procedure StartFrames;
begin
  TJSFunction(TJSObject(window)['phanesStyleProbeResetFrames']).call(window);
  GFrameStartTime := window.performance.now;
  GFrameStartCount := Integer(TJSObject(window)['phanesRenderedFrames']);
  GFrameStartDraws := Integer(StyleSnapshot['drawCalls']);
end;

function EndFrames: TJSObject;
begin
  Result := StyleSnapshot;
  Result['sampleMilliseconds'] := window.performance.now - GFrameStartTime;
  Result['renderedFrames'] := Integer(TJSObject(window)['phanesRenderedFrames']) - GFrameStartCount;
  Result['drawCallsDuringSample'] := Integer(Result['drawCalls']) - GFrameStartDraws;
end;

function RecordEvent(AEvent: TJSEvent): Boolean;
var
  LEntry: TJSObject;
  LToggle: TJSElement;
begin
  Result := True;
  LEntry := TJSObject.new;
  LEntry['type'] := AEvent._type;
  LEntry['target'] := TJSElement(AEvent.target).id;
  LEntry['text'] := TJSElement(AEvent.target).textContent;
  LEntry['prevented'] := AEvent.defaultPrevented;
  LEntry['phase'] := AEvent.eventPhase;
  LEntry['time'] := TJSObject(AEvent)['timeStamp'];
  LEntry['disabled'] := TJSObject(AEvent.target)['disabled'];
  LEntry['scrollX'] := window.scrollX;
  LEntry['scrollY'] := window.scrollY;
  LEntry['pointerType'] := TJSObject(AEvent)['pointerType'];
  LEntry['pointerId'] := TJSObject(AEvent)['pointerId'];
  LEntry['trusted'] := AEvent.isTrusted;
  if isObject(TJSObject(AEvent)['sourceCapabilities']) and
    not isNull(TJSObject(AEvent)['sourceCapabilities']) then
  begin
    LEntry['firesTouchEvents'] :=
      TJSObject(TJSObject(AEvent)['sourceCapabilities'])['firesTouchEvents'];
  end;
  if (AEvent._type = 'pointerdown') or (AEvent._type = 'pointerup') then
  begin
    LEntry['primary'] := TJSPointerEvent(AEvent).isPrimary;
    LEntry['pointer'] := TJSPointerEvent(AEvent).pointerId;
  end;
  LToggle := document.getElementById('tools-toggle');
  if LToggle <> nil then
  begin
    LEntry['expanded'] := LToggle.getAttribute('aria-expanded');
  end;
  GEvents.push(LEntry);
  if GEvents.Length > 96 then
  begin
    GEvents.shift;
  end;
end;

function ValidateEdit(const ABefore, ASelection, AOperation: String;
  const AAmount: Integer): TJSObject;
var
  LState: TJSObject;
  LData: TJSObject;
  LCurrent: TWorld;
  LRequest: TWorldRequest;
  LReason: String;
  LAccepted: Boolean;
begin
  Result := TJSObject.new;
  try
    LState := TJSObject(TJSObject(window)['phanesEditor']);
    LCurrent := ReadWorld(TJSObject(LState['world']));
    LData := TJSObject(TJSJSON.parse(ASelection));
    LData['size'] := LCurrent.FSize;
    LData['seed'] := LCurrent.FSeed;
    LData['operation'] := AOperation;
    LData['editLayer'] := 'terrain';
    LData['landformAmount'] := AAmount;
    LData['previous'] := TJSJSON.parse(ABefore);
    LData['assets'] := TJSObject(LState['palette'])['assets'];
    LRequest := ReadRequest(LData);
    LAccepted := ValidateLandformEdit(LRequest, LCurrent, LReason);
    Result['accepted'] := LAccepted;
    Result['reason'] := LReason;
    Result['roundTrip'] := TJSJSON.stringify(WorldJSON(ReadWorld(WorldJSON(LCurrent)))) =
      TJSJSON.stringify(WorldJSON(LCurrent));
  except
    on LException: Exception do
    begin
      Result['accepted'] := False;
      Result['reason'] := LException.Message;
    end;
  end;
end;

function SessionChecks: TJSArray;
const
  CCamera: array[0..9] of String =
    ('camera', 'zoom', 'yaw', 'pitch', 'x', 'y', 'z', 'panX', 'panY', 'panZ');
var
  LState: TJSObject;
  LBase: TJSObject;
  LBad: TJSObject;
  LCamera: TJSObject;
  LKey: String;
  LResults: TJSArray;

  function Clone: TJSObject;
  begin
    Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(LBase)));
  end;

  procedure Check(const AValue: TJSObject; const AExpected: Boolean; const AName: String);
  var
    LAccepted: Boolean;
    LResult: TJSObject;
  begin
    LAccepted := False;
    try
      ValidateSession(AValue, TJSArray(TJSObject(LState['palette'])['assets']));
      LAccepted := True;
    except
      on LException: Exception do
      begin
        LAccepted := False;
      end;
    end;
    LResult := TJSObject.new;
    LResult['name'] := AName;
    LResult['passed'] := LAccepted = AExpected;
    LResults.push(LResult);
  end;

begin
  LState := TJSObject(TJSObject(window)['phanesEditor']);
  LResults := TJSArray.new;
  LBase := TJSObject.new;
  LBase['format'] := 'phanes.session/v1';
  LBase['world'] := LState['world'];
  LBase['history'] := LState['history'];
  LBase['future'] := LState['future'];
  LBase['selection'] := LState['selection'];
  LBase['editing'] := LState['editing'];
  LCamera := TJSObject.new;
  for LKey in CCamera do
  begin
    LCamera[LKey] := LState[LKey];
  end;
  LBase['camera'] := LCamera;
  LBase['interior'] := TSnapshotController(TJSObject(window)['phanesInteriorUI']).snapshot;
  LBase['groundwork'] := TSnapshotController(TJSObject(window)['phanesGroundworkUI']).snapshot;
  LBase['modular'] := TSnapshotController(TJSObject(window)['phanesBuildingUI']).snapshot;
  LBase['landforms'] := TSnapshotController(TJSObject(window)['phanesLandformUI']).snapshot;
  Check(LBase, True, 'Current landform session is admitted');
  LBad := Clone;
  TJSObject(LBad['landforms'])['amount'] := 251;
  Check(LBad, False, 'Unaligned terrain amount is rejected');
  LBad := Clone;
  TJSObject(LBad['landforms'])['amount'] := 0;
  Check(LBad, False, 'Zero height step is rejected');
  LBad := Clone;
  TJSObject(LBad['landforms'])['active'] := 'true';
  Check(LBad, False, 'Text instead of active Boolean is rejected');
  LBad := Clone;
  TJSObject(LBad['landforms'])['active'] := True;
  TJSObject(LBad['modular'])['active'] := True;
  Check(LBad, False, 'Conflicting modular and landform contexts are rejected');
  LBad := Clone;
  TJSObject(LBad['landforms'])['active'] := True;
  TJSObject(LBad['groundwork'])['active'] := True;
  Check(LBad, False, 'Conflicting groundwork and landform contexts are rejected');
  LBad := Clone;
  TJSObject(LBad['landforms'])['active'] := True;
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":1,"depth":1,' +
    '"selectionScale":8,"selectionCells":[]}');
  Check(LBad, False, 'Modular-floor selection cannot masquerade as terrain selection');
  LBad := Clone;
  JSDelete(LBad, 'landforms');
  Check(LBad, True, 'Older session without landform UI context remains valid');
  Result := LResults;
end;

begin
  GEvents := TJSArray.new;
  TJSObject(window)['phanesLandformEvents'] := GEvents;
  document.addEventListener('pointerdown', @RecordEvent, True);
  document.addEventListener('pointerup', @RecordEvent, True);
  document.addEventListener('click', @RecordEvent, True);
  window.addEventListener('click', @RecordEvent, True);
  window.addEventListener('pointerdown', @RecordEvent);
  window.addEventListener('pointerup', @RecordEvent);
  window.addEventListener('touchstart', @RecordEvent);
  window.addEventListener('touchend', @RecordEvent);
  window.addEventListener('touchcancel', @RecordEvent);
  window.addEventListener('mousedown', @RecordEvent);
  window.addEventListener('mouseup', @RecordEvent);
  TJSObject(window)['phanesLandformCheck'] := @ValidateEdit;
  TJSObject(window)['phanesLandformSessionChecks'] := @SessionChecks;
  TJSObject(window)['phanesLandformStartFrames'] := @StartFrames;
  TJSObject(window)['phanesLandformEndFrames'] := @EndFrames;
end.
