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
unit phanes.interiors.catalog;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.contents.types;

type
  TInteriorAsset = record
    FId: String;
    FName: UnicodeString;
    FRole: String;
    FShape: String;
    FSourcePath: String;
    FUniformScale: Single;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FRed: Single;
    FGreen: Single;
    FBlue: Single;
  end;

function InteriorAsset(const AId: String; out AAsset: TInteriorAsset): Boolean;
function InteriorContentAssets: TContentAssets;
procedure InteriorContentGroup(const AId: String; out ACategory, AGroup: String);
function InteriorPlateSupport: TContentSupport;
function InteriorAssemblyAsset(const AId: String; out AAsset: TContentAsset): Boolean;

implementation

uses
  phanes.catalog.admission, phanes.catalog.furniture;

function InteriorAsset(const AId: String; out AAsset: TInteriorAsset): Boolean;
var
  LOptional: TOptionalAssetAdmission;
begin
  AAsset := Default(TInteriorAsset);
  AAsset.FId := AId;
  AAsset.FRed := 0.55;
  AAsset.FGreen := 0.37;
  AAsset.FBlue := 0.21;
  Result := True;
  if AId = 'phanes.table.oak.v1' then
  begin
    AAsset.FName := 'Oak worktable';
    AAsset.FRole := 'table';
    AAsset.FShape := 'kit-table';
    AAsset.FWidth := 1933;
    AAsset.FDepth := 1028;
    AAsset.FHeight := 750;
  end
  else if AId = 'phanes.shelf.oak.v1' then
  begin
    AAsset.FName := 'Four-tier bookcase';
    AAsset.FRole := 'bookcase';
    AAsset.FShape := 'kit-bookcase';
    AAsset.FWidth := 800;
    AAsset.FDepth := 500;
    AAsset.FHeight := 1760;
  end
  else if AId = 'phanes.table.lab.v1' then
  begin
    AAsset.FName := 'Laboratory workbench';
    AAsset.FRole := 'bench';
    AAsset.FShape := 'kit-table';
    AAsset.FWidth := 1933;
    AAsset.FDepth := 1028;
    AAsset.FHeight := 750;
  end
  else if AId = 'phanes.fixture.sink.v1' then
  begin
    AAsset.FName := 'Basin';
    AAsset.FRole := 'sink';
    AAsset.FShape := 'kit-fixture';
    AAsset.FSourcePath := 'furniture-kit/bathroomSink';
    AAsset.FUniformScale := 1.6;
    AAsset.FWidth := 546;
    AAsset.FDepth := 466;
    AAsset.FHeight := 898;
  end
  else if AId = 'phanes.fixture.toilet.v1' then
  begin
    AAsset.FName := 'Toilet';
    AAsset.FRole := 'toilet';
    AAsset.FShape := 'kit-fixture';
    AAsset.FSourcePath := 'furniture-kit/toilet';
    AAsset.FUniformScale := 1.65;
    AAsset.FWidth := 516;
    AAsset.FDepth := 788;
    AAsset.FHeight := 745;
  end
  else if AId = 'phanes.fixture.shower.v1' then
  begin
    AAsset.FName := 'Shower enclosure';
    AAsset.FRole := 'shower';
    AAsset.FShape := 'kit-fixture';
    AAsset.FSourcePath := 'furniture-kit/shower';
    AAsset.FUniformScale := 2;
    AAsset.FWidth := 1124;
    AAsset.FDepth := 1164;
    AAsset.FHeight := 2189;
  end
  else if AId = 'phanes.fixture.console.v1' then
  begin
    AAsset.FName := 'Laboratory console';
    AAsset.FRole := 'console';
    AAsset.FShape := 'kit-fixture';
    AAsset.FSourcePath := 'space-kit/desk_computerScreen';
    AAsset.FUniformScale := 2;
    AAsset.FWidth := 1052;
    AAsset.FDepth := 452;
    AAsset.FHeight := 1276;
  end
  else if (AId = 'phanes.plant.fern.v1') or (AId = 'phanes.plant.moon.v1') then
  begin
    AAsset.FName := 'Potted fern';
    AAsset.FRole := 'plant';
    AAsset.FShape := 'potted-plant';
    AAsset.FWidth := 800;
    AAsset.FDepth := 800;
    AAsset.FHeight := 1400;
    AAsset.FRed := 0.25;
    AAsset.FGreen := 0.45;
    AAsset.FBlue := 0.30;
    if AId = 'phanes.plant.moon.v1' then
    begin
      AAsset.FName := 'Moonleaf plant';
      AAsset.FRed := 0.42;
      AAsset.FGreen := 0.55;
      AAsset.FBlue := 0.48;
    end;
  end
  else if AId = 'phanes.chair.sage.v1' then
  begin
    AAsset.FName := 'Oak chair';
    AAsset.FRole := 'chair';
    AAsset.FShape := 'kit-chair';
    AAsset.FWidth := 400;
    AAsset.FDepth := 400;
    AAsset.FHeight := 940;
    AAsset.FRed := 0.40;
    AAsset.FGreen := 0.51;
    AAsset.FBlue := 0.38;
  end
  else if (AId = 'phanes.book.sage.v1') or (AId = 'phanes.book.clay.v1') or
    (AId = 'phanes.book.indigo.v1') then
  begin
    AAsset.FName := 'Bound book';
    AAsset.FRole := 'book';
    AAsset.FShape := 'book';
    AAsset.FWidth := 48;
    AAsset.FDepth := 190;
    AAsset.FHeight := 250;
    AAsset.FRed := 0.25;
    AAsset.FGreen := 0.39;
    AAsset.FBlue := 0.31;
    if AId = 'phanes.book.clay.v1' then
    begin
      AAsset.FName := 'Clay book';
      AAsset.FRed := 0.67;
      AAsset.FGreen := 0.31;
      AAsset.FBlue := 0.20;
    end
    else if AId = 'phanes.book.indigo.v1' then
    begin
      AAsset.FName := 'Indigo book';
      AAsset.FRed := 0.24;
      AAsset.FGreen := 0.29;
      AAsset.FBlue := 0.52;
    end
    else
    begin
      AAsset.FName := 'Sage book';
    end;
  end
  else if (AId = 'phanes.snail.ivory.v1') or (AId = 'phanes.snail.azure.v1') then
  begin
    AAsset.FName := 'Ceramic snail';
    AAsset.FRole := 'ornament';
    AAsset.FShape := 'snail';
    AAsset.FWidth := 140;
    AAsset.FDepth := 90;
    AAsset.FHeight := 100;
    AAsset.FRed := 0.90;
    AAsset.FGreen := 0.82;
    AAsset.FBlue := 0.65;
    if AId = 'phanes.snail.azure.v1' then
    begin
      AAsset.FName := 'Azure ceramic snail';
      AAsset.FRed := 0.23;
      AAsset.FGreen := 0.48;
      AAsset.FBlue := 0.57;
    end
    else
    begin
      AAsset.FName := 'Ivory ceramic snail';
    end;
  end
  else if (AId = 'phanes.plate.ivory.v1') or (AId = 'phanes.plate.azure.v1') then
  begin
    AAsset.FName := 'Ivory plate';
    AAsset.FRole := 'plate';
    AAsset.FShape := 'plate';
    AAsset.FWidth := 260;
    AAsset.FDepth := 260;
    AAsset.FHeight := 24;
    AAsset.FRed := 0.92;
    AAsset.FGreen := 0.88;
    AAsset.FBlue := 0.74;
    if AId = 'phanes.plate.azure.v1' then
    begin
      AAsset.FName := 'Azure plate';
      AAsset.FRed := 0.22;
      AAsset.FGreen := 0.43;
      AAsset.FBlue := 0.48;
    end;
  end
  else if AId = 'phanes.fork.silver.v1' then
  begin
    AAsset.FName := 'Silver fork';
    AAsset.FRole := 'fork';
    AAsset.FShape := 'fork';
    AAsset.FWidth := 28;
    AAsset.FDepth := 190;
    AAsset.FHeight := 8;
    AAsset.FRed := 0.64;
    AAsset.FGreen := 0.70;
    AAsset.FBlue := 0.71;
  end
  else if (AId = 'phanes.food.bread.country.v1') or (AId = 'phanes.food.bread.rye.v1') then
  begin
    AAsset.FName := 'Country bread';
    AAsset.FRole := 'bread';
    AAsset.FShape := 'bread';
    AAsset.FWidth := 50;
    AAsset.FDepth := 86;
    AAsset.FHeight := 18;
    AAsset.FRed := 0.68;
    AAsset.FGreen := 0.42;
    AAsset.FBlue := 0.19;
    if AId = 'phanes.food.bread.rye.v1' then
    begin
      AAsset.FName := 'Rye bread';
      AAsset.FRed := 0.40;
      AAsset.FGreen := 0.24;
      AAsset.FBlue := 0.12;
    end;
  end
  else if (AId = 'phanes.food.fruit.apple.v1') or (AId = 'phanes.food.fruit.pear.v1') then
  begin
    AAsset.FName := 'Crimson apple';
    AAsset.FRole := 'fruit';
    AAsset.FShape := 'apple';
    AAsset.FWidth := 40;
    AAsset.FDepth := 40;
    AAsset.FHeight := 48;
    AAsset.FRed := 0.61;
    AAsset.FGreen := 0.12;
    AAsset.FBlue := 0.055;
    if AId = 'phanes.food.fruit.pear.v1' then
    begin
      AAsset.FName := 'Golden pear';
      AAsset.FShape := 'pear';
      AAsset.FRed := 0.73;
      AAsset.FGreen := 0.65;
      AAsset.FBlue := 0.21;
    end;
  end
  else if (AId = 'phanes.food.cheese.amber.v1') or (AId = 'phanes.food.cheese.herb.v1') then
  begin
    AAsset.FName := 'Amber cheese';
    AAsset.FRole := 'cheese';
    AAsset.FShape := 'cheese';
    AAsset.FWidth := 42;
    AAsset.FDepth := 44;
    AAsset.FHeight := 22;
    AAsset.FRed := 0.91;
    AAsset.FGreen := 0.61;
    AAsset.FBlue := 0.18;
    if AId = 'phanes.food.cheese.herb.v1' then
    begin
      AAsset.FName := 'Herbed cheese';
      AAsset.FShape := 'herb-cheese';
      AAsset.FRed := 0.82;
      AAsset.FGreen := 0.80;
      AAsset.FBlue := 0.53;
    end;
  end
  else if OptionalAssetAdmission(AId, LOptional) and
    (LOptional.FDomain in [oadInterior, oadFurnishing]) then
  begin
    AAsset.FName := LOptional.FName;
    AAsset.FRole := LOptional.FRole;
    AAsset.FShape := 'kit-fixture';
    AAsset.FSourcePath := LOptional.FId;
    AAsset.FUniformScale := LOptional.FUniformScale;
    AAsset.FWidth := LOptional.FWidth;
    AAsset.FDepth := LOptional.FDepth;
    AAsset.FHeight := LOptional.FHeight;
  end
  else
  begin
    Result := False;
  end;
end;

procedure InteriorContentGroup(const AId: String; out ACategory, AGroup: String);
var
  LOptional: TOptionalAssetAdmission;
  LAsset: TInteriorAsset;
begin
  ACategory := '';
  AGroup := '';
  if OptionalAssetAdmission(AId, LOptional) and (LOptional.FDomain = oadInterior) then
  begin
    ACategory := LOptional.FCategory;
    AGroup := LOptional.FSubcategory;
    Exit;
  end;
  if not InteriorAsset(AId, LAsset) then
  begin
    Exit;
  end;
  ACategory := 'Objects';
  if LAsset.FRole = 'book' then
  begin
    AGroup := 'Books';
  end else if LAsset.FRole = 'ornament' then
  begin
    AGroup := 'Ornaments';
  end else if LAsset.FRole = 'plate' then
  begin
    AGroup := 'Plates';
  end else if LAsset.FRole = 'fork' then
  begin
    AGroup := 'Cutlery';
  end else if LAsset.FRole = 'bread' then
  begin
    ACategory := 'Food';
    AGroup := 'Bread';
  end else if LAsset.FRole = 'fruit' then
  begin
    ACategory := 'Food';
    AGroup := 'Fruit';
  end else if LAsset.FRole = 'cheese' then
  begin
    ACategory := 'Food';
    AGroup := 'Cheese';
  end;
end;

function InteriorContentAssets: TContentAssets;
const
  CIds: array[0..13] of String = (
    'phanes.book.sage.v1', 'phanes.book.clay.v1', 'phanes.book.indigo.v1',
    'phanes.snail.ivory.v1', 'phanes.snail.azure.v1',
    'phanes.plate.ivory.v1', 'phanes.fork.silver.v1', 'phanes.plate.azure.v1',
    'phanes.food.bread.country.v1', 'phanes.food.bread.rye.v1',
    'phanes.food.fruit.apple.v1', 'phanes.food.fruit.pear.v1',
    'phanes.food.cheese.amber.v1', 'phanes.food.cheese.herb.v1');
var
  LAsset: TInteriorAsset;
  LIds: TOptionalAssetIds;
  LOptional: TOptionalAssetAdmission;
  LCount: Integer;
  I: Integer;

  procedure AddAsset(const AId: String);
  begin
    if not InteriorAsset(AId, LAsset) then
    begin
      Exit;
    end;
    Result[LCount].FId := LAsset.FId;
    Result[LCount].FName := LAsset.FName;
    Result[LCount].FRole := LAsset.FRole;
    Result[LCount].FWidth := LAsset.FWidth;
    Result[LCount].FDepth := LAsset.FDepth;
    Result[LCount].FHeight := LAsset.FHeight;
    Result[LCount].FSingleInstance := True;
    if LAsset.FRole = 'plate' then
    begin
      SetLength(Result[LCount].FSupports, 1);
      Result[LCount].FSupports[0] := InteriorPlateSupport;
    end;
    Inc(LCount);
  end;

begin
  LIds := OptionalAssetIds;
  SetLength(Result, Length(CIds) + Length(LIds));
  LCount := 0;
  for I := 0 to High(CIds) do
  begin
    AddAsset(CIds[I]);
  end;
  for I := 0 to High(LIds) do
  begin
    if OptionalAssetAdmission(LIds[I], LOptional) and
      (LOptional.FDomain = oadInterior) then
    begin
      AddAsset(LIds[I]);
    end;
  end;
  SetLength(Result, LCount);
end;

function InteriorPlateSupport: TContentSupport;
begin
  Result := Default(TContentSupport);
  Result.FKey := 'well';
  Result.FName := 'On this plate';
  Result.FRole := 'plate-well';
  Result.FAssetId := 'phanes.support.plate.v1';
  Result.FY := 6;
  { The 116 mm square fits inside the actual 85 mm radius flat center, including
    the 64-sided mesh's chord boundary. The 24 mm outer rim is not the contact. }
  Result.FWidth := 116;
  Result.FDepth := 116;
  Result.FHeadroom := 80;
  Result.FAllowedRoles := ['bread', 'fruit', 'cheese'];
end;

function InteriorAssemblyAsset(const AId: String; out AAsset: TContentAsset): Boolean;
var
  LInterior: TInteriorAsset;
  LFurniture: TFurnitureProfile;
  LSupport: TContentSupport;
  I: Integer;
begin
  AAsset := Default(TContentAsset);
  { Furniture supports follow their measured source geometry, before the
    legacy role-based profiles used by existing saved tables and shelves. }
  if FurnitureProfile(AId, LFurniture) then
  begin
    AAsset := LFurniture.FFloor.FContent;
    Exit(True);
  end;
  Result := InteriorAsset(AId, LInterior);
  if not Result then
  begin
    Exit;
  end;
  AAsset.FId := LInterior.FId;
  AAsset.FName := LInterior.FName;
  AAsset.FRole := LInterior.FRole;
  AAsset.FWidth := LInterior.FWidth;
  AAsset.FDepth := LInterior.FDepth;
  AAsset.FHeight := LInterior.FHeight;
  AAsset.FSingleInstance := True;
  if LInterior.FRole = 'plate' then
  begin
    SetLength(AAsset.FSupports, 1);
    AAsset.FSupports[0] := InteriorPlateSupport;
  end
  else if LInterior.FRole = 'bookcase' then
  begin
    SetLength(AAsset.FSupports, 4);
    for I := 0 to 3 do
    begin
      LSupport := Default(TContentSupport);
      LSupport.FKey := 'tier-' + Chr(Ord('1') + I);
      LSupport.FName := 'Shelf ' + UnicodeString(Chr(Ord('1') + I));
      LSupport.FRole := 'shelf-tier';
      LSupport.FAssetId := 'phanes.support.shelf.v1';
      LSupport.FY := 260 + I * 480;
      LSupport.FWidth := 720;
      LSupport.FDepth := 420;
      LSupport.FHeadroom := 420;
      LSupport.FAllowedRoles := ['book', 'ornament'];
      AAsset.FSupports[I] := LSupport;
    end;
  end
  else if (LInterior.FRole = 'table') or (LInterior.FRole = 'bench') then
  begin
    LSupport := Default(TContentSupport);
    LSupport.FKey := 'top';
    LSupport.FName := 'Tabletop';
    LSupport.FRole := 'tabletop';
    LSupport.FAssetId := 'phanes.support.table.v1';
    LSupport.FY := 750;
    LSupport.FWidth := 1500;
    LSupport.FDepth := 800;
    LSupport.FHeadroom := 400;
    LSupport.FAllowedRoles := ['plate', 'fork'];
    if LInterior.FRole = 'bench' then
    begin
      LSupport.FName := 'Work surface';
      LSupport.FRole := 'bench-top';
      LSupport.FAssetId := 'phanes.support.bench.v1';
      LSupport.FHeadroom := 700;
      LSupport.FAllowedRoles := ['book', 'ornament'];
    end;
    SetLength(AAsset.FSupports, 1);
    AAsset.FSupports[0] := LSupport;
  end;
end;

end.
