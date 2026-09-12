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
unit phanes.composition.types;
{$mode delphi}
{$H+}

interface

type
  TCompositionKind = (ckContainer, ckSurface, ckObject);

  { Coordinates are local millimetres; quarter turns rotate about local up.
    This is semantic ownership and local placement, not a catalog admission or
    a collision certificate. Support geometry is checked by the domain adapter. }
  TCompositionNode = record
    FId: String;
    FParentId: String;
    FSupportId: String;
    FName: UnicodeString;
    FRole: String;
    FAssetId: String;
    FKind: TCompositionKind;
    FX: Integer;
    FY: Integer;
    FZ: Integer;
    FQuarterTurn: Integer;
    { Explicit container volume, centred in X/Z with its floor at Y=0.
      All zero retains an implicit admitted profile. Objects and surfaces use
      catalog geometry and cannot be resized through these fields. }
    FWidth: Integer;
    FDepth: Integer;
    FHeight: Integer;
    FSeed: Cardinal;
    FLocked: Boolean;
  end;

  TCompositionNodes = array of TCompositionNode;

  TCompositionDocument = record
    FRevision: Integer;
    FNodes: TCompositionNodes;
  end;

function SameNode(const ALeft, ARight: TCompositionNode): Boolean;
function HasCompositionExtent(const ANode: TCompositionNode): Boolean;
function CopyDocument(const ADocument: TCompositionDocument): TCompositionDocument;

implementation

function SameNode(const ALeft, ARight: TCompositionNode): Boolean;
begin
  Result := (ALeft.FId = ARight.FId) and
    (ALeft.FParentId = ARight.FParentId) and
    (ALeft.FSupportId = ARight.FSupportId) and
    (ALeft.FName = ARight.FName) and
    (ALeft.FRole = ARight.FRole) and
    (ALeft.FAssetId = ARight.FAssetId) and
    (ALeft.FKind = ARight.FKind) and
    (ALeft.FX = ARight.FX) and (ALeft.FY = ARight.FY) and (ALeft.FZ = ARight.FZ) and
    (ALeft.FQuarterTurn = ARight.FQuarterTurn) and
    (ALeft.FWidth = ARight.FWidth) and (ALeft.FDepth = ARight.FDepth) and
    (ALeft.FHeight = ARight.FHeight) and
    (ALeft.FSeed = ARight.FSeed) and (ALeft.FLocked = ARight.FLocked);
end;

function HasCompositionExtent(const ANode: TCompositionNode): Boolean;
begin
  Result := (ANode.FWidth <> 0) or (ANode.FDepth <> 0) or (ANode.FHeight <> 0);
end;

function CopyDocument(const ADocument: TCompositionDocument): TCompositionDocument;
begin
  Result.FRevision := ADocument.FRevision;
  Result.FNodes := Copy(ADocument.FNodes, 0, Length(ADocument.FNodes));
end;

end.
