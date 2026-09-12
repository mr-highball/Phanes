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
program PhanesCatalogFetchProbe;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses
  JS, Web, phanes.catalog.fetch;

var
  GFetcher: TCatalogFetcher;
  GProbe: TJSObject;
  GIndexUrl: String;
  GCacheBudget: Integer;

function StartFetch(AKitId, AModelId: JSValue): JSValue;
begin
  Result := GFetcher.FetchModel(String(AKitId), String(AModelId));
end;

function CancelFetch: JSValue;
begin
  GFetcher.Cancel;
  Result := Undefined;
end;

function ReleaseFetch(ALease: JSValue): JSValue;
begin
  GFetcher.Release(String(ALease));
  Result := Undefined;
end;

function ClearFetch: JSValue;
begin
  GFetcher.ClearUnused;
  Result := Undefined;
end;

function FetchStats: JSValue;
begin
  Result := GFetcher.Stats;
end;

function TestIndexUrl: String;
begin
  asm
    Result = new URL(window.location.href).searchParams.get('index') ||
      'data/library-files.json';
  end;
end;

function TestCacheBudget: Integer;
begin
  asm
    Result = Number(new URL(window.location.href).searchParams.get('budget')) ||
      100663296;
  end;
end;

begin
  GIndexUrl := TestIndexUrl;
  GCacheBudget := TestCacheBudget;
  GFetcher := TCatalogFetcher.Create(GIndexUrl, GCacheBudget);
  GProbe := TJSObject.new;
  GProbe['fetch'] := @StartFetch;
  GProbe['cancel'] := @CancelFetch;
  GProbe['release'] := @ReleaseFetch;
  GProbe['clear'] := @ClearFetch;
  GProbe['stats'] := @FetchStats;
  TJSObject(window)['phanesCatalogFetchProbe'] := GProbe;
end.
