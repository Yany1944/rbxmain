# Relay Admin — макет панели

Кликабельный макет без бэкенда: чистый HTML/CSS/JS, без сборки и зависимостей.

```
admin-panel/
├── index.html          вход: логин + пароль → код 2FA (TOTP)
├── dashboard.html      дашборд
└── assets/
    ├── style.css       тема (токены цветов в :root)
    ├── common.js       иконки, тосты, подсветка карточек
    ├── login.js        логика формы входа (имитация)
    └── dashboard.js    графики, счётчики, лента (фейковые данные)
```

Открыть можно прямо файлом в браузере или так: `python3 -m http.server -d admin-panel 8080`.

**Как работает имитация:** любой логин и пароль от 4 символов проходят, после этого любой
6-значный код, кроме `000000`, открывает дашборд. Короткий пароль и `000000` показывают
состояния ошибок. Все места, где нужен настоящий запрос, помечены `TODO(backend)`.

## Безопасный вход только для тебя

Главная идея — несколько независимых слоёв. Если один слой взломают, остальные всё равно держат.

### Слой 1 — панель не видна из интернета (самое важное)

Панель слушает только `127.0.0.1`, наружу её открывает либо SSH-туннель, либо VPN.
Тогда для всего остального мира порта просто нет.

**SSH-туннель** — проще всего, ничего не нужно ставить:

```bash
# на своём ПК; панель на сервере слушает 127.0.0.1:8080
ssh -N -L 8080:127.0.0.1:8080 user@SERVER_IP
# открыть http://localhost:8080
```

**WireGuard / Tailscale** — если нужен доступ с телефона: панель слушает только на
VPN-интерфейсе (например, `10.8.0.1`), в интернет она не торчит.

Relay-сервер для игроков при этом остаётся публичным — закрывается только админка.

### Слой 2 — авторизация в самой панели

Даже за туннелем панель должна требовать вход:

- **Один пользователь, без регистрации.** Логин и хеш пароля лежат в конфиге или env,
  эндпоинта регистрации нет совсем.
- **Пароль хранится только как хеш Argon2id** (или bcrypt, cost ≥ 12), сам пароль — длинный, из менеджера паролей.
- **Обязательный TOTP 2FA** (Google Authenticator, Aegis). Секрет генерируется один раз,
  хранится на сервере. Принимать код из окна ±1 шаг и запоминать последний принятый, чтобы
  нельзя было использовать его повторно.
- **Сессия — cookie** `HttpOnly; Secure; SameSite=Strict; Path=/`, случайный ID ≥ 128 бит,
  данные сессии хранятся на сервере. Не используй localStorage и JWT в JS.
- **Тайм-ауты:** 15 минут без активности и не больше 12 часов всего. После выхода сессия удаляется на сервере.
- **Ограничение попыток:** 5 неудач — блокировка на 15 минут (по IP и по логину). Плюс fail2ban на логи панели.
- **Одинаковый ответ** «Неверный логин или пароль», что бы ни было неправильно; сравнение — constant-time.
- **CSRF:** при `SameSite=Strict` и JSON-запросах обычно достаточно проверять `Origin`, для надёжности добавь CSRF-токен.

### Слой 3 — сервер и HTTP

- HTTPS (Let's Encrypt через Caddy или nginx), если панель доступна не только через SSH-туннель.
- Заголовки: `Content-Security-Policy: default-src 'self'`, `X-Frame-Options: DENY`,
  `Referrer-Policy: no-referrer`, `Strict-Transport-Security`.
- SSH: вход только по ключу (`PasswordAuthentication no`, `PermitRootLogin no`), фаервол `ufw`
  открывает только 22 и порт relay.
- Логировать каждый вход и каждую неудачную попытку (в будущем — вывести в разделе «Логи»).

### Минимальная схема API под этот макет

| Метод | Путь | Что делает |
|---|---|---|
| POST | `/api/auth/login` | `{username, password}` → `{mfa_required: true, challenge}` (challenge живёт 5 минут) |
| POST | `/api/auth/mfa` | `{challenge, code}` → `Set-Cookie: session=…` |
| POST | `/api/auth/logout` | удалить сессию |
| GET | `/api/stats?range=1h\|24h\|7d` | KPI, спарклайны и ряды для графика (см. `makeStats` в `dashboard.js`) |
| GET | `/api/server` | CPU / RAM / диск / сеть, load average |
| GET | `/api/peers?limit=6` | последние пиры |
| WS | `/api/events` | поток событий для ленты |

Все `/api/*`, кроме `login` и `mfa`, без валидной сессии отвечают `401`, и фронт на это
перекидывает на `index.html`.

## Деплой: push в `main` → панель обновляется сама

Сервер раз в 30 секунд забирает ветку `main` с GitHub, а Caddy раздаёт `/opt/rbxmain/admin-panel`.
Секретов и ключей от сервера в GitHub нет: сервер сам скачивает обновления, а не GitHub заходит на сервер.
Код из репозитория на сервере не выполняется, там только `git fetch` и `git reset`.

Установка на сервере (один раз):

```bash
cat > /etc/systemd/system/relay-admin-pull.service <<'UNIT'
[Unit]
Description=Pull Relay Admin panel from GitHub
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/opt/rbxmain
ExecStart=/usr/bin/git fetch --depth 1 --quiet origin main
ExecStart=/usr/bin/git reset --hard --quiet FETCH_HEAD
UNIT

cat > /etc/systemd/system/relay-admin-pull.timer <<'UNIT'
[Unit]
Description=Pull Relay Admin panel every 30 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now relay-admin-pull.timer
```

В блок панели в `/etc/caddy/Caddyfile` стоит добавить `header Cache-Control no-cache`, иначе браузер
может показывать старые CSS/JS до Ctrl+F5.

Проверка: `systemctl list-timers relay-admin-pull.timer` и `journalctl -u relay-admin-pull -n 20`.
