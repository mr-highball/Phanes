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
unit phanes.catalog.sources;

{$mode delphi}
{$H+}

interface

uses
  Classes, phanes.catalog.shared.files;

type
  { Own one namespace per exact admitted kit revision, with one source budget
    spanning every namespace. Acquired stores are borrowed; release each only
    after its scene and bundle leases. The pool outlives all acquired stores. }
  TCatalogSourcePool = class
  private type
    TNamespace = class
      FStore: TCatalogSharedFiles;
      FReferences: Integer;
      destructor Destroy; override;
    end;
  private
    FNamespaces: TStringList;
    FBudget: TCatalogSourceBudget;
    function GetUniqueBytes: Int64;
    function GetNamespaceCount: Integer;
  public
    constructor Create(const AByteLimit: Int64);
    destructor Destroy; override;
    function Acquire(const AKitId, AManifestSha256: String): TCatalogSharedFiles;
    procedure Release(const AStore: TCatalogSharedFiles);
    property UniqueBytes: Int64 read GetUniqueBytes;
    property NamespaceCount: Integer read GetNamespaceCount;
  end;

implementation

uses
  SysUtils, phanes.catalog.paths;

destructor TCatalogSourcePool.TNamespace.Destroy;
begin
  FStore.Free;
  inherited Destroy;
end;

constructor TCatalogSourcePool.Create(const AByteLimit: Int64);
begin
  inherited Create;
  FBudget := TCatalogSourceBudget.Create(AByteLimit);
  FNamespaces := TStringList.Create;
  FNamespaces.CaseSensitive := True;
  FNamespaces.Sorted := True;
end;

destructor TCatalogSourcePool.Destroy;
var
  I: Integer;
begin
  if FNamespaces <> nil then
  begin
    for I := 0 to FNamespaces.Count - 1 do
    begin
      FNamespaces.Objects[I].Free;
    end;
    FNamespaces.Free;
  end;
  FBudget.Free;
  inherited Destroy;
end;

function TCatalogSourcePool.Acquire(const AKitId,
  AManifestSha256: String): TCatalogSharedFiles;
var
  LKey: String;
  LIndex: Integer;
  LNamespace: TNamespace;
  I: Integer;
begin
  if not CatalogFilePathValid(AKitId) or (Length(AKitId) > 256) or
    (Pos('/', AKitId) <> 0) or (Length(AManifestSha256) <> 64) then
  begin
    raise Exception.Create('Catalog namespace needs an exact kit and manifest identity');
  end;
  for I := 1 to Length(AManifestSha256) do
  begin
    if not (AManifestSha256[I] in ['0'..'9', 'a'..'f']) then
    begin
      raise Exception.Create('Catalog manifest identity must be lowercase SHA-256');
    end;
  end;
  LKey := AKitId + '/' + AManifestSha256;
  LIndex := FNamespaces.IndexOf(LKey);
  if LIndex >= 0 then
  begin
    LNamespace := TNamespace(FNamespaces.Objects[LIndex]);
    if LNamespace.FReferences = High(Integer) then
    begin
      raise Exception.Create('Catalog namespace reference count exhausted');
    end;
    Inc(LNamespace.FReferences);
    Exit(LNamespace.FStore);
  end;
  LNamespace := TNamespace.Create;
  try
    LNamespace.FStore := TCatalogSharedFiles.Create(FBudget.ByteLimit, FBudget);
    LNamespace.FReferences := 1;
    FNamespaces.AddObject(LKey, LNamespace);
  except
    LNamespace.Free;
    raise;
  end;
  Result := LNamespace.FStore;
end;

procedure TCatalogSourcePool.Release(const AStore: TCatalogSharedFiles);
var
  LNamespace: TNamespace;
  I: Integer;
begin
  for I := 0 to FNamespaces.Count - 1 do
  begin
    LNamespace := TNamespace(FNamespaces.Objects[I]);
    if LNamespace.FStore = AStore then
    begin
      if LNamespace.FReferences = 1 then
      begin
        if LNamespace.FStore.FileCount <> 0 then
        begin
          raise Exception.Create('Catalog scene bundles must release before their final namespace');
        end;
        FNamespaces.Delete(I);
        LNamespace.Free;
      end
      else
      begin
        Dec(LNamespace.FReferences);
      end;
      Exit;
    end;
  end;
  raise Exception.Create('Catalog source namespace is not owned by this pool');
end;

function TCatalogSourcePool.GetUniqueBytes: Int64;
begin
  Result := FBudget.Bytes;
end;

function TCatalogSourcePool.GetNamespaceCount: Integer;
begin
  Result := FNamespaces.Count;
end;

end.
