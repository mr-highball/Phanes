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

unit phanes.groundworks.assembly;

{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.document,
  phanes.world.types,
  phanes.groundworks.geometry;

type
  TGroundworkMaterial = (gmStone, gmConcrete, gmCeramic, gmSteel);
  TGroundworkMaterials = array[0..15] of TGroundworkMaterial;
  TGroundworkAssembly = record
    FId: String;
    FPurpose: TGroundworkPurpose;
    FBody: TGroundworkBody;
    FGeometry: TGroundworkGeometry;
    FMaterials: TGroundworkMaterials;
    FSeed: Cardinal;
    FBuildingAsset: String;
  end;

function GroundworkId(const ACellX, ACellZ: Integer): String;
function GroundworkPartId(const AId: String; const ACell: Integer): String;
function ValidateGroundworkMaterials(const AAssembly: TGroundworkAssembly;
  out AReason: String): Boolean;
function ReadGroundwork(const AWorld: TWorld; const AId: String;
  var AAssembly: TGroundworkAssembly; out AReason: String): Boolean;
function ValidateGroundworks(const AWorld: TWorld; out AReason: String): Boolean;
function GroundworkOwner(const ADocument: TCompositionDocument; const AIndex: TCompositionIndex;
  const ANode: Integer): String;
function CreateGroundwork(const AWorld: TWorld; const ACellX, ACellZ, ATurn: Integer;
  const APurpose: TGroundworkPurpose; const ABody: TGroundworkBody; const ASeed: Cardinal;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
function ReimagineGroundwork(const AWorld: TWorld; const AId, AScopeId: String;
  const ABody: TGroundworkBody; const ASeed: Cardinal;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;

implementation

uses
  Math,
  SysUtils,
  wfc,
  phanes.structures.support,
  phanes.interiors.validate;

const
  CMaterialNames: array[TGroundworkMaterial] of String = ('stone', 'concrete', 'ceramic', 'steel');
  CPlotProfiles: array[TGroundworkPurpose] of String =
    ('phanes.plot.foundation32.v1', 'phanes.plot.launch32.v1');
  CBodyProfiles: array[TGroundworkBody] of String =
    ('phanes.groundworks.plinth16.v1', 'phanes.groundworks.piers16.v1');

function ValidPurposeBody(const APurpose: TGroundworkPurpose; const ABody: TGroundworkBody): Boolean;
begin
  Result := (Ord(APurpose) >= Ord(Low(TGroundworkPurpose))) and
    (Ord(APurpose) <= Ord(High(TGroundworkPurpose))) and
    (Ord(ABody) >= Ord(Low(TGroundworkBody))) and (Ord(ABody) <= Ord(High(TGroundworkBody)));
end;

function GroundworkOwner(const ADocument: TCompositionDocument; const AIndex: TCompositionIndex;
  const ANode: Integer): String;
var
  LCurrent: Integer;
  LDepth: Integer;
begin
  Result := '';
  LCurrent := ANode;
  for LDepth := 0 to 128 do
  begin
    if (LCurrent < 0) or (LCurrent >= Length(ADocument.FNodes)) then
    begin
      Exit;
    end;
    if (ADocument.FNodes[LCurrent].FRole = 'plot') and
      (ADocument.FNodes[LCurrent].FParentId = 'world') and
      ((ADocument.FNodes[LCurrent].FAssetId = CPlotProfiles[gpFoundation]) or
      (ADocument.FNodes[LCurrent].FAssetId = CPlotProfiles[gpLaunchPad])) then
    begin
      Exit(ADocument.FNodes[LCurrent].FId);
    end;
    LCurrent := AIndex.Find(ADocument.FNodes[LCurrent].FParentId);
  end;
end;

function GroundworkId(const ACellX, ACellZ: Integer): String;
begin
  Result := 'site-' + IntToStr(ACellX) + '-' + IntToStr(ACellZ);
end;

function CoreCell(const ACell: Integer): Boolean;
begin
  Result := (ACell = 5) or (ACell = 6) or (ACell = 9) or (ACell = 10);
end;

function GroundworkPartId(const AId: String; const ACell: Integer): String;
begin
  if CoreCell(ACell) then
  begin
    Exit(AId + '.deck.core');
  end;
  Result := AId + '.deck.panel-' + IntToStr(ACell);
end;

function MaterialProfile(const AMaterial: TGroundworkMaterial; const ACore: Boolean): String;
begin
  Result := 'phanes.groundworks.' + CMaterialNames[AMaterial];
  if ACore then
  begin
    Result := Result + '.core8.v1';
  end
  else
  begin
    Result := Result + '.panel4.v1';
  end;
end;

function MaterialFromProfile(const AProfile: String; const ACore: Boolean;
  out AMaterial: TGroundworkMaterial): Boolean;
var
  LMaterial: TGroundworkMaterial;
begin
  for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
  begin
    if AProfile = MaterialProfile(LMaterial, ACore) then
    begin
      AMaterial := LMaterial;
      Exit(True);
    end;
  end;
  Result := False;
end;

function ValidateGroundworkMaterials(const AAssembly: TGroundworkAssembly;
  out AReason: String): Boolean;
var
  LContrastCount: Integer;
  LRequiredCore: TGroundworkMaterial;
  I: Integer;
  J: Integer;
begin
  Result := False;
  AReason := 'Deck materials violate the admitted coverage or transition contract.';
  if not ValidPurposeBody(AAssembly.FPurpose, AAssembly.FBody) then
  begin
    Exit;
  end;
  LRequiredCore := gmConcrete;
  if AAssembly.FPurpose = gpLaunchPad then
  begin
    LRequiredCore := gmCeramic;
  end;
  LContrastCount := 0;
  for I := 0 to 15 do
  begin
    if (Ord(AAssembly.FMaterials[I]) < Ord(Low(TGroundworkMaterial))) or
      (Ord(AAssembly.FMaterials[I]) > Ord(High(TGroundworkMaterial))) then
    begin
      Exit;
    end;
    if CoreCell(I) then
    begin
      if AAssembly.FMaterials[I] <> LRequiredCore then
      begin
        Exit;
      end;
    end
    else if AAssembly.FMaterials[I] <> LRequiredCore then
    begin
      Inc(LContrastCount);
    end;
    { Explicit semantic palette transition: untreated stone and steel need a
      concrete/ceramic joint. Theme is deliberately not an input. These are
      authored game material contracts, not engineering/fire certification. }
    for J := I + 1 to 15 do
    begin
      if ((J = I + 1) and (I mod 4 <> 3)) or (J = I + 4) then
      begin
        if ((AAssembly.FMaterials[I] = gmStone) and (AAssembly.FMaterials[J] = gmSteel)) or
          ((AAssembly.FMaterials[I] = gmSteel) and (AAssembly.FMaterials[J] = gmStone)) then
        begin
          Exit;
        end;
      end;
    end;
  end;
  if (LContrastCount < 2) or (LContrastCount > 10) then
  begin
    Exit;
  end;
  AReason := '';
  Result := True;
end;

function PlotClearance(const AWorld: TWorld; const AAssembly: TGroundworkAssembly;
  out AReason: String): Boolean;
var
  LNode: TCompositionNode;
  LRadius: Integer;
begin
  Result := False;
  for LNode in AWorld.FComposition.FNodes do
  begin
    if (LNode.FParentId <> 'world') or (LNode.FId = AAssembly.FId) then
    begin
      Continue;
    end;
    LRadius := 0;
    if (LNode.FAssetId = CPlotProfiles[gpFoundation]) or
      (LNode.FAssetId = CPlotProfiles[gpLaunchPad]) then
    begin
      LRadius := 32000 + 280;
    end
    else if LNode.FRole = 'building' then
    begin
      { Existing studio roots depend on regional building datums; conservatively
        keep their complete regional envelope out of this plot and apron. }
      LRadius := 24000 + 280;
    end
    else
    begin
      AReason := 'An unadmitted world container prevents groundwork clearance verification: ' +
        LNode.FId;
      Exit;
    end;
    if (Abs(Double(LNode.FX) - AAssembly.FGeometry.FX) < LRadius) and
      (Abs(Double(LNode.FZ) - AAssembly.FGeometry.FZ) < LRadius) then
    begin
      AReason := 'Leave clear space around this plot; another assembly overlaps its boundary or access.';
      Exit;
    end;
  end;
  Result := True;
end;

function ReadGroundwork(const AWorld: TWorld; const AId: String;
  var AAssembly: TGroundworkAssembly; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LCandidate: TGroundworkAssembly;
  LNode: TCompositionNode;
  LPlot: Integer;
  LDeck: Integer;
  LBody: Integer;
  LRoot: Integer;
  LRamp: Integer;
  LToe: Integer;
  LPart: Integer;
  LExpectedParts: array of String;
  LExpectedX: Integer;
  LExpectedZ: Integer;
  LFound: Boolean;
  I: Integer;
  J: Integer;

  function Shape(const AAt: Integer; const AParent, ASupport, ARole, AProfile: String;
    const AKind: TCompositionKind; const AX, AY, AZ, ATurn: Integer): Boolean;
  var
    LValue: TCompositionNode;
  begin
    Result := False;
    if AAt < 0 then
    begin
      Exit;
    end;
    LValue := AWorld.FComposition.FNodes[AAt];
    Result := (LValue.FParentId = AParent) and (LValue.FSupportId = ASupport) and
      (LValue.FRole = ARole) and (LValue.FAssetId = AProfile) and (LValue.FKind = AKind) and
      (LValue.FX = AX) and (LValue.FY = AY) and (LValue.FZ = AZ) and
      (LValue.FQuarterTurn = ATurn);
  end;

  procedure Expected(const APartId: String);
  var
    LCount: Integer;
  begin
    LCount := Length(LExpectedParts);
    SetLength(LExpectedParts, LCount + 1);
    LExpectedParts[LCount] := APartId;
  end;

begin
  Result := False;
  if not ValidateComposition(AWorld.FComposition, AReason) then
  begin
    Exit;
  end;
  if (AWorld.FSize < 4) or (AWorld.FSize > 48) then
  begin
    AReason := 'Groundworks require a world between 4 and 48 regional cells wide.';
    Exit;
  end;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    AReason := 'Groundwork parts do not match their admitted versioned profiles: ' + AId;
    LRoot := LIndex.Find('world');
    if not Shape(LRoot, '', '', 'world', '', ckContainer, 0, 0, 0, 0) then
    begin
      AReason := 'Groundworks require the world root at its canonical origin.';
      Exit;
    end;
    LPlot := LIndex.Find(AId);
    if LPlot < 0 then
    begin
      Exit;
    end;
    LCandidate := Default(TGroundworkAssembly);
    LCandidate.FId := AId;
    LNode := AWorld.FComposition.FNodes[LPlot];
    if (LNode.FX < -AWorld.FSize * 8000) or (LNode.FX > AWorld.FSize * 8000) or
      (LNode.FZ < -AWorld.FSize * 8000) or (LNode.FZ > AWorld.FSize * 8000) then
    begin
      Exit;
    end;
    if LNode.FAssetId = CPlotProfiles[gpFoundation] then
    begin
      LCandidate.FPurpose := gpFoundation;
    end
    else if LNode.FAssetId = CPlotProfiles[gpLaunchPad] then
    begin
      LCandidate.FPurpose := gpLaunchPad;
    end
    else
    begin
      Exit;
    end;
    LCandidate.FGeometry.FX := LNode.FX;
    LCandidate.FGeometry.FZ := LNode.FZ;
    LCandidate.FGeometry.FCellX := (LNode.FX + AWorld.FSize * 8000) div 16000 - 1;
    LCandidate.FGeometry.FCellZ := (LNode.FZ + AWorld.FSize * 8000) div 16000 - 1;
    LCandidate.FSeed := LNode.FSeed;
    if (AId <> GroundworkId(LCandidate.FGeometry.FCellX, LCandidate.FGeometry.FCellZ)) or
      not Shape(LPlot, 'world', '', 'plot', CPlotProfiles[LCandidate.FPurpose], ckContainer,
        LNode.FX, 0, LNode.FZ, 0) then
    begin
      Exit;
    end;
    LDeck := LIndex.Find(AId + '.deck');
    LBody := LIndex.Find(AId + '.deck.body');
    LRamp := LIndex.Find(AId + '.deck.ramp');
    LToe := LIndex.Find(AId + '.deck.ramp.landing');
    if (LDeck < 0) or (LBody < 0) or (LRamp < 0) or (LToe < 0) then
    begin
      Exit;
    end;
    { Reject untrusted integer extremes before summing relative elevations.
      These broad limits enclose every terrain-admitted v1 geometry. }
    if (AWorld.FComposition.FNodes[LDeck].FY < 101) or
      (AWorld.FComposition.FNodes[LDeck].FY > 10000) or
      (AWorld.FComposition.FNodes[LBody].FY < -5000) or
      (AWorld.FComposition.FNodes[LBody].FY > 0) or
      (AWorld.FComposition.FNodes[LToe].FY < -4000) or
      (AWorld.FComposition.FNodes[LToe].FY > 4000) then
    begin
      Exit;
    end;
    LCandidate.FGeometry.FDeckY := AWorld.FComposition.FNodes[LDeck].FY;
    LCandidate.FGeometry.FBottomY := LCandidate.FGeometry.FDeckY +
      AWorld.FComposition.FNodes[LBody].FY;
    LCandidate.FGeometry.FQuarterTurn := AWorld.FComposition.FNodes[LRamp].FQuarterTurn;
    LCandidate.FGeometry.FToeY := LCandidate.FGeometry.FDeckY +
      AWorld.FComposition.FNodes[LToe].FY;
    if AWorld.FComposition.FNodes[LBody].FAssetId = CBodyProfiles[gbPlinth] then
    begin
      LCandidate.FBody := gbPlinth;
    end
    else if AWorld.FComposition.FNodes[LBody].FAssetId = CBodyProfiles[gbPiers] then
    begin
      LCandidate.FBody := gbPiers;
    end
    else
    begin
      Exit;
    end;
    if not Shape(LDeck, AId, '', 'support-deck', 'phanes.groundworks.deck16.v1',
      ckSurface, 0, LCandidate.FGeometry.FDeckY, 0, 0) or
      not Shape(LBody, AId + '.deck', '', 'substructure', CBodyProfiles[LCandidate.FBody],
      ckObject, 0, LCandidate.FGeometry.FBottomY - LCandidate.FGeometry.FDeckY, 0, 0) then
    begin
      Exit;
    end;
    LExpectedX := 0;
    LExpectedZ := 0;
    case LCandidate.FGeometry.FQuarterTurn of
      0:
        begin
          LExpectedZ := 8000;
        end;
      1:
        begin
          LExpectedX := 8000;
        end;
      2:
        begin
          LExpectedZ := -8000;
        end;
      3:
        begin
          LExpectedX := -8000;
        end;
      else
        Exit;
    end;
    if not Shape(LRamp, AId + '.deck', '', 'access-ramp', 'phanes.groundworks.ramp6.v1',
      ckObject, LExpectedX, 0, LExpectedZ, LCandidate.FGeometry.FQuarterTurn) or
      not Shape(LToe, AId + '.deck.ramp', '', 'access-landing', 'phanes.groundworks.landing2.v1',
      ckSurface, 0, LCandidate.FGeometry.FToeY - LCandidate.FGeometry.FDeckY, 6000, 0) then
    begin
      Exit;
    end;
    Expected(AId);
    Expected(AId + '.deck');
    Expected(AId + '.deck.body');
    Expected(AId + '.deck.ramp');
    Expected(AId + '.deck.ramp.landing');
    for I := 0 to 15 do
    begin
      LPart := LIndex.Find(GroundworkPartId(AId, I));
      if (LPart < 0) or not MaterialFromProfile(AWorld.FComposition.FNodes[LPart].FAssetId,
        CoreCell(I), LCandidate.FMaterials[I]) then
      begin
        Exit;
      end;
      LExpectedX := (I mod 4) * 4000 - 6000;
      LExpectedZ := (I div 4) * 4000 - 6000;
      if CoreCell(I) then
      begin
        LExpectedX := 0;
        LExpectedZ := 0;
      end;
      if not Shape(LPart, AId + '.deck', AId + '.deck', 'deck-panel',
        MaterialProfile(LCandidate.FMaterials[I], CoreCell(I)), ckObject,
        LExpectedX, 0, LExpectedZ, 0) then
      begin
        Exit;
      end;
      if not CoreCell(I) or (I = 5) then
      begin
        Expected(GroundworkPartId(AId, I));
      end;
    end;
    LPart := LIndex.Find(AId + '.deck.building');
    if LPart >= 0 then
    begin
      if not ValidSupportedBuilding(AWorld.FComposition.FNodes[LPart], AId + '.deck',
        LCandidate.FGeometry.FQuarterTurn) then
      begin
        Exit;
      end;
      LCandidate.FBuildingAsset := AWorld.FComposition.FNodes[LPart].FAssetId;
    end;
    { Only the canonical supported building can own additional descendants.
      Whole-world interior admission checks each of those descendants afterwards. }
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      if not InCompositionScope(AWorld.FComposition, LIndex, I, AId) then
      begin
        Continue;
      end;
      LFound := False;
      if (LCandidate.FBuildingAsset <> '') and
        (SupportedBuildingOwner(AWorld.FComposition, LIndex, I) = AId + '.deck.building') then
      begin
        LFound := True;
      end;
      for J := 0 to High(LExpectedParts) do
      begin
        if AWorld.FComposition.FNodes[I].FId = LExpectedParts[J] then
        begin
          LFound := True;
          Break;
        end;
      end;
      if not LFound then
      begin
        Exit;
      end;
    end;
    if not ValidateGroundworkGeometry(AWorld, LCandidate.FGeometry, AReason) or
      not ValidateGroundworkMaterials(LCandidate, AReason) or
      not PlotClearance(AWorld, LCandidate, AReason) then
    begin
      Exit;
    end;
    AAssembly := LCandidate;
    AReason := '';
    Result := True;
  finally
    LIndex.Free;
  end;
end;

function ValidateGroundworks(const AWorld: TWorld; out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAssembly: TGroundworkAssembly;
  LCurrent: Integer;
  LHasPlot: Boolean;
  LNode: TCompositionNode;
  I: Integer;
begin
  Result := False;
  if not ValidateComposition(AWorld.FComposition, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    for I := 0 to High(AWorld.FComposition.FNodes) do
    begin
      LNode := AWorld.FComposition.FNodes[I];
      if (LNode.FRole = 'plot') or (Copy(LNode.FAssetId, 1, 12) = 'phanes.plot.') then
      begin
        if not ReadGroundwork(AWorld, LNode.FId, LAssembly, AReason) then
        begin
          Exit;
        end;
      end
      else if Copy(LNode.FAssetId, 1, 19) = 'phanes.groundworks.' then
      begin
        LHasPlot := False;
        LCurrent := LIndex.Find(LNode.FParentId);
        while LCurrent >= 0 do
        begin
          if AWorld.FComposition.FNodes[LCurrent].FRole = 'plot' then
          begin
            LHasPlot := True;
            Break;
          end;
          LCurrent := LIndex.Find(AWorld.FComposition.FNodes[LCurrent].FParentId);
        end;
        if not LHasPlot then
        begin
          AReason := 'Groundwork part has no admitted plot owner: ' + LNode.FId;
          Exit;
        end;
      end;
    end;
    Result := ValidateInteriorNodes(AWorld, AReason);
  finally
    LIndex.Free;
  end;
end;

function SolvePanels(var AAssembly: TGroundworkAssembly; const AFixed: array of Boolean;
  const ASeed: Cardinal; const AChangeCell: Integer; out AReason: String): Boolean;
var
  LGraph: TGraph;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LMaterial: TGroundworkMaterial;
  LOther: TGroundworkMaterial;
  LCore: TGroundworkMaterial;
  LContrast: TGraphValues;
  LAlternatives: TGraphValues;
  LCandidate: TGroundworkAssembly;
  I: Integer;
begin
  Result := False;
  LCandidate := AAssembly;
  LCore := gmConcrete;
  if AAssembly.FPurpose = gpLaunchPad then
  begin
    LCore := gmCeramic;
  end;
  LGraph := TGraph.Create;
  try
    { Sixteen local 4m cells partition one 16m deck. The four center cells
      reserve ONE continuous 8m physical plate, so no seam crosses rocket feet.
      Actual WFC choices are twelve rim materials; geometry is an authored
      versioned profile. Exact fixed domains preserve nonselected/locked parts. }
    LGraph.Reshape(4, 4, 1);
    LGraph.Seed := ASeed;
    LGraph.WrapNeighbors := False;
    LGraph.PassMode := gpmOverlay;
    for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
    begin
      LGraph.AddValue(CMaterialNames[LMaterial]);
    end;
    for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
    begin
      for LOther := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
      begin
        if ((LMaterial = gmStone) and (LOther = gmSteel)) or
          ((LMaterial = gmSteel) and (LOther = gmStone)) then
        begin
          Continue;
        end;
        LGraph.Rules[CMaterialNames[LMaterial]].NewRule(
          [gdNorth, gdSouth, gdEast, gdWest], CMaterialNames[LOther]);
      end;
    end;
    LContrast := nil;
    for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
    begin
      if LMaterial <> LCore then
      begin
        LContrast := LContrast + [CMaterialNames[LMaterial]];
      end;
    end;
    LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('rim-variation', LContrast, 2, 10));
    for I := 0 to 15 do
    begin
      if CoreCell(I) then
      begin
        LGraph.SetAllowedValues(I mod 4, I div 4, 0, [CMaterialNames[LCore]]);
      end
      else if AFixed[I] then
      begin
        LGraph.SetAllowedValues(I mod 4, I div 4, 0, [CMaterialNames[AAssembly.FMaterials[I]]]);
      end
      else if I = AChangeCell then
      begin
        LAlternatives := nil;
        for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
        begin
          if LMaterial <> AAssembly.FMaterials[I] then
          begin
            LAlternatives := LAlternatives + [CMaterialNames[LMaterial]];
          end;
        end;
        LGraph.SetAllowedValues(I mod 4, I div 4, 0, LAlternatives);
      end;
    end;
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 2048;
    if not LGraph.TrySolve(LOptions, LReport) then
    begin
      AReason := 'The selected deck panels did not resolve within the search allowance.';
      Exit;
    end;
    for I := 0 to 15 do
    begin
      for LMaterial := Low(TGroundworkMaterial) to High(TGroundworkMaterial) do
      begin
        if LGraph.Entry[I mod 4, I div 4, 0].Value = CMaterialNames[LMaterial] then
        begin
          LCandidate.FMaterials[I] := LMaterial;
          Break;
        end;
      end;
    end;
    if not ValidateGroundworkMaterials(LCandidate, AReason) then
    begin
      Exit;
    end;
    AAssembly := LCandidate;
    Result := True;
  finally
    LGraph.Free;
  end;
end;

procedure AppendPart(var ADocument: TCompositionDocument; const AId, AParent, ASupport,
  ARole, AProfile: String; const AName: UnicodeString; const AKind: TCompositionKind;
  const AX, AY, AZ, ATurn: Integer; const ASeed: Cardinal);
var
  LNode: TCompositionNode;
  LCount: Integer;
begin
  LNode := Default(TCompositionNode);
  LNode.FId := AId;
  LNode.FParentId := AParent;
  LNode.FSupportId := ASupport;
  LNode.FRole := ARole;
  LNode.FAssetId := AProfile;
  LNode.FName := AName;
  LNode.FKind := AKind;
  LNode.FX := AX;
  LNode.FY := AY;
  LNode.FZ := AZ;
  LNode.FQuarterTurn := ATurn;
  LNode.FSeed := ASeed;
  LCount := Length(ADocument.FNodes);
  SetLength(ADocument.FNodes, LCount + 1);
  ADocument.FNodes[LCount] := LNode;
end;

function CreateGroundwork(const AWorld: TWorld; const ACellX, ACellZ, ATurn: Integer;
  const APurpose: TGroundworkPurpose; const ABody: TGroundworkBody; const ASeed: Cardinal;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
var
  LAssembly: TGroundworkAssembly;
  LDecoded: TGroundworkAssembly;
  LCandidate: TWorld;
  LFixed: array[0..15] of Boolean;
  LX: Integer;
  LZ: Integer;
  I: Integer;
begin
  Result := False;
  if not ValidPurposeBody(APurpose, ABody) then
  begin
    AReason := 'Choose an admitted groundwork purpose and substructure.';
    Exit;
  end;
  if not ValidateGroundworks(AWorld, AReason) then
  begin
    Exit;
  end;
  LAssembly := Default(TGroundworkAssembly);
  LAssembly.FId := GroundworkId(ACellX, ACellZ);
  LAssembly.FPurpose := APurpose;
  LAssembly.FBody := ABody;
  LAssembly.FSeed := ASeed;
  if not PlanGroundworkGeometry(AWorld, ACellX, ACellZ, ATurn, LAssembly.FGeometry, AReason) or
    not PlotClearance(AWorld, LAssembly, AReason) then
  begin
    Exit;
  end;
  for I := 0 to 15 do
  begin
    LFixed[I] := False;
  end;
  if not SolvePanels(LAssembly, LFixed, ASeed, -1, AReason) then
  begin
    Exit;
  end;
  LCandidate := AWorld;
  LCandidate.FComposition := CopyDocument(AWorld.FComposition);
  AppendPart(LCandidate.FComposition, LAssembly.FId, 'world', '', 'plot',
    CPlotProfiles[APurpose], 'Plot', ckContainer, LAssembly.FGeometry.FX, 0,
    LAssembly.FGeometry.FZ, 0, ASeed);
  AppendPart(LCandidate.FComposition, LAssembly.FId + '.deck', LAssembly.FId, '', 'support-deck',
    'phanes.groundworks.deck16.v1', 'Deck', ckSurface, 0, LAssembly.FGeometry.FDeckY, 0, 0, ASeed);
  AppendPart(LCandidate.FComposition, LAssembly.FId + '.deck.body', LAssembly.FId + '.deck', '',
    'substructure', CBodyProfiles[ABody], 'Supports', ckObject, 0,
    LAssembly.FGeometry.FBottomY - LAssembly.FGeometry.FDeckY, 0, 0, ASeed);
  LX := 0;
  LZ := 0;
  case ATurn of
    0:
      begin
        LZ := 8000;
      end;
    1:
      begin
        LX := 8000;
      end;
    2:
      begin
        LZ := -8000;
      end;
    3:
      begin
        LX := -8000;
      end;
  end;
  AppendPart(LCandidate.FComposition, LAssembly.FId + '.deck.ramp', LAssembly.FId + '.deck', '',
    'access-ramp', 'phanes.groundworks.ramp6.v1', 'Access ramp', ckObject, LX, 0, LZ, ATurn, ASeed);
  AppendPart(LCandidate.FComposition, LAssembly.FId + '.deck.ramp.landing',
    LAssembly.FId + '.deck.ramp', '', 'access-landing', 'phanes.groundworks.landing2.v1',
    'Graded landing', ckSurface, 0, LAssembly.FGeometry.FToeY - LAssembly.FGeometry.FDeckY,
    6000, 0, ASeed);
  for I := 0 to 15 do
  begin
    if CoreCell(I) and (I <> 5) then
    begin
      Continue;
    end;
    LX := (I mod 4) * 4000 - 6000;
    LZ := (I div 4) * 4000 - 6000;
    if CoreCell(I) then
    begin
      LX := 0;
      LZ := 0;
    end;
    AppendPart(LCandidate.FComposition, GroundworkPartId(LAssembly.FId, I),
      LAssembly.FId + '.deck', LAssembly.FId + '.deck', 'deck-panel',
      MaterialProfile(LAssembly.FMaterials[I], CoreCell(I)), 'Deck panel', ckObject,
      LX, 0, LZ, 0, ASeed);
  end;
  if not ValidateGroundworks(LCandidate, AReason) or
    not ReadGroundwork(LCandidate, LAssembly.FId, LDecoded, AReason) then
  begin
    Exit;
  end;
  Result := CommitComposition(AWorld.FComposition, LCandidate.FComposition, 'world',
    AWorld.FComposition.FRevision, ACommitted, AReason);
end;

function ReimagineGroundwork(const AWorld: TWorld; const AId, AScopeId: String;
  const ABody: TGroundworkBody; const ASeed: Cardinal;
  var ACommitted: TCompositionDocument; out AReason: String): Boolean;
var
  LAssembly: TGroundworkAssembly;
  LDecoded: TGroundworkAssembly;
  LIndex: TCompositionIndex;
  LCandidate: TWorld;
  LFixed: array[0..15] of Boolean;
  LNode: Integer;
  LBody: Integer;
  LScope: Integer;
  LChangeCell: Integer;
  LCanEdit: Boolean;
  LChanged: Boolean;
  I: Integer;

  function Protected(const AAt: Integer): Boolean;
  var
    LParent: Integer;
    LSupport: Integer;
  begin
    Result := AWorld.FComposition.FNodes[AAt].FLocked;
    if Result then
    begin
      Exit;
    end;
    LParent := LIndex.Find(AWorld.FComposition.FNodes[AAt].FParentId);
    if (LParent >= 0) and Protected(LParent) then
    begin
      Exit(True);
    end;
    LSupport := LIndex.Find(AWorld.FComposition.FNodes[AAt].FSupportId);
    Result := (LSupport >= 0) and Protected(LSupport);
  end;

begin
  Result := False;
  if not ValidPurposeBody(gpFoundation, ABody) then
  begin
    AReason := 'Choose an admitted substructure.';
    Exit;
  end;
  if not ValidateGroundworks(AWorld, AReason) or
    not ReadGroundwork(AWorld, AId, LAssembly, AReason) then
  begin
    Exit;
  end;
  LIndex := TCompositionIndex.Create(AWorld.FComposition.FNodes);
  try
    LScope := LIndex.Find(AScopeId);
    if (LScope < 0) or not InCompositionScope(AWorld.FComposition, LIndex, LScope, AId) then
    begin
      AReason := 'Choose a part of this groundwork to reimagine.';
      Exit;
    end;
    if Protected(LScope) then
    begin
      AReason := 'This part is protected by its own lock or a parent/support lock.';
      Exit;
    end;
    LCanEdit := False;
    LChangeCell := -1;
    for I := 0 to 15 do
    begin
      LNode := LIndex.Find(GroundworkPartId(AId, I));
      LFixed[I] := not InCompositionScope(AWorld.FComposition, LIndex, LNode, AScopeId) or
        Protected(LNode);
      if not LFixed[I] and not CoreCell(I) then
      begin
        LCanEdit := True;
        if AScopeId = GroundworkPartId(AId, I) then
        begin
          LChangeCell := I;
        end;
      end;
    end;
    LBody := LIndex.Find(AId + '.deck.body');
    LCanEdit := LCanEdit or (InCompositionScope(AWorld.FComposition, LIndex, LBody, AScopeId) and
      not Protected(LBody));
    if not LCanEdit then
    begin
      AReason := 'Choose an unlocked rim panel or substructure; this support geometry stays fixed.';
      Exit;
    end;
    if not SolvePanels(LAssembly, LFixed, ASeed, LChangeCell, AReason) then
    begin
      Exit;
    end;
    LCandidate := AWorld;
    LCandidate.FComposition := CopyDocument(AWorld.FComposition);
    for I := 0 to 15 do
    begin
      if LFixed[I] or CoreCell(I) then
      begin
        Continue;
      end;
      LNode := LIndex.Find(GroundworkPartId(AId, I));
      if LCandidate.FComposition.FNodes[LNode].FAssetId <>
        MaterialProfile(LAssembly.FMaterials[I], False) then
      begin
        LCandidate.FComposition.FNodes[LNode].FAssetId := MaterialProfile(LAssembly.FMaterials[I], False);
        LCandidate.FComposition.FNodes[LNode].FSeed := ASeed;
      end;
    end;
    LBody := LIndex.Find(AId + '.deck.body');
    if InCompositionScope(AWorld.FComposition, LIndex, LBody, AScopeId) and
      not Protected(LBody) and (LCandidate.FComposition.FNodes[LBody].FAssetId <> CBodyProfiles[ABody]) then
    begin
      LCandidate.FComposition.FNodes[LBody].FAssetId := CBodyProfiles[ABody];
      LCandidate.FComposition.FNodes[LBody].FSeed := ASeed;
    end;
    if not ValidateGroundworks(LCandidate, AReason) or
      not ReadGroundwork(LCandidate, AId, LDecoded, AReason) then
    begin
      Exit;
    end;
    LChanged := False;
    for I := 0 to High(LCandidate.FComposition.FNodes) do
    begin
      if not SameNode(LCandidate.FComposition.FNodes[I], AWorld.FComposition.FNodes[I]) then
      begin
        LChanged := True;
        Break;
      end;
    end;
    if not LChanged then
    begin
      AReason := 'This search produced no different admitted parts. The world is unchanged.';
      Exit;
    end;
    Result := CommitComposition(AWorld.FComposition, LCandidate.FComposition, AScopeId,
      AWorld.FComposition.FRevision, ACommitted, AReason);
  finally
    LIndex.Free;
  end;
end;

end.
