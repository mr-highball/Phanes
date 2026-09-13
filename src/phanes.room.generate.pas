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

unit phanes.room.generate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function GenerateRoom(const AParent: Integer; const ASeed: Cardinal;
  const APrevious: TRoom; const AReplaceShelf: Integer; out ARoom: TRoom;
  out AReason: String): Boolean;

implementation

uses
  wfc,
  wfc_lattice,
  phanes.room.validate;

function AcceptNeighbor(const AValue, ANeighbor: String; const ADirection: TGraphDirection): Boolean;
begin
  Result := True;
  if ((AValue = 'table-west') and (ADirection = gdEast)) or
    ((AValue = 'table-east') and (ADirection = gdWest)) then
  begin
    if AValue = 'table-west' then
    begin
      Exit(ANeighbor = 'table-east');
    end;
    Exit(ANeighbor = 'table-west');
  end;
  if (AValue = 'table-west') or (AValue = 'table-east') then
  begin
    if ADirection = gdNorth then
    begin
      Exit(ANeighbor = 'chair-s');
    end;
    if ADirection = gdSouth then
    begin
      Exit(ANeighbor = 'chair-n');
    end;
  end;
  if ((AValue = 'chair-n') and (ADirection = gdNorth)) or
    ((AValue = 'chair-s') and (ADirection = gdSouth)) then
  begin
    Exit((ANeighbor = 'table-west') or (ANeighbor = 'table-east'));
  end;
end;

function GenerateRoom(const AParent: Integer; const ASeed: Cardinal;
  const APrevious: TRoom; const AReplaceShelf: Integer; out ARoom: TRoom;
  out AReason: String): Boolean;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LRoles: TGraphValues;
  LAllowed: TGraphValues;
  LLayouts: TWfcLatticeLayouts;
  LProfiles: TGraphConnectivityValues;
  LRoot: TGraphPosition;
  LValue: String;
  LNeighbor: String;
  LDirection: TGraphDirection;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  Result := False;
  ARoom := Default(TRoom);
  if AReplaceShelf >= 0 then
  begin
    if not ValidateRoom(APrevious, AReason) then
    begin
      Exit;
    end;
    if (AReplaceShelf > 24) or (APrevious.FFurniture[AReplaceShelf] <> 'shelf') then
    begin
      AReason := 'Select a bookshelf to replace its appearance.';
      Exit;
    end;
  end;
  LGraph := TGraph.Create;
  try
    LGraph.Seed := ASeed;
    LGraph.Reshape(5, 5, 1);
    LGraph.CurrentPass := 'furniture';
    LGraph.PassMode := gpmOverlay;
    LRoles := ['empty', 'table-west', 'table-east', 'chair-n', 'chair-s', 'shelf'];
    for LValue in LRoles do
    begin
      LGraph.AddValue(LValue);
    end;
    { The two table cells form a two-unit footprint. Their north/south sockets
      require four facing chairs. Register complete reciprocal compatibility,
      including self-pairs; missing rules must not masquerade as constraints. }
    for LValue in LRoles do
    begin
      for LNeighbor in LRoles do
      begin
        for LDirection := gdNorth to gdWest do
        begin
          if AcceptNeighbor(LValue, LNeighbor, LDirection) and
            AcceptNeighbor(LNeighbor, LValue, InverseOfDir(LDirection)) then
          begin
            LGraph.Rules[LValue].NewRule([LDirection], LNeighbor);
          end;
        end;
      end;
    end;
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('one-table-west', ['table-west'], 1, 1));
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('one-table-east', ['table-east'], 1, 1));
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('four-seats', ['chair-n', 'chair-s'], 4, 4));
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('shelves', ['shelf'], 1, 3));
    LRoot.X := 2;
    LRoot.Y := 4;
    LRoot.Z := 0;
    SetLength(LProfiles, 1);
    LProfiles[0] := MakeGraphConnectivityValue('empty', [gdNorth, gdEast, gdSouth, gdWest]);
    LGraph.RequireConnectivity(MakeGraphConnectivityConstraint('doorway-and-free-floor',
      LRoot, [], LProfiles, True));

    LGraph.SwitchToPass('appearance');
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('empty').RequireMappedFromPass('furniture', MakeGraphPassCellQuery(['empty', 'table-east']));
    for LValue in ['furniture-kit/table', 'furniture-kit/tableCross', 'furniture-kit/tableCloth'] do
    begin
      LGraph.AddValue(LValue).RequireMappedFromPass('furniture', MakeGraphPassCellQuery(['table-west']));
    end;
    for LValue in ['furniture-kit/chair', 'furniture-kit/chairCushion'] do
    begin
      LGraph.AddValue(LValue).RequireMappedFromPass('furniture', MakeGraphPassCellQuery(['chair-n', 'chair-s']));
    end;
    for LValue in ['furniture-kit/bookcaseOpen', 'furniture-kit/bookcaseClosedWide'] do
    begin
      LGraph.AddValue(LValue).RequireMappedFromPass('furniture', MakeGraphPassCellQuery(['shelf']));
    end;
    LGraph.SwitchToPass('tableware');
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('empty').RequireMappedFromPass('furniture',
      MakeGraphPassCellQuery(['empty', 'chair-n', 'chair-s', 'shelf']));
    for LValue in ['porcelain', 'cobalt', 'earthenware'] do
    begin
      LGraph.AddValue(LValue).RequireMappedFromPass('furniture',
        MakeGraphPassCellQuery(['table-west', 'table-east']));
    end;
    SetLength(LLayouts, 3);
    LLayouts[0] := MakeWfcLatticeLayout(5, 5, 1, MakeWfcLatticeVector(0, 0, 0),
      MakeWfcLatticeVector(2, 2, 1), False);
    LLayouts[1] := LLayouts[0];
    LLayouts[2] := MakeWfcLatticeLayout(5, 10, 1, MakeWfcLatticeVector(0, 0, 0),
      MakeWfcLatticeVector(2, 1, 1), False);
    LGraph.ConfigurePassLayouts(LLayouts);
    for LZ := 0 to 4 do
    begin
      for LX := 0 to 4 do
      begin
        I := LZ * 5 + LX;
        if AReplaceShelf >= 0 then
        begin
          LGraph.PassGraph[0].SetAllowedValues(LX, LZ, 0, APrevious.FFurniture[I]);
          if I <> AReplaceShelf then
          begin
            LGraph.PassGraph[1].SetAllowedValues(LX, LZ, 0, APrevious.FLooks[I]);
          end
          else if APrevious.FLooks[I] = 'furniture-kit/bookcaseOpen' then
          begin
            LGraph.PassGraph[1].SetAllowedValues(LX, LZ, 0, 'furniture-kit/bookcaseClosedWide');
          end
          else
          begin
            LGraph.PassGraph[1].SetAllowedValues(LX, LZ, 0, 'furniture-kit/bookcaseOpen');
          end;
          Continue;
        end;
        LAllowed := ['empty'];
        if ((LX = 0) or (LX = 4) or (LZ = 0) or (LZ = 4)) and (I <> 22) then
        begin
          LAllowed := ['empty', 'shelf'];
        end;
        if (LZ = 2) and (LX >= 1) and (LX <= 2) then
        begin
          LAllowed := LAllowed + ['table-west'];
        end;
        if (LZ = 2) and (LX >= 2) and (LX <= 3) then
        begin
          LAllowed := LAllowed + ['table-east'];
        end;
        if (LZ = 1) and (LX >= 1) and (LX <= 3) then
        begin
          LAllowed := LAllowed + ['chair-n'];
        end;
        if (LZ = 3) and (LX >= 1) and (LX <= 3) then
        begin
          LAllowed := LAllowed + ['chair-s'];
        end;
        LGraph.PassGraph[0].SetAllowedValues(LX, LZ, 0, LAllowed);
      end;
    end;
    if AReplaceShelf >= 0 then
    begin
      for I := 0 to 49 do
      begin
        LGraph.PassGraph[2].SetAllowedValues(I mod 5, I div 5, 0, APrevious.FTableware[I]);
      end;
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 512;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'The room could not be resolved within the search allowance. The cabin is unchanged.';
      Exit;
    end;
    ARoom.FParent := AParent;
    ARoom.FSeed := ASeed;
    SetLength(ARoom.FFurniture, 25);
    SetLength(ARoom.FLooks, 25);
    SetLength(ARoom.FTableware, 50);
    for I := 0 to 24 do
    begin
      ARoom.FFurniture[I] := LGraph.PassGraph[0].Entry[I mod 5, I div 5, 0].Value;
      ARoom.FLooks[I] := LGraph.PassGraph[1].Entry[I mod 5, I div 5, 0].Value;
    end;
    for I := 0 to 49 do
    begin
      ARoom.FTableware[I] := LGraph.PassGraph[2].Entry[I mod 5, I div 5, 0].Value;
    end;
    Result := ValidateRoom(ARoom, AReason);
  finally
    LGraph.Free;
  end;
end;

end.
