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

unit phanes.interiors.profiles;
{$mode delphi}
{$H+}

interface

type
  TBuildingInterior = record
    FRoomAssetId: String;
    FName: String;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FFloor: Integer;
    FHasRoomPlans: Boolean;
  end;

function BuildingInterior(const AAssetId: String; out AProfile: TBuildingInterior): Boolean;

implementation

function BuildingInterior(const AAssetId: String; out AProfile: TBuildingInterior): Boolean;
begin
  AProfile := Default(TBuildingInterior);
  Result := True;
  if AAssetId = 'cabin' then
  begin
    AProfile.FName := 'Cabin';
    AProfile.FRoomAssetId := 'phanes.room.studio.v1';
    AProfile.FWidth := 9400;
    AProfile.FDepth := 9400;
    AProfile.FHeight := 2700;
    AProfile.FFloor := 80;
    AProfile.FHasRoomPlans := True;
  end
  else if (AAssetId = 'city-kit-suburban/building-type-a') or
    (AAssetId = 'city-kit-suburban/building-type-f') then
  begin
    { Imported meshes contain exterior shells only. These explicit portal rooms
      are independent authored spaces, not inferred floor plans or a promise of
      continuous mesh traversal. Dimensions are physical millimetres. The common
      furniture graph fits inside this room without scaling chairs or the player. }
    AProfile.FName := 'Gabled house';
    if AAssetId = 'city-kit-suburban/building-type-f' then
    begin
      AProfile.FName := 'Courtyard house';
    end;
    AProfile.FRoomAssetId := 'phanes.room.house-studio.v1';
    AProfile.FWidth := 8800;
    AProfile.FDepth := 7800;
    AProfile.FHeight := 2700;
    AProfile.FFloor := 120;
  end
  else
  begin
    Result := False;
  end;
end;

end.
