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

program PhanesLandformChecks;
{$mode delphi}
{$H+}

uses
  SysUtils, Math, phanes.world.types, phanes.world.height, phanes.world.generate,
  phanes.world.validate, phanes.world.edit.validate, phanes.landforms.world,
  phanes.terrain.types, phanes.terrain.validate,
  phanes.composition.types, phanes.composition.document;

var
  GChecks: Integer;
  GRequest: TWorldRequest;
  GBefore: TWorld;
  GAfter: TWorld;
  GRestored: TWorld;
  GReason: String;
  GFirst: TWorldHeight;
  GSecond: TWorldHeight;
  GFound: Boolean;
  GIndex: Integer;
  GX: Integer;
  GZ: Integer;
  I: Integer;

procedure Check(const ACondition: Boolean; const AName: String);
begin
  if not ACondition then
  begin
    raise Exception.Create('FAIL ' + AName + ': ' + GReason);
  end;
  Inc(GChecks);
end;

procedure CheckFreshWorlds;
const
  CIds: array[0..5] of String = ('nature-kit/tree_oak', 'nature-kit/flower_redA',
    'cabin', 'nature-kit/plant_bush', 'nature-kit/crops_wheatStageB', 'nature-kit/rock_largeA');
  CKinds: array[0..5] of String = ('tree', 'flowers', 'cabin', 'shrub', 'wheat', 'rock');
var
  LField: TTerrainField;
  LRepeat: TTerrainField;
  LRequest: TWorldRequest;
  LWorld: TWorld;
  LRestored: TWorld;
  LSize: Integer;
  LSeed: Integer;
  I: Integer;
begin
  for LSize := 4 to 6 do
  begin
    for LSeed := 731 to 734 do
    begin
      LField := Default(TTerrainField);
      Check(GenerateInitialLandform(LSize, LSeed, LField, GReason), 'fresh field generated');
      Check(ValidateTerrainField(LField, GReason), 'fresh field independently admitted');
      Check((LField.FSpec.FColumns = LSize * 2 + 1) and
        (LField.FSpec.FRows = LSize * 2 + 1), 'fresh world grid matches regional extent');
      for I := 0 to High(LField.FLevels) do
      begin
        Check((LField.FLevels[I] >= 4) and (LField.FLevels[I] <= 24),
          'initial dry interval leaves headroom for later edits');
      end;
      Check(GenerateInitialLandform(LSize, LSeed, LRepeat, GReason), 'fresh replay generated');
      Check(SameTerrainField(LField, LRepeat), 'fresh seed replay includes solver counters');
    end;
  end;
  LRequest := Default(TWorldRequest);
  LRequest.FOperation := 'create';
  LRequest.FSize := 4;
  LRequest.FSeed := 731;
  LRequest.FWidth := 4;
  LRequest.FDepth := 4;
  SetLength(LRequest.FAssets, Length(CIds));
  for I := 0 to High(CIds) do
  begin
    LRequest.FAssets[I].FId := CIds[I];
    LRequest.FAssets[I].FKind := CKinds[I];
  end;
  Check(GenerateWorld(LRequest, LWorld, GReason), 'create uses WFC terrain before regional passes');
  Check(ValidateWorld(LWorld, LRequest.FAssets, GReason), 'fresh layered world independently admitted');
  Check((LWorld.FElevation.FSpec.FVersion = TerrainFieldVersion) and
    not LWorld.FRelativeElevation, 'new world stores absolute field');
  Check((LWorld.FDecisions > LWorld.FElevation.FDecisions) and
    (LWorld.FPropagations >= LWorld.FElevation.FPropagations),
    'world statistics include height and regional solves');
  LRequest.FPrevious := LWorld;
  LRequest.FOperation := 'restore';
  Inc(LRequest.FSeed);
  Check(GenerateWorld(LRequest, LRestored, GReason), 'absolute generated world restores');
  Check(SameTerrainField(LWorld.FElevation, LRestored.FElevation) and
    (LWorld.FSeed = LRestored.FSeed), 'restore does not regenerate elevations');
  LRepeat := CopyTerrainField(LField);
  Check(not GenerateInitialLandform(49, 731, LRepeat, GReason), 'unsupported fresh size refused');
  Check(SameTerrainField(LRepeat, LField), 'fresh failure retains output');
end;

begin
  CheckFreshWorlds;
  GBefore := Default(TWorld);
  GBefore.FSize := 4;
  GBefore.FSeed := 731;
  GBefore.FAppearanceSeed := 731;
  GBefore.FComposition := InitialWorldComposition(731);
  for I := 0 to 4 do
  begin
    SetLength(GBefore.FLayers[I], Sqr(LayerSize(4, I)));
    for GIndex := 0 to High(GBefore.FLayers[I]) do
    begin
      GBefore.FLayers[I][GIndex] := 'empty';
      if I = 0 then
      begin
        GBefore.FLayers[I][GIndex] := 'meadow';
      end;
    end;
  end;
  Check(ValidateWorld(GBefore, nil, GReason), 'legacy baseline');
  GRequest := Default(TWorldRequest);
  GRequest.FSize := 4;
  GRequest.FSeed := 732;
  GRequest.FOperation := 'land-raise';
  GRequest.FEditLayer := 'terrain';
  GRequest.FLandformAmount := 1000;
  GRequest.FPrevious := GBefore;
  GRequest.FX := 1;
  GRequest.FZ := 1;
  GRequest.FWidth := 2;
  GRequest.FDepth := 2;
  Check(GenerateWorld(GRequest, GAfter, GReason), 'raise selected legacy land');
  Check(GAfter.FRelativeElevation, 'explicit additive migration');
  Check(ValidateWorld(GAfter, nil, GReason), 'admitted world');
  GFound := False;
  for GIndex := 0 to High(GAfter.FElevation.FLevels) do
  begin
    GX := GIndex mod 9;
    GZ := GIndex div 9;
    Check(GAfter.FElevation.FLevels[GIndex] >= 0, 'raise never lowers');
    if (GX <= 2) or (GX >= 6) or (GZ <= 2) or (GZ >= 6) then
    begin
      Check(GAfter.FElevation.FLevels[GIndex] = 0, 'all boundary and outside vertices retained');
    end;
    GFound := GFound or (GAfter.FElevation.FLevels[GIndex] > 0);
  end;
  Check(GFound, 'raise makes a real change');
  GFirst := TWorldHeight.Create(GBefore);
  GSecond := TWorldHeight.Create(GAfter);
  try
    for GZ := -31 to 31 do
    begin
      for GX := -31 to 31 do
      begin
        if (Abs(GX + 0.125) >= 16) or (Abs(GZ + 0.375) >= 16) then
        begin
          Check(GFirst.Height(GX + 0.125, GZ + 0.375) =
            GSecond.Height(GX + 0.125, GZ + 0.375), 'unchanged outside surface between vertices');
        end;
      end;
    end;
  finally
    GSecond.Free;
    GFirst.Free;
  end;
  Check(GenerateWorld(GRequest, GRestored, GReason), 'repeat same seed');
  Check(SameTerrainField(GAfter.FElevation, GRestored.FElevation), 'exact terrain replay');
  GRequest.FPrevious := GAfter;
  GRequest.FOperation := 'meadow';
  GRequest.FEditLayer := 'terrain';
  Check(GenerateWorld(GRequest, GRestored, GReason), 'regional edit over additive terrain');
  Check(GRestored.FRelativeElevation and SameTerrainField(GAfter.FElevation,
    GRestored.FElevation), 'regional generation retains complete terrain');
  GRestored.FRelativeElevation := False;
  Check(not ValidateRegionalEdit(GRequest, GRestored, GReason), 'mode-only forgery rejected');

  GRequest.FPrevious := GBefore;
  GRequest.FOperation := 'land-soften';
  GRequest.FEditLayer := 'terrain';
  Check(GenerateWorld(GRequest, GRestored, GReason), 'soften flat offsets');
  Check(SameTerrainField(GRestored.FElevation, GBefore.FElevation) and
    (GRestored.FSeed = GBefore.FSeed) and not GRestored.FRelativeElevation,
    'no-op retains exact legacy contract');

  GBefore.FComposition.FNodes[0].FLocked := True;
  GRequest.FPrevious := GBefore;
  GRequest.FOperation := 'land-raise';
  GRestored := GAfter;
  Check(not GenerateLandform(GRequest, GRestored, GReason), 'world lock rejects shaping');
  Check(SameTerrainField(GRestored.FElevation, GAfter.FElevation), 'failed output retained');
  WriteLn(GChecks, ' landform checks passed');
end.
