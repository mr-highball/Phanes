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
unit phanes.buildings.types;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.document,
  phanes.selection.grid;

const
  ModuleMetres = 2.0;
  ModuleMillimetres = 2000;
  ModuleWallMillimetres = 160;
  ModuleHeightMillimetres = 2800;
  ModuleMaximumFloors = 256;
  ModuleMaximumSide = 32;
  ModularBuildingAsset = 'phanes.building.modular.v1';

type
  TBuildingEdge = record
    FX: Integer;
    FZ: Integer;
    FVertical: Boolean;
    FNode: TCompositionNode;
  end;
  TBuildingEdges = array of TBuildingEdge;
  TModularBuilding = record
    FRoot: TCompositionNode;
    FSide: Integer;
    FFloors: TSelectionCells;
    FFloorNodes: TCompositionNodes;
    FEdges: TBuildingEdges;
    FFurnishings: TCompositionNodes;
  end;

function IsBuildingOperation(const AOperation: String): Boolean;
function ModularOwner(const ADocument: TCompositionDocument; const AIndex: TCompositionIndex;
  const ANode: Integer): String;
function ModuleFloorId(const ARoot: String; const AX, AZ: Integer): String;
function ModuleEdgeId(const ARoot: String; const AX, AZ: Integer; const AVertical: Boolean): String;
function ModuleToken(const AAsset: String): String;
function ModuleAsset(const AToken: String): String;
function ModuleIsFloor(const AToken: String): Boolean;
function ModuleIsEdge(const AToken: String): Boolean;
function ModuleIsPassage(const AToken: String): Boolean;
function ModuleIsDoor(const AToken: String): Boolean;
function ModuleIsWindow(const AToken: String): Boolean;
function ModuleFloorAt(const ABuilding: TModularBuilding; const AX, AZ: Integer): Boolean;
function ModuleEdgeAt(const ABuilding: TModularBuilding; const AX, AZ: Integer;
  const AVertical: Boolean): Integer;

implementation

uses
  SysUtils;

function IsBuildingOperation(const AOperation: String): Boolean;
begin
  Result := (AOperation = 'module-build') or (AOperation = 'module-extend') or
    (AOperation = 'module-populate') or
    (AOperation = 'module-edge') or (AOperation = 'module-toggle') or
    (AOperation = 'module-lock') or (AOperation = 'module-furnish') or
    (AOperation = 'module-remove');
end;

function ModularOwner(const ADocument: TCompositionDocument; const AIndex: TCompositionIndex;
  const ANode: Integer): String;
var
  LCurrent: Integer;
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
    if ADocument.FNodes[LCurrent].FAssetId = ModularBuildingAsset then
    begin
      Exit(ADocument.FNodes[LCurrent].FId);
    end;
    LCurrent := AIndex.Find(ADocument.FNodes[LCurrent].FParentId);
  end;
end;

function ModuleFloorId(const ARoot: String; const AX, AZ: Integer): String;
begin
  Result := ARoot + '.floor-' + IntToStr(AX) + '-' + IntToStr(AZ);
end;

function ModuleEdgeId(const ARoot: String; const AX, AZ: Integer; const AVertical: Boolean): String;
begin
  Result := ARoot + '.edge-h-';
  if AVertical then
  begin
    Result := ARoot + '.edge-v-';
  end;
  Result := Result + IntToStr(AX) + '-' + IntToStr(AZ);
end;

function ModuleToken(const AAsset: String): String;
begin
  Result := '';
  if (Copy(AAsset, 1, 14) = 'phanes.module.') and
    (Copy(AAsset, Length(AAsset) - 2, 3) = '.v1') then
  begin
    Result := Copy(AAsset, 15, Length(AAsset) - 17);
  end;
end;

function ModuleAsset(const AToken: String): String;
begin
  Result := 'phanes.module.' + AToken + '.v1';
end;

function ModuleIsFloor(const AToken: String): Boolean;
begin
  Result := (AToken = 'floor.oak') or (AToken = 'floor.stone');
end;

function ModuleIsDoor(const AToken: String): Boolean;
begin
  Result := (AToken = 'door.closed.plaster') or (AToken = 'door.closed.timber') or
    (AToken = 'door.open.plaster') or (AToken = 'door.open.timber');
end;

function ModuleIsWindow(const AToken: String): Boolean;
begin
  Result := (AToken = 'window.plaster') or (AToken = 'window.timber');
end;

function ModuleIsPassage(const AToken: String): Boolean;
begin
  Result := (AToken = 'opening') or ModuleIsDoor(AToken);
end;

function ModuleIsEdge(const AToken: String): Boolean;
begin
  Result := (AToken = 'wall.plaster') or (AToken = 'wall.timber') or
    (AToken = 'opening') or ModuleIsDoor(AToken) or ModuleIsWindow(AToken);
end;

function ModuleFloorAt(const ABuilding: TModularBuilding; const AX, AZ: Integer): Boolean;
begin
  Result := (AX >= 0) and (AZ >= 0) and (AX < ABuilding.FSide) and
    (AZ < ABuilding.FSide) and HasSelectionCell(ABuilding.FFloors, AZ * ABuilding.FSide + AX);
end;

function ModuleEdgeAt(const ABuilding: TModularBuilding; const AX, AZ: Integer;
  const AVertical: Boolean): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(ABuilding.FEdges) do
  begin
    if (ABuilding.FEdges[I].FX = AX) and (ABuilding.FEdges[I].FZ = AZ) and
      (ABuilding.FEdges[I].FVertical = AVertical) then
    begin
      Exit(I);
    end;
  end;
end;

end.
