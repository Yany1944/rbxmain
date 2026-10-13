// Секреты и коды никогда не пишутся в журнал.
import {createHash, createHmac, randomBytes, scrypt, timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
const derive = promisify(scrypt);
export const randomToken = () => randomBytes(32).toString('hex');
export const digest = value => createHash('sha256').update(value).digest('hex');
export const hmac = (secret, value) => createHmac('sha256', secret).update(value).digest('hex');
export function equal(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}
export async function passwordHash(password, salt = randomBytes(16).toString('hex')) {
  const value = await derive(password, salt, 64, {N:32768, r:8, p:1, maxmem:64*1024*1024});
  return `${salt}:${value.toString('hex')}`;
}
export async function passwordMatches(password, stored) {
  return equal(await passwordHash(password, stored.split(':')[0]), stored);
}
export function base32(bytes) {
  let bits = '', out = '';
  for (const byte of bytes) bits += byte.toString(2).padStart(8, '0');
  for (let i=0;i<bits.length;i+=5) out += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'[parseInt(bits.slice(i,i+5).padEnd(5,'0'),2)];
  return out;
}
function decode32(value) {
  let bits = '';
  for (const c of value.toUpperCase().replace(/=+$/, '')) {
    const i = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.indexOf(c);
    if (i < 0) throw new Error('Invalid TOTP secret');
    bits += i.toString(2).padStart(5, '0');
  }
  return Buffer.from(bits.match(/.{8}/g).map(v=>parseInt(v,2)));
}
export function totp(secret, step) {
  const counter = Buffer.alloc(8); counter.writeBigUInt64BE(BigInt(step));
  const mac = createHmac('sha1', decode32(secret)).update(counter).digest();
  return String((mac.readUInt32BE(mac[19]&15)&0x7fffffff)%1000000).padStart(6,'0');
}
export function totpStep(secret, code, now, last) {
  if (!/^\d{6}$/.test(code)) return null;
  const step = Math.floor(now/30);
  for (const candidate of [step, step-1, step+1]) {
    if (candidate > last && equal(totp(secret,candidate),code)) return candidate;
  }
  return null;
}
