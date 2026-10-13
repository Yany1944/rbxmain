// Рабочая панель: данные только с сервера, изменения подтверждаются ответом API.
(() => {
  'use strict';

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 1: Константы, состояние, утилиты
  // ════════════════════════════════════════════════════════════════════════
  const PAGES={overview:['Обзор','grid'],sessions:['Сессии','activity'],users:['Пользователи','users'],releases:['Релизы','box'],bans:['Блокировки','ban'],prices:['Цены','tag'],logs:['Журнал','list'],settings:['Настройки','settings']};
  const PAGE_SIZES=[10,25,50,100];
  const FILTERS={sessions:{status:'all',version:'all'},users:{status:'all',sort:'last'},releases:{status:'all'},bans:{kind:'all'},logs:{type:'all'}};
  const EVENTS={'login.ok':'Вход владельца','login.failed':'Неудачный вход','release.create':'Создана версия','release.published':'Версия опубликована','release.blocked':'Версия заблокирована','release.draft':'Версия в черновиках','session.open':'Запуск скрипта','session.revoke':'Сессия завершена','session.revoke-all':'Завершены все сессии','ban.create':'Блокировка','ban.remove':'Снята блокировка',maintenance:'Режим обслуживания','prices.run':'Обновление цен вручную','prices.updated':'Цены обновлены','prices.failed':'Ошибка обновления цен'};
  const ACTORS={owner:'Владелец',client:'Клиент',anonymous:'Гость',system:'Сервер'};
  const RELEASE_STATUS={draft:['Черновик',''],published:['Опубликована','on'],blocked:['Заблокирована','bad']};
  const category=event=>event.split('.')[0];

  const plural=(n,one,few,many)=>{const m10=n%10,m100=n%100;return `${n} ${m10===1&&m100!==11?one:m10>=2&&m10<=4&&(m100<12||m100>14)?few:many}`;};
  const launches=n=>plural(n,'запуск','запуска','запусков');
  const devicesText=n=>plural(n,'устройство','устройства','устройств');
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const content=document.getElementById('content');
  const page=()=>PAGES[location.hash.slice(1)]?location.hash.slice(1):'overview';
  const date=v=>new Date(v*1000).toLocaleString('ru-RU',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
  const clock=v=>new Date(v*1000).toLocaleTimeString('ru-RU',{hour:'2-digit',minute:'2-digit'});
  const dayKey=v=>{const d=new Date(v*1000);return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;};
  const dayTitle=v=>{
    const d=new Date(v*1000),today=new Date(),yesterday=new Date(Date.now()-86400000);
    if(d.toDateString()===today.toDateString())return 'Сегодня';
    if(d.toDateString()===yesterday.toDateString())return 'Вчера';
    return d.toLocaleDateString('ru-RU',{day:'numeric',month:'long',weekday:'long'});
  };
  const agoText=v=>{const s=Math.max(0,data.serverTime-v);return s<60?'только что':s<3600?`${Math.floor(s/60)} мин назад`:s<86400?`${Math.floor(s/3600)} ч назад`:s<86400*7?`${Math.floor(s/86400)} д назад`:date(v);};
  const ago=v=>`<span title="${esc(date(v))}">${agoText(v)}</span>`;
  // Настройки вида живут только в этом браузере; без localStorage всё работает со значениями по умолчанию
  const local={
    get(k,d){try{const v=localStorage.getItem('violite.'+k);return v===null?d:JSON.parse(v);}catch{return d;}},
    set(k,v){try{localStorage.setItem('violite.'+k,JSON.stringify(v));}catch{}},
  };

  let data=null,model=null,csrf='',busy=false,requestId=0,clockOffset=0,drawerRef=null,modalOpen=false,resultCount='';
  const views={},expanded=new Set(),profiles=new Map(),profileWait=new Set();
  const view=key=>views[key]??={q:'',page:1,size:local.get('size.'+key,25),...FILTERS[key]};

  async function api(path,body) {
    const response=await fetch(path,{method:body===undefined?'GET':'POST',credentials:'same-origin',cache:'no-store',headers:body===undefined?{}:{'Content-Type':'application/json','X-CSRF-Token':csrf},body:body===undefined?undefined:JSON.stringify(body)});
    const result=await response.json().catch(()=>({error:'Сервер недоступен'}));
    if(response.status===401){location.replace('index.html');throw new Error('Требуется вход');}
    if(!response.ok)throw new Error(result.error||'Не удалось выполнить запрос');
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 2: Модель — устройства (HWID) → аккаунты → сессии
  // ════════════════════════════════════════════════════════════════════════
  function buildModel() {
    const now=data.serverTime;
    const releases=new Map(data.releases.map(r=>[r.version,r]));
    const userBans=new Map(),hwidBans=new Map(),bansById=new Map();
    for(const b of data.bans){bansById.set(b.id,b);if(b.kind==='user')userBans.set(b.reference,b);else if(b.kind==='hwid')hwidBans.set(b.reference,b);}
    const devices=new Map(),sessionsById=new Map(),accountDevices=new Map(),accountFirst=new Map();
    // Сессии приходят от новых к старым: первая встреченная — последняя по времени
    for(const s of data.sessions) {
      s.active=!s.revoked&&s.expires>now;
      sessionsById.set(s.id,s);
      let d=devices.get(s.hwid_ref);
      if(!d){d={ref:s.hwid_ref,raw:'',sessions:[],accounts:new Map(),keys:new Set(),first:s.created,last:s.last_seen,active:0};devices.set(s.hwid_ref,d);}
      d.sessions.push(s);d.keys.add(s.key_ref);if(!d.raw&&s.hwid)d.raw=s.hwid;
      d.first=Math.min(d.first,s.created);d.last=Math.max(d.last,s.last_seen);if(s.active)d.active++;
      let a=d.accounts.get(s.user_id);
      if(!a){a={id:s.user_id,sessions:[],first:s.created,last:s.last_seen,active:0};d.accounts.set(s.user_id,a);}
      a.sessions.push(s);a.first=Math.min(a.first,s.created);a.last=Math.max(a.last,s.last_seen);if(s.active)a.active++;
      const refs=accountDevices.get(s.user_id)||new Set();refs.add(s.hwid_ref);accountDevices.set(s.user_id,refs);
      accountFirst.set(s.user_id,Math.min(accountFirst.get(s.user_id)??Infinity,s.created));
    }
    for(const d of devices.values()) {
      d.ban=hwidBans.get(d.ref)||null;
      d.accountList=[...d.accounts.values()].sort((x,y)=>y.active-x.active||y.last-x.last);
    }
    const deviceList=[...devices.values()].sort((a,b)=>(b.active>0)-(a.active>0)||b.last-a.last);
    const active=data.sessions.filter(s=>s.active);
    model={releases,userBans,hwidBans,bansById,devices,deviceList,sessionsById,accountDevices,accountFirst,active,
      online:new Set(active.map(s=>s.user_id)),accounts:accountDevices.size};
  }

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 3: Элементы разметки
  // ════════════════════════════════════════════════════════════════════════
  const profile=id=>profiles.get(id)||null;
  const accountName=id=>{const p=profile(id);return p?.displayName||p?.name||id;};
  const avatar=(id,size='',online=false)=>{const p=profile(id);return `<span class="avatar ${size} ${online?'on':''}">${p?.avatar?`<img src="${esc(p.avatar)}" alt="" loading="lazy" referrerpolicy="no-referrer">`:icon('user')}</span>`;};
  function who(id,size='',extra='',online=false) {
    const p=profile(id),title=p?.displayName||p?.name||id;
    const sub=[p?.name?'@'+p.name:'',p?.name||p?.displayName?id:'',extra].filter(Boolean).join(' · ');
    return `<span class="who">${avatar(id,size,online)}<span class="who-text"><b>${esc(title)}</b>${sub?`<small>${esc(sub)}</small>`:''}</span></span>`;
  }
  // Полный HWID из экзекутора; у старых сессий его нет — тогда начало HMAC устройства
  const rawOf=ref=>model.devices.get(ref)?.raw||ref;
  const hwid=(ref,bad=false)=>{const v=rawOf(ref);return `<span class="hwid ${bad?'bad':''} ${v.length>16?'long':''}" title="${esc(v)}">${esc(v)}</span>`;};
  const hwidShort=ref=>{const v=rawOf(ref);return v.length>16?v.slice(0,12)+'…':v;};
  const version=v=>{const r=model.releases.get(Number(v));return `<span class="version"><b>${esc(r?.label||'Неизвестная')}</b><span class="build">${esc(v)}</span></span>`;};
  const versionText=r=>`${r.label} · ${r.version}`;
  const status=(text,tone='',title='')=>`<span class="status ${tone}" ${title?`title="${esc(title)}"`:''}>${esc(text)}</span>`;
  const sessionStatus=s=>s.active?status('В игре','on'):s.revoked?status('Завершена','',s.reason):status('Вышел');
  const deviceStatus=d=>d.ban?status('Заблокирован','bad',d.ban.reason):d.active?status(d.active>1?`В игре · ${d.active}`:'В игре','on'):status('Не в игре');
  const stack=(ids,max=4)=>`<span class="stack">${ids.slice(0,max).map(id=>avatar(id,'sm',model.online.has(id))).join('')}</span>`;
  const accountsCell=d=>{const ids=d.accountList.map(a=>a.id);return `<div class="accounts-cell">${stack(ids)}<span class="names">${esc(ids.slice(0,3).map(accountName).join(', '))}${ids.length>3?` <i>+${ids.length-3}</i>`:''}</span></div>`;};
  const btn=(text,action,id='',cls='')=>`<button type="button" class="btn btn-sm ${cls}" data-action="${action}" data-id="${esc(id)}">${esc(text)}</button>`;
  const profileLink=id=>`<a class="icon-btn sm" href="https://www.roblox.com/users/${esc(id)}/profile" target="_blank" rel="noopener noreferrer" title="Профиль Roblox" aria-label="Профиль Roblox">${icon('external')}</a>`;
  const empty=(title,text,ic='inbox')=>`<div class="empty"><span class="tile">${icon(ic)}</span><b>${esc(title)}</b>${text?`<span>${esc(text)}</span>`:''}</div>`;
  const head=h=>Array.isArray(h)?`<th class="${h[1]}">${h[0]}</th>`:`<th>${h}</th>`;
  const table=(heads,rows,emptyHtml)=>`<div class="table-wrap"><table class="table"><thead><tr>${heads.map(head).join('')}</tr></thead><tbody>${rows||`<tr><td colspan="${heads.length}">${emptyHtml}</td></tr>`}</tbody></table></div>`;
  const card=(title,body,end='',sub='')=>`<section class="card"><div class="card-head"><h2>${title}</h2>${sub?`<span class="sub">${sub}</span>`:''}${end}</div>${body}</section>`;
  const search=(key,placeholder)=>`<label class="search">${icon('search')}<input class="input" type="search" data-filter="${key}" data-name="q" value="${esc(view(key).q)}" placeholder="${esc(placeholder)}" aria-label="Поиск"></label>`;
  const select=(key,name,label,options)=>`<select class="select" data-filter="${key}" data-name="${name}" aria-label="${esc(label)}">${options.map(([v,t])=>`<option value="${esc(v)}" ${String(view(key)[name])===String(v)?'selected':''}>${esc(t)}</option>`).join('')}</select>`;
  const seg=(key,name,label,options)=>`<div class="seg" role="group" aria-label="${esc(label)}">${options.map(([v,t])=>`<button type="button" data-seg="${key}" data-name="${name}" data-value="${esc(v)}" class="${String(view(key)[name])===String(v)?'is-active':''}" aria-pressed="${String(view(key)[name])===String(v)}">${esc(t)}</button>`).join('')}</div>`;
  const count='<span class="count" id="count"></span>';
  const field=(name,title,attrs='',hint='')=>`<div class="field"><label for="f-${name}">${title}</label><input class="input" id="f-${name}" name="${name}" required autocomplete="off" ${attrs}>${hint?`<span class="hint">${hint}</span>`:''}</div>`;
  const matchAccount=(id,q)=>id.includes(q)||(profile(id)?.name||'').toLowerCase().includes(q)||(profile(id)?.displayName||'').toLowerCase().includes(q);
  const filtered=(key,keys)=>{const v=view(key);return v.q.trim()!==''||keys.some(k=>v[k]!==FILTERS[key][k]);};

  // Постраничный вывод: размер страницы запоминается для каждой таблицы
  function paginate(key,rows,noun) {
    const v=view(key),pages=Math.max(1,Math.ceil(rows.length/v.size));
    v.page=Math.min(Math.max(1,v.page),pages);
    const start=(v.page-1)*v.size;
    resultCount=noun(rows.length);
    const pager=rows.length>PAGE_SIZES[0]||v.page>1?`<div class="pager"><label>Показывать <select class="select" data-size="${key}" aria-label="Записей на странице">${PAGE_SIZES.map(n=>`<option ${n===v.size?'selected':''}>${n}</option>`).join('')}</select></label><div class="pager-nav"><span>${start+1}–${Math.min(start+v.size,rows.length)} из ${rows.length}</span><button class="icon-btn" data-action="page" data-id="${key}:-1" ${v.page<=1?'disabled':''} aria-label="Предыдущая страница">${icon('left')}</button><button class="icon-btn" data-action="page" data-id="${key}:1" ${v.page>=pages?'disabled':''} aria-label="Следующая страница">${icon('chevron')}</button></div></div>`:'';
    return {rows:rows.slice(start,start+v.size),pager};
  }

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 4: График запусков по дням (один ряд — без легенды, подсказка по наведению)
  // ════════════════════════════════════════════════════════════════════════
  const CHART_DAYS=14;
  function activityDays() {
    const today=new Date();today.setHours(0,0,0,0);
    const days=[];
    for(let i=CHART_DAYS-1;i>=0;i--){const start=new Date(today);start.setDate(today.getDate()-i);days.push({start:start.getTime()/1000,count:0,devices:new Set(),accounts:new Set()});}
    const first=days[0].start;
    for(const s of data.sessions) {
      if(s.created<first)continue;
      const day=days[Math.min(CHART_DAYS-1,Math.floor((s.created-first)/86400))];
      // Переход на летнее время сдвигает сутки на час — уточняем по календарной дате
      const d=days.find(x=>dayKey(x.start)===dayKey(s.created))||day;
      d.count++;d.devices.add(s.hwid_ref);d.accounts.add(s.user_id);
    }
    return days;
  }
  function niceMax(v){if(v<=4)return 4;const p=10**Math.floor(Math.log10(v));const n=v/p;return (n<=2?2:n<=5?5:10)*p;}
  function drawCharts() {
    const el=document.querySelector('[data-chart]');if(!el||!data)return;
    const days=activityDays(),w=Math.max(260,el.clientWidth-36),h=el.querySelector('svg')?.clientHeight||190;
    const left=34,bottom=24,top=16,plotW=w-left,plotH=h-bottom-top;
    const max=niceMax(Math.max(...days.map(d=>d.count))),slot=plotW/days.length,barW=Math.min(24,slot*0.62);
    const y=v=>top+plotH-(v/max)*plotH;
    const peak=days.reduce((a,b)=>b.count>a.count?b:a,days[0]);
    const every=slot<34?2:1;
    let svg=`<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="Запуски скрипта по дням за ${CHART_DAYS} дней">`;
    for(const t of [0,max/2,max])svg+=`<line class="grid" x1="${left}" x2="${w}" y1="${y(t)}" y2="${y(t)}"/><text class="axis" x="${left-8}" y="${y(t)+4}" text-anchor="end">${Math.round(t)}</text>`;
    days.forEach((d,i)=>{
      const cx=left+slot*i+slot/2,x=cx-barW/2,bh=Math.max(0,y(0)-y(d.count)),r=Math.min(4,bh,barW/2),yt=y(d.count);
      const label=new Date(d.start*1000).toLocaleDateString('ru-RU',{day:'2-digit',month:'2-digit'});
      const isToday=i===days.length-1;
      svg+=`<g class="col" data-i="${i}"><rect class="hit" x="${left+slot*i}" y="${top}" width="${slot}" height="${plotH+bottom}"/>`;
      svg+=d.count?`<path class="bar" d="M${x},${y(0)}V${yt+r}Q${x},${yt} ${x+r},${yt}H${x+barW-r}Q${x+barW},${yt} ${x+barW},${yt+r}V${y(0)}Z"/>`:`<rect class="bar zero" x="${x}" y="${y(0)-2}" width="${barW}" height="2" rx="1"/>`;
      if(d===peak&&d.count)svg+=`<text class="peak" x="${cx}" y="${yt-6}" text-anchor="middle">${d.count}</text>`;
      if(isToday||(days.length-1-i)%every===0)svg+=`<text class="axis ${isToday?'today':''}" x="${cx}" y="${h-6}" text-anchor="middle">${label}</text>`;
      svg+='</g>';
    });
    svg+='</svg>';
    el.innerHTML=svg+'<div class="tip" id="chartTip"></div>';
    const tip=el.querySelector('#chartTip'),svgEl=el.querySelector('svg');
    svgEl.addEventListener('mousemove',e=>{
      const col=e.target.closest('.col');if(!col){tip.classList.remove('is-on');return;}
      const d=days[Number(col.dataset.i)],i=Number(col.dataset.i);
      tip.innerHTML=`<b>${esc(new Date(d.start*1000).toLocaleDateString('ru-RU',{weekday:'short',day:'numeric',month:'long'}))}</b>${esc(launches(d.count))}<br><span>${esc(devicesText(d.devices.size))} · ${esc(plural(d.accounts.size,'аккаунт','аккаунта','аккаунтов'))}</span>`;
      tip.style.left=`${18+left+slot*i+slot/2}px`;tip.style.top=`${Math.max(8,y(d.count)-4)}px`;tip.classList.add('is-on');
    });
    svgEl.addEventListener('mouseleave',()=>tip.classList.remove('is-on'));
  }
  let resizeTimer=0;
  window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(drawCharts,120);});

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 5: Страницы
  // ════════════════════════════════════════════════════════════════════════
  const pages={
    overview:{
      meta:()=>data.settings.maintenance?'<b>Обслуживание включено</b> · запуски отклоняются':`<b>${model.online.size}</b> ${plural(model.online.size,'игрок','игрока','игроков').replace(/^\d+ /,'')} в игре сейчас`,
      results() {
        const published=data.releases.filter(r=>r.status==='published');
        const week=data.serverTime-7*86400,dayStart=new Date().setHours(0,0,0,0)/1000;
        const newDevices=model.deviceList.filter(d=>d.first>=week).length;
        const newAccounts=[...model.accountFirst.values()].filter(t=>t>=week).length;
        const today=data.sessions.filter(s=>s.created>=dayStart).length;
        const activeDevices=new Set(model.active.map(s=>s.hwid_ref)).size;
        let html='';
        if(data.settings.maintenance)html+=`<div class="notice is-warning">${icon('alert')}Включено обслуживание: запуск и продление сессий отклоняются.<a class="btn btn-sm" href="#settings">Настройки</a></div>`;
        else if(!published.length)html+=`<div class="notice is-warning">${icon('alert')}Нет опубликованных версий — скрипт не запустится ни у кого.<a class="btn btn-sm" href="#releases">Релизы</a></div>`;
        const stats=[
          ['В игре',model.online.size,'activity','green','#sessions',`на ${devicesText(activeDevices)}`],
          ['Устройств',model.deviceList.length,'device','','#users',newDevices?`<b>+${newDevices}</b> за 7 дней`:'новых за 7 дней нет'],
          ['Аккаунтов',model.accounts,'users','purple','#users',newAccounts?`<b>+${newAccounts}</b> за 7 дней`:'новых за 7 дней нет'],
          ['Запусков за 30 дней',data.totals.total||0,'play','orange','#logs',`${today} сегодня`],
        ];
        html+=`<div class="stats">${stats.map(([l,v,ic,tone,h,foot])=>`<a class="stat" href="${h}"><div class="stat-top"><span class="tile ${tone}">${icon(ic)}</span>${l}</div><div><div class="stat-value">${esc(v)}</div><div class="stat-foot">${foot}</div></div></a>`).join('')}</div>`;
        const players=model.active.slice(0,12).map(s=>`<button type="button" class="player" data-action="open" data-id="${esc(s.hwid_ref)}">${avatar(s.user_id,'lg',true)}<span class="who-text"><b>${esc(accountName(s.user_id))}</b><small>${esc(model.releases.get(s.version)?.label||s.version)} · с ${esc(clock(s.created))}</small></span></button>`).join('');
        const more=model.active.length>12?`<a class="link" href="#sessions">Ещё ${model.active.length-12}</a>`:'<a class="link" href="#sessions">Все сессии</a>';
        const versions=published.map(r=>`<li>${version(r.version)}<span class="end">${model.active.filter(s=>s.version===r.version).length} в игре</span></li>`).join('');
        const feed=data.logs.slice(0,7).map(l=>{const ref=logRef(l);return `<li><span class="dot c-${category(l.event)}"></span><span class="text">${esc(EVENTS[l.event]||l.event)}${ref.text.trim()?`<small>${esc(ref.short||ref.text)}</small>`:''}</span><time title="${esc(date(l.time))}">${agoText(l.time)}</time></li>`;}).join('');
        const days=activityDays(),total=days.reduce((a,d)=>a+d.count,0);
        html+=`<div class="grid-main"><div class="stack-v">${card('Запуски по дням',`<div class="chart" data-chart><svg></svg></div>`,`<span class="end muted num" style="font-size:13px">${esc(launches(total))} за ${CHART_DAYS} дней</span>`)}${card('Сейчас в игре',players?`<div class="players">${players}</div>`:empty('Сейчас никто не играет','Активные игроки появятся здесь после запуска скрипта.','activity'),more)}</div><div class="stack-v">${card('Опубликованные версии',versions?`<ul class="versions">${versions}</ul>`:empty('Нет опубликованных версий','Опубликуйте релиз, чтобы открыть запуск.','box'),'<a class="link" href="#releases">Релизы</a>')}${card('Последние события',feed?`<ul class="feed">${feed}</ul>`:empty('Событий пока нет','','list'),'<a class="link" href="#logs">Журнал</a>')}</div></div>`;
        return html;
      },
    },

    sessions:{
      meta:()=>`<b>${model.active.length}</b> активных · ${devicesText(model.deviceList.length)} за 30 дней`,
      toolbar:()=>search('sessions','HWID, User ID или ник')+seg('sessions','status','Состояние',[['all','Все'],['active','В игре'],['ended','Завершённые']])+select('sessions','version','Версия',[['all','Все версии'],...data.releases.map(r=>[r.version,versionText(r)])])+count,
      results() {
        const v=view('sessions'),q=v.q.trim().toLowerCase();
        const match=s=>(v.status==='all'||(v.status==='active')===s.active)&&(v.version==='all'||String(s.version)===String(v.version))&&(!q||s.hwid_ref.includes(q)||(s.hwid||'').toLowerCase().includes(q)||matchAccount(s.user_id,q));
        const groups=model.deviceList.map(d=>({d,sessions:d.sessions.filter(match)})).filter(g=>g.sessions.length);
        const {rows,pager}=paginate('sessions',groups,devicesText);
        const html=rows.map(({d,sessions})=>{
          const open=expanded.has(d.ref);
          let out=`<tr class="clickable ${open?'is-open':''}" data-action="toggle" data-id="${esc(d.ref)}" aria-expanded="${open}"><td class="nowrap"><span class="chev">${icon('chevron')}</span>${hwid(d.ref,!!d.ban)}</td><td>${accountsCell(d)}</td><td>${deviceStatus(d)}</td><td class="hide-sm">${version(sessions[0].version)}</td><td class="nowrap muted">${ago(d.last)}</td><td class="actions">${btn('Открыть','open',d.ref,'btn-ghost')}</td></tr>`;
          if(open) {
            // Внутри устройства — аккаунты, с которых запускали скрипт, по их последней сессии
            const ids=[...new Set(sessions.map(s=>s.user_id))];
            out+=ids.map((id,i)=>{
              const a=d.accounts.get(id),last=sessions.find(s=>s.user_id===id),active=sessions.filter(s=>s.user_id===id&&s.active);
              return `<tr class="child ${i===ids.length-1?'last':''}"><td colspan="2">${who(id,'',launches(a.sessions.length),active.length>0)}</td><td>${sessionStatus(active[0]||last)}</td><td class="hide-sm">${version(last.version)}</td><td class="nowrap muted">${ago(a.last)}</td><td class="actions">${active.length?btn('Завершить','revoke-account',`${d.ref}|${id}`,'btn-danger'):profileLink(id)}</td></tr>`;
            }).join('');
          }
          return out;
        }).join('');
        return table(['HWID','Аккаунты','Состояние',['Версия','hide-sm'],'Последняя связь',['','actions']],html,filtered('sessions',['status','version'])?empty('Ничего не найдено','Измените запрос или фильтры.','search'):empty('Сессий пока нет','Они появятся после первого запуска скрипта.','activity'))+pager;
      },
      actions:()=>model&&model.active.length?btn('Завершить все','revoke-all','','btn-danger'):'',
    },

    users:{
      meta:()=>`${devicesText(model.deviceList.length)} · ${plural(model.accounts,'аккаунт','аккаунта','аккаунтов')} · <b>${model.hwidBans.size}</b> в бане`,
      toolbar:()=>search('users','HWID, User ID или ник')+seg('users','status','Состояние',[['all','Все'],['online','В игре'],['banned','Заблокированы']])+select('users','sort','Сортировка',[['last','По активности'],['first','Сначала новые'],['launches','По числу запусков']])+count,
      results() {
        const v=view('users'),q=v.q.trim().toLowerCase();
        let list=model.deviceList.filter(d=>(v.status==='all'||(v.status==='online'?d.active>0:!!d.ban))&&(!q||d.ref.includes(q)||d.raw.toLowerCase().includes(q)||d.accountList.some(a=>matchAccount(a.id,q))));
        if(v.sort==='first')list=[...list].sort((a,b)=>b.first-a.first);
        else if(v.sort==='launches')list=[...list].sort((a,b)=>b.sessions.length-a.sessions.length);
        const {rows,pager}=paginate('users',list,devicesText);
        const html=rows.map(d=>`<tr class="clickable" data-action="open" data-id="${esc(d.ref)}"><td class="nowrap">${hwid(d.ref,!!d.ban)}</td><td>${accountsCell(d)}</td><td class="num">${d.sessions.length}</td><td class="nowrap muted hide-sm">${ago(d.first)}</td><td class="nowrap muted">${ago(d.last)}</td><td>${deviceStatus(d)}</td><td class="actions"><span class="row-go">${icon('chevron')}</span></td></tr>`).join('');
        return table(['HWID','Аккаунты','Запусков',['Первый запуск','hide-sm'],'Последняя связь','Состояние',['','actions']],html,filtered('users',['status'])?empty('Ничего не найдено','Измените запрос или фильтры.','search'):empty('Пользователей пока нет','Первый запуск скрипта добавит устройство в этот список.','users'))+pager;
      },
    },

    releases:{
      meta:()=>{const p=data.releases.filter(r=>r.status==='published');return p.length?`Запуск открыт: <b>${esc(p.map(r=>r.label).join(', '))}</b>`:'<b>Нет опубликованных версий</b> · запуск закрыт';},
      toolbar:()=>search('releases','Название или Build ID')+seg('releases','status','Статус',[['all','Все'],['published','Опубликованные'],['draft','Черновики'],['blocked','Заблокированные']])+count,
      results() {
        const v=view('releases'),q=v.q.trim().toLowerCase();
        const list=data.releases.filter(r=>(v.status==='all'||r.status===v.status)&&(!q||r.label.toLowerCase().includes(q)||String(r.version).includes(q)));
        const {rows,pager}=paginate('releases',list,n=>plural(n,'версия','версии','версий'));
        const html=rows.map(r=>{
          const online=model.active.filter(s=>s.version===r.version).length,total=data.sessions.filter(s=>s.version===r.version).length;
          const [text,tone]=RELEASE_STATUS[r.status];
          const act=r.status==='published'?btn('Заблокировать','block',r.version,'btn-danger'):btn('Опубликовать','publish',r.version);
          return `<tr><td><div class="who"><span class="tile ${r.status==='published'?'green':r.status==='blocked'?'pink':''}">${icon('box')}</span><span class="who-text"><b>${esc(r.label)}</b><small>Build ${esc(r.version)}</small></span></div></td><td>${status(text,tone)}</td><td class="num">${online?`<span class="status on plain">${online}</span>`:'<span class="faint">0</span>'}</td><td class="num muted hide-sm">${total}</td><td class="nowrap muted hide-sm">${esc(date(r.created))}</td><td class="actions">${act}</td></tr>`;
        }).join('');
        return table(['Версия','Статус','В игре',['Запусков','hide-sm'],['Создана','hide-sm'],['','actions']],html,filtered('releases',['status'])?empty('Ничего не найдено','Измените запрос или фильтр.','search'):empty('Версий пока нет','Создайте черновик с Build ID из сборки.','box'))+pager;
      },
      actions:()=>`<button type="button" class="btn btn-primary" data-action="new-release">${icon('plus')}Новая версия</button>`,
    },

    bans:{
      meta:()=>`<b>${model.hwidBans.size}</b> ${model.hwidBans.size===1?'устройство':'устройств'} в бане`,
      toolbar:()=>search('bans','HWID, ник, User ID или причина')+(data.bans.some(b=>b.kind!=='hwid')?seg('bans','kind','Тип',[['all','Все'],['hwid','HWID'],['legacy','Старые']]):'')+count,
      results() {
        const v=view('bans'),q=v.q.trim().toLowerCase();
        const accountsOf=b=>b.kind==='hwid'?(model.devices.get(b.reference)?.accountList.map(a=>a.id)||[]):b.kind==='user'?[b.reference]:[];
        const list=data.bans.filter(b=>(v.kind==='all'||(v.kind==='hwid')===(b.kind==='hwid'))&&(!q||b.reference.toLowerCase().includes(q)||rawOf(b.reference).toLowerCase().includes(q)||b.reason.toLowerCase().includes(q)||accountsOf(b).some(id=>matchAccount(id,q))));
        const {rows,pager}=paginate('bans',list,n=>plural(n,'блокировка','блокировки','блокировок'));
        const html=rows.map(b=>{
          const ref=b.kind==='hwid'?(model.devices.has(b.reference)?b.reference:''):b.kind==='user'?[...(model.accountDevices.get(b.reference)||[])][0]||'':'';
          // Старые баны аккаунта/ключа ещё действуют на сервере — показываем, чтобы их можно было снять
          const target=b.kind==='hwid'?hwid(b.reference,true):`<span class="pill">${b.kind==='user'?'Старый бан аккаунта':'Старый бан ключа'}</span>`;
          const d=model.devices.get(b.reference),accounts=b.kind==='user'?who(b.reference,'sm'):d?accountsCell(d):'<span class="faint">нет в сессиях</span>';
          return `<tr ${ref?`class="clickable" data-action="open" data-id="${esc(ref)}"`:''}><td class="nowrap">${target}</td><td>${accounts}</td><td class="reason">${esc(b.reason)}</td><td class="nowrap muted hide-sm">${esc(date(b.created))}</td><td class="actions">${btn('Снять','unban',b.id)}</td></tr>`;
        }).join('');
        return table(['HWID','Аккаунты','Причина',['Создана','hide-sm'],['','actions']],html,filtered('bans',['kind'])?empty('Ничего не найдено','Измените запрос.','search'):empty('Блокировок нет','Бан по User ID заблокирует все устройства аккаунта.','shield'))+pager;
      },
      actions:()=>`<button type="button" class="btn btn-primary" data-action="new-ban">${icon('plus')}Новая блокировка</button>`,
    },

    prices:{
      meta:()=>data.prices?.enabled?'Обновление каждые 4 часа от 00:00 МСК':'Не настроены',
      results() {
        const pr=data.prices||{};
        if(!pr.enabled)return `<div class="card">${empty('Цены не настроены','На сервере не задан pricesDir.','tag')}</div>`;
        const history=pr.history||[],lastOk=history.find(r=>r.ok===1);
        const trigger={schedule:'По расписанию',manual:'Вручную'};
        const run=r=>r.finished?(r.ok?status('Готово','on'):status('Ошибка','bad')):status('Идёт','warn');
        const facts=`<div class="facts"><div class="fact"><span>Следующее обновление</span><b class="big" data-countdown="${esc(pr.nextRun)}">${esc(countdown(pr.nextRun))}</b></div><div class="fact"><span>Состояние</span><b class="big">${pr.running?'Обновляется':'Ожидание'}</b></div><div class="fact"><span>По расписанию</span><b>${esc(date(pr.nextRun))}</b></div><div class="fact"><span>Прокси</span><b>${pr.proxy?'Настроен':'Не задан'}</b></div></div>`;
        const last=lastOk?`<div class="facts"><div class="fact"><span>Цен в выдаче</span><b class="big">${esc(lastOk.priced)}</b></div><div class="fact"><span>Обновлено</span><b class="big">${agoText(lastOk.finished)}</b></div><div class="fact"><span>Время</span><b>${esc(date(lastOk.finished))}</b></div><div class="fact"><span>Запуск</span><b>${esc(trigger[lastOk.trigger]||lastOk.trigger)}</b></div></div>`:empty('Цен ещё нет','Запустите обновление вручную или дождитесь слота.','tag');
        const rows=history.map(r=>`<tr><td>${run(r)}</td><td>${esc(trigger[r.trigger]||r.trigger)}</td><td class="nowrap muted">${esc(date(r.started))}</td><td class="num">${r.finished?esc(`${r.finished-r.started} с`):'—'}</td><td class="num">${esc(r.priced??'—')}</td><td class="muted">${esc(r.error||'')}</td></tr>`).join('');
        return `<div class="grid-2">${card('Расписание',`<div class="card-body">${facts}</div>`,'','Ручной запуск его не сдвигает')}${card('Последнее успешное',`<div class="card-body">${last}</div>`)}</div><div style="height:16px"></div>${card('Запуски',table(['Статус','Запуск','Начало','Длительность','Цен','Ошибка'],rows,empty('Запусков ещё не было','','clock')),'','последние 10')}`;
      },
      actions:()=>{const running=data?.prices?.running;return data?.prices?.enabled?`<button type="button" class="btn btn-primary" data-action="prices-run" ${running?'disabled':''}>${icon('refresh')}${running?'Обновляется…':'Обновить сейчас'}</button>`:'';},
    },

    logs:{
      meta:()=>'Последние 200 событий',
      toolbar:()=>search('logs','Событие, аккаунт, HWID')+select('logs','type','Тип',[['all','Все события'],['session.','Сессии'],['release.','Релизы'],['ban.','Блокировки'],['login.','Входы'],['prices.','Цены'],['maintenance','Обслуживание']])+count,
      results() {
        const v=view('logs'),q=v.q.trim().toLowerCase();
        const list=data.logs.filter(l=>(v.type==='all'||l.event.startsWith(v.type))&&(!q||(EVENTS[l.event]||l.event).toLowerCase().includes(q)||l.detail.toLowerCase().includes(q)||logRef(l).text.toLowerCase().includes(q)));
        const {rows,pager}=paginate('logs',list,n=>plural(n,'событие','события','событий'));
        let lastDay='',html='';
        // Разделители по дням: журнал читается как лента, а не как сплошная таблица
        for(const l of rows) {
          const key=dayKey(l.time);
          if(key!==lastDay){lastDay=key;html+=`<tr class="day"><td colspan="4">${esc(dayTitle(l.time))}</td></tr>`;}
          const ref=logRef(l);
          html+=`<tr ${ref.open?`class="clickable" data-action="open" data-id="${esc(ref.open)}"`:''}><td class="nowrap muted num" style="width:72px">${esc(clock(l.time))}</td><td class="nowrap"><span class="feed-ev"><span class="dot c-${category(l.event)}" style="display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:10px;vertical-align:middle"></span>${esc(EVENTS[l.event]||l.event)}</span></td><td>${ref.html}</td><td class="muted hide-sm">${esc(ACTORS[l.actor]||l.actor)}</td></tr>`;
        }
        return table(['Время','Событие','Объект',['Кто','hide-sm']],html,filtered('logs',['type'])?empty('Ничего не найдено','Измените запрос или тип.','search'):empty('Событий пока нет','','list'))+pager;
      },
    },

    settings:{
      meta:()=>'Доступ к скрипту и вход владельца',
      results() {
        const on=!!data.settings.maintenance;
        const row=(title,text,control)=>`<div class="setting"><div class="setting-text"><b>${title}</b><span>${text}</span></div>${control}</div>`;
        return `${card('Доступ',row('Техническое обслуживание','Пока включено, новые запуски и продление сессий отклоняются. После выключения игроки запускают скрипт заново.',`${status(on?'Включено':'Выключено',on?'warn':'')}<button type="button" class="switch" role="switch" aria-checked="${on}" aria-label="Техническое обслуживание" data-action="maintenance"></button>`)+row('Проверка клиента','Как часто клиент подтверждает сессию.',`<span class="setting-value">каждые ${esc(data.heartbeat)}–${esc(data.heartbeat+10)} с</span>`)+row('Срок сессии','Сессия без подтверждения истекает через это время.',`<span class="setting-value">${esc(data.ttl)} с</span>`)+row('Завершение и бан','Применяются не мгновенно, а на следующей проверке клиента.',`<span class="setting-value">до ${esc(data.heartbeat+10)} с</span>`))}<div style="height:16px"></div>${card('Вход владельца',row('Способ входа','Пароль и одноразовый код из приложения-аутентификатора.','<span class="setting-value">Пароль + TOTP</span>')+row('Без активности','Сессия панели завершается, если не пользоваться ею.','<span class="setting-value">15 минут</span>')+row('Максимальная длительность','После этого нужно войти заново.','<span class="setting-value">12 часов</span>'))}`;
      },
    },
  };

  // Объект записи журнала: аккаунт сессии, версия, цель блокировки
  function logRef(l) {
    if(l.event==='session.open'||l.event==='session.revoke') {
      const s=model.sessionsById.get(l.detail);
      if(s)return {html:`<div class="who">${avatar(s.user_id,'sm',s.active)}<span class="who-text"><b>${esc(accountName(s.user_id))}</b><small>${esc(hwidShort(s.hwid_ref))}</small></span></div>`,text:`${accountName(s.user_id)} ${s.user_id} ${rawOf(s.hwid_ref)}`,short:`${accountName(s.user_id)} · ${hwidShort(s.hwid_ref)}`,open:s.hwid_ref};
    }
    if(l.event.startsWith('release.')&&/^\d+$/.test(l.detail)){const r=model.releases.get(Number(l.detail));return {html:version(l.detail),text:`${r?.label||''} ${l.detail}`,short:r?`${r.label} · ${l.detail}`:l.detail};}
    if(l.event.startsWith('ban.')) {
      const b=model.bansById.get(l.detail);
      if(b&&b.kind==='user')return {html:who(b.reference,'sm'),text:`${accountName(b.reference)} ${b.reference}`,open:[...(model.accountDevices.get(b.reference)||[])][0]};
      if(b){const d=model.devices.get(b.reference);return {html:`${hwid(b.reference,true)}${d?` <span class="muted" style="margin-left:6px">${esc(d.accountList.slice(0,2).map(a=>accountName(a.id)).join(', '))}</span>`:''}`,text:`${rawOf(b.reference)} ${d?d.accountList.map(a=>accountName(a.id)).join(' '):''}`,short:`${hwidShort(b.reference)} · ${b.reason}`,open:d?b.reference:''};}
      return {html:'<span class="faint">снята</span>',text:''};
    }
    if(l.event==='maintenance')return {html:l.detail==='true'?status('Включено','warn'):status('Выключено'),text:l.detail==='true'?'Включено':'Выключено'};
    if(l.event.startsWith('login.'))return {html:`<span class="mono muted">${esc(l.detail)}</span>`,text:l.detail,short:`IP ${l.detail}`};
    return {html:`<span class="mono muted">${esc(l.detail)}</span>`,text:l.detail};
  }

  // Отсчёт до слота цен по часам сервера
  const countdown=at=>{const left=Math.max(0,Math.round(at-(Date.now()/1000+clockOffset)));const h=Math.floor(left/3600),m=Math.floor(left%3600/60),s=left%60;return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;};

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 6: Отрисовка — каркас страницы строится один раз, данные обновляются отдельно
  // ════════════════════════════════════════════════════════════════════════
  function renderNav(current) {
    const counts={sessions:[model.active.length,'live'],users:[model.deviceList.length,''],bans:[data.bans.length,'']};
    document.getElementById('navigation').innerHTML=Object.entries(PAGES).map(([id,[title,ic]])=>`<a href="#${id}" class="nav-item ${id===current?'is-active':''}" ${id===current?'aria-current="page"':''}>${icon(ic)}<span>${title}</span>${counts[id]?.[0]?`<span class="nav-count ${counts[id][1]}">${counts[id][0]}</span>`:''}</a>`).join('');
  }
  function render() {
    if(!data)return;
    const current=page(),def=pages[current];
    renderNav(current);
    if(content.dataset.page!==current) {
      content.dataset.page=current;
      document.title=`${PAGES[current][0]} · Violite`;
      content.innerHTML=`<div class="page-head"><div><h1>${PAGES[current][0]}</h1><div class="page-meta" id="pageMeta"></div></div><div class="page-actions"><span class="updated" id="updated"></span><button type="button" class="icon-btn" id="refreshBtn" data-action="refresh" title="Обновить" aria-label="Обновить">${icon('refresh')}</button><span id="pageActions"></span></div></div>${def.toolbar?`<section class="card"><div class="toolbar" id="toolbar">${def.toolbar()}</div><div id="results"></div></section>`:'<div id="results"></div>'}`;
    } else {
      // Не перестраиваем панель фильтров, пока в ней фокус — иначе собьётся ввод
      const bar=document.getElementById('toolbar');
      if(bar&&!bar.contains(document.activeElement))bar.innerHTML=def.toolbar();
    }
    document.getElementById('pageMeta').innerHTML=def.meta?def.meta():'';
    document.getElementById('pageActions').innerHTML=def.actions?def.actions():'';
    document.getElementById('updated').textContent=`Обновлено в ${new Date(data.serverTime*1000).toLocaleTimeString('ru-RU')}`;
    renderResults();
    renderDrawer();
  }
  function renderResults() {
    const el=document.getElementById('results');
    if(!el||!data)return;
    resultCount='';
    el.innerHTML=pages[page()].results();
    const c=document.getElementById('count');if(c)c.textContent=resultCount;
    drawCharts();
  }
  // Скелет до первого ответа сервера, чтобы страница не прыгала
  content.innerHTML=`<div class="skeleton"><div class="sk" style="height:34px;width:220px"></div><div class="stats">${'<div class="sk" style="height:118px;border-radius:12px"></div>'.repeat(4)}</div><div class="sk" style="height:300px;border-radius:12px"></div></div>`;

  const conn=document.getElementById('conn');
  async function load() {
    const id=++requestId;
    try {
      const next=await api('/api/state');if(id!==requestId)return;
      data=next;clockOffset=next.serverTime-Date.now()/1000;buildModel();render();
      conn.classList.remove('is-off');conn.textContent='Сервер на связи';
      requestProfiles();
    } catch(error) {
      conn.classList.add('is-off');conn.textContent='Нет связи с сервером';
      if(!data)content.innerHTML=`<div class="page-head"><div><h1>Нет соединения</h1></div></div><div class="notice is-error">${icon('alert')}${esc(error.message)}<button type="button" class="btn btn-sm" data-action="refresh">Повторить</button></div>`;
    }
  }

  // Имена и аватары Roblox подгружаются после данных и дорисовываются без перезагрузки
  async function requestProfiles() {
    if(!data||data.api<2)return;
    const ids=[...new Set([...data.sessions.map(s=>s.user_id),...data.bans.filter(b=>b.kind==='user').map(b=>b.reference)])].filter(id=>!profiles.has(id)&&!profileWait.has(id));
    if(!ids.length)return;
    let changed=false;
    for(let i=0;i<ids.length;i+=100) {
      const chunk=ids.slice(i,i+100);chunk.forEach(id=>profileWait.add(id));
      try{const r=await api('/api/roblox?ids='+chunk.join(','));for(const id of chunk)profiles.set(id,r.profiles[id]||null);changed=true;}
      catch{/* повтор при следующем обновлении данных */}
      finally{chunk.forEach(id=>profileWait.delete(id));}
    }
    if(changed){renderResults();renderDrawer();}
  }

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 7: Карточка пользователя (HWID) — всё управление в одном месте
  // ════════════════════════════════════════════════════════════════════════
  const drawer=document.getElementById('drawer');
  function openDrawer(ref) {
    drawerRef=ref;renderDrawer();
    if(!drawer.open)drawer.showModal();
    drawer.scrollTop=0;
  }
  function renderDrawer() {
    if(!drawerRef||!model)return;
    const d=model.devices.get(drawerRef),scroll=drawer.scrollTop;
    // Заголовок — основной аккаунт устройства, как в Jnkie; HWID целиком отдельным блоком
    const main=d?.accountList[0],more=d?d.accountList.length-1:0;
    const top=`<div class="drawer-top"><span>Пользователь</span><button type="button" class="icon-btn" data-action="close-drawer" aria-label="Закрыть">${icon('x')}</button></div><div class="drawer-head">${main?avatar(main.id,'xl',main.active>0):`<span class="tile lg">${icon('device')}</span>`}<div class="drawer-name"><h2 id="drawerTitle">${esc(main?accountName(main.id):'Устройство')}${more?` <span class="more">+${more}</span>`:''}</h2>${d?`<div class="drawer-sub">${deviceStatus(d)}${d.ban?`<span>${esc(d.ban.reason)}</span>`:`<span>${launches(d.sessions.length)} · ${plural(d.accountList.length,'аккаунт','аккаунта','аккаунтов')}</span>`}</div>`:''}</div></div>`;
    if(!d){document.getElementById('drawerBody').innerHTML=top+empty('Устройство не найдено','Оно больше не встречается в сессиях за 30 дней.','device');return;}
    const raw=d.raw||d.ref;
    const hwidBox=`<div class="hwid-box ${d.ban?'bad':''}"><div class="hwid-box-text"><span>HWID${d.raw?'':' · начало хеша, сессии до обновления сервера'}</span><code>${esc(raw)}</code></div><button type="button" class="icon-btn" data-action="copy" data-id="${esc(raw)}" title="Скопировать HWID" aria-label="Скопировать HWID">${icon('copy')}</button></div>`;
    const canBanHwid=data.api>=2;
    const actions=[
      d.active?btn(`Завершить сессии (${d.active})`,'revoke-device',d.ref):'',
      d.ban?btn('Снять блокировку HWID','unban',d.ban.id):`<button type="button" class="btn btn-sm btn-danger" data-action="ban-hwid" data-id="${esc(d.ref)}" ${canBanHwid?'':'disabled title="Нужно обновить сервер Control"'}>${icon('ban')}Заблокировать HWID</button>`,
    ].join('');
    const facts=`${hwidBox}<div class="facts"><div class="fact"><span>Первый запуск</span><b>${esc(date(d.first))}</b></div><div class="fact"><span>Последняя связь</span><b>${agoText(d.last)}</b></div><div class="fact"><span>Запусков</span><b>${d.sessions.length}</b></div><div class="fact"><span>Аккаунтов</span><b>${d.accountList.length}</b></div></div><div class="keyline">Ключ Jnkie: ${[...d.keys].map(k=>`<span class="mono">${esc(k)}</span>`).join(', ')}</div>`;
    const accounts=d.accountList.map(a=>{
      const ban=model.userBans.get(a.id);
      const other=(model.accountDevices.get(a.id)?.size||1)-1;
      return `<div class="account">${who(a.id,'lg','',a.active>0)}<div class="account-meta">${a.active?status('В игре','on'):ago(a.last)}<br>${launches(a.sessions.length)}${other?` · ещё ${devicesText(other)}`:''}${ban?` · <span class="pill bad" title="${esc(ban.reason)}">Старый бан</span>`:''}</div><div class="account-actions">${profileLink(a.id)}${ban?btn('Снять старый бан','unban',ban.id):''}${other?btn('Бан всех HWID','ban-account',a.id,'btn-danger'):''}</div></div>`;
    }).join('');
    const history=d.sessions.slice(0,30).map(s=>`<tr><td>${who(s.user_id,'sm')}</td><td>${version(s.version)}</td><td class="nowrap muted">${ago(s.created)}</td><td>${sessionStatus(s)}</td><td class="actions">${s.active?btn('Завершить','revoke',s.id,'btn-danger'):''}</td></tr>`).join('');
    document.getElementById('drawerBody').innerHTML=`${top}${facts}<div class="drawer-actions">${actions}</div><h3>Аккаунты <span class="pill">${d.accountList.length}</span></h3><div class="accounts">${accounts}</div><h3>Сессии <span class="pill">${d.sessions.length>30?'последние 30':d.sessions.length}</span></h3><div class="framed">${table(['Аккаунт','Версия','Запуск','Состояние',['','actions']],history,empty('Сессий нет',''))}</div>`;
    drawer.scrollTop=scroll;
  }
  drawer.addEventListener('close',()=>{drawerRef=null;});
  // Клик по затемнению вокруг панели закрывает её
  drawer.addEventListener('click',e=>{if(e.target===drawer){const r=drawer.getBoundingClientRect();if(e.clientX<r.left)drawer.close();}});

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 8: Диалоги и действия
  // ════════════════════════════════════════════════════════════════════════
  function showDialog(title,body,submitLabel,danger=false) {
    if(modalOpen)return Promise.resolve(null);
    modalOpen=true;
    const dialog=document.getElementById('modal'),form=document.getElementById('modalForm'),submitBtn=document.getElementById('submitModal');
    document.getElementById('modalTitle').textContent=title;
    document.getElementById('modalBody').innerHTML=body;
    submitBtn.textContent=submitLabel;
    submitBtn.className=`btn ${danger?'btn-danger btn-solid':'btn-primary'}`;
    return new Promise(resolve=>{
      let result=null;
      const submit=e=>{e.preventDefault();result=Object.fromEntries(new FormData(form));dialog.close();};
      const cancel=()=>dialog.close();
      form.addEventListener('submit',submit);
      document.getElementById('cancelModal').addEventListener('click',cancel);
      dialog.addEventListener('close',()=>{
        form.removeEventListener('submit',submit);
        document.getElementById('cancelModal').removeEventListener('click',cancel);
        modalOpen=false;resolve(result);
      },{once:true});
      dialog.showModal();
      (dialog.querySelector('#modalBody input,#modalBody select')||submitBtn).focus();
    });
  }
  const confirmAction=(title,text,label='Подтвердить',danger=false)=>showDialog(title,`<p>${text}</p>`,label,danger);
  const reasonField=field('reason','Причина','maxlength="160" placeholder="Например, передача ключа"','Покажется игроку при отказе в доступе.');

  // Выполнить запрос(ы) к API и перечитать данные
  async function perform(target,fn,message='Сохранено') {
    busy=true;if(target)target.disabled=true;
    try{const result=await fn();toast(typeof message==='function'?message(result||{}):message);await load();}
    catch(err){toast(err.message,'alert');}
    finally{busy=false;if(target)target.disabled=false;}
  }

  const handlers={
    refresh:(id,t)=>{if(t){t.classList.remove('spin');void t.offsetWidth;t.classList.add('spin');}return load();},
    toggle:id=>{expanded.has(id)?expanded.delete(id):expanded.add(id);renderResults();},
    open:id=>id&&openDrawer(id),
    'close-drawer':()=>drawer.close(),
    copy:id=>navigator.clipboard?.writeText(id).then(()=>toast('Скопировано'),()=>toast('Не удалось скопировать','alert')),
    page:id=>{const [key,dir]=id.split(':');view(key).page+=Number(dir);renderResults();document.getElementById('toolbar')?.scrollIntoView({block:'nearest'});},
    async revoke(id,t){if(await confirmAction('Завершить сессию?','Скрипт у игрока выгрузится на следующей проверке.','Завершить',true))await perform(t,()=>api(`/api/sessions/${id}/revoke`,{}),'Сессия завершена');},
    async 'revoke-account'(id,t){
      const [ref,user]=id.split('|'),list=model.devices.get(ref)?.accounts.get(user)?.sessions.filter(s=>s.active)||[];
      if(list.length&&await confirmAction('Завершить сессию?',`Аккаунт ${esc(accountName(user))} будет отключён на следующей проверке.`,'Завершить',true))
        await perform(t,async()=>{for(const s of list)await api(`/api/sessions/${s.id}/revoke`,{});},'Сессия завершена');
    },
    async 'revoke-device'(ref,t){
      const list=model.devices.get(ref)?.sessions.filter(s=>s.active)||[];
      if(list.length&&await confirmAction('Завершить сессии устройства?',`Активных сессий: ${list.length}. Скрипт выгрузится на следующей проверке.`,'Завершить',true))
        await perform(t,async()=>{for(const s of list)await api(`/api/sessions/${s.id}/revoke`,{});},'Сессии завершены');
    },
    async 'revoke-all'(id,t){if(await confirmAction('Завершить все сессии?',`Будут отключены все игроки (${model.active.length}). Отменить нельзя.`,'Завершить все',true))await perform(t,()=>api('/api/sessions/revoke-all',{}),'Все сессии завершены');},
    async publish(v,t){if(await confirmAction('Опубликовать версию?',`<b>${esc(model.releases.get(Number(v))?.label)}</b> (Build ${esc(v)}) станет доступна для запуска.`,'Опубликовать'))await perform(t,()=>api(`/api/releases/${v}/status`,{status:'published'}),'Версия опубликована');},
    async block(v,t){if(await confirmAction('Заблокировать версию?',`<b>${esc(model.releases.get(Number(v))?.label)}</b> (Build ${esc(v)}): запуск и продление сессий этой версии будут отклоняться.`,'Заблокировать',true))await perform(t,()=>api(`/api/releases/${v}/status`,{status:'blocked'}),'Версия заблокирована');},
    async 'new-release'(id,t){
      const values=await showDialog('Новая версия',field('label','Название','maxlength="80" placeholder="Например, Violite 1.4"')+field('version','Build ID','type="number" min="1" max="999999999999" placeholder="Номер из сборки"','Версия создаётся черновиком — запуск закрыт до публикации.'),'Создать черновик');
      if(values)await perform(t,()=>api('/api/releases',{label:values.label.trim(),version:values.version}),'Черновик создан');
    },
    async 'new-ban'(id,t){
      const values=await showDialog('Новая блокировка',`<div class="field"><label for="f-kind">Найти устройство по</label><select class="select" id="f-kind" name="kind"><option value="user">Roblox User ID</option><option value="hwid">HWID</option></select></div>${field('value','Значение','maxlength="128" spellcheck="false"','По User ID блокируются все HWID, где запускался этот аккаунт. HWID — полностью, как в панели.')}${reasonField}`,'Заблокировать',true);
      if(!values)return;
      const value=values.value.trim();
      // Полный HWID сервер хеширует сам; 12 hex-символов — короткая ссылка старых сессий
      const body=values.kind!=='hwid'?{kind:'hwid',user:value,reason:values.reason}:/^[a-f0-9]{12}$/i.test(value)?{kind:'hwid',ref:value.toLowerCase(),reason:values.reason}:{kind:'hwid',value,reason:values.reason};
      await perform(t,()=>api('/api/bans',body),r=>r.count?`Заблокировано устройств: ${r.count}`:'Блокировка создана');
    },
    async 'ban-account'(id,t){
      const refs=[...(model.accountDevices.get(id)||[])].filter(ref=>!model.hwidBans.has(ref));
      if(!refs.length)return toast('Все устройства аккаунта уже заблокированы','alert');
      const values=await showDialog('Бан всех HWID аккаунта',`${who(id)}<p>Будут заблокированы устройства, где запускался этот аккаунт: ${refs.map(r=>hwid(r)).join(' ')}</p>${reasonField}`,'Заблокировать',true);
      if(values)await perform(t,()=>api('/api/bans',{kind:'hwid',user:id,reason:values.reason}),r=>`Заблокировано устройств: ${r.count}`);
    },
    async 'ban-hwid'(ref,t){const values=await showDialog('Заблокировать HWID',`<p>Устройство ${hwid(ref)} не сможет запускать скрипт ни с одного аккаунта.</p>${reasonField}`,'Заблокировать',true);if(values)await perform(t,()=>api('/api/bans',{kind:'hwid',ref,reason:values.reason}),'HWID заблокирован');},
    async unban(id,t){if(await confirmAction('Снять блокировку?','Доступ восстановится при следующем запуске.','Снять'))await perform(t,()=>api(`/api/bans/${id}/remove`,{}),'Блокировка снята');},
    async 'prices-run'(id,t){await perform(t,()=>api('/api/prices/run',{}),'Обновление цен запущено');},
    async maintenance(id,t){const on=!data.settings.maintenance;if(await confirmAction(on?'Включить обслуживание?':'Выключить обслуживание?',on?'Новые запуски и продление сессий будут отклоняться.':'Игроки снова смогут запускать скрипт.',on?'Включить':'Выключить',on))await perform(t,()=>api('/api/settings',{maintenance:on}),on?'Обслуживание включено':'Обслуживание выключено');},
  };

  document.addEventListener('click',e=>{
    const segBtn=e.target.closest('[data-seg]');
    if(segBtn) {
      // Сегмент-фильтр: подсветка обновляется на месте, перерисовываются только результаты
      const v=view(segBtn.dataset.seg);v[segBtn.dataset.name]=segBtn.dataset.value;v.page=1;
      for(const b of segBtn.parentElement.children){const on=b===segBtn;b.classList.toggle('is-active',on);b.setAttribute('aria-pressed',String(on));}
      renderResults();return;
    }
    const target=e.target.closest('[data-action]');
    if(!target||e.target.closest('a[href]')&&!e.target.closest('a[href]').dataset.action)return;
    if(busy&&!['toggle','open','close-drawer','copy','page'].includes(target.dataset.action))return;
    handlers[target.dataset.action]?.(target.dataset.id,target);
  });
  document.addEventListener('input',e=>{
    const el=e.target.closest('[data-filter]');if(!el)return;
    const v=view(el.dataset.filter);v[el.dataset.name]=el.value;v.page=1;renderResults();
  });
  document.addEventListener('change',e=>{
    const el=e.target.closest('[data-size]');if(!el)return;
    const v=view(el.dataset.size);v.size=Number(el.value);v.page=1;local.set('size.'+el.dataset.size,v.size);renderResults();
  });

  // ════════════════════════════════════════════════════════════════════════
  // БЛОК 9: Навигация, выход, автообновление
  // ════════════════════════════════════════════════════════════════════════
  const app=document.getElementById('app'),menuBtn=document.getElementById('menuBtn');
  const closeMenu=()=>{app.classList.remove('nav-open');menuBtn.setAttribute('aria-expanded','false');};
  menuBtn.addEventListener('click',()=>menuBtn.setAttribute('aria-expanded',String(app.classList.toggle('nav-open'))));
  document.getElementById('scrim').addEventListener('click',closeMenu);
  window.addEventListener('hashchange',()=>{closeMenu();if(drawer.open)drawer.close();render();content.focus({preventScroll:true});window.scrollTo(0,0);});
  document.getElementById('theme').addEventListener('click',()=>{window.cycleTheme();drawCharts();});
  document.getElementById('logout').addEventListener('click',async()=>{try{await api('/api/auth/logout',{});location.replace('index.html');}catch(err){toast(err.message,'alert');}});
  // «/» — к поиску текущей таблицы
  document.addEventListener('keydown',e=>{if(e.key==='/'&&!modalOpen&&!/INPUT|SELECT|TEXTAREA/.test(document.activeElement?.tagName||'')){const s=document.querySelector('.toolbar input[type=search]');if(s){e.preventDefault();s.focus();}}});

  api('/api/auth/me').then(me=>{csrf=me.csrf;return load();}).catch(err=>{content.innerHTML=`<div class="page-head"><div><h1>Сервер недоступен</h1></div></div><div class="notice is-error">${icon('alert')}${esc(err.message)}</div>`;});

  // Автообновление не трогает открытый диалог и не продлевает вход бездействующего владельца
  let lastActivity=Date.now();
  for(const event of ['pointerdown','keydown'])document.addEventListener(event,()=>{lastActivity=Date.now();});
  setInterval(()=>{if(!document.hidden&&!busy&&!modalOpen&&Date.now()-lastActivity<60000)load();},10000);
  setInterval(()=>{for(const el of document.querySelectorAll('[data-countdown]'))el.textContent=countdown(Number(el.dataset.countdown));},1000);
})();
