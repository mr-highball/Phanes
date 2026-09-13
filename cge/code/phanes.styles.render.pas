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

unit phanes.styles.render;

{$mode delphi}
{$H+}

interface

uses
  CastleViewport,
  X3DNodes,
  X3DFields,
  X3DTime;

type
  TVisualStyleRenderer = class
  private
    FViewport: TCastleViewport;
    FEffect: TScreenEffectNode;
    FShader: TComposedShaderNode;
    FShaderValid: Boolean;
    FIndex: TSFInt32;
    FStrength: TSFFloat;
    FDetail: TSFFloat;
    FDensity: TSFFloat;
    FLastDensity: Double;
    procedure Prepare;
    procedure ShaderValidity(const AEvent: TX3DEvent; const AValue: TX3DField;
      const ATime: TX3DTime);
  public
    constructor Create(const AViewport: TCastleViewport);
    destructor Destroy; override;
    procedure Apply(const AIndex: Integer; const AStrength, ADetail, ADensity: Double);
    procedure UpdateDensity(const ADensity: Double);
    property ShaderValid: Boolean read FShaderValid;
  end;

implementation

uses
  SysUtils,
  Math,
  CastleRenderOptions,
  CastleScreenEffects,
  phanes.styles.catalog;

constructor TVisualStyleRenderer.Create(const AViewport: TCastleViewport);
begin
  inherited Create;
  FViewport := AViewport;
  FLastDensity := 1;
end;

procedure TVisualStyleRenderer.Prepare;
var
  LShader: TComposedShaderNode;
  LPart: TShaderPartNode;
begin
  if FEffect <> nil then
  begin
    Exit;
  end;
  LPart := TShaderPartNode.Create;
  LPart.ShaderType := stFragment;
  LPart.SetUrl(['castle-data:/shaders/phanes.styles.fs']);
  LShader := TComposedShaderNode.Create;
  FShader := LShader;
  FShader.EventIsValid.AddNotification(ShaderValidity);
  LShader.SetParts([LPart]);
  FIndex := TSFInt32.Create(LShader, True, 'phanesStyle', 0);
  FStrength := TSFFloat.Create(LShader, True, 'phanesStrength', 1);
  FDetail := TSFFloat.Create(LShader, True, 'phanesDetail', 0.5);
  FDensity := TSFFloat.Create(LShader, True, 'phanesDensity', FLastDensity);
  LShader.AddCustomField(FIndex);
  LShader.AddCustomField(FStrength);
  LShader.AddCustomField(FDetail);
  LShader.AddCustomField(FDensity);
  FEffect := TScreenEffectNode.Create;
  FEffect.SetShaders([LShader]);
  FEffect.NeedsDepth := False;
  FEffect.Enabled := False;
  FViewport.AddScreenEffect(FEffect);
end;

destructor TVisualStyleRenderer.Destroy;
begin
  if FEffect <> nil then
  begin
    FShader.EventIsValid.RemoveNotification(ShaderValidity);
    FViewport.RemoveScreenEffect(FEffect);
    FEffect := nil;
  end;
  inherited;
end;

procedure TVisualStyleRenderer.ShaderValidity(const AEvent: TX3DEvent;
  const AValue: TX3DField; const ATime: TX3DTime);
begin
  FShaderValid := (AValue as TSFBool).Value;
end;

procedure TVisualStyleRenderer.Apply(const AIndex: Integer;
  const AStrength, ADetail, ADensity: Double);
begin
  if not ValidStyleSettings(AIndex, AStrength, ADetail) then
  begin
    raise Exception.Create('Invalid visual style settings');
  end;
  if (AIndex = 0) or (AStrength = 0) then
  begin
    if FEffect <> nil then
    begin
      FEffect.Enabled := False;
    end;
    Exit;
  end;
  Prepare;
  FIndex.Send(AIndex);
  FStrength.Send(AStrength);
  FDetail.Send(ADetail);
  UpdateDensity(ADensity);
  FEffect.Enabled := True;
  { Prepare the effect before the viewport can draw with it. The pinned WASI
    renderer reports shader compilation errors without raising or sending an
    isValid=false event, and can retain an unusable program. Only a positive
    validity notification admits this optional pass. Disabling it here lets a
    normal frame reach the existing UI acknowledgement and restore None. }
  TCastleScreenEffects(FViewport).PrepareResources;
  if not FShaderValid then
  begin
    FEffect.Enabled := False;
  end;
end;

procedure TVisualStyleRenderer.UpdateDensity(const ADensity: Double);
var
  LDensity: Double;
begin
  if IsNan(ADensity) or IsInfinite(ADensity) or (ADensity <= 0) then
  begin
    LDensity := 1;
  end else
  begin
    LDensity := ADensity;
  end;
  if Abs(LDensity - FLastDensity) > 0.0001 then
  begin
    FLastDensity := LDensity;
    if FDensity <> nil then
    begin
      FDensity.Send(LDensity);
    end;
  end;
end;

end.
