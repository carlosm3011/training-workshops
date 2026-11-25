// Node list: polls /api/nodes every 2 s so state changes show up without
// reloading, and sends Start/Stop/Restart to /api/nodes/<name>/<action>.

const POLL_MS = 2000;
const STATUS = { running: "en marcha", exited: "detenido", created: "creado", restarting: "reiniciando", paused: "pausado" };
const busy = new Set(); // containers with an action in flight

function uptime(s) {
  if (s == null) return "";
  if (s < 60) return `${s} s`;
  if (s < 3600) return `${Math.floor(s / 60)} min`;
  return `${Math.floor(s / 3600)} h ${Math.floor((s % 3600) / 60)} min`;
}

function cell(text, cls) {
  const td = document.createElement("td");
  td.textContent = text;
  if (cls) td.className = cls;
  return td;
}

function button(node, action, label) {
  const b = document.createElement("button");
  b.textContent = label;
  b.disabled = busy.has(node.name)
    || (action === "start" && node.status === "running")
    || (action === "stop" && node.status !== "running");
  b.addEventListener("click", () => act(node.name, action));
  return b;
}

function render(nodes) {
  const tbody = document.querySelector("#nodes tbody");
  tbody.replaceChildren(...nodes.map((node) => {
    const tr = document.createElement("tr");
    if (node.role === "master") tr.className = "master";
    tr.append(
      cell(node.name, "name"),
      cell(busy.has(node.name) ? "…" : (STATUS[node.status] || node.status), `status ${node.status}`),
      cell(node.ipv4, "addr"),
      cell(node.ipv6, "addr"),
      cell(uptime(node.uptime)),
    );
    const actions = document.createElement("td");
    actions.className = "actions";
    actions.append(button(node, "start", "Iniciar"), button(node, "stop", "Detener"), button(node, "restart", "Reiniciar"));
    tr.append(actions);
    return tr;
  }));
}

function showError(text) {
  const p = document.getElementById("message");
  p.textContent = text;
  p.hidden = !text;
}

async function refresh() {
  try {
    const r = await fetch("/api/nodes", { cache: "no-store" });
    if (r.status === 401) { location.href = "/login"; return; }
    const data = await r.json();
    render(data.nodes);
    showError("");
  } catch (e) {
    showError("No se pudo actualizar la lista de nodos.");
  }
}

async function act(name, action) {
  busy.add(name);
  refresh();
  try {
    const r = await fetch(`/api/nodes/${encodeURIComponent(name)}/${action}`, { method: "POST" });
    if (r.status === 401) { location.href = "/login"; return; }
    if (!r.ok) showError(`No se pudo ${action === "start" ? "iniciar" : action === "stop" ? "detener" : "reiniciar"} ${name}.`);
  } finally {
    busy.delete(name);
    refresh();
  }
}

refresh();
setInterval(refresh, POLL_MS);
