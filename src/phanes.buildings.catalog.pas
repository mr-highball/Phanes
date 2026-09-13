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
unit phanes.buildings.catalog;
{$mode delphi}
{$H+}
interface
uses phanes.composition.contents.types;
const
  FloorCategories: array[0..13] of String = ('Living spaces', 'Food', 'Kitchen',
    'Seating', 'Cabinets', 'Plants', 'Bathroom', 'Lighting', 'Equipment',
    'Artifacts', 'Containers', 'Sculptures', 'Technology', 'Objects');
function FloorCatalogIds(const ACategory: String): TContentNames;
function FloorCatalogAsset(const AId: String; out AAsset: TContentAsset): Boolean;
function FloorCatalogLabel(const AId: String): String;
implementation
uses SysUtils, phanes.catalog.objects, phanes.buildings.furniture;
function FloorCatalogAsset(const AId: String; out AAsset: TContentAsset): Boolean;
var
  LProfile: TObjectAssetAdmission;
  LAssets: TContentAssets;
  I: Integer;
begin
  AAsset := Default(TContentAsset);
  if ObjectAssetAdmission(AId, LProfile) then
  begin
    AAsset.FId := AId;
    AAsset.FName := LProfile.FName;
    AAsset.FRole := LProfile.FRole;
    AAsset.FWidth := LProfile.FWidth;
    AAsset.FDepth := LProfile.FDepth;
    AAsset.FHeight := LProfile.FHeight;
    AAsset.FSingleInstance := True;
    Exit(True);
  end;
  LAssets := BuildingFurnitureAssets;
  for I := 0 to High(LAssets) do
  begin
    if LAssets[I].FId = AId then
    begin
      AAsset := LAssets[I];
      Exit(True);
    end;
  end;
  Result := False;
end;
function FloorCatalogLabel(const AId: String): String;
var
  LProfile: TObjectAssetAdmission;
  LAsset: TContentAsset;
begin
  Result := AId;
  if ObjectAssetAdmission(AId, LProfile) then
  begin
    Exit(String(LProfile.FName) + ' (' + LProfile.FKitId + ')');
  end;
  if FloorCatalogAsset(AId, LAsset) then
  begin
    Result := String(LAsset.FName);
  end;
end;
function FloorCatalogIds(const ACategory: String): TContentNames;
var
  LIds: TObjectAssetIds;
  LBase: TContentAssets;
  LProfile: TObjectAssetAdmission;
  LCategory: String;
  LName: String;
  LMatch: Boolean;
  I: Integer;
  procedure Add(const AId: String);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AId;
  end;
begin
  Result := nil;
  LBase := BuildingFurnitureAssets;
  for I := 0 to High(LBase) do
  begin
    if (LBase[I].FWidth > 2000) or (LBase[I].FDepth > 2000) or
      (LBase[I].FHeight > 2800) or not ContentRoleAllowed(
      ['table', 'bookcase', 'chair', 'bench', 'plant', 'sink', 'toilet',
      'shower', 'console', 'ornament'], LBase[I].FRole) then
    begin
      Continue;
    end;
    LCategory := 'Living spaces';
    if LBase[I].FRole = 'ornament' then
    begin
      LCategory := 'Objects';
    end else if LBase[I].FRole = 'plant' then
    begin
      LCategory := 'Plants';
    end else if (LBase[I].FRole = 'sink') or (LBase[I].FRole = 'toilet') or
      (LBase[I].FRole = 'shower') then
    begin
      LCategory := 'Bathroom';
    end else if LBase[I].FRole = 'console' then
    begin
      LCategory := 'Technology';
    end else if LBase[I].FRole = 'chair' then
    begin
      LCategory := 'Seating';
    end;
    if LCategory = ACategory then
    begin
      Add(LBase[I].FId);
    end;
  end;
  LIds := ObjectAssetIds;
  for I := 0 to High(LIds) do
  begin
    if (Pos('phanes.catalog.batch.', LIds[I]) <> 1) or
      not ObjectAssetAdmission(LIds[I], LProfile) then
    begin
      Continue;
    end;
    LCategory := LProfile.FCategory;
    if (LCategory = 'Sofas') or (LCategory = 'Benches') then
    begin
      LCategory := 'Living spaces';
    end else if LCategory = 'Storage props' then
    begin
      LCategory := 'Containers';
    end else if LCategory = 'Lighting props' then
    begin
      LCategory := 'Lighting';
    end;
    LName := LowerCase(String(LProfile.FName));
    LMatch := LCategory = ACategory;
    if ACategory = 'Kitchen' then
    begin
      LMatch := (LCategory <> 'Food') and
        ((Pos('kitchen', LName) > 0) or (Pos('plate', LName) > 0) or
        (Pos('mug', LName) > 0) or (Pos('cup', LName) > 0) or
        (Pos('utensil', LName) > 0) or (Pos('pan ', LName + ' ') = 1) or
        (Pos('pot ', LName + ' ') = 1));
    end else if ACategory = 'Bathroom' then
    begin
      LMatch := LMatch or (Pos('bathroom', LName) > 0);
    end;
    if LMatch then
    begin
      Add(LIds[I]);
    end;
  end;
end;
end.
