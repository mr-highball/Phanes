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

unit phanes.tools.sourcehtml;

{$mode delphi}
{$H+}

interface

uses
  FPJSON;

procedure CheckBaseMeshFAQ(const AKit: TJSONObject; const AText: String);
procedure CheckBaseMeshPage(const ASource: TJSONObject; const AText: String);
procedure CompressSourceEvidence(const AInput, AOutput: String);
function ReadSourceEvidence(const APath, AHash: String): String;

implementation

uses
  Classes,
  SysUtils,
  DOM,
  DOM_HTML,
  SAX_HTML,
  ZStream,
  phanes.tools.files;

type
  TEvidenceStream = class(TDecompressionStream)
  public
    function ConsumedBytes: Int64;
  end;

function TEvidenceStream.ConsumedBytes: Int64;
begin
  Result := FStream.total_in;
end;

function Inert(const ANode: TDOMNode): Boolean;
var
  LTag: String;
  LStyle: String;
  LElement: TDOMElement;
begin
  Result := ANode.NodeType = COMMENT_NODE;
  if ANode is TDOMElement then
  begin
    LElement := TDOMElement(ANode);
    LTag := LowerCase(UTF8Encode(LElement.TagName));
    LStyle := LowerCase(UTF8Encode(LElement.GetAttribute('style')));
    LStyle := StringReplace(LStyle, ' ', '', [rfReplaceAll]);
    LStyle := StringReplace(LStyle, #9, '', [rfReplaceAll]);
    LStyle := StringReplace(LStyle, #10, '', [rfReplaceAll]);
    LStyle := StringReplace(LStyle, #13, '', [rfReplaceAll]);
    Result := (LTag = 'script') or (LTag = 'style') or
      (LTag = 'noscript') or (LTag = 'template') or LElement.HasAttribute('hidden') or
      (LowerCase(UTF8Encode(LElement.GetAttribute('aria-hidden'))) = 'true') or
      (Pos('display:none', LStyle) > 0) or (Pos('visibility:hidden', LStyle) > 0);
  end;
end;

function VisibleText(const ANode: TDOMNode): String;
var
  LChild: TDOMNode;
begin
  Result := '';
  if Inert(ANode) then
  begin
    Exit;
  end;
  if ANode.NodeType = TEXT_NODE then
  begin
    Exit(UTF8Encode(ANode.NodeValue));
  end;
  LChild := ANode.FirstChild;
  while LChild <> nil do
  begin
    Result := Result + VisibleText(LChild);
    LChild := LChild.NextSibling;
  end;
end;

function Compact(const AText: String): String;
var
  I: Integer;
  LSpace: Boolean;
begin
  Result := '';
  LSpace := False;
  for I := 1 to Length(AText) do
  begin
    if AText[I] in [#9, #10, #13, ' '] then
    begin
      LSpace := Result <> '';
    end
    else
    begin
      if LSpace then
      begin
        Result := Result + ' ';
      end;
      Result := Result + AText[I];
      LSpace := False;
    end;
  end;
end;

procedure CheckHTML(const AText, ACanonical, AArchive: String; const AFAQ: Boolean);
var
  LDocument: THTMLDocument;
  LStream: TStringStream;
  LCanonical: Integer;
  LArchives: Integer;
  LDeclarations: Integer;
  LNodes: Integer;

  procedure CheckLimits(const ANode: TDOMNode; const ADepth: Integer);
  var
    LChild: TDOMNode;
  begin
    Inc(LNodes);
    Require((LNodes <= 100000) and (ADepth <= 128), 'Source evidence DOM exceeds bounds');
    LChild := ANode.FirstChild;
    while LChild <> nil do
    begin
      CheckLimits(LChild, ADepth + 1);
      LChild := LChild.NextSibling;
    end;
  end;

  function LicenseItem(const ANode: TDOMNode): Boolean;
  var
    LQuestion: Boolean;
    LDeclaration: Boolean;
    LLinks: Integer;

    procedure VisitItem(const ACurrent: TDOMNode);
    var
      LChild: TDOMNode;
      LElement: TDOMElement;
      LTag: String;
      LHref: String;
    begin
      if Inert(ACurrent) then
      begin
        Exit;
      end;
      if ACurrent is TDOMElement then
      begin
        LElement := TDOMElement(ACurrent);
        LTag := LowerCase(UTF8Encode(LElement.TagName));
        if (ACurrent <> ANode) and (LTag = 'div') and
          (LElement.GetAttribute('role') = 'listitem') then
        begin
          Exit;
        end;
        if (LTag = 'h2') and
          (Compact(VisibleText(ACurrent)) = 'Can I use these Assets in commercial works?') then
        begin
          LQuestion := True;
        end;
        if (LTag = 'p') and
          (Pos('You certainly can as these models are under the CC0 licence.',
            Compact(VisibleText(ACurrent))) = 1) then
        begin
          LDeclaration := True;
        end;
        if LTag = 'a' then
        begin
          LHref := UTF8Encode(LElement.GetAttribute('href'));
          if Pos('creativecommons.org/', LHref) > 0 then
          begin
            Require(LHref = 'https://creativecommons.org/publicdomain/zero/1.0/',
              'Conflicting declaration inside collection license answer');
            Inc(LLinks);
          end;
        end;
      end;
      LChild := ACurrent.FirstChild;
      while LChild <> nil do
      begin
        VisitItem(LChild);
        LChild := LChild.NextSibling;
      end;
    end;

  begin
    LQuestion := False;
    LDeclaration := False;
    LLinks := 0;
    VisitItem(ANode);
    Result := LQuestion and LDeclaration and (LLinks = 1);
  end;

  procedure Visit(const ANode: TDOMNode);
  var
    LElement: TDOMElement;
    LChild: TDOMNode;
    LTag: String;
    LHref: String;
  begin
    if Inert(ANode) then
    begin
      Exit;
    end;
    if ANode is TDOMElement then
    begin
      LElement := TDOMElement(ANode);
      LTag := LowerCase(UTF8Encode(LElement.TagName));
      LHref := UTF8Encode(LElement.GetAttribute('href'));
      if (LTag = 'link') and (LElement.GetAttribute('rel') = 'canonical') then
      begin
        Require(LHref = ACanonical, 'Source evidence canonical page mismatch');
        Inc(LCanonical);
      end;
      if (not AFAQ) and (LTag = 'a') and
        (Pos('/_files/archives/', LHref) > 0) then
      begin
        Require(LHref = AArchive, 'Source page links a different original archive');
        Inc(LArchives);
      end;
      if AFAQ and (LTag = 'div') and (LElement.GetAttribute('role') = 'listitem') and
        LicenseItem(ANode) then
      begin
        Inc(LDeclarations);
      end;
    end;
    LChild := ANode.FirstChild;
    while LChild <> nil do
    begin
      Visit(LChild);
      LChild := LChild.NextSibling;
    end;
  end;

begin
  Require(Length(AText) <= 4 * 1024 * 1024, 'Source HTML exceeds bound');
  Require(Pos('<template', LowerCase(AText)) = 0, 'Unsupported inert HTML template');
  LDocument := nil;
  LStream := TStringStream.Create(AText);
  LCanonical := 0;
  LArchives := 0;
  LDeclarations := 0;
  LNodes := 0;
  try
    ReadHTMLFile(LDocument, LStream);
    CheckLimits(LDocument, 0);
    Visit(LDocument);
    Require(LCanonical = 1, 'Source requires exactly one canonical page identity');
    if AFAQ then
    begin
      Require(LDeclarations = 1, 'Missing visible collection-wide CC0 answer and link');
    end
    else
    begin
      Require(LArchives = 1, 'Missing unique source page to archive association');
    end;
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

procedure CheckBaseMeshFAQ(const AKit: TJSONObject; const AText: String);
begin
  Require((AKit.Get('publisher', '') = 'The Base Mesh') and
    (AKit.Strings['page'] = 'https://www.thebasemesh.com/model-library') and
    (AKit.Objects['licenseEvidence'].Strings['mode'] = 'basemesh.faq.v1') and
    (AKit.Objects['licenseEvidence'].Strings['url'] = 'https://www.thebasemesh.com/faq'),
    'Unrecognized collection license source');
  CheckHTML(AText, 'https://www.thebasemesh.com/faq', '', True);
end;

procedure CheckBaseMeshPage(const ASource: TJSONObject; const AText: String);
const
  CPagePrefix = 'https://www.thebasemesh.com/asset/';
  CArchivePrefix = 'https://www.thebasemesh.com/_files/archives/';
var
  LSlug: String;
  LDecoded: String;
  LArchive: String;
  LCode: Integer;
  LValue: Integer;
  I: Integer;
begin
  Require((Copy(ASource.Strings['page'], 1, Length(CPagePrefix)) = CPagePrefix) and
    (Length(ASource.Strings['page']) > Length(CPagePrefix)),
    'Unrecognized original model page');
  Require(Copy(ASource.Strings['archiveUrl'], 1, Length(CArchivePrefix)) = CArchivePrefix,
    'Unrecognized original model archive host/path');
  LSlug := Copy(ASource.Strings['page'], Length(CPagePrefix) + 1, MaxInt);
  LDecoded := '';
  I := 1;
  while I <= Length(LSlug) do
  begin
    if LSlug[I] = '%' then
    begin
      Require(I + 2 <= Length(LSlug), 'Incomplete source URL escape');
      Val('$' + Copy(LSlug, I + 1, 2), LValue, LCode);
      Require((LCode = 0) and (LValue >= 32) and (LValue < 127), 'Invalid source URL escape');
      LDecoded := LDecoded + Chr(LValue);
      Inc(I, 3);
    end
    else
    begin
      Require(LSlug[I] <> ' ', 'Source URL contains an unescaped space');
      LDecoded := LDecoded + LSlug[I];
      Inc(I);
    end;
  end;
  Require((LDecoded <> '') and (LDecoded <> '.') and (LDecoded <> '..') and
    (Trim(LDecoded) = LDecoded), 'Invalid source URL leaf');
  for I := 1 to Length(LDecoded) do
  begin
    Require(LDecoded[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', '(', ')', ' '],
      'Source URL must identify one canonical asset leaf');
  end;
  LArchive := Copy(ASource.Strings['archiveUrl'], Length(CArchivePrefix) + 1, MaxInt);
  I := Pos('?', LArchive);
  if I > 0 then
  begin
    Require(Copy(LArchive, I, 4) = '?dn=', 'Unsupported archive URL query');
    Delete(LArchive, I, MaxInt);
  end;
  Require((Length(LArchive) > 4) and (ExtractFileExt(LArchive) = '.zip'),
    'Archive URL must identify a ZIP leaf');
  for I := 1 to Length(LArchive) do
  begin
    Require(LArchive[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.'],
      'Archive URL must identify one canonical file leaf');
  end;
  CheckHTML(AText, ASource.Strings['page'], ASource.Strings['archiveUrl'], False);
end;

procedure CompressSourceEvidence(const AInput, AOutput: String);
var
  LBytes: TBytes;
  LInput: TFileStream;
  LStream: TMemoryStream;
  LZip: TCompressionStream;
begin
  LInput := TFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
  try
    Require(LInput.Size <= 4 * 1024 * 1024, 'Source HTML exceeds bound');
    SetLength(LBytes, LInput.Size);
    if Length(LBytes) > 0 then
    begin
      LInput.ReadBuffer(LBytes[0], Length(LBytes));
    end;
  finally
    LInput.Free;
  end;
  LStream := TMemoryStream.Create;
  try
    LZip := TCompressionStream.Create(clMax, LStream);
    try
      if Length(LBytes) > 0 then
      begin
        LZip.WriteBuffer(LBytes[0], Length(LBytes));
      end;
    finally
      LZip.Free;
    end;
    SetLength(LBytes, LStream.Size);
    LStream.Position := 0;
    if Length(LBytes) > 0 then
    begin
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
    WriteBytes(AOutput, LBytes);
  finally
    LStream.Free;
  end;
end;

function ReadSourceEvidence(const APath, AHash: String): String;
var
  LInput: TFileStream;
  LZip: TEvidenceStream;
  LOutput: TMemoryStream;
  LBuffer: array[0..4095] of Byte;
  LRead: Integer;
  LBytes: TBytes;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LInput.Size <= 4 * 1024 * 1024 + 65536, 'Compressed source evidence exceeds bound');
    LOutput := TMemoryStream.Create;
    LZip := TEvidenceStream.Create(LInput);
    try
      repeat
        LRead := LZip.Read(LBuffer, SizeOf(LBuffer));
        Require(LOutput.Size + LRead <= 4 * 1024 * 1024, 'Expanded source evidence exceeds bound');
        if LRead > 0 then
        begin
          LOutput.WriteBuffer(LBuffer, LRead);
        end;
      until LRead = 0;
      Require(LZip.ConsumedBytes = LInput.Size, 'Trailing bytes after source evidence stream');
      SetLength(LBytes, LOutput.Size);
      LOutput.Position := 0;
      if Length(LBytes) > 0 then
      begin
        LOutput.ReadBuffer(LBytes[0], Length(LBytes));
      end;
      Require(HashBytes(LBytes) = AHash, 'Source HTML differs from pinned evidence');
      Result := '';
      if Length(LBytes) > 0 then
      begin
        SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
      end;
    finally
      LZip.Free;
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

end.
