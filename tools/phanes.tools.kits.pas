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

unit phanes.tools.kits;

{$mode delphi}
{$H+}

interface

uses
  FPJSON;

procedure VerifyKits(const ARoot: String);
procedure ImportKits(const ARoot: String);
procedure CheckArchivePath(const APath: String);
procedure CheckExactFilePath(const ARoot, ARelative: String);
procedure CheckCreatorEvidence(const AKit: TJSONObject; const AText: String);
function ModelDependencies(const AModel, AKit: TJSONObject;
  const AKitRoot, AModelPath: String): TJSONArray;
function MeshBounds(const AModel: TJSONObject): TJSONArray;
function SuggestRole(const AName: String): String;

implementation

uses
  Classes,
  SysUtils,
  Math,
  DOM,
  DOM_HTML,
  SAX_HTML,
  Zipper,
  phanes.catalog.regional,
  phanes.tools.collections,
  phanes.tools.derived,
  phanes.tools.files;

procedure CheckArchivePath(const APath: String);
var
  LParts: TStringList;
  I: Integer;
begin
  Require((APath <> '') and (Pos('\', APath) = 0) and (Pos(':', APath) = 0),
    'Archive paths must use portable relative slash notation');
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '/';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := APath;
    for I := 0 to LParts.Count - 1 do
    begin
      Require((LParts[I] <> '') and (LParts[I] <> '.') and (LParts[I] <> '..') and
        (Trim(LParts[I]) = LParts[I]) and
        (LParts[I][Length(LParts[I])] <> '.'), 'Noncanonical archive path: ' + APath);
    end;
  finally
    LParts.Free;
  end;
end;

function DependencyExtension(const APath: String): Boolean;
var
  LExtension: String;
begin
  LExtension := LowerCase(ExtractFileExt(APath));
  Result := (LExtension = '.png') or (LExtension = '.jpg') or
    (LExtension = '.jpeg') or (LExtension = '.bin');
end;

procedure CheckAliasPaths(const AKit: TJSONObject);
var
  LTargets: TStringList;
  LAlias: TJSONObject;
  I: Integer;
begin
  if AKit.Find('dependencyAliases') = nil then
  begin
    Exit;
  end;
  Require(AKit.Arrays['dependencyAliases'].Count <= 256, 'Too many dependency aliases');
  LTargets := TStringList.Create;
  LTargets.Sorted := True;
  LTargets.CaseSensitive := False;
  try
    for I := 0 to AKit.Arrays['dependencyAliases'].Count - 1 do
    begin
      LAlias := AKit.Arrays['dependencyAliases'].Objects[I];
      CheckArchivePath(LAlias.Strings['from']);
      CheckArchivePath(LAlias.Strings['to']);
      Require(DependencyExtension(LAlias.Strings['from']) and
        DependencyExtension(LAlias.Strings['to']), 'Unsupported dependency alias format');
      Require(SameText(ExtractFileExt(LAlias.Strings['from']),
        ExtractFileExt(LAlias.Strings['to'])), 'Dependency alias changes format');
      Require(LTargets.IndexOf(LAlias.Strings['to']) < 0, 'Duplicate dependency alias target');
      LTargets.Add(LAlias.Strings['to']);
    end;
    for I := 0 to AKit.Arrays['dependencyAliases'].Count - 1 do
    begin
      Require(LTargets.IndexOf(AKit.Arrays['dependencyAliases'].Objects[I].Strings['from']) < 0,
        'Dependency alias must not refer to another alias');
    end;
  finally
    LTargets.Free;
  end;
end;

procedure CheckExactFilePath(const ARoot, ARelative: String);
var
  LParts: TStringList;
  LPath: String;
  LSearch: TSearchRec;
  I: Integer;
begin
  CheckArchivePath(ARelative);
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '/';
    LParts.DelimitedText := ARelative;
    LPath := ARoot;
    for I := 0 to LParts.Count - 1 do
    begin
      LPath := SafeChild(LPath, LParts[I]);
      Require(FindFirst(LPath, faAnyFile, LSearch) = 0, 'Missing exact file path: ' + LPath);
      try
        Require(LSearch.Name = LParts[I], 'Filename case differs from provenance: ' + ARelative);
      finally
        FindClose(LSearch);
      end;
    end;
  finally
    LParts.Free;
  end;
end;
function KitModel(const AKit: TJSONObject; const APath: String): Boolean;
var
  LExtension: String;
begin
  LExtension := LowerCase(ExtractFileExt(APath));
  if AKit.Get('modelFormat', 'glb') = 'gltf2' then
  begin
    Exit((LExtension = '.gltf') or (LExtension = '.glb'));
  end;
  Result := LExtension = '.' + AKit.Get('modelFormat', 'glb');
end;

procedure CheckKitLock(const ALock: TJSONObject);
var
  LIds: TStringList;
  LKit: TJSONObject;
  LId: String;
  I: Integer;
  J: Integer;
begin
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.CaseSensitive := False;
    Require(ALock.Arrays['kits'].Count > 0, 'Kit manifest must not be empty');
    for I := 0 to ALock.Arrays['kits'].Count - 1 do
    begin
      LKit := ALock.Arrays['kits'].Objects[I];
      LId := LKit.Strings['id'];
      Require(LId <> '', 'Empty kit ID');
      for J := 1 to Length(LId) do
      begin
        Require(LId[J] in ['a'..'z', '0'..'9', '-'], 'Noncanonical kit ID');
      end;
      Require(LIds.IndexOf(LId) < 0, 'Duplicate kit ID: ' + LId);
      LIds.Add(LId);
      if LKit.Get('sourceMode', '') = 'derived.obj.v1' then
      begin
        CheckDerivedKit(LKit);
        Continue;
      end;
      if LKit.Find('sources') <> nil then
      begin
        CheckCollectionKit(LKit);
        Continue;
      end;
      Require(LKit.Find('sourceMode') = nil, 'Unsupported source mode');
      CheckAliasPaths(LKit);
      Require(LKit.Strings['license'] = 'CC0-1.0', 'Unexpected source license');
      Require((LKit.Get('modelFormat', 'glb') = 'glb') or
        (LKit.Get('modelFormat', 'glb') = 'gltf') or
        (LKit.Get('modelFormat', 'glb') = 'gltf2'), 'Unsupported kit model format');
      Require(Length(LKit.Strings['archiveSha256']) = 64, 'Invalid archive hash');
      Require(Copy(LKit.Strings['archiveUrl'], 1, 8) = 'https://', 'Expected HTTPS archive');
      Require(Copy(LKit.Strings['page'], 1, 8) = 'https://', 'Expected HTTPS source page');
      CheckArchivePath(LKit.Get('licensePath', 'License.txt'));
      if LKit.Find('licenseEvidence') <> nil then
      begin
        Require(LKit.Find('licensePath') = nil,
          'Choose an archive notice or external creator evidence, never both');
        Require(Copy(LKit.Objects['licenseEvidence'].Strings['url'], 1, 8) = 'https://',
          'Creator license evidence must use HTTPS');
        Require(Length(LKit.Objects['licenseEvidence'].Strings['sha256']) = 64,
          'Creator license evidence needs a pinned hash');
      end;
    end;
  finally
    LIds.Free;
  end;
end;

procedure CheckCreatorEvidence(const AKit: TJSONObject; const AText: String);
var
  LDocument: THTMLDocument;
  LStream: TStringStream;
  LAuthors: Integer;
  LArchives: Integer;
  LLicenses: Integer;
  LNodes: Integer;

  procedure Visit(const ANode: TDOMNode; const AInLicense: Boolean; const ADepth: Integer);
  var
    LChild: TDOMNode;
    LElement: TDOMElement;
    LTag: String;
    LClass: String;
    LHref: String;
    LInLicense: Boolean;
  begin
    Inc(LNodes);
    Require((ADepth <= 128) and (LNodes <= 100000), 'Creator evidence DOM exceeds bounds');
    LInLicense := AInLicense;
    if ANode is TDOMElement then
    begin
      LElement := TDOMElement(ANode);
      LTag := LowerCase(UTF8Encode(LElement.TagName));
      if (LTag = 'script') or (LTag = 'style') or (LTag = 'noscript') or
        (LTag = 'template') then
      begin
        Exit;
      end;
      if (LTag = 'meta') and
        (UTF8Encode(LElement.GetAttribute('name')) = 'dcterms.creator') then
      begin
        Require(UTF8Encode(LElement.GetAttribute('content')) = 'quaternius',
          'Creator evidence author mismatch');
        Inc(LAuthors);
      end;
      LClass := UTF8Encode(LElement.GetAttribute('class'));
      LClass := StringReplace(LClass, #9, ' ', [rfReplaceAll]);
      LClass := StringReplace(LClass, #10, ' ', [rfReplaceAll]);
      LClass := StringReplace(LClass, #13, ' ', [rfReplaceAll]);
      if (LTag = 'div') and
        (Pos(' field-name-field-art-licenses ', ' ' + LClass + ' ') > 0) then
      begin
        LInLicense := True;
      end;
      if LTag = 'a' then
      begin
        LHref := UTF8Encode(LElement.GetAttribute('href'));
        if LHref = AKit.Strings['archiveUrl'] then
        begin
          Inc(LArchives);
        end;
        if LInLicense then
        begin
          Require((LHref = 'http://creativecommons.org/publicdomain/zero/1.0/') or
            (LHref = 'https://creativecommons.org/publicdomain/zero/1.0/'),
            'Creator license field contains a different declaration');
          Inc(LLicenses);
        end;
      end;
    end;
    LChild := ANode.FirstChild;
    while LChild <> nil do
    begin
      Visit(LChild, LInLicense, ADepth + 1);
      LChild := LChild.NextSibling;
    end;
  end;

begin
  Require(AKit.Objects['licenseEvidence'].Strings['mode'] = 'oga-submission.v1',
    'Unsupported creator evidence recipe');
  Require(AKit.Objects['licenseEvidence'].Strings['url'] = AKit.Strings['page'],
    'Creator evidence must be the pinned submission page');
  Require((AKit.Strings['author'] = 'Quaternius') and
    (Copy(AKit.Strings['page'], 1, Length('https://opengameart.org/content/')) =
      'https://opengameart.org/content/'),
    'Creator evidence needs a reviewed source adapter');
  Require(Length(AText) <= 2 * 1024 * 1024, 'Creator evidence exceeds size bound');
  { The FPC HTML parser predates template semantics. Reject that unsupported
    construct instead of treating inert descendants as license evidence. }
  Require(Pos('<template', LowerCase(AText)) = 0, 'Unsupported inert HTML template');
  LDocument := nil;
  LStream := TStringStream.Create(AText);
  LAuthors := 0;
  LArchives := 0;
  LLicenses := 0;
  LNodes := 0;
  try
    ReadHTMLFile(LDocument, LStream);
    Visit(LDocument, False, 0);
    Require(LAuthors = 1, 'Creator evidence requires exactly one matching author');
    Require(LArchives > 0, 'Creator evidence does not link this archive');
    Require(LLicenses > 0, 'Creator evidence license field does not declare CC0');
  finally
    LDocument.Free;
    LStream.Free;
  end;
end;
function ModelDependencies(const AModel, AKit: TJSONObject;
  const AKitRoot, AModelPath: String): TJSONArray;
const
  CGroups: array[0..1] of String = ('images', 'buffers');
var
  LArray: TJSONArray;
  LUri: String;
  LPath: String;
  LRoot: String;
  LRelative: String;
  I: Integer;
  J: Integer;
  K: Integer;
  LDependency: TJSONObject;
  LAlias: TJSONObject;
begin
  Result := TJSONArray.Create;
  try
    LRoot := IncludeTrailingPathDelimiter(ExpandFileName(AKitRoot));
    for J := 0 to High(CGroups) do
    begin
      if AModel.Find(CGroups[J]) = nil then
      begin
        Continue;
      end;
      LArray := AModel.Arrays[CGroups[J]];
      for I := 0 to LArray.Count - 1 do
      begin
        LUri := LArray.Objects[I].Get('uri', '');
        if (LUri = '') or (Copy(LUri, 1, 5) = 'data:') then
        begin
          Continue;
        end;
        { External files must be local to the kit; source archives are never
          allowed to turn a model load into an arbitrary network request. }
        Require((Pos(':', LUri) = 0) and (Pos('%', LUri) = 0) and
          (Pos('#', LUri) = 0) and (Pos('?', LUri) = 0) and
          (Pos('\', LUri) = 0) and (LUri[1] <> '/'), 'Unsupported model dependency URI');
        LPath := ExpandFileName(ExtractFilePath(AModelPath) +
          StringReplace(LUri, '/', PathDelim, [rfReplaceAll]));
        LRelative := ExtractRelativePath(LRoot, LPath);
        Require(SafeChild(LRoot, LRelative) = LPath, 'Dependency escapes kit');
        Require(FileExists(LPath), 'Missing model dependency: ' + LUri);
        LRelative := StringReplace(LRelative, PathDelim, '/', [rfReplaceAll]);
        LDependency := TJSONObject.Create(['path', LRelative,
          'sha256', HashFile(LPath), 'bytes', Length(ReadBytes(LPath))]);
        Result.Add(LDependency);
        if AKit.Find('dependencyAliases') <> nil then
        begin
          for K := 0 to AKit.Arrays['dependencyAliases'].Count - 1 do
          begin
            LAlias := AKit.Arrays['dependencyAliases'].Objects[K];
            if LAlias.Strings['to'] = LRelative then
            begin
              Require(HashFile(SafeChild(LRoot, LAlias.Strings['from'])) =
                LDependency.Strings['sha256'], 'Dependency alias changed source bytes');
              LDependency.Add('sourcePath', LAlias.Strings['from']);
            end;
          end;
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function SuggestRole(const AName: String): String;
const
  CTerms: array[0..11] of String = ('roof', 'wall|door|gate|fence', 'tree|cactus',
    'flower|mushroom', 'plant|grass|hedge|bush', 'crops|crop_', 'rock|stone|cliff',
    'bookcase|cabinet', 'chair|stool|bench', 'table|desk', 'building|hangar|tower',
    'road|path|floor|ground|terrain');
  CRoles: array[0..11] of String = ('roof', 'boundary', 'tree', 'flowers', 'shrub',
    'crop', 'rock', 'storage', 'seat', 'table', 'structure', 'surface');
var
  I: Integer;
  LTerm: String;
  LTerms: TStringList;
begin
  LTerms := TStringList.Create;
  try
    LTerms.Delimiter := '|';
    LTerms.StrictDelimiter := True;
    for I := 0 to High(CTerms) do
    begin
      LTerms.DelimitedText := CTerms[I];
      for LTerm in LTerms do
      begin
        if Pos(LTerm, LowerCase(AName)) > 0 then
        begin
          Exit(CRoles[I]);
        end;
      end;
    end;
    Result := 'prop';
  finally
    LTerms.Free;
  end;
end;

function MeshBounds(const AModel: TJSONObject): TJSONArray;
var
  LMesh: TJSONEnum;
  LPrimitive: TJSONEnum;
  LAccessor: TJSONObject;
  LMinimum: array[0..2] of Double;
  LMaximum: array[0..2] of Double;
  I: Integer;
  LCount: Integer;
begin
  for I := 0 to 2 do
  begin
    LMinimum[I] := Infinity;
    LMaximum[I] := NegInfinity;
  end;
  LCount := 0;
  for LMesh in AModel.Arrays['meshes'] do
  begin
    for LPrimitive in TJSONObject(LMesh.Value).Arrays['primitives'] do
    begin
      LAccessor := AModel.Arrays['accessors'].Objects[
        TJSONObject(LPrimitive.Value).Objects['attributes'].Integers['POSITION']];
      for I := 0 to 2 do
      begin
        LMinimum[I] := Min(LMinimum[I], LAccessor.Arrays['min'].Floats[I]);
        LMaximum[I] := Max(LMaximum[I], LAccessor.Arrays['max'].Floats[I]);
      end;
      Inc(LCount);
    end;
  end;
  Require(LCount > 0, 'GLB needs bounded position accessors');
  Result := TJSONArray.Create;
  Result.Add(TJSONArray.Create([LMinimum[0], LMinimum[1], LMinimum[2]]));
  Result.Add(TJSONArray.Create([LMaximum[0], LMaximum[1], LMaximum[2]]));
end;

type
  TKitImporter = class
  private
    FDestination: String;
    FPrefix: String;
    FLicenseEntry: String;
    FKit: TJSONObject;
    FInventory: TJSONArray;
    procedure CreateStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(ASender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  public
    procedure Run(const ARoot: String);
  end;

procedure TKitImporter.CreateStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  Require(AItem.Size <= 32 * 1024 * 1024, 'Archive member too large');
  AStream := TMemoryStream.Create;
end;

procedure TKitImporter.DoneStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var
  LBytes: TBytes;
  LRelative: String;
  LPath: String;
  LName: String;
  LModel: TJSONObject;
  LRecord: TJSONObject;
begin
  try
    LRelative := AItem.ArchiveFileName;
    if LRelative = FLicenseEntry then
    begin
      LRelative := 'License.txt';
    end
    else
    begin
      Require(Copy(LRelative, 1, Length(FPrefix)) = FPrefix, 'Unexpected archive path');
      Delete(LRelative, 1, Length(FPrefix));
    end;
    LPath := SafeChild(FDestination, LRelative);
    SetLength(LBytes, AStream.Size);
    AStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      AStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    WriteBytes(LPath, LBytes);
    if KitModel(FKit, LPath) then
    begin
      LModel := ModelJSON(LBytes, ExtractFileExt(LPath));
      try
        LName := ChangeFileExt(ExtractFileName(LPath), '');
        LRecord := TJSONObject.Create(['id', FKit.Strings['id'] + '/' +
          ChangeFileExt(LRelative, ''),
          'kit', FKit.Strings['id'], 'name', LName, 'theme', FKit.Strings['theme'],
          'suggestedRole', SuggestRole(LName), 'review', 'inventory-only',
          'storage', FKit.Get('storage', 'core'),
          'format', Copy(LowerCase(ExtractFileExt(LPath)), 2, MaxInt),
          'url', 'kits/' + FKit.Strings['id'] + '/' + LRelative,
          'sha256', HashBytes(LBytes), 'bytes', Length(LBytes),
          'license', FKit.Strings['license'], 'source', FKit.Strings['page']]);
        LRecord.Add('meshLocalBounds', MeshBounds(LModel));
        FInventory.Add(LRecord);
      finally
        LModel.Free;
      end;
    end;
  finally
    FreeAndNil(AStream);
  end;
end;

procedure TKitImporter.Run(const ARoot: String);
var
  LLock: TJSONObject;
  LOutput: TJSONObject;
  LItem: TJSONEnum;
  LZip: TUnZipper;
  LFiles: TStringList;
  LArchive: String;
  LName: String;
  LPublished: String;
  LRelative: String;
  LSource: String;
  LTarget: String;
  LNames: TStringList;
  LTotal: Int64;
  LFoundModels: Boolean;
  LSelectedModels: Integer;
  LModel: TJSONObject;
  LAsset: TJSONObject;
  LStart: Integer;
  LOutputIds: TStringList;
  LDependencies: TJSONArray;
  LStageGuid: TGUID;
  J: Integer;
  K: Integer;
  LFoundDependency: Boolean;
  LLicenseFile: String;
  LLicenseCache: String;
  LAlias: TJSONObject;
  I: Integer;
begin
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LOutput := TJSONObject.Create(['version', 2]);
  FInventory := TJSONArray.Create;
  LOutputIds := TStringList.Create;
  LOutputIds.Sorted := True;
  LOutputIds.CaseSensitive := False;
  LOutput.Add('assets', FInventory);
  try
    CheckKitLock(LLock);
    for LItem in LLock.Arrays['kits'] do
    begin
      FKit := TJSONObject(LItem.Value);
      LStart := FInventory.Count;
      if FKit.Get('sourceMode', '') = 'derived.obj.v1' then
      begin
        ImportDerivedKit(ARoot, FKit, FInventory);
        for I := LStart to FInventory.Count - 1 do
        begin
          Require(LOutputIds.IndexOf(FInventory.Objects[I].Strings['id']) < 0,
            'Duplicate derived output model ID');
          LOutputIds.Add(FInventory.Objects[I].Strings['id']);
        end;
        Continue;
      end;
      if FKit.Find('sources') <> nil then
      begin
        ImportCollectionKit(ARoot, FKit, FInventory);
        for I := LStart to FInventory.Count - 1 do
        begin
          Require(LOutputIds.IndexOf(FInventory.Objects[I].Strings['id']) < 0,
            'Duplicate collection output model ID');
          LOutputIds.Add(FInventory.Objects[I].Strings['id']);
        end;
        Continue;
      end;
      LArchive := SafeChild(ARoot, 'build/asset-research/' + FKit.Strings['id'] + '.zip');
      FetchPinned(FKit.Strings['archiveUrl'], LArchive, FKit.Strings['archiveSha256']);
      Require((FKit.Get('storage', 'core') = 'core') or
        (FKit.Get('storage', 'core') = 'library'), 'Unknown kit storage');
      LPublished := 'cge/data/kits/';
      if FKit.Get('storage', 'core') = 'library' then
      begin
        LPublished := 'assets/library/kits/';
      end;
      LPublished := SafeChild(ARoot, LPublished + FKit.Strings['id']);
      CreateGUID(LStageGuid);
      { Keep this prefix short for original nested filenames on Windows. The
        archive hash belongs to provenance; the fresh GUID owns this attempt. }
      FDestination := SafeChild(ARoot, 'build/asset-staging/' + GUIDToString(LStageGuid));
      Require(not DirectoryExists(FDestination), 'Expected a fresh import staging directory');
      FPrefix := '';
      LFoundModels := False;
      FLicenseEntry := FKit.Get('licensePath', 'License.txt');
      LLicenseFile := 'License.txt';
      if FKit.Find('licenseEvidence') <> nil then
      begin
        FLicenseEntry := '';
        LLicenseFile := 'SourceLicense.html';
      end;
      LZip := TUnZipper.Create;
      LFiles := TStringList.Create;
      LFiles.CaseSensitive := True;
      LNames := TStringList.Create;
      try
        LNames.Sorted := True;
        LNames.CaseSensitive := False;
        LZip.FileName := LArchive;
        LZip.Examine;
        for I := 0 to LZip.Entries.Count - 1 do
        begin
          LName := LZip.Entries[I].ArchiveFileName;
          if KitModel(FKit, LName) then
          begin
            FPrefix := Copy(LName, 1, LastDelimiter('/', LName));
            LFoundModels := True;
            Break;
          end;
        end;
        Require(LFoundModels, 'No models in the declared format in archive');
        FPrefix := FKit.Get('modelPrefix', FPrefix);
        LTotal := 0;
        LSelectedModels := 0;
        for I := 0 to LZip.Entries.Count - 1 do
        begin
          LName := LZip.Entries[I].ArchiveFileName;
          if FLicenseEntry = '' then
          begin
            Require(not ((Copy(LowerCase(ExtractFileName(LName)), 1, 7) = 'license') and
              (SameText(ExtractFileExt(LName), '.txt') or
              SameText(ExtractFileExt(LName), '.md'))),
              'Creator-page mode cannot replace a bundled license notice');
          end;
          if (LName <> '') and (LName[Length(LName)] <> '/') and
            ((LName = FLicenseEntry) or (Copy(LName, 1, Length(FPrefix)) = FPrefix)) then
          begin
            CheckArchivePath(LName);
            Require((LZip.Entries[I].Size >= 0) and
              (LZip.Entries[I].Size <= 32 * 1024 * 1024), 'Archive member too large');
            Inc(LTotal, LZip.Entries[I].Size);
            Require((LTotal <= 512 * 1024 * 1024) and (LFiles.Count < 20000),
              'Expanded kit exceeds import bounds');
            LRelative := Copy(LName, Length(FPrefix) + 1, MaxInt);
            if LName = FLicenseEntry then
            begin
              LRelative := 'License.txt';
            end;
            SafeChild(FDestination, LRelative);
            Require(LNames.IndexOf(LRelative) < 0, 'Case-folded archive path collision');
            LNames.Add(LRelative);
            LFiles.Add(LName);
            if KitModel(FKit, LRelative) then
            begin
              Inc(LSelectedModels);
            end;
          end;
        end;
        if FLicenseEntry <> '' then
        begin
          Require(LFiles.IndexOf(FLicenseEntry) >= 0, 'Archive is missing its license');
        end
        else
        begin
          Require(LNames.IndexOf(LLicenseFile) < 0,
            'Archive collides with external creator license evidence');
          LNames.Add(LLicenseFile);
        end;
        Require(LSelectedModels > 0, 'Selected prefix contains no declared model format');
        if FKit.Find('dependencyAliases') <> nil then
        begin
          Require(FKit.Arrays['dependencyAliases'].Count <= 256, 'Too many dependency aliases');
          for I := 0 to FKit.Arrays['dependencyAliases'].Count - 1 do
          begin
            LAlias := FKit.Arrays['dependencyAliases'].Objects[I];
            CheckArchivePath(LAlias.Strings['from']);
            CheckArchivePath(LAlias.Strings['to']);
            Require(LFiles.IndexOf(FPrefix + LAlias.Strings['from']) >= 0,
              'Dependency alias source is not an exact selected archive member');
            Require(LNames.IndexOf(LAlias.Strings['to']) < 0,
              'Dependency alias collides with a published path');
            Require(not KitModel(FKit, LAlias.Strings['to']),
              'Dependency aliases must not introduce model files');
            LNames.Add(LAlias.Strings['to']);
          end;
        end;
        LZip.OnCreateStream := CreateStream;
        LZip.OnDoneStream := DoneStream;
        LZip.UnZipFiles(LFiles);
        if FKit.Find('dependencyAliases') <> nil then
        begin
          for I := 0 to FKit.Arrays['dependencyAliases'].Count - 1 do
          begin
            LAlias := FKit.Arrays['dependencyAliases'].Objects[I];
            LSource := SafeChild(FDestination, LAlias.Strings['from']);
            Inc(LTotal, Length(ReadBytes(LSource)));
            Require(LTotal <= 512 * 1024 * 1024, 'Alias-expanded kit exceeds import bounds');
            WriteBytes(SafeChild(FDestination, LAlias.Strings['to']), ReadBytes(LSource));
          end;
        end;
        if FLicenseEntry = '' then
        begin
          LLicenseCache := SafeChild(ARoot, 'build/asset-research/' +
            FKit.Strings['id'] + '-license.html');
          FetchPinned(FKit.Objects['licenseEvidence'].Strings['url'], LLicenseCache,
            FKit.Objects['licenseEvidence'].Strings['sha256']);
          Require(Length(ReadBytes(LLicenseCache)) <= 2 * 1024 * 1024,
            'Creator license evidence exceeds size bound');
          CheckCreatorEvidence(FKit, ReadText(LLicenseCache));
          WriteBytes(SafeChild(FDestination, LLicenseFile), ReadBytes(LLicenseCache));
        end;
        Require(Pos('CC0', ReadText(SafeChild(FDestination, LLicenseFile))) > 0,
          'Kit does not contain the expected CC0 notice');
        for I := LStart to FInventory.Count - 1 do
        begin
          LAsset := FInventory.Objects[I];
          Require(LOutputIds.IndexOf(LAsset.Strings['id']) < 0, 'Duplicate output model ID');
          LOutputIds.Add(LAsset.Strings['id']);
          LAsset.Add('licenseSha256', HashFile(SafeChild(FDestination, LLicenseFile)));
          if FLicenseEntry = '' then
          begin
            LAsset.Add('licenseFile', LLicenseFile);
            LAsset.Add('licenseEvidence', FKit.Objects['licenseEvidence'].Clone);
          end;
          LSource := SafeChild(FDestination, Copy(LAsset.Strings['url'],
            Length('kits/' + FKit.Strings['id'] + '/') + 1, MaxInt));
          LModel := ModelJSON(ReadBytes(LSource), ExtractFileExt(LSource));
          try
            LDependencies := ModelDependencies(LModel, FKit, FDestination, LSource);
            LAsset.Add('dependencies', LDependencies);
            for J := 0 to LDependencies.Count - 1 do
            begin
              LFoundDependency := False;
              for K := 0 to LNames.Count - 1 do
              begin
                if LDependencies.Objects[J].Strings['path'] = LNames[K] then
                begin
                  LFoundDependency := True;
                  Break;
                end;
              end;
              Require(LFoundDependency, 'Dependency is not an exact selected archive member: ' +
                LDependencies.Objects[J].Strings['path']);
            end;
          finally
            LModel.Free;
          end;
        end;
        { New kit directories are published by one same-volume rename. Existing
          selected files are immutable. Unlisted complete
          kits may remain after a later kit fails; only the atomic inventory
          publication makes a complete import discoverable. }
        if DirectoryExists(LPublished) then
        begin
          for I := 0 to LNames.Count - 1 do
          begin
            LSource := SafeChild(FDestination, LNames[I]);
            LTarget := SafeChild(LPublished, LNames[I]);
            Require(FileExists(LTarget) and (not DirectoryExists(LTarget)),
              'Incomplete published kit; use a new versioned kit ID: ' + LTarget);
            Require(HashFile(LSource) = HashFile(LTarget),
              'Published kit differs; use a new versioned kit ID: ' + LTarget);
          end;
        end
        else
        begin
          ForceDirectories(ExtractFileDir(LPublished));
          Require(RenameFile(FDestination, LPublished), 'Cannot publish complete kit directory');
        end;
        WriteLn(FKit.Strings['id'], ': imported ', LFiles.Count, ' files');
      finally
        LNames.Free;
        LFiles.Free;
        LZip.Free;
      end;
    end;
    WriteTextAtomic(SafeChild(ARoot, 'data/asset-inventory.json'), LOutput.FormatJSON + #10);
  finally
    LOutputIds.Free;
    LOutput.Free;
    LLock.Free;
  end;
end;

procedure ImportKits(const ARoot: String);
var
  LImporter: TKitImporter;
begin
  LImporter := TKitImporter.Create;
  try
    LImporter.Run(ARoot);
  finally
    LImporter.Free;
  end;
end;

procedure VerifyKits(const ARoot: String);
var
  LRegional: TRegionalAssetAdmission;
  LInventory: TJSONObject;
  LLock: TJSONObject;
  LKit: TJSONObject;
  LKits: TStringList;
  LPalette: TJSONObject;
  LIds: TStringList;
  LRoles: TStringList;
  LItem: TJSONEnum;
  LPart: TJSONEnum;
  LAsset: TJSONObject;
  LModel: TJSONObject;
  LBytes: TBytes;
  LPath: String;
  LUri: String;
  LWidth: Double;
  LRoot: String;
  LKitRoot: String;
  LDependencies: TJSONArray;
  J: Integer;
  I: Integer;
begin
  LInventory := LoadJSON(SafeChild(ARoot, 'data/asset-inventory.json'));
  LLock := LoadJSON(SafeChild(ARoot, 'data/kits.lock.json'));
  LKits := TStringList.Create;
  LPalette := LoadJSON(SafeChild(ARoot, 'data/palette.json'));
  LIds := TStringList.Create;
  LRoles := TStringList.Create;
  try
    CheckKitLock(LLock);
    LKits.Sorted := True;
    LKits.CaseSensitive := True;
    for I := 0 to LLock.Arrays['kits'].Count - 1 do
    begin
      LKit := LLock.Arrays['kits'].Objects[I];
      LKits.AddObject(LKit.Strings['id'], LKit);
      if LKit.Get('sourceMode', '') = 'derived.obj.v1' then
      begin
        VerifyDerivedKit(ARoot, LKit, LInventory.Arrays['assets']);
      end;
      if LKit.Find('sources') <> nil then
      begin
        VerifyCollectionKit(ARoot, LKit, LInventory.Arrays['assets']);
      end;
      if LKit.Find('dependencyAliases') <> nil then
      begin
        LRoot := 'cge/data/kits/';
        if LKit.Get('storage', 'core') = 'library' then
        begin
          LRoot := 'assets/library/kits/';
        end;
        LKitRoot := SafeChild(ARoot, LRoot + LKit.Strings['id']);
        for J := 0 to LKit.Arrays['dependencyAliases'].Count - 1 do
        begin
          CheckExactFilePath(LKitRoot, LKit.Arrays['dependencyAliases'].Objects[J].Strings['from']);
          CheckExactFilePath(LKitRoot, LKit.Arrays['dependencyAliases'].Objects[J].Strings['to']);
          Require(HashFile(SafeChild(LKitRoot,
            LKit.Arrays['dependencyAliases'].Objects[J].Strings['from'])) =
            HashFile(SafeChild(LKitRoot,
            LKit.Arrays['dependencyAliases'].Objects[J].Strings['to'])),
            'Published dependency alias changed source bytes');
        end;
      end;
    end;
    LIds.Sorted := True;
    LIds.CaseSensitive := True;
    for LItem in LInventory.Arrays['assets'] do
    begin
      LAsset := TJSONObject(LItem.Value);
      I := LKits.IndexOf(LAsset.Strings['kit']);
      Require(I >= 0, 'Inventory kit is absent from source lock');
      LKit := TJSONObject(LKits.Objects[I]);
      if (LKit.Find('sources') <> nil) or
        (LKit.Get('sourceMode', '') = 'derived.obj.v1') then
      begin
        Require(LIds.IndexOf(LAsset.Strings['id']) < 0, 'Duplicate asset ID');
        LIds.Add(LAsset.Strings['id']);
        Continue;
      end;
      Require((LAsset.Strings['source'] = LKit.Strings['page']) and
        (LAsset.Strings['license'] = LKit.Strings['license']), 'Inventory source changed');
      Require(LIds.IndexOf(LAsset.Strings['id']) < 0, 'Duplicate asset ID');
      LIds.Add(LAsset.Strings['id']);
      LRoot := 'cge/data';
      Require((LAsset.Get('storage', 'core') = 'core') or
        (LAsset.Get('storage', 'core') = 'library'), 'Unknown asset storage');
      if LAsset.Get('storage', 'core') = 'library' then
      begin
        LRoot := 'assets/library';
      end;
      LPath := SafeChild(SafeChild(ARoot, LRoot), LAsset.Strings['url']);
      LKitRoot := SafeChild(SafeChild(ARoot, LRoot), 'kits/' + LAsset.Strings['kit']);
      LBytes := ReadBytes(LPath);
      Require(HashBytes(LBytes) = LAsset.Strings['sha256'], 'Model hash mismatch: ' + LPath);
      Require(Length(LBytes) = LAsset.Integers['bytes'], 'Model byte count mismatch');
      Require(ExtractFileExt(LPath) = '.' + LAsset.Get('format', 'glb'),
        'Model format metadata mismatch');
      LModel := ModelJSON(LBytes, ExtractFileExt(LPath));
      try
        LDependencies := ModelDependencies(LModel, LKit, LKitRoot, LPath);
        try
          Require(LAsset.Arrays['dependencies'].AsJSON = LDependencies.AsJSON,
            'Model dependency set or bytes changed: ' + LPath);
        finally
          LDependencies.Free;
        end;
      finally
        LModel.Free;
      end;
      Require(Pos('CC0', ReadText(SafeChild(SafeChild(ARoot, LRoot),
        'kits/' + LAsset.Strings['kit'] + '/' +
        LAsset.Get('licenseFile', 'License.txt')))) > 0,
        'Missing CC0 license: ' + LPath);
      Require(HashFile(SafeChild(LKitRoot, LAsset.Get('licenseFile', 'License.txt'))) =
        LAsset.Strings['licenseSha256'],
        'Source license changed: ' + LPath);
      if LAsset.Find('licenseEvidence') <> nil then
      begin
        Require((LKit.Find('licenseEvidence') <> nil) and
          (LAsset.Objects['licenseEvidence'].AsJSON = LKit.Objects['licenseEvidence'].AsJSON),
          'Creator evidence differs from pinned source lock');
        Require(LAsset.Get('licenseFile', '') = 'SourceLicense.html',
          'Creator evidence must retain its explicit filename');
        Require(LAsset.Objects['licenseEvidence'].Strings['sha256'] =
          LAsset.Strings['licenseSha256'], 'Creator evidence hash mismatch');
        CheckCreatorEvidence(LKit, ReadText(SafeChild(LKitRoot, 'SourceLicense.html')));
      end
      else
      begin
        Require(LKit.Find('licenseEvidence') = nil, 'Inventory omitted creator evidence');
      end;
    end;
    for LItem in LPalette.Arrays['assets'] do
    begin
      LAsset := TJSONObject(LItem.Value);
      LUri := LAsset.Strings['kind'];
      if LRoles.IndexOf(LUri) < 0 then
      begin
        LRoles.Add(LUri);
      end;
      LWidth := 4;
      if (LUri = 'cabin') or (LUri = 'castle') or (LUri = 'modern') or (LUri = 'scifi') then
      begin
        LWidth := 8;
      end;
      Require((LAsset.Floats['width'] > 0) and (LAsset.Floats['width'] <= LWidth),
        'Palette footprint exceeds cell size');
      if LAsset.Find('generator') <> nil then
      begin
        Require((LAsset.Strings['generator'] = 'phanes.cabin.shell.v1') and
          (LAsset.Strings['id'] = 'cabin') and (LUri = 'cabin') and
          (LAsset.Floats['width'] = 5) and (LAsset.Find('prefab') = nil),
          'Unknown or incompatible authored geometry profile');
      end
      else if LAsset.Find('prefab') <> nil then
      begin
        for LPart in LPalette.Objects['prefabs'].Arrays[LAsset.Strings['prefab']] do
        begin
          Require(LIds.IndexOf(TJSONObject(LPart.Value).Strings['asset']) >= 0, 'Unknown prefab model');
          Require((TJSONObject(LPart.Value).Arrays['scale'].Count = 3) and
            (TJSONObject(LPart.Value).Arrays['position'].Count = 3), 'Invalid prefab transform');
          for I := 0 to 2 do
          begin
            Require(TJSONObject(LPart.Value).Arrays['scale'].Floats[I] > 0, 'Invalid prefab scale');
          end;
        end;
      end
      else if Pos('phanes.catalog.', LAsset.Strings['id']) = 1 then
      begin
        Require(RegionalAssetAdmission(LAsset.Strings['id'], LRegional),
          'Unknown optional regional admission');
        Require((LUri = LRegional.FRole) and
          (LAsset.Strings['theme'] = LRegional.FTheme) and
          (LAsset.Get('cluster', 1) = 1) and
          (Abs(LAsset.Floats['width'] - Max(LRegional.FWidth, LRegional.FDepth) / 2000) < 0.00001),
          'Optional palette differs from its measured placement profile');
        Require(LIds.IndexOf(LRegional.FModelId) >= 0, 'Unknown optional source model');
      end
      else
      begin
        Require(LIds.IndexOf(LAsset.Strings['id']) >= 0, 'Unknown palette model');
      end;
    end;
    Require(LRoles.Count = 9, 'Unexpected regional role coverage');
    WriteLn('Verified ', LIds.Count, ' models, texture references, CC0 notices and ',
      LPalette.Arrays['assets'].Count, ' regional choices.');
  finally
    LRoles.Free;
    LIds.Free;
    LPalette.Free;
    LKits.Free;
    LLock.Free;
    LInventory.Free;
  end;
end;

end.
