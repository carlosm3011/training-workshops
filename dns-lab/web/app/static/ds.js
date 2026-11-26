// DS records of groupNN.lab. in lab. (#10): lists them from /api/ds/<group>,
// publishes pasted lines and removes single records. The instructor picks
// the group from a menu; a group only ever has its own.

const dsSection = document.getElementById("ds");
const dsGroupSel = document.getElementById("ds-group");
const dsForm = document.getElementById("ds-form");
const dsMsg = document.getElementById("ds-message");
const ALGORITHMS = { 8: "RSASHA256", 10: "RSASHA512", 13: "ECDSAP256SHA256", 14: "ECDSAP384SHA384", 15: "ED25519", 16: "ED448" };
const DIGESTS = { 1: "SHA-1", 2: "SHA-256", 4: "SHA-384" };

function dsGroup() {
  return dsGroupSel ? dsGroupSel.value : dsSection.dataset.groups;
}

function dsShow(text, isError) {
  dsMsg.textContent = text;
  dsMsg.className = isError ? "error" : "ok";
  dsMsg.hidden = !text;
}

function dsRender(records) {
  const tbody = document.querySelector("#ds-records tbody");
  if (!records.length) {
    const td = cell("Ningún DS publicado: la zona no tiene cadena de confianza desde lab.", "muted");
    td.colSpan = 4;
    const tr = document.createElement("tr");
    tr.append(td);
    tbody.replaceChildren(tr);
    return;
  }
  tbody.replaceChildren(...records.map((r) => {
    const tr = document.createElement("tr");
    const alg = ALGORITHMS[r.algorithm] ? `${r.algorithm} (${ALGORITHMS[r.algorithm]})` : String(r.algorithm);
    const digest = cell("", "digest");
    const kind = document.createElement("span");
    kind.className = "muted";
    kind.textContent = `${r.digest_type} (${DIGESTS[r.digest_type] || "?"}) `;
    const hex = document.createElement("code");
    hex.textContent = r.digest;
    digest.append(kind, hex);
    const actions = document.createElement("td");
    const b = document.createElement("button");
    b.textContent = "Quitar";
    b.addEventListener("click", () => dsCall("delete", { record: r.text }, b));
    actions.append(b);
    tr.append(cell(String(r.key_tag)), cell(alg), digest, actions);
    return tr;
  }));
}

async function dsCall(action, body, btn) {
  const url = `/api/ds/${encodeURIComponent(dsGroup())}${action === "delete" ? "/delete" : ""}`;
  if (btn) btn.disabled = true;
  try {
    const r = await fetch(url, body
      ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }
      : { cache: "no-store" });
    if (r.status === 401) { location.href = "/login"; return false; }
    const data = await r.json();
    if (!r.ok) {
      dsShow(typeof data.detail === "string" ? data.detail : "No se pudo completar la operación.", true);
      if (action === "delete") dsLoad();
      return false;
    }
    dsRender(data.records);
    dsShow(data.message || "", false);
    return true;
  } catch (e) {
    dsShow("No se pudo contactar al servidor.", true);
    return false;
  } finally {
    if (btn) btn.disabled = false;
  }
}

function dsLoad() { return dsCall("list"); }

dsForm.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const text = dsForm.elements.text;
  if (await dsCall("add", { text: text.value }, dsForm.querySelector("button"))) text.value = "";
});
if (dsGroupSel) dsGroupSel.addEventListener("change", () => { dsShow(""); dsLoad(); });

dsLoad();
