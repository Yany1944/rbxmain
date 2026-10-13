// Создаёт новый комплект вне Git. Существующие файлы никогда не перезаписывает.
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {passwordHash,randomToken,base32} from './security.js';
const directory=process.argv[2];
if(!directory)throw new Error('Usage: node control-server/init.js <private-directory> [panel-directory]');
const output=resolve(directory);
mkdirSync(output,{recursive:true,mode:0o700});
const password=randomToken(),totpSecret=base32(randomBytes(20));
const config={database:join(output,'control.sqlite'),panelDirectory:resolve(process.argv[3]||'admin-panel'),adminPort:8792,publicPort:8791,adminOrigins:['http://127.0.0.1:8090','http://localhost:8090','http://127.0.0.1:8792'],secureCookie:false,username:'owner',passwordHash:await passwordHash(password),totpSecret,proxySecret:randomToken(),responseSecret:randomToken(),identitySecret:randomToken(),ownerKeyHashes:[]};
writeFileSync(join(output,'config.json'),JSON.stringify(config,null,2)+'\n',{flag:'wx',mode:0o600});
writeFileSync(join(output,'FIRST-LOGIN.txt'),`Violite owner login\nUsername: owner\nPassword: ${password}\nTOTP secret: ${totpSecret}\notpauth://totp/Violite:owner?secret=${totpSecret}&issuer=Violite&algorithm=SHA1&digits=6&period=30\n\nStore these in your password manager and remove this file. Never upload it to Git.\n`,{flag:'wx',mode:0o600});
console.log('Created private config and FIRST-LOGIN.txt. No credentials printed.');
