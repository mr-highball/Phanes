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

unit phanes.spaces.geometry;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types;

type
  TSpaceWall = record
    FMinX: Integer;
    FMinZ: Integer;
    FMaxX: Integer;
    FMaxZ: Integer;
    FBottom: Integer;
    FTop: Integer;
  end;
  TSpaceWalls = array of TSpaceWall;

{ Walls in the plan frame, including outer shell boundaries and 2200 mm
  door headers. Bay volumes exclude partition thickness. }
function CabinPlanWalls(const APlan: TCompositionNode): TSpaceWalls;
function SpaceWallBlocks(const AWall: TSpaceWall; const AX, AZ,
  ARadius, ABodyHeight: Double): Boolean;

implementation

uses
  Math,
  phanes.spaces.plans;

function CabinPlanWalls(const APlan: TCompositionNode): TSpaceWalls;
var
  LRows: Integer;
  LWidth: Integer;
  LCenter: Integer;
  LStart: Integer;
  LX: Integer;
  LSide: Integer;
  LRow: Integer;

  procedure AddWall(const AMinX, AMinZ, AMaxX, AMaxZ, ABottom, ATop: Integer);
  var
    LCount: Integer;
  begin
    LCount := Length(Result);
    SetLength(Result, LCount + 1);
    Result[LCount].FMinX := AMinX;
    Result[LCount].FMinZ := AMinZ;
    Result[LCount].FMaxX := AMaxX;
    Result[LCount].FMaxZ := AMaxZ;
    Result[LCount].FBottom := ABottom;
    Result[LCount].FTop := ATop;
  end;

begin
  Result := nil;
  LRows := CabinPlanRows(APlan.FAssetId);
  if LRows = 0 then
  begin
    Exit;
  end;
  { The interior cutaway has the cabin's clear 9.4 m shell footprint. Its
    exterior connection is an explicit return action until seamless traversal
    is admitted; the plan's 1.2 m entrance opening itself remains measured. }
  AddWall(-4800, -4800, -4700, 4800, 0, 2700);
  AddWall(4700, -4800, 4800, 4800, 0, 2700);
  AddWall(-4700, -4800, 4700, -4700, 0, 2700);
  AddWall(-4700, 4700, -600, 4800, 0, 2700);
  AddWall(600, 4700, 4700, 4800, 0, 2700);
  AddWall(-600, 4700, 600, 4800, 2200, 2700);
  LWidth := (9200 - (LRows - 1) * 100) div LRows;
  for LSide := 0 to 1 do
  begin
    LX := -700;
    if LSide = 1 then
    begin
      LX := 700;
    end;
    LStart := -4700;
    for LRow := 0 to LRows - 1 do
    begin
      LCenter := -4600 + LWidth div 2 + LRow * (LWidth + 100);
      AddWall(LX - 50, LStart, LX + 50, LCenter - 500, 0, 2700);
      AddWall(LX - 50, LCenter - 500, LX + 50, LCenter + 500, 2200, 2700);
      LStart := LCenter + 500;
      if LRow < LRows - 1 then
      begin
        if LSide = 0 then
        begin
          AddWall(-4700, LCenter + LWidth div 2, -650,
            LCenter + LWidth div 2 + 100, 0, 2700);
        end
        else
        begin
          AddWall(650, LCenter + LWidth div 2, 4700,
            LCenter + LWidth div 2 + 100, 0, 2700);
        end;
      end;
    end;
    AddWall(LX - 50, LStart, LX + 50, 4700, 0, 2700);
  end;
end;

function SpaceWallBlocks(const AWall: TSpaceWall; const AX, AZ,
  ARadius, ABodyHeight: Double): Boolean;
var
  LX: Double;
  LZ: Double;
begin
  if IsNan(AX) or IsInfinite(AX) or IsNan(AZ) or IsInfinite(AZ) or
    IsNan(ARadius) or IsInfinite(ARadius) or (ARadius <= 0) or
    IsNan(ABodyHeight) or IsInfinite(ABodyHeight) or (ABodyHeight <= 0) or
    (AWall.FMinX > AWall.FMaxX) or (AWall.FMinZ > AWall.FMaxZ) or
    (AWall.FBottom > AWall.FTop) then
  begin
    Exit(True);
  end;
  if (AWall.FBottom >= ABodyHeight) or (AWall.FTop <= 0) then
  begin
    Exit(False);
  end;
  LX := Max(AWall.FMinX - AX, Max(AX - AWall.FMaxX, 0));
  LZ := Max(AWall.FMinZ - AZ, Max(AZ - AWall.FMaxZ, 0));
  Result := LX * LX + LZ * LZ < ARadius * ARadius;
end;

end.
