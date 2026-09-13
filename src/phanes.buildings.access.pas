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

unit phanes.buildings.access;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateBuildingAccess(const AWorld: TWorld; out AReason: String): Boolean;

implementation

uses
  Math, SysUtils, phanes.composition.types, phanes.buildings.types,
  phanes.buildings.validate, phanes.world.landscape;

function WalkableFloorConnected(const AWorld: TWorld; const ABuilding: TModularBuilding;
  const ALandscape: TLandscape; const AStartX, AStartZ: Double): Boolean;
var
  LMinX: Double;
  LMinZ: Double;
  LMaxX: Double;
  LMaxZ: Double;
  LX: Double;
  LZ: Double;
  LDistance: Double;
  LBest: Double;
  LWidth: Integer;
  LDepth: Integer;
  LStart: Integer;
  LAt: Integer;
  LNext: Integer;
  LHead: Integer;
  LTail: Integer;
  LCount: Integer;
  LFree: array of Boolean;
  LSeen: array of Boolean;
  LQueue: array of Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LMinX := 1E20;
  LMinZ := 1E20;
  LMaxX := -1E20;
  LMaxZ := -1E20;
  for I := 0 to High(ABuilding.FFloorNodes) do
  begin
    LMinX := Min(LMinX, ABuilding.FFloorNodes[I].FX / 1000 - 1);
    LMinZ := Min(LMinZ, ABuilding.FFloorNodes[I].FZ / 1000 - 1);
    LMaxX := Max(LMaxX, ABuilding.FFloorNodes[I].FX / 1000 + 1);
    LMaxZ := Max(LMaxZ, ABuilding.FFloorNodes[I].FZ / 1000 + 1);
  end;
  LWidth := Round((LMaxX - LMinX) * 4);
  LDepth := Round((LMaxZ - LMinZ) * 4);
  SetLength(LFree, LWidth * LDepth);
  SetLength(LSeen, Length(LFree));
  SetLength(LQueue, Length(LFree));
  LStart := -1;
  LBest := 1E20;
  LCount := 0;
  for J := 0 to LDepth - 1 do
  begin
    for I := 0 to LWidth - 1 do
    begin
      LX := LMinX + (I + 0.5) / 4;
      LZ := LMinZ + (J + 0.5) / 4;
      if not ModuleFloorAt(ABuilding, Floor((LX + AWorld.FSize * 8) / 2),
        Floor((LZ + AWorld.FSize * 8) / 2)) then
      begin
        Continue;
      end;
      LAt := J * LWidth + I;
      LFree[LAt] := ALandscape.CanStand(LX, LZ);
      if LFree[LAt] then
      begin
        Inc(LCount);
        LDistance := Sqr(LX - AStartX) + Sqr(LZ - AStartZ);
        if LDistance < LBest then
        begin
          LBest := LDistance;
          LStart := LAt;
        end;
      end;
    end;
  end;
  if LStart < 0 then
  begin
    Exit(False);
  end;
  LQueue[0] := LStart;
  LSeen[LStart] := True;
  LHead := 0;
  LTail := 1;
  while LHead < LTail do
  begin
    LAt := LQueue[LHead];
    Inc(LHead);
    for K := 0 to 3 do
    begin
      I := LAt mod LWidth;
      J := LAt div LWidth;
      case K of
        0:
        begin
          Dec(I);
        end;
        1:
        begin
          Inc(I);
        end;
        2:
        begin
          Dec(J);
        end;
        3:
        begin
          Inc(J);
        end;
      end;
      if (I < 0) or (J < 0) or (I >= LWidth) or (J >= LDepth) then
      begin
        Continue;
      end;
      LNext := J * LWidth + I;
      if LFree[LNext] and not LSeen[LNext] then
      begin
        LSeen[LNext] := True;
        LQueue[LTail] := LNext;
        Inc(LTail);
      end;
    end;
  end;
  Result := LTail = LCount;
end;

function ValidateBuildingAccess(const AWorld: TWorld; out AReason: String): Boolean;
var
  LTest: TWorld;
  LLandscape: TLandscape;
  LBuilding: TModularBuilding;
  LEdge: TBuildingEdge;
  LToken: String;
  LFirst: Boolean;
  LSecond: Boolean;
  LUsable: Boolean;
  LRoute: Boolean;
  LNX: Double;
  LNZ: Double;
  LX: Double;
  LZ: Double;
  LPreviousX: Double;
  LPreviousZ: Double;
  LDelta: Double;
  LAllowance: Double;
  LDistance: Double;
  LOffset: Double;
  I: Integer;
  J: Integer;
  K: Integer;
  LSample: Integer;
begin
  Result := False;
  { Test architectural access with operable doors open, without changing the
    document. Closed doors remain intentional, interactive collision barriers
    in the live world. The independent check uses the same physical geometry
    and terrain provider as walking, not the WFC connectivity metadata. }
  LTest := AWorld;
  LTest.FComposition := CopyDocument(AWorld.FComposition);
  for I := 0 to High(LTest.FComposition.FNodes) do
  begin
    LToken := ModuleToken(LTest.FComposition.FNodes[I].FAssetId);
    if Pos('door.closed.', LToken) = 1 then
    begin
      LTest.FComposition.FNodes[I].FAssetId := ModuleAsset(
        StringReplace(LToken, 'door.closed.', 'door.open.', []));
    end;
  end;
  LLandscape := TLandscape.Create;
  try
    try
      LLandscape.SetWorld(LTest);
    except
      on LException: Exception do
      begin
        AReason := 'This footprint conflicts with an existing foundation: ' + LException.Message;
        Exit;
      end;
    end;
    for I := 0 to High(LTest.FComposition.FNodes) do
    begin
      if LTest.FComposition.FNodes[I].FAssetId <> ModularBuildingAsset then
      begin
        Continue;
      end;
      if not ReadModularBuilding(LTest, LTest.FComposition.FNodes[I].FId, LBuilding, AReason) then
      begin
        Exit;
      end;
      LUsable := False;
      for J := 0 to High(LBuilding.FEdges) do
      begin
        LEdge := LBuilding.FEdges[J];
        if not ModuleIsPassage(ModuleToken(LEdge.FNode.FAssetId)) then
        begin
          Continue;
        end;
        LFirst := ModuleFloorAt(LBuilding, LEdge.FX, LEdge.FZ);
        LSecond := ModuleFloorAt(LBuilding, LEdge.FX - Ord(LEdge.FVertical),
          LEdge.FZ - Ord(not LEdge.FVertical));
        if LFirst = LSecond then
        begin
          Continue;
        end;
        LNX := Ord(LEdge.FVertical);
        LNZ := Ord(not LEdge.FVertical);
        if LFirst then
        begin
          LNX := -LNX;
          LNZ := -LNZ;
        end;
        LRoute := True;
        { Check the doorway and a two-metre landing. Players can turn after
          leaving a house; demanding a six-metre straight corridor rejects
          usable entrances beside other buildings or on concave footprints.
          Retain collision, slope and the explicit slab threshold checks. }
        for K := -1 to 1 do
        begin
          LOffset := K * 0.10;
          LPreviousX := LEdge.FNode.FX / 1000 - LNX + LNZ * LOffset;
          LPreviousZ := LEdge.FNode.FZ / 1000 - LNZ - LNX * LOffset;
          for LSample := 0 to 30 do
          begin
            LDistance := -1 + LSample * 0.1;
            LX := LEdge.FNode.FX / 1000 + LNX * LDistance + LNZ * LOffset;
            LZ := LEdge.FNode.FZ / 1000 + LNZ * LDistance - LNX * LOffset;
            if not LLandscape.CanStand(LX, LZ) then
            begin
              LRoute := False;
              Break;
            end;
            LAllowance := 0.080;
            if (LLandscape.Modular.At(LX, LZ) >= 0) <>
              (LLandscape.Modular.At(LPreviousX, LPreviousZ) >= 0) then
            begin
              LAllowance := 0.18;
            end;
            LDelta := Abs(LLandscape.Height(LX, LZ) -
              LLandscape.Height(LPreviousX, LPreviousZ));
            if LDelta > LAllowance then
            begin
              LRoute := False;
              Break;
            end;
            LPreviousX := LX;
            LPreviousZ := LZ;
          end;
          if not LRoute then
          begin
            Break;
          end;
        end;
        if LRoute then
        begin
          LUsable := True;
          Break;
        end;
      end;
      if not LUsable then
      begin
        AReason := 'This home needs a clear, gently sloping entrance to the surrounding land. ' +
          'Choose a door on another side, or a gentler footprint.';
        Exit;
      end;
      if not WalkableFloorConnected(LTest, LBuilding, LLandscape,
        LEdge.FNode.FX / 1000 - LNX, LEdge.FNode.FZ / 1000 - LNZ) then
      begin
        AReason := 'Furniture or a door would cut off part of this home. ' +
          'Leave a walking route through the rooms.';
        Exit;
      end;
    end;
    AReason := '';
    Result := True;
  finally
    LLandscape.Free;
  end;
end;

end.
