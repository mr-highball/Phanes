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
unit phanes.tests.catalog.shared.scenes;

{$mode delphi}
{$H+}

interface

function CheckSharedCatalogScenes(const ARoot: String): Integer;

implementation

uses
  Classes, SysUtils, FPJSON, X3DNodes, CastleImages,
  phanes.catalog.files, phanes.catalog.scene, phanes.catalog.shared.files,
  phanes.tools.files, phanes.tools.fingerprint;

const
  KitId = 'kaykit-furniture-bits-1-0';
  ManifestHash = '035cf9f058624c947f754d9049d8be075655c58086799c9335b029cc4bc680cb';
  ModelNames: array[0..7] of String = ('armchair', 'couch', 'bed_single_A',
    'bed_double_A', 'chair_A', 'chair_stool', 'table_medium', 'table_low');

type
  TSharedSceneCheck = class
  private
    FImages: TList;
    FUrls: TStringList;
    FChecks: Integer;
    FTextureNodes: Integer;
    FReload: Boolean;
    FGeometry: array[0..7] of String;
    procedure Check(const ACondition: Boolean; const AMessage: String);
    procedure Texture(ANode: TX3DNode);
    procedure ClearTextures;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot: String; const AShared: Boolean);
  end;

constructor TSharedSceneCheck.Create;
begin
  inherited Create;
  FImages := TList.Create;
  FUrls := TStringList.Create;
  FUrls.CaseSensitive := True;
end;

destructor TSharedSceneCheck.Destroy;
begin
  FUrls.Free;
  FImages.Free;
  inherited Destroy;
end;

procedure TSharedSceneCheck.Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(FChecks);
  Require(ACondition, AMessage);
end;

procedure TSharedSceneCheck.ClearTextures;
begin
  FImages.Clear;
  FUrls.Clear;
  FTextureNodes := 0;
end;

procedure TSharedSceneCheck.Texture(ANode: TX3DNode);
var
  LTexture: TImageTextureNode;
  LImage: TEncodedImage;
begin
  LTexture := ANode as TImageTextureNode;
  if FReload then
  begin
    LTexture.IsTextureLoaded := False;
  end;
  LImage := LTexture.TextureImage;
  Check(LImage <> nil, 'Retained scene source decodes its image');
  Check((LImage.Width = 1024) and (LImage.Height = 1024), 'Pinned atlas dimensions');
  Inc(FTextureNodes);
  if FImages.IndexOf(LImage) < 0 then
  begin
    FImages.Add(LImage);
  end;
  if FUrls.IndexOf(LTexture.TextureUsedFullUrl) < 0 then
  begin
    FUrls.Add(LTexture.TextureUsedFullUrl);
  end;
end;

procedure TSharedSceneCheck.Run(const ARoot: String; const AShared: Boolean);
var
  LStores: array[0..7] of TCatalogSharedFiles;
  LLeases: array[0..7] of TCatalogSceneLease;
  LStore: TCatalogSharedFiles;
  LBundle: TCatalogFileBundle;
  LManifest: TJSONObject;
  LModel: TJSONObject;
  LManifestPath: String;
  LTriangles: QWord;
  LUniqueBytes: Int64;
  LClosureBytes: Int64;
  LExpectedBytes: Int64;
  LGeometry: String;
  I: Integer;
  J: Integer;

  procedure AddFile(const AFile: TJSONObject);
  var
    LPath: String;
    LStream: TFileStream;
  begin
    LPath := SafeChild(ARoot, 'build/web/' + AFile.Strings['url']);
    Check(HashFile(LPath) = AFile.Strings['sha256'], 'Exact pinned source file hash');
    Check(FileByteCount(LPath) = AFile.Int64s['bytes'], 'Exact pinned source size');
    LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      LBundle.AddFile(AFile.Strings['path'], LStream);
      Inc(LExpectedBytes, LStream.Size);
    finally
      LStream.Free;
    end;
  end;

begin
  for I := 0 to High(LStores) do
  begin
    LStores[I] := nil;
    LLeases[I] := nil;
  end;
  LStore := nil;
  LBundle := nil;
  LManifest := nil;
  LTriangles := 0;
  LClosureBytes := 0;
  FReload := False;
  ClearTextures;
  try
    LManifestPath := SafeChild(ARoot, 'build/web/library/catalog/' + KitId + '-' +
      ManifestHash + '.json');
    Check(HashFile(LManifestPath) = ManifestHash, 'Exact pinned furniture manifest');
    LManifest := LoadJSON(LManifestPath);
    for I := 0 to High(LLeases) do
    begin
      if not AShared or (I = 0) then
      begin
        LStores[I] := TCatalogSharedFiles.Create(16 * 1024 * 1024);
        LStore := LStores[I];
      end;
      LModel := nil;
      for J := 0 to LManifest.Arrays['models'].Count - 1 do
      begin
        if LManifest.Arrays['models'].Objects[J].Strings['id'] =
          KitId + '/gltf/' + ModelNames[I] then
        begin
          LModel := LManifest.Arrays['models'].Objects[J];
          Break;
        end;
      end;
      Check(LModel <> nil, 'Measured furniture model belongs to pinned manifest');
      LBundle := TCatalogFileBundle.Create(16 * 1024 * 1024, LStore);
      LExpectedBytes := 0;
      for J := 0 to LModel.Arrays['files'].Count - 1 do
      begin
        AddFile(LModel.Arrays['files'].Objects[J]);
      end;
      AddFile(LManifest.Objects['notice']);
      LBundle.Seal(LModel.Strings['path']);
      LLeases[I] := TCatalogSceneLease.Create(LBundle);
      Check(LBundle = nil, 'Scene consumes source ownership');
      Check(LLeases[I].SourceBytes = LExpectedBytes, 'Lease counts full closure including notice');
      Inc(LClosureBytes, LLeases[I].SourceBytes);
      Inc(LTriangles, LLeases[I].Scene.TrianglesCount);
      LGeometry := StaticGeometryHash(LLeases[I].Scene);
      if AShared then
      begin
        Check(LGeometry = FGeometry[I], 'Shared source retains complete transformed geometry');
      end
      else
      begin
        FGeometry[I] := LGeometry;
      end;
      LLeases[I].Scene.RootNode.EnumerateNodes(TImageTextureNode, Texture, False);
    end;
    LUniqueBytes := 0;
    for I := 0 to High(LStores) do
    begin
      if LStores[I] <> nil then
      begin
        Inc(LUniqueBytes, LStores[I].UniqueBytes);
      end;
    end;
    Check(LTriangles = 3146, 'All eight scene triangle counts retained');
    Check(FTextureNodes = 8, 'Eight scene texture nodes loaded');
    Check(LClosureBytes = 290028, 'All eight complete closures retain notices');
    if AShared then
    begin
      Check((FImages.Count = 1) and (FUrls.Count = 1), 'Shared scenes decode one atlas');
      Check(LStores[0].FileCount = 18, 'Atlas and notice shared across eight closures');
      Check(LUniqueBytes = 175004, 'Unique complete source byte count');
    end
    else
    begin
      Check((FImages.Count = 8) and (FUrls.Count = 8), 'Isolated control decodes eight atlases');
      Check(LUniqueBytes = LClosureBytes, 'Isolated source bytes count each closure');
    end;
    WriteLn('Shared=', AShared, ' scenes=8 triangles=', LTriangles,
      ' decodedImages=', FImages.Count, ' sourceBytes=', LUniqueBytes);
    for I := 0 to 3 do
    begin
      FreeAndNil(LLeases[I]);
    end;
    if AShared then
    begin
      Check(LStores[0].FileCount = 10, 'Four released leases remove only unreferenced files');
    end;
    ClearTextures;
    FReload := True;
    for I := 4 to High(LLeases) do
    begin
      LLeases[I].Scene.RootNode.EnumerateNodes(TImageTextureNode, Texture, False);
    end;
    Check(FTextureNodes = 4, 'All surviving lease textures reload');
    if AShared then
    begin
      Check(FImages.Count = 1, 'Surviving leases still share one decoded atlas');
    end
    else
    begin
      Check(FImages.Count = 4, 'Isolated surviving leases retain separate decoded images');
    end;
    for I := 0 to High(LLeases) do
    begin
      FreeAndNil(LLeases[I]);
    end;
    for I := 0 to High(LStores) do
    begin
      if LStores[I] <> nil then
      begin
        Check((LStores[I].FileCount = 0) and (LStores[I].UniqueBytes = 0),
          'Last scene release removes all retained source files');
      end;
    end;
  finally
    for I := 0 to High(LLeases) do
    begin
      LLeases[I].Free;
    end;
    LBundle.Free;
    for I := 0 to High(LStores) do
    begin
      LStores[I].Free;
    end;
    LManifest.Free;
  end;
end;

function CheckSharedCatalogScenes(const ARoot: String): Integer;
var
  LCheck: TSharedSceneCheck;
begin
  LCheck := TSharedSceneCheck.Create;
  try
    LCheck.Run(ARoot, False);
    LCheck.Run(ARoot, True);
    Result := LCheck.FChecks;
  finally
    LCheck.Free;
  end;
end;

end.
