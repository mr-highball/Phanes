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
  const outlineOnly = process.env.TEST_OUTLINE_ONLY === '1';
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.BROWSER,
    args: ['--enable-unsafe-swiftshader'],
  });
  const evidence = { base, outlineOnly, viewports: [] };
  try {
    for (const viewport of [
      { width: 1440, height: 960 },
      { width: 390, height: 844 },
    ]) {
      if (process.env.TEST_VIEWPORT && process.env.TEST_VIEWPORT !== String(viewport.width))
        continue;
      const phone = viewport.width < 500;
      const deviceScaleFactor = phone && process.env.TEST_DPR === '2' ? 2 : 1;
      const page = await browser.newPage({ viewport, hasTouch: phone, deviceScaleFactor });
      const errors = [];
      const picks = [];
      page.on('pageerror', (error) => {
        errors.push(error.stack);
        console.error(error.stack);
      });
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
            phanesRenderedCameraVersion === phanesCameraVersion &&
            phanesRenderedGroundworkVersion === phanesGroundworkSelectionVersion,
          null,
          { timeout: 120000 },
        );
        assert.deepEqual(errors, []);
      };
      const click = async (selector) => {
        if (phone) await page.locator(selector).tap();
        else await page.locator(selector).click();
      };
      const snapshot = () =>
        page.evaluate(() =>
          structuredClone({
            world: phanesEditor.world,
            history: phanesEditor.history,
            future: phanesEditor.future,
          }),
        );
      const selected = () => page.evaluate(() => document.body.dataset.groundworkSelected);
      const shot = (name) =>
        page.screenshot({
          path: path.join(root, 'build', 'groundwork-pick-' + name + '-' + viewport.width + '.png'),
        });
      const aim = async (point, mode = 'top', yaw = 0.65, pitch = 0.08, zoom = 4) => {
        await page.evaluate(
          ({ point, mode, yaw, pitch, zoom }) => {
            Object.assign(phanesEditor, {
              panX: point[0],
              panY: point[1],
              panZ: point[2],
              zoom,
              yaw,
              pitch,
            });
            phanesEditorActions.setCamera(mode);
          },
          { point, mode, yaw, pitch, zoom },
        );
        await settle();
      };
      const screenPoint = (point) =>
        page.evaluate((point) => {
          const camera = JSON.parse(phanesCamera);
          const bounds = document.querySelector('canvas').getBoundingClientRect();
          const sub = (a, b) => a.map((n, i) => n - b[i]);
          const dot = (a, b) => a.reduce((sum, n, i) => sum + n * b[i], 0);
          const cross = (a, b) => [
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
          ];
          const norm = (a) => a.map((n) => n / Math.hypot(...a));
          const forward = norm(sub(camera.target, camera.position));
          const right = norm(cross(forward, camera.up));
          const up = cross(right, forward);
          const relative = sub(point, camera.position);
          const depth = dot(relative, forward);
          const halfY = camera.orthographic
            ? camera.span / 2
            : depth * Math.tan(phanesRenderedVerticalFov / 2);
          const halfX = camera.orthographic
            ? (halfY * bounds.width) / bounds.height
            : depth * Math.tan(phanesRenderedHorizontalFov / 2);
          return {
            x: bounds.x + ((dot(relative, right) / halfX + 1) * bounds.width) / 2,
            y: bounds.y + ((1 - dot(relative, up) / halfY) * bounds.height) / 2,
            left: bounds.x,
            top: bounds.y,
            width: bounds.width,
            height: bounds.height,
          };
        }, point);
      const tapPoint = async (point, expected, label) => {
        const before = await snapshot();
        const screen = await screenPoint(point);
        assert.ok(screen.x > screen.left && screen.x < screen.left + screen.width);
        assert.ok(screen.y > screen.top && screen.y < screen.top + screen.height);
        console.log(viewport.width + ': pick ' + label);
        if (phone) await page.touchscreen.tap(screen.x, screen.y);
        else await page.mouse.click(screen.x, screen.y);
        try {
          await page.waitForFunction(
            (id) =>
              document.body.dataset.groundworkSelected === id &&
              Number(document.body.dataset.groundworkPickedVersion) === phanesPickVersion,
            expected,
            { timeout: 15000 },
          );
          await settle();
          assert.equal(await page.evaluate(() => phanesRenderedGroundworkId), expected);
          assert.deepEqual(await snapshot(), before, 'Selection cannot mutate world or history');
        } catch (error) {
          console.error(
            await page.evaluate(() => ({
              selected: document.body.dataset.groundworkSelected,
              rendered: window.phanesRenderedGroundworkId,
              pick: phanesPickVersion,
              camera: JSON.parse(phanesCamera),
            })),
          );
          await shot('failure');
          throw error;
        }
        picks.push({ label, expected, point, screen });
      };
      const tapAuthoringPoint = async (point) => {
        const screen = await screenPoint(point);
        const priorSelection = await page.evaluate(() => phanesSelectionVersion);
        if (phone) await page.touchscreen.tap(screen.x, screen.y);
        else await page.mouse.click(screen.x, screen.y);
        await page.waitForFunction(
          (prior) => !phanesAuthoringBusy && phanesSelectionVersion > prior,
          priorSelection,
        );
        await settle();
      };
      const drawAuthoringGesture = async (tool, point, offsets) => {
        await click('[data-authoring-tool="' + tool + '"]');
        const screen = await screenPoint(point);
        if (phone) {
          const touch = await page.context().newCDPSession(page);
          await touch.send('Input.dispatchTouchEvent', {
            type: 'touchStart',
            touchPoints: [{ x: screen.x, y: screen.y }],
          });
          for (const [dx, dy] of offsets) {
            await touch.send('Input.dispatchTouchEvent', {
              type: 'touchMove',
              touchPoints: [{ x: screen.x + dx, y: screen.y + dy }],
            });
          }
          await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await touch.detach();
        } else {
          await page.mouse.move(screen.x, screen.y);
          await page.mouse.down();
          for (const [dx, dy] of offsets) {
            await page.mouse.move(screen.x + dx, screen.y + dy, { steps: 3 });
          }
          await page.mouse.up();
        }
        await page.waitForFunction(() => !phanesAuthoringBusy);
        await settle();
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
      await page.locator('#world-file').setInputFiles({
        name: 'phanes-picking.json',
        mimeType: 'application/json',
        buffer: Buffer.from(JSON.stringify({
          version: empty.formatVersion === 3 ? 3 : 2,
          world: empty,
        })),
      });
      await settle();
      await click('#open-groundworks');
      const turn = phone ? 1 : 0;
      await click('[data-groundwork-turn="' + turn + '"]');
      await click('#groundwork-foundation');
      await settle();
      const plotId = 'site-3-3';
      const world = (await snapshot()).world;
      const deck = world.composition.nodes.find((n) => n.id === plotId + '.deck');
      const deckY = deck.y / 1000;
      const localPoint = (u, y, v) => (turn === 0 ? [u, y, v] : [v, y, -u]);
      await aim([0, deckY, 0]);
      for (let i = 0; i < 16; i++) {
        if ([6, 9, 10].includes(i)) continue;
        const core = i === 5;
        const point = core ? [0, deckY, 0] : [(i % 4) * 4 - 6, deckY, Math.floor(i / 4) * 4 - 6];
        const id = plotId + (core ? '.deck.core' : '.deck.panel-' + i);
        await tapPoint(point, id, core ? 'core' : 'north-aligned panel ' + i);
        assert.equal(
          await page.locator('[data-groundwork-part="' + id + '"]').getAttribute('aria-pressed'),
          'true',
        );
      }
      await shot('panel');
      await aim([6, deckY, 6], 'orbit', 0.65, -0.18, 8);
      await shot('panel-orbit');
      await aim([0, deckY, 0]);
      await tapPoint(localPoint(0, deckY - 1, 11), plotId + '.deck.ramp', 'access slope');
      await tapPoint(localPoint(0, deckY - 1, 15), plotId + '.deck.ramp.landing', 'graded landing');
      assert.equal(await page.locator('#groundwork-reimagine').isDisabled(), true);
      await shot('landing');
      await aim(localPoint(0, deckY - 1, 15), 'orbit', (turn * Math.PI) / 2 + 0.65, -0.18, 12);
      await shot('landing-orbit');
      await aim([0, deckY, 0]);
      if (outlineOnly) {
        evidence.viewports.push({ viewport, deviceScaleFactor, turn, picks, errors });
        fs.writeFileSync(
          path.join(root, 'build', 'groundwork-outline-evidence.json'),
          JSON.stringify(evidence, null, 2) + '\n',
        );
        await page.close();
        continue;
      }
      await tapPoint(
        localPoint(-1, deckY + 1.04, 6),
        plotId + (turn === 0 ? '.deck.panel-13' : '.deck.panel-11'),
        'panel near approach',
      );
      // An 8cm rail is below one phone pixel in the whole-plot view. Frame it
      // before testing its actual surface instead of relying on rounded taps.
      await aim(localPoint(-8, deckY + 1.04, -4), 'top', 0, 0, 12);
      await tapPoint(localPoint(-8, deckY + 1.04, -4), plotId + '.deck', 'deck guard');
      await aim(localPoint(-1, deckY, 11), 'top', 0, 0, 12);
      await tapPoint(localPoint(-1, deckY, 11), plotId + '.deck.ramp', 'access guard');

      await aim([8, deckY - 0.35, 0], 'orbit', Math.PI / 2, -0.47, 8);
      if (turn === 1) {
        await tapPoint([8, deckY - 0.35, 0], plotId + '.deck.ramp', 'approach occludes support');
      }
      await aim([8, deckY - 0.35, -4], 'orbit', Math.PI / 2, -0.47, 8);
      await tapPoint([8, deckY - 0.35, -4], plotId + '.deck.body', 'exposed support');
      await shot('support');
      await click('[data-building-asset="cabin"]');
      await settle();
      await aim([0, deckY, 0]);
      await tapPoint([0, deckY, 0], plotId + '.deck.building', 'roof occludes core');
      assert.equal(await page.evaluate(() => phanesEditor.interiorRoom), '');
      await shot('building');

      // Rebuilding the owning chunk must re-resolve the durable selection.
      await click('#groundwork-piers');
      await settle();
      assert.equal(await selected(), plotId + '.deck.building');
      assert.equal(
        await page.evaluate(() => phanesRenderedGroundworkId),
        plotId + '.deck.building',
      );
      await tapPoint(
        [0, deckY, 0],
        plotId + '.deck.building',
        'same instance after chunk replacement',
      );
      await click('#groundwork-remove-building');
      await settle();
      assert.equal(await selected(), plotId + '.deck');
      assert.equal(await page.evaluate(() => phanesRenderedGroundworkId), plotId + '.deck');
      await click('#groundwork-undo');
      await settle();
      await tapPoint([0, deckY, 0], plotId + '.deck.building', 'restored instance');

      await aim([0, deckY, 0], 'orbit');
      const beforeDrag = await selected();
      const canvas = await page.locator('canvas').boundingBox();
      if (phone) {
        const touch = await page.context().newCDPSession(page);
        await touch.send('Input.dispatchTouchEvent', {
          type: 'touchStart',
          touchPoints: [{ x: canvas.x + canvas.width / 2, y: canvas.y + canvas.height / 2 }],
        });
        await touch.send('Input.dispatchTouchEvent', {
          type: 'touchMove',
          touchPoints: [
            { x: canvas.x + canvas.width / 2 + 45, y: canvas.y + canvas.height / 2 + 12 },
          ],
        });
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await touch.detach();
      } else {
        await page.mouse.move(canvas.x + canvas.width / 2, canvas.y + canvas.height / 2);
        await page.mouse.down();
        await page.mouse.move(canvas.x + canvas.width / 2 + 45, canvas.y + canvas.height / 2 + 12, {
          steps: 6,
        });
        await page.mouse.up();
      }
      await settle();
      assert.equal(await selected(), beforeDrag, 'Orbit drag does not select');

      // Two placements share the same template but must retain separate IDs.
      const twoPlots = await page.evaluate(async () => {
        const solve = (request) =>
          new Promise((resolve, reject) => {
            const worker = new Worker('world-worker.js');
            const timeout = setTimeout(() => {
              worker.terminate();
              reject(Error('Fixture timeout'));
            }, 30000);
            worker.onmessage = ({ data }) => {
              clearTimeout(timeout);
              worker.terminate();
              resolve(data);
            };
            worker.onerror = (error) => {
              clearTimeout(timeout);
              worker.terminate();
              reject(Error(error.message));
            };
            worker.postMessage({
              job: 1,
              size: 16,
              seed: 917,
              width: 2,
              depth: 2,
              assets: phanesEditor.palette.assets,
              ...request,
            });
          });
        const created = await solve({
          operation: 'create',
          x: 0,
          z: 0,
          width: 16,
          depth: 16,
        });
        if (!created.success) throw Error(created.message);
        let world = created.world;
        const flatLevel = Math.ceil(1000 / world.elevation.levelStep);
        world.elevation.minimumLevel = flatLevel;
        world.elevation.maximumLevel = flatLevel;
        world.elevation.maximumRise = 0;
        world.elevation.levels.fill(flatLevel);
        world.layers = world.layers.map((_, i) =>
          Array((i === 2 || i === 4 ? 32 : 16) ** 2).fill(i === 0 ? 'meadow' : 'empty'),
        );
        world.composition = {
          ...world.composition,
          revision: 0,
          nodes: world.composition.nodes.filter((n) => n.id === 'world'),
        };
        for (const [x, z] of [
          [3, 3],
          [9, 9],
        ]) {
          const foundation = await solve({
            operation: 'foundation',
            x,
            z,
            previous: world,
            groundworkBody: 'plinth',
          });
          if (!foundation.success) throw Error('Plot ' + x + ',' + z + ': ' + foundation.message);
          const id = 'site-' + x + '-' + z;
          const building = await solve({
            operation: 'place-building',
            x,
            z,
            previous: foundation.world,
            objectId: id,
            buildingAsset: 'cabin',
          });
          if (!building.success) throw Error(building.message);
          world = building.world;
        }
        return { world, id: 'site-9-9' };
      });
      await page.locator('#world-file').setInputFiles({
        name: 'phanes-two-plots.json',
        mimeType: 'application/json',
        buffer: Buffer.from(JSON.stringify({
          version: twoPlots.world.formatVersion === 3 ? 3 : 2,
          world: twoPlots.world,
        })),
      });
      await settle();
      const firstDeck = twoPlots.world.composition.nodes.find((n) => n.id === plotId + '.deck');
      const firstPoint = [-64, firstDeck.y / 1000, -64];
      await aim(firstPoint);
      await tapPoint(firstPoint, plotId + '.deck.building', 'first shared cabin instance');
      const secondPlot = twoPlots.world.composition.nodes.find((n) => n.id === twoPlots.id);
      const secondDeck = twoPlots.world.composition.nodes.find(
        (n) => n.id === twoPlots.id + '.deck',
      );
      const secondPoint = [secondPlot.x / 1000, secondDeck.y / 1000, secondPlot.z / 1000];
      await aim(secondPoint);
      await tapPoint(secondPoint, twoPlots.id + '.deck.building', 'second shared cabin instance');
      await shot('second-instance');

      for (const [selector, suffix] of [
        ['#groundwork-building', '.deck.building'],
        ['#groundwork-body', '.deck.body'],
        ['[data-groundwork-part="site-9-9.deck.panel-0"]', '.deck.panel-0'],
      ]) {
        await click(selector);
        await settle();
        await aim([-112, 5, -112]);
        assert.equal(
          await page.evaluate(() => phanesRenderedGroundworkId),
          '',
          'Demoted mesh is absent',
        );
        await click('#groundwork-frame');
        await settle();
        assert.equal(
          await page.evaluate(() => phanesRenderedGroundworkId),
          twoPlots.id + suffix,
          'Look closer restores the selected part from its owning chunk',
        );
      }
      await shot('reframed-panel');
      await aim(secondPoint);
      await tapPoint(secondPoint, twoPlots.id + '.deck.building', 'shared cabin after streaming');

      // Replaying an old renderer callback cannot reopen a dismissed inspector.
      const oldPick = await page.evaluate(() => phanesPickVersion);
      await click('#leave-groundworks');
      await settle();
      assert.equal(await page.evaluate(() => phanesRenderedGroundworkId), '');
      await page.evaluate(({ id, version }) => phanesGroundworkPicked(id, version), {
        id: twoPlots.id + '.deck.building',
        version: oldPick,
      });
      assert.equal(await page.locator('#groundwork-tools').isVisible(), false);

      // An inactive Point gesture keeps fine-grid and combine semantics when it
      // hits terrain; non-Point authoring gestures never reopen Groundworks.
      await aim([0, 1, 0]);
      await click('[data-authoring-tool="point"]');
      await page.locator('#selection-scale').selectOption('2');
      await page.locator('#selection-combine').selectOption('replace');
      await tapAuthoringPoint([0, 1, 0]);
      assert.equal(await page.evaluate(() => phanesEditor.selection.selectionScale), 2);
      assert.equal(await page.evaluate(() => phanesEditor.selection.selectionCells.length), 1);
      await page.locator('#selection-combine').selectOption('add');
      await tapAuthoringPoint([8, 1, 0]);
      assert.equal(await page.evaluate(() => phanesEditor.selection.selectionCells.length), 2);
      await page.locator('#selection-combine').selectOption('subtract');
      await tapAuthoringPoint([0, 1, 0]);
      assert.equal(await page.evaluate(() => phanesEditor.selection.selectionCells.length), 1);
      assert.equal(await page.locator('#groundwork-tools').isVisible(), false);

      await aim(secondPoint);
      const pickedBeforeAuthoringGestures = await page.evaluate(
        () => document.body.dataset.groundworkPickedVersion,
      );
      for (const [tool, offsets] of [
        ['brush', [[36, 0], [50, 18]]],
        ['box', [[42, 34]]],
        ['lasso', [[38, 0], [38, 32], [0, 32], [0, 0]]],
      ]) {
        await drawAuthoringGesture(tool, secondPoint, offsets);
        assert.equal(await page.locator('#groundwork-tools').isVisible(), false);
        assert.equal(
          await page.evaluate(() => document.body.dataset.groundworkPickedVersion),
          pickedBeforeAuthoringGestures,
        );
      }
      await page.locator('#selection-scale').selectOption('1');
      await page.locator('#selection-combine').selectOption('replace');
      await click('[data-authoring-tool="point"]');
      await tapPoint(
        secondPoint,
        twoPlots.id + '.deck.building',
        'reopen from actual world geometry',
      );

      // A drag that returns near its start remains a drag, even after release.
      await aim(secondPoint, 'orbit');
      const dragPoint = await screenPoint(secondPoint);
      const beforeLoop = await page.evaluate(() => ({
        pickVersion: phanesPickVersion,
        pickAction: phanesPickAction,
        cameraVersion: phanesCameraVersion,
        selected: document.body.dataset.groundworkSelected,
        pickedVersion: document.body.dataset.groundworkPickedVersion,
        selection: structuredClone(phanesEditor.selection),
      }));
      const snapshotBeforeLoop = await snapshot();
      if (phone) {
        const touch = await page.context().newCDPSession(page);
        for (const [type, dx] of [
          ['touchStart', 0],
          ['touchMove', 70],
          ['touchMove', 1],
        ]) {
          await touch.send('Input.dispatchTouchEvent', {
            type,
            touchPoints: [{ x: dragPoint.x + dx, y: dragPoint.y }],
          });
        }
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await touch.detach();
      } else {
        await page.mouse.move(dragPoint.x, dragPoint.y);
        await page.mouse.down();
        await page.mouse.move(dragPoint.x + 70, dragPoint.y, { steps: 4 });
        await page.mouse.move(dragPoint.x + 1, dragPoint.y, { steps: 4 });
        await page.mouse.up();
      }
      await settle();
      const afterLoop = await page.evaluate(() => ({
        pickVersion: phanesPickVersion,
        pickAction: phanesPickAction,
        cameraVersion: phanesCameraVersion,
        selected: document.body.dataset.groundworkSelected,
        pickedVersion: document.body.dataset.groundworkPickedVersion,
        selection: structuredClone(phanesEditor.selection),
      }));
      assert.ok(
        afterLoop.pickVersion > beforeLoop.pickVersion,
        'A completed drag invalidates its stale pick generation',
      );
      assert.equal(afterLoop.pickAction, '');
      assert.ok(afterLoop.cameraVersion > beforeLoop.cameraVersion, 'Orbit drag moves the camera');
      assert.equal(afterLoop.selected, beforeLoop.selected);
      assert.equal(afterLoop.pickedVersion, beforeLoop.pickedVersion);
      assert.deepEqual(afterLoop.selection, beforeLoop.selection);
      assert.deepEqual(await snapshot(), snapshotBeforeLoop, 'Orbit drag cannot edit world or history');
      const locked = structuredClone(twoPlots.world);
      for (const node of locked.composition.nodes) {
        if (
          ['.deck.body', '.deck.building', '.deck.panel-0'].some(
            (suffix) => node.id === twoPlots.id + suffix,
          )
        ) {
          node.locked = true;
        }
      }
      await page.locator('#world-file').setInputFiles({
        name: 'phanes-locked-parts.json',
        mimeType: 'application/json',
        buffer: Buffer.from(JSON.stringify({
          version: locked.formatVersion === 3 ? 3 : 2,
          world: locked,
        })),
      });
      await settle();
      // Import deliberately resets the regional selection to the world centre.
      // Re-select the actual locked instance before exercising its controls.
      await aim(secondPoint);
      await tapPoint(
        secondPoint,
        twoPlots.id + '.deck.building',
        'locked building remains inspectable',
      );
      for (const [selector, suffix] of [
        ['#groundwork-building', '.deck.building'],
        ['#groundwork-body', '.deck.body'],
        ['[data-groundwork-part="site-9-9.deck.panel-0"]', '.deck.panel-0'],
      ]) {
        const unchanged = await snapshot();
        if (!phone) {
          await page.locator(selector).focus();
          await page.keyboard.press('Enter');
        } else await click(selector);
        await settle();
        assert.equal(await selected(), twoPlots.id + suffix);
        assert.match(await page.locator('#groundwork-scope-hint').textContent(), /locked/i);
        assert.equal(await page.locator('#groundwork-reimagine').isDisabled(), true);
        assert.equal(await page.locator('#groundwork-plinth').isDisabled(), true);
        assert.equal(await page.locator('#groundwork-piers').isDisabled(), true);
        assert.deepEqual(await snapshot(), unchanged);
      }
      await click('#groundwork-frame');
      await settle();
      await shot('locked-panel');
      await click('#leave-groundworks');
      await settle();
      assert.equal(
        await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
        true,
      );
      assert.deepEqual(errors, []);
      evidence.viewports.push({
        viewport,
        deviceScaleFactor,
        turn,
        picks,
        lockedInspection: true,
        errors,
      });
      fs.writeFileSync(
        path.join(root, 'build', 'groundwork-picking-evidence.json'),
        JSON.stringify(evidence, null, 2) + '\n',
      );
      await page.close();
    }
    console.log(JSON.stringify(evidence, null, 2));
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
