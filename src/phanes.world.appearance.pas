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

unit phanes.world.appearance;
{$mode delphi}
{$H+}

interface

type
  TAppearanceRGB = record
    FR: Single;
    FG: Single;
    FB: Single;
  end;
  TWorldAppearance = record
    FPalette: String;
    FKey: String;
    FAtmosphere: String;
    FFinish: String;
    FSun: TAppearanceRGB;
    FSky: TAppearanceRGB;
    FTint: TAppearanceRGB;
    FRoughness: Single;
  end;

function SolveWorldAppearance(const ASeed: Cardinal): TWorldAppearance;
function ValidWorldAppearance(const AAppearance: TWorldAppearance): Boolean;

implementation

uses
  SysUtils,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_graph;

function RGB(const AR, AG, AB: Single): TAppearanceRGB;
begin
  Result.FR := AR;
  Result.FG := AG;
  Result.FB := AB;
end;

function ValidWorldAppearance(const AAppearance: TWorldAppearance): Boolean;
begin
  // Independently stated acceptance relationships; no theme appears in this contract.
  Result :=
    (((AAppearance.FPalette = 'sage') and
      ((AAppearance.FKey = 'honey') or (AAppearance.FKey = 'pearl'))) or
     ((AAppearance.FPalette = 'mineral') and
      ((AAppearance.FKey = 'pearl') or (AAppearance.FKey = 'silver'))) or
     ((AAppearance.FPalette = 'ochre') and (AAppearance.FKey = 'honey'))) and
    (((AAppearance.FKey = 'silver') and (AAppearance.FAtmosphere = 'azure')) or
     (((AAppearance.FKey = 'honey') or (AAppearance.FKey = 'pearl')) and
      ((AAppearance.FAtmosphere = 'azure') or (AAppearance.FAtmosphere = 'haze')))) and
    (((AAppearance.FAtmosphere = 'haze') and (AAppearance.FFinish = 'matte')) or
     ((AAppearance.FAtmosphere = 'azure') and
      ((AAppearance.FFinish = 'matte') or (AAppearance.FFinish = 'satin'))));
end;

function SolveWorldAppearance(const ASeed: Cardinal): TWorldAppearance;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LValidation: TWfcSequenceGraphValidationReport;
  LSequence: TWfcGeneratedSequence;
begin
  Result := Default(TWorldAppearance);
  // Four global cells: palette, key light, atmosphere, surface response.
  // These examples encode authored compatibility, not learned aesthetic truth.
  SetLength(LSamples, 6);
  LSamples[0] := MakeWfcSequenceSample(['sage', 'honey', 'haze', 'matte']);
  LSamples[1] := MakeWfcSequenceSample(['sage', 'pearl', 'azure', 'satin']);
  LSamples[2] := MakeWfcSequenceSample(['mineral', 'pearl', 'haze', 'matte']);
  LSamples[3] := MakeWfcSequenceSample(['mineral', 'silver', 'azure', 'matte']);
  LSamples[4] := MakeWfcSequenceSample(['ochre', 'honey', 'azure', 'satin']);
  LSamples[5] := MakeWfcSequenceSample(['sage', 'honey', 'azure', 'matte']);
  LModel := LearnSequenceModelCorpus(LSamples, 2);
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(4, 1, 1);
    LGraph.Seed := ASeed;
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    ApplySequenceModelToGraph(LModel, LGraph, wseWhole);
    IntersectSequenceAllowedTokens(LModel, LGraph, 0, ['sage', 'mineral', 'ochre']);
    IntersectSequenceAllowedTokens(LModel, LGraph, 1, ['honey', 'pearl', 'silver']);
    IntersectSequenceAllowedTokens(LModel, LGraph, 2, ['haze', 'azure']);
    IntersectSequenceAllowedTokens(LModel, LGraph, 3, ['matte', 'satin']);
    LOptions := DefaultGraphSolveOptions;
    if not LGraph.TrySolve(LOptions, LReport) or
      not CaptureSolvedSequence(LModel, LGraph, wseWhole, LSequence, LValidation) then
    begin
      raise Exception.Create('World appearance constraints exhausted');
    end;
    Result.FPalette := LSequence.Tokens[0];
    Result.FKey := LSequence.Tokens[1];
    Result.FAtmosphere := LSequence.Tokens[2];
    Result.FFinish := LSequence.Tokens[3];
    if not ValidWorldAppearance(Result) then
    begin
      raise Exception.Create('World appearance violates the visual contract');
    end;
    Result.FSun := RGB(1, 0.95, 0.83);
    if Result.FKey = 'pearl' then
    begin
      Result.FSun := RGB(1, 0.98, 0.93);
    end
    else if Result.FKey = 'silver' then
    begin
      Result.FSun := RGB(0.86, 0.94, 1);
    end;
    Result.FSky := RGB(0.72, 0.82, 0.85);
    if Result.FAtmosphere = 'haze' then
    begin
      Result.FSky := RGB(0.80, 0.82, 0.76);
    end;
    Result.FTint := RGB(0.94, 1, 0.93);
    if Result.FPalette = 'mineral' then
    begin
      Result.FTint := RGB(0.93, 0.97, 1);
    end
    else if Result.FPalette = 'ochre' then
    begin
      Result.FTint := RGB(1, 0.96, 0.88);
    end;
    Result.FRoughness := 0.82;
    if Result.FFinish = 'satin' then
    begin
      Result.FRoughness := 0.62;
    end;
  finally
    LGraph.Free;
    LModel.Free;
  end;
end;

end.

