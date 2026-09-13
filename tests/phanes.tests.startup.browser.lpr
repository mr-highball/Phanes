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
program PhanesStartupBrowserChecks;

{$mode delphi}
{$H+}

uses
  SysUtils, phanes.tools.browser, phanes.tools.files;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GCase: String;
  GProbe: UTF8String;

procedure Check(const APass: Boolean; const AMessage: String);
begin
  Require(APass, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

begin
  Require(ParamCount = 4, 'Usage: startup-checks BROWSER URL EVIDENCE CASE');
  GOutput := ExpandFileName(ParamStr(3));
  GCase := ParamStr(4);
  ForceDirectories(GOutput);
  if GCase = 'part-corrupt' then
  begin
    WriteText('build/web/runtime/test-corrupt.part', 'Wrong HTTP bytes for native SRI rejection');
  end;
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    try
      GPage.Resize(390, 844, 2);
      if GCase = 'engine-network' then
      begin
        GPage.BlockURLs(['*.wasm*']);
      end else if GCase = 'assets-network' then
      begin
        GPage.BlockURLs(['*phanes_data.zip*']);
      end else if GCase = 'catalog-network' then
      begin
        GPage.BlockURLs(['*data/palette.json*']);
      end;
      GProbe := ReadText('build/phanes.tests.startup.probe.js');
      if (Length(GProbe) >= 3) and (Ord(GProbe[1]) = $EF) and
        (Ord(GProbe[2]) = $BB) and (Ord(GProbe[3]) = $BF) then
      begin
        Delete(GProbe, 1, 3);
      end;
      GPage.InstallScript('window.phanesStartupTestCase=' + QuotedStr(GCase) + ';' +
        '(function(){' + String(GProbe) + ';rtl.run();})();');
      GPage.Navigate(ParamStr(2));
      if GCase = 'slow-catalog' then
      begin
        GPage.WaitFor('document.body && document.body.dataset.ready === "true"');
        Check(GPage.Text('document.body.dataset.startupState') = 'catalog',
          'A delayed catalog is reported accurately after the first frame');
        Check(GPage.Number('document.getElementById("startup-info").getBoundingClientRect().height') > 0,
          'The delayed catalog label remains visibly rendered after the first frame');
        Check(GPage.Number('document.getElementById("create-world").disabled ? 1:0') = 1,
          'A rendered frame alone never enables Create');
        GPage.Screenshot(GOutput + '/catalog-phone.png');
        GPage.Execute('window.phanesStartupTestResume()');
        GPage.WaitFor('document.body && document.body.dataset.startupState === "ready"');
        Check(GPage.Number('document.getElementById("create-world").disabled ? 1:0') = 0,
          'A delayed catalog completes startup without reloading');
      end else if GCase = 'slow-compile' then
      begin
        GPage.WaitFor('document.body && document.body.dataset.startupState === "compile"');
        GPage.WaitFor('!document.getElementById("startup-help").hidden', 40000);
        Check(GPage.Text('document.body.dataset.startupState') = 'compile',
          'A slow compilation stays pending instead of being declared failed');
        Check(GPage.Number('document.getElementById("create-world").disabled ? 1:0') = 1,
          'Slow compilation does not enable Create early');
        GPage.Screenshot(GOutput + '/slow-phone.png');
        GPage.Execute('window.phanesStartupTestResume()');
        GPage.WaitFor('document.body && document.body.dataset.startupState === "ready"');
        Check(True, 'A slow compilation can finish successfully without reloading');
      end else if (GCase = 'normal') or (GCase = 'part-recovery') then
      begin
        GPage.WaitFor('document.body && document.body.dataset.startupState === "ready"');
        Check(GPage.Number('document.getElementById("create-world").disabled ? 1:0') = 0,
          'Create enables after the renderer and catalog are both ready');
        Check(GPage.Number('window.phanesStartupTestHistory.length') >= 5,
          'Startup exposes separate download and engine preparation stages');
        GPage.Screenshot(GOutput + '/ready-phone.png');
        GPage.Resize(1280, 900, 1);
        GPage.Screenshot(GOutput + '/ready-desktop.png');
        GPage.SetValue('region-size', '4');
        GPage.Click('#create-world');
        GPage.WaitFor('document.body && phanesEditor.world && !phanesEditor.worker && ' +
          'Number(document.body.dataset.renderedRevision) === phanesSceneVersion');
        Check(True, 'Four-cell world creates and renders after startup');
        if GCase = 'part-recovery' then
        begin
          Check(GPage.Number('phanesStartupTestRequests[phanesStartupTestTarget]') = 3,
            'An interrupted part succeeds on the third bounded attempt');
          Check(GPage.Number('phanesStartupTestRequests[phanesStartupTestEngineParts[0]]') = 1,
            'Completed engine parts are retained across retries');
          Check(GPage.Number('phanesStartupTestEngineParts.length') > 100,
            'All engine parts complete after recovery');
        end;
      end else
      begin
        GPage.WaitFor('document.body && document.body.dataset.startupState === "failed"');
        Check(GPage.Number('document.getElementById("create-world").disabled ? 1:0') = 1,
          'Failed startup never enables Create');
        Check(GPage.Number('document.getElementById("import-world").disabled ? 1:0') = 1,
          'Failed startup never enables Open');
        Check(GPage.Number('document.getElementById("startup-info").getBoundingClientRect().height') > 0,
          'Startup failure reason remains visibly rendered');
        Check(GPage.Number('document.getElementById("startup-retry").hidden ? 1:0') = 0,
          'Failed startup offers Retry loading');
        if (GCase = 'caught-initialize') or (GCase = 'late-initialize') then
        begin
          Check(Pos('Injected initialization failure', GPage.Text(
            'document.getElementById("startup-info").textContent')) > 0,
            'WASI internally caught initialization error reaches the phone');
          if GCase = 'late-initialize' then
          begin
            Check(GPage.Text('document.body.dataset.ready') = 'true',
              'Initialization failure wins even after a first frame was drawn');
          end;
        end;
        GPage.Click('#startup-details summary');
        GPage.Click('#startup-select-details');
        Check(GPage.Number('document.getElementById("startup-details-text").selectionEnd') > 20,
          'Error details can be selected on HTTP without Clipboard permission');
        GPage.Screenshot(GOutput + '/failure-phone.png');
        WriteText(GOutput + '/details.txt', GPage.Text(
          'document.getElementById("startup-details-text").value'));
        if GCase = 'part-corrupt' then
        begin
          Check(Pos('could not be downloaded and verified', GPage.Text(
            'document.getElementById("startup-info").textContent')) > 0,
            'A failed part exposes a readable recovery message');
          Check(GPage.Number('phanesStartupTestRequests[phanesStartupTestTarget]') = 4,
            'Corrupted HTTP bytes exhaust exactly four verified attempts');
          Check(GPage.Number('phanesStartupTestHistory.includes("compile") ? 1:0') = 0,
            'Corrupted parts never reach compilation');
          Check(GPage.Number('phanesStartupTestRequests[phanesStartupTestEngineParts[0]]') = 1,
            'Corruption does not restart completed downloads');
        end else if GCase = 'part-cancel' then
        begin
          Check(GPage.Number('phanesStartupTestAborted ? 1:0') = 1,
            'A failed startup aborts its active Fetch signal');
          Check(GPage.Number('phanesStartupTestRequests[phanesStartupTestTarget]') = 1,
            'Cancellation stops without retrying');
        end;
        GPage.Resize(1280, 900, 1);
        GPage.Screenshot(GOutput + '/failure-desktop.png');
        if (GCase = 'engine-network') or (GCase = 'assets-network') then
        begin
          GPage.BlockURLs([]);
          GPage.Click('#startup-retry');
          GPage.WaitFor('document.body && document.body.dataset.startupState === "ready"');
          Check(True, 'Retry recovers when the interrupted download is available');
        end;
      end;
      WriteText(GOutput + '/stages.json', GPage.Text('JSON.stringify(window.phanesStartupTestHistory)'));
    except
      on LException: Exception do
      begin
        GPage.Screenshot(GOutput + '/unexpected-failure.png');
        WriteText(GOutput + '/unexpected-dom.txt', GPage.Text('document.body.innerText'));
        raise;
      end;
    end;
  finally
    GPage.Free;
    if GCase = 'part-corrupt' then
    begin
      DeleteFile('build/web/runtime/test-corrupt.part');
    end;
  end;
end.
