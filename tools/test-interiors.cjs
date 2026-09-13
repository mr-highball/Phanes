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
  const base = process.env.TEST_URL || 'http://127.0.0.1:4186/';
  const root = path.resolve(__dirname, '..');
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.BROWSER,
    args: ['--enable-unsafe-swiftshader'],
  });
  const evidence = { worker: [], viewports: [] };
  try {
    const page = await browser.newPage();
    await page.goto(new URL('data/palette.json', base).href);
    const assets = await page.evaluate(
      async () => (await (await fetch('palette.json')).json()).assets,
    );
    const solve = async (request, raw = false) =>
      page.evaluate(
        ({ request, raw, assets, base }) =>
          new Promise((resolve, reject) => {
            const worker = new Worker(new URL('world-worker.js', base));
            const timer = setTimeout(() => {
              worker.terminate();
              reject(Error('Interior worker timeout'));
            }, 30000);
            worker.onmessage = ({ data }) => {
              clearTimeout(timer);
              worker.terminate();
              resolve(data);
            };
            worker.onerror = (error) => {
              clearTimeout(timer);
              worker.terminate();
              reject(Error(error.message));
            };
            worker.postMessage(
              raw
                ? request
                : {
                    job: 1,
                    size: 4,
                    seed: 732,
                    x: 1,
                    z: 1,
                    width: 1,
                    depth: 1,
                    previous: null,
                    assets,
                    ...request,
                  },
            );
          }),
        { request, raw, assets, base },
      );
    const requireSuccess = (result) => {
      assert.equal(result.success, true, result.message);
      return result.world;
    };
    const generated = requireSuccess(
      await solve({ operation: 'create', width: 4, depth: 4, x: 0, z: 0 }),
    );
    const unfurnished = requireSuccess(await solve({ operation: 'cabin', previous: generated }));
    let furnished;
    const layouts = new Set();
    for (const seed of [...Array.from({ length: 32 }, (_, i) => i + 1), 4294967295]) {
      const world = requireSuccess(
        await solve({ operation: 'create-interior', previous: unfurnished, seed }),
      );
      assert.equal(world.formatVersion, unfurnished.formatVersion);
      assert.deepEqual(world.elevation, unfurnished.elevation);
      assert.equal(world.composition.nodes.length, 31);
      const nodes = world.composition.nodes;
      const room = nodes.find((n) => n.role === 'studio');
      const bookcase = nodes.find((n) => n.role === 'bookcase');
      const table = nodes.find((n) => n.role === 'table');
      layouts.add(table.x + ':' + bookcase.x);
      assert.equal(nodes.filter((n) => n.parent === room.id).length, 4);
      assert.equal(
        nodes.filter((n) => n.parent === bookcase.id + '.tier-4' && n.role === 'book').length,
        3,
      );
      assert.equal(
        nodes.filter((n) => n.parent === bookcase.id + '.tier-2' && n.role === 'ornament').length,
        1,
      );
      const plates = nodes.filter((n) => n.role === 'plate');
      assert.equal(plates.length, 2);
      for (const plate of plates) {
        const well = nodes.find((n) => n.id === plate.id + '.well');
        assert.equal(well.parent, plate.id);
        assert.equal(well.role, 'plate-well');
        assert.equal(well.y, 6, 'Food rests on the inner plate, below the raised rim');
        const food = nodes.filter((n) => n.parent === well.id);
        assert.deepEqual(food.map((n) => n.role).sort(), ['bread', 'cheese', 'fruit']);
        for (const item of food) {
          assert.equal(item.support, well.id);
          assert.equal(item.y, 0);
        }
      }
      assert.deepEqual(world.layers, unfurnished.layers);
      furnished = world;
    }
    assert.ok(
      layouts.size >= 4,
      'Furniture must have several distinct valid layouts: ' + [...layouts].join(', '),
    );
    evidence.worker.push({ case: '33 seeds including unsigned maximum', layouts: [...layouts] });
    const nodes = furnished.composition.nodes;
    const plates = nodes.filter((n) => n.role === 'plate');
    const plate = plates[0];
    const well = nodes.find((n) => n.id === plate.id + '.well');
    const fruit = nodes.find((n) => n.parent === well.id && n.role === 'fruit');
    const byId = (world, id) => world.composition.nodes.find((n) => n.id === id);
    const subtree = (world, id) => {
      const ids = new Set([id]);
      let previous;
      do {
        previous = ids.size;
        for (const n of world.composition.nodes) if (ids.has(n.parent)) ids.add(n.id);
      } while (previous !== ids.size);
      return world.composition.nodes.filter((n) => ids.has(n.id));
    };
    const fruitChanged = requireSuccess(await solve({
      operation: 'contents', previous: furnished, objectId: fruit.id,
    }));
    assert.notEqual(byId(fruitChanged, fruit.id).asset, fruit.asset);
    assert.deepEqual(fruitChanged.composition.nodes.filter((n) => n.id !== fruit.id),
      nodes.filter((n) => n.id !== fruit.id));
    const plateChanged = requireSuccess(await solve({
      operation: 'contents', previous: furnished, objectId: plate.id,
    }));
    assert.notEqual(byId(plateChanged, plate.id).asset, plate.asset);
    assert.deepEqual(plateChanged.composition.nodes.filter((n) => n.id !== plate.id),
      nodes.filter((n) => n.id !== plate.id));
    const tableChanged = requireSuccess(await solve({
      operation: 'contents', previous: furnished, objectId: plate.parent,
    }));
    for (const original of plates) {
      assert.ok(byId(tableChanged, original.id));
      assert.deepEqual(subtree(tableChanged, original.id).filter((n) => n.id !== original.id),
        subtree(furnished, original.id).filter((n) => n.id !== original.id));
    }
    const lessFruit = requireSuccess(await solve({
      operation: 'contents', previous: furnished, objectId: well.id,
      contentRole: 'fruit', contentCount: 0,
    }));
    assert.deepEqual(lessFruit.composition.nodes, nodes.filter((n) => n.id !== fruit.id));
    const moreFruit = requireSuccess(await solve({
      operation: 'contents', previous: lessFruit, objectId: well.id,
      contentRole: 'fruit', contentCount: 1,
    }));
    assert.equal(byId(moreFruit, fruit.id).role, 'fruit');
    assert.deepEqual(moreFruit.composition.nodes.filter((n) => n.id !== fruit.id),
      lessFruit.composition.nodes);
    const lessPlates = requireSuccess(await solve({
      operation: 'contents', previous: furnished, objectId: plate.parent,
      contentRole: 'plate', contentCount: 1,
    }));
    const survivor = lessPlates.composition.nodes.find((n) => n.role === 'plate');
    assert.equal(lessPlates.composition.nodes.filter((n) => n.role === 'plate').length, 1);
    assert.deepEqual(subtree(lessPlates, survivor.id), subtree(furnished, survivor.id));
    const removed = plates.find((n) => n.id !== survivor.id);
    for (const n of subtree(furnished, removed.id)) assert.equal(byId(lessPlates, n.id), undefined);
    const childLocked = structuredClone(furnished);
    byId(childLocked, fruit.id).locked = true;
    for (const request of [
      { objectId: plate.id },
      { objectId: plate.parent, contentRole: 'plate', contentCount: 0 },
    ]) {
      const rejected = await solve({ operation: 'contents', previous: childLocked, ...request });
      assert.equal(rejected.success, false);
      assert.equal(rejected.world, undefined);
    }
    const otherFruit = nodes.find((n) => n.role === 'fruit' && n.id !== fruit.id);
    requireSuccess(await solve({ operation: 'contents', previous: childLocked, objectId: otherFruit.id }));
    const legacy = structuredClone(furnished);
    const foodIds = new Set(plates.flatMap((n) => subtree(furnished, n.id).slice(1).map((n) => n.id)));
    legacy.composition.nodes = legacy.composition.nodes.filter((n) => !foodIds.has(n.id));
    assert.equal(legacy.composition.nodes.length, 23);
    assert.deepEqual(requireSuccess(await solve({ operation: 'restore', previous: legacy })), legacy);
    for (const corrupt of [
      (w) => { byId(w, well.id).y++; },
      (w) => { byId(w, fruit.id).asset = 'unknown.food'; },
      (w) => { byId(w, fruit.id).x = 120; },
      (w) => { byId(w, fruit.id).y = 1; },
      (w) => { byId(w, fruit.id).support = plates[1].id + '.well'; },
    ]) {
      const malformed = structuredClone(furnished);
      corrupt(malformed);
      const rejected = await solve({ operation: 'restore', previous: malformed });
      assert.equal(rejected.success, false);
      assert.equal(rejected.world, undefined);
    }
    const secondCabin = requireSuccess(await solve({
      operation: 'cabin', previous: furnished, x: 2, z: 2,
    }));
    const secondRoom = requireSuccess(await solve({
      operation: 'create-interior', previous: secondCabin, x: 2, z: 2,
    }));
    for (const n of nodes) assert.deepEqual(byId(secondRoom, n.id), n);
    evidence.worker.push({
      case: 'Nested food identity, parent and surrounding edits, exact counts, descendant locks, legacy save, malformed contact and second-room isolation',
      passed: true,
    });
    const book = nodes.find((n) => n.role === 'book');
    const changed = requireSuccess(
      await solve({ operation: 'contents', previous: furnished, objectId: book.id }),
    );
    assert.notEqual(changed.composition.nodes.find((n) => n.id === book.id).asset, book.asset);
    const neighbors = (w) => w.composition.nodes.filter((n) => n.id !== book.id);
    assert.deepEqual(neighbors(changed), neighbors(furnished));
    const replaced = requireSuccess(
      await solve({
        operation: 'contents',
        previous: furnished,
        objectId: book.id,
        contentAsset: 'phanes.snail.ivory.v1',
      }),
    );
    assert.equal(replaced.composition.nodes.find((n) => n.id === book.id).role, 'ornament');
    assert.deepEqual(neighbors(replaced), neighbors(furnished));
    const tier = nodes.find((n) => n.id.endsWith('.tier-4'));
    const counted = requireSuccess(
      await solve({
        operation: 'contents',
        previous: furnished,
        objectId: tier.id,
        contentRole: 'book',
        contentCount: 4,
      }),
    );
    assert.equal(counted.composition.nodes.filter((n) => n.parent === tier.id).length, 4);
    assert.deepEqual(
      counted.composition.nodes.filter((n) => n.parent !== tier.id),
      nodes.filter((n) => n.parent !== tier.id),
    );
    const locked = structuredClone(furnished);
    locked.composition.nodes.find((n) => n.id === book.support).locked = true;
    for (const request of [
      { operation: 'contents', previous: locked, objectId: book.id },
      { operation: 'clear', previous: locked },
      {
        operation: 'contents',
        previous: furnished,
        objectId: book.id,
        contentAsset: 'phanes.fork.silver.v1',
      },
      {
        operation: 'contents',
        previous: furnished,
        objectId: tier.id,
        contentRole: 'unknown',
        contentCount: 2,
      },
      { operation: 'contents', previous: furnished, objectId: book.id, contentAsset: null },
      { operation: 'unknown-operation', previous: furnished },
      { operation: 'restore' },
    ]) {
      const rejected = await solve(request);
      assert.equal(rejected.success, false, JSON.stringify(request));
      assert.equal(rejected.world, undefined);
      assert.ok(rejected.message);
    }
    const cleared = requireSuccess(await solve({ operation: 'clear', previous: furnished }));
    assert.equal(cleared.composition.nodes.length, 1);
    const restored = requireSuccess(await solve({ operation: 'restore', previous: furnished }));
    assert.deepEqual(restored, furnished);
    for (const request of [null, undefined, 7, [], 'bad']) {
      const rejected = await solve(request, true);
      assert.equal(rejected.success, false);
      assert.ok(rejected.message);
    }
    const displaced = structuredClone(furnished);
    displaced.composition.nodes.find((n) => n.id === tier.id).y++;
    assert.equal((await solve({ operation: 'restore', previous: displaced })).success, false);
    evidence.worker.push({
      case: 'Scoped edit, cross-role replacement, counts, locks, clear, exact restore, malformed inputs',
      passed: true,
    });
    await page.close();

    for (const viewport of (process.env.TEST_WORKER_ONLY ? [] : [
      { width: 1440, height: 960 },
      { width: 390, height: 844 },
    ])) {
      const view = await browser.newPage({ viewport, hasTouch: viewport.width < 500 });
      const errors = [];
      view.on('pageerror', (e) => {
        errors.push(e.message);
        console.error(e.message);
      });
      view.on('console', (m) => {
        if (m.type() === 'error' || /Exception|Error|Warning/.test(m.text())) {
          console.error(m.text());
        }
      });
      view.on('response', (r) => {
        if (r.status() >= 400) errors.push(r.status() + ' ' + r.url());
      });
      await view.goto(base, { waitUntil: 'domcontentloaded' });
      await view.waitForFunction(() => document.body.dataset.ready === 'true', null, {
        timeout: 120000,
      });
      const importWorld = async (world) => {
        const priorVersion = await view.evaluate(() => phanesSceneVersion);
        await view.locator('#world-file').setInputFiles({
          name: 'phanes-test.json',
          mimeType: 'application/json',
          buffer: Buffer.from(JSON.stringify({
            version: world.formatVersion === 3 ? 3 : 2,
            world,
          })),
        });
        try {
          await view.waitForFunction(
            (prior) => !phanesEditor.worker && phanesSceneVersion > prior,
            priorVersion,
          );
        } catch (error) {
          const state = await view.evaluate(() => ({
            sceneVersion: phanesSceneVersion,
            renderedRevision: document.body.dataset.renderedRevision,
            lastSolve: document.body.dataset.lastSolve,
            status: document.getElementById('status')?.textContent,
            toast: document.getElementById('toast')?.textContent,
            workerActive: !!phanesEditor.worker,
            catalogLoading: window.phanesCatalogLoading,
            catalogStageError: window.phanesCatalogStageError,
            interiorRoom: phanesEditor.interiorRoom,
            selection: phanesEditor.selection,
          }));
          const failure = { base, viewport, priorVersion,
            importedFormat: world.formatVersion, state, errors };
          fs.writeFileSync(path.join(root, 'build',
            'interior-import-failure-' + viewport.width + '-evidence.json'),
          JSON.stringify(failure, null, 2));
          await view.screenshot({ path: path.join(root, 'build',
            'interior-import-failure-' + viewport.width + '.png') });
          console.error('Interior import failure:', JSON.stringify(failure));
          throw error;
        }
        assert.equal(await view.evaluate(() => document.body.dataset.lastSolve), 'passed');
      };
      await importWorld(unfurnished);
      await view.waitForFunction(() => document.body.dataset.renderedRevision === '1', null, {
        timeout: 120000,
      });
      // Establish a known one-cell fixture selection; every interior interaction
      // below uses visible player controls and the real compiled worker/CGE host.
      await view.evaluate(() => {
        phanesEditor.selection = { x: 1, z: 1, width: 1, depth: 1 };
        phanesEditorActions.setCamera('top');
      });
      await view.locator('#open-interior').click();
      await view.waitForFunction(() => !!phanesEditor.interiorRoom && !phanesEditor.worker);
      await view.waitForFunction(
        () =>
          document.body.dataset.renderedInterior === phanesEditor.interiorRoom &&
          Number(document.body.dataset.renderedInteriorScene) === phanesSceneVersion,
      );
      await view.waitForTimeout(1200);
      await view.screenshot({
        path: path.join(root, 'build', 'interior-room-' + viewport.width + '.png'),
      });
      await view
        .locator('#interior-children button')
        .filter({ hasText: 'Four-tier bookcase' })
        .click();
      await view.locator('#interior-children button').filter({ hasText: 'Shelf 4' }).click();
      await view.locator('#interior-frame').click();
      await view.waitForTimeout(700);
      assert.equal(await view.locator('#interior-children button').count(), 3);
      await view.screenshot({
        path: path.join(root, 'build', 'interior-shelf-' + viewport.width + '.png'),
      });
      await view.locator('#interior-count').fill('4');
      await view.locator('#apply-content-count').click();
      await view.waitForFunction(() => !phanesEditor.worker);
      assert.equal(await view.locator('#interior-children button').count(), 4);
      await view.locator('#interior-parent').click();
      await view.locator('#interior-children button').filter({ hasText: 'Shelf 2' }).click();
      await view.locator('#interior-children button').click();
      await view.locator('#interior-frame').click();
      await view.waitForTimeout(700);
      const baseline = await view.evaluate(() => structuredClone(phanesEditor.world.composition));
      const selectedId = await view.evaluate(() => phanesEditor.interiorSelected);
      const sceneBounds = await view.locator('#castle-canvas').boundingBox();
      const pickOffset = Math.min(40, sceneBounds.width * 0.04);
      // The oblique pose previously put a post before the near plane. Exercise
      // that regression independently of the improved default framing angle.
      for (const pose of [
        { yaw: 0, pitch: -0.37 },
        { yaw: -0.4, pitch: 0 },
      ]) {
        await view.evaluate((pose) => {
          Object.assign(phanesEditor, pose);
          phanesEditorActions.setCamera('orbit');
        }, pose);
        await view.waitForTimeout(300);
        for (const [dx, dy] of [
          [0, 0],
          [pickOffset, 0],
          [-pickOffset, 0],
          [0, pickOffset],
          [0, -pickOffset],
        ]) {
          await view.locator('#interior-parent').click();
          await view.mouse.click(
            sceneBounds.x + sceneBounds.width / 2 + dx,
            sceneBounds.y + sceneBounds.height / 2 + dy,
          );
          try {
            await view.waitForFunction((id) => phanesEditor.interiorSelected === id, selectedId, {
              timeout: 5000,
            });
          } catch (error) {
            await view.screenshot({
              path: path.join(root, 'build', 'interior-pick-failed-' + viewport.width + '.png'),
            });
            console.error({
              viewport,
              pose,
              dx,
              dy,
              expected: selectedId,
              actual: await view.evaluate(() => phanesEditor.interiorSelected),
            });
            throw error;
          }
        }
      }
      await view.screenshot({
        path: path.join(root, 'build', 'interior-pick-' + viewport.width + '.png'),
      });
      // Cancelling or changing cameras must not replay the previous canvas ray.
      await view.locator('#interior-parent').click();
      const parentBeforeCancel = await view.evaluate(() => phanesEditor.interiorSelected);
      await view.evaluate(() => phanesEditorActions.setCamera('top'));
      await view.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await view.evaluate(
        () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
      );
      assert.equal(await view.evaluate(() => phanesEditor.interiorSelected), parentBeforeCancel);
      await view.locator('#interior-children button[data-node="' + selectedId + '"]').click();
      await view.locator('#interior-frame').click();
      await view.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await view.locator('#interior-looks button[data-asset="phanes.book.indigo.v1"]').click();
      await view.waitForFunction(() => !phanesEditor.worker);
      const after = await view.evaluate(() => phanesEditor.world.composition);
      assert.equal(after.nodes.find((n) => n.id === selectedId).asset, 'phanes.book.indigo.v1');
      assert.equal(await view.locator('#interior-title').textContent(), 'Indigo book');
      assert.deepEqual(
        after.nodes.filter((n) => n.id !== selectedId),
        baseline.nodes.filter((n) => n.id !== selectedId),
      );
      await view.locator('#interior-undo').click();
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition), baseline);
      await view.locator('#interior-redo').click();
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition), after);
      const downloadPromise = view.waitForEvent('download');
      await view.locator(viewport.width < 500 ? '#interior-export' : '#save-world').click();
      const download = await downloadPromise;
      const saved = JSON.parse(fs.readFileSync(await download.path(), 'utf8'));
      assert.equal(saved.version, saved.world.formatVersion === 3 ? 3 : 2);
      assert.equal(saved.version, 3);
      assert.deepEqual(saved.world.elevation, furnished.elevation);
      assert.deepEqual(saved.world.composition, after);
      await importWorld(saved.world);
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition), after);
      const foodBaseline = await view.evaluate(() => structuredClone(phanesEditor.world.composition));
      const scenePlate = foodBaseline.nodes.find((n) => n.role === 'plate');
      const sceneWell = foodBaseline.nodes.find((n) => n.id === scenePlate.id + '.well');
      const sceneFruit = foodBaseline.nodes.find((n) => n.parent === sceneWell.id && n.role === 'fruit');
      const sceneTable = foodBaseline.nodes.find((n) => n.id === scenePlate.parent);
      const chooseChild = async (id) => {
        const button = view.locator('#interior-children button[data-node="' + id + '"]');
        if (viewport.width < 500) await button.tap();
        else await button.click();
      };
      await view.locator('#interior-path button').first().click();
      await chooseChild(sceneTable.parent);
      await chooseChild(sceneTable.id);
      await chooseChild(scenePlate.id);
      await view.locator('#interior-frame').click();
      await view.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await view.waitForTimeout(500);
      const plateCamera = await view.evaluate(() => JSON.parse(phanesCamera));
      const delta = plateCamera.position.map((v, i) => v - plateCamera.target[i]);
      assert.ok(Math.atan2(delta[1], Math.hypot(delta[0], delta[2])) > 0.9,
        'Plate framing must show the food from above');
      await view.screenshot({ path: path.join(root, 'build', 'interior-plate-' + viewport.width + '.png') });
      await chooseChild(sceneWell.id);
      assert.equal(await view.locator('#interior-children button').count(), 3);
      assert.deepEqual(await view.locator('#interior-roles button').allTextContents(), ['Bread', 'Fruit', 'Cheese']);
      await view.locator('#interior-frame').click();
      await view.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await view.waitForTimeout(500);
      await view.screenshot({ path: path.join(root, 'build', 'interior-plate-contents-' + viewport.width + '.png') });
      await chooseChild(sceneFruit.id);
      await view.locator('#interior-frame').click();
      await view.waitForFunction(() => phanesRenderedCameraVersion === phanesCameraVersion);
      await view.waitForTimeout(500);
      await view.screenshot({ path: path.join(root, 'build', 'interior-fruit-' + viewport.width + '.png') });
      await view.locator('#interior-parent').click();
      const foodCanvas = await view.locator('#castle-canvas').boundingBox();
      const fx = foodCanvas.x + foodCanvas.width / 2;
      const fy = foodCanvas.y + foodCanvas.height / 2;
      if (viewport.width < 500) await view.touchscreen.tap(fx, fy);
      else await view.mouse.click(fx, fy);
      await view.waitForFunction((id) => phanesEditor.interiorSelected === id, sceneFruit.id, { timeout: 5000 });
      assert.notEqual(sceneFruit.asset, 'phanes.food.fruit.apple.v1');
      await view
        .locator('#interior-looks button[data-asset="phanes.food.fruit.apple.v1"]')
        .click();
      await view.waitForFunction(() => !phanesEditor.worker);
      const foodAfter = await view.evaluate(() => phanesEditor.world.composition);
      assert.notEqual(foodAfter.nodes.find((n) => n.id === sceneFruit.id).asset, sceneFruit.asset);
      assert.deepEqual(foodAfter.nodes.filter((n) => n.id !== sceneFruit.id),
        foodBaseline.nodes.filter((n) => n.id !== sceneFruit.id));
      await view.locator('#interior-undo').click();
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition), foodBaseline);
      await view.locator('#interior-parent').click();
      await view.locator('#interior-roles button[data-role="fruit"]').click();
      await view.locator('#interior-count').fill('0');
      await view.locator('#apply-content-count').click();
      await view.waitForFunction(() => !phanesEditor.worker);
      assert.equal(await view.locator('#interior-children button').count(), 2);
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition.nodes),
        foodBaseline.nodes.filter((n) => n.id !== sceneFruit.id));
      await view.locator('#interior-undo').click();
      assert.deepEqual(await view.evaluate(() => phanesEditor.world.composition), foodBaseline);
      await importWorld(legacy);
      await view.locator('#interior-path button').first().click();
      await chooseChild(nodes.find((n) => n.id === plate.parent).parent);
      await chooseChild(plate.parent);
      await chooseChild(plate.id);
      await view.locator('#interior-prepare-plate').click();
      await view.waitForFunction(() => !phanesEditor.worker);
      const prepared = await view.evaluate(() => phanesEditor.world.composition);
      assert.deepEqual(prepared.nodes.filter((n) => n.id !== well.id), legacy.composition.nodes);
      assert.equal(prepared.nodes.find((n) => n.id === well.id).parent, plate.id);
      await chooseChild(well.id);
      await view.locator('#interior-roles button[data-role="fruit"]').click();
      await view.locator('#interior-count').fill('1');
      await view.locator('#apply-content-count').click();
      await view.waitForFunction(() => !phanesEditor.worker);
      assert.equal(await view.locator('#interior-children button').count(), 1);
      assert.deepEqual(await view.evaluate((id) => phanesEditor.world.composition.nodes.filter(
        (n) => n.id !== id && n.parent !== id), well.id), legacy.composition.nodes);
      await importWorld(childLocked);
      await view.locator('#interior-path button').first().click();
      await chooseChild(nodes.find((n) => n.id === plate.parent).parent);
      await chooseChild(plate.parent);
      await chooseChild(plate.id);
      assert.equal(await view.locator('#interior-reimagine').isDisabled(), true);
      assert.equal(await view.locator('#interior-looks button:enabled').count(), 0);
      assert.ok((await view.locator('#interior-description').textContent()).includes(fruit.name));
      await chooseChild(well.id);
      await chooseChild(nodes.find((n) => n.parent === well.id && n.role === 'bread').id);
      assert.equal(await view.locator('#interior-reimagine').isEnabled(), true);
      assert.equal(
        await view
          .locator('#interior-looks button[data-asset="phanes.catalog.food.bread-slice.v1"]')
          .isEnabled(),
        true,
      );
      await view.locator('#reset-camera').click();
      await view.locator('[data-camera="walk"]').click();
      await view.waitForTimeout(400);
      const beforeWalk = await view.evaluate(() => ({
        x: phanesEditor.x,
        y: phanesEditor.y,
        z: phanesEditor.z,
      }));
      const walkButton = await view.locator('[data-move="w"]').boundingBox();
      await view.mouse.move(
        walkButton.x + walkButton.width / 2,
        walkButton.y + walkButton.height / 2,
      );
      await view.mouse.down();
      await view.waitForTimeout(400);
      await view.mouse.up();
      const afterWalk = await view.evaluate(() => ({
        x: phanesEditor.x,
        y: phanesEditor.y,
        z: phanesEditor.z,
      }));
      assert.ok(
        Math.abs(afterWalk.y - 1.68) < 0.00001,
        'Eye height remains 1.68 metres within float precision',
      );
      assert.ok(Math.hypot(afterWalk.x - beforeWalk.x, afterWalk.z - beforeWalk.z) > 0.1);
      await view.screenshot({
        path: path.join(root, 'build', 'interior-walk-' + viewport.width + '.png'),
      });
      assert.equal(
        await view.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
        true,
      );
      await view.locator('#leave-interior').click();
      await view.waitForFunction(() => !phanesEditor.interiorRoom);
      assert.deepEqual(errors, []);
      evidence.viewports.push({
        viewport,
        steps: [
          'furnish',
          'shelf count',
          'visible geometry picks at centre and four offsets in two camera poses',
          'item replacement',
          'undo',
          'redo',
          'export',
          'restore',
          'plate and nested support framing',
          'individual food click/tap and appearance change',
          'food count and complete arrangement undo',
          'legacy plate preparation preserves appearance and enables food counts',
          'locked food protects plate appearance while sibling food stays editable',
          'walk',
          'return',
        ],
        beforeWalk,
        afterWalk,
        errors,
      });
      await view.close();
    }
    fs.writeFileSync(
      path.join(root, 'build', 'interior-browser-evidence.json'),
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
