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

unit phanes.structures.support;

{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.document;

const
  SupportedBuildingCount = 7;

type
  TSupportedBuilding = record
    FAssetId: String;
    FName: String;
    FHalfX: Integer;
    FHalfZ: Integer;
    FModelYawDegrees: Integer;
    FHasStudio: Boolean;
  end;

function SupportedBuilding(const AAssetId: String; out AProfile: TSupportedBuilding): Boolean;
function SupportedBuildingAt(const AIndex: Integer): TSupportedBuilding;
function SupportedBuildingOwner(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANode: Integer): String;
function ValidSupportedBuilding(const ANode: TCompositionNode;
  const ADeckId: String; const ATurn: Integer): Boolean;
function BuildingAllowsStanding(const AAssetId: String; const AX, AZ, ARadius: Double): Boolean;

implementation

uses
  Math;

function SupportedBuildingAt(const AIndex: Integer): TSupportedBuilding;
begin
  Result := Default(TSupportedBuilding);
  { Metre-normalized CGE meshes, including eaves and outlying equipment.
    Both plot purposes admit these static shells by physical fit. This catalog
    does not assert functioning launch vehicles, interiors or modular WFC geometry. }
  case AIndex of
    0:
      begin
        Result.FAssetId := 'cabin';
        Result.FName := 'Cabin';
        Result.FHalfX := 5340;
        Result.FHalfZ := 5300;
        Result.FHasStudio := True;
      end;
    1:
      begin
        Result.FAssetId := 'keep';
        Result.FName := 'Keep';
        { The authored doorway is on raw +X; rotate it to logical +Z. }
        Result.FModelYawDegrees := 270;
        Result.FHalfX := 7000;
        Result.FHalfZ := 7000;
      end;
    2:
      begin
        Result.FAssetId := 'city-kit-suburban/building-type-a';
        Result.FName := 'Gabled house';
        Result.FHasStudio := True;
        Result.FModelYawDegrees := 180;
        Result.FHalfX := 6000;
        Result.FHalfZ := 4750;
      end;
    3:
      begin
        Result.FAssetId := 'city-kit-suburban/building-type-f';
        Result.FName := 'Courtyard house';
        Result.FHasStudio := True;
        Result.FModelYawDegrees := 180;
        Result.FHalfX := 6000;
        Result.FHalfZ := 5910;
      end;
    4:
      begin
        Result.FAssetId := 'space-kit/hangar_roundA';
        Result.FName := 'Round module';
        Result.FHalfX := 6000;
        Result.FHalfZ := 5200;
      end;
    5:
      begin
        Result.FAssetId := 'space-kit/hangar_smallA';
        Result.FName := 'Small habitat';
        Result.FHalfX := 6000;
        Result.FHalfZ := 6000;
      end;
    6:
      begin
        Result.FAssetId := 'rocket';
        Result.FName := 'Rocket';
        Result.FHalfX := 3600;
        Result.FHalfZ := 3600;
      end;
  end;
end;

function SupportedBuilding(const AAssetId: String; out AProfile: TSupportedBuilding): Boolean;
var
  I: Integer;
begin
  for I := 0 to SupportedBuildingCount - 1 do
  begin
    AProfile := SupportedBuildingAt(I);
    if AProfile.FAssetId = AAssetId then
    begin
      Exit(True);
    end;
  end;
  AProfile := Default(TSupportedBuilding);
  Result := False;
end;

function SupportedBuildingOwner(const ADocument: TCompositionDocument;
  const AIndex: TCompositionIndex; const ANode: Integer): String;
var
  LCurrent: Integer;
  LParent: Integer;
  LNode: TCompositionNode;
  I: Integer;
begin
  Result := '';
  LCurrent := ANode;
  for I := 0 to 128 do
  begin
    if (LCurrent < 0) or (LCurrent >= Length(ADocument.FNodes)) then
    begin
      Exit;
    end;
    LNode := ADocument.FNodes[LCurrent];
    LParent := AIndex.Find(LNode.FParentId);
    if (LNode.FKind = ckContainer) and (LNode.FRole = 'building') and
      (LNode.FId = LNode.FParentId + '.building') and (LParent >= 0) then
    begin
      if ADocument.FNodes[LParent].FAssetId = 'phanes.groundworks.deck16.v1' then
      begin
        Exit(LNode.FId);
      end;
    end;
    LCurrent := LParent;
  end;
end;

function ValidSupportedBuilding(const ANode: TCompositionNode;
  const ADeckId: String; const ATurn: Integer): Boolean;
var
  LProfile: TSupportedBuilding;
begin
  Result := SupportedBuilding(ANode.FAssetId, LProfile) and
    (ANode.FId = ADeckId + '.building') and (ANode.FParentId = ADeckId) and
    (ANode.FSupportId = ADeckId) and (ANode.FKind = ckContainer) and
    (ANode.FRole = 'building') and (ANode.FX = 0) and (ANode.FY = 0) and
    (ANode.FZ = 0) and (ANode.FQuarterTurn = ATurn) and
    (LProfile.FHalfX <= 7000) and (LProfile.FHalfZ <= 7000);
end;

function BuildingAllowsStanding(const AAssetId: String; const AX, AZ, ARadius: Double): Boolean;
var
  LProfile: TSupportedBuilding;
  LDX: Double;
  LDZ: Double;
begin
  if not SupportedBuilding(AAssetId, LProfile) then
  begin
    Exit(AAssetId = '');
  end;
  { Current facing offsets are half turns, or belong to square envelopes. }
  LDX := Max(Abs(AX) - LProfile.FHalfX / 1000, 0);
  LDZ := Max(Abs(AZ) - LProfile.FHalfZ / 1000, 0);
  Result := LDX * LDX + LDZ * LDZ > ARadius * ARadius;
end;

end.
