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

program PhanesReviews;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  phanes.tools.reviews;

var
  GMessages: TStringList;
  GPassed: Boolean;
  I: Integer;

begin
  GMessages := TStringList.Create;
  try
    try
      if (ParamCount = 2) and (ParamStr(1) = 'hash') then
      begin
        WriteLn(ReviewFileHash(ParamStr(2)));
        Halt(0);
      end;
      if (ParamCount <> 2) or (ParamStr(1) <> 'check') then
      begin
        raise Exception.Create('Usage: phanes.reviews check <repository> | hash <file>');
      end;
      GPassed := CheckReviewGate(ParamStr(2), GMessages);
      for I := 0 to GMessages.Count - 1 do
      begin
        WriteLn(GMessages[I]);
      end;
      if not GPassed then
      begin
        ExitCode := 1;
      end;
    except
      on LException: Exception do
      begin
        WriteLn(StdErr, 'Critic gate invalid: ', LException.Message);
        ExitCode := 2;
      end;
    end;
  finally
    GMessages.Free;
  end;
end.
