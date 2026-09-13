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
unit phanes.tests.catalog.shared.gpu;

{$mode delphi}
{$H+}

interface

implementation

uses
  Classes, SysUtils, FPJSON, JOB.JS, CastleWindow, CastleUIControls,
  CastleViewport, CastleScene, CastleSceneCore, CastleTransform, CastleVectors, X3DNodes,
  phanes.catalog.files, phanes.catalog.shared.files, phanes.catalog.scene,
  phanes.catalog.textures,
  phanes.world.appearance, phanes.world.surfaces;

type
  TSharedGpuView = class(TCastleView)
  private
    FBrowser: TJSObject;
    FViewport: TCastleViewport;
    FStore: TCatalogSharedFiles;
    FLeases: array[0..7] of TCatalogSceneLease;
    FProfiles: array[0..7] of TCatalogTextureProfile;
    FImages: TList;
    FUrls: TStringList;
    FRevision: LongInt;
    FDrawn: LongInt;
    FAlterSampler: Boolean;
    procedure Texture(ANode: TX3DNode);
    procedure ClearModels;
    procedure LoadModels;
    procedure Publish;
  public
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const ASecondsPassed: Single; var AHandleInput: Boolean); override;
    procedure RenderOverChildren; override;
  end;

var
  GWindow: TCastleWindow;

function CopyBundle(const AValue: IJSObject;
  const AStore: TCatalogSharedFiles): TCatalogFileBundle;
var
  LFiles: IJSObject;
  LFile: IJSObject;
  LBuffer: IJSArrayBuffer;
  LStream: TMemoryStream;
  I: Integer;
begin
  if AStore = nil then
  begin
    Result := TCatalogFileBundle.Create(16 * 1024 * 1024);
  end
  else
  begin
    Result := TCatalogFileBundle.Create(16 * 1024 * 1024, AStore);
  end;
  try
    LFiles := AValue.ReadJSPropertyObject('files', TJSObject);
    if (LFiles = nil) or (LFiles.ReadJSPropertyLongInt('length') <> 4) then
    begin
      raise Exception.Create('Witness requires glTF, bin, atlas and notice');
    end;
    for I := 0 to 3 do
    begin
      LFile := LFiles.ReadJSPropertyObject(IntToStr(I), TJSObject);
      LBuffer := LFile.ReadJSPropertyObject('buffer', TJSArrayBuffer) as IJSArrayBuffer;
      if (LBuffer = nil) or (LBuffer.ByteLength < 1) or
        (LBuffer.ByteLength > 16 * 1024 * 1024 - Result.ByteCount) then
      begin
        raise Exception.Create('Witness source buffer is outside its closure budget');
      end;
      LStream := TMemoryStream.Create;
      try
        LStream.Size := LBuffer.ByteLength;
        LBuffer.CopyToMemory(LStream.Memory, LBuffer.ByteLength);
        Result.AddFile(LFile.ReadJSPropertyUtf8String('path'), LStream);
      finally
        LStream.Free;
      end;
    end;
    Result.Seal(AValue.ReadJSPropertyUtf8String('rootPath'));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TSharedGpuView.Start;
var
  LLight: TCastleDirectionalLight;
begin
  inherited;
  FBrowser := TJSObject.JOBCreateGlobal('window');
  FImages := TList.Create;
  FUrls := TStringList.Create;
  FUrls.CaseSensitive := True;
  FViewport := TCastleViewport.Create(FreeAtStop);
  FViewport.FullSize := True;
  FViewport.BackgroundColor := Vector4(0.12, 0.16, 0.2, 1);
  InsertFront(FViewport);
  FViewport.Camera := TCastleCamera.Create(FreeAtStop);
  FViewport.Items.Add(FViewport.Camera);
  FViewport.Camera.ProjectionNear := 0.01;
  FViewport.Camera.SetView(Vector3(10, 12, 18), Vector3(-10, -12, -18), Vector3(0, 1, 0));
  LLight := TCastleDirectionalLight.Create(FreeAtStop);
  LLight.Orientation := otUpYDirectionMinusZ;
  LLight.Direction := Vector3(-1, -1, -1);
  LLight.Intensity := 2;
  FViewport.Items.Add(LLight);
  FBrowser.WriteJSPropertyBoolean('sharedGpuReady', True);
end;

procedure TSharedGpuView.ClearModels;
var
  I: Integer;
begin
  for I := 0 to High(FLeases) do
  begin
    if FLeases[I] <> nil then
    begin
      FViewport.Items.Remove(FLeases[I].Scene);
      FreeAndNil(FProfiles[I]);
      FreeAndNil(FLeases[I]);
    end;
  end;
  FreeAndNil(FStore);
end;

procedure TSharedGpuView.Stop;
begin
  ClearModels;
  FreeAndNil(FUrls);
  FreeAndNil(FImages);
  FreeAndNil(FBrowser);
  inherited;
end;

procedure TSharedGpuView.Texture(ANode: TX3DNode);
var
  LTexture: TImageTextureNode;
begin
  LTexture := ANode as TImageTextureNode;
  if FAlterSampler then
  begin
    if LTexture.TextureProperties = nil then
    begin
      LTexture.TextureProperties := TTexturePropertiesNode.Create;
    end;
    LTexture.TextureProperties.FdBoundaryModeS.Value := 'CLAMP_TO_EDGE';
  end;
  if FImages.IndexOf(LTexture.TextureImage) < 0 then
  begin
    FImages.Add(LTexture.TextureImage);
  end;
  if FUrls.IndexOf(LTexture.TextureUsedFullUrl) < 0 then
  begin
    FUrls.Add(LTexture.TextureUsedFullUrl);
  end;
end;

procedure TSharedGpuView.LoadModels;
var
  LValues: IJSObject;
  LValue: IJSObject;
  LBundle: TCatalogFileBundle;
  LAppearance: TWorldAppearance;
  I: Integer;
begin
  ClearModels;
  if FBrowser.ReadJSPropertyBoolean('sharedGpuUseShared') then
  begin
    FStore := TCatalogSharedFiles.Create(16 * 1024 * 1024);
  end;
  LValues := FBrowser.ReadJSPropertyObject('sharedGpuBundles', TJSObject);
  if (LValues = nil) or (LValues.ReadJSPropertyLongInt('length') <> 8) then
  begin
    raise Exception.Create('Witness needs eight verified model bundles');
  end;
  LAppearance := SolveWorldAppearance(42);
  FBrowser.WriteJSPropertyUtf8String('sharedGpuAppearance',
    FloatToStr(LAppearance.FTint.FR) + ',' + FloatToStr(LAppearance.FTint.FG) + ',' +
    FloatToStr(LAppearance.FTint.FB) + ';' + FloatToStr(LAppearance.FRoughness));
  for I := 0 to 7 do
  begin
    LValue := LValues.ReadJSPropertyObject(IntToStr(I), TJSObject);
    LBundle := CopyBundle(LValue, FStore);
    try
      FLeases[I] := TCatalogSceneLease.Create(LBundle);
    finally
      LBundle.Free;
    end;
    FAlterSampler := (I = 0) and FBrowser.ReadJSPropertyBoolean('sharedGpuAlterSampler');
    FLeases[I].Scene.RootNode.EnumerateNodes(TImageTextureNode, Texture, False);
    FAlterSampler := False;
    ApplyWorldSurface(FLeases[I].Scene, LAppearance);
    FProfiles[I] := TCatalogTextureProfile.Create(FLeases[I].Scene,
      'furniture-' + IntToStr(I), 1024 * 1024);
    FLeases[I].Scene.Translation := Vector3((I mod 4 - 1.5) * 4, 0, (I div 4 - 0.5) * 4);
    FLeases[I].PrepareResources(FViewport);
    FViewport.Items.Add(FLeases[I].Scene);
  end;
end;

procedure TSharedGpuView.Publish;
var
  LCount: Integer;
  LTriangles: Integer;
  LBytes: Int64;
  LState: TJSONObject;
  LProfiles: array of TCatalogTextureProfile;
  I: Integer;
begin
  FImages.Clear;
  FUrls.Clear;
  LCount := 0;
  LTriangles := 0;
  LBytes := 0;
  for I := 0 to 7 do
  begin
    if FLeases[I] <> nil then
    begin
      SetLength(LProfiles, LCount + 1);
      LProfiles[LCount] := FProfiles[I];
      Inc(LCount);
      Inc(LTriangles, FLeases[I].Scene.TrianglesCount);
      Inc(LBytes, FLeases[I].SourceBytes);
      FLeases[I].Scene.RootNode.EnumerateNodes(TImageTextureNode, Texture, False);
    end;
  end;
  if FStore <> nil then
  begin
    LBytes := FStore.UniqueBytes;
  end;
  LState := TJSONObject.Create(['models', LCount, 'triangles', LTriangles,
    'sourceBytes', LBytes, 'images', FImages.Count, 'urls', FUrls.Count,
    'textureProfilePixels', CatalogTexturePixels(LProfiles)]);
  try
    FBrowser.WriteJSPropertyUtf8String('sharedGpuState', LState.AsJSON);
  finally
    LState.Free;
  end;
end;

procedure TSharedGpuView.Update(const ASecondsPassed: Single; var AHandleInput: Boolean);
var
  LRevision: Integer;
  LAction: String;
  I: Integer;
begin
  inherited;
  LRevision := FBrowser.ReadJSPropertyLongInt('sharedGpuRevision');
  if LRevision = FRevision then
  begin
    Exit;
  end;
  FRevision := LRevision;
  try
    LAction := FBrowser.ReadJSPropertyUtf8String('sharedGpuAction');
    if LAction = 'load' then
    begin
      LoadModels;
    end
    else if LAction = 'half' then
    begin
      for I := 0 to 3 do
      begin
        FViewport.Items.Remove(FLeases[I].Scene);
        FreeAndNil(FProfiles[I]);
        FreeAndNil(FLeases[I]);
      end;
    end
    else if LAction = 'reload' then
    begin
      { Free all surviving scene resources before preparing any of them. }
      for I := 0 to 7 do
      begin
        if FLeases[I] <> nil then
        begin
          FLeases[I].Scene.GLContextClose;
          FLeases[I].Scene.FreeResources([frTextureDataInNodes]);
        end;
      end;
      for I := 0 to 7 do
      begin
        if FLeases[I] <> nil then
        begin
          FLeases[I].PrepareResources(FViewport);
        end;
      end;
    end
    else if LAction = 'clear' then
    begin
      ClearModels;
    end
    else
    begin
      raise Exception.Create('Unknown GPU witness action');
    end;
    Publish;
    FBrowser.WriteJSPropertyUtf8String('sharedGpuFailure', '');
    FDrawn := FRevision;
  except
    on LException: Exception do
    begin
      FBrowser.WriteJSPropertyUtf8String('sharedGpuFailure', LException.Message);
    end;
  end;
end;

procedure TSharedGpuView.RenderOverChildren;
begin
  inherited;
  FBrowser.WriteJSPropertyLongInt('sharedGpuDrawn', FDrawn);
end;

procedure InitializeApplication;
begin
  GWindow.Container.View := TSharedGpuView.Create(Application);
end;

initialization
  GWindow := TCastleWindow.Create(Application);
  Application.MainWindow := GWindow;
  Application.OnInitialize := InitializeApplication;
end.
