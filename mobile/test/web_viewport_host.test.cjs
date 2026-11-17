const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const web = path.join(__dirname, '../web');

function target(values = {}) {
  const events = new Map();
  return Object.assign(values, {
    addEventListener(name, fn) {
      if (!events.has(name)) events.set(name, new Set());
      events.get(name).add(fn);
    },
    removeEventListener(name, fn) { events.get(name)?.delete(fn); },
    emit(name) { for (const fn of events.get(name) ?? []) fn(); },
    listenerCount() { return [...events.values()].reduce((n, set) => n + set.size, 0); },
  });
}
function fixture(withViewport = true) {
  const frames = new Map();
  let id = 0;
  const host = {style: {}};
  const browser = target({
    innerWidth: 390, innerHeight: 844,
    document: {documentElement: {clientWidth: 390, clientHeight: 844}},
    requestAnimationFrame(fn) { frames.set(++id, fn); return id; },
    cancelAnimationFrame(key) { frames.delete(key); },
    visualViewport: withViewport ? target({width: 390, height: 844, offsetLeft: 0, offsetTop: 0}) : undefined,
  });
  vm.runInNewContext(fs.readFileSync(path.join(web, 'viewport_host.js'), 'utf8'), {window: browser});
  return {host, browser, frames, flush() {
    const pending = [...frames.values()]; frames.clear(); pending.forEach(fn => fn());
  }};
}

test('keyboard open/close keeps layout stable and publishes visible height, including growth', () => {
  const f = fixture();
  f.browser.trackChildrenViewport.attach(f.host);
  assert.equal(f.host.style.height, '844px');
  for (const height of [460, 430, 600, 844, 900]) {
    f.browser.visualViewport.height = height;
    f.browser.visualViewport.emit('resize'); f.flush();
    assert.equal(f.host.style.height, '844px');
    assert.equal(f.browser.trackChildrenViewport.visibleHeight, height);
    assert.ok(parseFloat(f.host.style.height) > 0);
  }
});
test('rotation uses layout dimensions; zoom/pan do not resize layout a second time', () => {
  const f = fixture(); f.browser.trackChildrenViewport.attach(f.host);
  Object.assign(f.browser.visualViewport, {width: 844, height: 390, offsetTop: 18});
  Object.assign(f.browser.document.documentElement, {clientWidth: 844, clientHeight: 390});
  f.browser.emit('orientationchange');
  f.browser.visualViewport.emit('resize'); f.browser.visualViewport.emit('scroll');
  assert.equal(f.frames.size, 1);
  Object.assign(f.browser.visualViewport, {width: 422, height: 195, scale: 2, offsetLeft: 40});
  f.flush();
  assert.equal(f.host.style.width, '844px');
  assert.equal(f.host.style.height, '390px');
  assert.equal(f.browser.trackChildrenViewport.visibleHeight, 390);
});
test('invalid transient viewport measurements fall back to valid document dimensions', () => {
  const f = fixture(); f.browser.trackChildrenViewport.attach(f.host);
  Object.assign(f.browser.visualViewport, {width: -1, height: NaN, offsetLeft: -5, offsetTop: -12});
  f.browser.visualViewport.emit('resize'); f.flush();
  assert.equal(f.host.style.width, '390px'); assert.equal(f.host.style.height, '844px');
  f.browser.innerWidth = 0; f.browser.innerHeight = Infinity;
  f.browser.emit('resize'); f.flush();
  assert.equal(f.host.style.height, '844px');
});
test('browsers without visualViewport resize with inner dimensions', () => {
  const f = fixture(false); f.browser.trackChildrenViewport.attach(f.host);
  f.browser.innerHeight = 500; f.browser.emit('resize'); f.flush();
  assert.equal(f.browser.trackChildrenViewport.visibleHeight, 500);
});
test('reattach does not duplicate listeners; disposing cancels pending updates', () => {
  const f = fixture(); f.browser.trackChildrenViewport.attach(f.host);
  const count = f.browser.listenerCount();
  const dispose = f.browser.trackChildrenViewport.attach(f.host);
  assert.equal(f.browser.listenerCount(), count);
  f.browser.emit('resize'); dispose();
  assert.equal(f.frames.size, 0); assert.equal(f.browser.listenerCount(), 0);
  assert.equal(f.browser.visualViewport.listenerCount(), 0);
});
test('subscribers are notified after measurements and can unsubscribe', () => {
  const f = fixture(); f.browser.trackChildrenViewport.attach(f.host);
  const heights = [];
  const cancel = f.browser.trackChildrenViewport.subscribe(() => heights.push(f.browser.trackChildrenViewport.visibleHeight));
  f.browser.visualViewport.height = 400; f.browser.visualViewport.emit('resize'); f.flush();
  cancel();
  f.browser.visualViewport.height = 844; f.browser.visualViewport.emit('resize'); f.flush();
  assert.deepEqual(heights, [400]);
});
test('Flutter bootstrap configures the measured host before loading the engine', () => {
  const f = fixture();
  let loaded = false;
  const code = fs.readFileSync(path.join(web, 'flutter_bootstrap.js'), 'utf8')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  vm.runInNewContext(code, {window: f.browser,
    document: {getElementById: () => f.host},
    _flutter: {loader: {load({config}) {
      assert.equal(config.hostElement, f.host);
      assert.equal(f.host.style.height, '844px'); loaded = true;
    }}},
  });
  assert.ok(loaded);
});
