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

unit phanes.room.validate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function ValidateRoom(const ARoom: TRoom; out AReason: String): Boolean;

implementation

function ValidateRoom(const ARoom: TRoom; out AReason: String): Boolean;
var
  I: Integer;
  LX: Integer;
  LZ: Integer;
  LTableWest: Integer;
  LTableEast: Integer;
  LChairs: Integer;
  LShelves: Integer;
  LEmpty: Integer;
  LVisited: array[0..24] of Boolean;
  LQueue: array[0..24] of Integer;
  LHead: Integer;
  LTail: Integer;
  LNeighbor: Integer;
  LDirection: Integer;
  LValue: String;
  LLook: String;
begin
  Result := False;
  AReason := 'The room has incomplete layers.';
  if (Length(ARoom.FFurniture) <> 25) or (Length(ARoom.FLooks) <> 25) or
    (Length(ARoom.FTableware) <> 50) then
  begin
    Exit;
  end;
  LTableWest := -1;
  LTableEast := -1;
  LChairs := 0;
  LShelves := 0;
  LEmpty := 0;
  FillChar(LVisited, SizeOf(LVisited), 0);
  for I := 0 to 24 do
  begin
    LX := I mod 5;
    LZ := I div 5;
    LValue := ARoom.FFurniture[I];
    LLook := ARoom.FLooks[I];
    AReason := 'An interior item has invalid placement or appearance.';
    if LValue = 'table-west' then
    begin
      if (LTableWest <> -1) or (LZ <> 2) or ((LX <> 1) and (LX <> 2)) then
      begin
        Exit;
      end;
      LTableWest := I;
      if (LLook <> 'furniture-kit/table') and (LLook <> 'furniture-kit/tableCross') and
        (LLook <> 'furniture-kit/tableCloth') then
      begin
        Exit;
      end;
    end
    else if LValue = 'table-east' then
    begin
      if (LTableEast <> -1) or (LZ <> 2) or ((LX <> 2) and (LX <> 3)) or (LLook <> 'empty') then
      begin
        Exit;
      end;
      LTableEast := I;
    end
    else if (LValue = 'chair-n') or (LValue = 'chair-s') then
    begin
      Inc(LChairs);
      if (LLook <> 'furniture-kit/chair') and (LLook <> 'furniture-kit/chairCushion') then
      begin
        Exit;
      end;
      if LValue = 'chair-n' then
      begin
        if LZ <> 1 then
        begin
          Exit;
        end;
        LNeighbor := I + 5;
      end
      else
      begin
        if LZ <> 3 then
        begin
          Exit;
        end;
        LNeighbor := I - 5;
      end;
      if (ARoom.FFurniture[LNeighbor] <> 'table-west') and
        (ARoom.FFurniture[LNeighbor] <> 'table-east') then
      begin
        Exit;
      end;
    end
    else if LValue = 'shelf' then
    begin
      Inc(LShelves);
      if (LX <> 0) and (LX <> 4) and (LZ <> 0) and (LZ <> 4) then
      begin
        Exit;
      end;
      if (LLook <> 'furniture-kit/bookcaseOpen') and (LLook <> 'furniture-kit/bookcaseClosedWide') then
      begin
        Exit;
      end;
    end
    else if LValue = 'empty' then
    begin
      Inc(LEmpty);
      if LLook <> 'empty' then
      begin
        Exit;
      end;
    end
    else
    begin
      Exit;
    end;
  end;
  if (LTableWest < 0) or (LTableEast <> LTableWest + 1) or (LChairs <> 4) or
    (LShelves < 1) or (LShelves > 3) then
  begin
    AReason := 'A dining room needs one complete table, four chairs, and one to three shelves.';
    Exit;
  end;

  { Independent flood fill checks every empty floor cell against the doorway.
    This does not call WFC's connectivity or rule construction code. }
  AReason := 'The doorway or part of the free floor is unreachable.';
  if ARoom.FFurniture[22] <> 'empty' then
  begin
    Exit;
  end;
  LHead := 0;
  LTail := 1;
  LQueue[0] := 22;
  LVisited[22] := True;
  while LHead < LTail do
  begin
    I := LQueue[LHead];
    Inc(LHead);
    LX := I mod 5;
    LZ := I div 5;
    for LDirection := 0 to 3 do
    begin
      LNeighbor := -1;
      case LDirection of
        0: if LX > 0 then LNeighbor := I - 1;
        1: if LX < 4 then LNeighbor := I + 1;
        2: if LZ > 0 then LNeighbor := I - 5;
        3: if LZ < 4 then LNeighbor := I + 5;
      end;
      if (LNeighbor >= 0) and not LVisited[LNeighbor] and (ARoom.FFurniture[LNeighbor] = 'empty') then
      begin
        LVisited[LNeighbor] := True;
        LQueue[LTail] := LNeighbor;
        Inc(LTail);
      end;
    end;
  end;
  if LTail <> LEmpty then
  begin
    Exit;
  end;
  for I := 0 to 49 do
  begin
    LValue := ARoom.FFurniture[(I div 10) * 5 + I mod 5];
    LLook := ARoom.FTableware[I];
    if (LValue = 'table-west') or (LValue = 'table-east') then
    begin
      if (LLook <> 'porcelain') and (LLook <> 'cobalt') and (LLook <> 'earthenware') then
      begin
        AReason := 'A table setting is missing or unknown.';
        Exit;
      end;
    end
    else if LLook <> 'empty' then
    begin
      AReason := 'Tableware has no supporting table surface.';
      Exit;
    end;
  end;
  AReason := 'Room layout, reachability, furniture and table support validated.';
  Result := True;
end;

end.
