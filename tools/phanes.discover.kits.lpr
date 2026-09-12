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

program PhanesDiscoverKits;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  StrUtils,
  Process,
  FPJSON,
  JSONParser,
  RegExpr,
  Zipper,
  phanes.tools.files;

procedure Fetch(const AUrl, APath: String);
var
  LProcess: TProcess;
begin
  if FileExists(APath) then
  begin
    Exit;
  end;
  Require(Copy(AUrl, 1, 8) = 'https://', 'Expected HTTPS source');
  ForceDirectories(ExtractFileDir(APath));
  LProcess := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    LProcess.Executable := 'curl.exe';
    {$ELSE}
    LProcess.Executable := 'curl';
    {$ENDIF}
    LProcess.Parameters.Add('--fail');
    LProcess.Parameters.Add('--location');
    LProcess.Parameters.Add('--silent');
    LProcess.Parameters.Add('--show-error');
    LProcess.Parameters.Add('--proto');
    LProcess.Parameters.Add('=https');
    LProcess.Parameters.Add('--proto-redir');
    LProcess.Parameters.Add('=https');
    LProcess.Parameters.Add('--max-time');
    LProcess.Parameters.Add('60');
    LProcess.Parameters.Add('--retry');
    LProcess.Parameters.Add('2');
    LProcess.Parameters.Add('--retry-delay');
    LProcess.Parameters.Add('1');
    LProcess.Parameters.Add('--speed-limit');
    LProcess.Parameters.Add('1024');
    LProcess.Parameters.Add('--speed-time');
    LProcess.Parameters.Add('15');
    LProcess.Parameters.Add('--max-filesize');
    LProcess.Parameters.Add('134217728');
    LProcess.Parameters.Add('--output');
    LProcess.Parameters.Add(APath + '.part');
    LProcess.Parameters.Add(AUrl);
    LProcess.Options := [poWaitOnExit, poNoConsole];
    LProcess.Execute;
    Require(LProcess.ExitStatus = 0, 'Source fetch failed: ' + AUrl);
    Require(RenameFile(APath + '.part', APath), 'Could not publish source download');
  finally
    LProcess.Free;
  end;
end;

type
  TAliasDiscovery = class
  private
    FZip: TUnZipper;
    FRoot: String;
    FNames: TStringList;
    FAliases: TJSONArray;
    procedure CreateStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  public
    function Run(const AZip: TUnZipper; const ARoot: String): TJSONArray;
  end;

procedure TAliasDiscovery.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  Require(AItem.Size <= 32 * 1024 * 1024, 'Model source exceeds discovery bound');
  AStream := TMemoryStream.Create;
end;

procedure TAliasDiscovery.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
const
  CGroups: array[0..1] of String = ('images', 'buffers');
var
  LBytes: TBytes;
  LModel: TJSONObject;
  LGroup: TJSONArray;
  LUri: String;
  LTarget: String;
  LSource: String;
  LFound: Integer;
  LAlready: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LModel := nil;
  try
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      AStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    LModel := ModelJSON(LBytes, ExtractFileExt(AItem.ArchiveFileName));
    for I := 0 to High(CGroups) do
    begin
      if LModel.Find(CGroups[I]) = nil then
      begin
        Continue;
      end;
      LGroup := LModel.Arrays[CGroups[I]];
      for J := 0 to LGroup.Count - 1 do
      begin
        LUri := LGroup.Objects[J].Get('uri', '');
        if (LUri = '') or (Copy(LUri, 1, 5) = 'data:') then
        begin
          Continue;
        end;
        Require((Pos(':', LUri) = 0) and (Pos('%', LUri) = 0) and
          (Pos('\', LUri) = 0) and (LUri[1] <> '/'), 'Unsupported discovery dependency URI');
        LTarget := ExtractRelativePath(IncludeTrailingPathDelimiter(FRoot),
          ExpandFileName(ExtractFilePath(SafeChild(FRoot, AItem.ArchiveFileName)) + LUri));
        SafeChild(FRoot, LTarget);
        LTarget := StringReplace(LTarget, PathDelim, '/', [rfReplaceAll]);
        if FNames.IndexOf(LTarget) >= 0 then
        begin
          Continue;
        end;
        LAlready := False;
        for K := 0 to FAliases.Count - 1 do
        begin
          if FAliases.Objects[K].Strings['to'] = LTarget then
          begin
            LAlready := True;
          end;
        end;
        if LAlready then
        begin
          Continue;
        end;
        LFound := 0;
        LSource := '';
        for K := 0 to FNames.Count - 1 do
        begin
          { These creator exports include separate Unreal normal maps. The glTF
            recipe uses the ordinary OpenGL texture set, never that alternative. }
          if (ExtractFileName(FNames[K]) = ExtractFileName(LTarget)) and
            (Pos('/Normals-UnrealEngine/', FNames[K]) = 0) then
          begin
            Inc(LFound);
            LSource := FNames[K];
          end;
        end;
        Require(LFound = 1, 'Missing dependency needs an unambiguous source: ' + LTarget);
        FAliases.Add(TJSONObject.Create(['from', LSource, 'to', LTarget]));
      end;
    end;
  finally
    LModel.Free;
    FreeAndNil(AStream);
  end;
end;

function TAliasDiscovery.Run(const AZip: TUnZipper; const ARoot: String): TJSONArray;
var
  LModels: TStringList;
  LName: String;
  I: Integer;
begin
  FZip := AZip;
  FRoot := SafeChild(ARoot, 'build/asset-research/alias-frame');
  FNames := TStringList.Create;
  FNames.Sorted := True;
  FNames.CaseSensitive := True;
  FNames.UseLocale := False;
  FAliases := TJSONArray.Create;
  LModels := TStringList.Create;
  try
    for I := 0 to FZip.Entries.Count - 1 do
    begin
      LName := FZip.Entries[I].ArchiveFileName;
      FNames.Add(LName);
      if SameText(ExtractFileExt(LName), '.gltf') or
        SameText(ExtractFileExt(LName), '.glb') then
      begin
        LModels.Add(LName);
      end;
    end;
    FZip.OnCreateStream := CreateStream;
    FZip.OnDoneStream := DoneStream;
    Require(LModels.Count > 0, 'No declared models for dependency discovery');
    FZip.UnZipFiles(LModels);
    Result := FAliases;
    FAliases := nil;
  finally
    FZip.OnCreateStream := nil;
    FZip.OnDoneStream := nil;
    LModels.Free;
    FAliases.Free;
    FNames.Free;
  end;
end;
function Theme(const AId: String): String;
begin
  if (Pos('nature', AId) > 0) or (Pos('forest', AId) > 0) or
    (Pos('cave', AId) > 0) then
  begin
    Exit('nature');
  end;
  if (Pos('space', AId) > 0) or (Pos('blaster', AId) > 0) then
  begin
    Exit('sci-fi');
  end;
  if (Pos('furniture', AId) > 0) or (Pos('food', AId) > 0) then
  begin
    Exit('interior');
  end;
  if (Pos('castle', AId) > 0) or (Pos('dungeon', AId) > 0) then
  begin
    Exit('medieval');
  end;
  if (Pos('fantasy', AId) > 0) or (Pos('pirate', AId) > 0) then
  begin
    Exit('fantasy');
  end;
  Result := 'mixed';
end;

procedure Discover(const ARoot: String);
var
  LLock: TJSONObject;
  LKit: TJSONObject;
  LResult: TJSONObject;
  LSkipped: TJSONArray;
  LPages: TStringList;
  LIds: TStringList;
  LLinks: TRegExpr;
  LZip: TUnZipper;
  LText: String;
  LPath: String;
  LUrl: String;
  LId: String;
  LArchiveUrl: String;
  LArchive: String;
  LGLBs: Integer;
  I: Integer;
  J: Integer;
begin
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LSkipped := TJSONArray.Create;
  LResult := TJSONObject.Create;
  LPages := TStringList.Create;
  LIds := TStringList.Create;
  LLinks := TRegExpr.Create;
  try
    LResult.Add('skipped', LSkipped);
    LPages.Sorted := True;
    LPages.Duplicates := dupIgnore;
    LIds.Sorted := True;
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LIds.Add(LLock.Arrays['kits'].Objects[I].Strings['id']);
    end;
    for I := 1 to 4 do
    begin
      LPath := SafeChild(ARoot, 'build/asset-research/kenney-3d-' + IntToStr(I) + '.html');
      Fetch('https://kenney.nl/assets/category:3D/page:' + IntToStr(I), LPath);
      LText := ReadText(LPath);
      LLinks.Expression := 'https://kenney.nl/assets/[a-z0-9-]+[''"]';
      if LLinks.Exec(LText) then
      begin
        repeat
          LUrl := LLinks.Match[0];
          Delete(LUrl, Length(LUrl), 1);
          LPages.Add(LUrl);
        until not LLinks.ExecNext;
      end;
    end;
    WriteLn('Discovered ', LPages.Count, ' source pages');
    for I := 0 to LPages.Count - 1 do
    begin
      LUrl := LPages[I];
      LId := Copy(LUrl, Length('https://kenney.nl/assets/') + 1, MaxInt);
      if LIds.IndexOf(LId) >= 0 then
      begin
        Continue;
      end;
      try
        LPath := SafeChild(ARoot, 'build/asset-research/' + LId + '.html');
        Fetch(LUrl, LPath);
        LText := ReadText(LPath);
        Require(Pos('creativecommons.org/publicdomain/zero/', LText) > 0,
          'No CC0 link on source page');
        LLinks.Expression := 'https://kenney.nl/media/pages/assets/[^''"<> ]+\.zip';
        Require(LLinks.Exec(LText), 'No original ZIP download link');
        LArchiveUrl := LLinks.Match[0];
        LArchive := SafeChild(ARoot, 'build/asset-research/' + LId + '.zip');
        Fetch(LArchiveUrl, LArchive);
        LGLBs := 0;
        LZip := TUnZipper.Create;
        try
          LZip.FileName := LArchive;
          LZip.Examine;
          for J := 0 to LZip.Entries.Count - 1 do
          begin
            if SameText(ExtractFileExt(LZip.Entries[J].ArchiveFileName), '.glb') then
            begin
              Inc(LGLBs);
            end;
          end;
        finally
          LZip.Free;
        end;
        Require(LGLBs > 0, 'Source has no GLB files; conversion needs a separate reviewed recipe');
        LKit := TJSONObject.Create(['id', LId, 'page', LUrl,
          'archiveSha256', HashFile(LArchive), 'archiveUrl', LArchiveUrl,
          'license', 'CC0-1.0', 'author', 'Kenney', 'theme', Theme(LId),
          'storage', 'library', 'retrieved', FormatDateTime('yyyy-mm-dd', Now)]);
        LLock.Arrays['kits'].Add(LKit);
        WriteLn(LId, ': ', LGLBs, ' GLBs; source pinned');
      except
        on LException: Exception do
        begin
          LSkipped.Add(TJSONObject.Create(['id', LId, 'reason', LException.Message]));
          WriteLn(LId, ': skipped: ', LException.Message);
        end;
      end;
      { Persist only a candidate lock. Import still requires a deliberate manifest edit. }
      WriteText(SafeChild(ARoot, 'build/asset-research/kits.candidate.lock.json'),
        LLock.FormatJSON + #10);
      WriteText(SafeChild(ARoot, 'build/asset-research/discovery-report.json'),
        LResult.FormatJSON + #10);
      Flush(Output);
    end;
  finally
    LLinks.Free;
    LIds.Free;
    LPages.Free;
    LResult.Free;
    LLock.Free;
  end;
end;

procedure DiscoverKayKit(const ARoot: String);
var
  LReposData: TJSONData;
  LRepos: TJSONArray;
  LRepo: TJSONObject;
  LCommit: TJSONObject;
  LLock: TJSONObject;
  LKit: TJSONObject;
  LZip: TUnZipper;
  LIds: TStringList;
  LPath: String;
  LId: String;
  LUrl: String;
  LArchive: String;
  LPrefix: String;
  LLicense: String;
  LName: String;
  LFormat: String;
  LFormatCount: Integer;
  I: Integer;
  J: Integer;
begin
  LPath := SafeChild(ARoot, 'build/asset-research/kaykit-repos.json');
  Fetch('https://api.github.com/users/KayKit-Game-Assets/repos?per_page=100', LPath);
  LReposData := GetJSON(ReadText(LPath), True);
  Require(LReposData is TJSONArray, 'Expected original creator repository listing');
  LRepos := TJSONArray(LReposData);
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LIds := TStringList.Create;
  try
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LIds.Add(LLock.Arrays['kits'].Objects[I].Strings['id']);
    end;
    for I := 0 to LRepos.Count - 1 do
    begin
      LRepo := LRepos.Objects[I];
      Require(LRepo.Objects['owner'].Strings['login'] = 'KayKit-Game-Assets',
        'Unexpected repository owner');
      LId := StringReplace(LowerCase(LRepo.Strings['name']), '.', '-', [rfReplaceAll]);
      if LIds.IndexOf(LId) >= 0 then
      begin
        Continue;
      end;
      LCommit := nil;
      LZip := nil;
      try
        try
          LPath := SafeChild(ARoot, 'build/asset-research/' + LId + '-commit.json');
          Fetch('https://api.github.com/repos/' + LRepo.Strings['full_name'] +
            '/commits/' + LRepo.Strings['default_branch'], LPath);
          LCommit := LoadJSON(LPath);
          Require(Length(LCommit.Strings['sha']) = 40, 'Expected exact source commit');
          LUrl := 'https://codeload.github.com/' + LRepo.Strings['full_name'] +
            '/zip/' + LCommit.Strings['sha'];
          LArchive := SafeChild(ARoot, 'build/asset-research/' + LId + '.zip');
          Fetch(LUrl, LArchive);
          LZip := TUnZipper.Create;
          LZip.FileName := LArchive;
          LZip.Examine;
          LLicense := '';
          LPrefix := '';
          LFormat := 'gltf2';
          LFormatCount := 0;
          for J := 0 to LZip.Entries.Count - 1 do
          begin
            LName := LZip.Entries[J].ArchiveFileName;
            if (Pos('/addons/', LName) > 0) and
              SameText(ExtractFileName(LName), 'LICENSE.txt') then
            begin
              LLicense := LName;
            end;
            if (SameText(ExtractFileExt(LName), '.gltf') or
              SameText(ExtractFileExt(LName), '.glb')) and (Pos('/Assets/', LName) > 0) then
            begin
              LPrefix := Copy(LName, 1, Pos('/Assets/', LName) + Length('/Assets/') - 1);
              Inc(LFormatCount);
            end;
          end;
          Require((LLicense <> '') and (LFormatCount > 0), 'Expected licensed glTF asset folder');
          LKit := TJSONObject.Create(['id', LId, 'page', LRepo.Strings['html_url'],
            'archiveSha256', HashFile(LArchive), 'archiveUrl', LUrl,
            'sourceCommit', LCommit.Strings['sha'], 'license', 'CC0-1.0',
            'author', 'Kay Lousberg', 'theme', Theme(LId), 'storage', 'library',
            'modelFormat', LFormat, 'modelPrefix', LPrefix, 'licensePath', LLicense,
            'retrieved', FormatDateTime('yyyy-mm-dd', Now)]);
          LLock.Arrays['kits'].Add(LKit);
          WriteLn(LId, ': ', LFormatCount, ' glTF source files; commit/archive pinned');
        except
          on LException: Exception do
          begin
            WriteLn(LId, ': skipped: ', LException.Message);
          end;
        end;
      finally
        LZip.Free;
        LCommit.Free;
      end;
      WriteTextAtomic(SafeChild(ARoot, 'build/asset-research/kits.kaykit.candidate.lock.json'),
        LLock.FormatJSON + #10);
      Flush(Output);
    end;
  finally
    LIds.Free;
    LLock.Free;
    LReposData.Free;
  end;
end;

procedure DiscoverQuaternius(const ARoot: String);
var
  LAliasDiscovery: TAliasDiscovery;
  LAliases: TJSONArray;
  LPages: TStringList;
  LArchives: TStringList;
  LIds: TStringList;
  LLinks: TRegExpr;
  LLock: TJSONObject;
  LReport: TJSONObject;
  LSkipped: TJSONArray;
  LKit: TJSONObject;
  LZip: TUnZipper;
  LPath: String;
  LText: String;
  LUrl: String;
  LId: String;
  LBaseId: String;
  LArchive: String;
  LPrefix: String;
  LLicense: String;
  LName: String;
  LCount: Integer;
  LFirstModel: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LPages := TStringList.Create;
  LPages.Sorted := True;
  LPages.Duplicates := dupIgnore;
  LArchives := TStringList.Create;
  LArchives.Sorted := True;
  LArchives.Duplicates := dupIgnore;
  LIds := TStringList.Create;
  LLinks := TRegExpr.Create;
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LReport := TJSONObject.Create;
  LSkipped := TJSONArray.Create;
  LReport.Add('skipped', LSkipped);
  try
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LIds.Add(LLock.Arrays['kits'].Objects[I].Strings['id']);
    end;
    for I := 0 to 4 do
    begin
      LPath := SafeChild(ARoot, 'build/asset-research/quaternius-oga-' + IntToStr(I) + '.html');
      Fetch('https://opengameart.org/users/quaternius?page=' + IntToStr(I), LPath);
      LLinks.Expression := 'href="(/content/[^"<>?# ]+)"';
      if LLinks.Exec(ReadText(LPath)) then
      begin
        repeat
          LPages.Add('https://opengameart.org' + LLinks.Match[1]);
        until not LLinks.ExecNext;
      end;
    end;
    WriteLn('Found ', LPages.Count, ' creator submission pages.');
    Flush(Output);
    for I := 0 to LPages.Count - 1 do
    begin
      LUrl := LPages[I];
      LBaseId := 'quaternius-' + Copy(LUrl, LastDelimiter('/', LUrl) + 1, MaxInt);
      try
        Require(Pos('universal-animation-library', LBaseId) = 0,
          'Animation libraries require separate clip accounting and playback admission');
        LPath := SafeChild(ARoot, 'build/asset-research/' + LBaseId + '.html');
        Fetch(LUrl, LPath);
        LText := ReadText(LPath);
        Require(Pos('name="dcterms.creator" content="quaternius"', LText) > 0,
          'Not a creator-authored submission');
        Require(Pos('creativecommons.org/publicdomain/zero/', LText) > 0,
          'No original CC0 declaration');
        LArchives.Clear;
        LLinks.Expression := 'href="(https://opengameart.org/sites/default/files/[^"<> ]+\.zip)"';
        if LLinks.Exec(LText) then
        begin
          repeat
            LArchives.Add(LLinks.Match[1]);
          until not LLinks.ExecNext;
        end;
        Require(LArchives.Count > 0, 'No original ZIP archive');
        for J := 0 to LArchives.Count - 1 do
        begin
          LId := LBaseId;
          if LArchives.Count > 1 then
          begin
            LId := LId + '-' + IntToStr(J + 1);
          end;
          if LIds.IndexOf(LId) >= 0 then
          begin
            Continue;
          end;
          try
            LAliases := nil;
            LArchive := SafeChild(ARoot, 'build/asset-research/' + LId + '.zip');
            Fetch(LArchives[J], LArchive);
            LZip := TUnZipper.Create;
            try
              LZip.FileName := LArchive;
              LZip.Examine;
              LLicense := '';
              LPrefix := '';
              LCount := 0;
              LFirstModel := True;
              for K := 0 to LZip.Entries.Count - 1 do
              begin
                LName := LZip.Entries[K].ArchiveFileName;
                if (Copy(LowerCase(ExtractFileName(LName)), 1, 7) = 'license') and
                  (SameText(ExtractFileExt(LName), '.txt') or
                  SameText(ExtractFileExt(LName), '.md')) then
                begin
                  LLicense := LName;
                end;
                if SameText(ExtractFileExt(LName), '.gltf') or
                  SameText(ExtractFileExt(LName), '.glb') then
                begin
                  if LFirstModel then
                  begin
                    LPrefix := Copy(LName, 1, LastDelimiter('/', LName));
                    LFirstModel := False;
                  end
                  else
                  begin
                    while (LPrefix <> '') and (Copy(LName, 1, Length(LPrefix)) <> LPrefix) do
                    begin
                      Delete(LPrefix, Length(LPrefix), 1);
                      LPrefix := Copy(LPrefix, 1, LastDelimiter('/', LPrefix));
                    end;
                  end;
                  Inc(LCount);
                end;
              end;
              Require(LCount > 0, 'No glTF 2.0 source files; conversion not yet admitted');
              LAliasDiscovery := TAliasDiscovery.Create;
              try
                LAliases := LAliasDiscovery.Run(LZip, ARoot);
              finally
                LAliasDiscovery.Free;
              end;
              { Original exports may share a texture directory above glTF. Keep
                their complete relative frame; web packaging later selects only
                the inventoried model/dependency closure and retained notice. }
              LPrefix := '';
            finally
              LZip.Free;
            end;
            LKit := TJSONObject.Create(['id', LId, 'page', LUrl,
              'archiveSha256', HashFile(LArchive), 'archiveUrl', LArchives[J],
              'license', 'CC0-1.0', 'author', 'Quaternius', 'theme', Theme(LId),
              'storage', 'library', 'modelFormat', 'gltf2', 'modelPrefix', LPrefix,
              'retrieved', FormatDateTime('yyyy-mm-dd', Now)]);
            if LLicense <> '' then
            begin
              LKit.Add('licensePath', LLicense);
            end
            else
            begin
              LKit.Add('licenseEvidence', TJSONObject.Create([
                'mode', 'oga-submission.v1', 'url', LUrl, 'sha256', HashFile(LPath)]));
              WriteBytes(SafeChild(ARoot, 'build/asset-research/' + LId + '-license.html'),
                ReadBytes(LPath));
            end;
            if (LAliases <> nil) and (LAliases.Count > 0) then
            begin
              LKit.Add('dependencyAliases', LAliases);
            end
            else
            begin
              LAliases.Free;
            end;
            LAliases := nil;
            LLock.Arrays['kits'].Add(LKit);
            LIds.Add(LId);
            WriteLn(LId, ': ', LCount, ' glTF files; archive pinned for review');
          except
            on LException: Exception do
            begin
              LSkipped.Add(TJSONObject.Create(['id', LId, 'page', LUrl,
                'archiveUrl', LArchives[J], 'reason', LException.Message]));
              LAliases.Free;
              WriteLn(LId, ': skipped: ', LException.Message);
            end;
          end;
          Flush(Output);
        end;
      except
        on LException: Exception do
        begin
          LSkipped.Add(TJSONObject.Create(['id', LBaseId, 'page', LUrl,
            'reason', LException.Message]));
          WriteLn(LBaseId, ': skipped: ', LException.Message);
        end;
      end;
      WriteTextAtomic(SafeChild(ARoot, 'build/asset-research/kits.quaternius.candidate.lock.json'),
        LLock.FormatJSON + #10);
      WriteTextAtomic(SafeChild(ARoot, 'build/asset-research/quaternius-discovery.json'),
        LReport.FormatJSON + #10);
      Flush(Output);
    end;
  finally
    LReport.Free;
    LLock.Free;
    LLinks.Free;
    LIds.Free;
    LArchives.Free;
    LPages.Free;
  end;
end;
begin
  try
    Require((ParamCount = 1) or ((ParamCount = 2) and
      ((ParamStr(2) = 'kaykit') or (ParamStr(2) = 'quaternius'))),
      'Usage: phanes.discover.kits repository-root [kaykit|quaternius]');
    if (ParamCount = 2) and (ParamStr(2) = 'quaternius') then
    begin
      DiscoverQuaternius(ExpandFileName(ParamStr(1)));
    end
    else if ParamCount = 2 then
    begin
      DiscoverKayKit(ExpandFileName(ParamStr(1)));
    end
    else
    begin
      Discover(ExpandFileName(ParamStr(1)));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
