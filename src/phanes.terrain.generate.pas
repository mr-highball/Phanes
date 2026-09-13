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

unit phanes.terrain.generate;

{$mode delphi}
{$H+}

interface

uses
  phanes.terrain.types;

function GenerateTerrain(const ARequest: TTerrainRequest; var ACommitted: TTerrainField;
  out AReason: String): Boolean;

implementation

uses
  Math,
  SysUtils,
  wfc,
  phanes.terrain.validate;

function GenerateTerrain(const ARequest: TTerrainRequest; var ACommitted: TTerrainField;
  out AReason: String): Boolean;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LCandidate: TTerrainField;
  LRules: TGraphRules;
  LAllowed: TGraphValues;
  LValues: TGraphValues;
  LDirection: TGraphDirection;
  LMinimum: Integer;
  LMaximum: Integer;
  LValue: Integer;
  LIndex: Integer;
  LX: Integer;
  LZ: Integer;
  I: Integer;
  J: Integer;
  LChanged: Boolean;
begin
  Result := False;
  if not ValidateTerrainRequest(ARequest, AReason) then
  begin
    Exit;
  end;
  { One WFC cell is one shared height vertex. Equal weights choose integer
    levels; reciprocal cardinal rules enforce a Lipschitz rise limit.
    Per-vertex intervals express landform intent. No noise field is sampled or
    relabelled, and no post-solve smoothing can violate fixed heights. }
  LGraph := TGraph.Create;
  try
    LGraph.Seed := ARequest.FSeed;
    LGraph.Reshape(ARequest.FSpec.FColumns, ARequest.FSpec.FRows, 1);
    LGraph.CurrentPass := 'elevation';
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    SetLength(LValues, ARequest.FSpec.FMaximumLevel - ARequest.FSpec.FMinimumLevel + 1);
    for I := 0 to High(LValues) do
    begin
      LValues[I] := 'height-' + IntToStr(I + ARequest.FSpec.FMinimumLevel);
      LGraph.AddValue(LValues[I]);
    end;
    for I := 0 to High(LValues) do
    begin
      LRules := Default(TGraphRules);
      SetLength(LRules, 4);
      for LDirection := gdNorth to gdWest do
      begin
        LAllowed := nil;
        for J := Max(0, I - ARequest.FSpec.FMaximumRise) to
          Min(High(LValues), I + ARequest.FSpec.FMaximumRise) do
        begin
          LAllowed := LAllowed + [LValues[J]];
        end;
        LRules[Ord(LDirection)].Key := LDirection;
        LRules[Ord(LDirection)].Info := False;
        LRules[Ord(LDirection)].Value := LAllowed;
      end;
      LGraph.Rules[LValues[I]].Rules := LRules;
    end;
    for LZ := 0 to ARequest.FSpec.FRows - 1 do
    begin
      for LX := 0 to ARequest.FSpec.FColumns - 1 do
      begin
        LIndex := LZ * ARequest.FSpec.FColumns + LX;
        LMinimum := ARequest.FSpec.FMinimumLevel;
        LMaximum := ARequest.FSpec.FMaximumLevel;
        if Length(ARequest.FDomains) > 0 then
        begin
          LMinimum := ARequest.FDomains[LIndex].FMinimum;
          LMaximum := ARequest.FDomains[LIndex].FMaximum;
        end;
        if TerrainVertexPreserved(ARequest, LX, LZ) then
        begin
          LMinimum := Max(LMinimum, ARequest.FPrevious.FLevels[LIndex]);
          LMaximum := Min(LMaximum, ARequest.FPrevious.FLevels[LIndex]);
        end;
        if LMinimum > LMaximum then
        begin
          AReason := 'The requested landform conflicts with a preserved terrain height at ' +
            IntToStr(LX) + ', ' + IntToStr(LZ) + '.';
          Exit;
        end;
        LAllowed := nil;
        for I := LMinimum to LMaximum do
        begin
          LAllowed := LAllowed + [LValues[I - ARequest.FSpec.FMinimumLevel]];
        end;
        LGraph.SetAllowedValues(LX, LZ, 0, LAllowed);
      end;
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := ARequest.FMaxBacktracks;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'These terrain heights did not resolve within the search allowance. ' +
        'Ease the requested rise or enlarge the editable region.';
      Exit;
    end;
    LCandidate := Default(TTerrainField);
    LCandidate.FSpec := ARequest.FSpec;
    LCandidate.FSeed := ARequest.FSeed;
    SetLength(LCandidate.FLevels, ARequest.FSpec.FColumns * ARequest.FSpec.FRows);
    for LZ := 0 to ARequest.FSpec.FRows - 1 do
    begin
      for LX := 0 to ARequest.FSpec.FColumns - 1 do
      begin
        LValue := ARequest.FSpec.FMinimumLevel - 1;
        for I := 0 to High(LValues) do
        begin
          if LValues[I] = LGraph.Entry[LX, LZ, 0].Value then
          begin
            LValue := I + ARequest.FSpec.FMinimumLevel;
            Break;
          end;
        end;
        LCandidate.FLevels[LZ * ARequest.FSpec.FColumns + LX] := LValue;
      end;
    end;
    for I := 0 to High(LReport.Passes) do
    begin
      Inc(LCandidate.FDecisions, LReport.Passes[I].Decisions);
      Inc(LCandidate.FPropagations, LReport.Passes[I].Propagations);
      Inc(LCandidate.FBacktracks, LReport.Passes[I].Backtracks);
    end;
    LChanged := True;
    if ARequest.FHasPrevious then
    begin
      LChanged := False;
      for I := 0 to High(LCandidate.FLevels) do
      begin
        LChanged := LChanged or (LCandidate.FLevels[I] <> ARequest.FPrevious.FLevels[I]);
      end;
      if not LChanged then
      begin
        LCandidate := CopyTerrainField(ARequest.FPrevious);
      end;
    end;
    if not ValidateTerrainResult(ARequest, LCandidate, AReason) then
    begin
      Exit;
    end;
    if not LChanged then
    begin
      AReason := 'The selected terrain already satisfies these constraints; no height changed.';
    end;
    { Commit only after complete decoded admission. Both ordinary and aliased
      output arguments keep their previous contents on every failure path. }
    ACommitted := LCandidate;
    Result := True;
  finally
    LGraph.Free;
  end;
end;

end.
