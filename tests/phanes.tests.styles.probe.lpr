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
program phanes.tests.styles.probe;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses
  JS,
  Web,
  SysUtils;

type
  TProbeSet = class external name 'Set'
    constructor new;
    procedure add(const AValue: JSValue);
    procedure Remove(const AValue: JSValue); external name 'delete';
    size: Integer;
  end;

var
  GTextureCreate: TJSFunction;
  GTextureDelete: TJSFunction;
  GProgramCreate: TJSFunction;
  GProgramDelete: TJSFunction;
  GFramebufferCreate: TJSFunction;
  GFramebufferDelete: TJSFunction;
  GShaderSource: TJSFunction;
  GCompileShader: TJSFunction;
  GShaderFailures: array of String;
  GDrawArrays: TJSFunction;
  GDrawElements: TJSFunction;
  GEnable: TJSFunction;
  GDisable: TJSFunction;
  GStencilEnabled: Boolean;
  GStencilDraws: Integer;
  GDrawCount: Integer;
  GTextures: TProbeSet;
  GPrograms: TProbeSet;
  GFramebuffers: TProbeSet;
  GTextureCreates: Integer;
  GProgramCreates: Integer;
  GFramebufferCreates: Integer;
  GIntervals: array of Double;
  GErrors: array of String;
  GLastFrame: Double;
  GFailureInjected: Boolean;
  GShadowShaders: array of String;

{ These asm statements retrieve the receiver of the foreign WebGL call.
  All instrumentation, bounds, counters and failure decisions are Pascal. The
  wrappers preserve the original context, arguments and returned GPU objects. }
function CreateTexture: JSValue;
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  Result := GTextureCreate.apply(LContext, []);
  if not isNull(Result) then
  begin
    GTextures.add(Result);
    Inc(GTextureCreates);
  end;
end;

procedure DeleteTexture(const ATexture: JSValue);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  GTextures.Remove(ATexture);
  GTextureDelete.apply(LContext, [ATexture]);
end;

function CreateProgram: JSValue;
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  Result := GProgramCreate.apply(LContext, []);
  if not isNull(Result) then
  begin
    GPrograms.add(Result);
    Inc(GProgramCreates);
  end;
end;

procedure DeleteProgram(const AProgram: JSValue);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  GPrograms.Remove(AProgram);
  GProgramDelete.apply(LContext, [AProgram]);
end;

function CreateFramebuffer: JSValue;
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  Result := GFramebufferCreate.apply(LContext, []);
  if not isNull(Result) then
  begin
    GFramebuffers.add(Result);
    Inc(GFramebufferCreates);
  end;
end;

procedure DeleteFramebuffer(const AFramebuffer: JSValue);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  GFramebuffers.Remove(AFramebuffer);
  GFramebufferDelete.apply(LContext, [AFramebuffer]);
end;

procedure ShaderSource(const AShader: JSValue; const ASource: String);
var
  LContext: TJSObject;
  LSource: String;
  LCount: Integer;
begin
  asm
    LContext = this;
  end;
  LSource := ASource;
  if (Pos('lighting-check', window.location.search) > 0) and
    (Pos('castle_shadow_map_', ASource) > 0) then
  begin
    LCount := Length(GShadowShaders);
    if LCount < 64 then
    begin
      SetLength(GShadowShaders, LCount + 1);
      GShadowShaders[LCount] := ASource;
    end;
  end;
  if (Pos('style-test-failure', window.location.search) > 0) and
    (Pos('uniform int phanesStyle;', ASource) > 0) then
  begin
    LSource := LSource + #10 + 'THIS_IS_AN_INTENTIONAL_SHADER_TEST_FAILURE';
    GFailureInjected := True;
  end;
  GShaderSource.apply(LContext, [AShader, LSource]);
end;

procedure Enable(const ACapability: Integer);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  if ACapability = 2960 then
  begin
    GStencilEnabled := True;
  end;
  GEnable.apply(LContext, [ACapability]);
end;

procedure Disable(const ACapability: Integer);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  if ACapability = 2960 then
  begin
    GStencilEnabled := False;
  end;
  GDisable.apply(LContext, [ACapability]);
end;

procedure DrawArrays(const AMode, AFirst, ACount: Integer);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  Inc(GDrawCount);
  if GStencilEnabled then
  begin
    Inc(GStencilDraws);
  end;
  GDrawArrays.apply(LContext, [AMode, AFirst, ACount]);
end;

procedure DrawElements(const AMode, ACount, AType, AOffset: Integer);
var
  LContext: TJSObject;
begin
  asm
    LContext = this;
  end;
  Inc(GDrawCount);
  if GStencilEnabled then
  begin
    Inc(GStencilDraws);
  end;
  GDrawElements.apply(LContext, [AMode, ACount, AType, AOffset]);
end;

procedure Frame(const ATime: Double);
var
  LCount: Integer;
begin
  LCount := Length(GIntervals);
  if (GLastFrame > 0) and (LCount < 4096) then
  begin
    SetLength(GIntervals, LCount + 1);
    GIntervals[LCount] := ATime - GLastFrame;
  end;
  GLastFrame := ATime;
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Frame(ATime);
    end);
end;

function ErrorEvent(AEvent: TJSEvent): Boolean;
var
  LCount: Integer;
begin
  Result := True;
  LCount := Length(GErrors);
  if LCount < 32 then
  begin
    SetLength(GErrors, LCount + 1);
    GErrors[LCount] := String(TJSObject(AEvent)['message']);
  end;
end;

procedure CompileShader(const AShader: JSValue);
var
  LContext: TJSObject;
  LCount: Integer;
begin
  LContext := TJSObject(JSThis);
  GCompileShader.apply(LContext, [AShader]);
  if not Boolean(TJSFunction(LContext['getShaderParameter']).apply(LContext,
    [AShader, $8B81])) then
  begin
    LCount := Length(GShaderFailures);
    SetLength(GShaderFailures, LCount + 1);
    GShaderFailures[LCount] := String(TJSFunction(LContext['getShaderInfoLog']).apply(
      LContext, [AShader]));
  end;
end;

function Snapshot: TJSObject;
var
  LContext: TJSObject;
begin
  Result := TJSObject.new;
  Result['textureCreates'] := GTextureCreates;
  Result['textureLive'] := GTextures.size;
  Result['programCreates'] := GProgramCreates;
  Result['programLive'] := GPrograms.size;
  Result['framebufferCreates'] := GFramebufferCreates;
  Result['framebufferLive'] := GFramebuffers.size;
  Result['frameIntervals'] := GIntervals;
  Result['errors'] := GErrors;
  Result['shaderFailures'] := GShaderFailures;
  Result['failureInjected'] := GFailureInjected;
  Result['drawCalls'] := GDrawCount;
  Result['shadowShaders'] := GShadowShaders;
  Result['stencilDraws'] := GStencilDraws;
  LContext := TJSObject(TJSHTMLCanvasElement(document.getElementById('castle-canvas')).getContext('webgl2'));
  if not isNull(LContext) then
  begin
    Result['contextAttributes'] := TJSFunction(LContext['getContextAttributes']).call(LContext);
    Result['stencilBits'] := TJSFunction(LContext['getParameter']).call(LContext, 3415);
  end;
end;

procedure ResetFrames;
begin
  SetLength(GIntervals, 0);
  GLastFrame := 0;
end;

procedure LoseContext;
var
  LCanvas: TJSHTMLCanvasElement;
  LContext: TJSObject;
  LExtension: TJSObject;
begin
  LCanvas := TJSHTMLCanvasElement(document.getElementById('castle-canvas'));
  LContext := TJSObject(LCanvas.getContext('webgl2'));
  LExtension := TJSObject(TJSFunction(LContext['getExtension']).call(LContext, 'WEBGL_lose_context'));
  TJSFunction(LExtension['loseContext']).call(LExtension);
  TJSObject(window)['phanesTestLostContext'] := LExtension;
end;

procedure RestoreContext;
var
  LExtension: TJSObject;
begin
  LExtension := TJSObject(TJSObject(window)['phanesTestLostContext']);
  TJSFunction(LExtension['restoreContext']).call(LExtension);
end;

procedure Install;
var
  LPrototype: TJSObject;
begin
  LPrototype := TJSObject(TJSObject(TJSObject(window)['WebGL2RenderingContext'])['prototype']);
  GTextures := TProbeSet.new;
  GPrograms := TProbeSet.new;
  GFramebuffers := TProbeSet.new;
  GTextureCreate := TJSFunction(LPrototype['createTexture']);
  GTextureDelete := TJSFunction(LPrototype['deleteTexture']);
  GProgramCreate := TJSFunction(LPrototype['createProgram']);
  GProgramDelete := TJSFunction(LPrototype['deleteProgram']);
  GFramebufferCreate := TJSFunction(LPrototype['createFramebuffer']);
  GFramebufferDelete := TJSFunction(LPrototype['deleteFramebuffer']);
  GShaderSource := TJSFunction(LPrototype['shaderSource']);
  GCompileShader := TJSFunction(LPrototype['compileShader']);
  GDrawArrays := TJSFunction(LPrototype['drawArrays']);
  GDrawElements := TJSFunction(LPrototype['drawElements']);
  GEnable := TJSFunction(LPrototype['enable']);
  GDisable := TJSFunction(LPrototype['disable']);
  LPrototype['enable'] := @Enable;
  LPrototype['disable'] := @Disable;
  LPrototype['drawArrays'] := @DrawArrays;
  LPrototype['drawElements'] := @DrawElements;
  LPrototype['createTexture'] := @CreateTexture;
  LPrototype['deleteTexture'] := @DeleteTexture;
  LPrototype['createProgram'] := @CreateProgram;
  LPrototype['deleteProgram'] := @DeleteProgram;
  LPrototype['createFramebuffer'] := @CreateFramebuffer;
  LPrototype['deleteFramebuffer'] := @DeleteFramebuffer;
  LPrototype['shaderSource'] := @ShaderSource;
  LPrototype['compileShader'] := @CompileShader;
  TJSObject(window)['phanesStyleProbeSnapshot'] := @Snapshot;
  TJSObject(window)['phanesStyleProbeResetFrames'] := @ResetFrames;
  TJSObject(window)['phanesStyleProbeLoseContext'] := @LoseContext;
  TJSObject(window)['phanesStyleProbeRestoreContext'] := @RestoreContext;
  window.addEventListener('error', @ErrorEvent);
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Frame(ATime);
    end);
end;

begin
  Install;
end.
