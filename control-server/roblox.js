// Профили Roblox для панели: имя и аватар по User ID. Данные публичные, но браузер
// не может спросить Roblox напрямую (CORS), поэтому запрос идёт через сервер.
// Кэш в памяти: панель обновляется каждые 10 с и не должна каждый раз ходить в Roblox.
const TTL = 6 * 3600 * 1000;
const FAIL_TTL = 2 * 60 * 1000;
const MAX_CACHE = 5000;
const CHUNK = 100;
const AVATAR = /^https:\/\/[a-z0-9.-]+\.rbxcdn\.com\/[\w\-./%]+$/i;

export function createRoblox(options = {}) {
  const fetcher = options.fetch || globalThis.fetch;
  const clock = options.now || Date.now;
  const cache = new Map();

  async function json(url, init) {
    const response = await fetcher(url, {...init, signal: AbortSignal.timeout(6000)});
    if (!response.ok) throw new Error('Roblox ' + response.status);
    return response.json();
  }

  async function fetchChunk(ids) {
    const [users, thumbs] = await Promise.allSettled([
      json('https://users.roblox.com/v1/users', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({userIds: ids.map(Number), excludeBannedUsers: false})}),
      json(`https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${ids.join(',')}&size=150x150&format=Png&isCircular=false`),
    ]);
    if (users.status === 'rejected' && thumbs.status === 'rejected') throw users.reason;
    const names = new Map((users.value?.data || []).map(u => [String(u.id), u]));
    const images = new Map((thumbs.value?.data || []).map(t => [String(t.targetId), t]));
    const at = clock();
    for (const id of ids) {
      const user = names.get(id), image = images.get(id);
      const avatar = image?.state === 'Completed' && AVATAR.test(image.imageUrl || '') ? image.imageUrl : null;
      // Без ответа users-API имя неизвестно: такую запись перепроверяем раньше
      // Аватар ещё рендерится (Pending) — тоже перепроверяем скоро, а не через 6 ч
      const partial = users.status === 'rejected' || thumbs.status === 'rejected' || !avatar;
      cache.set(id, {at, ttl: partial ? FAIL_TTL : TTL, value: {name: user?.name || null, displayName: user?.displayName || null, avatar}});
    }
  }

  async function lookup(ids) {
    const unique = [...new Set(ids)].filter(id => /^\d{1,20}$/.test(id)).slice(0, CHUNK);
    const now = clock();
    const missing = unique.filter(id => {const hit = cache.get(id); return !hit || hit.at + hit.ttl <= now;});
    if (missing.length) {
      try { await fetchChunk(missing); }
      catch {
        // Устаревшее значение лучше пустого; повтор — не раньше FAIL_TTL
        for (const id of missing) cache.set(id, {at: now, ttl: FAIL_TTL, value: cache.get(id)?.value || null});
      }
      // Старые записи вытесняются в порядке добавления
      while (cache.size > MAX_CACHE) cache.delete(cache.keys().next().value);
    }
    return Object.fromEntries(unique.map(id => [id, cache.get(id)?.value || null]));
  }

  return {lookup};
}
