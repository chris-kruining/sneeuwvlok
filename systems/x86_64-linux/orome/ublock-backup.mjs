// Asks the built-in uBlock of a running (headless) Helium for its backup, the same request its "Back up to file" button makes.
// Helium has to be started with --remote-debugging-port=9333 and --user-data-dir set to the real profile, see the readme
const port = 9333;
const ublock = "blockjmkbacgjkknlgpkjjiijinjdanf";
const out = process.argv[2];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let version;
for (let i = 0; i < 40 && !version; i++) {
  try { version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json(); } catch { await sleep(500); }
}
if (!version) throw new Error("helium's debug port never came up");

const target = await (await fetch(`http://127.0.0.1:${port}/json/new?chrome-extension://${ublock}/dashboard.html`, { method: "PUT" })).json();
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r));
let id = 0;
const call = (method, params) => new Promise((resolve) => {
  const n = ++id;
  const on = (e) => { const m = JSON.parse(e.data); if (m.id === n) { ws.removeEventListener("message", on); resolve(m); } };
  ws.addEventListener("message", on);
  ws.send(JSON.stringify({ id: n, method, params }));
});

let result;
for (let i = 0; i < 20; i++) {
  result = await call("Runtime.evaluate", {
    expression: "typeof vAPI === 'undefined' ? null : vAPI.messaging.send('dashboard', { what: 'backupUserData' }).then(r => JSON.stringify(r.userData, null, '  '))",
    awaitPromise: true,
    returnByValue: true,
  });
  if (result.result?.result?.value) break;
  await sleep(500);
}
const json = result.result?.result?.value;
if (!json) { console.error("no backup:", JSON.stringify(result).slice(0, 400)); process.exit(1); }

const { writeFileSync } = await import("node:fs");
writeFileSync(out, json);
const data = JSON.parse(json);
console.log("backup written, keys:", Object.keys(data).join(", "));
await fetch(`http://127.0.0.1:${port}/json/close/${target.id}`).catch(() => {});
