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
  const evidence = { base, viewports: [] };
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.BROWSER,
    args: ['--enable-unsafe-swiftshader'],
  });
  try {
    for (const viewport of [
      { width: 1440, height: 960 },
      { width: 390, height: 844 },
    ]) {
      console.log('Room journeys: ' + viewport.width + ' at ' + base);
      const page = await browser.newPage({ viewport, hasTouch: viewport.width < 500 });
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      page.on('console', (message) => {
        if (message.type() === 'error') {
          errors.push(message.text());
        }
      });
      page.on('response', (response) => {
        if (response.status() >= 400) {
          errors.push(response.status() + ' ' + response.url());
        }
      });
      await page.goto(base);
      await page.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      const waitChange = async (action) => {
        const version = await page.evaluate(() => phanesSceneVersion);
        await action();
        await page.waitForFunction(
          (prior) => !phanesEditor.worker && phanesSceneVersion > prior,
          version,
          { timeout: 60000 },
        );
        assert.equal(await page.evaluate(() => document.body.dataset.lastSolve), 'passed');
      };
      const click = async (selector) => {
        console.log(viewport.width + ': ' + selector);
        if (viewport.width < 500) {
          await page.locator(selector).tap();
        } else {
          await page.locator(selector).click();
        }
      };
      const changed = (selector) => waitChange(() => click(selector));
      const composition = () =>
        page.evaluate(() => structuredClone(phanesEditor.world.composition));
      const render = () =>
        page.waitForFunction(
          () =>
            document.body.dataset.renderedInterior === phanesEditor.interiorRoom &&
            Number(document.body.dataset.renderedInteriorScene) === phanesSceneVersion &&
            phanesRenderedCameraVersion === phanesCameraVersion,
          null,
          { timeout: 60000 },
        );
      const child = (id) => click('#interior-children button[data-node="' + id + '"]');
      const importWorld = (world) =>
        waitChange(() =>
          page.locator('#world-file').setInputFiles({
            name: 'phanes-rooms.json',
            mimeType: 'application/json',
            buffer: Buffer.from(JSON.stringify({ version: 2, world })),
          }),
        );
      // A generated regional cabin is the fixture. Room actions below use the
      // visible controls, actual worker, and rendered Castle application.
      const fixture = await page.evaluate(async () => {
        const assets = phanesEditor.palette.assets;
        const solve = (operation, previous) =>
          new Promise((resolve, reject) => {
            const worker = new Worker('world-worker.js');
            const timer = setTimeout(() => {
              worker.terminate();
              reject(Error('Fixture timeout'));
            }, 30000);
            worker.onmessage = ({ data }) => {
              clearTimeout(timer);
              worker.terminate();
              if (data.success) {
                resolve(data.world);
              } else {
                reject(Error(data.message));
              }
            };
            worker.onerror = (event) => {
              clearTimeout(timer);
              worker.terminate();
              reject(Error(event.message));
            };
            worker.postMessage({
              job: 1,
              operation,
              previous,
              assets,
              size: 4,
              seed: 732,
              x: operation === 'create' ? 0 : 1,
              z: operation === 'create' ? 0 : 1,
              width: operation === 'create' ? 4 : 1,
              depth: operation === 'create' ? 4 : 1,
            });
          });
        return solve('cabin', await solve('create', null));
      });
      await importWorld(fixture);
      await page.evaluate(() => {
        phanesEditor.selection = { x: 1, z: 1, width: 1, depth: 1 };
        phanesEditorActions.setCamera('top');
      });
      await click('#design-rooms');
      assert.equal(await page.locator('#space-layout-dialog').evaluate((e) => e.open), true);
      const modalBaseline = await composition();
      await page.keyboard.press('4');
      assert.equal(await page.evaluate(() => phanesEditor.camera), 'top');
      await page.screenshot({
        path: path.join(root, 'build/rooms-layout-' + viewport.width + '.png'),
      });
      await page.keyboard.press('Escape');
      assert.deepEqual(await composition(), modalBaseline);
      await click('#design-rooms');
      await changed('#space-layout-six');
      await render();
      const plan = 'building-1-1.plan';
      const bay = plan + '.bay-5';
      const room = bay + '.room';
      assert.equal((await composition()).nodes.filter((n) => n.role === 'bay').length, 6);
      await child(bay);
      await click('#interior-space-name-tools summary');
      await page.locator('#interior-space-name').fill('Bay 5 · Discovery');
      await waitChange(() => page.locator('#interior-space-name').press('Enter'));
      assert.equal(await page.locator('#interior-title').textContent(), 'Bay 5 · Discovery');
      await changed('#space-program-lab');
      await render();
      let state = await composition();
      assert.equal(await page.evaluate(() => phanesEditor.interiorSelected), room);
      assert.equal(state.nodes.find((n) => n.id === room).asset, 'phanes.space.laboratory.v1');
      const shelf = state.nodes.find((n) => n.parent === room && n.role === 'bookcase');
      const bench = state.nodes.find((n) => n.parent === room && n.role === 'bench');
      assert.ok(shelf);
      assert.ok(bench);
      await page.screenshot({
        path: path.join(root, 'build/rooms-lab-' + viewport.width + '.png'),
      });
      await child(shelf.id);
      await child(shelf.id + '.tier-4');
      assert.equal(await page.locator('#interior-children button').count(), 3);
      await click('#interior-frame');
      await render();
      await page.screenshot({
        path: path.join(root, 'build/rooms-shelf-' + viewport.width + '.png'),
      });
      await page.locator('#interior-count').fill('4');
      await changed('#apply-content-count');
      assert.equal(await page.locator('#interior-children button').count(), 4);
      await click('#interior-parent');
      await child(shelf.id + '.tier-2');
      assert.equal(await page.locator('#interior-children button').count(), 1);
      await click('#interior-children button');
      const snailId = await page.evaluate(() => phanesEditor.interiorSelected);
      const beforeSnail = await composition();
      await changed('#interior-looks button[data-asset="phanes.book.indigo.v1"]');
      const afterSnail = await composition();
      assert.equal(afterSnail.nodes.find((n) => n.id === snailId).asset, 'phanes.book.indigo.v1');
      assert.deepEqual(
        afterSnail.nodes.filter((n) => n.id !== snailId),
        beforeSnail.nodes.filter((n) => n.id !== snailId),
      );
      await click('#interior-undo');
      assert.deepEqual(await composition(), beforeSnail);
      await click('#interior-redo');
      assert.deepEqual(await composition(), afterSnail);
      await click('#interior-path button[data-node="' + room + '"]');
      await child(bench.id);
      await child(bench.id + '.top');
      await page.locator('#interior-count').fill('6');
      await changed('#apply-content-count');
      assert.equal(await page.locator('#interior-children button').count(), 6);
      const labBefore = (await composition()).nodes.filter(
        (n) => n.id === bay || n.id.startsWith(bay + '.'),
      );
      await click('#interior-path button[data-node="' + plan + '"]');
      await child(plan + '.bay-6');
      await changed('#space-program-bath');
      await render();
      state = await composition();
      assert.deepEqual(
        state.nodes.filter((n) => n.id === bay || n.id.startsWith(bay + '.')),
        labBefore,
      );
      assert.deepEqual(
        state.nodes
          .filter((n) => n.parent === plan + '.bay-6.room')
          .map((n) => n.role)
          .sort(),
        ['shower', 'sink', 'toilet'],
      );
      await click('#interior-path button[data-node="' + plan + '"]');
      await click('#interior-frame');
      await render();
      await page.screenshot({
        path: path.join(root, 'build/rooms-plan-' + viewport.width + '.png'),
      });
      assert.equal(
        await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
        true,
      );
      const savedComposition = await composition();
      const [download] = await Promise.all([
        page.waitForEvent('download'),
        click(viewport.width < 500 ? '#interior-export' : '#save-world'),
      ]);
      const saved = JSON.parse(fs.readFileSync(await download.path(), 'utf8'));
      assert.deepEqual(saved.world.composition, savedComposition);
      await importWorld(saved.world);
      assert.deepEqual(await composition(), savedComposition);
      await click('#interior-space-name-tools summary');
      await page.locator('#interior-space-name').fill('   ');
      const beforeRejectedName = await page.evaluate(() => ({
        scene: phanesSceneVersion,
        history: phanesEditor.history.length,
      }));
      await click('#interior-space-rename');
      await page.waitForFunction(() => !phanesEditor.worker);
      assert.equal(await page.evaluate(() => document.body.dataset.lastSolve), 'failed');
      assert.deepEqual(await composition(), savedComposition);
      assert.deepEqual(
        await page.evaluate(() => ({
          scene: phanesSceneVersion,
          history: phanesEditor.history.length,
        })),
        beforeRejectedName,
      );
      await child(bay);
      const cancelled = await page.evaluate(() => {
        const before = { scene: phanesSceneVersion, history: phanesEditor.history.length };
        document.querySelector('#interior-reimagine').click();
        const started = !!phanesEditor.worker;
        document.querySelector('#cancel').click();
        return { before, started, stopped: !phanesEditor.worker };
      });
      assert.equal(cancelled.started, true);
      assert.equal(cancelled.stopped, true);
      await page.waitForTimeout(250);
      assert.deepEqual(await composition(), savedComposition);
      assert.deepEqual(
        await page.evaluate(() => ({
          scene: phanesSceneVersion,
          history: phanesEditor.history.length,
        })),
        cancelled.before,
      );
      await click('#interior-path button[data-node="' + plan + '"]');
      // Protected descendants block destructive room/layout replacement while
      // preserving navigation and ordinary room reimagination.
      const locked = structuredClone(saved.world);
      locked.composition.nodes.find((n) => n.id === snailId).locked = true;
      await importWorld(locked);
      await child(bay);
      assert.equal(await page.locator('#space-program-bath').isDisabled(), true);
      assert.equal(await page.locator('#interior-reimagine').isEnabled(), true);
      await click('#interior-path button[data-node="' + plan + '"]');
      await click('#interior-layout');
      assert.equal(await page.locator('[data-plan-profile]:enabled').count(), 0);
      await click('#space-layout-cancel');
      await importWorld(saved.world);
      for (const [button, count] of [
        ['four', 4],
        ['two', 2],
      ]) {
        await click('#interior-layout');
        await changed('#space-layout-' + button);
        await render();
        assert.equal((await composition()).nodes.filter((n) => n.role === 'bay').length, count);
      }
      await click('#interior-undo');
      assert.equal((await composition()).nodes.filter((n) => n.role === 'bay').length, 4);
      await click('#leave-interior');
      assert.equal(await page.evaluate(() => phanesEditor.interiorRoom), '');
      assert.equal(await page.evaluate(() => phanesEditor.camera), 'top');
      // Repeat the entry path from a cabin owned by a generated foundation.
      const empty = structuredClone(fixture);
      empty.layers = empty.layers.map((layer, i) =>
        layer.map(() => (i === 0 ? 'meadow' : 'empty')),
      );
      empty.composition.nodes = [empty.composition.nodes.find((n) => n.id === 'world')];
      empty.composition.revision = 0;
      await importWorld(empty);
      await page.evaluate(() => {
        phanesEditor.selection = { x: 1, z: 1, width: 1, depth: 1 };
        phanesEditorActions.setCamera('top');
      });
      await click('#open-groundworks');
      await click('[data-groundwork-turn="' + (viewport.width < 500 ? 1 : 0) + '"]');
      await changed('#groundwork-foundation');
      await changed('[data-building-asset="cabin"]');
      await changed('#groundwork-inside');
      await render();
      const studioBeforePlan = await composition();
      await click('#interior-layout');
      await changed('#space-layout-six');
      await render();
      const supportedPlan = 'site-1-1.deck.building.plan';
      assert.equal(await page.evaluate(() => phanesEditor.interiorRoom), supportedPlan);
      await click('#interior-undo');
      await render();
      assert.equal(
        await page.evaluate(() => phanesEditor.interiorRoom),
        'site-1-1.deck.building.studio',
      );
      assert.deepEqual(await composition(), studioBeforePlan);
      await click('#interior-redo');
      await render();
      assert.equal(await page.evaluate(() => phanesEditor.interiorRoom), supportedPlan);
      await child(supportedPlan + '.bay-5');
      await changed('#space-program-lab');
      await render();
      await click('#leave-interior');
      assert.equal(await page.locator('#groundwork-inside').isVisible(), true);
      assert.deepEqual(errors, []);
      evidence.viewports.push({
        viewport,
        result: 'passed',
        journeys: [
          'layout modal/cancel',
          'six bays',
          'rename',
          'laboratory Bay 5',
          'shelf counts',
          'single snail replacement',
          'undo/redo',
          'six-slot bench',
          'neighbor bathroom preservation',
          'export/restore',
          'rejected name preserves publication/history',
          'room worker cancellation preserves publication/history',
          'locks',
          'four/two bays',
          'return camera',
          'foundation-supported cabin plan and laboratory',
          'studio/plan undo retains cabin context',
        ],
      });
      await page.close();
    }
  } catch (error) {
    evidence.failure = error.stack;
    for (const context of browser.contexts()) {
      for (const page of context.pages()) {
        await page
          .screenshot({ path: path.join(root, 'build/rooms-journey-failure.png') })
          .catch(() => {});
        evidence.state = await page
          .evaluate(() => ({
            selected: window.phanesEditor?.interiorSelected,
            status: document.querySelector('#status')?.textContent,
          }))
          .catch(() => null);
      }
    }
    throw error;
  } finally {
    fs.writeFileSync(
      path.join(root, 'build/rooms-browser-evidence.json'),
      JSON.stringify(evidence, null, 2),
    );
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
