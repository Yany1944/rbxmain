import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {once} from 'node:events';
import {createApp} from '../app.js';
import {passwordHash,totp,base32,hmac,randomToken} from '../security.js';

const password='test-password-not-for-deployment';
const hash=await passwordHash(password);
const origin='http://127.0.0.1:8090';
async function fixture(t) {
  const directory=mkdtempSync(join(tmpdir(),'violite-control-'));
  let clock=1791490000000;
  const config={database:join(directory,'control.sqlite'),proxySecret:'p'.repeat(64),responseSecret:'r'.repeat(64),identitySecret:'i'.repeat(64),username:'owner',passwordHash:hash,totpSecret:'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',adminOrigins:[origin],panelDirectory:resolve('../admin-panel')};
  const robloxCalls=[];
  // Roblox в тестах не вызывается по сети: ответы users/thumbnails подставляются
  const robloxFetch=async(url,init)=>{
    robloxCalls.push(url);
    const body=String(url).includes('users.roblox.com')?{data:JSON.parse(init.body).userIds.filter(id=>id!==999).map(id=>({id,name:'user'+id,displayName:'Display '+id}))}:{data:[{targetId:12345,state:'Completed',imageUrl:'https://tr.rbxcdn.com/abc/150/150/AvatarHeadshot/Png/noFilter'},{targetId:777,state:'Completed',imageUrl:'https://evil.test/x.png'}]};
    return new Response(JSON.stringify(body),{status:200,headers:{'Content-Type':'application/json'}});
  };
  const app=createApp(config,{now:()=>clock,robloxFetch});
  app.publicServer.listen(0,'127.0.0.1');app.adminServer.listen(0,'127.0.0.1');
  await Promise.all([once(app.publicServer,'listening'),once(app.adminServer,'listening')]);
  const publicUrl=`http://127.0.0.1:${app.publicServer.address().port}`,adminUrl=`http://127.0.0.1:${app.adminServer.address().port}`;
  let cookie='',csrf='';
  async function admin(path,body,headers={}) {
    const r=await fetch(adminUrl+path,{method:body===undefined?'GET':'POST',headers:{Origin:origin,Cookie:cookie,'X-CSRF-Token':csrf,'Content-Type':'application/json',...headers},body:body===undefined?undefined:JSON.stringify(body)});
    return {status:r.status,body:await r.json(),cookie:r.headers.get('set-cookie')};
  }
  async function login() {
    const first=await admin('/api/auth/login',{username:'owner',password});assert.equal(first.status,200);
    const second=await admin('/api/auth/mfa',{challenge:first.body.challenge,code:totp(config.totpSecret,Math.floor(clock/30000))});assert.equal(second.status,200);
    cookie=second.cookie.split(';')[0];csrf=(await admin('/api/auth/me')).body.csrf;
  }
  async function control(path,body={},headers={}) {
    const b={key:'JN-TEST-KEY',hwid:'TEST-HWID',user:'12345',v:'100',nonce:randomToken().slice(0,32),...body};
    const r=await fetch(publicUrl+path,{method:'POST',headers:{'Content-Type':'application/json','X-Violite-Proxy':config.proxySecret,...headers},body:JSON.stringify(b)});
    const result=await r.json();
    if(result.payload){assert.equal(result.sig,hmac(config.responseSecret,b.nonce+'|'+result.payload));return {status:r.status,body:JSON.parse(result.payload)};}
    return {status:r.status,body:result};
  }
  async function publish() {await admin('/api/releases',{version:100,label:'1.0.0'});const r=await admin('/api/releases/100/status',{status:'published'});assert.equal(r.status,200);}
  t.after(async()=>{await Promise.all([new Promise(r=>app.publicServer.close(r)),new Promise(r=>app.adminServer.close(r))]);app.close();rmSync(directory,{recursive:true,force:true});});
  return {app,config,admin,control,login,publish,robloxCalls,advance:seconds=>{clock+=seconds*1000;},clock:()=>clock};
}

test('TOTP RFC 6238 vector (6 digits)',()=>{
  const secret=base32(Buffer.from('12345678901234567890'));
  assert.equal(totp(secret,1),'287082');
});
test('admin authentication, CSRF, Origin and public/admin separation',async t=>{
  const f=await fixture(t);
  assert.equal((await f.admin('/api/state')).status,401);
  assert.equal((await f.admin('/api/auth/login',{username:'owner',password},{Origin:'https://evil.test'})).status,403);
  assert.equal((await f.admin('/api/auth/login',{username:'owner',password:'wrong'})).status,401);
  await f.login();
  assert.equal((await f.admin('/api/settings',{maintenance:true},{'X-CSRF-Token':''})).status,403);
  assert.equal((await f.control('/api/state')).status,404);
  assert.equal((await f.control('/session',{}, {'X-Violite-Proxy':'wrong'})).status,401);
  assert.equal((await f.admin('/api/auth/logout',{})).status,200);
  assert.equal((await f.admin('/api/state')).status,401);
});
test('only published exact numeric Build IDs can start; blocked stops without kick',async t=>{
  const f=await fixture(t);await f.login();
  assert.deepEqual((await f.control('/session')).body,{ok:false,kill:true,kick:true,message:'Ошибка проверки версии'});
  assert.equal((await f.admin('/api/releases',{version:100,label:'1.0.0'})).status,200);
  assert.equal((await f.control('/session')).body.ok,false);
  await f.admin('/api/releases/100/status',{status:'published'});
  const start=(await f.control('/session')).body;assert.equal(start.ok,true);assert.equal(start.role,'user');
  await f.admin('/api/releases/100/status',{status:'blocked'});
  const beat=(await f.control('/beat',{token:start.token})).body;assert.equal(beat.ok,false);assert.equal(beat.kick,false);
});
test('heartbeat binding, nonce replay, TTL and token revocation',async t=>{
  const f=await fixture(t);await f.login();await f.publish();
  const nonce=randomToken().slice(0,32),s=(await f.control('/session',{nonce})).body;
  assert.equal((await f.control('/session',{nonce})).body.ok,false);
  for(const bad of [{key:'ANOTHER'},{hwid:'ANOTHER'},{user:'54321'},{token:'0'.repeat(64)}])assert.equal((await f.control('/beat',{token:s.token,...bad})).body.ok,false);
  assert.equal((await f.control('/beat',{token:s.token})).body.ok,true);
  const state=(await f.admin('/api/state')).body;
  assert.equal(JSON.stringify(state).includes('JN-TEST-KEY'),false);
  assert.equal(JSON.stringify(state).includes(s.token),false);
  await f.admin(`/api/sessions/${state.sessions[0].id}/revoke`,{});
  assert.equal((await f.control('/beat',{token:s.token})).body.ok,false);
  const next=(await f.control('/session')).body;f.advance(181);
  assert.equal((await f.control('/beat',{token:next.token})).body.ok,false);
});
test('maintenance, bans and revoke all are enforced by the client API',async t=>{
  const f=await fixture(t);await f.login();await f.publish();
  const s=(await f.control('/session')).body;
  await f.admin('/api/sessions/revoke-all',{});assert.equal((await f.control('/beat',{token:s.token})).body.ok,false);
  await f.admin('/api/settings',{maintenance:true});assert.equal((await f.control('/session')).body.ok,false);
  await f.admin('/api/settings',{maintenance:false});
  for(const [kind,value] of [['user','12345'],['key','JN-TEST-KEY'],['hwid','TEST-HWID']]) {
    assert.equal((await f.admin('/api/bans',{kind,value,reason:'Test denial'})).status,200);
    assert.equal((await f.control('/session')).body.message,'Test denial');
    const state=(await f.admin('/api/state')).body;
    await f.admin(`/api/bans/${state.bans[0].id}/remove`,{});
  }
  assert.equal((await f.control('/session')).body.ok,true);
});
test('duplicate releases, malformed input, idle expiry and one-use MFA',async t=>{
  const f=await fixture(t);await f.login();await f.publish();
  assert.equal((await f.admin('/api/releases',{version:100,label:'duplicate'})).status,409);
  assert.equal((await f.admin('/api/releases',{version:'1.2.3',label:'bad'})).status,400);
  assert.equal((await f.control('/session',{v:'1.2.3'})).status,400);
  const challenge=(await f.admin('/api/auth/login',{username:'owner',password})).body.challenge;
  assert.equal((await f.admin('/api/auth/mfa',{challenge,code:totp(f.config.totpSecret,Math.floor(f.clock()/30000))})).status,401);
  f.advance(901);assert.equal((await f.admin('/api/state')).status,401);
});
test('SQLite records survive a second connection',async t=>{
  const f=await fixture(t);await f.login();await f.publish();await f.control('/session');
  const second=createApp(f.config);
  try {assert.equal(second.store.get('SELECT count(*) AS n FROM releases').n,1);assert.equal(second.store.get('SELECT count(*) AS n FROM sessions').n,1);}finally{second.close();}
});

test('login rate limit is per client IP; HTTPS proxy gets a Secure cookie',async t=>{
  const f=await fixture(t);
  const attacker={'X-Forwarded-For':'203.0.113.7'};
  for(let i=0;i<5;i++)assert.equal((await f.admin('/api/auth/login',{username:'owner',password:'wrong'},attacker)).status,401);
  assert.equal((await f.admin('/api/auth/login',{username:'owner',password:'wrong'},attacker)).status,429);
  // Владелец с другого адреса входит, несмотря на перебор с чужого IP
  const owner={'X-Forwarded-For':'198.51.100.2','X-Forwarded-Proto':'https'};
  const first=await f.admin('/api/auth/login',{username:'owner',password},owner);assert.equal(first.status,200);
  const second=await f.admin('/api/auth/mfa',{challenge:first.body.challenge,code:totp(f.config.totpSecret,Math.floor(f.clock()/30000))},owner);
  assert.equal(second.status,200);assert.match(second.cookie,/; Secure/);
});

test('HWID ban by panel reference and Roblox profiles',async t=>{
  const f=await fixture(t);await f.login();await f.publish();
  assert.equal((await f.control('/session')).body.ok,true);
  const state=(await f.admin('/api/state')).body;assert.equal(state.api,2);
  const ref=state.sessions[0].hwid_ref;
  assert.equal((await f.admin('/api/bans',{kind:'hwid',ref:'0'.repeat(12),reason:'x'})).status,404);
  assert.equal((await f.admin('/api/bans',{kind:'hwid',ref,reason:'Device denial'})).status,200);
  assert.equal((await f.control('/session')).body.message,'Device denial');
  assert.equal((await f.admin('/api/state')).body.bans[0].reference,ref);
  assert.equal((await f.admin('/api/roblox?ids=12345,777,999')).status,200);
  const profiles=(await f.admin('/api/roblox?ids=12345,777,999')).body.profiles;
  assert.deepEqual(profiles['12345'],{name:'user12345',displayName:'Display 12345',avatar:'https://tr.rbxcdn.com/abc/150/150/AvatarHeadshot/Png/noFilter'});
  assert.equal(profiles['777'].avatar,null);assert.equal(profiles['999'].name,null);
  assert.equal(f.robloxCalls.length,2,'second lookup is served from cache');
  assert.equal((await f.admin('/api/roblox?ids=abc')).status,400);
});

test('ban by Roblox account blocks every HWID the account used',async t=>{
  const f=await fixture(t);await f.login();await f.publish();
  await f.control('/session',{hwid:'DEVICE-A',user:'500'});
  await f.control('/session',{hwid:'DEVICE-B',user:'500'});
  await f.control('/session',{hwid:'DEVICE-C',user:'600'});
  assert.equal((await f.admin('/api/bans',{kind:'hwid',user:'404',reason:'x'})).status,404);
  const r=await f.admin('/api/bans',{kind:'hwid',user:'500',reason:'Alt accounts'});
  assert.equal(r.status,200);assert.equal(r.body.count,2);
  assert.equal((await f.admin('/api/bans',{kind:'hwid',user:'500',reason:'again'})).status,409);
  // Новый аккаунт на заблокированном устройстве не проходит, чужое устройство — проходит
  assert.equal((await f.control('/session',{hwid:'DEVICE-B',user:'777'})).body.message,'Alt accounts');
  assert.equal((await f.control('/session',{hwid:'DEVICE-C',user:'600'})).body.ok,true);
  assert.equal((await f.admin('/api/state')).body.bans.filter(b=>b.kind==='hwid').length,2);
});
