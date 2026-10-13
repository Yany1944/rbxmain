import {readFileSync} from 'node:fs';
import {createApp} from './app.js';
const path=process.env.VIOLITE_CONFIG;
if(!path)throw new Error('Set VIOLITE_CONFIG to the private configuration file');
const config=JSON.parse(readFileSync(path,'utf8'));
const app=createApp(config);
app.publicServer.listen(config.publicPort||8791,'127.0.0.1');
app.adminServer.listen(config.adminPort||8792,'127.0.0.1');
for(const server of [app.publicServer,app.adminServer])server.on('error',error=>{console.error('Listener failed:',error.code);process.exit(1);});
let stopping=false;
function shutdown(){if(stopping)return;stopping=true;let pending=2;for(const server of [app.publicServer,app.adminServer])server.close(()=>{if(--pending===0){app.close();process.exit(0);}});setTimeout(()=>process.exit(1),12000).unref();}
process.on('SIGTERM',shutdown);process.on('SIGINT',shutdown);
