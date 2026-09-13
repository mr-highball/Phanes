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
unit phanes.catalog.shared.files;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils, CastleUriUtils;

type
  { A source-byte store shared by catalog bundles. Paths keep immutable bytes
    while at least one bundle holds a reference. The caller must keep an
    externally supplied store alive longer than every bundle that uses it. }
  TCatalogSharedFiles = class
  private type
    TEntry = class
      FBytes: TBytes;
      FReferences: Integer;
    end;
  private
    FFiles: TStringList;
    FProtocol: String;
    FByteLimit: Int64;
    FUniqueBytes: Int64;
    function PathFromUrl(const AUrl: String): String;
    function ReadUrl(const AUrl: String; out AMimeType: String): TStream;
    function ExistsUrl(const AUrl: String): TUriExists;
    function GetFileCount: Integer;
  public
    constructor Create(const AByteLimit: Int64);
    destructor Destroy; override;
    procedure AcquireFile(const APath: String; const AContents: TStream);
    procedure ReleaseFile(const APath: String);
    function Url(const APath: String): String;
    property UniqueBytes: Int64 read FUniqueBytes;
    property FileCount: Integer read GetFileCount;
  end;

implementation

uses
  CastleDownload, phanes.catalog.paths;

var
  GNextSharedStore: QWord;

constructor TCatalogSharedFiles.Create(const AByteLimit: Int64);
var
  LProtocol: TRegisteredProtocol;
  LProtocolName: String;
begin
  inherited Create;
  if (AByteLimit < 1) or (AByteLimit > 64 * 1024 * 1024) then
  begin
    raise Exception.Create(
      'Shared catalog source budget must be between 1 byte and 64 MiB');
  end;
  FByteLimit := AByteLimit;
  FFiles := TStringList.Create;
  FFiles.CaseSensitive := True;
  FFiles.Sorted := True;
  if GNextSharedStore = High(QWord) then
  begin
    raise Exception.Create('Shared catalog protocol identifiers exhausted');
  end;
  Inc(GNextSharedStore);
  LProtocolName := 'phanes-shared-' + UIntToStr(GNextSharedStore);
  LProtocol := RegisterUrlProtocol(LProtocolName);
  FProtocol := LProtocolName;
  LProtocol.ReadEvent := ReadUrl;
  LProtocol.ExistsEvent := ExistsUrl;
end;

destructor TCatalogSharedFiles.Destroy;
var
  I: Integer;
begin
  if FProtocol <> '' then
  begin
    UnregisterUrlProtocol(FProtocol);
  end;
  if FFiles <> nil then
  begin
    for I := 0 to FFiles.Count - 1 do
    begin
      FFiles.Objects[I].Free;
    end;
    FFiles.Free;
  end;
  inherited Destroy;
end;

function TCatalogSharedFiles.GetFileCount: Integer;
begin
  Result := FFiles.Count;
end;

function TCatalogSharedFiles.PathFromUrl(const AUrl: String): String;
var
  LPrefix: String;
begin
  LPrefix := FProtocol + ':/';
  if Copy(AUrl, 1, Length(LPrefix)) <> LPrefix then
  begin
    raise Exception.Create('URL does not belong to this shared catalog store');
  end;
  Result := UrlDecode(Copy(AUrl, Length(LPrefix) + 1, MaxInt));
  if not CatalogFilePathValid(Result) then
  begin
    raise Exception.Create('Invalid shared catalog URL path');
  end;
end;

function TCatalogSharedFiles.ReadUrl(const AUrl: String;
  out AMimeType: String): TStream;
var
  LIndex: Integer;
  LEntry: TEntry;
begin
  LIndex := FFiles.IndexOf(PathFromUrl(AUrl));
  if LIndex < 0 then
  begin
    raise Exception.Create('Shared catalog file is not live');
  end;
  LEntry := TEntry(FFiles.Objects[LIndex]);
  Result := TMemoryStream.Create;
  try
    if Length(LEntry.FBytes) > 0 then
    begin
      Result.WriteBuffer(LEntry.FBytes[0], Length(LEntry.FBytes));
    end;
    Result.Position := 0;
    AMimeType := UriMimeType(AUrl);
  except
    Result.Free;
    raise;
  end;
end;

function TCatalogSharedFiles.ExistsUrl(const AUrl: String): TUriExists;
begin
  try
    if FFiles.IndexOf(PathFromUrl(AUrl)) >= 0 then
    begin
      Result := ueFile;
    end else
    begin
      Result := ueNotExists;
    end;
  except
    Result := ueNotExists;
  end;
end;

procedure TCatalogSharedFiles.AcquireFile(const APath: String;
  const AContents: TStream);
var
  LPosition: Int64;
  LSize: Int64;
  LData: TBytes;
  LIndex: Integer;
  I: Integer;
  LEntry: TEntry;
begin
  if AContents = nil then
  begin
    raise Exception.Create('Shared catalog file contents are missing');
  end;
  LPosition := AContents.Position;
  try
    if not CatalogFilePathValid(APath) then
    begin
      raise Exception.Create('Invalid shared catalog file path');
    end;
    LSize := AContents.Size;
    if (LSize <= 0) or (LSize > High(Integer)) then
    begin
      raise Exception.Create('Shared catalog file is empty or too large');
    end;
    LIndex := FFiles.IndexOf(APath);
    if LIndex >= 0 then
    begin
      LEntry := TEntry(FFiles.Objects[LIndex]);
      if LSize <> Length(LEntry.FBytes) then
      begin
        raise Exception.Create(
          'Shared catalog path already has different immutable bytes');
      end;
      if LEntry.FReferences = High(Integer) then
      begin
        raise Exception.Create('Shared catalog reference count exhausted');
      end;
    end else
    begin
      for I := 0 to FFiles.Count - 1 do
      begin
        if SameText(FFiles[I], APath) then
        begin
          raise Exception.Create(
            'Case-only shared catalog path alias is forbidden');
        end;
      end;
      if (LSize > FByteLimit) or (LSize > FByteLimit - FUniqueBytes) then
      begin
        raise Exception.Create(
          'Shared catalog file exceeds the remaining source budget');
      end;
    end;
    SetLength(LData, LSize);
    AContents.Position := 0;
    AContents.ReadBuffer(LData[0], LSize);
  finally
    { Restore before publishing bytes or a reference. A stream whose restore
      fails cannot leave state that its caller has no opportunity to release. }
    AContents.Position := LPosition;
  end;

  if LIndex >= 0 then
  begin
    LEntry := TEntry(FFiles.Objects[LIndex]);
    if CompareByte(LEntry.FBytes[0], LData[0], Length(LData)) <> 0 then
    begin
      raise Exception.Create(
        'Shared catalog path already has different immutable bytes');
    end;
    Inc(LEntry.FReferences);
    Exit;
  end;

  LEntry := TEntry.Create;
  LEntry.FBytes := LData;
  LEntry.FReferences := 1;
  try
    FFiles.AddObject(APath, LEntry);
  except
    LEntry.Free;
    raise;
  end;
  Inc(FUniqueBytes, LSize);
end;

procedure TCatalogSharedFiles.ReleaseFile(const APath: String);
var
  LIndex: Integer;
  LEntry: TEntry;
begin
  LIndex := FFiles.IndexOf(APath);
  if LIndex < 0 then
  begin
    raise Exception.Create('Shared catalog file has no live reference');
  end;
  LEntry := TEntry(FFiles.Objects[LIndex]);
  Dec(LEntry.FReferences);
  if LEntry.FReferences = 0 then
  begin
    Dec(FUniqueBytes, Length(LEntry.FBytes));
    FFiles.Delete(LIndex);
    LEntry.Free;
  end;
end;

function TCatalogSharedFiles.Url(const APath: String): String;
begin
  if not CatalogFilePathValid(APath) or (FFiles.IndexOf(APath) < 0) then
  begin
    raise Exception.Create(
      'Shared catalog URL requires a live exact-case path');
  end;
  Result := FProtocol + ':/' + UrlEncode(APath);
end;

end.
