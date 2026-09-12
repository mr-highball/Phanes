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

unit phanes.tests.dependencies;

{$mode delphi}
{$H+}

interface

procedure RunDependencyChecks;

implementation

uses
  SysUtils,
  wfc;

procedure RunDependencyChecks;
var
  LGraph: TGraph;
begin
  { Verify the pinned WFC core can be compiled and instantiated by pas2js.
    Model conformance belongs to WFC's own suite, not this empty application. }
  LGraph := TGraph.Create;
  try
    if LGraph = nil then
    begin
      raise Exception.Create('WFC graph initialization failed');
    end;
  finally
    LGraph.Free;
  end;
end;

end.
