import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,writeFileSync,readFileSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';
import {createApp} from '../app.js';
import {nextSlot} from '../prices.js';
import {passwordHash,totp} from '../security.js';

const iso = s => Math.floor(Date.parse(s) / 1000);

test('slots every 4 hours from 00:00 MSK', () => {
  // 00:00 МСК = 21:00 UTC предыдущего дня
  assert.equal(nextSlot(iso('2026-10-08T20:59:59Z')), iso('2026-10-08T21:00:00Z'));
  assert.equal(nextSlot(iso('2026-10-08T21:00:00Z')), iso('2026-10-09T01:00:00Z'));
  assert.equal(nextSlot(iso('2026-10-09T12:30:00Z')), iso('2026-10-09T13:00:00Z'));
  assert.equal(nextSlot(iso('2026-10-09T17:00:01Z')), iso('2026-10-09T21:00:00Z'));
});

const password = 'test-password-not-for-deployment';
const hash = await passwordHash(password);
const origin = 'http://127.0.0.1:8090';

async function fixture(t, script) {
  const dir = mkdtempSync(join(tmpdir(), 'violite-prices-'));
  const fake = join(dir, 'fake.mjs');
  writeFileSync(fake, script);
  let clock = Date.parse('2026-10-09T12:30:00Z');
  const config = {database: join(dir, 'c.sqlite'), proxySecret: 'p'.repeat(64), responseSecret: 'r'.repeat(64), identitySecret: 'i'.repeat(64),
    username: 'owner', passwordHash: hash, totpSecret: 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP', adminOrigins: [origin], panelDirectory: dir,
    pricesDir: dir, pricesCommand: [process.execPath, fake], pricesProxy: 'host:1:user:pass'};
  const app = createApp(config, {now: () => clock, noSchedule: true});
  app.publicServer.listen(0, '127.0.0.1'); app.adminServer.listen(0, '127.0.0.1');
  await Promise.all([once(app.publicServer, 'listening'), once(app.adminServer, 'listening')]);
  const pub = `http://127.0.0.1:${app.publicServer.address().port}`, adm = `http://127.0.0.1:${app.adminServer.address().port}`;
  let cookie = '', csrf = '';
  const admin = async (path, body) => {
    const r = await fetch(adm + path, {method: body === undefined ? 'GET' : 'POST', headers: {Origin: origin, Cookie: cookie, 'X-CSRF-Token': csrf, 'Content-Type': 'application/json'}, body: body === undefined ? undefined : JSON.stringify(body)});
    return {status: r.status, body: await r.json(), cookie: r.headers.get('set-cookie')};
  };
  const first = await admin('/api/auth/login', {username: 'owner', password});
  const second = await admin('/api/auth/mfa', {challenge: first.body.challenge, code: totp(config.totpSecret, Math.floor(clock / 30000))});
  cookie = second.cookie.split(';')[0]; csrf = (await admin('/api/auth/me')).body.csrf;
  const waitIdle = async () => { for (let i = 0; i < 200 && (await admin('/api/state')).body.prices.running; i++) await new Promise(r => setTimeout(r, 25)); };
  t.after(async () => { await Promise.all([new Promise(r => app.publicServer.close(r)), new Promise(r => app.adminServer.close(r))]); app.close(); rmSync(dir, {recursive: true, force: true}); });
  return {dir, pub, admin, waitIdle};
}

const OK_SCRIPT = `import {writeFileSync} from 'node:fs';
const out = process.argv[process.argv.indexOf('--out') + 1];
if (process.env.VIOLITE_PRICES_PROXY !== 'host:1:user:pass') process.exit(9);
writeFileSync(out, JSON.stringify({meta:{priced:2},items:{A:{v:5},B:{v:null}}}));
console.log('RESULT ' + JSON.stringify({ok:true,priced:2}));`;

test('manual run publishes prices, keeps the schedule, serves ETag', async t => {
  const f = await fixture(t, OK_SCRIPT);
  assert.equal((await fetch(f.pub + '/prices')).status, 503);
  const before = (await f.admin('/api/state')).body.prices.nextRun;
  assert.equal((await f.admin('/api/prices/run', {})).status, 200);
  await f.waitIdle();
  const state = (await f.admin('/api/state')).body.prices;
  assert.equal(state.nextRun, before);
  assert.equal(state.history[0].ok, 1); assert.equal(state.history[0].priced, 2); assert.equal(state.history[0].trigger, 'manual');
  const r = await fetch(f.pub + '/prices');
  assert.equal(r.status, 200);
  assert.equal((await r.json()).items.A.v, 5);
  assert.equal((await fetch(f.pub + '/prices', {headers: {'If-None-Match': r.headers.get('etag')}})).status, 304);
});

test('blocked run is recorded as failure and keeps the old file', async t => {
  const f = await fixture(t, `console.log('RESULT ' + JSON.stringify({ok:false,error:'blocked: godlies: HTTP 403'})); process.exit(2);`);
  writeFileSync(join(f.dir, 'prices.json'), '{"old":true}');
  await f.admin('/api/prices/run', {});
  await f.waitIdle();
  const last = (await f.admin('/api/state')).body.prices.history[0];
  assert.equal(last.ok, 0); assert.match(last.error, /blocked/);
  assert.equal(readFileSync(join(f.dir, 'prices.json'), 'utf8'), '{"old":true}');
});
