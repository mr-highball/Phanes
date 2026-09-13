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

const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const root = path.resolve(__dirname, '..');
  const source = fs.readFileSync(path.join(root, 'build/phanes.tests.spaces.js'), 'utf8');
  const browser = await chromium.launch({ headless: true, executablePath: process.env.BROWSER });
  const messages = [];
  const started = performance.now();
  const phases = [];
  const suiteTimeoutMs = 60_000;
  let timeout;
  try {
    const page = await browser.newPage();
    page.on('console', (message) => {
      const text = message.text();
      messages.push(text);
      if (text.startsWith('PHASE ')) {
        phases.push({ elapsedMs: performance.now() - started, text });
      }
    });
    const execution = page.evaluate((compiledPascal) => {
      (0, eval)(compiledPascal);
      try {
        rtl.run();
      } catch (error) {
        throw new Error(error.fMessage || error.message || String(error));
      }
    }, source);
    await Promise.race([
      execution,
      new Promise((_, reject) => {
        timeout = setTimeout(
          () => reject(new Error('Spaces browser suite exceeded 60 seconds')),
          suiteTimeoutMs,
        );
      }),
    ]);
    const result = { passed: true, elapsedMs: performance.now() - started, phases, messages };
    fs.writeFileSync(
      path.join(root, 'build/spaces-browser-evidence.json'),
      JSON.stringify(result, null, 2),
    );
    console.log(messages.join('\n'));
    console.log('Browser suite elapsed ms:', Math.round(result.elapsedMs));
  } catch (error) {
    fs.writeFileSync(
      path.join(root, 'build/spaces-browser-evidence.json'),
      JSON.stringify({ passed: false, phases, messages, error: String(error) }, null, 2),
    );
    console.log(messages.join('\n'));
    throw error;
  } finally {
    clearTimeout(timeout);
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
