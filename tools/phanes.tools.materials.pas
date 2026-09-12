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

unit phanes.tools.materials;
{$mode delphi}
{$H+}
interface
procedure ProcessMaterials(const ARoot: String; const ADownload: Boolean);
implementation
uses
  SysUtils, FPJSON, phanes.tools.files;
procedure ProcessMaterials(const ARoot: String; const ADownload: Boolean);
var
  LManifest: TJSONObject;
  LFile: TJSONObject;
  LPath: String;
  I: Integer;
begin
  LManifest := LoadJSON(SafeChild(ARoot, 'data/materials.lock.json'));
  try
    Require(LManifest.Integers['version'] = 1, 'Unsupported material manifest');
    Require(LManifest.Strings['license'] = 'CC0-1.0', 'Unexpected material license');
    Require(LManifest.Arrays['files'].Count > 0, 'Empty material library');
    for I := 0 to LManifest.Arrays['files'].Count - 1 do
    begin
      LFile := TJSONObject(LManifest.Arrays['files'][I]);
      LPath := SafeChild(ARoot, LFile.Strings['path']);
      if ADownload then
      begin
        FetchPinned(LFile.Strings['url'], LPath, LFile.Strings['sha256']);
      end;
      Require(HashFile(LPath) = LFile.Strings['sha256'], 'Changed material: ' + LPath);
    end;
    WriteLn(LManifest.Arrays['files'].Count, ' pinned material textures verified');
  finally
    LManifest.Free;
  end;
end;
end.

