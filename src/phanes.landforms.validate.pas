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

unit phanes.landforms.validate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateLandformEdit(const ARequest: TWorldRequest; const AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  Math, phanes.world.validate, phanes.world.selection, phanes.landforms.types,
  phanes.terrain.types, phanes.composition.types, phanes.world.landscape,
  phanes.world.elevation;

function SameValues(const ALeft, ARight: TStringArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(ALeft) <> Length(ARight) then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft) do
  begin
    if ALeft[I] <> ARight[I] then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function Roughness(const AField: TTerrainField): Integer;
var
  LSide: Integer;
  I: Integer;
begin
  Result := 0;
  LSide := AField.FSpec.FColumns;
  for I := 0 to High(AField.FLevels) do
  begin
    if I mod LSide > 0 then
    begin
      Inc(Result, Sqr(AField.FLevels[I] - AField.FLevels[I - 1]));
    end;
    if I >= LSide then
    begin
      Inc(Result, Sqr(AField.FLevels[I] - AField.FLevels[I - LSide]));
    end;
  end;
end;

function ValidateLandformEdit(const ARequest: TWorldRequest; const AWorld: TWorld;
  out AReason: String): Boolean;
var
  LAllowed: array of Boolean;
  LSide: Integer;
  LCell: Integer;
  LX: Integer;
  LZ: Integer;
  LVertexX: Integer;
  LVertexZ: Integer;
  LOld: Integer;
  LChange: Integer;
  LScale: Integer;
  LChanged: Boolean;
  LWorldX: Double;
  LWorldZ: Double;
  LCenterX: Double;
  LCenterZ: Double;
  LRadius: Double;
  LStep: Integer;
  LMean: Integer;
  LBefore: TLandscape;
  LAfter: TLandscape;
  LCount: Integer;
  LOldHeight: Double;
  LNewHeight: Double;
  LPointX: Double;
  LPointZ: Double;
  K: Integer;
  LNode: TCompositionNode;
  I: Integer;
  J: Integer;

  function Touches(const AX, AZ, ARadius: Double): Boolean;
  begin
    { A changed vertex affects its incident triangles, spanning at most eight
      metres in either direction. Boundary-only contact has zero influence. }
    Result := (LWorldX - 8 < AX + ARadius) and (LWorldX + 8 > AX - ARadius) and
      (LWorldZ - 8 < AZ + ARadius) and (LWorldZ + 8 > AZ - ARadius);
  end;

begin
  Result := False;
  AReason := 'Terrain admission requires an in-world selection and a supported height amount.';
  if (ARequest.FSize <> ARequest.FPrevious.FSize) or
    (ARequest.FEditLayer <> 'terrain') or (ARequest.FLandformAmount < 1) or
    (ARequest.FLandformAmount > 8000) or
    (ARequest.FX < 0) or (ARequest.FZ < 0) or (ARequest.FWidth < 1) or
    (ARequest.FDepth < 1) or (ARequest.FWidth > ARequest.FSize) or
    (ARequest.FDepth > ARequest.FSize) or
    (ARequest.FX > ARequest.FSize - ARequest.FWidth) or
    (ARequest.FZ > ARequest.FSize - ARequest.FDepth) then
  begin
    Exit;
  end;
  if not IsLandformOperation(ARequest.FOperation) or
    not ValidateSelection(ARequest, AReason) or
    not ValidateWorld(ARequest.FPrevious, ARequest.FAssets, AReason) or
    not ValidateWorld(AWorld, ARequest.FAssets, AReason) then
  begin
    Exit;
  end;
  LStep := 250;
  if ARequest.FPrevious.FElevation.FSpec.FVersion <> 0 then
  begin
    LStep := ARequest.FPrevious.FElevation.FSpec.FLevelStep;
  end;
  AReason := 'The height amount must align with the saved elevation levels.';
  if ARequest.FLandformAmount mod LStep <> 0 then
  begin
    Exit;
  end;
  AReason := 'Terrain shaping changed unrelated world data.';
  if (AWorld.FSize <> ARequest.FPrevious.FSize) or
    (AWorld.FAppearanceSeed <> ARequest.FPrevious.FAppearanceSeed) or
    (AWorld.FComposition.FRevision <> ARequest.FPrevious.FComposition.FRevision) or
    (Length(AWorld.FComposition.FNodes) <> Length(ARequest.FPrevious.FComposition.FNodes)) or
    (Length(AWorld.FRooms) <> Length(ARequest.FPrevious.FRooms)) then
  begin
    Exit;
  end;
  for I := 0 to 4 do
  begin
    if not SameValues(AWorld.FLayers[I], ARequest.FPrevious.FLayers[I]) then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(AWorld.FComposition.FNodes) do
  begin
    if not SameNode(AWorld.FComposition.FNodes[I], ARequest.FPrevious.FComposition.FNodes[I]) then
    begin
      Exit;
    end;
  end;
  for I := 0 to High(AWorld.FRooms) do
  begin
    if (AWorld.FRooms[I].FParent <> ARequest.FPrevious.FRooms[I].FParent) or
      (AWorld.FRooms[I].FSeed <> ARequest.FPrevious.FRooms[I].FSeed) or
      not SameValues(AWorld.FRooms[I].FFurniture, ARequest.FPrevious.FRooms[I].FFurniture) or
      not SameValues(AWorld.FRooms[I].FLooks, ARequest.FPrevious.FRooms[I].FLooks) or
      not SameValues(AWorld.FRooms[I].FTableware, ARequest.FPrevious.FRooms[I].FTableware) then
    begin
      Exit;
    end;
  end;
  AReason := 'Terrain shaping changed the saved height contract.';
  if ARequest.FPrevious.FElevation.FSpec.FVersion <> 0 then
  begin
    if not SameTerrainSpec(AWorld.FElevation.FSpec, ARequest.FPrevious.FElevation.FSpec) or
      (AWorld.FRelativeElevation <> ARequest.FPrevious.FRelativeElevation) then
    begin
      Exit;
    end;
  end
  else if AWorld.FElevation.FSpec.FVersion <> 0 then
  begin
    if not AWorld.FRelativeElevation or (AWorld.FElevation.FSpec.FLevelStep <> 250) or
      (AWorld.FElevation.FSpec.FMinimumLevel <> -32) or
      (AWorld.FElevation.FSpec.FMaximumLevel <> 32) or
      (AWorld.FElevation.FSpec.FMaximumRise <> 4) then
    begin
      Exit;
    end;
  end;
  LSide := AWorld.FSize * 2;
  SetLength(LAllowed, Sqr(LSide));
  { Decode the cell mask independently of the generator's PaintedCell helper. }
  if ARequest.FSelectionScale = 0 then
  begin
    for LZ := ARequest.FZ * 2 to (ARequest.FZ + ARequest.FDepth) * 2 - 1 do
    begin
      for LX := ARequest.FX * 2 to (ARequest.FX + ARequest.FWidth) * 2 - 1 do
      begin
        LAllowed[LZ * LSide + LX] := True;
      end;
    end;
  end
  else
  begin
    LScale := ARequest.FSelectionScale;
    for I := 0 to High(ARequest.FSelectionCells) do
    begin
      LCell := ARequest.FSelectionCells[I];
      for LZ := (LCell div (AWorld.FSize * LScale)) * (2 div LScale) to
        (LCell div (AWorld.FSize * LScale) + 1) * (2 div LScale) - 1 do
      begin
        for LX := (LCell mod (AWorld.FSize * LScale)) * (2 div LScale) to
          (LCell mod (AWorld.FSize * LScale) + 1) * (2 div LScale) - 1 do
        begin
          LAllowed[LZ * LSide + LX] := True;
        end;
      end;
    end;
  end;
  LChanged := False;
  for I := 0 to High(AWorld.FElevation.FLevels) do
  begin
    LOld := 0;
    if ARequest.FPrevious.FElevation.FSpec.FVersion <> 0 then
    begin
      LOld := ARequest.FPrevious.FElevation.FLevels[I];
    end;
    LChange := AWorld.FElevation.FLevels[I] - LOld;
    if LChange = 0 then
    begin
      Continue;
    end;
    LChanged := True;
    AReason := 'A terrain result exceeded its requested amount or direction.';
    if (Abs(LChange) * AWorld.FElevation.FSpec.FLevelStep > ARequest.FLandformAmount) or
      ((ARequest.FOperation = 'land-raise') and (LChange < 0)) or
      ((ARequest.FOperation = 'land-lower') and (LChange > 0)) then
    begin
      Exit;
    end;
    LVertexX := I mod (LSide + 1);
    LVertexZ := I div (LSide + 1);
    AReason := 'A terrain result changed the selection boundary or an outside triangle.';
    if (LVertexX = 0) or (LVertexZ = 0) or (LVertexX = LSide) or (LVertexZ = LSide) then
    begin
      Exit;
    end;
    AReason := 'Terrain shaping must preserve the sea-facing edge of the world.';
    if (LVertexX <= 1) or (LVertexZ <= 1) or
      (LVertexX >= LSide - 1) or (LVertexZ >= LSide - 1) then
    begin
      Exit;
    end;
    if ARequest.FOperation = 'land-soften' then
    begin
      LMean := 0;
      if ARequest.FPrevious.FElevation.FSpec.FVersion <> 0 then
      begin
        LMean := Round((LOld * 2 + ARequest.FPrevious.FElevation.FLevels[I - 1] +
          ARequest.FPrevious.FElevation.FLevels[I + 1] +
          ARequest.FPrevious.FElevation.FLevels[I - LSide - 1] +
          ARequest.FPrevious.FElevation.FLevels[I + LSide + 1]) / 6);
      end;
      AReason := 'Soften moved a height beyond its previous neighborhood mean.';
      if (AWorld.FElevation.FLevels[I] < Min(LOld, LMean)) or
        (AWorld.FElevation.FLevels[I] > Max(LOld, LMean)) then
      begin
        Exit;
      end;
    end;
    for LZ := LVertexZ - 1 to LVertexZ do
    begin
      for LX := LVertexX - 1 to LVertexX do
      begin
        if not LAllowed[LZ * LSide + LX] then
        begin
          Exit;
        end;
      end;
    end;
    LWorldX := LVertexX * 8 - AWorld.FSize * 8;
    LWorldZ := LVertexZ * 8 - AWorld.FSize * 8;
    AReason := 'A terrain result changed water or land supporting existing construction.';
    for J := 0 to High(AWorld.FLayers[0]) do
    begin
      LRadius := 0;
      if AWorld.FLayers[0][J] = 'water' then
      begin
        LRadius := 8;
      end
      else if AWorld.FLayers[3][J] <> 'empty' then
      begin
        LRadius := 8;
      end;
      LCenterX := (J mod AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      LCenterZ := (J div AWorld.FSize + 0.5 - AWorld.FSize / 2) * 16;
      if (LRadius > 0) and Touches(LCenterX, LCenterZ, LRadius) then
      begin
        Exit;
      end;
    end;
    for J := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LNode := AWorld.FComposition.FNodes[J];
      if (LNode.FId = 'world') and LNode.FLocked then
      begin
        Exit;
      end;
      LRadius := 0;
      if (LNode.FRole = 'plot') and (LNode.FParentId = 'world') then
      begin
        LRadius := 16.5;
      end
      else if LNode.FRole = 'floor-tile' then
      begin
        LRadius := 9;
      end;
      if (LRadius > 0) and Touches(LNode.FX / 1000, LNode.FZ / 1000, LRadius) then
      begin
        Exit;
      end;
    end;
  end;
  if not LChanged then
  begin
    AReason := 'Raise or Lower must change at least one selected height.';
    if (ARequest.FOperation = 'land-raise') or (ARequest.FOperation = 'land-lower') then
    begin
      Exit;
    end;
    AReason := 'An unchanged terrain edit must retain the complete previous world contract.';
    if not SameTerrainField(AWorld.FElevation, ARequest.FPrevious.FElevation) or
      (AWorld.FRelativeElevation <> ARequest.FPrevious.FRelativeElevation) or
      (AWorld.FSeed <> ARequest.FPrevious.FSeed) or
      (AWorld.FDecisions <> ARequest.FPrevious.FDecisions) or
      (AWorld.FPropagations <> ARequest.FPrevious.FPropagations) or
      (AWorld.FBacktracks <> ARequest.FPrevious.FBacktracks) then
    begin
      Exit;
    end;
  end
  else
  begin
    AReason := 'Changed terrain must identify this request.';
    if (AWorld.FSeed <> ARequest.FSeed) or (AWorld.FElevation.FSeed <> ARequest.FSeed) then
    begin
      Exit;
    end;
    AReason := 'Terrain world counters must match the admitted height solve.';
    if (AWorld.FDecisions <> AWorld.FElevation.FDecisions) or
      (AWorld.FPropagations <> AWorld.FElevation.FPropagations) or
      (AWorld.FBacktracks <> AWorld.FElevation.FBacktracks) then
    begin
      Exit;
    end;
  end;
  AReason := 'Soften must not increase the saved height field roughness.';
  if (ARequest.FOperation = 'land-soften') and
    (Roughness(AWorld.FElevation) > Roughness(ARequest.FPrevious.FElevation)) then
  begin
    Exit;
  end;
  LBefore := TLandscape.Create;
  LAfter := TLandscape.Create;
  try
    LBefore.SetWorld(ARequest.FPrevious);
    LAfter.SetWorld(AWorld);
    for I := 0 to High(AWorld.FLayers[2]) do
    begin
      if (AWorld.FLayers[2][I] = 'empty') or (AWorld.FLayers[2][I] = 'rock') then
      begin
        Continue;
      end;
      LCount := 1;
      for J := 0 to High(ARequest.FAssets) do
      begin
        if ARequest.FAssets[J].FId = AWorld.FLayers[4][I] then
        begin
          LCount := Max(1, ARequest.FAssets[J].FCluster);
          Break;
        end;
      end;
      AReason := 'The retained foliage cluster has no supported placement profile.';
      if LCount > 9 then
      begin
        Exit;
      end;
      LCenterX := (I mod LSide + 0.5 - LSide / 2) * 8;
      LCenterZ := (I div LSide + 0.5 - LSide / 2) * 8;
      for K := 0 to LCount - 1 do
      begin
        LPointX := LCenterX;
        LPointZ := LCenterZ;
        if LCount > 1 then
        begin
          LPointX := LPointX + (K mod 3 - 1) * 1.6 + Sin(I + K * 7) * 0.4;
          LPointZ := LPointZ + (K div 3 - 1) * 1.6 + Cos(I * 3 + K) * 0.4;
        end;
        LOldHeight := LBefore.Height(LPointX, LPointZ);
        LNewHeight := LAfter.Height(LPointX, LPointZ);
        AReason := 'This edit would submerge retained plants. Raise the land or choose a different region.';
        if LNewHeight < Min(WorldStandingMinimumMetres, LOldHeight) - 0.0000001 then
        begin
          Exit;
        end;
      end;
    end;
  finally
    LAfter.Free;
    LBefore.Free;
  end;
  AReason := '';
  Result := True;
end;

end.
