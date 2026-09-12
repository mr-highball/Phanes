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

unit phanes.tools.files;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  FPJSON;

function ReadBytes(const APath: String): TBytes;
function ReadText(const APath: String): UTF8String;
procedure WriteBytes(const APath: String; const ABytes: TBytes);
procedure WriteText(const APath: String; const AText: UTF8String);
procedure WriteTextAtomic(const APath: String; const AText: UTF8String);
function LoadJSON(const APath: String): TJSONObject;
function HashBytes(const ABytes: TBytes): String;
function HashFile(const APath: String): String;
function FileByteCount(const APath: String): Int64;
procedure CopyFileBytes(const ASource, ATarget: String);
function SafeChild(const ARoot, ARelative: String): String;
procedure Require(const ACondition: Boolean; const AMessage: String);
procedure FetchPinned(const AUrl, APath, ASha256: String);
function Little32(const ABytes: TBytes; const AOffset: Integer): Cardinal;
function GLBJSON(const ABytes: TBytes): TJSONObject;
function ModelJSON(const ABytes: TBytes; const AExtension: String): TJSONObject;

implementation

uses
  JSONParser,
  FpSHA256,
  FPHTTPClient,
  OpenSSLSockets
  {$IFDEF WINDOWS}
  , Windows
  {$ENDIF}
  ;

const
  PinnedDownloadLimit = 128 * 1024 * 1024;

type
  TPinnedDownloadStream = class(TMemoryStream)
  public
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

function TPinnedDownloadStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  { Reject before TMemoryStream allocates storage. The HTTP client can receive
    chunked responses, so Content-Length alone cannot enforce this limit. }
  Require((ACount >= 0) and (Position >= 0) and
    (Position <= PinnedDownloadLimit - ACount), 'Download exceeds 128 MiB');
  Result := inherited Write(ABuffer, ACount);
end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function ReadBytes(const APath: String): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= 128 * 1024 * 1024, 'Input exceeds 128 MiB: ' + APath);
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

function ReadText(const APath: String): UTF8String;
var
  LBytes: TBytes;
begin
  LBytes := ReadBytes(APath);
  Result := '';
  if Length(LBytes) > 0 then
  begin
    SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
  end;
end;

procedure WriteBytes(const APath: String; const ABytes: TBytes);
var
  LStream: TFileStream;
begin
  ForceDirectories(ExtractFileDir(APath));
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteText(const APath: String; const AText: UTF8String);
var
  LBytes: TBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(AText));
  end;
  WriteBytes(APath, LBytes);
end;

function LoadJSON(const APath: String): TJSONObject;
var
  LData: TJSONData;
begin
  LData := GetJSON(ReadText(APath), True);
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('Expected JSON object: ' + APath);
  end;
  Result := TJSONObject(LData);
end;

procedure WriteTextAtomic(const APath: String; const AText: UTF8String);
var
  LTemporary: String;
  LText: UTF8String;
begin
  { Authored metadata follows the repository LF contract on every host.
    Original archive and license bytes are copied with WriteBytes instead. }
  LText := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  LText := StringReplace(LText, #13, #10, [rfReplaceAll]);
  LTemporary := APath + '.pending-' + IntToStr(GetProcessID);
  try
    WriteText(LTemporary, LText);
    {$IFDEF WINDOWS}
    Require(MoveFileExW(PWideChar(UTF8Decode(LTemporary)), PWideChar(UTF8Decode(APath)),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH), 'Cannot publish ' + APath);
    {$ELSE}
    Require(RenameFile(LTemporary, APath), 'Cannot publish ' + APath);
    {$ENDIF}
  finally
    if FileExists(LTemporary) then
    begin
      SysUtils.DeleteFile(LTemporary);
    end;
  end;
end;

function HashBytes(const ABytes: TBytes): String;
var
  LHash: AnsiString;
begin
  TSHA256.DigestHexa(ABytes, LHash);
  Result := LowerCase(LHash);
end;

function HashFile(const APath: String): String;
var
  LInput: TFileStream;
  LHash: TSHA256;
  LHex: AnsiString;
  LBuffer: array[0..65535] of Byte;
  LRead: Integer;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LHash.Init;
    repeat
      LRead := LInput.Read(LBuffer, SizeOf(LBuffer));
      if LRead > 0 then
      begin
        LHash.Update(@LBuffer[0], LRead);
      end;
    until LRead = 0;
    LHash.Final;
    LHash.OutputHexa(LHex);
    Result := LowerCase(LHex);
  finally
    LInput.Free;
  end;
end;

function FileByteCount(const APath: String): Int64;
var
  LInput: TFileStream;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := LInput.Size;
  finally
    LInput.Free;
  end;
end;

procedure CopyFileBytes(const ASource, ATarget: String);
var
  LInput: TFileStream;
  LOutput: TFileStream;
begin
  LInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    ForceDirectories(ExtractFileDir(ATarget));
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LOutput.CopyFrom(LInput, LInput.Size);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function SafeChild(const ARoot, ARelative: String): String;
var
  LRoot: String;
  LRelative: String;
begin
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  LRelative := StringReplace(ARelative, '/', PathDelim, [rfReplaceAll]);
  Require((LRelative <> '') and (Pos(':', LRelative) = 0) and
    (LRelative[1] <> PathDelim), 'Expected relative local path: ' + ARelative);
  Result := ExpandFileName(LRoot + LRelative);
  {$IFDEF WINDOWS}
  Require(SameText(Copy(Result, 1, Length(LRoot)), LRoot), 'Path escapes root: ' + ARelative);
  {$ELSE}
  Require(Copy(Result, 1, Length(LRoot)) = LRoot, 'Path escapes root: ' + ARelative);
  {$ENDIF}
end;

procedure FetchPinned(const AUrl, APath, ASha256: String);
var
  LClient: TFPHTTPClient;
  LStream: TMemoryStream;
  LBytes: TBytes;
begin
  if FileExists(APath) then
  begin
    Require(FileByteCount(APath) <= PinnedDownloadLimit, 'Pinned download exceeds size bound');
    Require(HashFile(APath) = ASha256, 'Pinned file hash mismatch: ' + APath);
    Exit;
  end;
  Require(Copy(AUrl, 1, 8) = 'https://', 'Downloads require HTTPS');
  LClient := TFPHTTPClient.Create(nil);
  LStream := TPinnedDownloadStream.Create;
  try
    LClient.AllowRedirect := True;
    LClient.ConnectTimeout := 30000;
    LClient.IOTimeout := 90000;
    LClient.AddHeader('User-Agent', 'Phanes-asset-tools/1.0');
    LClient.Get(AUrl, LStream);
    Require(LStream.Size <= 128 * 1024 * 1024, 'Download exceeds 128 MiB');
    SetLength(LBytes, LStream.Size);
    LStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    Require(HashBytes(LBytes) = ASha256, 'Downloaded content changed: ' + AUrl);
    WriteBytes(APath, LBytes);
  finally
    LStream.Free;
    LClient.Free;
  end;
end;

function Little32(const ABytes: TBytes; const AOffset: Integer): Cardinal;
begin
  Require((AOffset >= 0) and (AOffset <= Length(ABytes) - 4), 'Truncated 32-bit field');
  Result := Cardinal(ABytes[AOffset]) or (Cardinal(ABytes[AOffset + 1]) shl 8) or
    (Cardinal(ABytes[AOffset + 2]) shl 16) or (Cardinal(ABytes[AOffset + 3]) shl 24);
end;

function GLBJSON(const ABytes: TBytes): TJSONObject;
var
  LLength: Cardinal;
  LText: UTF8String;
  LData: TJSONData;
begin
  Require((Length(ABytes) >= 20) and (Little32(ABytes, 0) = $46546C67) and
    (Little32(ABytes, 4) = 2) and (Little32(ABytes, 8) = Cardinal(Length(ABytes))),
    'Invalid GLB header/version/length');
  LLength := Little32(ABytes, 12);
  Require((LLength > 0) and (LLength <= Cardinal(Length(ABytes) - 20)) and
    (Little32(ABytes, 16) = $4E4F534A), 'Invalid GLB JSON chunk');
  SetString(LText, PAnsiChar(@ABytes[20]), LLength);
  LData := GetJSON(LText, True);
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('Invalid GLB JSON object');
  end;
  Result := TJSONObject(LData);
end;

function ModelJSON(const ABytes: TBytes; const AExtension: String): TJSONObject;
var
  LText: UTF8String;
  LData: TJSONData;
begin
  if SameText(AExtension, '.glb') then
  begin
    Result := GLBJSON(ABytes);
  end
  else
  begin
    Require(SameText(AExtension, '.gltf'), 'Unsupported source model format');
    Require(Length(ABytes) > 0, 'Empty glTF document');
    SetString(LText, PAnsiChar(@ABytes[0]), Length(ABytes));
    LData := GetJSON(LText, True);
    if not (LData is TJSONObject) then
    begin
      LData.Free;
      raise Exception.Create('Invalid glTF JSON object');
    end;
    Result := TJSONObject(LData);
  end;
  try
    Require(Result.Objects['asset'].Strings['version'] = '2.0', 'Expected glTF 2.0');
  except
    Result.Free;
    raise;
  end;
end;

end.
