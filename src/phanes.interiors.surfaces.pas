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

unit phanes.interiors.surfaces;
{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.contents.types;

function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;

implementation

uses
  SysUtils, Math,
  phanes.composition.document,
  phanes.interiors.catalog, phanes.catalog.furniture;

function SurfaceRequest(const ADocument: TCompositionDocument; const ASurfaceId: String;
  out ARequest: TContentRequest; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LSurface: Integer;
  LParent: Integer;
  LFurniture: TFurnitureProfile;
  LSlot: TContentSlot;
  LProfile: TContentSupport;
  LNode: TCompositionNode;
  LRole: String;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  ARequest := Default(TContentRequest);
  Result := False;
  AReason := 'Select an admitted interior support surface.';
  LIndex := TCompositionIndex.Create(ADocument.FNodes);
  try
    LSurface := LIndex.Find(ASurfaceId);
    if (LSurface < 0) or (ADocument.FNodes[LSurface].FKind <> ckSurface) then
    begin
      Exit;
    end;
    ARequest.FSurfaceId := ASurfaceId;
    ARequest.FScopeId := ASurfaceId;
    ARequest.FExpectedRevision := ADocument.FRevision;
    ARequest.FAssets := InteriorContentAssets;
    SetLength(ARequest.FSlots, 4);
    LParent := LIndex.Find(ADocument.FNodes[LSurface].FParentId);
    if (LParent >= 0) and FurnitureProfile(ADocument.FNodes[LParent].FAssetId,
      LFurniture) then
    begin
      { A surface ID alone is insufficient: the exact furniture profile owns
        its measured contact plane and usable rectangle. }
      if (Length(LFurniture.FFloor.FContent.FSupports) <> 1) or
        (ASurfaceId <> ADocument.FNodes[LParent].FId + '.top') then
      begin
        Exit;
      end;
      LProfile := LFurniture.FFloor.FContent.FSupports[0];
      if ADocument.FNodes[LSurface].FAssetId <> LProfile.FAssetId then
      begin
        Exit;
      end;
      ARequest.FSurfaceWidth := LProfile.FWidth;
      ARequest.FSurfaceDepth := LProfile.FDepth;
      ARequest.FHeadroom := LProfile.FHeadroom;
      for I := 0 to 3 do
      begin
        LSlot := Default(TContentSlot);
        LSlot.FObjectId := ASurfaceId + '.item-' + IntToStr(I);
        LSlot.FWidth := Min(450, LProfile.FWidth div 2 - 80);
        LSlot.FDepth := Min(400, LProfile.FDepth div 2 - 80);
        LSlot.FHeight := LProfile.FHeadroom;
        LSlot.FX := (2 * (I mod 2) - 1) * (LProfile.FWidth div 4);
        LSlot.FZ := (2 * (I div 2) - 1) * (LProfile.FDepth div 4);
        LSlot.FAllowedRoles := LProfile.FAllowedRoles;
        LSlot.FAllowEmpty := True;
        ARequest.FSlots[I] := LSlot;
      end;
    end
    else if ADocument.FNodes[LSurface].FAssetId = 'phanes.support.shelf.v1' then
    begin
      ARequest.FSurfaceWidth := 720;
      ARequest.FSurfaceDepth := 420;
      ARequest.FHeadroom := 420;
      for I := 0 to 3 do
      begin
        LSlot := Default(TContentSlot);
        LSlot.FObjectId := ASurfaceId + '.item-' + IntToStr(I);
        LSlot.FX := -270 + I * 180;
        LSlot.FWidth := 160;
        LSlot.FDepth := 300;
        LSlot.FHeight := 310;
        LSlot.FAllowedRoles := ['book', 'ornament'];
        LSlot.FAllowEmpty := True;
        ARequest.FSlots[I] := LSlot;
      end;
    end
    else if ADocument.FNodes[LSurface].FAssetId = 'phanes.support.table.v1' then
    begin
      ARequest.FSurfaceWidth := 1500;
      ARequest.FSurfaceDepth := 800;
      ARequest.FHeadroom := 400;
      for I := 0 to 3 do
      begin
        LSlot := Default(TContentSlot);
        LSlot.FObjectId := ASurfaceId + '.item-' + IntToStr(I);
        LSlot.FWidth := 300;
        LSlot.FDepth := 300;
        LSlot.FHeight := 310;
        LSlot.FX := -300;
        LSlot.FAllowedRoles := ['plate'];
        if I = 2 then
        begin
          LSlot.FX := 300;
        end;
        if Odd(I) then
        begin
          LSlot.FWidth := 60;
          LSlot.FDepth := 240;
          LSlot.FX := -550;
          if I = 3 then
          begin
            LSlot.FX := 550;
          end;
          LSlot.FAllowedRoles := ['fork'];
        end;
        LSlot.FAllowEmpty := True;
        ARequest.FSlots[I] := LSlot;
      end;
    end
    else if ADocument.FNodes[LSurface].FAssetId = 'phanes.support.bench.v1' then
    begin
      ARequest.FSurfaceWidth := 1500;
      ARequest.FSurfaceDepth := 800;
      ARequest.FHeadroom := 700;
      SetLength(ARequest.FSlots, 6);
      for I := 0 to 5 do
      begin
        LSlot := Default(TContentSlot);
        LSlot.FObjectId := ASurfaceId + '.item-' + IntToStr(I);
        LSlot.FWidth := 400;
        LSlot.FDepth := 300;
        LSlot.FHeight := 600;
        LSlot.FX := -480 + (I mod 3) * 480;
        LSlot.FZ := -210 + (I div 3) * 420;
        LSlot.FAllowedRoles := ['book', 'ornament'];
        LSlot.FAllowEmpty := True;
        ARequest.FSlots[I] := LSlot;
      end;
    end
    else if ADocument.FNodes[LSurface].FAssetId = 'phanes.support.plate.v1' then
    begin
      LProfile := InteriorPlateSupport;
      ARequest.FSurfaceWidth := LProfile.FWidth;
      ARequest.FSurfaceDepth := LProfile.FDepth;
      ARequest.FHeadroom := LProfile.FHeadroom;
      SetLength(ARequest.FSlots, 3);
      for I := 0 to 2 do
      begin
        LSlot := Default(TContentSlot);
        LSlot.FObjectId := ASurfaceId + '.item-' + IntToStr(I);
        LSlot.FWidth := 52;
        LSlot.FDepth := 52;
        LSlot.FHeight := LProfile.FHeadroom;
        LSlot.FX := 28;
        LSlot.FZ := -28;
        LSlot.FAllowedRoles := ['fruit'];
        if I = 0 then
        begin
          LSlot.FX := -29;
          LSlot.FZ := 0;
          LSlot.FDepth := 100;
          LSlot.FAllowedRoles := ['bread'];
        end
        else if I = 2 then
        begin
          LSlot.FZ := 28;
          LSlot.FAllowedRoles := ['cheese'];
        end;
        LSlot.FAllowEmpty := True;
        ARequest.FSlots[I] := LSlot;
      end;
    end
    else
    begin
      Exit;
    end;
    { A saved arrangement is also the default count intent for reimagination.
      A player's new count request overrides these totals before solving.
      Surface geometry is versioned by its immutable admitted profile ID. }
    SetLength(ARequest.FQuotas, 7);
    for I := 0 to 6 do
    begin
      case I of
        0:
        begin
          LRole := 'book';
        end;
        1:
        begin
          LRole := 'ornament';
        end;
        2:
        begin
          LRole := 'plate';
        end;
        3:
        begin
          LRole := 'fork';
        end;
        4:
        begin
          LRole := 'bread';
        end;
        5:
        begin
          LRole := 'fruit';
        end;
        6:
        begin
          LRole := 'cheese';
        end;
      end;
      LCount := 0;
      for J := 0 to High(ADocument.FNodes) do
      begin
        LNode := ADocument.FNodes[J];
        if (LNode.FSupportId = ASurfaceId) and (LNode.FRole = LRole) then
        begin
          Inc(LCount);
        end;
      end;
      ARequest.FQuotas[I].FRole := LRole;
      ARequest.FQuotas[I].FMinimum := LCount;
      ARequest.FQuotas[I].FMaximum := LCount;
    end;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

end.
