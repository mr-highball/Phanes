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
unit phanes.library.files;

{$mode delphi}
{$H+}

interface

uses
  JS, Web;

const
  LibraryCacheBytes = 96 * 1024 * 1024;
  LibraryModelBytes = 64 * 1024 * 1024;
  LibraryManifestBytes = 8 * 1024 * 1024;

type
  TLibraryFiles = class
  private
    FIndexUrl: String;
    FIndex: TJSObject;
    FCache: TJSObject;
    FLeases: TJSObject;
    FBytes: Double;
    FClock: Integer;
    FJob: Integer;
    FLeaseId: Integer;
    FController: TJSAbortController;
    function ReadFile(const AFile: TJSObject; const AMaximum, AJob: Integer;
      const ASignal: TJSAbortSignal): TJSArrayBuffer; async;
    function ReadIndex(const AJob: Integer; const ASignal: TJSAbortSignal): TJSObject; async;
    function Acquire(const AFile: TJSObject; const AJob: Integer;
      const ASignal: TJSAbortSignal): TJSObject; async;
    procedure CheckJob(const AJob: Integer);
    procedure MakeRoom(const ABytes: Double);
    procedure Unpin(const AEntries: TJSArray);
    procedure Progress(const AModel: String; const AComplete, ATotal: Double);
  public
    constructor Create(const AIndexUrl: String);
    function LoadModel(const AKit, AModel: String): TJSObject; async;
    procedure Cancel;
    procedure Release(const ALeaseId: String);
    procedure ClearUnused;
    function Stats: TJSObject;
  end;

function ValidLibraryPath(const APath: String): Boolean;
function LibraryIntegrity(const AHash: String): String;
procedure ValidateLibraryModel(const AModel: TJSObject);

implementation

uses
  SysUtils, Math;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function ObjectField(const AData: TJSObject; const AKey: String): TJSObject;
begin
  Require(isObject(AData[AKey]) and not isNull(AData[AKey]) and
    not TJSArray.isArray(AData[AKey]), 'Invalid library object: ' + AKey);
  Result := TJSObject(AData[AKey]);
end;

function StringField(const AData: TJSObject; const AKey: String): String;
begin
  Require(isString(AData[AKey]), 'Invalid library text: ' + AKey);
  Result := String(AData[AKey]);
end;

function FileBytes(const AFile: TJSObject; const AMaximum: Integer): Integer;
begin
  Require(isInteger(AFile['bytes']) and (Double(AFile['bytes']) > 0) and
    (Double(AFile['bytes']) <= AMaximum), 'Library file exceeds the loading allowance.');
  Result := Integer(AFile['bytes']);
end;

function ValidLibraryPath(const APath: String): Boolean;
var
  LParts: TStringDynArray;
  LPart: String;
  I: Integer;
begin
  Result := False;
  if (APath = '') or (Length(APath) > 512) then
  begin
    Exit;
  end;
  for I := 1 to Length(APath) do
  begin
    if (Ord(APath[I]) < 32) or (Pos(APath[I], '\:?#%') > 0) then
    begin
      Exit;
    end;
  end;
  LParts := APath.Split(['/']);
  for LPart in LParts do
  begin
    if (LPart = '') or (LPart = '.') or (LPart = '..') or
      (LPart = '__proto__') or (LPart = 'constructor') or (LPart = 'prototype') then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function LibraryIntegrity(const AHash: String): String;
const
  CHex = '0123456789abcdef';
var
  LBytes: String;
  LHigh: Integer;
  LLow: Integer;
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Invalid library SHA-256.');
  LBytes := '';
  for I := 0 to 31 do
  begin
    LHigh := Pos(AHash[I * 2 + 1], CHex) - 1;
    LLow := Pos(AHash[I * 2 + 2], CHex) - 1;
    Require((LHigh >= 0) and (LLow >= 0), 'Invalid library SHA-256.');
    LBytes := LBytes + Chr(LHigh * 16 + LLow);
  end;
  { Fetch performs native subresource-integrity verification on same-origin
    HTTP too. This avoids a second download or a secure-context-only crypto API. }
  Result := 'sha256-' + window.btoa(LBytes);
end;

procedure ValidateLibraryModel(const AModel: TJSObject);
var
  LFiles: TJSArray;
  LFile: TJSObject;
  LPaths: TJSObject;
  LPath: String;
  LRoot: String;
  LHash: String;
  LTotal: Double;
  LFound: Boolean;
  I: Integer;
begin
  Require(ValidLibraryPath(StringField(AModel, 'id')), 'Invalid library model ID.');
  LRoot := StringField(AModel, 'path');
  Require(ValidLibraryPath(LRoot), 'Invalid model path.');
  Require((StringField(AModel, 'format') = 'glb') or
    (StringField(AModel, 'format') = 'gltf'), 'Unsupported library model format.');
  Require(LowerCase(ExtractFileExt(LRoot)) = '.' + String(AModel['format']),
    'Model format and file extension differ.');
  Require(TJSArray.isArray(AModel['files']), 'Library model has no file closure.');
  LFiles := TJSArray(AModel['files']);
  Require((LFiles.length > 0) and (LFiles.length <= 128), 'Unsupported model file count.');
  LPaths := TJSObject.new;
  LTotal := 0;
  LFound := False;
  for I := 0 to LFiles.length - 1 do
  begin
    Require(isObject(LFiles[I]) and not isNull(LFiles[I]), 'Invalid model file.');
    LFile := TJSObject(LFiles[I]);
    LPath := StringField(LFile, 'path');
    Require(ValidLibraryPath(LPath) and not LPaths.hasOwnProperty(LPath),
      'Duplicate or invalid model file path.');
    LPaths[LPath] := True;
    LHash := StringField(LFile, 'sha256');
    LibraryIntegrity(LHash);
    Require(StringField(LFile, 'url') = 'library/blobs/' + LHash,
      'Unexpected library file URL.');
    LTotal := LTotal + FileBytes(LFile, LibraryModelBytes);
    if LPath = LRoot then
    begin
      Require(LHash = StringField(AModel, 'sha256'), 'Model source hash differs.');
      LFound := True;
    end;
  end;
  Require(LFound, 'Library model source is missing from its file closure.');
  Require(isInteger(AModel['downloadBytes']) and
    (LTotal = Double(AModel['downloadBytes'])) and (LTotal <= LibraryModelBytes),
    'Model download size differs or exceeds the loading allowance.');
end;

constructor TLibraryFiles.Create(const AIndexUrl: String);
begin
  inherited Create;
  FIndexUrl := AIndexUrl;
  FCache := TJSObject.new;
  FLeases := TJSObject.new;
end;

procedure TLibraryFiles.CheckJob(const AJob: Integer);
begin
  Require(AJob = FJob, 'Model loading was cancelled.');
end;

procedure TLibraryFiles.Cancel;
begin
  Inc(FJob);
  if FController <> nil then
  begin
    FController.abort;
    FController := nil;
  end;
end;

function TLibraryFiles.ReadFile(const AFile: TJSObject; const AMaximum, AJob: Integer;
  const ASignal: TJSAbortSignal): TJSArrayBuffer;
var
  LOptions: TJSObject;
  LResponse: TJSResponse;
  LExpected: Integer;
begin
  CheckJob(AJob);
  LExpected := FileBytes(AFile, AMaximum);
  LOptions := TJSObject.new;
  LOptions['signal'] := ASignal;
  LOptions['integrity'] := LibraryIntegrity(StringField(AFile, 'sha256'));
  LResponse := await(TJSResponse, window.fetch(StringField(AFile, 'url'), LOptions));
  CheckJob(AJob);
  Require(LResponse.ok, 'Could not load the library file (HTTP ' + IntToStr(LResponse.status) + ').');
  Result := await(TJSArrayBuffer, LResponse.arrayBuffer);
  CheckJob(AJob);
  Require(Result.byteLength = LExpected, 'Downloaded model file has an unexpected size.');
end;

function TLibraryFiles.ReadIndex(const AJob: Integer; const ASignal: TJSAbortSignal): TJSObject;
var
  LResponse: TJSResponse;
  LOptions: TJSObject;
  LText: String;
begin
  if FIndex <> nil then
  begin
    Exit(FIndex);
  end;
  LOptions := TJSObject.new;
  LOptions['signal'] := ASignal;
  LResponse := await(TJSResponse, window.fetch(FIndexUrl, LOptions));
  CheckJob(AJob);
  Require(LResponse.ok, 'The optional library index is unavailable.');
  LText := await(String, LResponse.text);
  CheckJob(AJob);
  Require(Length(LText) <= 256 * 1024, 'Library index exceeds its allowance.');
  Result := TJSObject(TJSJSON.parse(LText));
  Require((Result['version'] = 1) and (Result['recipe'] = 'phanes.catalog.files.v1') and
    TJSArray.isArray(Result['kits']), 'Unsupported library index.');
  FIndex := Result;
end;

procedure TLibraryFiles.MakeRoom(const ABytes: Double);
var
  LKey: String;
  LOldest: String;
  LTick: Double;
  LEntry: TJSObject;
begin
  while FBytes + ABytes > LibraryCacheBytes do
  begin
    LOldest := '';
    LTick := Infinity;
    for LKey in TJSObject.keys(FCache) do
    begin
      LEntry := TJSObject(FCache[LKey]);
      if (Integer(LEntry['pins']) = 0) and (Double(LEntry['used']) < LTick) then
      begin
        LTick := Double(LEntry['used']);
        LOldest := LKey;
      end;
    end;
    Require(LOldest <> '', 'The model memory allowance is in use. Release an unused model first.');
    LEntry := TJSObject(FCache[LOldest]);
    FBytes := FBytes - TJSArrayBuffer(LEntry['buffer']).byteLength;
    JSDelete(FCache, LOldest);
  end;
end;

function TLibraryFiles.Acquire(const AFile: TJSObject; const AJob: Integer;
  const ASignal: TJSAbortSignal): TJSObject;
var
  LHash: String;
  LBuffer: TJSArrayBuffer;
begin
  CheckJob(AJob);
  LHash := StringField(AFile, 'sha256');
  if FCache.hasOwnProperty(LHash) then
  begin
    Result := TJSObject(FCache[LHash]);
    Require(TJSArrayBuffer(Result['buffer']).byteLength = FileBytes(AFile, LibraryModelBytes),
      'Cached file size differs from the model manifest.');
  end else
  begin
    MakeRoom(FileBytes(AFile, LibraryModelBytes));
    LBuffer := await(ReadFile(AFile, LibraryModelBytes, AJob, ASignal));
    CheckJob(AJob);
    Result := TJSObject.new;
    Result['buffer'] := LBuffer;
    Result['pins'] := 0;
    FCache[LHash] := Result;
    FBytes := FBytes + LBuffer.byteLength;
  end;
  Inc(FClock);
  Result['used'] := FClock;
  Result['pins'] := Integer(Result['pins']) + 1;
end;

procedure TLibraryFiles.Unpin(const AEntries: TJSArray);
var
  LEntry: TJSObject;
  I: Integer;
begin
  for I := 0 to AEntries.length - 1 do
  begin
    LEntry := TJSObject(AEntries[I]);
    Require(Integer(LEntry['pins']) > 0, 'Library file ownership is unbalanced.');
    LEntry['pins'] := Integer(LEntry['pins']) - 1;
  end;
end;

procedure TLibraryFiles.Progress(const AModel: String; const AComplete, ATotal: Double);
var
  LDetail: TJSObject;
  LEvent: TJSCustomEventInit;
begin
  LDetail := TJSObject.new;
  LDetail['model'] := AModel;
  LDetail['completedBytes'] := AComplete;
  LDetail['totalBytes'] := ATotal;
  LEvent := TJSCustomEventInit.new;
  LEvent.detail := LDetail;
  window.dispatchEvent(TJSCustomEvent.new('phanes-library-progress', LEvent));
end;

function TLibraryFiles.LoadModel(const AKit, AModel: String): TJSObject;
var
  LJob: Integer;
  LController: TJSAbortController;
  LIndex: TJSObject;
  LKit: TJSObject;
  LManifest: TJSObject;
  LModel: TJSObject;
  LFile: TJSObject;
  LEntry: TJSObject;
  LFiles: TJSObject;
  LNotice: TJSObject;
  LEntries: TJSArray;
  LRows: TJSArray;
  LBuffer: TJSArrayBuffer;
  LLease: String;
  LComplete: Double;
  LTotal: Double;
  I: Integer;
begin
  Require(ValidLibraryPath(AKit) and (Pos('/', AKit) = 0) and
    ValidLibraryPath(AModel), 'Invalid library selection.');
  Cancel;
  LJob := FJob;
  LController := TJSAbortController.new;
  FController := LController;
  LEntries := TJSArray.new;
  try
    LIndex := await(ReadIndex(LJob, LController.signal));
    LKit := nil;
    LRows := TJSArray(LIndex['kits']);
    for I := 0 to LRows.length - 1 do
    begin
      if TJSObject(LRows[I])['id'] = AKit then
      begin
        LKit := TJSObject(LRows[I]);
        Break;
      end;
    end;
    Require(LKit <> nil, 'This kit is not in the optional library.');
    Require(StringField(LKit, 'url') = 'library/catalog/' + AKit + '-' +
      StringField(LKit, 'sha256') + '.json', 'Unexpected library manifest URL.');
    LBuffer := await(ReadFile(LKit, LibraryManifestBytes, LJob, LController.signal));
    LManifest := TJSObject(TJSJSON.parse(TJSTextDecoder.new.decode(LBuffer)));
    Require((LManifest['version'] = 1) and (LManifest['kit'] = AKit) and
      (LManifest['inventorySha256'] = LIndex['inventorySha256']) and
      TJSArray.isArray(LManifest['models']), 'Library manifest identity differs.');
    LNotice := ObjectField(LManifest, 'notice');
    Require(ValidLibraryPath(StringField(LNotice, 'path')) and
      (StringField(LNotice, 'url') = 'library/blobs/' + StringField(LNotice, 'sha256')),
      'Invalid library notice.');
    FileBytes(LNotice, LibraryModelBytes);
    LModel := nil;
    LRows := TJSArray(LManifest['models']);
    for I := 0 to LRows.length - 1 do
    begin
      if TJSObject(LRows[I])['id'] = AModel then
      begin
        LModel := TJSObject(LRows[I]);
        Break;
      end;
    end;
    Require(LModel <> nil, 'This model is not in the selected kit.');
    ValidateLibraryModel(LModel);
    LTotal := Double(LModel['downloadBytes']) + FileBytes(LNotice, LibraryModelBytes);
    Require(LTotal <= LibraryModelBytes, 'Model and notice exceed the loading allowance.');
    LFiles := TJSObject.new;
    LRows := TJSArray(LModel['files']);
    LComplete := 0;
    Progress(AModel, 0, LTotal);
    for I := 0 to LRows.length do
    begin
      if I = LRows.length then
      begin
        LFile := LNotice;
      end else
      begin
        LFile := TJSObject(LRows[I]);
      end;
      LEntry := await(Acquire(LFile, LJob, LController.signal));
      LEntries.push(LEntry);
      LFiles[String(LFile['path'])] := LEntry['buffer'];
      LComplete := LComplete + TJSArrayBuffer(LEntry['buffer']).byteLength;
      Progress(AModel, LComplete, LTotal);
    end;
    CheckJob(LJob);
    Inc(FLeaseId);
    LLease := 'model-' + IntToStr(FLeaseId);
    FLeases[LLease] := LEntries;
    Result := TJSObject.new;
    Result['lease'] := LLease;
    Result['id'] := AModel;
    Result['path'] := LModel['path'];
    Result['format'] := LModel['format'];
    Result['files'] := LFiles;
    Result['source'] := LManifest['source'];
    Result['author'] := LManifest['author'];
    Result['license'] := LManifest['license'];
    Result['notice'] := LNotice['path'];
    LEntries := nil;
  finally
    if LEntries <> nil then
    begin
      Unpin(LEntries);
    end;
    if LJob = FJob then
    begin
      FController := nil;
    end;
  end;
end;

procedure TLibraryFiles.Release(const ALeaseId: String);
begin
  if FLeases.hasOwnProperty(ALeaseId) then
  begin
    Unpin(TJSArray(FLeases[ALeaseId]));
    JSDelete(FLeases, ALeaseId);
  end;
end;

procedure TLibraryFiles.ClearUnused;
var
  LKey: String;
  LEntry: TJSObject;
begin
  for LKey in TJSObject.keys(FCache) do
  begin
    LEntry := TJSObject(FCache[LKey]);
    if Integer(LEntry['pins']) = 0 then
    begin
      FBytes := FBytes - TJSArrayBuffer(LEntry['buffer']).byteLength;
      JSDelete(FCache, LKey);
    end;
  end;
end;

function TLibraryFiles.Stats: TJSObject;
begin
  Result := TJSObject.new;
  Result['bytes'] := FBytes;
  Result['files'] := Length(TJSObject.keys(FCache));
  Result['leases'] := Length(TJSObject.keys(FLeases));
  Result['loading'] := FController <> nil;
  Result['budgetBytes'] := LibraryCacheBytes;
end;

end.
