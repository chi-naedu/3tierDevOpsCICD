// === Config ===
const API_BASE = window.API_BASE || "http://BACKEND_API_DNS_OR_IP/api";

// === State ===
const state = {
  tasks: [],
  filter: "all",
  search: "",
  sort: "newest",
  selectedId: null,
  selectedSet: new Set()
};

// === DOM ===
const listEl   = document.getElementById("list");
const viewerEl = document.getElementById("viewer");
const newTitle = document.getElementById("newTitle");
const addBtn   = document.getElementById("addBtn");
const searchEl = document.getElementById("search");
const sortEl   = document.getElementById("sort");
const statsEl  = document.getElementById("stats");

// === Helpers ===
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function filteredSortedTasks() {
  let items = [...state.tasks];

  // filter
  if (state.filter === "active") items = items.filter(t => !t.completed);
  if (state.filter === "completed") items = items.filter(t => t.completed);

  // search
  if (state.search.trim()) {
    const q = state.search.toLowerCase();
    items = items.filter(t => t.title.toLowerCase().includes(q));
  }

  // sort
  const byTitle = (a,b) => a.title.localeCompare(b.title);
  const byDate  = (a,b) => new Date(a.created_at) - new Date(b.created_at);

  if (state.sort === "az")   items.sort(byTitle);
  if (state.sort === "za")   items.sort((a,b)=>byTitle(b,a));
  if (state.sort === "oldest") items.sort(byDate);
  if (state.sort === "newest") items.sort((a,b)=>byDate(b,a));

  return items;
}

function setChipsActive(filter) {
  document.querySelectorAll(".chip").forEach(c => {
    c.classList.toggle("active", c.dataset.filter === filter);
  });
}

// === API ===
async function apiGet() {
  const res = await fetch(`${API_BASE}/tasks`);
  if (!res.ok) throw new Error("Failed to fetch tasks");
  return res.json();
}
async function apiCreate(title) {
  const res = await fetch(`${API_BASE}/tasks`, {
    method:"POST", headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({ title })
  });
  if (!res.ok) throw new Error("Failed to create task");
  return res.json();
}
async function apiUpdate(id, patch) {
  const res = await fetch(`${API_BASE}/tasks/${id}`, {
    method:"PUT", headers:{ "Content-Type":"application/json" },
    body: JSON.stringify(patch)
  });
  if (!res.ok) throw new Error("Failed to update task");
  return res.json();
}
async function apiDelete(id) {
  const res = await fetch(`${API_BASE}/tasks/${id}`, { method:"DELETE" });
  if (!res.ok) throw new Error("Failed to delete task");
}

// === Render ===
function renderStats() {
  const total = state.tasks.length;
  const done = state.tasks.filter(t=>t.completed).length;
  statsEl.textContent = `${total} task${total!==1?"s":""} • ${done} completed`;
}

function renderList() {
  listEl.innerHTML = "";
  const items = filteredSortedTasks();

  if (!items.length) {
    listEl.innerHTML = `<div class="muted">No tasks match your filters.</div>`;
    return;
  }

  for (const t of items) {
    const row = document.createElement("div");
    row.className = "item";
    row.innerHTML = `
      <input type="checkbox" class="sel" ${state.selectedSet.has(t.id) ? "checked":""} />
      <div class="title ${t.completed?"done":""}" title="Double-click to edit">${t.title}</div>
      <span class="badge">${new Date(t.created_at).toLocaleString()}</span>
      <div class="actions">
        <button class="btn" data-act="toggle">${t.completed ? "Undo" : "Done"}</button>
        <button class="btn ghost" data-act="view">View</button>
        <button class="btn ghost" data-act="delete" style="border-color:#3a1f1f;color:#ffb4b4">Delete</button>
      </div>
    `;

    // Event wiring
    const sel = row.querySelector(".sel");
    sel.addEventListener("change", () => {
      sel.checked ? state.selectedSet.add(t.id) : state.selectedSet.delete(t.id);
    });

    row.querySelector('[data-act="toggle"]').onclick = async () => {
      await apiUpdate(t.id, { completed: !t.completed });
      await refresh();
      selectInViewer(t.id);
    };

    row.querySelector('[data-act="view"]').onclick = () => {
      state.selectedId = t.id;
      renderViewer();
    };

    row.querySelector('[data-act="delete"]').onclick = async () => {
      if (!confirm("Delete this task?")) return;
      await apiDelete(t.id);
      state.selectedSet.delete(t.id);
      if (state.selectedId === t.id) state.selectedId = null;
      await refresh();
    };

    // Inline edit on double-click
    const titleEl = row.querySelector(".title");
    titleEl.ondblclick = () => startInlineEdit(titleEl, t);

    listEl.appendChild(row);
  }
}

function startInlineEdit(titleEl, task) {
  const input = document.createElement("input");
  input.type = "text";
  input.value = task.title;
  input.style.width = "100%";
  titleEl.replaceWith(input);
  input.focus();
  const save = async () => {
    const val = input.value.trim();
    if (val && val !== task.title) {
      await apiUpdate(task.id, { title: val });
      await refresh();
      selectInViewer(task.id);
    } else {
      // restore view without change
      renderList();
    }
  };
  input.addEventListener("blur", save);
  input.addEventListener("keydown", e => {
    if (e.key === "Enter") save();
    if (e.key === "Escape") renderList();
  });
}

function renderViewer() {
  if (!state.selectedId) {
    viewerEl.innerHTML = `<div class="muted">Select a task to view or edit.</div>`;
    return;
  }
  const t = state.tasks.find(x=>x.id===state.selectedId);
  if (!t) { viewerEl.innerHTML = `<div class="muted">Task not found.</div>`; return; }

  viewerEl.innerHTML = `
    <div class="row">
      <label class="muted">Title</label>
      <input id="viewerTitle" type="text" value="${escapeHtml(t.title)}" />
    </div>
    <div class="row muted">Created: ${new Date(t.created_at).toLocaleString()}</div>
    <div class="row">
      <button id="viewerToggle" class="btn">${t.completed ? "Mark as Active" : "Mark as Done"}</button>
      <button id="viewerSave" class="btn brand">Save</button>
      <button id="viewerDelete" class="btn ghost" style="border-color:#3a1f1f;color:#ffb4b4">Delete</button>
    </div>
  `;

  document.getElementById("viewerToggle").onclick = async () => {
    await apiUpdate(t.id, { completed: !t.completed });
    await refresh();
    selectInViewer(t.id);
  };

  document.getElementById("viewerSave").onclick = async () => {
    const newTitle = document.getElementById("viewerTitle").value.trim();
    if (!newTitle) return alert("Title cannot be empty.");
    if (newTitle !== t.title) await apiUpdate(t.id, { title: newTitle });
    await refresh();
    selectInViewer(t.id);
  };

  document.getElementById("viewerDelete").onclick = async () => {
    if (!confirm("Delete this task?")) return;
    await apiDelete(t.id);
    state.selectedId = null;
    await refresh();
  };
}

function selectInViewer(id){
  state.selectedId = id;
  renderViewer();
}

function renderAll(){
  renderStats();
  renderList();
  renderViewer();
}

// === Events (top bar) ===
addBtn.onclick = async () => {
  const title = newTitle.value.trim();
  if (!title) return newTitle.focus();
  await apiCreate(title);
  newTitle.value = "";
  await refresh();
};

searchEl.oninput = (e)=>{ state.search = e.target.value; renderAll(); };
sortEl.onchange = (e)=>{ state.sort = e.target.value; renderAll(); };

document.querySelectorAll(".chip").forEach(chip=>{
  chip.onclick = ()=>{ state.filter = chip.dataset.filter; setChipsActive(state.filter); renderAll(); };
});

// Bulk actions
document.getElementById("bulkComplete").onclick = async ()=>{
  const ids = [...state.selectedSet];
  if (!ids.length) return;
  await Promise.all(ids.map(id => apiUpdate(id,{completed:true})));
  state.selectedSet.clear();
  await refresh();
};
document.getElementById("bulkUndo").onclick = async ()=>{
  const ids = [...state.selectedSet];
  if (!ids.length) return;
  await Promise.all(ids.map(id => apiUpdate(id,{completed:false})));
  state.selectedSet.clear();
  await refresh();
};
document.getElementById("bulkDelete").onclick = async ()=>{
  const ids = [...state.selectedSet];
  if (!ids.length) return;
  if (!confirm(`Delete ${ids.length} selected task(s)?`)) return;
  for (const id of ids) { await apiDelete(id); }
  state.selectedSet.clear();
  if (ids.includes(state.selectedId)) state.selectedId = null;
  await refresh();
};

// === Init ===
async function refresh(){
  state.tasks = await apiGet();
  renderAll();
}
function escapeHtml(s){ return s.replace(/[&<>"']/g, m=>({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[m])); }

refresh().catch(err=>{
  listEl.innerHTML = `<div class="muted">Failed to load tasks. Check API_BASE and CORS.<br>${err}</div>`;
});
