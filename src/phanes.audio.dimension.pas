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

unit phanes.audio.dimension;

{$mode delphi}
{$H+}

interface

uses
  JS,
  WebOrWorker;

procedure StartMusicDimension(const AChanged: TJSEventHandler);
function MusicDimensionWeights: TJSArray;
function MusicDimensionTempo: Integer;
procedure UseMusicDimensionPair;
procedure UpdateMusicDimension(const AStats: TJSObject);

implementation

uses
  Web,
  SysUtils,
  Math,
  phanes.music.types,
  phanes.music.track;

type
  TMusicDimension = class
  private
    FChanged: WebOrWorker.TJSEventHandler;
    FWeights: TMusicWeights;
    FNodes: array[0..MusicStyleCount - 1] of TJSHTMLElement;
    FLinks: array[0..MusicStyleCount - 1] of TJSElement;
    FX: array[0..MusicStyleCount - 1] of Double;
    FY: array[0..MusicStyleCount - 1] of Double;
    FTempo: Integer;
    FDragging: Integer;
    FPointerX: Double;
    FPointerY: Double;
    FMoved: Boolean;
    FArrange: Boolean;
    FLastTrack: String;
    FLastBeat: Integer;
    procedure Refresh;
    procedure PositionNodes;
    function Choose(AEvent: TJSEvent): Boolean;
    function Weight(AEvent: TJSEvent): Boolean;
    function Tempo(AEvent: TJSEvent): Boolean;
    function AutoTempo(AEvent: TJSEvent): Boolean;
    function Arrange(AEvent: TJSEvent): Boolean;
    function ResetLayout(AEvent: TJSEvent): Boolean;
    function ArrangeKey(AEvent: TJSEvent): Boolean;
    function PointerDown(AEvent: TJSEvent): Boolean;
    function PointerMove(AEvent: TJSEvent): Boolean;
    function PointerUp(AEvent: TJSEvent): Boolean;
    function Resize(AEvent: TJSEvent): Boolean;
  public
    constructor Create(const AChanged: WebOrWorker.TJSEventHandler);
    procedure Update(const AStats: TJSObject);
  end;

var
  GDimension: TMusicDimension;

function Node(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

function TimeText(const ASeconds: Double): String;
var
  LSeconds: Integer;
begin
  LSeconds := Max(0, Trunc(ASeconds));
  Result := IntToStr(LSeconds div 60) + ':' + Format('%.2d', [LSeconds mod 60]);
end;

procedure SetClass(const AElement: TJSElement; const AName: String; const AEnabled: Boolean);
begin
  if AElement.classList.contains(AName) = AEnabled then
  begin
    Exit;
  end;
  if AEnabled then
  begin
    AElement.classList.add(AName);
  end
  else
  begin
    AElement.classList.remove(AName);
  end;
end;

constructor TMusicDimension.Create(const AChanged: WebOrWorker.TJSEventHandler);
const
  CColours: array[0..9] of String = ('#b3baff', '#79e3ec', '#c49aff', '#a5b7f9',
    '#fdb0df', '#b0efc3', '#7acdc7', '#f7b49b', '#dba9fb', '#ffdb94');
var
  LButton: TJSHTMLElement;
  LInput: TJSHTMLElement;
  LAngle: Double;
  I: Integer;
begin
  inherited Create;
  FChanged := AChanged;
  FDragging := -1;
  FLastBeat := -1;
  FWeights[5] := 100;
  for I := 0 to MusicStyleCount - 1 do
  begin
    FNodes[I] := TJSHTMLElement(document.createElement('div'));
    FNodes[I].className := 'music-island';
    FNodes[I].id := 'style-island-' + IntToStr(I);
    FNodes[I].style.setProperty('--island-colour', CColours[I]);
    FNodes[I].innerHTML := '<button id="style-node-' + IntToStr(I) + '" data-style="' +
      IntToStr(I) + '" aria-pressed="false"><span class="island-orb" aria-hidden="true"></span><strong>' +
      MusicStyle(I).FName + '</strong><span>' + IntToStr(MusicStyle(I).FBpm) +
      ' BPM · <span class="connection-word">Connect</span></span></button>' +
      '<label class="island-weight">Blend strength <input id="style-weight-' + IntToStr(I) +
      '" data-style="' + IntToStr(I) + '" type="range" min="0" max="100" value="0"' +
      ' aria-label="' + MusicStyle(I).FName + ' blend strength" /></label>';
    Node('music-space').appendChild(FNodes[I]);
    LButton := Node('style-node-' + IntToStr(I));
    LInput := Node('style-weight-' + IntToStr(I));
    LButton.addEventListener('click', @Choose);
    LButton.addEventListener('pointerdown', @PointerDown);
    LButton.addEventListener('keydown', @ArrangeKey);
    LInput.addEventListener('input', @Weight);
    LInput.addEventListener('change', FChanged);
    FLinks[I] := document.createElementNS('http://www.w3.org/2000/svg', 'path');
    FLinks[I].setAttribute('stroke', CColours[I]);
    FLinks[I].setAttribute('class', 'music-connection');
    FLinks[I].id := 'style-link-' + IntToStr(I);
    Node('music-links').appendChild(FLinks[I]);
    LAngle := I * 2 * Pi / MusicStyleCount - Pi / 2;
    FX[I] := 50 + 36 * Cos(LAngle);
    FY[I] := 50 + 35 * Sin(LAngle);
  end;
  Node('music-tempo').addEventListener('input', @Tempo);
  Node('music-tempo').addEventListener('change', FChanged);
  Node('tempo-auto').addEventListener('click', @AutoTempo);
  Node('music-arrange').addEventListener('click', @Arrange);
  Node('music-reset').addEventListener('click', @ResetLayout);
  window.addEventListener('pointermove', @PointerMove);
  window.addEventListener('pointerup', @PointerUp);
  window.addEventListener('pointercancel', @PointerUp);
  window.addEventListener('resize', @Resize);
  Resize(nil);
  Refresh;
end;

procedure TMusicDimension.PositionNodes;
var
  I: Integer;
begin
  for I := 0 to MusicStyleCount - 1 do
  begin
    FNodes[I].style.setProperty('left', FloatToStr(FX[I]) + '%');
    FNodes[I].style.setProperty('top', FloatToStr(FY[I]) + '%');
    FLinks[I].setAttribute('d', 'M ' + FloatToStr(FX[I] * 10) + ' ' +
      FloatToStr(FY[I] * 7.2) + ' Q 500 ' + FloatToStr(FY[I] * 7.2) + ' 500 360');
  end;
end;

function TMusicDimension.Resize(AEvent: TJSEvent): Boolean;
var
  I: Integer;
  LAngle: Double;
begin
  Result := True;
  for I := 0 to MusicStyleCount - 1 do
  begin
    if window.innerWidth < 700 then
    begin
      FX[I] := 19 + (I mod 2) * 62;
      FY[I] := 10 + (I div 2) * 20;
    end
    else
    begin
      LAngle := I * 2 * Pi / MusicStyleCount - Pi / 2;
      FX[I] := 50 + 36 * Cos(LAngle);
      FY[I] := 50 + 35 * Sin(LAngle);
    end;
  end;
  PositionNodes;
end;

procedure TMusicDimension.Refresh;
var
  LRequest: TMusicRequest;
  LCount: Integer;
  LBpm: Double;
  I: Integer;
begin
  LRequest := Default(TMusicRequest);
  LRequest.FWeights := FWeights;
  LRequest.FTempo := FTempo;
  LBpm := MusicTempo(LRequest);
  Node('tempo-value').textContent := IntToStr(Round(LBpm));
  Node('music-bpm').textContent := IntToStr(Round(LBpm));
  TJSHTMLInputElement(Node('music-tempo')).value := IntToStr(Round(LBpm));
  Node('tempo-auto').setAttribute('aria-pressed', BoolToStr(FTempo = 0, 'true', 'false'));
  LCount := 0;
  for I := 0 to MusicStyleCount - 1 do
  begin
    TJSHTMLInputElement(Node('style-weight-' + IntToStr(I))).value := IntToStr(FWeights[I]);
    Node('style-node-' + IntToStr(I)).setAttribute('aria-pressed',
      BoolToStr(FWeights[I] > 0, 'true', 'false'));
    SetClass(FNodes[I], 'connected', FWeights[I] > 0);
    SetClass(FLinks[I], 'connected', FWeights[I] > 0);
    FLinks[I].setAttribute('stroke-width', FloatToStr(1 + FWeights[I] / 18));
    if FWeights[I] > 0 then
    begin
      Inc(LCount);
      FNodes[I].querySelector('.connection-word').textContent := IntToStr(FWeights[I]) + '%';
    end
    else
    begin
      FNodes[I].querySelector('.connection-word').textContent := 'Connect';
    end;
  end;
  Node('music-connected').textContent := IntToStr(LCount) + ' connected ' +
    ' / new track with every play';
end;

function TMusicDimension.Choose(AEvent: TJSEvent): Boolean;
var
  LButton: TJSElement;
  LIndex: Integer;
  LTotal: Integer;
  I: Integer;
begin
  Result := True;
  if FArrange then
  begin
    Exit;
  end;
  if FMoved then
  begin
    FMoved := False;
    Exit;
  end;
  LButton := TJSElement(AEvent.target).closest('[data-style]');
  LIndex := StrToInt(LButton.getAttribute('data-style'));
  LTotal := 0;
  for I := 0 to MusicStyleCount - 1 do
  begin
    Inc(LTotal, FWeights[I]);
  end;
  if (FWeights[LIndex] > 0) and (LTotal > FWeights[LIndex]) then
  begin
    FWeights[LIndex] := 0;
  end
  else if FWeights[LIndex] > 0 then
  begin
    Node('music-status').textContent := 'Connect another style before removing the last connection.';
    Exit;
  end
  else
  begin
    FWeights[LIndex] := 70;
  end;
  Refresh;
  FChanged(AEvent);
end;

function TMusicDimension.Weight(AEvent: TJSEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LIndex: Integer;
  LTotal: Integer;
  I: Integer;
begin
  Result := True;
  LInput := TJSHTMLInputElement(AEvent.target);
  LIndex := StrToInt(LInput.getAttribute('data-style'));
  FWeights[LIndex] := StrToInt(LInput.value);
  LTotal := 0;
  for I := 0 to MusicStyleCount - 1 do
  begin
    Inc(LTotal, FWeights[I]);
  end;
  if LTotal = 0 then
  begin
    FWeights[LIndex] := 1;
  end;
  Refresh;
end;

function TMusicDimension.Tempo(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FTempo := StrToInt(TJSHTMLInputElement(AEvent.target).value);
  Refresh;
end;

function TMusicDimension.AutoTempo(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FTempo := 0;
  Refresh;
  FChanged(AEvent);
end;

function TMusicDimension.PointerDown(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LButton: TJSElement;
begin
  Result := True;
  FMoved := False;
  LPointer := TJSPointerEvent(AEvent);
  if not FArrange and (LPointer.pointerType <> 'mouse') then
  begin
    Exit;
  end;
  LButton := TJSElement(AEvent.target).closest('[data-style]');
  FDragging := StrToInt(LButton.getAttribute('data-style'));
  FPointerX := LPointer.clientX;
  FPointerY := LPointer.clientY;
  FMoved := False;
  LButton.setPointerCapture(LPointer.pointerId);
end;

function TMusicDimension.PointerMove(AEvent: TJSEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LBounds: TJSDOMRect;
begin
  Result := True;
  if FDragging < 0 then
  begin
    Exit;
  end;
  LPointer := TJSPointerEvent(AEvent);
  if Abs(LPointer.clientX - FPointerX) + Abs(LPointer.clientY - FPointerY) < 6 then
  begin
    Exit;
  end;
  FMoved := True;
  LBounds := Node('music-space').getBoundingClientRect;
  FX[FDragging] := Max(18, Min(82, (LPointer.clientX - LBounds.left) / LBounds.width * 100));
  FY[FDragging] := Max(10, Min(90, (LPointer.clientY - LBounds.top) / LBounds.height * 100));
  PositionNodes;
end;

function TMusicDimension.PointerUp(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FDragging := -1;
  if AEvent._type = 'pointercancel' then
  begin
    FMoved := False;
  end;
end;

function TMusicDimension.Arrange(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  FArrange := not FArrange;
  FDragging := -1;
  FMoved := False;
  SetClass(Node('music-space'), 'arranging', FArrange);
  Node('music-arrange').setAttribute('aria-pressed', BoolToStr(FArrange, 'true', 'false'));
  if FArrange then
  begin
    Node('music-arrange').textContent := 'Done arranging';
    Node('music-space-hint').textContent := 'Drag a style or use its arrow keys. Reset restores spacing. Your sound stays the same.';
  end
  else
  begin
    Node('music-arrange').textContent := 'Arrange nodes';
    Node('music-space-hint').textContent := 'Tap to connect · swipe to scroll · adjust blend strength to change the sound';
  end;
end;

function TMusicDimension.ResetLayout(AEvent: TJSEvent): Boolean;
begin
  FDragging := -1;
  FMoved := False;
  Result := Resize(AEvent);
end;

function TMusicDimension.ArrangeKey(AEvent: TJSEvent): Boolean;
var
  LKey: String;
  LIndex: Integer;
begin
  Result := True;
  if not FArrange then
  begin
    Exit;
  end;
  LKey := TJSKeyboardEvent(AEvent).key;
  LIndex := StrToInt(TJSElement(AEvent.currentTarget).getAttribute('data-style'));
  case LKey of
    'ArrowLeft': FX[LIndex] := Max(18, FX[LIndex] - 5);
    'ArrowRight': FX[LIndex] := Min(82, FX[LIndex] + 5);
    'ArrowUp': FY[LIndex] := Max(10, FY[LIndex] - 5);
    'ArrowDown': FY[LIndex] := Min(90, FY[LIndex] + 5);
    else Exit;
  end;
  AEvent.preventDefault;
  PositionNodes;
end;

procedure TMusicDimension.Update(const AStats: TJSObject);
var
  LTrack: TJSObject;
  LSection: TJSObject;
  LPhases: TJSArray;
  LSegment: TJSHTMLElement;
  LStyle: Integer;
  LBeat: Integer;
  LProgress: Double;
  I: Integer;
begin
  if not Node('audio-panel').classList.contains('audio-visible') then
  begin
    Exit;
  end;
  LTrack := TJSObject(AStats['track']);
  if not isObject(LTrack) or (LTrack = nil) then
  begin
    Node('track-clock').textContent := '5+ minutes / composed for this moment';
    Exit;
  end;
  if FLastTrack <> String(LTrack['id']) + ':' + IntToStr(TJSArray(LTrack['phases']).Length) then
  begin
    FLastTrack := String(LTrack['id']) + ':' + IntToStr(TJSArray(LTrack['phases']).Length);
    Node('track-form').textContent := '';
    LPhases := TJSArray(LTrack['phases']);
    for I := 0 to LPhases.Length - 1 do
    begin
      LSegment := TJSHTMLElement(document.createElement('span'));
      LSegment.className := 'track-segment phase-' + IntToStr(Integer(LPhases[I]));
      LSegment.title := TrackPhaseName(Integer(LPhases[I]));
      Node('track-form').appendChild(LSegment);
    end;
  end;
  Node('track-clock').textContent := TimeText(Double(LTrack['elapsed'])) + ' / ' +
    TimeText(Double(LTrack['seconds']));
  if isNumber(LTrack['phase']) then
  begin
    Node('track-phase').textContent := TrackPhaseName(Integer(LTrack['phase']));
  end;
  LProgress := Double(LTrack['elapsed']) / Double(LTrack['seconds']);
  Node('track-position').style.setProperty('width', FloatToStr(LProgress * 100) + '%');
  if not isNumber(LTrack['beat']) then
  begin
    Exit;
  end;
  LBeat := Trunc(Double(LTrack['beat']));
  if (LBeat <> FLastBeat) and isBoolean(AStats['playing']) and Boolean(AStats['playing']) then
  begin
    FLastBeat := LBeat;
    Node('music-heart').classList.remove('beat-pulse');
    // Alternate the pulse class, avoiding forced layout on the audio scheduler's tick.
    SetClass(Node('music-heart'), 'beat-even', LBeat mod 2 = 0);
    SetClass(Node('music-heart'), 'beat-odd', LBeat mod 2 = 1);
    for I := 0 to 3 do
    begin
      SetClass(Node('beat-' + IntToStr(I)), 'active', LBeat mod 4 = I);
    end;
  end;
  LStyle := -1;
  LSection := TJSObject(AStats['section']);
  if isObject(LSection) and (LSection <> nil) then
  begin
    LStyle := Integer(TJSArray(LSection['styles'])[Min(7, LBeat div 4)]);
  end;
  for I := 0 to MusicStyleCount - 1 do
  begin
    SetClass(FNodes[I], 'sounding', I = LStyle);
    SetClass(FLinks[I], 'sounding', I = LStyle);
  end;
end;

procedure StartMusicDimension(const AChanged: WebOrWorker.TJSEventHandler);
begin
  GDimension := TMusicDimension.Create(AChanged);
end;

function MusicDimensionWeights: TJSArray;
var
  I: Integer;
begin
  Result := TJSArray.new;
  for I := 0 to MusicStyleCount - 1 do
  begin
    Result.push(GDimension.FWeights[I]);
  end;
end;

function MusicDimensionTempo: Integer;
begin
  Result := GDimension.FTempo;
end;

procedure UseMusicDimensionPair;
var
  LRequest: TMusicRequest;
begin
  LRequest := Default(TMusicRequest);
  LRequest.FStyle := StrToInt(TJSHTMLSelectElement(Node('music-style')).value);
  LRequest.FBlendStyle := StrToInt(TJSHTMLSelectElement(Node('music-blend-style')).value);
  LRequest.FBlend := StrToInt(TJSHTMLInputElement(Node('music-blend')).value);
  GDimension.FWeights := MusicWeights(LRequest);
  GDimension.Refresh;
end;

procedure UpdateMusicDimension(const AStats: TJSObject);
begin
  if GDimension <> nil then
  begin
    GDimension.Update(AStats);
  end;
end;

end.
