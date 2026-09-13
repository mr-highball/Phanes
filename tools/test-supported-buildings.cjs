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
    args: ['--enable-unsafe-swiftshader', '--js-flags=--stack-trace-limit=80'],
  });
  const evidence = { base, viewports: [] };
  try {
    for (const viewport of [
      { width: 1440, height: 960 },
      { width: 390, height: 844 },
    ]) {
      const page = await browser.newPage({ viewport, hasTouch: viewport.width < 500 });
      page.setDefaultTimeout(30000);
      const errors = [];
      page.on('pageerror', (error) => {
        errors.push(error.message);
        console.error(error.stack);
        page
          .evaluate((message) => (window.phanesTestError = message), error.message)
          .catch(() => {});
      });
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      page.on('response', (response) => {
        if (response.status() >= 400) errors.push(response.status() + ' ' + response.url());
      });
      const settle = async () => {
        console.log('Settling worker and renderer');
        await page.waitForFunction(() => !phanesEditor.worker);
        await page.waitForFunction(
          () =>
            window.phanesTestError ||
            (Number(document.body.dataset.renderedRevision) === phanesSceneVersion &&
              phanesPendingChunks === 0 &&
              phanesRenderedCameraVersion === phanesCameraVersion),
          null,
          { timeout: 120000 },
        );
        assert.deepEqual(errors, []);
      };
      const changed = async (action) => {
        const priorRevision = await page.evaluate(() => phanesSceneVersion);
        await action();
        await page.waitForFunction(
          (prior) => !phanesEditor.worker && phanesSceneVersion > prior,
          priorRevision,
        );
        await settle();
      };
      const snapshot = () => page.evaluate(() => structuredClone(phanesEditor.world));
      const shot = (name) =>
        page.screenshot({
          path: path.join(root, 'build', 'supported-' + name + '-' + viewport.width + '.png'),
        });
      const click = async (selector) => {
        console.log(viewport.width + ': ' + selector);
        const target = page.locator(selector);
        if (viewport.width < 500) await target.tap();
        else await target.click();
      };
      console.log(viewport.width + ': opening ' + base);
      await page.goto(base, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      await page.locator('#region-size').fill('8');
      await click('#create-world');
      await page.waitForFunction(() => !phanesEditor.worker && phanesEditor.world);
      const empty = await page.evaluate(() => {
        const world = structuredClone(phanesEditor.world);
        world.layers = world.layers.map((layer, i) =>
          layer.map(() => (i === 0 ? 'meadow' : 'empty')),
        );
        return world;
      });
      await changed(() =>
        page.locator('#world-file').setInputFiles({
          name: 'phanes-supported-buildings.json',
          mimeType: 'application/json',
          buffer: Buffer.from(JSON.stringify({
            version: empty.formatVersion === 3 ? 3 : 2,
            world: empty,
          })),
        }),
      );
      await click('#open-groundworks');
      const turn = viewport.width < 500 ? 1 : 0;
      await click('[data-groundwork-turn="' + turn + '"]');
      await click('#groundwork-foundation');
      await settle();
      const plot = await snapshot();
      const buildingId = 'site-3-3.deck.building';
      const profiles = [
        'rocket',
        'keep',
        'city-kit-suburban/building-type-a',
        'city-kit-suburban/building-type-f',
        'space-kit/hangar_roundA',
        'space-kit/hangar_smallA',
        'cabin',
      ];
      const placements = [];
      for (const asset of profiles) {
        await click('[data-building-asset="' + asset + '"]');
        await settle();
        const world = await snapshot();
        const building = world.composition.nodes.find((n) => n.id === buildingId);
        assert.equal(building.asset, asset);
        assert.equal(building.parent, 'site-3-3.deck');
        assert.equal(building.support, building.parent);
        assert.deepEqual(
          [building.x, building.y, building.z, building.quarterTurn],
          [0, 0, 0, turn],
        );
        assert.deepEqual(world.layers, plot.layers);
        for (const node of plot.composition.nodes) {
          assert.deepEqual(
            world.composition.nodes.find((n) => n.id === node.id),
            node,
          );
        }
        assert.equal(
          await page.locator('[data-building-asset="' + asset + '"]').getAttribute('aria-pressed'),
          'true',
        );
        await click('#groundwork-frame');
        await settle();
        if (['rocket', 'keep', 'cabin'].includes(asset)) await shot(asset);
        if (asset === 'keep') {
          await click('#groundwork-walk');
          await settle();
          const touch = viewport.width < 500 ? await page.context().newCDPSession(page) : null;
          const circuit = [];
          for (const segment of [
            { key: 'w', axis: 'v', limit: 7.5, greater: false },
            { key: 'd', axis: 'u', limit: 7.42, greater: true },
            { key: 'w', axis: 'v', limit: -7.42, greater: false },
            { key: 'a', axis: 'u', limit: -7.42, greater: false },
            { key: 's', axis: 'v', limit: 7.42, greater: true },
            { key: 'd', axis: 'u', limit: 0, greater: true },
          ]) {
            if (touch) {
              const box = await page.locator('[data-move="' + segment.key + '"]').boundingBox();
              await touch.send('Input.dispatchTouchEvent', {
                type: 'touchStart',
                touchPoints: [{ x: box.x + box.width / 2, y: box.y + box.height / 2 }],
              });
            } else {
              await page.keyboard.down(segment.key);
            }
            try {
              await page.waitForFunction(
                ({ turn, segment }) => {
                  const u = turn === 1 ? -phanesPlayerState.z : phanesPlayerState.x;
                  const v = turn === 1 ? phanesPlayerState.x : phanesPlayerState.z;
                  const value = segment.axis === 'u' ? u : v;
                  return segment.greater ? value >= segment.limit : value <= segment.limit;
                },
                { turn, segment },
                { timeout: 30000 },
              );
            } finally {
              if (touch)
                await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
              else await page.keyboard.up(segment.key);
            }
            const position = await page.evaluate(() => structuredClone(phanesPlayerState));
            assert.ok(Math.abs(position.eyeHeight - 1.68) < 0.001);
            circuit.push(position);
          }
          await shot('keep-walk');
          evidence.viewports.push({ viewport, keepCircuit: circuit });
        }
        placements.push({ asset, revision: world.composition.revision });
      }
      const exteriorCamera = await page.evaluate(() => {
        const result = {};
        for (const key of ['camera', 'zoom', 'yaw', 'pitch', 'panX', 'panY', 'panZ'])
          result[key] = phanesEditor[key];
        return result;
      });
      await click('#groundwork-inside');
      await page.waitForFunction(
        () => phanesEditor.interiorRoom.endsWith('.studio') && !phanesEditor.worker,
      );
      await page.waitForFunction(
        () => document.body.dataset.renderedInterior === phanesEditor.interiorRoom,
      );
      assert.equal(await page.locator('#interior-tools').isVisible(), true);
      assert.equal(await page.locator('#groundwork-tools').isVisible(), false);
      const furnished = await snapshot();
      const bookcase = furnished.composition.nodes.find((n) => n.role === 'bookcase');
      assert.equal(
        furnished.composition.nodes.filter(
          (n) => n.parent === bookcase.id + '.tier-4' && n.role === 'book',
        ).length,
        3,
      );
      const snail = furnished.composition.nodes.find(
        (n) => n.parent === bookcase.id + '.tier-2' && n.role === 'ornament',
      );
      assert.ok(snail);
      await page.locator('[data-node="' + bookcase.id + '"]').click();
      await page.locator('[data-node="' + bookcase.id + '.tier-2"]').click();
      await page.locator('[data-node="' + snail.id + '"]').click();
      await click('#interior-frame');
      await page.waitForFunction(
        () =>
          phanesRenderedCameraVersion === phanesCameraVersion &&
          Number(document.body.dataset.renderedInteriorVersion) === phanesInteriorVersion,
      );
      const bounds = await page.locator('#castle-canvas').boundingBox();
      await click('#interior-parent');
      if (viewport.width < 500)
        await page.touchscreen.tap(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
      else await page.mouse.click(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
      await page.waitForFunction((id) => phanesEditor.interiorSelected === id, snail.id);
      await shot('shelf');
      await changed(() => click('#interior-reimagine'));
      const edited = await snapshot();
      assert.notEqual(edited.composition.nodes.find((n) => n.id === snail.id).asset, snail.asset);
      for (const node of furnished.composition.nodes.filter((n) => n.id !== snail.id)) {
        assert.deepEqual(
          edited.composition.nodes.find((n) => n.id === node.id),
          node,
        );
      }
      await click('#leave-interior');
      await settle();
      assert.equal(await page.locator('#groundwork-tools').isVisible(), true);
      assert.deepEqual(
        await page.evaluate(() => {
          const result = {};
          for (const key of ['camera', 'zoom', 'yaw', 'pitch', 'panX', 'panY', 'panZ'])
            result[key] = phanesEditor[key];
          return result;
        }),
        exteriorCamera,
      );
      assert.equal(await page.locator('[data-building-asset="keep"]').isDisabled(), true);
      await click('#groundwork-piers');
      await settle();
      const supported = await snapshot();
      for (const node of edited.composition.nodes.filter((n) => n.id.startsWith(buildingId))) {
        assert.deepEqual(
          supported.composition.nodes.find((n) => n.id === node.id),
          node,
        );
      }
      await click('[data-groundwork-part="site-3-3.deck.panel-1"]');
      await click('#groundwork-reimagine');
      await settle();
      const panel = await snapshot();
      for (const node of supported.composition.nodes.filter((n) => n.id.startsWith(buildingId))) {
        assert.deepEqual(
          panel.composition.nodes.find((n) => n.id === node.id),
          node,
        );
      }
      await click('#groundwork-remove-building');
      await settle();
      assert.equal(
        (await snapshot()).composition.nodes.some((n) => n.id.startsWith(buildingId)),
        false,
      );
      await changed(() => click('#groundwork-undo'));
      assert.deepEqual(await snapshot(), panel);
      await changed(() =>
        page.locator('#world-file').setInputFiles({
          name: 'phanes-furnished-foundation.json',
          mimeType: 'application/json',
          buffer: Buffer.from(JSON.stringify({
            version: panel.formatVersion === 3 ? 3 : 2,
            world: panel,
          })),
        }),
      );
      assert.deepEqual((await snapshot()).composition, panel.composition);
      assert.deepEqual((await snapshot()).layers, panel.layers);
      await click('#groundwork-inside');
      await page.waitForFunction(
        () => document.body.dataset.renderedInterior === phanesEditor.interiorRoom,
      );
      await click('#leave-interior');
      await settle();
      assert.equal(
        await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
        true,
      );
      assert.deepEqual(errors, []);
      evidence.viewports.push({ viewport, placements, buildingId, snailId: snail.id, errors });
      await page.close();
    }
    fs.writeFileSync(
      path.join(root, 'build/supported-buildings-evidence.json'),
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
