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

unit phanes.tools.fingerprint;

{$mode delphi}
{$H+}

interface

uses
  CastleScene;

function StaticGeometryHash(const AScene: TCastleScene): String;

implementation

uses
  Classes,
  SysUtils,
  Math,
  CastleShapes,
  CastleVectors,
  CastleTriangles,
  phanes.tools.files;

type
  TGeometryFingerprint = class
  private
    FMinimum: array[0..2] of Double;
    FMaximum: array[0..2] of Double;
    FTransform: TMatrix4;
    FSpan: Double;
    FTriangles: TStringList;
    FPositions: TTriangle3List;
    procedure Triangle(AShape: TObject; const APosition: TTriangle3;
      const ANormal: TTriangle3; const ATexCoord: TTriangle4; const AFace: TFaceIndex);
    procedure EncodeTriangle(const APosition: TTriangle3);
  public
    function Calculate(const AScene: TCastleScene): String;
  end;

procedure TGeometryFingerprint.Triangle(AShape: TObject; const APosition: TTriangle3;
  const ANormal: TTriangle3; const ATexCoord: TTriangle4; const AFace: TFaceIndex);
var
  LPosition: TTriangle3;
  LValue: Double;
  I: Integer;
  J: Integer;
begin
  Require(FPositions.Count < 1000000, 'Static geometry fingerprint exceeds triangle budget');
  LPosition := APosition.Transform(FTransform);
  for I := 0 to 2 do
  begin
    for J := 0 to 2 do
    begin
      LValue := LPosition.Data[I].Data[J];
      Require(not IsNan(LValue) and not IsInfinite(LValue), 'Nonfinite fingerprint triangle');
      FMinimum[J] := Min(FMinimum[J], LValue);
      FMaximum[J] := Max(FMaximum[J], LValue);
    end;
  end;
  FPositions.Add(LPosition);
end;

procedure TGeometryFingerprint.EncodeTriangle(const APosition: TTriangle3);
var
  LVertices: array[0..2] of String;
  LValue: Double;
  LTemporary: String;
  I: Integer;
  J: Integer;
begin
  for I := 0 to 2 do
  begin
    LVertices[I] := '';
    for J := 0 to 2 do
    begin
      LValue := (Double(APosition.Data[I].Data[J]) -
        (FMinimum[J] + FMaximum[J]) * 0.5) / FSpan;
      Require(not IsNan(LValue) and not IsInfinite(LValue) and
        (Abs(LValue) <= 0.5001), 'Triangle lies outside finite scene fingerprint bounds');
      LVertices[I] := LVertices[I] + IntToHex(Round(LValue * 1000000) + 1000000, 6);
    end;
  end;
  { A shape fingerprint ignores winding, vertex/index order and materials.
    Sorted triangles preserve multiplicity. It is only a grouping aid for the
    current pose, not proof of equal animation, normals, UVs or gameplay. }
  for I := 0 to 1 do
  begin
    for J := I + 1 to 2 do
    begin
      if LVertices[I] > LVertices[J] then
      begin
        LTemporary := LVertices[I];
        LVertices[I] := LVertices[J];
        LVertices[J] := LTemporary;
      end;
    end;
  end;
  FTriangles.Add(LVertices[0] + LVertices[1] + LVertices[2]);
end;

function TGeometryFingerprint.Calculate(const AScene: TCastleScene): String;
var
  LShapes: TShapeList;
  LBytes: TBytes;
  LText: UTF8String;
  I: Integer;
begin
  FTransform := AScene.Transform;
  for I := 0 to 2 do
  begin
    FMinimum[I] := Infinity;
    FMaximum[I] := NegInfinity;
  end;
  FPositions := TTriangle3List.Create;
  FTriangles := TStringList.Create;
  try
    FTriangles.CaseSensitive := True;
    FTriangles.UseLocale := False;
    FTriangles.LineBreak := #10;
    LShapes := AScene.Shapes.TraverseList(True, True, False);
    for I := 0 to LShapes.Count - 1 do
    begin
      LShapes[I].Triangulate(Triangle);
    end;
    Require(FPositions.Count > 0, 'No visible static triangles for fingerprint');
    { Normalize only the collected rendered triangles. Accessor/scene bounds
      can also contain unused vertices and live in a different transform frame. }
    FSpan := Max(FMaximum[0] - FMinimum[0],
      Max(FMaximum[1] - FMinimum[1], FMaximum[2] - FMinimum[2]));
    Require(FSpan > 1.0e-12, 'Cannot normalize zero-sized scene geometry');
    for I := 0 to FPositions.Count - 1 do
    begin
      EncodeTriangle(FPositions[I]);
    end;
    Require(FTriangles.Count > 0, 'No visible static triangles for fingerprint');
    FTriangles.Sort;
    LText := UTF8String('phanes.static.geometry.v1' + #10 + FTriangles.Text);
    SetLength(LBytes, Length(LText));
    Move(LText[1], LBytes[0], Length(LText));
    Result := HashBytes(LBytes);
  finally
    FTriangles.Free;
    FPositions.Free;
  end;
end;

function StaticGeometryHash(const AScene: TCastleScene): String;
var
  LFingerprint: TGeometryFingerprint;
begin
  LFingerprint := TGeometryFingerprint.Create;
  try
    Result := LFingerprint.Calculate(AScene);
  finally
    LFingerprint.Free;
  end;
end;

end.
