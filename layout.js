// HUD layout editor: lets the player drag and resize HUD elements from the /hud dashboard.
// Layout is stored in localStorage ("hudLayout") as { id: { x, y, s } }.
(function () {
  const STORAGE_KEY = 'hudLayout';

  // id -> element selector, label, and the selector of the parent whose scale affects offsets
  const TARGETS = [
    { id: 'top',      sel: '#section-top-hud',    label: 'Job / Wallet / Bank' },
    { id: 'status',   sel: '#status-bar-main',    label: 'Status icons', scaledParent: '#section-bottom-hud' },
    { id: 'location', sel: '.location-area',      label: 'Location',     scaledParent: '#section-bottom-hud' },
    { id: 'second',   sel: '#status-bar-second',  label: 'Status (Second theme)' },
    { id: 'ammo',     sel: '#section-weapon-ammo', label: 'Weapon / Ammo' },
    { id: 'car',      sel: '#section-car-hud',    label: 'Vehicle HUD' },
  ];

  const ICON = 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v20M2 12h20M12 2l-3 3M12 2l3 3M12 22l-3-3M12 22l3-3M2 12l3-3M2 12l3 3M22 12l-3-3M22 12l-3 3"/></svg>'
  );
  let layout = {};
  let editing = false;
  let backup = null;
  const boxes = {};

  function load() {
    try { layout = JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}; } catch (e) { layout = {}; }
  }
  function save() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(layout)); } catch (e) { /* ignore */ }
  }

  function parentScale(t) {
    if (!t.scaledParent) return 1;
    const p = document.querySelector(t.scaledParent);
    if (!p || !p.offsetWidth) return 1;
    return p.getBoundingClientRect().width / p.offsetWidth || 1;
  }

  function apply(t) {
    const el = document.querySelector(t.sel);
    if (!el) return;
    const l = layout[t.id];
    if (!l) {
      el.style.removeProperty('translate');
      el.style.removeProperty('scale');
      return;
    }
    el.style.translate = `${l.x || 0}px ${l.y || 0}px`;
    el.style.scale = String(l.s || 1);
    if (t.id === 'status' || t.id === 'location') el.style.transformOrigin = el.style.transformOrigin || 'left center';
  }

  function applyAll() { TARGETS.forEach(apply); }

  // ---------- edit mode ----------
  function positionBox(t) {
    const el = document.querySelector(t.sel);
    const box = boxes[t.id];
    if (!el || !box) return;
    const r = el.getBoundingClientRect();
    const visible = r.width > 2 && r.height > 2;
    box.style.display = visible ? 'block' : 'none';
    box.style.left = r.left + 'px';
    box.style.top = r.top + 'px';
    box.style.width = r.width + 'px';
    box.style.height = r.height + 'px';
  }
  function positionAll() { TARGETS.forEach(positionBox); }

  function ensureLayout(t) {
    if (!layout[t.id]) layout[t.id] = { x: 0, y: 0, s: 1 };
    return layout[t.id];
  }

  function makeBox(t) {
    const box = document.createElement('div');
    box.className = 'layout-box';
    box.innerHTML = `<span class="layout-label">${t.label}</span><span class="layout-handle" title="Drag to resize"></span>`;
    document.body.appendChild(box);
    boxes[t.id] = box;

    // drag to move
    box.addEventListener('pointerdown', (e) => {
      if (e.target.classList.contains('layout-handle')) return;
      e.preventDefault();
      box.setPointerCapture(e.pointerId);
      const l = ensureLayout(t);
      const start = { x: e.clientX, y: e.clientY, lx: l.x, ly: l.y };
      const k = parentScale(t);
      const move = (ev) => {
        l.x = start.lx + (ev.clientX - start.x) / k;
        l.y = start.ly + (ev.clientY - start.y) / k;
        apply(t); positionAll();
      };
      const up = () => { box.removeEventListener('pointermove', move); box.removeEventListener('pointerup', up); };
      box.addEventListener('pointermove', move);
      box.addEventListener('pointerup', up);
    });

    // drag handle to resize
    const handle = box.querySelector('.layout-handle');
    handle.addEventListener('pointerdown', (e) => {
      e.preventDefault(); e.stopPropagation();
      handle.setPointerCapture(e.pointerId);
      const l = ensureLayout(t);
      const startS = l.s || 1;
      const startX = e.clientX;
      const move = (ev) => {
        l.s = Math.max(0.4, Math.min(2.5, startS + (ev.clientX - startX) / 200));
        apply(t); positionAll();
      };
      const up = () => { handle.removeEventListener('pointermove', move); handle.removeEventListener('pointerup', up); };
      handle.addEventListener('pointermove', move);
      handle.addEventListener('pointerup', up);
    });

    // wheel to resize
    box.addEventListener('wheel', (e) => {
      e.preventDefault();
      const l = ensureLayout(t);
      l.s = Math.max(0.4, Math.min(2.5, (l.s || 1) + (e.deltaY < 0 ? 0.05 : -0.05)));
      apply(t); positionAll();
    }, { passive: false });
  }

  let toolbar = null;
  let carHadShow = false;

  function startEdit() {
    if (editing) return;
    editing = true;
    backup = JSON.stringify(layout);
    document.body.classList.add('layout-editing');

    const car = document.getElementById('section-car-hud');
    if (car) { carHadShow = car.classList.contains('show'); car.classList.add('show'); }
    const second = document.getElementById('status-bar-second');
    if (second && getComputedStyle(second).display === 'none') second.dataset.layoutHidden = '1';

    TARGETS.forEach((t) => { if (!boxes[t.id]) makeBox(t); });
    positionAll();

    toolbar = document.createElement('div');
    toolbar.className = 'layout-toolbar';
    toolbar.innerHTML = `
      <span>Drag to move &bull; drag the corner or scroll to resize</span>
      <button data-a="reset">Reset</button>
      <button data-a="cancel">Cancel</button>
      <button data-a="save" class="primary">Save</button>`;
    document.body.appendChild(toolbar);
    toolbar.addEventListener('click', (e) => {
      const a = e.target.getAttribute('data-a');
      if (a === 'reset') { layout = {}; applyAll(); positionAll(); }
      if (a === 'cancel') { layout = JSON.parse(backup); applyAll(); stopEdit(); }
      if (a === 'save') { save(); stopEdit(); }
    });
  }

  function stopEdit() {
    editing = false;
    document.body.classList.remove('layout-editing');
    Object.keys(boxes).forEach((k) => { boxes[k].remove(); delete boxes[k]; });
    if (toolbar) { toolbar.remove(); toolbar = null; }
    const car = document.getElementById('section-car-hud');
    if (car && !carHadShow) car.classList.remove('show');
  }

  // ESC cancels the editor instead of closing the dashboard
  window.addEventListener('keydown', (e) => {
    if (editing && e.key === 'Escape') {
      e.stopImmediatePropagation(); e.preventDefault();
      layout = JSON.parse(backup); applyAll(); stopEdit();
    }
  }, true);

  window.addEventListener('resize', () => { if (editing) positionAll(); });

  // ---------- dashboard row ----------
  function addRow() {
    const group = document.querySelector('.settings-group');
    if (!group || group.querySelector('.layout-row')) return;
    const row = document.createElement('div');
    row.className = 'setting-row layout-row';
    row.innerHTML = `
      <div class="icon-wrapper"><img class="edit-icon" alt="Layout" src="${ICON}"></div>
      <div class="row-content">
        <div class="row-text">
          <h3>HUD Layout</h3>
          <p>Move and resize HUD elements wherever you want</p>
        </div>
        <div class="row-controls">
          <button class="save-btn" id="layout-edit-btn">Edit</button>
          <button class="save-btn" id="layout-reset-btn" style="margin-left:8px;background:#303030">Reset</button>
        </div>
      </div>`;
    const header = group.querySelector('.group-header');
    if (header && header.nextSibling) group.insertBefore(row, header.nextSibling); else group.appendChild(row);
    row.querySelector('#layout-edit-btn').addEventListener('click', startEdit);
    row.querySelector('#layout-reset-btn').addEventListener('click', () => { layout = {}; save(); applyAll(); });
  }

  function init() {
    load();
    applyAll();
    addRow();
    // elements can be (re)rendered by the HUD scripts; re-apply shortly after load
    setTimeout(applyAll, 1600);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
