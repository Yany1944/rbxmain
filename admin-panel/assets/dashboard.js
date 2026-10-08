// Макет дашборда. Все данные ниже — фейковые генераторы; заменяй их на fetch к своему API
// в местах с TODO(backend). Отрисовка (графики, счётчики, лента) от источника данных не зависит.
(function () {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const ease = (t) => 1 - Math.pow(1 - t, 3);

  // ─── Фейковые данные ──────────────────────────────────────────────────────
  // TODO(backend): заменить на ответ GET /api/stats?range=...
  function series(n, base, amp, noise) {
    const out = [];
    for (let i = 0; i < n; i++) {
      const day = Math.sin((i / n) * Math.PI * 2 - Math.PI / 2) * 0.5 + 0.5; // суточный цикл
      out.push(Math.max(0, base + amp * day + rand(-noise, noise)));
    }
    return out;
  }
  const RANGES = {
    '1h': { points: 60, label: (i) => `${String(i).padStart(2, '0')}м`, step: 10 },
    '24h': { points: 48, label: (i) => `${String(Math.floor(i / 2)).padStart(2, '0')}:${i % 2 ? '30' : '00'}`, step: 8 },
    '7d': { points: 42, label: (i) => ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][Math.floor(i / 6)], step: 6 },
  };
  function makeStats(range) {
    const n = RANGES[range].points;
    const k = range === '7d' ? 1.3 : range === '1h' ? 0.8 : 1;
    return {
      kpi: {
        peers: Math.round(rand(180, 260) * k),
        syncs: Math.round(rand(900, 1400) * k),
        latency: Math.round(rand(38, 62)),
        uptime: 99.97,
      },
      spark: {
        peers: series(24, 120, 140, 18),
        syncs: series(24, 700, 600, 90),
        latency: series(24, 40, 20, 8),
        uptime: Array.from({ length: 24 }, () => rand(99.9, 100)),
      },
      today: series(n, 400 * k, 900 * k, 90),
      yesterday: series(n, 380 * k, 820 * k, 70),
      labels: Array.from({ length: n }, (_, i) => RANGES[range].label(i)),
      step: RANGES[range].step,
    };
  }

  // ─── KPI: плавный счётчик ─────────────────────────────────────────────────
  function countTo(el, target) {
    const dec = +(el.dataset.decimals || 0);
    const suffix = el.dataset.suffix || '';
    const from = parseFloat(el.dataset.current || '0');
    const t0 = performance.now();
    const dur = 900;
    el.dataset.current = target;
    (function frame(now) {
      const t = Math.min(1, (now - t0) / dur);
      const v = from + (target - from) * ease(t);
      el.textContent = v.toLocaleString('ru-RU', { minimumFractionDigits: dec, maximumFractionDigits: dec }) + suffix;
      if (t < 1) requestAnimationFrame(frame);
    })(t0);
  }

  // ─── Геометрия линий ──────────────────────────────────────────────────────
  // Сглаженная кривая (monotone-подобная, через контрольные точки Catmull-Rom)
  function smoothPath(pts) {
    if (pts.length < 2) return '';
    let d = `M${pts[0][0]},${pts[0][1]}`;
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[i - 1] || pts[i];
      const p1 = pts[i];
      const p2 = pts[i + 1];
      const p3 = pts[i + 2] || p2;
      const c1x = p1[0] + (p2[0] - p0[0]) / 6;
      const c1y = p1[1] + (p2[1] - p0[1]) / 6;
      const c2x = p2[0] - (p3[0] - p1[0]) / 6;
      const c2y = p2[1] - (p3[1] - p1[1]) / 6;
      d += ` C${c1x.toFixed(1)},${c1y.toFixed(1)} ${c2x.toFixed(1)},${c2y.toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
    }
    return d;
  }
  const el = (tag, attrs = {}) => {
    const n = document.createElementNS(SVG_NS, tag);
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    return n;
  };
  function animateDraw(path) {
    const len = path.getTotalLength();
    path.style.setProperty('--len', len);
    path.classList.remove('draw');
    void path.getBoundingClientRect();
    path.classList.add('draw');
  }

  // ─── Спарклайны ───────────────────────────────────────────────────────────
  function drawSpark(svg, data) {
    const w = svg.clientWidth || 200, h = 34;
    svg.setAttribute('viewBox', `0 0 ${w} ${h}`);
    svg.innerHTML = '';
    const defs = el('defs');
    defs.innerHTML = '<linearGradient id="sparkFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8b8cff" stop-opacity=".25"/><stop offset="1" stop-color="#8b8cff" stop-opacity="0"/></linearGradient>';
    svg.appendChild(defs);
    const min = Math.min(...data), max = Math.max(...data);
    const pts = data.map((v, i) => [(i / (data.length - 1)) * w, h - 3 - ((v - min) / (max - min || 1)) * (h - 6)]);
    const line = smoothPath(pts);
    svg.appendChild(el('path', { class: 'area', d: `${line} L${w},${h} L0,${h} Z` }));
    const p = el('path', { class: 'line', d: line });
    svg.appendChild(p);
    animateDraw(p);
  }

  // ─── Основной график ──────────────────────────────────────────────────────
  const chart = document.getElementById('chart');
  const wrap = document.getElementById('chartWrap');
  const tip = document.getElementById('tooltip');
  let chartState = null;

  function drawChart(stats) {
    const W = wrap.clientWidth, H = wrap.clientHeight;
    const pad = { l: 40, r: 8, t: 8, b: 24 };
    const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
    chart.setAttribute('viewBox', `0 0 ${W} ${H}`);
    chart.innerHTML = '';

    const defs = el('defs');
    defs.innerHTML = '<linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8b8cff" stop-opacity=".22"/><stop offset="1" stop-color="#8b8cff" stop-opacity="0"/></linearGradient>';
    chart.appendChild(defs);

    const max = Math.ceil(Math.max(...stats.today, ...stats.yesterday) / 200) * 200;
    const x = (i) => pad.l + (i / (stats.today.length - 1)) * iw;
    const y = (v) => pad.t + ih - (v / max) * ih;

    for (let g = 0; g <= 4; g++) {
      const v = (max / 4) * g;
      chart.appendChild(el('line', { class: 'gridline', x1: pad.l, x2: W - pad.r, y1: y(v), y2: y(v) }));
      const t = el('text', { class: 'axis', x: pad.l - 8, y: y(v) + 4, 'text-anchor': 'end' });
      t.textContent = v >= 1000 ? `${(v / 1000).toFixed(1)}k` : v;
      chart.appendChild(t);
    }
    stats.labels.forEach((lab, i) => {
      if (i % stats.step) return;
      const t = el('text', { class: 'axis', x: x(i), y: H - 6, 'text-anchor': 'middle' });
      t.textContent = lab;
      chart.appendChild(t);
    });

    const ptsA = stats.today.map((v, i) => [x(i), y(v)]);
    const ptsB = stats.yesterday.map((v, i) => [x(i), y(v)]);
    const lineA = smoothPath(ptsA);

    chart.appendChild(el('path', { class: 'series b', d: smoothPath(ptsB) }));
    const area = el('path', { class: 'area', d: `${lineA} L${x(ptsA.length - 1)},${pad.t + ih} L${pad.l},${pad.t + ih} Z` });
    area.style.animation = 'fadeIn 1.2s var(--ease)';
    chart.appendChild(area);
    const a = el('path', { class: 'series a', d: lineA });
    chart.appendChild(a);
    animateDraw(a);

    const cursor = el('line', { class: 'cursor', y1: pad.t, y2: pad.t + ih });
    const dot = el('circle', { class: 'cursor-dot', r: 4 });
    chart.append(cursor, dot);
    chartState = { stats, x, y, pad, iw, cursor, dot };
  }

  wrap.addEventListener('pointermove', (e) => {
    if (!chartState) return;
    const { stats, x, y, pad, iw, cursor, dot } = chartState;
    const r = wrap.getBoundingClientRect();
    const mx = e.clientX - r.left;
    const i = Math.round(Math.min(1, Math.max(0, (mx - pad.l) / iw)) * (stats.today.length - 1));
    const cx = x(i), cy = y(stats.today[i]);
    cursor.setAttribute('x1', cx); cursor.setAttribute('x2', cx);
    dot.setAttribute('cx', cx); dot.setAttribute('cy', cy);
    tip.innerHTML = `<div class="t">${stats.labels[i]}</div>
      <div class="row"><span>Сегодня</span><b>${Math.round(stats.today[i]).toLocaleString('ru-RU')}</b></div>
      <div class="row" style="color:var(--muted)"><span>Вчера</span><span>${Math.round(stats.yesterday[i]).toLocaleString('ru-RU')}</span></div>`;
    const tw = tip.offsetWidth;
    tip.style.left = `${cx + 12 + tw > r.width ? cx - tw - 12 : cx + 12}px`;
    tip.style.top = `${Math.max(0, cy - 40)}px`;
    wrap.classList.add('hover');
  });
  wrap.addEventListener('pointerleave', () => wrap.classList.remove('hover'));

  // ─── Ресурсы сервера ──────────────────────────────────────────────────────
  // TODO(backend): заменить на GET /api/server
  const meters = { cpu: 23, ram: 41, disk: 58, net: 17 };
  function renderMeters() {
    for (const [k, v] of Object.entries(meters)) {
      document.querySelector(`[data-meter="${k}"] > i`).style.width = `${v}%`;
      document.querySelector(`[data-meter="${k}"]`).classList.toggle('warn', v > 75);
      document.querySelector(`[data-meter-val="${k}"]`).textContent = `${Math.round(v)}%`;
    }
  }
  function tickMeters() {
    for (const k of ['cpu', 'net']) meters[k] = Math.min(95, Math.max(5, meters[k] + rand(-8, 8)));
    meters.ram = Math.min(90, Math.max(30, meters.ram + rand(-2, 2)));
    const l = (meters.cpu / 50).toFixed(2);
    document.getElementById('loadAvg').textContent = `${l} ${(l * 0.9).toFixed(2)} ${(l * 0.75).toFixed(2)}`;
    renderMeters();
  }

  // ─── Пиры ─────────────────────────────────────────────────────────────────
  // TODO(backend): заменить на GET /api/peers
  const NAMES = ['NightFox_77', 'pinkglow', 'xX_Builder_Xx', 'Murder_Pro', 'yany', 'k1tsune', 'SheriffMain', 'lilbloxy', 'emote_enjoyer', 'ghostwalk'];
  const GAMES = ['MM2', 'Adopt Me', 'Brookhaven', 'Bloxburg'];
  function renderPeers() {
    const rows = Array.from({ length: 6 }, () => ({
      name: pick(NAMES),
      game: `${pick(GAMES)} · ${Math.random().toString(16).slice(2, 6)}`,
      status: pick(['on', 'on', 'on', 'idle', 'off']),
      items: Math.floor(rand(0, 40)),
      ping: Math.floor(rand(18, 140)),
    }));
    const label = { on: 'В сети', idle: 'Простой', off: 'Отключён' };
    const tbody = document.getElementById('peers');
    tbody.innerHTML = '';
    rows.forEach((r, i) => {
      const tr = document.createElement('tr');
      tr.className = 'reveal';
      tr.style.setProperty('--i', i);
      tr.innerHTML = `<td style="color:var(--text)"></td><td class="mono"></td>
        <td><span class="status ${r.status}">${label[r.status]}</span></td>
        <td class="num">${r.items}</td><td class="num mono">${r.ping} мс</td>`;
      tr.children[0].textContent = r.name; // имена — потенциально чужие данные, только textContent
      tr.children[1].textContent = r.game;
      tbody.appendChild(tr);
    });
  }

  // ─── Лента событий ────────────────────────────────────────────────────────
  // TODO(backend): заменить на WebSocket /api/events
  const EVENTS = [
    ['ok', (n) => `<b></b> подключился к relay`],
    ['ok', (n) => `<b></b> синхронизировал образ (${Math.floor(rand(3, 38))} предм.)`],
    ['', (n) => `<b></b> сменил сервер`],
    ['warn', (n) => `<b></b> превысил лимит SYNC_MAX_ITEMS`],
    ['', (n) => `<b></b> отключился`],
    ['err', () => `Отклонён ассет неверного типа от <b></b>`],
  ];
  const feed = document.getElementById('feed');
  function pushEvent(animate = true) {
    const [lv, fmt] = pick(EVENTS);
    const li = document.createElement('li');
    if (animate) li.className = 'new';
    const t = new Date().toLocaleTimeString('ru-RU');
    li.innerHTML = `<span class="lv ${lv}"></span><span class="msg">${fmt()}</span><time>${t}</time>`;
    li.querySelector('b').textContent = pick(NAMES);
    feed.prepend(li);
    while (feed.children.length > 30) feed.lastChild.remove();
  }

  // ─── Переключатель диапазона ──────────────────────────────────────────────
  const seg = document.getElementById('range');
  const thumb = seg.querySelector('.seg-thumb');
  let range = '24h';
  function moveThumb() {
    const b = seg.querySelector('button.is-active');
    thumb.style.left = `${b.offsetLeft}px`;
    thumb.style.width = `${b.offsetWidth}px`;
  }
  seg.addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b || b.classList.contains('is-active')) return;
    seg.querySelectorAll('button').forEach((x) => x.classList.toggle('is-active', x === b));
    moveThumb();
    range = b.dataset.range;
    load();
  });

  // ─── Загрузка ─────────────────────────────────────────────────────────────
  let current;
  function load() {
    current = makeStats(range);
    document.querySelectorAll('[data-kpi]').forEach((n) => countTo(n, current.kpi[n.dataset.kpi]));
    document.querySelectorAll('[data-spark]').forEach((s) => drawSpark(s, current.spark[s.dataset.spark]));
    drawChart(current);
  }

  document.getElementById('refresh').addEventListener('click', (e) => {
    const ic = e.currentTarget.querySelector('.icon');
    ic.animate([{ transform: 'rotate(0)' }, { transform: 'rotate(360deg)' }], { duration: 600, easing: 'cubic-bezier(.22,1,.36,1)' });
    load(); renderPeers(); tickMeters();
    toast('Данные обновлены');
  });
  document.querySelectorAll('[data-soon], .nav-item[aria-disabled="true"]').forEach((b) =>
    b.addEventListener('click', () => toast('Раздел появится позже', 'clock')));

  // Мобильное меню
  const app = document.getElementById('app');
  document.getElementById('menuBtn').addEventListener('click', () => app.classList.add('nav-open'));
  document.getElementById('scrim').addEventListener('click', () => app.classList.remove('nav-open'));

  // Таймер неактивности сессии (имитация; настоящий таймаут держит сервер)
  const SESSION_SEC = 15 * 60;
  let lastActive = Date.now();
  ['pointerdown', 'keydown'].forEach((ev) => addEventListener(ev, () => { lastActive = Date.now(); }));
  setInterval(() => {
    const left = Math.max(0, SESSION_SEC - Math.floor((Date.now() - lastActive) / 1000));
    document.getElementById('sessionLeft').textContent =
      `${String(Math.floor(left / 60)).padStart(2, '0')}:${String(left % 60).padStart(2, '0')}`;
    if (left === 0) location.href = 'index.html';
  }, 1000);

  let resizeT;
  addEventListener('resize', () => {
    moveThumb();
    clearTimeout(resizeT);
    resizeT = setTimeout(() => current && drawChart(current), 150);
  });

  // Старт
  moveThumb();
  load();
  renderMeters();
  renderPeers();
  for (let i = 0; i < 8; i++) pushEvent(false);
  setInterval(tickMeters, 2500);
  setInterval(() => pushEvent(true), 3200);
  // Живой пульс: пиры онлайн немного плавают
  setInterval(() => {
    const n = document.querySelector('[data-kpi="peers"]');
    current.kpi.peers = Math.max(0, current.kpi.peers + Math.round(rand(-4, 5)));
    countTo(n, current.kpi.peers);
  }, 4000);
})();
