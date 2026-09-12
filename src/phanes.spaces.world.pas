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

unit phanes.spaces.world;
{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function IsSpaceOperation(const AOperation: String): Boolean;
function EditSpaces(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  SysUtils,
  phanes.composition.types,
  phanes.composition.document,
  phanes.world.height,
  phanes.world.validate,
  phanes.spaces.plans,
  phanes.spaces.rooms;

function IsSpaceOperation(const AOperation: String): Boolean;
begin
  Result := (AOperation = 'create-plan') or (AOperation = 'room-purpose') or
    (AOperation = 'room-reimagine') or (AOperation = 'rename-space');
end;

function EditSpaces(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
var
  LDocument: TCompositionDocument;
  LCommitted: TCompositionDocument;
  LPrivate: TCompositionDocument;
  LCandidate: TWorld;
  LIndex: TCompositionIndex;
  LNode: TCompositionNode;
  LBuildingId: String;
  LScopeId: String;
  LProgram: String;
  LSelected: Integer;
  LCount: Integer;
  LCell: Integer;
  LCode: Integer;
  I: Integer;
begin
  Result := False;
  AWorld := Default(TWorld);
  if not ValidateWorld(ARequest.FPrevious, ARequest.FAssets, AReason) then
  begin
    Exit;
  end;
  LDocument := CopyDocument(ARequest.FPrevious.FComposition);
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LSelected := LIndex.Find(ARequest.FObjectId);
    if ARequest.FOperation = 'create-plan' then
    begin
      AReason := 'Select a cabin and choose its room layout.';
      LScopeId := ARequest.FObjectId;
      if ARequest.FObjectId = '' then
      begin
        if (ARequest.FWidth <> 1) or (ARequest.FDepth <> 1) or
          (ARequest.FX < 0) or (ARequest.FX >= ARequest.FPrevious.FSize) or
          (ARequest.FZ < 0) or (ARequest.FZ >= ARequest.FPrevious.FSize) then
        begin
          Exit;
        end;
        LCell := ARequest.FZ * ARequest.FPrevious.FSize + ARequest.FX;
        if ARequest.FPrevious.FLayers[1][LCell] <> 'cabin' then
        begin
          Exit;
        end;
        LBuildingId := 'building-' + IntToStr(ARequest.FX) + '-' + IntToStr(ARequest.FZ);
        LSelected := LIndex.Find(LBuildingId);
        LScopeId := LBuildingId;
        if LSelected < 0 then
        begin
          LNode := Default(TCompositionNode);
          LNode.FId := LBuildingId;
          LNode.FParentId := 'world';
          LNode.FRole := 'building';
          LNode.FAssetId := 'cabin';
          LNode.FKind := ckContainer;
          LNode.FName := 'Cabin';
          LNode.FX := Round((ARequest.FX + 0.5 - ARequest.FPrevious.FSize / 2) * 16000);
          LNode.FZ := Round((ARequest.FZ + 0.5 - ARequest.FPrevious.FSize / 2) * 16000);
          LNode.FY := Round(WorldBuildingDatum(ARequest.FPrevious, ARequest.FX, ARequest.FZ) * 1000);
          LCount := Length(LDocument.FNodes);
          SetLength(LDocument.FNodes, LCount + 1);
          LDocument.FNodes[LCount] := LNode;
          LScopeId := 'world';
        end;
      end
      else
      begin
        if LSelected < 0 then
        begin
          Exit;
        end;
        LBuildingId := ARequest.FObjectId;
      end;
      LDocument.FRevision := 0;
      if not CreateCabinPlan(LDocument, LBuildingId, ARequest.FPlanProfile,
        ARequest.FSeed, 0, LPrivate, AReason) then
      begin
        Exit;
      end;
      LPrivate.FRevision := ARequest.FPrevious.FComposition.FRevision;
      if not CommitComposition(ARequest.FPrevious.FComposition, LPrivate, LScopeId,
        LPrivate.FRevision, LCommitted, AReason) then
      begin
        Exit;
      end;
    end
    else
    begin
      AReason := 'Choose a named bay or room inside an admitted floor plan.';
      if (LSelected < 0) or (SpacePlanOwner(LDocument, LIndex, LSelected) = '') then
      begin
        Exit;
      end;
      LNode := LDocument.FNodes[LSelected];
      if ARequest.FOperation = 'rename-space' then
      begin
        if ((LNode.FRole <> 'bay') and (LNode.FRole <> 'room') and
          (LNode.FRole <> 'floor-plan')) then
        begin
          Exit;
        end;
        AReason := 'Use a name of 1 to 80 characters.';
        if (Trim(ARequest.FSpaceName) = '') or (Length(ARequest.FSpaceName) > 80) then
        begin
          Exit;
        end;
        I := 1;
        while I <= Length(ARequest.FSpaceName) do
        begin
          LCode := Ord(ARequest.FSpaceName[I]);
          if (LCode < 32) or ((LCode >= $DC00) and (LCode <= $DFFF)) then
          begin
            Exit;
          end;
          if (LCode >= $D800) and (LCode <= $DBFF) then
          begin
            Inc(I);
            if I > Length(ARequest.FSpaceName) then
            begin
              Exit;
            end;
            LCode := Ord(ARequest.FSpaceName[I]);
            if (LCode < $DC00) or (LCode > $DFFF) then
            begin
              Exit;
            end;
          end;
          Inc(I);
        end;
        LDocument.FNodes[LSelected].FName := ARequest.FSpaceName;
        if not CommitComposition(ARequest.FPrevious.FComposition, LDocument, LNode.FId,
          LDocument.FRevision, LCommitted, AReason) then
        begin
          Exit;
        end;
      end
      else
      begin
        if (LNode.FKind <> ckContainer) or (LNode.FRole <> 'room') then
        begin
          Exit;
        end;
        LProgram := ARequest.FRoomProgram;
        if ARequest.FOperation = 'room-reimagine' then
        begin
          LProgram := LNode.FAssetId;
        end
        else if ARequest.FOperation <> 'room-purpose' then
        begin
          Exit;
        end;
        if not GenerateProgramRoom(LDocument, LNode.FId, LProgram, ARequest.FSeed,
          LDocument.FRevision, ARequest.FOperation = 'room-purpose', LCommitted, AReason) then
        begin
          Exit;
        end;
      end;
    end;
    LCandidate := ARequest.FPrevious;
    LCandidate.FComposition := LCommitted;
    if ARequest.FOperation <> 'rename-space' then
    begin
      LCandidate.FSeed := ARequest.FSeed;
    end;
    if not ValidateWorld(LCandidate, ARequest.FAssets, AReason) then
    begin
      Exit;
    end;
    AWorld := LCandidate;
    Result := True;
  finally
    LIndex.Free;
  end;
end;

end.
