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

unit phanes.scene.picking;

{$mode delphi}
{$H+}

interface

uses
  CastleTransform,
  CastleVectors;

{ Return the nearest rendered face. Callers own the result. Non-selectable
  geometry still occludes objects; the root must exclude editor decorations. }
function VisibleRayCollision(const ARoot: TCastleTransform;
  const AOrigin, ADirection: TVector3): TRayCollision;

implementation

uses
  SysUtils,
  CastleShapes,
  X3DNodes;

type
  TPickingTransform = class(TCastleTransform);

function BackFacingHit(const ACollision: TRayCollision): Boolean;
var
  LHit: TRayCollisionNode;
  LGeometry: TAbstractGeometryNode;
  LDirection: TVector3;
  LDot: Single;
begin
  Result := False;
  LHit := ACollision[0];
  if LHit.Triangle = nil then
  begin
    Exit;
  end;
  LGeometry := TShape(LHit.Triangle^.InternalShape).OriginalGeometry;
  if not LGeometry.Solid then
  begin
    Exit;
  end;
  { CGE reports the ray in the hit transform's parent coordinates and the
    triangulated normal in scene coordinates. Honour winding and solidness. }
  LDirection := LHit.Item.InverseTransform.MultDirection(LHit.RayDirection);
  LDot := TVector3.DotProduct(LHit.Triangle^.SceneSpace.Normal, LDirection);
  if (LGeometry is TAbstractComposedGeometryNode) and
    not TAbstractComposedGeometryNode(LGeometry).Ccw then
  begin
    LDot := -LDot;
  end;
  Result := LDot > 0;
end;

function VisibleRayCollision(const ARoot: TCastleTransform;
  const AOrigin, ADirection: TVector3): TRayCollision;
var
  LOrigin: TVector3;
  LDirection: TVector3;
  LDistance: Single;
  I: Integer;
begin
  Result := nil;
  if ARoot = nil then
  begin
    Exit;
  end;
  LOrigin := AOrigin;
  LDirection := ADirection.Normalize;
  LDistance := 0;
  for I := 0 to 127 do
  begin
    Result := TPickingTransform(ARoot).RayCollision(LOrigin, LDirection, nil);
    if Result = nil then
    begin
      Exit;
    end;
    if not BackFacingHit(Result) then
    begin
      { Keep distance relative to the original near-plane ray even after
        stepping past invisible, back-facing triangles. }
      Result.Distance := Result.Distance + LDistance;
      Exit;
    end;
    LDistance := LDistance + Result.Distance + 0.000001;
    LOrigin := AOrigin + LDirection * LDistance;
    FreeAndNil(Result);
  end;
  { Exhausting the cap does not make the last culled face visible. }
end;

end.
