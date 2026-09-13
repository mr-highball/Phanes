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
unit phanes.interiors.validate;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types,
  phanes.composition.types,
  phanes.composition.contents.types;

function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;
{ Caller first admits each groundwork assembly; this pass admits building descendants. }
function ValidateInteriorNodes(const AWorld: TWorld; out AReason: String): Boolean;

implementation

uses
  SysUtils,
  Math,
  phanes.composition.document,
  phanes.composition.contents.validate,
  phanes.interiors.catalog,
  phanes.interiors.profiles,
  phanes.interiors.surfaces,
  phanes.spaces.plans,
  phanes.world.height,
  phanes.buildings.types,
  phanes.buildings.validate,
  phanes.structures.support,
  phanes.groundworks.assembly;

function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;
begin
  Result := phanes.interiors.surfaces.SurfaceRequest(ADocument, ASurfaceId, ARequest, AReason);
end;

function ValidateInteriorNodes(const AWorld: TWorld; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LParentNode: TCompositionNode;
  LAsset: TInteriorAsset;
  LInterior: TBuildingInterior;
  LProfile: TContentSupport;
  LRequest: TContentRequest;
  LChildren: array of array of Integer;
  LParent: Integer;
  LX: Integer;
  LZ: Integer;
  LTier: Integer;
  LCount: Integer;
  LTable: Integer;
  LBookcase: Integer;
  LChairWest: Integer;
  LChairEast: Integer;
  LChild: Integer;
  I: Integer;
  J: Integer;

  function Pose(const ANode: TCompositionNode; const AX, AY, AZ,
    ATurn: Integer): Boolean;
  begin
    Result := (ANode.FX = AX) and (ANode.FY = AY) and (ANode.FZ = AZ) and
      (ANode.FQuarterTurn = ATurn);
  end;

  function SingleChild(const AParent: Integer; const AId: String): Boolean;
  begin
    Result := (Length(LChildren[AParent]) = 1) and
      (AWorld.FComposition.FNodes[LChildren[AParent][0]].FId = AId);
  end;

  function CabinInterior(const AParent: Integer; const AId: String): Boolean;
  begin
    Result := SingleChild(AParent, AId + '.studio') or
      SingleChild(AParent, AId + '.plan');
  end;

begin
  Result := False;
  AReason := 'Interior admission requires complete regional layers in a 4 to 48 cell world.';
  if (AWorld.FSize < 4) or (AWorld.FSize > 48) then
  begin
    Exit;
  end;
  for I := 0 to 4 do
  begin
    if Length(AWorld.FLayers[I]) <> Sqr(LayerSize(AWorld.FSize, I)) then
    begin
      Exit;
    end;
  end;
  if not ValidateComposition(AWorld.FComposition, AReason) or
    not ValidateModularBuildings(AWorld, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    SetLength(LChildren, Length(AWorld.FComposition.FNodes));
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LParent := LIndex.Find(AWorld.FComposition.FNodes[I].FParentId);
      if LParent >= 0 then
      begin
        LCount := Length(LChildren[LParent]);
        SetLength(LChildren[LParent], LCount + 1);
        LChildren[LParent][LCount] := I;
      end;
    end;
    { Admit each complete plan before treating its descendants as a separate
      domain. Neither a prefix nor a claimed role can bypass shell admission. }
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      if (AWorld.FComposition.FNodes[I].FRole = 'floor-plan') and
        not ValidateCabinPlan(AWorld.FComposition, AWorld.FComposition.FNodes[I].FId,
          AReason) then
      begin
        Exit;
      end;
    end;
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LNode := AWorld.FComposition.FNodes[I];
      if (SpacePlanOwner(AWorld.FComposition, LIndex, I) <> '') or
        (ModularOwner(AWorld.FComposition, LIndex, I) <> '') then
      begin
        Continue;
      end;
      if HasCompositionExtent(LNode) then
      begin
        AReason := 'This profile does not admit editable container dimensions: ' + LNode.FId;
        Exit;
      end;
      if LNode.FId = 'world' then
      begin
        Continue;
      end;
      { Only skip nodes owned by a fully admitted groundwork. Prefix matching
        alone would hide malformed or unknown geometry from world admission. }
      if (GroundworkOwner(AWorld.FComposition, LIndex, I) <> '') and
        (SupportedBuildingOwner(AWorld.FComposition, LIndex, I) = '') then
      begin
        Continue;
      end;
      AReason := 'Interior geometry or ownership does not match its admitted profile: ' + LNode.FId;
      LParent := LIndex.Find(LNode.FParentId);
      if LParent < 0 then
      begin
        Exit;
      end;
      LParentNode := AWorld.FComposition.FNodes[LParent];
      if LNode.FKind = ckContainer then
      begin
        if (LNode.FSupportId <> '') and
          (SupportedBuildingOwner(AWorld.FComposition, LIndex, I) <> LNode.FId) then
        begin
          Exit;
        end;
        if LNode.FRole = 'building' then
        begin
          if SupportedBuildingOwner(AWorld.FComposition, LIndex, I) = LNode.FId then
          begin
            if (Length(LChildren[I]) > 0) and
              (not BuildingInterior(LNode.FAssetId, LInterior) or
              not CabinInterior(I, LNode.FId)) then
            begin
              Exit;
            end;
            Continue;
          end;
          { Admit actual regional anchors, including their terrain elevation.
            A regional replacement must not leave an orphan furnished building. }
          LX := Floor(LNode.FX / 16000 + AWorld.FSize / 2);
          LZ := Floor(LNode.FZ / 16000 + AWorld.FSize / 2);
          if (LX < 0) or (LZ < 0) or (LX >= AWorld.FSize) or (LZ >= AWorld.FSize) then
          begin
            Exit;
          end;
          if (LNode.FParentId <> 'world') or not BuildingInterior(LNode.FAssetId, LInterior) or
            (LNode.FId <> 'building-' + IntToStr(LX) + '-' + IntToStr(LZ)) or
            (AWorld.FLayers[3][LZ * AWorld.FSize + LX] <> LNode.FAssetId) or
            not Pose(LNode, Round((LX + 0.5 - AWorld.FSize / 2) * 16000),
              Round(WorldBuildingDatum(AWorld, LX, LZ) * 1000),
              Round((LZ + 0.5 - AWorld.FSize / 2) * 16000), 0) or
            not CabinInterior(I, LNode.FId) then
          begin
            Exit;
          end;
        end
        else if LNode.FRole = 'studio' then
        begin
          if (LParentNode.FRole <> 'building') or (LParentNode.FKind <> ckContainer) or
            not BuildingInterior(LParentNode.FAssetId, LInterior) or
            (LNode.FId <> LNode.FParentId + '.studio') or
            (LNode.FAssetId <> LInterior.FRoomAssetId) or
            not Pose(LNode, 0, LInterior.FFloor, 0, 0) or
            (Length(LChildren[I]) <> 4) then
          begin
            Exit;
          end;
          LTable := -1;
          LBookcase := -1;
          LChairWest := -1;
          LChairEast := -1;
          for J := 0 to High(LChildren[I]) do
          begin
            LChild := LChildren[I][J];
            if AWorld.FComposition.FNodes[LChild].FRole = 'table' then
            begin
              if LTable >= 0 then
              begin
                Exit;
              end;
              LTable := LChild;
            end
            else if AWorld.FComposition.FNodes[LChild].FRole = 'bookcase' then
            begin
              if LBookcase >= 0 then
              begin
                Exit;
              end;
              LBookcase := LChild;
            end
            else if (AWorld.FComposition.FNodes[LChild].FRole = 'chair') and
              (AWorld.FComposition.FNodes[LChild].FQuarterTurn = 1) then
            begin
              if LChairWest >= 0 then
              begin
                Exit;
              end;
              LChairWest := LChild;
            end
            else if (AWorld.FComposition.FNodes[LChild].FRole = 'chair') and
              (AWorld.FComposition.FNodes[LChild].FQuarterTurn = 3) then
            begin
              if LChairEast >= 0 then
              begin
                Exit;
              end;
              LChairEast := LChild;
            end
            else
            begin
              Exit;
            end;
          end;
          if (LTable < 0) or (LBookcase < 0) or (LChairWest < 0) or (LChairEast < 0) then
          begin
            Exit;
          end;
          LX := AWorld.FComposition.FNodes[LTable].FX;
          { The admitted poses leave the whole row between bookcase and table
            empty and one side of the table row open. Thus every empty cell
            in the four by four floor graph connects to the front aisle,
            regardless of which of the four back anchors holds the bookcase. }
          if not Pose(AWorld.FComposition.FNodes[LChairWest], LX - 1250, 0, -700, 1) or
            not Pose(AWorld.FComposition.FNodes[LChairEast], LX + 1250, 0, -700, 3) then
          begin
            Exit;
          end;
        end
        else
        begin
          Exit;
        end;
      end
      else if LNode.FKind = ckSurface then
      begin
        if (LParentNode.FKind <> ckObject) or (LNode.FSupportId <> '') then
        begin
          Exit;
        end;
        if LNode.FRole = 'shelf-tier' then
        begin
          LTier := (LNode.FY - 260) div 480 + 1;
          if (LTier < 1) or (LTier > 4) or
            (LParentNode.FAssetId <> 'phanes.shelf.oak.v1') or
            (LNode.FAssetId <> 'phanes.support.shelf.v1') or
            (LNode.FId <> LNode.FParentId + '.tier-' + IntToStr(LTier)) or
            not Pose(LNode, 0, 260 + (LTier - 1) * 480, 0, 0) then
          begin
            Exit;
          end;
        end
        else if LNode.FRole = 'tabletop' then
        begin
          if (LParentNode.FAssetId <> 'phanes.table.oak.v1') or
            (LNode.FAssetId <> 'phanes.support.table.v1') or
            (LNode.FId <> LNode.FParentId + '.top') or not Pose(LNode, 0, 750, 0, 0) then
          begin
            Exit;
          end;
        end
        else if LNode.FRole = 'plate-well' then
        begin
          LProfile := InteriorPlateSupport;
          if (LParentNode.FRole <> 'plate') or
            (LNode.FAssetId <> LProfile.FAssetId) or
            (LNode.FId <> LNode.FParentId + '.' + LProfile.FKey) or
            not Pose(LNode, LProfile.FX, LProfile.FY, LProfile.FZ,
              LProfile.FQuarterTurn) then
          begin
            Exit;
          end;
        end
        else
        begin
          Exit;
        end;
        if not SurfaceRequest(AWorld.FComposition, LNode.FId, LRequest, AReason) or
          not ValidateContentResult(AWorld.FComposition, LRequest, AReason) then
        begin
          Exit;
        end;
      end
      else
      begin
        if not InteriorAsset(LNode.FAssetId, LAsset) or (LNode.FRole <> LAsset.FRole) then
        begin
          Exit;
        end;
        if LNode.FSupportId <> '' then
        begin
          if (LParentNode.FKind <> ckSurface) or
            (LNode.FSupportId <> LNode.FParentId) then
          begin
            Exit;
          end;
        end
        else
        begin
          if (LParentNode.FKind <> ckContainer) or (LParentNode.FRole <> 'studio') then
          begin
            Exit;
          end;
          { These v1 room anchors leave a full front aisle, at least 83 mm
            between the measured table and seated chairs, and 2 m between
            the back bookcase and table. Validate decoded poses independently. }
          LX := -1;
          if LNode.FRole = 'bookcase' then
          begin
            LX := (LNode.FX + 3300) div 2200;
            if (LX < 0) or (LX > 3) or not Pose(LNode, -3300 + LX * 2200, 0, -3200, 0) or
              (Length(LChildren[I]) <> 4) then
            begin
              Exit;
            end;
            for LTier := 1 to 4 do
            begin
              LChild := LIndex.Find(LNode.FId + '.tier-' + IntToStr(LTier));
              if (LChild < 0) or (AWorld.FComposition.FNodes[LChild].FParentId <> LNode.FId) or
                (AWorld.FComposition.FNodes[LChild].FKind <> ckSurface) then
              begin
                Exit;
              end;
            end;
          end
          else if LNode.FRole = 'table' then
          begin
            LX := (LNode.FX + 3300) div 2200;
            if ((LX <> 1) and (LX <> 2)) or not Pose(LNode, -3300 + LX * 2200, 0, -700, 0) or
              not SingleChild(I, LNode.FId + '.top') then
            begin
              Exit;
            end;
            Inc(LX, 4);
          end
          else if LNode.FRole = 'chair' then
          begin
            if LNode.FQuarterTurn = 1 then
            begin
              LX := (LNode.FX - 950 + 3300) div 2200;
              if (LX < 0) or (LX > 1) or not Pose(LNode, -3300 + LX * 2200 + 950, 0, -700, 1) then
              begin
                Exit;
              end;
            end
            else if LNode.FQuarterTurn = 3 then
            begin
              LX := (LNode.FX + 950 + 3300) div 2200;
              if (LX < 2) or (LX > 3) or not Pose(LNode, -3300 + LX * 2200 - 950, 0, -700, 3) then
              begin
                Exit;
              end;
            end
            else
            begin
              Exit;
            end;
            if Length(LChildren[I]) <> 0 then
            begin
              Exit;
            end;
            Inc(LX, 4);
          end
          else
          begin
            Exit;
          end;
          if LNode.FId <> LNode.FParentId + '.furniture-' + IntToStr(LX) then
          begin
            Exit;
          end;
        end;
      end;
    end;
    Result := True;
    AReason := '';
  finally
    LIndex.Free;
  end;
end;

end.
