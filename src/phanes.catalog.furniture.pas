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
unit phanes.catalog.furniture;

{$mode delphi}
{$H+}

interface

uses
  phanes.spaces.floor.types;

type
  TFurnitureProfile = record
    FKitId: String;
    FModelId: String;
    FSourceSha256: String;
    FManifestSha256: String;
    FCategory: String;
    FSubcategory: String;
    FUniformScale: Double;
    FTriangles: Integer;
    FVertices: Integer;
    FTexturePixels: Integer;
    FFloor: TFloorAsset;
  end;
  TFurnitureIds = array of String;

function FurnitureProfile(const AId: String;
  out AProfile: TFurnitureProfile): Boolean;
function FurnitureIds: TFurnitureIds;

implementation

const
  FurnitureKitId = 'kaykit-furniture-bits-1-0';
  FurnitureManifestSha256 =
    '035cf9f058624c947f754d9049d8be075655c58086799c9335b029cc4bc680cb';

function FurnitureIds: TFurnitureIds;
begin
  Result := nil;
  SetLength(Result, 8);
  Result[0] := 'phanes.catalog.furniture.kaykit-armchair.v1';
  Result[1] := 'phanes.catalog.furniture.kaykit-couch.v1';
  Result[2] := 'phanes.catalog.furniture.kaykit-bed-single.v1';
  Result[3] := 'phanes.catalog.furniture.kaykit-bed-double.v1';
  Result[4] := 'phanes.catalog.furniture.kaykit-chair.v1';
  Result[5] := 'phanes.catalog.furniture.kaykit-stool.v1';
  Result[6] := 'phanes.catalog.furniture.kaykit-table.v1';
  Result[7] := 'phanes.catalog.furniture.kaykit-coffee-table.v1';
end;

procedure SetTabletop(var AProfile: TFurnitureProfile; const AHeight,
  AWidth, ADepth: Integer);
begin
  SetLength(AProfile.FFloor.FContent.FSupports, 1);
  with AProfile.FFloor.FContent.FSupports[0] do
  begin
    FKey := 'top';
    FName := 'Tabletop';
    FRole := 'tabletop';
    FAssetId := 'phanes.support.table.v1';
    FX := 0;
    FY := AHeight;
    FZ := 0;
    FQuarterTurn := 0;
    FWidth := AWidth;
    FDepth := ADepth;
    FHeadroom := 600;
    SetLength(FAllowedRoles, 4);
    FAllowedRoles[0] := 'book';
    FAllowedRoles[1] := 'ornament';
    FAllowedRoles[2] := 'plate';
    FAllowedRoles[3] := 'fork';
  end;
end;

procedure SetCommon(var AProfile: TFurnitureProfile; const AId, AName,
  ARole, ASubcategory, AModelId, ASourceSha256: String;
  const AScale: Double; const ATriangles, AVertices, AWidth, ADepth,
  AHeight, AFrontQuarterTurn: Integer);
begin
  AProfile := Default(TFurnitureProfile);
  AProfile.FKitId := FurnitureKitId;
  AProfile.FModelId := AModelId;
  AProfile.FSourceSha256 := ASourceSha256;
  AProfile.FManifestSha256 := FurnitureManifestSha256;
  AProfile.FCategory := 'Furniture';
  AProfile.FSubcategory := ASubcategory;
  AProfile.FUniformScale := AScale;
  AProfile.FTriangles := ATriangles;
  AProfile.FVertices := AVertices;
  AProfile.FTexturePixels := 1048576;
  AProfile.FFloor.FContent.FId := AId;
  AProfile.FFloor.FContent.FName := UnicodeString(AName);
  AProfile.FFloor.FContent.FRole := ARole;
  AProfile.FFloor.FContent.FWidth := AWidth;
  AProfile.FFloor.FContent.FDepth := ADepth;
  AProfile.FFloor.FContent.FHeight := AHeight;
  AProfile.FFloor.FContent.FSingleInstance := True;
  AProfile.FFloor.FAllowedTurns := 15;
  { Seats, stools and tables are authored for approach from source +Z. Beds
    instead use source +X as an operating side, leaving the -Z headboard clear.
    These are placement policies; they do not assert sitting or sleeping logic. }
  AProfile.FFloor.FFrontQuarterTurn := AFrontQuarterTurn;
  AProfile.FFloor.FNeedsApproach := True;
end;

function FurnitureProfile(const AId: String;
  out AProfile: TFurnitureProfile): Boolean;
begin
  AProfile := Default(TFurnitureProfile);
  Result := True;
  if AId = 'phanes.catalog.furniture.kaykit-armchair.v1' then
  begin
    SetCommon(AProfile, AId, 'Armchair', 'sofa', 'Seating',
      'kaykit-furniture-bits-1-0/gltf/armchair',
      '5236bd9c4945fb60d5ac4d4b064c0c0c74bcded1c280b474d3899a1d84d68b25',
      0.9, 528, 442, 1621, 1441, 1102, 0);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-couch.v1' then
  begin
    SetCommon(AProfile, AId, 'Couch', 'sofa', 'Seating',
      'kaykit-furniture-bits-1-0/gltf/couch',
      '1a5b74b3a3368870783743c5ce7baa61f45f71131dca66af80b35fd4ac63c222',
      0.9, 636, 550, 2701, 1441, 1102, 0);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-bed-single.v1' then
  begin
    SetCommon(AProfile, AId, 'Single bed', 'bed', 'Beds',
      'kaykit-furniture-bits-1-0/gltf/bed_single_A',
      '7b2852bb66bf82cad3e0d03a499b1480879790fa66b645347e3e73761c4fe3f5',
      0.7, 474, 600, 1121, 2100, 700, 1);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-bed-double.v1' then
  begin
    SetCommon(AProfile, AId, 'Double bed', 'bed', 'Beds',
      'kaykit-furniture-bits-1-0/gltf/bed_double_A',
      '55451127bbeb9734bb88c1a761a6246eaaf89ac33eee2f703d78053719e5c4e5',
      0.7, 540, 669, 2170, 2100, 700, 1);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-chair.v1' then
  begin
    SetCommon(AProfile, AId, 'Chair', 'chair', 'Seating',
      'kaykit-furniture-bits-1-0/gltf/chair_A',
      'fdc71044f23c89c5cff9093cff18bac295c9b750e73daf3cbd8ee6ca9e930dbb',
      0.9, 308, 458, 675, 761, 1133, 0);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-stool.v1' then
  begin
    SetCommon(AProfile, AId, 'Stool', 'chair', 'Seating',
      'kaykit-furniture-bits-1-0/gltf/chair_stool',
      '6f830305b9afb97f8d77d52a92971ee237d3012db2ca1abbd4abafc2d82f4c46',
      0.9, 216, 298, 675, 675, 450, 0);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-table.v1' then
  begin
    SetCommon(AProfile, AId, 'Table', 'table', 'Tables',
      'kaykit-furniture-bits-1-0/gltf/table_medium',
      'fd5e5fe8bbf1d3729b6bd725165d58490e9cbd8dd46ce42314b01f20951a302b',
      0.75, 168, 260, 1500, 1500, 750, 0);
    SetTabletop(AProfile, 750, 1323, 1323);
  end
  else if AId = 'phanes.catalog.furniture.kaykit-coffee-table.v1' then
  begin
    SetCommon(AProfile, AId, 'Coffee table', 'table', 'Tables',
      'kaykit-furniture-bits-1-0/gltf/table_low',
      '3bf202a3ee70ee95943c26419bd5f540353a16b8b6a0b41449746f85c3319a2a',
      0.8, 276, 336, 1921, 1200, 400, 0);
    SetTabletop(AProfile, 400, 1699, 1051);
  end
  else
  begin
    AProfile := Default(TFurnitureProfile);
    Result := False;
  end;
end;

end.
