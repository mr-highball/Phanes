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

const canvas = document.getElementById('castle-canvas');

// Phanes owns keyboard navigation through its DOM bridge and Pascal controller.
// Castle renders the scene and has no keyboard navigation component. Consume both
// halves here so its window listeners cannot receive unmatched DOM-control keys.
for (const name of ['keydown', 'keyup']) {
  document.addEventListener(name, (event) => event.stopPropagation());
}

window.phanesReady = function () {
  document.body.dataset.ready = 'true';
  window.dispatchEvent(new Event('phanes-ready'));
};

window.addEventListener('load', () => {
  rtl.showUncaughtExceptions = true;
  rtl.run();
});
