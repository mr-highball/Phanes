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

program PhanesGroundworkTests;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  phanes.world.types,
  phanes.world.elevation,
  phanes.groundworks.geometry,
  phanes.groundworks.assembly,
  phanes.structures.support,
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.wire,
  phanes.world.generate,
  phanes.world.validate,
  phanes.world.landscape;

var
  GChecks: Integer;
  GWorld: TWorld;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure EmptyWorld(const ASize: Integer);
var
  I: Integer;
  J: Integer;
begin
  GWorld := Default(TWorld);
  GWorld.FSize := ASize;
  GWorld.FComposition := InitialWorldComposition(1);
  for I := 0 to 4 do
  begin
    SetLength(GWorld.FLayers[I], Sqr(LayerSize(ASize, I)));
    for J := 0 to High(GWorld.FLayers[I]) do
    begin
      GWorld.FLayers[I][J] := 'empty';
      if I = 0 then
      begin
        GWorld.FLayers[I][J] := 'meadow';
      end;
    end;
  end;
end;

procedure CheckTransforms;
const
  CToeX: array[0..3] of Integer = (0, 14, 0, -14);
  CToeZ: array[0..3] of Integer = (14, 0, -14, 0);
var
  LGeometry: TGroundworkGeometry;
  LX: Double;
  LZ: Double;
  LU: Double;
  LV: Double;
  I: Integer;
begin
  LGeometry := Default(TGroundworkGeometry);
  LGeometry.FX := 32000;
  LGeometry.FZ := -48000;
  for I := 0 to 3 do
  begin
    LGeometry.FQuarterTurn := I;
    GroundworkToWorld(LGeometry, 0, 14, LX, LZ);
    Check((Abs(LX - 32 - CToeX[I]) < 1e-8) and
      (Abs(LZ + 48 - CToeZ[I]) < 1e-8), 'All cardinal toes rotate about the plot center');
    GroundworkToWorld(LGeometry, 0.73, 11.8, LX, LZ);
    GroundworkToLocal(LGeometry, LX, LZ, LU, LV);
    Check((Abs(LU - 0.73) < 1e-8) and (Abs(LV - 11.8) < 1e-8),
      'Local/world round trip');
  end;
end;

procedure CheckContext;
var
  LReason: String;
  LGeometry: TGroundworkGeometry;
begin
  EmptyWorld(4);
  Check(GroundworkContext(GWorld, 1, 1, LReason), 'Central 2 x 2 plot works in a 4 x 4 world');
  Check(not GroundworkContext(GWorld, 0, 1, LReason), 'Implicit world-edge water excluded');
  Check(not GroundworkContext(GWorld, 2, 1, LReason), 'Full positive border required');
  Check(not GroundworkContext(GWorld, High(Integer), 1, LReason), 'Extreme X cannot overflow border');
  Check(not GroundworkContext(GWorld, 1, High(Integer), LReason), 'Extreme Z cannot overflow border');
  Check(not GroundworkContext(GWorld, Low(Integer), 1, LReason), 'Negative extreme rejects');
  GWorld.FLayers[0][0] := 'water';
  Check(not GroundworkContext(GWorld, 1, 1, LReason), 'Diagonal water halo excluded');
  GWorld.FLayers[0][0] := 'meadow';
  GWorld.FLayers[3][15] := 'cabin';
  Check(not GroundworkContext(GWorld, 1, 1, LReason), 'Adjacent implicit plateau excluded');
  GWorld.FLayers[3][15] := 'empty';
  LGeometry := Default(TGroundworkGeometry);
  LGeometry.FDeckY := 12345;
  Check(not PlanGroundworkGeometry(GWorld, 0, 0, 0, LGeometry, LReason), 'Invalid planning rejects');
  Check(LGeometry.FDeckY = 12345, 'Rejected planning preserves caller output');
  Check(not PlanGroundworkGeometry(GWorld, 1, 1, 4, LGeometry, LReason), 'Unknown turn rejects');
  GWorld.FLayers[2][2 * 8 + 2] := 'tree';
  Check(not GroundworkContext(GWorld, 1, 1, LReason), 'Foliage inside selected plot must be cleared');
  GWorld.FLayers[2][2 * 8 + 2] := 'empty';
  SetLength(GWorld.FLayers[4], 0);
  Check(not GroundworkContext(GWorld, 1, 1, LReason), 'Incomplete world rejects safely');
end;

procedure CheckAcceptedSurface(const AGeometry: TGroundworkGeometry);
var
  LX: Double;
  LZ: Double;
  LHeight: Double;
  LU: Double;
  LV: Double;
  LBefore: Double;
  LAfter: Double;
  LDU: Double;
  LDV: Double;
  I: Integer;
  J: Integer;
begin
  for I := 0 to 20 do
  begin
    LU := -1 + I * 0.1;
    GroundworkToWorld(AGeometry, LU, 16, LX, LZ);
    Check(Abs(GroundworkSurfaceHeight(AGeometry, LX, LZ) - TerrainBaseHeight(LX, LZ)) < 1e-9,
      'Every landing boundary point meets unchanged terrain');
    GroundworkToWorld(AGeometry, LU, 16.001, LX, LZ);
    Check(Abs(GroundworkSoilHeight(AGeometry, LX, LZ) - TerrainBaseHeight(LX, LZ)) < 1e-9,
      'No soil edit outside the selected plot');
    GroundworkToWorld(AGeometry, LU, 14 - 0.000001, LX, LZ);
    LBefore := GroundworkSurfaceHeight(AGeometry, LX, LZ);
    GroundworkToWorld(AGeometry, LU, 14 + 0.000001, LX, LZ);
    LAfter := GroundworkSurfaceHeight(AGeometry, LX, LZ);
    Check(Abs(LBefore - LAfter) < 0.000002, 'Full-width ramp/landing seam is continuous');
    for J := 0 to 80 do
    begin
      LV := 8 + J * 0.1;
      GroundworkToWorld(AGeometry, LU, LV, LX, LZ);
      LHeight := GroundworkSurfaceHeight(AGeometry, LX, LZ);
      Check(LHeight >= WorldStandingMinimumMetres, 'Admitted access is dry across its full width');
      Check(TerrainBaseHeight(LX, LZ) - GroundworkSoilHeight(AGeometry, LX, LZ) <=
        GroundworkMaximumCutMetres + 1e-8, 'Actual soil cut stays within allowance');
      if (I > 0) and (I < 20) and (J > 60) and (J < 80) then
      begin
        GroundworkToWorld(AGeometry, LU + 0.0001, LV, LX, LZ);
        LDU := (GroundworkSurfaceHeight(AGeometry, LX, LZ) - LHeight) / 0.0001;
        GroundworkToWorld(AGeometry, LU, LV + 0.0001, LX, LZ);
        LDV := (GroundworkSurfaceHeight(AGeometry, LX, LZ) - LHeight) / 0.0001;
        Check(Sqrt(Sqr(LDU) + Sqr(LDV)) < GroundworkMaximumGrade,
          'Actual landing gradient agrees with analytic admission bound');
      end;
    end;
  end;
  GroundworkToWorld(AGeometry, 0, 0, LX, LZ);
  Check(Abs(GroundworkSoilHeight(AGeometry, LX, LZ) - TerrainBaseHeight(LX, LZ)) < 1e-9,
    'Deck does not secretly flatten the soil underneath it');
end;

procedure CheckGeometry;
var
  LGeometry: TGroundworkGeometry;
  LMutated: TGroundworkGeometry;
  LReason: String;
  LAccepted: Integer;
  LRejected: Integer;
  LX: Integer;
  LZ: Integer;
  LTurn: Integer;
begin
  EmptyWorld(48);
  LAccepted := 0;
  LRejected := 0;
  for LZ := 1 to 45 do
  begin
    for LX := 1 to 45 do
    begin
      for LTurn := 0 to 3 do
      begin
        if PlanGroundworkGeometry(GWorld, LX, LZ, LTurn, LGeometry, LReason) then
        begin
          Inc(LAccepted);
          Check(ValidateGroundworkGeometry(GWorld, LGeometry, LReason), 'Decoded geometry admits');
          if (LX mod 7 = 1) and (LZ mod 11 = 1) then
          begin
            CheckAcceptedSurface(LGeometry);
          end;
          LMutated := LGeometry;
          Inc(LMutated.FToeY, 100);
          Check(not ValidateGroundworkGeometry(GWorld, LMutated, LReason),
            'Forged toe elevation rejects');
          LMutated := LGeometry;
          Inc(LMutated.FDeckY, 100);
          Check(not ValidateGroundworkGeometry(GWorld, LMutated, LReason),
            'Forged support datum rejects');
        end
        else
        begin
          Inc(LRejected);
          Check(LReason <> '', 'Rejected physical domain has an actionable reason');
        end;
      end;
    end;
  end;
  Check((LAccepted > 100) and (LRejected > 100), 'Corpus contains admitted and rejected geometry');
  WriteLn(LAccepted, ' admitted / ', LRejected, ' rejected cardinal plot candidates');
  { Critic regressions: the former flat toe differs by >10cm across this width. }
  Check(PlanGroundworkGeometry(GWorld, 12, 2, 0, LGeometry, LReason),
    'Full-width seam regression remains usable with a graded landing: ' + LReason);
  CheckAcceptedSurface(LGeometry);
  Check(not PlanGroundworkGeometry(GWorld, 32, 6, 0, LGeometry, LReason),
    'Dry midpoint does not admit a submerged lateral approach');
end;

procedure CheckAssemblies;
var
  LDocument: TCompositionDocument;
  LBaseline: TCompositionDocument;
  LOther: TCompositionDocument;
  LAssembly: TGroundworkAssembly;
  LIndex: TCompositionIndex;
  LReason: String;
  LId: String;
  LPartId: String;
  LAt: Integer;
  LChanged: Integer;
  LInvalid: Integer;
  LPurpose: TGroundworkPurpose;
  LTurn: Integer;
  LSeed: Integer;
  I: Integer;
begin
  for LPurpose := Low(TGroundworkPurpose) to High(TGroundworkPurpose) do
  begin
    for LTurn := 0 to 3 do
    begin
      for LSeed := 1 to 16 do
      begin
        EmptyWorld(48);
        LId := GroundworkId(23, 23);
        Check(CreateGroundwork(GWorld, 23, 23, LTurn, LPurpose, gbPlinth, LSeed,
          LDocument, LReason), 'Create domain groundwork: ' + LReason);
        Check((Length(LDocument.FNodes) = 19) and (LDocument.FRevision = 1),
          'Plot/deck/body/ramp/landing/core and twelve rim panels are persistent');
        Check((Length(GWorld.FComposition.FNodes) = 1) and (GWorld.FComposition.FRevision = 0),
          'Successful staged creation leaves baseline untouched');
        Check(CreateGroundwork(GWorld, 23, 23, LTurn, LPurpose, gbPlinth, LSeed,
          LOther, LReason), 'Repeated seeded generation succeeds');
        for I := 0 to High(LDocument.FNodes) do
        begin
          Check(SameNode(LDocument.FNodes[I], LOther.FNodes[I]), 'Seeded document is deterministic');
        end;
        GWorld.FComposition := LDocument;
        Check(ReadCompositionJSON(CompositionJSON(LDocument), LOther, LReason),
          'Groundwork parts round-trip through the existing composition wire format');
        for I := 0 to High(LDocument.FNodes) do
        begin
          Check(SameNode(LDocument.FNodes[I], LOther.FNodes[I]), 'Saved groundwork node is exact');
        end;
        Check(ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Independent profile admission: ' + LReason);
        Check(ValidateGroundworkMaterials(LAssembly, LReason), 'WFC output satisfies material contract');
        LBaseline := CopyDocument(LDocument);
        Check(not CreateGroundwork(GWorld, 23, 23, LTurn, LPurpose, gbPiers, LSeed,
          LDocument, LReason), 'Duplicate stable plot IDs reject');
        Check((LDocument.FRevision = LBaseline.FRevision) and
          (Length(LDocument.FNodes) = Length(LBaseline.FNodes)), 'Failed creation retains output');
        Check(not CreateGroundwork(GWorld, 24, 23, LTurn, LPurpose, gbPiers, LSeed,
          LDocument, LReason), 'Different ID with overlapping plot rejects');
        Check(not CreateGroundwork(GWorld, 25, 23, LTurn, LPurpose, gbPiers, LSeed,
          LDocument, LReason), 'Touching plot would alter approach apron and rejects');
        Check(CreateGroundwork(GWorld, 26, 23, LTurn, LPurpose, gbPiers, LSeed,
          LOther, LReason), 'Separated plot preserves neighboring assembly: ' + LReason);
        for I := 0 to High(LBaseline.FNodes) do
        begin
          Check(SameNode(LBaseline.FNodes[I], LOther.FNodes[I]), 'Outside plot nodes remain identical');
        end;
      end;
    end;
  end;
  EmptyWorld(48);
  LId := GroundworkId(23, 23);
  Check(CreateGroundwork(GWorld, 23, 23, 1, gpLaunchPad, gbPlinth, 71,
    LDocument, LReason), 'Replacement fixture creates');
  GWorld.FComposition := LDocument;
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LAt := LIndex.Find(LId + '.deck.core');
    GWorld.FComposition.FNodes[LAt].FLocked := True;
    LBaseline := CopyDocument(GWorld.FComposition);
    Check(not ReimagineGroundwork(GWorld, LId, LId + '.deck.body', gbPlinth, 700,
      LDocument, LReason), 'Same body request reports unchanged');
    Check(LDocument.FRevision = LBaseline.FRevision, 'Unchanged result does not consume a revision');
    Check(not ReimagineGroundwork(GWorld, LId, LId + '.deck.ramp', gbPiers, 701,
      LDocument, LReason), 'Immutable ramp scope is explicitly rejected');
    Check(ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Material mutation fixture admits');
    LInvalid := 99;
    LAssembly.FMaterials[0] := TGroundworkMaterial(LInvalid);
    Check(not ValidateGroundworkMaterials(LAssembly, LReason), 'Unknown material enum rejects');
    Check(ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Purpose mutation fixture admits');
    LAssembly.FPurpose := TGroundworkPurpose(LInvalid);
    Check(not ValidateGroundworkMaterials(LAssembly, LReason), 'Unknown purpose enum rejects');
    Check(not CreateGroundwork(GWorld, 1, 1, 0, TGroundworkPurpose(LInvalid), gbPlinth,
      77, LDocument, LReason), 'Create rejects unknown purpose before indexing');
    Check(not ReimagineGroundwork(GWorld, LId, LId, TGroundworkBody(LInvalid),
      77, LDocument, LReason), 'Replacement rejects unknown body before indexing');
    Check(ReimagineGroundwork(GWorld, LId, LId + '.deck.body', gbPiers, 72,
      LDocument, LReason), 'Body changes beneath a stable locked core: ' + LReason);
    LChanged := 0;
    for I := 0 to High(LDocument.FNodes) do
    begin
      if not SameNode(LBaseline.FNodes[I], LDocument.FNodes[I]) then
      begin
        Inc(LChanged);
        Check(LDocument.FNodes[I].FId = LId + '.deck.body', 'Only selected body changed');
      end;
    end;
    Check(LChanged = 1, 'Substructure recipe actually changed');
    GWorld.FComposition := LDocument;
    LPartId := GroundworkPartId(LId, 0);
    LChanged := 0;
    for LSeed := 1 to 32 do
    begin
      LBaseline := CopyDocument(GWorld.FComposition);
      Check(ReimagineGroundwork(GWorld, LId, LPartId, gbPlinth, LSeed,
        LDocument, LReason), 'One panel can resolve with frozen surroundings');
      for I := 0 to High(LDocument.FNodes) do
      begin
        if not SameNode(LBaseline.FNodes[I], LDocument.FNodes[I]) then
        begin
          Inc(LChanged);
          Check(LDocument.FNodes[I].FId = LPartId, 'One-panel edit preserves every neighboring node');
        end;
      end;
      GWorld.FComposition := LDocument;
    end;
    Check(LChanged > 0, 'Single-panel WFC produces real alternatives');
    LBaseline := CopyDocument(GWorld.FComposition);
    GWorld.FComposition := CopyDocument(LBaseline);
    GWorld.FComposition.FNodes[0].FX := 1000;
    Check(not ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Shifted root cannot alter physical frame');
    GWorld.FComposition := CopyDocument(LBaseline);
    LAt := LIndex.Find(LId + '.deck.ramp');
    GWorld.FComposition := CopyDocument(LBaseline);
    GWorld.FComposition.FNodes[LAt].FX := 0;
    GWorld.FComposition.FNodes[LAt].FZ := 8000;
    Check(not ReadGroundwork(GWorld, LId, LAssembly, LReason),
      'Rotated ramp at unrotated origin is rejected');
    GWorld.FComposition := CopyDocument(LBaseline);
    LAt := LIndex.Find(LId + '.deck.core');
    Inc(GWorld.FComposition.FNodes[LAt].FX, 1);
    Check(not ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Shifted continuous core rejects');
    GWorld.FComposition := CopyDocument(LBaseline);
    LAt := LIndex.Find(LId + '.deck.body');
    GWorld.FComposition.FNodes[LAt].FAssetId := 'phanes.groundworks.unknown.v1';
    Check(not ReadGroundwork(GWorld, LId, LAssembly, LReason), 'Unknown support profile rejects');
    GWorld.FComposition := CopyDocument(LBaseline);
    LAt := LIndex.Find(LId + '.deck');
    GWorld.FComposition.FNodes[LAt].FLocked := True;
    LBaseline := CopyDocument(GWorld.FComposition);
    LDocument := CopyDocument(LBaseline);
    Check(not ReimagineGroundwork(GWorld, LId, LId, gbPlinth, 74,
      LDocument, LReason), 'Locked deck rejects a request with no editable parts');
    Check(LDocument.FRevision = LBaseline.FRevision, 'Rejected lock edit preserves revision');
    for I := 0 to High(LDocument.FNodes) do
    begin
      Check(SameNode(LBaseline.FNodes[I], LDocument.FNodes[I]), 'Deck lock protects every dependent part');
    end;
  finally
    LIndex.Free;
  end;
end;

procedure CheckWorldTransactions;
var
  LRequest: TWorldRequest;
  LWorld: TWorld;
  LBaseline: TWorld;
  LCreated: TWorld;
  LIndex: TCompositionIndex;
  LReason: String;
  LId: String;
  LX: Integer;
  LZ: Integer;
  LSide: Integer;
  LDivisor: Integer;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  EmptyWorld(8);
  LRequest := Default(TWorldRequest);
  LRequest.FSize := 8;
  LRequest.FSeed := 503;
  LRequest.FX := 3;
  LRequest.FZ := 3;
  LRequest.FWidth := 2;
  LRequest.FDepth := 2;
  LRequest.FGroundworkTurn := -1;
  LRequest.FOperation := 'foundation';
  SetLength(LRequest.FAssets, 2);
  LRequest.FAssets[0].FId := 'cabin';
  LRequest.FAssets[0].FKind := 'cabin';
  LRequest.FAssets[1].FId := 'nature-kit/tree_oak';
  LRequest.FAssets[1].FKind := 'tree';
  GWorld.FLayers[1][27] := 'cabin';
  GWorld.FLayers[3][27] := 'cabin';
  GWorld.FLayers[2][104] := 'tree';
  GWorld.FLayers[4][104] := 'nature-kit/tree_oak';
  LRequest.FPrevious := GWorld;
  LBaseline := GWorld;
  Check(ValidateWorld(LBaseline, LRequest.FAssets, LReason), 'Regional clearance fixture admits');
  LRequest.FPrevious.FComposition := CopyDocument(LBaseline.FComposition);
  LRequest.FPrevious.FComposition.FRevision := High(Integer) - 1;
  Check(GenerateWorld(LRequest, LWorld, LReason), 'Last available revision supports one atomic creation');
  Check(LWorld.FComposition.FRevision = High(Integer), 'Temporary stages do not spend saved revisions');
  LRequest.FPrevious := LBaseline;
  Check(GenerateWorld(LRequest, LWorld, LReason), 'Worker core creates a visible-size plot: ' + LReason);
  Check(LWorld.FComposition.FRevision = LBaseline.FComposition.FRevision + 1,
    'Clearing and attaching supports publish exactly one revision');
  Check(ValidateWorld(LWorld, LRequest.FAssets, LReason), 'World validator admits exact groundworks');
  for I := 0 to 4 do
  begin
    LSide := LayerSize(8, I);
    LDivisor := LSide div 8;
    for J := 0 to High(LWorld.FLayers[I]) do
    begin
      LX := (J mod LSide) div LDivisor;
      LZ := (J div LSide) div LDivisor;
      if (LX < 3) or (LX > 4) or (LZ < 3) or (LZ > 4) then
      begin
        Check(LWorld.FLayers[I][J] = LBaseline.FLayers[I][J], 'Outside regional values stay exact');
      end
      else if I <> 0 then
      begin
        Check(LWorld.FLayers[I][J] = 'empty', 'Selected plot clears all overlapping placements');
      end;
    end;
  end;
  Check((LBaseline.FLayers[3][27] = 'cabin') and (LBaseline.FLayers[4][104] = 'nature-kit/tree_oak'),
    'Staged region edits preserve baseline arrays');
  LCreated := LWorld;
  LId := GroundworkId(3, 3);
  LRequest.FPrevious := LCreated;
  LRequest.FOperation := 'groundwork';
  LRequest.FObjectId := GroundworkPartId(LId, 0);
  LRequest.FSeed := 504;
  Check(GenerateWorld(LRequest, LWorld, LReason), 'World request can reimagine one rim panel');
  for I := 0 to 4 do
  begin
    for J := 0 to High(LWorld.FLayers[I]) do
    begin
      Check(LWorld.FLayers[I][J] = LCreated.FLayers[I][J], 'Panel edits preserve every regional layer');
    end;
  end;
  for I := 0 to High(LWorld.FComposition.FNodes) do
  begin
    if LWorld.FComposition.FNodes[I].FId <> LRequest.FObjectId then
    begin
      Check(SameNode(LWorld.FComposition.FNodes[I], LCreated.FComposition.FNodes[I]),
        'World edit preserves other support nodes');
    end;
  end;
  LCreated := LWorld;
  LRequest.FPrevious := LCreated;
  LRequest.FOperation := 'clear';
  LRequest.FWidth := 1;
  Check(not GenerateWorld(LRequest, LWorld, LReason), 'Partial plot clear rejects');
  LRequest.FWidth := 2;
  LRequest.FPrevious.FComposition := CopyDocument(LCreated.FComposition);
  LIndex := TCompositionIndex.Create(LRequest.FPrevious.FComposition.FNodes);
  try
    LAt := LIndex.Find(LId + '.deck.core');
    LRequest.FPrevious.FComposition.FNodes[LAt].FLocked := True;
    Check(not GenerateWorld(LRequest, LWorld, LReason), 'Clear cannot remove locked plot descendants');
    LRequest.FPrevious.FComposition.FNodes[LAt].FLocked := False;
    Check(GenerateWorld(LRequest, LWorld, LReason), 'Whole unlocked plot clears atomically');
    Check((Length(LWorld.FComposition.FNodes) = 1) and
      (LWorld.FComposition.FRevision = LCreated.FComposition.FRevision + 1),
      'Whole plot removal is a single undoable revision');
    LRequest.FOperation := 'restore';
    LRequest.FPrevious := LCreated;
    Check(GenerateWorld(LRequest, LWorld, LReason), 'Saved groundwork restores exactly');
    Check(CompositionJSON(LWorld.FComposition) = CompositionJSON(LCreated.FComposition),
      'Restore does not regenerate support materials');
    LRequest.FPrevious.FComposition := CopyDocument(LCreated.FComposition);
    Inc(LRequest.FPrevious.FComposition.FNodes[LAt].FX);
    Check(not GenerateWorld(LRequest, LWorld, LReason), 'World import rejects forged core position');
  finally
    LIndex.Free;
  end;
  LRequest.FPrevious := LCreated;
  LRequest.FX := High(Integer);
  Check(not GenerateWorld(LRequest, LWorld, LReason), 'Worker-core selection arithmetic rejects extremes');
end;

procedure CheckWholeGroundworkDocument;
var
  LDocument: TCompositionDocument;
  LBaseline: TCompositionDocument;
  LIndex: TCompositionIndex;
  LAssembly: TGroundworkAssembly;
  LReason: String;
  LAt: Integer;
begin
  EmptyWorld(48);
  Check(CreateGroundwork(GWorld, 23, 23, 0, gpFoundation, gbPlinth, 301,
    LDocument, LReason), 'Whole-document fixture first plot');
  GWorld.FComposition := LDocument;
  Check(CreateGroundwork(GWorld, 26, 23, 0, gpLaunchPad, gbPiers, 302,
    LDocument, LReason), 'Whole-document fixture second plot');
  GWorld.FComposition := LDocument;
  Check(ValidateGroundworks(GWorld, LReason), 'All recognized plots independently admit');
  LIndex := TCompositionIndex.Create(LDocument.FNodes);
  try
    LAt := LIndex.Find(GroundworkId(26, 23) + '.deck.core');
    GWorld.FComposition := CopyDocument(LDocument);
    Inc(GWorld.FComposition.FNodes[LAt].FX);
    Check(ReadGroundwork(GWorld, GroundworkId(23, 23), LAssembly, LReason),
      'Local decoder reports only its own assembly');
    Check(not ValidateGroundworks(GWorld, LReason), 'Whole admission catches malformed other plot');
    LBaseline := CopyDocument(LDocument);
    Check(not ReimagineGroundwork(GWorld, GroundworkId(23, 23),
      GroundworkId(23, 23) + '.deck.body', gbPiers, 303, LDocument, LReason),
      'Mutation cannot preserve a malformed other plot');
    Check(not CreateGroundwork(GWorld, 29, 23, 0, gpFoundation, gbPlinth, 304,
      LDocument, LReason), 'Creation cannot preserve a malformed other plot');
    Check((LDocument.FRevision = LBaseline.FRevision) and
      SameNode(LDocument.FNodes[LAt], LBaseline.FNodes[LAt]), 'Failed global admission preserves output');
    GWorld.FComposition := CopyDocument(LBaseline);
    GWorld.FComposition.FNodes[LAt].FParentId := 'world';
    Check(not ValidateGroundworks(GWorld, LReason), 'Reserved groundwork profile cannot be orphaned');
  finally
    LIndex.Free;
  end;
end;

procedure CheckLandscapeGroundworks;
var
  LLandscape: TLandscape;
  LAssembly: TGroundworkAssembly;
  LDocument: TCompositionDocument;
  LReason: String;
  LNearSignature: String;
  LFarSignature: String;
  LX: Double;
  LZ: Double;
  LTargetX: Double;
  LTargetZ: Double;
  LDX: Double;
  LDZ: Double;
  LToeX: Double;
  LToeZ: Double;
  LPatchX: Double;
  LPatchZ: Double;
  LCutHeight: Double;
  LLandingHeight: Double;
  LTurn: Integer;
  I: Integer;
begin
  LLandscape := TLandscape.Create;
  try
    for LTurn := 0 to 3 do
    begin
      EmptyWorld(48);
      Check(CreateGroundwork(GWorld, 23, 23, LTurn, gpFoundation, gbPlinth, 605,
        LDocument, LReason), 'Landscape fixture creates');
      GWorld.FComposition := LDocument;
      LLandscape.SetWorld(GWorld);
      Check(LLandscape.GroundworkCount = 1, 'Landscape caches one admitted support assembly');
      LAssembly := LLandscape.Groundwork(0);
      Check(Abs(LLandscape.Height(0, 0) - LAssembly.FGeometry.FDeckY / 1000) < 1e-8,
        'Standing surface follows the deck datum');
      Check(Abs(LLandscape.SoilHeight(0, 0) - TerrainBaseHeight(0, 0)) < 1e-8,
        'Soil beneath the deck stays at its own height');
      GroundworkToWorld(LAssembly.FGeometry, 0.65, 16.3, LX, LZ);
      GroundworkToWorld(LAssembly.FGeometry, 0.65, 6, LTargetX, LTargetZ);
      LDX := (LTargetX - LX) / 103;
      LDZ := (LTargetZ - LZ) / 103;
      Check(LLandscape.CanStand(LX, LZ), 'Full-radius approach starts beyond the landing');
      for I := 1 to 103 do
      begin
        LLandscape.Move(LX, LZ, LDX, LDZ);
      end;
      Check((Abs(LX - LTargetX) < 0.00001) and (Abs(LZ - LTargetZ) < 0.00001),
        'Actual movement reaches the deck from every cardinal ramp without a seam catch');
      GroundworkToWorld(LAssembly.FGeometry, 0.70, 11, LX, LZ);
      Check(not LLandscape.CanStand(LX, LZ), 'Ramp rail includes player radius and its own thickness');
      GroundworkToWorld(LAssembly.FGeometry, -1.23, 16.23, LX, LZ);
      Check(not LLandscape.CanStand(LX, LZ), 'Diagonal exit approach clears the actual square post');
      GroundworkToWorld(LAssembly.FGeometry, -1.25, 16.25, LX, LZ);
      Check(GroundworkAllowsStanding(LAssembly.FGeometry, LX, LZ, 0.28),
        'A diagonal approach beyond the square post remains clear');
      GroundworkToWorld(LAssembly.FGeometry, 7.7, 2, LX, LZ);
      Check(not LLandscape.CanStand(LX, LZ), 'Deck edge guard cannot be stepped through');
      GroundworkToWorld(LAssembly.FGeometry, 0, 14, LToeX, LToeZ);
      GroundworkToWorld(LAssembly.FGeometry, 0, 13.5, LPatchX, LPatchZ);
      LCutHeight := LLandscape.SoilPatchHeight(LToeX, LToeZ, LPatchX, LPatchZ);
      GroundworkToWorld(LAssembly.FGeometry, 0, 14.5, LPatchX, LPatchZ);
      LLandingHeight := LLandscape.SoilPatchHeight(LToeX, LToeZ, LPatchX, LPatchZ);
      Check(Abs(LLandingHeight - LCutHeight - GroundworkSlabMetres) < 0.00001,
        'Terrain patches retain both sides of the ramp underside step');
      LNearSignature := LLandscape.ChunkSignature(5, 5);
      LFarSignature := LLandscape.ChunkSignature(0, 0);
      Check(ReimagineGroundwork(GWorld, LAssembly.FId, LAssembly.FId + '.deck.body',
        gbPiers, 606, LDocument, LReason), 'Composition-only substructure edit succeeds');
      GWorld.FComposition := LDocument;
      LLandscape.SetWorld(GWorld);
      Check(LLandscape.ChunkSignature(5, 5) <> LNearSignature,
        'Composition-only edits invalidate affected chunk geometry');
      Check(LLandscape.ChunkSignature(0, 0) = LFarSignature,
        'Composition-only edits preserve distant chunk signatures');
      EmptyWorld(48);
      LLandscape.SetWorld(GWorld);
      Check(LLandscape.GroundworkCount = 0, 'Removing a plot drops the cached assembly');
      Check(Abs(LLandscape.Height(0, 0) - TerrainBaseHeight(0, 0)) < 1e-8,
        'Removed plots leave no stale standing surface');
    end;
    EmptyWorld(48);
    Check(CreateGroundwork(GWorld, 41, 38, 1, gpFoundation, gbPlinth, 605,
      LDocument, LReason), 'Near-water approach regression is admitted');
    GWorld.FComposition := LDocument;
    LLandscape.SetWorld(GWorld);
    LAssembly := LLandscape.Groundwork(0);
    GroundworkToWorld(LAssembly.FGeometry, 0, 17, LX, LZ);
    Check(not LLandscape.CanStand(LX, LZ), 'Old spawn outside the apron is submerged');
    GroundworkToWorld(LAssembly.FGeometry, 0, GroundworkPlotHalfMetres, LX, LZ);
    LTargetX := LX;
    LTargetZ := LZ;
    Check(LLandscape.FindStanding(LX, LZ), 'Approach start lies inside admitted dry land');
    Check((LX = LTargetX) and (LZ = LTargetZ), 'Entering the approach does not relocate the player');
  finally
    LLandscape.Free;
  end;
end;


procedure CheckSupportedBuildings;
var
  LRequest: TWorldRequest;
  LPlot: TWorld;
  LAttached: TWorld;
  LFurnished: TWorld;
  LResult: TWorld;
  LTampered: TWorld;
  LDocument: TCompositionDocument;
  LIndex: TCompositionIndex;
  LAssembly: TGroundworkAssembly;
  LProfile: TSupportedBuilding;
  LLandscape: TLandscape;
  LReason: String;
  LId: String;
  LSignature: String;
  LSnapshot: String;
  LLockIds: array[0..4] of String;
  LAt: Integer;
  LChild: Integer;
  LTurn: Integer;
  LPurpose: TGroundworkPurpose;
  LX: Double;
  LZ: Double;
  LTargetX: Double;
  LTargetZ: Double;
  LDX: Double;
  LDZ: Double;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LLandscape := TLandscape.Create;
  try
    for LPurpose := Low(TGroundworkPurpose) to High(TGroundworkPurpose) do
    begin
      for LTurn := 0 to 3 do
      begin
        EmptyWorld(8);
        Check(CreateGroundwork(GWorld, 3, 3, LTurn, LPurpose, gbPlinth, 701,
          LDocument, LReason), 'Supported building plot admits');
        LPlot := GWorld;
        LPlot.FComposition := LDocument;
        LRequest := Default(TWorldRequest);
        LRequest.FPrevious := LPlot;
        LRequest.FSize := 8;
        LRequest.FX := 3;
        LRequest.FZ := 3;
        LRequest.FWidth := 2;
        LRequest.FDepth := 2;
        LRequest.FSeed := 702;
        LRequest.FOperation := 'place-building';
        LRequest.FObjectId := GroundworkId(3, 3);
        LId := LRequest.FObjectId + '.deck.building';
        LLandscape.SetWorld(LPlot);
        LSignature := LLandscape.ChunkSignature(0, 0);
        for I := 0 to 6 do
        begin
          LProfile := SupportedBuildingAt(I);
          LRequest.FBuildingAsset := LProfile.FAssetId;
          Check(GenerateWorld(LRequest, LAttached, LReason), 'Admit all static profiles: ' + LReason);
          Check(Length(LAttached.FComposition.FNodes) = Length(LDocument.FNodes) + 1,
            'Attachment adds exactly one supported building');
          Check(LAttached.FComposition.FRevision = LDocument.FRevision + 1,
            'Attachment consumes exactly one revision');
          LAt := High(LAttached.FComposition.FNodes);
          Check(ValidSupportedBuilding(LAttached.FComposition.FNodes[LAt],
            LRequest.FObjectId + '.deck', LTurn), 'Exact local pose and explicit surface ownership');
          for J := 0 to High(LDocument.FNodes) do
          begin
            Check(SameNode(LDocument.FNodes[J], LAttached.FComposition.FNodes[J]),
              'Attachment preserves every support record');
          end;
          LLandscape.SetWorld(LAttached);
          Check(LLandscape.ChunkSignature(0, 0) <> LSignature, 'Building invalidates chunk cache');
          Check(not LLandscape.CanStand(0, 0), 'Building blocks its center');
          LAssembly := LLandscape.Groundwork(0);
          { Follow the approach and complete a square around the maximum keep
            envelope. This includes all four turns with the actual move substeps. }
          GroundworkToWorld(LAssembly.FGeometry, 0, 16, LX, LZ);
          for J := 0 to 5 do
          begin
            case J of
              0:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, 0, 7.5, LTargetX, LTargetZ);
                end;
              1:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, 7.5, 7.5, LTargetX, LTargetZ);
                end;
              2:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, 7.5, -7.5, LTargetX, LTargetZ);
                end;
              3:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, -7.5, -7.5, LTargetX, LTargetZ);
                end;
              4:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, -7.5, 7.5, LTargetX, LTargetZ);
                end;
              5:
                begin
                  GroundworkToWorld(LAssembly.FGeometry, 0, 7.5, LTargetX, LTargetZ);
                end;
            end;
            LDX := (LTargetX - LX) / 160;
            LDZ := (LTargetZ - LZ) / 160;
            for K := 1 to 160 do
            begin
              LLandscape.Move(LX, LZ, LDX, LDZ);
            end;
            Check((Abs(LX - LTargetX) < 0.00001) and (Abs(LZ - LTargetZ) < 0.00001),
              'All profiles retain the full walking circuit in every orientation');
          end;
          for J := 0 to 11 do
          begin
            LTampered := LAttached;
            LTampered.FComposition := CopyDocument(LAttached.FComposition);
            case J of
              0:
                begin
                  LTampered.FComposition.FNodes[LAt].FX := 1;
                end;
              1:
                begin
                  LTampered.FComposition.FNodes[LAt].FY := -1;
                end;
              2:
                begin
                  LTampered.FComposition.FNodes[LAt].FZ := 1;
                end;
              3:
                begin
                  LTampered.FComposition.FNodes[LAt].FQuarterTurn := (LTurn + 1) mod 4;
                end;
              4:
                begin
                  LTampered.FComposition.FNodes[LAt].FSupportId := '';
                end;
              5:
                begin
                  LTampered.FComposition.FNodes[LAt].FSupportId := LRequest.FObjectId + '.deck.core';
                end;
              6:
                begin
                  LTampered.FComposition.FNodes[LAt].FParentId := LRequest.FObjectId;
                end;
              7:
                begin
                  LTampered.FComposition.FNodes[LAt].FAssetId := 'unknown';
                end;
              8:
                begin
                  LTampered.FComposition.FNodes[LAt].FRole := 'unknown';
                end;
              9:
                begin
                  LTampered.FComposition.FNodes[LAt].FKind := ckObject;
                end;
              10:
                begin
                  LTampered.FComposition.FNodes[LAt].FId := LId + '.extra';
                end;
              11:
                begin
                  SetLength(LTampered.FComposition.FNodes, LAt + 2);
                  LTampered.FComposition.FNodes[LAt + 1] := Default(TCompositionNode);
                  LTampered.FComposition.FNodes[LAt + 1].FId := LId + '.extra';
                  LTampered.FComposition.FNodes[LAt + 1].FParentId := LId;
                  LTampered.FComposition.FNodes[LAt + 1].FKind := ckContainer;
                  LTampered.FComposition.FNodes[LAt + 1].FRole := 'unknown';
                end;
            end;
            Check(not ValidateGroundworks(LTampered, LReason), 'Forged supported subtree rejects');
          end;
        end;
      end;
    end;
    LRequest.FPrevious := LPlot;
    LRequest.FBuildingAsset := 'cabin';
    Check(GenerateWorld(LRequest, LAttached, LReason), 'Cabin attachment fixture');
    LRequest.FPrevious := LAttached;
    LRequest.FPrevious.FComposition := CopyDocument(LAttached.FComposition);
    LRequest.FPrevious.FComposition.FNodes[High(LAttached.FComposition.FNodes)].FName :=
      'My Observatory';
    LRequest.FBuildingAsset := 'keep';
    Check(GenerateWorld(LRequest, LResult, LReason), 'Unfurnished shell replacement admits');
    Check(LResult.FComposition.FNodes[High(LResult.FComposition.FNodes)].FName = 'My Observatory',
      'Stable building identity retains a custom name across replacement');
    LTampered := LAttached;
    LTampered.FLayers[1] := nil;
    Check(not ValidateGroundworks(LTampered, LReason), 'Missing regional arrays reject cleanly');
    Check(not CreateGroundwork(LTampered, 1, 1, 0, gpFoundation, gbPlinth, 999,
      LDocument, LReason), 'Public creation rejects incomplete baseline without exception');
    LRequest.FPrevious := LAttached;
    LRequest.FOperation := 'create-interior';
    LRequest.FObjectId := LId;
    LRequest.FPrevious.FComposition := CopyDocument(LAttached.FComposition);
    LRequest.FPrevious.FComposition.FRevision := High(Integer) - 1;
    Check(GenerateWorld(LRequest, LResult, LReason), 'Furnishing works at last available revision');
    Check(LResult.FComposition.FRevision = High(Integer), 'Private content solves spend no revisions');
    LRequest.FPrevious := LAttached;
    Check(GenerateWorld(LRequest, LFurnished, LReason), 'Supported cabin owns a complete studio: ' + LReason);
    LIndex := TCompositionIndex.Create(LFurnished.FComposition.FNodes);
    try
      LAt := LIndex.Find(LId);
      LChild := -1;
      for I := 0 to High(LFurnished.FComposition.FNodes) do
      begin
        if LFurnished.FComposition.FNodes[I].FRole = 'ornament' then
        begin
          LChild := I;
          Break;
        end;
      end;
      Check(LChild >= 0, 'Furnished supported cabin retains individual ceramic ornament');
      LLockIds[0] := GroundworkId(3, 3);
      LLockIds[1] := LLockIds[0] + '.deck';
      LLockIds[2] := LId;
      LLockIds[3] := LId + '.studio';
      LLockIds[4] := LFurnished.FComposition.FNodes[LChild].FId;
      for I := 0 to 4 do
      begin
        LRequest.FPrevious := LFurnished;
        LRequest.FPrevious.FComposition := CopyDocument(LFurnished.FComposition);
        LRequest.FPrevious.FComposition.FNodes[LIndex.Find(LLockIds[I])].FLocked := True;
        LSnapshot := CompositionJSON(LRequest.FPrevious.FComposition);
        LRequest.FObjectId := LId;
        LRequest.FOperation := 'remove-building';
        Check(not GenerateWorld(LRequest, LResult, LReason), 'Every ancestor and descendant lock rejects removal');
        Check(CompositionJSON(LRequest.FPrevious.FComposition) = LSnapshot,
          'Failed edit preserves baseline exactly');
      end;
      LRequest.FOperation := 'groundwork';
      LRequest.FObjectId := GroundworkId(3, 3) + '.deck.body';
      LRequest.FGroundworkBody := 'piers';
      Check(GenerateWorld(LRequest, LResult, LReason), 'Locked ornament permits compatible body edit');
      for I := 0 to High(LFurnished.FComposition.FNodes) do
      begin
        if InCompositionScope(LFurnished.FComposition, LIndex, I, LId) then
        begin
          Check(SameNode(LRequest.FPrevious.FComposition.FNodes[I], LResult.FComposition.FNodes[I]),
            'Body edit keeps entire building subtree and locks byte-identical');
        end;
      end;
      LRequest.FPrevious := LFurnished;
      LRequest.FOperation := 'place-building';
      LRequest.FObjectId := LId;
      LRequest.FBuildingAsset := 'keep';
      Check(not GenerateWorld(LRequest, LResult, LReason), 'Replacement cannot orphan the furnished studio');
      LTampered := LFurnished;
      LTampered.FComposition := CopyDocument(LFurnished.FComposition);
      LTampered.FComposition.FNodes[LAt].FAssetId := 'keep';
      Check(not ValidateGroundworks(LTampered, LReason), 'Imported studio cannot be hosted by keep');
      LTampered.FComposition := CopyDocument(LFurnished.FComposition);
      LTampered.FComposition.FNodes[LChild].FParentId := GroundworkId(3, 3) + '.deck.body';
      LTampered.FComposition.FNodes[LChild].FSupportId := '';
      Check(not ValidateGroundworks(LTampered, LReason), 'Unknown descendants cannot hide under support body');
      LRequest.FOperation := 'remove-building';
      Check(GenerateWorld(LRequest, LResult, LReason), 'Unlocked building removes as explicit transaction');
      Check(Length(LResult.FComposition.FNodes) = Length(LPlot.FComposition.FNodes),
        'Removal keeps only original plot assembly');
    finally
      LIndex.Free;
    end;
  finally
    LLandscape.Free;
  end;
end;

begin
  CheckTransforms;
  CheckContext;
  CheckGeometry;
  CheckAssemblies;
  CheckWholeGroundworkDocument;
  CheckWorldTransactions;
  CheckLandscapeGroundworks;
  CheckSupportedBuildings;
  WriteLn(GChecks, ' groundwork geometry and composition checks passed');
end.
