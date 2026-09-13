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

unit phanes.spaces.programs;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.contents.types,
  phanes.spaces.floor.types;

const
  EmptyRoomProgram = 'phanes.space.empty.v1';
  BathroomProgram = 'phanes.space.bathroom.v1';
  LaboratoryProgram = 'phanes.space.laboratory.v1';
  SittingRoomProgram = 'phanes.space.sitting-room.v1';
  BedroomProgram = 'phanes.space.bedroom.v1';

function RoomProgramName(const AId: String): UnicodeString;
function RoomProgramRequest(const ARoom: TCompositionNode;
  out ARequest: TFloorRequest; out AReason: String): Boolean;
function RoomAssemblyAssets: TContentAssets;

implementation

uses
  Math,
  phanes.interiors.catalog,
  phanes.catalog.furniture,
  phanes.spaces.floor.validate;

function RoomProgramName(const AId: String): UnicodeString;
begin
  Result := '';
  if AId = EmptyRoomProgram then
  begin
    Result := 'Empty room';
  end
  else if AId = BathroomProgram then
  begin
    Result := 'Bathroom';
  end
  else if AId = LaboratoryProgram then
  begin
    Result := 'Laboratory';
  end
  else if AId = SittingRoomProgram then
  begin
    Result := 'Sitting room';
  end
  else if AId = BedroomProgram then
  begin
    Result := 'Bedroom';
  end;
end;

function RoomAssemblyAssets: TContentAssets;
const
  CIds: array[0..5] of String = (
    'phanes.table.lab.v1', 'phanes.shelf.oak.v1',
    'phanes.fixture.sink.v1', 'phanes.fixture.toilet.v1',
    'phanes.fixture.shower.v1', 'phanes.fixture.console.v1');
var
  LStart: Integer;
  LIds: TFurnitureIds;
  LProfile: TFurnitureProfile;
  I: Integer;
begin
  Result := InteriorContentAssets;
  LStart := Length(Result);
  SetLength(Result, LStart + Length(CIds));
  for I := 0 to High(CIds) do
  begin
    InteriorAssemblyAsset(CIds[I], Result[LStart + I]);
  end;
  LIds := FurnitureIds;
  LStart := Length(Result);
  SetLength(Result, LStart + Length(LIds));
  for I := 0 to High(LIds) do
  begin
    FurnitureProfile(LIds[I], LProfile);
    Result[LStart + I] := LProfile.FFloor.FContent;
  end;
end;

function RoomProgramRequest(const ARoom: TCompositionNode;
  out ARequest: TFloorRequest; out AReason: String): Boolean;
var
  LDimensions: array[0..2] of Double;
  LValue: Double;
  LIds: TFurnitureIds;
  LProfile: TFurnitureProfile;
  LRole: String;
  LIndex: Integer;
  LQuota: Integer;
  LNewProgram: Boolean;
  I: Integer;

  procedure AddFixture(const AId: String; const AFront: Integer;
    const AServices: TContentNames);
  var
    LIndex: Integer;
  begin
    LIndex := Length(ARequest.FAssets);
    SetLength(ARequest.FAssets, LIndex + 1);
    InteriorAssemblyAsset(AId, ARequest.FAssets[LIndex].FContent);
    ARequest.FAssets[LIndex].FAllowedTurns := 15;
    ARequest.FAssets[LIndex].FFrontQuarterTurn := AFront;
    ARequest.FAssets[LIndex].FNeedsApproach := True;
    ARequest.FAssets[LIndex].FRequiredServices := AServices;
    SetLength(ARequest.FQuotas, LIndex + 1);
    ARequest.FQuotas[LIndex].FRole := ARequest.FAssets[LIndex].FContent.FRole;
    ARequest.FQuotas[LIndex].FMinimum := 1;
    ARequest.FQuotas[LIndex].FMaximum := 1;
  end;

begin
  Result := False;
  ARequest := Default(TFloorRequest);
  AReason := 'Choose an admitted room program inside an explicit room volume.';
  if (ARoom.FKind <> ckContainer) or (ARoom.FRole <> 'room') or
    (ARoom.FSupportId <> '') or (RoomProgramName(ARoom.FAssetId) = '') then
  begin
    Exit;
  end;
  LDimensions[0] := ARoom.FWidth;
  LDimensions[1] := ARoom.FDepth;
  LDimensions[2] := ARoom.FHeight;
  for I := 0 to 2 do
  begin
    LValue := LDimensions[I];
    if IsNan(LValue) or IsInfinite(LValue) or (Frac(LValue) <> 0) then
    begin
      Exit;
    end;
  end;
  AReason := 'These room programs admit widths and depths from 2.5 to 9.4 m, and heights from 2.2 to 3.5 m.';
  if (ARoom.FWidth < 2500) or (ARoom.FWidth > 9400) or
    (ARoom.FDepth < 2500) or (ARoom.FDepth > 9400) or
    (ARoom.FHeight < 2200) or (ARoom.FHeight > 3500) then
  begin
    Exit;
  end;
  ARequest.FScopeId := ARoom.FId;
  ARequest.FSeed := ARoom.FSeed;
  ARequest.FWidth := ARoom.FWidth;
  ARequest.FDepth := ARoom.FDepth;
  ARequest.FHeight := ARoom.FHeight;
  { This deterministic pitch rule belongs to the immutable v1 program.
    Fine support graphs retain millimetre geometry independently of this floor.
    The largest laboratory has 81 cells and 29 tokens, below the work bound. }
  ARequest.FPitch := 750;
  if (ARoom.FWidth div 750) * (ARoom.FDepth div 750) > 56 then
  begin
    ARequest.FPitch := 1000;
  end;
  ARequest.FPlayerRadius := 280;
  ARequest.FDoorWidth := 1000;
  ARequest.FMaxBacktracks := 512;
  if ARoom.FAssetId = BathroomProgram then
  begin
    { Declared program eligibility; these are not simulated utility networks.
      The closed shower requires exterior approach, not walk-in admission. }
    ARequest.FServices := ['water', 'drain'];
    AddFixture('phanes.fixture.sink.v1', 0, ['water', 'drain']);
    AddFixture('phanes.fixture.toilet.v1', 0, ['water', 'drain']);
    AddFixture('phanes.fixture.shower.v1', 0, ['water', 'drain']);
  end
  else if ARoom.FAssetId = LaboratoryProgram then
  begin
    ARequest.FServices := ['power'];
    AddFixture('phanes.table.lab.v1', 0, []);
    AddFixture('phanes.fixture.console.v1', 2, ['power']);
    AddFixture('phanes.shelf.oak.v1', 0, []);
  end;
  LNewProgram := (ARoom.FAssetId = SittingRoomProgram) or
    (ARoom.FAssetId = BedroomProgram);
  if LNewProgram then
  begin
    LIds := FurnitureIds;
    for I := 0 to High(LIds) do
    begin
      FurnitureProfile(LIds[I], LProfile);
      LRole := LProfile.FFloor.FContent.FRole;
      if (LRole = 'chair') or (LRole = 'table') or
        ((ARoom.FAssetId = SittingRoomProgram) and (LRole = 'sofa')) or
        ((ARoom.FAssetId = BedroomProgram) and (LRole = 'bed')) then
      begin
        LIndex := Length(ARequest.FAssets);
        SetLength(ARequest.FAssets, LIndex + 1);
        ARequest.FAssets[LIndex] := LProfile.FFloor;
        { Quotas count independently useful furniture roles, not each visual
          variant. One bed does not become two when another model is admitted. }
        LQuota := 0;
        while (LQuota < Length(ARequest.FQuotas)) and
          (ARequest.FQuotas[LQuota].FRole <> LRole) do
        begin
          Inc(LQuota);
        end;
        if LQuota = Length(ARequest.FQuotas) then
        begin
          SetLength(ARequest.FQuotas, LQuota + 1);
          ARequest.FQuotas[LQuota].FRole := LRole;
          ARequest.FQuotas[LQuota].FMinimum := 1;
          ARequest.FQuotas[LQuota].FMaximum := 1;
        end;
      end;
    end;
    { These new v1 programs choose the finest admitted lattice from this fixed
      sequence. Larger complete footprints and variants retain the existing
      work allowance; neither meshes nor the player are scaled to fit. Old
      programs retain their original pitch rule and saved-pose interpretation. }
    ARequest.FPitch := 750;
    while ARequest.FPitch <= 1500 do
    begin
      if ValidateFloorRequest(ARequest, AReason) then
      begin
        Exit(True);
      end;
      Inc(ARequest.FPitch, 250);
    end;
    Exit(False);
  end;
  { The empty program still has a declared fixture so the generic
    floor adapter has a catalog domain; its exact zero quota admits only floor. }
  if ARoom.FAssetId = EmptyRoomProgram then
  begin
    AddFixture('phanes.shelf.oak.v1', 0, []);
    ARequest.FQuotas[0].FMinimum := 0;
    ARequest.FQuotas[0].FMaximum := 0;
  end;
  Result := ValidateFloorRequest(ARequest, AReason);
end;

end.
