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

unit phanes.world.shadowbounds;

{$mode delphi}
{$H+}

interface

uses
  CastleBoxes,
  CastleVectors;

{ Derive a finite extrusion from complete world bounds and the actual world-space
  shadow direction. Camera movement changes only the far bound, not extrusion.
  Does not change near/X/Y projection or camera position. }
procedure FiniteDirectionalShadowBounds(const ABounds: TBox3D;
  const ACameraPosition, ACameraDirection, AShadowDirection: TVector3;
  out ADistance, AFar: Single);

implementation

uses
  SysUtils,
  Math;

procedure FiniteDirectionalShadowBounds(const ABounds: TBox3D;
  const ACameraPosition, ACameraDirection, AShadowDirection: TVector3;
  out ADistance, AFar: Single);
const
  CInputMargin = 16 * 1.1920928955078125E-7;
var
  LDirection: TVector3Double;
  LShadow: TVector3Double;
  LCamera: TVector3Double;
  LExtent: Double;
  LCoordinateScale: Double;
  LRequiredDistance: Double;
  LAxisDistance: Double;
  LHaveDistance: Boolean;
  LDistance: Double;
  LDepth: Double;
  LFar: Double;
  LDirectionLength: Double;
  LSupport: Double;
  I: Integer;
begin
  LCoordinateScale := 1;
  for I := 0 to 2 do
  begin
    if IsNan(ABounds.Data[0][I]) or IsInfinite(ABounds.Data[0][I]) or
      IsNan(ABounds.Data[1][I]) or IsInfinite(ABounds.Data[1][I]) or
      IsNan(ACameraPosition[I]) or IsInfinite(ACameraPosition[I]) or
      IsNan(ACameraDirection[I]) or IsInfinite(ACameraDirection[I]) or
      IsNan(AShadowDirection[I]) or IsInfinite(AShadowDirection[I]) then
    begin
      raise EArgumentException.Create('Finite shadow bounds require finite coordinates.');
    end;
    LExtent := Double(ABounds.Data[1][I]) - ABounds.Data[0][I];
    if LExtent < 0 then
    begin
      raise EArgumentException.Create('Finite shadow bounds are inverted.');
    end;
    LCoordinateScale := Max(LCoordinateScale, Max(Abs(ABounds.Data[0][I]),
      Abs(ABounds.Data[1][I])));
  end;
  LShadow := Vector3Double(AShadowDirection);
  LDirectionLength := LShadow.Length;
  if LDirectionLength = 0 then
  begin
    raise EArgumentException.Create('Finite shadow bounds require a shadow direction.');
  end;
  LShadow := LShadow / LDirectionLength;
  LRequiredDistance := 0;
  LHaveDistance := False;
  for I := 0 to 2 do
  begin
    if LShadow[I] <> 0 then
    begin
      LExtent := Double(ABounds.Data[1][I]) - ABounds.Data[0][I];
      LAxisDistance := (LExtent + CInputMargin * LCoordinateScale) / Abs(LShadow[I]);
      if not LHaveDistance or (LAxisDistance < LRequiredDistance) then
      begin
        LRequiredDistance := LAxisDistance;
        LHaveDistance := True;
      end;
    end;
  end;
  { Separation on one coordinate axis is sufficient: each parallel shadow ray
    moves monotonically on that axis and cannot return to the receiver box after
    its endpoint. Taking the shortest axis bound avoids very long, thin volumes
    in wide shallow worlds. The margin covers Single extrusion/endpoint rounding;
    strict upward quantization keeps the translated box separated and reduces
    cache rebuilds from small geometry changes. }
  if not LHaveDistance or IsNan(LRequiredDistance) or IsInfinite(LRequiredDistance) or
    (LRequiredDistance > 1.0E30) then
  begin
    raise EArgumentException.Create('World bounds exceed finite shadow coordinate support.');
  end;
  LDistance := 1;
  while LDistance <= LRequiredDistance do
  begin
    LDistance := LDistance * 2;
    if LDistance > 1.0E30 then
    begin
      raise EArgumentException.Create('World bounds exceed finite shadow coordinate support.');
    end;
  end;
  LDirection := Vector3Double(ACameraDirection);
  LDirectionLength := LDirection.Length;
  if LDirectionLength = 0 then
  begin
    raise EArgumentException.Create('Finite shadow bounds require a camera direction.');
  end;
  LDirection := LDirection / LDirectionLength;
  LCamera := Vector3Double(ACameraPosition);
  LDepth := 0;
  for I := 0 to 2 do
  begin
    if LDirection[I] >= 0 then
    begin
      LSupport := ABounds.Data[1][I];
    end
    else
    begin
      LSupport := ABounds.Data[0][I];
    end;
    LDepth := LDepth + LDirection[I] * (LSupport - LCamera[I]);
    LCoordinateScale := Max(LCoordinateScale, Abs(LCamera[I]));
  end;
  { Extrusion adds no more than D to camera depth, regardless of sun direction.
    Include all scene geometry and the finite caps, with a rounding margin. }
  LFar := Max(1, LDepth + LDistance) +
    CInputMargin * (LCoordinateScale + LDistance + Abs(LDepth));
  if (LDistance > 1.0E30) or (LFar > 1.0E30) then
  begin
    raise EArgumentException.Create('World bounds exceed finite shadow coordinate support.');
  end;
  ADistance := LDistance;
  AFar := LFar;
end;

end.
