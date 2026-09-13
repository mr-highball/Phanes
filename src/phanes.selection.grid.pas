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


unit phanes.selection.grid;

{$mode delphi}
{$H+}

interface

type
  TSelectionCells = array of Integer;
  TSelectionBits = array of Boolean;
  TSelectionPoint = record
    FX: Double;
    FZ: Double;
  end;
  TSelectionPoints = array of TSelectionPoint;

function HasSelectionCell(const ACells: TSelectionCells; const AIndex: Integer): Boolean;
function SelectionCells(const ABits: TSelectionBits): TSelectionCells;
procedure PaintSelection(var ABits: TSelectionBits; const ASize: Integer;
  const AFrom, ATo: TSelectionPoint; const ARadius: Double);
procedure LassoSelection(var ABits: TSelectionBits; const ASize: Integer;
  const APoints: TSelectionPoints; const AIncludeTouchedCells: Boolean = False);

implementation

uses
  Math;

function HasSelectionCell(const ACells: TSelectionCells; const AIndex: Integer): Boolean;
var
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
begin
  LLow := 0;
  LHigh := High(ACells);
  while LLow <= LHigh do
  begin
    LMiddle := (LLow + LHigh) div 2;
    if ACells[LMiddle] = AIndex then
    begin
      Exit(True);
    end;
    if ACells[LMiddle] < AIndex then
    begin
      LLow := LMiddle + 1;
    end else
    begin
      LHigh := LMiddle - 1;
    end;
  end;
  Result := False;
end;

function SelectionCells(const ABits: TSelectionBits): TSelectionCells;
var
  LCount: Integer;
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ABits));
  LCount := 0;
  for I := 0 to High(ABits) do
  begin
    if ABits[I] then
    begin
      Result[LCount] := I;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

procedure PaintSelection(var ABits: TSelectionBits; const ASize: Integer;
  const AFrom, ATo: TSelectionPoint; const ARadius: Double);
var
  LX: Integer;
  LZ: Integer;
  LDX: Double;
  LDZ: Double;
  LT: Double;
  LLength: Double;
begin
  { A continuous capsule, sampled at cell centres, avoids holes between sparse
    pointer events. Coordinates and radius are in cells, independent of camera. }
  LDX := ATo.FX - AFrom.FX;
  LDZ := ATo.FZ - AFrom.FZ;
  LLength := Sqr(LDX) + Sqr(LDZ);
  for LZ := Max(0, Floor(Min(AFrom.FZ, ATo.FZ) - ARadius)) to
    Min(ASize - 1, Floor(Max(AFrom.FZ, ATo.FZ) + ARadius)) do
  begin
    for LX := Max(0, Floor(Min(AFrom.FX, ATo.FX) - ARadius)) to
      Min(ASize - 1, Floor(Max(AFrom.FX, ATo.FX) + ARadius)) do
    begin
      LT := 0;
      if LLength > 0 then
      begin
        LT := EnsureRange(((LX + 0.5 - AFrom.FX) * LDX +
          (LZ + 0.5 - AFrom.FZ) * LDZ) / LLength, 0, 1);
      end;
      if Sqr(LX + 0.5 - AFrom.FX - LT * LDX) +
        Sqr(LZ + 0.5 - AFrom.FZ - LT * LDZ) <= Sqr(ARadius) then
      begin
        ABits[LZ * ASize + LX] := True;
      end;
    end;
  end;
end;

function EdgeCrossesCell(const AFrom, ATo: TSelectionPoint; const AX, AZ: Integer): Boolean;
var
  LFirst: Double;
  LLast: Double;

  function ClipAxis(const AStart, ADelta, ALow, AHigh: Double): Boolean;
  var
    LA: Double;
    LB: Double;
  begin
    if ADelta = 0 then
    begin
      Exit((AStart > ALow) and (AStart < AHigh));
    end;
    LA := (ALow - AStart) / ADelta;
    LB := (AHigh - AStart) / ADelta;
    LFirst := Max(LFirst, Min(LA, LB));
    LLast := Min(LLast, Max(LA, LB));
    Result := LFirst < LLast;
  end;

begin
  { Test the open cell interior: an edge that lies exactly on a grid border
    does not unexpectedly add the neighbouring row. No sampling gaps. }
  LFirst := 0;
  LLast := 1;
  Result := ClipAxis(AFrom.FX, ATo.FX - AFrom.FX, AX, AX + 1) and
    ClipAxis(AFrom.FZ, ATo.FZ - AFrom.FZ, AZ, AZ + 1);
end;

procedure LassoSelection(var ABits: TSelectionBits; const ASize: Integer;
  const APoints: TSelectionPoints; const AIncludeTouchedCells: Boolean);
var
  LX: Integer;
  LZ: Integer;
  LInside: Boolean;
  LTouched: Boolean;
  LMinX: Double;
  LMinZ: Double;
  LMaxX: Double;
  LMaxZ: Double;
  I: Integer;
  J: Integer;
begin
  { Even/odd containment gives self-crossing lassos an unambiguous meaning.
    Authoring can also include cells crossed by the contour, so a small
    first-person outline selects the cell it touches instead of doing nothing. }
  if Length(APoints) < 3 then
  begin
    Exit;
  end;
  LMinX := APoints[0].FX;
  LMinZ := APoints[0].FZ;
  LMaxX := LMinX;
  LMaxZ := LMinZ;
  for I := 1 to High(APoints) do
  begin
    LMinX := Min(LMinX, APoints[I].FX);
    LMinZ := Min(LMinZ, APoints[I].FZ);
    LMaxX := Max(LMaxX, APoints[I].FX);
    LMaxZ := Max(LMaxZ, APoints[I].FZ);
  end;
  for LZ := Max(0, Floor(LMinZ)) to Min(ASize - 1, Floor(LMaxZ)) do
  begin
    for LX := Max(0, Floor(LMinX)) to Min(ASize - 1, Floor(LMaxX)) do
    begin
      LInside := False;
      LTouched := False;
      J := High(APoints);
      for I := 0 to High(APoints) do
      begin
        if AIncludeTouchedCells and not LTouched then
        begin
          LTouched := EdgeCrossesCell(APoints[I], APoints[J], LX, LZ);
        end;
        if (APoints[I].FZ > LZ + 0.5) <> (APoints[J].FZ > LZ + 0.5) then
        begin
          if LX + 0.5 < (APoints[J].FX - APoints[I].FX) *
            (LZ + 0.5 - APoints[I].FZ) / (APoints[J].FZ - APoints[I].FZ) + APoints[I].FX then
          begin
            LInside := not LInside;
          end;
        end;
        J := I;
      end;
      if LInside or LTouched then
      begin
        ABits[LZ * ASize + LX] := True;
      end;
    end;
  end;
end;

end.
