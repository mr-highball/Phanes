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
program PhanesTestsCatalogFurniture;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, FPJSON, JSONParser,
  phanes.catalog.furniture, phanes.spaces.floor.types,
  phanes.composition.contents.types;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function LoadObject(const APath: String): TJSONObject;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := TJSONObject(GetJSON(LStream));
  finally
    LStream.Free;
  end;
end;

function FindModel(const ARoot: TJSONObject; const AId: String): TJSONObject;
var
  LModels: TJSONArray;
  I: Integer;
begin
  Result := nil;
  LModels := ARoot.Arrays['models'];
  for I := 0 to LModels.Count - 1 do
  begin
    if LModels.Objects[I].Strings['id'] = AId then
    begin
      Exit(LModels.Objects[I]);
    end;
  end;
end;

procedure CheckRotation(const AProfile: TFurnitureProfile);
var
  LPlacement: TFloorPlacement;
  LRequest: TFloorRequest;
  LBounds: TFloorRectangle;
  LWidth: Double;
  LDepth: Double;
  LApproachX: Integer;
  LApproachZ: Integer;
  LColumns: Integer;
  LRows: Integer;
  LExpectedX: Integer;
  LExpectedZ: Integer;
  LFront: Integer;
  LTurn: Integer;
begin
  LRequest := Default(TFloorRequest);
  LRequest.FWidth := 12000;
  LRequest.FDepth := 12000;
  LRequest.FPitch := 100;
  LPlacement := Default(TFloorPlacement);
  LPlacement.FCellX := 40;
  LPlacement.FCellZ := 40;
  for LTurn := 0 to 3 do
  begin
    LPlacement.FQuarterTurn := LTurn;
    FloorSpan(LRequest, AProfile.FFloor, LTurn, LColumns, LRows);
    LBounds := FloorBounds(LRequest, LPlacement, AProfile.FFloor);
    LWidth := LBounds.FMaxX - LBounds.FMinX;
    LDepth := LBounds.FMaxZ - LBounds.FMinZ;
    if Odd(LTurn) then
    begin
      Check(Abs(LWidth - AProfile.FFloor.FContent.FDepth) < 0.001,
        'odd turn swaps width');
      Check(Abs(LDepth - AProfile.FFloor.FContent.FWidth) < 0.001,
        'odd turn swaps depth');
    end
    else
    begin
      Check(Abs(LWidth - AProfile.FFloor.FContent.FWidth) < 0.001,
        'even turn preserves width');
      Check(Abs(LDepth - AProfile.FFloor.FContent.FDepth) < 0.001,
        'even turn preserves depth');
    end;
    FloorApproachCell(LRequest, LPlacement, AProfile.FFloor,
      LApproachX, LApproachZ);
    LExpectedX := LPlacement.FCellX + (LColumns - 1) div 2;
    LExpectedZ := LPlacement.FCellZ + (LRows - 1) div 2;
    LFront := (AProfile.FFloor.FFrontQuarterTurn + LTurn) mod 4;
    case LFront of
      0: LExpectedZ := LPlacement.FCellZ + LRows;
      1: LExpectedX := LPlacement.FCellX + LColumns;
      2: LExpectedZ := LPlacement.FCellZ - 1;
      3: LExpectedX := LPlacement.FCellX - 1;
    end;
    Check((LApproachX = LExpectedX) and (LApproachZ = LExpectedZ),
      'approach rotates with operating front');
  end;
end;

procedure CheckTabletop(const AProfile: TFurnitureProfile;
  const AModel: TJSONObject);
var
  LProposed: TJSONObject;
  LSamples: TJSONArray;
  LSupport: TContentSupport;
  LHalfWidth: Double;
  LHalfDepth: Double;
  LScale: Double;
  I: Integer;
begin
  Check(Length(AProfile.FFloor.FContent.FSupports) = 1,
    'table has one measured support');
  LSupport := AProfile.FFloor.FContent.FSupports[0];
  Check((LSupport.FKey = 'top') and (LSupport.FName = 'Tabletop') and
    (LSupport.FRole = 'tabletop') and
    (LSupport.FAssetId = 'phanes.support.table.v1'),
    'tabletop identity follows content support contract');
  Check((LSupport.FX = 0) and (LSupport.FZ = 0) and
    (LSupport.FQuarterTurn = 0) and (LSupport.FHeadroom = 600),
    'tabletop authored pose and headroom');
  Check((Length(LSupport.FAllowedRoles) = 4) and
    ContentRoleAllowed(LSupport.FAllowedRoles, 'book') and
    ContentRoleAllowed(LSupport.FAllowedRoles, 'ornament') and
    ContentRoleAllowed(LSupport.FAllowedRoles, 'plate') and
    ContentRoleAllowed(LSupport.FAllowedRoles, 'fork'),
    'tabletop supports established decor and dining roles');
  LProposed := AModel.Objects['proposedTabletop'];
  Check(LProposed.Booleans['accepted'] and
    (LProposed.Integers['passingSamples'] = LProposed.Integers['totalSamples']),
    'tabletop rectangle has complete ray evidence');
  LScale := AProfile.FUniformScale * 1000;
  LHalfWidth := LSupport.FWidth / 2;
  LHalfDepth := LSupport.FDepth / 2;
  Check((-LHalfWidth >= LProposed.Arrays['minimum'].Floats[0] * LScale) and
    (LHalfWidth <= LProposed.Arrays['maximum'].Floats[0] * LScale) and
    (-LHalfDepth >= LProposed.Arrays['minimum'].Floats[1] * LScale) and
    (LHalfDepth <= LProposed.Arrays['maximum'].Floats[1] * LScale),
    'integer support corners stay inside measured usable rectangle');
  Check(Abs(LSupport.FY - LProposed.Floats['height'] * LScale) < 0.001,
    'support height follows measured top plane');
  LSamples := LProposed.Arrays['verticalRaySamples'];
  for I := 0 to LSamples.Count - 1 do
  begin
    if (Abs(Abs(LSamples.Objects[I].Floats['x']) -
      LProposed.Arrays['maximum'].Floats[0]) < 0.00001) and
      (Abs(Abs(LSamples.Objects[I].Floats['z']) -
      LProposed.Arrays['maximum'].Floats[1]) < 0.00001) then
    begin
      Check(LSamples.Objects[I].Booleans['pass'],
        'measured usable corner has an actual top ray hit');
    end;
  end;
end;

procedure CheckCatalog(const AEvidencePath: String);
const
  CManifest = '035cf9f058624c947f754d9049d8be075655c58086799c9335b029cc4bc680cb';
  CIds: array[0..7] of String = (
    'phanes.catalog.furniture.kaykit-armchair.v1',
    'phanes.catalog.furniture.kaykit-couch.v1',
    'phanes.catalog.furniture.kaykit-bed-single.v1',
    'phanes.catalog.furniture.kaykit-bed-double.v1',
    'phanes.catalog.furniture.kaykit-chair.v1',
    'phanes.catalog.furniture.kaykit-stool.v1',
    'phanes.catalog.furniture.kaykit-table.v1',
    'phanes.catalog.furniture.kaykit-coffee-table.v1');
  CRoles: array[0..7] of String = (
    'sofa', 'sofa', 'bed', 'bed', 'chair', 'chair', 'table', 'table');
  CSubcategories: array[0..7] of String = (
    'Seating', 'Seating', 'Beds', 'Beds', 'Seating', 'Seating',
    'Tables', 'Tables');
var
  LEvidence: TJSONObject;
  LFresh: TFurnitureProfile;
  LIds: TFurnitureIds;
  LModel: TJSONObject;
  LProfile: TFurnitureProfile;
  LWidth: Double;
  LDepth: Double;
  LHeight: Double;
  I: Integer;
  J: Integer;
begin
  LEvidence := LoadObject(AEvidencePath);
  try
    Check(LEvidence.Integers['failures'] = 0, 'geometry evidence passed');
    LIds := FurnitureIds;
    Check(Length(LIds) = 8, 'exact furniture catalog size');
    for I := 0 to High(LIds) do
    begin
      Check(LIds[I] = CIds[I], 'stable ordered furniture ID');
      for J := I + 1 to High(LIds) do
      begin
        Check(LIds[I] <> LIds[J], 'furniture IDs unique');
      end;
      Check(FurnitureProfile(LIds[I], LProfile), LIds[I] + ' resolves');
      Check(LProfile.FFloor.FContent.FId = LIds[I], 'stable content ID');
      Check((LProfile.FKitId = 'kaykit-furniture-bits-1-0') and
        (LProfile.FManifestSha256 = CManifest), 'exact source closure pin');
      Check((LProfile.FCategory = 'Furniture') and
        (LProfile.FSubcategory = CSubcategories[I]) and
        (LProfile.FFloor.FContent.FRole = CRoles[I]),
        'exact furniture grouping and placement role');
      Check(LProfile.FFloor.FContent.FSingleInstance and
        (LProfile.FFloor.FAllowedTurns = 15) and
        LProfile.FFloor.FNeedsApproach and
        (Length(LProfile.FFloor.FRequiredServices) = 0),
        'portable floor placement policy');
      LModel := FindModel(LEvidence, LProfile.FModelId);
      Check(LModel <> nil, 'profile model occurs in retained evidence');
      Check((LProfile.FSourceSha256 = LModel.Strings['sourceSha256']) and
        (LProfile.FTriangles = LModel.Integers['triangles']) and
        (LProfile.FVertices = LModel.Integers['positionVertices']) and
        (LProfile.FTexturePixels = LModel.Integers['texturePixels']),
        'source identity and decoded costs match evidence');
      LWidth := (LModel.Arrays['boundsMaximum'].Floats[0] -
        LModel.Arrays['boundsMinimum'].Floats[0]) *
        LProfile.FUniformScale * 1000;
      LHeight := (LModel.Arrays['boundsMaximum'].Floats[1] -
        LModel.Arrays['boundsMinimum'].Floats[1]) *
        LProfile.FUniformScale * 1000;
      LDepth := (LModel.Arrays['boundsMaximum'].Floats[2] -
        LModel.Arrays['boundsMinimum'].Floats[2]) *
        LProfile.FUniformScale * 1000;
      Check((LProfile.FFloor.FContent.FWidth >= LWidth) and
        (LProfile.FFloor.FContent.FWidth < LWidth + 1.001) and
        (LProfile.FFloor.FContent.FDepth >= LDepth) and
        (LProfile.FFloor.FContent.FDepth < LDepth + 1.001) and
        (LProfile.FFloor.FContent.FHeight >= LHeight) and
        (LProfile.FFloor.FContent.FHeight < LHeight + 1.001),
        'integer envelope is the ceiling of scaled measured bounds');
      if LProfile.FFloor.FContent.FRole = 'bed' then
      begin
        Check((LProfile.FFloor.FContent.FDepth >= 2100) and
          (LProfile.FFloor.FFrontQuarterTurn = 1),
          'bed keeps realistic length and side approach');
      end
      else
      begin
        Check(LProfile.FFloor.FFrontQuarterTurn = 0,
          'seat or table approaches from source +Z');
      end;
      if LProfile.FFloor.FContent.FRole = 'table' then
      begin
        CheckTabletop(LProfile, LModel);
      end
      else
      begin
        Check(Length(LProfile.FFloor.FContent.FSupports) = 0,
          'seat or bed claims no object support');
      end;
      CheckRotation(LProfile);
    end;
    LProfile.FKitId := 'stale';
    LProfile.FFloor.FContent.FId := 'stale';
    SetLength(LProfile.FFloor.FContent.FSupports, 1);
    Check(not FurnitureProfile('unknown', LProfile), 'unknown ID rejected');
    Check((LProfile.FKitId = '') and
      (LProfile.FFloor.FContent.FId = '') and
      (Length(LProfile.FFloor.FContent.FSupports) = 0),
      'unknown lookup clears complete output');
    LIds[0] := 'mutated';
    Check(FurnitureIds[0] = 'phanes.catalog.furniture.kaykit-armchair.v1',
      'returned ID arrays do not alias');
    Check(FurnitureProfile('phanes.catalog.furniture.kaykit-table.v1',
      LProfile), 'table resolves for independence check');
    LProfile.FFloor.FContent.FSupports[0].FAllowedRoles[0] := 'mutated';
    Check(FurnitureProfile('phanes.catalog.furniture.kaykit-table.v1',
      LFresh) and
      (LFresh.FFloor.FContent.FSupports[0].FAllowedRoles[0] = 'book'),
      'returned nested arrays do not alias');
  finally
    LEvidence.Free;
  end;
end;

begin
  try
    Check(ParamCount = 2,
      'Usage: phanes.tests.catalog.furniture REPOSITORY EVIDENCE_JSON');
    Check(DirectoryExists(ParamStr(1)), 'repository input exists');
    CheckCatalog(ParamStr(2));
    WriteLn('PASS ', GChecks, ' furniture profile checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
