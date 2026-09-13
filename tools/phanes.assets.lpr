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

program PhanesAssets;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, FPJSON,
  phanes.catalog.regional,
  phanes.tools.files,
  phanes.tools.kits,
  phanes.tools.catalog,
  phanes.tools.pages,
  phanes.tools.music,
  phanes.tools.materials;

procedure PrepareRegionalPalette(const ARoot: String);
var
  LPalette: TJSONObject;
  LAssets: TJSONArray;
  LRow: TJSONObject;
  LIds: TRegionalAssetIds;
  LProfile: TRegionalAssetAdmission;
  I: Integer;
begin
  LPalette := LoadJSON(SafeChild(ARoot, 'data/palette.json'));
  try
    LAssets := LPalette.Arrays['assets'];
    for I := LAssets.Count - 1 downto 0 do
    begin
      if Pos('phanes.catalog.', LAssets.Objects[I].Strings['id']) = 1 then
      begin
        LAssets.Delete(I);
      end;
    end;
    LIds := RegionalAssetIds;
    for I := 0 to High(LIds) do
    begin
      Require(RegionalAssetAdmission(LIds[I], LProfile), 'Regional admission is missing');
      LRow := TJSONObject.Create;
      LRow.Add('id', LProfile.FId);
      LRow.Add('kind', LProfile.FRole);
      LRow.Add('theme', LProfile.FTheme);
      LRow.Add('name', UTF8Encode(LProfile.FName));
      LRow.Add('width', Max(LProfile.FWidth, LProfile.FDepth) / 2000);
      LAssets.Add(LRow);
    end;
    WriteTextAtomic(SafeChild(ARoot, 'data/palette.json'), LPalette.FormatJSON + #10);
    WriteLn('Prepared ', Length(LIds), ' optional regional palette choices.');
  finally
    LPalette.Free;
  end;
end;

var
  GRoot: String;
  GCommand: String;

begin
  try
    GRoot := GetCurrentDir;
    if ParamCount >= 2 then
    begin
      GRoot := ExpandFileName(ParamStr(2));
    end;
    GCommand := ParamStr(1);
    if GCommand = 'verify-kits' then
    begin
      VerifyKits(GRoot);
    end
    else if GCommand = 'import-kits' then
    begin
      ImportKits(GRoot);
      VerifyKits(GRoot);
      SummarizeCatalog(GRoot);
    end
    else if GCommand = 'package-catalog' then
    begin
      VerifyKits(GRoot);
      PackageCatalog(GRoot);
    end
    else if GCommand = 'stage-pages' then
    begin
      StagePages(GRoot);
    end
    else if GCommand = 'summarize-catalog' then
    begin
      VerifyKits(GRoot);
      SummarizeCatalog(GRoot);
    end
    else if GCommand = 'prepare-regional-palette' then
    begin
      PrepareRegionalPalette(GRoot);
      SummarizeCatalog(GRoot);
    end
    else if (GCommand = 'import-music') or (GCommand = 'verify-music') then
    begin
      ProcessMusic(GRoot, GCommand = 'verify-music');
    end
    else if (GCommand = 'import-materials') or (GCommand = 'verify-materials') then
    begin
      ProcessMaterials(GRoot, GCommand = 'import-materials');
    end
    else
    begin
      raise Exception.Create('Usage: phanes.assets verify-kits|import-kits|' +
        'import-music|verify-music|import-materials|verify-materials|' +
        'package-catalog|summarize-catalog|prepare-regional-palette|stage-pages [repository-root]');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
