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

program PhanesTestsStreamingCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  phanes.tools.files;

const
  SmallLengths: array[0..6] of Integer = (0, 3, 65535, 65536, 65537, 131072, 131073);
  LargeBytes = Int64(129) * 1024 * 1024 + 123;
  { Independently established using the platform SHA-256 implementation for
    this exact repeated 0..255 byte sequence, including the final 123 bytes. }
  LargeHash = '2a9e70c6725e2e435439dacd12ff02be489e43b86efe92361bf1076725efd53c';

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AName: String);
begin
  Inc(GChecks);
  Require(ACondition, AName);
end;

procedure Run;
var
  LRoot: String;
  LScratch: String;
  LGuid: TGUID;
  LInput: String;
  LOutput: String;
  LHash: String;
  LStream: TFileStream;
  LBlock: array[0..65535] of Byte;
  LBytes: TBytes;
  LRemaining: Int64;
  LCount: Integer;
  LRefused: Boolean;
  LEvidence: TJSONObject;
  I: Integer;
  J: Integer;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  LRoot := ExpandFileName(ParamStr(1));
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh fixture identifier');
  LScratch := SafeChild(LRoot, 'build/tests/streaming-critic');
  if ParamCount = 2 then
  begin
    LScratch := ExpandFileName(ParamStr(2));
  end;
  LScratch := SafeChild(LScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(LScratch), 'Expected fresh streaming fixture');
  ForceDirectories(LScratch);
  LInput := SafeChild(LScratch, 'source.bin');
  LOutput := SafeChild(LScratch, 'nested/copy.bin');
  for I := 0 to High(SmallLengths) do
  begin
    SetLength(LBytes, SmallLengths[I]);
    for J := 0 to High(LBytes) do
    begin
      LBytes[J] := Byte(J and $FF);
    end;
    WriteBytes(LInput, LBytes);
    Check(FileByteCount(LInput) = Length(LBytes), 'Small input byte count');
    Check(HashFile(LInput) = HashBytes(LBytes), 'Stream hash handles chunk boundary');
    CopyFileBytes(LInput, LOutput);
    Check(FileByteCount(LOutput) = Length(LBytes), 'Copy truncates prior longer destination');
    Check(HashFile(LOutput) = HashBytes(LBytes), 'Small copy preserves bytes');
  end;
  for I := 0 to High(LBlock) do
  begin
    LBlock[I] := Byte(I and $FF);
  end;
  LStream := TFileStream.Create(LInput, fmCreate);
  try
    LRemaining := LargeBytes;
    while LRemaining > 0 do
    begin
      LCount := SizeOf(LBlock);
      if LRemaining < LCount then
      begin
        LCount := LRemaining;
      end;
      LStream.WriteBuffer(LBlock, LCount);
      Dec(LRemaining, LCount);
    end;
  finally
    LStream.Free;
  end;
  Check(FileByteCount(LInput) = LargeBytes, 'Large input exceeds 128 MiB with exact tail');
  LHash := HashFile(LInput);
  Check(LHash = LargeHash, 'Large stream agrees with independent known SHA-256');
  CopyFileBytes(LInput, LOutput);
  Check(FileByteCount(LOutput) = LargeBytes, 'Large copy size');
  Check(HashFile(LOutput) = LHash, 'Large copy streaming hash');
  LRefused := False;
  try
    CopyFileBytes(SafeChild(LScratch, 'missing.bin'), LOutput);
  except
    on LException: Exception do
    begin
      LRefused := True;
    end;
  end;
  Check(LRefused, 'Missing copy source rejects');
  Check(HashFile(LOutput) = LHash, 'Missing source leaves previous destination intact');
  LEvidence := TJSONObject.Create(['checks', GChecks, 'bytes', LargeBytes,
    'source', LInput, 'copy', LOutput, 'sha256', LHash]);
  try
    WriteTextAtomic(SafeChild(LScratch, 'evidence.json'),
      LEvidence.FormatJSON + #10);
    WriteLn(LEvidence.FormatJSON);
    { These exact two files were created in this fresh bounded fixture directory.
      Preserve them on failure; successful CI runs need not retain 258 MiB. }
    Require(SysUtils.DeleteFile(LInput), 'Cannot remove completed generated source fixture');
    Require(SysUtils.DeleteFile(LOutput), 'Cannot remove completed generated copy fixture');
    WriteLn('PASS ', GChecks, ' independent streaming checks');
  finally
    LEvidence.Free;
  end;
end;

begin
  Run;
end.
