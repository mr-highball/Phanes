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

unit phanes.app.view;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  FPJSON,
  CastleUIControls,
  CastleViewport,
  CastleTransform,
  CastleScene,
  CastleVectors,
  CastleColors,
  CastleBoxes,
  JOB.JS,
  phanes.world.landscape,
  phanes.world.elevation,
  phanes.world.placement,
  phanes.interiors.scene,
  phanes.buildings.scene,
  phanes.styles.render,
  phanes.world.appearance,
  phanes.catalog.residency;

type
  TWorldChunk = record
    FRoot: TCastleTransform;
    FSignature: String;
    FWantedSignature: String;
    FDetail: Boolean;
    FWantedDetail: Boolean;
  end;

  TMainView = class(TCastleView)
  private
    FViewport: TCastleViewport;
    FStyles: TVisualStyleRenderer;
    FStyleVersion: Integer;
    FStyleRenderedVersion: Integer;
    FStyleIndex: Integer;
    FStyleStrength: Double;
    FStyleValidRequest: Boolean;
    FWorldRoot: TCastleTransform;
    FModular: TModularScene;
    FModularOutline: TCastleTransform;
    FModularSelected: String;
    FModularSceneSeen: Integer;
    FModularFrameVersion: Integer;
    FModularBounds: TBox3D;
    FModularStroke: Single;
    FInterior: TInteriorScene;
    FInteriorId: String;
    FInteriorVersion: Integer;
    FInteriorSceneVersion: Integer;
    FInteriorFrameVersion: Integer;
    FInteriorRenderedVersion: Integer;
    FSelectionRoot: TCastleTransform;
    FGroundworkOutline: TCastleTransform;
    FGroundworkSelectionVersion: Integer;
    FGroundworkRenderedVersion: Integer;
    FGroundworkSelectionDirty: Boolean;
    FGroundworkSelectedId: String;
    FGroundworkFrameVersion: Integer;
    FGroundworkBounds: TBox3D;
    FGroundworkStroke: Single;
    FBrowser: TJSObject;
    FTemplates: TStringList;
    FCatalog: TCatalogSceneStore;
    FPalette: TJSONObject;
    FAssetBounds: TJSONObject;
    FSceneVersion: Integer;
    FSelectionVersion: Integer;
    FSelectionMasked: Boolean;
    FPickVersion: Integer;
    FCameraVersion: Integer;
    FRenderedCameraVersion: Integer;
    FRenderedFrames: Integer;
    FReady: Boolean;
    FSize: Integer;
    FLandscape: TLandscape;
    FChunks: array of TWorldChunk;
    FChunkSide: Integer;
    FMode: String;
    FWalkX: Double;
    FWalkZ: Double;
    FFocusX: Double;
    FFocusZ: Double;
    FSun: TCastleDirectionalLight;
    FFillLights: array[0..3] of TCastleDirectionalLight;
    FFog: TCastleFog;
    FAppearance: TWorldAppearance;
    FAppearanceSeed: Cardinal;
    FHasAppearance: Boolean;
    FChunkBuilds: Integer;
    FMaxChunkMs: Double;
    FRenderPending: Boolean;
    FLastWalkInput: String;
    FWalkIdle: Boolean;
    FReportedResident: Integer;
    FReportedPending: Integer;
    FReportedBuilds: Integer;
    procedure BuildChunk(const AIndex: Integer);
    procedure StreamChunks;
    procedure UpdateWalk(const ASeconds: Single);
    procedure UpdateEntry;
    function PickTerrain(const AOrigin, ADirection: TVector3; out APoint: TVector3): Boolean;
    function PickGroundwork(const AOrigin, ADirection: TVector3;
      out APoint: TVector3; out ATerrain: Boolean): String;
    function RawAsset(const AId: String): TCastleScene;
    function Asset(const AId: String): TCastleTransform;
    procedure RecordAssetBounds(const AId: String; const ATemplate: TCastleTransform);
    procedure RetireCatalogTemplate(const AId: String);
    function Definition(const AId: String): TJSONObject;
    procedure ApplyWorld;
    procedure ApplyInterior;
    procedure ApplySelection;
    procedure ApplyGroundworkSelection;
    procedure UpdateGroundworkStroke;
    procedure UpdateInteriorStroke;
    function SelectionMetresPerPixel(const ABounds: TBox3D): Single;
    procedure ApplyCamera;
    procedure ApplyStyle;
  public
    procedure Start; override;
    procedure Stop; override;
    procedure RenderOverChildren; override;
    procedure Update(const ASecondsPassed: Single; var AHandleInput: Boolean); override;
  end;

implementation

uses
  SysUtils,
  Math,
  JSONParser,
  CastleCameras,
  CastleProjection,
  CastleRenderOptions,
  X3DNodes,
  phanes.world.types,
  phanes.styles.catalog,
  phanes.styles.selection,
  phanes.selection.scene,
  phanes.composition.wire,
  phanes.terrain.wire,
  phanes.world.height,
  phanes.world.terrain,
  phanes.world.surfaces,
  phanes.structures.scene,
  phanes.structures.support,
  phanes.interiors.profiles,
  phanes.groundworks.scene,
  phanes.scene.picking,
  phanes.world.batching,
  phanes.catalog.regional,
  phanes.groundworks.geometry,
  phanes.groundworks.assembly;

const
  CFillIntensities: array[0..3] of Single = (0.28, 0.28, 0.18, 0.18);

type
  TPhanesViewport = class(TCastleViewport)
  public
    function EffectsRendered: Boolean;
  end;

  TPhanesSun = class(TCastleDirectionalLight)
  public
    procedure Configure;
  end;

function TPhanesViewport.EffectsRendered: Boolean;
begin
  Result := RenderScreenEffects;
end;

procedure TMainView.ApplyStyle;
var
  LId: String;
  LDetail: Double;
begin
  LId := FBrowser.ReadJSPropertyUtf8String('phanesStyleId');
  FStyleIndex := VisualStyleIndex(LId);
  FStyleStrength := FBrowser.ReadJSPropertyDouble('phanesStyleStrength');
  LDetail := FBrowser.ReadJSPropertyDouble('phanesStyleDetail');
  FStyleValidRequest := ValidStyleSettings(FStyleIndex, FStyleStrength, LDetail);
  if not FStyleValidRequest then
  begin
    FStyleIndex := 0;
    FStyleStrength := 1;
    LDetail := 0.5;
  end;
  FStyles.Apply(FStyleIndex, FStyleStrength, LDetail,
    FViewport.RenderRect.Height / Max(1, FBrowser.ReadJSPropertyDouble('phanesViewportCssHeight')));
end;

procedure TPhanesSun.Configure;
begin
  { Public shadow volumes traverse the viewport's separate scenes and their
    references. A map attached only to this light's private scene has no model
    receivers. Keep the light node owned by its original scene. }
  Shadows := True;
end;

function TMainView.RawAsset(const AId: String): TCastleScene;
var
  LIndex: Integer;
begin
  if Pos('phanes.catalog.', AId) = 1 then
  begin
    Exit(FCatalog.Scene(AId));
  end;
  LIndex := FTemplates.IndexOf('raw:' + AId);
  if LIndex >= 0 then
  begin
    Exit(TCastleScene(FTemplates.Objects[LIndex]));
  end;
  Result := TCastleScene.Create(FreeAtStop);
  Result.Load('castle-data:/kits/' + AId + '.glb');
  Result.PreciseCollisions := True;
  ApplyWorldSurface(Result, FAppearance);
  FTemplates.AddObject('raw:' + AId, Result);
end;

function TMainView.Definition(const AId: String): TJSONObject;
var
  LAssets: TJSONArray;
  I: Integer;
begin
  LAssets := FPalette.Arrays['assets'];
  for I := 0 to LAssets.Count - 1 do
  begin
    Result := TJSONObject(LAssets[I]);
    if Result.Strings['id'] = AId then
    begin
      Exit;
    end;
  end;
  raise Exception.Create('Unknown asset: ' + AId);
end;

procedure TMainView.RecordAssetBounds(const AId: String; const ATemplate: TCastleTransform);
var
  LInstance: TCastleTransformReference;
  LBounds: TBox3D;
  LData: TJSONObject;
  LDoor: TCastleTransform;
  LLeftJamb: TBox3D;
  LRightJamb: TBox3D;
  LHeader: TBox3D;
  LHalfX: Double;
  LHalfZ: Double;
  LBuildingProfile: TSupportedBuilding;
begin
  { Inspect the actual reference semantics used by BuildChunk. Bounds are local
    physical metres before a placed instance's yaw and translation. This compact
    diagnostic is published once per loaded asset, not once per object or frame. }
  LInstance := TCastleTransformReference.Create(nil);
  try
    LInstance.ReferenceTransformation := rtDoNotIgnore;
    LInstance.Reference := ATemplate;
    LBounds := LInstance.BoundingBox;
    if RockFootprint(AId, LHalfX, LHalfZ) and
      ((Abs(LBounds.Data[0].X + LHalfX) > 0.002) or
      (Abs(LBounds.Data[1].X - LHalfX) > 0.002) or
      (Abs(LBounds.Data[0].Z + LHalfZ) > 0.002) or
      (Abs(LBounds.Data[1].Z - LHalfZ) > 0.002)) then
    begin
      raise Exception.Create('Rock geometry needs a reviewed collision profile: ' + AId);
    end;
    if SupportedBuilding(AId, LBuildingProfile) and
      ((LBounds.Data[0].X < -LBuildingProfile.FHalfX / 1000 - 0.002) or
      (LBounds.Data[1].X > LBuildingProfile.FHalfX / 1000 + 0.002) or
      (LBounds.Data[0].Z < -LBuildingProfile.FHalfZ / 1000 - 0.002) or
      (LBounds.Data[1].Z > LBuildingProfile.FHalfZ / 1000 + 0.002) or
      (Abs(LBounds.Data[0].Y) > 0.002)) then
    begin
      raise Exception.Create('Building geometry needs a reviewed support profile: ' + AId);
    end;
    LData := TJSONObject.Create;
    LData.Add('min', TJSONArray.Create([LBounds.Data[0].X, LBounds.Data[0].Y,
      LBounds.Data[0].Z]));
    LData.Add('max', TJSONArray.Create([LBounds.Data[1].X, LBounds.Data[1].Y,
      LBounds.Data[1].Z]));
    LData.Add('size', TJSONArray.Create([LBounds.SizeX, LBounds.SizeY, LBounds.SizeZ]));
    if AId = 'cabin' then
    begin
      LDoor := TCastleTransform(ATemplate[0].FindComponent('CabinDoor'));
      LBounds := LDoor.BoundingBox;
      LData.Add('doorSize', TJSONArray.Create([LBounds.SizeX, LBounds.SizeY, LBounds.SizeZ]));
      LLeftJamb := TCastleTransform(ATemplate[0].FindComponent('CabinDoorJamb0')).BoundingBox;
      LRightJamb := TCastleTransform(ATemplate[0].FindComponent('CabinDoorJamb1')).BoundingBox;
      LHeader := TCastleTransform(ATemplate[0].FindComponent('CabinDoorHeader')).BoundingBox;
      LData.Add('doorClearance', TJSONArray.Create([
        LRightJamb.Data[0].X - LLeftJamb.Data[1].X, LHeader.Data[0].Y - 0.08]));
    end;
    if FAssetBounds.Find(AId) <> nil then
    begin
      FAssetBounds.Delete(AId);
    end;
    FAssetBounds.Add(AId, LData);
    FBrowser.WriteJSPropertyUnicodeString('phanesAssetBounds', UnicodeString(FAssetBounds.AsJSON));
  finally
    LInstance.Free;
  end;
end;

procedure TMainView.RetireCatalogTemplate(const AId: String);
begin
  FModular.RetireModel(AId);
  if FAssetBounds.Find(AId) <> nil then
  begin
    FAssetBounds.Delete(AId);
    FBrowser.WriteJSPropertyUnicodeString('phanesAssetBounds', UnicodeString(FAssetBounds.AsJSON));
  end;
end;

function TMainView.Asset(const AId: String): TCastleTransform;
var
  LIndex: Integer;
  LDefinition: TJSONObject;
  LParts: TJSONArray;
  LPart: TJSONObject;
  LReference: TCastleTransformReference;
  LRaw: TCastleScene;
  LBounds: TBox3D;
  LScale: Single;
  LAssembly: TCastleTransform;
  LRegional: TRegionalAssetAdmission;
  I: Integer;
begin
  LIndex := FTemplates.IndexOf(AId);
  if LIndex >= 0 then
  begin
    Exit(TCastleTransform(FTemplates.Objects[LIndex]));
  end;
  LDefinition := Definition(AId);
  Result := TCastleTransform.Create(FreeAtStop);
  if AId = 'cabin' then
  begin
    Result.Add(CreateCabinShell(Result, FAppearance));
    FTemplates.AddObject(AId, Result);
    RecordAssetBounds(AId, Result);
    Exit;
  end;
  LAssembly := TCastleTransform.Create(Result);
  Result.Add(LAssembly);
  if RegionalAssetAdmission(AId, LRegional) then
  begin
    { Optional regional admission declares physical metres. Do not renormalize
      these models through the older palette's logical-width convention. }
    LRaw := RawAsset(AId);
    LBounds := LRaw.BoundingBox;
    LScale := LRegional.FUniformScale;
    LReference := TCastleTransformReference.Create(LAssembly);
    LReference.ReferenceTransformation := rtDoNotIgnore;
    LReference.Reference := LRaw;
    LReference.Scale := Vector3(LScale, LScale, LScale);
    LReference.Translation := Vector3(-LBounds.Center.X * LScale,
      -LBounds.Data[0].Y * LScale, -LBounds.Center.Z * LScale);
    LAssembly.Add(LReference);
    FTemplates.AddObject(AId, Result);
    RecordAssetBounds(AId, Result);
    Exit;
  end;
  if LDefinition.Find('prefab') <> nil then
  begin
    LParts := FPalette.Objects['prefabs'].Arrays[LDefinition.Strings['prefab']];
    for I := 0 to LParts.Count - 1 do
    begin
      LPart := TJSONObject(LParts[I]);
      LReference := TCastleTransformReference.Create(LAssembly);
      LReference.Reference := RawAsset(LPart.Strings['asset']);
      LReference.Scale := Vector3(LPart.Arrays['scale'].Floats[0],
        LPart.Arrays['scale'].Floats[1], LPart.Arrays['scale'].Floats[2]);
      LReference.Translation := Vector3(LPart.Arrays['position'].Floats[0],
        LPart.Arrays['position'].Floats[1], LPart.Arrays['position'].Floats[2]);
      LReference.Rotation := Vector4(0, 1, 0, DegToRad(LPart.Get('yaw', 0.0)));
      LAssembly.Add(LReference);
    end;
  end
  else
  begin
    LRaw := RawAsset(AId);
    LBounds := LRaw.BoundingBox;
    LScale := LDefinition.Floats['width'] / Max(0.01, Max(LBounds.SizeX, LBounds.SizeZ));
    LReference := TCastleTransformReference.Create(LAssembly);
    LReference.Reference := LRaw;
    LReference.Scale := Vector3(LScale, LScale, LScale);
    LReference.Translation := Vector3(-LBounds.Center.X * LScale,
      -LBounds.Data[0].Y * LScale, -LBounds.Center.Z * LScale);
    LAssembly.Add(LReference);
  end;
  { Normalize the complete transformed assembly, including imported GLB node
    offsets. Put this transform below the reusable template root: CGE's default
    reference semantics ignore a referenced root's own transform. Palette width
    retains its existing logical-unit contract; the resulting size is metres. }
  LBounds := LAssembly.BoundingBox;
  LScale := LDefinition.Floats['width'] * WorldAssetScale /
    Max(0.01, Max(LBounds.SizeX, LBounds.SizeZ));
  LAssembly.Scale := Vector3(LScale, LScale, LScale);
  LAssembly.Translation := Vector3(-LBounds.Center.X * LScale,
    -LBounds.Data[0].Y * LScale, -LBounds.Center.Z * LScale);
  FTemplates.AddObject(AId, Result);
  RecordAssetBounds(AId, Result);
end;

procedure TMainView.Start;
var
  LSky: TCastleBackground;
  procedure Fill(const AIndex: Integer; const ADirection, AColor: TVector3);
  var
    LLight: TCastleDirectionalLight;
  begin
    LLight := TCastleDirectionalLight.Create(FreeAtStop);
    LLight.Orientation := otUpYDirectionMinusZ;
    LLight.Direction := ADirection;
    LLight.Color := AColor;
    LLight.Intensity := CFillIntensities[AIndex];
    FFillLights[AIndex] := LLight;
    FViewport.Items.Add(LLight);
  end;
begin
  inherited;
  FLandscape := TLandscape.Create;
  ToneMapping := tmACES;
  FBrowser := TJSObject.JOBCreateGlobal('window');
  FTemplates := TStringList.Create;
  FAssetBounds := TJSONObject.Create;
  FSceneVersion := -1;
  FInteriorRenderedVersion := -1;
  FSelectionVersion := -1;
  FGroundworkSelectionVersion := -1;
  FGroundworkRenderedVersion := -1;
  FPickVersion := 0;
  FCameraVersion := -1;
  FReady := False;
  FSize := 12;
  FViewport := TPhanesViewport.Create(FreeAtStop);
  FStyles := TVisualStyleRenderer.Create(FViewport);
  FViewport.FullSize := True;
  FViewport.BackgroundColor := Vector4(0.065, 0.09, 0.12, 1);
  FViewport.DynamicBatching := True;
  FViewport.ScreenSpaceAmbientOcclusion := False;
  InsertFront(FViewport);
  FModular := TModularScene.Create(FreeAtStop);
  FModular.AssetLoader := RawAsset;
  FViewport.Items.Add(FModular);
  FViewport.Camera := TCastleCamera.Create(FreeAtStop);
  FViewport.Items.Add(FViewport.Camera);
  FViewport.Camera.ProjectionNear := 0.1;
  FViewport.Camera.ProjectionFar := 0;
  FCatalog := TCatalogSceneStore.Create(FBrowser, FViewport, FTemplates);
  FCatalog.RetireTemplate := RetireCatalogTemplate;
  FAppearance := SolveWorldAppearance(0);
  FSun := TPhanesSun.Create(FreeAtStop);
  { Light nodes emit along local -Z, unlike a model's default +Z direction. }
  FSun.Orientation := otUpYDirectionMinusZ;
  FSun.Direction := Vector3(-0.6, -1, -0.45);
  FSun.Color := Vector3(1, 0.95, 0.83);
  FSun.Intensity := 1.8;
  TPhanesSun(FSun).Configure;
  FViewport.Items.Add(FSun);
  { Four broad, unshadowed directions approximate sky and ground bounce.
    Their tetrahedral coverage leaves no surface normal without diffuse fill.
    They stay in world space as the player turns; no camera lamp is used. }
  Fill(0, Vector3(1, -1, 1), Vector3(0.76, 0.86, 1));
  Fill(1, Vector3(-1, -1, -1), Vector3(0.76, 0.86, 1));
  Fill(2, Vector3(1, 1, -1), Vector3(0.87, 0.81, 0.70));
  Fill(3, Vector3(-1, 1, 1), Vector3(0.87, 0.81, 0.70));
  LSky := TCastleBackground.Create(FreeAtStop);
  LSky.SkyTopColor := Vector3(0.19, 0.39, 0.60);
  LSky.SkyEquatorColor := Vector3(0.76, 0.81, 0.76);
  LSky.GroundEquatorColor := LSky.SkyEquatorColor;
  LSky.GroundBottomColor := Vector3(0.18, 0.27, 0.25);
  FViewport.Background := LSky;
  FFog := TCastleFog.Create(FreeAtStop);
  FFog.Color := LSky.SkyEquatorColor;
  FFog.VisibilityRange := 280;
  FViewport.Fog := FFog;
end;

procedure TMainView.Stop;
begin
  FreeAndNil(FStyles);
  { CGE's InternalStop frees this owner after Stop returns, and inherited Stop
    is empty. Destroy derived references now, before the catalog scenes/files. }
  FreeAtStop.DestroyComponents;
  FreeAndNil(FCatalog);
  FreeAndNil(FLandscape);
  FreeAndNil(FPalette);
  FreeAndNil(FAssetBounds);
  FreeAndNil(FTemplates);
  FreeAndNil(FBrowser);
  inherited;
end;

procedure TMainView.ApplyWorld;
var
  LData: TJSONObject;
  LWorld: TWorld;
  LWater: TCastleBox;
  I: Integer;
  J: Integer;
  LReason: String;
begin
  if FPalette = nil then
  begin
    FPalette := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesPalette')));
  end;
  LData := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesScene')));
  try
    LWorld := Default(TWorld);
    LWorld.FSize := LData.Integers['size'];
    LWorld.FSeed := LData.Int64s['seed'];
    LWorld.FAppearanceSeed := LData.Get('appearanceSeed', Int64(LWorld.FSeed));
    if not (LData.Get('formatVersion', 1) in [1, 2, 3, 4]) then
    begin
      raise Exception.Create('Unsupported world scene format.');
    end;
    LWorld.FRelativeElevation := LData.Get('formatVersion', 1) = 4;
    if LData.Get('formatVersion', 1) in [3, 4] then
    begin
      if (LData.Find('elevation') = nil) or
        not ReadTerrainJSON(LData.Find('elevation').AsJSON, LWorld.FElevation, LReason) then
      begin
        raise Exception.Create('Cannot render saved elevation: ' + LReason);
      end;
    end
    else if LData.Find('elevation') <> nil then
    begin
      raise Exception.Create('Saved elevation requires world scene version 3.');
    end;
    if not ValidateWorldHeight(LWorld, LReason) then
    begin
      raise Exception.Create('Cannot render world height: ' + LReason);
    end;
    if not ReadCompositionJSON(LData.Objects['composition'].AsJSON,
      LWorld.FComposition, LReason) then
    begin
      raise Exception.Create('Cannot render world composition: ' + LReason);
    end;
    if not FHasAppearance or (FAppearanceSeed <> LWorld.FAppearanceSeed) then
    begin
      FAppearance := SolveWorldAppearance(LWorld.FAppearanceSeed);
      FAppearanceSeed := LWorld.FAppearanceSeed;
      FHasAppearance := True;
      FSun.Color := Vector3(FAppearance.FSun.FR, FAppearance.FSun.FG, FAppearance.FSun.FB);
      FFog.Color := Vector3(FAppearance.FSky.FR, FAppearance.FSky.FG, FAppearance.FSky.FB);
      FViewport.Background.SkyEquatorColor := FFog.Color;
      FViewport.Background.GroundEquatorColor := FFog.Color;
      for I := 0 to FTemplates.Count - 1 do
      begin
        if Pos('raw:', FTemplates[I]) = 1 then
        begin
          ApplyWorldSurface(TCastleScene(FTemplates.Objects[I]), FAppearance);
        end
        else if FTemplates[I] = 'cabin' then
        begin
          UpdateCabinAppearance(TCastleTransform(FTemplates.Objects[I]), FAppearance);
        end;
      end;
      FCatalog.ApplyAppearance(FAppearance);
      // Unicode arguments avoid the pinned JOB bridge's unaligned inline UTF-8 payload.
      FBrowser.InvokeJSNoResult('phanesAppearanceReady', [UnicodeString(FAppearance.FPalette),
        UnicodeString(FAppearance.FKey), UnicodeString(FAppearance.FAtmosphere),
        UnicodeString(FAppearance.FFinish), FAppearanceSeed]);
    end;
    for I := 0 to 4 do
    begin
      SetLength(LWorld.FLayers[I], TJSONArray(LData.Arrays['layers'][I]).Count);
      for J := 0 to High(LWorld.FLayers[I]) do
      begin
        LWorld.FLayers[I][J] := TJSONArray(LData.Arrays['layers'][I]).Strings[J];
      end;
    end;
    FCatalog.SetWorld(LWorld);
    FLandscape.SetWorld(LWorld);
    FModular.Apply(LWorld, FAppearance);
    if (FSize <> LWorld.FSize) or (FWorldRoot = nil) then
    begin
      FreeAndNil(FWorldRoot);
      FChunks := nil;
      FSize := LWorld.FSize;
      FChunkSide := (FSize + WorldChunkCells - 1) div WorldChunkCells;
      SetLength(FChunks, FChunkSide * FChunkSide);
      FWorldRoot := TCastleTransform.Create(FreeAtStop);
      FViewport.Items.Add(FWorldRoot);
      LWater := TCastleBox.Create(FWorldRoot);
      LWater.Size := Vector3(FSize * WorldCellMetres + 160, 0.4,
        FSize * WorldCellMetres + 160);
      LWater.Translation := Vector3(0, WorldWaterMetres - 0.2, 0);
      LWater.Color := Vector4(0.035, 0.22, 0.25, 1);
      LWater.Material := pmPhysical;
      FWorldRoot.Add(LWater);
    end;
    for I := 0 to High(FChunks) do
    begin
      FChunks[I].FWantedSignature := IntToStr(FAppearanceSeed) + ':' +
        FLandscape.ChunkSignature(I mod FChunkSide, I div FChunkSide);
    end;
    { Indoor coordinates belong to the active room. Republishing an object edit
      must not move that player using exterior terrain or building collisions. }
    if (FMode = 'walk') and (FInterior = nil) then
    begin
      if not FLandscape.FindStanding(FWalkX, FWalkZ) then
      begin
        FBrowser.InvokeJSNoResult('phanesNavigationBlocked', []);
      end;
    end;
    FRenderPending := True;
    ApplyInterior;
  finally
    LData.Free;
  end;
end;

procedure TMainView.ApplyInterior;
var
  LSettings: TJSONObject;
  LRoomId: String;
  LSelectedId: String;
  LFrame: Integer;
  LBounds: TBox3D;
  LCenter: TVector3;
  LFillGain: Single;
  I: Integer;
begin
  if FLandscape.World.FSize = 0 then
  begin
    Exit;
  end;
  LSettings := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesInterior')));
  try
    LRoomId := LSettings.Get('roomId', '');
    if (LRoomId <> FInteriorId) or
      (FInteriorSceneVersion <> FSceneVersion) then
    begin
      FreeAndNil(FInterior);
      if LRoomId <> FInteriorId then
      begin
        FWalkX := 0;
        FWalkZ := 3.8;
        FMode := '';
      end;
      FInteriorId := LRoomId;
      FInteriorSceneVersion := FSceneVersion;
      if LRoomId <> '' then
      begin
        FInterior := TInteriorScene.CreateInterior(FreeAtStop, FreeAtStop,
          FTemplates, RawAsset, FLandscape.World.FComposition, LRoomId);
        FViewport.Items.Add(FInterior);
        FInterior.SetWalkView(FMode = 'walk');
      end;
    end;
    FWorldRoot.Exists := FInterior = nil;
    FModular.Exists := FInterior = nil;
    { The roof blocks direct sunlight in enclosed portal rooms. Approximate
      their otherwise missing indirect bounce with the same four stationary
      fill directions. The gain is constant across room camera modes, uses no
      additional light or shadow pass, and returns to the exterior value on exit. }
    LFillGain := 1;
    if FInterior <> nil then
    begin
      LFillGain := 2.4;
    end;
    for I := Low(FFillLights) to High(FFillLights) do
    begin
      FFillLights[I].Intensity := CFillIntensities[I] * LFillGain;
    end;
    if FSelectionRoot <> nil then
    begin
      FSelectionRoot.Exists := FInterior = nil;
    end;
    if FInterior <> nil then
    begin
      LSelectedId := LSettings.Get('selectedId', LRoomId);
      FInterior.Select(LSelectedId);
      LFrame := LSettings.Get('frameVersion', 0);
      if LFrame <> FInteriorFrameVersion then
      begin
        FInteriorFrameVersion := LFrame;
        LBounds := FInterior.BoundsFor(LSelectedId);
        if not LBounds.IsEmpty then
        begin
          LCenter := LBounds.Center;
          FBrowser.InvokeJSNoResult('phanesInteriorFrame', [LCenter.X, LCenter.Y,
            LCenter.Z, Max(0.16, Max(LBounds.SizeX, Max(LBounds.SizeY, LBounds.SizeZ)))]);
        end;
      end;
    end;
  finally
    LSettings.Free;
  end;
end;

procedure TMainView.BuildChunk(const AIndex: Integer);
var
  LRoot: TCastleTransform;
  LTerrain: TCastleScene;
  LReference: TCastleTransformReference;
  LDefinition: TJSONObject;
  LTemplate: TCastleTransform;
  LValue: String;
  LWorld: TWorld;
  LGroundwork: TGroundworkAssembly;
  LBuilding: TGroundworkPart;
  LBuildingProfile: TSupportedBuilding;
  LScale: Single;
  LX: Single;
  LZ: Single;
  LStart: QWord;
  LIndex: Integer;
  LSide: Integer;
  LMultiplier: Integer;
  LPitch: Integer;
  LCount: Integer;
  LFoliage: array of TStaticFoliageBatch;
  LFoliageScene: TCastleScene;
  LBatched: Boolean;
  LBatchIndex: Integer;
  LX0: Integer;
  LZ0: Integer;
  LLayerIndex: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LStart := GetTickCount64;
  LWorld := FLandscape.World;
  LRoot := TCastleTransform.Create(FWorldRoot);
  LFoliage := nil;
  try
    try
      LTerrain := BuildTerrain(LRoot, FLandscape, AIndex mod FChunkSide,
        AIndex div FChunkSide, FChunks[AIndex].FWantedDetail);
      ApplyWorldSurface(LTerrain, FAppearance);
      LRoot.Add(LTerrain);
      // Coarse distant chunks retain terrain. Nearby chunks own real model placements.
      if FChunks[AIndex].FWantedDetail then
      begin
        for I := 0 to FLandscape.GroundworkCount - 1 do
        begin
          LGroundwork := FLandscape.Groundwork(I);
          if (LGroundwork.FGeometry.FCellX div WorldChunkCells = AIndex mod FChunkSide) and
            (LGroundwork.FGeometry.FCellZ div WorldChunkCells = AIndex div FChunkSide) then
          begin
            LRoot.Add(CreateGroundworkScene(LRoot, LGroundwork, FAppearance, FLandscape.Elevation));
            if LGroundwork.FBuildingAsset <> '' then
            begin
              LTemplate := Asset(LGroundwork.FBuildingAsset);
              LBuilding := TGroundworkPart.Create(LRoot);
              LBuilding.FObjectId := LGroundwork.FId + '.deck.building';
              LRoot.Add(LBuilding);
              LReference := TCastleTransformReference.Create(LBuilding);
              LReference.ReferenceTransformation := rtDoNotIgnore;
              LReference.Reference := LTemplate;
              if not SupportedBuilding(LGroundwork.FBuildingAsset, LBuildingProfile) then
              begin
                raise Exception.Create('Missing admitted building profile.');
              end;
              LReference.Translation := Vector3(LGroundwork.FGeometry.FX / 1000,
                LGroundwork.FGeometry.FDeckY / 1000, LGroundwork.FGeometry.FZ / 1000);
              LReference.Rotation := Vector4(0, 1, 0,
                LGroundwork.FGeometry.FQuarterTurn * Pi / 2 +
                DegToRad(LBuildingProfile.FModelYawDegrees));
              LBuilding.Add(LReference);
            end;
          end;
        end;
        for LLayerIndex := 3 to 4 do
        begin
          LMultiplier := 1;
          if LLayerIndex = 4 then
          begin
            LMultiplier := 2;
          end;
          LSide := FSize * LMultiplier;
          LPitch := Round(WorldCellMetres) div LMultiplier;
          LX0 := (AIndex mod FChunkSide) * WorldChunkCells * LMultiplier;
          LZ0 := (AIndex div FChunkSide) * WorldChunkCells * LMultiplier;
          for J := LZ0 to Min(LSide - 1, LZ0 + WorldChunkCells * LMultiplier - 1) do
          begin
            for I := LX0 to Min(LSide - 1, LX0 + WorldChunkCells * LMultiplier - 1) do
            begin
              LIndex := J * LSide + I;
              LValue := LWorld.FLayers[LLayerIndex][LIndex];
              if LValue = 'empty' then
              begin
                Continue;
              end;
              LTemplate := Asset(LValue);
              LDefinition := Definition(LValue);
              LCount := LDefinition.Get('cluster', 1);
              for K := 0 to LCount - 1 do
              begin
                LX := (I + 0.5 - LSide / 2) * LPitch;
                LZ := (J + 0.5 - LSide / 2) * LPitch;
                if LCount > 1 then
                begin
                  LX := LX + (K mod 3 - 1) * 1.6 + Sin(LIndex + K * 7) * 0.4;
                  LZ := LZ + (K div 3 - 1) * 1.6 + Cos(LIndex * 3 + K) * 0.4;
                end;
                if (LLayerIndex = 4) and FLandscape.Modular.ClearsVegetation(LX, LZ, 4) then
                begin
                  Continue;
                end;
                LReference := TCastleTransformReference.Create(LRoot);
                LReference.ReferenceTransformation := rtDoNotIgnore;
                LReference.Reference := LTemplate;
                LScale := 1;
                if LLayerIndex = 4 then
                begin
                  LScale := VegetationScale(LIndex, K);
                end;
                LReference.Scale := Vector3(LScale, LScale, LScale);
                LReference.Translation := Vector3(LX, FLandscape.Height(LX, LZ), LZ);
                LReference.Rotation := Vector4(0, 1, 0, PlacementQuarterTurn(LIndex, K) * Pi / 2);
                LBatched := False;
                if LLayerIndex = 4 then
                begin
                  for LBatchIndex := 0 to High(LFoliage) do
                  begin
                    if LFoliage[LBatchIndex].Add(LReference) then
                    begin
                      LBatched := True;
                      Break;
                    end;
                  end;
                  if not LBatched then
                  begin
                    LBatchIndex := Length(LFoliage);
                    SetLength(LFoliage, LBatchIndex + 1);
                    LFoliage[LBatchIndex] := TStaticFoliageBatch.Create;
                    LBatched := LFoliage[LBatchIndex].Add(LReference);
                    if not LBatched then
                    begin
                      LFoliage[LBatchIndex].Free;
                      SetLength(LFoliage, LBatchIndex);
                    end;
                  end;
                end;
                if LBatched then
                begin
                  LReference.Free;
                end
                else
                begin
                  LRoot.Add(LReference);
                end;
              end;
            end;
          end;
        end;
      end;
      for LBatchIndex := 0 to High(LFoliage) do
      begin
        LFoliageScene := LFoliage[LBatchIndex].Finish(LRoot, FAppearance);
        if LFoliageScene <> nil then
        begin
          LRoot.Add(LFoliageScene);
        end;
      end;
      // Replace only this chunk after its new geometry is ready.
      FreeAndNil(FChunks[AIndex].FRoot);
      FWorldRoot.Add(LRoot);
      FChunks[AIndex].FRoot := LRoot;
      FChunks[AIndex].FSignature := FChunks[AIndex].FWantedSignature;
      FChunks[AIndex].FDetail := FChunks[AIndex].FWantedDetail;
      FGroundworkSelectionDirty := True;
    except
      LRoot.Free;
      raise;
    end;
  finally
    for LBatchIndex := 0 to High(LFoliage) do
    begin
      LFoliage[LBatchIndex].Free;
    end;
  end;
  Inc(FChunkBuilds);
  FMaxChunkMs := Max(FMaxChunkMs, GetTickCount64 - LStart);
end;

procedure TMainView.StreamChunks;
var
  LCenterX: Integer;
  LCenterZ: Integer;
  LChosen: Integer;
  LDistance: Integer;
  LBest: Integer;
  LResident: Integer;
  LPending: Integer;
  I: Integer;
begin
  if Length(FChunks) = 0 then
  begin
    Exit;
  end;
  LCenterX := EnsureRange(Floor((FFocusX + FSize * 8) / 64), 0, FChunkSide - 1);
  LCenterZ := EnsureRange(Floor((FFocusZ + FSize * 8) / 64), 0, FChunkSide - 1);
  LChosen := -1;
  LBest := MaxInt;
  LResident := 0;
  LPending := 0;
  for I := 0 to High(FChunks) do
  begin
    FChunks[I].FWantedDetail := (Abs(I mod FChunkSide - LCenterX) <= 1) and
      (Abs(I div FChunkSide - LCenterZ) <= 1);
    if FChunks[I].FDetail then
    begin
      Inc(LResident);
    end;
    if (FChunks[I].FSignature <> FChunks[I].FWantedSignature) or
      (FChunks[I].FDetail <> FChunks[I].FWantedDetail) then
    begin
      Inc(LPending);
      LDistance := Abs(I mod FChunkSide - LCenterX) + Abs(I div FChunkSide - LCenterZ);
      // Evict old detailed placements before admitting new ones: at most nine residents.
      if FChunks[I].FDetail and not FChunks[I].FWantedDetail then
      begin
        LDistance := -1;
      end;
      if LDistance < LBest then
      begin
        LBest := LDistance;
        LChosen := I;
      end;
    end;
  end;
  if LChosen >= 0 then
  begin
    BuildChunk(LChosen);
  end;
  if (FReportedResident <> LResident) or (FReportedPending <> LPending) or
    (FReportedBuilds <> FChunkBuilds) then
  begin
    FReportedResident := LResident;
    FReportedPending := LPending;
    FReportedBuilds := FChunkBuilds;
    FBrowser.InvokeJSNoResult('phanesRenderMetrics', [Length(FChunks), LResident,
      LPending, FChunkBuilds, FMaxChunkMs, FViewport.ScreenSpaceAmbientOcclusion]);
  end;
end;

procedure TMainView.UpdateWalk(const ASeconds: Single);
var
  LInput: TJSONObject;
  LInputText: String;
  LForward: Double;
  LStrafe: Double;
  LYaw: Double;
  LPitch: Double;
  LSpeed: Double;
  LLength: Double;
  LPosition: TVector3;
  LDirection: TVector3;
  LDX: Double;
  LDZ: Double;
  LSteps: Integer;
  I: Integer;
begin
  if (FMode <> 'walk') or (FLandscape.World.FSize = 0) then
  begin
    Exit;
  end;
  LInputText := FBrowser.ReadJSPropertyUtf8String('phanesMoveInput');
  if (LInputText = FLastWalkInput) and FWalkIdle then
  begin
    Exit;
  end;
  FLastWalkInput := LInputText;
  LInput := TJSONObject(GetJSON(LInputText));
  try
    LForward := LInput.Get('forward', 0.0);
    LStrafe := LInput.Get('strafe', 0.0);
    FWalkIdle := (LForward = 0) and (LStrafe = 0);
    LYaw := LInput.Get('yaw', 0.0);
    LPitch := LInput.Get('pitch', 0.0);
    LLength := Max(1, Sqrt(Sqr(LForward) + Sqr(LStrafe)));
    LSpeed := PlayerWalkMetresPerSecond;
    if LInput.Get('run', False) then
    begin
      LSpeed := PlayerRunMetresPerSecond;
    end;
    LSpeed := LSpeed * Min(0.05, ASeconds) / LLength;
    LDX := (Sin(LYaw) * LForward + Cos(LYaw) * LStrafe) * LSpeed;
    LDZ := (-Cos(LYaw) * LForward + Sin(LYaw) * LStrafe) * LSpeed;
    if FInterior <> nil then
    begin
      LSteps := Max(1, Ceil(Sqrt(Sqr(LDX) + Sqr(LDZ)) / 0.1));
      for I := 1 to LSteps do
      begin
        if FInterior.CanStand(FWalkX + LDX / LSteps, FWalkZ) then
        begin
          FWalkX := FWalkX + LDX / LSteps;
        end;
        if FInterior.CanStand(FWalkX, FWalkZ + LDZ / LSteps) then
        begin
          FWalkZ := FWalkZ + LDZ / LSteps;
        end;
      end;
      LPosition := Vector3(FWalkX, PlayerEyeMetres, FWalkZ);
    end
    else
    begin
      FLandscape.Move(FWalkX, FWalkZ, LDX, LDZ);
      LPosition := Vector3(FWalkX, FLandscape.Height(FWalkX, FWalkZ) + PlayerEyeMetres, FWalkZ);
    end;
    LDirection := Vector3(Sin(LYaw) * Cos(LPitch), Sin(LPitch), -Cos(LYaw) * Cos(LPitch));
    FViewport.Camera.SetWorldView(LPosition, LDirection, Vector3(0, 1, 0));
    FFocusX := FWalkX;
    FFocusZ := FWalkZ;
    FBrowser.InvokeJSNoResult('phanesPlayerPosition', [FWalkX, LPosition.Y, FWalkZ,
      LPosition.Y - PlayerEyeMetres]);
  finally
    LInput.Free;
  end;
end;

function TMainView.PickGroundwork(const AOrigin, ADirection: TVector3;
  out APoint: TVector3; out ATerrain: Boolean): String;
var
  LCollision: TRayCollision;
  LAssembly: TGroundworkAssembly;
  LU: Double;
  LV: Double;
  I: Integer;
begin
  Result := '';
  ATerrain := False;
  LCollision := VisibleRayCollision(FWorldRoot, AOrigin, ADirection);
  if LCollision = nil then
  begin
    Exit;
  end;
  try
    APoint := AOrigin + ADirection.Normalize * LCollision.Distance;
    for I := 0 to LCollision.Count - 1 do
    begin
      if LCollision[I].Item is TGroundworkPart then
      begin
        Exit(TGroundworkPart(LCollision[I].Item).FObjectId);
      end;
    end;
    ATerrain := LCollision[0].Item is TWorldTerrainScene;
    if not ATerrain then
    begin
      Exit;
    end;
    { The graded landing is actual terrain, not a floating surrogate plane.
      Classify only a nearest terrain hit; nearer buildings still occlude it. }
    for I := 0 to FLandscape.GroundworkCount - 1 do
    begin
      LAssembly := FLandscape.Groundwork(I);
      GroundworkToLocal(LAssembly.FGeometry, APoint.X, APoint.Z, LU, LV);
      if (Abs(LU) <= 1) and (LV >= 14) and (LV <= 16) then
      begin
        Exit(LAssembly.FId + '.deck.ramp.landing');
      end;
    end;
  finally
    LCollision.Free;
  end;
end;

procedure TMainView.ApplyGroundworkSelection;
var
  LSettings: TJSONObject;
  LBounds: TBox3D;
  LAssembly: TGroundworkAssembly;
  LPoint: TVector3;
  LX: Double;
  LZ: Double;
  LFrame: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  FreeAndNil(FGroundworkOutline);
  FGroundworkSelectedId := '';
  FGroundworkStroke := 0;
  FGroundworkSelectionDirty := False;
  FGroundworkRenderedVersion := -1;
  LSettings := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesGroundworkSelection')));
  try
    if (FInterior <> nil) or not LSettings.Get('visible', False) then
    begin
      Exit;
    end;
    FGroundworkSelectedId := LSettings.Get('selectedId', '');
    LBounds := GroundworkBounds(FWorldRoot, FGroundworkSelectedId);
    for I := 0 to FLandscape.GroundworkCount - 1 do
    begin
      LAssembly := FLandscape.Groundwork(I);
      if (FGroundworkSelectedId = LAssembly.FId + '.deck') and not LBounds.IsEmpty then
      begin
        LPoint := Vector3(LAssembly.FGeometry.FX / 1000,
          LAssembly.FGeometry.FDeckY / 1000, LAssembly.FGeometry.FZ / 1000);
        LBounds := TBox3D.Empty;
        LBounds.Include(LPoint + Vector3(-8, -GroundworkSlabMetres, -8));
        LBounds.Include(LPoint + Vector3(8, 0, 8));
      end
      else if FGroundworkSelectedId = LAssembly.FId + '.deck.ramp.landing' then
      begin
        LBounds := TBox3D.Empty;
        { These are the actual 0.125 m landing mesh vertices. Four corners
          miss interior extrema of the curved grading profile. }
        for J := 0 to 16 do
        begin
          for K := 0 to 16 do
          begin
            GroundworkToWorld(LAssembly.FGeometry, J * 0.125 - 1, 14 + K * 0.125, LX, LZ);
            LBounds.Include(Vector3(LX,
              GroundworkSurfaceHeight(LAssembly.FGeometry, LX, LZ, FLandscape.Elevation), LZ));
          end;
        end;
      end;
    end;
    FGroundworkOutline := CreateGroundworkOutline(FreeAtStop, LBounds);
    FGroundworkBounds := LBounds;
    if FGroundworkOutline <> nil then
    begin
      FViewport.Items.Add(FGroundworkOutline);
      LFrame := LSettings.Get('frameVersion', 0);
      if LFrame <> FGroundworkFrameVersion then
      begin
        FGroundworkFrameVersion := LFrame;
        if LSettings.Get('frameId', '') = FGroundworkSelectedId then
        begin
          LPoint := LBounds.Center;
          FBrowser.InvokeJSNoResult('phanesGroundworkFrame', [UnicodeString(FGroundworkSelectedId),
            LPoint.X, LPoint.Y, LPoint.Z, Max(LBounds.SizeX, Max(LBounds.SizeY, LBounds.SizeZ))]);
        end;
      end;
    end
    else
    begin
      FGroundworkSelectedId := '';
    end;
  finally
    LSettings.Free;
  end;
end;

function TMainView.SelectionMetresPerPixel(const ABounds: TBox3D): Single;
var
  LPosition: TVector3;
  LDirection: TVector3;
  LUp: TVector3;
  LHeight: Single;
begin
  LHeight := Max(1, FBrowser.ReadJSPropertyDouble('phanesViewportCssHeight'));
  if FViewport.Camera.ProjectionType = ptOrthographic then
  begin
    Result := FViewport.Camera.Orthographic.Height / LHeight;
  end
  else
  begin
    FViewport.Camera.GetView(LPosition, LDirection, LUp);
    Result := 2 * Max(0.1,
      TVector3.DotProduct(ABounds.Center - LPosition, LDirection)) *
      Tan(FViewport.Camera.Perspective.EffectiveFieldOfView.Y / 2) / LHeight;
  end;
end;

procedure TMainView.UpdateInteriorStroke;
begin
  if (FInterior <> nil) and not FInterior.SelectionBounds.IsEmpty then
  begin
    FInterior.UpdateSelectionStroke(SelectionMetresPerPixel(FInterior.SelectionBounds) * 2.0);
  end;
end;

procedure TMainView.UpdateGroundworkStroke;
var
  LStroke: Single;
begin
  if FGroundworkOutline = nil then
  begin
    Exit;
  end;
  { Keep selection feedback about 2.25 CSS pixels wide, independent of DPI.
    Reuse the twelve edges while moving the camera; small width changes need
    no scene reconstruction. Padding keeps their strokes outside the model. }
  LStroke := Max(0.025, SelectionMetresPerPixel(FGroundworkBounds) * 2.25);
  if Abs(LStroke - FGroundworkStroke) > Max(0.0001, FGroundworkStroke * 0.04) then
  begin
    FGroundworkStroke := LStroke;
    ResizeGroundworkOutline(FGroundworkOutline, FGroundworkBounds, LStroke);
  end;
end;

function TMainView.PickTerrain(const AOrigin, ADirection: TVector3; out APoint: TVector3): Boolean;
var
  LDistance: Double;
  LLow: Double;
  LHigh: Double;
  LStep: Double;
  LEnter: Double;
  LExit: Double;
  LNear: Double;
  LFar: Double;
  LSwap: Double;
  LHalf: Double;
  LAxis: Integer;
  I: Integer;
begin
  Result := False;
  { Clip the complete marching/refinement interval to the stored XZ field.
    An outside ray entering below the surface must never bisect outside it. }
  LEnter := 0;
  LExit := 2400;
  LHalf := FLandscape.World.FSize * 8;
  for LAxis := 0 to 2 do
  begin
    if LAxis = 1 then
    begin
      Continue;
    end;
    if Abs(ADirection[LAxis]) < 0.0000001 then
    begin
      if (AOrigin[LAxis] < -LHalf) or (AOrigin[LAxis] > LHalf) then
      begin
        Exit;
      end;
      Continue;
    end;
    LNear := (-LHalf - AOrigin[LAxis]) / ADirection[LAxis];
    LFar := (LHalf - AOrigin[LAxis]) / ADirection[LAxis];
    if LNear > LFar then
    begin
      LSwap := LNear;
      LNear := LFar;
      LFar := LSwap;
    end;
    LEnter := Max(LEnter, LNear);
    LExit := Min(LExit, LFar);
  end;
  if LEnter > LExit then
  begin
    Exit;
  end;
  LDistance := LEnter;
  LStep := 1;
  while LDistance <= LExit do
  begin
    APoint := AOrigin + ADirection * LDistance;
    APoint.X := EnsureRange(APoint.X, -LHalf, LHalf);
    APoint.Z := EnsureRange(APoint.Z, -LHalf, LHalf);
    if (FLandscape.Cell(APoint.X, APoint.Z) >= 0) and
      (APoint.Y <= Max(WorldWaterMetres, FLandscape.Height(APoint.X, APoint.Z))) then
    begin
      LLow := Max(LEnter, LDistance - LStep);
      LHigh := LDistance;
      for I := 0 to 15 do
      begin
        LDistance := (LLow + LHigh) / 2;
        APoint := AOrigin + ADirection * LDistance;
        APoint.X := EnsureRange(APoint.X, -LHalf, LHalf);
        APoint.Z := EnsureRange(APoint.Z, -LHalf, LHalf);
        if APoint.Y > Max(WorldWaterMetres, FLandscape.Height(APoint.X, APoint.Z)) then
        begin
          LLow := LDistance;
        end
        else
        begin
          LHigh := LDistance;
        end;
      end;
      Exit(True);
    end;
    LDistance := LDistance + LStep;
  end;
end;

procedure TMainView.ApplySelection;
var
  LSelection: TJSONObject;
begin
  FreeAndNil(FSelectionRoot);
  FSelectionRoot := TCastleTransform.Create(FreeAtStop);
  FSelectionRoot.Pickable := False;
  FSelectionRoot.Collides := False;
  FViewport.Items.Add(FSelectionRoot);
  LSelection := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesSelection')));
  try
    FSelectionMasked := LSelection.Find('selectionCells') <> nil;
    if LSelection.Get('visible', False) then
    begin
      FSelectionRoot.Add(CreateRegionOutline(FSelectionRoot, FLandscape, LSelection));
    end;
  finally
    LSelection.Free;
  end;
end;
procedure TMainView.ApplyCamera;
var
  LCamera: TJSONObject;
  LNewMode: String;
  LPosition: TVector3;
  LTarget: TVector3;
  LUp: TVector3;
begin
  FLastWalkInput := '';
  LCamera := TJSONObject(GetJSON(FBrowser.ReadJSPropertyUtf8String('phanesCamera')));
  try
    LNewMode := LCamera.Get('mode', 'top');
    FViewport.Camera.Perspective.FieldOfViewAxis := faSmallest;
    FViewport.Camera.Perspective.FieldOfView := Pi / 4;
    if LNewMode = 'walk' then
    begin
      { Bound the larger axis: 70 degrees on the smaller portrait axis expands
        past 110 vertically, stretching nearby ceilings and floors. The engine
        recalculates the other axis on resize; Orbit keeps its framing contract. }
      FViewport.Camera.Perspective.FieldOfViewAxis := faLargest;
      FViewport.Camera.Perspective.FieldOfView := DegToRad(95);
    end;
    FFocusX := LCamera.Get('focusX', 0.0);
    FFocusZ := LCamera.Get('focusZ', 0.0);
    FFog.VisibilityRange := 280;
    if (LNewMode = 'top') or (LNewMode = 'orbit') then
    begin
      FFog.VisibilityRange := FSize * WorldCellMetres * 8;
    end;
    if LCamera.Booleans['orthographic'] then
    begin
      FViewport.Camera.ProjectionType := ptOrthographic;
      FViewport.Camera.Orthographic.Height := LCamera.Floats['span'];
      FViewport.Camera.Orthographic.Width := 0;
      FViewport.Camera.Orthographic.Origin := Vector2(0.5, 0.5);
    end
    else
    begin
      FViewport.Camera.ProjectionType := ptPerspective;
    end;
    LPosition := Vector3(LCamera.Arrays['position'].Floats[0],
      LCamera.Arrays['position'].Floats[1], LCamera.Arrays['position'].Floats[2]);
    LTarget := Vector3(LCamera.Arrays['target'].Floats[0],
      LCamera.Arrays['target'].Floats[1], LCamera.Arrays['target'].Floats[2]);
    LUp := Vector3(LCamera.Arrays['up'].Floats[0],
      LCamera.Arrays['up'].Floats[1], LCamera.Arrays['up'].Floats[2]);
    if (LNewMode = 'walk') and (FMode <> 'walk') then
    begin
      FWalkX := LPosition.X;
      FWalkZ := LPosition.Z;
      if FInterior <> nil then
      begin
        if FInterior.FindStanding(FWalkX, FWalkZ) then
        begin
          LTarget := LTarget + Vector3(FWalkX, PlayerEyeMetres, FWalkZ) - LPosition;
          LPosition := Vector3(FWalkX, PlayerEyeMetres, FWalkZ);
        end
        else
        begin
          FBrowser.InvokeJSNoResult('phanesInteriorNavigationBlocked', []);
          LNewMode := 'fly';
        end;
      end
      else if (FLandscape.World.FSize > 0) and not FLandscape.FindStanding(FWalkX, FWalkZ) then
      begin
        FBrowser.InvokeJSNoResult('phanesNavigationBlocked', []);
        LNewMode := 'fly';
      end;
    end;
    FMode := LNewMode;
    if FInterior <> nil then
    begin
      FInterior.SetWalkView(FMode = 'walk');
    end;
    FViewport.Camera.SetWorldView(LPosition, LTarget - LPosition, LUp);
  finally
    LCamera.Free;
  end;
end;

procedure TMainView.Update(const ASecondsPassed: Single; var AHandleInput: Boolean);
var
  LVersion: Integer;
  LPoint: TVector3;
  LOrigin: TVector3;
  LDirection: TVector3;
  LScreenPoint: TVector2;
  LObjectId: String;
  LTerrainHit: Boolean;
  LCollision: TRayCollision;
  LModularPoint: TVector3;
  LSelected: String;
  LBounds: TBox3D;
  LModularStroke: Single;
  LModularCenter: TVector3;
begin
  { Covered views may still prepare a candidate. Suspension, including graphics
    loss, stops preparation until the session has a usable context again. }
  if not FBrowser.ReadJSPropertyBoolean('phanesWorldSuspended') then
  begin
    FCatalog.StagePending(FAppearance);
  end;
  FViewport.Exists := not FBrowser.ReadJSPropertyBoolean('phanesWorldCovered') and
    not FBrowser.ReadJSPropertyBoolean('phanesWorldSuspended');
  if not FViewport.Exists then
  begin
    Exit;
  end;
  inherited;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesStyleRevision');
  FStyles.UpdateDensity(FViewport.RenderRect.Height /
    Max(1, FBrowser.ReadJSPropertyDouble('phanesViewportCssHeight')));
  if (LVersion > 0) and (LVersion <> FStyleVersion) then
  begin
    FStyleVersion := LVersion;
    ApplyStyle;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesSceneVersion');
  if (LVersion > 0) and (LVersion <> FSceneVersion) then
  begin
    FSceneVersion := LVersion;
    ApplyWorld;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesInteriorVersion');
  if LVersion <> FInteriorVersion then
  begin
    FInteriorVersion := LVersion;
    ApplyInterior;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesCameraVersion');
  if LVersion <> FCameraVersion then
  begin
    FCameraVersion := LVersion;
    ApplyCamera;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesSelectionVersion');
  if LVersion <> FSelectionVersion then
  begin
    FSelectionVersion := LVersion;
    ApplySelection;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesPickVersion');
  if (LVersion <> FPickVersion) and
    (FBrowser.ReadJSPropertyUtf8String('phanesPickAction') <> '') and
    (FBrowser.ReadJSPropertyLongInt('phanesPickSceneVersion') = FSceneVersion) and
    (FBrowser.ReadJSPropertyLongInt('phanesPickCameraVersion') = FCameraVersion) then
  begin
    FPickVersion := LVersion;
    LScreenPoint := Vector2(
      FBrowser.ReadJSPropertyDouble('phanesPickX') * FViewport.EffectiveWidth,
      (1 - FBrowser.ReadJSPropertyDouble('phanesPickY')) * FViewport.EffectiveHeight);
    FViewport.PositionToRay(LScreenPoint, False, LOrigin, LDirection);
    { Picking starts on the same near plane as rendering. Starting at the eye
      lets invisible clipped geometry intercept a close-up. The plane query
      also handles off-centre perspective and parallel orthographic rays. }
    if FViewport.PositionToCameraPlane(LScreenPoint, False,
      FViewport.Camera.ProjectionNear, LPoint) then
    begin
      LOrigin := LPoint;
    end;
    if (FBrowser.ReadJSPropertyUtf8String('phanesPickAction') = 'authoring') or
      (FBrowser.ReadJSPropertyUtf8String('phanesPickAction') = 'authoring-point') then
    begin
      LObjectId := '';
      if not FRenderPending and
        (FBrowser.ReadJSPropertyUtf8String('phanesPickAction') = 'authoring-point') then
      begin
        LObjectId := PickGroundwork(LOrigin, LDirection, LPoint, LTerrainHit);
      end;
      if LObjectId <> '' then
      begin
        FBrowser.InvokeJSNoResult('phanesGroundworkPicked',
          [UnicodeString(LObjectId), LVersion]);
      end
      else if not FRenderPending and PickTerrain(LOrigin, LDirection, LPoint) then
      begin
        FBrowser.InvokeJSNoResult('phanesAuthoringPicked',
          [LPoint.X, LPoint.Z, LVersion, True]);
      end else
      begin
        FBrowser.InvokeJSNoResult('phanesAuthoringPicked', [0, 0, LVersion, False]);
      end;
    end
    else if FInterior <> nil then
    begin
      LObjectId := FInterior.Pick(LOrigin, LDirection);
      FBrowser.InvokeJSNoResult('phanesInteriorPicked', [UnicodeString(LObjectId), LVersion]);
    end
    else if FBrowser.ReadJSPropertyBoolean('phanesModularPicking') and not FRenderPending then
    begin
      LObjectId := FModular.Pick(LOrigin, LDirection, LModularPoint);
      if LObjectId <> '' then
      begin
        LCollision := VisibleRayCollision(FWorldRoot, LOrigin, LDirection);
        try
          if (LCollision <> nil) and
            (LCollision.Distance + 0.002 < (LModularPoint - LOrigin).Length) then
          begin
            LObjectId := '';
          end;
        finally
          LCollision.Free;
        end;
      end;
      FBrowser.InvokeJSNoResult('phanesModularPicked', [UnicodeString(LObjectId), LVersion]);
    end
    else if (FBrowser.ReadJSPropertyUtf8String('phanesPickAction') <> '') and
      not FRenderPending and
      (FBrowser.ReadJSPropertyLongInt('phanesPickSceneVersion') = FSceneVersion) and
      (FBrowser.ReadJSPropertyLongInt('phanesPickCameraVersion') = FCameraVersion) then
    begin
      LObjectId := '';
      LTerrainHit := False;
      if FBrowser.ReadJSPropertyUtf8String('phanesPickAction') = 'end' then
      begin
        LObjectId := PickGroundwork(LOrigin, LDirection, LPoint, LTerrainHit);
      end;
      if LObjectId <> '' then
      begin
        FBrowser.InvokeJSNoResult('phanesGroundworkPicked', [UnicodeString(LObjectId), LVersion]);
      end
      else if LTerrainHit then
      begin
        FBrowser.InvokeJSNoResult('phanesPicked', [LPoint.X, LPoint.Z, LVersion]);
      end
      else if ((FBrowser.ReadJSPropertyUtf8String('phanesPickAction') <> 'end') or
        not FBrowser.ReadJSPropertyBoolean('phanesGroundworkActive')) and
        PickTerrain(LOrigin, LDirection, LPoint) then
      begin
        FBrowser.InvokeJSNoResult('phanesPicked', [LPoint.X, LPoint.Z, LVersion]);
      end;
    end;
  end;
  UpdateWalk(ASecondsPassed);
  LSelected := FBrowser.ReadJSPropertyUtf8String('phanesModularSelected');
  FModular.View(FViewport.Camera.Translation,
    FBrowser.ReadJSPropertyBoolean('phanesModularCutaway'), LSelected);
  if (LSelected <> FModularSelected) or (FModularSceneSeen <> FSceneVersion) then
  begin
    FModularSceneSeen := FSceneVersion;
    FModularSelected := LSelected;
    FreeAndNil(FModularOutline);
    FModularStroke := 0;
    if (LSelected <> '') and (FInterior = nil) then
    begin
      LBounds := FModular.BoundsFor(LSelected);
      FModularBounds := LBounds;
      FModularOutline := CreateGroundworkOutline(FreeAtStop, LBounds);
      if FModularOutline <> nil then
      begin
        FViewport.Items.Add(FModularOutline);
      end;
    end;
  end;
  if FModularOutline <> nil then
  begin
    LModularStroke := Max(0.0005, SelectionMetresPerPixel(FModularBounds) * 2.25);
    if Abs(LModularStroke - FModularStroke) > Max(0.00005, FModularStroke * 0.04) then
    begin
      FModularStroke := LModularStroke;
      ResizeGroundworkOutline(FModularOutline, FModularBounds, LModularStroke, 0.0005);
    end;
  end;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesModularFrameVersion');
  if LVersion <> FModularFrameVersion then
  begin
    FModularFrameVersion := LVersion;
    LSelected := FBrowser.ReadJSPropertyUtf8String('phanesModularFrameTarget');
    LBounds := FModular.BoundsFor(LSelected);
    if not LBounds.IsEmpty then
    begin
      LModularCenter := LBounds.Center;
      FBrowser.InvokeJSNoResult('phanesModularFrame', [UnicodeString(LSelected),
        LModularCenter.X, LModularCenter.Y, LModularCenter.Z,
        Max(0.16, Max(LBounds.SizeX, Max(LBounds.SizeY, LBounds.SizeZ)))]);
    end;
  end;
  UpdateEntry;
  StreamChunks;
  LVersion := FBrowser.ReadJSPropertyLongInt('phanesGroundworkSelectionVersion');
  if (LVersion <> FGroundworkSelectionVersion) or FGroundworkSelectionDirty then
  begin
    FGroundworkSelectionVersion := LVersion;
    ApplyGroundworkSelection;
  end;
  UpdateGroundworkStroke;
  UpdateInteriorStroke;
end;

procedure TMainView.UpdateEntry;
var
  LProfile: TBuildingInterior;
  LWorld: TWorld;
  LPlayer: TVector3;
  LAssembly: TGroundworkAssembly;
  LCandidate: TJSONObject;
  LDistance: Double;
  LBest: Double;
  LX: Integer;
  LZ: Integer;
  I: Integer;
  J: Integer;
  procedure Consider(const AId: String; const AX, AY, AZ: Double;
    const ACellX, ACellZ: Integer; const ASupported: Boolean);
  begin
    LDistance := Sqr(LPlayer.X - AX) + Sqr(LPlayer.Z - AZ);
    if (LDistance < LBest) and (Abs(LPlayer.Y - AY - 1.68) < 2.5) then
    begin
      LBest := LDistance;
      LCandidate.Clear;
      LCandidate.Add('id', AId);
      LCandidate.Add('x', ACellX);
      LCandidate.Add('z', ACellZ);
      LCandidate.Add('supported', ASupported);
      LCandidate.Add('label', 'Enter house');
      if LProfile.FHasRoomPlans then
      begin
        LCandidate.Strings['label'] := 'Enter cabin';
      end;
    end;
  end;
begin
  LCandidate := TJSONObject.Create(['id', '']);
  try
    if (FWorldRoot <> nil) and (FInterior = nil) then
    begin
      LWorld := FLandscape.World;
      LPlayer := FViewport.Camera.Translation;
      LBest := Sqr(8);
      LX := Floor((LPlayer.X + LWorld.FSize * 8) / 16);
      LZ := Floor((LPlayer.Z + LWorld.FSize * 8) / 16);
      for I := Max(0, LX - 1) to Min(LWorld.FSize - 1, LX + 1) do
      begin
        for J := Max(0, LZ - 1) to Min(LWorld.FSize - 1, LZ + 1) do
        begin
          if BuildingInterior(LWorld.FLayers[3][J * LWorld.FSize + I], LProfile) then
          begin
            Consider('building-' + IntToStr(I) + '-' + IntToStr(J),
              (I + 0.5 - LWorld.FSize / 2) * 16, WorldBuildingDatum(LWorld, I, J),
              (J + 0.5 - LWorld.FSize / 2) * 16, I, J, False);
          end;
        end;
      end;
      for I := 0 to FLandscape.GroundworkCount - 1 do
      begin
        LAssembly := FLandscape.Groundwork(I);
        if BuildingInterior(LAssembly.FBuildingAsset, LProfile) then
        begin
          Consider(LAssembly.FId + '.deck.building', LAssembly.FGeometry.FX / 1000,
            LAssembly.FGeometry.FDeckY / 1000, LAssembly.FGeometry.FZ / 1000,
            LAssembly.FGeometry.FCellX, LAssembly.FGeometry.FCellZ, True);
        end;
      end;
    end;
    FBrowser.WriteJSPropertyUtf8String('phanesNearbyInterior', LCandidate.AsJSON);
  finally
    LCandidate.Free;
  end;
end;

procedure TMainView.RenderOverChildren;
var
  LStyleApplied: Boolean;
  LSelectionBounds: TBox3D;
begin
  if not FViewport.Exists then
  begin
    Exit;
  end;
  inherited;
  Inc(FRenderedFrames);
  FBrowser.WriteJSPropertyLongInt('phanesRenderedFrames', FRenderedFrames);
  if (FStyleIndex > 0) and (FStyleStrength > 0) and FStyles.ShaderValid and
    TPhanesViewport(FViewport).EffectsRendered then
  begin
    LSelectionBounds := TBox3D.Empty;
    if FInterior <> nil then
    begin
      LSelectionBounds := FInterior.SelectionBounds;
    end else if FGroundworkOutline <> nil then
    begin
      LSelectionBounds := FGroundworkBounds;
    end else if (FSelectionRoot <> nil) and FSelectionRoot.Exists and not FSelectionMasked then
    begin
      LSelectionBounds := FSelectionRoot.BoundingBox;
    end;
    DrawStyleSelection(FViewport, LSelectionBounds,
      FBrowser.ReadJSPropertyDouble('phanesViewportCssHeight'));
  end;
  if FStyleRenderedVersion <> FStyleVersion then
  begin
    LStyleApplied := FStyleValidRequest and ((FStyleIndex = 0) or (FStyleStrength = 0) or
      (FStyles.ShaderValid and TPhanesViewport(FViewport).EffectsRendered));
    FStyleRenderedVersion := FStyleVersion;
    FBrowser.WriteJSPropertyLongInt('phanesRenderedStyleRevision', FStyleVersion);
    FBrowser.WriteJSPropertyBoolean('phanesStylePassRendered',
      TPhanesViewport(FViewport).EffectsRendered);
    FBrowser.InvokeJSNoResult('phanesStyleRendered', [FStyleVersion, LStyleApplied]);
    if not LStyleApplied then
    begin
      FStyles.Apply(0, 1, 0.5, 1);
    end;
  end;
  { The viewport is a child. A view's Render runs before its children, so
    acknowledging there publishes the previous projection/frame. }
  if FRenderedCameraVersion <> FCameraVersion then
  begin
    FRenderedCameraVersion := FCameraVersion;
    FBrowser.WriteJSPropertyLongInt('phanesRenderedCameraVersion', FCameraVersion);
    FBrowser.WriteJSPropertyDouble('phanesRenderedHorizontalFov',
      FViewport.Camera.Perspective.EffectiveFieldOfView.X);
    FBrowser.WriteJSPropertyDouble('phanesRenderedVerticalFov',
      FViewport.Camera.Perspective.EffectiveFieldOfView.Y);
  end;
  if (FInteriorRenderedVersion <> FInteriorVersion) and
    ((FInteriorId = '') or (FInterior <> nil)) then
  begin
    FInteriorRenderedVersion := FInteriorVersion;
    FBrowser.InvokeJSNoResult('phanesInteriorRendered', [UnicodeString(FInteriorId),
      FInteriorVersion, FInteriorSceneVersion]);
  end;
  if FRenderPending and (FBrowser.ReadJSPropertyLongInt('phanesPendingChunks') = 0) then
  begin
    FRenderPending := False;
    FBrowser.InvokeJSNoResult('phanesWorldRendered', [FSceneVersion]);
  end;
  if not FRenderPending and
    (FBrowser.ReadJSPropertyLongInt('phanesSceneVersion') = FSceneVersion) and
    not FBrowser.ReadJSPropertyBoolean('phanesCatalogLoading') then
  begin
    FCatalog.Collect;
  end;
  if FGroundworkRenderedVersion <> FGroundworkSelectionVersion then
  begin
    FGroundworkRenderedVersion := FGroundworkSelectionVersion;
    FBrowser.WriteJSPropertyUtf8String('phanesRenderedGroundworkId', FGroundworkSelectedId);
    FBrowser.WriteJSPropertyLongInt('phanesRenderedGroundworkVersion', FGroundworkSelectionVersion);
  end;
  if not FReady then
  begin
    FReady := True;
    FBrowser.InvokeJSNoResult('phanesReady', []);
  end;
end;

end.
