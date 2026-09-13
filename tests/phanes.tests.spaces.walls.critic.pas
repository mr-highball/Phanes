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

unit phanes.tests.spaces.walls.critic;
{$mode delphi}
{$H+}

interface

function RunSpaceWallCriticChecks: Integer;

implementation

uses
  SysUtils,
  Math,
  phanes.composition.types,
  phanes.spaces.plans,
  phanes.spaces.geometry;
var
  GChecks: Integer;
procedure Check(const AOkay: Boolean; const ACase: String);
begin
  Inc(GChecks);
  if not AOkay then
  begin
    raise Exception.Create(ACase);
  end;
end;
function AnyWall(const AWalls: TSpaceWalls; const AX, AZ, AHeight: Double): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AWalls) do
  begin
    if SpaceWallBlocks(AWalls[I], AX, AZ, 280, AHeight) then
    begin
      Exit(True);
    end;
  end;
end;
function DistanceToRectangle(const AWall: TSpaceWall; const AX, AZ: Double): Double;
var
  LX: Double;
  LZ: Double;
begin
  LX := AX;
  LZ := AZ;
  if LX < AWall.FMinX then
  begin
    LX := AWall.FMinX;
  end;
  if LX > AWall.FMaxX then
  begin
    LX := AWall.FMaxX;
  end;
  if LZ < AWall.FMinZ then
  begin
    LZ := AWall.FMinZ;
  end;
  if LZ > AWall.FMaxZ then
  begin
    LZ := AWall.FMaxZ;
  end;
  Result := Hypot(AX - LX, AZ - LZ);
end;
procedure Run;
const
  CProfiles: array[0..2] of String = (CabinTwoBays, CabinFourBays, CabinSixBays);
  CCenters: array[0..2,0..2] of Integer = ((0,0,0),(-2325,2325,0),(-3100,0,3100));
var
  LPlan: TCompositionNode;
  LWalls: TSpaceWalls;
  LWall: TSpaceWall;
  LExpected: Boolean;
  LHeight: Double;
  LX: Double;
  LZ: Double;
  LProfile: Integer;
  LRow: Integer;
  LSide: Integer;
  LSample: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LPlan := Default(TCompositionNode);
  for LProfile := 0 to 2 do
  begin
    LPlan.FAssetId := CProfiles[LProfile];
    LWalls := CabinPlanWalls(LPlan);
    Check(Length(LWalls) = 12 + 6 * LProfile, 'complete wall/header count');
    for I := 0 to High(LWalls) do
    begin
      LWall := LWalls[I];
      Check((LWall.FMinX < LWall.FMaxX) and (LWall.FMinZ < LWall.FMaxZ) and
        (LWall.FBottom < LWall.FTop), 'positive wall volume');
      for J := -2 to 2 do
      begin
        for K := -2 to 2 do
        begin
          LX := (LWall.FMinX + LWall.FMaxX) / 2 +
            J * ((LWall.FMaxX - LWall.FMinX) / 4 + 140);
          LZ := (LWall.FMinZ + LWall.FMaxZ) / 2 +
            K * ((LWall.FMaxZ - LWall.FMinZ) / 4 + 140);
          for LSample := 0 to 2 do
          begin
            LHeight := 1850;
            if LSample = 1 then
            begin
              LHeight := 2200;
            end;
            if LSample = 2 then
            begin
              LHeight := 2200.5;
            end;
            LExpected := (LWall.FBottom < LHeight) and (LWall.FTop > 0) and
              (DistanceToRectangle(LWall, LX, LZ) < 280);
            Check(SpaceWallBlocks(LWall, LX, LZ, 280, LHeight) = LExpected,
              'finite-height circle distance independent oracle');
          end;
        end;
      end;
    end;
    for LRow := 0 to LProfile do
    begin
      for LSide := -1 to 1 do
      begin
        if LSide = 0 then
        begin
          Continue;
        end;
        { Cross each portal completely, then reach the room's clear centre.
          Empty-room route; actual generated fixtures are a separate oracle. }
        for LSample := 0 to 270 do
        begin
          Check(not AnyWall(LWalls, LSide * LSample * 10, CCenters[LProfile,LRow], 1850),
            'every complete portal centreline clears');
        end;
        Check(not AnyWall(LWalls, LSide * 700, CCenters[LProfile,LRow] + 220, 1850),
          'portal radius touches jamb at clear maximum');
        Check(AnyWall(LWalls, LSide * 700, CCenters[LProfile,LRow] + 220.01, 1850),
          'portal radius outside clear maximum hits jamb');
        Check(not AnyWall(LWalls, LSide * 700, CCenters[LProfile,LRow], 2200),
          'exact header underside contact allowed');
        Check(AnyWall(LWalls, LSide * 700, CCenters[LProfile,LRow], 2200.01),
          'body above clear portal height hits header');
      end;
    end;
    for LSample := -442 to 442 do
    begin
      Check(not AnyWall(LWalls, 0, LSample * 10, 1850), 'entire central corridor clears');
    end;
    for LRow := 0 to LProfile - 1 do
    begin
      LZ := (CCenters[LProfile,LRow] + CCenters[LProfile,LRow + 1]) / 2;
      Check(AnyWall(LWalls, -2700, LZ, 1850), 'left row partition occupies actual gap');
      Check(AnyWall(LWalls, 2700, LZ, 1850), 'right row partition occupies actual gap');
    end;
  end;
  LWall := Default(TSpaceWall);
  LWall.FMinX := -50;
  LWall.FMaxX := 50;
  LWall.FMinZ := -50;
  LWall.FMaxZ := 50;
  LWall.FTop := 2700;
  Check(SpaceWallBlocks(LWall, 0, 0, 0, 1850), 'zero radius rejected');
  Check(SpaceWallBlocks(LWall, 0, 0, 280, 0), 'zero body height rejected');
  LWall.FMinX := 51;
  Check(SpaceWallBlocks(LWall, 0, 0, 280, 1850), 'inverted wall rejected');
end;

function RunSpaceWallCriticChecks: Integer;
begin
  GChecks := 0;
  Run;
  Result := GChecks;
end;

end.
