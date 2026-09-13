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

program PhanesTransferBrowser;

{$mode delphi}
{$H+}

uses
  SysUtils,
  phanes.tools.browser,
  phanes.tools.files;

var
  GPage: TBrowserProbe;
  GOutput: String;
  GRequireSignedRangeGuard: Boolean;

begin
  Require((ParamCount = 3) or (ParamCount = 4),
    'Usage: transfer-browser BROWSER URL OUTPUT [require-signed-range-guard]');
  GRequireSignedRangeGuard := (ParamCount = 4) and
    (ParamStr(4) = 'require-signed-range-guard');
  Require((ParamCount = 3) or GRequireSignedRangeGuard,
    'Unknown WebGL transfer browser option');
  GOutput := ExpandFileName(ParamStr(3));
  ForceDirectories(GOutput);
  GPage := TBrowserProbe.Create(ParamStr(1), GOutput + '/profile');
  try
    GPage.Resize(640, 480);
    GPage.InstallScript('window.transferErrors=[];window.addEventListener("error",' +
      'e=>transferErrors.push(e.message));window.addEventListener("unhandledrejection",' +
      'e=>transferErrors.push(String(e.reason)));');
    GPage.Navigate(ParamStr(2));
    try
      GPage.WaitFor('Boolean(window.phanesTransferResult || window.phanesTransferFailure)' +
        '||window.transferErrors.length>0||document.body.innerText.includes("Fatal error")', 180000);
    except
      on LException: Exception do
      begin
        WriteText(GOutput + '/startup-failure.json', GPage.Text(
          'JSON.stringify({body:document.body.innerText,errors:window.transferErrors})'));
        raise;
      end;
    end;
    WriteText(GOutput + '/result.json', GPage.Text(
      'JSON.stringify({result:JSON.parse(window.phanesTransferResult||"{}"),' +
      'failure:window.phanesTransferFailure||null,errors:window.transferErrors,body:document.body.innerText})'));
    WriteLn(ReadText(GOutput + '/result.json'));
    Require(GPage.Text('JSON.parse(window.phanesTransferResult||"{}").passed===true') = 'true',
      'WebAssembly transfer checks pass');
    Require(GPage.Text('window.transferErrors.length===0 && !window.phanesTransferFailure') = 'true',
      'WebAssembly transfer checks finish without browser errors');
    Require(GPage.Text('JSON.parse(window.phanesTransferResult||"{}").legacyChecks===9493') =
      'true', 'The 9,493 legacy numerical assertions remain intact');
    if GRequireSignedRangeGuard then
    begin
      Require(GPage.Text('JSON.parse(window.phanesTransferResult||"{}").signedRangeGuard===' +
        '"passed"&&JSON.parse(window.phanesTransferResult||"{}").boundaryChecks===13') = 'true',
        'The signed byte boundary checks pass');
    end;
  finally
    GPage.Free;
  end;
end.
