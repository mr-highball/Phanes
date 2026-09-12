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
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const root = path.resolve(__dirname, '..');
  const base = process.env.TEST_URL || 'http://127.0.0.1:4186/';
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.BROWSER,
    args: ['--enable-unsafe-swiftshader'],
  });
  const evidence = { base, viewports: [] };
  try {
    for (const viewport of [
      { width: 1440, height: 960 },
      { width: 390, height: 844 },
    ]) {
      const page = await browser.newPage({ viewport, hasTouch: viewport.width < 500 });
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      page.on('response', (response) => {
        if (response.status() >= 400) errors.push(response.status() + ' ' + response.url());
      });
      await page.goto(base, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      await page.locator('#region-size').fill('8');
      await page.locator('#world-seed').fill('731');
      await page.locator('#create-world').click();
      await page.waitForFunction(() => !phanesEditor.worker && phanesEditor.world);
      const world = await page.evaluate(() => {
        const w = structuredClone(phanesEditor.world);
        w.layers = w.layers.map((layer, i) => layer.map(() => (i === 0 ? 'meadow' : 'empty')));
        for (const [index, kind, asset] of [
          [27, 'cabin', 'cabin'],
          [28, 'scifi', 'rocket'],
          [36, 'modern', 'city-kit-suburban/building-type-a'],
        ]) {
          w.layers[1][index] = kind;
          w.layers[3][index] = asset;
        }
        return w;
      });
      await page.locator('#world-file').setInputFiles({
        name: 'phanes-structures.json',
        mimeType: 'application/json',
        buffer: Buffer.from(JSON.stringify({ version: 2, world })),
      });
      await page.waitForFunction(
        () => !phanesEditor.worker && phanesEditor.world?.layers[3][28] === 'rocket',
      );
      await page.waitForFunction(
        () => Number(document.body.dataset.renderedRevision) === phanesSceneVersion,
        null,
        { timeout: 120000 },
      );
      const bounds = await page.evaluate(() => JSON.parse(phanesAssetBounds));
      for (const asset of ['cabin', 'rocket', 'city-kit-suburban/building-type-a']) {
        const box = bounds[asset];
        assert.ok(box, asset + ' has actual Castle instance bounds');
        assert.ok(Math.abs(box.min[0] + box.max[0]) < 0.001, asset + ' centered X');
        assert.ok(Math.abs(box.min[2] + box.max[2]) < 0.001, asset + ' centered Z');
        assert.ok(Math.abs(box.min[1]) < 0.001, asset + ' starts on its support plane');
      }
      assert.ok(Math.abs(bounds.rocket.size[0] - 7.2) < 0.001);
      assert.ok(Math.abs(bounds.rocket.size[1] - 11.6) < 0.001);
      assert.ok(Math.abs(bounds.rocket.size[2] - 7.2) < 0.001);
      assert.ok(
        Math.abs(
          Math.max(
            bounds['city-kit-suburban/building-type-a'].size[0],
            bounds['city-kit-suburban/building-type-a'].size[2],
          ) - 12,
        ) < 0.001,
      );
      assert.ok(bounds.cabin.size[0] > 10.6 && bounds.cabin.size[0] < 10.7);
      assert.ok(bounds.cabin.size[1] > 4.6 && bounds.cabin.size[1] < 4.7);
      assert.ok(Math.abs(bounds.cabin.doorSize[0] - 1.155) < 0.001);
      assert.ok(Math.abs(bounds.cabin.doorSize[1] - 2.175) < 0.001);
      await page.evaluate(() => {
        Object.assign(phanesEditor, {
          panX: 0,
          panY: 5,
          panZ: 0,
          zoom: 3.2,
          yaw: 0.6,
          pitch: 0.15,
        });
        phanesEditorActions.setCamera('orbit');
      });
      await page.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await page.screenshot({
        path: path.join(root, 'build', 'structures-world-' + viewport.width + '.png'),
      });
      await page.evaluate(() => {
        Object.assign(phanesEditor, { x: -1.2, y: 6, z: -8, yaw: -Math.PI / 2, pitch: -0.26 });
        phanesEditorActions.setCamera('walk');
      });
      await page.waitForFunction(
        () =>
          phanesRenderedCameraVersion === phanesCameraVersion &&
          window.phanesPlayerState?.eyeHeight > 1.67 &&
          window.phanesPlayerState?.eyeHeight < 1.69,
      );
      const player = await page.evaluate(() => window.phanesPlayerState);
      const fov = await page.evaluate(() => [
        phanesRenderedHorizontalFov,
        phanesRenderedVerticalFov,
      ]);
      assert.ok(
        Math.abs(Math.min(...fov) - (70 * Math.PI) / 180) < 0.0001,
        'Actual horizontal/vertical FOV: ' + JSON.stringify(fov),
      );
      assert.ok(Math.abs(bounds.cabin.doorClearance[0] - 1.2) < 0.001);
      assert.ok(Math.abs(bounds.cabin.doorClearance[1] - 2.2) < 0.001);
      await page.screenshot({
        path: path.join(root, 'build', 'structures-door-' + viewport.width + '.png'),
      });
      assert.deepEqual(errors, []);
      evidence.viewports.push({ viewport, bounds, player, fov, errors });
      await page.close();
    }
    fs.writeFileSync(
      path.join(root, 'build', 'structures-browser-evidence.json'),
      JSON.stringify(evidence, null, 2),
    );
    console.log(JSON.stringify(evidence, null, 2));
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
