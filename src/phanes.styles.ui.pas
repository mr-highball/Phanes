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

unit phanes.styles.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartStyleUI;

implementation

uses
  JS,
  Web,
  SysUtils,
  phanes.styles.catalog;

type
  TStyleVisualViewport = class external name 'VisualViewport'(TJSEventTarget)
    height: Double;
    offsetTop: Double;
  end;

  TStyleWindow = class external name 'Window'(TJSWindow)
    visualViewport: TStyleVisualViewport;
  end;

  TStyleUI = class
  private
    FIndex: Integer;
    FRevision: Integer;
    FStrength: Double;
    FDetail: Double;
    FComparing: Boolean;
    FUnavailable: Boolean;
    FRequestedAt: Double;
    FGroup: String;
    function Click(AEvent: TJSEvent): Boolean;
    function InputChanged(AEvent: TJSEvent): Boolean;
    function KeyDown(AEvent: TJSEvent): Boolean;
    function FitViewport(AEvent: TJSEvent): Boolean;
    procedure Filter;
    procedure Publish;
    procedure Refresh;
    procedure SetOpen(const AOpen: Boolean);
  public
    constructor Create;
    procedure Rendered(const ARevision: Integer; const AApplied: Boolean);
    function Snapshot: TJSObject;
    procedure RestoreCheckpoint(const AValue: TJSObject);
  end;

var
  GStyles: TStyleUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

function Input(const AId: String): TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(document.getElementById(AId));
end;

function GroupSelect: TJSHTMLSelectElement;
begin
  Result := TJSHTMLSelectElement(document.getElementById('style-group'));
end;

constructor TStyleUI.Create;
var
  I: Integer;
  LButton: TJSHTMLElement;
  LSwatch: TJSHTMLElement;
  LLabel: TJSHTMLElement;
  LDescription: TJSHTMLElement;
  LBridge: TJSObject;
begin
  inherited Create;
  FStrength := 1;
  FDetail := 0.5;
  FGroup := 'All';
  TJSObject(window)['phanesStyleRendered'] := @Rendered;
  LBridge := TJSObject.new;
  LBridge['snapshot'] := @Snapshot;
  LBridge['restoreCheckpoint'] := @RestoreCheckpoint;
  TJSObject(window)['phanesStyleUI'] := LBridge;
  for I := 0 to VisualStyleCount - 1 do
  begin
    LButton := TJSHTMLElement(document.createElement('button'));
    LButton.id := 'style-choice-' + VisualStyles[I].FId;
    LButton.className := 'style-choice';
    LButton.setAttribute('data-style-id', VisualStyles[I].FId);
    LButton.setAttribute('aria-pressed', 'false');
    LButton.addEventListener('click', @Click);
    LSwatch := TJSHTMLElement(document.createElement('span'));
    LSwatch.className := 'style-swatch';
    LSwatch.setAttribute('data-look', VisualStyles[I].FId);
    LSwatch.setAttribute('aria-hidden', 'true');
    LButton.appendChild(LSwatch);
    LLabel := TJSHTMLElement(document.createElement('strong'));
    LLabel.textContent := VisualStyles[I].FName;
    LButton.appendChild(LLabel);
    LDescription := TJSHTMLElement(document.createElement('small'));
    LDescription.textContent := VisualStyles[I].FDescription;
    LButton.appendChild(LDescription);
    Element('style-choices').appendChild(LButton);
  end;
  Element('open-styles').addEventListener('click', @Click);
  Element('close-styles').addEventListener('click', @Click);
  Element('style-reset').addEventListener('click', @Click);
  Element('style-compare').addEventListener('click', @Click);
  Element('style-panel').addEventListener('keydown', @KeyDown);
  Element('open-audio').addEventListener('click', @Click);
  Input('style-strength').addEventListener('input', @InputChanged);
  Input('style-detail').addEventListener('input', @InputChanged);
  Input('style-search').addEventListener('input', @InputChanged);
  GroupSelect.addEventListener('change', @InputChanged);
  window.addEventListener('resize', @FitViewport);
  if Assigned(TStyleWindow(window).visualViewport) then
  begin
    TStyleWindow(window).visualViewport.addEventListener('resize', @FitViewport);
    TStyleWindow(window).visualViewport.addEventListener('scroll', @FitViewport);
  end;
  FitViewport(nil);
  Publish;
  Refresh;
end;

procedure TStyleUI.SetOpen(const AOpen: Boolean);
begin
  Element('style-panel').hidden := not AOpen;
  Element('open-styles').setAttribute('aria-expanded', LowerCase(BoolToStr(AOpen, True)));
  if AOpen then
  begin
    if Element('audio-panel').classList.contains('audio-visible') then
    begin
      Element('close-audio').click;
    end;
    FitViewport(nil);
    window.dispatchEvent(TJSEvent.new('blur'));
    if Element('style-choice-' + VisualStyles[FIndex].FId).hidden then
    begin
      Input('style-search').focus;
    end else
    begin
      Element('style-choice-' + VisualStyles[FIndex].FId).focus;
    end;
  end else
  begin
    if FComparing then
    begin
      FComparing := False;
      Publish;
      Refresh;
    end;
    Element('open-styles').focus;
  end;
end;

function TStyleUI.FitViewport(AEvent: TJSEvent): Boolean;
var
  LHeight: Double;
  LTop: Double;
  LViewport: TStyleVisualViewport;
begin
  Result := True;
  LHeight := window.innerHeight;
  LTop := 0;
  LViewport := TStyleWindow(window).visualViewport;
  if Assigned(LViewport) then
  begin
    LHeight := LViewport.height;
    LTop := LViewport.offsetTop;
  end;
  Element('style-panel').style.setProperty('--style-height', FloatToStr(LHeight) + 'px');
  Element('style-panel').style.setProperty('--style-top', FloatToStr(LTop) + 'px');
  Element('style-panel').setAttribute('data-compact', LowerCase(BoolToStr(LHeight < 600, True)));
end;

procedure TStyleUI.Filter;
var
  I: Integer;
  LQuery: String;
  LMatch: Boolean;
  LCount: Integer;
  LText: String;
begin
  LQuery := LowerCase(Trim(Input('style-search').value));
  FGroup := GroupSelect.value;
  LCount := 0;
  for I := 0 to VisualStyleCount - 1 do
  begin
    LText := LowerCase(VisualStyles[I].FName + ' ' + VisualStyles[I].FDescription +
      ' ' + VisualStyles[I].FGroup);
    LMatch := ((FGroup = 'All') or (VisualStyles[I].FGroup = FGroup)) and
      ((LQuery = '') or (Pos(LQuery, LText) > 0));
    Element('style-choice-' + VisualStyles[I].FId).hidden := not LMatch;
    if LMatch then
    begin
      Inc(LCount);
    end;
  end;
  Element('style-empty').hidden := LCount > 0;
end;

procedure TStyleUI.Refresh;
var
  I: Integer;
  LActive: Boolean;
begin
  for I := 0 to VisualStyleCount - 1 do
  begin
    Element('style-choice-' + VisualStyles[I].FId).setAttribute('aria-pressed',
      LowerCase(BoolToStr(I = FIndex, True)));
  end;
  Element('style-current').textContent := VisualStyles[FIndex].FName;
  Element('style-detail-label').textContent := VisualStyles[FIndex].FDetailName;
  Input('style-strength').value := IntToStr(Round(FStrength * 100));
  Input('style-detail').value := IntToStr(Round(FDetail * 100));
  Element('style-strength-value').textContent := IntToStr(Round(FStrength * 100)) + '%';
  Element('style-detail-value').textContent := IntToStr(Round(FDetail * 100)) + '%';
  LActive := FIndex > 0;
  Input('style-strength').disabled := not LActive;
  Input('style-detail').disabled := not LActive;
  TJSHTMLButtonElement(Element('style-compare')).disabled := not LActive;
  Element('style-compare').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FComparing, True)));
  if FComparing then
  begin
    Element('style-compare').textContent := 'Return to style';
  end else
  begin
    Element('style-compare').textContent := 'Compare original';
  end;
  Filter;
end;

procedure TStyleUI.Publish;
begin
  FRequestedAt := window.performance.now;
  Inc(FRevision);
  if FComparing then
  begin
    TJSObject(window)['phanesStyleId'] := 'none';
  end else
  begin
    TJSObject(window)['phanesStyleId'] := VisualStyles[FIndex].FId;
  end;
  TJSObject(window)['phanesStyleStrength'] := FStrength;
  TJSObject(window)['phanesStyleDetail'] := FDetail;
  TJSObject(window)['phanesStyleRevision'] := FRevision;
  Element('style-status').textContent := 'Applying to your world...';
  Element('style-panel').setAttribute('aria-busy', 'true');
end;

procedure TStyleUI.Rendered(const ARevision: Integer; const AApplied: Boolean);
begin
  if ARevision <> FRevision then
  begin
    Exit;
  end;
  Element('style-panel').setAttribute('aria-busy', 'false');
  TJSObject(window)['phanesStyleElapsedMs'] := window.performance.now - FRequestedAt;
  if not AApplied then
  begin
    FUnavailable := True;
    FIndex := 0;
    FComparing := False;
    Publish;
    Refresh;
    Element('style-status').textContent := 'This effect is unavailable. Original view restored.';
    Exit;
  end;
  if FUnavailable then
  begin
    Element('style-status').textContent := 'This effect is unavailable. Original view restored.';
  end else if FComparing then
  begin
    Element('style-status').textContent := 'Comparing the original view';
  end else if (FIndex = 0) or (FStrength = 0) then
  begin
    Element('style-status').textContent := 'Original rendered view';
  end else
  begin
    Element('style-status').textContent := VisualStyles[FIndex].FName + ' is live';
  end;
  Element('style-panel').setAttribute('data-rendered-revision', IntToStr(ARevision));
end;

function TStyleUI.Click(AEvent: TJSEvent): Boolean;
var
  LTarget: TJSHTMLElement;
  LId: String;
  LIndex: Integer;
begin
  Result := True;
  LTarget := TJSHTMLElement(AEvent.currentTarget);
  LId := LTarget.id;
  if LId = 'open-audio' then
  begin
    if not Element('style-panel').hidden then
    begin
      SetOpen(False);
      Element('open-audio').focus;
    end;
    Exit;
  end;
  AEvent.stopPropagation;
  if LId = 'open-styles' then
  begin
    SetOpen(Element('style-panel').hidden);
    Exit;
  end;
  if LId = 'close-styles' then
  begin
    SetOpen(False);
    Exit;
  end;
  if LId = 'style-compare' then
  begin
    FComparing := not FComparing;
  end else
  begin
    LIndex := VisualStyleIndex(LTarget.getAttribute('data-style-id'));
    if LId = 'style-reset' then
    begin
      LIndex := 0;
      Input('style-search').value := '';
      GroupSelect.value := 'All';
    end;
    if LIndex < 0 then
    begin
      Exit;
    end;
    FIndex := LIndex;
    FComparing := False;
    FStrength := 1;
    FDetail := DefaultStyleDetail(FIndex);
  end;
  FUnavailable := False;
  Publish;
  Refresh;
end;

function TStyleUI.InputChanged(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  AEvent.stopPropagation;
  if (TJSHTMLElement(AEvent.currentTarget).id = 'style-search') or
    (TJSHTMLElement(AEvent.currentTarget).id = 'style-group') then
  begin
    Filter;
    Exit;
  end;
  FStrength := StrToIntDef(Input('style-strength').value, 100) / 100;
  FDetail := StrToIntDef(Input('style-detail').value, 50) / 100;
  FComparing := False;
  FUnavailable := False;
  Publish;
  Refresh;
end;

function TStyleUI.KeyDown(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  AEvent.stopPropagation;
  if TJSKeyboardEvent(AEvent).key = 'Escape' then
  begin
    AEvent.preventDefault;
    SetOpen(False);
  end;
end;

function TStyleUI.Snapshot: TJSObject;
begin
  Result := TJSObject.new;
  Result['id'] := VisualStyles[FIndex].FId;
  Result['strength'] := FStrength;
  Result['detail'] := FDetail;
end;

procedure TStyleUI.RestoreCheckpoint(const AValue: TJSObject);
var
  I: Integer;
begin
  if AValue = nil then
  begin
    Exit;
  end;
  for I := 0 to VisualStyleCount - 1 do
  begin
    if AValue['id'] = VisualStyles[I].FId then
    begin
      FIndex := I;
      FStrength := Double(AValue['strength']);
      FDetail := Double(AValue['detail']);
      FComparing := False;
      Publish;
      Refresh;
      Exit;
    end;
  end;
end;

procedure StartStyleUI;
begin
  GStyles := TStyleUI.Create;
end;

end.
