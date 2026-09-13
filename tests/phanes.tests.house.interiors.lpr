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

program PhanesHouseInteriorChecks;
{$mode delphi}
{$H+}
uses
  SysUtils, Math, FPJSON, phanes.tools.files, phanes.world.types,
  phanes.world.generate, phanes.world.validate, phanes.composition.types,
  phanes.composition.document, phanes.interiors.catalog, phanes.groundworks.assembly,
  phanes.catalog.admission;
var
  LAssets: TAssets;
  LPalette: TJSONObject;
  LBase: TWorld;
  LWorld: TWorld;
  LBad: TWorld;
  LChanged: TWorld;
  LRequest: TWorldRequest;
  LAsset: TInteriorAsset;
  LNode: TCompositionNode;
  LReason: String;
  LChecks: Integer;
  LX: Double;
  LZ: Double;
  I: Integer;
  J: Integer;
  K: Integer;
  LSeed: Integer;
  LHouse: Integer;
  LTurn: Integer;
  LPlotId: String;
  LFoundation: TWorld;
  LAttached: TWorld;
const
  CHouses: array[0..1] of String =
    ('city-kit-suburban/building-type-a', 'city-kit-suburban/building-type-f');

procedure Check(const AOkay: Boolean; const ACase: String);
begin
  Inc(LChecks);
  Require(AOkay, ACase + ': ' + LReason);
end;

function Clone(const AWorld: TWorld): TWorld;
var
  LLayer: Integer;
begin
  Result := AWorld;
  Result.FComposition := CopyDocument(AWorld.FComposition);
  for LLayer := 0 to 4 do
  begin
    Result.FLayers[LLayer] := Copy(AWorld.FLayers[LLayer]);
  end;
end;

procedure CheckOptionalContents(const AWorld: TWorld; const ARequest: TWorldRequest);
var
  LIds: TOptionalAssetIds;
  LAdmission: TOptionalAssetAdmission;
  LEdit: TWorldRequest;
  LResult: TWorld;
  LLocked: TWorld;
  LTarget: Integer;
  LIndex: TCompositionIndex;
  LCategory: String;
  LGroup: String;
  LOther: Integer;
  A: Integer;
  B: Integer;
begin
  LIds := OptionalAssetIds;
  for A := 0 to High(LIds) do
  begin
    Check(OptionalAssetAdmission(LIds[A], LAdmission), 'Every catalog ID has a profile');
    if LAdmission.FDomain <> oadInterior then
    begin
      Continue;
    end;
    InteriorContentGroup(LIds[A], LCategory, LGroup);
    Check((LCategory <> '') and (LGroup <> ''), 'Every interior choice has navigation metadata');
    LTarget := -1;
    for B := 0 to High(AWorld.FComposition.FNodes) do
    begin
      if (AWorld.FComposition.FNodes[B].FKind = ckObject) and
        (AWorld.FComposition.FNodes[B].FRole = LAdmission.FRole) and
        (AWorld.FComposition.FNodes[B].FSupportId <> '') then
      begin
        LTarget := B;
        Break;
      end;
    end;
    Check(LTarget >= 0, 'The furnished world contains the admitted role ' + LAdmission.FRole);
    LEdit := ARequest;
    LEdit.FPrevious := AWorld;
    LEdit.FOperation := 'contents';
    LEdit.FObjectId := AWorld.FComposition.FNodes[LTarget].FId;
    LEdit.FContentAsset := LIds[A];
    Check(GenerateWorld(LEdit, LResult, LReason), 'Actual support accepts ' + LIds[A]);
    Check(ValidateWorld(LResult, LAssets, LReason), 'Optional replacement passes world validation');
    LIndex := TCompositionIndex.Create(LResult.FComposition.FNodes);
    try
      Check(LResult.FComposition.FNodes[LIndex.Find(LEdit.FObjectId)].FAssetId = LIds[A],
        'The requested optional asset is the published result');
      Check(Length(LResult.FComposition.FNodes) = Length(AWorld.FComposition.FNodes),
        'A leaf replacement preserves composition size');
      for B := 0 to High(AWorld.FComposition.FNodes) do
      begin
        if B = LTarget then
        begin
          Continue;
        end;
        LOther := LIndex.Find(AWorld.FComposition.FNodes[B].FId);
        Check((LOther >= 0) and SameNode(AWorld.FComposition.FNodes[B],
          LResult.FComposition.FNodes[LOther]), 'Every unrelated node remains exact');
      end;
    finally
      LIndex.Free;
    end;
    LLocked := Clone(AWorld);
    LLocked.FComposition.FNodes[LTarget].FLocked := True;
    LEdit.FPrevious := LLocked;
    if GenerateWorld(LEdit, LResult, LReason) then
    begin
      { A request for the already selected asset can succeed without a change. }
      Check(Length(LResult.FComposition.FNodes) = Length(LLocked.FComposition.FNodes),
        'A locked no-op retains every node');
      for B := 0 to High(LLocked.FComposition.FNodes) do
      begin
        Check(SameNode(LLocked.FComposition.FNodes[B], LResult.FComposition.FNodes[B]),
          'A successful locked request preserves the complete composition');
      end;
    end else
    begin
      Check(True, 'A lock rejects an incompatible optional replacement');
    end;
  end;
end;

begin
  LPalette := LoadJSON('data/palette.json');
  try
    SetLength(LAssets, LPalette.Arrays['assets'].Count);
    for I := 0 to High(LAssets) do
    begin
      LAssets[I].FId := LPalette.Arrays['assets'].Objects[I].Strings['id'];
      LAssets[I].FKind := LPalette.Arrays['assets'].Objects[I].Strings['kind'];
      LAssets[I].FTheme := LPalette.Arrays['assets'].Objects[I].Strings['theme'];
      LAssets[I].FCluster := LPalette.Arrays['assets'].Objects[I].Get('cluster', 1);
    end;
  finally
    LPalette.Free;
  end;
  LBase := Default(TWorld);
  LBase.FSize := 4;
  LBase.FSeed := 731;
  LBase.FAppearanceSeed := 731;
  LBase.FComposition := InitialWorldComposition(731);
  for I := 0 to 4 do
  begin
    SetLength(LBase.FLayers[I], Sqr(LayerSize(4, I)));
    for J := 0 to High(LBase.FLayers[I]) do
    begin
      LBase.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        LBase.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
  for LHouse := 0 to 1 do
  begin
    LBase.FLayers[1][5] := 'modern';
    LBase.FLayers[3][5] := CHouses[LHouse];
    Check(ValidateWorld(LBase, LAssets, LReason), 'Actual imported house baseline admitted');
    for LSeed := 1 to 8 do
    begin
      LRequest := Default(TWorldRequest);
      LRequest.FPrevious := LBase;
      LRequest.FAssets := LAssets;
      LRequest.FSize := 4;
      LRequest.FX := 1;
      LRequest.FZ := 1;
      LRequest.FWidth := 1;
      LRequest.FDepth := 1;
      LRequest.FSeed := LSeed;
      LRequest.FContentCount := -1;
      LRequest.FGroundworkTurn := -1;
      LRequest.FOperation := 'create-interior';
      Check(GenerateWorld(LRequest, LWorld, LReason), 'House interior generated and admitted');
      Check(ValidateWorld(LWorld, LAssets, LReason), 'Complete house world independently valid');
      if (LHouse = 0) and (LSeed = 1) then
      begin
        CheckOptionalContents(LWorld, LRequest);
      end;
      Check(LWorld.FComposition.FNodes[1].FAssetId = CHouses[LHouse],
        'Building retains exact imported asset identity');
      for I := 0 to 4 do
      begin
        for J := 0 to High(LBase.FLayers[I]) do
        begin
          Check(LBase.FLayers[I][J] = LWorld.FLayers[I][J], 'All regional cells preserved');
        end;
      end;
      for I := 0 to High(LWorld.FComposition.FNodes) do
      begin
        LNode := LWorld.FComposition.FNodes[I];
        if LNode.FParentId <> 'building-1-1.studio' then
        begin
          Continue;
        end;
        Check(InteriorAsset(LNode.FAssetId, LAsset), 'Furniture has measured bounds');
        LX := LAsset.FWidth / 2;
        LZ := LAsset.FDepth / 2;
        if Odd(LNode.FQuarterTurn) then
        begin
          LX := LAsset.FDepth / 2;
          LZ := LAsset.FWidth / 2;
        end;
        Check((Abs(LNode.FX) + LX < 4300) and (Abs(LNode.FZ) + LZ < 3800) and
          (LAsset.FHeight < 2700), 'Unscaled furniture stays inside the 8.8 by 7.8 room walls');
      end;
      LBad := Clone(LWorld);
      LBad.FLayers[3][5] := CHouses[1 - LHouse];
      Check(not ValidateWorld(LBad, LAssets, LReason), 'Same-category shell substitution cannot retain an orphan room');
      LBad := Clone(LWorld);
      LBad.FComposition.FNodes[2].FAssetId := 'phanes.room.studio.v1';
      Check(not ValidateWorld(LBad, LAssets, LReason), 'Cabin profile cannot masquerade as a house room');
      LRequest.FPrevious := LWorld;
      LRequest.FOperation := 'asset';
      LRequest.FEditLayer := 'buildings';
      LRequest.FExactAsset := CHouses[1 - LHouse];
      Check(GenerateWorld(LRequest, LChanged, LReason), 'Explicit house replacement succeeds');
      Check(Length(LChanged.FComposition.FNodes) = 1, 'Replaced house removes only its owned room tree');
      LBad := Clone(LWorld);
      LBad.FComposition.FNodes[High(LBad.FComposition.FNodes)].FLocked := True;
      LRequest.FPrevious := LBad;
      Check(not GenerateWorld(LRequest, LChanged, LReason), 'Protected interior rejects shell replacement');
      LRequest.FPrevious := LWorld;
      LRequest.FX := 2;
      LRequest.FZ := 2;
      Check(GenerateWorld(LRequest, LChanged, LReason), 'A distant house can be placed');
      Check(Length(LChanged.FComposition.FNodes) = Length(LWorld.FComposition.FNodes),
        'Distant edit preserves the furnished house tree');
      for K := 0 to High(LWorld.FComposition.FNodes) do
      begin
        Check(SameNode(LWorld.FComposition.FNodes[K], LChanged.FComposition.FNodes[K]),
          'Distant edit keeps exact furniture and contents');
      end;
    end;
  end;
  LBase.FLayers[1][5] := 'empty';
  LBase.FLayers[3][5] := 'empty';
  LPlotId := GroundworkId(1, 1);
  for LTurn := 0 to 3 do
  begin
    LRequest := Default(TWorldRequest);
    LRequest.FPrevious := LBase;
    LRequest.FAssets := LAssets;
    LRequest.FSize := 4;
    LRequest.FX := 1;
    LRequest.FZ := 1;
    LRequest.FWidth := 2;
    LRequest.FDepth := 2;
    LRequest.FSeed := 503;
    LRequest.FOperation := 'foundation';
    LRequest.FGroundworkTurn := LTurn;
    Check(GenerateWorld(LRequest, LFoundation, LReason), 'Rotated foundation fixture admitted');
    for LHouse := 0 to 1 do
    begin
      LRequest.FPrevious := LFoundation;
      LRequest.FOperation := 'place-building';
      LRequest.FObjectId := LPlotId;
      LRequest.FBuildingAsset := CHouses[LHouse];
      Check(GenerateWorld(LRequest, LAttached, LReason), 'Imported house attaches to rotated foundation');
      LRequest.FPrevious := LAttached;
      LRequest.FOperation := 'create-interior';
      LRequest.FObjectId := LPlotId + '.deck.building';
      Check(GenerateWorld(LRequest, LWorld, LReason), 'Supported house gets its own admitted interior');
      Check(ValidateWorld(LWorld, LAssets, LReason), 'Rotated furnished house independently admitted');
      for I := 0 to High(LAttached.FComposition.FNodes) do
      begin
        Check(SameNode(LAttached.FComposition.FNodes[I], LWorld.FComposition.FNodes[I]),
          'Interior creation retains every rotated support and shell record');
      end;
      LRequest.FPrevious := Clone(LWorld);
      LRequest.FPrevious.FComposition.FNodes[High(LWorld.FComposition.FNodes)].FLocked := True;
      LRequest.FOperation := 'remove-building';
      Check(not GenerateWorld(LRequest, LChanged, LReason), 'Protected house contents prevent supported removal');
      LRequest.FPrevious := LWorld;
      Check(GenerateWorld(LRequest, LChanged, LReason), 'Unprotected furnished shell can be removed');
      Check(Length(LChanged.FComposition.FNodes) = Length(LFoundation.FComposition.FNodes),
        'Removing supported house retains the complete foundation');
      for I := 0 to High(LFoundation.FComposition.FNodes) do
      begin
        Check(SameNode(LFoundation.FComposition.FNodes[I], LChanged.FComposition.FNodes[I]),
          'Removing furnished shell preserves exact foundation parts');
      end;
    end;
  end;
  WriteLn('PASS ', LChecks, ' house profile, furniture, ownership and isolation checks');
end.
