import {DatabaseSync,backup} from 'node:sqlite';
import {readFileSync,chmodSync,existsSync} from 'node:fs';
const config=JSON.parse(readFileSync(process.env.VIOLITE_CONFIG,'utf8'));
const destination=process.argv[2];
if(!destination||existsSync(destination))throw new Error('Provide a new backup destination');
const db=new DatabaseSync(config.database,{readOnly:true});
try{await backup(db,destination);chmodSync(destination,0o600);}finally{db.close();}
console.log('Consistent database backup completed.');
