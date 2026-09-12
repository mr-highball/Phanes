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
unit phanes.styles.selection;

{$mode delphi}
{$H+}

interface

uses
  CastleViewport,
  CastleBoxes;

procedure DrawStyleSelection(const AViewport: TCastleViewport; const ABounds: TBox3D;
  const ACssHeight: Single);

implementation

uses
  Math,
  CastleVectors,
  CastleColors,
  CastleRectangles,
  CastleGLUtils;

procedure DrawStyleSelection(const AViewport: TCastleViewport; const ABounds: TBox3D;
  const ACssHeight: Single);
var
  LPoints: array[0..7] of TVector3;
  LDistance: array[0..7] of Single;
  LCamera: TVector3;
  LDirection: TVector3;
  LUp: TVector3;
  LMin: TVector2;
  LMax: TVector2;
  LRect: TFloatRectangle;
  LDensity: Single;
  LNear: Single;
  LExtent: Single;
  LThickness: Single;
  LSeen: Boolean;
  LColor: TCastleColor;
  I: Integer;
  J: Integer;
  K: Integer;

  procedure IncludePoint(const APoint: TVector3);
  var
    LScreen: TVector2;
  begin
    LScreen := AViewport.PositionFromWorld(APoint);
    LScreen.X := LRect.Left + LScreen.X * LRect.Width / AViewport.EffectiveWidth;
    LScreen.Y := LRect.Bottom + LScreen.Y * LRect.Height / AViewport.EffectiveHeight;
    LMin.X := Min(LMin.X, LScreen.X);
    LMin.Y := Min(LMin.Y, LScreen.Y);
    LMax.X := Max(LMax.X, LScreen.X);
    LMax.Y := Max(LMax.Y, LScreen.Y);
    LSeen := True;
  end;

  procedure Bracket(const AX, AY, ADirectionX, ADirectionY: Single);
  var
    LX: Single;
    LY: Single;
  begin
    LX := AX;
    LY := AY;
    if ADirectionX < 0 then
    begin
      LX := AX - LExtent;
    end;
    if ADirectionY < 0 then
    begin
      LY := AY - LExtent;
    end;
    DrawRectangle(FloatRectangle(LX, AY - LThickness / 2, LExtent, LThickness), LColor);
    DrawRectangle(FloatRectangle(AX - LThickness / 2, LY, LThickness, LExtent), LColor);
  end;

begin
  if ABounds.IsEmpty or (AViewport.EffectiveWidth <= 0) or
    (AViewport.EffectiveHeight <= 0) then
  begin
    Exit;
  end;
  LRect := AViewport.RenderRect;
  LDensity := LRect.Height / Max(1, ACssHeight);
  AViewport.Camera.GetView(LCamera, LDirection, LUp);
  LNear := AViewport.Camera.ProjectionNear;
  LMin := Vector2(MaxSingle, MaxSingle);
  LMax := Vector2(-MaxSingle, -MaxSingle);
  LSeen := False;
  { Build a known bit-indexed box. Clip its twelve edges against the same
    camera near plane before projection, so close-up selections cannot flip
    to the opposite side of the screen. These are selection bounds, not an
    occlusion or surface silhouette claim. }
  for I := 0 to 7 do
  begin
    LPoints[I] := Vector3(ABounds.Data[I and 1].X,
      ABounds.Data[(I shr 1) and 1].Y, ABounds.Data[(I shr 2) and 1].Z);
    LDistance[I] := TVector3.DotProduct(LPoints[I] - LCamera, LDirection) - LNear;
    if LDistance[I] >= 0 then
    begin
      IncludePoint(LPoints[I]);
    end;
  end;
  for I := 0 to 7 do
  begin
    for K := 0 to 2 do
    begin
      J := I xor (1 shl K);
      if (I < J) and ((LDistance[I] < 0) <> (LDistance[J] < 0)) then
      begin
        IncludePoint(LPoints[I] + (LPoints[J] - LPoints[I]) *
          (LDistance[I] / (LDistance[I] - LDistance[J])));
      end;
    end;
  end;
  if not LSeen or (LMax.X < LRect.Left) or (LMin.X > LRect.Right) or
    (LMax.Y < LRect.Bottom) or (LMin.Y > LRect.Top) then
  begin
    Exit;
  end;
  LMin.X := Max(LRect.Left + 4 * LDensity, LMin.X - 4 * LDensity);
  LMin.Y := Max(LRect.Bottom + 4 * LDensity, LMin.Y - 4 * LDensity);
  LMax.X := Min(LRect.Right - 4 * LDensity, LMax.X + 4 * LDensity);
  LMax.Y := Min(LRect.Top - 4 * LDensity, LMax.Y + 4 * LDensity);
  LExtent := Min(12 * LDensity, Min(LMax.X - LMin.X, LMax.Y - LMin.Y) * 0.35);
  if LExtent <= 0 then
  begin
    Exit;
  end;
  { Filled strips avoid WebGL's implementation-dependent wide line support.
    Render after the ScreenEffect: coarse pixels and false-color treatments
    cannot erase the light/dark pair. None retains its existing rendering. }
  for I := 0 to 1 do
  begin
    if I = 0 then
    begin
      LThickness := 4.5 * LDensity;
      LColor := Vector4(0.055, 0.085, 0.09, 1);
    end else
    begin
      LThickness := 2 * LDensity;
      LColor := Vector4(0.86, 0.96, 0.65, 1);
    end;
    Bracket(LMin.X, LMin.Y, 1, 1);
    Bracket(LMax.X, LMin.Y, -1, 1);
    Bracket(LMin.X, LMax.Y, 1, -1);
    Bracket(LMax.X, LMax.Y, -1, -1);
  end;
end;

end.

