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
const assert = require('node:assert/strict');

(async () => {
  const root = path.resolve(__dirname, '..');
  const base = process.env.TEST_URL || 'http://127.0.0.1:4186/';
  const dependencyScript = fs.readFileSync(path.join(root, 'build/phanes.tests.js'), 'utf8');
  const audioScript = fs.readFileSync(path.join(root, 'build/phanes.tests.audio.js'), 'utf8');
  const catalogSummary = JSON.parse(
    fs.readFileSync(path.join(root, 'data/catalog-summary.json'), 'utf8'),
  );
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.BROWSER,
    args: ['--enable-unsafe-swiftshader'],
  });
  const evidence = [];
  let dependencyCheck = 'not run';
  let audioProtocol = null;
  const prefix = new URL(base).pathname === '/' ? 'root' : 'project';

  try {
    const dependencyPage = await browser.newPage();
    await dependencyPage.evaluate((source) => {
      (0, eval)(source);
      rtl.run();
    }, dependencyScript);
    dependencyCheck = 'passed';
    await dependencyPage.close();

    const audioPage = await browser.newPage();
    await audioPage.goto(base, { waitUntil: 'domcontentloaded' });
    await audioPage.evaluate(
      ({ source, base }) => {
        window.phanesTestBase = base;
        (0, eval)(`(() => { ${source}\nrtl.run(); })();`);
      },
      { source: audioScript, base },
    );
    await audioPage.waitForFunction(() => window.phanesAudioTests?.completed, null, {
      timeout: 130000,
    });
    audioProtocol = await audioPage.evaluate(() => window.phanesAudioTests);
    assert.equal(audioProtocol.passed, true, audioProtocol.message);
    await audioPage.close();

    for (const viewport of [
      { width: 1280, height: 800 },
      { width: 390, height: 844 },
    ]) {
      const page = await browser.newPage({ viewport, hasTouch: viewport.width < 500 });
      const failures = [];
      const inventoryRequests = [];
      const summaryUnavailable = viewport.width < 500;
      if (summaryUnavailable) {
        await page.route('**/data/catalog-summary.json', (route) =>
          route.fulfill({ status: 503, contentType: 'application/json', body: '{}' }),
        );
      }
      page.on('request', (request) => {
        if (new URL(request.url()).pathname.endsWith('/data/asset-inventory.json')) {
          inventoryRequests.push(request.url());
        }
      });
      page.on('pageerror', (error) => failures.push(error.message));
      page.on('response', (response) => {
        if (
          summaryUnavailable &&
          response.url().endsWith('/data/catalog-summary.json') &&
          response.status() === 503
        ) {
          return;
        }
        if (response.status() >= 400) {
          failures.push(`${response.status()} ${response.url()}`);
        }
      });
      page.on('requestfailed', (request) => failures.push(`Request failed: ${request.url()}`));
      await page.goto(base, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      assert.equal(await page.title(), 'Phanes · World creator');
      await page.waitForFunction(
        ({ unavailable, count, regionalCount }) => {
          const label = document.getElementById('kit-count').textContent;
          return unavailable
            ? label === `${regionalCount} regional choices`
            : label.startsWith(`${count} source pieces`);
        },
        {
          unavailable: summaryUnavailable,
          count: catalogSummary.importedModels,
          regionalCount: catalogSummary.regionalChoices,
        },
      );
      assert.deepEqual(inventoryRequests, [], 'Startup must not fetch the full source inventory');
      await page.locator('#create-world').click();
      await page.waitForFunction(() => document.body.dataset.renderedRevision === '1', null, {
        timeout: 120000,
      });
      const canvas = await page.locator('#castle-canvas').boundingBox();
      const shell = await page.locator('#viewport-shell').boundingBox();
      assert.equal(canvas.width, shell.width);
      assert.equal(canvas.height, shell.height);
      assert.ok(canvas.width > 200 && canvas.height > 200);
      const baseline = await page.evaluate(() => phanesEditor.world.layers);
      await page.locator('[data-intent="castle"]').click();
      await page.waitForFunction(() => document.body.dataset.renderedRevision === '2', null, {
        timeout: 120000,
      });
      const edited = await page.evaluate(() => phanesEditor.world.layers);
      assert.notDeepEqual(edited, baseline);
      if (viewport.width > 500) {
        await page.locator('#undo').click();
        await page.waitForFunction(() => document.body.dataset.renderedRevision === '3');
        assert.deepEqual(await page.evaluate(() => phanesEditor.world.layers), baseline);
        await page.locator('#redo').click();
        await page.waitForFunction(() => document.body.dataset.renderedRevision === '4');
        assert.deepEqual(await page.evaluate(() => phanesEditor.world.layers), edited);
        await page.mouse.move(canvas.x + canvas.width * 0.42, canvas.y + canvas.height * 0.4);
        await page.mouse.down();
        await page.waitForTimeout(80);
        await page.mouse.move(canvas.x + canvas.width * 0.6, canvas.y + canvas.height * 0.57, {
          steps: 8,
        });
        await page.mouse.up();
        await page.waitForTimeout(150);
        const selection = await page.evaluate(() => phanesEditor.selection);
        assert.ok(
          selection.width > 1 && selection.depth > 1,
          'Dragging creates a region selection through CGE picking',
        );
      }
      await page.locator('[data-camera="orbit"]').click();
      await page.waitForTimeout(400);
      assert.deepEqual(failures, []);
      if (viewport.width < 500) {
        await page.locator('#reimagine').scrollIntoViewIfNeeded();
        for (const id of ['select-all', 'open-groundworks', 'open-interior', 'reimagine']) {
          const action = await page.locator('#' + id).boundingBox();
          assert.ok(
            action.x >= 0 && action.x + action.width <= viewport.width,
            id + ' remains within the phone width',
          );
        }
      }
      await page.screenshot({ path: path.join(root, `build/${prefix}-${viewport.width}.png`) });
      for (const mode of ['fly', 'walk', 'top']) {
        await page.locator(`[data-camera="${mode}"]`).click();
        assert.equal(await page.evaluate(() => phanesEditor.camera), mode);
      }
      await page.locator('#edit-toggle').click();
      assert.equal(await page.evaluate(() => phanesEditor.editing), false);
      await page.locator('#edit-toggle').click();
      assert.equal(await page.evaluate(() => phanesEditor.editing), true);
      evidence.push({
        base,
        viewport,
        ready: true,
        worldCreation: true,
        castleBrush: true,
        cameraModes: true,
        eagerInventoryRequests: inventoryRequests.length,
        summaryUnavailable,
        failures,
      });
      await page.close();
    }
  } finally {
    await browser.close();
    fs.writeFileSync(
      path.join(root, `build/${prefix}-evidence.json`),
      JSON.stringify({ dependencyCheck, audioProtocol, views: evidence }, null, 2) + '\n',
    );
  }
  console.log('WFC dependency and Castle desktop/phone startup checks passed.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
