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

unit phanes.tools.music;

{$mode delphi}
{$H+}

interface

procedure ProcessMusic(const ARoot: String; const ACheck: Boolean);

implementation

uses
  Classes,
  SysUtils,
  FPJSON,
  phanes.tools.files,
  phanes.tools.midi;

procedure ProcessMusic(const ARoot: String; const ACheck: Boolean);
const
  CPrefixes: array[0..3] of String = ('midi', 'score', 'archive', 'notice');
var
  LManifest: TJSONObject;
  LOutput: TJSONObject;
  LRecords: TJSONArray;
  LItem: TJSONEnum;
  LReference: TJSONObject;
  LRecord: TJSONObject;
  LScore: TMidiScore;
  LIdentities: TStringList;
  LIds: TStringList;
  LPrefix: String;
  LIdentity: String;
  LPath: String;
  LSourceRoot: String;
  LText: UTF8String;
  LCount: Integer;
begin
  LManifest := LoadJSON(SafeChild(ARoot, 'data/music/references.json'));
  LOutput := TJSONObject.Create(['version', 1,
    'extraction', 'pascal-scale-degrees-and-sixteenth-onsets-v1', 'beatsPerSample', 32]);
  LRecords := TJSONArray.Create;
  LOutput.Add('references', LRecords);
  LIdentities := TStringList.Create;
  LIds := TStringList.Create;
  try
    Require(LManifest.Arrays['references'].Count >= 100, 'At least 100 references are required');
    LIdentities.Sorted := True;
    LIds.Sorted := True;
    LSourceRoot := SafeChild(ARoot, 'data/music/sources');
    LCount := 0;
    for LItem in LManifest.Arrays['references'] do
    begin
      LReference := TJSONObject(LItem.Value);
      Require(LIds.IndexOf(LReference.Strings['id']) < 0, 'Duplicate reference ID');
      LIds.Add(LReference.Strings['id']);
      for LPrefix in CPrefixes do
      begin
        if LReference.Find(LPrefix + 'Path') <> nil then
        begin
          LPath := LReference.Strings[LPrefix + 'Path'];
          Require(Copy(LPath, 1, 19) = 'data/music/sources/', 'Invalid source root');
          LPath := SafeChild(LSourceRoot, Copy(LPath, 20, MaxInt));
          Require(HashFile(LPath) = LReference.Strings[LPrefix + 'Sha256'],
            'Reference hash mismatch: ' + LPath);
        end;
      end;
      LText := LReference.Strings['license'];
      Require((LText = 'Public Domain') or (LText = 'CC0-1.0'), 'Unadmitted reference license');
      if LText = 'Public Domain' then
      begin
        LText := LowerCase(ReadText(SafeChild(ARoot, LReference.Strings['scorePath'])));
        Require(Pos('public domain', LText) > 0, 'Source edition has no public-domain statement');
      end
      else
      begin
        LText := ReadText(SafeChild(ARoot, LReference.Strings['noticePath']));
        Require(Pos('creativecommons.org/publicdomain/zero/1.0', LText) > 0,
          'Source page has no CC0 license link');
      end;
      LScore := ReadMidi(ReadBytes(SafeChild(ARoot, LReference.Strings['midiPath'])));
      LIdentity := ScoreIdentity(LScore);
      Require(LIdentities.IndexOf(LIdentity) < 0,
        'Duplicate or transposed score: ' + LReference.Strings['id']);
      LIdentities.Add(LIdentity);
      LRecord := ExtractSamples(LScore);
      LRecord.Add('id', LReference.Strings['id']);
      LRecord.Add('title', LReference.Strings['title']);
      LRecord.Add('composer', LReference.Strings['composer']);
      LRecord.Add('url', LReference.Strings['url']);
      LRecord.Add('license', LReference.Strings['license']);
      LRecord.Add('semanticSha256', LIdentity);
      LRecord.Add('noteCount', Length(LScore.FNotes));
      Inc(LCount, LRecord.Arrays['samples'].Count);
      LRecords.Add(LRecord);
    end;
    LPath := SafeChild(ARoot, 'data/music/corpus.json');
    LText := LOutput.AsJSON + #10;
    if ACheck then
    begin
      Require(ReadText(LPath) = LText, 'Music corpus is stale; run import-music');
    end
    else
    begin
      WriteText(LPath, LText);
    end;
    WriteLn('Verified ', LRecords.Count, ' distinct scores; ', LCount,
      ' WFC samples; ', Length(LText), ' JSON bytes.');
  finally
    LIds.Free;
    LIdentities.Free;
    LOutput.Free;
    LManifest.Free;
  end;
end;

end.
