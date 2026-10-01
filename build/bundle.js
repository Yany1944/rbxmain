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
// Так один и тот же исходник в dev грузит зависимости через HttpGet (видно
// правки без пуша), а в release — через Kernel.Require (в файле нет загрузок
// своего кода, перехватывать и подменять нечего).
//
// Плейсхолдеры __VIOLITE_*__ заполняются из build/secrets.json (gitignored).
// Запуск: node build/bundle.js [--release] [--out <path>]
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const RELEASE = args.includes('--release');
const outIdx = args.indexOf('--out');
const OUT = outIdx >= 0 ? args[outIdx + 1]
  : path.join(ROOT, 'build', RELEASE ? 'Violite.bundle.lua' : 'Violite.dev.lua');

// Порядок важен: Kernel первым (его фабрика — бутстрап), MainScript — точка входа.
const MODULES = [
  { name: 'GUI', file: 'Libraryes/GUI.lua' },
  { name: 'Visuals', file: 'Libraryes/Visuals.lua' },
  { name: 'Optimization', file: 'Libraryes/Optimization.lua' },
  { name: 'Movement', file: 'Libraryes/Movement.lua' },
  { name: 'Skinchanger', file: 'skinchanger.lua', optional: true },
  { name: 'MainScript', file: 'MainScript.lua', entry: true },
];

const BUILD_VERSION = Number(process.env.VIOLITE_VERSION)
  || Math.floor(Date.now() / 1000);

function loadSecrets() {
  const p = path.join(ROOT, 'build', 'secrets.json');
  const secrets = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
  if (RELEASE) {
    // Без этих значений релиз либо не дойдёт до сервера, либо не проверит подпись
    for (const field of ['controlUrl', 'proxySecret', 'responseSecret', 'loaderUrl']) {
      if (typeof secrets[field] !== 'string' || secrets[field].length < 8) {
        throw new Error(`build/secrets.json: "${field}" is required for --release`);
      }
    }
    for (const field of ['controlUrl', 'loaderUrl']) {
      if (!/^https:\/\//.test(secrets[field])) throw new Error(`${field} must be https://`);
    }
  }
  return secrets;
}

// --#dev ... --#end  и  --#release <код>
function applyMarkers(src, release) {
  const lines = src.split(/\r?\n/);
  const out = [];
  let skipping = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === '--#dev') { skipping = release; continue; }
    if (trimmed === '--#end') { skipping = false; continue; }
    if (skipping) continue;
    const rel = line.match(/^(\s*)--#release ?(.*)$/);
    if (rel) {
      if (release) out.push(rel[1] + rel[2]);
      continue;
    }
    out.push(line);
  }
  return out.join('\n');
}

// Грубая проверка лимита локалов Luau (200) на функцию: считаем объявления
// `local` по глубине do/function. Не компилятор, но ловит явное превышение.
function warnLocalBudget(name, src) {
  // эвристика: самый насыщенный скоуп верхнего уровня функции-обёртки
  let depth = 0, maxLocals = 0, scope = [0];
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
  if (maxLocals > 190) {
    console.warn(`  ! ${name}: ~${maxLocals} locals in one scope (Luau limit 200)`);
  }
}

// Значения подставляются внутрь Lua-строк — экранируем, чтобы секрет с кавычкой
// или обратной косой не сломал синтаксис
function luaEscape(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r?\n/g, '\\n');
}

function fill(src, secrets) {
  const values = {
    __VIOLITE_CONTROL_URL__: (secrets.controlUrl || 'https://127.0.0.1').replace(/\/+$/, ''),
    __VIOLITE_PROXY_SECRET__: secrets.proxySecret || '',
    __VIOLITE_RESPONSE_SECRET__: secrets.responseSecret || '',
    // Лоадер (с ключом) для автоперезапуска после телепорта
    __VIOLITE_LOADER_URL__: secrets.loaderUrl || '',
    // dev-значения в релиз не попадают вовсе
    __VIOLITE_DEV_URL__: RELEASE ? '' : (secrets.devUrl || 'http://127.0.0.1:8790'),
    __VIOLITE_DEV_SECRET__: RELEASE ? '' : (secrets.devSecret || ''),
    __VIOLITE_DEV_OFFLINE__: RELEASE ? '0' : String(secrets.devOffline ?? '1'),
  };
  return src.replace(/__VIOLITE_[A-Z_]+__/g, (name) =>
    Object.prototype.hasOwnProperty.call(values, name) ? luaEscape(values[name]) : name);
}

// Релиз не должен содержать dev-хвостов и незаполненных плейсхолдеров
function verifyRelease(bundle) {
  const problems = [];
  const left = bundle.match(/__VIOLITE_[A-Z_]+__/g);
  if (left) problems.push('unfilled placeholders: ' + [...new Set(left)].join(', '));
  if (/^\s*--#(dev|end|release)\b/m.test(bundle)) problems.push('leftover markers');
  for (const needle of ['VioDbg', 'x-violite-dev', 'DevOffline', 'Yany1944/rbxmain']) {
    if (bundle.includes(needle)) problems.push('dev code leaked: ' + needle);
  }
  if (problems.length) throw new Error('release check failed:\n  ' + problems.join('\n  '));
}

function main() {
  const secrets = loadSecrets();
  const kernelSrc = fill(applyMarkers(
    fs.readFileSync(path.join(ROOT, 'Libraryes/Kernel.lua'), 'utf8'), RELEASE), secrets);
  warnLocalBudget('Kernel', kernelSrc);

  const parts = [];
  parts.push('-- Violite bundle — generated by build/bundle.js. Do not edit.');
  parts.push(`-- mode=${RELEASE ? 'release' : 'dev'} version=${BUILD_VERSION}`);
  parts.push(`local BUILD_VERSION = ${BUILD_VERSION}`);
  parts.push('');
  // Фабрика ядра (исходник уже `return function(options)`)
  parts.push('local KernelFactory = (function()');
  parts.push(kernelSrc);
  parts.push('end)()');
  parts.push('');
  parts.push('local __modules = {}');

  let entryName = null;
  for (const mod of MODULES) {
    const full = path.join(ROOT, mod.file);
    if (!fs.existsSync(full)) {
      if (mod.optional) { console.warn(`  (skip ${mod.name}: ${mod.file} missing)`); continue; }
      throw new Error(`missing module ${mod.file}`);
    }
    let src = fill(applyMarkers(fs.readFileSync(full, 'utf8'), RELEASE), secrets);
    warnLocalBudget(mod.name, src);
    if (mod.entry) entryName = mod.name;
    // Каждый модуль — функция(Kernel); её тело — исходник как есть.
    parts.push('');
    parts.push(`-- ===== ${mod.name} (${mod.file}) =====`);
    parts.push(`__modules[${JSON.stringify(mod.name)}] = function(Kernel)`);
    parts.push(src);
    parts.push('end');
  }

  parts.push('');
  parts.push('-- ===== bootstrap =====');
  parts.push('local Kernel = KernelFactory({ Version = BUILD_VERSION, Release = ' + (RELEASE ? 'true' : 'false') + ', Modules = __modules })');
  parts.push('if not Kernel.Start() then return end');
  if (entryName) {
    parts.push(`Kernel.Require(${JSON.stringify(entryName)})`);
  }
  parts.push('');

  const bundle = parts.join('\n');
  if (RELEASE) verifyRelease(bundle);
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, bundle, 'utf8');
  const kb = (Buffer.byteLength(bundle, 'utf8') / 1024).toFixed(0);
  console.log(`bundle written: ${OUT} (${kb} KB, mode=${RELEASE ? 'release' : 'dev'}, v${BUILD_VERSION})`);
}

main();
