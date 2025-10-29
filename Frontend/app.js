// ===== Main App IIFE =====
// We wrap the entire app in an (async () => { ... })();
// This:
// 1. Runs the code immediately (fixing the DOMContentLoaded issue)
// 2. Creates a local scope, which fixes the "duplicate variable" SyntaxError

(async () => {
  // MOVED: API_BASE is now declared *inside* the function,
  // so it doesn't conflict with any global variables.
  const API_BASE = window.API_BASE ?? "/api";
  console.log("[config] API_BASE =", API_BASE);

  // Global error trap so silent errors don’t kill the app
  window.addEventListener("error", (e) => {
    console.error("Uncaught error:", e.error || e.message);
    const listEl = document.getElementById("list");
    if (listEl) listEl.innerHTML = `<div class="muted">⚠️ ${escapeHtml(String(e.error || e.message))}</div>`;
  });

  // Small fetch helper (always sends cookies, handles 401)
  async function api(path, opts = {}) {
    const res = await fetch(`${API_BASE}${path}`, {
      credentials: "include",
      headers: { "Content-Type": "application/json", ...(opts.headers || {}) },
      ...opts,
    });
    if (res.status === 401) {
      console.warn("401 from", path, "→ redirecting to home.html");
      window.location.href = "home.html";
      return new Promise(() => {}); // halt further work
    }
    if (!res.ok) {
      let msg = `Request failed (${res.status})`;
      try { const data = await res.json(); if (data?.error) msg = data.error; } catch {}
      throw new Error(msg);
    }
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  }

  // API wrappers
  const apiGetTasks = () => api(`/tasks`, { method: "GET" });
  const apiCreate   = (title) => api(`/tasks`, { method: "POST", body: JSON.stringify({ title }) });
  const apiUpdate   = (id, patch) => api(`/tasks/${id}`, { method: "PUT", body: JSON.stringify(patch) });
  const apiDelete   = (id) => api(`/tasks/${id}`, { method: "DELETE" });

  // ===== State =====
  const state = {
    tasks: [],
    filter: "all",
    search: "",
    sort: "newest",
    selectedId: null,
    selectedSet: new Set(),
  };

  // ===== Helpers =====
  function escapeHtml(s){ return s.replace(/[&<>"']/g, m=>({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[m])); }
  function setChipsActive(filter) {
    document.querySelectorAll(".chip").forEach(c => {
      c.classList.toggle("active", c.dataset.filter === filter);
    });
  }
  function filteredSortedTasks() {
    let items = [...state.tasks];
    if (state.filter === "active")    items = items.filter(t => !t.completed);
    if (state.filter === "completed") items = items.filter(t =>  t.completed);
    if (state.search.trim()) {
      const q = state.search.toLowerCase();
      items = items.filter(t => t.title.toLowerCase().includes(q));
    }
    const byTitle = (a,b) => a.title.localeCompare(b.title);
    const byDate  = (a,b) => new Date(a.created_at) - new Date(b.created_at);
    if (state.sort === "az")      items.sort(byTitle);
    if (state.sort === "za")      items.sort((a,b)=>byTitle(b,a));
    if (state.sort === "oldest")  items.sort(byDate);
    if (state.sort === "newest")  items.sort((a,b)=>byDate(b,a));
    return items;
  }

  // ===== Main UI (was DOMContentLoaded) =====
  // REMOVED: document.addEventListener("DOMContentLoaded", ...)
  console.log("[app] Script running...");

  // Grab elements
  const listEl   = document.getElementById("list");
  const viewerEl = document.getElementById("viewer");
  const newTitle = document.getElementById("newTitle");
  const addBtn   = document.getElementById("addBtn");
  const searchEl = document.getElementById("search");
  const sortEl   = document.getElementById("sort");
  const statsEl  = document.getElementById("stats");

  // Validate DOM
  const missing = [ ["list",listEl],["viewer",viewerEl],["newTitle",newTitle],["addBtn",addBtn],["search",searchEl],["sort",sortEl],["stats",statsEl] ]
                   .filter(([_,el]) => !el).map(([id])=>id);
  if (missing.length) {
    console.error("Missing DOM IDs:", missing);
    alert("Page is missing required elements: " + missing.join(", "));
    return;
  }

  // Verify auth
  try {
    console.log("[app] Checking session /auth/me…"); // You should see this now
    await api(`/auth/me`, { method: "GET" }); // redirects on 401
  } catch (e) {
    listEl.innerHTML = `<div class="muted">Auth check failed: ${escapeHtml(e.message)}</div>`;
    return;
  }

  // ===== Initial load function =====
  async function refresh(){
    try {
      console.log("[app] Fetching tasks…"); // You should see this now
      state.tasks = await apiGetTasks();
      console.log("[app] tasks loaded:", state.tasks.length);
      renderAll();
    } catch (err) {
      console.error("Failed to load tasks:", err);
      listEl.innerHTML = `<div class="muted">Failed to load tasks. ${escapeHtml(err.message)}</div>`;
    }
  }

  // ===== Render helpers =====
  function renderStats() {
    const total = state.tasks.length;
    const done  = state.tasks.filter(t=>t.completed).length;
    statsEl.textContent = `${total} task${total!==1?"s":""} • ${done} completed`;
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
        renderList(); // restore
      }
    };
    input.addEventListener("blur", save);
    input.addEventListener("keydown", e => {
      if (e.key === "Enter") save();
      if (e.key === "Escape") renderList();
    });
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
        <div class="title ${t.completed?"done":""}" title="Double-click to edit">${escapeHtml(t.title)}</div>
        <span class="badge">${new Date(t.created_at).toLocaleString()}</span>
        <div class="actions">
          <button class="btn" data-act="toggle">${t.completed ? "Undo" : "Done"}</button>
          <button class="btn ghost" data-act="view">View</button>
          <button class="btn ghost" data-act="delete" style="border-color:#fee2e2;color:#b91c1c">Delete</button>
        </div>
      `;

      row.querySelector(".sel").addEventListener("change", (ev) => {
        ev.target.checked ? state.selectedSet.add(t.id) : state.selectedSet.delete(t.id);
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

      row.querySelector(".title").ondblclick = () => startInlineEdit(row.querySelector(".title"), t);

      listEl.appendChild(row);
    }
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
        <button id="viewerDelete" class="btn ghost" style="border-color:#fee2e2;color:#b91c1c">Delete</button>
      </div>
    `;

    document.getElementById("viewerToggle").onclick = async () => {
      await apiUpdate(t.id, { completed: !t.completed });
      await refresh();
      selectInViewer(t.id);
    };

    document.getElementById("viewerSave").onclick = async () => {
      const val = document.getElementById("viewerTitle").value.trim();
      if (!val) return alert("Title cannot be empty.");
      if (val !== t.title) await apiUpdate(t.id, { title: val });
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

  function selectInViewer(id){ state.selectedId = id; renderViewer(); }
  function renderAll(){ renderStats(); renderList(); renderViewer(); }

  // ===== Events =====
  addBtn.onclick = async () => {
    const title = newTitle.value.trim();
    if (!title) { newTitle.focus(); return; }
    console.log("[app] Add clicked:", title);
    addBtn.disabled = true;
    try {
      await apiCreate(title);
      newTitle.value = "";
      await refresh();
    } catch (e) {
      alert(`Failed to create task: ${e.message}`);
      console.error("Create failed:", e);
    } finally {
      addBtn.disabled = false;
    }
  };
  newTitle.addEventListener("keydown", (e) => { if (e.key === "Enter") addBtn.click(); });

  let searchTimer;
  searchEl.oninput = (e)=>{
    clearTimeout(searchTimer);
    searchTimer = setTimeout(()=>{
      state.search = e.target.value;
      renderAll();
    }, 150);
  };
  sortEl.onchange = (e)=>{ state.sort = e.target.value; renderAll(); };

  document.querySelectorAll(".chip").forEach(chip=>{
    chip.onclick = ()=>{
      state.filter = chip.dataset.filter;
      setChipsActive(state.filter);
      renderAll();
    };
  });

  // ===== Initial load =====
  // Run the first refresh to load tasks
  await refresh();

})(); // <-- This closes and runs the IIFE