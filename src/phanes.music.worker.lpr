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

program PhanesMusicWorker;

{$mode delphi}
{$H+}

uses
  JS,
  WebOrWorker,
  WebWorker,
  SysUtils,
  phanes.music.types,
  phanes.music.generate,
  phanes.music.track,
  phanes.music.wire;

var
  GGenerator: TMusicGenerator;
  GTrack: TMusicTrackPlan;
  GRequest: TMusicRequest;
  GTrackIndex: Integer;

function Receive(AEvent: TJSEvent): Boolean;
var
  LMessage: TJSObject;
  LResponse: TJSObject;
  LReferences: TMusicReferences;
  LStates: TJSArray;
  LPhases: TJSArray;
  LSection: TMusicSection;
  LTrack: TJSObject;
  LSeed: Integer;
  LRequest: TMusicRequest;
  LPlan: TMusicTrackPlan;
  I: Integer;
begin
  Result := True;
  LMessage := TJSObject(TJSMessageEvent(AEvent).Data);
  LResponse := TJSObject.new;
  LResponse['job'] := LMessage['job'];
  try
    if String(LMessage['command']) = 'initialize' then
    begin
      FreeAndNil(GGenerator);
      GTrack := Default(TMusicTrackPlan);
      GRequest := Default(TMusicRequest);
      GTrackIndex := 0;
      LReferences := ReadMusicReferences(TJSObject(LMessage['corpus']));
      GGenerator := TMusicGenerator.Create(LReferences);
      if isObject(LMessage['previous']) and (LMessage['previous'] <> nil) then
      begin
        GGenerator.Restore(ReadMusicSection(TJSObject(LMessage['previous'])));
      end;
      LResponse['ready'] := True;
      LResponse['references'] := Length(LReferences);
      LStates := TJSArray.new;
      for I := 0 to MusicLaneCount - 1 do
      begin
        LStates.push(GGenerator.ModelStateCount(I));
      end;
      LResponse['states'] := LStates;
    end
    else if String(LMessage['command']) = 'begin-track' then
    begin
      if GGenerator = nil then
      begin
        raise Exception.Create('Music corpus has not been initialized');
      end;
      LRequest := ReadMusicRequest(LMessage);
      LPlan := PlanMusicTrack(LRequest);
      GRequest := LRequest;
      GTrack := LPlan;
      GTrackIndex := 0;
      LTrack := TJSObject.new;
      LTrack['seconds'] := GTrack.FSeconds;
      LTrack['bpm'] := GTrack.FBpm;
      LPhases := TJSArray.new;
      for I := 0 to High(GTrack.FPhases) do
      begin
        LPhases.push(GTrack.FPhases[I]);
      end;
      LTrack['phases'] := LPhases;
      LResponse['track'] := LTrack;
    end
    else if String(LMessage['command']) = 'extend-track' then
    begin
      LRequest := ReadMusicRequest(LMessage);
      if (GGenerator = nil) or (LRequest.FIndex <> GTrackIndex) or
        (GTrackIndex >= Length(GTrack.FPhases)) then
      begin
        raise Exception.Create('This musical ending is already composed');
      end;
      for I := 0 to MusicLaneCount - 1 do
      begin
        if LRequest.FLocks[I] <> GRequest.FLocks[I] then
        begin
          raise Exception.Create('Locked layers changed during tempo planning');
        end;
      end;
      { An extension is monotonic. A repeated or superseded minimum is an
        idempotent acknowledgement of the already admitted musical form. }
      LPlan := GTrack;
      if LRequest.FMinimumSections > Length(GTrack.FPhases) then
      begin
        LPlan := ExtendMusicTrack(LRequest, Copy(GTrack.FPhases, 0, GTrackIndex),
          LRequest.FMinimumSections);
      end;
      LPhases := TJSArray.new;
      for I := 0 to High(LPlan.FPhases) do
      begin
        LPhases.push(LPlan.FPhases[I]);
      end;
      LResponse['phases'] := LPhases;
      LResponse['planExtended'] := True;
      GTrack := LPlan;
    end
    else if String(LMessage['command']) = 'track-next' then
    begin
      if GGenerator = nil then
      begin
        raise Exception.Create('No remaining section in this track');
      end;
      // The browser supplies fresh random entropy for each section, including across reloads.
      // Keep its integer wire validation identical to ordinary generation requests.
      LRequest := ReadMusicRequest(LMessage);
      LSeed := LRequest.FSeed;
      if LRequest.FIndex <> GTrackIndex then
      begin
        raise Exception.Create('Unexpected or duplicate track section index');
      end;
      for I := 0 to MusicLaneCount - 1 do
      begin
        if LRequest.FLocks[I] <> GRequest.FLocks[I] then
        begin
          raise Exception.Create('Begin a new track to change locked layers');
        end;
      end;
      LPlan := GTrack;
      if LRequest.FMinimumSections > Length(GTrack.FPhases) then
      begin
        LPlan := ExtendMusicTrack(LRequest, Copy(GTrack.FPhases, 0, GTrackIndex),
          LRequest.FMinimumSections);
      end;
      if GTrackIndex >= Length(LPlan.FPhases) then
      begin
        raise Exception.Create('No remaining section in this track');
      end;
      LRequest := GRequest;
      LRequest.FSeed := LSeed;
      LRequest.FIndex := GTrackIndex;
      LRequest.FHasFeaturedStyle := True;
      LRequest.FFeaturedStyle := FeaturedTrackStyle(LRequest, GTrackIndex);
      LSection := GGenerator.Generate(LRequest);
      ShapeTrackSection(LPlan.FPhases[GTrackIndex], GTrackIndex,
        Length(LPlan.FPhases), LSection);
      ValidateMusic(LSection);
      LResponse['section'] := MusicSectionJSON(LSection);
      TJSObject(LResponse['section'])['phase'] := LPlan.FPhases[GTrackIndex];
      if Length(LPlan.FPhases) <> Length(GTrack.FPhases) then
      begin
        LPhases := TJSArray.new;
        for I := 0 to High(LPlan.FPhases) do
        begin
          LPhases.push(LPlan.FPhases[I]);
        end;
        LResponse['phases'] := LPhases;
      end;
      GTrack := LPlan;
      GRequest := LRequest;
      Inc(GTrackIndex);
    end
    else if String(LMessage['command']) = 'next' then
    begin
      if GGenerator = nil then
      begin
        raise Exception.Create('Music corpus has not been initialized');
      end;
      LResponse['section'] := MusicSectionJSON(GGenerator.Generate(ReadMusicRequest(LMessage)));
    end
    else
    begin
      raise Exception.Create('Unknown music command');
    end;
    LResponse['success'] := True;
  except
    on LException: Exception do
    begin
      LResponse['success'] := False;
      LResponse['message'] := LException.Message;
    end;
  end;
  Self_.postMessage(LResponse);
end;

begin
  Self_.addEventListener('message', @Receive);
end.
