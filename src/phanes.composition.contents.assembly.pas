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

unit phanes.composition.contents.assembly;

{$mode delphi}
{$H+}

interface

uses
  phanes.composition.types,
  phanes.composition.document,
  phanes.composition.contents.types;

type
  { Doubles represent exact integer/half-millimetre coordinates here. The
    validated 128-level signed-32-bit hierarchy remains below 2^53. }
  TContentBounds = record
    FEmpty: Boolean;
    FMinX: Double;
    FMinY: Double;
    FMinZ: Double;
    FMaxX: Double;
    FMaxY: Double;
    FMaxZ: Double;
  end;

  TContentAssemblies = class
  private
    FDocument: TCompositionDocument;
    FAssets: TContentAssets;
    FIndex: TCompositionIndex;
    FFirstChild: array of Integer;
    FNextChild: array of Integer;
    FFirstSupported: array of Integer;
    FNextSupported: array of Integer;
    function ReadObject(const ANode: Integer; const AAssetId: String;
      const ADepth: Integer; out ABounds: TContentBounds; out AReason: String): Boolean;
    function ReadSurface(const ANode: Integer; const AProfile: TContentSupport;
      const ADepth: Integer; out ABounds: TContentBounds; out AReason: String): Boolean;
  public
    { Caller validates the document and catalog before constructing this reader.
      It never mutates either input, and indexes child/support edges once. }
    constructor Create(const ADocument: TCompositionDocument; const AAssets: TContentAssets);
    destructor Destroy; override;
    function Bounds(const AObjectId, ACandidateAssetId: String;
      out ABounds: TContentBounds; out AReason: String): Boolean;
    function HasChildren(const AObjectId: String): Boolean;
    function HasLockedDescendant(const AObjectId: String): Boolean;
  end;

function ValidateContentAssets(const AAssets: TContentAssets; out AReason: String): Boolean;
function TransformContentBounds(const ABounds: TContentBounds;
  const AX, AY, AZ, AQuarterTurn: Integer): TContentBounds;
function ContentBoundsFit(const ABounds: TContentBounds;
  const AWidth, ADepth, AHeight: Integer): Boolean;
function ContentSupportsAvailable(const ADocument: TCompositionDocument;
  const AObjectId: String; const AAsset: TContentAsset; out AReason: String): Boolean;
function EnsureContentSupports(var ADocument: TCompositionDocument;
  const AObject: TCompositionNode; const AAsset: TContentAsset; out AReason: String): Boolean;

implementation

uses
  Math;

function ValidDimension(const AValue: Integer): Boolean;
begin
  Result := (AValue > 0) and (AValue <= 1000000);
end;

function ValidKey(const AValue: String): Boolean;
var
  I: Integer;
begin
  Result := (AValue <> '') and (Length(AValue) <= 64);
  for I := 1 to Length(AValue) do
  begin
    if not (AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidateContentAssets(const AAssets: TContentAssets; out AReason: String): Boolean;
var
  LAsset: TContentAsset;
  LSupport: TContentSupport;
  LRole: String;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := False;
  for I := 0 to High(AAssets) do
  begin
    LAsset := AAssets[I];
    AReason := 'Invalid or grouped content asset: ' + LAsset.FId;
    if (LAsset.FId = '') or (LAsset.FRole = '') or not LAsset.FSingleInstance or
      not ValidDimension(LAsset.FWidth) or not ValidDimension(LAsset.FDepth) or
      not ValidDimension(LAsset.FHeight) or (Length(LAsset.FSupports) > 32) then
    begin
      Exit;
    end;
    for J := 0 to I - 1 do
    begin
      if AAssets[J].FId = LAsset.FId then
      begin
        AReason := 'Duplicate content asset: ' + LAsset.FId;
        Exit;
      end;
    end;
    for J := 0 to High(LAsset.FSupports) do
    begin
      LSupport := LAsset.FSupports[J];
      AReason := 'Invalid usable support on content asset: ' + LAsset.FId;
      if not ValidKey(LSupport.FKey) or (LSupport.FRole = '') or
        (LSupport.FAssetId = '') or not ValidDimension(LSupport.FWidth) or
        not ValidDimension(LSupport.FDepth) or not ValidDimension(LSupport.FHeadroom) or
        (Abs(Double(LSupport.FX)) > 1000000) or (Abs(Double(LSupport.FY)) > 1000000) or
        (Abs(Double(LSupport.FZ)) > 1000000) or (LSupport.FQuarterTurn < 0) or
        (LSupport.FQuarterTurn > 3) or (Length(LSupport.FAllowedRoles) = 0) or
        (Length(LSupport.FAllowedRoles) > 32) then
      begin
        Exit;
      end;
      for LRole in LSupport.FAllowedRoles do
      begin
        if LRole = '' then
        begin
          Exit;
        end;
      end;
      for K := 0 to J - 1 do
      begin
        if LAsset.FSupports[K].FKey = LSupport.FKey then
        begin
          AReason := 'Duplicate usable support key on ' + LAsset.FId;
          Exit;
        end;
      end;
    end;
  end;
  AReason := '';
  Result := True;
end;

procedure IncludeBounds(var ABounds: TContentBounds; const AOther: TContentBounds);
begin
  if AOther.FEmpty then
  begin
    Exit;
  end;
  if ABounds.FEmpty then
  begin
    ABounds := AOther;
    Exit;
  end;
  ABounds.FMinX := Min(ABounds.FMinX, AOther.FMinX);
  ABounds.FMinY := Min(ABounds.FMinY, AOther.FMinY);
  ABounds.FMinZ := Min(ABounds.FMinZ, AOther.FMinZ);
  ABounds.FMaxX := Max(ABounds.FMaxX, AOther.FMaxX);
  ABounds.FMaxY := Max(ABounds.FMaxY, AOther.FMaxY);
  ABounds.FMaxZ := Max(ABounds.FMaxZ, AOther.FMaxZ);
end;

function TransformContentBounds(const ABounds: TContentBounds;
  const AX, AY, AZ, AQuarterTurn: Integer): TContentBounds;
begin
  Result := ABounds;
  if ABounds.FEmpty then
  begin
    Exit;
  end;
  case AQuarterTurn of
    1:
      begin
        Result.FMinX := ABounds.FMinZ;
        Result.FMaxX := ABounds.FMaxZ;
        Result.FMinZ := -ABounds.FMaxX;
        Result.FMaxZ := -ABounds.FMinX;
      end;
    2:
      begin
        Result.FMinX := -ABounds.FMaxX;
        Result.FMaxX := -ABounds.FMinX;
        Result.FMinZ := -ABounds.FMaxZ;
        Result.FMaxZ := -ABounds.FMinZ;
      end;
    3:
      begin
        Result.FMinX := -ABounds.FMaxZ;
        Result.FMaxX := -ABounds.FMinZ;
        Result.FMinZ := ABounds.FMinX;
        Result.FMaxZ := ABounds.FMaxX;
      end;
  end;
  Result.FMinX := Result.FMinX + AX;
  Result.FMaxX := Result.FMaxX + AX;
  Result.FMinY := Result.FMinY + AY;
  Result.FMaxY := Result.FMaxY + AY;
  Result.FMinZ := Result.FMinZ + AZ;
  Result.FMaxZ := Result.FMaxZ + AZ;
end;

function ContentBoundsFit(const ABounds: TContentBounds;
  const AWidth, ADepth, AHeight: Integer): Boolean;
begin
  Result := ABounds.FEmpty or ((ABounds.FMinX >= -AWidth / 2) and
    (ABounds.FMaxX <= AWidth / 2) and (ABounds.FMinZ >= -ADepth / 2) and
    (ABounds.FMaxZ <= ADepth / 2) and (ABounds.FMinY >= 0) and
    (ABounds.FMaxY <= AHeight));
end;

function BoundsOverlap(const ALeft, ARight: TContentBounds): Boolean;
begin
  Result := not ALeft.FEmpty and not ARight.FEmpty and
    (ALeft.FMinX < ARight.FMaxX) and (ALeft.FMaxX > ARight.FMinX) and
    (ALeft.FMinY < ARight.FMaxY) and (ALeft.FMaxY > ARight.FMinY) and
    (ALeft.FMinZ < ARight.FMaxZ) and (ALeft.FMaxZ > ARight.FMinZ);
end;

constructor TContentAssemblies.Create(const ADocument: TCompositionDocument;
  const AAssets: TContentAssets);
var
  LParent: Integer;
  I: Integer;
begin
  inherited Create;
  FDocument := ADocument;
  FAssets := AAssets;
  FIndex := TCompositionIndex.Create(ADocument.FNodes);
  SetLength(FFirstChild, Length(ADocument.FNodes));
  SetLength(FNextChild, Length(ADocument.FNodes));
  SetLength(FFirstSupported, Length(ADocument.FNodes));
  SetLength(FNextSupported, Length(ADocument.FNodes));
  for I := 0 to High(FFirstChild) do
  begin
    FFirstChild[I] := -1;
    FFirstSupported[I] := -1;
    FNextChild[I] := -1;
    FNextSupported[I] := -1;
  end;
  for I := 0 to High(FFirstChild) do
  begin
    LParent := FIndex.Find(ADocument.FNodes[I].FParentId);
    if LParent >= 0 then
    begin
      FNextChild[I] := FFirstChild[LParent];
      FFirstChild[LParent] := I;
    end;
    LParent := FIndex.Find(ADocument.FNodes[I].FSupportId);
    if LParent >= 0 then
    begin
      FNextSupported[I] := FFirstSupported[LParent];
      FFirstSupported[LParent] := I;
    end;
  end;
end;

destructor TContentAssemblies.Destroy;
begin
  FIndex.Free;
  inherited Destroy;
end;

function TContentAssemblies.ReadSurface(const ANode: Integer;
  const AProfile: TContentSupport; const ADepth: Integer;
  out ABounds: TContentBounds; out AReason: String): Boolean;
var
  LNode: TCompositionNode;
  LChild: Integer;
  LBounds: TContentBounds;
  LSiblings: array of TContentBounds;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  ABounds := Default(TContentBounds);
  ABounds.FEmpty := True;
  LNode := FDocument.FNodes[ANode];
  AReason := 'A nested support does not match its admitted profile: ' + LNode.FId;
  if (LNode.FKind <> ckSurface) or (LNode.FSupportId <> '') or
    (LNode.FRole <> AProfile.FRole) or (LNode.FAssetId <> AProfile.FAssetId) or
    (LNode.FX <> AProfile.FX) or (LNode.FY <> AProfile.FY) or
    (LNode.FZ <> AProfile.FZ) or (LNode.FQuarterTurn <> AProfile.FQuarterTurn) then
  begin
    Exit;
  end;
  LChild := FFirstSupported[ANode];
  while LChild >= 0 do
  begin
    if FDocument.FNodes[LChild].FParentId <> LNode.FId then
    begin
      AReason := 'A nested support has an externally owned dependent: ' + LNode.FId;
      Exit;
    end;
    LChild := FNextSupported[LChild];
  end;
  LChild := FFirstChild[ANode];
  while LChild >= 0 do
  begin
    AReason := 'Invalid nested support contact or role: ' + FDocument.FNodes[LChild].FId;
    if (FDocument.FNodes[LChild].FSupportId <> LNode.FId) or
      (FDocument.FNodes[LChild].FY <> 0) or
      not ContentRoleAllowed(AProfile.FAllowedRoles, FDocument.FNodes[LChild].FRole) then
    begin
      Exit;
    end;
    if not ReadObject(LChild, '', ADepth + 1, LBounds, AReason) then
    begin
      Exit;
    end;
    LBounds := TransformContentBounds(LBounds, FDocument.FNodes[LChild].FX,
      FDocument.FNodes[LChild].FY, FDocument.FNodes[LChild].FZ,
      FDocument.FNodes[LChild].FQuarterTurn);
    if not ContentBoundsFit(LBounds, AProfile.FWidth, AProfile.FDepth, AProfile.FHeadroom) then
    begin
      AReason := 'A complete nested item exceeds its usable support: ' +
        FDocument.FNodes[LChild].FId;
      Exit;
    end;
    for I := 0 to High(LSiblings) do
    begin
      if BoundsOverlap(LSiblings[I], LBounds) then
      begin
        AReason := 'Nested assemblies overlap on support: ' + LNode.FId;
        Exit;
      end;
    end;
    LCount := Length(LSiblings);
    SetLength(LSiblings, LCount + 1);
    LSiblings[LCount] := LBounds;
    IncludeBounds(ABounds, LBounds);
    LChild := FNextChild[LChild];
  end;
  Result := True;
end;

function TContentAssemblies.ReadObject(const ANode: Integer; const AAssetId: String;
  const ADepth: Integer; out ABounds: TContentBounds; out AReason: String): Boolean;
var
  LNode: TCompositionNode;
  LAsset: TContentAsset;
  LChildBounds: TContentBounds;
  LSupportBounds: array of TContentBounds;
  LAssetId: String;
  LAssetIndex: Integer;
  LChild: Integer;
  LProfile: Integer;
  I: Integer;
  J: Integer;
begin
  Result := False;
  ABounds := Default(TContentBounds);
  ABounds.FEmpty := True;
  LNode := FDocument.FNodes[ANode];
  LAssetId := AAssetId;
  if LAssetId = '' then
  begin
    LAssetId := LNode.FAssetId;
  end;
  LAssetIndex := ContentAssetIndex(FAssets, LAssetId);
  AReason := 'Unadmitted nested content geometry: ' + LNode.FId;
  if (LNode.FKind <> ckObject) or (LAssetIndex < 0) or (ADepth > 128) then
  begin
    Exit;
  end;
  LAsset := FAssets[LAssetIndex];
  if (AAssetId = '') and (LNode.FRole <> LAsset.FRole) then
  begin
    Exit;
  end;
  ABounds.FEmpty := False;
  ABounds.FMinX := -LAsset.FWidth / 2;
  ABounds.FMaxX := LAsset.FWidth / 2;
  ABounds.FMinZ := -LAsset.FDepth / 2;
  ABounds.FMaxZ := LAsset.FDepth / 2;
  ABounds.FMaxY := LAsset.FHeight;
  LChild := FFirstChild[ANode];
  while LChild >= 0 do
  begin
    LProfile := -1;
    for I := 0 to High(LAsset.FSupports) do
    begin
      if FDocument.FNodes[LChild].FId = LNode.FId + '.' + LAsset.FSupports[I].FKey then
      begin
        LProfile := I;
        Break;
      end;
    end;
    if LProfile < 0 then
    begin
      AReason := 'No admitted support retains child: ' + FDocument.FNodes[LChild].FId;
      Exit;
    end;
    if not ReadSurface(LChild, LAsset.FSupports[LProfile], ADepth + 1,
      LChildBounds, AReason) then
    begin
      Exit;
    end;
    LChildBounds := TransformContentBounds(LChildBounds,
      FDocument.FNodes[LChild].FX, FDocument.FNodes[LChild].FY,
      FDocument.FNodes[LChild].FZ, FDocument.FNodes[LChild].FQuarterTurn);
    for J := 0 to High(LSupportBounds) do
    begin
      if BoundsOverlap(LSupportBounds[J], LChildBounds) then
      begin
        AReason := 'Contents on separate supports overlap inside ' + LNode.FId;
        Exit;
      end;
    end;
    J := Length(LSupportBounds);
    SetLength(LSupportBounds, J + 1);
    LSupportBounds[J] := LChildBounds;
    { This is an occupancy union for neighboring assemblies. The parent's
      bounding box is not a solid collider: declared supports can occupy a
      cavity, such as food inside a plate's rim or books inside a bookcase. }
    IncludeBounds(ABounds, LChildBounds);
    LChild := FNextChild[LChild];
  end;
  AReason := '';
  Result := True;
end;

function TContentAssemblies.Bounds(const AObjectId, ACandidateAssetId: String;
  out ABounds: TContentBounds; out AReason: String): Boolean;
var
  LNode: Integer;
begin
  ABounds := Default(TContentBounds);
  ABounds.FEmpty := True;
  LNode := FIndex.Find(AObjectId);
  AReason := 'Select an existing content assembly: ' + AObjectId;
  Result := (LNode >= 0) and ReadObject(LNode, ACandidateAssetId, 0, ABounds, AReason);
end;

function TContentAssemblies.HasChildren(const AObjectId: String): Boolean;
var
  LNode: Integer;
begin
  LNode := FIndex.Find(AObjectId);
  Result := (LNode >= 0) and (FFirstChild[LNode] >= 0);
end;

function TContentAssemblies.HasLockedDescendant(const AObjectId: String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FDocument.FNodes) do
  begin
    if FDocument.FNodes[I].FLocked and (FDocument.FNodes[I].FId <> AObjectId) and
      InCompositionScope(FDocument, FIndex, I, AObjectId) then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function ContentSupportsAvailable(const ADocument: TCompositionDocument;
  const AObjectId: String; const AAsset: TContentAsset; out AReason: String): Boolean;
var
  LSupport: TContentSupport;
  LId: String;
  I: Integer;
begin
  Result := False;
  for LSupport in AAsset.FSupports do
  begin
    LId := AObjectId + '.' + LSupport.FKey;
    AReason := 'The support identity exceeds the saved identifier limit: ' + LId;
    if Length(LId) > 128 then
    begin
      Exit;
    end;
    for I := 0 to High(ADocument.FNodes) do
    begin
      if (ADocument.FNodes[I].FId = LId) and
        (ADocument.FNodes[I].FParentId <> AObjectId) then
      begin
        AReason := 'A support identity already belongs to another object: ' + LId;
        Exit;
      end;
    end;
  end;
  AReason := '';
  Result := True;
end;

function EnsureContentSupports(var ADocument: TCompositionDocument;
  const AObject: TCompositionNode; const AAsset: TContentAsset; out AReason: String): Boolean;
var
  LSupport: TContentSupport;
  LNode: TCompositionNode;
  LId: String;
  LFound: Boolean;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  { Domain construction performs the same check. Recheck before mutation. }
  if not ContentSupportsAvailable(ADocument, AObject.FId, AAsset, AReason) then
  begin
    Exit;
  end;
  for LSupport in AAsset.FSupports do
  begin
    LId := AObject.FId + '.' + LSupport.FKey;
    LFound := False;
    for I := 0 to High(ADocument.FNodes) do
    begin
      if ADocument.FNodes[I].FId = LId then
      begin
        LFound := True;
        Break;
      end;
    end;
    if LFound then
    begin
      Continue;
    end;
    LNode := Default(TCompositionNode);
    LNode.FId := LId;
    LNode.FParentId := AObject.FId;
    LNode.FName := LSupport.FName;
    LNode.FRole := LSupport.FRole;
    LNode.FAssetId := LSupport.FAssetId;
    LNode.FKind := ckSurface;
    LNode.FX := LSupport.FX;
    LNode.FY := LSupport.FY;
    LNode.FZ := LSupport.FZ;
    LNode.FQuarterTurn := LSupport.FQuarterTurn;
    LNode.FSeed := AObject.FSeed;
    LCount := Length(ADocument.FNodes);
    SetLength(ADocument.FNodes, LCount + 1);
    ADocument.FNodes[LCount] := LNode;
  end;
  AReason := '';
  Result := True;
end;

end.
