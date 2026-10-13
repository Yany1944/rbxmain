import {DatabaseSync} from 'node:sqlite';
import {mkdirSync} from 'node:fs';
import {dirname} from 'node:path';

export function openStore(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), {recursive:true, mode:0o700});
  const db = new DatabaseSync(path);
  if(db.prepare('PRAGMA user_version').get().user_version>1){db.close();throw new Error('Database schema is newer than this server');}
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS settings(id INTEGER PRIMARY KEY CHECK(id=1),maintenance INTEGER NOT NULL DEFAULT 0);
    INSERT OR IGNORE INTO settings(id) VALUES(1);
    CREATE TABLE IF NOT EXISTS releases(version INTEGER PRIMARY KEY,label TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('draft','published','blocked')),created INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY,token_hash TEXT UNIQUE NOT NULL,key_hash TEXT NOT NULL,hwid_hash TEXT NOT NULL,user_id TEXT NOT NULL,version INTEGER NOT NULL,role TEXT NOT NULL,created INTEGER NOT NULL,last_seen INTEGER NOT NULL,expires INTEGER NOT NULL,revoked INTEGER NOT NULL DEFAULT 0,reason TEXT NOT NULL DEFAULT '');
    CREATE INDEX IF NOT EXISTS session_expiry ON sessions(expires);
    CREATE TABLE IF NOT EXISTS bans(id TEXT PRIMARY KEY,kind TEXT NOT NULL CHECK(kind IN ('key','hwid','user')),value TEXT NOT NULL,reason TEXT NOT NULL,created INTEGER NOT NULL,UNIQUE(kind,value));
    CREATE TABLE IF NOT EXISTS nonces(key_hash TEXT NOT NULL,nonce TEXT NOT NULL,expires INTEGER NOT NULL,PRIMARY KEY(key_hash,nonce));
    CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,time INTEGER NOT NULL,actor TEXT NOT NULL,event TEXT NOT NULL,detail TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS challenges(hash TEXT PRIMARY KEY,expires INTEGER NOT NULL,attempts INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS admin_sessions(hash TEXT PRIMARY KEY,csrf TEXT NOT NULL,created INTEGER NOT NULL,last_seen INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS auth_state(id INTEGER PRIMARY KEY CHECK(id=1),last_totp INTEGER NOT NULL DEFAULT -1);
    INSERT OR IGNORE INTO auth_state(id) VALUES(1);
    CREATE TABLE IF NOT EXISTS config_state(id INTEGER PRIMARY KEY CHECK(id=1),auth_hash TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS rate_limits(bucket TEXT PRIMARY KEY,start INTEGER NOT NULL,count INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS price_runs(id INTEGER PRIMARY KEY,started INTEGER NOT NULL,finished INTEGER,ok INTEGER,trigger TEXT NOT NULL,priced INTEGER,error TEXT NOT NULL DEFAULT '');
    PRAGMA user_version=1;`);
  // Исходный HWID экзекутора для панели (блокировки по-прежнему по HMAC). Новая колонка
  // со значением по умолчанию совместима с прежним релизом — откат не ломается.
  if(!db.prepare('PRAGMA table_info(sessions)').all().some(c=>c.name==='hwid'))db.exec("ALTER TABLE sessions ADD COLUMN hwid TEXT NOT NULL DEFAULT ''");
  return {
    db,
    get(sql,...args) {return db.prepare(sql).get(...args);},
    all(sql,...args) {return db.prepare(sql).all(...args);},
    run(sql,...args) {return db.prepare(sql).run(...args);},
    transaction(fn) {db.exec('BEGIN IMMEDIATE'); try {const r=fn();db.exec('COMMIT');return r;} catch(e) {db.exec('ROLLBACK');throw e;}},
    close() {db.close();},
  };
}
