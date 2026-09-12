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
program PhanesCatalogFetchFixture;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.files;

var
  GRoot: String;

function BytesOf(const AValues: array of Byte): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
  begin
    Result[I] := AValues[I];
  end;
end;

function PublishBlob(const ABytes: TBytes): String;
begin
  Result := HashBytes(ABytes);
  WriteBytes(SafeChild(GRoot, 'library/blobs/' + Result), ABytes);
end;

function FileRow(const APath, AHash: String; const ABytes: Integer): TJSONObject;
begin
  Result := TJSONObject.Create(['path', APath, 'url', 'library/blobs/' + AHash,
    'sha256', AHash, 'bytes', ABytes]);
end;

function Model(const AId, APath, AHash: String; const AFiles: TJSONArray;
  const ABytes: Integer): TJSONObject;
begin
  Result := TJSONObject.Create(['id', 'bounded-kit/' + AId, 'name', AId,
    'format', 'glb', 'path', APath, 'sha256', AHash,
    'files', AFiles, 'downloadBytes', ABytes]);
end;

var
  LNoticeHash: String;
  LPinHash: String;
  LSharedHash: String;
  LOldHash: String;
  LNewHash: String;
  LLargeAHash: String;
  LLargeBHash: String;
  LModels: TJSONArray;
  LManifest: TJSONObject;
  LIndex: TJSONObject;
  LManifestTemporary: String;
  LManifestPath: String;
  LManifestUrl: String;
  LManifestHash: String;
begin
  Require(ParamCount = 1, 'Usage: catalog-fetch-fixture OUTPUT');
  GRoot := ExpandFileName(ParamStr(1));
  ForceDirectories(SafeChild(GRoot, 'data'));
  ForceDirectories(SafeChild(GRoot, 'library/catalog'));
  ForceDirectories(SafeChild(GRoot, 'library/blobs'));
  LNoticeHash := PublishBlob(BytesOf([9, 9]));
  LPinHash := PublishBlob(BytesOf([1, 2]));
  LSharedHash := PublishBlob(BytesOf([3, 4, 5, 6]));
  LOldHash := PublishBlob(BytesOf([7, 8]));
  LNewHash := PublishBlob(BytesOf([10, 11, 12, 13]));
  LLargeAHash := PublishBlob(BytesOf([14, 15, 16, 17, 18, 19]));
  LLargeBHash := PublishBlob(BytesOf([20, 21, 22, 23, 24, 25]));

  LModels := TJSONArray.Create;
  LModels.Add(Model('pin', 'pin.glb', LPinHash,
    TJSONArray.Create([FileRow('pin.glb', LPinHash, 2)]), 2));
  LModels.Add(Model('seed', 'shared.glb', LSharedHash,
    TJSONArray.Create([FileRow('shared.glb', LSharedHash, 4),
    FileRow('old.bin', LOldHash, 2)]), 6));
  LModels.Add(Model('target', 'target.glb', LSharedHash,
    TJSONArray.Create([FileRow('target.glb', LSharedHash, 4),
    FileRow('duplicate-new.bin', LNewHash, 4), FileRow('new.bin', LNewHash, 4)]), 12));
  LModels.Add(Model('too-big', 'large-a.glb', LLargeAHash,
    TJSONArray.Create([FileRow('large-a.glb', LLargeAHash, 6),
    FileRow('large-b.bin', LLargeBHash, 6)]), 12));
  LManifest := TJSONObject.Create(['version', 1, 'kit', 'bounded-kit',
    'inventorySha256', StringOfChar('a', 64), 'author', 'Phanes test fixture',
    'source', 'local bounded fixture', 'license', 'MIT', 'models', LModels,
    'notice', FileRow('License.txt', LNoticeHash, 2)]);
  try
    LManifestTemporary := SafeChild(GRoot, 'library/catalog/bounded.json');
    WriteTextAtomic(LManifestTemporary, UTF8String(LManifest.FormatJSON + #10));
    LManifestHash := HashFile(LManifestTemporary);
    LManifestUrl := 'library/catalog/bounded-kit-' + LManifestHash + '.json';
    LManifestPath := SafeChild(GRoot, LManifestUrl);
    Require(RenameFile(LManifestTemporary, LManifestPath),
      'Could not publish bounded catalog manifest');
    LIndex := TJSONObject.Create(['version', 1, 'recipe', 'phanes.catalog.files.v1',
      'inventorySha256', StringOfChar('a', 64),
      'sourceLockSha256', StringOfChar('b', 64),
      'kits', TJSONArray.Create([TJSONObject.Create(['id', 'bounded-kit',
      'models', 4, 'url', LManifestUrl, 'sha256', LManifestHash,
      'bytes', FileByteCount(LManifestPath)])])]);
    try
      WriteTextAtomic(SafeChild(GRoot, 'data/library-files.json'),
        UTF8String(LIndex.FormatJSON + #10));
    finally
      LIndex.Free;
    end;
  finally
    LManifest.Free;
  end;
end.
