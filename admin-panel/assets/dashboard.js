// БЛОК 1: Демонстрационные данные. Запросов к сервисам и хранения секретов здесь нет.
(() => {
  "use strict";
  const pages = {
    overview: ["Обзор", "grid", "Всё важное о вашем скрипте в одном месте."],
    keys: [
      "Ключи доступа",
      "key",
      "Выдача доступа, сроки действия и привязка к устройствам.",
    ],
    users: [
      "Пользователи",
      "users",
      "Игроки, их доступ и история использования Violite.",
    ],
    sessions: [
      "Сессии",
      "activity",
      "Активные подключения, heartbeat и управление доступом.",
    ],
    bans: [
      "Блокировки",
      "ban",
      "Ограничения по ключу, устройству и Roblox User ID.",
    ],
    releases: [
      "Релизы",
      "box",
      "Версии скрипта, каналы распространения и история публикаций.",
    ],
    loader: [
      "Лоадер",
      "terminal",
      "Вход в Violite: интерфейс ключа и путь до запуска скрипта.",
    ],
    relay: [
      "Relay",
      "server",
      "Синхронизация образов и состояние инфраструктуры.",
    ],
    logs: [
      "Журнал событий",
      "list",
      "История действий владельца, авторизаций и работы сервисов.",
    ],
    settings: [
      "Настройки",
      "settings",
      "Правила доступа, параметры сессий и безопасность панели.",
    ],
  };
  const State = {
    page: "overview",
    range: "24h",
    query: "",
    filter: "Все",
    nextId: 20,
    settings: {
      hwid: true,
      maintenance: false,
      relay: true,
      minVersion: "2.4.0",
      heartbeat: "60",
      ttl: "180",
      retries: "3",
      idle: "15",
      lifetime: "12",
    },
    loader: {
      title: "Добро пожаловать",
      message: "Введите ключ, чтобы запустить Violite.",
      button: "Запустить Violite",
      saveKey: true,
    },
    keys: [
      {
        id: 1,
        key: "VIO-DEMO-A7F2",
        user: "Yany1944",
        plan: "Lifetime",
        role: "owner",
        status: "Активен",
        expires: "Бессрочно",
        hwid: "A81C…09F2",
      },
      {
        id: 2,
        key: "VIO-DEMO-B9D4",
        user: "lunar.exe",
        plan: "30 дней",
        role: "user",
        status: "Активен",
        expires: "07.11.2026",
        hwid: "C94F…11B8",
      },
      {
        id: 3,
        key: "VIO-DEMO-C3E8",
        user: "voidwalker",
        plan: "30 дней",
        role: "user",
        status: "Активен",
        expires: "02.11.2026",
        hwid: "E71A…00D3",
      },
      {
        id: 4,
        key: "VIO-DEMO-D1A6",
        user: "mira",
        plan: "7 дней",
        role: "user",
        status: "Активен",
        expires: "15.10.2026",
        hwid: "F55D…19C2",
      },
      {
        id: 5,
        key: "VIO-DEMO-E8B1",
        user: "Не назначен",
        plan: "30 дней",
        role: "user",
        status: "Не активирован",
        expires: "После активации",
        hwid: "Не привязан",
      },
      {
        id: 6,
        key: "VIO-DEMO-F2C5",
        user: "northstar",
        plan: "7 дней",
        role: "user",
        status: "Истёк",
        expires: "07.10.2026",
        hwid: "B29E…81A4",
      },
    ],
    sessions: [
      {
        id: 1,
        user: "Yany1944",
        uid: "19440001",
        keyId: 1,
        executor: "Potassium",
        version: "2.4.1",
        ping: 42,
        age: "1 ч 24 мин",
        server: "MM2 · EU-01",
        status: "Активна",
      },
      {
        id: 2,
        user: "lunar.exe",
        uid: "19440002",
        keyId: 2,
        executor: "Wave",
        version: "2.4.1",
        ping: 68,
        age: "47 мин",
        server: "MM2 · EU-02",
        status: "Активна",
      },
      {
        id: 3,
        user: "voidwalker",
        uid: "19440003",
        keyId: 3,
        executor: "Potassium",
        version: "2.4.0",
        ping: 51,
        age: "32 мин",
        server: "MM2 · EU-01",
        status: "Активна",
      },
      {
        id: 4,
        user: "mira",
        uid: "19440004",
        keyId: 4,
        executor: "Delta",
        version: "2.4.1",
        ping: 89,
        age: "12 мин",
        server: "MM2 · US-03",
        status: "Активна",
      },
    ],
    bans: [
      {
        id: 1,
        type: "User ID",
        value: "19440999",
        reason: "Нарушение правил доступа",
        duration: "Бессрочно",
        date: "07.10.2026",
      },
    ],
    releases: [
      {
        id: 1,
        version: "2.4.1",
        channel: "Stable",
        date: "08.10.2026",
        status: "Опубликован",
        notes: "Улучшения стабильности и обновление GUI.",
      },
      {
        id: 2,
        version: "2.4.2",
        channel: "Beta",
        date: "08.10.2026",
        status: "Черновик",
        notes: "Подготовка следующего обновления.",
      },
      {
        id: 3,
        version: "2.4.0",
        channel: "Stable",
        date: "02.10.2026",
        status: "Архив",
        notes: "Единая сборка на Kernel.",
      },
    ],
    logs: [
      {
        time: "14:32:08",
        level: "INFO",
        source: "Сессии",
        text: "Yany1944 — сессия продлена",
      },
      {
        time: "14:31:42",
        level: "INFO",
        source: "Ключи",
        text: "Ключ для mira активирован",
      },
      {
        time: "14:28:15",
        level: "INFO",
        source: "Релизы",
        text: "Версия 2.4.1 опубликована в Stable",
      },
      {
        time: "14:25:03",
        level: "WARN",
        source: "Защита",
        text: "Отклонён вход с истёкшим ключом",
      },
      {
        time: "14:20:11",
        level: "INFO",
        source: "Relay",
        text: "Подключение lunar.exe установлено",
      },
    ],
  };
  const content = document.getElementById("content");
  const modal = document.getElementById("modal");
  const modalForm = document.getElementById("modalForm");
  let submitHandler = null;
  const esc = (s) =>
    String(s).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const active = () => State.sessions.filter((s) => s.status === "Активна");
  const currentRelease = () =>
    State.releases.find(
      (r) => r.status === "Опубликован" && r.channel === "Stable",
    );
  const badge = (text, color = "") =>
    `<span class="badge ${color}">${esc(text)}</span>`;
  const status = (text) =>
    badge(
      text,
      /Истёк|Завершена|Архив/.test(text)
        ? "neutral"
        : /Отозван|Заблокирован/.test(text)
          ? "red"
          : /Черновик|Не активирован/.test(text)
            ? "amber"
            : "",
    );
  const btn = (text, action, ic = "", cls = "", id = "") =>
    `<button type="button" class="btn ${cls}" data-action="${action}" ${id !== "" ? `data-id="${id}"` : ""}>${ic ? icon(ic) : ""}${text}</button>`;
  const go = (page, text) =>
    `<button class="text-link" data-go="${page}" aria-label="${text || pages[page][0]}">${text}${icon("arrow")}</button>`;
  const userCell = (name, sub = "") =>
    `<div class="user-cell"><span class="avatar">${esc(name.slice(0, 2).toUpperCase())}</span><span>${esc(name)}${sub ? `<small>${esc(sub)}</small>` : ""}</span></div>`;
  const card = (title, sub, body, action = "", cls = "") =>
    `<section class="card ${cls}"><div class="card-head"><div><h2>${title}</h2>${sub ? `<div class="sub">${sub}</div>` : ""}</div>${action}</div><div class="card-body">${body}</div></section>`;
  const field = (name, label, value = "", type = "text", extra = "") =>
    `<div class="field"><label for="f-${name}">${label}</label><input class="input" id="f-${name}" name="${name}" type="${type}" value="${esc(value)}" ${extra}></div>`;
  const select = (name, label, options, value = "") =>
    `<div class="field"><label for="f-${name}">${label}</label><select id="f-${name}" name="${name}">${options.map((o) => `<option ${o === value ? "selected" : ""}>${esc(o)}</option>`).join("")}</select></div>`;
  const switchRow = (key, title, desc, group = "settings") =>
    `<div class="setting-row"><div><b>${title}</b><p>${desc}</p></div><button type="button" class="switch" role="switch" aria-label="${title}" aria-checked="${State[group][key]}" data-toggle="${key}" data-group="${group}"></button></div>`;
  const table = (headers, rows) =>
    `<div class="table-scroll"><table class="table"><thead><tr>${headers.map((h) => `<th scope="col">${h}</th>`).join("")}</tr></thead><tbody>${rows.length ? rows.join("") : `<tr><td colspan="${headers.length}"><div class="empty">${icon("search")}<strong>Ничего не найдено</strong>Попробуйте другой запрос или фильтр.</div></td></tr>`}</tbody></table></div>`;
  const row = (cells) =>
    `<tr>${cells.map((c) => `<td>${c}</td>`).join("")}</tr>`;
  const matches = (item) =>
    Object.values(item)
      .join(" ")
      .toLowerCase()
      .includes(State.query.toLowerCase());
  const metric = (label, value, foot, ic, index = 0) =>
    `<div class="metric"><div class="metric-label">${label}${icon(ic)}</div><div class="metric-value">${value}</div><div class="metric-foot">${foot}</div><svg class="metric-spark" viewBox="0 0 80 30" aria-hidden="true"><path d="M0 ${23 - index * 2} L8 22 L14 25 L23 15 L30 18 L39 10 L47 13 L55 7 L62 11 L72 5 L80 8" fill="none" stroke="var(--accent)" stroke-width="1.5"/></svg></div>`;
  const head = (actions = "") =>
    `<div class="page-head"><div><span class="eyebrow">VIOLITE / ${State.page === "overview" ? "WORKSPACE" : "CONTROL"}</span><h1>${pages[State.page][0]}</h1><p>${pages[State.page][2]}</p></div><div class="head-actions">${actions}</div></div>`;
  const toolbar = (placeholder, filters = []) =>
    `<div class="toolbar"><input id="filterQuery" class="input" aria-label="Поиск в разделе" placeholder="${placeholder}" value="${esc(State.query)}">${filters.length ? `<select id="filterStatus" aria-label="Фильтр">${["Все", ...filters].map((f) => `<option ${f === State.filter ? "selected" : ""}>${f}</option>`).join("")}</select>` : ""}<span class="toolbar-count">Демонстрационные записи</span></div>`;
  function log(source, text, level = "INFO") {
    State.logs.unshift({
      time: new Date().toLocaleTimeString("ru-RU", {
        timeZone: "Europe/Moscow",
      }),
      source,
      text,
      level,
    });
  }
  function updated(message) {
    log("Панель", message);
    render();
    toast(`${message} · демо`);
  }
  function navigate(page) {
    if (pages[page]) {
      if (State.page === page) render();
      else location.hash = page;
    }
  }

  // БЛОК 2: Главная страница и сводные компоненты.
  function chart() {
    const values =
      State.range === "1h"
        ? [
            18, 22, 20, 31, 27, 34, 31, 28, 36, 30, 32, 40, 37, 44, 42, 38, 45,
            40, 49, 44, 43, 50, 46, 47,
          ]
        : State.range === "7d"
          ? [
              12, 17, 15, 21, 18, 26, 22, 25, 31, 30, 27, 37, 32, 38, 40, 34,
              44, 39, 45, 42, 49, 44, 46, 50,
            ]
          : [
              18, 21, 19, 25, 22, 20, 27, 24, 28, 21, 29, 26, 36, 33, 39, 31,
              36, 41, 35, 39, 34, 43, 38, 42,
            ];
    const points = values
      .map((v, i) => `${(i * 600) / (values.length - 1)},${155 - v * 2.6}`)
      .join(" ");
    const previous = values
      .map((v, i) => `${(i * 600) / (values.length - 1)},${175 - v * 1.5}`)
      .join(" ");
    const labels =
      State.range === "1h"
        ? ["13:30", "13:40", "13:50", "14:00", "14:10", "14:30"]
        : State.range === "7d"
          ? ["02 окт", "03 окт", "04 окт", "05 окт", "06 окт", "08 окт"]
          : ["00:00", "04:00", "08:00", "12:00", "16:00", "20:00"];
    return `<div class="chart-meta"><span><i class="legend-dot"></i>Выданные сессии</span><span><i class="legend-dot dim"></i>Предыдущий период</span></div><svg class="chart" viewBox="0 0 600 175" preserveAspectRatio="none" role="img" aria-label="Демонстрационный график выданных сессий за ${State.range}"><defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#a599ff" stop-opacity=".2"/><stop offset="1" stop-color="#a599ff" stop-opacity="0"/></linearGradient></defs>${[20, 65, 110, 155].map((y) => `<path class="chart-grid" d="M0 ${y}H600"/>`).join("")}<polyline points="${previous}" fill="none" stroke="#605d71" stroke-width="1.5" stroke-dasharray="4 5"/><polygon points="0,175 ${points} 600,175" fill="url(#area)"/><polyline points="${points}" fill="none" stroke="#a599ff" stroke-width="2" vector-effect="non-scaling-stroke"/></svg><div class="chart-labels">${labels.map((l) => `<span>${l}</span>`).join("")}</div>`;
  }
  function sessionRows(list, compact = false) {
    return list.map((s) =>
      row([
        userCell(s.user, compact ? s.executor : `ID ${s.uid}`),
        ...(compact
          ? [
              badge("v" + s.version, "neutral"),
              `<span class="mono">${s.age}</span>`,
              status(s.status),
            ]
          : [
              esc(s.executor),
              badge("v" + s.version, "neutral"),
              `<span class="mono">${s.ping} мс</span>`,
              esc(s.age),
              status(s.status),
            ]),
        btn("Открыть", "session-detail", "", "btn-ghost btn-small", s.id),
      ]),
    );
  }
  function overview() {
    const release = currentRelease();
    return (
      head(btn("Новый ключ", "new-key", "plus", "btn-primary")) +
      `<div class="status-strip">${icon("shield")}<span>${State.settings.maintenance ? "Выдача сессий приостановлена в макете" : "Сценарий: защита активна, сервисы доступны"}</span><span class="status-right">Демо-снимок · 08 октября 2026</span></div><div class="metrics">${metric("Активные сессии", active().length, "<span>Подключения в демо-наборе</span>", "activity")}${metric("Ключи доступа", State.keys.filter((k) => k.status === "Активен").length, `${State.keys.length} ключей всего`, "key", 1)}${metric("Успешные входы", "98.6<small>%</small>", "<b>↑ 1.2%</b><span>к прошлым суткам</span>", "shield", 2)}${metric("Время ответа", "42<small>мс</small>", "<b>↓ 8 мс</b><span>медиана за 24 часа</span>", "zap", 3)}</div><div class="overview-grid"><div class="stack"><section class="card"><div class="card-head"><div><h2>Активность скрипта</h2><div class="sub">Запуски и выдача сессий</div></div><div class="seg">${["1h", "24h", "7d"].map((r, i) => `<button data-range="${r}" class="${State.range === r ? "is-active" : ""}" aria-pressed="${State.range === r}">${["1ч", "24ч", "7д"][i]}</button>`).join("")}</div></div><div class="card-body">${chart()}</div><div class="chart-summary"><span>Выдано <b>${State.range === "1h" ? "86" : State.range === "7d" ? "5 284" : "842"}</b></span><span>Отклонено <b>${State.range === "1h" ? "2" : State.range === "7d" ? "74" : "12"}</b></span><span>Доступность <b>99.98%</b></span></div></section><section class="card"><div class="card-head"><div><h2>Сейчас в Violite</h2><div class="sub">Последние активные подключения</div></div>${go("sessions", "Все сессии")}</div>${table(["Игрок", "Версия", "В игре", "Статус", ""], sessionRows(active(), true))}<div class="table-foot"><span>${active().length} активных сессий</span><span>Heartbeat · ${esc(State.settings.heartbeat)} с</span></div></section><div class="quick-actions">${[
        ["key", "Выдать доступ", "Создать новый ключ", "new-key"],
        ["box", "Новый релиз", "Подготовить обновление", "new-release"],
        ["ban", "Блокировка", "Ограничить доступ", "new-ban"],
      ]
        .map(
          ([ic, t, d, a]) =>
            `<button class="quick-action" data-action="${a}">${icon(ic)}<span>${t}<small>${d}</small></span>${icon("arrow")}</button>`,
        )
        .join(
          "",
        )}</div></div><div class="stack">${card("Текущий релиз", "Основной канал распространения", `<div class="release-title"><span class="release-version">v${esc(release?.version || "—")}</span>${badge("Stable", "purple")}</div><p class="sub">${esc(release?.notes || "Нет опубликованной версии")}</p><dl class="kv"><dt>Опубликован</dt><dd>${esc(release?.date || "—")}</dd><dt>Минимальная версия</dt><dd class="mono">${esc(State.settings.minVersion)}</dd><dt>Доставка</dt><dd>Junkie / Luraph</dd></dl><button class="btn full" data-go="releases">Управление релизами${icon("arrow")}</button>`, "", "release-card")}${card("Состояние сервисов", "Демонстрационный статус", `<div class="service-row">${icon("shield")}<span>Авторизация<small>Ключи и выдача сессий</small></span>${badge(State.settings.maintenance ? "Пауза" : "Доступна", State.settings.maintenance ? "amber" : "")}</div><div class="service-row">${icon("activity")}<span>Heartbeat<small>Продление доступа</small></span>${badge("Доступен")}</div><div class="service-row">${icon("server")}<span>Skin relay<small>Синхронизация образов</small></span>${badge(State.settings.relay ? "Доступен" : "Пауза", State.settings.relay ? "" : "amber")}</div>`, go("relay", ""))}<section class="card"><div class="card-head"><h2>Последние события</h2>${go("logs", "Все")}</div><ul class="activity-list">${State.logs
        .slice(0, 3)
        .map(
          (l, i) =>
            `<li><span class="activity-icon">${icon(["activity", "key", "box"][i])}</span><div>${esc(l.source)}<p>${esc(l.text)}</p></div><span class="time">${esc(l.time.slice(0, 5))}</span></li>`,
        )
        .join("")}</ul></section></div></div>`
    );
  }

  // БЛОК 3: Разделы доступа и управления версиями.
  function listPage(title, subtitle, action, search, filters, headers, rows) {
    return (
      head(action) +
      `<section class="card"><div class="card-head"><div><h2>${title}</h2><div class="sub">${subtitle}</div></div>${badge("DEMO", "neutral")}</div>${toolbar(search, filters)}<div id="tableResult">${table(headers, rows)}</div><div class="table-foot"><span id="resultCount">Найдено: ${rows.length}</span><span>Поиск по всем полям</span></div></section>`
    );
  }
  function listData() {
    const q = (items) => items.filter(matches);
    if (State.page === "keys") {
      const items = q(State.keys).filter(
        (k) => State.filter === "Все" || k.status === State.filter,
      );
      return {
        headers: [
          "Ключ / владелец",
          "Тариф",
          "Роль",
          "Срок действия",
          "HWID",
          "Статус",
          "",
        ],
        rows: items.map((k) =>
          row([
            `<span class="mono">${esc(k.key)}</span><div class="sub">${esc(k.user)}</div>`,
            esc(k.plan),
            badge(k.role, k.role === "owner" ? "purple" : "neutral"),
            esc(k.expires),
            `<span class="mono">${esc(k.hwid)}</span>`,
            status(k.status),
            btn("Управлять", "key-detail", "", "btn-small btn-ghost", k.id),
          ]),
        ),
      };
    }
    if (State.page === "sessions") {
      const items = q(State.sessions).filter(
        (s) => State.filter === "Все" || s.status === State.filter,
      );
      return {
        headers: [
          "Игрок",
          "Executor",
          "Версия",
          "Отклик",
          "Длительность",
          "Статус",
          "",
        ],
        rows: sessionRows(items),
      };
    }
    if (State.page === "users") {
      const items = q(
        State.keys.filter((k) => k.user !== "Не назначен"),
      ).filter((k) => State.filter === "Все" || k.role === State.filter);
      return {
        headers: ["Пользователь", "Роль", "Доступ", "Устройство", "Сессии", ""],
        rows: items.map((k) =>
          row([
            userCell(k.user),
            badge(k.role, k.role === "owner" ? "purple" : "neutral"),
            status(k.status),
            esc(k.hwid),
            String(active().filter((s) => s.keyId === k.id).length),
            btn("Профиль", "user-detail", "", "btn-small btn-ghost", k.id),
          ]),
        ),
      };
    }
    if (State.page === "bans") {
      const items = q(State.bans).filter(
        (b) => State.filter === "Все" || b.type === State.filter,
      );
      return {
        headers: ["Ограничение", "Тип", "Причина", "Срок", "Создано", ""],
        rows: items.map((b) =>
          row([
            `<span class="mono">${esc(b.value)}</span>`,
            badge(b.type, "red"),
            esc(b.reason),
            esc(b.duration),
            esc(b.date),
            btn("Снять", "remove-ban", "", "btn-small btn-ghost", b.id),
          ]),
        ),
      };
    }
    if (State.page === "releases") {
      const items = q(State.releases).filter(
        (r) => State.filter === "Все" || r.channel === State.filter,
      );
      return {
        headers: ["Версия", "Канал", "Дата", "Изменения", "Статус", ""],
        rows: items.map((r) =>
          row([
            `<b class="mono">v${esc(r.version)}</b>`,
            badge(r.channel, r.channel === "Stable" ? "purple" : "amber"),
            esc(r.date),
            esc(r.notes),
            status(r.status),
            btn("Подробнее", "release-detail", "", "btn-small btn-ghost", r.id),
          ]),
        ),
      };
    }
    const items = q(State.logs).filter(
      (l) => State.filter === "Все" || l.level === State.filter,
    );
    return {
      headers: ["Время · МСК", "Уровень", "Источник", "Событие"],
      rows: items.map((l) =>
        row([
          `<span class="mono">${esc(l.time)}</span>`,
          badge(
            l.level,
            l.level === "WARN"
              ? "amber"
              : l.level === "ERROR"
                ? "red"
                : "neutral",
          ),
          esc(l.source),
          esc(l.text),
        ]),
      ),
    };
  }
  const listConfig = {
    keys: [
      "Все ключи",
      "Доступ к скрипту и привязки устройств",
      "new-key",
      "Новый ключ",
      "Поиск по ключу, игроку, HWID…",
      ["Активен", "Не активирован", "Истёк", "Отозван"],
    ],
    users: [
      "Пользователи Violite",
      "Профили владельцев ключей",
      null,
      null,
      "Поиск по имени или устройству…",
      ["owner", "user"],
    ],
    sessions: [
      "Подключения",
      "Состояние доступа и последние heartbeat",
      null,
      null,
      "Поиск по игроку, версии, executor…",
      ["Активна", "Завершена"],
    ],
    bans: [
      "Список блокировок",
      "Правила отказа при выдаче доступа",
      "new-ban",
      "Добавить блокировку",
      "Поиск по идентификатору или причине…",
      ["User ID", "HWID", "Ключ"],
    ],
    releases: [
      "История версий",
      "Черновики, опубликованные и архивные сборки",
      "new-release",
      "Новый релиз",
      "Поиск по версии и описанию…",
      ["Stable", "Beta"],
    ],
    logs: [
      "Аудит и диагностика",
      "Демонстрационная история событий",
      "export-logs",
      "Экспорт JSON",
      "Поиск по событию или источнику…",
      ["INFO", "WARN", "ERROR"],
    ],
  };
  function listing() {
    const [title, sub, action, label, placeholder, filters] =
      listConfig[State.page];
    const data = listData();
    return listPage(
      title,
      sub,
      action
        ? btn(
            label,
            action,
            action === "export-logs" ? "download" : "plus",
            action === "export-logs" ? "" : "btn-primary",
          )
        : "",
      placeholder,
      filters,
      data.headers,
      data.rows,
    );
  }
  function updateList() {
    const data = listData();
    document.getElementById("tableResult").innerHTML = table(
      data.headers,
      data.rows,
    );
    document.getElementById("resultCount").textContent =
      `Найдено: ${data.rows.length}`;
  }
  // БЛОК 4: Лоадер, инфраструктура и настройки.
  function loader() {
    return (
      head() +
      `<div class="section-grid">${card("Окно запуска", "Концепт будущего GUI лоадера", `<p class="preview-label">ПРЕДПРОСМОТР / ${badge("UI CONCEPT", "purple")}</p><div class="loader-preview"><div class="brand"><span class="brand-mark">v<span>˙</span></span><span><strong>violite</strong><small>MURDER MYSTERY 2</small></span></div><h3>${esc(State.loader.title)}</h3><p>${esc(State.loader.message)}</p><input class="input mono" aria-label="Демонстрационный ключ лоадера" placeholder="VIO-XXXX-XXXX-XXXX" id="previewKey"><button class="btn btn-primary full" data-action="preview-launch">${esc(State.loader.button)}${icon("arrow")}</button><div class="loader-bottom"><span>Демо · ключ не проверяется</span><span>v2.4</span></div></div><div class="form-note">Этот экран задаёт внешний вид. Roblox-лоадер на вашей GUI-библиотеке будет следующим этапом.</div>`)}${card("Содержимое лоадера", "Тексты и поведение окна", `<form data-form="loader">${field("title", "Заголовок", State.loader.title, "text", 'required maxlength="70"')}${field("message", "Подсказка к ключу", State.loader.message, "text", 'required maxlength="160"')}${field("button", "Текст кнопки", State.loader.button, "text", 'required maxlength="40"')}${switchRow("saveKey", "Запоминать ключ", "Место для будущего сохранения в VioCFG/Violite.", "loader")}<div style="margin-top:20px"><button class="btn btn-primary" type="submit">Применить к макету</button></div></form>`)}${card("Путь запуска", "Порядок интеграции с системой доступа", `<div class="flow"><div class="flow-step"><span class="eyebrow">01 / UI SOURCE</span><b>Ввод ключа</b><p>GUI Violite получает ключ пользователя.</p></div>${icon("arrow")}<div class="flow-step"><span class="eyebrow">02 / JUNKIE</span><b>Проверка доступа</b><p>SCRIPT_KEY передаётся системе ключей.</p></div>${icon("arrow")}<div class="flow-step"><span class="eyebrow">03 / KERNEL</span><b>Выдача сессии</b><p>Запуск бандла и продление доступа.</p></div></div><div class="setting-row"><div><b>Источник лоадера</b><p>Публикация UI Source и привязка к Original Code.</p></div>${badge("Не подключён", "amber")}</div>`, "", "wide")}</div>`
    );
  }
  function relay() {
    const connected = State.settings.relay ? active() : [];
    return (
      head(btn("Проверить статус", "relay-check", "refresh")) +
      `<div class="metrics">${metric("Подключения", connected.length, "Пиры в текущем демо-наборе", "users")}${metric("Синхронизаций / мин", State.settings.relay ? "128" : "0", "Демонстрационные измерения", "refresh")}${metric("Задержка p95", "64<small>мс</small>", "Демонстрационные измерения", "activity")}${metric("Доступность", "99.98<small>%</small>", "Демонстрационные измерения", "server")}</div><div class="section-grid">${card(
        "Ресурсы сервера",
        "Пример будущей телеметрии",
        [
          ["CPU", 24, "24%"],
          ["Оперативная память", 38, "384 МБ / 1 ГБ"],
          ["Хранилище", 17, "3.4 ГБ / 20 ГБ"],
          ["Сеть", 12, "1.2 Мбит/с"],
        ]
          .map(
            ([t, p, v]) =>
              `<div class="meter-label">${t}<span>${v}</span></div><div class="meter"><i style="width:${p}%"></i></div>`,
          )
          .join(""),
      )}${card("Управление relay", "Синхронизация образов игроков", `${switchRow("relay", "Принимать подключения", "В макете изменяет состояние сервиса и список пиров.")}<dl class="kv"><dt>Транспорт</dt><dd>WebSocket / TLS</dd><dt>Контур</dt><dd>Skin sync</dd><dt>Статус</dt><dd>${badge(State.settings.relay ? "Доступен" : "Пауза", State.settings.relay ? "" : "amber")}</dd></dl><div class="form-note">Перезапуск и диагностика будут подключены к серверу. Здесь можно просмотреть сценарий действия.</div>${btn("Перезапуск сервиса", "restart-relay", "refresh")}`)}<section class="card wide"><div class="card-head"><div><h2>Подключённые пиры</h2><div class="sub">Синхронизация в пределах игрового сервера</div></div></div>${table(
        ["Игрок", "Игровой сервер", "Отклик", "Состояние"],
        connected.map((s) =>
          row([
            userCell(s.user),
            esc(s.server),
            `${s.ping} мс`,
            badge("Синхронизирован"),
          ]),
        ),
      )}</section></div>`
    );
  }
  function settings() {
    return (
      head() +
      `<div class="section-grid">${card("Правила доступа", "Проверки при выдаче сессии", `${switchRow("hwid", "Привязка к устройству", "Один ключ — одно устройство. Сброс доступен в карточке ключа.")}${switchRow("maintenance", "Техническое обслуживание", "Приостановить выдачу новых сессий.")}<form data-form="access" style="margin-top:22px">${field("minVersion", "Минимальная версия", State.settings.minVersion, "text", 'required pattern="[0-9]+[.][0-9]+[.][0-9]+"')}<button class="btn" type="submit">Сохранить правила</button></form>`)}${card("Жизненный цикл сессии", "Продление и поведение при потере связи", `<form data-form="session-settings"><div class="field-row">${field("heartbeat", "Heartbeat, секунды", State.settings.heartbeat, "number", 'required min="10" max="300"')}${field("ttl", "Срок сессии, секунды", State.settings.ttl, "number", 'required min="30" max="3600"')}</div>${field("retries", "Допустимые сетевые сбои", State.settings.retries, "number", 'required min="1" max="10"')}<button class="btn" type="submit">Сохранить параметры</button></form>`)}${card("Вход в панель", "Учётная запись владельца", `<div class="setting-row"><div><b>Двухфакторная проверка</b><p>Настройка TOTP и резервных кодов.</p></div>${btn("Настроить", "setup-2fa", "", "btn-small")}</div><div class="setting-row"><div><b>Пароль владельца</b><p>Изменение пароля и завершение входов.</p></div>${btn("Изменить", "change-password", "", "btn-small")}</div><div class="form-note" style="margin-top:20px;margin-bottom:0">Авторизация ещё не подключена. В макет не нужно вводить настоящие пароли и секреты.</div>`)}${card("Сессия панели", "Ограничения для будущего входа", `<form data-form="panel-settings"><div class="field-row">${field("idle", "Без активности, минуты", State.settings.idle, "number", 'required min="1" max="120"')}${field("lifetime", "Максимум, часы", State.settings.lifetime, "number", 'required min="1" max="24"')}</div><button class="btn" type="submit">Сохранить ограничения</button></form>`)}${card("Экстренное отключение", "Глобальное управление доступом", `<div class="setting-row"><div><b>Завершить все сессии</b><p>Будущая команда Kernel.Kill для всех подключений. В макете завершает демонстрационные сессии.</p></div>${btn("Отключить всех", "kill-all", "ban", "btn-danger")}</div><div class="setting-row"><div><b>Вернуть исходный макет</b><p>Сбросить все локальные изменения и демонстрационные записи.</p></div>${btn("Сбросить", "reset-demo", "", "btn-ghost")}</div>`, "", "wide danger-zone")}</div>`
    );
  }

  // БЛОК 5: Диалоги. Все изменения ограничены памятью этой страницы.
  function openModal(title, body, handler = null, submitText = "Сохранить") {
    document.getElementById("modalTitle").textContent = title;
    document.getElementById("modalBody").innerHTML = body;
    document.getElementById("submitModal").textContent = submitText;
    document.getElementById("submitModal").hidden = !handler;
    document.getElementById("cancelModal").textContent = handler
      ? "Отмена"
      : "Закрыть";
    submitHandler = handler;
    if (!modal.open) modal.showModal();
    requestAnimationFrame(() =>
      modal
        .querySelector("#modalBody input, #modalBody select, #modalBody button")
        ?.focus(),
    );
  }
  function confirmDemo(title, description, fn, label = "Подтвердить") {
    openModal(
      title,
      `<div class="form-note">${description}</div>`,
      () => {
        fn();
        return true;
      },
      label,
    );
  }
  function newKey() {
    openModal(
      "Выдать доступ",
      `<div class="form-note">Будет создан демонстрационный ключ. Для реального доступа позже подключим систему ключей.</div>${field("user", "Получатель", "", "text", 'required maxlength="50" placeholder="Имя игрока"')}<div class="field-row">${select("plan", "Срок доступа", ["7 дней", "30 дней", "Lifetime"], "30 дней")}${select("role", "Роль", ["user", "owner"])}</div>`,
      (data) => {
        const id = ++State.nextId;
        const plan = data.get("plan");
        State.keys.unshift({
          id,
          key: `VIO-DEMO-${String(id).padStart(4, "0")}`,
          user: data.get("user").trim(),
          plan,
          role: data.get("role"),
          status: "Не активирован",
          expires: plan === "Lifetime" ? "Бессрочно" : "После активации",
          hwid: "Не привязан",
        });
        updated("Демонстрационный ключ создан");
        return true;
      },
      "Создать ключ",
    );
  }
  function keyDetail(id) {
    const k = State.keys.find((k) => k.id === id);
    if (!k) return;
    openModal(
      "Ключ доступа",
      `<div class="form-note mono">${esc(k.key)}</div><dl class="kv"><dt>Владелец</dt><dd>${esc(k.user)}</dd><dt>Статус</dt><dd>${status(k.status)}</dd><dt>Устройство</dt><dd>${esc(k.hwid)}</dd></dl><div class="field-row">${select("plan", "Тариф", ["7 дней", "30 дней", "Lifetime"], k.plan)}${select("role", "Роль", ["user", "owner"], k.role)}</div>${field("expires", "Срок действия", k.expires, "text", 'required maxlength="50"')}<div class="head-actions" style="margin-bottom:20px;flex-wrap:wrap">${btn("Сбросить HWID", "reset-hwid", "refresh", "", k.id)}${k.status !== "Отозван" ? btn("Отозвать ключ", "revoke-key", "ban", "btn-danger", k.id) : ""}</div>`,
      (data) => {
        k.plan = data.get("plan");
        k.role = data.get("role");
        k.expires = data.get("expires").trim();
        updated("Параметры ключа изменены");
        return true;
      },
    );
  }
  function sessionDetail(id) {
    const s = State.sessions.find((s) => s.id === id);
    if (!s) return;
    openModal(
      "Сессия игрока",
      `${userCell(s.user, `Roblox ID ${s.uid}`)}<dl class="kv"><dt>Состояние</dt><dd>${status(s.status)}</dd><dt>Executor</dt><dd>${esc(s.executor)}</dd><dt>Версия</dt><dd>${esc(s.version)}</dd><dt>Игровой сервер</dt><dd>${esc(s.server)}</dd><dt>Время в игре</dt><dd>${esc(s.age)}</dd><dt>Heartbeat</dt><dd>${s.status === "Активна" ? "8 секунд назад" : "Остановлен"}</dd></dl>${s.status === "Активна" ? btn("Завершить сессию", "kill-session", "ban", "btn-danger", id) : ""}`,
    );
  }
  function userDetail(id) {
    const k = State.keys.find((k) => k.id === id);
    if (!k) return;
    const s = State.sessions.find((s) => s.keyId === id);
    openModal(
      "Профиль пользователя",
      `${userCell(k.user, k.role)}<dl class="kv"><dt>Roblox User ID</dt><dd>${esc(s?.uid || "Ещё не получен")}</dd><dt>Ключ</dt><dd class="mono">${esc(k.key)}</dd><dt>Доступ</dt><dd>${status(k.status)}</dd><dt>Срок</dt><dd>${esc(k.expires)}</dd><dt>Устройство</dt><dd>${esc(k.hwid)}</dd></dl><div class="head-actions">${btn("Управлять ключом", "key-detail", "key", "", id)}${btn("Блокировать", "ban-user", "ban", "btn-danger", id)}</div>`,
    );
  }
  function newBan(type = "User ID", value = "") {
    openModal(
      "Добавить блокировку",
      `${select("type", "Тип ограничения", ["User ID", "HWID", "Ключ"], type)}${field("value", "Идентификатор", value, "text", 'required maxlength="100"')}${field("reason", "Причина", "", "text", 'required maxlength="180"')}${select("duration", "Срок", ["24 часа", "7 дней", "Бессрочно"], "Бессрочно")}`,
      (data) => {
        const ban = {
          id: ++State.nextId,
          type: data.get("type"),
          value: data.get("value").trim(),
          reason: data.get("reason").trim(),
          duration: data.get("duration"),
          date: new Date().toLocaleDateString("ru-RU", {
            timeZone: "Europe/Moscow",
          }),
        };
        if (ban.type === "User ID" && !/^\d+$/.test(ban.value)) {
          modalForm.elements.value.setCustomValidity(
            "Укажите числовой Roblox User ID",
          );
          modalForm.elements.value.reportValidity();
          return false;
        }
        State.bans.unshift(ban);
        State.sessions.forEach((s) => {
          const k = State.keys.find((k) => k.id === s.keyId);
          if (
            (ban.type === "User ID" && s.uid === ban.value) ||
            (ban.type === "Ключ" && k?.key === ban.value) ||
            (ban.type === "HWID" && k?.hwid === ban.value)
          )
            s.status = "Завершена";
        });
        updated("Блокировка добавлена");
        return true;
      },
      "Добавить",
    );
  }
  function newRelease() {
    openModal(
      "Подготовить релиз",
      `${field("version", "Версия", "", "text", 'required pattern="[0-9]+[.][0-9]+[.][0-9]+" placeholder="2.5.0"')}${select("channel", "Канал", ["Stable", "Beta"], "Beta")}<div class="field"><label for="f-notes">Что изменилось</label><textarea name="notes" id="f-notes" rows="4" required maxlength="300" placeholder="Описание обновления"></textarea></div><div class="form-note">Создаётся карточка черновика. Загрузка бандла и публикация в Junkie будут подключены позже.</div>`,
      (data) => {
        if (
          State.releases.some(
            (r) =>
              r.version === data.get("version") &&
              r.channel === data.get("channel"),
          )
        ) {
          modalForm.elements.version.setCustomValidity(
            "Эта версия уже есть в выбранном канале",
          );
          modalForm.elements.version.reportValidity();
          return false;
        }
        State.releases.unshift({
          id: ++State.nextId,
          version: data.get("version"),
          channel: data.get("channel"),
          date: new Date().toLocaleDateString("ru-RU", {
            timeZone: "Europe/Moscow",
          }),
          status: "Черновик",
          notes: data.get("notes").trim(),
        });
        updated("Черновик релиза создан");
        return true;
      },
      "Создать черновик",
    );
  }
  function releaseDetail(id) {
    const r = State.releases.find((r) => r.id === id);
    if (!r) return;
    openModal(
      `Релиз ${r.version}`,
      `<div class="head-actions">${badge(r.channel, "purple")}${status(r.status)}</div><p class="form-note" style="margin-top:18px">${esc(r.notes)}</p><dl class="kv"><dt>Версия</dt><dd>${esc(r.version)}</dd><dt>Создан</dt><dd>${esc(r.date)}</dd><dt>Бандл</dt><dd>Не загружен</dd><dt>Junkie</dt><dd>Не подключён</dd></dl><div class="form-note">Действие меняет статус только в макете. Реальная сборка и доставка не выполняются.</div>${r.status !== "Опубликован" ? btn(r.status === "Архив" ? "Сценарий отката" : "Сценарий публикации", "publish-release", "box", "btn-primary", id) : ""}`,
    );
  }
  function search() {
    openModal(
      "Найти в панели",
      '<input class="input" id="globalSearch" aria-label="Поиск разделов, игроков и ключей" placeholder="Раздел, игрок или ключ…"><div id="searchResults" class="search-results"></div>',
    );
    const input = document.getElementById("globalSearch");
    const update = () => {
      const q = input.value.toLowerCase().trim();
      const hits = [
        ...Object.entries(pages)
          .filter(([, p]) => p[0].toLowerCase().includes(q))
          .map(
            ([id, p]) =>
              `<button type="button" class="search-result" data-search-go="${id}">${icon(p[1])}${p[0]}<small>Раздел</small></button>`,
          ),
        ...State.keys
          .filter((k) => (k.user + " " + k.key).toLowerCase().includes(q))
          .map(
            (k) =>
              `<button type="button" class="search-result" data-action="key-detail" data-id="${k.id}">${icon("key")}<span>${esc(k.user)}<small style="display:block">${esc(k.key)}</small></span><small>Ключ</small></button>`,
          ),
      ];
      document.getElementById("searchResults").innerHTML = hits.length
        ? hits.join("")
        : '<div class="empty">Ничего не найдено</div>';
    };
    input.addEventListener("input", update);
    update();
    requestAnimationFrame(() => input.focus());
  }
  // БЛОК 6: Действия макета и навигация.
  const actions = {
    "new-key": newKey,
    "new-ban": () => newBan(),
    "new-release": newRelease,
    "key-detail": keyDetail,
    "session-detail": sessionDetail,
    "user-detail": userDetail,
    "release-detail": releaseDetail,
    "ban-user": (id) => {
      const s = State.sessions.find((s) => s.keyId === id);
      const k = State.keys.find((k) => k.id === id);
      newBan(s ? "User ID" : "Ключ", s?.uid || k.key);
    },
    "reset-hwid": (id) =>
      confirmDemo(
        "Сбросить привязку?",
        "Следующая авторизация сможет привязать ключ к другому устройству. В макете изменится только запись ключа.",
        () => {
          State.keys.find((k) => k.id === id).hwid = "Не привязан";
          updated("Привязка устройства сброшена");
        },
        "Сбросить",
      ),
    "revoke-key": (id) =>
      confirmDemo(
        "Отозвать ключ?",
        "Доступ по ключу будет закрыт, связанные демонстрационные сессии завершатся.",
        () => {
          State.keys.find((k) => k.id === id).status = "Отозван";
          State.sessions
            .filter((s) => s.keyId === id)
            .forEach((s) => (s.status = "Завершена"));
          updated("Ключ отозван");
        },
        "Отозвать",
      ),
    "kill-session": (id) =>
      confirmDemo(
        "Завершить сессию?",
        "В реальном сервисе это действие отправит команду выгрузки скрипта. Здесь завершится демонстрационная сессия.",
        () => {
          State.sessions.find((s) => s.id === id).status = "Завершена";
          updated("Сессия завершена");
        },
        "Завершить",
      ),
    "kill-all": () =>
      confirmDemo(
        "Отключить всех пользователей?",
        `Будут завершены все активные сессии макета: ${active().length}.`,
        () => {
          State.sessions.forEach((s) => (s.status = "Завершена"));
          updated("Все сессии завершены");
        },
        "Отключить всех",
      ),
    "remove-ban": (id) =>
      confirmDemo(
        "Снять блокировку?",
        "Ограничение исчезнет из демонстрационного списка. Завершённые сессии автоматически не восстановятся.",
        () => {
          State.bans = State.bans.filter((b) => b.id !== id);
          updated("Блокировка снята");
        },
        "Снять",
      ),
    "publish-release": (id) => {
      const r = State.releases.find((r) => r.id === id);
      confirmDemo(
        "Изменить текущий релиз?",
        `Версия ${esc(r.version)} станет текущей для канала ${esc(r.channel)} в макете.`,
        () => {
          State.releases
            .filter(
              (x) => x.channel === r.channel && x.status === "Опубликован",
            )
            .forEach((x) => (x.status = "Архив"));
          r.status = "Опубликован";
          updated("Статус релиза изменён");
        },
        "Применить в макете",
      );
    },
    "restart-relay": () =>
      confirmDemo(
        "Перезапуск relay",
        "Место для подтверждения перезапуска сервиса. Сервер не подключён, действие будет записано только в журнал макета.",
        () => updated("Сценарий перезапуска relay выполнен"),
        "Проверить сценарий",
      ),
    "relay-check": () =>
      toast("Демо-данные отображены. Сервер ещё не подключён.", "server"),
    "preview-launch": () => {
      const input = document.getElementById("previewKey");
      if (!input.value.trim()) {
        input.setCustomValidity("Введите демонстрационный ключ");
        input.reportValidity();
        return;
      }
      toast(
        "Ключ введён. Проверка Junkie будет подключена в Roblox-лоадере.",
        "key",
      );
    },
    "setup-2fa": () =>
      openModal(
        "Двухфакторная проверка",
        `<div class="form-note">Здесь появятся настройка TOTP, проверка первого кода и резервные коды после подключения серверной авторизации.</div><div class="flow-step"><span class="eyebrow">ПЛАН ПОДКЛЮЧЕНИЯ</span><b>Пароль → TOTP → сессия владельца</b><p>Секрет создаётся сервером. Макет не генерирует и не сохраняет секреты.</p></div>`,
      ),
    "change-password": () =>
      openModal(
        "Изменение пароля",
        `<div class="form-note">Форма появится после подключения авторизации: текущий пароль, новый пароль, подтверждение TOTP и завершение остальных входов. В демонстрационную панель реальные пароли вводить не нужно.</div>`,
      ),
    "reset-demo": () =>
      confirmDemo(
        "Сбросить макет?",
        "Все изменения текущего предпросмотра будут сброшены.",
        () => location.reload(),
        "Сбросить",
      ),
    "export-logs": () => {
      const blob = new Blob(
        [
          JSON.stringify(
            {
              demo: true,
              events: State.logs
                .filter(matches)
                .filter(
                  (l) => State.filter === "Все" || l.level === State.filter,
                ),
            },
            null,
            2,
          ),
        ],
        { type: "application/json" },
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "violite-demo-events.json";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      toast("Демонстрационный журнал экспортирован");
    },
  };
  function renderNav() {
    document.getElementById("navigation").innerHTML = [
      [
        "Рабочее пространство",
        ["overview", "keys", "users", "sessions", "bans"],
      ],
      ["Распространение", ["releases", "loader"]],
      ["Система", ["relay", "logs", "settings"]],
    ]
      .map(
        ([title, ids]) =>
          `<div class="nav-label">${title}</div>${ids.map((id) => `<a class="nav-item ${id === State.page ? "is-active" : ""}" href="#${id}" ${id === State.page ? 'aria-current="page"' : ""}>${icon(pages[id][1])}${pages[id][0]}${id === "sessions" ? `<span class="nav-count">${active().length}</span>` : ""}</a>`).join("")}`,
      )
      .join("");
  }
  function render() {
    renderNav();
    document.title = `${pages[State.page][0]} · Violite`;
    document.getElementById("breadcrumb").textContent = pages[State.page][0];
    content.innerHTML =
      State.page === "overview"
        ? overview()
        : State.page === "loader"
          ? loader()
          : State.page === "relay"
            ? relay()
            : State.page === "settings"
              ? settings()
              : listing();
  }
  function setMenu(open) {
    document.getElementById("app").classList.toggle("nav-open", open);
    document
      .getElementById("menuBtn")
      .setAttribute("aria-expanded", String(open));
  }
  function route() {
    State.page = pages[location.hash.slice(1)]
      ? location.hash.slice(1)
      : "overview";
    State.query = "";
    State.filter = "Все";
    setMenu(false);
    render();
    window.scrollTo(0, 0);
  }
  document.addEventListener("click", (e) => {
    const target = e.target.closest("button,a");
    if (!target) return;
    if (target.dataset.go) {
      navigate(target.dataset.go);
      return;
    }
    if (target.dataset.searchGo) {
      modal.close();
      navigate(target.dataset.searchGo);
      return;
    }
    if (target.dataset.range) {
      State.range = target.dataset.range;
      render();
      return;
    }
    if (target.dataset.action) {
      actions[target.dataset.action]?.(Number(target.dataset.id));
      return;
    }
    if (target.dataset.toggle) {
      const group = target.dataset.group;
      const key = target.dataset.toggle;
      State[group][key] = !State[group][key];
      target.setAttribute("aria-checked", String(State[group][key]));
      log(
        "Настройки",
        `${target.getAttribute("aria-label")}: ${State[group][key] ? "включено" : "выключено"}`,
      );
      if (State.page === "relay") render();
      toast("Параметр изменён в макете");
    }
  });
  document.addEventListener("input", (e) => {
    if (e.target.form) {
      e.target.form
        .querySelectorAll("input, textarea")
        .forEach((input) => input.setCustomValidity(""));
    } else if (e.target.setCustomValidity) e.target.setCustomValidity("");
    if (e.target.id === "filterQuery") {
      State.query = e.target.value;
      updateList();
    }
  });
  document.addEventListener("change", (e) => {
    if (e.target.id === "filterStatus") {
      State.filter = e.target.value;
      updateList();
    }
    if (e.target.closest("#modalForm"))
      modalForm
        .querySelectorAll("input")
        .forEach((i) => i.setCustomValidity(""));
  });
  // Пробельный ввод не должен создавать пустые записи и подписи.
  document.addEventListener(
    "submit",
    (e) => {
      const invalid = [
        ...e.target.querySelectorAll("input[required], textarea[required]"),
      ].find((input) => !input.value.trim());
      if (!invalid) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      invalid.setCustomValidity("Заполните поле");
      invalid.reportValidity();
    },
    true,
  );
  document.addEventListener("submit", (e) => {
    const type = e.target.dataset.form;
    if (!type) return;
    e.preventDefault();
    const data = Object.fromEntries(new FormData(e.target));
    if (type === "loader") {
      Object.assign(State.loader, data);
      updated("Тексты лоадера обновлены");
    } else {
      if (
        type === "session-settings" &&
        Number(data.ttl) <= Number(data.heartbeat)
      ) {
        const ttl = e.target.elements.ttl;
        ttl.setCustomValidity(
          "Срок сессии должен превышать интервал heartbeat",
        );
        ttl.reportValidity();
        return;
      }
      Object.assign(State.settings, data);
      updated("Настройки сохранены в макете");
    }
  });
  modalForm.addEventListener("submit", (e) => {
    e.preventDefault();
    if (submitHandler && submitHandler(new FormData(modalForm)) !== false)
      modal.close();
  });
  document.getElementById("closeModal").onclick = () => modal.close();
  document.getElementById("cancelModal").onclick = () => modal.close();
  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      const r = modal.getBoundingClientRect();
      if (
        e.clientX < r.left ||
        e.clientX > r.right ||
        e.clientY < r.top ||
        e.clientY > r.bottom
      )
        modal.close();
    }
  });
  document.getElementById("searchBtn").onclick = search;
  document.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
      e.preventDefault();
      search();
    }
    if (e.key === "Escape") setMenu(false);
  });
  document.getElementById("menuBtn").onclick = () =>
    setMenu(!document.getElementById("app").classList.contains("nav-open"));
  document.getElementById("scrim").onclick = () => setMenu(false);
  window.addEventListener("hashchange", route);
  route();
})();
