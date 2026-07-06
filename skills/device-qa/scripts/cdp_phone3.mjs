// 실폰 robust 드라이버: 매 run 타겟 재탐색 + ws 재연결 + bringToFront(백그라운드 탭 0x0 방지).
// usage: node cdp_phone3.mjs <port> <runs> <sinkPath>
import fs from 'node:fs';
const PORT = process.argv[2];
const RUNS = +(process.argv[3] || 8);
const SINK = process.argv[4];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const doneCount = () => {
  try { return (fs.readFileSync(SINK, 'utf8').match(/__PERF_DONE__/g) || []).length; }
  catch (e) { return 0; }
};
async function getTarget() {
  for (let i = 0; i < 30; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
      const t = list.find((x) => x.type === 'page' && x.webSocketDebuggerUrl && /:8099/.test(x.url || ''));
      if (t) return t;
    } catch (e) {}
    await sleep(1000);
  }
  return null;
}
async function oneRun(run) {
  const t = await getTarget();
  if (!t) { console.log(`run ${run}: NO TARGET`); return false; }
  const ws = new WebSocket(t.webSocketDebuggerUrl);
  let id = 0; const pend = new Map();
  const send = (m, p) => new Promise((res, rej) => {
    const myid = ++id; pend.set(myid, res);
    ws.send(JSON.stringify({ id: myid, method: m, params: p || {} }));
    setTimeout(() => { if (pend.has(myid)) { pend.delete(myid); rej(new Error('cmd timeout')); } }, 8000);
  });
  ws.addEventListener('message', (e) => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } });
  let ok = false;
  try {
    await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
    await send('Page.enable');
    await send('Page.bringToFront');     // 백그라운드 탭 0x0 방지
    const before = doneCount();
    await send('Page.reload', { ignoreCache: false });
    await sleep(1500);
    await send('Page.bringToFront').catch(() => {});
    for (let i = 0; i < 360; i++) {
      if (doneCount() > before) { ok = true; break; }
      await sleep(500);
    }
  } catch (e) {
    console.log(`run ${run}: ERR ${e.message}`);
  }
  try { ws.close(); } catch (e) {}
  console.log(`run ${run}/${RUNS} ${ok ? 'done' : 'TIMEOUT'}`);
  return ok;
}
for (let run = 1; run <= RUNS; run++) {
  await oneRun(run);
  await sleep(800);
}
console.log('all runs complete');
process.exit(0);
