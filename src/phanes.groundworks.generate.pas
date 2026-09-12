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

unit phanes.groundworks.generate;

{$mode delphi}
{$H+}

interface

uses
  phanes.world.types;

function IsGroundworkCreation(const AOperation: String): Boolean;
function AttachGroundwork(const ARequest: TWorldRequest; var AWorld: TWorld;
  out AReason: String): Boolean;
function EditGroundwork(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;

implementation

uses
  phanes.composition.types,
  phanes.composition.document,
  phanes.groundworks.geometry,
  phanes.groundworks.assembly;

function IsGroundworkCreation(const AOperation: String): Boolean;
begin
  Result := (AOperation = 'foundation') or (AOperation = 'launch-pad');
end;

function RequestedBody(const AValue: String; const ADefault: TGroundworkBody;
  out ABody: TGroundworkBody; out AReason: String): Boolean;
begin
  ABody := ADefault;
  Result := True;
  if AValue = 'plinth' then
  begin
    ABody := gbPlinth;
  end
  else if AValue = 'piers' then
  begin
    ABody := gbPiers;
  end
  else if AValue <> '' then
  begin
    AReason := 'Choose plinth or piers for the support structure.';
    Result := False;
  end;
end;

function AttachGroundwork(const ARequest: TWorldRequest; var AWorld: TWorld;
  out AReason: String): Boolean;
var
  LBody: TGroundworkBody;
  LPurpose: TGroundworkPurpose;
  LDocument: TCompositionDocument;
  LCommitted: TCompositionDocument;
  LStaged: TWorld;
  LStartTurn: Integer;
  LTurn: Integer;
  LAttempts: Integer;
  LCreated: Boolean;
  I: Integer;
begin
  Result := False;
  if not IsGroundworkCreation(ARequest.FOperation) or
    (ARequest.FWidth <> 2) or (ARequest.FDepth <> 2) then
  begin
    AReason := 'Select a complete 2 x 2 plot for this groundwork.';
    Exit;
  end;
  if (ARequest.FGroundworkTurn < -1) or (ARequest.FGroundworkTurn > 3) then
  begin
    AReason := 'Choose a cardinal approach direction or automatic access.';
    Exit;
  end;
  if not RequestedBody(ARequest.FGroundworkBody, gbPlinth, LBody, AReason) then
  begin
    Exit;
  end;
  LPurpose := gpFoundation;
  if ARequest.FOperation = 'launch-pad' then
  begin
    LPurpose := gpLaunchPad;
  end;
  LStartTurn := ARequest.FGroundworkTurn;
  LAttempts := 1;
  if LStartTurn = -1 then
  begin
    LStartTurn := ARequest.FSeed mod 4;
    LAttempts := 4;
  end;
  LCreated := False;
  LStaged := AWorld;
  LStaged.FComposition := CopyDocument(AWorld.FComposition);
  LStaged.FComposition.FRevision := ARequest.FPrevious.FComposition.FRevision;
  for I := 0 to LAttempts - 1 do
  begin
    LTurn := (LStartTurn + I) mod 4;
    if CreateGroundwork(LStaged, ARequest.FX, ARequest.FZ, LTurn, LPurpose, LBody,
      ARequest.FSeed, LDocument, AReason) then
    begin
      LCreated := True;
      Break;
    end;
  end;
  if not LCreated then
  begin
    Exit;
  end;
  { Regional clearing and local material generation use private staged snapshots.
    Their intermediate commits never leave the worker. Rebase only this staged
    revision, then run the original baseline's lock/dependency gate once more.
    The published world advances exactly one revision for the complete action. }
  LDocument.FRevision := ARequest.FPrevious.FComposition.FRevision;
  if not CommitComposition(ARequest.FPrevious.FComposition, LDocument, 'world',
    ARequest.FPrevious.FComposition.FRevision, LCommitted, AReason) then
  begin
    Exit;
  end;
  AWorld.FComposition := LCommitted;
  Result := True;
end;

function EditGroundwork(const ARequest: TWorldRequest; out AWorld: TWorld;
  out AReason: String): Boolean;
var
  LIndex: TCompositionIndex;
  LAssembly: TGroundworkAssembly;
  LBody: TGroundworkBody;
  LDocument: TCompositionDocument;
  LId: String;
begin
  AWorld := Default(TWorld);
  Result := False;
  LIndex := TCompositionIndex.Create(ARequest.FPrevious.FComposition.FNodes);
  try
    LId := GroundworkOwner(ARequest.FPrevious.FComposition, LIndex,
      LIndex.Find(ARequest.FObjectId));
    if LId = '' then
    begin
      AReason := 'Select an existing groundwork or one of its rim panels or supports.';
      Exit;
    end;
    if not ReadGroundwork(ARequest.FPrevious, LId, LAssembly, AReason) or
      not RequestedBody(ARequest.FGroundworkBody, LAssembly.FBody, LBody, AReason) then
    begin
      Exit;
    end;
    if not ReimagineGroundwork(ARequest.FPrevious, LId, ARequest.FObjectId, LBody,
      ARequest.FSeed, LDocument, AReason) then
    begin
      Exit;
    end;
    AWorld := ARequest.FPrevious;
    AWorld.FComposition := LDocument;
    AWorld.FSeed := ARequest.FSeed;
    Result := True;
  finally
    LIndex.Free;
  end;
end;

end.
