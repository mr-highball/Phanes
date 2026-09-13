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
program PhanesCatalogFetchBrowserChecks;

{$mode delphi}
{$H+}

uses
  SysUtils, phanes.tools.browser, phanes.tools.files;

const
  FoodKit = 'quaternius-low-poly-food-pack-surface-v1';
  FoodModel = FoodKit + '/soysauce-2882b4c31b';
  FurnitureKit = 'kaykit-furniture-bits-1-0';
  FurnitureModel = FurnitureKit + '/gltf/rug_rectangle_A';
  BoundedKit = 'bounded-kit';

var
  GPage: TBrowserProbe;
  GCase: String;

procedure Check(const APass: Boolean; const AMessage: String);
begin
  Require(APass, AMessage);
  WriteLn('PASS ', AMessage);
  Flush(Output);
end;

begin
  Require(ParamCount = 4, 'Usage: catalog-fetch-checks BROWSER URL EVIDENCE CASE');
  GCase := ParamStr(4);
  ForceDirectories(ExpandFileName(ParamStr(3)));
  GPage := TBrowserProbe.Create(ParamStr(1),
    ExpandFileName(ParamStr(3)) + '/profile');
  try
    GPage.Navigate(ParamStr(2));
    GPage.WaitFor('!!window.phanesCatalogFetchProbe');
    if GCase = 'stream-index' then
    begin
      GPage.Execute('window.catalogNativeFetch=window.fetch;window.streamPulls=0;' +
        'window.streamCancelled=false;window.fetch=(u,o)=>{' +
        'if(String(u).includes("data/library-files.json")){' +
        'return Promise.resolve(new Response(new ReadableStream({' +
        'pull(c){streamPulls++;if(streamPulls===1)c.enqueue(new Uint8Array(200000));' +
        'else if(streamPulls===2)c.enqueue(new Uint8Array(70000));' +
        'else {window.streamReadPastLimit=true;c.enqueue(new Uint8Array(1))}},' +
        'cancel(){streamCancelled=true}},{highWaterMark:0}))) }return catalogNativeFetch(u,o)};' +
        'window.streamFailed=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/pin").then(()=>window.streamUnexpected=true,' +
        '()=>window.streamFailed=true)');
      GPage.WaitFor('window.streamFailed || window.streamUnexpected', 30000);
      Check(GPage.Text('window.streamUnexpected===true') = 'false',
        'Chunked index overflow cannot complete');
      Check((GPage.Number('window.streamPulls') = 2) and
        (GPage.Text('window.streamReadPastLimit===true') = 'false'),
        'Index rejects the overflowing chunk before reading another');
      Check(GPage.Text('window.streamCancelled') = 'true',
        'Index overflow cancels its response reader');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 0),
        'Chunked index overflow leaves no cache or lease');
      Exit;
    end;
    if GCase = 'stream-manifest' then
    begin
      GPage.Execute('window.catalogNativeFetch=window.fetch;window.manifestExpected=0;' +
        'catalogNativeFetch("data/library-files.json").then(r=>r.json()).then(i=>{' +
        'manifestExpected=i.kits.find(k=>k.id==="bounded-kit").bytes})');
      GPage.WaitFor('window.manifestExpected>0');
      GPage.Execute('window.streamPulls=0;window.streamCancelled=false;' +
        'window.fetch=(u,o)=>{if(String(u).includes("library/catalog/")){' +
        'return Promise.resolve(new Response(new ReadableStream({' +
        'pull(c){streamPulls++;if(streamPulls===1)' +
        'c.enqueue(new Uint8Array(manifestExpected+1));' +
        'else {window.streamReadPastLimit=true;c.enqueue(new Uint8Array(1))}},' +
        'cancel(){streamCancelled=true}},{highWaterMark:0}))) }return catalogNativeFetch(u,o)};' +
        'window.streamFailed=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/pin").then(()=>window.streamUnexpected=true,' +
        '()=>window.streamFailed=true)');
      GPage.WaitFor('window.streamFailed || window.streamUnexpected', 30000);
      Check(GPage.Text('window.streamUnexpected===true') = 'false',
        'Chunked manifest overflow cannot complete');
      Check((GPage.Number('window.streamPulls') = 1) and
        (GPage.Text('window.streamReadPastLimit===true') = 'false') and
        (GPage.Text('window.streamCancelled') = 'true'),
        'Manifest rejects its first oversized chunk and cancels the reader');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 0),
        'Chunked manifest overflow leaves no cache or lease');
      Exit;
    end;
    if GCase = 'stream-model' then
    begin
      GPage.Execute('window.catalogNativeFetch=window.fetch;window.pinReady=false;' +
        'phanesCatalogFetchProbe.fetch("bounded-kit","bounded-kit/pin")' +
        '.then(v=>{pin=v;pinReady=true})');
      GPage.WaitFor('window.pinReady');
      GPage.Execute('window.streamPulls=0;window.streamCancelled=false;' +
        'window.fetch=(u,o)=>{if(String(u).includes("library/blobs/")&&' +
        '!String(u).endsWith(pin.files[0].sha256)&&!String(u).endsWith(pin.files[1].sha256)){' +
        'return Promise.resolve(new Response(new ReadableStream({' +
        'pull(c){streamPulls++;if(streamPulls===1)c.enqueue(new Uint8Array(4));' +
        'else if(streamPulls===2)c.enqueue(new Uint8Array(1));' +
        'else {window.streamReadPastLimit=true;c.enqueue(new Uint8Array(1))}},' +
        'cancel(){streamCancelled=true}},{highWaterMark:0}))) }return catalogNativeFetch(u,o)};' +
        'window.streamFailed=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/seed").then(()=>window.streamUnexpected=true,' +
        '()=>window.streamFailed=true)');
      GPage.WaitFor('window.streamFailed || window.streamUnexpected', 30000);
      Check(GPage.Text('window.streamUnexpected===true') = 'false',
        'Chunked model overrun cannot complete');
      Check((GPage.Number('window.streamPulls') = 2) and
        (GPage.Text('window.streamReadPastLimit===true') = 'false') and
        (GPage.Text('window.streamCancelled') = 'true'),
        'Model rejects the overflowing chunk before reading another and cancels');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 4) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 1) and
        (GPage.Text('pin.files.every(f=>f.buffer.byteLength>0)') = 'true'),
        'Chunked model overrun preserves the existing pinned lease');

      GPage.Execute('window.streamPulls=0;window.streamAborted=false;' +
        'window.streamFailed=false;window.fetch=(u,o)=>{' +
        'if(String(u).includes("library/blobs/")&&!String(u).endsWith(pin.files[0].sha256)' +
        '&&!String(u).endsWith(pin.files[1].sha256)){' +
        'let pullResolve=null;return Promise.resolve(new Response(new ReadableStream({' +
        'start(c){o.signal.addEventListener("abort",()=>{streamAborted=true;' +
        'c.error(new DOMException("cancelled","AbortError"));if(pullResolve)pullResolve()})},' +
        'pull(c){streamPulls++;return new Promise(r=>{pullResolve=r})},' +
        'cancel(){window.cancelReaderCalled=true}},{highWaterMark:0})))}' +
        'return catalogNativeFetch(u,o)};' +
        'phanesCatalogFetchProbe.fetch("bounded-kit","bounded-kit/seed")' +
        '.then(()=>window.streamUnexpected=true,()=>window.streamFailed=true)');
      GPage.WaitFor('window.streamPulls===1');
      GPage.Execute('phanesCatalogFetchProbe.cancel()');
      GPage.WaitFor('window.streamFailed || window.streamUnexpected', 30000);
      Check((GPage.Text('window.streamUnexpected===true') = 'false') and
        (GPage.Text('window.streamAborted') = 'true'),
        'Cancellation interrupts an active chunked reader');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 4) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 1) and
        (GPage.Text('pin.files.every(f=>f.buffer.byteLength>0)') = 'true'),
        'Chunked cancellation preserves existing pinned bytes');
      GPage.Execute('phanesCatalogFetchProbe.release(pin.lease);' +
        'phanesCatalogFetchProbe.clear()');
      Exit;
    end;
    if GCase = 'stream-error' then
    begin
      GPage.Execute('window.catalogNativeFetch=window.fetch;window.pinReady=false;' +
        'window.unhandled=[];addEventListener("unhandledrejection",e=>{' +
        'unhandled.push(String(e.reason));e.preventDefault()});' +
        'phanesCatalogFetchProbe.fetch("bounded-kit","bounded-kit/pin")' +
        '.then(v=>{pin=v;pinReady=true})');
      GPage.WaitFor('window.pinReady');
      GPage.Execute('window.errorScheduled=false;window.fetch=(u,o)=>{' +
        'if(String(u).includes("library/blobs/")&&!String(u).endsWith(pin.files[0].sha256)' +
        '&&!String(u).endsWith(pin.files[1].sha256)){' +
        'return Promise.resolve(new Response(new ReadableStream({' +
        'pull(c){if(!errorScheduled){errorScheduled=true;' +
        'setTimeout(()=>c.error(new Error("stream-read-failure")),0)}}' +
        '},{highWaterMark:0})))}return catalogNativeFetch(u,o)};' +
        'window.streamFailed=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/seed").then(()=>window.streamUnexpected=true,e=>{' +
        'window.streamFailure=String(e);window.streamFailed=true})');
      GPage.WaitFor('window.streamFailed || window.streamUnexpected', 30000);
      GPage.Execute('new Promise(r=>setTimeout(()=>{window.completionTurn=true;r()},100))');
      Check(GPage.Text('window.streamUnexpected===true') = 'false',
        'Errored readable stream cannot complete');
      Check(Pos('stream-read-failure', GPage.Text('window.streamFailure')) > 0,
        'Errored readable stream reports its original read failure');
      Check((GPage.Number('window.unhandled.length') = 0) and
        (GPage.Text('window.completionTurn') = 'true'),
        'Rejected reader cancellation produces no unhandled rejection');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 4) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 1) and
        (GPage.Text('pin.files.every(f=>f.buffer.byteLength>0)') = 'true'),
        'Read failure preserves existing pinned bytes and creates no partial state');
      GPage.Execute('phanesCatalogFetchProbe.release(pin.lease);' +
        'phanesCatalogFetchProbe.clear()');
      Exit;
    end;
    if GCase = 'bounded' then
    begin
      GPage.Execute('window.catalogRequests=[];window.catalogNativeFetch=window.fetch;' +
        'window.fetch=(u,o)=>{catalogRequests.push(String(u));return catalogNativeFetch(u,o)};' +
        'window.pinReady=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/pin").then(v=>{pin=v;pinReady=true})');
      GPage.WaitFor('window.pinReady');
      GPage.Execute('window.seedReady=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/seed").then(v=>{seed=v;seedReady=true})');
      GPage.WaitFor('window.seedReady');
      GPage.Execute('phanesCatalogFetchProbe.release(seed.lease);window.targetReady=false;' +
        'window.beforeTargetRequests=catalogRequests.length;' +
        'phanesCatalogFetchProbe.fetch("bounded-kit","bounded-kit/target")' +
        '.then(v=>{target=v;targetReady=true})');
      GPage.WaitFor('window.targetReady');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 12,
        'Protected near-budget commit stays at its configured cache limit');
      Check(GPage.Text('target.files[1].buffer===target.files[2].buffer') = 'true',
        'Cold duplicate hash paths share one transaction buffer');
      Check(GPage.Number('catalogRequests.slice(beforeTargetRequests)' +
        '.filter(u=>u.includes("library/blobs/")).length') = 1,
        'Cold duplicate hash rows request their content only once');
      Check(GPage.Text('target.files.every(f=>f.buffer.byteLength>0)') = 'true',
        'Every near-budget lease row retains live bytes');

      GPage.Execute('window.newHash=target.files.find(f=>f.path==="new.bin").sha256;' +
        'phanesCatalogFetchProbe.release(target.lease);phanesCatalogFetchProbe.clear();' +
        'window.seedReady=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/seed").then(v=>{seed=v;seedReady=true})');
      GPage.WaitFor('window.seedReady');
      GPage.Execute('phanesCatalogFetchProbe.release(seed.lease);' +
        'window.delayedFetch=window.fetch;window.delayed=false;' +
        'window.fetch=(u,o)=>{if(!delayed&&String(u).endsWith(newHash)){' +
        'delayed=true;setTimeout(()=>{phanesCatalogFetchProbe.clear();' +
        'window.clearRan=true},0);return new Promise((resolve,reject)=>{' +
        'let t=setTimeout(()=>delayedFetch(u,o).then(resolve,reject),500);' +
        'o.signal.addEventListener("abort",()=>{clearTimeout(t);reject(new DOMException(' +
        '"cancelled","AbortError"))})})}return delayedFetch(u,o)};' +
        'window.interleavedReady=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/target").then(v=>{interleaved=v;interleavedReady=true})');
      GPage.WaitFor('window.interleavedReady', 30000);
      Check(GPage.Text('window.delayed && window.clearRan') = 'true',
        'Clear runs after the selected missing fetch enters its delay');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 12,
        'Commit recomputes unique missing bytes after interleaved clear');
      Check(GPage.Text('interleaved.files.every(f=>f.buffer.byteLength>0)') = 'true',
        'Interleaved clear cannot discard staged lease rows');
      GPage.Execute('phanesCatalogFetchProbe.release(interleaved.lease);' +
        'phanesCatalogFetchProbe.clear();window.fetch=window.delayedFetch;' +
        'window.tooBigFailed=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/too-big").then(()=>window.tooBigUnexpected=true,' +
        '()=>window.tooBigFailed=true)');
      GPage.WaitFor('window.tooBigFailed || window.tooBigUnexpected', 30000);
      Check(GPage.Text('window.tooBigUnexpected===true') = 'false',
        'Over-budget unique transaction fails before cache insertion');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().leases') = 1,
        'Failed transaction preserves the existing pinned lease');
      Check(GPage.Text('pin.files.every(f=>f.buffer.byteLength>0)') = 'true',
        'Failed transaction preserves existing lease buffers');

      GPage.Execute('window.cancelFetch=window.fetch;window.cancelDelayed=false;' +
        'window.fetch=(u,o)=>{if(!cancelDelayed&&String(u).includes("library/blobs/")){' +
        'cancelDelayed=true;return new Promise((resolve,reject)=>{' +
        'let t=setTimeout(()=>cancelFetch(u,o).then(resolve,reject),500);' +
        'o.signal.addEventListener("abort",()=>{clearTimeout(t);reject(new DOMException(' +
        '"cancelled","AbortError"))})})}return cancelFetch(u,o)};' +
        'window.cancelled=false;phanesCatalogFetchProbe.fetch("bounded-kit",' +
        '"bounded-kit/seed").then(()=>window.cancelUnexpected=true,' +
        '()=>window.cancelled=true);setTimeout(()=>phanesCatalogFetchProbe.cancel(),100)');
      GPage.WaitFor('window.cancelled || window.cancelUnexpected', 30000);
      Check(GPage.Text('window.cancelUnexpected===true') = 'false',
        'Cancelled bounded transaction cannot complete');
      Check((GPage.Number('phanesCatalogFetchProbe.stats().leases') = 1) and
        (GPage.Text('pin.files.every(f=>f.buffer.byteLength>0)') = 'true'),
        'Cancellation preserves the existing pinned lease and buffers');
      GPage.Execute('phanesCatalogFetchProbe.release(pin.lease);' +
        'phanesCatalogFetchProbe.clear()');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0,
        'Duplicate-row pins balance after release and clear');
      Exit;
    end;
    if (GCase <> 'normal') and (GCase <> 'encoded') then
    begin
      if GCase = 'missing' then
      begin
        GPage.Execute('window.failed=false;window.unexpected=false;' +
          'phanesCatalogFetchProbe.fetch(' + QuotedStr(FurnitureKit) + ',' +
          QuotedStr(FurnitureModel) +
          ').then(()=>unexpected=true,e=>{failed=true;failure=String(e)})');
      end else
      begin
        GPage.Execute('window.failed=false;window.unexpected=false;' +
          'phanesCatalogFetchProbe.fetch(' + QuotedStr(FoodKit) + ',' +
          QuotedStr(FoodModel) +
          ').then(()=>unexpected=true,e=>{failed=true;failure=String(e)})');
      end;
      GPage.WaitFor('window.failed || window.unexpected', 30000);
      Check(GPage.Text('unexpected') = 'false',
        GCase + ' publication never produces a completed bundle');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().leases') = 0,
        GCase + ' publication leaves no lease');
      Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0,
        GCase + ' publication leaves no partial cache entry');
      Exit;
    end;
    if GCase = 'encoded' then
    begin
      { Fetch supplies an already decoded body while retaining compressed
        transfer headers. Reproduce that boundary without changing the bytes. }
      GPage.Execute('window.encodingFetch=window.fetch;window.fetch=async(u,o)=>{' +
        'const r=await encodingFetch(u,o),h=new Headers(r.headers);' +
        'h.set("content-encoding","gzip");h.set("content-length","1");' +
        'return new Response(r.body,{status:r.status,headers:h})}');
    end;
    GPage.Execute('window.catalogRequests=[];window.catalogNativeFetch=window.fetch;' +
      'window.fetch=(u,o)=>{catalogRequests.push(String(u));return catalogNativeFetch(u,o)}');
    GPage.Execute('window.catalogProgress=[];' +
      'addEventListener("phanes-catalog-fetch-progress",e=>catalogProgress.push(e.detail));' +
      'window.foodPromise=phanesCatalogFetchProbe.fetch(' + QuotedStr(FoodKit) + ',' +
      QuotedStr(FoodModel) + ').then(v=>window.food=v)');
    GPage.WaitFor('!!window.food', 30000);
    Check(GPage.Number('food.files.length') = 2,
      'Real GLB fetch includes the model and notice only');
    Check(GPage.Number('food.files[0].buffer.byteLength') = 11880,
      'Real GLB bytes match the published model');
    Check(GPage.Text('food.rootPath') = 'soysauce-2882b4c31b.glb',
      'Real GLB retains its canonical root filename');
    Check(GPage.Text('food.files[1].notice') = 'true',
      'Completed bundle identifies the notice');
    Check(GPage.Number('catalogProgress.at(-1).completedBytes') =
      GPage.Number('catalogProgress.at(-1).totalBytes'),
      'Progress reaches the verified closure size');
    GPage.Execute('window.firstLease=food.lease;window.food=null;' +
      'window.blobsBeforeReuse=catalogRequests.filter(u=>u.includes("library/blobs/")).length;' +
      'window.secondPromise=phanesCatalogFetchProbe.fetch(' + QuotedStr(FoodKit) + ',' +
      QuotedStr(FoodModel) + ').then(v=>window.food2=v)');
    GPage.WaitFor('!!window.food2', 30000);
    Check(GPage.Number('phanesCatalogFetchProbe.stats().files') = 2,
      'Repeated model fetch reuses the two content-hash entries');
    Check(GPage.Number('catalogRequests.filter(u=>u.includes("library/blobs/")).length') =
      GPage.Number('blobsBeforeReuse'),
      'Cache reuse performs no second model or notice request');
    GPage.Execute('phanesCatalogFetchProbe.release(firstLease);' +
      'phanesCatalogFetchProbe.release(food2.lease);phanesCatalogFetchProbe.clear()');
    Check(GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0,
      'Explicit release and clear discard unused bytes');

    GPage.Execute('window.rugPromise=phanesCatalogFetchProbe.fetch(' +
      QuotedStr(FurnitureKit) + ',' + QuotedStr(FurnitureModel) +
      ').then(v=>window.rug=v)');
    GPage.WaitFor('!!window.rug', 30000);
    Check(GPage.Number('rug.files.length') = 4,
      'Real glTF fetch includes model, texture, buffer and notice');
    Check(GPage.Number('rug.files.slice(0,3).reduce((n,f)=>n+f.buffer.byteLength,0)') =
      20376, 'Real glTF dependency closure matches the published byte total');
    Check(GPage.Text('rug.files.slice(0,3).map(f=>f.path).join("|")') =
      'gltf/rug_rectangle_A.gltf|gltf/furniturebits_texture.png|' +
      'gltf/rug_rectangle_A.bin', 'Real glTF preserves dependency-relative paths');

    GPage.Execute('window.originalFetch=window.fetch;window.delayedOnce=true;' +
      'window.fetch=(u,o)=>{if(delayedOnce&&String(u).includes("library/blobs/")){' +
      'delayedOnce=false;return new Promise((resolve,reject)=>{' +
      'let t=setTimeout(()=>originalFetch(u,o).then(resolve,reject),1000);' +
      'o.signal.addEventListener("abort",()=>{clearTimeout(t);reject(new DOMException("cancelled","AbortError"))})})}' +
      'return originalFetch(u,o)};' +
      'window.staleResolved=false;window.staleRejected=false;' +
      'phanesCatalogFetchProbe.clear();phanesCatalogFetchProbe.fetch(' +
      QuotedStr(FoodKit) + ',' + QuotedStr(FoodModel) +
      ').then(()=>staleResolved=true,()=>staleRejected=true);' +
      'setTimeout(()=>phanesCatalogFetchProbe.fetch(' + QuotedStr(FurnitureKit) + ',' +
      QuotedStr(FurnitureModel) + ').then(v=>window.fresh=v),50)');
    GPage.WaitFor('window.staleRejected && !!window.fresh', 30000);
    Check(GPage.Text('staleResolved') = 'false',
      'A new generation prevents stale completion');
    Check(GPage.Text('fresh.modelId') = FurnitureModel,
      'The replacement generation completes independently');
    GPage.Execute('window.fetch=window.originalFetch;' +
      'phanesCatalogFetchProbe.release(rug.lease);' +
      'phanesCatalogFetchProbe.release(fresh.lease);phanesCatalogFetchProbe.clear()');
    if GCase = 'encoded' then
    begin
      GPage.Execute('window.fetch=async(u,o)=>{' +
        'const r=await encodingFetch(u,o);if(!String(u).includes("library/blobs/"))return r;' +
        'const b=await r.arrayBuffer(),h=new Headers(r.headers);' +
        'h.set("content-encoding","gzip");h.set("content-length","1");' +
        'return new Response(b.slice(0,b.byteLength-1),{status:r.status,headers:h})};' +
        'window.shortFailed=false;window.shortUnexpected=false;' +
        'phanesCatalogFetchProbe.fetch(' + QuotedStr(FoodKit) + ',' +
        QuotedStr(FoodModel) + ').then(()=>shortUnexpected=true,e=>{' +
        'shortFailure=e.fMessage||e.message||String(e);shortFailed=true})');
      GPage.WaitFor('window.shortFailed || window.shortUnexpected', 30000);
      Check((GPage.Text('shortUnexpected') = 'false') and
        (Pos('bytes differ from its manifest', GPage.Text('shortFailure')) > 0),
        'Compressed transfer headers cannot hide a truncated decoded body: ' +
        GPage.Text('window.shortFailure||"unexpected success"'));
      Check((GPage.Number('phanesCatalogFetchProbe.stats().bytes') = 0) and
        (GPage.Number('phanesCatalogFetchProbe.stats().leases') = 0),
        'Truncated encoded response leaves no partial cache or lease');
    end;
  finally
    GPage.Free;
  end;
end.
