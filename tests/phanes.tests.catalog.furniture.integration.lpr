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
program PhanesTestsCatalogFurnitureIntegration;

{$mode delphi}
{$H+}

uses
  SysUtils,
  phanes.catalog.admission,
  phanes.catalog.furniture,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire,
  phanes.composition.contents.types,
  phanes.composition.contents.assembly,
  phanes.composition.contents.generate,
  phanes.interiors.catalog,
  phanes.interiors.surfaces,
  phanes.spaces.floor.types,
  phanes.spaces.programs,
  phanes.spaces.rooms;

var
  GChecks: Integer;
  GReason: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage + ': ' + GReason);
  end;
end;

function RoomFixture(const AWidth, ADepth: Integer): TCompositionDocument;
begin
  Result := Default(TCompositionDocument);
  Result.FRevision := 7;
  SetLength(Result.FNodes, 3);
  Result.FNodes[0].FId := 'world';
  Result.FNodes[0].FName := 'World';
  Result.FNodes[0].FRole := 'world';
  Result.FNodes[0].FKind := ckContainer;
  Result.FNodes[1].FId := 'room';
  Result.FNodes[1].FParentId := 'world';
  Result.FNodes[1].FName := 'Empty room';
  Result.FNodes[1].FRole := 'room';
  Result.FNodes[1].FAssetId := EmptyRoomProgram;
  Result.FNodes[1].FKind := ckContainer;
  Result.FNodes[1].FWidth := AWidth;
  Result.FNodes[1].FDepth := ADepth;
  Result.FNodes[1].FHeight := 2700;
  Result.FNodes[2].FId := 'outside-marker';
  Result.FNodes[2].FParentId := 'world';
  Result.FNodes[2].FName := 'Preserved sibling';
  Result.FNodes[2].FRole := 'marker';
  Result.FNodes[2].FKind := ckObject;
  Result.FNodes[2].FAssetId := 'phanes.plant.fern.v1';
end;

function FindDirectRole(const ADocument: TCompositionDocument;
  const ARole: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(ADocument.FNodes) do
  begin
    if (ADocument.FNodes[I].FParentId = 'room') and
      (ADocument.FNodes[I].FRole = ARole) then
    begin
      Exit(I);
    end;
  end;
end;

function RoleCount(const ADocument: TCompositionDocument;
  const ARole: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(ADocument.FNodes) do
  begin
    if (ADocument.FNodes[I].FParentId = 'room') and
      (ADocument.FNodes[I].FRole = ARole) then
    begin
      Inc(Result);
    end;
  end;
end;

procedure CheckCatalogLayers;
var
  LAdmission: TOptionalAssetAdmission;
  LContent: TContentAssets;
  LFurnitureIds: TFurnitureIds;
  LIds: TOptionalAssetIds;
  LRoomAssets: TContentAssets;
  I: Integer;
begin
  LIds := OptionalAssetIds;
  LFurnitureIds := FurnitureIds;
  Check(Length(LIds) = 40, 'optional catalog adds exactly eight furniture IDs');
  Check((LIds[0] = 'phanes.catalog.book.kaykit-single.v1') and
    (LIds[1] = 'phanes.catalog.vase.quaternius.v1') and
    (LIds[2] = 'phanes.catalog.book.rpg-closed.v1') and
    (LIds[31] = 'phanes.catalog.rock.forest-stones.v1'),
    'prior 32 optional IDs retain their boundary order');
  for I := 0 to High(LFurnitureIds) do
  begin
    Check(LIds[32 + I] = LFurnitureIds[I], 'furniture appended in profile order');
    Check(OptionalAssetAdmission(LIds[32 + I], LAdmission) and
      (LAdmission.FDomain = oadFurnishing),
      'furniture has a distinct optional admission domain');
  end;
  LContent := InteriorContentAssets;
  LRoomAssets := RoomAssemblyAssets;
  Check(ValidateContentAssets(LContent, GReason),
    'generic validator accepts interior content catalog');
  Check(ValidateContentAssets(LRoomAssets, GReason),
    'generic validator accepts room assembly catalog');
  for I := 0 to High(LFurnitureIds) do
  begin
    Check(ContentAssetIndex(LContent, LFurnitureIds[I]) < 0,
      'furniture excluded from tabletop object choices');
    Check(ContentAssetIndex(LRoomAssets, LFurnitureIds[I]) >= 0,
      'furniture included in room assembly choices');
  end;
end;

procedure CheckProgramRequest(const AProgram: String;
  const AWidth, ADepth: Integer);
var
  LRequest: TFloorRequest;
  LRoom: TCompositionNode;
  LRequiredRole: String;
  I: Integer;
begin
  LRoom := RoomFixture(AWidth, ADepth).FNodes[1];
  LRoom.FAssetId := AProgram;
  Check(RoomProgramRequest(LRoom, LRequest, GReason),
    'new program admits requested room dimensions');
  Check((LRequest.FPitch >= 750) and (LRequest.FPitch <= 1500) and
    (LRequest.FMaxBacktracks = 512), 'new program keeps bounded floor work');
  if AProgram = SittingRoomProgram then
  begin
    LRequiredRole := 'sofa';
  end
  else
  begin
    LRequiredRole := 'bed';
  end;
  Check(Length(LRequest.FQuotas) = 3, 'new program has three role quotas');
  for I := 0 to High(LRequest.FQuotas) do
  begin
    Check((LRequest.FQuotas[I].FMinimum = 1) and
      (LRequest.FQuotas[I].FMaximum = 1),
      'each furniture role has exact-one quota');
  end;
  Check((LRequest.FQuotas[0].FRole = LRequiredRole) and
    (LRequest.FQuotas[1].FRole = 'chair') and
    (LRequest.FQuotas[2].FRole = 'table'),
    'program quota roles are purpose, chair and table');
end;

procedure CheckPlacement(const ADocument: TCompositionDocument;
  const AProgram: String);
var
  LLayout: TFloorLayout;
  LRequest: TFloorRequest;
  LX: Integer;
  LZ: Integer;
  LAsset: Integer;
  LColumns: Integer;
  LRows: Integer;
  I: Integer;
begin
  Check(ReadProgramRoom(ADocument, 'room', LRequest, LLayout, GReason),
    'generated room decodes to a floor layout');
  Check(Length(LLayout.FPlacements) = 3, 'generated room has exactly three fixtures');
  for I := 0 to High(LLayout.FPlacements) do
  begin
    LAsset := FloorAssetIndex(LRequest.FAssets,
      LLayout.FPlacements[I].FAssetId);
    Check(LAsset >= 0, 'placed furniture remains admitted');
    FloorApproachCell(LRequest, LLayout.FPlacements[I],
      LRequest.FAssets[LAsset], LX, LZ);
    LColumns := LRequest.FWidth div LRequest.FPitch;
    LRows := LRequest.FDepth div LRequest.FPitch;
    Check((LX >= 0) and (LX < LColumns) and (LZ >= 0) and (LZ < LRows),
      'operating approach remains inside room lattice');
    Check(LLayout.FFreeCells[LZ * LColumns + LX],
      'operating approach remains clear of every footprint');
  end;
  if AProgram = SittingRoomProgram then
  begin
    Check((RoleCount(ADocument, 'sofa') = 1) and
      (RoleCount(ADocument, 'bed') = 0), 'sitting room realizes exact sofa role');
  end
  else
  begin
    Check((RoleCount(ADocument, 'bed') = 1) and
      (RoleCount(ADocument, 'sofa') = 0), 'bedroom realizes exact bed role');
  end;
  Check((RoleCount(ADocument, 'chair') = 1) and
    (RoleCount(ADocument, 'table') = 1),
    'generated program realizes exact chair and table roles');
end;

procedure CheckMeasuredSurface(var ADocument: TCompositionDocument);
var
  LChanged: TCompositionDocument;
  LIndex: TCompositionIndex;
  LProfile: TFurnitureProfile;
  LRequest: TContentRequest;
  LSurface: String;
  LTable: Integer;
  LWell: Integer;
  I: Integer;
begin
  LTable := FindDirectRole(ADocument, 'table');
  Check(LTable >= 0, 'generated program has table for surface test');
  Check(FurnitureProfile(ADocument.FNodes[LTable].FAssetId, LProfile),
    'generated table retains furniture profile identity');
  LSurface := ADocument.FNodes[LTable].FId + '.top';
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    Check(LIndex.Find(LSurface) >= 0,
      'generated measured table retains complete support child');
  finally
    LIndex.Free;
  end;
  Check(SurfaceRequest(ADocument, LSurface, LRequest, GReason),
    'measured furniture surface builds a content request');
  Check((LRequest.FSurfaceWidth =
    LProfile.FFloor.FContent.FSupports[0].FWidth) and
    (LRequest.FSurfaceDepth =
    LProfile.FFloor.FContent.FSupports[0].FDepth),
    'surface request uses exact furniture support dimensions');
  Check((LRequest.FSurfaceWidth <> 1500) or
    (LRequest.FSurfaceDepth <> 800),
    'measured furniture does not fall through to legacy table dimensions');
  Check(Length(LRequest.FSlots) = 4, 'measured tabletop exposes four slots');
  for I := 0 to High(LRequest.FSlots) do
  begin
    Check((2 * Abs(LRequest.FSlots[I].FX) + LRequest.FSlots[I].FWidth <=
      LRequest.FSurfaceWidth) and
      (2 * Abs(LRequest.FSlots[I].FZ) + LRequest.FSlots[I].FDepth <=
      LRequest.FSurfaceDepth), 'table slot stays inside measured rectangle');
  end;
  for I := 0 to High(LRequest.FQuotas) do
  begin
    LRequest.FQuotas[I].FMinimum := 0;
    LRequest.FQuotas[I].FMaximum := 0;
    if LRequest.FQuotas[I].FRole = 'plate' then
    begin
      LRequest.FQuotas[I].FMinimum := 1;
      LRequest.FQuotas[I].FMaximum := 1;
    end;
  end;
  Check(GenerateContents(ADocument, LRequest, LChanged, GReason),
    'measured tabletop accepts one plate');
  Check(ValidateProgramRoom(LChanged, 'room', GReason),
    'room validator accepts nested content on measured support');
  LWell := -1;
  for I := 0 to High(LChanged.FNodes) do
  begin
    if (LChanged.FNodes[I].FRole = 'plate-well') and
      (LChanged.FNodes[I].FKind = ckSurface) then
    begin
      LWell := I;
    end;
  end;
  Check(LWell >= 0, 'nested plate retains its own support child');
  ADocument := LChanged;
end;

procedure CheckLegacyProgram;
var
  LDocument: TCompositionDocument;
  LRequest: TContentRequest;
  LSurface: String;
  LTable: Integer;
begin
  LDocument := RoomFixture(4300, 8700);
  Check(GenerateProgramRoom(LDocument, 'room', LaboratoryProgram, 0, 7,
    True, LDocument, GReason), 'legacy laboratory still generates');
  LTable := FindDirectRole(LDocument, 'bench');
  Check(LTable >= 0, 'legacy laboratory keeps workbench');
  LSurface := LDocument.FNodes[LTable].FId + '.top';
  Check(SurfaceRequest(LDocument, LSurface, LRequest, GReason),
    'legacy work surface still resolves');
  Check((LRequest.FSurfaceWidth = 1500) and
    (LRequest.FSurfaceDepth = 800),
    'legacy work surface dimensions remain unchanged');
end;

procedure CheckGeneration(const AProgram: String);
var
  LBaseline: TCompositionDocument;
  LChanged: TCompositionDocument;
  LIndex: TCompositionIndex;
  LMarker: TCompositionNode;
  LSeed: Cardinal;
begin
  for LSeed := 0 to 3 do
  begin
    LBaseline := RoomFixture(4300, 8700);
    LMarker := LBaseline.FNodes[2];
    Check(GenerateProgramRoom(LBaseline, 'room', AProgram, LSeed, 7,
      True, LChanged, GReason), 'two-bay-size room generates seed ' +
      IntToStr(LSeed));
    Check(ValidateProgramRoom(LChanged, 'room', GReason),
      'generated room passes independent room validation');
    LIndex := TCompositionIndex.Create(LChanged.FNodes);
    try
      Check(SameNode(LMarker,
        LChanged.FNodes[LIndex.Find(LMarker.FId)]),
        'generation preserves out-of-scope sibling exactly');
    finally
      LIndex.Free;
    end;
    CheckPlacement(LChanged, AProgram);
    if LSeed = 0 then
    begin
      CheckMeasuredSurface(LChanged);
    end;
  end;
  CheckProgramRequest(AProgram, 4300, 3800);
  CheckProgramRequest(AProgram, 9400, 9400);
end;

procedure CheckSmallRoomFailure;
var
  LBaseline: TCompositionDocument;
  LCommitted: TCompositionDocument;
  LBefore: String;
begin
  LBaseline := RoomFixture(2500, 2500);
  LCommitted := CopyDocument(LBaseline);
  LBefore := CompositionJSON(LCommitted);
  Check(not GenerateProgramRoom(LBaseline, 'room', BedroomProgram, 0, 7,
    True, LCommitted, GReason), 'small room rejects complete bedroom program');
  Check(CompositionJSON(LCommitted) = LBefore,
    'failed small-room generation preserves caller baseline');
end;

begin
  try
    CheckCatalogLayers;
    CheckProgramRequest(SittingRoomProgram, 4300, 8700);
    CheckProgramRequest(BedroomProgram, 4300, 8700);
    CheckGeneration(SittingRoomProgram);
    CheckGeneration(BedroomProgram);
    CheckSmallRoomFailure;
    CheckLegacyProgram;
    WriteLn('PASS ', GChecks, ' furniture integration checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
