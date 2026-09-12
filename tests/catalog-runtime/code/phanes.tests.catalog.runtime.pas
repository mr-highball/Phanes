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
unit phanes.tests.catalog.runtime;

{$mode delphi}
{$H+}

interface

implementation

uses
  SysUtils, Math, JOB.JS, CastleWindow, CastleUIControls, CastleViewport,
  CastleScene, CastleTransform, CastleVectors, CastleBoxes, phanes.catalog.files,
  phanes.catalog.scene;

type
  TCatalogProbeView = class(TCastleView)
  private
    FBrowser: TJSObject;
    FViewport: TCastleViewport;
    FLease: TCatalogSceneLease;
    FRevision: LongInt;
    procedure LoadBundle(const ARevision: LongInt);
  public
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const ASecondsPassed: Single; var AHandleInput: Boolean); override;
    procedure RenderOverChildren; override;
  end;

var
  GWindow: TCastleWindow;

procedure TCatalogProbeView.Start;
var
  LLight: TCastleDirectionalLight;
begin
  inherited;
  FBrowser := TJSObject.JOBCreateGlobal('window');
  FViewport := TCastleViewport.Create(FreeAtStop);
  FViewport.FullSize := True;
  FViewport.BackgroundColor := Vector4(0.12, 0.16, 0.2, 1);
  InsertFront(FViewport);
  FViewport.Camera := TCastleCamera.Create(FreeAtStop);
  FViewport.Items.Add(FViewport.Camera);
  FViewport.Camera.ProjectionNear := 0.001;
  LLight := TCastleDirectionalLight.Create(FreeAtStop);
  LLight.Orientation := otUpYDirectionMinusZ;
  LLight.Direction := Vector3(-1, -1, -1);
  LLight.Intensity := 2;
  FViewport.Items.Add(LLight);
  FBrowser.WriteJSPropertyBoolean('phanesCatalogRendererReady', True);
end;

procedure TCatalogProbeView.Stop;
begin
  if FLease <> nil then
  begin
    FViewport.Items.Remove(FLease.Scene);
  end;
  FreeAndNil(FLease);
  FreeAndNil(FBrowser);
  inherited;
end;

procedure TCatalogProbeView.LoadBundle(const ARevision: LongInt);
var
  LValue: IJSObject;
  LBundle: TCatalogFileBundle;
  LLease: TCatalogSceneLease;
  LBox: TBox3D;
  LCenter: TVector3;
  LPosition: TVector3;
  LRadius: Single;
begin
  LValue := FBrowser.ReadJSPropertyObject('phanesCatalogBundle', TJSObject);
  LBundle := CatalogBundleFromBrowser(LValue,
    FBrowser.ReadJSPropertyLongInt('phanesCatalogExpectedGeneration'));
  LLease := nil;
  try
    LLease := TCatalogSceneLease.Create(LBundle);
    LLease.PrepareResources(FViewport);
    LBox := LLease.Scene.BoundingBox;
    LCenter := (LBox.Data[0] + LBox.Data[1]) * 0.5;
    LRadius := Max(0.1, Max(LBox.Data[1].X - LBox.Data[0].X,
      Max(LBox.Data[1].Y - LBox.Data[0].Y, LBox.Data[1].Z - LBox.Data[0].Z)));
    LPosition := LCenter + Vector3(LRadius * 1.3, LRadius, LRadius * 1.3);
    FViewport.Camera.SetView(LPosition, LCenter - LPosition, Vector3(0, 1, 0));
    if FLease <> nil then
    begin
      FViewport.Items.Remove(FLease.Scene);
    end;
    FreeAndNil(FLease);
    FLease := LLease;
    LLease := nil;
    FViewport.Items.Add(FLease.Scene);
    FBrowser.WriteJSPropertyLongInt('phanesCatalogTriangles', FLease.Scene.TrianglesCount);
    FBrowser.WriteJSPropertyLongInt('phanesCatalogSourceBytes', FLease.SourceBytes);
    FBrowser.WriteJSPropertyLongInt('phanesCatalogLoadedRevision', ARevision);
  finally
    LLease.Free;
    LBundle.Free;
  end;
end;

procedure TCatalogProbeView.Update(const ASecondsPassed: Single; var AHandleInput: Boolean);
var
  LRevision: LongInt;
begin
  inherited;
  LRevision := FBrowser.ReadJSPropertyLongInt('phanesCatalogRequestRevision');
  if LRevision <> FRevision then
  begin
    FRevision := LRevision;
    try
      LoadBundle(LRevision);
      FBrowser.WriteJSPropertyUtf8String('phanesCatalogRendererFailure', '');
    except
      on LException: Exception do
      begin
        FBrowser.WriteJSPropertyUtf8String('phanesCatalogRendererFailure', LException.Message);
      end;
    end;
  end;
end;

procedure TCatalogProbeView.RenderOverChildren;
begin
  inherited;
  if FLease <> nil then
  begin
    FBrowser.WriteJSPropertyLongInt('phanesCatalogDrawnRevision',
      FBrowser.ReadJSPropertyLongInt('phanesCatalogLoadedRevision'));
  end;
end;

procedure InitializeApplication;
begin
  GWindow.Container.View := TCatalogProbeView.Create(Application);
end;

initialization
  GWindow := TCastleWindow.Create(Application);
  Application.MainWindow := GWindow;
  Application.OnInitialize := InitializeApplication;
end.
