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
unit phanes.catalog.residency;

{$mode delphi}
{$H+}

interface

uses
  Classes, JOB.JS, CastleScene, CastleViewport, phanes.world.types,
  phanes.world.appearance;

type
  TCatalogRetireTemplate = procedure(const AId: String) of object;

  { Optional object templates are pinned by the complete active world. During
    replacement the old templates remain until the caller's drawn-world barrier.
    Count/pixel/source limits are independent; none claims a total GPU byte cap. }
  TCatalogSceneStore = class
  private
    FBrowser: TJSObject;
    FViewport: TCastleViewport;
    FTemplates: TStringList;
    FEntries: TStringList;
    FActive: TStringList;
    FSeen: LongInt;
    FSourceBytes: Int64;
    FVertices: Int64;
    FTexturePixels: Int64;
    FTriangles: Int64;
    FRetireTemplate: TCatalogRetireTemplate;
    procedure PublishState;
  public
    constructor Create(const ABrowser: TJSObject; const AViewport: TCastleViewport;
      const ATemplates: TStringList);
    destructor Destroy; override;
    procedure StagePending(const AAppearance: TWorldAppearance);
    procedure SetWorld(const AWorld: TWorld);
    procedure ApplyAppearance(const AAppearance: TWorldAppearance);
    { Only after old chunks/interior references have been destroyed, and while
      no candidate is preparing. Derived templates are freed before raw scenes. }
    procedure Collect;
    function Scene(const AId: String): TCastleScene;
    property RetireTemplate: TCatalogRetireTemplate read FRetireTemplate write FRetireTemplate;
  end;

implementation

uses
  SysUtils, FPJSON, CastleBoxes, phanes.catalog.admission,
  phanes.catalog.files, phanes.catalog.scene, phanes.world.surfaces;

const
  SourceLimit = 16 * 1024 * 1024;
  VertexLimit = 250000;
  TriangleLimit = 50000;
  TexturePixelLimit = 4 * 1024 * 1024;
  ModelLimit = 32;

type
  TResidentModel = class
    FLease: TCatalogSceneLease;
    FAdmission: TOptionalAssetAdmission;
    destructor Destroy; override;
  end;

destructor TResidentModel.Destroy;
begin
  FLease.Free;
  inherited Destroy;
end;

constructor TCatalogSceneStore.Create(const ABrowser: TJSObject;
  const AViewport: TCastleViewport; const ATemplates: TStringList);
begin
  inherited Create;
  FBrowser := ABrowser;
  FViewport := AViewport;
  FTemplates := ATemplates;
  FEntries := TStringList.Create;
  FEntries.CaseSensitive := True;
  FActive := TStringList.Create;
  FActive.CaseSensitive := True;
  PublishState;
end;

destructor TCatalogSceneStore.Destroy;
var
  I: Integer;
begin
  for I := 0 to FEntries.Count - 1 do
  begin
    FEntries.Objects[I].Free;
  end;
  FEntries.Free;
  FActive.Free;
  inherited Destroy;
end;

procedure TCatalogSceneStore.PublishState;
var
  LIds: TJSONArray;
  LStats: TJSONObject;
  I: Integer;
begin
  LIds := TJSONArray.Create;
  LStats := TJSONObject.Create;
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      LIds.Add(FEntries[I]);
    end;
    FBrowser.WriteJSPropertyUtf8String('phanesCatalogReadyIds', LIds.AsJSON);
    LStats.Add('models', FEntries.Count);
    LStats.Add('sourceBytes', FSourceBytes);
    LStats.Add('vertices', FVertices);
    LStats.Add('triangles', FTriangles);
    LStats.Add('texturePixels', FTexturePixels);
    LStats.Add('sourceLimit', SourceLimit);
    LStats.Add('vertexLimit', VertexLimit);
    LStats.Add('triangleLimit', TriangleLimit);
    LStats.Add('texturePixelLimit', TexturePixelLimit);
    LStats.Add('modelLimit', ModelLimit);
    FBrowser.WriteJSPropertyUtf8String('phanesCatalogResidentStats', LStats.AsJSON);
  finally
    LStats.Free;
    LIds.Free;
  end;
end;

procedure TCatalogSceneStore.StagePending(const AAppearance: TWorldAppearance);
var
  LRevision: LongInt;
  LMessage: IJSObject;
  LValue: IJSObject;
  LFiles: IJSObject;
  LFile: IJSObject;
  LAdmission: TOptionalAssetAdmission;
  LBundle: TCatalogFileBundle;
  LResident: TResidentModel;
  LBounds: TBox3D;
  LId: String;
  LRoot: String;
  LRootMatches: Integer;
  LCount: Integer;
  I: Integer;
begin
  LRevision := FBrowser.ReadJSPropertyLongInt('phanesCatalogStageRevision');
  if (LRevision = 0) or (LRevision = FSeen) then
  begin
    Exit;
  end;
  FSeen := LRevision;
  LMessage := FBrowser.ReadJSPropertyObject('phanesCatalogStage', TJSObject);
  if (LMessage = nil) or
    (LMessage.ReadJSPropertyLongInt('request') <>
    FBrowser.ReadJSPropertyLongInt('phanesCatalogRequestId')) then
  begin
    Exit;
  end;
  LBundle := nil;
  LResident := nil;
  try
    try
      LId := LMessage.ReadJSPropertyUtf8String('asset');
      if not OptionalAssetAdmission(LId, LAdmission) then
      begin
        raise Exception.Create('The requested object has no catalog admission');
      end;
      if FEntries.IndexOf(LId) < 0 then
      begin
        if (FEntries.Count >= ModelLimit) or
          (FVertices + LAdmission.FVertices > VertexLimit) or
          (FTriangles + LAdmission.FTriangles > TriangleLimit) or
          (FTexturePixels + LAdmission.FTexturePixels > TexturePixelLimit) or
          (FSourceBytes >= SourceLimit) then
        begin
          raise Exception.Create('Optional objects reached the scene budget; remove unused items first');
        end;
        LValue := LMessage.ReadJSPropertyObject('bundle', TJSObject);
        if (LValue = nil) or
          (LValue.ReadJSPropertyUtf8String('kitId') <> LAdmission.FKitId) or
          (LValue.ReadJSPropertyUtf8String('modelId') <> LAdmission.FModelId) or
          (LValue.ReadJSPropertyUtf8String('manifestSha256') <> LAdmission.FManifestSha256) then
        begin
          raise Exception.Create('The prepared model differs from its admitted source revision');
        end;
        LRoot := LValue.ReadJSPropertyUtf8String('rootPath');
        LFiles := LValue.ReadJSPropertyObject('files', TJSObject);
        if LFiles = nil then
        begin
          raise Exception.Create('The prepared model has no source files');
        end;
        LCount := LFiles.ReadJSPropertyLongInt('length');
        if (LCount <= 0) or (LCount > 4096) then
        begin
          raise Exception.Create('The prepared model has an invalid file count');
        end;
        LRootMatches := 0;
        for I := 0 to LCount - 1 do
        begin
          LFile := LFiles.ReadJSPropertyObject(IntToStr(I), TJSObject);
          if (LFile <> nil) and (LFile.ReadJSPropertyUtf8String('path') = LRoot) and
            (LFile.ReadJSPropertyUtf8String('sha256') = LAdmission.FSourceSha256) then
          begin
            Inc(LRootMatches);
          end;
        end;
        if LRootMatches <> 1 then
        begin
          raise Exception.Create('The prepared root model hash differs from its admission');
        end;
        LBundle := CatalogBundleFromBrowser(LValue,
          LValue.ReadJSPropertyLongInt('generation'), SourceLimit - FSourceBytes);
        LResident := TResidentModel.Create;
        LResident.FAdmission := LAdmission;
        LResident.FLease := TCatalogSceneLease.Create(LBundle);
        LBounds := LResident.FLease.Scene.BoundingBox;
        if (LResident.FLease.Scene.TrianglesCount <> LAdmission.FTriangles) or
          (LBounds.SizeX * LAdmission.FUniformScale > LAdmission.FWidth / 1000) or
          (LBounds.SizeZ * LAdmission.FUniformScale > LAdmission.FDepth / 1000) or
          (LBounds.SizeY * LAdmission.FUniformScale > LAdmission.FHeight / 1000) then
        begin
          raise Exception.Create('Decoded object geometry differs from its placement admission');
        end;
        ApplyWorldSurface(LResident.FLease.Scene, AAppearance);
        LResident.FLease.PrepareResources(FViewport);
        FEntries.AddObject(LId, LResident);
        Inc(FSourceBytes, LResident.FLease.SourceBytes);
        Inc(FVertices, LAdmission.FVertices);
        Inc(FTriangles, LAdmission.FTriangles);
        Inc(FTexturePixels, LAdmission.FTexturePixels);
        LResident := nil;
        PublishState;
      end;
      FBrowser.WriteJSPropertyUtf8String('phanesCatalogStageError', '');
    except
      on LException: Exception do
      begin
        FBrowser.WriteJSPropertyUtf8String('phanesCatalogStageError', LException.Message);
      end;
    end;
  finally
    LResident.Free;
    LBundle.Free;
    FBrowser.WriteJSPropertyLongInt('phanesCatalogStageAck', LRevision);
  end;
end;

procedure TCatalogSceneStore.SetWorld(const AWorld: TWorld);
var
  LId: String;
  I: Integer;
begin
  FActive.Clear;
  for I := 0 to High(AWorld.FComposition.FNodes) do
  begin
    LId := AWorld.FComposition.FNodes[I].FAssetId;
    if (Pos('phanes.catalog.', LId) = 1) and (FActive.IndexOf(LId) < 0) then
    begin
      FActive.Add(LId);
    end;
  end;
  { Pin the complete world, including foliage in currently distant chunks.
    Camera streaming may build those chunks after this publication finishes. }
  for I := 0 to High(AWorld.FLayers[4]) do
  begin
    LId := AWorld.FLayers[4][I];
    if (Pos('phanes.catalog.', LId) = 1) and (FActive.IndexOf(LId) < 0) then
    begin
      FActive.Add(LId);
    end;
  end;
end;

procedure TCatalogSceneStore.ApplyAppearance(const AAppearance: TWorldAppearance);
var
  I: Integer;
begin
  for I := 0 to FEntries.Count - 1 do
  begin
    ApplyWorldSurface(TResidentModel(FEntries.Objects[I]).FLease.Scene, AAppearance);
  end;
end;

procedure TCatalogSceneStore.Collect;
var
  LResident: TResidentModel;
  LTemplate: Integer;
  LChanged: Boolean;
  I: Integer;
begin
  LChanged := False;
  for I := FEntries.Count - 1 downto 0 do
  begin
    if FActive.IndexOf(FEntries[I]) >= 0 then
    begin
      Continue;
    end;
    { Both the studio and same-world modular renderer cache derived templates.
      Retire every such reference before releasing the raw scene and its files. }
    if Assigned(FRetireTemplate) then
    begin
      FRetireTemplate(FEntries[I]);
    end;
    LTemplate := FTemplates.IndexOf('interior:' + FEntries[I]);
    if LTemplate >= 0 then
    begin
      FTemplates.Objects[LTemplate].Free;
      FTemplates.Delete(LTemplate);
    end;
    LTemplate := FTemplates.IndexOf(FEntries[I]);
    if LTemplate >= 0 then
    begin
      FTemplates.Objects[LTemplate].Free;
      FTemplates.Delete(LTemplate);
    end;
    LResident := TResidentModel(FEntries.Objects[I]);
    Dec(FSourceBytes, LResident.FLease.SourceBytes);
    Dec(FVertices, LResident.FAdmission.FVertices);
    Dec(FTriangles, LResident.FAdmission.FTriangles);
    Dec(FTexturePixels, LResident.FAdmission.FTexturePixels);
    LResident.Free;
    FEntries.Delete(I);
    LChanged := True;
  end;
  if LChanged then
  begin
    PublishState;
  end;
end;

function TCatalogSceneStore.Scene(const AId: String): TCastleScene;
var
  LIndex: Integer;
begin
  LIndex := FEntries.IndexOf(AId);
  if LIndex < 0 then
  begin
    raise Exception.Create('Optional object was published before its resources were prepared: ' + AId);
  end;
  Result := TResidentModel(FEntries.Objects[LIndex]).FLease.Scene;
end;

end.
