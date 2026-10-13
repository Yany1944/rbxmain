#!/usr/bin/env python3
"""
update_prices.py — цены MM2 с supremevalues.com для апгрейдера Violite.

Один проход: скачать 14 категорий → разобрать → сопоставить с внутренними ID
игры (catalog.json — дамп инвентаря MMV) → записать prices.json атомарно.
Перенос старых sv_scrape.py + sv_resolve.py (Obsid/Skinchanger/07 Tools):
логика разбора и сопоставления та же, но:
  * без дискового кэша HTML и промежуточного sv_raw.json;
  * категории качаются параллельно (по сессии на поток, каждая прогрета);
  * сначала напрямую (Cloudflare режет обычный curl по TLS-отпечатку, имитация
    Chrome проходит), при блоке — повтор через прокси VIOLITE_PRICES_PROXY;
  * заблокированная страница = ошибка всего запуска, старый prices.json цел
    (раньше блок молча превращался в пустую категорию);
  * защита от усадки: если точных цен меньше доли --min-ratio от прошлого
    файла — не публикуем.

Выход: {"meta": {...}, "items": {"<ID>": {"v": число|null, "c": категория, "n": имя}}}
  v — только точная цена с сайта; «x4 T1 Legendaries» и неизвестные — null.
  o: 1 — у скина на сайте цена «в штуках» (overstock); без o и без v — priceless.
  В items есть все ID каталога: подорожавший скин получит цену без правок.

Последняя строка stdout — `RESULT {...}` (сводка для control-server).
Коды выхода: 0 — опубликовано, 2 — сайт не отдал данные, 3 — подозрительная
усадка, 4 — ошибка конфигурации.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

try:
    from curl_cffi import requests as cr
except ImportError:
    sys.exit("curl_cffi is required: pip install curl_cffi")
try:
    from bs4 import BeautifulSoup
except ImportError:
    sys.exit("beautifulsoup4 is required: pip install beautifulsoup4")

BASE = "https://supremevalues.com"
# Только категории оружия: pets/sets/evos/untradables апгрейдеру не нужны
CATEGORIES = [
    "godlies", "chromas", "ancients", "vintages", "uniques",
    "legendaries", "rares", "uncommons", "commons", "misc",
]
HERE = Path(__file__).resolve().parent
IMPERSONATE = "chrome"
WORKERS = 3
TIMEOUT = 25
RETRIES = 2
MIN_PAGE = 3000

CATEGORY_RARITY = {
    "godlies": "Godly", "chromas": "Godly", "ancients": "Ancient",
    "legendaries": "Legendary", "rares": "Rare", "uncommons": "Uncommon",
    "commons": "Common", "uniques": "Unique", "misc": "Misc", "vintages": None,
}
SKIP_NAMES = {"Default Knife", "Default Gun", "TestItem", "DefaultKnife", "DefaultGun"}


class Blocked(Exception):
    pass


# ------------------------------------------------------------------ загрузка

def proxy_url() -> str | None:
    raw = os.environ.get("VIOLITE_PRICES_PROXY", "").strip()
    if not raw:
        return None
    if "://" in raw:
        return raw
    parts = raw.split(":")
    if len(parts) == 4:                      # host:port:user:pass (формат продавцов)
        host, port, user, password = parts
        return f"http://{user}:{password}@{host}:{port}"
    if len(parts) == 2:
        return f"http://{raw}"
    sys.exit(4)


def looks_valid(html: str) -> bool:
    return len(html) >= MIN_PAGE and ("_svPopup" in html or "itemcell" in html)


def new_session(proxy: str | None):
    s = cr.Session(impersonate=IMPERSONATE)
    if proxy:
        s.proxies = {"http": proxy, "https": proxy}
    s.get(f"{BASE}/mm2/", timeout=TIMEOUT)      # прогрев: куки защиты
    return s


def fetch_category(cat: str, proxy: str | None) -> str:
    last = ""
    for attempt in range(RETRIES + 1):
        try:
            s = new_session(proxy)
            r = s.get(f"{BASE}/mm2/{cat}", timeout=TIMEOUT)
            if r.status_code == 200 and looks_valid(r.text):
                return r.text
            last = f"HTTP {r.status_code}, {len(r.text)} bytes"
        except Exception as e:                   # сеть/прокси
            last = type(e).__name__
        time.sleep(1.5 * (attempt + 1))
    raise Blocked(f"{cat}: {last}")


def fetch_all(proxy: str | None) -> dict[str, str]:
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {cat: pool.submit(fetch_category, cat, proxy) for cat in CATEGORIES}
        return {cat: f.result() for cat, f in futures.items()}


# ------------------------------------------------------------------ разбор

def extract_sv_popup(html: str) -> dict:
    """Объект `var _svPopup = {...}` — разбор со счётом скобок (регулярка рвётся)."""
    m = re.search(r"var\s+_svPopup\s*=\s*\{", html)
    if not m:
        return {}
    start, depth, in_str, quote, esc = m.end() - 1, 0, False, "", False
    for i in range(start, len(html)):
        ch = html[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                in_str = False
            continue
        if ch in ('"', "'"):
            in_str, quote = True, ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(html[start:i + 1])
                except json.JSONDecodeError:
                    return {}
    return {}


CELL_LABELS = ("Value", "Range", "Stability", "Demand", "Rarity", "Origin",
               "Class", "Description", "Death Effect", "Owner", "EXP Requirement")
CELL_RE = {
    label: re.compile(
        rf"(?:^|\s){re.escape(label)} - (.*?)"
        rf"(?=\s(?:{'|'.join(re.escape(x) for x in CELL_LABELS)}) - |$)")
    for label in ("Value", "Origin")
}


def extract_cells(html: str) -> dict[str, dict]:
    """HTML-карточки .itemcell: в _svPopup есть не все позиции."""
    soup = BeautifulSoup(html, "html.parser")
    out: dict[str, dict] = {}
    for cell in soup.select("div.itemcell"):
        head, body = cell.select_one(".itemhead"), cell.select_one(".itembody")
        if not head or not body:
            continue
        name = head.get_text(" ", strip=True)
        txt = re.sub(r"\s+", " ", body.get_text(" ", strip=True))
        rec = {}
        for label, rx in CELL_RE.items():
            m = rx.search(txt)
            if m:
                rec[label.lower()] = m.group(1).strip()
        if name and rec:
            out[name] = rec
    return out


def canon_name(name: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"^C\.\s+", "Chroma ", name.strip())).lower()


def num(text) -> float | None:
    if text is None:
        return None
    if isinstance(text, (int, float)):
        return float(text)
    t = str(text).strip().replace(",", "").replace("+", "")
    try:
        return float(t)
    except ValueError:
        return None


ORIGIN_RE = re.compile(r"^\s*(?P<event>.*?)\s*(?P<year>\d{4})?\s*(?:\((?P<how>[^)]*)\))?\s*$")


def parse_origin(text) -> dict:
    raw = (text or "").strip()
    m = ORIGIN_RE.match(raw)
    if not m:
        return {"raw": raw, "event": None, "year": None}
    return {"raw": raw, "event": (m.group("event") or "").strip() or None, "year": m.group("year")}


TYPE_SUFFIX_RE = re.compile(r"^(?P<base>.+?)\s*\((?P<kind>Knife|Gun)\)\s*$", re.I)


def split_type(name: str) -> tuple[str, str | None]:
    m = TYPE_SUFFIX_RE.match(name.strip())
    return (m.group("base").strip(), m.group("kind").capitalize()) if m else (name.strip(), None)


SUB1_RE = re.compile(r"^x\s*(\d+)\s*T1\s*(Commons?|Uncommons?|Rares?|Legendary|Legendaries)\s*$", re.I)


def site_items(pages: dict[str, str]) -> list[dict]:
    items = []
    for cat, html in pages.items():
        merged: dict[str, dict] = {}
        seen: set[str] = set()
        for nm, rec in extract_sv_popup(html).items():
            merged[nm] = {"value": rec.get("value"), "raw": rec.get("rawValue"), "origin": rec.get("origin")}
            seen.add(canon_name(nm))
        for nm, rec in extract_cells(html).items():
            if canon_name(nm) not in seen:          # «C. X» — тот же предмет, что «Chroma X»
                merged[nm] = {"value": rec.get("value"), "raw": None, "origin": rec.get("origin")}
                seen.add(canon_name(nm))
        for nm, rec in merged.items():
            if nm.strip() in SKIP_NAMES:
                continue
            # Точная цена: rawValue блоба или число в карточке. «x4 T1 …» — не цена
            value = num(rec["raw"])
            if value is None:
                value = num(rec["value"])
            # «x4 T1 Legendaries» — цена в штуках скинов другой редкости (overstock)
            over = value is None and bool(SUB1_RE.match(str(rec["value"] or "").strip()))
            _, kind = split_type(nm)
            items.append({"name": nm.strip(), "category": cat, "value": value, "over": over,
                          "kind": kind, "origin": parse_origin(rec.get("origin"))})
    return items


# ------------------------------------------------------------- сопоставление
# (из sv_resolve.py: имя обязательно, остальное — баллы; близкие баллы = не берём)

def norm(s) -> str:
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", str(s)).replace("’", "'").replace("`", "'").lower()
    return re.sub(r"[^a-z0-9]+", "", s)


def norm_event(s) -> str:
    if not s:
        return ""
    s = re.sub(r"[^a-z]+", "", str(s).lower().replace("’", "'").replace("'", ""))
    for a, b in (("xmas", "christmas"), ("hw", "halloween")):
        s = s.replace(a, b)
    return s


CHROMA_RE = re.compile(r"^(?:chroma|c\.)\s+", re.I)
TAG_RE = re.compile(r"\s*\[([A-Za-z]+)(\d{4})\]\s*$")
YEAR_PAREN_RE = re.compile(r"\s*\((\d{4})\)\s*$")
TAG_EVENT = {"xmas": "Christmas", "hallows": "Halloween", "summer": "Summer",
             "easter": "Easter", "valentines": "Valentines", "thanksgiving": "Thanksgiving"}
ORIGIN_KIND_RE = re.compile(r"\b(knife|gun)\b", re.I)


def strip_chroma(name: str):
    m = CHROMA_RE.match(name.strip())
    return (name[m.end():].strip(), True) if m else (name.strip(), False)


def strip_suffix_hints(name: str):
    event = year = None
    m = TAG_RE.search(name)
    if m:
        event, year = TAG_EVENT.get(m.group(1).lower()), m.group(2)
        name = name[:m.start()].strip()
    m = YEAR_PAREN_RE.search(name)
    if m:
        year = year or m.group(1)
        name = name[:m.start()].strip()
    return name.strip(), event, year


def kind_from_origin(raw):
    found = {m.group(1).lower() for m in ORIGIN_KIND_RE.finditer(raw or "")}
    return found.pop().capitalize() if len(found) == 1 else None


def is_chroma_key(key: str, rec: dict) -> bool:
    return "chroma" in key.lower() or bool(rec.get("chroma"))


def score(item, key, rec, want_chroma, hint_event, hint_year, kind) -> int:
    s = 50 if want_chroma == is_chroma_key(key, rec) else -60
    if kind and rec.get("type"):
        s += 25 if kind == rec["type"] else -40
    site_event = hint_event or item["origin"].get("event")
    site_year = hint_year or item["origin"].get("year")
    if site_event and rec.get("event"):
        s += 20 if norm_event(site_event) == norm_event(rec["event"]) else -10
    if site_year:
        if rec.get("year"):
            s += 25 if str(site_year) == str(rec["year"]) else -20
        else:
            s -= 12
    want_rarity = CATEGORY_RARITY.get(item["category"])
    if want_rarity and rec.get("rarity"):
        s += 15 if rec["rarity"] == want_rarity else -12
    return s


def resolve(items: list[dict], catalog: dict[str, dict], overrides: dict) -> dict[str, dict]:
    index: dict[str, list] = defaultdict(list)
    for key, rec in catalog.items():
        if rec.get("name") and rec["name"] not in SKIP_NAMES:
            index[norm(rec["name"])].append((key, rec))

    def specificity(i):
        _, ev, yr = strip_suffix_hints(i["name"])
        return (1 if (ev or yr) else 0, 1 if i.get("kind") else 0,
                1 if i["origin"].get("year") else 0, 1 if i["value"] is not None else 0)

    out: dict[str, dict] = {}
    for item in sorted(items, key=specificity, reverse=True):
        name = item["name"]
        ov_key = f"{name}|{item['category']}"
        if ov_key in overrides or name in overrides:
            chosen = overrides.get(ov_key, overrides.get(name))
            if chosen is None or chosen not in catalog:
                continue
        else:
            clean, hint_event, hint_year = strip_suffix_hints(name)
            clean, kind = split_type(clean)
            kind = kind or item.get("kind") or kind_from_origin(item["origin"].get("raw"))
            base, want_chroma = strip_chroma(clean)
            cands = index.get(norm(base), [])
            if not cands:
                continue
            scored = sorted(((score(item, k, r, want_chroma, hint_event, hint_year, kind), k)
                             for k, r in cands), key=lambda t: -t[0])
            if len(scored) > 1 and scored[0][0] - scored[1][0] < 15:
                continue                       # неоднозначно: лучше дырка, чем чужая цена
            chosen = scored[0][1]
        if chosen in out:
            continue                           # ключ уже закрыт более точной записью
        out[chosen] = {"v": item["value"], "c": item["category"], "o": item["over"]}
    return out


# ------------------------------------------------------------------ main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="куда писать prices.json")
    ap.add_argument("--catalog", default=str(HERE / "catalog.json"))
    ap.add_argument("--overrides", default=str(HERE / "overrides.json"))
    ap.add_argument("--min-ratio", type=float, default=0.7)
    ap.add_argument("--proxy-only", action="store_true", help="сразу через прокси (проверка прокси)")
    args = ap.parse_args()

    started = time.monotonic()
    catalog_raw = json.loads(Path(args.catalog).read_text(encoding="utf-8"))
    catalog = {i["id"]: i for i in catalog_raw["items"]}
    overrides_path = Path(args.overrides)
    overrides = json.loads(overrides_path.read_text(encoding="utf-8")) if overrides_path.exists() else {}

    # Сначала напрямую (имитации браузера обычно хватает), при блоке — через
    # прокси: так трафик прокси тратится только когда он действительно нужен
    proxy = proxy_url()
    via = "proxy" if args.proxy_only else "direct"
    try:
        pages = fetch_all(proxy if args.proxy_only else None)
    except Blocked as e:
        if not proxy or args.proxy_only:
            print(f"RESULT {json.dumps({'ok': False, 'error': 'blocked: ' + str(e)})}")
            return 2
        try:
            pages, via = fetch_all(proxy), "proxy"
        except Blocked as e2:
            print(f"RESULT {json.dumps({'ok': False, 'error': 'blocked (proxy): ' + str(e2)})}")
            return 2

    matched = resolve(site_items(pages), catalog, overrides)
    items = {}
    for key, rec in catalog.items():
        m = matched.get(key)
        items[key] = {"v": m["v"] if m else None, "c": m["c"] if m else None, "n": rec.get("name")}
        if m and m["v"] is None and m["o"]:
            items[key]["o"] = 1                    # overstock: цена в штуках, не валюта
    for key, m in matched.items():                # сопоставлено, но нет в каталоге (редкие)
        if key not in items:
            items[key] = {"v": m["v"], "c": m["c"], "n": None}
    priced = sum(1 for v in items.values() if v["v"] is not None)

    out = Path(args.out)
    if out.exists():
        try:
            previous = json.loads(out.read_text(encoding="utf-8"))["meta"]["priced"]
        except Exception:
            previous = 0
        if previous and priced < previous * args.min_ratio:
            print(f"RESULT {json.dumps({'ok': False, 'error': f'shrink: {priced} < {previous}', 'priced': priced})}")
            return 3

    payload = {
        "meta": {
            "schema": 2,
            "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "source": BASE,
            "catalog": len(catalog),
            "priced": priced,
            "items": len(items),
            "via": via,
        },
        "items": items,
    }
    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    os.replace(tmp, out)
    print(f"RESULT {json.dumps({'ok': True, 'priced': priced, 'items': len(items), 'via': via, 'seconds': round(time.monotonic() - started, 1)})}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
