// Headless web-benchmark driver.
//
// Serves a `ruby2d build --web` output directory, runs its `app.html` in
// headless Chrome with software WebGL, and prints the benchmark harness's
// report (captured from the page console) to stdout. No npm dependencies —
// uses node's built-in http server and global WebSocket/fetch (node >= 22).
//
// Usage: node drive.js <build/web dir> [app.html]
//
// Exit code 0 if a report was captured (contains "CPU build"), else non-zero.

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const DIR = process.argv[2];
const HTML = process.argv[3] || 'app.html';
const CHROME = process.env.CHROME ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const DBG = 9333 + (process.pid % 500);        // avoid clashes across runs
const PROFILE = fs.mkdtempSync(path.join(os.tmpdir(), 'r2d-cdp-'));
const TIMEOUT_MS = Number(process.env.DRIVE_TIMEOUT || 90000);
const MIME = { '.wasm': 'application/wasm', '.js': 'text/javascript',
  '.html': 'text/html', '.data': 'application/octet-stream',
  '.mem': 'application/octet-stream', '.css': 'text/css' };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = http.createServer((req, res) => {
  const f = path.join(DIR, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f, (err, buf) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' });
    res.end(buf);
  });
});

let msgId = 0;
const send = (ws, method, params, sessionId) =>
  ws.send(JSON.stringify({ id: ++msgId, method, params: params || {}, sessionId }));

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${server.address().port}/${HTML}`;

  const chrome = spawn(CHROME, [
    '--headless=new', '--no-sandbox', '--no-first-run', '--mute-audio',
    '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--window-size=1280,720', `--remote-debugging-port=${DBG}`,
    `--user-data-dir=${PROFILE}`, 'about:blank',
  ], { stdio: 'ignore' });

  let ver;
  for (let i = 0; i < 60 && !ver; i++) {
    try { ver = await (await fetch(`http://127.0.0.1:${DBG}/json/version`)).json(); }
    catch { await sleep(200); }
  }
  if (!ver) { console.error('DRIVER: Chrome debug endpoint never came up'); process.exit(2); }

  const ws = new WebSocket(ver.webSocketDebuggerUrl);
  const lines = [];
  let done = false;

  const finish = (reason) => {
    if (done) return; done = true;
    process.stdout.write(lines.join('\n') + '\n');
    if (reason) console.error(`DRIVER: ${reason}`);
    try { ws.close(); } catch {}
    chrome.kill('SIGKILL');
    server.close();
    try { fs.rmSync(PROFILE, { recursive: true, force: true }); } catch {}
    process.exit(lines.some((l) => l.includes('CPU build')) ? 0 : 1);
  };

  ws.addEventListener('open', () => {
    send(ws, 'Target.setDiscoverTargets', { discover: true });
    fetch(`http://127.0.0.1:${DBG}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' })
      .catch(() => send(ws, 'Target.createTarget', { url }));
  });

  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.method === 'Target.targetCreated' && msg.params.targetInfo.type === 'page') {
      send(ws, 'Target.attachToTarget', { targetId: msg.params.targetInfo.targetId, flatten: true });
    }
    if (msg.method === 'Target.attachedToTarget') {
      send(ws, 'Runtime.enable', {}, msg.params.sessionId);
    }
    // The harness prints via emscripten Module.print -> console.log.
    if (msg.method === 'Runtime.consoleAPICalled') {
      const text = msg.params.args.map((a) => (a.value !== undefined ? a.value : '')).join(' ');
      lines.push(text);
      if (/^-{20,}/.test(text) && lines.some((l) => l.includes('Throughput'))) finish(null);
    }
    if (msg.method === 'Runtime.exceptionThrown') {
      const e = msg.params.exceptionDetails;
      lines.push(`JS EXCEPTION: ${(e.exception && e.exception.description) || e.text}`);
    }
  });

  ws.addEventListener('error', (e) => finish(`ws error: ${e.message || e}`));
  setTimeout(() => finish('timeout waiting for report'), TIMEOUT_MS);
})();
