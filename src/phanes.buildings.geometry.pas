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
unit phanes.buildings.geometry;
{$mode delphi}
{$H+}

interface

uses
  phanes.buildings.types;

type
  TModuleMaterial = (mmFloor, mmPlaster, mmWood, mmGlass, mmMetal);
  TModuleBox = record
    FX: Double;
    FY: Double;
    FZ: Double;
    FWidth: Double;
    FHeight: Double;
    FDepth: Double;
    FMaterial: TModuleMaterial;
  end;
  TModuleBoxes = array of TModuleBox;

function ModuleBoxes(const AToken: String): TModuleBoxes;
function ModuleBlocks(const AEdge: TBuildingEdge; const AX, AZ, ARadius: Double): Boolean;
function ModuleDoorSweepBlocks(const AEdge: TBuildingEdge; const AX, AZ, ARadius: Double): Boolean;
function ModuleDoorSweepMeetsEdge(const ADoor, AOther: TBuildingEdge): Boolean;

implementation

uses
  Math, SysUtils;

function ModuleBoxes(const AToken: String): TModuleBoxes;
var
  LMaterial: TModuleMaterial;
  I: Integer;

  procedure Add(const AX, AY, AZ, AWidth, AHeight, ADepth: Double; const AMaterial: TModuleMaterial);
  var
    LAt: Integer;
  begin
    LAt := Length(Result);
    SetLength(Result, LAt + 1);
    Result[LAt].FX := AX;
    Result[LAt].FY := AY;
    Result[LAt].FZ := AZ;
    Result[LAt].FWidth := AWidth;
    Result[LAt].FHeight := AHeight;
    Result[LAt].FDepth := ADepth;
    Result[LAt].FMaterial := AMaterial;
  end;

begin
  Result := nil;
  LMaterial := mmPlaster;
  if Pos('.timber', AToken) > 0 then
  begin
    LMaterial := mmWood;
  end;
  if ModuleIsFloor(AToken) then
  begin
    Add(0, -0.08, 0, 2, 0.16, 2, mmFloor);
    Exit;
  end;
  if AToken = 'opening' then
  begin
    Exit;
  end;
  if ModuleIsWindow(AToken) then
  begin
    Add(0, 0.45, 0, 2, 0.9, 0.16, LMaterial);
    Add(0, 2.55, 0, 2, 0.5, 0.16, LMaterial);
    for I := -1 to 1 do
    begin
      if I = 0 then
      begin
        Continue;
      end;
      Add(I * 0.87, 1.6, 0, 0.26, 1.4, 0.16, LMaterial);
      Add(I * 0.70, 1.6, 0, 0.08, 1.44, 0.22, mmWood);
    end;
    Add(0, 0.93, 0, 1.48, 0.08, 0.32, mmWood);
    Add(0, 2.27, 0, 1.48, 0.08, 0.22, mmWood);
    Add(0, 1.6, 0, 1.32, 1.26, 0.012, mmGlass);
    Exit;
  end;
  if ModuleIsDoor(AToken) then
  begin
    for I := -1 to 1 do
    begin
      if I = 0 then
      begin
        Continue;
      end;
      Add(I * 0.82, 1.1, 0, 0.36, 2.2, 0.16, LMaterial);
      Add(I * 0.62, 1.1, 0, 0.06, 2.2, 0.20, mmWood);
    end;
    Add(0, 2.5, 0, 2, 0.6, 0.16, LMaterial);
    Add(0, 2.2, 0, 1.30, 0.08, 0.22, mmWood);
    if Pos('door.open.', AToken) = 1 then
    begin
      Add(-0.59, 1.08, 0.57, 0.06, 2.16, 1.14, mmWood);
      Add(-0.53, 1.04, 1.03, 0.08, 0.06, 0.10, mmMetal);
    end
    else
    begin
      Add(0, 1.08, 0, 1.18, 2.16, 0.06, mmWood);
      Add(0.48, 1.04, 0.065, 0.10, 0.06, 0.08, mmMetal);
      Add(0.48, 1.04, -0.065, 0.10, 0.06, 0.08, mmMetal);
    end;
    Exit;
  end;
  if (AToken = 'wall.plaster') or (AToken = 'wall.timber') then
  begin
    Add(0, 1.4, 0, 2, 2.8, 0.16, LMaterial);
  end;
end;

procedure EdgeLocal(const AEdge: TBuildingEdge; const AX, AZ: Double; out AU, AV: Double);
begin
  AU := AX - AEdge.FNode.FX / 1000;
  AV := AZ - AEdge.FNode.FZ / 1000;
  if AEdge.FVertical then
  begin
    AU := -(AZ - AEdge.FNode.FZ / 1000);
    AV := AX - AEdge.FNode.FX / 1000;
  end;
end;

function ModuleBlocks(const AEdge: TBuildingEdge; const AX, AZ, ARadius: Double): Boolean;
var
  LBoxes: TModuleBoxes;
  LBox: TModuleBox;
  LU: Double;
  LV: Double;
  LDX: Double;
  LDZ: Double;
  I: Integer;
begin
  Result := False;
  EdgeLocal(AEdge, AX, AZ, LU, LV);
  if (Abs(LU) > 1.4 + ARadius) or (Abs(LV) > 1.4 + ARadius) then
  begin
    Exit;
  end;
  LBoxes := ModuleBoxes(ModuleToken(AEdge.FNode.FAssetId));
  for I := 0 to High(LBoxes) do
  begin
    LBox := LBoxes[I];
    if (LBox.FY - LBox.FHeight / 2 >= 1.85) or (LBox.FY + LBox.FHeight / 2 <= 0) then
    begin
      Continue;
    end;
    LDX := Max(0, Abs(LU - LBox.FX) - LBox.FWidth / 2);
    LDZ := Max(0, Abs(LV - LBox.FZ) - LBox.FDepth / 2);
    if Sqr(LDX) + Sqr(LDZ) < Sqr(ARadius) then
    begin
      Exit(True);
    end;
  end;
end;

function ModuleDoorSweepMeetsEdge(const ADoor, AOther: TBuildingEdge): Boolean;
var
  LBoxes: TModuleBoxes;
  LBox: TModuleBox;
  LX: Double;
  LZ: Double;
  LU: Double;
  LV: Double;
  LHalfU: Double;
  LHalfV: Double;
  LMinU: Double;
  LMinV: Double;
  LMaxU: Double;
  LMaxV: Double;
  I: Integer;
begin
  Result := False;
  if (Abs(ADoor.FNode.FX - AOther.FNode.FX) > 4000) or
    (Abs(ADoor.FNode.FZ - AOther.FNode.FZ) > 4000) then
  begin
    Exit;
  end;
  LBoxes := ModuleBoxes(ModuleToken(AOther.FNode.FAssetId));
  for I := 0 to High(LBoxes) do
  begin
    LBox := LBoxes[I];
    if (LBox.FY - LBox.FHeight / 2 >= 2.16) or
      (LBox.FY + LBox.FHeight / 2 <= 0) then
    begin
      Continue;
    end;
    LX := LBox.FX;
    LZ := LBox.FZ;
    if AOther.FVertical then
    begin
      LX := LBox.FZ;
      LZ := -LBox.FX;
    end;
    EdgeLocal(ADoor, AOther.FNode.FX / 1000 + LX,
      AOther.FNode.FZ / 1000 + LZ, LU, LV);
    LHalfU := LBox.FWidth / 2;
    LHalfV := LBox.FDepth / 2;
    if ADoor.FVertical <> AOther.FVertical then
    begin
      LHalfU := LBox.FDepth / 2;
      LHalfV := LBox.FWidth / 2;
    end;
    LMinU := Max(-0.62, LU - LHalfU);
    LMinV := Max(-0.1, LV - LHalfV);
    LMaxU := LU + LHalfU;
    LMaxV := LV + LHalfV;
    if (LMinU <= LMaxU) and (LMinV <= LMaxV) and
      (Sqr(EnsureRange(-0.59, LMinU, LMaxU) + 0.59) +
      Sqr(EnsureRange(0.0, LMinV, LMaxV)) < Sqr(1.26)) then
    begin
      Exit(True);
    end;
  end;
end;

function ModuleDoorSweepBlocks(const AEdge: TBuildingEdge; const AX, AZ, ARadius: Double): Boolean;
var
  LU: Double;
  LV: Double;
begin
  EdgeLocal(AEdge, AX, AZ, LU, LV);
  { Conservative quarter-disc contains the complete leaf sweep and handle.
    Interaction rejects a player inside this region instead of teleporting them. }
  Result := (LU >= -0.62 - ARadius) and (LV >= -0.1 - ARadius) and
    (Sqr(LU + 0.59) + Sqr(LV) < Sqr(1.26 + ARadius));
end;

end.
