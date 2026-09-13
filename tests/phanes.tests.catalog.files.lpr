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
program PhanesTestsCatalogFiles;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, FPJSON, CastleScene, CastleDownload, CastleUriUtils,
  phanes.catalog.files, phanes.catalog.shared.files, phanes.catalog.scene,
  phanes.catalog.sources, phanes.tests.catalog.shared.scenes, phanes.tools.files,
  phanes.tests.catalog.textures, phanes.tools.fingerprint;

type
  TOversizedStream = class(TStream)
  private
    FPosition: Int64;
    FReadCount: Integer;
  public
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    function GetSize: Int64; override;
    property ReadCount: Integer read FReadCount;
  end;

  TRestoreFailStream = class(TStream)
  private
    FPosition: Int64;
    FWasRead: Boolean;
  public
    constructor Create;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    function GetSize: Int64; override;
  end;

var
  GChecks: Integer;

function TOversizedStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Inc(FReadCount);
  raise Exception.Create('Oversized stream must be rejected before reading');
end;

function TOversizedStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  raise Exception.Create('Oversized stream is read-only');
end;

function TOversizedStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
begin
  case AOrigin of
    soBeginning:
      FPosition := AOffset;
    soCurrent:
      Inc(FPosition, AOffset);
    soEnd:
      FPosition := GetSize + AOffset;
  end;
  Result := FPosition;
end;

function TOversizedStream.GetSize: Int64;
begin
  Result := 1024 * 1024 * 1024;
end;

constructor TRestoreFailStream.Create;
begin
  inherited Create;
  FPosition := 2;
end;

function TRestoreFailStream.Read(var ABuffer; ACount: LongInt): LongInt;
const
  CBytes: array[0..4] of Byte = (97, 108, 112, 104, 97);
begin
  Result := GetSize - FPosition;
  if Result > ACount then
  begin
    Result := ACount;
  end;
  if Result > 0 then
  begin
    Move(CBytes[FPosition], ABuffer, Result);
    Inc(FPosition, Result);
    FWasRead := True;
  end;
end;

function TRestoreFailStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  raise Exception.Create('Restore-failure stream is read-only');
end;

function TRestoreFailStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
begin
  if FWasRead and (AOrigin = soBeginning) and (AOffset = 2) then
  begin
    raise Exception.Create('Injected stream position restore failure');
  end;
  case AOrigin of
    soBeginning:
      FPosition := AOffset;
    soCurrent:
      Inc(FPosition, AOffset);
    soEnd:
      FPosition := GetSize + AOffset;
  end;
  Result := FPosition;
end;

function TRestoreFailStream.GetSize: Int64;
begin
  Result := 5;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function StreamOf(const AValue: RawByteString): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if Length(AValue) > 0 then
  begin
    Result.WriteBuffer(AValue[1], Length(AValue));
  end;
  Result.Position := 0;
end;

function ReadAll(const AStream: TStream): RawByteString;
begin
  SetLength(Result, AStream.Size);
  AStream.Position := 0;
  if AStream.Size > 0 then
  begin
    AStream.ReadBuffer(Result[1], AStream.Size);
  end;
end;

procedure AddTextFile(const ABundle: TCatalogFileBundle;
  const APath: String; const AValue: RawByteString);
var
  LStream: TMemoryStream;
begin
  LStream := StreamOf(AValue);
  try
    ABundle.AddFile(APath, LStream);
  finally
    LStream.Free;
  end;
end;

procedure CheckSharedStoreBoundaries;
var
  LStore: TCatalogSharedFiles;
  LBundle: TCatalogFileBundle;
  LOversized: TOversizedStream;
  LRestoreFail: TRestoreFailStream;
  LFailed: Boolean;
  LPosition: Int64;
  LError: String;
begin
  LStore := nil;
  LFailed := False;
  LError := '';
  try
    LStore := TCatalogSharedFiles.Create(0);
  except
    on LException: Exception do
    begin
      LFailed := True;
      LError := LException.Message;
    end;
  end;
  Check(LFailed and (LStore = nil) and
    (LError = 'Shared catalog source budget must be between 1 byte and 64 MiB'),
    'zero shared-store budget rejects without a partial object');

  LFailed := False;
  LError := '';
  try
    LStore := TCatalogSharedFiles.Create(64 * 1024 * 1024 + 1);
  except
    on LException: Exception do
    begin
      LFailed := True;
      LError := LException.Message;
    end;
  end;
  Check(LFailed and (LStore = nil) and
    (LError = 'Shared catalog source budget must be between 1 byte and 64 MiB'),
    'oversized shared-store budget rejects without a partial object');

  LBundle := nil;
  LFailed := False;
  LError := '';
  try
    LBundle := TCatalogFileBundle.Create(1, nil);
  except
    on LException: Exception do
    begin
      LFailed := True;
      LError := LException.Message;
    end;
  end;
  Check(LFailed and (LBundle = nil) and
    (LError = 'Catalog shared source store is missing'),
    'external bundle rejects a missing store without a partial object');

  LStore := TCatalogSharedFiles.Create(16);
  LOversized := TOversizedStream.Create;
  try
    LOversized.Position := 7;
    LPosition := LOversized.Position;
    LFailed := False;
    try
      LStore.AcquireFile('huge.bin', LOversized);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed and (LOversized.ReadCount = 0) and
      (LOversized.Position = LPosition),
      'oversized stream rejects before allocation or read and preserves position');
    Check((LStore.FileCount = 0) and (LStore.UniqueBytes = 0),
      'oversized stream rejection leaves the store empty');

    LRestoreFail := TRestoreFailStream.Create;
    try
      LFailed := False;
      try
        LStore.AcquireFile('restore.bin', LRestoreFail);
      except
        on Exception do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed and (LStore.FileCount = 0) and (LStore.UniqueBytes = 0),
        'stream restore failure cannot publish bytes or a reference');
    finally
      LRestoreFail.Free;
    end;
  finally
    LOversized.Free;
    LStore.Free;
  end;
end;

procedure CheckSharedBundles;
var
  LStore: TCatalogSharedFiles;
  LFirst: TCatalogFileBundle;
  LSecond: TCatalogFileBundle;
  LFailedBundle: TCatalogFileBundle;
  LSealFailedBundle: TCatalogFileBundle;
  LInput: TMemoryStream;
  LRead: TStream;
  LUrl: String;
  LFailed: Boolean;
begin
  LStore := TCatalogSharedFiles.Create(64);
  LFirst := TCatalogFileBundle.Create(32, LStore);
  LSecond := TCatalogFileBundle.Create(32, LStore);
  LFailedBundle := nil;
  LSealFailedBundle := nil;
  try
    AddTextFile(LFirst, 'models/shared.gltf', 'model');
    LFirst.Seal('models/shared.gltf');
    LUrl := LFirst.ModelUrl;
    AddTextFile(LSecond, 'models/shared.gltf', 'model');
    LSecond.Seal('models/shared.gltf');
    Check(LSecond.ModelUrl = LUrl, 'shared bundles expose the same model URL');
    Check((LStore.FileCount = 1) and (LStore.UniqueBytes = 5) and
      (LFirst.ByteCount = 5) and (LSecond.ByteCount = 5),
      'shared bytes are stored once while each bundle accounts its full closure');

    FreeAndNil(LFirst);
    LRead := Download(LUrl);
    try
      Check(ReadAll(LRead) = 'model',
        'releasing either shared bundle keeps the other bundle readable');
    finally
      LRead.Free;
    end;

    LFailedBundle := TCatalogFileBundle.Create(32, LStore);
    AddTextFile(LFailedBundle, 'models/temporary.bin', 'temp');
    LInput := StreamOf('other');
    try
      LFailed := False;
      try
        LFailedBundle.AddFile('models/shared.gltf', LInput);
      except
        on Exception do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'conflicting shared bytes fail bundle acquisition');
    finally
      LInput.Free;
    end;
    FreeAndNil(LFailedBundle);
    Check((LStore.FileCount = 1) and (LStore.UniqueBytes = 5),
      'destroying a failed bundle rolls back only its acquired paths');

    LSealFailedBundle := TCatalogFileBundle.Create(32, LStore);
    AddTextFile(LSealFailedBundle, 'models/not-model.bin', 'temp');
    LFailed := False;
    try
      LSealFailedBundle.Seal('models/not-model.bin');
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'invalid model extension fails sealing');
    FreeAndNil(LSealFailedBundle);
    Check((LStore.FileCount = 1) and (LStore.UniqueBytes = 5),
      'destroying a seal-rejected bundle releases its acquired paths');

    FreeAndNil(LSecond);
    Check((LStore.FileCount = 0) and (LStore.UniqueBytes = 0),
      'final bundle references remove shared files and bytes');
    Check(UriExists(LUrl) <> ueFile, 'final release removes the shared URL');
  finally
    LSealFailedBundle.Free;
    LFailedBundle.Free;
    LSecond.Free;
    LFirst.Free;
    LStore.Free;
  end;
end;

procedure CheckSharedStoreIsolation;
var
  LFirstStore: TCatalogSharedFiles;
  LSecondStore: TCatalogSharedFiles;
  LBundle: TCatalogFileBundle;
  LInput: TMemoryStream;
  LRead: TStream;
  LFirstUrl: String;
  LSecondUrl: String;
  LStaleUrl: String;
begin
  LFirstStore := TCatalogSharedFiles.Create(16);
  LSecondStore := TCatalogSharedFiles.Create(16);
  try
    LInput := StreamOf('first');
    try
      LFirstStore.AcquireFile('same.bin', LInput);
    finally
      LInput.Free;
    end;
    LInput := StreamOf('other');
    try
      LSecondStore.AcquireFile('same.bin', LInput);
    finally
      LInput.Free;
    end;
    LFirstUrl := LFirstStore.Url('same.bin');
    LSecondUrl := LSecondStore.Url('same.bin');
    Check(LFirstUrl <> LSecondUrl, 'separate stores isolate identical paths');
    LRead := Download(LFirstUrl);
    try
      Check(ReadAll(LRead) = 'first', 'first isolated store retains its bytes');
    finally
      LRead.Free;
    end;
    LRead := Download(LSecondUrl);
    try
      Check(ReadAll(LRead) = 'other', 'second isolated store retains its bytes');
    finally
      LRead.Free;
    end;
  finally
    LSecondStore.Free;
    LFirstStore.Free;
  end;

  LFirstStore := TCatalogSharedFiles.Create(16);
  try
    LBundle := TCatalogFileBundle.Create(16, LFirstStore);
    try
      AddTextFile(LBundle, 'same.gltf', 'old');
      LBundle.Seal('same.gltf');
      LStaleUrl := LBundle.ModelUrl;
    finally
      LBundle.Free;
    end;
  finally
    LFirstStore.Free;
  end;
  LSecondStore := TCatalogSharedFiles.Create(16);
  try
    LBundle := TCatalogFileBundle.Create(16, LSecondStore);
    try
      AddTextFile(LBundle, 'same.gltf', 'new');
      LBundle.Seal('same.gltf');
      Check(LBundle.ModelUrl <> LStaleUrl,
        'destroyed shared-store protocol names are never reused');
      Check(UriExists(LStaleUrl) <> ueFile,
        'stale URL cannot address a replacement store');
    finally
      LBundle.Free;
    end;
  finally
    LSecondStore.Free;
  end;
end;

procedure CheckAggregateSourceBudget;
var
  LBudget: TCatalogSourceBudget;
  LFirstStore: TCatalogSharedFiles;
  LSecondStore: TCatalogSharedFiles;
  LInput: TMemoryStream;
  LRestoreFail: TRestoreFailStream;
  LFailed: Boolean;
  LError: String;
begin
  LBudget := nil;
  LError := '';
  try
    LBudget := TCatalogSourceBudget.Create(0);
  except
    on LException: Exception do
    begin
      LError := LException.Message;
    end;
  end;
  Check((LBudget = nil) and
    (LError =
      'Catalog aggregate source budget must be between 1 byte and 64 MiB'),
    'aggregate budget rejects zero without a partial object');

  LBudget := TCatalogSourceBudget.Create(10);
  LFailed := False;
  try
    LBudget.Reserve(0);
  except
    on LException: Exception do
    begin
      LFailed := LException.Message =
        'Catalog source reservation must be positive';
    end;
  end;
  Check(LFailed and (LBudget.Bytes = 0),
    'aggregate budget rejects a nonpositive reservation without mutation');
  LFailed := False;
  try
    LBudget.Reserve(11);
  except
    on LException: Exception do
    begin
      LFailed := LException.Message = 'Catalog aggregate source budget exceeded';
    end;
  end;
  Check(LFailed and (LBudget.Bytes = 0),
    'aggregate budget rejects an overflowing reservation without mutation');
  LBudget.Reserve(10);
  LFailed := False;
  try
    LBudget.Release(11);
  except
    on LException: Exception do
    begin
      LFailed := LException.Message =
        'Catalog aggregate source budget underflow';
    end;
  end;
  Check(LFailed and (LBudget.Bytes = 10),
    'aggregate budget rejects underflow without mutation');
  LFailed := False;
  try
    LBudget.Release(0);
  except
    on LException: Exception do
    begin
      LFailed := LException.Message = 'Catalog source release must be positive';
    end;
  end;
  Check(LFailed and (LBudget.Bytes = 10),
    'aggregate budget rejects a nonpositive release without mutation');
  LBudget.Release(10);

  LFirstStore := TCatalogSharedFiles.Create(10, LBudget);
  LSecondStore := TCatalogSharedFiles.Create(10, LBudget);
  try
    LInput := StreamOf('123456');
    try
      LFirstStore.AcquireFile('same.bin', LInput);
    finally
      LInput.Free;
    end;
    Check((LBudget.Bytes = 6) and (LFirstStore.UniqueBytes = 6),
      'first namespace reserves its unique source bytes');

    LInput := StreamOf('12345');
    try
      LFailed := False;
      try
        LSecondStore.AcquireFile('rejected.bin', LInput);
      except
        on LException: Exception do
        begin
          LFailed := LException.Message =
            'Catalog aggregate source budget exceeded';
        end;
      end;
    finally
      LInput.Free;
    end;
    Check(LFailed and (LBudget.Bytes = 6) and
      (LSecondStore.FileCount = 0),
      'competing namespace rejection preserves aggregate and store state');

    LInput := StreamOf('abcd');
    try
      LSecondStore.AcquireFile('same.bin', LInput);
    finally
      LInput.Free;
    end;
    Check((LBudget.Bytes = 10) and (LFirstStore.FileCount = 1) and
      (LSecondStore.FileCount = 1),
      'identical paths in separate namespaces reserve separate bytes');

    LInput := StreamOf('123456');
    try
      LFirstStore.AcquireFile('same.bin', LInput);
    finally
      LInput.Free;
    end;
    Check((LBudget.Bytes = 10) and (LFirstStore.FileCount = 1),
      'duplicate live path remains acquirable at the full aggregate cap');
    LFirstStore.ReleaseFile('same.bin');

    FreeAndNil(LSecondStore);
    Check(LBudget.Bytes = 6,
      'destroying a namespace returns all of its retained aggregate bytes');
    FreeAndNil(LFirstStore);
    Check(LBudget.Bytes = 0,
      'destroying the final namespace returns the aggregate budget to zero');

    LFirstStore := TCatalogSharedFiles.Create(10, LBudget);
    LRestoreFail := TRestoreFailStream.Create;
    try
      LFailed := False;
      try
        LFirstStore.AcquireFile('restore.bin', LRestoreFail);
      except
        on LException: Exception do
        begin
          LFailed := LException.Message =
            'Injected stream position restore failure';
        end;
      end;
      Check(LFailed and (LBudget.Bytes = 0) and
        (LFirstStore.FileCount = 0),
        'restore failure rolls back a pre-copy aggregate reservation');
    finally
      LRestoreFail.Free;
    end;
  finally
    LSecondStore.Free;
    LFirstStore.Free;
    LBudget.Free;
  end;
end;

procedure CheckSourcePoolIdentity;
const
  CHashA = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  CHashB = '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
var
  LPool: TCatalogSourcePool;
  LSameFirst: TCatalogSharedFiles;
  LSameSecond: TCatalogSharedFiles;
  LDifferentKit: TCatalogSharedFiles;
  LDifferentRevision: TCatalogSharedFiles;
  LFailed: Boolean;
begin
  LPool := TCatalogSourcePool.Create(32);
  try
    LSameFirst := LPool.Acquire('kit-a', CHashA);
    LSameSecond := LPool.Acquire('kit-a', CHashA);
    LDifferentKit := LPool.Acquire('kit-b', CHashA);
    LDifferentRevision := LPool.Acquire('kit-a', CHashB);
    Check(LSameFirst = LSameSecond,
      'same exact kit and manifest reuse one source namespace');
    Check((LDifferentKit <> LSameFirst) and
      (LDifferentRevision <> LSameFirst) and
      (LDifferentKit <> LDifferentRevision),
      'different kits and manifest revisions use isolated namespaces');
    Check(LPool.NamespaceCount = 3,
      'source pool counts exact namespace identities once');

    LFailed := False;
    try
      LPool.Acquire('../kit', CHashA);
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog namespace needs an exact kit and manifest identity';
      end;
    end;
    Check(LFailed and (LPool.NamespaceCount = 3),
      'invalid kit identity rejects without adding a namespace');
    LFailed := False;
    try
      LPool.Acquire('kit-a', UpperCase(CHashA));
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog manifest identity must be lowercase SHA-256';
      end;
    end;
    Check(LFailed and (LPool.NamespaceCount = 3),
      'noncanonical manifest identity rejects without adding a namespace');

    LPool.Release(LSameFirst);
    Check(LPool.NamespaceCount = 3,
      'one of two same-namespace references leaves the namespace live');
    LPool.Release(LSameSecond);
    LPool.Release(LDifferentKit);
    LPool.Release(LDifferentRevision);
    Check((LPool.NamespaceCount = 0) and (LPool.UniqueBytes = 0),
      'balanced empty namespace references clear the pool');
  finally
    LPool.Free;
  end;
end;

procedure CheckSourcePoolLeaseLifecycle;
const
  CHash = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
var
  LPool: TCatalogSourcePool;
  LStore: TCatalogSharedFiles;
  LBundle: TCatalogFileBundle;
  LRead: TStream;
  LUrl: String;
  LFreshUrl: String;
  LFailed: Boolean;
begin
  LPool := TCatalogSourcePool.Create(16);
  LStore := LPool.Acquire('kit-a', CHash);
  LBundle := TCatalogFileBundle.Create(16, LStore);
  try
    AddTextFile(LBundle, 'model.gltf', 'old');
    LBundle.Seal('model.gltf');
    LUrl := LBundle.ModelUrl;
    LFailed := False;
    try
      LPool.Release(LStore);
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog scene bundles must release before their final namespace';
      end;
    end;
    Check(LFailed and (LPool.NamespaceCount = 1) and
      (LPool.UniqueBytes = 3),
      'premature final namespace release fails without changing ownership');
    LRead := Download(LUrl);
    try
      Check(ReadAll(LRead) = 'old',
        'premature namespace release leaves the previous lease readable');
    finally
      LRead.Free;
    end;
  finally
    FreeAndNil(LBundle);
  end;
  LPool.Release(LStore);
  Check((LPool.NamespaceCount = 0) and (LPool.UniqueBytes = 0),
    'bundle-first balanced release clears namespace bytes');

  LStore := LPool.Acquire('kit-a', CHash);
  LBundle := TCatalogFileBundle.Create(16, LStore);
  try
    AddTextFile(LBundle, 'model.gltf', 'new');
    LBundle.Seal('model.gltf');
    LFreshUrl := LBundle.ModelUrl;
    Check(LFreshUrl <> LUrl,
      'reacquiring a retired namespace creates a fresh protocol URL');
  finally
    LBundle.Free;
  end;
  LPool.Release(LStore);
  Check((LPool.NamespaceCount = 0) and (LPool.UniqueBytes = 0),
    'reacquired namespace also releases cleanly');
  LPool.Free;
end;

procedure CheckSourcePoolAggregateCompetition;
const
  CHash = '123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0';
var
  LPool: TCatalogSourcePool;
  LFirstStore: TCatalogSharedFiles;
  LSecondStore: TCatalogSharedFiles;
  LFirstBundle: TCatalogFileBundle;
  LSecondBundle: TCatalogFileBundle;
  LRead: TStream;
  LUrl: String;
  LFailed: Boolean;
begin
  LPool := TCatalogSourcePool.Create(5);
  LFirstStore := LPool.Acquire('kit-a', CHash);
  LSecondStore := LPool.Acquire('kit-b', CHash);
  LFirstBundle := TCatalogFileBundle.Create(5, LFirstStore);
  LSecondBundle := TCatalogFileBundle.Create(5, LSecondStore);
  try
    AddTextFile(LFirstBundle, 'model.gltf', '1234');
    LFirstBundle.Seal('model.gltf');
    LUrl := LFirstBundle.ModelUrl;
    LFailed := False;
    try
      AddTextFile(LSecondBundle, 'model.gltf', '12');
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog aggregate source budget exceeded';
      end;
    end;
    Check(LFailed and (LPool.UniqueBytes = 4) and
      (LSecondStore.FileCount = 0),
      'second namespace cannot exceed the shared global source cap');
    LRead := Download(LUrl);
    try
      Check(ReadAll(LRead) = '1234',
        'aggregate rejection leaves the previous namespace readable');
    finally
      LRead.Free;
    end;
  finally
    LSecondBundle.Free;
    LFirstBundle.Free;
  end;
  LPool.Release(LSecondStore);
  LPool.Release(LFirstStore);
  Check((LPool.NamespaceCount = 0) and (LPool.UniqueBytes = 0),
    'competing namespaces release to an empty aggregate pool');
  LPool.Free;
end;

procedure CheckSceneOwnership;
var
  LBundle: TCatalogFileBundle;
  LLease: TCatalogSceneLease;
  LInput: TStringStream;
  LRejected: Boolean;
  LUrl: String;
  LRead: TStream;
begin
  LBundle := TCatalogFileBundle.Create(1024);
  LLease := nil;
  LInput := TStringStream.Create('This is not a glTF binary.');
  try
    LRejected := False;
    try
      LLease := TCatalogSceneLease.Create(LBundle);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBundle <> nil), 'unsealed input retains caller ownership');
    LBundle.AddFile('invalid.glb', LInput);
    LBundle.Seal('invalid.glb');
    LUrl := LBundle.ModelUrl;
    LRejected := False;
    try
      LLease := TCatalogSceneLease.Create(LBundle);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBundle = nil) and (LLease = nil),
      'failed decode consumes and destroys the staged source lease');
    LRejected := False;
    try
      LRead := Download(LUrl);
      LRead.Free;
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'failed scene construction releases the source protocol');
  finally
    LLease.Free;
    LBundle.Free;
    LInput.Free;
  end;
end;

procedure CheckGuards;
var
  LBundle: TCatalogFileBundle;
  LBytes: TMemoryStream;
  LOther: TCatalogFileBundle;
  LFailed: Boolean;
  LRead: TStream;
  LValue: Byte;
  LUrl: String;
begin
  Check(not CatalogFilePathValid('../outside.glb'), 'parent path');
  Check(not CatalogFilePathValid('/absolute.glb'), 'absolute path');
  Check(not CatalogFilePathValid('a//b.glb'), 'empty segment');
  Check(not CatalogFilePathValid('a/%2e%2e/b.glb'), 'encoded parent');
  Check(not CatalogFilePathValid('https://host/a.glb'), 'remote URL');
  Check(not CatalogFilePathValid('a\b.glb'), 'backslash');
  Check(not CatalogFilePathValid('a.glb?other'), 'query');
  Check(CatalogFilePathValid('Models/Some Item.glb'), 'valid spaced path');
  LBytes := TMemoryStream.Create;
  LBundle := TCatalogFileBundle.Create(1);
  LOther := TCatalogFileBundle.Create(1);
  try
    LValue := 42;
    LBytes.WriteBuffer(LValue, 1);
    LBundle.AddFile('Models/Some Item.glb', LBytes);
    Check(LBytes.Position = 1, 'source position preserved');
    Check(LBundle.ByteCount = 1, 'source accounting exact');
    LFailed := False;
    try
      LBundle.AddFile('models/some item.glb', LBytes);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'case alias rejected');
    LFailed := False;
    try
      LBundle.AddFile('other.glb', LBytes);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed and (LBundle.ByteCount = 1), 'budget rejection preserves bundle');
    LFailed := False;
    try
      LBundle.Seal('models/some item.glb');
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed and not LBundle.Sealed, 'model requires exact case');
    LBundle.Seal('Models/Some Item.glb');
    LUrl := LBundle.ModelUrl;
    LRead := Download(LUrl);
    try
      LRead.ReadBuffer(LValue, 1);
      Check(LValue = 42, 'URL round trip with spaces');
    finally
      LRead.Free;
    end;
    LBytes.Position := 0;
    LValue := 7;
    LBytes.WriteBuffer(LValue, 1);
    LOther.AddFile('Models/Some Item.glb', LBytes);
    LOther.Seal('Models/Some Item.glb');
    Check(LOther.ModelUrl <> LUrl, 'distinct bundle namespace');
    LRead := Download(LUrl);
    try
      LRead.ReadBuffer(LValue, 1);
      Check(LValue = 42, 'other bundle cannot overwrite bytes');
    finally
      LRead.Free;
    end;
    LFailed := False;
    try
      LBundle.AddFile('after.glb', LBytes);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'sealed bundle immutable');
    FreeAndNil(LBundle);
    LFailed := False;
    try
      LRead := Download(LUrl);
      LRead.Free;
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'destroy releases registered protocol');
  finally
    LOther.Free;
    LBundle.Free;
    LBytes.Free;
  end;
end;

procedure CheckModel(const ARoot, AKitId, AModelId: String);
var
  LIndex: TJSONObject;
  LManifest: TJSONObject;
  LKit: TJSONObject;
  LModel: TJSONObject;
  LFile: TJSONObject;
  LBundle: TCatalogFileBundle;
  LInput: TFileStream;
  LOriginal: TCastleScene;
  LLease: TCatalogSceneLease;
  LBlob: String;
  I: Integer;
  J: Integer;
begin
  LIndex := LoadJSON(SafeChild(ARoot, 'build/web/data/library-files.json'));
  LManifest := nil;
  LBundle := nil;
  LOriginal := nil;
  LLease := nil;
  try
    LKit := nil;
    for I := 0 to LIndex.Arrays['kits'].Count - 1 do
    begin
      if LIndex.Arrays['kits'].Objects[I].Strings['id'] = AKitId then
      begin
        LKit := LIndex.Arrays['kits'].Objects[I];
        Break;
      end;
    end;
    Check(LKit <> nil, 'fixture kit exists');
    LBlob := SafeChild(ARoot, 'build/web/' + LKit.Strings['url']);
    Check(HashFile(LBlob) = LKit.Strings['sha256'], 'fixture manifest hash');
    LManifest := LoadJSON(LBlob);
    LModel := nil;
    for I := 0 to LManifest.Arrays['models'].Count - 1 do
    begin
      if LManifest.Arrays['models'].Objects[I].Strings['id'] = AModelId then
      begin
        LModel := LManifest.Arrays['models'].Objects[I];
        Break;
      end;
    end;
    Check(LModel <> nil, 'fixture model exists');
    LBundle := TCatalogFileBundle.Create(1024 * 1024);
    for J := 0 to LModel.Arrays['files'].Count - 1 do
    begin
      LFile := LModel.Arrays['files'].Objects[J];
      LBlob := SafeChild(ARoot, 'build/web/' + LFile.Strings['url']);
      Check(HashFile(LBlob) = LFile.Strings['sha256'], 'fixture blob hash');
      LInput := TFileStream.Create(LBlob, fmOpenRead or fmShareDenyWrite);
      try
        Check(LInput.Size = LFile.Int64s['bytes'], 'fixture blob length');
        LBundle.AddFile(LFile.Strings['path'], LInput);
      finally
        LInput.Free;
      end;
    end;
    Check(LBundle.ByteCount = LModel.Int64s['downloadBytes'], 'complete source bytes');
    LBundle.Seal(LModel.Strings['path']);
    LOriginal := TCastleScene.Create(nil);
    LOriginal.Load(SafeChild(ARoot, 'assets/library/kits/' + AKitId + '/' +
      LModel.Strings['path']));
    LLease := TCatalogSceneLease.Create(LBundle);
    Check(LBundle = nil, 'successful decode consumes the source bundle');
    Check(LLease.Scene.TrianglesCount > 0, 'staged model has triangles');
    Check(LLease.Scene.TrianglesCount = LOriginal.TrianglesCount, 'triangle parity');
    Check(StaticGeometryHash(LLease.Scene) = StaticGeometryHash(LOriginal),
      'transformed geometry parity');
    Check(not LLease.Scene.BoundingBox.IsEmpty, 'staged bounds nonempty');
    Check(LLease.SourceBytes = LModel.Int64s['downloadBytes'], 'lease retains complete source bytes');
    WriteLn(AModelId, ': ', LLease.Scene.TrianglesCount, ' triangles; ',
      LLease.SourceBytes, ' source bytes; geometry matches');
  finally
    { Keep sources available for all scene resource access until scene disposal. }
    LLease.Free;
    LOriginal.Free;
    LBundle.Free;
    LManifest.Free;
    LIndex.Free;
  end;
end;

begin
  try
    CheckSharedStoreBoundaries;
    CheckSharedBundles;
    CheckSharedStoreIsolation;
    CheckAggregateSourceBudget;
    CheckSourcePoolIdentity;
    CheckSourcePoolLeaseLifecycle;
    CheckSourcePoolAggregateCompetition;
    CheckGuards;
    CheckSceneOwnership;
    CheckModel(ParamStr(1), 'quaternius-low-poly-food-pack-surface-v1',
      'quaternius-low-poly-food-pack-surface-v1/soysauce-2882b4c31b');
    CheckModel(ParamStr(1), 'kaykit-furniture-bits-1-0',
      'kaykit-furniture-bits-1-0/gltf/rug_rectangle_A');
    Inc(GChecks, CheckSharedCatalogScenes(ParamStr(1)));
    Inc(GChecks, CheckCatalogTextureProfiles);
    WriteLn('PASS ', GChecks, ' catalog filesystem checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
