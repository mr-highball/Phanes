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

unit phanes.world.surfaces;
{$mode delphi}
{$H+}

interface
uses
  CastleScene, X3DNodes, phanes.world.appearance;
type
  { Identifies the position-aware world finish that the static foliage cache
    explicitly translates. Other custom effects retain normal scene rendering. }
  TWorldSurfaceEffect = class(TEffectNode);
procedure ApplyWorldSurface(const AScene: TCastleScene; const AAppearance: TWorldAppearance;
  const AStaticBatch: Boolean = False);
implementation
uses
  SysUtils, X3DFields, CastleVectors, CastleRenderOptions,
  phanes.interiors.materials;

procedure ApplyWorldSurface(const AScene: TCastleScene; const AAppearance: TWorldAppearance;
  const AStaticBatch: Boolean);
var
  LEffect: TEffectNode;
  LVertex: TEffectPartNode;
  LFragment: TEffectPartNode;
begin
  LEffect := TWorldSurfaceEffect.Create;
  LEffect.Language := slGLSL;
  LEffect.AddCustomField(TSFVec3f.Create(LEffect, True, 'phanesTint',
    Vector3(AAppearance.FTint.FR, AAppearance.FTint.FG, AAppearance.FTint.FB)));
  LEffect.AddCustomField(TSFFloat.Create(LEffect, True, 'phanesRoughness', AAppearance.FRoughness));
  LVertex := TEffectPartNode.Create;
  LVertex.ShaderType := stVertex;
  // This is a small GPU material binding; profile solving and policy remain Pascal.
  // Matrix column lengths account for model scale without making grain swim with the camera.
  LVertex.Contents :=
    'varying vec3 phanesSurfacePosition;' + LineEnding +
    'varying float phanesSurfaceDistance;' + LineEnding +
    'void PLUG_vertex_object_space(const in vec4 p, inout vec3 n) {' + LineEnding +
    '  vec3 s = vec3(length(castle_ModelViewMatrix[0].xyz),' +
    ' length(castle_ModelViewMatrix[1].xyz), length(castle_ModelViewMatrix[2].xyz));' + LineEnding +
    '  phanesSurfacePosition = p.xyz * s;' + LineEnding +
    '  phanesSurfaceDistance = length((castle_ModelViewMatrix * p).xyz);' + LineEnding +
    '}';
  if AStaticBatch then
  begin
    { Static chunk vertices already contain their world transform. Preserve the
      original material grain coordinates explicitly so batching does not
      rotate, rescale or shift surface detail when an instance joins a batch. }
    LVertex.Contents :=
      'attribute vec3 phanesOriginalSurface;' + LineEnding +
      'varying vec3 phanesSurfacePosition;' + LineEnding +
      'varying float phanesSurfaceDistance;' + LineEnding +
      'void PLUG_vertex_object_space(const in vec4 p, inout vec3 n) {' + LineEnding +
      '  phanesSurfacePosition = phanesOriginalSurface;' + LineEnding +
      '  phanesSurfaceDistance = length((castle_ModelViewMatrix * p).xyz);' + LineEnding +
      '}';
  end;
  LFragment := TEffectPartNode.Create;
  LFragment.ShaderType := stFragment;
  LFragment.Contents :=
    'varying vec3 phanesSurfacePosition;' + LineEnding +
    'varying float phanesSurfaceDistance;' + LineEnding +
    'uniform vec3 phanesTint;' + LineEnding +
    'uniform float phanesRoughness;' + LineEnding +
    'float phanesGrain() {' + LineEnding +
    ' vec3 p = phanesSurfacePosition;' + LineEnding +
    ' return sin(p.x * 8.7 + sin(p.z * 6.1)) * sin(p.y * 9.3 + p.z * 7.7);' + LineEnding +
    '}' + LineEnding +
    'void PLUG_material_metallic_roughness(inout float m, inout float r) {' + LineEnding +
    ' r = clamp(mix(r, phanesRoughness, 0.65) + phanesGrain() * 0.055, 0.36, 0.94);' + LineEnding +
    '}' + LineEnding +
    'void PLUG_fragment_modify(inout vec4 c) {' + LineEnding +
    ' float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));' + LineEnding +
    ' float grain = phanesGrain() * 0.045 / (1.0 + phanesSurfaceDistance * 0.04);' + LineEnding +
    ' c.rgb = mix(vec3(y), c.rgb, 0.92) * phanesTint * (1.0 + grain);' + LineEnding +
    '}';
  LEffect.SetParts([LVertex, LFragment]);
  if (Pos('furniture-kit/table.glb', AScene.Url) > 0) or
    (Pos('furniture-kit/chair.glb', AScene.Url) > 0) or
    (Pos('furniture-kit/bookcaseOpen.glb', AScene.Url) > 0) then
  begin
    AScene.SetEffects([LEffect, InteriorDetail(InteriorWood)]);
  end
  else
  begin
    AScene.SetEffects([LEffect]);
  end;
end;
end.
