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

const legacyBaseHeight = (x, z) =>
  4 +
  2.6 * Math.sin(x * 0.035) +
  1.8 * Math.cos(z * 0.041) +
  0.9 * Math.sin((x + z) * 0.063);

// Independent saved-field witness: version 1 uses the x-z anti-diagonal and
// stores integer vertex levels whose physical scale is levelStep millimetres.
const savedElevationHeight = (elevation, x, z) => {
  const gridX = (x * 1000 - elevation.originX) / elevation.spacing;
  const gridZ = (z * 1000 - elevation.originZ) / elevation.spacing;
  const column = Math.min(elevation.columns - 2, Math.floor(gridX));
  const row = Math.min(elevation.rows - 2, Math.floor(gridZ));
  const u = gridX - column;
  const v = gridZ - row;
  const index = row * elevation.columns + column;
  const level00 = elevation.levels[index];
  const level10 = elevation.levels[index + 1];
  const level01 = elevation.levels[index + elevation.columns];
  const level11 = elevation.levels[index + elevation.columns + 1];
  let level;
  if (u + v <= 1) {
    level = (1 - u - v) * level00 + u * level10 + v * level01;
  } else {
    level = (u + v - 1) * level11 + (1 - u) * level01 + (1 - v) * level10;
  }
  return (level * elevation.levelStep) / 1000;
};

const buildingDatum = (world, cellX, cellZ) => {
  const x = (cellX + 0.5 - world.size / 2) * 16;
  const z = (cellZ + 0.5 - world.size / 2) * 16;
  if (world.formatVersion === 3) {
    return savedElevationHeight(world.elevation, x, z);
  }
  if (world.formatVersion === 4) {
    return savedElevationHeight(world.elevation, x, z) + legacyBaseHeight(x, z);
  }
  return legacyBaseHeight(x, z);
};

(async () => {
  const triangulationFixture = {
    originX: 0,
    originZ: 0,
    spacing: 1000,
    columns: 2,
    rows: 2,
    levelStep: 1000,
    levels: [0, 10, 20, 40],
  };
  assert.equal(
    savedElevationHeight(triangulationFixture, 0.25, 0.5),
    12.5,
    'Saved elevation uses the lower x-z triangle weights',
  );
  assert.equal(
    savedElevationHeight(triangulationFixture, 0.75, 0.5),
    20,
    'Saved elevation uses the upper x-z triangle weights',
  );

  const base = process.env.TEST_URL || 'http://127.0.0.1:4186/';
  const browser = await chromium.launch({ headless: true, executablePath: process.env.BROWSER });
  const evidence = [];
  try {
    const page = await browser.newPage();
    // Load a small same-origin resource so generator testing does not need CGE.
    await page.goto(new URL('data/palette.json', base).href);
    const assets = await page.evaluate(
      async () => (await (await fetch('palette.json')).json()).assets,
    );
    const solve = async (request) =>
      page.evaluate(
        ({ request, assets, base }) =>
          new Promise((resolve, reject) => {
            const worker = new Worker(new URL('world-worker.js', base));
            const timer = setTimeout(() => {
              worker.terminate();
              reject(new Error('Worker exceeded 30-second test deadline'));
            }, 30000);
            worker.onmessage = ({ data }) => {
              clearTimeout(timer);
              worker.terminate();
              resolve(data);
            };
            worker.onerror = (event) => {
              clearTimeout(timer);
              worker.terminate();
              reject(new Error(event.message));
            };
            worker.postMessage({ job: 1, assets, ...request });
          }),
        { request, assets, base },
      );
    let baseline;
    let largest;
    let checkedBuildingCells = 0;
    for (const size of [4, 8, 12, 24, 48]) {
      const request = {
        size,
        seed: 731,
        operation: 'create',
        x: 0,
        z: 0,
        width: size,
        depth: size,
        previous: null,
      };
      const start = Date.now();
      const first = await solve(request);
      assert.equal(first.success, true, first.message);
      const repeat = await solve(request);
      assert.deepEqual(
        repeat.world.layers,
        first.world.layers,
        'Same seed produces identical layers',
      );
      assert.equal(first.world.layers.length, 5);
      for (let index = 0; index < size * size; index++) {
        if (first.world.layers[1][index] !== 'empty') {
          const datum = buildingDatum(first.world, index % size, Math.floor(index / size));
          checkedBuildingCells += 1;
          assert.ok(datum >= 0.101, 'WFC excludes buildings below safe physical height');
        }
      }
      evidence.push({
        size,
        cells: size * size * 11,
        twoRunsMilliseconds: Date.now() - start,
        decisions: first.world.decisions,
      });
      if (size === 12) {
        baseline = first.world;
      }
      if (size === 48) {
        largest = first.world;
      }
    }
    assert.ok(checkedBuildingCells > 0, 'Physical building checks require generated buildings');

    const legacyLowland = structuredClone(largest);
    legacyLowland.formatVersion = 2;
    delete legacyLowland.elevation;
    legacyLowland.layers.forEach((layer, index) =>
      layer.fill(index === 0 ? 'meadow' : 'empty'),
    );
    assert.ok(
      buildingDatum(legacyLowland, 43, 9) < 0.101,
      'Legacy lowland fixture remains physically wet',
    );
    const legacyLowlandBefore = JSON.stringify(legacyLowland);
    for (const operation of ['cabin', 'castle', 'modern', 'scifi', 'rocket']) {
      const refused = await solve({
        size: 48,
        seed: 731,
        operation,
        x: 43,
        z: 9,
        width: 1,
        depth: 1,
        previous: legacyLowland,
      });
      assert.equal(
        refused.success,
        false,
        'Explicit legacy underwater building request is refused',
      );
      assert.match(refused.message, /safe building height/);
      assert.equal(refused.world, undefined, 'A refused building must not silently become empty');
      assert.equal(
        JSON.stringify(legacyLowland),
        legacyLowlandBefore,
        'Legacy refusal preserves the baseline',
      );
    }
    const legacySubmerged = structuredClone(legacyLowland);
    legacySubmerged.layers[1][9 * 48 + 43] = 'cabin';
    legacySubmerged.layers[3][9 * 48 + 43] = 'cabin';
    const legacyWetRestore = await solve({
      size: 48,
      seed: 731,
      operation: 'restore',
      x: 0,
      z: 0,
      width: 48,
      depth: 48,
      previous: legacySubmerged,
    });
    assert.equal(
      legacyWetRestore.success,
      false,
      'Saved legacy underwater building rejected independently',
    );
    assert.match(legacyWetRestore.message, /safe standing height/);

    for (const formatVersion of [3, 4]) {
      const fieldLowland = structuredClone(largest);
      fieldLowland.formatVersion = formatVersion;
      fieldLowland.elevation.minimumLevel = -10;
      fieldLowland.elevation.maximumLevel = -10;
      fieldLowland.elevation.maximumRise = 0;
      fieldLowland.elevation.levelStep = 1000;
      fieldLowland.elevation.levels.fill(-10);
      fieldLowland.layers.forEach((layer, index) =>
        layer.fill(index === 0 ? 'meadow' : 'empty'),
      );
      const wetCells = [];
      for (let z = 0; z < fieldLowland.size; z++) {
        for (let x = 0; x < fieldLowland.size; x++) {
          if (buildingDatum(fieldLowland, x, z) < 0.101) {
            wetCells.push({ x, z });
          }
        }
      }
      assert.ok(wetCells.length > 0, `Format ${formatVersion} fixture has wet field cells`);
      const wetCell = wetCells[Math.floor(wetCells.length / 2)];
      const fieldLowlandBefore = JSON.stringify(fieldLowland);
      for (const operation of ['cabin', 'castle', 'modern', 'scifi', 'rocket']) {
        const refused = await solve({
          size: 48,
          seed: 731,
          operation,
          x: wetCell.x,
          z: wetCell.z,
          width: 1,
          depth: 1,
          previous: fieldLowland,
        });
        assert.equal(
          refused.success,
          false,
          `Format ${formatVersion} underwater building request is refused`,
        );
        assert.match(refused.message, /safe building height/);
        assert.equal(refused.world, undefined, 'A refused building must not silently become empty');
        assert.equal(
          JSON.stringify(fieldLowland),
          fieldLowlandBefore,
          `Format ${formatVersion} refusal preserves the baseline`,
        );
      }
      const submerged = structuredClone(fieldLowland);
      const wetIndex = wetCell.z * fieldLowland.size + wetCell.x;
      submerged.layers[1][wetIndex] = 'cabin';
      submerged.layers[3][wetIndex] = 'cabin';
      const wetRestore = await solve({
        size: 48,
        seed: 731,
        operation: 'restore',
        x: 0,
        z: 0,
        width: 48,
        depth: 48,
        previous: submerged,
      });
      assert.equal(
        wetRestore.success,
        false,
        `Saved format ${formatVersion} underwater building rejected independently`,
      );
      assert.match(wetRestore.message, /safe standing height/);
    }
    for (const operation of [
      'forest',
      'flowers',
      'field',
      'cabin',
      'castle',
      'modern',
      'scifi',
      'water',
      'clear',
    ]) {
      const request = {
        size: 12,
        seed: 732,
        operation,
        x: 5,
        z: 5,
        width: 2,
        depth: 2,
        previous: baseline,
      };
      const result = await solve(request);
      assert.equal(result.success, true, `${operation}: ${result.message}`);
      for (let layer = 0; layer < 5; layer++) {
        const pitch = layer === 2 || layer === 4 ? 2 : 1;
        const side = 12 * pitch;
        for (let index = 0; index < side * side; index++) {
          const x = Math.floor((index % side) / pitch);
          const z = Math.floor(Math.floor(index / side) / pitch);
          const selected = x >= 5 && x < 7 && z >= 5 && z < 7;
          if (!selected) {
            assert.equal(
              result.world.layers[layer][index],
              baseline.layers[layer][index],
              'All cells outside selection remain identical',
            );
          } else if (['cabin', 'castle', 'modern', 'scifi'].includes(operation)) {
            if (layer === 1) {
              assert.equal(result.world.layers[layer][index], operation);
            }
            if (layer === 2 || layer === 4) {
              assert.equal(
                result.world.layers[layer][index],
                'empty',
                'Entire building footprint is clear in finer layers',
              );
            }
          } else if (operation === 'flowers' && layer === 2) {
            assert.equal(result.world.layers[layer][index], 'flowers');
          }
        }
      }
    }
    const water = await solve({
      size: 4,
      seed: 42,
      operation: 'water',
      x: 0,
      z: 0,
      width: 4,
      depth: 4,
      previous: null,
    });
    assert.equal(water.success, true);
    const incompatible = await solve({
      size: 4,
      seed: 43,
      operation: 'forest',
      x: 1,
      z: 1,
      width: 1,
      depth: 1,
      previous: water.world,
    });
    assert.equal(
      incompatible.success,
      false,
      'A forest directly against a frozen water boundary must fail',
    );
    assert.equal(incompatible.world, undefined, 'Failure does not publish a replacement');
    const restored = await solve({
      size: 12,
      seed: baseline.seed,
      operation: 'restore',
      x: 0,
      z: 0,
      width: 12,
      depth: 12,
      previous: baseline,
    });
    assert.equal(restored.success, true);
    assert.deepEqual(
      restored.world.layers,
      baseline.layers,
      'Restore preserves all saved layers exactly',
    );
    const corrupt = structuredClone(baseline);
    corrupt.layers[3][0] = 'unregistered/asset';
    const rejected = await solve({
      size: 12,
      seed: 731,
      operation: 'restore',
      x: 0,
      z: 0,
      width: 12,
      depth: 12,
      previous: corrupt,
    });
    assert.equal(
      rejected.success,
      false,
      'Unregistered imported geometry is rejected before rendering',
    );
    const fractional = await solve({
      size: 4.5,
      seed: 1,
      operation: 'create',
      x: 0,
      z: 0,
      width: 4,
      depth: 4,
      previous: null,
    });
    assert.equal(
      fractional.success,
      false,
      'Fractional dimensions are rejected at the worker boundary',
    );
    const truncated = structuredClone(baseline);
    truncated.layers[2].pop();
    const truncatedResult = await solve({
      size: 12,
      seed: 731,
      operation: 'restore',
      x: 0,
      z: 0,
      width: 12,
      depth: 12,
      previous: truncated,
    });
    assert.equal(
      truncatedResult.success,
      false,
      'Incomplete saved layers are rejected before construction',
    );
    const plotBaseline = structuredClone(baseline);
    plotBaseline.layers.forEach((layer, index) => layer.fill(index === 0 ? 'meadow' : 'empty'));
    const plotRequest = {
      size: 12,
      seed: 841,
      operation: 'launch-pad',
      x: 5,
      z: 5,
      width: 2,
      depth: 2,
      previous: plotBaseline,
      groundworkTurn: -1,
      groundworkBody: 'piers',
    };
    const plot = await solve(plotRequest);
    assert.equal(plot.success, true, plot.message);
    assert.equal(plot.world.composition.revision, plotBaseline.composition.revision + 1);
    assert.equal(plot.world.composition.nodes.length, 19);
    assert.deepEqual(
      plot.world.layers,
      plotBaseline.layers,
      'Prepared plot preserves regional cells',
    );
    const plotId = 'site-5-5';
    const panelId = `${plotId}.deck.panel-0`;
    const panel = await solve({
      ...plotRequest,
      operation: 'groundwork',
      previous: plot.world,
      objectId: panelId,
      seed: 842,
    });
    assert.equal(panel.success, true, panel.message);
    assert.deepEqual(panel.world.layers, plot.world.layers);
    for (const node of plot.world.composition.nodes) {
      const next = panel.world.composition.nodes.find((item) => item.id === node.id);
      if (node.id === panelId) {
        assert.notEqual(next.asset, node.asset, 'Reimagine produces a real panel alternative');
      } else {
        assert.deepEqual(next, node, 'Unselected plot parts remain exact');
      }
    }
    const plotRestore = await solve({
      ...plotRequest,
      operation: 'restore',
      previous: panel.world,
    });
    assert.equal(plotRestore.success, true, plotRestore.message);
    assert.deepEqual(plotRestore.world.composition, panel.world.composition);
    const badPlot = structuredClone(panel.world);
    badPlot.composition.nodes.find((node) => node.id === `${plotId}.deck.core`).x += 1;
    const refusedPlot = await solve({ ...plotRequest, operation: 'restore', previous: badPlot });
    assert.equal(
      refusedPlot.success,
      false,
      'Imported groundwork geometry is independently admitted',
    );
    assert.equal(refusedPlot.world, undefined);
    for (const invalidOptions of [
      { groundworkTurn: null },
      { groundworkTurn: 4 },
      { groundworkTurn: 0.5 },
      { groundworkBody: null },
      { groundworkBody: 'unknown' },
    ]) {
      const invalid = await solve({ ...plotRequest, ...invalidOptions });
      assert.equal(
        invalid.success,
        false,
        'Invalid groundwork options reject at the worker boundary',
      );
      assert.equal(invalid.world, undefined);
    }
    const partialPlotClear = await solve({
      ...plotRequest,
      operation: 'clear',
      previous: panel.world,
      width: 1,
    });
    assert.equal(partialPlotClear.success, false, 'Partial groundwork removal rejects');
    const clearedPlot = await solve({ ...plotRequest, operation: 'clear', previous: panel.world });
    assert.equal(clearedPlot.success, true, clearedPlot.message);
    assert.equal(clearedPlot.world.composition.nodes.length, 1);
    assert.equal(clearedPlot.world.composition.revision, panel.world.composition.revision + 1);

    fs.writeFileSync(
      path.join(__dirname, '../build/world-evidence.json'),
      JSON.stringify(
        {
          passed: true,
          checks: [
            'determinism',
            'regional brushes',
            'exact frozen surroundings',
            'complete fine-grid footprint clearance',
            'failed edit rejection',
            'exact restore',
            'invalid asset rejection',
            'saved elevation x-z triangle contract',
            'physical dry datums for legacy, absolute and relative elevation worlds',
            'explicit underwater request and submerged restore rejection',
            'atomic groundwork creation and one-panel preservation',
            'groundwork restore, physical admission and option validation',
            'whole-plot clear and partial-clear rejection',
          ],
          scaling: evidence,
        },
        null,
        2,
      ) + '\n',
    );
    console.log('World generation, scoped preservation, failure and restore checks passed.');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
