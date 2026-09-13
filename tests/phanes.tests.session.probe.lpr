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

program PhanesSessionProbe;
{$mode delphi}
{$H+}
{$modeswitch externalclass}
uses
  JS, Web, SysUtils, phanes.session.wire;
type
  TSnapshotController = class external name 'Object'(TJSObject)
    function snapshot: TJSObject;
  end;
var
  GState: TJSObject;
  GBase: TJSObject;
  GResults: TJSArray;
function CopyValue(const AValue: TJSObject): TJSObject;
begin
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
end;
procedure Check(const AValue: TJSObject; const AValid: Boolean; const AName: String);
var
  LAccepted: Boolean;
  LResult: TJSObject;
begin
  LAccepted := False;
  try
    ValidateSession(AValue, TJSArray(TJSObject(GState['palette'])['assets']));
    LAccepted := True;
  except
    on E: Exception do
    begin
      LAccepted := False;
    end;
  end;
  LResult := TJSObject.new;
  LResult['name'] := AName;
  LResult['passed'] := LAccepted = AValid;
  GResults.push(LResult);
end;
procedure Run;
const
  CCamera: array[0..9] of String =
    ('camera', 'zoom', 'yaw', 'pitch', 'x', 'y', 'z', 'panX', 'panY', 'panZ');
var
  LCamera: TJSObject;
  LBad: TJSObject;
  LHistory: TJSArray;
  LKey: String;
begin
  GState := TJSObject(TJSObject(window)['phanesEditor']);
  GResults := TJSArray.new;
  GBase := TJSObject.new;
  GBase['format'] := 'phanes.session/v1';
  GBase['world'] := GState['world'];
  GBase['history'] := GState['history'];
  GBase['future'] := GState['future'];
  GBase['editing'] := GState['editing'];
  GBase['selection'] := GState['selection'];
  GBase['interior'] := TSnapshotController(TJSObject(window)['phanesInteriorUI']).snapshot;
  GBase['groundwork'] := TSnapshotController(TJSObject(window)['phanesGroundworkUI']).snapshot;
  LCamera := TJSObject.new;
  for LKey in CCamera do
  begin
    LCamera[LKey] := GState[LKey];
  end;
  GBase['camera'] := LCamera;
  Check(GBase, True, 'Complete current session admitted');
  LBad := CopyValue(GBase);
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":2,"depth":1,"selectionScale":1,"selectionCells":[0,1]}');
  Check(LBad, True, 'Regional brush mask admitted without regenerating the world');
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":1,"depth":1,"selectionScale":2,"selectionCells":[0,1]}');
  Check(LBad, True, 'Fine foliage mask admitted');
  LBad['selection'] := TJSJSON.parse('{"x":3,"z":3,"width":1,"depth":1,"selectionScale":1,"selectionCells":[]}');
  Check(LBad, True, 'Cleared selection admitted');
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":1,"depth":1,"selectionScale":1,"selectionCells":[0,0]}');
  Check(LBad, False, 'Duplicate mask cells rejected');
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":1,"depth":1,"selectionScale":1,"selectionCells":[0,1]}');
  Check(LBad, False, 'Mask with mismatching boundary rejected');
  LBad['selection'] := TJSJSON.parse('{"x":0,"z":0,"width":1,"depth":1,"selectionScale":2}');
  Check(LBad, False, 'Mask scale without cells rejected');
  LBad := CopyValue(GBase);
  LBad['selection'] := TJSObject.new;
  Check(LBad, False, 'Missing selection coordinates rejected');
  LBad := CopyValue(GBase);
  LBad['selection'] := TJSArray.new;
  Check(LBad, False, 'Array selection rejected');
  LBad := CopyValue(GBase);
  TJSObject(LBad['camera'])['x'] := 'invalid';
  Check(LBad, False, 'Nonnumeric camera rejected');
  LBad := CopyValue(GBase);
  TJSObject(LBad['groundwork'])['turn'] := 'invalid';
  Check(LBad, False, 'Nonnumeric groundwork direction rejected');
  LBad := CopyValue(GBase);
  TJSObject(LBad['interior'])['selected'] := 'world';
  Check(LBad, False, 'Interior selection outside its room rejected');
  LBad := CopyValue(GBase);
  TJSObject(LBad['interior'])['previousCamera'] := nil;
  Check(LBad, False, 'Missing exterior return pose rejected');
  LBad := CopyValue(GBase);
  LHistory := TJSArray.new;
  LHistory.push(CopyValue(TJSObject(GBase['world'])));
  TJSArray(TJSArray(TJSObject(LHistory[0])['layers'])[1])[0] := 'unknown-asset';
  LBad['history'] := LHistory;
  Check(LBad, False, 'Corrupt undo world rejected independently of current world');
  LBad := CopyValue(GBase);
  LBad['future'] := LHistory;
  Check(LBad, False, 'Corrupt redo world rejected independently of current world');
  TJSObject(window)['phanesSessionChecks'] := GResults;
end;
begin
  TJSObject(window)['phanesSessionProbeRun'] := @Run;
end.
