import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve, extname} from 'node:path';
import {openStore} from './store.js';
import {digest,hmac,equal,randomToken,passwordMatches,totpStep} from './security.js';
import {createPrices} from './prices.js';
import {createRoblox} from './roblox.js';

class HttpError extends Error {constructor(status,message){super(message);this.status=status;}}
const fail = (status,message) => {throw new HttpError(status,message);};
const text = (v,min,max) => typeof v==='string' && v.length>=min && v.length<=max && !/[\x00-\x1f]/.test(v);
const version = v => /^\d{1,12}$/.test(String(v)) && Number(v)>0 && Number.isSafeInteger(Number(v));
// Слушатели только на loopback: X-Forwarded-For ставит Caddy (входящий заголовок он
// заменяет адресом клиента), поэтому последний элемент — реальный IP посетителя.
// Без прокси (туннель/локально) — адрес сокета.
const clientIp = req => (String(req.headers['x-forwarded-for']||'').split(',').pop().trim() || req.socket.remoteAddress || 'local').slice(0,64);
const viaHttps = req => req.headers['x-forwarded-proto']==='https';

export function createApp(config, options={}) {
  for (const key of ['proxySecret','responseSecret','identitySecret']) if (!text(config[key],32,256)) throw new Error(`Invalid ${key}`);
  if (!/^[a-f0-9]{32}:[a-f0-9]{128}$/.test(config.passwordHash||'')) throw new Error('Invalid passwordHash');
  if (!/^[A-Z2-7]{32}$/.test(config.totpSecret||'')) throw new Error('Invalid totpSecret');
  if (!text(config.username,1,64)) throw new Error('Invalid username');
  if (!Array.isArray(config.adminOrigins) || !config.adminOrigins.length) throw new Error('adminOrigins required');
  for (const origin of config.adminOrigins) {
    const url=new URL(origin);
    if(url.origin!==origin || !['https:','http:'].includes(url.protocol)) throw new Error('Invalid admin origin');
    if(url.protocol==='http:' && !['localhost','127.0.0.1','[::1]'].includes(url.hostname)) throw new Error('HTTP admin requires loopback tunnel');
  }
  const store=openStore(config.database);
  const now=()=>Math.floor((options.now?options.now():Date.now())/1000);
  const ttl=180;
  const query=store;
  // После смены учётных данных прежние cookie и незавершённые входы недействительны.
  const authHash=digest(config.username+'|'+config.passwordHash+'|'+config.totpSecret);
  if(query.get('SELECT auth_hash FROM config_state WHERE id=1')?.auth_hash!==authHash) {
    query.transaction(()=>{
      query.run('DELETE FROM admin_sessions');query.run('DELETE FROM challenges');
      query.run('INSERT OR REPLACE INTO config_state VALUES(1,?)',authHash);
    });
  }
  const audit=(actor,event,detail)=>query.run('INSERT INTO audit(time,actor,event,detail) VALUES(?,?,?,?)',now(),actor,event,detail);
  const identity=(kind,value)=>hmac(config.identitySecret,`${kind}:${value}`);
  const prices=createPrices(config,query,{now,audit});
  const roblox=createRoblox({fetch:options.robloxFetch});
  if(!options.noSchedule) prices.schedule();
  function rate(bucket,max,seconds) {
    const t=now();const old=query.get('SELECT * FROM rate_limits WHERE bucket=?',bucket);
    if (!old || old.start+seconds<=t) query.run('INSERT OR REPLACE INTO rate_limits VALUES(?,?,1)',bucket,t);
    else {if(old.count>=max) fail(429,'Слишком много запросов. Повторите позже.');query.run('UPDATE rate_limits SET count=count+1 WHERE bucket=?',bucket);}
  }
  function cleanup() {
    const t=now();
    query.run('DELETE FROM nonces WHERE expires<?',t);
    query.run('DELETE FROM challenges WHERE expires<?',t);
    query.run('DELETE FROM admin_sessions WHERE last_seen<? OR created<?',t-900,t-43200);
    query.run('DELETE FROM rate_limits WHERE start<?',t-3600);
    query.run('DELETE FROM sessions WHERE expires<?',t-30*86400);
    query.run('DELETE FROM audit WHERE time<?',t-90*86400);
    query.run('DELETE FROM price_runs WHERE started<?',t-30*86400);
  }
  const timer=setInterval(cleanup,60000);timer.unref();cleanup();
  function signed(res,nonce,data) {
    const payload=JSON.stringify(data);
    send(res,200,{payload,sig:hmac(config.responseSecret,nonce+'|'+payload)});
  }
  function denial(message, kick=false) {return {ok:false,kill:true,kick,message};}
  function checkAccess(v,ids) {
    const release=query.get('SELECT status FROM releases WHERE version=?',Number(v));
    if (!release || release.status!=='published') return denial(release?.status==='blocked'?'Версия заблокирована':'Ошибка проверки версии',release?.status!=='blocked');
    if(query.get('SELECT maintenance FROM settings WHERE id=1').maintenance) return denial('Техническое обслуживание');
    for(const [kind,value] of Object.entries(ids)) {
      const ban=query.get('SELECT reason FROM bans WHERE kind=? AND value=?',kind,value);
      if(ban) return denial(ban.reason||'Доступ заблокирован');
    }
    return null;
  }
  // Цены для апгрейдера — открытые данные: без секрета, с лимитом по IP и ETag
  async function servePrices(req,res) {
    rate('prices:'+clientIp(req),30,60);
    const data=await prices.payload();
    if(!data) fail(503,'Prices are not ready');
    const headers={'ETag':data.etag,'Cache-Control':'public, max-age=300'};
    if(req.headers['if-none-match']===data.etag){res.writeHead(304,headers);return res.end();}
    res.writeHead(200,{'Content-Type':'application/json; charset=utf-8',...headers});
    res.end(req.method==='HEAD'?undefined:data.body);
  }
  async function control(req,res,path) {
    if((req.method==='GET'||req.method==='HEAD') && path==='/prices') return servePrices(req,res);
    if(req.method!=='POST' || !['/session','/beat'].includes(path)) fail(404,'Not found');
    if(!equal(req.headers['x-violite-proxy']||'',config.proxySecret)) fail(401,'Unauthorized');
    const body=await jsonBody(req);
    if(!text(body.key,1,512)||!/^\w[\w-]{0,127}$/.test(body.hwid||'')||!/^\d{1,20}$/.test(body.user||'')||!version(body.v)||! /^[a-f0-9]{32}$/.test(body.nonce||'')) fail(400,'Invalid session request');
    const key=identity('key',body.key), hwid=identity('hwid',body.hwid), ids={key,hwid,user:body.user};
    rate('client:'+key,40,60);
    const outcome=query.transaction(()=>{
      if(query.get('SELECT 1 FROM nonces WHERE key_hash=? AND nonce=? AND expires>?',key,body.nonce,now())) return denial('Повторный запрос');
      query.run('INSERT OR REPLACE INTO nonces VALUES(?,?,?)',key,body.nonce,now()+300);
      const denied=checkAccess(body.v,ids);if(denied) return denied;
      if(path==='/beat') {
        if(!/^[a-f0-9]{64}$/.test(body.token||'')) return denial('Недействительная сессия');
        const session=query.get('SELECT * FROM sessions WHERE token_hash=?',digest(body.token));
        if(!session||session.key_hash!==key||session.hwid_hash!==hwid||session.user_id!==body.user||session.version!==Number(body.v)) return denial('Недействительная сессия');
        if(session.revoked||session.expires<=now()) return denial(session.reason||'Сессия завершена');
        query.run('UPDATE sessions SET last_seen=?,expires=? WHERE id=?',now(),now()+ttl,session.id);
        return {ok:true,token:body.token,ttl,role:session.role};
      }
      const token=randomToken(),id=randomToken().slice(0,24);
      const role=(config.ownerKeyHashes||[]).includes(key)?'owner':'user';
      // Один живой запуск на ключ и устройство; перезапуск отзывает старый токен.
      query.run("UPDATE sessions SET revoked=1,reason='Заменена новым запуском' WHERE key_hash=? AND hwid_hash=? AND revoked=0",key,hwid);
      query.run('INSERT INTO sessions(id,token_hash,key_hash,hwid_hash,user_id,version,role,created,last_seen,expires) VALUES(?,?,?,?,?,?,?,?,?,?)',id,digest(token),key,hwid,body.user,Number(body.v),role,now(),now(),now()+ttl);
      audit('client','session.open',id);
      return {ok:true,token,ttl,role};
    });
    signed(res,body.nonce,outcome);
  }
  function origin(req) {
    const value=req.headers.origin;
    if(!config.adminOrigins.includes(value)) fail(403,'Недопустимый источник запроса');
  }
  function authenticated(req,write=false) {
    const match=(req.headers.cookie||'').match(/(?:^|;\s*)violite_session=([a-f0-9]{64})(?:;|$)/);
    const session=match&&query.get('SELECT * FROM admin_sessions WHERE hash=?',digest(match[1]));
    if(!session||session.last_seen+900<=now()||session.created+43200<=now()) fail(401,'Требуется вход');
    if(write){origin(req);if(!equal(req.headers['x-csrf-token']||'',session.csrf))fail(403,'Обновите страницу и повторите действие');}
    query.run('UPDATE admin_sessions SET last_seen=? WHERE hash=?',now(),session.hash);
    return session;
  }
  // Secure — всегда через HTTPS-хост панели; по туннелю http://127.0.0.1 — без него
  const cookie=(req,value,age)=>`violite_session=${value}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${age}${config.secureCookie||viaHttps(req)?'; Secure':''}`;
  async function admin(req,res,path,url) {
    if(req.method==='POST' && path==='/api/auth/login') {
      origin(req);rate('login:'+clientIp(req),5,900);
      const body=await jsonBody(req);
      if(!text(body.username,1,64)||!text(body.password,1,1024)) fail(401,'Неверный логин или пароль');
      const valid=await passwordMatches(body.password,config.passwordHash);
      if(!valid||!equal(body.username,config.username)) {audit('anonymous','login.failed',clientIp(req));fail(401,'Неверный логин или пароль');}
      const challenge=randomToken();query.run('INSERT INTO challenges VALUES(?,?,0)',digest(challenge),now()+180);
      return send(res,200,{challenge});
    }
    if(req.method==='POST' && path==='/api/auth/mfa') {
      origin(req);rate('mfa:'+clientIp(req),15,900);const body=await jsonBody(req);
      if(!/^[a-f0-9]{64}$/.test(body.challenge||'')) fail(401,'Повторите вход');
      const challenge=query.get('SELECT * FROM challenges WHERE hash=?',digest(body.challenge));
      if(!challenge||challenge.expires<=now()||challenge.attempts>=5) fail(401,'Повторите вход');
      query.run('UPDATE challenges SET attempts=attempts+1 WHERE hash=?',challenge.hash);
      const last=query.get('SELECT last_totp FROM auth_state WHERE id=1').last_totp;
      const step=totpStep(config.totpSecret,String(body.code||''),now(),last);
      if(step===null) fail(401,'Неверный или уже использованный код');
      const token=randomToken(),csrf=randomToken();
      query.transaction(()=>{
        query.run('UPDATE auth_state SET last_totp=? WHERE id=1',step);
        query.run('DELETE FROM challenges');
        query.run('DELETE FROM rate_limits WHERE bucket IN (?,?)','login:'+clientIp(req),'mfa:'+clientIp(req));
        query.run('INSERT INTO admin_sessions VALUES(?,?,?,?)',digest(token),csrf,now(),now());
        audit('owner','login.ok',clientIp(req));
      });
      return send(res,200,{ok:true},{'Set-Cookie':cookie(req,token,43200)});
    }
    if(path.startsWith('/api/')) {
      const session=authenticated(req,req.method!=='GET');
      if(req.method==='GET' && path==='/api/auth/me') return send(res,200,{username:config.username,csrf:session.csrf});
      if(req.method==='POST' && path==='/api/auth/logout') {
        query.run('DELETE FROM admin_sessions WHERE hash=?',session.hash);
        return send(res,200,{ok:true},{'Set-Cookie':cookie(req,'',0)});
      }
      if(req.method==='GET' && path==='/api/roblox') {
        // Имена и аватары для панели; не больше 100 ID за запрос
        const ids=String(url.searchParams.get('ids')||'').split(',').filter(Boolean);
        if(!ids.length||ids.length>100||!ids.every(id=>/^\d{1,20}$/.test(id)))fail(400,'Нужен список User ID');
        return send(res,200,{profiles:await roblox.lookup(ids)});
      }
      if(req.method==='GET' && path==='/api/state') {
        const sessions=query.all('SELECT id,user_id,version,role,created,last_seen,expires,revoked,reason,substr(key_hash,1,12) AS key_ref,substr(hwid_hash,1,12) AS hwid_ref FROM sessions ORDER BY created DESC LIMIT 2000');
        const totals=query.get('SELECT count(*) AS total,sum(CASE WHEN revoked=0 AND expires>? THEN 1 ELSE 0 END) AS active FROM sessions',now());
        return send(res,200,{api:2,serverTime:now(),settings:query.get('SELECT maintenance FROM settings WHERE id=1'),releases:query.all('SELECT * FROM releases ORDER BY version DESC LIMIT 500'),sessions,totals,bans:query.all('SELECT id,kind,CASE WHEN kind=\'user\' THEN value ELSE substr(value,1,12) END AS reference,reason,created FROM bans ORDER BY created DESC LIMIT 500'),logs:query.all('SELECT * FROM audit ORDER BY id DESC LIMIT 200'),ttl,heartbeat:60,prices:prices.status()});
      }
      const body=await jsonBody(req);
      if(req.method==='POST' && path==='/api/prices/run') {
        // Ручное обновление: расписание не сдвигается (слоты считаются от часов)
        if(!prices.run('manual'))fail(409,'Обновление уже идёт или цены не настроены');
        audit('owner','prices.run','');
        return send(res,200,{ok:true});
      }
      if(req.method==='POST' && path==='/api/releases') {
        if(!version(body.version)||!text(body.label,1,80))fail(400,'Нужны числовой Build ID и название');
        if(query.get('SELECT 1 FROM releases WHERE version=?',Number(body.version)))fail(409,'Такой Build ID уже существует');
        query.transaction(()=>{query.run("INSERT INTO releases VALUES(?,?,'draft',?)",Number(body.version),body.label,now());audit('owner','release.create',String(body.version));});
      } else if(req.method==='POST' && /^\/api\/releases\/\d+\/status$/.test(path)) {
        const v=Number(path.split('/')[3]);if(!['draft','published','blocked'].includes(body.status))fail(400,'Неизвестный статус');
        if(!query.get('SELECT 1 FROM releases WHERE version=?',v))fail(404,'Версия не найдена');
        query.transaction(()=>{query.run('UPDATE releases SET status=? WHERE version=?',body.status,v);audit('owner','release.'+body.status,String(v));});
      } else if(req.method==='POST' && /^\/api\/sessions\/[a-f0-9]{24}\/revoke$/.test(path)) {
        const id=path.split('/')[3];if(!query.get('SELECT 1 FROM sessions WHERE id=?',id))fail(404,'Сессия не найдена');
        query.transaction(()=>{query.run("UPDATE sessions SET revoked=1,reason='Сессия завершена владельцем' WHERE id=?",id);audit('owner','session.revoke',id);});
      } else if(req.method==='POST' && path==='/api/sessions/revoke-all') {
        query.transaction(()=>{query.run("UPDATE sessions SET revoked=1,reason='Сессия завершена владельцем' WHERE revoked=0");audit('owner','session.revoke-all','');});
      } else if(req.method==='POST' && path==='/api/settings') {
        if(typeof body.maintenance!=='boolean')fail(400,'Нужно значение maintenance');
        query.transaction(()=>{query.run('UPDATE settings SET maintenance=? WHERE id=1',Number(body.maintenance));audit('owner','maintenance',String(body.maintenance));});
      } else if(req.method==='POST' && path==='/api/bans') {
        if(body.kind==='hwid'&&body.user!==undefined) {
          // Бан аккаунта бессмыслен (новый создаётся за минуту), поэтому блокируются
          // все устройства, на которых этот аккаунт запускал скрипт
          if(!/^\d{1,20}$/.test(String(body.user))||!text(body.reason,1,160))fail(400,'Заполните User ID и причину');
          const hashes=query.all('SELECT DISTINCT hwid_hash FROM sessions WHERE user_id=?',String(body.user)).map(r=>r.hwid_hash);
          if(!hashes.length)fail(404,'Аккаунт не встречается в сессиях');
          const fresh=hashes.filter(h=>!query.get("SELECT 1 FROM bans WHERE kind='hwid' AND value=?",h));
          if(!fresh.length)fail(409,'Все устройства аккаунта уже заблокированы');
          query.transaction(()=>{for(const h of fresh){const id=randomToken().slice(0,24);query.run("INSERT INTO bans VALUES(?,'hwid',?,?,?)",id,h,body.reason,now());audit('owner','ban.create',id);}});
          return send(res,200,{ok:true,count:fresh.length});
        }
        let value;
        if(body.kind==='hwid'&&body.ref!==undefined) {
          // Панель видит только начало HMAC устройства: полный хеш берём из сессий
          if(!/^[a-f0-9]{12}$/.test(body.ref)||!text(body.reason,1,160))fail(400,'Заполните HWID и причину');
          const found=query.all('SELECT DISTINCT hwid_hash FROM sessions WHERE substr(hwid_hash,1,12)=? LIMIT 2',body.ref);
          if(found.length!==1)fail(404,'HWID не найден среди сессий');
          value=found[0].hwid_hash;
        } else {
          if(!['key','hwid','user'].includes(body.kind)||!text(body.value,1,512)||!text(body.reason,1,160))fail(400,'Заполните тип, значение и причину');
          if(body.kind==='user'&&!/^\d{1,20}$/.test(body.value))fail(400,'User ID должен быть числом');
          value=body.kind==='user'?body.value:identity(body.kind,body.value);
        }
        const id=randomToken().slice(0,24);
        if(query.get('SELECT 1 FROM bans WHERE kind=? AND value=?',body.kind,value))fail(409,'Блокировка уже существует');
        query.transaction(()=>{query.run('INSERT INTO bans VALUES(?,?,?,?,?)',id,body.kind,value,body.reason,now());audit('owner','ban.create',id);});
      } else if(req.method==='POST' && /^\/api\/bans\/[a-f0-9]{24}\/remove$/.test(path)) {
        const id=path.split('/')[3];if(!query.get('SELECT 1 FROM bans WHERE id=?',id))fail(404,'Блокировка не найдена');
        query.transaction(()=>{query.run('DELETE FROM bans WHERE id=?',id);audit('owner','ban.remove',id);});
      } else fail(404,'Операция не найдена');
      return send(res,200,{ok:true});
    }
    if(req.method!=='GET'&&req.method!=='HEAD')fail(405,'Method not allowed');
    // Только явно разрешённые файлы панели. Исходники и конфигурация недоступны.
    const file=path==='/'?'index.html':path.slice(1);
    if(!/^(index\.html|dashboard\.html|assets\/(common\.js|login\.js|live\.js|style\.css))$/.test(file))fail(404,'Not found');
    // До первого push рабочей панели используем проверенную копию релиза.
    // После push существующий таймер продолжает обновлять только статические файлы.
    let panelDirectory=config.panelDirectory;
    if(config.panelFallbackDirectory) {
      const marker=await readFile(resolve(panelDirectory,'control-api-version.json'),'utf8').then(JSON.parse).catch(()=>null);
      if(marker?.version!==1)panelDirectory=config.panelFallbackDirectory;
    }
    const data=await readFile(resolve(panelDirectory,file));
    res.writeHead(200,{'Content-Type':{'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript; charset=utf-8'}[extname(file)],'Cache-Control':'no-store'});res.end(req.method==='HEAD'?undefined:data);
  }
  function listener(kind) {
    return http.createServer({maxHeaderSize:8192},async(req,res)=>{
      res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Cache-Control','no-store');
      res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');
      res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://*.rbxcdn.com; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
      try {
        const url=new URL(req.url,'http://localhost'),path=url.pathname;
        if(kind==='public') await control(req,res,path);else await admin(req,res,path,url);
      } catch(e) {
        if(!res.headersSent)send(res,e.status||500,{error:e.status?e.message:'Ошибка сервера'});else res.end();
        if(!e.status)console.error('Control request failed:',e.code||e.name);
      }
    });
  }
  const publicServer=listener('public'),adminServer=listener('admin');
  for(const server of [publicServer,adminServer]) {server.requestTimeout=10000;server.headersTimeout=10000;server.maxRequestsPerSocket=100;}
  return {publicServer,adminServer,store,identity,prices,close(){clearInterval(timer);prices.stop();store.close();}};
}

function send(res,status,data,headers={}) {res.writeHead(status,{'Content-Type':'application/json; charset=utf-8',...headers});res.end(JSON.stringify(data));}
async function jsonBody(req) {
  if(!/^application\/json(?:;|$)/i.test(req.headers['content-type']||''))fail(415,'Требуется application/json');
  let size=0;const parts=[];
  for await(const part of req) {size+=part.length;if(size>16384)fail(413,'Запрос слишком большой');parts.push(part);}
  try {const value=JSON.parse(Buffer.concat(parts).toString('utf8'));if(!value||Array.isArray(value)||typeof value!=='object')throw 0;return value;}catch{fail(400,'Некорректный JSON');}
}
