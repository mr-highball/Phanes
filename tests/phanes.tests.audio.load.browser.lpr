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
program PhanesAudioLoadChecks;

{$mode delphi}
{$H+}

uses
  SysUtils, FPJSON, phanes.tools.browser, phanes.tools.files;

var
  GPage: TBrowserProbe;
  GProbe: UTF8String;
  GOutput: String;
  GProfile: TJSONObject;
  GTempo: Integer;
  I: Integer;

begin
  Require(ParamCount = 3, 'Usage: audio-load-checks BROWSER URL EVIDENCE');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    GProbe := ReadText('build/phanes.tests.audio.load.probe.js');
    if (Length(GProbe) >= 3) and (Ord(GProbe[1]) = $EF) and
      (Ord(GProbe[2]) = $BB) and (Ord(GProbe[3]) = $BF) then
    begin
      Delete(GProbe, 1, 3);
    end;
    GPage.InstallScript('(function(){' + String(GProbe) + ';rtl.run();})();');
    GPage.Resize(390, 844, 2);
    GPage.Navigate(ParamStr(2));
    GPage.WaitFor('document.body.dataset.startupState==="ready"');
    GPage.SetValue('region-size', '4');
    GPage.Click('#create-world');
    GPage.WaitFor('Number(document.body.dataset.renderedRevision)===phanesSceneVersion');
    GPage.Click('[data-camera="fly"]');
    GPage.Click('#edit-toggle');
    GProfile := GPage.Profile(6000);
    try
      WriteText(GOutput + '/world-profile.json', GProfile.AsJSON);
    finally
      GProfile.Free;
    end;
    GPage.Click('#open-audio');
    GPage.SetValue('music-tempo', '120', 'change');
    GPage.Click('#music-mobile-toggle');
    GPage.WaitFor('phanesAudioState.scheduledEvents>0');
    Sleep(5000);
    WriteText(GOutput + '/initial.json', GPage.Text('JSON.stringify(phanesAudioState)'));
    for I := 0 to 19 do
    begin
      GTempo := 80 + ((I * 13) mod 70);
      GPage.SetValue('music-tempo', IntToStr(GTempo), 'input');
      GPage.SetValue('music-tempo', IntToStr(GTempo), 'change');
      Sleep(50);
    end;
    GPage.SetValue('music-tempo', '110', 'change');
    GPage.WaitFor('phanesAudioState.activeBpm===110 && !phanesAudioState.tempoPending', 20000);
    GPage.Click('#close-audio');
    Sleep(5000);
    WriteText(GOutput + '/final.json', GPage.Text('JSON.stringify(phanesAudioState)'));
    WriteText(GOutput + '/events.json', GPage.Text('JSON.stringify(phanesAudioLoadProbe)'));
    GPage.Screenshot(GOutput + '/playing-world.png');
    WriteLn('Captured actual source-node scheduling during rapid tempo changes.');
  finally
    GPage.Free;
  end;
end.

