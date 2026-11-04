// Execute the actual generated engine resize handler with controlled viewport
// metrics. This tests the backport, rather than a second copy of its formula.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sdk = path.resolve(__dirname,
  '../.dart_tool/web_engine/src/out/keyboard_fix/flutter_web_sdk');
const source = fs.readFileSync(path.join(sdk,
  'kernel/ddclibrarybundle-canvaskit/dart_sdk.js'), 'utf8');
const match = source.match(/\[_handleBrowserResize\]\([^)]*\) \{([\s\S]*?)\n    \}/);
assert.ok(match, 'Could not find the compiled resize handler');
const names = ['_engine', '_computePhysicalSize', '_shouldPreservePhysicalSizeOnResize',
  '_isRotation', '_physicalSize', '_computeOnScreenKeyboardInsets'];
const resize = new Function(...names, `return function() {${match[1]}}`)(
  {StyleManager: {scaleSemanticsHost() {}}}, ...names.slice(1));

function scenario(name, initial, next, editing, rotating, expectedHeight, expectedInset) {
  let inset;
  let notifications = 0;
  const view = {
    dom: {semanticsHost: {}}, devicePixelRatio: 1,
    _physicalSize: initial,
    get physicalSize() { return this._physicalSize; },
    _computePhysicalSize: () => next,
    _shouldPreservePhysicalSizeOnResize: editing,
    _isRotation: () => rotating,
    _computeOnScreenKeyboardInsets() {
      inset = this._physicalSize.height - next.height;
      assert.ok(inset >= 0, 'ViewInsets cannot be negative');
    },
    platformDispatcher: {invokeOnMetricsChanged() { notifications++; }},
  };
  resize.call(view);
  assert.equal(view.physicalSize.height, expectedHeight, name);
  assert.equal(inset, expectedInset, name);
  assert.equal(notifications, 1, name);
  console.log(`PASS ${name}`);
}
scenario('keyboard opens', {width: 390, height: 844}, {width: 390, height: 500},
  true, false, 844, 344);
scenario('keyboard closes while editing with stale size',
  {width: 390, height: 500}, {width: 390, height: 844}, true, false, 844, 0);
scenario('viewport grows while changing input keyboards',
  {width: 390, height: 500}, {width: 390, height: 560}, true, false, 560, 0);
scenario('regular resize', {width: 390, height: 844}, {width: 390, height: 600},
  false, false, 600, 0);
scenario('rotation while editing', {width: 390, height: 844}, {width: 844, height: 390},
  true, true, 390, 0);
