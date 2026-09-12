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
unit phanes.catalog.files;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils, CastleUriUtils
  {$ifdef WASI}, JOB.JS{$endif};

type
  { Renderer-side staging for an already verified complete model closure.
    Retain this lease while its scene may reload textures or other resources.
    The limit covers retained source bytes, not decoded geometry/GPU memory.
    Hash verification and request cancellation belong to the browser fetcher. }
  TCatalogFileBundle = class
  private
    FFileSystem: TCastleMemoryFileSystem;
    FPaths: TStringList;
    FProtocol: String;
    FModelUrl: String;
    FByteLimit: Int64;
    FByteCount: Int64;
    FSealed: Boolean;
    FFailed: Boolean;
    procedure RequireWritable;
  public
    constructor Create(const AByteLimit: Int64);
    destructor Destroy; override;
    procedure AddFile(const APath: String; const AContents: TStream);
    procedure Seal(const AModelPath: String);
    property ModelUrl: String read FModelUrl;
    property ByteCount: Int64 read FByteCount;
    property Sealed: Boolean read FSealed;
  end;

function CatalogFilePathValid(const APath: String): Boolean;
{$ifdef WASI}
function CatalogBundleFromBrowser(const AValue: IJSObject;
  const AExpectedGeneration: LongInt;
  const AMaximumBytes: Int64 = 64 * 1024 * 1024): TCatalogFileBundle;
{$endif}

implementation

uses
  CastleDownload;

var
  GNextBundle: QWord;

function CatalogFilePathValid(const APath: String): Boolean;
var
  I: Integer;
  LStart: Integer;
  LPart: String;
begin
  Result := False;
  if (APath = '') or (Length(APath) > 1024) then
  begin
    Exit;
  end;
  LStart := 1;
  for I := 1 to Length(APath) + 1 do
  begin
    if I <= Length(APath) then
    begin
      if (Ord(APath[I]) < 32) or (Ord(APath[I]) = 127) or
        (APath[I] in ['\', ':', '%', '?', '#']) then
      begin
        Exit;
      end;
    end;
    if (I > Length(APath)) or (APath[I] = '/') then
    begin
      LPart := Copy(APath, LStart, I - LStart);
      if (LPart = '') or (LPart = '.') or (LPart = '..') or
        (Trim(LPart) <> LPart) then
      begin
        Exit;
      end;
      LStart := I + 1;
    end;
  end;
  Result := True;
end;

constructor TCatalogFileBundle.Create(const AByteLimit: Int64);
begin
  inherited Create;
  if (AByteLimit <= 0) or (AByteLimit > 64 * 1024 * 1024) then
  begin
    raise Exception.Create('Catalog source budget must be between 1 byte and 64 MiB');
  end;
  FByteLimit := AByteLimit;
  FPaths := TStringList.Create;
  FPaths.CaseSensitive := False;
  { Reject case aliases because the pinned memory filesystem does not set its
    internal TStringList case mode despite its documented case-sensitive API. }
  if GNextBundle = High(QWord) then
  begin
    raise Exception.Create('Catalog bundle identifiers exhausted');
  end;
  Inc(GNextBundle);
  FProtocol := 'phanes-catalog-' + UIntToStr(GNextBundle);
  FFileSystem := TCastleMemoryFileSystem.Create;
  FFileSystem.RegisterUrlProtocol(FProtocol);
end;

destructor TCatalogFileBundle.Destroy;
begin
  FFileSystem.Free;
  FPaths.Free;
  inherited Destroy;
end;

procedure TCatalogFileBundle.RequireWritable;
begin
  if FSealed or FFailed then
  begin
    raise Exception.Create('Catalog bundle is sealed or failed');
  end;
end;

procedure TCatalogFileBundle.AddFile(const APath: String; const AContents: TStream);
var
  LOutput: TStream;
  LSize: Int64;
  LPosition: Int64;
begin
  RequireWritable;
  if not CatalogFilePathValid(APath) or (FPaths.IndexOf(APath) >= 0) or
    (FPaths.Count >= 4096) then
  begin
    raise Exception.Create('Invalid or duplicate catalog file path');
  end;
  if AContents = nil then
  begin
    raise Exception.Create('Catalog file contents are missing');
  end;
  LSize := AContents.Size;
  if (LSize <= 0) or (LSize > FByteLimit - FByteCount) then
  begin
    raise Exception.Create('Catalog file exceeds the remaining source budget');
  end;
  LPosition := AContents.Position;
  try
    try
      AContents.Position := 0;
      LOutput := UrlSaveStream(FProtocol + ':/' + UrlEncode(APath));
      try
        if LOutput.CopyFrom(AContents, LSize) <> LSize then
        begin
          raise Exception.Create('Catalog file copy was incomplete');
        end;
      finally
        { Castle commits this file when the writable stream is destroyed. }
        LOutput.Free;
      end;
      FPaths.Add(APath);
      Inc(FByteCount, LSize);
    except
      FFailed := True;
      raise;
    end;
  finally
    AContents.Position := LPosition;
  end;
end;

procedure TCatalogFileBundle.Seal(const AModelPath: String);
var
  LIndex: Integer;
  LExtension: String;
begin
  RequireWritable;
  LIndex := FPaths.IndexOf(AModelPath);
  LExtension := LowerCase(ExtractFileExt(AModelPath));
  if not CatalogFilePathValid(AModelPath) or (LIndex < 0) then
  begin
    raise Exception.Create('Catalog model is not in the staged bundle');
  end;
  if (FPaths[LIndex] <> AModelPath) or
    ((LExtension <> '.glb') and (LExtension <> '.gltf')) then
  begin
    raise Exception.Create('Catalog model path has incorrect case or format');
  end;
  FModelUrl := FProtocol + ':/' + UrlEncode(AModelPath);
  FSealed := True;
end;

{$ifdef WASI}
function CatalogBundleFromBrowser(const AValue: IJSObject;
  const AExpectedGeneration: LongInt; const AMaximumBytes: Int64): TCatalogFileBundle;
var
  LFiles: IJSObject;
  LFile: IJSObject;
  LBuffer: IJSArrayBuffer;
  LContents: TMemoryStream;
  LBundle: TCatalogFileBundle;
  LCount: LongInt;
  LSize: LongInt;
  I: LongInt;
begin
  Result := nil;
  if (AValue = nil) or
    (AValue.ReadJSPropertyLongInt('generation') <> AExpectedGeneration) then
  begin
    raise Exception.Create('Catalog download generation is no longer current');
  end;
  LFiles := AValue.ReadJSPropertyObject('files', TJSObject);
  if LFiles = nil then
  begin
    raise Exception.Create('Catalog download has no files');
  end;
  LCount := LFiles.ReadJSPropertyLongInt('length');
  if (LCount <= 0) or (LCount > 4096) then
  begin
    raise Exception.Create('Catalog file count is outside the staging limit');
  end;
  LBundle := TCatalogFileBundle.Create(AMaximumBytes);
  try
    for I := 0 to LCount - 1 do
    begin
      LFile := LFiles.ReadJSPropertyObject(IntToStr(I), TJSObject);
      if LFile = nil then
      begin
        raise Exception.Create('Catalog download contains a missing file');
      end;
      LBuffer := LFile.ReadJSPropertyObject('buffer', TJSArrayBuffer) as IJSArrayBuffer;
      if LBuffer = nil then
      begin
        raise Exception.Create('Catalog file buffer is missing');
      end;
      LSize := LBuffer.ByteLength;
      if (LSize <= 0) or (LSize > AMaximumBytes - LBundle.ByteCount) then
      begin
        raise Exception.Create('Catalog buffer exceeds the remaining source budget');
      end;
      LContents := TMemoryStream.Create;
      try
        LContents.Size := LSize;
        { One bounded bridge copy, independent of asset byte count. The browser
          lease stays pinned until the caller acknowledges complete staging. }
        LBuffer.CopyToMemory(LContents.Memory, LSize);
        LBundle.AddFile(LFile.ReadJSPropertyUtf8String('path'), LContents);
      finally
        LContents.Free;
      end;
    end;
    LBundle.Seal(AValue.ReadJSPropertyUtf8String('rootPath'));
    Result := LBundle;
    LBundle := nil;
  finally
    LBundle.Free;
  end;
end;
{$endif}

end.
