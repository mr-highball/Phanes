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

const byId = (id) => document.getElementById(id);
const state = {
  world: null,
  palette: null,
  job: 0,
  worker: null,
  history: [],
  future: [],
  selection: { x: 0, z: 0, width: 1, depth: 1 },
  editing: true,
  camera: 'top',
  zoom: 1,
  yaw: 0.7,
  pitch: -0.2,
  x: 0,
  y: 12,
  z: 20,
  panX: 0,
  panZ: 0,
  panY: 0,
  interiorRoom: '',
  interiorSelected: '',
  interiorAssets: [],
  ready: false,
};
window.phanesEditor = state;
window.phanesSceneVersion = 0;
window.phanesSelectionVersion = 0;
window.phanesCameraVersion = 0;
window.phanesPickVersion = 0;
window.phanesPickX = 0;
window.phanesPickY = 0;
window.phanesPickSceneVersion = 0;
window.phanesPickCameraVersion = 0;
window.phanesPickAction = '';
window.phanesGroundworkSelection = '{}';
window.phanesGroundworkSelectionVersion = 0;
window.phanesGroundworkActive = false;
window.phanesMoveInput = '{}';
window.phanesPendingChunks = 0;
window.phanesSelection = JSON.stringify({ visible: false });
window.phanesInterior = '{}';
window.phanesInteriorVersion = 0;
let workerStarted = 0;
let anchor = null;
let dragging = false;
let lastPointer = null;
let orbitDragging = false;
let pointerStart = null;
let activePointerId = null;
let pointerMoved = false;

const pickActions = new Map();

function notify(message, error = false) {
  const toast = byId('toast');
  toast.textContent = message;
  toast.classList.toggle('error', error);
  toast.hidden = false;
  clearTimeout(notify.timer);
  notify.timer = setTimeout(() => (toast.hidden = true), error ? 12000 : 4500);
}

function updateControls() {
  const blocked = Boolean(state.worker) || Boolean(window.phanesRecovering);
  const busy = blocked || Boolean(window.phanesCatalogLoading);
  document.querySelectorAll('[data-intent]').forEach((button) => {
    button.disabled = !state.world || blocked;
  });
  for (const id of ['save-world', 'edit-toggle', 'reimagine', 'clear-region', 'select-all']) {
    byId(id).disabled = !state.world || blocked;
  }
  byId('undo').disabled = !state.history.length || blocked;
  byId('redo').disabled = !state.future.length || blocked;
  byId('busy').hidden = !busy;
  byId('create-world').disabled = !state.ready || !state.palette || blocked ||
    document.body.dataset.startupState !== 'ready';
  byId('import-world').disabled = !state.ready || !state.palette || blocked ||
    document.body.dataset.startupState !== 'ready';
  document.body.dataset.solving = String(busy);
  window.phanesInteriorUI?.refresh();
  window.phanesGroundworkUI?.refresh();
  window.phanesNavigationUI?.refresh();
  window.phanesAuthoringUI?.refresh();
  window.phanesCatalogUI?.refresh();
  window.phanesBuildingUI?.refresh();
  window.phanesLandformUI?.refresh();
}

function syncSelection() {
  window.phanesGroundworkUI?.normalizeSelection();
  window.phanesGroundworkUI?.sendSelection();
  window.phanesAuthoringUI?.refresh();
  const selection = state.selection;
  window.phanesSelection = JSON.stringify({
    ...selection,
    visible:
      !!state.world &&
      state.editing &&
      !state.interiorRoom &&
      !window.phanesGroundworkHasPlot &&
      (!selection.selectionCells || selection.selectionCells.length > 0),
  });
  window.phanesSelectionVersion++;
  byId('selection-size').textContent = `${selection.width} × ${selection.depth} region cells`;
  byId('selection-description').textContent =
    `${selection.width * 16} × ${selection.depth * 16} metres · choose what belongs here`;
  window.phanesInteriorUI?.refresh();
  window.phanesGroundworkUI?.refresh();
  window.phanesAuthoringUI?.refresh();
  window.phanesCatalogUI?.refresh();
  window.phanesBuildingUI?.refresh();
  window.phanesLandformUI?.refresh();
}

function syncCamera() {
  window.phanesViewportCssHeight = canvas.clientHeight;
  const span = state.interiorRoom ? 11 : (state.world?.size || 12) * 16;
  let camera;
  if (state.camera === 'top') {
    const aspect = canvas.clientWidth / Math.max(1, canvas.clientHeight);
    camera = {
      orthographic: true,
      span: (span * Math.max(1.18, 1.18 / aspect)) / state.zoom,
      position: [state.panX, span * 2, state.panZ],
      target: [state.panX, state.panY, state.panZ],
      up: [0, 0, -1],
    };
  } else if (state.camera === 'orbit') {
    const aspect = canvas.clientWidth / Math.max(1, canvas.clientHeight);
    const distance = (span * 1.25 * Math.max(1, 1 / aspect)) / state.zoom;
    const elevation = Math.max(0.18, Math.min(1.4, 0.65 + state.pitch));
    camera = {
      orthographic: false,
      span,
      position: [
        state.panX + Math.sin(state.yaw) * distance * Math.cos(elevation),
        state.panY + distance * Math.sin(elevation),
        state.panZ + Math.cos(state.yaw) * distance * Math.cos(elevation),
      ],
      target: [state.panX, state.panY, state.panZ],
      up: [0, 1, 0],
    };
  } else {
    const y = state.y;
    camera = {
      orthographic: false,
      span,
      position: [state.x, y, state.z],
      target: [
        state.x + Math.sin(state.yaw) * Math.cos(state.pitch),
        y + Math.sin(state.pitch),
        state.z - Math.cos(state.yaw) * Math.cos(state.pitch),
      ],
      up: [0, 1, 0],
    };
  }
  camera.mode = state.camera;
  camera.focusX = ['top', 'orbit'].includes(state.camera) ? state.panX : state.x;
  camera.focusZ = ['top', 'orbit'].includes(state.camera) ? state.panZ : state.z;
  window.phanesCamera = JSON.stringify(camera);
  window.phanesCameraVersion++;
}

function cancelPointer() {
  window.phanesAuthoringUI?.cancel();
  dragging = false;
  orbitDragging = false;
  lastPointer = null;
  pointerStart = null;
  activePointerId = null;
  pointerMoved = false;
  anchor = null;
  pickActions.clear();
  window.phanesPickAction = '';
  window.phanesPickVersion++;
}

function setCamera(mode) {
  cancelPointer();
  state.camera = mode;
  syncSelection();
  document.querySelectorAll('[data-camera]').forEach((button) => {
    const selected = button.dataset.camera === mode;
    button.classList.toggle('active', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
  byId('crosshair').hidden = mode !== 'walk' && mode !== 'fly';

  byId('interaction-hint').textContent =
    mode === 'top'
      ? 'Drag to select · scroll to zoom · G to reimagine'
      : mode === 'orbit'
        ? 'Drag to orbit · scroll to zoom · 1 for overhead selection'
        : mode === 'walk'
          ? 'WASD or movement pad · drag to look · Shift to run'
          : 'WASD to fly · drag to look · Q/E to rise or descend';
  window.phanesNavigationUI?.refresh();
  window.phanesAuthoringUI?.refresh();
  window.phanesCatalogUI?.refresh();
  syncCamera();
  window.phanesBuildingUI?.refresh();
  window.phanesLandformUI?.refresh();
}

function publish(world, remember = true) {
  cancelPointer();
  clearTimeout(notify.timer);
  byId('toast').hidden = true;
  if (remember && state.world) {
    state.history.push(state.world);
    if (state.history.length > 30) {
      state.history.shift();
    }
  }
  if (remember) {
    state.future = [];
  }
  state.world = world;
  window.phanesInteriorUI?.onWorld();
  window.phanesGroundworkUI?.onWorld();
  window.phanesBuildingUI?.onWorld();
  state.selection.x = Math.min(state.selection.x, world.size - 1);
  state.selection.z = Math.min(state.selection.z, world.size - 1);
  state.selection.width = Math.min(state.selection.width, world.size - state.selection.x);
  state.selection.depth = Math.min(state.selection.depth, world.size - state.selection.z);
  window.phanesScene = JSON.stringify(world);
  window.phanesSceneVersion++;
  byId('welcome').hidden = true;
  byId('status').textContent = 'World ready';
  byId('world-name').textContent = `World ${world.seed}`;
  byId('world-stats').textContent =
    `${world.size * 16} × ${world.size * 16} metres · 5 layers · ${world.decisions.toLocaleString()} WFC decisions`;
  document.body.dataset.worldReady = 'true';
  syncSelection();
  syncCamera();
  setCamera(state.camera);
  updateControls();
  window.dispatchEvent(new Event('phanes-world-published'));
}

function prepareWorld(world, callback) {
  if (!window.phanesCatalogRuntime) {
    return Promise.resolve(false);
  }
  return window.phanesCatalogRuntime.publish(world, callback);
}

function cancelSolve() {
  if (state.worker) {
    state.worker.terminate();
    state.worker = null;
    state.job++;
  }
  window.phanesCatalogRuntime?.cancel();
  byId('status').textContent = state.world ? 'World unchanged' : 'Ready to create';
  updateControls();
}

function generate(operation, imported = null, options = {}) {
  if (window.phanesNavigationUI && !window.phanesNavigationUI.canGenerate(operation)) {
    return;
  }
  if (!state.ready || !state.palette || state.worker ||
      document.body.dataset.startupState !== 'ready') {
    return;
  }
  const size =
    operation === 'create' ? Number(byId('region-size').value) : (imported || state.world).size;
  const seed = imported
    ? imported.seed
    : operation === 'create'
      ? Number(byId('world-seed').value)
      : (state.world.seed + 1) >>> 0;
  if (
    !Number.isInteger(size) ||
    size < 4 ||
    size > 48 ||
    !Number.isInteger(seed) ||
    seed < 0 ||
    seed > 4294967295
  ) {
    notify('Choose a valid region size and unsigned seed.', true);
    return;
  }
  const selection =
    operation === 'create' || imported ? { x: 0, z: 0, width: size, depth: size } : state.selection;
  const editRequest = window.phanesAuthoringUI
    ? window.phanesAuthoringUI.request(operation, selection, options)
    : { ...options, ...selection };
  if (!editRequest) return;
  window.phanesCatalogRuntime?.cancel();
  const worker = new Worker('world-worker.js');
  state.worker = worker;
  const job = ++state.job;
  workerStarted = performance.now();
  worker.onmessage = ({ data }) => {
    if (state.worker !== worker || job !== state.job || data.job !== job) {
      return;
    }
    state.worker.terminate();
    state.worker = null;
    if (data.success) {
      if (data.unchanged) {
        notify(data.message || 'The selected land already meets these constraints.');
        byId('status').textContent = 'World unchanged';
        document.body.dataset.lastSolve = 'unchanged';
        updateControls();
        return;
      }
      data.world.solveMilliseconds = Math.round(performance.now() - workerStarted);
      prepareWorld(data.world, () => {
        if (operation === 'create' || imported) {
          state.selection = {
            x: Math.floor(size / 2) - 1,
            z: Math.floor(size / 2) - 1,
            width: 1,
            depth: 1,
          };
        }
        state.interiorAssets = data.interiorAssets || [];
        publish(data.world);
        if (['create-interior', 'create-plan'].includes(operation)) {
          if (options.objectId) {
            window.phanesInteriorUI?.openBuilding(options.objectId);
          } else {
            window.phanesInteriorUI?.openSelected();
          }
        }
        if (operation === 'room-purpose') {
          window.phanesInteriorUI?.choose(options.objectId, true);
        }
        notify(
          operation.startsWith('land-') ? data.message : [
            'create-interior',
            'create-plan',
            'room-purpose',
            'room-reimagine',
            'rename-space',
            'contents',
          ].includes(operation)
            ? 'Your interior is ready. Surrounding objects were preserved.'
            : `Created in ${data.world.solveMilliseconds} ms. World validated.`,
        );
        document.body.dataset.lastSolve = 'passed';
        updateControls();
      });
    } else {
      notify(data.message, true);
      byId('status').textContent = 'Try another possibility · world unchanged';
      document.body.dataset.lastSolve = 'failed';
    }
    updateControls();
  };
  worker.onerror = (event) => {
    if (state.worker !== worker || job !== state.job) {
      return;
    }
    cancelSolve();
    notify(`The generator stopped: ${event.message}`, true);
  };
  worker.postMessage({
    ...editRequest,
    job,
    operation,
    size,
    seed,
    assets: state.palette.assets,
    previous: operation === 'create' ? null : imported || state.world,
  });
  byId('status').textContent = 'Resolving your world…';
  updateControls();
}

window.phanesWorldRendered = (revision) => {
  document.body.dataset.renderedRevision = String(revision);
};

window.phanesRenderMetrics = (chunks, resident, pending, builds, maxChunkMs, ssao) => {
  window.phanesPendingChunks = pending;
  window.phanesRenderState = { chunks, resident, pending, builds, maxChunkMs, ssao };
};
window.phanesAppearanceReady = (palette, key, atmosphere, finish, seed) => {
  window.phanesAppearanceState = { palette, key, atmosphere, finish, seed };
};
window.phanesPlayerPosition = (x, y, z, ground) => {
  Object.assign(state, { x, y, z });
  window.phanesPlayerState = { x, y, z, ground, eyeHeight: y - ground };
};
window.phanesNavigationBlocked = () => {
  setCamera('fly');
  notify('No clear ground here. Fly to explore, or create a patch of land.');
};

window.phanesPicked = (worldX, worldZ, version) => {
  const action = pickActions.get(version);
  pickActions.delete(version);
  if (!state.world || !state.editing || !action || version !== window.phanesPickVersion) {
    return;
  }
  const size = state.world.size;
  const x = Math.min(size - 1, Math.max(0, Math.floor((worldX + size * 8) / 16)));
  const z = Math.min(size - 1, Math.max(0, Math.floor((worldZ + size * 8) / 16)));
  if (action === 'start' || !anchor) {
    anchor = { x, z };
  }
  state.selection = {
    x: Math.min(x, anchor.x),
    z: Math.min(z, anchor.z),
    width: Math.abs(x - anchor.x) + 1,
    depth: Math.abs(z - anchor.z) + 1,
  };
  syncSelection();
  if (action === 'end' || action === 'region-end') {
    anchor = null;
  }
};

function pick(event, action) {
  const bounds = canvas.getBoundingClientRect();
  window.phanesPickX = (event.clientX - bounds.left) / bounds.width;
  window.phanesPickY = (event.clientY - bounds.top) / bounds.height;
  window.phanesPickSceneVersion = window.phanesSceneVersion;
  window.phanesPickCameraVersion = window.phanesCameraVersion;
  window.phanesPickAction = action;
  pickActions.clear();
  pickActions.set(++window.phanesPickVersion, action);
}

canvas.addEventListener('contextmenu', (event) => event.preventDefault());

byId('create-form').addEventListener('submit', (event) => {
  event.preventDefault();
  generate('create');
});
document
  .querySelectorAll('[data-camera]')
  .forEach((button) => button.addEventListener('click', () => setCamera(button.dataset.camera)));
byId('reimagine').onclick = () => generate('reimagine');
byId('clear-region').onclick = () => generate('clear');
byId('cancel').onclick = cancelSolve;
byId('undo').onclick = () => {
  if (state.history.length && !state.worker) {
    const target = state.history[state.history.length - 1];
    prepareWorld(target, () => {
      state.future.push(state.world);
      state.history.pop();
      publish(target, false);
    });
  }
};
byId('redo').onclick = () => {
  if (state.future.length && !state.worker) {
    const target = state.future[state.future.length - 1];
    prepareWorld(target, () => {
      state.history.push(state.world);
      state.future.pop();
      publish(target, false);
    });
  }
};
byId('reset-camera').onclick = () => {
  if (state.interiorRoom) {
    window.phanesInteriorUI.resetCamera();
    return;
  }
  state.zoom = 1;
  state.panX = 0;
  state.panY = 0;
  state.panZ = 0;
  state.x = 0;
  state.z = (state.world?.size || 12) * 2;
  state.y = 12;
  state.yaw = 0.7;
  syncCamera();
};
byId('zoom-in').onclick = () => {
  state.zoom = Math.min(state.interiorRoom ? 64 : (window.phanesModularZoomLimit || 12), state.zoom * 1.25);
  syncCamera();
};
byId('zoom-out').onclick = () => {
  state.zoom = Math.max(0.4, state.zoom / 1.25);
  syncCamera();
};
byId('region-size').oninput = () => {
  const size = Number(byId('region-size').value) * 16;
  byId('size-hint').textContent = `${size} × ${size} metres · 16 metres per region cell`;
};
document.addEventListener('keydown', (event) => {
  if (
    event.target.matches('input, textarea, select') ||
    event.target.closest('#audio-panel') ||
    document.querySelector('dialog[open]')
  ) {
    return;
  }

  if (['1', '2', '3', '4'].includes(event.key)) {
    setCamera(['top', 'orbit', 'fly', 'walk'][Number(event.key) - 1]);
  }
  if (event.key === 'Tab' && !event.shiftKey && state.world && event.target === canvas) {
    event.preventDefault();
    byId('edit-toggle').click();
  }
  if (event.key.toLowerCase() === 'g' && state.world && state.editing && !event.repeat) {
    if (state.interiorRoom) {
      byId('interior-reimagine').click();
    } else if (document.body.dataset.groundworks === 'true') {
      byId('groundwork-reimagine').click();
    } else {
      generate('reimagine');
    }
  }
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
    event.preventDefault();
    byId(event.shiftKey ? 'redo' : 'undo').click();
  }
});
new ResizeObserver(syncCamera).observe(canvas);
syncCamera();
updateControls();

window.phanesEditorActions = {
  publish,
  prepareWorld,
  cancelSolve,
  updateControls,
  generate,
  setCamera,
  syncCamera,
  syncSelection,
  cancelPointer,
  pick,
  notify,
};

fetch('data/palette.json')
  .then((response) => {
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return response.json();
  })
  .then((palette) => {
    state.palette = palette;
    window.phanesPalette = JSON.stringify(palette);
    window.dispatchEvent(new Event('phanes-palette-ready'));
    byId('kit-count').textContent = `${palette.assets.length} regional choices`;
    updateControls();
    fetch('data/catalog-summary.json')
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then((summary) => {
        byId('kit-count').textContent =
          `${summary.importedModels} source pieces · ${palette.assets.length} regional choices`;
      })
      .catch(() => {
        // The source count is optional; it must not block the creation tools.
      });
  })
  .catch((error) => window.phanesStartup.fail(`Could not load the kit library: ${error.message}`));

window.addEventListener('phanes-ready', () => {
  state.ready = true;
  updateControls();
});

window.addEventListener('phanes-startup-failed', updateControls);
window.addEventListener('phanes-startup-ready', updateControls);
