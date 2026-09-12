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
  const base = process.env.TEST_URL || 'http://127.0.0.1:4196/';
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
      const turn = viewport.width < 500 ? 1 : 0;
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      page.on('response', (response) => {
        if (response.status() >= 400) errors.push(response.status() + ' ' + response.url());
      });
      const settle = async () => {
        await page.waitForFunction(() => !phanesEditor.worker);
        await page.waitForFunction(
          () =>
            Number(document.body.dataset.renderedRevision) === phanesSceneVersion &&
            phanesPendingChunks === 0 &&
            phanesRenderedCameraVersion === phanesCameraVersion,
          null,
          { timeout: 120000 },
        );
      };
      const snapshot = () => page.evaluate(() => structuredClone(phanesEditor.world));
      const shot = (name) =>
        page.screenshot({
          path: path.join(root, 'build', 'groundworks-' + name + '-' + viewport.width + '.png'),
        });
      await page.goto(base, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      await page.locator('#region-size').fill('8');
      await page.locator('#create-world').click();
      await page.waitForFunction(() => !phanesEditor.worker && phanesEditor.world);
      const empty = await page.evaluate(() => {
        const world = structuredClone(phanesEditor.world);
        world.layers = world.layers.map((layer, i) =>
          layer.map(() => (i === 0 ? 'meadow' : 'empty')),
        );
        return world;
      });
      await page.locator('#world-file').setInputFiles({
        name: 'phanes-groundworks.json',
        mimeType: 'application/json',
        buffer: Buffer.from(JSON.stringify({ version: 2, world: empty })),
      });
      await settle();
      await page.locator('#open-groundworks').click();
      assert.equal(await page.locator('#groundwork-tools').isVisible(), true);
      assert.deepEqual(await page.evaluate(() => phanesEditor.selection), {
        x: 3,
        z: 3,
        width: 2,
        depth: 2,
      });
      if (viewport.width < 500) {
        const bounds = await page.locator('#groundwork-tools').boundingBox();
        assert.ok(bounds.width >= viewport.width - 40, 'Groundwork tools use the full phone width');
      }
      await page.locator('[data-groundwork-turn="' + turn + '"]').click();
      await page.locator('#groundwork-piers').click();
      assert.equal(await page.locator('#groundwork-piers').getAttribute('aria-pressed'), 'true');
      await shot('preview');
      const before = await snapshot();
      await page.locator('#groundwork-launch-pad').click();
      await page.waitForFunction(
        () => !phanesEditor.worker && phanesEditor.world.composition.nodes.length === 19,
      );
      await settle();
      const created = await snapshot();
      assert.equal(created.composition.revision, before.composition.revision + 1);
      assert.deepEqual(created.layers, before.layers);
      assert.equal(
        created.composition.nodes.find((n) => n.role === 'substructure').asset,
        'phanes.groundworks.piers16.v1',
      );
      assert.equal(await page.locator('#groundwork-title').textContent(), 'Launch pad');
      await page.locator('#groundwork-frame').click();
      await settle();
      await shot('orbit');
      await page.locator('[data-groundwork-part="site-3-3.deck.core"]').click();
      assert.equal(await page.locator('#groundwork-reimagine').isDisabled(), true);
      await page.locator('[data-groundwork-part="site-3-3.deck.panel-1"]').click();
      assert.equal(await page.locator('#groundwork-reimagine').isDisabled(), false);
      await page.locator('#groundwork-reimagine').click();
      await settle();
      const edited = await snapshot();
      const selected = 'site-3-3.deck.panel-1';
      assert.notEqual(
        edited.composition.nodes.find((n) => n.id === selected).asset,
        created.composition.nodes.find((n) => n.id === selected).asset,
      );
      for (const node of created.composition.nodes.filter((n) => n.id !== selected)) {
        assert.deepEqual(
          edited.composition.nodes.find((n) => n.id === node.id),
          node,
        );
      }
      assert.deepEqual(edited.layers, created.layers);
      await shot('panel');
      await page.locator('#groundwork-undo').click();
      await settle();
      assert.deepEqual(await snapshot(), created);
      await page.locator('#groundwork-plinth').click();
      await settle();
      const plinth = await snapshot();
      assert.equal(
        plinth.composition.nodes.find((n) => n.role === 'substructure').asset,
        'phanes.groundworks.plinth16.v1',
      );
      for (const node of created.composition.nodes.filter((n) => n.role !== 'substructure')) {
        assert.deepEqual(
          plinth.composition.nodes.find((n) => n.id === node.id),
          node,
        );
      }
      await page.locator('#groundwork-walk').click();
      await settle();
      const start = await page.evaluate(() => phanesPlayerState);
      assert.ok(Math.abs(start.eyeHeight - 1.68) < 0.001);
      assert.ok(Math.abs(start.x - (turn === 1 ? 16 : 0)) < 0.001);
      assert.ok(Math.abs(start.z - (turn === 0 ? 16 : 0)) < 0.001);
      await shot('approach');
      const touch = viewport.width < 500 ? await page.context().newCDPSession(page) : null;
      if (viewport.width < 500) {
        const box = await page.locator('[data-move="w"]').boundingBox();
        await touch.send('Input.dispatchTouchEvent', {
          type: 'touchStart',
          touchPoints: [{ x: box.x + box.width / 2, y: box.y + box.height / 2 }],
        });
      } else {
        await page.keyboard.down('w');
      }
      try {
        await page.waitForFunction(
          (direction) => (direction === 1 ? phanesPlayerState.x < 7.5 : phanesPlayerState.z < 7.5),
          turn,
          { timeout: 15000 },
        );
      } finally {
        if (viewport.width < 500) {
          await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        } else {
          await page.keyboard.up('w');
        }
      }
      const arrived = await page.evaluate(() => phanesPlayerState);
      const deck = plinth.composition.nodes.find((n) => n.role === 'support-deck');
      assert.ok(Math.abs(arrived.ground - deck.y / 1000) < 0.001);
      await shot('deck');
      assert.equal(
        await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
        true,
      );
      await page.locator('#leave-groundworks').click();
      assert.equal(await page.locator('#groundwork-tools').isVisible(), false);
      assert.deepEqual(errors, []);
      evidence.viewports.push({
        viewport,
        start,
        arrived,
        revisions: [before, created, edited, plinth].map((w) => w.composition.revision),
        errors,
      });
      await page.close();
    }
    fs.writeFileSync(
      path.join(root, 'build/groundworks-view-evidence.json'),
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
