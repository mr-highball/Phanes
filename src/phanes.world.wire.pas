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

unit phanes.world.wire;

{$mode delphi}
{$H+}

interface

uses
  JS,
  phanes.world.types;

function ReadWorld(const AData: TJSObject): TWorld;
function ReadRequest(const AData: TJSObject): TWorldRequest;
function WorldJSON(const AWorld: TWorld): TJSObject;
function InteriorCatalogJSON: TJSArray;

implementation

uses
  SysUtils,
  phanes.terrain.wire,
  phanes.world.selection,
  phanes.world.height,
  phanes.composition.contents.types,
  phanes.interiors.catalog,
  phanes.composition.wire;

function InteriorCatalogJSON: TJSArray;
var
  LAssets: TContentAssets;
  LEntry: TJSObject;
  I: Integer;
begin
  Result := TJSArray.new;
  LAssets := InteriorContentAssets;
  for I := 0 to High(LAssets) do
  begin
    LEntry := TJSObject.new;
    LEntry['id'] := LAssets[I].FId;
    LEntry['name'] := LAssets[I].FName;
    LEntry['role'] := LAssets[I].FRole;
    Result.Push(LEntry);
  end;
end;

function ReadInteger(const AData: TJSObject; const AKey: String;
  const AMinimum, AMaximum: Double): JSValue;
begin
  if not isInteger(AData[AKey]) then
  begin
    raise Exception.Create('Expected an integer for ' + AKey + '.');
  end;
  Result := AData[AKey];
  if (Double(Result) < AMinimum) or (Double(Result) > AMaximum) then
  begin
    raise Exception.Create('Value outside the supported range: ' + AKey + '.');
  end;
end;

function ReadWorld(const AData: TJSObject): TWorld;
var
  LLayer: Integer;
  I: Integer;
  LValues: TJSArray;
  LLayers: TJSArray;
  LFormat: Integer;
  LReason: String;
begin
  Result := Default(TWorld);
  if not isDefined(AData) or (AData = nil) then
  begin
    Exit;
  end;
  if not isObject(AData) or isArray(AData) then
  begin
    raise Exception.Create('A saved world must be an object.');
  end;
  Result.FSize := Integer(ReadInteger(AData, 'size', 4, 48));
  Result.FSeed := Cardinal(ReadInteger(AData, 'seed', 0, 4294967295));
  Result.FAppearanceSeed := Result.FSeed;
  if jsTypeOf(AData['appearanceSeed']) <> 'undefined' then
  begin
    Result.FAppearanceSeed := Cardinal(ReadInteger(AData, 'appearanceSeed', 0, 4294967295));
  end;
  Result.FDecisions := Integer(ReadInteger(AData, 'decisions', 0, High(Integer)));
  Result.FPropagations := Integer(ReadInteger(AData, 'propagations', 0, High(Integer)));
  Result.FBacktracks := Integer(ReadInteger(AData, 'backtracks', 0, High(Integer)));
  LFormat := 1;
  if jsTypeOf(AData['formatVersion']) <> 'undefined' then
  begin
    LFormat := Integer(ReadInteger(AData, 'formatVersion', 1, 4));
  end;
  if LFormat = 1 then
  begin
    if jsTypeOf(AData['composition']) <> 'undefined' then
    begin
      raise Exception.Create('A composition requires world format version 2.');
    end;
    Result.FComposition := InitialWorldComposition(Result.FSeed);
  end
  else
  begin
    if not isObject(AData['composition']) or (AData['composition'] = nil) or
      not ReadCompositionJSON(TJSJSON.stringify(AData['composition']),
        Result.FComposition, LReason) then
    begin
      raise Exception.Create('Invalid world composition: ' + LReason);
    end;
  end;
  if LFormat < 3 then
  begin
    if jsTypeOf(AData['elevation']) <> 'undefined' then
    begin
      raise Exception.Create('Saved height fields require world format version 3.');
    end;
  end
  else
  begin
    if not isObject(AData['elevation']) or (AData['elevation'] = nil) or
      not ReadTerrainJSON(TJSJSON.stringify(AData['elevation']), Result.FElevation, LReason) then
    begin
      raise Exception.Create('Invalid saved elevation: ' + LReason);
    end;
  end;
  Result.FRelativeElevation := LFormat = 4;
  if not ValidateWorldHeight(Result, LReason) then
  begin
    raise Exception.Create(LReason);
  end;
  if not isArray(AData['layers']) then
  begin
    raise Exception.Create('A saved world must contain five layer arrays.');
  end;
  LLayers := TJSArray(AData['layers']);
  if LLayers.Length <> 5 then
  begin
    raise Exception.Create('A saved world must contain five layers.');
  end;
  for LLayer := 0 to 4 do
  begin
    if not isArray(LLayers[LLayer]) then
    begin
      raise Exception.Create('Invalid saved layer.');
    end;
    LValues := TJSArray(LLayers[LLayer]);
    if LValues.Length <> Sqr(LayerSize(Result.FSize, LLayer)) then
    begin
      raise Exception.Create('Saved layer dimensions do not match the world.');
    end;
    SetLength(Result.FLayers[LLayer], LValues.Length);
    for I := 0 to LValues.Length - 1 do
    begin
      if not isString(LValues[I]) then
      begin
        raise Exception.Create('Saved cells must contain named values.');
      end;
      Result.FLayers[LLayer][I] := String(LValues[I]);
    end;
  end;
end;

function ReadRequest(const AData: TJSObject): TWorldRequest;
var
  LCells: TJSArray;
  LReason: String;
  LAssets: TJSArray;
  LAsset: TJSObject;
  LField: String;
  I: Integer;
begin
  Result := Default(TWorldRequest);
  if not isObject(AData) or (AData = nil) or isArray(AData) then
  begin
    raise Exception.Create('A world request must be an object.');
  end;
  Result.FSize := Integer(ReadInteger(AData, 'size', 4, 48));
  Result.FSeed := Cardinal(ReadInteger(AData, 'seed', 0, 4294967295));
  if not isString(AData['operation']) then
  begin
    raise Exception.Create('Choose a named world operation.');
  end;
  Result.FOperation := String(AData['operation']);
  Result.FLandformAmount := 1000;
  if jsTypeOf(AData['landformAmount']) <> 'undefined' then
  begin
    Result.FLandformAmount := Integer(ReadInteger(AData, 'landformAmount', 1, 8000));
  end;
  Result.FX := Integer(ReadInteger(AData, 'x', 0, 47));
  Result.FZ := Integer(ReadInteger(AData, 'z', 0, 47));
  Result.FWidth := Integer(ReadInteger(AData, 'width', 1, 48));
  Result.FDepth := Integer(ReadInteger(AData, 'depth', 1, 48));
  if jsTypeOf(AData['selectionCells']) <> 'undefined' then
  begin
    if not isArray(AData['selectionCells']) then
    begin
      raise Exception.Create('Selection cells must be an array.');
    end;
    Result.FSelectionScale := Integer(ReadInteger(AData, 'selectionScale', 1, 8));
    LCells := TJSArray(AData['selectionCells']);
    if LCells.Length > Sqr(Result.FSize * Result.FSelectionScale) then
    begin
      raise Exception.Create('Too many selection cells.');
    end;
    SetLength(Result.FSelectionCells, LCells.Length);
    for I := 0 to LCells.Length - 1 do
    begin
      if not isInteger(LCells[I]) or (Double(LCells[I]) < 0) or
        (Double(LCells[I]) >= Sqr(Result.FSize * Result.FSelectionScale)) then
      begin
        raise Exception.Create('Selection indices must be whole cells inside the world.');
      end;
      Result.FSelectionCells[I] := Integer(LCells[I]);
    end;
  end
  else if jsTypeOf(AData['selectionScale']) <> 'undefined' then
  begin
    raise Exception.Create('A selection scale requires its cell mask.');
  end;
  Result.FPrevious := ReadWorld(TJSObject(AData['previous']));
  Result.FContentCount := -1;
  Result.FGroundworkTurn := -1;
  Result.FModulePose := isDefined(AData['moduleX']) or isDefined(AData['moduleZ']) or
    isDefined(AData['moduleTurn']);
  if Result.FModulePose then
  begin
    Result.FModuleX := Integer(ReadInteger(AData, 'moduleX', -750, 750));
    Result.FModuleZ := Integer(ReadInteger(AData, 'moduleZ', -750, 750));
    Result.FModuleTurn := Integer(ReadInteger(AData, 'moduleTurn', 0, 3));
    if (Result.FModuleX mod 250 <> 0) or (Result.FModuleZ mod 250 <> 0) then
    begin
      raise Exception.Create('Choose a furnishing position on the quarter-metre grid.');
    end;
  end;
  if jsTypeOf(AData['groundworkTurn']) <> 'undefined' then
  begin
    Result.FGroundworkTurn := Integer(ReadInteger(AData, 'groundworkTurn', -1, 3));
  end;
  for I := 0 to 9 do
  begin
    case I of
      0:
      begin
        LField := 'objectId';
      end;
      1:
      begin
        LField := 'contentAsset';
      end;
      2:
      begin
        LField := 'contentRole';
      end;
      3:
      begin
        LField := 'groundworkBody';
      end;
      4:
      begin
        LField := 'buildingAsset';
      end;
      5:
      begin
        LField := 'planProfile';
      end;
      6:
      begin
        LField := 'roomProgram';
      end;
      7:
      begin
        LField := 'spaceName';
      end;
      8:
      begin
        LField := 'editLayer';
      end;
      9:
      begin
        LField := 'exactAsset';
      end;
    end;
    if (jsTypeOf(AData[LField]) <> 'undefined') and not isString(AData[LField]) then
    begin
      raise Exception.Create('The ' + LField + ' field must be text.');
    end;
  end;
  if isString(AData['objectId']) then
  begin
    Result.FObjectId := String(AData['objectId']);
  end;
  if isString(AData['editLayer']) then
  begin
    Result.FEditLayer := String(AData['editLayer']);
  end;
  if isString(AData['exactAsset']) then
  begin
    Result.FExactAsset := String(AData['exactAsset']);
  end;
  if isString(AData['contentAsset']) then
  begin
    Result.FContentAsset := String(AData['contentAsset']);
  end;
  if isString(AData['contentRole']) then
  begin
    Result.FContentRole := String(AData['contentRole']);
  end;
  if isString(AData['groundworkBody']) then
  begin
    Result.FGroundworkBody := String(AData['groundworkBody']);
  end;
  if isString(AData['buildingAsset']) then
  begin
    Result.FBuildingAsset := String(AData['buildingAsset']);
  end;
  if isString(AData['planProfile']) then
  begin
    Result.FPlanProfile := String(AData['planProfile']);
  end;
  if isString(AData['roomProgram']) then
  begin
    Result.FRoomProgram := String(AData['roomProgram']);
  end;
  if isString(AData['spaceName']) then
  begin
    Result.FSpaceName := UnicodeString(AData['spaceName']);
  end;
  if jsTypeOf(AData['contentCount']) <> 'undefined' then
  begin
    Result.FContentCount := Integer(ReadInteger(AData, 'contentCount', 0, 6));
  end;
  if not isArray(AData['assets']) then
  begin
    raise Exception.Create('The world asset catalog must be an array.');
  end;
  LAssets := TJSArray(AData['assets']);
  SetLength(Result.FAssets, LAssets.Length);
  for I := 0 to LAssets.Length - 1 do
  begin
    LAsset := TJSObject(LAssets[I]);
    if not isObject(LAsset) or (LAsset = nil) or isArray(LAsset) or
      not isString(LAsset['id']) or not isString(LAsset['kind']) or
      not isString(LAsset['theme']) then
    begin
      raise Exception.Create('A world asset requires text id, kind and theme fields.');
    end;
    Result.FAssets[I].FId := String(LAsset['id']);
    Result.FAssets[I].FKind := String(LAsset['kind']);
    Result.FAssets[I].FTheme := String(LAsset['theme']);
    Result.FAssets[I].FCluster := 1;
    if jsTypeOf(LAsset['cluster']) <> 'undefined' then
    begin
      Result.FAssets[I].FCluster := Integer(ReadInteger(LAsset, 'cluster', 1, 9));
    end;
  end;
  if jsTypeOf(AData['assetChoices']) <> 'undefined' then
  begin
    if not isArray(AData['assetChoices']) then
    begin
      raise Exception.Create('A catalog group must contain a list of item IDs.');
    end;
    LCells := TJSArray(AData['assetChoices']);
    if (LCells.Length = 0) or (LCells.Length > Length(Result.FAssets)) then
    begin
      raise Exception.Create('Choose a nonempty catalog group.');
    end;
    SetLength(Result.FAssetChoices, LCells.Length);
    for I := 0 to LCells.Length - 1 do
    begin
      if not isString(LCells[I]) then
      begin
        raise Exception.Create('Catalog group IDs must be text.');
      end;
      Result.FAssetChoices[I] := String(LCells[I]);
    end;
  end;
  if not ValidateSelection(Result, LReason) then
  begin
    raise Exception.Create(LReason);
  end;
end;

function WorldJSON(const AWorld: TWorld): TJSObject;
var
  LLayers: TJSArray;
  LValues: TJSArray;
  LLayer: Integer;
  LValue: String;
  LReason: String;
begin
  if not ValidateWorldHeight(AWorld, LReason) then
  begin
    raise Exception.Create('Cannot serialize world elevation: ' + LReason);
  end;
  Result := TJSObject.new;
  Result['formatVersion'] := 2;
  if AWorld.FElevation.FSpec.FVersion <> 0 then
  begin
    Result['formatVersion'] := 3;
    if AWorld.FRelativeElevation then
    begin
      Result['formatVersion'] := 4;
    end;
    Result['elevation'] := TJSJSON.parse(TerrainJSON(AWorld.FElevation));
  end;
  Result['size'] := AWorld.FSize;
  Result['seed'] := AWorld.FSeed;
  Result['appearanceSeed'] := AWorld.FAppearanceSeed;
  Result['decisions'] := AWorld.FDecisions;
  Result['propagations'] := AWorld.FPropagations;
  Result['backtracks'] := AWorld.FBacktracks;
  LLayers := TJSArray.new;
  for LLayer := 0 to 4 do
  begin
    LValues := TJSArray.new;
    for LValue in AWorld.FLayers[LLayer] do
    begin
      LValues.Push(LValue);
    end;
    LLayers.Push(LValues);
  end;
  Result['layers'] := LLayers;
  Result['composition'] := TJSJSON.parse(CompositionJSON(AWorld.FComposition));
end;

end.
