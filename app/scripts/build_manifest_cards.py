#!/usr/bin/env python3
"""Regenerate assets/songs/manifest.json for the trot-card (greeting-card) model.

Manifest entry: {id, title, artist, youtubeId, cardCount, order, hash}
- hash: sha256 of the song file's raw bytes, first 16 hex chars. The app's
  SongRepository compares this to decide whether to re-download a changed/new
  song (OTA via GitHub raw). Must be regenerated after any song edit/add.
- cardCount: len(cards).
- order: integer recency rank. Existing songs keep their order; brand-new songs
  get max(order)+1, +2, ... in filename order so newer additions sort first.

Run after adding/editing song files, then commit + push (OTA, no rebuild).
"""
import glob
import hashlib
import json
import os

SONGS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "songs"))
MANIFEST = os.path.join(SONGS_DIR, "manifest.json")


def main() -> None:
    prev_order = {}
    max_order = 0
    if os.path.exists(MANIFEST):
        for s in json.load(open(MANIFEST)):
            prev_order[s["id"]] = s.get("order", 0)
            max_order = max(max_order, s.get("order", 0))

    entries = []
    next_order = max_order + 1
    for path in sorted(glob.glob(os.path.join(SONGS_DIR, "*.json"))):
        if os.path.basename(path) == "manifest.json":
            continue
        raw = open(path, "rb").read()
        song = json.loads(raw)
        sid = song["id"]
        if sid in prev_order:
            order = prev_order[sid]
        else:
            order = next_order
            next_order += 1
        entry = {
            "id": sid,
            "title": song.get("title", ""),
            "artist": song.get("artist", ""),
            "youtubeId": song.get("youtubeId", ""),
            "cardCount": len(song.get("cards", [])),
            "order": order,
            "hash": hashlib.sha256(raw).hexdigest()[:16],
        }
        # 프로그램 소속 곡만 program 키를 실어 프로그램별 그룹핑을 지원.
        # (정통 트로트 등 미지정 곡은 키 없음 → 기존 항목 그대로.)
        program = song.get("program", "")
        if program:
            entry["program"] = program
        entries.append(entry)

    entries.sort(key=lambda e: e["id"])
    with open(MANIFEST, "w") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"manifest: {len(entries)} songs (added order {max_order + 1}..{next_order - 1})")


if __name__ == "__main__":
    main()
