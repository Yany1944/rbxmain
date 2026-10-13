// Цены MM2 для апгрейдера: расписание обновления, ручной запуск, раздача клиентам.
// Слоты — каждые 4 часа от 00:00 МСК. Следующий слот считается от часов, а не от
// последнего запуска, поэтому ручное обновление расписание не сдвигает: запуск
// за 30 минут до слота не отменяет слот.
import {spawn} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';

export const SLOT_SECONDS = 4 * 3600;
export const MSK_OFFSET = 3 * 3600;   // UTC+3 без перехода на летнее время
const RUN_TIMEOUT_MS = 5 * 60 * 1000;

export function nextSlot(nowSec) {
  const local = nowSec + MSK_OFFSET;
  return (Math.floor(local / SLOT_SECONDS) + 1) * SLOT_SECONDS - MSK_OFFSET;
}

export function createPrices(config, store, {now, audit}) {
  const enabled = typeof config.pricesDir === 'string' && config.pricesDir.length > 0;
  const file = enabled ? resolve(config.pricesDir, 'prices.json') : null;
  const state = {running: false, timer: null, cache: null};
  // Запуск, оборванный перезапуском сервиса, не должен висеть «в процессе»
  store.run("UPDATE price_runs SET finished=?,ok=0,error='interrupted' WHERE finished IS NULL", now());

  // Команда запуска: по умолчанию python + update_prices.py; в тестах подменяется
  function command() {
    if (Array.isArray(config.pricesCommand)) return config.pricesCommand;
    const script = resolve(import.meta.dirname, 'prices', 'update_prices.py');
    return [config.pricesPython || 'python3', script];
  }

  function run(trigger) {
    if (!enabled || state.running) return false;
    state.running = true;
    const started = now();
    const id = Number(store.run('INSERT INTO price_runs(started,trigger) VALUES(?,?)', started, trigger).lastInsertRowid);
    const [exe, ...args] = command();
    const env = {...process.env};
    // Прокси — секрет: только в окружение процесса, не в аргументы и не в журнал
    if (config.pricesProxy) env.VIOLITE_PRICES_PROXY = config.pricesProxy; else delete env.VIOLITE_PRICES_PROXY;
    const child = spawn(exe, [...args, '--out', file], {env, stdio: ['ignore', 'pipe', 'pipe']});
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => { stdout = (stdout + chunk).slice(-8192); });
    child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-2048); });
    const killer = setTimeout(() => child.kill('SIGKILL'), RUN_TIMEOUT_MS);
    killer.unref();
    const finish = (ok, priced, error) => {
      clearTimeout(killer);
      state.running = false;
      state.cache = null;
      store.run('UPDATE price_runs SET finished=?,ok=?,priced=?,error=? WHERE id=?', now(), ok ? 1 : 0, priced ?? null, error ?? '', id);
      audit('system', ok ? 'prices.updated' : 'prices.failed', `${trigger}${priced != null ? ':' + priced : ''}`);
    };
    child.on('error', error => finish(false, null, 'spawn: ' + error.code));
    child.on('close', code => {
      const line = stdout.split('\n').reverse().find(l => l.startsWith('RESULT '));
      let result = null;
      try { result = line ? JSON.parse(line.slice(7)) : null; } catch { result = null; }
      if (code === 0 && result?.ok) finish(true, result.priced, '');
      else finish(false, result?.priced, (result?.error || `exit ${code}` + (stderr ? ': ' + stderr.trim().split('\n').pop() : '')).slice(0, 300));
    });
    return true;
  }

  function schedule() {
    if (!enabled) return;
    clearTimeout(state.timer);
    const wait = Math.max(1, nextSlot(now()) - now()) * 1000;
    state.timer = setTimeout(() => { run('schedule'); schedule(); }, Math.min(wait, 2 ** 31 - 1));
    state.timer.unref();
  }

  async function payload() {
    if (!enabled) return null;
    if (state.cache) return state.cache;
    try {
      const body = await readFile(file);
      state.cache = {body, etag: '"' + createHash('sha256').update(body).digest('hex').slice(0, 32) + '"'};
      return state.cache;
    } catch {
      return null;
    }
  }

  function status() {
    const history = store.all('SELECT id,started,finished,ok,trigger,priced,error FROM price_runs ORDER BY id DESC LIMIT 10');
    return {enabled, running: state.running, nextRun: enabled ? nextSlot(now()) : null, proxy: Boolean(config.pricesProxy), history};
  }

  return {run, schedule, payload, status, stop() { clearTimeout(state.timer); }};
}
