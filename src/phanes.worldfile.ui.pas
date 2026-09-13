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

unit phanes.worldfile.ui;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

procedure StartWorldFileUI;

implementation

uses
  JS, Web, SysUtils;

const
  MaximumWorldFileBytes = 8 * 1024 * 1024;

type
  TEditorActions = class external name 'Object'(TJSObject)
    procedure cancelSolve;
    procedure generate(const AOperation: String; const AImported, AOptions: TJSObject);
    procedure notify(const AMessage: String; const AError: Boolean);
  end;

  TWorldFile = class external name 'File'(TJSObject)
    size: NativeInt;
    function text: TJSPromise;
  end;

  TWorldFileUI = class
  private
    FState: TJSObject;
    FActions: TEditorActions;
    FVersion: Integer;
    FRequest: Integer;
    function Click(AEvent: TJSEvent): Boolean;
    function Changed(AEvent: TJSEvent): Boolean;
    procedure ImportFile(const AFile: TWorldFile; const ARequest: Integer); async;
    procedure Finish(const AStatus, AMessage: String);
    function EnvelopeWorld(const AText: String): TJSObject;
    procedure ExportWorld;
  public
    constructor Create;
  end;

var
  GWorldFileUI: TWorldFileUI;

function Element(const AId: String): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.getElementById(AId));
end;

constructor TWorldFileUI.Create;
var
  LBridge: TJSObject;
begin
  inherited Create;
  FState := TJSObject(TJSObject(window)['phanesEditor']);
  FActions := TEditorActions(TJSObject(window)['phanesEditorActions']);
  Element('save-world').addEventListener('click', @Click);
  Element('import-world').addEventListener('click', @Click);
  Element('world-file').addEventListener('change', @Changed);
  LBridge := TJSObject.new;
  LBridge['version'] := 0;
  LBridge['status'] := 'ready';
  LBridge['message'] := '';
  TJSObject(window)['phanesWorldFileUI'] := LBridge;
  TJSObject(window)['phanesWorldFileVersion'] := 0;
end;

procedure TWorldFileUI.Finish(const AStatus, AMessage: String);
var
  LBridge: TJSObject;
begin
  Inc(FVersion);
  LBridge := TJSObject(TJSObject(window)['phanesWorldFileUI']);
  LBridge['version'] := FVersion;
  LBridge['status'] := AStatus;
  LBridge['message'] := AMessage;
  TJSObject(window)['phanesWorldFileVersion'] := FVersion;
end;

function TWorldFileUI.EnvelopeWorld(const AText: String): TJSObject;
var
  LEnvelope: TJSObject;
  LWorld: TJSObject;
  LVersion: Integer;
  LWorldVersion: Integer;
begin
  LEnvelope := TJSObject(TJSJSON.parse(AText));
  if not isObject(LEnvelope) or isNull(LEnvelope) or isArray(LEnvelope) or
    not isInteger(LEnvelope['version']) then
  begin
    raise Exception.Create('This is not a supported Phanes world.');
  end;
  LVersion := Integer(LEnvelope['version']);
  if (LVersion < 1) or (LVersion > 4) or
    not isObject(LEnvelope['world']) or isNull(LEnvelope['world']) or
    isArray(LEnvelope['world']) then
  begin
    raise Exception.Create('This is not a supported Phanes world.');
  end;
  LWorld := TJSObject(LEnvelope['world']);
  LWorldVersion := 1;
  if jsTypeOf(LWorld['formatVersion']) <> 'undefined' then
  begin
    if not isInteger(LWorld['formatVersion']) then
    begin
      raise Exception.Create('This is not a supported Phanes world.');
    end;
    LWorldVersion := Integer(LWorld['formatVersion']);
  end;
  if (LWorldVersion <> LVersion) or
    not isInteger(LWorld['size']) or (Integer(LWorld['size']) < 4) or
    (Integer(LWorld['size']) > 48) or not isArray(LWorld['layers']) or
    (TJSArray(LWorld['layers']).Length <> 5) then
  begin
    raise Exception.Create('This is not a supported Phanes world.');
  end;
  Result := LWorld;
end;

procedure TWorldFileUI.ExportWorld;
var
  LWorld: TJSObject;
  LEnvelope: TJSObject;
  LOptions: TJSBlobInit;
  LBlob: TJSBlob;
  LLink: TJSHTMLAnchorElement;
  LUrl: String;
  LVersion: Integer;
begin
  if not isObject(FState['world']) or isNull(FState['world']) then
  begin
    Exit;
  end;
  LWorld := TJSObject(FState['world']);
  if not isInteger(LWorld['formatVersion']) then
  begin
    LVersion := 1;
  end else
  begin
    LVersion := Integer(LWorld['formatVersion']);
  end;
  if (LVersion < 1) or (LVersion > 4) then
  begin
    FActions.notify('This world uses an unsupported save format.', True);
    Finish('rejected', 'Unsupported live world format');
    Exit;
  end;
  LEnvelope := TJSObject.new;
  LEnvelope['version'] := LVersion;
  LEnvelope['world'] := LWorld;
  LOptions := TJSBlobInit.new;
  LOptions['type'] := 'application/json';
  LBlob := TJSBlob.new([TJSJSON.stringify(LEnvelope)], LOptions);
  LUrl := TJSURL.createObjectURL(LBlob);
  LLink := TJSHTMLAnchorElement(document.createElement('a'));
  LLink.href := LUrl;
  LLink.download := 'phanes-' + String(LWorld['seed']) + '.json';
  LLink.click;
  window.setTimeout(procedure
    begin
      TJSURL.revokeObjectURL(LUrl);
    end, 1000);
  Finish('exported', 'World exported');
end;

procedure TWorldFileUI.ImportFile(const AFile: TWorldFile; const ARequest: Integer);
var
  LText: JSValue;
  LWorld: TJSObject;
begin
  try
    LText := await(JSValue, AFile.text);
    if ARequest <> FRequest then
    begin
      Exit;
    end;
    LWorld := EnvelopeWorld(String(LText));
    { Worker restore performs the complete world, elevation, composition and
      layer validation before publication changes the live world or history. }
    FActions.cancelSolve;
    FActions.generate('restore', LWorld, TJSObject.new);
    Finish('submitted', 'World submitted to worker validation');
  except
    on LException: Exception do
    begin
      if ARequest <> FRequest then
      begin
        Exit;
      end;
      FActions.notify(LException.Message, True);
      Finish('rejected', LException.Message);
    end;
    else
    begin
      if ARequest <> FRequest then
      begin
        Exit;
      end;
      FActions.notify('The world file is corrupt or could not be read.', True);
      Finish('rejected', 'The world file is corrupt or could not be read.');
    end;
  end;
  TJSHTMLInputElement(Element('world-file')).value := '';
end;

function TWorldFileUI.Click(AEvent: TJSEvent): Boolean;
begin
  Result := True;
  if TJSElement(AEvent.currentTarget).id = 'save-world' then
  begin
    ExportWorld;
  end else
  begin
    Element('world-file').click;
  end;
end;

function TWorldFileUI.Changed(AEvent: TJSEvent): Boolean;
var
  LFiles: TJSObject;
  LFile: TWorldFile;
begin
  Result := True;
  LFiles := TJSObject(TJSObject(AEvent.currentTarget)['files']);
  if not isObject(LFiles) or isNull(LFiles) or
    not isObject(LFiles['0']) or isNull(LFiles['0']) then
  begin
    Exit;
  end;
  LFile := TWorldFile(LFiles['0']);
  Inc(FRequest);
  if LFile.size > MaximumWorldFileBytes then
  begin
    FActions.notify('Choose a Phanes world file under 8 MB.', True);
    Finish('rejected', 'World file exceeds 8 MB');
    TJSHTMLInputElement(Element('world-file')).value := '';
    Exit;
  end;
  ImportFile(LFile, FRequest);
end;

procedure StartWorldFileUI;
begin
  GWorldFileUI := TWorldFileUI.Create;
end;

end.
