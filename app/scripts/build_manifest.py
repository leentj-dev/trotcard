#!/usr/bin/env python3
"""Regenerate assets/songs/manifest.json from the individual song JSON files.

Each manifest entry: id, title, artist, youtubeId, synced, wordCount, order, hash.

- hash: sha1 of the song's canonical content. ANY content change (words,
  translations, timestamps, introOffset, title, ...) produces a new hash, which
  is what the app's SongRepository._changed() compares to decide whether to
  re-download a song. This is the single source of truth for "did this song
  change" — so it must be regenerated whenever a song file is added or edited.
- order: "first added" unix time, preserved from the existing manifest so the
  feed's recency sort is stable; brand-new songs get the current time.
- synced: mirrors Song.isSynced (>= 10 words carry a timestamp).

Run after any song change. A git pre-commit hook runs it automatically.
"""
import glob
import hashlib
import json
import os
import time

SONGS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "songs"))
MANIFEST = os.path.join(SONGS_DIR, "manifest.json")


def content_hash(song: dict) -> str:
    canon = json.dumps(song, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha1(canon.encode("utf-8")).hexdigest()[:16]


def is_synced(words: list) -> bool:
    return sum(1 for w in words if isinstance(w, dict) and w.get("timestamp") is not None) >= 10


def main() -> None:
    prev_order = {}
    if os.path.exists(MANIFEST):
        for s in json.load(open(MANIFEST)):
            prev_order[s["id"]] = s.get("order", 0)

    now = int(time.time())
    entries = []
    for path in sorted(glob.glob(os.path.join(SONGS_DIR, "*.json"))):
        if os.path.basename(path) == "manifest.json":
            continue
        song = json.load(open(path))
        sid = song["id"]
        words = song.get("words", [])
        entries.append({
            "id": sid,
            "title": song.get("title", ""),
            "artist": song.get("artist", ""),
            "youtubeId": song.get("youtubeId", ""),
            "synced": is_synced(words),
            "wordCount": len(words),
            "order": prev_order.get(sid, now),
            "hash": content_hash(song),
        })

    entries.sort(key=lambda e: e["id"])
    with open(MANIFEST, "w") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
    print(f"manifest: {len(entries)} songs, {sum(1 for e in entries if e['synced'])} synced")


if __name__ == "__main__":
    main()
