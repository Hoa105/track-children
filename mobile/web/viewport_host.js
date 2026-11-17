(function (browser) {
  'use strict';
  const hosts = new WeakMap();
  const subscribers = new Set();
  let visibleHeight = 1;
  function positive(...values) {
    return values.find(value => Number.isFinite(value) && value > 0) ?? 1;
  }
  function attach(host) {
    if (!host) throw new Error('Flutter viewport host is missing.');
    hosts.get(host)?.();
    const viewport = browser.visualViewport;
    const root = browser.document.documentElement;
    let frame = null;
    let disposed = false;
    function update() {
      frame = null;
      if (disposed) return;
      // Read all dimensions together. Keyboard dismissal, orientation changes
      // and browser chrome/zoom changes can emit several events in one frame.
      // Keep layout size separate from the keyboard/zoom's visual viewport.
      // Flutter supplies zero engine insets for an embedded host; the Dart
      // adapter applies the visible-height difference to MediaQuery instead.
      host.style.width = `${positive(root.clientWidth, browser.innerWidth, viewport?.width)}px`;
      host.style.height = `${positive(root.clientHeight, browser.innerHeight, viewport?.height)}px`;
      // Pinch zoom alone must not be mistaken for the on-screen keyboard.
      visibleHeight = positive(viewport?.height * positive(viewport?.scale, 1), browser.innerHeight, root.clientHeight);
      for (const subscriber of subscribers) subscriber();
    }
    function schedule() {
      if (frame === null && !disposed) frame = browser.requestAnimationFrame(update);
    }
    const listeners = [
      [browser, 'resize'], [browser, 'orientationchange'], [browser, 'pageshow'],
      ...(viewport ? [[viewport, 'resize'], [viewport, 'scroll']] : []),
    ];
    for (const [target, event] of listeners) target.addEventListener(event, schedule);
    update();
    function dispose() {
      disposed = true;
      if (frame !== null) browser.cancelAnimationFrame(frame);
      for (const [target, event] of listeners) target.removeEventListener(event, schedule);
      hosts.delete(host);
    }
    hosts.set(host, dispose);
    return dispose;
  }
  browser.trackChildrenViewport = {
    attach,
    get visibleHeight() { return visibleHeight; },
    subscribe(listener) { subscribers.add(listener); return () => subscribers.delete(listener); },
  };
})(window);
