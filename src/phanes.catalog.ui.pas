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


unit phanes.catalog.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartCatalogUI;

implementation

uses
  JS, Web, SysUtils, Classes;

type
  TCatalogState = class external name 'Object'(TJSObject)
    world: TJSObject;
    palette: TJSObject;
    selection: TJSObject;
    worker: TJSObject;
    editing: Boolean;
  end;

  TCatalogActions = class external name 'Object'(TJSObject)
    procedure generate(const AOperation: String; const AImported, AOptions: TJSObject);
  end;

  TCatalogUI = class
  private
    FState: TCatalogState;
    FActions: TCatalogActions;
    FCategory: String;
    FCategoryName: String;
    FGroup: String;
    FOperation: String;
    FExact: String;
    FLayer: String;
    FChoice: String;
    FChoices: TJSArray;
    FReady: Boolean;
    function CategoryAsset(const AAsset: TJSObject): Boolean;
    function GroupKey(const AAsset: TJSObject): String;
    function GroupName(const AKey: String): String;
    function Click(AEvent: TJSEvent): Boolean;
    function Search(AEvent: TJSEvent): Boolean;
    function ScopeChanged(AEvent: TJSEvent): Boolean;
    function ScopeMatches: Boolean;
    procedure ClearChoice;
    procedure Draw;
    procedure AddChoice(const AName, ADetail, AKey, AValue: String);
  public
    constructor Create;
    procedure Refresh;
  end;

var
  GCatalog: TCatalogUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

constructor TCatalogUI.Create;
var
  LButtons: TJSNodeList;
  LBridge: TJSObject;
  I: Integer;
begin
  inherited Create;
  FState := TCatalogState(TJSObject(window)['phanesEditor']);
  FActions := TCatalogActions(TJSObject(window)['phanesEditorActions']);
  LButtons := document.querySelectorAll('[data-intent]');
  for I := 0 to LButtons.length - 1 do
  begin
    LButtons[I].addEventListener('click', @Click);
  end;
  Element('catalog-back').addEventListener('click', @Click);
  Element('catalog-results').addEventListener('click', @Click);
  Element('catalog-apply').addEventListener('click', @Click);
  Element('catalog-search').addEventListener('input', @Search);
  Element('selection-layer').addEventListener('change', @ScopeChanged);
  Element('selection-scale').addEventListener('change', @ScopeChanged);
  LBridge := TJSObject.new;
  LBridge['refresh'] := @Refresh;
  TJSObject(window)['phanesCatalogUI'] := LBridge;
end;

function TCatalogUI.CategoryAsset(const AAsset: TJSObject): Boolean;
var
  LKind: String;
begin
  LKind := String(AAsset['kind']);
  case FCategory of
    'forest': Result := (LKind = 'tree') or (LKind = 'shrub') or (LKind = 'rock');
    'flowers': Result := LKind = 'flowers';
    'field': Result := (LKind = 'wheat') or (LKind = 'flowers');
    'rocket': Result := (LKind = 'scifi') or (String(AAsset['id']) = 'space-kit/rock_crystals');
    'scifi': Result := (LKind = 'scifi') and (String(AAsset['id']) <> 'rocket');
    else Result := LKind = FCategory;
  end;
end;

function TCatalogUI.GroupKey(const AAsset: TJSObject): String;
begin
  Result := String(AAsset['kind']);
  if String(AAsset['id']) = 'rocket' then
  begin
    Result := 'rocket';
  end;
end;

function TCatalogUI.GroupName(const AKey: String): String;
begin
  case AKey of
    'tree': Result := 'Trees';
    'shrub': Result := 'Shrubs';
    'rock': Result := 'Stones & crystals';
    'flowers': Result := 'Flowers';
    'wheat': Result := 'Crops';
    'cabin': Result := 'Cabin shells';
    'castle': Result := 'Keeps';
    'modern': Result := 'Houses';
    'scifi': Result := 'Habitats & stations';
    'rocket': Result := 'Spacecraft';
    else Result := AKey;
  end;
end;

procedure TCatalogUI.AddChoice(const AName, ADetail, AKey, AValue: String);
var
  LButton: TJSHTMLElement;
  LSmall: TJSHTMLElement;
begin
  LButton := TJSHTMLElement(document.createElement('button'));
  LButton.setAttribute('data-catalog-' + AKey, AValue);
  LButton.textContent := AName;
  LSmall := TJSHTMLElement(document.createElement('small'));
  LSmall.textContent := ADetail;
  LButton.appendChild(LSmall);
  if AKey = 'asset' then
  begin
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(FExact = AValue, True)));
  end;
  Element('catalog-results').appendChild(LButton);
end;

procedure TCatalogUI.ClearChoice;
begin
  FReady := False;
  FChoice := '';
  FExact := '';
  FChoices := nil;
  FOperation := '';
  FLayer := '';
end;

procedure TCatalogUI.Draw;
var
  LAssets: TJSArray;
  LAsset: TJSObject;
  LGroups: TStringList;
  LSearch: String;
  LGroup: String;
  LDetail: String;
  I: Integer;
begin
  Element('catalog-browser').hidden := FCategory = '';
  if FCategory <> '' then
  begin
    document.body.classList.add('catalog-open');
  end else
  begin
    document.body.classList.remove('catalog-open');
  end;
  if (FCategory = '') or (FState.palette = nil) then
  begin
    Exit;
  end;
  Element('catalog-title').textContent := FCategoryName;
  Element('catalog-path').textContent := 'Categories / ' + FCategoryName;
  Element('catalog-back').textContent := 'All categories';
  if FGroup <> '' then
  begin
    Element('catalog-title').textContent := GroupName(FGroup);
    Element('catalog-path').textContent := Element('catalog-path').textContent + ' / ' + GroupName(FGroup);
    Element('catalog-back').textContent := 'Back to ' + FCategoryName;
  end;
  Element('catalog-results').textContent := '';
  LSearch := LowerCase(Trim(TJSHTMLInputElement(Element('catalog-search')).value));
  LAssets := TJSArray(FState.palette['assets']);
  LGroups := TStringList.Create;
  try
    if LSearch = '' then
    begin
      if FGroup = '' then
      begin
        if (FCategory = 'forest') or (FCategory = 'flowers') or (FCategory = 'field') or
          (FCategory = 'water') then
        begin
          AddChoice('Compose ' + LowerCase(FCategoryName), 'Landscape and compatible objects',
            'landscape', FCategory);
        end;
      end else
      begin
        LDetail := 'A compatible model from this group in each selected cell';
        if (FGroup = 'tree') or (FGroup = 'shrub') or (FGroup = 'rock') or
          (FGroup = 'flowers') or (FGroup = 'wheat') then
        begin
          LDetail := 'A mixture of up to 8 models across the selection';
        end;
        AddChoice('Let WFC choose ' + LowerCase(GroupName(FGroup)),
          LDetail, 'group-choice', FGroup);
      end;
    end;
    for I := 0 to LAssets.Length - 1 do
    begin
      LAsset := TJSObject(LAssets[I]);
      if not CategoryAsset(LAsset) then
      begin
        Continue;
      end;
      LGroup := GroupKey(LAsset);
      if (FGroup <> '') and (LGroup <> FGroup) then
      begin
        Continue;
      end;
      if (LSearch <> '') and
        (Pos(LSearch, LowerCase(String(LAsset['name']) + ' ' + LGroup + ' ' + String(LAsset['id']))) = 0) then
      begin
        Continue;
      end;
      if (FGroup = '') and (LSearch = '') then
      begin
        if LGroups.IndexOf(LGroup) < 0 then
        begin
          LGroups.Add(LGroup);
          AddChoice(GroupName(LGroup), 'Browse individual items', 'group', LGroup);
        end;
      end else
      begin
        LDetail := 'Exact model';
        if isInteger(LAsset['cluster']) then
        begin
          LDetail := 'Exact model · a cluster in each selected foliage cell';
        end;
        AddChoice(String(LAsset['name']), LDetail, 'asset', String(LAsset['id']));
      end;
    end;
    if Element('catalog-results').childElementCount = 0 then
    begin
      Element('catalog-results').textContent := 'No matching placeable items in this category.';
    end;
  finally
    LGroups.Free;
  end;
  Refresh;
end;

function TCatalogUI.Click(AEvent: TJSEvent): Boolean;
var
  LButton: TJSElement;
  LAssets: TJSArray;
  LAsset: TJSObject;
  LOptions: TJSObject;
  I: Integer;
begin
  Result := True;
  LButton := TJSElement(AEvent.target).closest('button');
  if LButton = nil then
  begin
    Exit;
  end;
  if LButton.id = 'catalog-apply' then
  begin
    if not FReady or not ScopeMatches or
      TJSHTMLButtonElement(Element('catalog-apply')).disabled then
    begin
      Exit;
    end;
    LOptions := TJSObject.new;
    LOptions['editLayer'] := TJSHTMLSelectElement(Element('selection-layer')).value;
    if FChoices <> nil then
    begin
      LOptions['assetChoices'] := FChoices;
    end;
    if FExact <> '' then
    begin
      LOptions['exactAsset'] := FExact;
    end;
    FActions.generate(FOperation, nil, LOptions);
    Exit;
  end;
  if LButton.hasAttribute('data-intent') then
  begin
    FCategory := LButton.getAttribute('data-intent');
    FCategoryName := TJSHTMLElement(LButton.querySelector('span')).firstChild.textContent;
    FGroup := '';
    ClearChoice;
    TJSHTMLInputElement(Element('catalog-search')).value := '';
  end
  else if LButton.id = 'catalog-back' then
  begin
    ClearChoice;
    if FGroup <> '' then
    begin
      FGroup := '';
    end else
    begin
      FCategory := '';
    end;
    TJSHTMLInputElement(Element('catalog-search')).value := '';
  end
  else if LButton.hasAttribute('data-catalog-group') then
  begin
    ClearChoice;
    FGroup := LButton.getAttribute('data-catalog-group');
  end
  else
  begin
    FExact := '';
    FChoices := nil;
    FReady := True;
    FLayer := '';
    if LButton.hasAttribute('data-catalog-landscape') then
    begin
      FOperation := LButton.getAttribute('data-catalog-landscape');
      FChoice := 'Compose ' + LowerCase(FCategoryName) + ' in the selection';
    end
    else if LButton.hasAttribute('data-catalog-group-choice') then
    begin
      FOperation := LButton.getAttribute('data-catalog-group-choice');
      FChoices := TJSArray.new;
      LAssets := TJSArray(FState.palette['assets']);
      for I := 0 to LAssets.Length - 1 do
      begin
        LAsset := TJSObject(LAssets[I]);
        if CategoryAsset(LAsset) and (GroupKey(LAsset) = FOperation) then
        begin
          FChoices.push(LAsset['id']);
        end;
      end;
      FChoice := 'WFC chooses ' + LowerCase(GroupName(FOperation));
      if (FOperation = 'cabin') or (FOperation = 'castle') or (FOperation = 'modern') or
        (FOperation = 'scifi') or (FOperation = 'rocket') then
      begin
        FLayer := 'buildings';
      end else
      begin
        FLayer := 'foliage';
      end;
    end
    else if LButton.hasAttribute('data-catalog-asset') then
    begin
      FExact := LButton.getAttribute('data-catalog-asset');
      FOperation := 'asset';
      LAssets := TJSArray(FState.palette['assets']);
      for I := 0 to LAssets.Length - 1 do
      begin
        LAsset := TJSObject(LAssets[I]);
        if String(LAsset['id']) = FExact then
        begin
          FChoice := String(LAsset['name']);
          if (String(LAsset['kind']) = 'cabin') or (String(LAsset['kind']) = 'castle') or
            (String(LAsset['kind']) = 'modern') or (String(LAsset['kind']) = 'scifi') then
          begin
            FLayer := 'buildings';
          end else
          begin
            FLayer := 'foliage';
          end;
          Break;
        end;
      end;
    end;
    TJSHTMLSelectElement(Element('selection-layer')).value := FLayer;
  end;
  Draw;
  if LButton.hasAttribute('data-catalog-asset') or
    LButton.hasAttribute('data-catalog-group-choice') or LButton.hasAttribute('data-catalog-landscape') then
  begin
    if TJSHTMLButtonElement(Element('catalog-apply')).disabled then
    begin
      Element('catalog-choice').focus;
    end else
    begin
      Element('catalog-apply').focus;
    end;
    Element('catalog-confirm').scrollIntoView(False);
  end else if FCategory <> '' then
  begin
    Element('catalog-title').focus;
    Element('catalog-browser').scrollIntoView;
  end else
  begin
    TJSHTMLElement(document.querySelector('[data-intent]')).focus;
  end;
end;

function TCatalogUI.Search(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  Draw;
end;

function TCatalogUI.ScopeChanged(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  Refresh;
end;

function TCatalogUI.ScopeMatches: Boolean;
var
  LLayer: String;
begin
  LLayer := TJSHTMLSelectElement(Element('selection-layer')).value;
  if FLayer <> '' then
  begin
    Result := LLayer = FLayer;
  end else
  begin
    Result := (LLayer = '') or (LLayer = 'terrain') or
      ((LLayer = 'foliage') and (FOperation <> 'water'));
  end;
end;

procedure TCatalogUI.Refresh;
var
  LEmpty: Boolean;
begin
  Element('catalog-confirm').hidden := not FReady;
  LEmpty := False;
  if isArray(FState.selection['selectionCells']) then
  begin
    LEmpty := TJSArray(FState.selection['selectionCells']).Length = 0;
  end;
  TJSHTMLButtonElement(Element('catalog-apply')).disabled := not FReady or
    (FState.world = nil) or (FState.worker <> nil) or not FState.editing or LEmpty or not ScopeMatches;
  if FChoice = '' then
  begin
    Element('catalog-choice').textContent := 'Browse a subcategory, then choose a group or exact item.';
  end else
  begin
    Element('catalog-choice').textContent := FChoice + ' · ' + Element('selection-size').textContent;
    if not ScopeMatches then
    begin
      if FLayer = 'foliage' then
      begin
        Element('catalog-choice').textContent := FChoice + ' · choose Foliage only under Change.';
      end else if FLayer = 'buildings' then
      begin
        Element('catalog-choice').textContent := FChoice + ' · choose Buildings & their clearance under Change.';
      end else
      begin
        Element('catalog-choice').textContent := FChoice + ' · choose a compatible terrain or landscape scope under Change.';
      end;
    end else
    begin
      Element('catalog-choice').textContent := Element('catalog-choice').textContent + ' · ' +
        TJSHTMLSelectElement(Element('selection-layer')).selectedOptions[0].textContent;
    end;
  end;
end;

procedure StartCatalogUI;
begin
  GCatalog := TCatalogUI.Create;
end;

end.
