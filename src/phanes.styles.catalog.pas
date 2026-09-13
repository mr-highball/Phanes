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

unit phanes.styles.catalog;

{$mode delphi}
{$H+}

interface

type
  TVisualStyle = record
    FId: String;
    FName: String;
    FDescription: String;
    FGroup: String;
    FDetailName: String;
  end;

const
  VisualStyleCount = 23;
  VisualStyles: array[0..VisualStyleCount - 1] of TVisualStyle = (
    (FId: 'none'; FName: 'None';
      FDescription: 'The original rendered world.'; FGroup: 'Original'; FDetailName: 'Detail'),
    (FId: 'toon'; FName: 'Toon';
      FDescription: 'Bold contours and sculpted color bands.'; FGroup: 'Drawn'; FDetailName: 'Contour'),
    (FId: 'ink'; FName: 'Ink wash';
      FDescription: 'Deep ink edges over pale flowing tones.'; FGroup: 'Drawn'; FDetailName: 'Ink'),
    (FId: 'graphite'; FName: 'Graphite';
      FDescription: 'Crosshatched graphite on warm paper.'; FGroup: 'Drawn'; FDetailName: 'Hatching'),
    (FId: 'watercolor'; FName: 'Watercolor';
      FDescription: 'Soft pigment pools and textured paper.'; FGroup: 'Drawn'; FDetailName: 'Pigment'),
    (FId: 'gouache'; FName: 'Gouache';
      FDescription: 'Opaque paint with broad, broken strokes.'; FGroup: 'Drawn'; FDetailName: 'Brush size'),
    (FId: 'chalk'; FName: 'Chalkboard';
      FDescription: 'Powdery white contours on slate.'; FGroup: 'Drawn'; FDetailName: 'Chalk'),
    (FId: 'copper'; FName: 'Copper etching';
      FDescription: 'Fine engraved marks in burnished copper.'; FGroup: 'Drawn'; FDetailName: 'Engraving'),
    (FId: 'comic'; FName: 'Comic print';
      FDescription: 'Halftone dots and crisp comic contours.'; FGroup: 'Print & pixel'; FDetailName: 'Dot size'),
    (FId: 'riso'; FName: 'Risograph';
      FDescription: 'Offset coral and indigo print layers.'; FGroup: 'Print & pixel'; FDetailName: 'Ink spread'),
    (FId: 'pixel'; FName: 'Pixel world';
      FDescription: 'A crisp, deliberately low-resolution world.'; FGroup: 'Print & pixel'; FDetailName: 'Pixel size'),
    (FId: 'dither'; FName: 'Dithered console';
      FDescription: 'Ordered dithering and a limited retro palette.'; FGroup: 'Print & pixel'; FDetailName: 'Pixel size'),
    (FId: 'mosaic'; FName: 'Mosaic';
      FDescription: 'Glazed tiles separated by fine grout.'; FGroup: 'Print & pixel'; FDetailName: 'Tile size'),
    (FId: 'stained'; FName: 'Stained glass';
      FDescription: 'Faceted color cells set in dark lead.'; FGroup: 'Print & pixel'; FDetailName: 'Facet size'),
    (FId: 'crt'; FName: 'Arcade CRT';
      FDescription: 'Phosphor, scanlines and RGB dots.'; FGroup: 'Print & pixel'; FDetailName: 'Scanlines'),
    (FId: 'vhs'; FName: 'Analog tape';
      FDescription: 'Soft chroma drift and worn tape texture.'; FGroup: 'Print & pixel'; FDetailName: 'Tape wear'),
    (FId: 'bloom'; FName: 'Soft bloom';
      FDescription: 'Luminous highlights with a gentle glow.'; FGroup: 'Atmosphere'; FDetailName: 'Glow radius'),
    (FId: 'noir'; FName: 'Silver noir';
      FDescription: 'Rich monochrome, film grain and falloff.'; FGroup: 'Atmosphere'; FDetailName: 'Film grain'),
    (FId: 'dream'; FName: 'Dreamscape';
      FDescription: 'Diffuse light and a pearlescent haze.'; FGroup: 'Atmosphere'; FDetailName: 'Diffusion'),
    (FId: 'prism'; FName: 'Prismatic';
      FDescription: 'Spectral fringes around luminous edges.'; FGroup: 'Spectral'; FDetailName: 'Separation'),
    (FId: 'thermal'; FName: 'Thermal palette';
      FDescription: 'False-color bands inspired by heat imagery.'; FGroup: 'Spectral'; FDetailName: 'Color bands'),
    (FId: 'blueprint'; FName: 'Blueprint';
      FDescription: 'Luminous drafting lines over a blue grid.'; FGroup: 'Spectral'; FDetailName: 'Grid size'),
    (FId: 'aurora'; FName: 'Aurora glass';
      FDescription: 'Iridescent contours and cool luminous color.'; FGroup: 'Spectral'; FDetailName: 'Iridescence')
  );

function VisualStyleIndex(const AId: String): Integer;
function DefaultStyleDetail(const AIndex: Integer): Double;
function ValidStyleSettings(const AIndex: Integer; const AStrength, ADetail: Double): Boolean;

implementation

uses
  Math;

function DefaultStyleDetail(const AIndex: Integer): Double;
begin
  if AIndex in [10, 11, 12, 13] then
  begin
    Result := 0.2;
  end else
  begin
    Result := 0.5;
  end;
end;

function VisualStyleIndex(const AId: String): Integer;
var
  I: Integer;
begin
  for I := 0 to VisualStyleCount - 1 do
  begin
    if VisualStyles[I].FId = AId then
    begin
      Exit(I);
    end;
  end;
  Result := -1;
end;

function ValidStyleSettings(const AIndex: Integer; const AStrength, ADetail: Double): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < VisualStyleCount) and
    not IsNan(AStrength) and not IsInfinite(AStrength) and
    not IsNan(ADetail) and not IsInfinite(ADetail) and
    (AStrength >= 0) and (AStrength <= 1) and (ADetail >= 0) and (ADetail <= 1);
end;

end.
