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

program PhanesTempoPlans;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, phanes.music.types, phanes.music.track;

var
  LRequest: TMusicRequest;
  LOriginal: TMusicTrackPlan;
  LExtended: TMusicTrackPlan;
  LPrefix: TMusicValues;
  LCount: Integer;
  LSeed: Integer;
  LKeep: Integer;
  I: Integer;
  LP: Integer;
  LQ: Integer;
begin
  LCount := 0;
  for LSeed := 0 to 99 do
  begin
    LRequest := Default(TMusicRequest);
    LRequest.FSeed := LSeed;
    LRequest.FWeights[LSeed mod MusicStyleCount] := 100;
    LRequest.FTempo := 60;
    LOriginal := PlanMusicTrack(LRequest);
    LRequest.FTempo := 160;
    for LKeep := 1 to Length(LOriginal.FPhases) - 1 do
    begin
      LPrefix := Copy(LOriginal.FPhases, 0, LKeep);
      LExtended := ExtendMusicTrack(LRequest, LPrefix, 28);
      if (Length(LExtended.FPhases) <> 28) or (LExtended.FPhases[27] <> 4) or
        (LExtended.FSeconds < 300) then
      begin
        raise Exception.Create('Extended track duration or ending is invalid');
      end;
      for I := 0 to High(LPrefix) do
      begin
        if LExtended.FPhases[I] <> LPrefix[I] then
        begin
          raise Exception.Create('Extension changed an already composed phrase');
        end;
      end;
      for I := 1 to High(LExtended.FPhases) do
      begin
        LP := LExtended.FPhases[I - 1];
        LQ := LExtended.FPhases[I];
        if not (((LP in [0, 1]) and (LQ in [1, 2])) or
          ((LP in [2, 3]) and (LQ in [1, 2, 3, 4]))) then
        begin
          raise Exception.Create('Unobserved macro transition in extended form');
        end;
      end;
      Inc(LCount);
    end;
  end;
  WriteLn(LCount, ' tempo extensions preserve composed prefixes, source transitions, and five-minute form');
end.

