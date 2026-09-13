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
program PhanesCatalogRegionalProbe;

{$mode delphi}
{$H+}

uses
  JS, Web, SysUtils, Math, phanes.world.wire, phanes.world.types,
  phanes.world.landscape, phanes.world.placement, phanes.catalog.regional;

function Placement(const AData: TJSObject; const ACell: Integer): TJSObject;
var
  LWorld: TWorld;
  LLandscape: TLandscape;
  LProfile: TRegionalAssetAdmission;
  LX: Double;
  LZ: Double;
  LScale: Double;
begin
  LWorld := ReadWorld(AData);
  if (ACell < 0) or (ACell >= Length(LWorld.FLayers[4])) or
    not RegionalAssetAdmission(LWorld.FLayers[4][ACell], LProfile) then
  begin
    raise Exception.Create('A focused capture requires an admitted regional placement');
  end;
  LLandscape := TLandscape.Create;
  try
    LLandscape.SetWorld(LWorld);
    LX := (ACell mod (LWorld.FSize * 2) + 0.5 - LWorld.FSize) * 8;
    LZ := (ACell div (LWorld.FSize * 2) + 0.5 - LWorld.FSize) * 8;
    LScale := VegetationScale(ACell, 0);
    Result := TJSObject.new;
    Result['x'] := LX;
    Result['z'] := LZ;
    Result['ground'] := LLandscape.Height(LX, LZ);
    Result['y'] := LLandscape.Height(LX, LZ) + LProfile.FHeight * LScale / 2000;
    Result['extent'] := Max(LProfile.FHeight, Max(LProfile.FWidth, LProfile.FDepth)) * LScale / 1000;
  finally
    LLandscape.Free;
  end;
end;

begin
  TJSObject(window)['phanesRegionalCapturePlacement'] := @Placement;
end.
