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

unit phanes.tests.spaces.world.critic;
{$mode delphi}
{$H+}

interface

function RunSpaceWorldCriticChecks: Integer;

implementation

uses
  SysUtils,
  Math,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire,
  phanes.world.types,
  phanes.world.generate,
  phanes.world.validate,
  phanes.world.elevation,
  phanes.groundworks.geometry,
  phanes.groundworks.assembly,
  phanes.spaces.plans,
  phanes.spaces.programs
  {$ifdef PAS2JS}
  , JS, phanes.world.wire
  {$endif};
var
  GChecks: Integer;
  GAssets: TAssets;
  GReason: String;

procedure Check(const AOkay: Boolean; const ACase: String);
begin
  Inc(GChecks);
  if not AOkay then
  begin
    raise Exception.Create(ACase + ': ' + GReason);
  end;
end;

function CopyWorld(const AWorld: TWorld): TWorld;
var
  I: Integer;
begin
  Result := AWorld;
  Result.FComposition := CopyDocument(AWorld.FComposition);
  for I := 0 to 4 do
  begin
    Result.FLayers[I] := Copy(AWorld.FLayers[I], 0, Length(AWorld.FLayers[I]));
  end;
end;

function SameDocument(const ALeft, ARight: TCompositionDocument): Boolean;
var
  I: Integer;
begin
  Result := (ALeft.FRevision = ARight.FRevision) and
    (Length(ALeft.FNodes) = Length(ARight.FNodes));
  if not Result then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft.FNodes) do
  begin
    if not SameNode(ALeft.FNodes[I], ARight.FNodes[I]) then
    begin
      Exit(False);
    end;
  end;
end;

function SameRegional(const ALeft, ARight: TWorld): Boolean;
var
  I: Integer;
  J: Integer;
begin
  Result := (ALeft.FSize = ARight.FSize) and
    (ALeft.FAppearanceSeed = ARight.FAppearanceSeed) and
    (ALeft.FDecisions = ARight.FDecisions) and
    (ALeft.FPropagations = ARight.FPropagations) and
    (ALeft.FBacktracks = ARight.FBacktracks);
  if not Result then
  begin
    Exit;
  end;
  for I := 0 to 4 do
  begin
    if Length(ALeft.FLayers[I]) <> Length(ARight.FLayers[I]) then
    begin
      Exit(False);
    end;
    for J := 0 to High(ALeft.FLayers[I]) do
    begin
      if ALeft.FLayers[I][J] <> ARight.FLayers[I][J] then
      begin
        Exit(False);
      end;
    end;
  end;
end;

function EmptyWorld: TWorld;
var
  I: Integer;
  J: Integer;
begin
  Result := Default(TWorld);
  Result.FSize := 16;
  Result.FSeed := 101;
  Result.FAppearanceSeed := 999;
  Result.FComposition := InitialWorldComposition(101);
  for I := 0 to 4 do
  begin
    SetLength(Result.FLayers[I], Sqr(LayerSize(16, I)));
    for J := 0 to High(Result.FLayers[I]) do
    begin
      Result.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        Result.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
end;

function Request(const AWorld: TWorld; const AOperation, AId: String): TWorldRequest;
begin
  Result := Default(TWorldRequest);
  Result.FPrevious := AWorld;
  Result.FSize := AWorld.FSize;
  Result.FX := 7;
  Result.FZ := 3;
  Result.FWidth := 1;
  Result.FDepth := 1;
  Result.FSeed := AWorld.FSeed + 1;
  Result.FAssets := GAssets;
  Result.FOperation := AOperation;
  Result.FObjectId := AId;
  Result.FContentCount := -1;
  Result.FGroundworkTurn := -1;
end;

procedure OutsideChecks(const ABefore, AAfter: TWorld; const AScope: String);
var
  LBeforeIndex: TCompositionIndex;
  LAfterIndex: TCompositionIndex;
  LAt: Integer;
  I: Integer;
begin
  Check(SameRegional(ABefore, AAfter), 'room edit keeps all regional arrays/metrics exact');
  Check(AAfter.FComposition.FRevision = ABefore.FComposition.FRevision + 1,
    'room edit publishes one revision');
  LBeforeIndex := TCompositionIndex.Create(ABefore.FComposition.FNodes);
  LAfterIndex := TCompositionIndex.Create(AAfter.FComposition.FNodes);
  try
    for I := 0 to High(ABefore.FComposition.FNodes) do
    begin
      if not InCompositionScope(ABefore.FComposition, LBeforeIndex, I, AScope) then
      begin
        LAt := LAfterIndex.Find(ABefore.FComposition.FNodes[I].FId);
        Check(LAt >= 0, 'outside identity retained');
        Check(SameNode(ABefore.FComposition.FNodes[I], AAfter.FComposition.FNodes[LAt]),
          'outside record exact');
      end;
    end;
  finally
    LBeforeIndex.Free;
    LAfterIndex.Free;
  end;
end;

function FindRole(const AWorld: TWorld; const AScope, ARole: String): String;
var
  LIndex: TCompositionIndex;
  I: Integer;
begin
  Result := '';
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      if (AWorld.FComposition.FNodes[I].FRole = ARole) and
        InCompositionScope(AWorld.FComposition, LIndex, I, AScope) then
      begin
        Exit(AWorld.FComposition.FNodes[I].FId);
      end;
    end;
  finally
    LIndex.Free;
  end;
end;

procedure Run;
const
  CRegional = 'building-7-3';
  CSupported = 'site-3-3.deck.building';
var
  LWorld: TWorld;
  LBefore: TWorld;
  LChanged: TWorld;
  LBad: TWorld;
  LRestore: TWorld;
  LDocument: TCompositionDocument;
  LRequest: TWorldRequest;
  LIndex: TCompositionIndex;
  LRoom: String;
  LBench: String;
  LItem: String;
  LAt: Integer;
  {$ifdef PAS2JS}
  LWire: TJSObject;
  {$endif}
  I: Integer;
  J: Integer;
begin
  SetLength(GAssets, 1);
  GAssets[0].FId := 'cabin';
  GAssets[0].FKind := 'cabin';
  GAssets[0].FTheme := 'nature';
  LWorld := EmptyWorld;
  Check(DryBuildingDatum(16, 7, 3), 'regional cabin datum');
  LWorld.FLayers[1][3 * 16 + 7] := 'cabin';
  LWorld.FLayers[3][3 * 16 + 7] := 'cabin';
  Check(ValidateWorld(LWorld, GAssets, GReason), 'regional starting world');
  Check(CreateGroundwork(LWorld, 3, 3, 0, gpFoundation, gbPlinth, 111,
    LDocument, GReason), 'supported plot fixture');
  LWorld.FComposition := LDocument;
  LRequest := Request(LWorld, 'place-building', 'site-3-3');
  LRequest.FBuildingAsset := 'cabin';
  Check(GenerateWorld(LRequest, LChanged, GReason), 'supported cabin fixture');
  LWorld := LChanged;

  LBefore := CopyWorld(LWorld);
  LRequest := Request(LWorld, 'create-plan', '');
  LRequest.FPlanProfile := CabinSixBays;
  Check(GenerateWorld(LRequest, LChanged, GReason), 'regional plan creation');
  OutsideChecks(LWorld, LChanged, CRegional);
  Check(SameDocument(LWorld.FComposition, LBefore.FComposition), 'regional creation baseline');
  LWorld := LChanged;
  LRequest := Request(LWorld, 'create-plan', CSupported);
  LRequest.FPlanProfile := CabinSixBays;
  Check(GenerateWorld(LRequest, LChanged, GReason), 'supported plan creation');
  OutsideChecks(LWorld, LChanged, CSupported);
  LWorld := LChanged;
  for I := 0 to 1 do
  begin
    LRoom := CRegional + '.plan.bay-5.room';
    if I = 1 then
    begin
      LRoom := CSupported + '.plan.bay-5.room';
    end;
    LRequest := Request(LWorld, 'room-purpose', LRoom);
    LRequest.FRoomProgram := LaboratoryProgram;
    Check(GenerateWorld(LRequest, LChanged, GReason), 'lab program world transaction');
    OutsideChecks(LWorld, LChanged, LRoom);
    LWorld := LChanged;
  end;

  LRoom := CSupported + '.plan.bay-5.room';
  LBench := FindRole(LWorld, LRoom, 'bench') + '.top';
  LRequest := Request(LWorld, 'contents', LBench);
  LRequest.FContentRole := 'book';
  LRequest.FContentCount := 6;
  Check(GenerateWorld(LRequest, LChanged, GReason), 'six item bench capacity');
  OutsideChecks(LWorld, LChanged, LBench);
  LWorld := LChanged;
  LRequest.FPrevious := LWorld;
  LRequest.FContentCount := 7;
  LBefore := CopyWorld(LWorld);
  Check(not GenerateWorld(LRequest, LChanged, GReason), 'seven items reject six slots');
  Check(SameDocument(LWorld.FComposition, LBefore.FComposition), 'failed count preserves baseline');
  LItem := FindRole(LWorld, LRoom, 'ornament');
  LRequest := Request(LWorld, 'contents', LItem);
  Check(GenerateWorld(LRequest, LChanged, GReason), 'deep ornament reimagine');
  OutsideChecks(LWorld, LChanged, LItem);
  LWorld := LChanged;

  { Verify complete-plan revalidation under hostile child/profile/frame changes. }
  for I := 0 to High(LWorld.FComposition.FNodes) do
  begin
    LBad := CopyWorld(LWorld);
    if LBad.FComposition.FNodes[I].FWidth > 0 then
    begin
      Inc(LBad.FComposition.FNodes[I].FWidth);
    end
    else
    begin
      LBad.FComposition.FNodes[I].FWidth := 1;
      LBad.FComposition.FNodes[I].FDepth := 1;
      LBad.FComposition.FNodes[I].FHeight := 1;
    end;
    Check(not ValidateWorld(LBad, GAssets, GReason), 'every profile extent forgery rejects');
    LRequest := Request(LBad, 'restore', '');
    Check(not GenerateWorld(LRequest, LRestore, GReason), 'forged extent restore rejects');
  end;
  LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
  try
    for I := 0 to High(LWorld.FComposition.FNodes) do
    begin
      if not InCompositionScope(LWorld.FComposition, LIndex, I, LRoom) then
      begin
        Continue;
      end;
      LBad := CopyWorld(LWorld);
      LBad.FComposition.FNodes[I].FAssetId := 'unknown.profile';
      Check(not ValidateWorld(LBad, GAssets, GReason), 'unknown deep profile rejects');
    end;
    LAt := LIndex.Find(LItem);
    LBad := CopyWorld(LWorld);
    LBad.FComposition.FNodes[LAt].FLocked := True;
    LRequest := Request(LBad, 'room-purpose', LRoom);
    LRequest.FRoomProgram := BathroomProgram;
    Check(not GenerateWorld(LRequest, LChanged, GReason),
      'locked deep item prevents purpose replacement');
    LRequest := Request(LBad, 'create-plan', CSupported);
    LRequest.FPlanProfile := CabinTwoBays;
    Check(not GenerateWorld(LRequest, LChanged, GReason),
      'locked item prevents whole plan replacement');
    LRequest := Request(LBad, 'room-reimagine', LRoom);
    Check(GenerateWorld(LRequest, LChanged, GReason), 'locked item permits surrounding reimagine');
    OutsideChecks(LBad, LChanged, LRoom);
    LAt := LIndex.Find(CSupported + '.plan');
    for J := 0 to 3 do
    begin
      LBad := CopyWorld(LWorld);
      case J of
        0:
        begin
          LBad.FComposition.FNodes[LAt].FParentId := 'world';
        end;
        1:
        begin
          LBad.FComposition.FNodes[LAt].FRole := 'pretend-plan';
        end;
        2:
        begin
          LBad.FComposition.FNodes[LAt].FSupportId := 'site-3-3.deck';
        end;
        3:
        begin
          LBad.FComposition.FNodes[LAt].FId := 'fake.plan';
        end;
      end;
      Check(not ValidateWorld(LBad, GAssets, GReason), 'forged plan ownership/role rejects');
    end;
  finally
    LIndex.Free;
  end;

  LRequest := Request(LWorld, 'rename-space', LRoom);
  LRequest.FSpaceName := UnicodeString('Lab ') + WideChar($2605);
  Check(GenerateWorld(LRequest, LChanged, GReason), 'Unicode room rename');
  Check(LChanged.FSeed = LWorld.FSeed, 'rename preserves generation provenance');
  OutsideChecks(LWorld, LChanged, LRoom);
  LWorld := LChanged;
  for I := 0 to 3 do
  begin
    case I of
      0:
      begin
        LRequest.FSpaceName := '';
      end;
      1:
      begin
        LRequest.FSpaceName := '   ';
      end;
      2:
      begin
        LRequest.FSpaceName := UnicodeString(StringOfChar('x', 81));
      end;
      3:
      begin
        LRequest.FSpaceName := 'Line' + WideChar(10) + 'break';
      end;
    end;
    LRequest.FPrevious := LWorld;
    Check(not GenerateWorld(LRequest, LChanged, GReason), 'invalid room label rejects');
  end;
  LRequest.FPrevious := LWorld;
  for I := 0 to 3 do
  begin
    case I of
      0:
      begin
        LRequest.FSpaceName := UnicodeString(WideChar($D800));
      end;
      1:
      begin
        LRequest.FSpaceName := UnicodeString(WideChar($DFFF));
      end;
      2:
      begin
        LRequest.FSpaceName := UnicodeString(WideChar($D800)) + 'x' + WideChar($DC00);
      end;
      3:
      begin
        LRequest.FSpaceName := UnicodeString(WideChar($D800)) + WideChar($D800);
      end;
    end;
    Check(not GenerateWorld(LRequest, LChanged, GReason),
      'invalid Unicode is rejected before publication');
  end;
  LRequest.FSpaceName := UnicodeString(WideChar($D83D)) + WideChar($DC0C);
  Check(GenerateWorld(LRequest, LChanged, GReason), 'supplementary name pair stays legal');
  Check(Length(CompositionJSON(LChanged.FComposition)) > 0,
    'accepted supplementary name is serializable');
  {$ifdef PAS2JS}
  LWire := WorldJSON(LWorld);
  Check(Integer(TJSObject(LWire['composition'])['version']) = 2, 'world saves explicit inner v2');
  LRestore := ReadWorld(LWire);
  Check(ValidateWorld(LRestore, GAssets, GReason), 'saved named room world restores');
  Check(SameDocument(LWorld.FComposition, LRestore.FComposition),
    'world roundtrip preserves all nodes');
  Check(SameRegional(LWorld, LRestore), 'world roundtrip preserves regional arrays');
  {$endif}
end;

function RunSpaceWorldCriticChecks: Integer;
begin
  GChecks := 0;
  Run;
  Result := GChecks;
end;

end.
