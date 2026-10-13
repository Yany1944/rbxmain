# Violite Control — реальный контур сессий

Node.js 24.14+ (ветка 24), без npm-зависимостей. SQLite в отдельном каталоге.
Relay не изменяется. API не исполняет произвольный Lua: только выдаёт/продлевает
сессии и сообщает клиенту об отзыве, блокировке или обслуживании.

## Запуск и проверка локально

Из корня проекта:

```powershell
node control-server/init.js .local/control admin-panel
$env:VIOLITE_CONFIG = (Resolve-Path .local/control/config.json).Path
node control-server/server.js
```

Открыть `http://127.0.0.1:8792`. Данные первого входа и TOTP enrollment URI находятся
в `.local/control/FIRST-LOGIN.txt`; перенести в менеджер паролей/Authenticator.
Удалить этот файл после сохранения. `config.json`, SQLite и резервные копии приватны.
Init не перезаписывает существующие файлы.

```powershell
cd control-server
node --test test/*.test.js
```

## Контракт Kernel

Публичный адрес: `https://193-39-143-31.sslip.io/control`.
POST `/session` и `/beat`: JSON, заголовок `X-Violite-Proxy` из `proxySecret`.
Тело: `{key,hwid,user,v,nonce,token?}`. `v` — числовой BUILD_VERSION, а не semver.
`nonce` — 32 hex-символа. В beat также передаётся user.

Только запрос из защищённого `JD_SECURE_REQUEST` должен обладать proxySecret;
Jnkie проверяет ключ и подставляет `JD_KEY` на своей стороне. Наш API **не является
самостоятельным валидатором ключей Jnkie**. Прямой клиентский HTTP с этим секретом
не соответствует выбранной модели. REST API-ключ Jnkie не требуется и не встроен.
До публикации необходимо проверить реальный защищённый запрос через Jnkie.

Ответ: `{payload:"<JSON>",sig:HMAC-SHA256(responseSecret,nonce+"|"+payload)}`.
Ключи/HWID сохраняются только как HMAC с отдельным identitySecret; токены — SHA-256.
User ID сообщает клиент: поле не доказывает личность Roblox. Роль owner назначается
только по `ownerKeyHashes` из серверного config, не по User ID.

Срок сессии 180 с, клиент продлевает её раз в 60–70 с. Повторный запуск того же
ключа/устройства отзывает прежний токен. Отзыв/бан/обслуживание срабатывает на
следующем запросе, а не мгновенно. При потере сервера действует TTL и существующее
правило Kernel для трёх неудачных heartbeat. Исполнение произвольных команд отсутствует.

Версии по умолчанию отсутствуют. Создание — только draft. Только published допускает
запуск. Неизвестный/draft Build ID → ошибка проверки версии и kick. blocked → отказ
и выгрузка без kick (дальнейшее поведение можно уточнить). На старте release Kernel
при невозможности получить проверенный ответ тоже делает kick с сообщением
«Ошибка проверки версии». Dev не используется для проверки релизной защиты.

## Панель

Вход: scrypt-пароль и TOTP (повтор кода отвергается). Cookie HttpOnly/SameSite Strict;
CSRF токен + проверка Origin для изменений. Ограничение попыток сохраняется в БД.
Панель доступна из интернета: https://panel.193-39-143-31.sslip.io (Caddy → 8792).
Origin этого хоста есть в `adminOrigins`; cookie получает Secure автоматически, если
Caddy передал `X-Forwarded-Proto: https`. Лимиты входа считаются по IP клиента
(последний элемент X-Forwarded-For, его ставит Caddy): перебор с чужого адреса не
блокирует вход владельца. Туннель на 8090 остаётся запасным входом (HTTP, без Secure).

Работают: релизы, сессии, отзыв, блокировки по ключу/HWID/User ID, обслуживание,
журнал и сводка. Ключи выдаются в Jnkie. Relay-метрики и удалённое редактирование
лоадера не подключены: панель явно сообщает об этом, демоданных нет.
Сессий в `/api/state` до 2000, остальные списки до 500, журнал — 200; сессии хранятся
30 дней, аудит 90 дней. `/api/state` содержит `api:2` — по нему панель включает новые функции.

Блокировки из панели — только HWID. `POST /api/bans`:
- `{kind:'hwid', ref, reason}` — `ref` это первые 12 символов HMAC устройства (`hwid_ref`
  в сессиях); полный хеш сервер берёт из таблицы sessions.
- `{kind:'hwid', user, reason}` — блокирует все HWID, на которых встречался Roblox User ID;
  ответ `{ok, count}`. 404 — аккаунта нет в сессиях, 409 — все его устройства уже в бане.
- Прежние `{kind, value, reason}` (user/key/hwid по сырому значению) ещё принимаются.

`GET /api/roblox?ids=1,2` (до 100 ID) — имена и аватары через users/thumbnails API
Roblox, кэш в памяти 6 ч. CSP разрешает картинки только с `https://*.rbxcdn.com`.

## Развёртывание без вмешательства в Relay

- `/opt/violite-control/node` — отдельный Node 24, системный Node 18 не заменяется.
- `/opt/violite-control/releases/<id>` — проверенная копия control-server и admin-panel.
- `/opt/violite-control/current` — ссылка на активный релиз.
- `/etc/violite-control/config.json` — секреты, владелец `root:violite`, режим 0640.
- `/var/lib/violite-control/control.sqlite` — база, владелец `violite`, каталог 0700.
- systemd `violite-control.service`: непривилегированный пользователь, loopback
  8791 (только client API), 8792 (панель + admin API).
- Caddy публично проксирует исключительно `/control/session` и `/control/beat`.
  Остальные пути прежнего публичного сайта продолжают идти в Relay:8787.
- Панель: отдельный хост `panel.193-39-143-31.sslip.io` → 8792 и запасной туннель
  на 8090. Не добавлять 8792 или `/api/*` в публичный блок relay-хоста.

`deploy/Caddy.snippet` — фрагменты для существующего конфига, не полный replacement.
Перед reload: backup Caddyfile, `caddy validate`. После reload проверить Relay,
недоступность публичного admin API, вход через туннель и журнал сервиса.

Панель отдаётся из самого релиза: `panelDirectory` = `/opt/violite-control/current/admin-panel`,
`panelFallbackDirectory` не используется. Публичный Git-каталог `/opt/rbxmain` для панели
больше не читается — UI и backend всегда одной версии. Без входа доступны только
страница входа и общие стили/скрипты; `dashboard.html` перенаправляет на вход,
`assets/live.js` отвечает 401.

Секреты нельзя хранить в `/opt/rbxmain`: его содержимое заменяет git reset.
В build/secrets.json для сборки нужны `controlUrl`, соответствующие proxySecret и
responseSecret, а также **ссылка запуска основного защищённого скрипта** `loaderUrl`.
Не публиковать dev bundle. Original Code обрабатывается Jnkie; обфусцированный UI
подключается отдельно, как описано в build/KEY-LOADER.md.

## Обновление и откат

С компьютера владельца, из корня проекта (нужен SSH-ключ `skin_relay`):

```powershell
powershell -ExecutionPolicy Bypass -File control-server\deploy\deploy.ps1
```

Скрипт упаковывает `admin-panel` и `control-server` (без config, базы и .md), отправляет
по SSH и запускает `deploy/release.sh` на сервере. Тот:
1. распаковывает в `releases/<UTC-время>`, гоняет тесты на Node 24 — при ошибке ничего не меняется;
2. делает backup SQLite и `config.json.bak-<id>`;
3. переключает `current`, перезапускает только violite-control;
4. проверяет `/` = 200, `/dashboard.html` = 302, `/api/state` = 401, иначе сам откатывает
   ссылку и конфиг. Хранит 5 последних релизов. Команда ручного отката печатается в конце.

При несовместимой миграции БД восстановить backup при остановленном сервисе.
Текущая схема версии 1; более новую схему этот сервер открывать отказывается.
Ручной backup:

```sh
sudo -u violite env VIOLITE_CONFIG=/etc/violite-control/config.json \
  /opt/violite-control/node/bin/node /opt/violite-control/current/control-server/backup.js \
  /var/lib/violite-control/backup-UNIQUE.sqlite
```

Смена username/passwordHash/totpSecret после перезапуска отзывает прежние входы.
Не менять identitySecret без миграции: от него зависят ключи сессий и блокировки.
Не выводить config, ключи, cookies или TOTP в общий журнал.

## Состояние развёртывания — 8 октября 2026

На 193.39.143.31 установлен релиз 20261008-01 с отдельным Node 24.19.0.
Control, Caddy, Relay и существующий таймер обновления активны.
Права каталога базы — 0700. Приватный API без входа возвращает 401;
публичный /control/api/state — 404. Relay проверен: 8 smoke-проверок прошли,
его процесс не перезапускался. 7 интеграционных тестов Control прошли локально
и на Linux. В изолированной локальной панели проверены TOTP-вход и черновик.

Проверка первого входа в production остаётся ручной: автоматическая проверка
отклонила команду открытия фонового SSH-туннеля вместе с автоматическим входом;
подробная причина не предоставлена. Это не подтверждение боевого входа.

Публичных релизов и тестовых клиентских сессий в production не создавали.
Следующий обязательный этап: защищённая сборка Jnkie, её фактический loader URL,
проверка JD_SECURE_REQUEST и отмены UI Source, затем регистрация точного Build ID
и один контролируемый запуск клиента. До этого связка Jnkie → Control не считается
проверенной и не должна выдаваться пользователям как завершённый релиз.

Первый вход: SSH-туннель на 8090 (см. ../admin-panel/README.md), затем
http://127.0.0.1:8090. Локальные учётные данные:
.local/control-production/FIRST-LOGIN.txt. В репозиторий они не включены.
Резервный Caddyfile: /etc/caddy/Caddyfile.before-violite-control-20261008.

## Состояние развёртывания — 8 октября 2026, вечер

Релиз 20261008-02: лимиты входа по IP, Secure-cookie по HTTPS, публичный хост
панели в Caddy, новая версия интерфейса панели (из admin-panel). 8 тестов прошли
локально и на сервере. Бэкапы до переключения: `/etc/violite-control/config.json.bak-20261008-200339`,
`/etc/caddy/Caddyfile.bak-20261008-200339`, `/var/lib/violite-control/backup-20261008-200339.sqlite`.
Откат: `ln -sfn /opt/violite-control/releases/20261008-01 /opt/violite-control/current`,
вернуть оба .bak, `systemctl restart violite-control && systemctl reload caddy`.

## Цены для апгрейдера (с 9 октября 2026)

- `prices/update_prices.py` — парсер supremevalues.com (перенос sv_scrape + sv_resolve из
  Obsid): 10 категорий оружия параллельно, ~2 с. Сначала напрямую (curl_cffi с отпечатком
  Chrome проходит Cloudflare), при блоке — через `pricesProxy`. Блок/усадка (< 70 % точных
  цен от прошлого) — ошибка запуска, старый `prices.json` не трогается.
- `prices/catalog.json` — дамп инвентаря MMV (850 ножей/пистолетов, ID как в MM2): все ID
  попадают в выдачу, `v` — только точная цена, иначе `null` («x4 T1 …» не считаем).
  Новые скины игры: снова дампнуть каталог в MMV и положить сюда.
- `prices.js` — слоты каждые 4 ч от 00:00 МСК (21:00 UTC), ручной запуск расписание не
  сдвигает; история в таблице `price_runs`.
- Публично: `GET /control/prices` (лимит 30/мин на IP, ETag, кэш 5 мин). Панель → «Цены».
- Конфиг: `pricesDir` (/var/lib/violite-control/prices), `pricesPython`
  (/opt/violite-control/prices-venv/bin/python), `pricesProxy` (секрет). Релиз 20261009-01.

