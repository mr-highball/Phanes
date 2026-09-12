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

unit phanes.interiors.food.scene;

{$mode delphi}
{$H+}

interface

uses
  CastleTransform,
  CastleVectors;

procedure CreateFoodModel(const AParent: TCastleTransform;
  const AShape: String; const AColour: TVector3);

implementation

uses
  Math,
  SysUtils,
  CastleScene,
  CastleRenderOptions,
  X3DNodes,
  X3DFields;

function FoodDetail(const AKind: Integer): TEffectNode;
var
  LVertex: TEffectPartNode;
  LFragment: TEffectPartNode;
begin
  Result := TEffectNode.Create;
  Result.Language := slGLSL;
  Result.AddCustomField(TSFFloat.Create(Result, True, 'phanesFoodKind', AKind));
  LVertex := TEffectPartNode.Create;
  LVertex.ShaderType := stVertex;
  LVertex.Contents :=
    'varying highp vec3 phanesFoodPosition;' + LineEnding +
    'void PLUG_vertex_object_space(const in vec4 p,inout vec3 n) {' + LineEnding +
    ' phanesFoodPosition=p.xyz; }';
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  { Original millimetre surface detail; no texture download or displacement.
    Coarse pores remain legible while subpixel freckles fade with distance. }
  LFragment.Contents :=
    'varying highp vec3 phanesFoodPosition;' + LineEnding +
    'uniform float phanesFoodKind;' + LineEnding +
    'float phanesFoodHash(vec3 p) {' + LineEnding +
    ' p=fract(p*0.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }' + LineEnding +
    'void PLUG_main_texture_apply(inout vec4 c,const in vec3 n) {' + LineEnding +
    ' vec3 p=phanesFoodPosition; float pixel=max(length(dFdx(p)),length(dFdy(p)));' + LineEnding +
    ' float fine=1.0-smoothstep(0.0002,0.0015,pixel);' + LineEnding +
    ' vec3 q=p*1100.0; vec3 cell=floor(q); float grain=phanesFoodHash(cell);' + LineEnding +
    ' float pore=1.0-smoothstep(0.10,0.28,length(fract(q)-0.5));' + LineEnding +
    ' if(phanesFoodKind<1.5) {' + LineEnding +
    '  float crumb=1.0-smoothstep(0.0,0.003,abs(p.y-0.016));' + LineEnding +
    '  c.rgb=mix(c.rgb,vec3(0.80,0.64,0.39),crumb*0.8);' + LineEnding +
    '  c.rgb*=1.0-fine*pore*step(0.6,grain)*0.50;' + LineEnding +
    ' } else if(phanesFoodKind<2.5) {' + LineEnding +
    '  c.rgb*=0.92+0.08*sin(p.y*180.0+p.x*80.0);' + LineEnding +
    '  c.rgb=mix(c.rgb,vec3(0.88,0.70,0.37),fine*pore*step(0.75,grain)*0.35);' + LineEnding +
    ' } else {' + LineEnding +
    '  c.rgb*=1.0-fine*pore*step(0.7,grain)*0.20;' + LineEnding +
    '  float rind=1.0-smoothstep(0.0,0.003,abs(p.z-0.022));' + LineEnding +
    '  c.rgb=mix(c.rgb,vec3(0.65,0.40,0.12),rind*0.65);' + LineEnding +
    '  if(phanesFoodKind>3.5) {' + LineEnding +
    '   vec3 h=p*440.0; float seed=phanesFoodHash(floor(h));' + LineEnding +
    '   vec3 leaf=fract(h)-0.5; leaf.x*=0.65; leaf.z*=1.3;' + LineEnding +
    '   float fleck=(1.0-smoothstep(0.16,0.31,length(leaf)))*step(0.54,seed);' + LineEnding +
    '   float visible=1.0-smoothstep(0.0006,0.0025,pixel);' + LineEnding +
    '   c.rgb=mix(c.rgb,vec3(0.13,0.24,0.045),fleck*visible*0.90);' + LineEnding +
    '  }' + LineEnding +
    ' } }' + LineEnding +
    'void PLUG_material_metallic_roughness(inout float m,inout float r) {' + LineEnding +
    ' m=0.0; r=0.72; if(phanesFoodKind>1.5 && phanesFoodKind<2.5) r=0.34; }';
  Result.SetParts([LVertex, LFragment]);
end;

procedure AddMesh(const AParent: TCastleTransform; const APoints: TCoordinateNode;
  const AMesh: TIndexedTriangleSetNode; const AColour: TVector3; const AKind: Integer);
var
  LMaterial: TPhysicalMaterialNode;
  LAppearance: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
  LScene: TCastleScene;
begin
  AMesh.Coord := APoints;
  LMaterial := TPhysicalMaterialNode.Create;
  LMaterial.BaseColor := AColour;
  LMaterial.Metallic := 0;
  LMaterial.Roughness := 0.7;
  LAppearance := TAppearanceNode.Create;
  LAppearance.Material := LMaterial;
  LShape := TShapeNode.Create;
  LShape.Geometry := AMesh;
  LShape.Appearance := LAppearance;
  LRoot := TX3DRootNode.Create;
  LRoot.AddChildren(LShape);
  LScene := TCastleScene.Create(AParent);
  LScene.Load(LRoot, True);
  LScene.PreciseCollisions := True;
  LScene.SetEffects([FoodDetail(AKind)]);
  AParent.Add(LScene);
end;

procedure Fruit(const AParent: TCastleTransform; const APear: Boolean; const AColour: TVector3);
const
  CAppleRadii: array[0..10] of Single =
    (0, 0.009, 0.015, 0.019, 0.0195, 0.0195, 0.018, 0.014, 0.009, 0.004, 0);
  CAppleHeights: array[0..10] of Single =
    (0, 0.004, 0.008, 0.012, 0.016, 0.022, 0.028, 0.034, 0.038, 0.037, 0.035);
  CPearRadii: array[0..10] of Single =
    (0, 0.008, 0.015, 0.0195, 0.0195, 0.017, 0.012, 0.008, 0.006, 0.003, 0);
var
  LPoints: TCoordinateNode;
  LMesh: TIndexedTriangleSetNode;
  LStem: TCastleCylinder;
  LRadius: Single;
  LAngle: Single;
  LHeight: Single;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  LPoints := TCoordinateNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  for J := 0 to 10 do
  begin
    LHeight := J * 0.004;
    if not APear then
    begin
      LHeight := CAppleHeights[J];
    end;
    for I := 0 to 48 do
    begin
      LAngle := I / 48 * 2 * Pi;
      LRadius := CAppleRadii[J];
      if APear then
      begin
        LRadius := CPearRadii[J];
      end;
      LRadius := LRadius * (1 - 0.018 * Cos(5 * LAngle));
      LPoints.FdPoint.Items.Add(Vector3(Cos(LAngle) * LRadius,
        LHeight, Sin(LAngle) * LRadius));
    end;
  end;
  for J := 0 to 9 do
  begin
    for I := 0 to 47 do
    begin
      LAt := J * 49 + I;
      LMesh.FdIndex.Items.Add(LAt);
      LMesh.FdIndex.Items.Add(LAt + 49);
      LMesh.FdIndex.Items.Add(LAt + 1);
      LMesh.FdIndex.Items.Add(LAt + 1);
      LMesh.FdIndex.Items.Add(LAt + 49);
      LMesh.FdIndex.Items.Add(LAt + 50);
    end;
  end;
  AddMesh(AParent, LPoints, LMesh, AColour, 2);
  LStem := TCastleCylinder.Create(AParent);
  LStem.Radius := 0.0014;
  LStem.Height := 0.009;
  LStem.Translation := Vector3(0, 0.0435, 0);
  if not APear then
  begin
    LStem.Height := 0.011;
    LStem.Translation := Vector3(0.0004, 0.0395, 0);
    LStem.Rotation := Vector4(0, 0, 1, -0.18);
  end;
  LStem.Color := Vector4(0.20, 0.12, 0.045, 1);
  LStem.Material := pmPhysical;
  LStem.PreciseCollisions := True;
  AParent.Add(LStem);
end;

procedure Portion(const AParent: TCastleTransform; const ABread, AHerb: Boolean;
  const AColour: TVector3);
var
  LPoints: TCoordinateNode;
  LMesh: TIndexedTriangleSetNode;
  LOutline: array of TVector2;
  LAngle: Single;
  LRadius: Single;
  LHeight: Single;
  LCenterX: Single;
  LCenterZ: Single;
  LAt: Integer;
  LNext: Integer;
  LCount: Integer;
  I: Integer;

  procedure Triangle(const AFirst, ASecond, AThird: TVector3);
  begin
    LAt := LPoints.FdPoint.Items.Count;
    LPoints.FdPoint.Items.Add(AFirst);
    LPoints.FdPoint.Items.Add(ASecond);
    LPoints.FdPoint.Items.Add(AThird);
    LMesh.FdIndex.Items.Add(LAt);
    LMesh.FdIndex.Items.Add(LAt + 1);
    LMesh.FdIndex.Items.Add(LAt + 2);
  end;

  function Point(const AIndex: Integer; const AY: Single): TVector3;
  begin
    Result := Vector3(LOutline[AIndex].X, AY, LOutline[AIndex].Y);
  end;

begin
  LPoints := TCoordinateNode.Create;
  LMesh := TIndexedTriangleSetNode.Create;
  LHeight := 0.022;
  if ABread then
  begin
    LHeight := 0.016;
    SetLength(LOutline, 32);
    for I := 0 to 31 do
    begin
      LAngle := (I div 8) * Pi / 2 + (I mod 8) / 7 * Pi / 2;
      LCenterX := 0.017;
      LCenterZ := 0.035;
      if (I div 8 = 1) or (I div 8 = 2) then
      begin
        LCenterX := -LCenterX;
      end;
      if I div 8 >= 2 then
      begin
        LCenterZ := -LCenterZ;
      end;
      LRadius := 0.008;
      LOutline[I] := Vector2(LCenterX + Cos(LAngle) * LRadius,
        LCenterZ + Sin(LAngle) * LRadius);
    end;
  end
  else
  begin
    SetLength(LOutline, 3);
    LOutline[0] := Vector2(0, -0.022);
    LOutline[1] := Vector2(0.021, 0.022);
    LOutline[2] := Vector2(-0.021, 0.022);
  end;
  LCount := Length(LOutline);
  for I := 0 to LCount - 1 do
  begin
    LNext := (I + 1) mod LCount;
    Triangle(Vector3(0, LHeight, 0), Point(LNext, LHeight), Point(I, LHeight));
    Triangle(Vector3(0, 0, 0), Point(I, 0), Point(LNext, 0));
    Triangle(Point(I, 0), Point(I, LHeight), Point(LNext, 0));
    Triangle(Point(LNext, 0), Point(I, LHeight), Point(LNext, LHeight));
  end;
  if ABread then
  begin
    AddMesh(AParent, LPoints, LMesh, AColour, 1);
  end
  else if AHerb then
  begin
    AddMesh(AParent, LPoints, LMesh, AColour, 4);
  end
  else
  begin
    AddMesh(AParent, LPoints, LMesh, AColour, 3);
  end;
end;

procedure CreateFoodModel(const AParent: TCastleTransform;
  const AShape: String; const AColour: TVector3);
begin
  if (AShape = 'apple') or (AShape = 'pear') then
  begin
    Fruit(AParent, AShape = 'pear', AColour);
  end
  else
  begin
    Portion(AParent, AShape = 'bread', AShape = 'herb-cheese', AColour);
  end;
end;

end.
