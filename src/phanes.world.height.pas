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

unit phanes.world.height;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.terrain.surface;

type
  { A cached, immutable raw-height provider. Layered water/building/groundwork
    grading remains in the landscape and support adapters. }
  TWorldHeight = class
  private
    FSize: Integer;
    FSurface: TTerrainSurface;
    FRelative: Boolean;
  public
    constructor Create(const AWorld: TWorld);
    destructor Destroy; override;
    function HasField: Boolean;
    function Height(const AX, AZ: Double): Double;
    function BuildingDatum(const AX, AZ: Integer): Double;
    function DryBuildingDatum(const AX, AZ: Integer): Boolean;
    procedure Bounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
      out AMinimum, AMaximum: Double);
    procedure GradientBounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
      out AMaximumDX, AMaximumDZ: Double);
  end;

function ValidateWorldHeight(const AWorld: TWorld; out AReason: String): Boolean;
function WorldBuildingDatum(const AWorld: TWorld; const AX, AZ: Integer): Double;

implementation

uses
  SysUtils,
  phanes.terrain.types,
  phanes.terrain.validate,
  phanes.world.elevation;

function ValidateWorldHeight(const AWorld: TWorld; out AReason: String): Boolean;
begin
  Result := False;
  AReason := 'World height needs a world between four and forty-eight regional cells.';
  if (AWorld.FSize < 4) or (AWorld.FSize > 48) then
  begin
    Exit;
  end;
  if AWorld.FElevation.FSpec.FVersion = 0 then
  begin
    AReason := 'Legacy analytic terrain must have a completely empty elevation record.';
    Result := not AWorld.FRelativeElevation and
      SameTerrainField(AWorld.FElevation, Default(TTerrainField));
    if Result then
    begin
      AReason := '';
    end;
    Exit;
  end;
  if not ValidateTerrainField(AWorld.FElevation, AReason) then
  begin
    Exit;
  end;
  AReason := 'The world elevation frame must use an eight-metre grid over the complete world.';
  if (AWorld.FElevation.FSpec.FColumns <> AWorld.FSize * 2 + 1) or
    (AWorld.FElevation.FSpec.FRows <> AWorld.FSize * 2 + 1) or
    (AWorld.FElevation.FSpec.FSpacing <> 8000) or
    (AWorld.FElevation.FSpec.FOriginX <> -AWorld.FSize * 8000) or
    (AWorld.FElevation.FSpec.FOriginZ <> -AWorld.FSize * 8000) then
  begin
    Exit;
  end;
  AReason := '';
  Result := True;
end;

constructor TWorldHeight.Create(const AWorld: TWorld);
var
  LReason: String;
begin
  inherited Create;
  if not ValidateWorldHeight(AWorld, LReason) then
  begin
    raise EArgumentException.Create('Cannot construct world height: ' + LReason);
  end;
  FSize := AWorld.FSize;
  FRelative := AWorld.FRelativeElevation;
  if AWorld.FElevation.FSpec.FVersion <> 0 then
  begin
    FSurface := TTerrainSurface.Create(AWorld.FElevation);
  end;
end;

function WorldBuildingDatum(const AWorld: TWorld; const AX, AZ: Integer): Double;
var
  LHeight: TWorldHeight;
begin
  LHeight := TWorldHeight.Create(AWorld);
  try
    Result := LHeight.BuildingDatum(AX, AZ);
  finally
    LHeight.Free;
  end;
end;

destructor TWorldHeight.Destroy;
begin
  FSurface.Free;
  inherited Destroy;
end;

function TWorldHeight.HasField: Boolean;
begin
  Result := FSurface <> nil;
end;

function TWorldHeight.Height(const AX, AZ: Double): Double;
begin
  if FSurface <> nil then
  begin
    Result := FSurface.Height(AX, AZ);
    if FRelative then
    begin
      Result := Result + TerrainBaseHeight(AX, AZ);
    end;
    Exit;
  end;
  Result := TerrainBaseHeight(AX, AZ);
end;

function TWorldHeight.BuildingDatum(const AX, AZ: Integer): Double;
begin
  if (AX < 0) or (AZ < 0) or (AX >= FSize) or (AZ >= FSize) then
  begin
    raise EArgumentException.Create('Building datum cell must lie inside the world.');
  end;
  Result := Height((AX + 0.5 - FSize / 2) * 16, (AZ + 0.5 - FSize / 2) * 16);
end;

function TWorldHeight.DryBuildingDatum(const AX, AZ: Integer): Boolean;
begin
  Result := BuildingDatum(AX, AZ) >= WorldStandingMinimumMetres + 0.001;
end;

procedure TWorldHeight.Bounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMinimum, AMaximum: Double);
var
  LDX: Double;
  LDZ: Double;
  LBaseMinimum: Double;
  LBaseMaximum: Double;
begin
  if FSurface <> nil then
  begin
    FSurface.Bounds(AMinX, AMinZ, AMaxX, AMaxZ, AMinimum, AMaximum, LDX, LDZ);
    if FRelative then
    begin
      TerrainHeightBounds(AMinX, AMinZ, AMaxX, AMaxZ, LBaseMinimum, LBaseMaximum);
      AMinimum := AMinimum + LBaseMinimum;
      AMaximum := AMaximum + LBaseMaximum;
    end;
  end
  else
  begin
    TerrainHeightBounds(AMinX, AMinZ, AMaxX, AMaxZ, AMinimum, AMaximum);
  end;
end;

procedure TWorldHeight.GradientBounds(const AMinX, AMinZ, AMaxX, AMaxZ: Double;
  out AMaximumDX, AMaximumDZ: Double);
var
  LMinimum: Double;
  LMaximum: Double;
begin
  if FSurface <> nil then
  begin
    FSurface.Bounds(AMinX, AMinZ, AMaxX, AMaxZ, LMinimum, LMaximum, AMaximumDX, AMaximumDZ);
    if FRelative then
    begin
      AMaximumDX := AMaximumDX + 0.1477;
      AMaximumDZ := AMaximumDZ + 0.1305;
    end;
  end
  else
  begin
    TerrainHeightBounds(AMinX, AMinZ, AMaxX, AMaxZ, LMinimum, LMaximum);
    AMaximumDX := 0.1477;
    AMaximumDZ := 0.1305;
  end;
end;

end.
