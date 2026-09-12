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
  Classes, SysUtils, FPJSON, CastleScene, CastleDownload,
  phanes.catalog.files, phanes.catalog.scene, phanes.tools.files, phanes.tools.fingerprint;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
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
    CheckGuards;
    CheckSceneOwnership;
    CheckModel(ParamStr(1), 'quaternius-low-poly-food-pack-surface-v1',
      'quaternius-low-poly-food-pack-surface-v1/soysauce-2882b4c31b');
    CheckModel(ParamStr(1), 'kaykit-furniture-bits-1-0',
      'kaykit-furniture-bits-1-0/gltf/rug_rectangle_A');
    WriteLn('PASS ', GChecks, ' catalog filesystem checks');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
