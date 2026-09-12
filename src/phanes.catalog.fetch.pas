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
unit phanes.catalog.fetch;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses
  JS, Web;

const
  CatalogFetchCacheBytes = 96 * 1024 * 1024;
  CatalogFetchModelBytes = 64 * 1024 * 1024;
  CatalogFetchManifestBytes = 8 * 1024 * 1024;
  CatalogFetchIndexBytes = 256 * 1024;
  CatalogFetchTimeoutMilliseconds = 60000;
  { One transaction is active and its files are fetched one at a time. Keeping
    this explicit makes the network and temporary-buffer bound part of the API. }
  CatalogFetchConcurrency = 1;

type
  TCatalogAbortSignal = class external name 'AbortSignal'(TJSObject)
  end;

  TCatalogAbortController = class external name 'AbortController'(TJSObject)
  private
    FSignal: TCatalogAbortSignal; external name 'signal';
  public
    constructor new;
    procedure abort;
    property signal: TCatalogAbortSignal read FSignal;
  end;

  TCatalogStreamReader = class external name 'Object'(TJSObject)
    function read: TJSPromise;
    function cancel: TJSPromise;
    procedure releaseLock;
  end;

  TCatalogReadableStream = class external name 'ReadableStream'(TJSObject)
    function getReader: TCatalogStreamReader;
  end;

  TCatalogFetcher = class
  private
    FIndexUrl: String;
    FPublicationBaseUrl: String;
    FIndex: TJSObject;
    FCache: TJSObject;
    FLeases: TJSObject;
    FCacheBytes: Double;
    FCacheBudget: Integer;
    FClock: Integer;
    FGeneration: Integer;
    FLeaseSerial: Integer;
    FController: TCatalogAbortController;
    function AbsoluteUrl(const APath: String): String;
    procedure CheckGeneration(const AGeneration: Integer);
    function ReadBoundedResponse(const AResponse: TJSResponse;
      const AExpected, AMaximum, AGeneration: Integer): TJSArrayBuffer; async;
    function FetchBytes(const AFile: TJSObject; const AMaximum,
      AGeneration: Integer; const ASignal: TCatalogAbortSignal): TJSArrayBuffer; async;
    function ReadIndex(const AGeneration: Integer;
      const ASignal: TCatalogAbortSignal): TJSObject; async;
    procedure MakeRoom(const ABytes: Double; const AProtectedHashes: TJSObject);
    procedure Unpin(const AEntries: TJSArray);
    procedure ReportProgress(const AModel: String; const AGeneration: Integer;
      const ACompleted, ATotal: Double);
  public
    constructor Create(const AIndexUrl: String;
      const ACacheBudget: Integer = CatalogFetchCacheBytes);
    function FetchModel(const AKitId, AModelId: String): TJSObject; async;
    procedure Cancel;
    procedure Release(const ALease: String);
    procedure ClearUnused;
    function Stats: TJSObject;
  end;

function CatalogFetchIntegrity(const AHash: String): String;
function IsCanonicalCatalogPath(const APath: String): Boolean;
procedure ValidateCatalogModel(const AKitId, AModelId: String;
  const AModel, ANotice: TJSObject);

implementation

uses
  SysUtils, Types, Math;

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
    not TJSArray.isArray(AData[AKey]), 'Invalid catalog object: ' + AKey);
  Result := TJSObject(AData[AKey]);
end;

function StringField(const AData: TJSObject; const AKey: String): String;
begin
  Require(isString(AData[AKey]), 'Invalid catalog text: ' + AKey);
  Result := String(AData[AKey]);
end;

function BoundedBytes(const AFile: TJSObject; const AMaximum: Integer): Integer;
begin
  Require(isInteger(AFile['bytes']) and (Double(AFile['bytes']) > 0) and
    (Double(AFile['bytes']) <= AMaximum), 'Catalog file exceeds its byte allowance.');
  Result := Integer(AFile['bytes']);
end;

function IsCanonicalCatalogPath(const APath: String): Boolean;
var
  LParts: TStringDynArray;
  LPart: String;
  I: Integer;
begin
  Result := False;
  if (APath = '') or (Length(APath) > 512) or (APath[1] = '/') or
    (APath[Length(APath)] = '/') then
  begin
    Exit;
  end;
  for I := 1 to Length(APath) do
  begin
    if (Ord(APath[I]) < 32) or (Ord(APath[I]) = 127) or
      (Pos(APath[I], '\\:?#%') > 0) then
    begin
      Exit;
    end;
  end;
  LParts := APath.Split(['/']);
  for LPart in LParts do
  begin
    if (LPart = '') or (LPart = '.') or (LPart = '..') or
      (LPart = '__proto__') or (LPart = 'constructor') or
      (LPart = 'prototype') then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function CatalogFetchIntegrity(const AHash: String): String;
const
  CHex = '0123456789abcdef';
var
  LBytes: String;
  LHigh: Integer;
  LLow: Integer;
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Invalid catalog SHA-256.');
  LBytes := '';
  for I := 0 to 31 do
  begin
    LHigh := Pos(AHash[I * 2 + 1], CHex) - 1;
    LLow := Pos(AHash[I * 2 + 2], CHex) - 1;
    Require((LHigh >= 0) and (LLow >= 0), 'Invalid catalog SHA-256.');
    LBytes := LBytes + Chr(LHigh * 16 + LLow);
  end;
  { Fetch SRI works for same-origin plain HTTP, unlike Web Crypto. Supplying an
    exact supported digest keeps corrupt responses from reaching the bundle. }
  Result := 'sha256-' + window.btoa(LBytes);
end;

procedure ValidateFile(const AFile: TJSObject; const APaths: TJSObject;
  const AMaximum: Integer);
var
  LPath: String;
  LHash: String;
begin
  LPath := StringField(AFile, 'path');
  Require(IsCanonicalCatalogPath(LPath) and
    not APaths.hasOwnProperty(LowerCase(LPath)),
    'Duplicate or unsafe catalog file path.');
  { Castle's browser memory filesystem resolves paths case-insensitively. Reject
    aliases here so a verified closure cannot change meaning during staging. }
  APaths[LowerCase(LPath)] := True;
  LHash := StringField(AFile, 'sha256');
  CatalogFetchIntegrity(LHash);
  Require(StringField(AFile, 'url') = 'library/blobs/' + LHash,
    'Catalog blob URL does not match its content hash.');
  BoundedBytes(AFile, AMaximum);
end;

procedure ValidateCatalogModel(const AKitId, AModelId: String;
  const AModel, ANotice: TJSObject);
var
  LFiles: TJSArray;
  LFile: TJSObject;
  LPaths: TJSObject;
  LRoot: String;
  LFormat: String;
  LTotal: Double;
  LFoundRoot: Boolean;
  I: Integer;
begin
  Require(StringField(AModel, 'id') = AModelId, 'Catalog returned a different model ID.');
  Require(Pos(AKitId + '/', AModelId) = 1, 'Model ID does not belong to its kit.');
  Require(IsCanonicalCatalogPath(AModelId), 'Invalid catalog model ID.');
  LRoot := StringField(AModel, 'path');
  Require(IsCanonicalCatalogPath(LRoot), 'Invalid catalog model path.');
  LFormat := StringField(AModel, 'format');
  Require((LFormat = 'glb') or (LFormat = 'gltf'), 'Unsupported catalog model format.');
  Require(LowerCase(ExtractFileExt(LRoot)) = '.' + LFormat,
    'Catalog model format and extension differ.');
  Require(TJSArray.isArray(AModel['files']), 'Catalog model has no file closure.');
  LFiles := TJSArray(AModel['files']);
  Require((LFiles.length > 0) and (LFiles.length <= 128),
    'Unsupported catalog model file count.');
  LPaths := TJSObject.new;
  LTotal := 0;
  LFoundRoot := False;
  for I := 0 to LFiles.length - 1 do
  begin
    Require(isObject(LFiles[I]) and not isNull(LFiles[I]) and
      not TJSArray.isArray(LFiles[I]), 'Invalid catalog model file.');
    LFile := TJSObject(LFiles[I]);
    ValidateFile(LFile, LPaths, CatalogFetchModelBytes);
    LTotal := LTotal + BoundedBytes(LFile, CatalogFetchModelBytes);
    if StringField(LFile, 'path') = LRoot then
    begin
      Require(StringField(LFile, 'sha256') = StringField(AModel, 'sha256'),
        'Catalog root model hash differs from its closure.');
      LFoundRoot := True;
    end;
  end;
  Require(LFoundRoot, 'Catalog root model is absent from its closure.');
  Require(isInteger(AModel['downloadBytes']) and
    (LTotal = Double(AModel['downloadBytes'])), 'Catalog model byte total differs.');
  Require(isObject(ANotice) and not isNull(ANotice) and
    not TJSArray.isArray(ANotice), 'Catalog notice is missing.');
  ValidateFile(ANotice, LPaths, CatalogFetchModelBytes);
  LTotal := LTotal + BoundedBytes(ANotice, CatalogFetchModelBytes);
  Require(LTotal <= CatalogFetchModelBytes,
    'Catalog model and notice exceed the transaction allowance.');
end;

constructor TCatalogFetcher.Create(const AIndexUrl: String;
  const ACacheBudget: Integer);
begin
  inherited Create;
  Require(IsCanonicalCatalogPath(AIndexUrl), 'Choose a local canonical catalog index URL.');
  Require((ACacheBudget > 0) and (ACacheBudget <= CatalogFetchCacheBytes),
    'Catalog cache budget must be within the hard memory limit.');
  FIndexUrl := AIndexUrl;
  FCacheBudget := ACacheBudget;
  FCache := TJSObject.new;
  FLeases := TJSObject.new;
  asm
    this.FPublicationBaseUrl = new URL('.', document.baseURI).href;
  end;
end;

function TCatalogFetcher.AbsoluteUrl(const APath: String): String;
begin
  asm
    Result = new URL(APath, this.FPublicationBaseUrl).href;
  end;
end;

procedure TCatalogFetcher.CheckGeneration(const AGeneration: Integer);
begin
  Require(AGeneration = FGeneration, 'Catalog fetch was cancelled.');
end;

function TCatalogFetcher.ReadBoundedResponse(const AResponse: TJSResponse;
  const AExpected, AMaximum, AGeneration: Integer): TJSArrayBuffer;
var
  LBody: TCatalogReadableStream;
  LReader: TCatalogStreamReader;
  LRead: TJSObject;
  LChunk: TJSUint8Array;
  LBytes: TJSUint8Array;
  LLimit: Integer;
  LOffset: Integer;
  LComplete: Boolean;
  LCancel: TJSPromise;
begin
  Require((AMaximum > 0) and (AExpected <= AMaximum),
    'Invalid catalog response byte allowance.');
  if AExpected >= 0 then
  begin
    LLimit := AExpected;
  end else
  begin
    LLimit := AMaximum;
  end;
  Require(isObject(TJSObject(AResponse)['body']) and
    not isNull(TJSObject(AResponse)['body']),
    'Catalog response has no readable body.');
  LBody := TCatalogReadableStream(TJSObject(AResponse)['body']);
  LReader := LBody.getReader;
  Require(LReader <> nil, 'Catalog response body has no reader.');
  { Exact responses copy directly into their final app-owned buffer. The small
    index may briefly own its fixed maximum plus a trimmed result. Fetch SRI may
    buffer internally before exposing this stream; that browser allocation is
    outside the loader's application-buffer bound. }
  LBytes := TJSUint8Array.new(LLimit);
  LOffset := 0;
  LComplete := False;
  try
    repeat
      CheckGeneration(AGeneration);
      LRead := await(TJSObject, LReader.read);
      CheckGeneration(AGeneration);
      Require(isObject(LRead) and not isNull(LRead),
        'Catalog response reader returned an invalid result.');
      if Boolean(LRead['done']) then
      begin
        Break;
      end;
      Require(isObject(LRead['value']) and not isNull(LRead['value']),
        'Catalog response reader returned an invalid chunk.');
      LChunk := TJSUint8Array(LRead['value']);
      Require((LChunk.byteLength > 0) and
        (LChunk.byteLength <= LLimit - LOffset),
        'Catalog response exceeded its byte allowance.');
      LBytes._set(LChunk, LOffset);
      Inc(LOffset, LChunk.byteLength);
    until False;
    CheckGeneration(AGeneration);
    if AExpected >= 0 then
    begin
      Require(LOffset = AExpected, 'Catalog response bytes differ from its manifest.');
      Result := LBytes.buffer;
    end else
    begin
      Require(LOffset > 0, 'Catalog response body is empty.');
      Result := LBytes.buffer.slice(0, LOffset);
    end;
    LComplete := True;
  finally
    if not LComplete then
    begin
      try
        LCancel := LReader.cancel;
        if LCancel <> nil then
        begin
          { Cancellation of an already errored stream may itself reject. Consume
            that cleanup result asynchronously without replacing or delaying the
            original bound, integrity, cancellation or read failure. }
          LCancel.&catch(function(AReason: JSValue): JSValue
            begin
              Result := Undefined;
            end);
        end;
      except
        on Exception do
        begin
          { Preserve the original failure if cancellation throws synchronously. }
        end;
      end;
    end;
    try
      LReader.releaseLock;
    except
      on Exception do
      begin
        { Cleanup cannot replace a completed result or the original failure. }
      end;
    end;
  end;
end;

procedure TCatalogFetcher.Cancel;
begin
  Inc(FGeneration);
  if FController <> nil then
  begin
    FController.abort;
    FController := nil;
  end;
end;

function TCatalogFetcher.FetchBytes(const AFile: TJSObject; const AMaximum,
  AGeneration: Integer; const ASignal: TCatalogAbortSignal): TJSArrayBuffer;
var
  LOptions: TJSObject;
  LResponse: TJSResponse;
  LExpected: Integer;
begin
  CheckGeneration(AGeneration);
  LExpected := BoundedBytes(AFile, AMaximum);
  LOptions := TJSObject.new;
  LOptions['signal'] := ASignal;
  LOptions['integrity'] := CatalogFetchIntegrity(StringField(AFile, 'sha256'));
  LOptions['cache'] := 'no-store';
  LResponse := await(TJSResponse,
    window.fetch(AbsoluteUrl(StringField(AFile, 'url')), LOptions));
  CheckGeneration(AGeneration);
  Require(LResponse.ok, 'Catalog file request failed (HTTP ' +
    IntToStr(LResponse.status) + ').');
  if LResponse.headers.has('content-length') then
  begin
    Require(StrToIntDef(LResponse.headers.get('content-length'), -1) = LExpected,
      'Catalog response length differs from its manifest.');
  end;
  Result := await(ReadBoundedResponse(LResponse, LExpected, LExpected, AGeneration));
end;

function TCatalogFetcher.ReadIndex(const AGeneration: Integer;
  const ASignal: TCatalogAbortSignal): TJSObject;
var
  LOptions: TJSObject;
  LResponse: TJSResponse;
  LBuffer: TJSArrayBuffer;
  LKits: TJSArray;
begin
  if FIndex <> nil then
  begin
    Exit(FIndex);
  end;
  LOptions := TJSObject.new;
  LOptions['signal'] := ASignal;
  LOptions['cache'] := 'no-store';
  LResponse := await(TJSResponse, window.fetch(AbsoluteUrl(FIndexUrl), LOptions));
  CheckGeneration(AGeneration);
  Require(LResponse.ok, 'The optional catalog index is unavailable.');
  if LResponse.headers.has('content-length') then
  begin
    Require((StrToIntDef(LResponse.headers.get('content-length'), -1) > 0) and
      (StrToIntDef(LResponse.headers.get('content-length'), -1) <=
      CatalogFetchIndexBytes), 'Catalog index exceeds its byte allowance.');
  end;
  LBuffer := await(ReadBoundedResponse(LResponse, -1, CatalogFetchIndexBytes,
    AGeneration));
  Result := TJSObject(TJSJSON.parse(TJSTextDecoder.new.decode(LBuffer)));
  Require(isObject(Result) and not isNull(Result) and not TJSArray.isArray(Result) and
    isInteger(Result['version']) and (Integer(Result['version']) = 1) and
    (StringField(Result, 'recipe') = 'phanes.catalog.files.v1') and
    TJSArray.isArray(Result['kits']), 'Unsupported catalog index.');
  CatalogFetchIntegrity(StringField(Result, 'inventorySha256'));
  CatalogFetchIntegrity(StringField(Result, 'sourceLockSha256'));
  LKits := TJSArray(Result['kits']);
  Require((LKits.length > 0) and (LKits.length <= 512),
    'Unsupported catalog kit count.');
  FIndex := Result;
end;

procedure TCatalogFetcher.MakeRoom(const ABytes: Double;
  const AProtectedHashes: TJSObject);
var
  LKeys: TStringDynArray;
  LKey: String;
  LOldest: String;
  LOldestTick: Double;
  LEntry: TJSObject;
begin
  Require(ABytes <= FCacheBudget, 'Catalog cache cannot retain this transaction.');
  while FCacheBytes + ABytes > FCacheBudget do
  begin
    LOldest := '';
    LOldestTick := Infinity;
    LKeys := TJSObject.keys(FCache);
    for LKey in LKeys do
    begin
      LEntry := TJSObject(FCache[LKey]);
      if (Integer(LEntry['pins']) = 0) and
        not AProtectedHashes.hasOwnProperty(LKey) and
        (Double(LEntry['used']) < LOldestTick) then
      begin
        LOldest := LKey;
        LOldestTick := Double(LEntry['used']);
      end;
    end;
    Require(LOldest <> '', 'Release a catalog bundle before loading this model.');
    LEntry := TJSObject(FCache[LOldest]);
    FCacheBytes := FCacheBytes - TJSArrayBuffer(LEntry['buffer']).byteLength;
    JSDelete(FCache, LOldest);
  end;
end;

procedure TCatalogFetcher.Unpin(const AEntries: TJSArray);
var
  LEntry: TJSObject;
  I: Integer;
begin
  for I := 0 to AEntries.length - 1 do
  begin
    LEntry := TJSObject(AEntries[I]);
    Require(Integer(LEntry['pins']) > 0, 'Catalog bundle ownership is unbalanced.');
    LEntry['pins'] := Integer(LEntry['pins']) - 1;
  end;
end;

procedure TCatalogFetcher.ReportProgress(const AModel: String;
  const AGeneration: Integer; const ACompleted, ATotal: Double);
var
  LDetail: TJSObject;
begin
  CheckGeneration(AGeneration);
  LDetail := TJSObject.new;
  LDetail['modelId'] := AModel;
  LDetail['generation'] := AGeneration;
  LDetail['completedBytes'] := ACompleted;
  LDetail['totalBytes'] := ATotal;
  asm
    window.dispatchEvent(new CustomEvent('phanes-catalog-fetch-progress',
      {detail: LDetail}));
  end;
end;

function TCatalogFetcher.FetchModel(const AKitId, AModelId: String): TJSObject;
var
  LGeneration: Integer;
  LController: TCatalogAbortController;
  LTimeout: NativeInt;
  LIndex: TJSObject;
  LKit: TJSObject;
  LManifestDescriptor: TJSObject;
  LManifestBuffer: TJSArrayBuffer;
  LManifest: TJSObject;
  LNotice: TJSObject;
  LModel: TJSObject;
  LKits: TJSArray;
  LModels: TJSArray;
  LFiles: TJSArray;
  LAllFiles: TJSArray;
  LStaged: TJSArray;
  LTransactionEntries: TJSObject;
  LLeaseEntries: TJSArray;
  LRows: TJSArray;
  LFile: TJSObject;
  LStage: TJSObject;
  LEntry: TJSObject;
  LRow: TJSObject;
  LHash: String;
  LLease: String;
  LCompleted: Double;
  LTotal: Double;
  LNewBytes: Double;
  LRequiredBytes: Double;
  LHashes: TStringDynArray;
  LMatches: Integer;
  I: Integer;
begin
  Require(IsCanonicalCatalogPath(AKitId) and (Pos('/', AKitId) = 0) and
    IsCanonicalCatalogPath(AModelId), 'Invalid catalog selection.');
  Cancel;
  LGeneration := FGeneration;
  LController := TCatalogAbortController.new;
  FController := LController;
  LTimeout := window.setTimeout(procedure
    begin
      LController.abort;
    end, CatalogFetchTimeoutMilliseconds);
  try
    LIndex := await(ReadIndex(LGeneration, LController.signal));
    LKits := TJSArray(LIndex['kits']);
    LKit := nil;
    LMatches := 0;
    for I := 0 to LKits.length - 1 do
    begin
      Require(isObject(LKits[I]) and not isNull(LKits[I]) and
        not TJSArray.isArray(LKits[I]), 'Invalid catalog kit entry.');
      if StringField(TJSObject(LKits[I]), 'id') = AKitId then
      begin
        Inc(LMatches);
        LKit := TJSObject(LKits[I]);
      end;
    end;
    Require(LMatches = 1, 'Catalog kit selection is absent or ambiguous.');
    CatalogFetchIntegrity(StringField(LKit, 'sha256'));
    Require(StringField(LKit, 'url') = 'library/catalog/' + AKitId + '-' +
      StringField(LKit, 'sha256') + '.json', 'Catalog manifest URL is not hash-bound.');
    BoundedBytes(LKit, CatalogFetchManifestBytes);
    LManifestDescriptor := TJSObject.new;
    LManifestDescriptor['path'] := LKit['url'];
    LManifestDescriptor['url'] := LKit['url'];
    LManifestDescriptor['sha256'] := LKit['sha256'];
    LManifestDescriptor['bytes'] := LKit['bytes'];
    LManifestBuffer := await(FetchBytes(LManifestDescriptor, CatalogFetchManifestBytes,
      LGeneration, LController.signal));
    LManifest := TJSObject(TJSJSON.parse(TJSTextDecoder.new.decode(LManifestBuffer)));
    Require(isObject(LManifest) and not isNull(LManifest) and
      not TJSArray.isArray(LManifest) and isInteger(LManifest['version']) and
      (Integer(LManifest['version']) = 1) and
      (StringField(LManifest, 'kit') = AKitId) and
      (StringField(LManifest, 'inventorySha256') =
      StringField(LIndex, 'inventorySha256')) and TJSArray.isArray(LManifest['models']),
      'Catalog manifest identity differs from its index.');
    LModels := TJSArray(LManifest['models']);
    Require((LModels.length > 0) and (LModels.length <= 4096),
      'Unsupported catalog model count.');
    Require(isInteger(LKit['models']) and
      (Integer(LKit['models']) = LModels.length),
      'Catalog manifest model count differs from its index.');
    StringField(LManifest, 'source');
    StringField(LManifest, 'author');
    StringField(LManifest, 'license');
    LModel := nil;
    LMatches := 0;
    for I := 0 to LModels.length - 1 do
    begin
      Require(isObject(LModels[I]) and not isNull(LModels[I]) and
        not TJSArray.isArray(LModels[I]), 'Invalid catalog model entry.');
      if StringField(TJSObject(LModels[I]), 'id') = AModelId then
      begin
        Inc(LMatches);
        LModel := TJSObject(LModels[I]);
      end;
    end;
    Require(LMatches = 1, 'Catalog model selection is absent or ambiguous.');
    LNotice := ObjectField(LManifest, 'notice');
    ValidateCatalogModel(AKitId, AModelId, LModel, LNotice);

    LFiles := TJSArray(LModel['files']);
    LAllFiles := TJSArray.new;
    for I := 0 to LFiles.length - 1 do
    begin
      LAllFiles.push(LFiles[I]);
    end;
    LAllFiles.push(LNotice);
    LTotal := Double(LModel['downloadBytes']) +
      BoundedBytes(LNotice, CatalogFetchModelBytes);
    LCompleted := 0;
    LStaged := TJSArray.new;
    LTransactionEntries := TJSObject.new;
    ReportProgress(AModelId, LGeneration, 0, LTotal);
    for I := 0 to LAllFiles.length - 1 do
    begin
      LFile := TJSObject(LAllFiles[I]);
      LHash := StringField(LFile, 'sha256');
      LStage := TJSObject.new;
      LStage['file'] := LFile;
      if LTransactionEntries.hasOwnProperty(LHash) then
      begin
        LEntry := TJSObject(LTransactionEntries[LHash]);
        Require(TJSArrayBuffer(LEntry['buffer']).byteLength =
          BoundedBytes(LFile, CatalogFetchModelBytes),
          'Duplicate catalog hash has inconsistent byte lengths.');
      end else if FCache.hasOwnProperty(LHash) then
      begin
        LEntry := TJSObject(FCache[LHash]);
        Require(TJSArrayBuffer(LEntry['buffer']).byteLength =
          BoundedBytes(LFile, CatalogFetchModelBytes),
          'Cached catalog bytes differ from the manifest.');
      end else
      begin
        LEntry := TJSObject.new;
        LEntry['buffer'] := await(FetchBytes(LFile, CatalogFetchModelBytes,
          LGeneration, LController.signal));
        LEntry['pins'] := 0;
      end;
      LTransactionEntries[LHash] := LEntry;
      LStage['entry'] := LEntry;
      LStaged.push(LStage);
      LCompleted := LCompleted + BoundedBytes(LFile, CatalogFetchModelBytes);
      ReportProgress(AModelId, LGeneration, LCompleted, LTotal);
    end;
    CheckGeneration(LGeneration);

    { ClearUnused may run while a file is awaited. Recompute the complete unique
      resident set immediately before the synchronous cache commit. MakeRoom
      must not evict any hash that this lease is about to pin. }
    LNewBytes := 0;
    LRequiredBytes := 0;
    LHashes := TJSObject.keys(LTransactionEntries);
    for LHash in LHashes do
    begin
      LEntry := TJSObject(LTransactionEntries[LHash]);
      LRequiredBytes := LRequiredBytes + TJSArrayBuffer(LEntry['buffer']).byteLength;
      if not FCache.hasOwnProperty(LHash) then
      begin
        LNewBytes := LNewBytes + TJSArrayBuffer(LEntry['buffer']).byteLength;
      end;
    end;
    Require(LRequiredBytes <= FCacheBudget,
      'Catalog model exceeds the configured cache budget.');
    MakeRoom(LNewBytes, LTransactionEntries);
    for LHash in LHashes do
    begin
      if not FCache.hasOwnProperty(LHash) then
      begin
        LEntry := TJSObject(LTransactionEntries[LHash]);
        FCache[LHash] := LEntry;
        FCacheBytes := FCacheBytes + TJSArrayBuffer(LEntry['buffer']).byteLength;
      end;
    end;
    Require(FCacheBytes <= FCacheBudget, 'Catalog cache commit exceeded its budget.');
    LLeaseEntries := TJSArray.new;
    LRows := TJSArray.new;
    for I := 0 to LStaged.length - 1 do
    begin
      LStage := TJSObject(LStaged[I]);
      LFile := TJSObject(LStage['file']);
      LHash := StringField(LFile, 'sha256');
      LEntry := TJSObject(FCache[LHash]);
      Inc(FClock);
      LEntry['used'] := FClock;
      LEntry['pins'] := Integer(LEntry['pins']) + 1;
      LLeaseEntries.push(LEntry);
      LRow := TJSObject.new;
      LRow['path'] := LFile['path'];
      LRow['sha256'] := LHash;
      LRow['buffer'] := LEntry['buffer'];
      LRow['notice'] := I = LStaged.length - 1;
      LRows.push(LRow);
    end;
    Inc(FLeaseSerial);
    LLease := 'catalog-' + IntToStr(FLeaseSerial);
    FLeases[LLease] := LLeaseEntries;
    Result := TJSObject.new;
    Result['lease'] := LLease;
    Result['generation'] := LGeneration;
    Result['kitId'] := AKitId;
    Result['modelId'] := AModelId;
    Result['manifestSha256'] := LKit['sha256'];
    Result['rootPath'] := LModel['path'];
    Result['format'] := LModel['format'];
    Result['files'] := LRows;
    Result['noticePath'] := LNotice['path'];
    Result['source'] := LManifest['source'];
    Result['author'] := LManifest['author'];
    Result['license'] := LManifest['license'];
  finally
    window.clearTimeout(LTimeout);
    if LGeneration = FGeneration then
    begin
      FController := nil;
    end;
  end;
end;

procedure TCatalogFetcher.Release(const ALease: String);
begin
  if FLeases.hasOwnProperty(ALease) then
  begin
    Unpin(TJSArray(FLeases[ALease]));
    JSDelete(FLeases, ALease);
  end;
end;

procedure TCatalogFetcher.ClearUnused;
var
  LKeys: TStringDynArray;
  LKey: String;
  LEntry: TJSObject;
begin
  LKeys := TJSObject.keys(FCache);
  for LKey in LKeys do
  begin
    LEntry := TJSObject(FCache[LKey]);
    if Integer(LEntry['pins']) = 0 then
    begin
      FCacheBytes := FCacheBytes - TJSArrayBuffer(LEntry['buffer']).byteLength;
      JSDelete(FCache, LKey);
    end;
  end;
end;

function TCatalogFetcher.Stats: TJSObject;
begin
  Result := TJSObject.new;
  Result['bytes'] := FCacheBytes;
  Result['files'] := Length(TJSObject.keys(FCache));
  Result['leases'] := Length(TJSObject.keys(FLeases));
  Result['generation'] := FGeneration;
  Result['loading'] := FController <> nil;
  Result['budgetBytes'] := FCacheBudget;
  Result['concurrency'] := CatalogFetchConcurrency;
end;

end.
