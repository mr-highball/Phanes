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

program PhanesCatalogInspect;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  FPJSON,
  CastleScene,
  CastleBoxes,
  CastleVectors,
  phanes.tools.files,
  phanes.tools.fingerprint;

procedure Inspect(const ARoot: String);
var
  LInventory: TJSONObject;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LAsset: TJSONObject;
  LRow: TJSONObject;
  LScene: TCastleScene;
  LBounds: TBox3D;
  LBase: String;
  LPath: String;
  LFailed: Integer;
  LHashes: TStringList;
  LHash: String;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LInventory := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LReport := TJSONObject.Create(['version', 1, 'scope',
    'CGE static decode and transformed bounds; not physical placement or animation admission',
    'inventorySha256', HashFile(SafeChild(ARoot, 'data/asset-inventory.json'))]);
  LRows := TJSONArray.Create;
  LReport.Add('assets', LRows);
  LFailed := 0;
  LHashes := TStringList.Create;
  LHashes.Sorted := True;
  LHashes.Duplicates := dupIgnore;
  try
    for I := 0 to LInventory.Arrays['assets'].Count - 1 do
    begin
      LAsset := LInventory.Arrays['assets'].Objects[I];
      LRow := TJSONObject.Create(['id', LAsset.Strings['id'],
        'sha256', LAsset.Strings['sha256']]);
      LRows.Add(LRow);
      LBase := 'cge/data';
      if LAsset.Get('storage', 'core') = 'library' then
      begin
        LBase := 'assets/library';
      end;
      LPath := SafeChild(SafeChild(ARoot, LBase), LAsset.Strings['url']);
      LScene := TCastleScene.Create(nil);
      try
        try
          Require(HashFile(LPath) = LAsset.Strings['sha256'], 'Model changed after inventory');
          LScene.Load(LPath);
          LBounds := LScene.BoundingBox;
          Require(not LBounds.IsEmpty, 'Decoded scene is empty');
          for J := 0 to 1 do
          begin
            for K := 0 to 2 do
            begin
              Require(not IsNan(LBounds.Data[J].Data[K]) and
                not IsInfinite(LBounds.Data[J].Data[K]), 'Nonfinite transformed bounds');
            end;
          end;
          Require(LScene.TrianglesCount > 0, 'No rendered triangles');
          LHash := StaticGeometryHash(LScene);
          LHashes.Add(LHash);
          LRow.Add('staticGeometryHash', LHash);
          LRow.Add('status', 'decoded');
          LRow.Add('triangles', Int64(LScene.TrianglesCount));
          LRow.Add('minimum', TJSONArray.Create([LBounds.Data[0].X,
            LBounds.Data[0].Y, LBounds.Data[0].Z]));
          LRow.Add('maximum', TJSONArray.Create([LBounds.Data[1].X,
            LBounds.Data[1].Y, LBounds.Data[1].Z]));
        except
          on LException: Exception do
          begin
            Inc(LFailed);
            LRow.Add('status', 'quarantined');
            LRow.Add('reason', LException.Message);
            WriteLn(LAsset.Strings['id'], ': ', LException.Message);
          end;
        end;
      finally
        LScene.Free;
      end;
      if (I + 1) mod 100 = 0 then
      begin
        WriteLn('Decoded ', I + 1, ' / ', LInventory.Arrays['assets'].Count);
        Flush(Output);
      end;
    end;
    LReport.Add('decoded', LRows.Count - LFailed);
    LReport.Add('quarantined', LFailed);
    LReport.Add('staticGeometryGroups', LHashes.Count);
    LReport.Add('groupingRecipe', 'phanes.static.geometry.v1');
    LReport.Add('groupingScope', 'Current-pose triangles, translation and uniform scale normalized; '+
      'one-millionth-extent quantization; ignores winding, materials, UVs and normals. '+
      'Grouping aid only, not proof of distinct model families or equivalent animation.');
    WriteTextAtomic(SafeChild(ARoot, 'data/catalog-geometry.json'), LReport.FormatJSON + #10);
    WriteLn('CGE inspected ', LRows.Count, ' models; ', LFailed, ' quarantined; ',
      LHashes.Count, ' static geometry groups');
  finally
    LReport.Free;
    LHashes.Free;
    LInventory.Free;
  end;
end;

begin
  try
    Require(ParamCount = 1, 'Usage: phanes.catalog.inspect repository-root');
    Inspect(ExpandFileName(ParamStr(1)));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
