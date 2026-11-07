// Run after: flutter build web --debug --output=build/web-viewport-debug
// Uses an isolated headless Chrome profile; never touches the user's browser.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../build/web-viewport-debug');
const mime = {'.js': 'text/javascript', '.html': 'text/html', '.wasm': 'application/wasm',
  '.json': 'application/json', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png'};
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(fn, message) {
  for (let i = 0; i < 150; i++) { const result = await fn(); if (result) return result; await pause(200); }
  throw new Error(message);
}
(async () => {
  const server = http.createServer((req, res) => {
    const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = path.resolve(root, `.${name === '/' ? '/index.html' : name}`);
    if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
    fs.readFile(file, (error, bytes) => {
      if (error) { res.writeHead(404).end(); return; }
      res.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream'); res.end(bytes);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const profile = fs.mkdtempSync(path.resolve(__dirname, '../build/viewport-chrome-'));
  const browser = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--no-first-run', '--no-default-browser-check', '--enable-unsafe-swiftshader', 'about:blank',
  ], {windowsHide: true, stdio: 'ignore'});
  let socket;
  try {
    const portFile = path.join(profile, 'DevToolsActivePort');
    await until(() => fs.existsSync(portFile), 'Chrome did not start.');
    const port = fs.readFileSync(portFile, 'utf8').split('\n')[0].trim();
    const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    socket = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    const pending = new Map(), errors = [];
    let id = 0;
    socket.onmessage = event => {
      const value = JSON.parse(event.data);
      if (value.id) {
        const job = pending.get(value.id); pending.delete(value.id);
        if (value.error) job.reject(new Error(JSON.stringify(value.error))); else job.resolve(value.result);
      }
      if (value.method === 'Runtime.exceptionThrown') errors.push(value.params.exceptionDetails.exception?.description ?? value.params.exceptionDetails.text);
      if (value.method === 'Runtime.consoleAPICalled' && value.params.type === 'error')
        errors.push(value.params.args.map(arg => arg.value ?? arg.description ?? '').join(' '));
    };
    const call = (method, params = {}) => new Promise((resolve, reject) => {
      pending.set(++id, {resolve, reject}); socket.send(JSON.stringify({id, method, params}));
    });
    const evaluate = async expression => (await call('Runtime.evaluate', {expression, returnByValue: true})).result.value;
    await call('Runtime.enable'); await call('Page.enable');
    await call('Emulation.setDeviceMetricsOverride', {width: 390, height: 844, deviceScaleFactor: 2, mobile: true});
    await call('Page.navigate', {url});
    await until(() => evaluate("!!document.querySelector('#flutter-host flutter-view, #flutter-host flt-glass-pane, #flutter-host canvas')"), 'Flutter did not mount in viewport host.');
    await pause(1500);
    // Simulate keyboard/browser-bar height changes while the real debug engine
    // observes host dimensions; viewport growth must never produce negative insets.
    for (const [width, height] of [[390, 430], [390, 844], [390, 900], [844, 390], [390, 844]]) {
      await call('Emulation.setDeviceMetricsOverride', {width, height, deviceScaleFactor: 2, mobile: true});
      await pause(400);
      const size = await evaluate("({width: document.getElementById('flutter-host').clientWidth, height: document.getElementById('flutter-host').clientHeight, vw: document.documentElement.clientWidth, vh: document.documentElement.clientHeight})");
      assert.ok(Math.abs(size.width - size.vw) <= 1 && Math.abs(size.height - size.vh) <= 1, JSON.stringify(size));
      assert.ok(size.width > 0 && size.height > 0);
    }
    assert.deepEqual(errors.filter(error => /ViewInsets|viewInsets|Assertion failed/.test(error)), []);
    assert.ok(await evaluate("!!document.querySelector('#flutter-host flutter-view, #flutter-host flt-glass-pane, #flutter-host canvas')"));
    console.log('PASS: real Flutter debug engine mounted; five mobile viewport changes; no ViewInsets/assertion errors.');
    await call('Browser.close');
  } finally {
    socket?.close(); browser.kill(); server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
