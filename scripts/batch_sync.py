#!/usr/bin/env python3
"""Batch-attach timestamps to song JSONs that have none.

For each file: search lrclib by artist/title, pick the synced track whose
lyrics match the most of our words, and apply those timings. Lyrics are used
transiently — only per-word seconds are stored.

Usage: python3 scripts/batch_sync.py songs/a.json songs/b.json ...
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"


def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "kpop-hangul-sync/1.0"})
    with urllib.request.urlopen(req, timeout=20) as res:
        return json.load(res)


def parse_lrc(lrc: str):
    out = []
    for raw in lrc.splitlines():
        m = re.match(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)", raw)
        if m:
            t = int(m.group(1)) * 60 + float(m.group(2))
            text = m.group(3).strip()
            if text:
                out.append((t, text))
    return out


def clean_title(t: str) -> str:
    # drop parenthetical english / feat etc. for a looser search
    return re.sub(r"\(.*?\)", "", t).strip()


def match_count(words, lines):
    joined = "\n".join(text for _, text in lines)
    return sum(1 for w in words if w["korean"].rstrip("?!.") in joined)


def best_track(artist, title, words):
    candidates = []
    ct, ca = clean_title(title), clean_title(artist)
    queries = [
        f"{artist} {title}",
        f"{ca} {ct}",
        ct,  # Korean title alone — lrclib often matches on track name
    ]
    seen = set()
    for q in queries:
        try:
            results = fetch(f"{API}/search?q={urllib.parse.quote(q)}")
        except Exception:
            continue
        for r in results:
            if r["id"] in seen or not r.get("syncedLyrics"):
                continue
            seen.add(r["id"])
            lines = parse_lrc(r["syncedLyrics"])
            candidates.append((match_count(words, lines), r["id"], lines, r))
        time.sleep(0.4)
    if not candidates:
        return None
    candidates.sort(key=lambda c: c[0], reverse=True)
    return candidates[0]


def apply(path):
    song = json.load(open(path, encoding="utf-8"))
    words = song["words"]
    best = best_track(song["artist"], song["title"], words)
    if not best:
        print(f"❌ {path}: lrclib 검색 결과 없음")
        return "fail"
    count, tid, lines, meta = best
    joined_lines = lines
    matched = 0
    for w in words:
        key = w["korean"].rstrip("?!.")
        hit = next((t for t, text in joined_lines if key in text), None)
        if hit is not None:
            w["timestamp"] = round(hit, 1)
            matched += 1
        else:
            w["timestamp"] = None
    if matched < 10:
        print(f"⚠️  {path}: 매칭 {matched} (<10) — lrclib id {tid} best, 싱크 미달")
        # leave timestamps as-is (partial); consolidate will treat as unsynced
        json.dump(song, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        return "partial"
    song["words"].sort(key=lambda w: (w["timestamp"] is None, w["timestamp"] or 0))
    json.dump(song, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"✅ {path}: {matched}/{len(words)} (lrclib {tid}, {meta['artistName']} - {meta['trackName']})")
    return "ok"


def main():
    stats = {"ok": 0, "partial": 0, "fail": 0}
    for path in sys.argv[1:]:
        try:
            stats[apply(path)] += 1
        except Exception as e:
            print(f"❌ {path}: {e}")
            stats["fail"] += 1
        time.sleep(0.5)
    print(f"\n요약: 싱크성공 {stats['ok']}, 미달 {stats['partial']}, 실패 {stats['fail']}")


if __name__ == "__main__":
    main()
