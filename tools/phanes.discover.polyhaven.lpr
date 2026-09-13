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


program PhanesDiscoverPolyHaven;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Process,
  FPJSON,
  phanes.tools.files,
  phanes.tools.kits;

const
  ApiURL = 'https://api.polyhaven.com';
  DownloadURL = 'https://dl.polyhaven.org/file/ph-assets/Models/';
  UserAgent = 'Phanes-asset-tools/1.0';

type
  TFetchSlot = record
    FProcess: TProcess;
    FJob: TJSONObject;
  end;

procedure CheckSourceId(const AId: String);
var
  I: Integer;
begin
  Require((Length(AId) > 0) and (Length(AId) <= 100), 'Invalid source ID length');
  for I := 1 to Length(AId) do
  begin
    Require(AId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-'],
      'Unsupported source ID: ' + AId);
  end;
end;

procedure FetchBatch(const AJobs: TJSONArray);
var
  LSlots: array[0..3] of TFetchSlot;
  LNext: Integer;
  LActive: Integer;
  LComplete: Integer;
  LJob: TJSONObject;
  LPath: String;
  I: Integer;
begin
  for I := 0 to High(LSlots) do
  begin
    LSlots[I].FProcess := nil;
    LSlots[I].FJob := nil;
  end;
  LNext := 0;
  LActive := 0;
  LComplete := 0;
  try
    repeat
      for I := 0 to High(LSlots) do
      begin
        if (LSlots[I].FProcess <> nil) and (not LSlots[I].FProcess.Running) then
        begin
          LJob := LSlots[I].FJob;
          LPath := LJob.Strings['path'];
          if LSlots[I].FProcess.ExitStatus <> 0 then
          begin
            LJob.Add('error', 'Poly Haven API transfer failed');
          end
          else
          if not RenameFile(LPath + '.part', LPath) then
          begin
            LJob.Add('error', 'Could not publish API response');
          end;
          FreeAndNil(LSlots[I].FProcess);
          LSlots[I].FJob := nil;
          Dec(LActive);
          Inc(LComplete);
          if LComplete mod 25 = 0 then
          begin
            WriteLn('Poly Haven API metadata ', LComplete, ' / ', AJobs.Count);
            Flush(Output);
          end;
        end;
        while (LSlots[I].FProcess = nil) and (LNext < AJobs.Count) do
        begin
          LJob := AJobs.Objects[LNext];
          Inc(LNext);
          LPath := LJob.Strings['path'];
          Require(Copy(LJob.Strings['url'], 1, Length(ApiURL) + 1) = ApiURL + '/',
            'Unexpected API host');
          if FileExists(LPath) then
          begin
            Require(FileByteCount(LPath) <= 16 * 1024 * 1024, 'API cache exceeds bound');
            Inc(LComplete);
            Continue;
          end;
          ForceDirectories(ExtractFileDir(LPath));
          LSlots[I].FJob := LJob;
          LSlots[I].FProcess := TProcess.Create(nil);
          {$IFDEF WINDOWS}
          LSlots[I].FProcess.Executable := 'curl.exe';
          {$ELSE}
          LSlots[I].FProcess.Executable := 'curl';
          {$ENDIF}
          with LSlots[I].FProcess.Parameters do
          begin
            Add('--fail');
            Add('--silent');
            Add('--show-error');
            Add('--proto');
            Add('=https');
            Add('--user-agent');
            Add(UserAgent);
            Add('--max-time');
            Add('60');
            Add('--retry');
            Add('1');
            Add('--retry-delay');
            Add('1');
            Add('--max-filesize');
            Add('16777216');
            Add('--output');
            Add(LPath + '.part');
            Add(LJob.Strings['url']);
          end;
          LSlots[I].FProcess.Options := [poNoConsole];
          LSlots[I].FProcess.Execute;
          Inc(LActive);
        end;
      end;
      if LActive > 0 then
      begin
        Sleep(20);
      end;
    until (LNext = AJobs.Count) and (LActive = 0);
    WriteLn('Poly Haven metadata batch complete: ', LComplete);
    Flush(Output);
  finally
    for I := 0 to High(LSlots) do
    begin
      if LSlots[I].FProcess <> nil then
      begin
        if LSlots[I].FProcess.Running then
        begin
          LSlots[I].FProcess.Terminate(1);
        end;
        LSlots[I].FProcess.Free;
      end;
    end;
  end;
end;

function FileRecord(const APath, AId: String; const AData: TJSONObject): TJSONObject;
var
  LURL: String;
  LRelative: String;
  LHash: String;
  LParts: TStringList;
  LNumber: TJSONData;
  I: Integer;
begin
  CheckArchivePath(APath);
  LURL := AData.Strings['url'];
  Require(Copy(LURL, 1, Length(DownloadURL)) = DownloadURL, 'Unexpected model download host');
  LRelative := Copy(LURL, Length(DownloadURL) + 1, MaxInt);
  CheckArchivePath(LRelative);
  Require((Pos('%', LRelative) = 0) and (Pos('?', LRelative) = 0) and
    (Pos('#', LRelative) = 0), 'Encoded or indirect model download path');
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '/';
    LParts.DelimitedText := LRelative;
    Require((LParts.Count = 4) and (LParts[2] = AId), 'Download source identity differs');
    Require((LParts[0] = 'gltf') or (LParts[0] = 'jpg') or (LParts[0] = 'png'),
      'Unsupported original source format');
    Require(ExtractFileName(APath) = LParts[3], 'Local and original filename differ');
  finally
    LParts.Free;
  end;
  LHash := AData.Strings['md5'];
  Require(Length(LHash) = 32, 'Expected original MD5 pin');
  for I := 1 to Length(LHash) do
  begin
    Require(LHash[I] in ['a'..'f', '0'..'9'], 'Noncanonical original MD5 pin');
  end;
  LNumber := AData.Find('size');
  Require((LNumber is TJSONNumber) and
    (TJSONNumber(LNumber).NumberType in [ntInteger, ntInt64, ntQWord]),
    'Expected integer file size');
  Require((LNumber.AsInt64 > 0) and (LNumber.AsInt64 <= 512 * 1024 * 1024),
    'Original file size exceeds discovery bound');
  Result := TJSONObject.Create;
  Result.Add('path', APath);
  Result.Add('url', LURL);
  Result.Add('md5', LHash);
  Result.Add('bytes', LNumber.AsInt64);
end;

function Candidate(const AId: String; const AAsset, AResponse: TJSONObject): TJSONObject;
var
  LSource: TJSONObject;
  LIncludes: TJSONObject;
  LFiles: TJSONArray;
  LFile: TJSONObject;
  LNames: TStringList;
  LTotal: Int64;
  I: Integer;
begin
  Require(AAsset.Integers['type'] = 2, 'Source is not a model');
  Require((AResponse.Find('gltf') is TJSONObject) and
    (AResponse.Objects['gltf'].Find('1k') is TJSONObject) and
    (AResponse.Objects['gltf'].Objects['1k'].Find('gltf') is TJSONObject),
    'No original 1k glTF source');
  LSource := AResponse.Objects['gltf'].Objects['1k'].Objects['gltf'];
  Require(LSource.Find('include') is TJSONObject, 'Original glTF has no dependency listing');
  LIncludes := LSource.Objects['include'];
  Require(LIncludes.Count <= 128, 'Original dependency count exceeds bound');
  LFiles := TJSONArray.Create;
  LNames := TStringList.Create;
  Result := nil;
  try
    try
      LNames.Sorted := True;
      LNames.CaseSensitive := False;
      LNames.UseLocale := False;
      LFile := FileRecord(AId + '_1k.gltf', AId, LSource);
      LFiles.Add(LFile);
      LTotal := LFile.Int64s['bytes'];
      LNames.Add(LFile.Strings['path']);
      for I := 0 to LIncludes.Count - 1 do
      begin
        Require(LNames.IndexOf(LIncludes.Names[I]) < 0, 'Case-folded file collision');
        LNames.Add(LIncludes.Names[I]);
      end;
      for I := 0 to LNames.Count - 1 do
      begin
        if LNames[I] = AId + '_1k.gltf' then
        begin
          Continue;
        end;
        Require((ExtractFileExt(LNames[I]) = '.bin') or
          (ExtractFileExt(LNames[I]) = '.jpg') or (ExtractFileExt(LNames[I]) = '.png'),
          'Unsupported glTF dependency format');
        LFile := FileRecord(LNames[I], AId, LIncludes.Objects[LNames[I]]);
        LFiles.Add(LFile);
        Inc(LTotal, LFile.Int64s['bytes']);
      end;
      Require(LTotal <= Int64(1024) * 1024 * 1024, 'Original closure exceeds discovery bound');
      Result := TJSONObject.Create;
      Result.Add('id', AId);
      Result.Add('name', AAsset.Strings['name']);
      Result.Add('page', 'https://polyhaven.com/a/' + AId);
      Result.Add('authors', AAsset.Objects['authors'].Clone);
      Result.Add('sourceCategory', AAsset.Get('category', ''));
      Result.Add('sourceTags', AAsset.Arrays['tags'].Clone);
      if AAsset.Find('dimensions') is TJSONArray then
      begin
        Result.Add('sourceDimensions', AAsset.Arrays['dimensions'].Clone);
      end;
      Result.Add('sourcePolycount', AAsset.Get('polycount', Int64(0)));
      Result.Add('textureTier', '1k');
      Result.Add('status', 'discovery-only');
      Result.Add('declaredDownloadBytes', LTotal);
      Result.Add('files', LFiles);
      LFiles := nil;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LNames.Free;
    LFiles.Free;
  end;
end;

procedure Run;
var
  LRoot: String;
  LCache: String;
  LAssets: TJSONObject;
  LResponse: TJSONObject;
  LReport: TJSONObject;
  LCandidate: TJSONObject;
  LJobs: TJSONArray;
  LSources: TJSONArray;
  LSkipped: TJSONArray;
  LNames: TStringList;
  LCount: Integer;
  LBytes: Int64;
  LId: String;
  I: Integer;
begin
  Require((ParamCount >= 1) and (ParamCount <= 2),
    'Usage: phanes.discover.polyhaven repository-root [source-limit]');
  LRoot := ExpandFileName(ParamStr(1));
  LCache := SafeChild(LRoot, 'build/asset-research/polyhaven');
  LAssets := nil;
  LResponse := nil;
  LReport := nil;
  LJobs := TJSONArray.Create;
  LNames := TStringList.Create;
  try
    LJobs.Add(TJSONObject.Create(['url', ApiURL + '/assets?t=models',
      'path', SafeChild(LCache, 'assets.json')]));
    FetchBatch(LJobs);
    Require(LJobs.Objects[0].Find('error') = nil, 'Could not retrieve Poly Haven model list');
    LAssets := LoadJSON(SafeChild(LCache, 'assets.json'));
    Require((LAssets.Count > 0) and (LAssets.Count <= 5000), 'Model list exceeds bound');
    LNames.Sorted := True;
    LNames.CaseSensitive := True;
    LNames.UseLocale := False;
    for I := 0 to LAssets.Count - 1 do
    begin
      CheckSourceId(LAssets.Names[I]);
      LNames.Add(LAssets.Names[I]);
    end;
    LCount := LNames.Count;
    if ParamCount = 2 then
    begin
      LCount := StrToInt(ParamStr(2));
      Require((LCount > 0) and (LCount <= LNames.Count), 'Source limit outside list');
    end;
    LJobs.Clear;
    for I := 0 to LCount - 1 do
    begin
      LId := LNames[I];
      LJobs.Add(TJSONObject.Create(['id', LId, 'url', ApiURL + '/files/' + LId,
        'path', SafeChild(LCache, 'files/' + LId + '.json')]));
    end;
    FetchBatch(LJobs);
    LReport := TJSONObject.Create;
    LSources := TJSONArray.Create;
    LSkipped := TJSONArray.Create;
    LReport.Add('format', 'phanes.polyhaven.discovery/v1');
    LReport.Add('publisher', 'Poly Haven');
    LReport.Add('api', ApiURL);
    LReport.Add('licenseURL', 'https://polyhaven.com/license');
    LReport.Add('apiTermsURL', 'https://github.com/Poly-Haven/Public-API/blob/master/ToS.md');
    LReport.Add('retrieved', FormatDateTime('yyyy-mm-dd', Now));
    LReport.Add('catalogSha256', HashFile(SafeChild(LCache, 'assets.json')));
    LReport.Add('listed', LAssets.Count);
    LReport.Add('inspected', LCount);
    LReport.Add('sources', LSources);
    LReport.Add('skipped', LSkipped);
    LBytes := 0;
    for I := 0 to LJobs.Count - 1 do
    begin
      LId := LJobs.Objects[I].Strings['id'];
      try
        Require(LJobs.Objects[I].Find('error') = nil, 'API response transfer failed');
        LResponse := LoadJSON(LJobs.Objects[I].Strings['path']);
        LCandidate := Candidate(LId, LAssets.Objects[LId], LResponse);
        LCandidate.Add('filesMetadataSha256', HashFile(LJobs.Objects[I].Strings['path']));
        LSources.Add(LCandidate);
        Inc(LBytes, LCandidate.Int64s['declaredDownloadBytes']);
      except
        on LException: Exception do
        begin
          LSkipped.Add(TJSONObject.Create(['id', LId, 'reason', LException.Message]));
        end;
      end;
      FreeAndNil(LResponse);
    end;
    LReport.Add('candidateModels', LSources.Count);
    LReport.Add('declaredDownloadBytes', LBytes);
    WriteTextAtomic(SafeChild(LCache, 'candidate.json'), LReport.FormatJSON);
    WriteLn('Poly Haven metadata: ', LSources.Count, ' candidates / ',
      LSkipped.Count, ' skipped; declared closure bytes ', LBytes);
    WriteLn('Discovery only; no model import, license admission or physical admission.');
  finally
    LResponse.Free;
    LReport.Free;
    LNames.Free;
    LJobs.Free;
    LAssets.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
