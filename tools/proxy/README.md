# Сервер-посредник для онлайн-версии (Cloudflare Workers, бесплатно)

Зачем: чтобы онлайн-анализ работал у всех, кто скачал приложение, без ввода ключа.
Ключ Gemini хранится только на сервере (секрет `GEMINI_KEY`), в приложении и в репозитории его нет.
Каждый телефон может сделать `DAILY_LIMIT` анализов в день (по умолчанию 20).
Если пользователь ввёл свой ключ в настройках — приложение ходит в Gemini напрямую, мимо сервера.

## Установка (один раз)

1. Зарегистрируйтесь на https://dash.cloudflare.com/sign-up (бесплатно).
2. Создайте **новый** ключ Gemini на https://aistudio.google.com/apikey.
3. В терминале, в папке `tools/proxy`:

```bash
npx wrangler login
npx wrangler secret put GEMINI_KEY
npx wrangler deploy
```

На втором шаге wrangler попросит вставить ключ — вставьте и нажмите Enter (ключ не показывается на экране).
После `deploy` будет адрес вида `https://agro-ai-proxy.<ваше-имя>.workers.dev`.

4. Сообщите адрес сборкам приложения (переменная репозитория, не секрет):

```bash
gh variable set AGRO_PROXY_URL --body "https://agro-ai-proxy.<ваше-имя>.workers.dev"
```

5. Запустите сборки заново (push или Actions → build / ios → Run workflow).

Проверка: откройте адрес в браузере — должно быть `Agro AI proxy: ok`.
