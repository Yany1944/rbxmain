#!/bin/sh
# Выпуск Control на сервере: распаковка в releases/<id>, тесты на Node 24, backup базы,
# переключение current и перезапуск. При любой ошибке после переключения — откат.
# Запускается deploy.ps1 от root: sh release.sh /tmp/violite-release.tgz
set -eu
# Любая неожиданная остановка печатает строку с кодом, а не обрывается молча
trap 'rc=$?; [ "$rc" -eq 0 ] || echo "!! release.sh stopped (exit $rc)"' EXIT

ARCHIVE=$1
BASE=/opt/violite-control
NODE=$BASE/node/bin/node
CONFIG=/etc/violite-control/config.json
ID=$(date -u +%Y%m%d-%H%M%S)
DIR=$BASE/releases/$ID
PREV=$(readlink -f "$BASE/current")

echo "== Release $ID (previous: $(basename "$PREV"))"
mkdir -p "$DIR"
tar -xzf "$ARCHIVE" -C "$DIR"
rm -f "$ARCHIVE"
chown -R root:root "$DIR"
chmod -R u=rwX,go=rX "$DIR"

echo "== Tests"
if ! (cd "$DIR/control-server" && "$NODE" --test --test-reporter=tap test/*.test.js >/tmp/violite-test.log 2>&1); then
  tail -n 40 /tmp/violite-test.log
  rm -rf "$DIR"
  echo "!! Tests failed, nothing changed"
  exit 1
fi
grep -E "^# (pass|fail)" /tmp/violite-test.log || true

echo "== Database backup"
runuser -u violite -- env VIOLITE_CONFIG=$CONFIG "$NODE" "$DIR/control-server/backup.js" "/var/lib/violite-control/backup-$ID.sqlite"

# Панель отдаётся из самого релиза: сервер больше не читает UI из публичного Git-каталога
cp -p "$CONFIG" "$CONFIG.bak-$ID"
"$NODE" -e '
const fs=require("fs"),path=process.argv[1],c=JSON.parse(fs.readFileSync(path,"utf8"));
c.panelDirectory="/opt/violite-control/current/admin-panel";delete c.panelFallbackDirectory;
fs.writeFileSync(path,JSON.stringify(c,null,2)+"\n");' "$CONFIG"

rollback() {
  echo "!! $1, rolling back to $(basename "$PREV")"
  ln -sfn "$PREV" "$BASE/current"
  cp -p "$CONFIG.bak-$ID" "$CONFIG"
  systemctl restart violite-control
  exit 1
}

echo "== Switch and restart"
ln -sfn "$DIR" "$BASE/current"
systemctl restart violite-control || rollback "Restart failed"
sleep 2
systemctl is-active --quiet violite-control || rollback "Service is not running"

# Страница входа открыта, панель и API — только после входа
"$NODE" -e '
const get=p=>fetch("http://127.0.0.1:8792"+p,{redirect:"manual"}).then(r=>r.status);
Promise.all([get("/"),get("/dashboard.html"),get("/api/state")]).then(s=>{
  console.log("   / "+s[0]+", /dashboard.html "+s[1]+", /api/state "+s[2]);
  process.exit(s[0]===200&&s[1]===302&&s[2]===401?0:1);
},()=>process.exit(1));' || rollback "Health check failed"

# Хранить пять последних релизов, текущий и предыдущий не трогать
ls -1d "$BASE"/releases/* | sort | head -n -5 | while read -r old; do
  [ "$old" = "$DIR" ] || [ "$old" = "$PREV" ] || rm -rf "$old"
done

echo "== Done: $ID is live. Rollback: ln -sfn $PREV $BASE/current && cp -p $CONFIG.bak-$ID $CONFIG && systemctl restart violite-control"
