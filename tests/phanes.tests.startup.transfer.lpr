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
program PhanesStartupTransferChecks;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, FPJSON, FPHTTPClient, FpSHA256, phanes.tools.files;

type
  TSlowStream = class(TMemoryStream)
  public
    FStart: QWord;
    FRate: Integer;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

function TSlowStream.Write(const ABuffer; ACount: LongInt): LongInt;
var
  LDue: QWord;
  LNow: QWord;
begin
  Require((ACount >= 0) and (Size + ACount <= 524288), 'Part exceeds its bounded response');
  Result := inherited Write(ABuffer, ACount);
  { Slow the actual HTTP consumer, not a browser's post-download presentation.
    This causes socket backpressure on the unmodified Pascal server. }
  LDue := FStart + QWord(Size) * 1000 div QWord(FRate);
  LNow := GetTickCount64;
  if LDue > LNow then
  begin
    Sleep(LDue - LNow);
  end;
end;

var
  GManifest: TJSONObject;
  GFiles: TJSONArray;
  GFile: TJSONObject;
  GPart: TJSONObject;
  GClient: TFPHTTPClient;
  GStream: TSlowStream;
  GBytes: TBytes;
  GHash: TSHA256;
  GHex: AnsiString;
  GTotal: Int64;
  GStart: QWord;
  GUrl: String;
  I: Integer;
  J: Integer;

begin
  Require(ParamCount = 3, 'Usage: transfer-checks WEB_ROOT SERVER_URL BYTES_PER_SECOND');
  GUrl := ParamStr(2);
  Require((GUrl <> '') and (GUrl[Length(GUrl)] = '/'), 'URL must end in slash');
  GManifest := LoadJSON(SafeChild(ExpandFileName(ParamStr(1)), 'data/runtime-parts.json'));
  GClient := TFPHTTPClient.Create(nil);
  GStream := TSlowStream.Create;
  try
    GStream.FRate := StrToInt(ParamStr(3));
    Require(GStream.FRate >= 16384, 'Test rate must be at least 16 KiB/s');
    GClient.IOTimeout := 45000;
    GFiles := GManifest.Arrays['files'];
    for I := 0 to GFiles.Count - 1 do
    begin
      GFile := GFiles.Objects[I];
      GHash.Init;
      GTotal := 0;
      GStart := GetTickCount64;
      for J := 0 to GFile.Arrays['parts'].Count - 1 do
      begin
        GPart := GFile.Arrays['parts'].Objects[J];
        GStream.Clear;
        GStream.FStart := GetTickCount64;
        GClient.Get(GUrl + GPart.Strings['url'], GStream);
        Require(GClient.ResponseStatusCode = 200, 'Expected HTTP 200');
        Require(GStream.Size = GPart.Int64s['bytes'], 'Incomplete HTTP part');
        SetLength(GBytes, GStream.Size);
        Move(GStream.Memory^, GBytes[0], Length(GBytes));
        Require(HashBytes(GBytes) = GPart.Strings['sha256'], 'Downloaded part hash differs');
        GHash.Update(@GBytes[0], Length(GBytes));
        Inc(GTotal, Length(GBytes));
        if (J mod 16 = 0) or (J = GFile.Arrays['parts'].Count - 1) then
        begin
          WriteLn('Verified ', GFile.Strings['path'], ' ', GTotal, ' / ', GFile.Int64s['bytes']);
          Flush(Output);
        end;
      end;
      GHash.Final;
      GHash.OutputHexa(GHex);
      Require((GTotal = GFile.Int64s['bytes']) and
        (LowerCase(GHex) = HashFile(SafeChild(ParamStr(1), GFile.Strings['path']))),
        'Reassembled HTTP parts differ from original source');
      WriteLn('PASS exact reconstruction ', GFile.Strings['path'], ' in ',
        GetTickCount64 - GStart, ' ms at ', GStream.FRate, ' bytes/second');
      Flush(Output);
    end;
  finally
    GStream.Free;
    GClient.Free;
    GManifest.Free;
  end;
end.

