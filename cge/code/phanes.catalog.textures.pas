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
unit phanes.catalog.textures;

{$mode delphi}
{$H+}

interface

uses
  Classes, CastleScene, X3DNodes;

type
  { Conservative texture-pixel claims captured before GPU preparation.
    Texture nodes, texture properties, and effective render filters must remain
    unchanged for the lifetime of this snapshot. This does not claim GPU bytes. }
  TCatalogTextureProfile = class
  private type
    TClaim = class
      FPixels: Int64;
    end;
  private
    FClaims: TStringList;
    FAssetId: String;
    FDeclaredPixels: Int64;
    FProfileId: QWord;
    FMeasuredPixels: Int64;
    FOpaque: Boolean;
    FScene: TCastleScene;
    procedure AddClaim(const AKey: String; const APixels: Int64);
    procedure InspectTexture(ANode: TX3DNode);
    procedure ReplaceWithOpaqueClaim;
  public
    constructor Create(const AScene: TCastleScene; const AAssetId: String;
      const ADeclaredPixels: Int64);
    destructor Destroy; override;
  end;

function CatalogTexturePixels(
  const AProfiles: array of TCatalogTextureProfile): Int64;

implementation

uses
  SysUtils, Math, FPJSON, CastleImages, CastleRenderOptions;

type
  TSceneAccess = class(TCastleScene)
  public
    function CurrentRenderOptions: TCastleRenderOptions;
  end;

var
  GNextTextureProfile: QWord;

function TSceneAccess.CurrentRenderOptions: TCastleRenderOptions;
begin
  Result := EffectiveRenderOptions;
end;

function SingleBitsHex(const AValue: Single): String;
var
  LBits: Cardinal;
begin
  if IsNan(AValue) or IsInfinite(AValue) then
  begin
    raise Exception.Create('Catalog texture anisotropy must be finite');
  end;
  Move(AValue, LBits, SizeOf(LBits));
  Result := IntToHex(LBits, 8);
end;

function ImageClaimKey(const ATexture: TImageTextureNode;
  const AWidth, AHeight: Int64;
  const ARenderOptions: TCastleRenderOptions): String;
var
  LJson: TJSONObject;
  LProperties: TTexturePropertiesNode;
begin
  LJson := TJSONObject.Create;
  try
    LJson.Add('kind', 'image');
    LJson.Add('url', ATexture.TextureUsedFullUrl);
    LJson.Add('width', AWidth);
    LJson.Add('height', AHeight);
    LJson.Add('nodeClass', ATexture.ClassName);
    LJson.Add('flipVertically', ATexture.FlipVertically);
    LJson.Add('repeatS', ATexture.RepeatS);
    LJson.Add('repeatT', ATexture.RepeatT);
    LJson.Add('effectiveMinificationFilter',
      Ord(ARenderOptions.MinificationFilter));
    LJson.Add('effectiveMagnificationFilter',
      Ord(ARenderOptions.MagnificationFilter));
    LJson.Add('defaultMinificationFilter',
      Ord(TCastleRenderOptions.DefaultMinificationFilter));
    LJson.Add('defaultMagnificationFilter',
      Ord(TCastleRenderOptions.DefaultMagnificationFilter));
    LProperties := ATexture.TextureProperties;
    if LProperties = nil then
    begin
      LJson.Add('textureProperties', 'nil');
    end else
    begin
      LJson.Add('textureProperties', 'explicit');
      LJson.Add('minificationFilter', Ord(LProperties.MinificationFilter));
      LJson.Add('magnificationFilter', Ord(LProperties.MagnificationFilter));
      LJson.Add('boundaryModeS', Ord(LProperties.BoundaryModeS));
      LJson.Add('boundaryModeT', Ord(LProperties.BoundaryModeT));
      LJson.Add('boundaryModeR', Ord(LProperties.BoundaryModeR));
      LJson.Add('anisotropicDegreeBits',
        SingleBitsHex(LProperties.AnisotropicDegree));
      LJson.Add('guiTexture', LProperties.GuiTexture);
    end;
    Result := LJson.AsJSON;
  finally
    LJson.Free;
  end;
end;

constructor TCatalogTextureProfile.Create(const AScene: TCastleScene;
  const AAssetId: String; const ADeclaredPixels: Int64);
var
  LPadding: Int64;
  LJson: TJSONObject;
begin
  inherited Create;
  if AScene = nil then
  begin
    raise Exception.Create('Catalog texture profile scene is missing');
  end;
  if (ADeclaredPixels < 0) or (ADeclaredPixels > 64 * 1024 * 1024) then
  begin
    raise Exception.Create(
      'Catalog declared texture pixels must be between 0 and 64 MiB');
  end;
  if GNextTextureProfile = High(QWord) then
  begin
    raise Exception.Create('Catalog texture profile identifiers exhausted');
  end;
  Inc(GNextTextureProfile);
  FProfileId := GNextTextureProfile;
  FAssetId := AAssetId;
  FDeclaredPixels := ADeclaredPixels;
  FScene := AScene;
  FClaims := TStringList.Create;
  FClaims.CaseSensitive := True;
  FClaims.Sorted := True;
  if AScene.RootNode <> nil then
  begin
    AScene.RootNode.EnumerateNodes(TAbstractTextureNode, InspectTexture, False);
  end;
  if FOpaque then
  begin
    ReplaceWithOpaqueClaim;
  end else
  begin
    LPadding := FDeclaredPixels - FMeasuredPixels;
    if LPadding > 0 then
    begin
      LJson := TJSONObject.Create;
      try
        LJson.Add('kind', 'padding');
        LJson.Add('asset', FAssetId);
        LJson.Add('profile', UIntToStr(FProfileId));
        AddClaim(LJson.AsJSON, LPadding);
      finally
        LJson.Free;
      end;
    end;
  end;
  FScene := nil;
end;

destructor TCatalogTextureProfile.Destroy;
var
  I: Integer;
begin
  if FClaims <> nil then
  begin
    for I := 0 to FClaims.Count - 1 do
    begin
      FClaims.Objects[I].Free;
    end;
    FClaims.Free;
  end;
  inherited Destroy;
end;

procedure TCatalogTextureProfile.AddClaim(const AKey: String;
  const APixels: Int64);
var
  LClaim: TClaim;
  LIndex: Integer;
begin
  LIndex := FClaims.IndexOf(AKey);
  if LIndex >= 0 then
  begin
    LClaim := TClaim(FClaims.Objects[LIndex]);
    if LClaim.FPixels <> APixels then
    begin
      raise Exception.Create('Catalog texture claim key has conflicting pixels');
    end;
    Exit;
  end;
  LClaim := TClaim.Create;
  LClaim.FPixels := APixels;
  try
    FClaims.AddObject(AKey, LClaim);
  except
    LClaim.Free;
    raise;
  end;
end;

procedure TCatalogTextureProfile.InspectTexture(ANode: TX3DNode);
var
  LTexture: TImageTextureNode;
  LImage: TEncodedImage;
  LWidth: Int64;
  LHeight: Int64;
  LPixels: Int64;
  LKey: String;
  LIndex: Integer;
  LRenderOptions: TCastleRenderOptions;
begin
  if ANode is TMultiTextureNode then
  begin
    Exit;
  end;
  if not (ANode is TImageTextureNode) then
  begin
    FOpaque := True;
    Exit;
  end;
  LTexture := TImageTextureNode(ANode);
  LImage := LTexture.TextureImage;
  if LImage = nil then
  begin
    raise Exception.Create('Catalog image texture has no decoded image');
  end;
  LWidth := LImage.Width;
  LHeight := LImage.Height;
  if (LWidth <= 0) or (LHeight <= 0) or
    (LWidth > FDeclaredPixels) or (LHeight > FDeclaredPixels) then
  begin
    raise Exception.Create(
      'Catalog texture dimensions exceed declared texture pixels');
  end;
  LPixels := LWidth * LHeight;
  if LPixels > FDeclaredPixels then
  begin
    raise Exception.Create(
      'Catalog measured unique texture pixels exceed the declaration');
  end;
  if LTexture.TextureUsedFullUrl = '' then
  begin
    FOpaque := True;
    Exit;
  end;
  LRenderOptions := TSceneAccess(FScene).CurrentRenderOptions;
  if LRenderOptions = nil then
  begin
    FOpaque := True;
    Exit;
  end;
  LKey := ImageClaimKey(LTexture, LWidth, LHeight, LRenderOptions);
  LIndex := FClaims.IndexOf(LKey);
  if LIndex < 0 then
  begin
    if LPixels > FDeclaredPixels - FMeasuredPixels then
    begin
      raise Exception.Create(
        'Catalog measured unique texture pixels exceed the declaration');
    end;
    AddClaim(LKey, LPixels);
    Inc(FMeasuredPixels, LPixels);
  end;
end;

procedure TCatalogTextureProfile.ReplaceWithOpaqueClaim;
var
  I: Integer;
  LJson: TJSONObject;
begin
  for I := 0 to FClaims.Count - 1 do
  begin
    FClaims.Objects[I].Free;
  end;
  FClaims.Clear;
  FMeasuredPixels := 0;
  if FDeclaredPixels = 0 then
  begin
    Exit;
  end;
  LJson := TJSONObject.Create;
  try
    LJson.Add('kind', 'opaque');
    LJson.Add('asset', FAssetId);
    LJson.Add('profile', UIntToStr(FProfileId));
    AddClaim(LJson.AsJSON, FDeclaredPixels);
  finally
    LJson.Free;
  end;
end;

function CatalogTexturePixels(
  const AProfiles: array of TCatalogTextureProfile): Int64;
var
  LClaims: TStringList;
  LProfile: TCatalogTextureProfile;
  LClaim: TCatalogTextureProfile.TClaim;
  LExisting: TCatalogTextureProfile.TClaim;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  Result := 0;
  LClaims := TStringList.Create;
  try
    LClaims.CaseSensitive := True;
    LClaims.Sorted := True;
    for I := 0 to High(AProfiles) do
    begin
      LProfile := AProfiles[I];
      if LProfile = nil then
      begin
        raise Exception.Create('Catalog texture profile is missing');
      end;
      for J := 0 to LProfile.FClaims.Count - 1 do
      begin
        LClaim := TCatalogTextureProfile.TClaim(LProfile.FClaims.Objects[J]);
        LIndex := LClaims.IndexOf(LProfile.FClaims[J]);
        if LIndex >= 0 then
        begin
          LExisting := TCatalogTextureProfile.TClaim(LClaims.Objects[LIndex]);
          if LExisting.FPixels <> LClaim.FPixels then
          begin
            raise Exception.Create(
              'Catalog texture claim key has conflicting aggregate pixels');
          end;
        end else
        begin
          if LClaim.FPixels > High(Int64) - Result then
          begin
            raise Exception.Create('Catalog texture pixel total overflow');
          end;
          Inc(Result, LClaim.FPixels);
          LClaims.AddObject(LProfile.FClaims[J], LClaim);
        end;
      end;
    end;
  finally
    LClaims.Free;
  end;
end;

end.
