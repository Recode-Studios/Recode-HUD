(() => {
  const moduleEl = document.getElementById('mm-module');
  if (!moduleEl || typeof GetParentResourceName !== 'function') return;

  const viewport = document.getElementById('mm-viewport');
  const bearingNumber = document.getElementById('mm-bearing-number');
  const distanceEl = document.getElementById('mm-distance');
  const districtEl = document.getElementById('mm-district');
  const streetEl = document.getElementById('mm-street');
  const glyphs = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&!';
  const frames = new Map();

  let scaleMultiplier = 1;
  let layoutTimer = 0;
  let layoutRetries = 0;
  let lastHeading = null;
  let dialAngle = 0;
  let wasVisible = false;
  let districtTarget = '';
  let streetTarget = '';

  const post = (name, body) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {})
  }).catch(() => {});

  function setHeading(value) {
    const heading = ((Math.round(Number(value) || 0) % 360) + 360) % 360;

    if (lastHeading === null) {
      dialAngle = -heading;
    } else {
      dialAngle -= ((heading - lastHeading + 540) % 360) - 180;
    }

    lastHeading = heading;
    moduleEl.style.setProperty('--mm-dial-angle', `${dialAngle}deg`);
    moduleEl.style.setProperty('--mm-label-angle', `${-dialAngle}deg`);
    bearingNumber.textContent = String(heading).padStart(3, '0');
  }

  function setDistance(meters) {
    const value = Math.max(0, Math.round(Number(meters) || 0));
    distanceEl.textContent = value <= 0 ? '' : value < 1000 ? `${value} M` : `${(value / 1000).toFixed(1)} KM`;
    distanceEl.classList.toggle('is-hidden', value <= 0);
  }

  function scramble(element, value, duration, delay) {
    const target = String(value || '').toUpperCase();
    const previous = frames.get(element);
    if (previous) cancelAnimationFrame(previous);

    if (!target) {
      element.textContent = '';
      frames.delete(element);
      return;
    }

    const startedAt = performance.now() + delay;

    const render = (now) => {
      const elapsed = Math.max(0, now - startedAt);
      const progress = Math.min(1, elapsed / duration);
      const revealed = Math.floor(progress * (target.length + 1));
      const phase = Math.floor(elapsed / 45);

      element.textContent = Array.from(target, (character, index) => {
        if (character === ' ' || index < revealed) return character;
        return glyphs[(index * 17 + phase * 13 + target.length * 7) % glyphs.length];
      }).join('');

      if (progress < 1) {
        frames.set(element, requestAnimationFrame(render));
      } else {
        element.textContent = target;
        frames.delete(element);
      }
    };

    frames.set(element, requestAnimationFrame(render));
  }

  function setLocation(district, street, force) {
    const nextDistrict = district || districtTarget;
    const nextStreet = street || streetTarget;

    if (force || nextDistrict !== districtTarget) {
      districtTarget = nextDistrict;
      scramble(districtEl, districtTarget, 850, 0);
    }

    if (force || nextStreet !== streetTarget) {
      streetTarget = nextStreet;
      scramble(streetEl, streetTarget, 950, 55);
    }
  }

  function updateScale() {
    const base = Math.min(window.innerHeight / 1080, window.innerWidth / 1920);
    const scale = Math.max(0.55, Math.min(1.5, base * scaleMultiplier));
    moduleEl.style.setProperty('--mm-scale', String(scale));
  }

  function reportLayout() {
    clearTimeout(layoutTimer);
    layoutTimer = setTimeout(() => {
      const bounds = viewport.getBoundingClientRect();
      if (bounds.width < 1 || bounds.height < 1) {
        // NUI not laid out yet (happens while joining): try again
        layoutRetries += 1;
        if (layoutRetries < 120) reportLayout();
        return;
      }
      layoutRetries = 0;

      post('mmLayout', {
        left: bounds.left / window.innerWidth,
        top: bounds.top / window.innerHeight,
        width: bounds.width / window.innerWidth,
        height: bounds.height / window.innerHeight
      });
    }, 50);
  }

  // The stock radar is moved through an invisible frame (#mm-stock-frame). Lua sends where the
  // radar sits by default; the layout editor in layout.js then moves/scales that frame.
  const stockFrame = document.getElementById('mm-stock-frame');
  let stockTimer = 0;

  function reportStockLayout() {
    if (!stockFrame) return;

    clearTimeout(stockTimer);
    stockTimer = setTimeout(() => {
      let saved = null;
      try { saved = (JSON.parse(localStorage.getItem('hudLayout')) || {}).minimapStock || null; } catch (e) { /* ignore */ }

      // nothing saved = default position of the HUD theme
      if (!saved) {
        post('mmStockLayout', { reset: true });
        return;
      }

      const bounds = stockFrame.getBoundingClientRect();
      if (bounds.width < 1 || bounds.height < 1) return;

      post('mmStockLayout', {
        left: bounds.left / window.innerWidth,
        top: bounds.top / window.innerHeight,
        width: bounds.width / window.innerWidth,
        height: bounds.height / window.innerHeight
      });
    }, 60);
  }

  function configure(data) {
    const ui = data.ui || {};
    const stock = data.stockDefault;
    if (stockFrame && stock) {
      stockFrame.style.left = `${stock.left * 100}vw`;
      stockFrame.style.top = `${stock.top * 100}vh`;
      stockFrame.style.width = `${stock.width * 100}vw`;
      stockFrame.style.height = `${stock.height * 100}vh`;
      reportStockLayout();
    }
    const row = document.getElementById('minimap-setting-row');
    // config.lua can disable the round minimap completely: no dashboard switch then
    if (row && data.available === false) row.style.display = 'none';
    moduleEl.classList.toggle('hide-location', ui.showLocation !== true);
    scaleMultiplier = Number(ui.scale) || 1;
    moduleEl.style.setProperty('--mm-left', `${Number(ui.leftVw) || 2.2}vw`);
    moduleEl.style.setProperty('--mm-bottom', `${Number(ui.bottomVh) || 11}vh`);
    updateScale();
    reportLayout();
  }

  function update(data) {
    const visible = data.visible === true;

    setHeading(data.heading);
    setDistance(data.distance);
    setLocation(data.district, data.street, visible && !wasVisible);
    wasVisible = visible;

    moduleEl.classList.toggle('is-visible', visible);
  }

  // round minimap (true) or the stock GTA radar (false)
  function setMode(custom) {
    document.body.classList.toggle('mm-active', custom === true);
    if (custom === true) reportLayout(); else reportStockLayout();
  }

  // the /hud dashboard stores the choice as hud_visible_minimap (global.js)
  function savedCustom() {
    try { return localStorage.getItem('hud_visible_minimap') !== 'false'; } catch (e) { return true; }
  }

  document.querySelectorAll('.toggle-group[data-setting="minimap"] .toggle-btn').forEach((button) => {
    button.addEventListener('click', () => {
      post('mmMode', { custom: button.getAttribute('data-value') === 'true' });
    });
  });

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'coii:minimap:configure') configure(data);
    if (data.action === 'coii:minimap:update') update(data);
    if (data.action === 'coii:minimap:mode') setMode(data.custom);
  });

  window.addEventListener('hud-layout-changed', () => {
    reportLayout();
    reportStockLayout();
  });

  window.addEventListener('resize', () => {
    updateScale();
    reportLayout();
    reportStockLayout();
  });

  updateScale();
  post('mmReady', { custom: savedCustom() });
})();
