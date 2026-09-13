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
unit phanes.catalog.scene;

{$mode delphi}
{$H+}

interface

uses
  CastleScene, CastleViewport, phanes.catalog.files;

type
  { Owns one decoded scene together with every source file it may reload.
    Scene is borrowed: remove viewport/template references before freeing this
    lease. This ownership object does not establish decoded or GPU budgets. }
  TCatalogSceneLease = class
  private
    FFiles: TCatalogFileBundle;
    FScene: TCastleScene;
    function GetSourceBytes: Int64;
  public
    { A sealed bundle is consumed and set to nil before decoding begins, even
      if decoding raises. Invalid/unsealed input remains owned by the caller. }
    constructor Create(var AFiles: TCatalogFileBundle);
    destructor Destroy; override;
    { Call after admission/material setup, with an open rendering context.
      Preparation precedes publication. It must run again after context recovery;
      a successful old call is not proof of readiness in a new context. }
    procedure PrepareResources(const AViewport: TCastleViewport);
    property Scene: TCastleScene read FScene;
    property SourceBytes: Int64 read GetSourceBytes;
  end;

implementation

uses
  SysUtils, Math, CastleBoxes, CastleApplicationProperties;

constructor TCatalogSceneLease.Create(var AFiles: TCatalogFileBundle);
var
  LBounds: TBox3D;
  I: Integer;
  J: Integer;
begin
  inherited Create;
  if (AFiles = nil) or not AFiles.Sealed then
  begin
    raise Exception.Create('Optional model requires a sealed source bundle');
  end;
  FFiles := AFiles;
  AFiles := nil;
  FScene := TCastleScene.Create(nil);
  FScene.Load(FFiles.ModelUrl);
  LBounds := FScene.BoundingBox;
  if LBounds.IsEmpty or (FScene.TrianglesCount = 0) then
  begin
    raise Exception.Create('Optional model decoded without geometry');
  end;
  for I := 0 to 1 do
  begin
    for J := 0 to 2 do
    begin
      if IsNan(LBounds.Data[I].Data[J]) or IsInfinite(LBounds.Data[I].Data[J]) then
      begin
        raise Exception.Create('Optional model decoded with non-finite bounds');
      end;
    end;
  end;
end;

destructor TCatalogSceneLease.Destroy;
begin
  FScene.Free;
  FFiles.Free;
  inherited Destroy;
end;

function TCatalogSceneLease.GetSourceBytes: Int64;
begin
  Result := FFiles.ByteCount;
end;

procedure TCatalogSceneLease.PrepareResources(const AViewport: TCastleViewport);
begin
  if AViewport = nil then
  begin
    raise Exception.Create('Optional model preparation requires a viewport');
  end;
  if not ApplicationProperties.IsGLContextOpen then
  begin
    raise Exception.Create('Optional model preparation requires an open rendering context');
  end;
  AViewport.PrepareResources(FScene);
end;

end.
