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

program PhanesCurateBaseMesh;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  Zipper,
  phanes.tools.files,
  phanes.tools.sourcehtml,
  phanes.tools.collections;

type
  TModelPins = class
  private
    FPaths: TStringList;
    procedure CreateStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  public
    function Run(const ASource: TJSONObject; const AArchive: String): TJSONArray;
  end;

procedure TModelPins.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  Require((AItem.Size > 0) and (AItem.Size <= 32 * 1024 * 1024), 'Model exceeds source bound');
  AStream := TMemoryStream.Create;
end;

procedure TModelPins.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LBytes: TBytes;
  LModel: TJSONObject;
  I: Integer;
begin
  try
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      AStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    I := FPaths.IndexOf(AItem.ArchiveFileName);
    Require((I >= 0) and (FPaths.Objects[I] = nil), 'Duplicate or unexpected model member');
    LModel := ModelJSON(LBytes, ExtractFileExt(AItem.ArchiveFileName));
    LModel.Free;
    FPaths.Objects[I] := TJSONObject.Create([
      'path', AItem.ArchiveFileName, 'sha256', HashBytes(LBytes), 'bytes', Length(LBytes)]);
  finally
    FreeAndNil(AStream);
  end;
end;

function TModelPins.Run(const ASource: TJSONObject; const AArchive: String): TJSONArray;
var
  LZip: TUnZipper;
  I: Integer;
begin
  Result := nil;
  FPaths := TStringList.Create;
  FPaths.Sorted := True;
  FPaths.CaseSensitive := True;
  FPaths.UseLocale := False;
  FPaths.Duplicates := dupError;
  LZip := TUnZipper.Create;
  try
    try
      Require(ASource.Arrays['bundledNotices'].Count = 0,
        'Collection fallback cannot override a bundled notice');
      Require(HashFile(AArchive) = ASource.Strings['archiveSha256'], 'Original archive changed');
      for I := 0 to ASource.Arrays['models'].Count - 1 do
      begin
        FPaths.Add(ASource.Arrays['models'].Objects[I].Strings['path']);
      end;
      Require(FPaths.Count > 0, 'Empty source model selection');
      LZip.FileName := AArchive;
      LZip.Examine;
      LZip.OnCreateStream := CreateStream;
      LZip.OnDoneStream := DoneStream;
      LZip.UnZipFiles(FPaths);
      Result := TJSONArray.Create;
      for I := 0 to FPaths.Count - 1 do
      begin
        Require(FPaths.Objects[I] <> nil, 'Missing exact original model member');
        Result.Add(TJSONObject(FPaths.Objects[I]));
        FPaths.Objects[I] := nil;
      end;
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    for I := 0 to FPaths.Count - 1 do
    begin
      FPaths.Objects[I].Free;
    end;
    FPaths.Free;
    LZip.Free;
  end;
end;

procedure CopySourceFile(const ASource, ATarget, AHash: String);
begin
  Require(HashFile(ASource) = AHash, 'Source file changed before curation');
  if FileExists(ATarget) then
  begin
    Require(HashFile(ATarget) = AHash, 'Curated source cache differs');
    Exit;
  end;
  CopyFileBytes(ASource, ATarget);
  Require(HashFile(ATarget) = AHash, 'Curated copy changed source bytes');
end;

procedure Run(const ARoot, AOutputRoot, AId: String; const ALimit: Integer);
var
  LDiscovery: TJSONObject;
  LLock: TJSONObject;
  LKit: TJSONObject;
  LEvidence: TJSONObject;
  LSources: TJSONArray;
  LSource: TJSONObject;
  LOriginal: TJSONObject;
  LCache: String;
  LEvidenceRoot: String;
  LRelative: String;
  LArchive: String;
  LPage: String;
  LModels: TModelPins;
  I: Integer;
begin
  for I := 1 to Length(AId) do
  begin
    Require(AId[I] in ['a'..'z', '0'..'9', '-'], 'Noncanonical snapshot ID');
  end;
  Require(AId <> '', 'Empty snapshot ID');
  LCache := SafeChild(ARoot, 'build/asset-research/basemesh');
  LDiscovery := LoadJSON(LCache + '/candidate.json');
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LModels := TModelPins.Create;
  try
    Require(LDiscovery.Integers['sourceArchives'] = LDiscovery.Arrays['sources'].Count,
      'Discovery has not completed original archive inspection');
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      Require(LLock.Arrays['kits'].Objects[I].Strings['id'] <> AId,
        'Snapshot ID already belongs to the source lock');
    end;
    LKit := TJSONObject.Create([
      'id', AId, 'sourceMode', 'collection.v1', 'sourceAdapter', 'basemesh.v1',
      'collection', 'basemesh', 'name', 'The Base Mesh',
      'author', 'The Base Mesh contributors', 'publisher', 'The Base Mesh',
      'theme', 'mixed', 'storage', 'library', 'license', 'CC0-1.0',
      'page', 'https://www.thebasemesh.com/model-library',
      'retrieved', LDiscovery.Strings['retrieved']]);
    LLock.Arrays['kits'].Add(LKit);
    LEvidenceRoot := 'assets/provenance/' + AId;
    LEvidence := TJSONObject.Create([
      'mode', 'basemesh.faq.v1', 'url', 'https://www.thebasemesh.com/faq',
      'sha256', LDiscovery.Objects['licenseEvidence'].Strings['sha256'],
      'path', LEvidenceRoot + '/faq.html.zlib']);
    LKit.Add('licenseEvidence', LEvidence);
    Require(HashFile(LCache + '/faq.html') = LEvidence.Strings['sha256'], 'FAQ changed');
    CheckBaseMeshFAQ(LKit, ReadText(LCache + '/faq.html'));
    CompressSourceEvidence(LCache + '/faq.html', SafeChild(AOutputRoot, LEvidence.Strings['path']));
    LEvidence.Add('compressedSha256', HashFile(SafeChild(AOutputRoot, LEvidence.Strings['path'])));
    LSources := TJSONArray.Create;
    LKit.Add('sources', LSources);
    for I := 0 to LDiscovery.Arrays['sources'].Count - 1 do
    begin
      if (ALimit > 0) and (I >= ALimit) then
      begin
        Break;
      end;
      LOriginal := LDiscovery.Arrays['sources'].Objects[I];
      LRelative := LEvidenceRoot + '/' + LOriginal.Strings['id'] + '.html.zlib';
      LPage := SafeChild(LCache, 'pages/' + LOriginal.Strings['id'] + '.html');
      Require(HashFile(LPage) = LOriginal.Strings['pageSha256'], 'Source page changed');
      CheckBaseMeshPage(LOriginal, ReadText(LPage));
      CompressSourceEvidence(LPage, SafeChild(AOutputRoot, LRelative));
      LSource := TJSONObject.Create([
        'id', LOriginal.Strings['id'], 'name', LOriginal.Strings['name'],
        'page', LOriginal.Strings['page'], 'pageSha256', LOriginal.Strings['pageSha256'],
        'pageEvidence', LRelative, 'pageEvidenceSha256', HashFile(SafeChild(AOutputRoot, LRelative)),
        'archiveUrl', LOriginal.Strings['archiveUrl'], 'archiveSha256', LOriginal.Strings['archiveSha256'],
        'sourceCategory', LOriginal.Strings['sourceCategory'],
        'modelPrefix', '', 'modelFormat', 'gltf2']);
      LSources.Add(LSource);
      LArchive := SafeChild(LCache, 'archives/' + LOriginal.Strings['id'] + '.zip');
      LSource.Add('models', LModels.Run(LOriginal, LArchive));
      CopySourceFile(LArchive, SafeChild(AOutputRoot, 'build/asset-research/collections/' +
        LSource.Strings['archiveSha256'] + '.zip'), LSource.Strings['archiveSha256']);
      if (I + 1) mod 50 = 0 then
      begin
        WriteLn('Curated ', I + 1, ' original model source archives.');
        Flush(Output);
      end;
    end;
    CheckCollectionKit(LKit);
    WriteTextAtomic(SafeChild(AOutputRoot, 'build/asset-research/kits.basemesh.candidate.json'),
      LLock.FormatJSON + #10);
    WriteLn('Curated ', LSources.Count, ' sources under one collection snapshot. ',
      'Candidate lock only; main catalog unchanged.');
  finally
    LModels.Free;
    LLock.Free;
    LDiscovery.Free;
  end;
end;

var
  GLimit: Integer;
begin
  try
    Require((ParamCount >= 3) and (ParamCount <= 4),
      'Usage: phanes.curate.basemesh source-root output-root snapshot-id [source-limit]');
    GLimit := 0;
    if ParamCount = 4 then
    begin
      GLimit := StrToInt(ParamStr(4));
      Require(GLimit > 0, 'Expected positive source limit');
    end;
    Run(ExpandFileName(ParamStr(1)), ExpandFileName(ParamStr(2)), ParamStr(3), GLimit);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
