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
unit phanes.session.wire;

{$mode delphi}
{$H+}

interface

uses
  JS;

function ValidateSession(const ASession: TJSObject; const AAssets: TJSArray): TJSObject;

implementation

uses
  SysUtils, Math, phanes.world.types, phanes.world.wire, phanes.world.generate,
  phanes.composition.document, phanes.styles.catalog, phanes.groundworks.assembly,
  phanes.buildings.types;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure ValidateCamera(const ACamera: TJSObject);
const
  CNumbers: array[0..8] of String =
    ('x', 'y', 'z', 'panX', 'panY', 'panZ', 'yaw', 'pitch', 'zoom');
var
  LValue: Double;
  LKey: String;
  I: Integer;
begin
  Require(isObject(ACamera) and (ACamera <> nil) and not isArray(ACamera),
    'Saved camera is missing.');
  Require(isString(ACamera['camera']) and
    ((String(ACamera['camera']) = 'top') or (String(ACamera['camera']) = 'orbit') or
     (String(ACamera['camera']) = 'fly') or (String(ACamera['camera']) = 'walk')),
    'Unknown saved camera.');
  for I := 0 to 8 do
  begin
    LKey := CNumbers[I];
    Require(isNumber(ACamera[LKey]), 'Saved camera coordinate must be numeric.');
    LValue := Double(ACamera[LKey]);
    Require(TJSNumber.isFinite(LValue) and (Abs(LValue) <= 10000), 'Saved camera exceeds bounds.');
  end;
  { Modular object inspection uses the world span, up to 48 * 128 zoom units.
    This remains a finite camera-only setting, independent of edit authority. }
  Require((Double(ACamera['zoom']) >= 0.1) and (Double(ACamera['zoom']) <= 6144),
    'Saved camera zoom exceeds bounds.');
end;

procedure ValidateSnapshot(const ASnapshot: TJSObject; const AAssets: TJSArray;
  const ASelection: TJSObject = nil);
var
  LRequest: TJSObject;
  LWorld: TWorld;
  LReason: String;
  LCells: TJSArray;
  LSize: Integer;
  LScale: Integer;
  LCell: Integer;
  LLast: Integer;
  LMinX: Integer;
  LMaxX: Integer;
  LMinZ: Integer;
  LMaxZ: Integer;
  I: Integer;
begin
  Require(isObject(ASnapshot) and (ASnapshot <> nil) and not isArray(ASnapshot),
    'Saved world is missing.');
  Require(Length(TJSJSON.stringify(ASnapshot)) <= 8 * 1024 * 1024,
    'Saved world exceeds the recovery allowance.');
  LRequest := TJSObject.new;
  LRequest['operation'] := 'restore';
  LRequest['size'] := ASnapshot['size'];
  LRequest['seed'] := ASnapshot['seed'];
  LRequest['x'] := 0;
  LRequest['z'] := 0;
  LRequest['width'] := ASnapshot['size'];
  LRequest['depth'] := ASnapshot['size'];
  LRequest['previous'] := ASnapshot;
  LRequest['assets'] := AAssets;
  { A selection is editor state, not authority to regenerate a saved world.
    Restore admits the complete world first; masks are checked independently,
    including the valid empty selection left by the Clear selection control. }
  Require(GenerateWorld(ReadRequest(LRequest), LWorld, LReason),
    'Saved world cannot be recovered: ' + LReason);
  if ASelection <> nil then
  begin
    LSize := LWorld.FSize;
    Require((Double(ASelection['x']) >= 0) and (Double(ASelection['z']) >= 0) and
      (Double(ASelection['width']) >= 1) and (Double(ASelection['depth']) >= 1) and
      (Double(ASelection['width']) <= LSize) and (Double(ASelection['depth']) <= LSize) and
      (Double(ASelection['x']) <= LSize - Double(ASelection['width'])) and
      (Double(ASelection['z']) <= LSize - Double(ASelection['depth'])),
      'Saved selection must fit inside the world.');
    if isDefined(ASelection['selectionCells']) or isDefined(ASelection['selectionScale']) then
    begin
      Require(isArray(ASelection['selectionCells']) and
        isInteger(ASelection['selectionScale']) and
        ((ASelection['selectionScale'] = 1) or (ASelection['selectionScale'] = 2) or
        (ASelection['selectionScale'] = 8)),
        'Saved mask requires regional or foliage cells.');
      LCells := TJSArray(ASelection['selectionCells']);
      LScale := Integer(ASelection['selectionScale']);
      LLast := -1;
      LMinX := LSize;
      LMinZ := LSize;
      LMaxX := -1;
      LMaxZ := -1;
      Require(LCells.length <= Sqr(LSize * LScale), 'Saved mask has too many cells.');
      for I := 0 to LCells.length - 1 do
      begin
        Require(isInteger(LCells[I]) and (Double(LCells[I]) > LLast) and
          (Double(LCells[I]) < Sqr(LSize * LScale)),
          'Saved mask must contain ordered, unique cells inside the world.');
        LCell := Integer(LCells[I]);
        LLast := LCell;
        LMinX := Min(LMinX, (LCell mod (LSize * LScale)) div LScale);
        LMaxX := Max(LMaxX, (LCell mod (LSize * LScale)) div LScale);
        LMinZ := Min(LMinZ, (LCell div (LSize * LScale)) div LScale);
        LMaxZ := Max(LMaxZ, (LCell div (LSize * LScale)) div LScale);
      end;
      if LCells.length = 0 then
      begin
        Require((Integer(ASelection['width']) = 1) and (Integer(ASelection['depth']) = 1),
          'An empty saved selection uses a single anchor cell.');
        Exit;
      end;
      Require((Integer(ASelection['x']) = LMinX) and (Integer(ASelection['z']) = LMinZ) and
        (Integer(ASelection['width']) = LMaxX - LMinX + 1) and
        (Integer(ASelection['depth']) = LMaxZ - LMinZ + 1),
        'Saved selection bounds must match its actual mask.');
    end;
  end;
end;

function ValidateSession(const ASession: TJSObject; const AAssets: TJSArray): TJSObject;
const
  CStacks: array[0..1] of String = ('history', 'future');
  CBounds: array[0..3] of String = ('x', 'z', 'width', 'depth');
  CStyleSettings: array[0..1] of String = ('strength', 'detail');
var
  LStack: TJSArray;
  LKey: String;
  LWorld: TWorld;
  LIndex: TCompositionIndex;
  LInterior: TJSObject;
  LGroundwork: TJSObject;
  LModular: TJSObject;
  LLandforms: TJSObject;
  LLevelStep: Integer;
  LRoom: Integer;
  LSelected: Integer;
  LStyleKnown: Boolean;
  LAssembly: TGroundworkAssembly;
  LReason: String;
  I: Integer;
begin
  Require(isObject(ASession) and (ASession <> nil) and not isArray(ASession),
    'Saved session is missing.');
  Require(ASession['format'] = 'phanes.session/v1', 'Unknown saved session format.');
  Require(Length(TJSJSON.stringify(ASession)) <= 32 * 1024 * 1024,
    'Saved session exceeds the recovery allowance.');
  Require(isBoolean(ASession['editing']), 'Saved editing mode is missing.');
  if isDefined(ASession['style']) then
  begin
    Require(isObject(ASession['style']) and (ASession['style'] <> nil) and
      not isArray(ASession['style']), 'Saved visual style is invalid.');
    LStyleKnown := False;
    for I := 0 to VisualStyleCount - 1 do
    begin
      LStyleKnown := LStyleKnown or (TJSObject(ASession['style'])['id'] = VisualStyles[I].FId);
    end;
    Require(LStyleKnown, 'Saved visual style is unknown.');
    for LKey in CStyleSettings do
    begin
      Require(isNumber(TJSObject(ASession['style'])[LKey]) and
        (Double(TJSObject(ASession['style'])[LKey]) >= 0) and
        (Double(TJSObject(ASession['style'])[LKey]) <= 1), 'Saved visual style setting is invalid.');
    end;
  end;
  ValidateCamera(TJSObject(ASession['camera']));
  Require(isObject(ASession['selection']) and (ASession['selection'] <> nil) and
    not isArray(ASession['selection']),
    'Saved selection is missing.');
  for LKey in CBounds do
  begin
    Require(isInteger(TJSObject(ASession['selection'])[LKey]),
      'Saved selection bounds must be whole cells.');
  end;
  ValidateSnapshot(TJSObject(ASession['world']), AAssets, TJSObject(ASession['selection']));
  for LKey in CStacks do
  begin
    Require(isArray(ASession[LKey]), 'Saved history must be an array.');
    LStack := TJSArray(ASession[LKey]);
    Require(LStack.length <= 30, 'Saved history exceeds the recovery allowance.');
    for I := 0 to LStack.length - 1 do
    begin
      ValidateSnapshot(TJSObject(LStack[I]), AAssets);
    end;
  end;
  if isObject(ASession['interior']) and (ASession['interior'] <> nil) and
    (TJSObject(ASession['interior'])['previousCamera'] <> nil) and
    isDefined(TJSObject(ASession['interior'])['previousCamera']) then
  begin
    ValidateCamera(TJSObject(TJSObject(ASession['interior'])['previousCamera']));
  end;
  Require(isObject(ASession['interior']) and (ASession['interior'] <> nil) and
    not isArray(ASession['interior']),
    'Saved interior context is missing.');
  LInterior := TJSObject(ASession['interior']);
  Require(isString(LInterior['room']) and isString(LInterior['selected']),
    'Saved interior identifiers must be text.');
  if LInterior['room'] <> '' then
  begin
    Require(isObject(LInterior['previousCamera']) and (LInterior['previousCamera'] <> nil),
      'Saved interior return position is missing.');
    Require(isBoolean(TJSObject(LInterior['previousCamera'])['editing']),
      'Saved exterior editing mode is missing.');
    LWorld := ReadWorld(TJSObject(ASession['world']));
    LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
    try
      LRoom := LIndex.Find(String(LInterior['room']));
      LSelected := LIndex.Find(String(LInterior['selected']));
      Require((LRoom >= 0) and (LSelected >= 0), 'Saved interior no longer exists.');
      Require((LWorld.FComposition.FNodes[LRoom].FRole = 'studio') or
        (LWorld.FComposition.FNodes[LRoom].FRole = 'floor-plan'),
        'Saved interior must be a walkable room or floor plan.');
      Require(InCompositionScope(LWorld.FComposition, LIndex, LSelected,
        String(LInterior['room'])), 'Saved selection is outside its interior.');
    finally
      LIndex.Free;
    end;
  end;
  Require(isObject(ASession['groundwork']) and (ASession['groundwork'] <> nil) and
    not isArray(ASession['groundwork']), 'Saved groundwork context is missing.');
  LGroundwork := TJSObject(ASession['groundwork']);
  Require(isBoolean(LGroundwork['active']) and isString(LGroundwork['plot']) and
    isString(LGroundwork['selected']), 'Saved groundwork context is invalid.');
  Require((LGroundwork['body'] = 'plinth') or (LGroundwork['body'] = 'piers'),
    'Saved groundwork body is unknown.');
  Require(isInteger(LGroundwork['turn']) and (Double(LGroundwork['turn']) >= -1) and
    (Double(LGroundwork['turn']) <= 3), 'Saved groundwork direction is invalid.');
  if LGroundwork['plot'] <> '' then
  begin
    LWorld := ReadWorld(TJSObject(ASession['world']));
    LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
    try
      LRoom := LIndex.Find(String(LGroundwork['plot']));
      Require(LRoom >= 0, 'Saved groundwork plot is missing.');
      Require(LWorld.FComposition.FNodes[LRoom].FRole = 'plot',
        'Saved groundwork must identify a plot.');
      LSelected := LIndex.Find(String(LGroundwork['selected']));
      Require((LSelected >= 0) and InCompositionScope(LWorld.FComposition, LIndex,
        LSelected, String(LGroundwork['plot'])), 'Saved groundwork selection is outside its plot.');
      if LGroundwork['active'] = True then
      begin
        Require(ReadGroundwork(LWorld, String(LGroundwork['plot']), LAssembly, LReason),
          'Saved groundwork could not be admitted: ' + LReason);
        Require((TJSObject(ASession['selection'])['x'] = LAssembly.FGeometry.FCellX) and
          (TJSObject(ASession['selection'])['z'] = LAssembly.FGeometry.FCellZ) and
          (TJSObject(ASession['selection'])['width'] = 2) and
          (TJSObject(ASession['selection'])['depth'] = 2),
          'Saved groundwork and regional selection identify different plots.');
      end;
    finally
      LIndex.Free;
    end;
  end;
  if isDefined(ASession['modular']) then
  begin
    Require(isObject(ASession['modular']) and (ASession['modular'] <> nil) and
      not isArray(ASession['modular']), 'Saved modular context is invalid.');
    LModular := TJSObject(ASession['modular']);
    Require(isBoolean(LModular['active']) and isBoolean(LModular['picking']) and
      isBoolean(LModular['cutaway']) and isString(LModular['root']) and
      isString(LModular['selected']), 'Saved modular context has invalid fields.');
    LWorld := ReadWorld(TJSObject(ASession['world']));
    LIndex := TCompositionIndex.Create(LWorld.FComposition.FNodes);
    try
      if LModular['root'] <> '' then
      begin
        LRoom := LIndex.Find(String(LModular['root']));
        Require((LRoom >= 0) and
          (LWorld.FComposition.FNodes[LRoom].FAssetId = ModularBuildingAsset),
          'Saved modular home is missing.');
      end;
      if LModular['selected'] <> '' then
      begin
        LSelected := LIndex.Find(String(LModular['selected']));
        Require((LSelected >= 0) and
          (ModularOwner(LWorld.FComposition, LIndex, LSelected) = String(LModular['root'])),
          'Saved modular part is outside its home.');
      end;
    finally
      LIndex.Free;
    end;
  end;
  if isDefined(ASession['landforms']) then
  begin
    Require(isObject(ASession['landforms']) and (ASession['landforms'] <> nil) and
      not isArray(ASession['landforms']), 'Saved landform context is invalid.');
    Require(isBoolean(TJSObject(ASession['landforms'])['active']) and
      isInteger(TJSObject(ASession['landforms'])['amount']),
      'Saved landform controls have invalid fields.');
    Require((Integer(TJSObject(ASession['landforms'])['amount']) >= 1) and
      (Integer(TJSObject(ASession['landforms'])['amount']) <= 8000),
      'Saved terrain change is outside its supported range.');
    LLandforms := TJSObject(ASession['landforms']);
    LWorld := ReadWorld(TJSObject(ASession['world']));
    LLevelStep := 250;
    if LWorld.FElevation.FSpec.FVersion <> 0 then
    begin
      LLevelStep := LWorld.FElevation.FSpec.FLevelStep;
    end;
    Require(Integer(LLandforms['amount']) mod LLevelStep = 0,
      'Saved terrain amount must match the world height step.');
    if LLandforms['active'] = True then
    begin
      Require((LInterior['room'] = '') and (LGroundwork['active'] = False),
        'Saved terrain tools conflict with another active construction context.');
      if isDefined(ASession['modular']) then
      begin
        Require(TJSObject(ASession['modular'])['active'] = False,
          'Saved terrain and modular tools cannot both be active.');
      end;
      Require(TJSObject(ASession['selection'])['selectionScale'] <> 8,
        'Saved terrain tools require a land selection rather than modular floors.');
    end;
  end;
  { Preserve the exact admitted document and both history stacks. Recovery
    does not generate a new seed or overwrite generation timing metadata. }
  Result := ASession;
end;

end.
