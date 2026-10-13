#!/usr/bin/env node
// ──────────────────────────────────────────────────────────────────────────────
// Violite bundler — склеивает MainScript, GUI, Kernel и модули в один файл.
//
// Каждый исходник оборачивается в свою функцию → у каждого собственный лимит
// Luau в 200 локалов/upvalue, лимит не суммируется при склейке.
//
// Разметка в исходниках:
//   --#dev ... --#end   — блок остаётся в dev, вырезается в release
//   --#release <код>    — строка-комментарий в dev, раскомментируется в release
//
// Два режима:
//   dev     — работает где угодно: сессия owner выдаётся локально, есть VioDbg.
//             node build/bundle.js [--install]
//             → dist/dev/Violite.dev.lua (+ копия в workspace executor'а с --install)
//   release — запускается только из Junkie (JD_SECURE_REQUEST) и только при живой
//             сессии нашего Control (Build ID опубликован, обслуживание выключено).
//             node build/bundle.js --release
//             → dist/release/Violite.release.lua + manifest + RELEASE.txt
//
// Секреты релиза: build/secrets.json (gitignored). proxySecret/responseSecret, если
// их там нет, берутся из приватного конфига Control (по умолчанию
// .local/control-production/config.json) — тот же файл, что лежит на VDS.
// Прочие флаги: --out <path>, --secrets <path>.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const RELEASE = args.includes('--release');
const INSTALL = args.includes('--install');
// Виртуализация обфускатора (VM Luraph) замедляет код в десятки раз: per-frame логика
// фич давала просадки FPS и фризы. В релизе в VM остаётся только Kernel (секреты,
// JD_SECURE_REQUEST, проверка подписи); модули фич — под макросом скорости Luraph.
// В исходниках пишется LPH_NO_VIRTUALIZE, сборщик меняет его на выбранный макрос:
// Luraph в Junkie не знает ни LPH_NO_VIRTUALIZE, ни LPH_JIT_MAX ("Unknown macro") — по умолчанию none.
//   --perf-macro LPH_JIT_MAX | LPH_JIT | LPH_NO_VIRTUALIZE | none (none — всё в VM)
// --virtualize-all — то же, что --perf-macro none.
const PERF_MACRO = args.includes('--virtualize-all') ? 'none' : (option('--perf-macro') || 'none');
if (!['LPH_JIT_MAX', 'LPH_JIT', 'LPH_NO_VIRTUALIZE', 'none'].includes(PERF_MACRO)) {
  throw new Error('--perf-macro must be LPH_JIT_MAX, LPH_JIT, LPH_NO_VIRTUALIZE or none');
}
const VIRTUALIZE_ALL = PERF_MACRO === 'none';
// none/dev: обёртка — обычная функция без LPH-имени, обфускатор её не трогает
const PERF_CALL = RELEASE && !VIRTUALIZE_ALL ? PERF_MACRO : '__violiteNative';

function option(name) {
  const at = args.indexOf(name);
  if (at < 0) return null;
  if (!args[at + 1] || args[at + 1].startsWith('--')) throw new Error(`${name} requires a value`);
  return args[at + 1];
}

const DIST = path.join(ROOT, 'dist', RELEASE ? 'release' : 'dev');
const OUT = path.resolve(option('--out') || path.join(DIST, RELEASE ? 'Violite.release.lua' : 'Violite.dev.lua'));
const DEFAULT_CONTROL_URL = 'https://193-39-143-31.sslip.io/control';
const DEFAULT_CONTROL_CONFIG = path.join(ROOT, '.local', 'control-production', 'config.json');
// Workspace Potassium: readfile видит только его содержимое
const EXECUTOR_DIR = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'),
  'Potassium', 'workspace', 'VioCFG', 'Violite');

// Порядок важен: Kernel идёт отдельно первым (его фабрика — бутстрап), MainScript — точка входа.
// optional — только для dev: в релизе отсутствие модуля = ошибка сборки.
const MODULES = [
  { name: 'GUI', file: 'Libraryes/GUI.lua' },
  { name: 'Visuals', file: 'Libraryes/Visuals.lua' },
  { name: 'Optimization', file: 'Libraryes/Optimization.lua' },
  { name: 'Movement', file: 'Libraryes/Movement.lua' },
  { name: 'HUD', file: 'Libraryes/HUD.lua' },
  { name: 'Skinchanger', file: 'skinchanger.lua', optional: true },
  { name: 'MainScript', file: 'MainScript.lua', entry: true },
];

const BUILD_VERSION = process.env.VIOLITE_VERSION === undefined
  ? Math.floor(Date.now() / 1000) : Number(process.env.VIOLITE_VERSION);
if (!Number.isSafeInteger(BUILD_VERSION) || BUILD_VERSION < 1 || BUILD_VERSION > 999999999999) {
  throw new Error('VIOLITE_VERSION must be an integer from 1 to 999999999999');
}

const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));

function loadSecrets() {
  const custom = option('--secrets');
  const file = custom ? path.resolve(custom) : path.join(ROOT, 'build', 'secrets.json');
  if (custom && !fs.existsSync(file)) throw new Error(`Secrets file does not exist: ${file}`);
  const secrets = fs.existsSync(file) ? readJson(file) : {};
  if (!RELEASE) return secrets;

  // Секреты HMAC общие с сервером: берём из его конфига, чтобы не держать две копии
  const controlConfig = secrets.controlConfig ? path.resolve(ROOT, secrets.controlConfig) : DEFAULT_CONTROL_CONFIG;
  if ((!secrets.proxySecret || !secrets.responseSecret) && fs.existsSync(controlConfig)) {
    const control = readJson(controlConfig);
    secrets.proxySecret = secrets.proxySecret || control.proxySecret;
    secrets.responseSecret = secrets.responseSecret || control.responseSecret;
  }
  secrets.controlUrl = secrets.controlUrl || DEFAULT_CONTROL_URL;

  for (const field of ['controlUrl', 'proxySecret', 'responseSecret']) {
    if (typeof secrets[field] !== 'string' || secrets[field].length < 8) {
      throw new Error(`release: "${field}" не найден ни в build/secrets.json, ни в ${path.relative(ROOT, controlConfig)}`);
    }
  }
  const urls = ['controlUrl'];
  if (secrets.loaderUrl) urls.push('loaderUrl');
  for (const field of urls) {
    const url = new URL(secrets[field]);
    if (url.protocol !== 'https:' || url.username || url.password || url.hash
        || ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) || /\.(example|invalid|test)$/.test(url.hostname)) {
      throw new Error(`${field} must be a real public HTTPS URL without credentials or fragment (now: ${secrets[field]})`);
    }
  }
  for (const field of ['proxySecret', 'responseSecret']) {
    if (secrets[field].length < 32 || /[\x00-\x1f\x7f"\\]/.test(secrets[field])) {
      throw new Error(`${field} must contain at least 32 printable characters without quotes`);
    }
  }
  return secrets;
}

// --#dev ... --#end  и  --#release <код>
function applyMarkers(src, release, name) {
  const lines = src.split(/\r?\n/);
  const out = [];
  let skipping = false, openAt = 0;
  lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed === '--#dev') {
      if (openAt) throw new Error(`${name}:${index + 1}: nested --#dev (previous at ${openAt})`);
      openAt = index + 1; skipping = release; return;
    }
    if (trimmed === '--#end') {
      if (!openAt) throw new Error(`${name}:${index + 1}: --#end without --#dev`);
      openAt = 0; skipping = false; return;
    }
    if (skipping) return;
    const rel = line.match(/^(\s*)--#release ?(.*)$/);
    if (rel) {
      if (release) out.push(rel[1] + rel[2]);
      return;
    }
    out.push(line);
  });
  if (openAt) throw new Error(`${name}:${openAt}: --#dev without --#end`);
  return out.join('\n');
}

// Грубая проверка лимита локалов Luau (200) на функцию: считаем объявления
// `local` по глубине do/function. Не компилятор, но ловит явное превышение.
function warnLocalBudget(name, src) {
  let maxLocals = 0;
  const scope = [0];
  for (const raw of src.split(/\r?\n/)) {
    const line = raw.replace(/--.*$/, '').replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/g, '""');
    // `elseif ... then` продолжает тот же if — нового блока не открывает
    const opens = (line.match(/\b(function|do|then|repeat)\b/g) || []).length
      - (line.match(/\belseif\b/g) || []).length;
    const closes = (line.match(/\b(end|until)\b/g) || []).length;
    const locals = (line.match(/(^|\s)local\s/g) || []).length;
    scope[scope.length - 1] += locals;
    maxLocals = Math.max(maxLocals, scope[scope.length - 1]);
    for (let i = 0; i < opens; i++) scope.push(0);
    for (let i = 0; i < closes && scope.length > 1; i++) scope.pop();
  }
  if (maxLocals > 190) console.warn(`  ! ${name}: ~${maxLocals} locals in one scope (Luau limit 200)`);
}

// Значения подставляются внутрь Lua-строк — экранируем, чтобы секрет с кавычкой
// или обратной косой не сломал синтаксис
function luaEscape(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r?\n/g, '\\n');
}

function fill(src, secrets) {
  const values = {
    __VIOLITE_CONTROL_URL__: (RELEASE ? secrets.controlUrl : 'https://127.0.0.1').replace(/\/+$/, ''),
    __VIOLITE_PROXY_SECRET__: RELEASE ? secrets.proxySecret : '',
    __VIOLITE_RESPONSE_SECRET__: RELEASE ? secrets.responseSecret : '',
    // Лоадер Junkie для автоперезапуска после телепорта; пусто — автозапуск выключен
    __VIOLITE_LOADER_URL__: RELEASE ? (secrets.loaderUrl || '') : '',
    // dev-значения в релиз не попадают вовсе
    __VIOLITE_DEV_URL__: RELEASE ? '' : (secrets.devUrl || 'http://127.0.0.1:8790'),
    __VIOLITE_DEV_SECRET__: RELEASE ? '' : (secrets.devSecret || ''),
    __VIOLITE_DEV_OFFLINE__: RELEASE ? '0' : String(secrets.devOffline ?? '1'),
  };
  return src.replace(/__VIOLITE_[A-Z_]+__/g, (name) =>
    Object.prototype.hasOwnProperty.call(values, name) ? luaEscape(values[name]) : name);
}

// Релиз не должен содержать dev-хвостов и незаполненных плейсхолдеров, а проверка
// сессии обязана идти через Junkie: без JD_SECURE_REQUEST сборка бесполезна
function verifyRelease(bundle, secrets) {
  const problems = [];
  const left = bundle.match(/__VIOLITE_[A-Z_]+__/g);
  if (left) problems.push('unfilled placeholders: ' + [...new Set(left)].join(', '));
  if (/^\s*--#(dev|end|release)\b/m.test(bundle)) problems.push('leftover markers');
  for (const needle of ['VioDbg', 'x-violite-dev', 'DevOffline', 'Yany1944/rbxmain', 'DevUrl', 'DevSecret']) {
    if (bundle.includes(needle)) problems.push('dev code leaked: ' + needle);
  }
  const secureCalls = (bundle.match(/JD_SECURE_REQUEST\(\{/g) || []).length;
  if (secureCalls !== 2) problems.push(`expected 2 JD_SECURE_REQUEST calls (session, beat), found ${secureCalls}`);
  if (!bundle.includes(`${secrets.controlUrl.replace(/\/+$/, '')}/session`)) problems.push('control URL missing');
  if (!bundle.includes('KernelFactory({ Version = BUILD_VERSION, Release = true,')) problems.push('bootstrap is not in release mode');
  for (const macro of ['LPH_NO_VIRTUALIZE', 'LPH_JIT_MAX', 'LPH_JIT']) {
    if (macro !== PERF_MACRO && new RegExp('\\b' + macro + '\\b').test(bundle)) problems.push(`unexpected macro ${macro} (selected ${PERF_MACRO})`);
  }
  if (problems.length) throw new Error('release check failed:\n  ' + problems.join('\n  '));
}

function writeFile(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data, 'utf8');
}

function main() {
  const secrets = loadSecrets();
  const kernelSrc = fill(applyMarkers(
    fs.readFileSync(path.join(ROOT, 'Libraryes/Kernel.lua'), 'utf8'), RELEASE, 'Kernel'), secrets)
    .replace(/\bLPH_NO_VIRTUALIZE\b/g, PERF_CALL);
  warnLocalBudget('Kernel', kernelSrc);

  const parts = [];
  parts.push('-- Violite bundle — generated by build/bundle.js. Do not edit.');
  parts.push(`-- mode=${RELEASE ? 'release' : 'dev'} version=${BUILD_VERSION}`);
  parts.push(`local BUILD_VERSION = ${BUILD_VERSION}`);
  if (PERF_CALL === '__violiteNative') {
    parts.push('local function __violiteNative(...) return ... end');
  } else {
    // Без обфускатора (проверка сырого релиза) макрос Luraph — обычная функция
    parts.push('if not LPH_OBFUSCATED then');
    parts.push(`    ${PERF_CALL} = function(...) return ... end`);
    parts.push('end');
  }
  parts.push('');
  // Фабрика ядра (исходник уже `return function(options)`)
  parts.push('local KernelFactory = (function()');
  parts.push(kernelSrc);
  parts.push('end)()');
  parts.push('');
  parts.push('local __modules = {}');

  let entryName = null;
  const included = [];
  for (const mod of MODULES) {
    const full = path.join(ROOT, mod.file);
    if (!fs.existsSync(full)) {
      if (mod.optional && !RELEASE) { console.warn(`  (skip ${mod.name}: ${mod.file} missing)`); continue; }
      throw new Error(`missing module ${mod.file}`);
    }
    const src = fill(applyMarkers(fs.readFileSync(full, 'utf8').replace(/^\uFEFF/, ''), RELEASE, mod.file), secrets);
    warnLocalBudget(mod.name, src);
    if (mod.entry) entryName = mod.name;
    included.push(mod.name);
    // Каждый модуль — функция(Kernel); её тело — исходник как есть.
    parts.push('');
    parts.push(`-- ===== ${mod.name} (${mod.file}) =====`);
    const native = RELEASE && !VIRTUALIZE_ALL;
    parts.push(`__modules[${JSON.stringify(mod.name)}] = ${native ? PERF_CALL + '(' : ''}function(Kernel)`);
    parts.push(src);
    parts.push(native ? 'end)' : 'end');
  }

  parts.push('');
  parts.push('-- ===== bootstrap =====');
  parts.push('if not game:IsLoaded() then game.Loaded:Wait() end');
  parts.push('local Kernel = KernelFactory({ Version = BUILD_VERSION, Release = ' + (RELEASE ? 'true' : 'false') + ', Modules = __modules })');
  parts.push('if not Kernel.Start() then return end');
  if (entryName) {
    parts.push(`local started, startError = pcall(Kernel.Require, ${JSON.stringify(entryName)})`);
    parts.push('if not started then Kernel.Stop(); warn("Violite: initialization failed", startError) end');
  }
  parts.push('');

  const bundle = parts.join('\n');
  if (RELEASE) verifyRelease(bundle, secrets);
  const sha256 = crypto.createHash('sha256').update(bundle).digest('hex');
  writeFile(OUT, bundle);
  const manifest = { version: BUILD_VERSION, mode: RELEASE ? 'release' : 'dev', file: path.basename(OUT), sha256,
    modules: included, built: new Date().toISOString() };
  if (RELEASE) manifest.controlUrl = secrets.controlUrl;
  writeFile(OUT.replace(/\.lua$/, '') + '.manifest.json', JSON.stringify(manifest, null, 2) + '\n');
  const kb = (Buffer.byteLength(bundle, 'utf8') / 1024).toFixed(0);
  console.log(`bundle written: ${OUT} (${kb} KB, mode=${RELEASE ? 'release' : 'dev'}, Build ID ${BUILD_VERSION})`);

  if (INSTALL && !RELEASE) {
    if (fs.existsSync(path.dirname(EXECUTOR_DIR))) {
      const target = path.join(EXECUTOR_DIR, 'Violite.dev.lua');
      writeFile(target, bundle);
      // OwnerTools запускается рядом с dev-сборкой (роль owner в dev выдаётся всегда)
      const owner = path.join(ROOT, 'OwnerTools.lua');
      if (fs.existsSync(owner)) fs.copyFileSync(owner, path.join(EXECUTOR_DIR, 'OwnerTools.lua'));
      console.log(`installed: ${target}`);
      console.log('run in executor: loadstring(readfile("VioCFG/Violite/Violite.dev.lua"))()');
    } else {
      console.warn(`  ! executor workspace not found: ${path.dirname(EXECUTOR_DIR)} — copy the file manually`);
    }
  }

  if (RELEASE) {
    const notes = [
      `Violite release — Build ID ${BUILD_VERSION}`,
      `Собрано: ${manifest.built}`,
      `SHA-256: ${sha256}`,
      `Control: ${secrets.controlUrl}`,
      `Автозапуск после телепорта: ${secrets.loaderUrl ? secrets.loaderUrl : 'ВЫКЛЮЧЕН (нет loaderUrl в build/secrets.json)'}`,
      '',
      'Чтобы сборка заработала у игроков:',
      `  1. Панель → Релизы → «Добавить»: Build ID ${BUILD_VERSION}, название версии.`,
      '  2. Junkie → основной скрипт → Original Code: вставить Violite.release.lua целиком.',
      '  3. Junkie → UI Source: обфусцированный Violite.loader.ui.lua (см. build/KEY-LOADER.md).',
      '  4. В панели «Опубликовать» — черновик сервер не пускает даже владельца',
      '     (кик «Version check failed»). Затем проверить запуск по ссылке Junkie.',
      '  5. Старую версию в панели — «Заблокировать» (выгрузит её у всех на следующем продлении).',
      '',
      'Без Junkie (вставка файла в executor напрямую) сборка не запускается: JD_SECURE_REQUEST',
      'есть только в защищённом скрипте. Выключение скрипта для всех — «Обслуживание» в панели.',
      '',
    ].join('\n');
    writeFile(path.join(path.dirname(OUT), 'RELEASE.txt'), notes);
    console.log(notes);
  }
}

try {
  main();
} catch (error) {
  console.error(`\nBUILD FAILED: ${error.message}`);
  process.exit(1);
}
