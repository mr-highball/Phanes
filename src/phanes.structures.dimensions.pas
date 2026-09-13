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

unit phanes.structures.dimensions;

{$mode delphi}
{$H+}

interface

const
  { Physical metres, shared by shell geometry, room frames and support admission.
    A cabin is assembled around its doorway, not stretched from a door mesh. }
  CabinOuterMetres = 10.0;
  CabinWallMetres = 0.30;
  CabinInsideMetres = 9.40;
  CabinFloorMetres = 0.08;
  CabinWallHeightMetres = 2.70;
  CabinDoorWidthMetres = 1.20;
  CabinDoorHeightMetres = 2.20;
  CabinRoofRiseMetres = 1.80;
  CabinRoofOverhangMetres = 0.30;
  RocketFootprintMetres = 7.20;

implementation

end.

