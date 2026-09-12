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

unit phanes.world.types;

{$mode delphi}
{$H+}

interface

uses
  phanes.selection.grid,
  phanes.composition.types,
  phanes.terrain.types;

type
  TStringArray = array of String;

  TAsset = record
    FId: String;
    FKind: String;
    FTheme: String;
    FCluster: Integer;
  end;

  TAssets = array of TAsset;

  TRoom = record
    FParent: Integer;
    FSeed: Cardinal;
    FFurniture: TStringArray;
    FLooks: TStringArray;
    FTableware: TStringArray;
  end;

  TRooms = array of TRoom;

  TWorld = record
    FSize: Integer;
    FSeed: Cardinal;
    FAppearanceSeed: Cardinal;
    FElevation: TTerrainField;
    FRelativeElevation: Boolean;
    FLayers: array[0..4] of TStringArray;
    FRooms: TRooms;
    FComposition: TCompositionDocument;
    FDecisions: Integer;
    FPropagations: Integer;
    FBacktracks: Integer;
  end;

  TWorldRequest = record
    FSize: Integer;
    FSeed: Cardinal;
    FOperation: String;
    FLandformAmount: Integer;
    FX: Integer;
    FZ: Integer;
    FWidth: Integer;
    FDepth: Integer;
    FSelectionScale: Integer;
    FSelectionCells: TSelectionCells;
    FEditLayer: String;
    FExactAsset: String;
    FAssetChoices: TStringArray;
    FRoomCell: Integer;
    FObjectId: String;
    FContentAsset: String;
    FContentRole: String;
    FContentCount: Integer;
    FGroundworkTurn: Integer;
    FModulePose: Boolean;
    FModuleX: Integer;
    FModuleZ: Integer;
    FModuleTurn: Integer;
    FGroundworkBody: String;
    FBuildingAsset: String;
    FPlanProfile: String;
    FRoomProgram: String;
    FSpaceName: UnicodeString;
    FAssets: TAssets;
    FPrevious: TWorld;
  end;

function LayerSize(const AWorldSize, ALayer: Integer): Integer;
function LayerName(const ALayer: Integer): String;
function AssetKind(const AAssets: TAssets; const AId: String): String;
function InitialWorldComposition(const ASeed: Cardinal): TCompositionDocument;

implementation

function InitialWorldComposition(const ASeed: Cardinal): TCompositionDocument;
begin
  Result := Default(TCompositionDocument);
  SetLength(Result.FNodes, 1);
  Result.FNodes[0].FId := 'world';
  Result.FNodes[0].FName := 'World';
  Result.FNodes[0].FRole := 'world';
  Result.FNodes[0].FKind := ckContainer;
  Result.FNodes[0].FSeed := ASeed;
end;

function LayerSize(const AWorldSize, ALayer: Integer): Integer;
begin
  Result := AWorldSize;
  if (ALayer = 2) or (ALayer = 4) then
  begin
    Result := Result * 2;
  end;
end;

function LayerName(const ALayer: Integer): String;
begin
  case ALayer of
    0: Result := 'terrain';
    1: Result := 'architecture';
    2: Result := 'ecology';
    3: Result := 'buildings';
    4: Result := 'vegetation';
  end;
end;

function AssetKind(const AAssets: TAssets; const AId: String): String;
var
  LAsset: TAsset;
begin
  Result := '';
  for LAsset in AAssets do
  begin
    if LAsset.FId = AId then
    begin
      Exit(LAsset.FKind);
    end;
  end;
end;

end.
