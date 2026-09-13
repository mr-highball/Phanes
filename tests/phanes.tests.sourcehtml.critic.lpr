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

program PhanesTestsSourceHTMLCritic;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  FPJSON,
  ZStream,
  phanes.tools.files,
  phanes.tools.sourcehtml;

const
  FAQURL = 'https://www.thebasemesh.com/faq';
  PageURL = 'https://www.thebasemesh.com/asset/phanes-synthetic-fixture';
  ArchiveURL = 'https://www.thebasemesh.com/_files/archives/critic.zip?dn=critic.zip';
  Question = '<h2>Can I use these Assets in commercial works?</h2>';
  Declaration = '<p>You certainly can as these models are under the CC0 licence.</p>';
  LicenseLink = '<a href="https://creativecommons.org/publicdomain/zero/1.0/">CC0</a>';
  ArchiveLink = '<a href="' + ArchiveURL + '">ZIP</a>';
  Limit = 4 * 1024 * 1024;

var
  GRoot: String;
  GScratch: String;
  GKit: TJSONObject;
  GSource: TJSONObject;
  GChecks: Integer;
  GFailures: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    Inc(GFailures);
    WriteLn('FAIL ', AMessage);
  end;
end;

function Replace(const AText, AOld, ANew: String): String;
begin
  Result := StringReplace(AText, AOld, ANew, [rfReplaceAll]);
end;

function TextBytes(const AText: String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

function Page(const ACanonical, ABody: String): String;
begin
  Result := '<!doctype html><html><head><link rel="canonical" href="' + ACanonical +
    '"/></head><body>' + ABody + '</body></html>';
end;

function FAQItem(const ABody: String): String;
begin
  Result := '<div role="listitem">' + ABody + '</div>';
end;

procedure HTMLCase(const AName, AText: String; const AFAQ, AExpected: Boolean;
  const AData: TJSONObject = nil);
var
  LAccepted: Boolean;
  LReason: String;
  LData: TJSONObject;
begin
  LAccepted := True;
  LReason := '';
  if AData <> nil then
  begin
    LData := AData;
  end
  else if AFAQ then
  begin
    LData := GKit;
  end
  else
  begin
    LData := GSource;
  end;
  try
    if AFAQ then
    begin
      CheckBaseMeshFAQ(LData, AText);
    end
    else
    begin
      CheckBaseMeshPage(LData, AText);
    end;
  except
    on LException: Exception do
    begin
      LAccepted := False;
      LReason := LException.Message;
    end;
  end;
  Check(LAccepted = AExpected, AName + ' accepted=' + BoolToStr(LAccepted, True) +
    ' expected=' + BoolToStr(AExpected, True) + ' reason=' + LReason);
end;

procedure ReadCase(const AName: String; const ACompressed, ARaw: TBytes;
  const AExpected: Boolean; const AOverrideHash: String = '');
var
  LPath: String;
  LHash: String;
  LActual: String;
  LAccepted: Boolean;
begin
  LPath := SafeChild(GScratch, AName + '.zlib');
  WriteBytes(LPath, ACompressed);
  LHash := HashBytes(ARaw);
  if AOverrideHash <> '' then
  begin
    LHash := AOverrideHash;
  end;
  LAccepted := True;
  try
    LActual := ReadSourceEvidence(LPath, LHash);
    Check(HashBytes(TextBytes(LActual)) = HashBytes(ARaw), AName + ' exact returned bytes');
  except
    on LException: Exception do
    begin
      LAccepted := False;
      WriteLn('REJECT ', AName, ': ', LException.Message);
    end;
  end;
  Check(LAccepted = AExpected, AName + ' read acceptance');
end;

function DeflateIndependent(const ABytes: TBytes): TBytes;
var
  LStream: TMemoryStream;
  LDeflate: TCompressionStream;
begin
  LStream := TMemoryStream.Create;
  try
    LDeflate := TCompressionStream.Create(clDefault, LStream);
    try
      if Length(ABytes) > 0 then
      begin
        LDeflate.WriteBuffer(ABytes[0], Length(ABytes));
      end;
    finally
      LDeflate.Free;
    end;
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHTML;
var
  LAnswer: String;
  LFAQ: String;
  LPage: String;
  LData: TJSONObject;
  LNested: String;
  I: Integer;
begin
  LAnswer := FAQItem(Question + Declaration + LicenseLink);
  LFAQ := Page(FAQURL, LAnswer);
  LPage := Page(PageURL, ArchiveLink);
  HTMLCase('minimal FAQ', LFAQ, True, True);
  HTMLCase('minimal source', LPage, False, True);
  HTMLCase('FAQ nested formatting', Page(FAQURL, FAQItem(Question +
    '<p>You certainly can as these <strong>models</strong> are under the CC0 licence.</p>' +
    LicenseLink)), True, True);
  HTMLCase('FAQ whitespace', Replace(LFAQ, 'models are', 'models' + #13#10 + #9 + 'are'),
    True, True);
  HTMLCase('FAQ wrong canonical', Replace(LFAQ, FAQURL, FAQURL + '/wrong'), True, False);
  HTMLCase('page wrong canonical', Replace(LPage, PageURL, PageURL + '-wrong'), False, False);
  HTMLCase('page wrong archive', Replace(LPage, ArchiveURL, ArchiveURL + '&wrong=1'), False, False);
  HTMLCase('page archive query omitted', Replace(LPage, ArchiveURL,
    'https://www.thebasemesh.com/_files/archives/critic.zip'), False, False);
  HTMLCase('page archive text only', Page(PageURL, '<p>' + ArchiveURL + '</p>'), False, False);
  HTMLCase('page archive comment', Page(PageURL, '<!--' + ArchiveLink + '-->'), False, False);
  HTMLCase('page archive script', Page(PageURL, '<script>' + ArchiveLink + '</script>'), False, False);
  HTMLCase('page archive style', Page(PageURL, '<style>' + ArchiveLink + '</style>'), False, False);
  HTMLCase('page archive noscript', Page(PageURL, '<noscript>' + ArchiveLink + '</noscript>'),
    False, False);
  HTMLCase('page archive template', Page(PageURL, '<template>' + ArchiveLink + '</template>'),
    False, False);
  HTMLCase('duplicate page archive', Page(PageURL, ArchiveLink + ArchiveLink), False, False);
  HTMLCase('duplicate canonical', Replace(LPage, '</head>',
    '<link rel="canonical" href="' + PageURL + '"/></head>'), False, False);
  HTMLCase('canonical comment', Replace(LPage, '<link rel="canonical" href="' + PageURL + '"/>',
    '<!--<link rel="canonical" href="' + PageURL + '"/>-->'), False, False);
  HTMLCase('FAQ no answer container', Page(FAQURL, Question + Declaration + LicenseLink), True, False);
  HTMLCase('FAQ comment declaration', Replace(LFAQ, Declaration, '<!--' + Declaration + '-->'),
    True, False);
  HTMLCase('FAQ script declaration', Replace(LFAQ, Declaration,
    '<script>' + Declaration + '</script>'), True, False);
  HTMLCase('FAQ wrong CC link', Replace(LFAQ, 'publicdomain/zero/1.0/', 'licenses/by/4.0/'),
    True, False);
  HTMLCase('FAQ conflicting CC link', Replace(LFAQ, LicenseLink,
    LicenseLink + '<a href="https://creativecommons.org/licenses/by/4.0/">BY</a>'), True, False);
  HTMLCase('FAQ license in another item', Page(FAQURL,
    FAQItem(Question) + FAQItem(Declaration + LicenseLink)), True, False);
  HTMLCase('FAQ answer ends before license', Page(FAQURL,
    FAQItem(Question + Declaration) + LicenseLink), True, False);
  HTMLCase('FAQ duplicate answers', Page(FAQURL, LAnswer + LAnswer), True, False);
  HTMLCase('FAQ nested other answer', Page(FAQURL,
    FAQItem(Question + FAQItem('<h2>What license do donations need?</h2>' + Declaration +
      LicenseLink))), True, False);
  HTMLCase('FAQ negated declaration', Replace(LFAQ, Declaration,
    '<p>It is not true that these models are under the CC0 licence.</p>'), True, False);
  HTMLCase('FAQ hidden answer', Page(FAQURL, Replace(LAnswer,
    '<div role="listitem">', '<div role="listitem" hidden>')), True, False);
  HTMLCase('FAQ aria-hidden declaration', Replace(LFAQ, Declaration,
    '<div aria-hidden="true">' + Declaration + '</div>'), True, False);
  HTMLCase('FAQ inline hidden declaration', Replace(LFAQ, Declaration,
    '<div style="display:none">' + Declaration + '</div>'), True, False);
  HTMLCase('page hidden archive', Page(PageURL, '<div hidden>' + ArchiveLink + '</div>'),
    False, False);
  LData := TJSONObject(GKit.Clone);
  try
    LData.Strings['publisher'] := 'Another publisher';
    HTMLCase('FAQ wrong publisher', LFAQ, True, False, LData);
    LData.Strings['publisher'] := 'The Base Mesh';
    LData.Objects['licenseEvidence'].Strings['mode'] := 'oga-submission.v1';
    HTMLCase('FAQ wrong adapter mode', LFAQ, True, False, LData);
  finally
    LData.Free;
  end;
  LData := TJSONObject(GSource.Clone);
  try
    LData.Strings['page'] := 'https://www.thebasemesh.com.evil.example/asset/fixture';
    HTMLCase('page lookalike host', Page(LData.Strings['page'], ArchiveLink), False, False, LData);
    LData.Strings['page'] := 'https://www.thebasemesh.com/asset/../faq';
    HTMLCase('page parent traversal', Page(LData.Strings['page'], ArchiveLink), False, False, LData);
    LData.Strings['page'] := PageURL;
    LData.Strings['archiveUrl'] := 'https://www.thebasemesh.com/_files/archives/../../../elsewhere.zip';
    HTMLCase('archive parent traversal', Page(PageURL, '<a href="' +
      LData.Strings['archiveUrl'] + '">ZIP</a>'), False, False, LData);
  finally
    LData.Free;
  end;
  HTMLCase('oversized HTML', StringOfChar('x', Limit + 1), True, False);
  LNested := LPage;
  for I := 0 to 140 do
  begin
    LNested := Replace(LNested, ArchiveLink, '<div>' + ArchiveLink + '</div>');
  end;
  HTMLCase('deep HTML', LNested, False, False);
end;

procedure TestCompression;
var
  LRaw: TBytes;
  LCompressed: TBytes;
  LChanged: TBytes;
  LInput: String;
  LOutput: String;
  LAccepted: Boolean;
  LState: Cardinal;
  I: Integer;
begin
  LInput := SafeChild(GScratch, 'input.html');
  LOutput := SafeChild(GScratch, 'output.zlib');
  LRaw := TextBytes('raw' + #13#10 + 'UTF-8 ' + #$E2#$98#$83 + #0 + #255 + #13 + 'end');
  WriteBytes(LInput, LRaw);
  CompressSourceEvidence(LInput, LOutput);
  LCompressed := ReadBytes(LOutput);
  ReadCase('exact mixed-byte roundtrip', LCompressed, LRaw, True);
  ReadCase('independent deflate input', DeflateIndependent(LRaw), LRaw, True);
  ReadCase('wrong raw hash', LCompressed, LRaw, False, StringOfChar('0', 64));
  LChanged := Copy(LCompressed);
  LChanged[Length(LChanged) - 1] := LChanged[Length(LChanged) - 1] xor $FF;
  ReadCase('wrong checksum', LChanged, LRaw, False);
  ReadCase('missing checksum', Copy(LCompressed, 0, Length(LCompressed) - 4), LRaw, False);
  ReadCase('truncated compressed body', Copy(LCompressed, 0, Length(LCompressed) div 2), LRaw, False);
  LChanged := Copy(LCompressed);
  SetLength(LChanged, Length(LChanged) + 4);
  LChanged[Length(LChanged) - 4] := 123;
  ReadCase('trailing compressed garbage', LChanged, LRaw, False);
  ReadCase('empty compressed input', nil, nil, False);
  ReadCase('valid empty roundtrip', DeflateIndependent(nil), nil, True);
  LRaw := TextBytes(StringOfChar('A', Limit + 1));
  ReadCase('expanded budget', DeflateIndependent(LRaw), LRaw, False);
  LChanged := nil;
  SetLength(LChanged, Limit + 1);
  ReadCase('compressed budget', LChanged, nil, False);
  WriteBytes(LInput, LRaw);
  WriteBytes(LOutput, TextBytes('old output'));
  LAccepted := True;
  try
    CompressSourceEvidence(LInput, LOutput);
  except
    on LException: Exception do
    begin
      LAccepted := False;
    end;
  end;
  Check(not LAccepted, 'Oversized input refuses compression');
  Check(HashFile(LOutput) = HashBytes(TextBytes('old output')), 'Refused compression preserves output');
  { An admitted maximum-size raw snapshot must remain readable even when
    incompressible data makes its zlib representation slightly larger. }
  SetLength(LRaw, Limit);
  LState := 123456789;
  for I := 0 to High(LRaw) do
  begin
    LState := LState xor (LState shl 13);
    LState := LState xor (LState shr 17);
    LState := LState xor (LState shl 5);
    LRaw[I] := Byte(LState and $FF);
  end;
  WriteBytes(LInput, LRaw);
  CompressSourceEvidence(LInput, LOutput);
  LCompressed := ReadBytes(LOutput);
  WriteLn('MAXIMUM raw=', Length(LRaw), ' compressed=', Length(LCompressed));
  ReadCase('maximum incompressible roundtrip', LCompressed, LRaw, True);
end;

procedure RealPages;
var
  LCandidate: TJSONObject;
  LSource: TJSONObject;
  LText: String;
begin
  if not FileExists(SafeChild(GRoot, 'build/asset-research/basemesh/faq.html')) then
  begin
    WriteLn('SKIP optional live-capture checks; all synthetic fixtures remain offline');
    Exit;
  end;
  LText := String(ReadText(SafeChild(GRoot, 'build/asset-research/basemesh/faq.html')));
  HTMLCase('actual captured FAQ', LText, True, True);
  LCandidate := LoadJSON(SafeChild(GRoot, 'build/asset-research/basemesh/candidate.json'));
  try
    LSource := LCandidate.Arrays['sources'].Objects[0];
    LText := String(ReadText(SafeChild(GRoot, 'build/asset-research/basemesh/pages/' +
      LSource.Strings['id'] + '.html')));
    HTMLCase('actual captured model page', LText, False, True, LSource);
  finally
    LCandidate.Free;
  end;
end;

procedure Run;
var
  LGuid: TGUID;
begin
  Require((ParamCount = 1) or (ParamCount = 2), 'Pass repository root and optional scratch root');
  GRoot := ExpandFileName(ParamStr(1));
  GScratch := SafeChild(GRoot, 'build/tests/sourcehtml-critic');
  if ParamCount = 2 then
  begin
    GScratch := ExpandFileName(ParamStr(2));
  end;
  Require(CreateGUID(LGuid) = 0, 'Cannot create fresh evidence fixture identifier');
  GScratch := SafeChild(GScratch, GUIDToString(LGuid));
  Require(not DirectoryExists(GScratch), 'Expected fresh fixture root');
  GKit := TJSONObject.Create(['publisher', 'The Base Mesh',
    'page', 'https://www.thebasemesh.com/model-library']);
  GKit.Add('licenseEvidence', TJSONObject.Create(['mode', 'basemesh.faq.v1', 'url', FAQURL]));
  GSource := TJSONObject.Create(['page', PageURL, 'archiveUrl', ArchiveURL]);
  try
    TestHTML;
    TestCompression;
    RealPages;
    WriteLn('RESULT ', GChecks, ' independent source evidence checks, failures=', GFailures);
    Require(GFailures = 0, 'Independent source evidence checks failed');
  finally
    GKit.Free;
    GSource.Free;
  end;
end;

begin
  Run;
end.
