/*
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
*/

const fs = require('node:fs');
const path = require('node:path');
const { WASI } = require('node:wasi');

(async () => {
  const root = path.resolve(__dirname, '..');
  const binary = fs.readFileSync(path.join(root, 'build/terrain-wasm/phanes.tests.terrain.wasm'));
  const wasi = new WASI({
    version: 'preview1',
    args: [],
    env: {},
    preopens: {},
    returnOnExit: true,
  });
  const { instance } = await WebAssembly.instantiate(binary, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  const started = performance.now();
  const exitCode = wasi.start(instance);
  if (exitCode !== 0) {
    throw new Error('Pascal terrain WASM checks exited with ' + exitCode);
  }
  console.log('WASM suite elapsed ms:', Math.round(performance.now() - started));
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
