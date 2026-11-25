// A root shell on one node: xterm.js over /ws/terminal/<name>. Keystrokes
// and output travel as binary (UTF-8) frames; size changes as JSON text.

const el = document.getElementById("term");
const node = el.dataset.node;
const statusEl = document.getElementById("status");

const term = new Terminal({
  cursorBlink: true,
  fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, "DejaVu Sans Mono", monospace',
  fontSize: 14,
  scrollback: 5000,
  theme: { background: "#1d1d1b", foreground: "#ececea", cursor: "#e0574a" },
});
const fit = new FitAddon.FitAddon();
term.loadAddon(fit);
term.open(el);
fit.fit();

const proto = location.protocol === "https:" ? "wss:" : "ws:";
const ws = new WebSocket(`${proto}//${location.host}/ws/terminal/${encodeURIComponent(node)}`);
ws.binaryType = "arraybuffer";
const enc = new TextEncoder();

function sendSize() {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: "resize", cols: term.cols, rows: term.rows }));
  }
}

ws.onopen = () => {
  statusEl.textContent = "conectado";
  sendSize();
  term.focus();
};
ws.onmessage = (ev) => term.write(new Uint8Array(ev.data));
ws.onclose = (ev) => {
  const why = ev.code === 4401 ? "sesión vencida: volvé a ingresar"
    : ev.code === 4403 ? "no tenés acceso a este nodo"
    : "desconectado";
  statusEl.textContent = why;
  term.write(`\r\n\x1b[2m[${why}]\x1b[0m\r\n`);
};

term.onData((data) => { if (ws.readyState === WebSocket.OPEN) ws.send(enc.encode(data)); });
term.onBinary((data) => {
  if (ws.readyState !== WebSocket.OPEN) return;
  ws.send(Uint8Array.from(data, (c) => c.charCodeAt(0) & 0xff));
});
term.onResize(sendSize);

new ResizeObserver(() => fit.fit()).observe(el);
