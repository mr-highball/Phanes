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

unit phanes.landforms.ui;
{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartLandformUI;

implementation

uses
  JS, Web, SysUtils, phanes.landforms.types;

type
  TEditorState = class external name 'Object'(TJSObject)
    world: TJSObject;
    worker: TJSObject;
    selection: TJSObject;
    interiorRoom: String;
    editing: Boolean;
  end;

  TEditorActions = class external name 'Object'(TJSObject)
    procedure generate(const AOperation: String; const AImported, AOptions: TJSObject);
    procedure cancelPointer;
    procedure updateControls;
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TLandformUI = class
  private
    FState: TEditorState;
    FActions: TEditorActions;
    FActive: Boolean;
    function Click(AEvent: TJSEvent): Boolean;
  public
    constructor Create;
    procedure Refresh;
    function Snapshot: TJSObject;
    procedure RestoreCheckpoint(const AValue: TJSObject);
  end;

var
  GLandformUI: TLandformUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

constructor TLandformUI.Create;
var
  LButtons: TJSNodeList;
  LBridge: TJSObject;
  I: Integer;
begin
  FState := TEditorState(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  LButtons := document.querySelectorAll('[data-landform]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButtons[I].addEventListener('click', @Click);
  end;
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  LBridge['snapshot'] := @Snapshot;
  LBridge['restoreCheckpoint'] := @RestoreCheckpoint;
  TJSObject(window)['phanesLandformUI'] := LBridge;
  Refresh;
end;

function TLandformUI.Click(AEvent: TJSEvent): Boolean;
var
  LAction: String;
  LOptions: TJSObject;
begin
  Result := True;
  if (FState.world = nil) or (FState.worker <> nil) or not FState.editing then
  begin
    Exit;
  end;
  LAction := TJSHTMLElement(AEvent.currentTarget).getAttribute('data-landform');
  if LAction = 'open' then
  begin
    FActive := True;
    Refresh;
    if TJSHTMLSelectElement(Element('selection-scale')).value = '8' then
    begin
      TJSHTMLSelectElement(Element('selection-scale')).value := '1';
      Element('selection-scale').dispatchEvent(TJSEvent.new('change'));
    end;
    TJSHTMLSelectElement(Element('selection-layer')).value := 'terrain';
    TJSHTMLElement(document.querySelector('[data-authoring-tool="brush"]')).click;
    Element('tools-panel').scrollTop := 0;
    FActions.notify('Brush a region, then raise it, lower it or imagine hills. Its boundary stays in place.', False);
  end
  else if LAction = 'leave' then
  begin
    FActive := False;
  end
  else if LAction = 'draw' then
  begin
    FActions.cancelPointer;
    TJSHTMLElement(document.querySelector('[data-authoring-tool="brush"]')).click;
  end
  else if (LAction = 'undo') or (LAction = 'redo') then
  begin
    Element(LAction).click;
  end
  else if IsLandformOperation(LAction) then
  begin
    LOptions := TJSObject.new;
    LOptions['editLayer'] := 'terrain';
    LOptions['landformAmount'] := StrToInt(TJSHTMLSelectElement(Element('landform-amount')).value);
    FActions.generate(LAction, nil, LOptions);
  end;
  FActions.updateControls;
end;

procedure TLandformUI.Refresh;
var
  LReady: Boolean;
  LButtons: TJSNodeList;
  LOptions: TJSHTMLSelectElement;
  LOption: TJSHTMLOptionElement;
  LStep: Integer;
  LValue: Integer;
  I: Integer;
begin
  if (FState.interiorRoom <> '') or
    (document.body.getAttribute('data-groundworks') = 'true') or
    (document.body.getAttribute('data-modular') = 'true') then
  begin
    FActive := False;
  end;
  LReady := (FState.world <> nil) and (FState.worker = nil) and FState.editing;
  document.body.setAttribute('data-landforms', LowerCase(BoolToStr(FActive, True)));
  Element('landform-tools').hidden := not FActive;
  TJSHTMLOptionElement(Element('selection-scale').querySelector('option[value="8"]')).disabled := FActive;
  LButtons := document.querySelectorAll('[data-landform]');
  for I := 0 to LButtons.length - 1 do
  begin
    TJSHTMLButtonElement(LButtons[I]).disabled := not LReady;
  end;
  TJSHTMLButtonElement(Element('landform-undo')).disabled := not LReady or
    TJSHTMLButtonElement(Element('undo')).disabled;
  TJSHTMLButtonElement(Element('landform-redo')).disabled := not LReady or
    TJSHTMLButtonElement(Element('redo')).disabled;
  LOptions := TJSHTMLSelectElement(Element('landform-amount'));
  LOptions.disabled := not LReady;
  LStep := 250;
  if (FState.world <> nil) and isObject(FState.world['elevation']) then
  begin
    LStep := Integer(TJSObject(FState.world['elevation'])['levelStep']);
  end;
  for I := 0 to LOptions.options.length - 1 do
  begin
    LOption := TJSHTMLOptionElement(LOptions.options[I]);
    LValue := StrToInt(LOption.value);
    LOption.disabled := (LValue < LStep) or (LValue mod LStep <> 0);
  end;
  LValue := StrToInt(LOptions.value);
  if (LValue < LStep) or (LValue mod LStep <> 0) then
  begin
    LOption := TJSHTMLOptionElement(LOptions.querySelector('option[value="' + IntToStr(LStep) + '"]'));
    if LOption = nil then
    begin
      LOption := TJSHTMLOptionElement(document.createElement('option'));
      LOption.value := IntToStr(LStep);
      LOption.textContent := FloatToStr(LStep / 1000) + ' m';
      LOptions.appendChild(LOption);
    end;
    LOptions.value := IntToStr(LStep);
  end;
end;

function TLandformUI.Snapshot: TJSObject;
begin
  Result := TJSObject.new;
  Result['active'] := FActive;
  Result['amount'] := StrToInt(TJSHTMLSelectElement(Element('landform-amount')).value);
end;

procedure TLandformUI.RestoreCheckpoint(const AValue: TJSObject);
var
  LOption: TJSHTMLOptionElement;
  LAmount: String;
begin
  if AValue = nil then
  begin
    Exit;
  end;
  FActive := AValue['active'] = True;
  LAmount := IntToStr(Integer(AValue['amount']));
  if Element('landform-amount').querySelector('option[value="' + LAmount + '"]') = nil then
  begin
    LOption := TJSHTMLOptionElement(document.createElement('option'));
    LOption.value := LAmount;
    LOption.textContent := FloatToStr(Integer(AValue['amount']) / 1000) + ' m';
    Element('landform-amount').appendChild(LOption);
  end;
  TJSHTMLSelectElement(Element('landform-amount')).value := LAmount;
  Refresh;
end;

procedure StartLandformUI;
begin
  GLandformUI := TLandformUI.Create;
end;

end.
