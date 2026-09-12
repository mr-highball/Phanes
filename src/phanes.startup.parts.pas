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
unit phanes.startup.parts;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses
  JS, Web;

function DownloadStartupFile(const AManifest, AUrl, APhase, ALabel: String): TJSArrayBuffer; async;

implementation

uses
  SysUtils;

const
  StartupPartBytes = 512 * 1024;
  StartupFileLimit = 256 * 1024 * 1024;
  PartAttempts = 4;

type
  TStartupBridge = class external name 'Object'(TJSObject)
    procedure stage(const APhase, ALabel: String);
    procedure progress(const ALoaded, ATotal: Double);
    procedure log(const AMessage: String);
  end;

function Startup: TStartupBridge;
begin
  Result := TStartupBridge(TJSObject(window)['phanesStartup']);
end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise TJSError.new(AMessage);
  end;
end;

procedure CheckActive;
begin
  Require(document.body.getAttribute('data-startup-state') <> 'failed',
    'Startup has stopped.');
end;

function Integrity(const AHash: String): String;
const
  CHex = '0123456789abcdef';
var
  LBytes: String;
  LHigh: Integer;
  LLow: Integer;
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Invalid startup SHA-256.');
  LBytes := '';
  for I := 0 to 31 do
  begin
    LHigh := Pos(AHash[I * 2 + 1], CHex) - 1;
    LLow := Pos(AHash[I * 2 + 2], CHex) - 1;
    Require((LHigh >= 0) and (LLow >= 0), 'Invalid startup SHA-256.');
    LBytes := LBytes + Chr(LHigh * 16 + LLow);
  end;
  { Fetch verifies this supported digest on same-origin LAN HTTP too. Never
    supply empty or malformed metadata, which browsers may silently ignore. }
  Result := 'sha256-' + window.btoa(LBytes);
end;

function StartupFile(const AManifest, AUrl: String): TJSObject;
var
  LManifest: TJSObject;
  LFiles: TJSArray;
  LFile: TJSObject;
  LParts: TJSArray;
  LPart: TJSObject;
  LHash: String;
  LTotal: Integer;
  LExpected: Integer;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  { The ordered manifest is compiled into the host together with the source
    revisions. No unverified mutable index chooses executable engine bytes. }
  LManifest := TJSObject(TJSJSON.parse(AManifest));
  Require((Integer(LManifest['version']) = 1) and
    (Integer(LManifest['partBytes']) = StartupPartBytes) and
    TJSArray.isArray(LManifest['files']), 'Invalid startup part manifest.');
  LFiles := TJSArray(LManifest['files']);
  Require(LFiles.length = 2, 'Invalid startup file count.');
  for I := 0 to LFiles.length - 1 do
  begin
    LFile := TJSObject(LFiles[I]);
    LHash := String(LFile['sha256']);
    Integrity(LHash);
    if String(LFile['path']) + '?revision=' + LHash <> AUrl then
    begin
      Continue;
    end;
    Require(Result = nil, 'Duplicate startup file.');
    Require(isInteger(LFile['bytes']) and (Integer(LFile['bytes']) > 0) and
      (Integer(LFile['bytes']) <= StartupFileLimit), 'Invalid startup file size.');
    Require(TJSArray.isArray(LFile['parts']), 'Invalid startup parts.');
    LParts := TJSArray(LFile['parts']);
    Require(LParts.length = (Integer(LFile['bytes']) + StartupPartBytes - 1) div
      StartupPartBytes, 'Invalid startup part count.');
    LTotal := 0;
    for J := 0 to LParts.length - 1 do
    begin
      LPart := TJSObject(LParts[J]);
      LHash := String(LPart['sha256']);
      Integrity(LHash);
      Require(String(LPart['url']) = 'runtime/parts/' + LHash + '.part',
        'Invalid startup part URL.');
      LExpected := StartupPartBytes;
      if J = LParts.length - 1 then
      begin
        LExpected := Integer(LFile['bytes']) - LTotal;
      end;
      Require(isInteger(LPart['bytes']) and (Integer(LPart['bytes']) = LExpected),
        'Invalid startup part length.');
      Inc(LTotal, LExpected);
    end;
    Result := LFile;
  end;
  Require(Result <> nil, 'Startup file revision is absent from the manifest.');
end;

function FetchPart(const APart: TJSObject; const AAsset: String): TJSArrayBuffer; async;
var
  LController: TJSAbortController;
  LOptions: TJSObject;
  LAbort: TJSEventHandler;
  LTimer: NativeInt;
  LResponse: TJSResponse;
begin
  CheckActive;
  LController := TJSAbortController.new;
  LAbort := function(AEvent: TJSEvent): Boolean
    begin
      LController.abort;
      Result := True;
    end;
  window.addEventListener('phanes-startup-failed', LAbort);
  LTimer := window.setTimeout(procedure
    begin
      LController.abort;
    end, 30000);
  try
    LOptions := TJSObject.new;
    LOptions['signal'] := LController.signal;
    LOptions['integrity'] := Integrity(String(APart['sha256']));
    LOptions['cache'] := 'no-store';
    { The query labels network diagnostics and fault tests. File identity and
      integrity remain the content hash; the stock server ignores the query. }
    LResponse := await(TJSResponse, window.fetch(String(APart['url']) +
      '?asset=' + AAsset, LOptions));
    Require(LResponse.ok, 'HTTP ' + IntToStr(LResponse.status));
    Result := await(TJSArrayBuffer, LResponse.arrayBuffer);
    CheckActive;
    Require(Result.byteLength = Integer(APart['bytes']), 'Incomplete startup part.');
  finally
    window.clearTimeout(LTimer);
    window.removeEventListener('phanes-startup-failed', LAbort);
    LController.abort;
  end;
end;

function DownloadStartupFile(const AManifest, AUrl, APhase, ALabel: String): TJSArrayBuffer;
var
  LFile: TJSObject;
  LParts: TJSArray;
  LBytes: TJSUint8Array;
  LBuffer: TJSArrayBuffer;
  LComplete: Integer;
  LAttempt: Integer;
  LWait: JSValue;
  I: Integer;
begin
  CheckActive;
  LFile := StartupFile(AManifest, AUrl);
  LParts := TJSArray(LFile['parts']);
  Startup.stage(APhase, ALabel);
  Startup.log(ALabel + ': ' + IntToStr(LParts.length) + ' verified parts');
  LBytes := TJSUint8Array.new(Integer(LFile['bytes']));
  LComplete := 0;
  Startup.progress(0, LBytes.length);
  for I := 0 to LParts.length - 1 do
  begin
    for LAttempt := 1 to PartAttempts do
    begin
      CheckActive;
      try
        LBuffer := await(FetchPart(TJSObject(LParts[I]), String(LFile['path'])));
        Break;
      except
        CheckActive;
        if LAttempt = PartAttempts then
        begin
          raise TJSError.new(ALabel + ': part ' + IntToStr(I + 1) + ' of ' +
            IntToStr(LParts.length) + ' could not be downloaded and verified after ' +
            IntToStr(PartAttempts) + ' attempts. Check your connection and retry.');
        end;
        Startup.log('Retrying ' + ALabel.ToLower + ', part ' + IntToStr(I + 1) +
          ' (attempt ' + IntToStr(LAttempt + 1) + ' of ' + IntToStr(PartAttempts) + ')');
        LWait := await(JSValue, TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
          begin
            window.setTimeout(procedure
              begin
                AResolve(True);
              end, 500 * LAttempt);
          end));
      end;
    end;
    CheckActive;
    { One destination allocation; only the current verified response is retained.
      Retrying a part never restarts or double-counts completed bytes. }
    LBytes._set(TJSUint8Array.new(LBuffer), LComplete);
    Inc(LComplete, LBuffer.byteLength);
    LBuffer := nil;
    Startup.progress(LComplete, LBytes.length);
  end;
  Startup.log(ALabel + ': received and verified ' + IntToStr(LComplete) + ' bytes');
  Result := TJSArrayBuffer(LBytes.buffer);
end;

end.
