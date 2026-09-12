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

program PhanesDiscoverBaseMesh;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  StrUtils,
  Process,
  DOM,
  DOM_HTML,
  SAX_HTML,
  XMLRead,
  FPJSON,
  Zipper,
  phanes.tools.files;

const
  BaseURL = 'https://www.thebasemesh.com';
  AssetPrefix = BaseURL + '/asset/';
  SitemapURL = BaseURL +
    '/dynamic-asset_p_ed7478c4_54f0_4f34_aa95_b766a3c7f144_0_5000-sitemap.xml';

type
  TFetchSlot = record
    FProcess: TProcess;
    FJob: TJSONObject;
  end;

procedure FetchBatch(const AJobs: TJSONArray);
var
  LSlots: array[0..3] of TFetchSlot;
  LJob: TJSONObject;
  LUrl: String;
  LPath: String;
  LNext: Integer;
  LActive: Integer;
  LCompleted: Integer;
  I: Integer;
begin
  for I := 0 to High(LSlots) do
  begin
    LSlots[I].FProcess := nil;
    LSlots[I].FJob := nil;
  end;
  LNext := 0;
  LActive := 0;
  LCompleted := 0;
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
            LJob.Add('error', 'Source download failed');
          end
          else
          if not RenameFile(LPath + '.part', LPath) then
          begin
            LJob.Add('error', 'Could not publish downloaded source');
          end;
          FreeAndNil(LSlots[I].FProcess);
          LSlots[I].FJob := nil;
          Dec(LActive);
          Inc(LCompleted);
          if LCompleted mod 25 = 0 then
          begin
            WriteLn('Fetched or cached ', LCompleted, ' / ', AJobs.Count);
            Flush(Output);
          end;
        end;
        while (LSlots[I].FProcess = nil) and (LNext < AJobs.Count) do
        begin
          LJob := AJobs.Objects[LNext];
          Inc(LNext);
          LPath := LJob.Strings['path'];
          if FileExists(LPath) then
          begin
            Inc(LCompleted);
            Continue;
          end;
          LUrl := LJob.Strings['url'];
          Require(Copy(LUrl, 1, 8) = 'https://', 'Expected HTTPS discovery source');
          ForceDirectories(ExtractFileDir(LPath));
          LSlots[I].FProcess := TProcess.Create(nil);
          LSlots[I].FJob := LJob;
          {$IFDEF WINDOWS}
          LSlots[I].FProcess.Executable := 'curl.exe';
          {$ELSE}
          LSlots[I].FProcess.Executable := 'curl';
          {$ENDIF}
          with LSlots[I].FProcess.Parameters do
          begin
            Add('--fail');
            Add('--location');
            Add('--silent');
            Add('--show-error');
            Add('--proto');
            Add('=https');
            Add('--proto-redir');
            Add('=https');
            Add('--max-time');
            Add('60');
            Add('--retry');
            Add('1');
            Add('--retry-delay');
            Add('1');
            Add('--max-filesize');
            Add('134217728');
            Add('--output');
            Add(LPath + '.part');
            Add(LUrl);
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
    WriteLn('Source transfer batch complete: ', LCompleted, ' / ', AJobs.Count);
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

function PageRecord(const APath, AUrl, AId: String): TJSONObject;
var
  LDocument: THTMLDocument;
  LStream: TStringStream;
  LLinks: TStringList;
  LHeadings: TStringList;
  LTitle: String;

  procedure Visit(const ANode: TDOMNode; const ADepth: Integer);
  var
    LElement: TDOMElement;
    LTag: String;
    LHref: String;
    LChild: TDOMNode;
  begin
    Require(ADepth < 128, 'Source HTML nesting exceeds discovery bound');
    if ANode is TDOMElement then
    begin
      LElement := TDOMElement(ANode);
      LTag := LowerCase(UTF8Encode(LElement.TagName));
      if (LTag = 'script') or (LTag = 'style') or (LTag = 'noscript') or
        (LTag = 'template') then
      begin
        Exit;
      end;
      if LTag = 'a' then
      begin
        LHref := UTF8Encode(LElement.GetAttribute('href'));
        if (Copy(LHref, 1, Length(BaseURL + '/_files/archives/')) =
          BaseURL + '/_files/archives/') and (Pos('.zip', LHref) > 0) then
        begin
          LLinks.Add(LHref);
        end;
      end;
      if (LTag = 'h3') and (LTitle = '') then
      begin
        LTitle := Trim(UTF8Encode(LElement.TextContent));
      end;
      if LTag = 'h2' then
      begin
        LHeadings.Add(Trim(UTF8Encode(LElement.TextContent)));
      end;
    end;
    LChild := ANode.FirstChild;
    while LChild <> nil do
    begin
      Visit(LChild, ADepth + 1);
      LChild := LChild.NextSibling;
    end;
  end;

begin
  LDocument := nil;
  LTitle := '';
  LLinks := TStringList.Create;
  LLinks.Sorted := True;
  LLinks.CaseSensitive := True;
  LLinks.Duplicates := dupIgnore;
  LHeadings := TStringList.Create;
  LStream := TStringStream.Create(ReadText(APath));
  try
    Require(LStream.Size <= 4 * 1024 * 1024, 'Source page exceeds discovery bound');
    ReadHTMLFile(LDocument, LStream);
    Visit(LDocument, 0);
    Require(LLinks.Count = 1, 'Expected one original ZIP link on model page');
    Require((LTitle <> '') and (LHeadings.Count = 9), 'Unrecognized model metadata layout');
    Require((LHeadings[0] = 'Model Information') and
      (LHeadings[1] = 'Tris:') and (LHeadings[2] = 'Unwrapped:') and
      (LHeadings[3] = 'Model Formats:') and (LHeadings[4] = 'Category:'),
      'Unrecognized model metadata headings');
    Result := TJSONObject.Create([
      'id', AId, 'name', LTitle, 'page', AUrl, 'pageSha256', HashFile(APath),
      'archiveUrl', LLinks[0], 'sourceCategory', LHeadings[8],
      'sourceFormats', LHeadings[7], 'sourceTriangles', LHeadings[5],
      'sourceUVs', LHeadings[6]]);
  finally
    LStream.Free;
    LHeadings.Free;
    LLinks.Free;
    LDocument.Free;
  end;
end;

procedure InspectArchive(const ASource: TJSONObject; const APath: String);
var
  LZip: TUnZipper;
  LModels: TJSONArray;
  LNotices: TJSONArray;
  LName: String;
  LExtension: String;
  I: Integer;
begin
  LZip := TUnZipper.Create;
  LModels := TJSONArray.Create;
  LNotices := TJSONArray.Create;
  ASource.Add('models', LModels);
  ASource.Add('bundledNotices', LNotices);
  try
    LZip.FileName := APath;
    LZip.Examine;
    Require(LZip.Entries.Count <= 20000, 'Source archive exceeds entry bound');
    for I := 0 to LZip.Entries.Count - 1 do
    begin
      LName := LZip.Entries[I].ArchiveFileName;
      LExtension := LowerCase(ExtractFileExt(LName));
      if (LExtension = '.glb') or (LExtension = '.gltf') then
      begin
        LModels.Add(TJSONObject.Create(['path', LName, 'bytes', LZip.Entries[I].Size]));
      end;
      if (Copy(LowerCase(ExtractFileName(LName)), 1, 7) = 'license') and
        ((LExtension = '.txt') or (LExtension = '.md')) then
      begin
        LNotices.Add(LName);
      end;
    end;
    Require(LModels.Count > 0, 'No original GLB/glTF files; conversion is not admitted');
    ASource.Add('archiveSha256', HashFile(APath));
  finally
    LZip.Free;
  end;
end;

procedure Run(const ARoot: String; const ALimit: Integer);
var
  LCache: String;
  LJobs: TJSONArray;
  LPages: TStringList;
  LDocument: TXMLDocument;
  LLocations: TDOMNodeList;
  LUrl: String;
  LId: String;
  LPath: String;
  LCandidate: TJSONObject;
  LSources: TJSONArray;
  LSkipped: TJSONArray;
  LRecord: TJSONObject;
  LModels: Integer;
  LPortable: Boolean;
  I: Integer;
  J: Integer;
begin
  LCache := SafeChild(ARoot, 'build/asset-research/basemesh');
  LJobs := TJSONArray.Create;
  LPages := TStringList.Create;
  LPages.Sorted := True;
  LPages.CaseSensitive := True;
  LPages.Duplicates := dupIgnore;
  LDocument := nil;
  LCandidate := TJSONObject.Create([
    'version', 1, 'status', 'discovery-candidate-only', 'id', 'basemesh',
    'name', 'The Base Mesh', 'author', 'The Base Mesh / Tim Steer and contributors',
    'license', 'CC0-1.0', 'page', BaseURL + '/model-library',
    'retrieved', FormatDateTime('yyyy-mm-dd', Date)]);
  LSources := TJSONArray.Create;
  LSkipped := TJSONArray.Create;
  LCandidate.Add('sources', LSources);
  LCandidate.Add('skipped', LSkipped);
  try
    LJobs.Add(TJSONObject.Create(['url', SitemapURL, 'path', LCache + '/sitemap.xml']));
    LJobs.Add(TJSONObject.Create(['url', BaseURL + '/faq', 'path', LCache + '/faq.html']));
    FetchBatch(LJobs);
    for I := 0 to LJobs.Count - 1 do
    begin
      Require(LJobs.Objects[I].Find('error') = nil, 'Could not fetch collection source');
    end;
    LCandidate.Add('licenseEvidence', TJSONObject.Create([
      'url', BaseURL + '/faq', 'sha256', HashFile(LCache + '/faq.html')]));
    LCandidate.Add('sitemap', TJSONObject.Create([
      'url', SitemapURL, 'sha256', HashFile(LCache + '/sitemap.xml')]));
    ReadXMLFile(LDocument, LCache + '/sitemap.xml');
    LLocations := LDocument.GetElementsByTagName('loc');
    try
      for I := 0 to LLocations.Count - 1 do
      begin
        LUrl := UTF8Encode(LLocations[I].TextContent);
        Require(Copy(LUrl, 1, Length(AssetPrefix)) = AssetPrefix,
          'Unexpected URL in creator asset sitemap');
        LPages.Add(LUrl);
      end;
    finally
      LLocations.Free;
    end;
    Require((LPages.Count > 0) and (LPages.Count <= 5000), 'Unexpected source page count');
    LCandidate.Add('discoveredPages', LPages.Count);
    LJobs.Clear;
    for I := 0 to LPages.Count - 1 do
    begin
      if (ALimit > 0) and (I >= ALimit) then
      begin
        Break;
      end;
      LId := Copy(LPages[I], Length(AssetPrefix) + 1, MaxInt);
      Require((LId <> '') and (Length(LId) <= 100), 'Invalid source slug');
      LPortable := True;
      for J := 1 to Length(LId) do
      begin
        if not (LId[J] in ['a'..'z', '0'..'9', '-', '_']) then
        begin
          LPortable := False;
        end;
      end;
      if not LPortable then
      begin
        { Keep original URLs unchanged; a hash gives punctuation-heavy source
          slugs a stable portable namespace without lossy filename rewrites. }
        LId := 'source-' + Copy(HashBytes(BytesOf(LPages[I])), 1, 24);
      end;
      LJobs.Add(TJSONObject.Create([
        'id', LId, 'url', LPages[I], 'path', SafeChild(LCache, 'pages/' + LId + '.html')]));
    end;
    WriteLn('Discovering ', LJobs.Count, ' source pages from ', LPages.Count, ' listed models.');
    Flush(Output);
    FetchBatch(LJobs);
    for I := 0 to LJobs.Count - 1 do
    begin
      LRecord := nil;
      try
        Require(LJobs.Objects[I].Find('error') = nil, 'Source page download failed');
        LRecord := PageRecord(LJobs.Objects[I].Strings['path'], LJobs.Objects[I].Strings['url'],
          LJobs.Objects[I].Strings['id']);
        LSources.Add(LRecord);
        LRecord := nil;
      except
        on LException: Exception do
        begin
          LSkipped.Add(TJSONObject.Create([
            'page', LJobs.Objects[I].Strings['url'], 'reason', LException.Message]));
        end;
      end;
      LRecord.Free;
      if (I + 1) mod 25 = 0 then
      begin
        WriteLn('Inspected source page ', I + 1, ' / ', LJobs.Count);
        Flush(Output);
      end;
    end;
    WriteTextAtomic(LCache + '/candidate.json', LCandidate.FormatJSON + #10);
    LJobs.Clear;
    for I := 0 to LSources.Count - 1 do
    begin
      LJobs.Add(TJSONObject.Create([
        'url', LSources.Objects[I].Strings['archiveUrl'],
        'path', SafeChild(LCache, 'archives/' + LSources.Objects[I].Strings['id'] + '.zip')]));
    end;
    WriteLn('Fetching ', LJobs.Count, ' original source archives.');
    Flush(Output);
    FetchBatch(LJobs);
    LModels := 0;
    for I := LSources.Count - 1 downto 0 do
    begin
      try
        Require(LJobs.Objects[I].Find('error') = nil, 'Original archive download failed');
        LPath := LJobs.Objects[I].Strings['path'];
        InspectArchive(LSources.Objects[I], LPath);
        Inc(LModels, LSources.Objects[I].Arrays['models'].Count);
      except
        on LException: Exception do
        begin
          LSkipped.Add(TJSONObject.Create([
            'page', LSources.Objects[I].Strings['page'], 'reason', LException.Message]));
          LSources.Delete(I);
        end;
      end;
    end;
    LCandidate.Add('sourceArchives', LSources.Count);
    LCandidate.Add('sourceModelFiles', LModels);
    WriteTextAtomic(LCache + '/candidate.json', LCandidate.FormatJSON + #10);
    WriteLn('Candidate: ', LSources.Count, ' original archives, ', LModels,
      ' GLB/glTF files; ', LSkipped.Count, ' skipped. No catalog admission.');
  finally
    LCandidate.Free;
    LDocument.Free;
    LPages.Free;
    LJobs.Free;
  end;
end;

var
  GLimit: Integer;
begin
  try
    Require((ParamCount >= 1) and (ParamCount <= 2),
      'Usage: phanes.discover.basemesh repository-root [page-limit]');
    GLimit := 0;
    if ParamCount = 2 then
    begin
      GLimit := StrToInt(ParamStr(2));
      Require(GLimit > 0, 'Expected a positive page limit');
    end;
    Run(ExpandFileName(ParamStr(1)), GLimit);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
