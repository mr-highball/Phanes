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
unit phanes.composition.contents.types;
{$mode delphi}
{$H+}

interface

type
  TContentNames = array of String;

  { An admitted usable support in one object's local frame. Surface instances
    are optional, preserving old saves; when present their geometry is exact. }
  TContentSupport = record
    FKey: String;
    FName: UnicodeString;
    FRole: String;
    FAssetId: String;
    FX: Integer;
    FY: Integer;
    FZ: Integer;
    FQuarterTurn: Integer;
    FWidth: Integer;
    FDepth: Integer;
    FHeadroom: Integer;
    FAllowedRoles: TContentNames;
  end;
  TContentSupports = array of TContentSupport;

  { Admission describes one independently addressable instance, with an upright
    bounding envelope measured in millimetres. A grouped mesh is not one book. }
  TContentAsset = record
    FId: String;
    FName: UnicodeString;
    FRole: String;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FSingleInstance: Boolean;
    FSupports: TContentSupports;
  end;
  TContentAssets = array of TContentAsset;

  { An explicit, non-overlapping usable volume in the surface's local frame.
    X/Z is the centre, Y=0 the support plane. Its object ID survives replacement.
    Slots are reserved volumes, not a world-wide fine grid. }
  TContentSlot = record
    FObjectId: String;
    FX: Integer;
    FZ: Integer;
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FQuarterTurn: Integer;
    FAllowedRoles: TContentNames;
    FAllowedAssets: TContentNames;
    FAllowEmpty: Boolean;
  end;
  TContentSlots = array of TContentSlot;

  TContentQuota = record
    FRole: String;
    FMinimum: Integer;
    FMaximum: Integer;
  end;
  TContentQuotas = array of TContentQuota;

  TContentRequest = record
    FSurfaceId: String;
    FScopeId: String;
    FExpectedRevision: Integer;
    FSeed: Cardinal;
    FSurfaceWidth: Integer;
    FSurfaceDepth: Integer;
    FHeadroom: Integer;
    FSlots: TContentSlots;
    FAssets: TContentAssets;
    FQuotas: TContentQuotas;
    { Ordinary reimagination retains occupied assemblies. A caller must express
      count reduction/removal and movement separately from random regeneration. }
    FRemovableAssemblyRoles: TContentNames;
    FAllowAssemblyMoves: Boolean;
  end;

function ContentAssetIndex(const AAssets: TContentAssets; const AId: String): Integer;
function ContentSlotIndex(const ASlots: TContentSlots; const AId: String): Integer;
function ContentRoleAllowed(const ARoles: TContentNames; const ARole: String): Boolean;

implementation

function ContentAssetIndex(const AAssets: TContentAssets; const AId: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AAssets) do
  begin
    if AAssets[I].FId = AId then
    begin
      Exit(I);
    end;
  end;
  Result := -1;
end;

function ContentSlotIndex(const ASlots: TContentSlots; const AId: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ASlots) do
  begin
    if ASlots[I].FObjectId = AId then
    begin
      Exit(I);
    end;
  end;
  Result := -1;
end;

function ContentRoleAllowed(const ARoles: TContentNames; const ARole: String): Boolean;
var
  LRole: String;
begin
  for LRole in ARoles do
  begin
    if LRole = ARole then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

end.
