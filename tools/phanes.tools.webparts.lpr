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
program PhanesWebParts;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, FPJSON, phanes.tools.files;

const
  PartBytes = 512 * 1024;

var
  GRoot: String;
  GManifest: TJSONObject;
  GFiles: TJSONArray;
  GFile: TJSONObject;
  GParts: TJSONArray;
  GInput: TFileStream;
  GBytes: TBytes;
  GNames: array[0..1] of String;
  GPath: String;
  GHash: String;
  GCount: Integer;
  I: Integer;

procedure BindHost;
var
  LBinding: TJSONObject;
  LRoot: String;
  LHash: String;
begin
  Require(ParamCount = 3, 'Usage: phanes.tools.webparts bind WEB_ROOT MANIFEST_SHA256');
  LRoot := ExpandFileName(ParamStr(2));
  LHash := HashFile(SafeChild(LRoot, 'data/runtime-parts.json'));
  Require(LHash = ParamStr(3), 'Startup manifest changed while compiling the host.');
  LBinding := TJSONObject.Create(['version', 1, 'manifestSha256', LHash,
    'hostSha256', HashFile(SafeChild(LRoot, 'phanes.js'))]);
  try
    WriteTextAtomic(SafeChild(LRoot, 'data/runtime-host.json'), LBinding.FormatJSON + #10);
  finally
    LBinding.Free;
  end;
  WriteLn('Bound compiled host to its ordered startup manifest.');
end;

begin
  if ParamStr(1) = 'bind' then
  begin
    BindHost;
    Halt(0);
  end;
  Require(ParamCount = 1, 'Usage: phanes.tools.webparts WEB_ROOT');
  GRoot := ExpandFileName(ParamStr(1));
  GNames[0] := 'phanes_data.zip';
  GNames[1] := 'phanes.wasm';
  GManifest := TJSONObject.Create(['version', 1, 'partBytes', PartBytes]);
  GFiles := TJSONArray.Create;
  GManifest.Add('files', GFiles);
  try
    for I := 0 to High(GNames) do
    begin
      GInput := TFileStream.Create(SafeChild(GRoot, GNames[I]), fmOpenRead or fmShareDenyWrite);
      try
        Require((GInput.Size > 0) and (GInput.Size <= 256 * 1024 * 1024),
          'Startup file size is unsupported.');
        GFile := TJSONObject.Create(['path', GNames[I], 'bytes', GInput.Size,
          'sha256', HashFile(SafeChild(GRoot, GNames[I]))]);
        GFiles.Add(GFile);
        GParts := TJSONArray.Create;
        GFile.Add('parts', GParts);
        while GInput.Position < GInput.Size do
        begin
          GCount := PartBytes;
          if GInput.Size - GInput.Position < GCount then
          begin
            GCount := GInput.Size - GInput.Position;
          end;
          SetLength(GBytes, GCount);
          GInput.ReadBuffer(GBytes[0], GCount);
          GHash := HashBytes(GBytes);
          GPath := 'runtime/parts/' + GHash + '.part';
          if FileExists(SafeChild(GRoot, GPath)) then
          begin
            Require(HashFile(SafeChild(GRoot, GPath)) = GHash, 'A startup part changed.');
          end else
          begin
            WriteBytes(SafeChild(GRoot, GPath), GBytes);
          end;
          GParts.Add(TJSONObject.Create(['url', GPath, 'bytes', GCount, 'sha256', GHash]));
        end;
      finally
        GInput.Free;
      end;
    end;
    WriteTextAtomic(SafeChild(GRoot, 'data/runtime-parts.json'), GManifest.FormatJSON + #10);
    WriteLn('Published bounded startup parts for data and engine.');
  finally
    GManifest.Free;
  end;
end.
