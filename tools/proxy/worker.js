// Agro AI — посредник для онлайн-анализа без ключа у пользователя.
//
// Телефон → этот сервер (ключ Gemini хранится только здесь, в секрете GEMINI_KEY) → Gemini.
// Приложение присылает вместо ключа случайный ID устройства; сервер подставляет
// настоящий ключ и ограничивает число анализов в день на одно устройство.

const GEMINI = 'https://generativelanguage.googleapis.com';
const DEFAULT_DAILY_LIMIT = 20;

function err(status, code, message) {
  return new Response(JSON.stringify({ error: { code: status, status: code, message } }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// Счётчик анализов за сутки для устройства. Cache API — бесплатно и без базы данных;
// счёт ведётся в каждом дата-центре отдельно, для защиты от злоупотреблений этого хватает.
async function bump(device, limit) {
  const day = new Date().toISOString().slice(0, 10);
  const key = new Request(`https://count.agro-ai/${day}/${encodeURIComponent(device)}`);
  const cache = caches.default;
  const hit = await cache.match(key);
  const used = hit ? parseInt(await hit.text(), 10) || 0 : 0;
  if (used >= limit) return false;
  await cache.put(
    key,
    new Response(String(used + 1), { headers: { 'cache-control': 'max-age=90000' } }),
  );
  return true;
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response('Agro AI proxy: ok', { headers: { 'content-type': 'text/plain' } });
    }
    // Пропускаем только список моделей и generateContent — больше ничего.
    const listing = req.method === 'GET' && url.pathname === '/v1beta/models';
    const generate =
      req.method === 'POST' && /^\/v1beta\/models\/[\w.\-]+:generateContent$/.test(url.pathname);
    if (!listing && !generate) return err(404, 'NOT_FOUND', 'Not found');

    if (!env.GEMINI_KEY) return err(500, 'INTERNAL', 'Server key is not configured');

    const device =
      req.headers.get('x-goog-api-key') ||
      (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    if (!device || device.length < 8 || device.length > 64) {
      return err(401, 'UNAUTHENTICATED', 'API key not valid. Device id is missing.');
    }

    if (generate) {
      const limit = parseInt(env.DAILY_LIMIT || '', 10) || DEFAULT_DAILY_LIMIT;
      if (!(await bump(device, limit))) {
        return err(429, 'RESOURCE_EXHAUSTED', `Daily limit of ${limit} analyses reached`);
      }
    }

    const target = new URL(GEMINI + url.pathname);
    if (listing) target.searchParams.set('pageSize', url.searchParams.get('pageSize') || '1000');
    const res = await fetch(target, {
      method: req.method,
      headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_KEY },
      body: generate ? await req.arrayBuffer() : undefined,
    });
    return new Response(res.body, {
      status: res.status,
      headers: { 'content-type': 'application/json' },
    });
  },
};
