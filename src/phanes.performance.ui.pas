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

unit phanes.performance.ui;

{$mode delphi}
{$H+}

interface

procedure StartPerformanceUI;

implementation

uses
  JS, Web, SysUtils, Math;

type
  TPerformanceUI = class
  private
    FCanvas: TJSHTMLCanvasElement;
    FScale: Double;
    FLastFrame: Double;
    FSampleStart: Double;
    FFrameTotal: Double;
    FFrameCount: Integer;
    FLastFit: Double;
    FLastVersion: Integer;
    FSettleUntil: Double;
    FLastRendered: Integer;
    function Changed(AEvent: TJSEvent): Boolean;
    function Visibility(AEvent: TJSEvent): Boolean;
    procedure Fit;
    procedure Frame(const ATime: Double);
  public
    constructor Create;
  end;

var
  GPerformance: TPerformanceUI;

function Mode: String;
begin
  Result := TJSHTMLSelectElement(document.getElementById('render-quality')).value;
end;

constructor TPerformanceUI.Create;
begin
  inherited Create;
  FCanvas := TJSHTMLCanvasElement(document.getElementById('castle-canvas'));
  FScale := 2;
  FSettleUntil := window.performance.now + 3000;
  document.getElementById('render-quality').addEventListener('change', @Changed);
  window.addEventListener('resize', @Changed);
  document.addEventListener('visibilitychange', @Visibility);
  document.addEventListener('freeze', @Visibility);
  document.addEventListener('resume', @Visibility);
  FCanvas.addEventListener('webglcontextlost', @Visibility);
  Fit;
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Frame(ATime);
    end);
end;

procedure TPerformanceUI.Fit;
var
  LRatio: Double;
  LWidth: Integer;
  LHeight: Integer;
begin
  LRatio := Min(window.devicePixelRatio, FScale);
  if Mode = 'detail' then
  begin
    LRatio := window.devicePixelRatio;
  end else if Mode = 'smooth' then
  begin
    LRatio := Min(window.devicePixelRatio, 1);
  end;
  LWidth := Max(1, Round(FCanvas.clientWidth * LRatio));
  LHeight := Max(1, Round(FCanvas.clientHeight * LRatio));
  if (LWidth <> FCanvas.width) or (LHeight <> FCanvas.height) then
  begin
    FCanvas.width := LWidth;
    FCanvas.height := LHeight;
  end;
  TJSObject(window)['phanesRenderDensity'] := LRatio;
end;

function TPerformanceUI.Changed(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FScale := 2;
  Visibility(nil);
  FSettleUntil := window.performance.now + 3000;
  Fit;
end;

procedure TPerformanceUI.Frame(const ATime: Double);
var
  LVersion: Integer;
  LRendered: Integer;
  LMean: Double;
  LStats: TJSObject;
begin
  LVersion := Integer(TJSObject(window)['phanesSceneVersion']);
  if FLastVersion <> LVersion then
  begin
    FLastVersion := LVersion;
    FSettleUntil := ATime + 3000;
  end;
  LRendered := Integer(TJSObject(window)['phanesRenderedFrames']);
  if (FLastFrame > 0) and (ATime >= FSettleUntil) and not document.hidden and
    not Boolean(TJSObject(window)['phanesRecovering']) and
    not Boolean(TJSObject(window)['phanesWorldCovered']) then
  begin
    FFrameTotal := FFrameTotal + ATime - FLastFrame;
    if LRendered > FLastRendered then
    begin
      Inc(FFrameCount, LRendered - FLastRendered);
    end;
  end;
  FLastRendered := LRendered;
  FLastFrame := ATime;
  if ATime - FLastFit > 100 then
  begin
    Fit;
    FLastFit := ATime;
  end;
  if ATime - FSampleStart >= 2500 then
  begin
    if FFrameCount >= 4 then
    begin
      LMean := FFrameTotal / FFrameCount;
      LStats := TJSObject.new;
      LStats['frameMs'] := LMean;
      LStats['fps'] := 1000 / Max(1, LMean);
      LStats['density'] := TJSObject(window)['phanesRenderDensity'];
      LStats['mode'] := Mode;
      TJSObject(window)['phanesPerformance'] := LStats;
      { Resize only after a sustained sample and outside scene admission.
        DOM controls stay at native resolution; only the 3D buffer changes. }
      if (Mode = 'balanced') and (ATime >= FSettleUntil) then
      begin
        if LMean > 36 then
        begin
          FScale := Max(1.5, FScale - 0.15);
          FSettleUntil := ATime + 2500;
        end else if (LMean < 19) and (FScale < 2) then
        begin
          FScale := Min(2, FScale + 0.1);
          FSettleUntil := ATime + 5000;
        end;
      end;
    end else
    begin
      TJSObject(window)['phanesPerformance'] := nil;
    end;
    FSampleStart := ATime;
    FFrameTotal := 0;
    FFrameCount := 0;
  end;
  window.requestAnimationFrame(procedure(ATime: Double)
    begin
      Frame(ATime);
    end);
end;

function TPerformanceUI.Visibility(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FLastFrame := 0;
  FFrameTotal := 0;
  FFrameCount := 0;
  FSampleStart := window.performance.now;
  FSettleUntil := FSampleStart + 3000;
  TJSObject(window)['phanesPerformance'] := nil;
end;

procedure StartPerformanceUI;
begin
  GPerformance := TPerformanceUI.Create;
end;

end.
