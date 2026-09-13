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

program PhanesTerrainBench;
{$mode delphi}
{$H+}

uses
  SysUtils,
  phanes.terrain.types,
  phanes.terrain.generate,
  phanes.terrain.validate
  {$ifdef PAS2JS}
  , JS
  {$endif}
  ;

function Milliseconds: Double;
begin
  {$ifdef PAS2JS}
  Result := TJSDate.now;
  {$else}
  Result := GetTickCount64;
  {$endif}
end;

procedure Measure(const ASize, ALevels: Integer; const AMaximumRise: Integer = 2);
var
  LRequest: TTerrainRequest;
  LField: TTerrainField;
  LStarted: Double;
  LReason: String;
begin
  LRequest := Default(TTerrainRequest);
  LRequest.FSpec.FVersion := 1;
  LRequest.FSpec.FColumns := ASize;
  LRequest.FSpec.FRows := ASize;
  LRequest.FSpec.FSpacing := 8000;
  LRequest.FSpec.FLevelStep := 500;
  LRequest.FSpec.FMaximumLevel := ALevels - 1;
  LRequest.FSpec.FMaximumRise := AMaximumRise;
  LRequest.FWidth := ASize - 1;
  LRequest.FDepth := ASize - 1;
  LRequest.FSeed := 99173;
  LStarted := Milliseconds;
  if not GenerateTerrain(LRequest, LField, LReason) or
    not ValidateTerrainResult(LRequest, LField, LReason) then
  begin
    raise Exception.Create(LReason);
  end;
  WriteLn('Terrain vertices=', ASize * ASize, ' levels=', ALevels,
    ' maximumRise=', AMaximumRise,
    ' elapsedMs=', Round(Milliseconds - LStarted),
    ' decisions=', LField.FDecisions, ' propagations=', LField.FPropagations,
    ' backtracks=', LField.FBacktracks);
end;

begin
  Measure(17, 9);
  Measure(33, 17);
  Measure(49, 33);
  Measure(97, 65);
  Measure(97, 65, 64);
end.
