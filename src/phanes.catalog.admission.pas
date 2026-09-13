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
unit phanes.catalog.admission;

{$mode delphi}
{$H+}

interface

type
  TOptionalAssetDomain = (oadInterior, oadRegional, oadFurnishing);

  TOptionalAssetAdmission = record
    FDomain: TOptionalAssetDomain;
    FId: String;
    FKitId: String;
    FModelId: String;
    FSourceSha256: String;
    FManifestSha256: String;
    FCategory: String;
    FSubcategory: String;
    FRole: String;
    FName: UnicodeString;
    FUniformScale: Double;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FTriangles: Integer;
    FVertices: Integer;
    FTexturePixels: Integer;
  end;

  TOptionalAssetIds = array of String;

function OptionalAssetAdmission(const AId: String;
  out AAdmission: TOptionalAssetAdmission): Boolean;
function OptionalAssetIds: TOptionalAssetIds;

implementation

uses
  phanes.catalog.objects, phanes.catalog.regional, phanes.catalog.furniture;

const
  BookId = 'phanes.catalog.book.kaykit-single.v1';
  VaseId = 'phanes.catalog.vase.quaternius.v1';

procedure ClearAdmission(out AAdmission: TOptionalAssetAdmission);
begin
  AAdmission.FDomain := oadInterior;
  AAdmission.FId := '';
  AAdmission.FKitId := '';
  AAdmission.FModelId := '';
  AAdmission.FSourceSha256 := '';
  AAdmission.FManifestSha256 := '';
  AAdmission.FCategory := '';
  AAdmission.FSubcategory := '';
  AAdmission.FRole := '';
  AAdmission.FName := '';
  AAdmission.FUniformScale := 0;
  AAdmission.FWidth := 0;
  AAdmission.FDepth := 0;
  AAdmission.FHeight := 0;
  AAdmission.FTriangles := 0;
  AAdmission.FVertices := 0;
  AAdmission.FTexturePixels := 0;
end;

function OptionalAssetAdmission(const AId: String;
  out AAdmission: TOptionalAssetAdmission): Boolean;
var
  LObject: TObjectAssetAdmission;
  LRegional: TRegionalAssetAdmission;
  LFurniture: TFurnitureProfile;
begin
  ClearAdmission(AAdmission);
  Result := True;
  if AId = BookId then
  begin
    AAdmission.FId := BookId;
    AAdmission.FKitId := 'kaykit-furniture-bits-1-0';
    AAdmission.FModelId := 'kaykit-furniture-bits-1-0/gltf/book_single';
    AAdmission.FSourceSha256 :=
      '7b86695b060681fc6de8ac70fc1f24b870edcaf84bfe4ed98b7e706ae594d464';
    AAdmission.FManifestSha256 :=
      '035cf9f058624c947f754d9049d8be075655c58086799c9335b029cc4bc680cb';
    AAdmission.FCategory := 'Objects';
    AAdmission.FSubcategory := 'Books';
    AAdmission.FRole := 'book';
    AAdmission.FName := 'Bound book';
    AAdmission.FUniformScale := 0.5;
    AAdmission.FWidth := 131;
    AAdmission.FDepth := 183;
    AAdmission.FHeight := 251;
    AAdmission.FTriangles := 68;
    AAdmission.FVertices := 112;
    AAdmission.FTexturePixels := 1048576;
  end else
  if AId = VaseId then
  begin
    AAdmission.FId := VaseId;
    AAdmission.FKitId := 'quaternius-furniture-low-poly-surface-v1';
    AAdmission.FModelId :=
      'quaternius-furniture-low-poly-surface-v1/vase2-2bf7766b41';
    AAdmission.FSourceSha256 :=
      '234d87682dd5750a2116aa1f010f84d1ef004e8963b27c89c545213964595623';
    AAdmission.FManifestSha256 :=
      '483f9ebda4ee132756dc7e701dee7fb245f824671158aa87819e80eab2d33c59';
    AAdmission.FCategory := 'Objects';
    AAdmission.FSubcategory := 'Vases';
    AAdmission.FRole := 'ornament';
    AAdmission.FName := 'Decorative vase';
    AAdmission.FUniformScale := 0.85;
    AAdmission.FWidth := 143;
    AAdmission.FDepth := 143;
    AAdmission.FHeight := 261;
    AAdmission.FTriangles := 204;
    AAdmission.FVertices := 612;
    AAdmission.FTexturePixels := 0;
  end else
  if ObjectAssetAdmission(AId, LObject) then
  begin
    AAdmission.FId := LObject.FId;
    AAdmission.FKitId := LObject.FKitId;
    AAdmission.FModelId := LObject.FModelId;
    AAdmission.FSourceSha256 := LObject.FSourceSha256;
    AAdmission.FManifestSha256 := LObject.FManifestSha256;
    AAdmission.FCategory := LObject.FCategory;
    AAdmission.FSubcategory := LObject.FSubcategory;
    AAdmission.FRole := LObject.FRole;
    AAdmission.FName := LObject.FName;
    AAdmission.FUniformScale := LObject.FUniformScale;
    AAdmission.FWidth := LObject.FWidth;
    AAdmission.FDepth := LObject.FDepth;
    AAdmission.FHeight := LObject.FHeight;
    AAdmission.FTriangles := LObject.FTriangles;
    AAdmission.FVertices := LObject.FVertices;
    AAdmission.FTexturePixels := LObject.FTexturePixels;
  end else
  if RegionalAssetAdmission(AId, LRegional) then
  begin
    AAdmission.FDomain := oadRegional;
    AAdmission.FId := LRegional.FId;
    AAdmission.FKitId := LRegional.FKitId;
    AAdmission.FModelId := LRegional.FModelId;
    AAdmission.FSourceSha256 := LRegional.FSourceSha256;
    AAdmission.FManifestSha256 := LRegional.FManifestSha256;
    AAdmission.FCategory := 'Nature';
    AAdmission.FSubcategory := LRegional.FRole;
    AAdmission.FRole := LRegional.FRole;
    AAdmission.FName := LRegional.FName;
    AAdmission.FUniformScale := LRegional.FUniformScale;
    AAdmission.FWidth := LRegional.FWidth;
    AAdmission.FDepth := LRegional.FDepth;
    AAdmission.FHeight := LRegional.FHeight;
    AAdmission.FTriangles := LRegional.FTriangles;
    AAdmission.FVertices := LRegional.FVertices;
    AAdmission.FTexturePixels := LRegional.FTexturePixels;
  end else
  if FurnitureProfile(AId, LFurniture) then
  begin
    AAdmission.FDomain := oadFurnishing;
    AAdmission.FId := LFurniture.FFloor.FContent.FId;
    AAdmission.FKitId := LFurniture.FKitId;
    AAdmission.FModelId := LFurniture.FModelId;
    AAdmission.FSourceSha256 := LFurniture.FSourceSha256;
    AAdmission.FManifestSha256 := LFurniture.FManifestSha256;
    AAdmission.FCategory := LFurniture.FCategory;
    AAdmission.FSubcategory := LFurniture.FSubcategory;
    AAdmission.FRole := LFurniture.FFloor.FContent.FRole;
    AAdmission.FName := LFurniture.FFloor.FContent.FName;
    AAdmission.FUniformScale := LFurniture.FUniformScale;
    AAdmission.FWidth := LFurniture.FFloor.FContent.FWidth;
    AAdmission.FDepth := LFurniture.FFloor.FContent.FDepth;
    AAdmission.FHeight := LFurniture.FFloor.FContent.FHeight;
    AAdmission.FTriangles := LFurniture.FTriangles;
    AAdmission.FVertices := LFurniture.FVertices;
    AAdmission.FTexturePixels := LFurniture.FTexturePixels;
  end else
  begin
    Result := False;
  end;
end;

function OptionalAssetIds: TOptionalAssetIds;
var
  LObjectIds: TObjectAssetIds;
  LIds: TRegionalAssetIds;
  LFurnitureIds: TFurnitureIds;
  I: Integer;
begin
  LObjectIds := ObjectAssetIds;
  LIds := RegionalAssetIds;
  LFurnitureIds := FurnitureIds;
  SetLength(Result, 2 + Length(LObjectIds) + Length(LIds) + Length(LFurnitureIds));
  Result[0] := BookId;
  Result[1] := VaseId;
  for I := 0 to High(LObjectIds) do
  begin
    Result[I + 2] := LObjectIds[I];
  end;
  for I := 0 to High(LIds) do
  begin
    Result[I + 2 + Length(LObjectIds)] := LIds[I];
  end;
  for I := 0 to High(LFurnitureIds) do
  begin
    Result[I + 2 + Length(LObjectIds) + Length(LIds)] := LFurnitureIds[I];
  end;
end;

end.
