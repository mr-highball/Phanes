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
unit phanes.interiors.materials;
{$mode delphi}
{$H+}

interface

uses
  X3DNodes,
  CastleBoxes;

type
  TInteriorFootprints = array of TBox3D;

const
  InteriorWood = 1;
  InteriorPlaster = 2;
  InteriorCloth = 3;
  InteriorCeramic = 4;
  InteriorMetal = 5;

{ Shared immutable material effect. Callers attach it without changing its fields. }
function InteriorDetail(const AKind: Integer; const AExteriorWood: Boolean = False;
  const AStaticBatch: Boolean = False): TEffectNode;
function InteriorFloorDetail(const AFootprints: TInteriorFootprints): TEffectNode;
function ModularFloorDetail(const AStone: Boolean): TEffectNode;

implementation

uses
  SysUtils,
  X3DFields,
  CastleVectors,
  CastleRenderOptions;

var
  GDetails: array[InteriorWood..InteriorMetal, Boolean, Boolean] of TEffectNode;
  GFloorDetails: array[Boolean] of TEffectNode;

function InteriorFloorDetail(const AFootprints: TInteriorFootprints): TEffectNode;
var
  LVertex: TEffectPartNode;
  LFragment: TEffectPartNode;
  LUniforms: String;
  LContacts: String;
  LName: String;
  I: Integer;
begin
  Result := TEffectNode.Create;
  Result.Language := slGLSL;
  LUniforms := '';
  LContacts := '';
  for I := 0 to High(AFootprints) do
  begin
    LName := 'phanesFloorObject' + IntToStr(I);
    Result.AddCustomField(TSFVec4f.Create(Result, True, LName,
      Vector4(AFootprints[I].Center.X, AFootprints[I].Center.Z,
      AFootprints[I].SizeX * 0.5, AFootprints[I].SizeZ * 0.5)));
    LUniforms := LUniforms + 'uniform vec4 ' + LName + ';' + LineEnding;
    LContacts := LContacts + ' shade*=phanesFloorContact(p,' + LName + ');' + LineEnding;
  end;
  LVertex := TEffectPartNode.Create;
  LVertex.ShaderType := stVertex;
  LVertex.Contents :=
    'varying highp vec2 phanesFloorPosition;' + LineEnding +
    'void PLUG_vertex_object_space(const in vec4 p,inout vec3 n) {' + LineEnding +
    ' phanesFloorPosition=p.xz; }';
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  { The continuous floor has filtered millimetre joints, not geometric cracks.
    Contact attenuation is an explicit local approximation using each admitted
    furniture envelope. It is not a light-space shadow map or SSAO.
    Rebuilding from placed bounds keeps it aligned after an imported layout. }
  LFragment.Contents :=
    'varying highp vec2 phanesFloorPosition;' + LineEnding + LUniforms +
    'float phanesFloorContact(vec2 p,vec4 b) {' + LineEnding +
    ' vec2 q=abs(p-b.xy); vec2 outside=max(q-b.zw,vec2(0));' + LineEnding +
    ' float broad=exp(-dot(outside,outside)*12.0)*0.16;' + LineEnding +
    ' vec2 foot=q-b.zw*0.84;' + LineEnding +
    ' float tight=exp(-dot(foot,foot)*95.0)*0.36;' + LineEnding +
    ' return 1.0-broad-tight; }' + LineEnding +
    'void PLUG_main_texture_apply(inout vec4 c,const in vec3 n) {' + LineEnding +
    ' vec2 p=phanesFloorPosition;' + LineEnding +
    ' vec2 q=(p+4.7)/vec2(0.235,1.8); float row=floor(q.x);' + LineEnding +
    ' q.y+=mod(row,3.0)*0.37; vec2 f=fract(q);' + LineEnding +
    ' vec2 edge=min(f,1.0-f)*vec2(0.235,1.8);' + LineEnding +
    ' vec2 pixel=max(abs(dFdx(p))+abs(dFdy(p)),vec2(0.00001));' + LineEnding +
    ' vec2 seam=clamp((0.001+pixel*0.5-edge)/pixel,0.0,1.0);' + LineEnding +
    ' float board=fract(sin(dot(vec2(row,floor(q.y)),vec2(12.9898,78.233)))*43758.5453);' + LineEnding +
    ' float shade=1.0;' + LineEnding + LContacts +
    ' shade*=1.0-0.18*exp(-max(0.0,4.6+p.y)*7.0);' + LineEnding +
    ' shade*=1.0-0.14*exp(-max(0.0,4.6+p.x)*7.0);' + LineEnding +
    ' c.rgb*=mix(0.94,1.06,board)*(1.0-0.32*max(seam.x,seam.y))*shade;' + LineEnding +
    '}';
  Result.SetParts([LVertex, LFragment]);
end;

function CreateInteriorDetail(const AKind: Integer; const AExteriorWood,
  AStaticBatch: Boolean): TEffectNode;
var
  LVertex: TEffectPartNode;
  LFragment: TEffectPartNode;
  LWoodField: String;
begin
  LWoodField :=
    { Keep irregular broad variation quiet, with millimetre fibres visible only
      at close range. Regular five-centimetre bands dominated walking views.
      Two noise evaluations retain the former field's sampling cost. }
    '  float micro=1.0-smoothstep(0.0007,0.003,pixel);' + LineEnding +
    '  float broad=phanesDetailNoise(p*vec3(14.0,3.0,0.35));' + LineEnding +
    '  float fibres=phanesDetailNoise(p*vec3(340.0,35.0,4.0));' + LineEnding +
    '  return 0.5+0.06*(broad-0.5)+0.12*(fibres-0.5)*micro;' + LineEnding;
  if AExteriorWood then
  begin
    { Painted exterior timber needs subdued, irregular fibres at millimetre
      scale. Periodic five-centimetre bands read as corrugated sheet metal. }
    LWoodField :=
      '  float micro=1.0-smoothstep(0.0005,0.003,pixel);' + LineEnding +
      '  float grain=phanesDetailNoise(p*vec3(320.0,2.5,320.0));' + LineEnding +
      '  float fibre=phanesDetailNoise(p*vec3(1500.0,18.0,1500.0));' + LineEnding +
      '  float broad=phanesDetailNoise(p*vec3(5.0,0.7,5.0));' + LineEnding +
      '  return 0.52+0.07*(grain-0.5)*fine+' +
      '0.06*(fibre-0.5)*micro+0.12*(broad-0.5);' + LineEnding;
  end;
  Result := TEffectNode.Create;
  Result.Language := slGLSL;
  Result.AddCustomField(TSFFloat.Create(Result, True, 'phanesDetailKind', AKind));
  LVertex := TEffectPartNode.Create;
  LVertex.ShaderType := stVertex;
  LVertex.Contents :=
    'varying highp vec3 phanesDetailPosition;' + LineEnding +
    'varying highp vec3 phanesDetailEye;' + LineEnding +
    'void PLUG_vertex_object_space(const in vec4 p, inout vec3 n) {' + LineEnding +
    ' vec3 s=vec3(length(castle_ModelViewMatrix[0].xyz),' +
    'length(castle_ModelViewMatrix[1].xyz),length(castle_ModelViewMatrix[2].xyz));' + LineEnding +
    ' phanesDetailPosition=p.xyz*s;' + LineEnding +
    ' phanesDetailEye=(castle_ModelViewMatrix*p).xyz;' + LineEnding +
    '}';
  if AStaticBatch then
  begin
    LVertex.Contents :=
      'attribute vec3 phanesOriginalSurface;' + LineEnding +
      'varying highp vec3 phanesDetailPosition;' + LineEnding +
      'varying highp vec3 phanesDetailEye;' + LineEnding +
      'void PLUG_vertex_object_space(const in vec4 p, inout vec3 n) {' + LineEnding +
      ' vec3 s=vec3(length(castle_ModelViewMatrix[0].xyz),' +
      'length(castle_ModelViewMatrix[1].xyz),length(castle_ModelViewMatrix[2].xyz));' + LineEnding +
      ' phanesDetailPosition=phanesOriginalSurface*s;' + LineEnding +
      ' phanesDetailEye=(castle_ModelViewMatrix*p).xyz;' + LineEnding +
      '}';
  end;
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  { Original analytic material fields in local physical metres. The pixel
    footprint fades fine detail before it aliases; derivative bump mapping
    perturbs the lighting normal without displacing admitted geometry.
    GPU material code is a binding; catalog and placement policy remain Pascal. }
  LFragment.Contents :=
    'varying highp vec3 phanesDetailPosition;' + LineEnding +
    'varying highp vec3 phanesDetailEye;' + LineEnding +
    'uniform float phanesDetailKind;' + LineEnding +
    'highp float phanesDetailHash(highp vec3 p) {' + LineEnding +
    ' p=fract(p*0.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }' + LineEnding +
    'highp float phanesDetailNoise(highp vec3 p) {' + LineEnding +
    ' highp vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);' + LineEnding +
    ' return mix(mix(mix(phanesDetailHash(i),phanesDetailHash(i+vec3(1,0,0)),f.x),' + LineEnding +
    ' mix(phanesDetailHash(i+vec3(0,1,0)),phanesDetailHash(i+vec3(1,1,0)),f.x),f.y),' + LineEnding +
    ' mix(mix(phanesDetailHash(i+vec3(0,0,1)),phanesDetailHash(i+vec3(1,0,1)),f.x),' + LineEnding +
    ' mix(phanesDetailHash(i+vec3(0,1,1)),phanesDetailHash(i+vec3(1,1,1)),f.x),f.y),f.z); }' + LineEnding +
    'highp float phanesDetailField() {' + LineEnding +
    ' highp vec3 p=phanesDetailPosition;' + LineEnding +
    ' highp float pixel=max(length(dFdx(p)),length(dFdy(p)));' + LineEnding +
    ' float fine=1.0-smoothstep(0.001,0.012,pixel);' + LineEnding +
    ' if(phanesDetailKind<1.5) {' + LineEnding +
    LWoodField +
    ' }' + LineEnding +
    ' if(phanesDetailKind<2.5) return 0.5+0.20*(phanesDetailNoise(p*7.0)-0.5)+' +
    '0.20*(phanesDetailNoise(p*125.0)-0.5)*fine;' + LineEnding +
    ' if(phanesDetailKind<3.5) return 0.5+0.25*fine*sin(p.x*1700.0)*sin(p.y*1700.0);' + LineEnding +
    ' return 0.5+0.12*fine*(phanesDetailNoise(p*240.0)-0.5);' + LineEnding +
    '}' + LineEnding +
    'void PLUG_main_texture_apply(inout vec4 c, const in vec3 n) {' + LineEnding +
    ' float h=phanesDetailField();' + LineEnding +
    ' if(phanesDetailKind<1.5) c.rgb*=0.72+0.52*h;' + LineEnding +
    ' else if(phanesDetailKind<2.5) c.rgb*=0.84+0.24*h;' + LineEnding +
    ' else c.rgb*=0.94+0.12*h;' + LineEnding +
    '}' + LineEnding +
    'void PLUG_material_metallic_roughness(inout float m,inout float r) {' + LineEnding +
    ' float h=phanesDetailField();' + LineEnding +
    ' if(phanesDetailKind<4.5) m=0.0;' + LineEnding +
    ' if(phanesDetailKind<1.5) r=mix(r,0.48+0.20*h,0.7);' + LineEnding +
    ' else if(phanesDetailKind<2.5) r=0.84+0.08*h;' + LineEnding +
    ' else if(phanesDetailKind<3.5) r=0.68+0.08*h;' + LineEnding +
    ' else if(phanesDetailKind<4.5) r=0.20+0.05*h;' + LineEnding +
    ' else {m=0.85; r=0.24;}' + LineEnding +
    '}' + LineEnding +
    'void PLUG_fragment_eye_space(const in vec4 p,inout vec3 n) {' + LineEnding +
    ' highp float amount=0.00018;' + LineEnding +
    ' if(phanesDetailKind>1.5 && phanesDetailKind<2.5) amount=0.0007;' + LineEnding +
    ' if(phanesDetailKind>2.5) amount=0.000025;' + LineEnding +
    ' highp float h=phanesDetailField()*amount;' + LineEnding +
    ' highp vec3 b=normalize(n);' + LineEnding +
    ' highp vec3 dx=dFdx(phanesDetailEye),dy=dFdy(phanesDetailEye);' + LineEnding +
    ' highp vec3 r1=cross(dy,b),r2=cross(b,dx); highp float det=dot(dx,r1);' + LineEnding +
    ' highp vec3 dh=dFdx(h)*r1+dFdy(h)*r2;' + LineEnding +
    ' if(abs(det)>1.0e-12) {' + LineEnding +
    '  highp vec3 g=dh/det;' + LineEnding +
    '  highp float g2=dot(g,g);' + LineEnding +
    '  if(g2>=0.0 && g2<1.0e12) {' + LineEnding +
    '   g*=min(1.0,0.35*inversesqrt(max(g2,1.0e-12)));' + LineEnding +
    '   n=normalize(b-g);' + LineEnding +
    '  }' + LineEnding +
    ' }' + LineEnding +
    '}';
  Result.SetParts([LVertex, LFragment]);
end;

function InteriorDetail(const AKind: Integer; const AExteriorWood,
  AStaticBatch: Boolean): TEffectNode;
begin
  if (AKind < InteriorWood) or (AKind > InteriorMetal) then
  begin
    raise Exception.Create('Unknown interior material kind');
  end;
  { CGE hashes effect node identity because uniform values belong to that node.
    These kind/wood variants never change. Sharing the node therefore shares
    compiled programs across walls, furniture, foundations and their instances. }
  if GDetails[AKind, AExteriorWood, AStaticBatch] = nil then
  begin
    GDetails[AKind, AExteriorWood, AStaticBatch] :=
      CreateInteriorDetail(AKind, AExteriorWood, AStaticBatch);
    GDetails[AKind, AExteriorWood, AStaticBatch].WaitForRelease;
  end;
  Result := GDetails[AKind, AExteriorWood, AStaticBatch];
end;

function ModularFloorDetail(const AStone: Boolean): TEffectNode;
var
  LVertex: TEffectPartNode;
  LFragment: TEffectPartNode;
begin
  if GFloorDetails[AStone] <> nil then
  begin
    Exit(GFloorDetails[AStone]);
  end;
  Result := TEffectNode.Create;
  Result.WaitForRelease;
  Result.Language := slGLSL;
  Result.AddCustomField(TSFFloat.Create(Result, True, 'phanesModuleStone', Ord(AStone)));
  LVertex := TEffectPartNode.Create;
  LVertex.ShaderType := stVertex;
  LVertex.Contents :=
    'varying highp vec3 phanesModuleFloorP;' + LineEnding +
    'void PLUG_vertex_object_space(const in vec4 p,inout vec3 n) {' + LineEnding +
    ' phanesModuleFloorP=p.xyz; }';
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  { Millimetre joints reveal physical scale without exaggerating the two-metre
    authoring grid. Derivative filtering preserves thin seams at a distance. }
  LFragment.Contents :=
    'varying highp vec3 phanesModuleFloorP;' + LineEnding +
    'uniform float phanesModuleStone;' + LineEnding +
    'void PLUG_main_texture_apply(inout vec4 c,const in vec3 n) {' + LineEnding +
    ' vec2 p=phanesModuleFloorP.xz+vec2(1.0);' + LineEnding +
    ' vec2 pitch=mix(vec2(0.2,1.0),vec2(1.0),phanesModuleStone);' + LineEnding +
    ' vec2 q=p/pitch; float row=floor(q.x);' + LineEnding +
    ' q.y+=mod(row,2.0)*0.5*(1.0-phanesModuleStone);' + LineEnding +
    ' vec2 f=fract(q); vec2 edge=min(f,1.0-f)*pitch;' + LineEnding +
    ' vec2 pixel=max(abs(dFdx(p))+abs(dFdy(p)),vec2(0.00001));' + LineEnding +
    ' vec2 seam=clamp((0.0015+pixel*0.5-edge)/pixel,0.0,1.0);' + LineEnding +
    ' float joint=max(seam.x,seam.y);' + LineEnding +
    ' c.rgb*=1.0-0.24*joint;' + LineEnding +
    '}';
  Result.SetParts([LVertex, LFragment]);
  GFloorDetails[AStone] := Result;
end;

procedure ReleaseDetails;
var
  I: Integer;
begin
  for I := InteriorWood to InteriorMetal do
  begin
    NodeRelease(GDetails[I, False, False]);
    NodeRelease(GDetails[I, True, False]);
    NodeRelease(GDetails[I, False, True]);
    NodeRelease(GDetails[I, True, True]);
  end;
  NodeRelease(GFloorDetails[False]);
  NodeRelease(GFloorDetails[True]);
end;

finalization
  ReleaseDetails;

end.
