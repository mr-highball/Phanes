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
unit phanes.spaces.floor.types;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.contents.types;

type
  { Asset bounds are upright, centred in X/Z and grounded at Y=0, in mm.
    FrontQuarterTurn describes the actual operating face in that same frame.
    A console may need an approach but provide no flat content support. }
  TFloorAsset = record
    FContent: TContentAsset;
    FAllowedTurns: Integer;
    FFrontQuarterTurn: Integer;
    FNeedsApproach: Boolean;
    FRequiredServices: TContentNames;
  end;
  TFloorAssets = array of TFloorAsset;

  TFloorPlacement = record
    FId: String;
    FAssetId: String;
    FCellX: Integer;
    FCellZ: Integer;
    FQuarterTurn: Integer;
  end;
  TFloorPlacements = array of TFloorPlacement;
  TFloorFreeCells = array of Boolean;

  { One local rectangular room, with a doorway in its +Z wall.
    The lattice reserves complete fixture footprints. Its free-cell centre
    paths are wide enough for the specified player; contents use independent
    finer local support graphs, not this floor resolution. }
  TFloorRequest = record
    FScopeId: String;
    FSeed: Cardinal;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FPitch: Integer;
    FPlayerRadius: Integer;
    FDoorX: Integer;
    FDoorWidth: Integer;
    FServices: TContentNames;
    FAssets: TFloorAssets;
    FQuotas: TContentQuotas;
    { Callers include every object that must retain its pose, identity and
      appearance, including furniture with protected or occupied descendants. }
    FFixed: TFloorPlacements;
    { These identities belong to preserved document nodes or their namespaces.
      Existing FFixed instances may retain them; newly created fixtures may not. }
    FUnavailableNewIds: TContentNames;
    FMaxBacktracks: Integer;
  end;

  TFloorLayout = record
    FPlacements: TFloorPlacements;
    FFreeCells: TFloorFreeCells;
    FDecisions: Integer;
    FPropagations: Integer;
    FBacktracks: Integer;
  end;

  TFloorRectangle = record
    FMinX: Double;
    FMinZ: Double;
    FMaxX: Double;
    FMaxZ: Double;
  end;

function FloorAssetIndex(const AAssets: TFloorAssets; const AId: String): Integer;
function FloorAssetAvailable(const ARequest: TFloorRequest; const AIndex: Integer): Boolean;
procedure FloorSpan(const ARequest: TFloorRequest; const AAsset: TFloorAsset;
  const ATurn: Integer; out AColumns, ARows: Integer);
procedure FloorPose(const ARequest: TFloorRequest; const APlacement: TFloorPlacement;
  const AAsset: TFloorAsset; out AX, AZ: Integer);
function FloorBounds(const ARequest: TFloorRequest; const APlacement: TFloorPlacement;
  const AAsset: TFloorAsset): TFloorRectangle;
procedure FloorApproachCell(const ARequest: TFloorRequest;
  const APlacement: TFloorPlacement; const AAsset: TFloorAsset; out AX, AZ: Integer);
procedure FloorEntryCell(const ARequest: TFloorRequest; out AX, AZ: Integer);

implementation

uses
  Math;

function FloorAssetIndex(const AAssets: TFloorAssets; const AId: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AAssets) do
  begin
    if AAssets[I].FContent.FId = AId then
    begin
      Exit(I);
    end;
  end;
  Result := -1;
end;

function FloorAssetAvailable(const ARequest: TFloorRequest; const AIndex: Integer): Boolean;
var
  LService: String;
begin
  Result := ARequest.FAssets[AIndex].FContent.FHeight <= ARequest.FHeight;
  for LService in ARequest.FAssets[AIndex].FRequiredServices do
  begin
    Result := Result and ContentRoleAllowed(ARequest.FServices, LService);
  end;
end;

procedure FloorSpan(const ARequest: TFloorRequest; const AAsset: TFloorAsset;
  const ATurn: Integer; out AColumns, ARows: Integer);
begin
  AColumns := (AAsset.FContent.FWidth + ARequest.FPitch - 1) div ARequest.FPitch;
  ARows := (AAsset.FContent.FDepth + ARequest.FPitch - 1) div ARequest.FPitch;
  if Odd(ATurn) then
  begin
    AColumns := (AAsset.FContent.FDepth + ARequest.FPitch - 1) div ARequest.FPitch;
    ARows := (AAsset.FContent.FWidth + ARequest.FPitch - 1) div ARequest.FPitch;
  end;
end;

procedure FloorPose(const ARequest: TFloorRequest; const APlacement: TFloorPlacement;
  const AAsset: TFloorAsset; out AX, AZ: Integer);
var
  LColumns: Integer;
  LRows: Integer;
begin
  FloorSpan(ARequest, AAsset, APlacement.FQuarterTurn, LColumns, LRows);
  AX := -(ARequest.FWidth div ARequest.FPitch) * (ARequest.FPitch div 2) +
    APlacement.FCellX * ARequest.FPitch + LColumns * (ARequest.FPitch div 2);
  AZ := -(ARequest.FDepth div ARequest.FPitch) * (ARequest.FPitch div 2) +
    APlacement.FCellZ * ARequest.FPitch + LRows * (ARequest.FPitch div 2);
end;

function FloorBounds(const ARequest: TFloorRequest; const APlacement: TFloorPlacement;
  const AAsset: TFloorAsset): TFloorRectangle;
var
  LX: Integer;
  LZ: Integer;
  LWidth: Integer;
  LDepth: Integer;
begin
  FloorPose(ARequest, APlacement, AAsset, LX, LZ);
  LWidth := AAsset.FContent.FWidth;
  LDepth := AAsset.FContent.FDepth;
  if Odd(APlacement.FQuarterTurn) then
  begin
    LWidth := AAsset.FContent.FDepth;
    LDepth := AAsset.FContent.FWidth;
  end;
  Result.FMinX := LX - LWidth / 2;
  Result.FMaxX := LX + LWidth / 2;
  Result.FMinZ := LZ - LDepth / 2;
  Result.FMaxZ := LZ + LDepth / 2;
end;

procedure FloorApproachCell(const ARequest: TFloorRequest;
  const APlacement: TFloorPlacement; const AAsset: TFloorAsset; out AX, AZ: Integer);
var
  LColumns: Integer;
  LRows: Integer;
begin
  FloorSpan(ARequest, AAsset, APlacement.FQuarterTurn, LColumns, LRows);
  AX := APlacement.FCellX + (LColumns - 1) div 2;
  AZ := APlacement.FCellZ + (LRows - 1) div 2;
  case (APlacement.FQuarterTurn + AAsset.FFrontQuarterTurn) mod 4 of
    0:
    begin
      AZ := APlacement.FCellZ + LRows;
    end;
    1:
    begin
      AX := APlacement.FCellX + LColumns;
    end;
    2:
    begin
      AZ := APlacement.FCellZ - 1;
    end;
    3:
    begin
      AX := APlacement.FCellX - 1;
    end;
  end;
end;

procedure FloorEntryCell(const ARequest: TFloorRequest; out AX, AZ: Integer);
var
  LColumns: Integer;
begin
  LColumns := ARequest.FWidth div ARequest.FPitch;
  AX := EnsureRange(Floor(ARequest.FDoorX / ARequest.FPitch + LColumns / 2),
    0, LColumns - 1);
  AZ := ARequest.FDepth div ARequest.FPitch - 1;
end;

end.
