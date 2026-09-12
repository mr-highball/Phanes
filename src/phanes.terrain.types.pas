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

unit phanes.terrain.types;

{$mode delphi}
{$H+}

interface

const
  TerrainFieldVersion = 1;
  TerrainMaximumVertices = 9409;
  TerrainMaximumCoordinateMm = 4096000;
  TerrainMaximumElevationMm = 512000;

type
  TTerrainLevels = array of Integer;
  TTerrainProtection = array of Boolean;

  { Nodes are shared vertices, not regional biome cells. Heights are integer
    levels times step millimetres. The anti-diagonal joins the +X and +Z
    corners of every square; this triangulation is part of version 1. }
  TTerrainSpec = record
    FVersion: Integer;
    FColumns: Integer;
    FRows: Integer;
    FOriginX: Integer;
    FOriginZ: Integer;
    FSpacing: Integer;
    FLevelStep: Integer;
    FMinimumLevel: Integer;
    FMaximumLevel: Integer;
    FMaximumRise: Integer;
  end;

  TTerrainField = record
    FSpec: TTerrainSpec;
    FSeed: Cardinal;
    FLevels: TTerrainLevels;
    FDecisions: Integer;
    FPropagations: Integer;
    FBacktracks: Integer;
  end;

  TTerrainDomain = record
    FMinimum: Integer;
    FMaximum: Integer;
  end;
  TTerrainDomains = array of TTerrainDomain;

  TTerrainRequest = record
    FSpec: TTerrainSpec;
    FSeed: Cardinal;
    FHasPrevious: Boolean;
    FPrevious: TTerrainField;
    { Cell rectangle. In repairs, its boundary vertices stay fixed as well
      as every vertex outside it. Thus no outside triangle changes height.
      A one-cell-wide strip has no editable interior vertices. }
    FX: Integer;
    FZ: Integer;
    FWidth: Integer;
    FDepth: Integer;
    { Nil means the full level interval at every vertex. A supplied array
      has exactly columns * rows entries, including preserved vertices. }
    FDomains: TTerrainDomains;
    FProtected: TTerrainProtection;
    FMaxBacktracks: Integer;
  end;

function SameTerrainSpec(const ALeft, ARight: TTerrainSpec): Boolean;
function SameTerrainField(const ALeft, ARight: TTerrainField): Boolean;
function CopyTerrainField(const AField: TTerrainField): TTerrainField;
function TerrainVertexPreserved(const ARequest: TTerrainRequest;
  const AX, AZ: Integer): Boolean;

implementation

function SameTerrainSpec(const ALeft, ARight: TTerrainSpec): Boolean;
begin
  Result := (ALeft.FVersion = ARight.FVersion) and
    (ALeft.FColumns = ARight.FColumns) and (ALeft.FRows = ARight.FRows) and
    (ALeft.FOriginX = ARight.FOriginX) and (ALeft.FOriginZ = ARight.FOriginZ) and
    (ALeft.FSpacing = ARight.FSpacing) and (ALeft.FLevelStep = ARight.FLevelStep) and
    (ALeft.FMinimumLevel = ARight.FMinimumLevel) and
    (ALeft.FMaximumLevel = ARight.FMaximumLevel) and
    (ALeft.FMaximumRise = ARight.FMaximumRise);
end;

function CopyTerrainField(const AField: TTerrainField): TTerrainField;
begin
  Result := AField;
  Result.FLevels := Copy(AField.FLevels, 0, Length(AField.FLevels));
end;

function SameTerrainField(const ALeft, ARight: TTerrainField): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not SameTerrainSpec(ALeft.FSpec, ARight.FSpec) or
    (ALeft.FSeed <> ARight.FSeed) or (ALeft.FDecisions <> ARight.FDecisions) or
    (ALeft.FPropagations <> ARight.FPropagations) or (ALeft.FBacktracks <> ARight.FBacktracks) or
    (Length(ALeft.FLevels) <> Length(ARight.FLevels)) then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft.FLevels) do
  begin
    if ALeft.FLevels[I] <> ARight.FLevels[I] then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function TerrainVertexPreserved(const ARequest: TTerrainRequest;
  const AX, AZ: Integer): Boolean;
begin
  { The caller first validates dimensions, selection and optional arrays. }
  Result := ARequest.FHasPrevious and
    ((AX <= ARequest.FX) or (AZ <= ARequest.FZ) or
    (AX >= ARequest.FX + ARequest.FWidth) or (AZ >= ARequest.FZ + ARequest.FDepth));
  if ARequest.FHasPrevious and (Length(ARequest.FProtected) > 0) then
  begin
    Result := Result or ARequest.FProtected[AZ * ARequest.FSpec.FColumns + AX];
  end;
end;

end.
