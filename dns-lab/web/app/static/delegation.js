// NS records and glue of groupNN.lab. in lab. (#33): lists the delegation
// from /api/delegation/<group> and replaces it with the textarea's lines,
// "name [address …]". Uses regGroup() and the menu from ds.js.

const delegForm = document.getElementById("deleg-form");
const delegMsg = document.getElementById("deleg-message");

function delegShow(text, isError) {
  delegMsg.textContent = text;
  delegMsg.className = isError ? "error" : "ok";
  delegMsg.hidden = !text;
}

// The delegation init creates: ns0-2 at the group's three nodes.
function delegDefaults(group) {
  const g = parseInt(group.slice("group".length), 10);
  return [0, 1, 2].map((n) => `ns${n}.${group}.lab. 10.53.${g}.${10 + n} fd53::${g}:${10 + n}`).join("\n");
}

function delegRender(data) {
  const tbody = document.querySelector("#deleg-servers tbody");
  tbody.replaceChildren(...data.servers.map((s) => {
    const tr = document.createElement("tr");
    const v4 = s.addresses.filter((a) => !a.includes(":"));
    const v6 = s.addresses.filter((a) => a.includes(":"));
    tr.append(cell(s.name), cell(v4.join(" ") || "—", v4.length ? "" : "muted"), cell(v6.join(" ") || "—", v6.length ? "" : "muted"));
    return tr;
  }));
  delegForm.elements.text.value = data.text;
  delegForm.elements.text.rows = Math.max(3, data.servers.length + 1);
}

async function delegCall(body, btn) {
  const url = `/api/delegation/${encodeURIComponent(regGroup())}`;
  if (btn) btn.disabled = true;
  try {
    const r = await fetch(url, body
      ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }
      : { cache: "no-store" });
    if (r.status === 401) { location.href = "/login"; return false; }
    const data = await r.json();
    if (!r.ok) {
      delegShow(typeof data.detail === "string" ? data.detail : "No se pudo completar la operación.", true);
      return false;
    }
    delegRender(data);
    delegShow(data.message || "", false);
    return true;
  } catch (e) {
    delegShow("No se pudo contactar al servidor.", true);
    return false;
  } finally {
    if (btn) btn.disabled = false;
  }
}

delegForm.addEventListener("submit", (ev) => {
  ev.preventDefault();
  delegCall({ text: delegForm.elements.text.value }, delegForm.querySelector("button[type=submit]"));
});
document.getElementById("deleg-defaults").addEventListener("click", () => {
  delegForm.elements.text.value = delegDefaults(regGroup());
  delegShow("Valores iniciales cargados en el formulario; guárdalos para aplicarlos.", false);
});
if (regGroupSel) regGroupSel.addEventListener("change", () => { delegShow(""); delegCall(); });

delegCall();
