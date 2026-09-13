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
unit phanes.tests.catalog.textures;

{$mode delphi}
{$H+}

interface

function CheckCatalogTextureProfiles: Integer;

implementation

uses
  SysUtils, CastleScene, CastleImages, CastleRenderOptions, X3DNodes,
  phanes.catalog.textures;

const
  AtlasPixels = Int64(1024) * 1024;

type
  TTestScene = class(TCastleScene)
  public
    procedure UseOverrideOptions(const AOptions: TCastleRenderOptions);
  end;

var
  GChecks: Integer;

procedure TTestScene.UseOverrideOptions(
  const AOptions: TCastleRenderOptions);
begin
  InternalOverrideRenderOptions := AOptions;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function TexturedScene(const AUrl: String; const AFlipVertically: Boolean;
  const AOverrideFilter: Boolean): TTestScene;
var
  LImage: TRGBImage;
  LTexture: TImageTextureNode;
  LAppearance: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
  LOptions: TCastleRenderOptions;
begin
  Result := TTestScene.Create(nil);
  try
    LImage := TRGBImage.Create(1024, 1024);
    LTexture := TImageTextureNode.Create;
    LTexture.LoadFromImage(LImage, True, AUrl);
    LTexture.FlipVertically := AFlipVertically;
    LAppearance := TAppearanceNode.Create;
    LAppearance.Texture := LTexture;
    LShape := TShapeNode.Create;
    LShape.Appearance := LAppearance;
    LRoot := TX3DRootNode.Create;
    LRoot.AddChildren(LShape);
    Result.Load(LRoot, True);
    if AOverrideFilter then
    begin
      LOptions := TCastleRenderOptions.Create(Result);
      LOptions.MinificationFilter := minNearest;
      Result.UseOverrideOptions(LOptions);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function UntexturedScene: TTestScene;
var
  LRoot: TX3DRootNode;
begin
  Result := TTestScene.Create(nil);
  try
    LRoot := TX3DRootNode.Create;
    Result.Load(LRoot, True);
  except
    Result.Free;
    raise;
  end;
end;

function OpaqueTextureScene: TTestScene;
var
  LTexture: TPixelTextureNode;
  LAppearance: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
begin
  Result := TTestScene.Create(nil);
  try
    LTexture := TPixelTextureNode.Create;
    LAppearance := TAppearanceNode.Create;
    LAppearance.Texture := LTexture;
    LShape := TShapeNode.Create;
    LShape.Appearance := LAppearance;
    LRoot := TX3DRootNode.Create;
    LRoot.AddChildren(LShape);
    Result.Load(LRoot, True);
  except
    Result.Free;
    raise;
  end;
end;

function MissingImageScene: TTestScene;
var
  LTexture: TImageTextureNode;
  LAppearance: TAppearanceNode;
  LShape: TShapeNode;
  LRoot: TX3DRootNode;
begin
  Result := TTestScene.Create(nil);
  try
    LTexture := TImageTextureNode.Create;
    LAppearance := TAppearanceNode.Create;
    LAppearance.Texture := LTexture;
    LShape := TShapeNode.Create;
    LShape.Appearance := LAppearance;
    LRoot := TX3DRootNode.Create;
    LRoot.AddChildren(LShape);
    Result.Load(LRoot, True);
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckImageClaims;
var
  LSharedFirst: TTestScene;
  LSharedSecond: TTestScene;
  LIsolated: TTestScene;
  LSamplerVariant: TTestScene;
  LInheritedVariant: TTestScene;
  LFirstProfile: TCatalogTextureProfile;
  LSecondProfile: TCatalogTextureProfile;
  LIsolatedProfile: TCatalogTextureProfile;
  LSamplerProfile: TCatalogTextureProfile;
  LInheritedProfile: TCatalogTextureProfile;
  LFailedProfile: TCatalogTextureProfile;
  LFailed: Boolean;
begin
  LSharedFirst := TexturedScene('memory:/atlas.png', False, False);
  LSharedSecond := TexturedScene('memory:/atlas.png', False, False);
  LIsolated := TexturedScene('memory:/other-atlas.png', False, False);
  LSamplerVariant := TexturedScene('memory:/atlas.png', True, False);
  LInheritedVariant := TexturedScene('memory:/atlas.png', False, True);
  LFirstProfile := nil;
  LSecondProfile := nil;
  LIsolatedProfile := nil;
  LSamplerProfile := nil;
  LInheritedProfile := nil;
  try
    LFirstProfile := TCatalogTextureProfile.Create(
      LSharedFirst, 'first', AtlasPixels);
    LSecondProfile := TCatalogTextureProfile.Create(
      LSharedSecond, 'second', AtlasPixels);
    LIsolatedProfile := TCatalogTextureProfile.Create(
      LIsolated, 'isolated', AtlasPixels);
    LSamplerProfile := TCatalogTextureProfile.Create(
      LSamplerVariant, 'sampler', AtlasPixels);
    LInheritedProfile := TCatalogTextureProfile.Create(
      LInheritedVariant, 'inherited', AtlasPixels);
    Check(CatalogTexturePixels([LFirstProfile, LSecondProfile]) = AtlasPixels,
      'same URL, dimensions, and sampler state share one pixel claim');
    Check(CatalogTexturePixels([LFirstProfile, LIsolatedProfile]) =
      2 * AtlasPixels, 'isolated texture URLs retain separate pixel claims');
    Check(CatalogTexturePixels([LFirstProfile, LSamplerProfile]) =
      2 * AtlasPixels, 'flip variant cannot discount a sampler allocation');
    Check(CatalogTexturePixels([LFirstProfile, LInheritedProfile]) =
      2 * AtlasPixels,
      'effective override filters cannot discount an inherited allocation');
    Check(CatalogTexturePixels([LFirstProfile, LFirstProfile]) = AtlasPixels,
      'repeating the same profile does not double count its image claim');

    LFailedProfile := nil;
    LFailed := False;
    try
      LFailedProfile := TCatalogTextureProfile.Create(
        LSharedFirst, 'undersized', 1024);
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog measured unique texture pixels exceed the declaration';
      end;
    end;
    Check(LFailed and (LFailedProfile = nil),
      'declared pixels smaller than measured unique images reject');
  finally
    LInheritedProfile.Free;
    LSamplerProfile.Free;
    LIsolatedProfile.Free;
    LSecondProfile.Free;
    LFirstProfile.Free;
    LInheritedVariant.Free;
    LSamplerVariant.Free;
    LIsolated.Free;
    LSharedSecond.Free;
    LSharedFirst.Free;
  end;
end;

procedure CheckOpaqueClaims;
var
  LOpaqueScene: TTestScene;
  LUntexturedScene: TTestScene;
  LOpaqueProfile: TCatalogTextureProfile;
  LPaddingProfile: TCatalogTextureProfile;
begin
  LOpaqueScene := OpaqueTextureScene;
  LUntexturedScene := UntexturedScene;
  LOpaqueProfile := nil;
  LPaddingProfile := nil;
  try
    LOpaqueProfile := TCatalogTextureProfile.Create(
      LOpaqueScene, 'same-asset', 100);
    LPaddingProfile := TCatalogTextureProfile.Create(
      LUntexturedScene, 'same-asset', 100);
    Check(CatalogTexturePixels([LOpaqueProfile, LPaddingProfile]) = 200,
      'opaque and padding claims remain distinct across profile instances');
    Check(CatalogTexturePixels([LOpaqueProfile, LOpaqueProfile]) = 100,
      'the same opaque profile may be unioned repeatedly without double count');
  finally
    LPaddingProfile.Free;
    LOpaqueProfile.Free;
    LUntexturedScene.Free;
    LOpaqueScene.Free;
  end;
end;

procedure CheckImageFailureGuards;
var
  LMissingImage: TTestScene;
  LEmptyUrl: TTestScene;
  LProfile: TCatalogTextureProfile;
  LFailed: Boolean;
begin
  LMissingImage := MissingImageScene;
  LEmptyUrl := TexturedScene('', False, False);
  try
    LProfile := nil;
    LFailed := False;
    try
      LProfile := TCatalogTextureProfile.Create(
        LMissingImage, 'missing-image', 2048);
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog image texture has no decoded image';
      end;
    end;
    Check(LFailed and (LProfile = nil),
      'image texture without decoded image rejects explicitly');

    LProfile := nil;
    LFailed := False;
    try
      LProfile := TCatalogTextureProfile.Create(
        LEmptyUrl, 'empty-url-underdeclared', 2048);
    except
      on LException: Exception do
      begin
        LFailed := LException.Message =
          'Catalog measured unique texture pixels exceed the declaration';
      end;
    end;
    Check(LFailed and (LProfile = nil),
      'known image pixels reject underdeclaration before empty-URL fallback');
  finally
    LEmptyUrl.Free;
    LMissingImage.Free;
  end;
end;

function CheckCatalogTextureProfiles: Integer;
begin
  GChecks := 0;
  CheckImageClaims;
  CheckOpaqueClaims;
  CheckImageFailureGuards;
  Result := GChecks;
end;

end.
