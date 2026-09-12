/*
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
*/

/* One Castle ScreenEffect pass. Coordinates remain in the rendered viewport:
   styles never warp the world away from the editor's picking rays.
   No depth texture, animation, history buffer or extra render pass is required.
   None and zero strength are disabled in Pascal, preserving the normal path. */

uniform int phanesStyle;
uniform float phanesStrength;
uniform float phanesDetail;
uniform float phanesDensity;

float luminance(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sampleWorld(vec2 p) {
  vec2 limit = vec2(float(screen_width), float(screen_height));
  return screenf_get_color(clamp(p, vec2(0.5), limit - vec2(0.5))).rgb;
}

float grain(vec2 p) {
  return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 soften(vec2 p, float radius) {
  vec3 c = sampleWorld(p) * 4.0;
  c += sampleWorld(p + vec2(radius, 0.0)) * 2.0;
  c += sampleWorld(p - vec2(radius, 0.0)) * 2.0;
  c += sampleWorld(p + vec2(0.0, radius)) * 2.0;
  c += sampleWorld(p - vec2(0.0, radius)) * 2.0;
  c += sampleWorld(p + vec2(radius, radius));
  c += sampleWorld(p - vec2(radius, radius));
  c += sampleWorld(p + vec2(radius, -radius));
  c += sampleWorld(p + vec2(-radius, radius));
  return c / 16.0;
}

float contour(vec2 p, float radius) {
  vec3 dx = sampleWorld(p + vec2(radius, 0.0)) - sampleWorld(p - vec2(radius, 0.0));
  vec3 dy = sampleWorld(p + vec2(0.0, radius)) - sampleWorld(p - vec2(0.0, radius));
  return clamp(length(dx) + length(dy), 0.0, 1.0);
}

vec3 paintRegion(vec2 p, float radius) {
  vec3 center = sampleWorld(p);
  vec3 chosen = center;
  float best = 100.0;
  for (int iy = 0; iy < 2; iy++) {
    for (int ix = 0; ix < 2; ix++) {
      vec2 direction = vec2(float(ix) * 2.0 - 1.0, float(iy) * 2.0 - 1.0);
      vec3 a = sampleWorld(p + vec2(direction.x * radius, 0.0));
      vec3 b = sampleWorld(p + vec2(0.0, direction.y * radius));
      vec3 c = sampleWorld(p + direction * radius);
      vec3 mean = (center + a + b + c) * 0.25;
      vec3 variance = (center - mean) * (center - mean) +
        (a - mean) * (a - mean) + (b - mean) * (b - mean) + (c - mean) * (c - mean);
      float score = variance.r + variance.g + variance.b;
      if (score < best) {
        best = score;
        chosen = mean;
      }
    }
  }
  return chosen;
}

vec3 bands(vec3 c, float count) {
  return floor(c * count + 0.5) / count;
}

float hatch(vec2 p, float spacing, float width) {
  float line = abs(fract((p.x + p.y) / spacing) - 0.5) * spacing;
  return 1.0 - smoothstep(width, width + 1.0, line);
}

float dots(vec2 p, float spacing, float coverage) {
  vec2 cell = fract(p / spacing) - 0.5;
  return 1.0 - smoothstep(coverage * 0.52, coverage * 0.52 + 0.065, length(cell));
}

float bayer(vec2 p) {
  vec2 a = mod(floor(p), 2.0);
  vec2 b = mod(floor(p / 2.0), 2.0);
  return (4.0 * (2.0 * a.x + 3.0 * a.y - 4.0 * a.x * a.y) +
    (2.0 * b.x + 3.0 * b.y - 4.0 * b.x * b.y) + 0.5) / 16.0;
}

vec3 heat(float x) {
  vec3 a = mix(vec3(0.02, 0.01, 0.15), vec3(0.46, 0.02, 0.62),
    smoothstep(0.0, 0.3, x));
  a = mix(a, vec3(0.97, 0.17, 0.05), smoothstep(0.27, 0.6, x));
  a = mix(a, vec3(1.0, 0.83, 0.06), smoothstep(0.56, 0.84, x));
  return mix(a, vec3(1.0, 0.99, 0.78), smoothstep(0.8, 1.0, x));
}

void main(void) {
  vec2 p = screenf_position();
  vec2 q = p / phanesDensity;
  vec2 uv = screenf_01_position;
  vec3 original = sampleWorld(p);
  vec3 c = original;
  float y = luminance(c);
  float d = phanesDetail;
  float n = grain(q);
  float edge = 0.0;

  if (phanesStyle == 1) {
    edge = smoothstep(0.07, 0.3, contour(p, (0.65 + d) * phanesDensity));
    float level = floor(y * 5.0 + 0.5) / 5.0;
    c = mix(c, c * (level + 0.05) / (y + 0.05), 0.85);
    c = mix(c * 1.07, vec3(0.045, 0.06, 0.085), edge * (0.55 + 0.4 * d));
  } else if (phanesStyle == 2) {
    vec3 wash = soften(p, 1.5 * phanesDensity);
    edge = contour(p, phanesDensity);
    c = mix(vec3(0.93, 0.93, 0.86), wash * vec3(0.72, 0.85, 0.89), 0.65);
    c -= vec3(edge * (0.5 + d) + (n - 0.5) * 0.035);
  } else if (phanesStyle == 3) {
    edge = contour(p, phanesDensity);
    float spacing = mix(8.0, 3.0, d);
    float h = hatch(q, spacing, 0.45) * (1.0 - smoothstep(0.15, 0.7, y));
    h += hatch(vec2(q.x, -q.y), spacing, 0.4) * (1.0 - smoothstep(0.1, 0.4, y));
    c = vec3(0.94, 0.915, 0.855) * (1.0 - edge * 0.8 - h * 0.48);
    c -= (1.0 - y) * 0.13 + (n - 0.5) * 0.065;
  } else if (phanesStyle == 4) {
    edge = contour(p, phanesDensity);
    vec3 pigment = soften(p, mix(0.65, 2.5, d) * phanesDensity);
    pigment = mix(pigment, original, smoothstep(0.03, 0.25, edge) * 0.65);
    c = mix(vec3(0.96, 0.94, 0.87), pigment, 0.72 + d * 0.16);
    c *= 1.0 - edge * 0.13;
    c += (n - 0.5) * 0.022;
  } else if (phanesStyle == 5) {
    vec3 paint = paintRegion(p, mix(1.0, 7.0, d) * phanesDensity);
    c = mix(paint, original, 0.2) * 1.04;
    c = mix(vec3(luminance(c)), c, 1.12);
    c += (n - 0.5) * 0.012;
  } else if (phanesStyle == 6) {
    edge = contour(p, mix(0.7, 1.7, d) * phanesDensity);
    float dust = (0.55 + n * 0.45) * smoothstep(0.025, 0.32, edge);
    c = vec3(0.035, 0.075, 0.074) + vec3(0.84, 0.88, 0.79) * dust;
    c += hatch(q, 5.0, 0.4) * (1.0 - y) * 0.07;
  } else if (phanesStyle == 7) {
    edge = smoothstep(0.04, 0.38, contour(p, phanesDensity));
    float engraving = hatch(q, mix(7.0, 3.0, d), 0.35) *
      (1.0 - smoothstep(0.1, 0.38, y));
    float tone = pow(smoothstep(0.04, 0.85, y), 0.75);
    c = mix(vec3(0.11, 0.055, 0.035), vec3(1.0, 0.78, 0.5), tone);
    c *= 1.0 - engraving * 0.18 - edge * 0.38;
    c += vec3(0.09, 0.05, 0.025) * edge * tone + (n - 0.5) * 0.012;
  } else if (phanesStyle == 8) {
    float size = mix(4.0, 12.0, d);
    float ink = dots(q, size, sqrt(max(0.0, 1.0 - y)));
    c = mix(bands(c, 5.0) * 1.12, vec3(0.11, 0.08, 0.13), ink * 0.48);
    edge = smoothstep(0.1, 0.35, contour(p, phanesDensity));
    c = mix(c, vec3(0.025), edge * 0.85);
  } else if (phanesStyle == 9) {
    vec3 paper = vec3(0.98, 0.91, 0.78);
    float tone = smoothstep(0.06, 0.83, y);
    float warm = clamp((original.r - original.b + 0.06) * 3.0, 0.0, 0.85);
    c = mix(vec3(0.14, 0.23, 0.43), paper, tone);
    c = mix(c, mix(vec3(0.75, 0.24, 0.24), paper, tone), warm);
    float print = dots(q, 2.5 + d * 2.5, sqrt(max(0.0, 1.0 - y)));
    c *= 1.0 - print * 0.09;
    edge = contour(p + vec2((0.5 + d) * phanesDensity, 0.0), phanesDensity);
    c = mix(c, vec3(0.14, 0.2, 0.36), edge * 0.45);
  } else if (phanesStyle == 10) {
    float size = mix(1.0, 15.0, d) * phanesDensity;
    c = bands(sampleWorld((floor(p / size) + 0.5) * size), 14.0);
  } else if (phanesStyle == 11) {
    float size = mix(1.0, 4.0, d) * phanesDensity;
    vec2 cell = floor(p / size);
    c = sampleWorld((cell + 0.5) * size);
    c = floor(c * vec3(7.0, 8.0, 6.0) + bayer(cell)) / vec3(7.0, 8.0, 6.0);
  } else if (phanesStyle == 12) {
    float size = mix(3.0, 20.0, d) * phanesDensity;
    vec2 cell = fract(p / size);
    c = sampleWorld((floor(p / size) + 0.5) * size);
    float rim = min(min(cell.x, cell.y), min(1.0 - cell.x, 1.0 - cell.y));
    c = mix(vec3(0.13, 0.16, 0.17), c * (0.94 + cell.y * 0.12),
      smoothstep(0.025, 0.075, rim));
  } else if (phanesStyle == 13) {
    float size = mix(4.0, 30.0, d) * phanesDensity;
    vec2 base = floor(p / size);
    vec2 nearest = vec2(0.0);
    float first = 8.0;
    float second = 8.0;
    for (int iy = -1; iy <= 1; iy++) {
      for (int ix = -1; ix <= 1; ix++) {
        vec2 cell = base + vec2(float(ix), float(iy));
        vec2 seed = cell + vec2(0.22 + grain(cell) * 0.56,
          0.22 + grain(cell + vec2(39.0, 17.0)) * 0.56);
        float distanceSquared = dot(seed - p / size, seed - p / size);
        if (distanceSquared < first) {
          second = first;
          first = distanceSquared;
          nearest = seed;
        } else {
          second = min(second, distanceSquared);
        }
      }
    }
    c = sampleWorld(nearest * size);
    c = mix(vec3(luminance(c)), c, 1.5) * 1.2;
    c = mix(vec3(0.025, 0.035, 0.05), c,
      smoothstep(0.02, 0.095, sqrt(second) - sqrt(first)));
  } else if (phanesStyle == 14) {
    float scan = 0.86 + 0.14 * cos(q.y * 3.14159265);
    vec3 phosphor = vec3(0.88);
    float subpixel = mod(floor(q.x), 3.0);
    if (subpixel < 1.0) { phosphor.r = 1.2; }
    else if (subpixel < 2.0) { phosphor.g = 1.2; }
    else { phosphor.b = 1.2; }
    c = pow(c, vec3(0.92)) * mix(vec3(1.0), phosphor * scan, 0.35 + d * 0.65);
    c *= 1.0 - dot(uv - 0.5, uv - 0.5) * 0.42;
  } else if (phanesStyle == 15) {
    float offset = (0.5 + d * 3.0) * phanesDensity;
    vec3 smear = soften(p, offset);
    c = vec3(sampleWorld(p + vec2(offset, 0.0)).r, smear.g,
      sampleWorld(p - vec2(offset, 0.0)).b);
    c = mix(vec3(luminance(c)), c, 0.78) * vec3(1.03, 0.98, 0.96);
    c += (n - 0.5) * (0.025 + d * 0.06);
    c *= 0.97 + 0.03 * sin(q.y * 1.57);
  } else if (phanesStyle == 16) {
    vec3 glow = soften(p, mix(3.0, 14.0, d) * phanesDensity);
    c += max(glow - 0.48, 0.0) * 0.85;
    c = mix(c, soften(p, phanesDensity), 0.1);
  } else if (phanesStyle == 17) {
    float silver = smoothstep(0.03, 0.91, y);
    silver += (n - 0.5) * (0.02 + d * 0.12);
    silver *= 1.0 - smoothstep(0.2, 0.8, length(uv - 0.5)) * 0.38;
    c = vec3(silver);
  } else if (phanesStyle == 18) {
    vec3 haze = soften(p, mix(3.0, 16.0, d) * phanesDensity);
    c = mix(c, haze, 0.48) * vec3(0.93, 1.015, 1.075);
    c += max(haze - 0.3, 0.0) * vec3(0.32, 0.23, 0.35);
    c = mix(c, vec3(0.77, 0.69, 0.88), 0.095);
  } else if (phanesStyle == 19) {
    float offset = (1.0 + 5.0 * d) * phanesDensity;
    edge = contour(p, phanesDensity);
    c = vec3(sampleWorld(p + vec2(offset, 0.0)).r, c.g,
      sampleWorld(p - vec2(offset, 0.0)).b);
    c += edge * vec3(0.18, 0.1, 0.22);
  } else if (phanesStyle == 20) {
    float count = mix(24.0, 6.0, d);
    c = heat(floor(y * count + 0.5) / count);
  } else if (phanesStyle == 21) {
    edge = contour(p, phanesDensity);
    float size = mix(12.0, 40.0, d);
    vec2 cell = fract(q / size);
    float grid = 1.0 - smoothstep(0.02, 0.07, min(cell.x, cell.y));
    c = vec3(0.025, 0.11, 0.24) + grid * vec3(0.025, 0.09, 0.14);
    c += smoothstep(0.035, 0.3, edge) * vec3(0.59, 0.84, 0.83);
    c += bands(vec3(y), 6.0) * vec3(0.025, 0.045, 0.08);
  } else if (phanesStyle == 22) {
    edge = contour(p, (1.0 + d) * phanesDensity);
    vec3 spectrum = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + y * 8.0 + d * 3.0);
    c = mix(c * vec3(0.56, 0.83, 0.96), spectrum, 0.25);
    c += spectrum * edge * 0.9;
    c += max(soften(p, 4.0 * phanesDensity) - 0.5, 0.0) * 0.4;
  }
  gl_FragColor = vec4(mix(original, clamp(c, 0.0, 1.0), phanesStrength), 1.0);
}
