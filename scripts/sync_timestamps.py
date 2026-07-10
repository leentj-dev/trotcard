#!/usr/bin/env python3
"""Attach word timestamps to a song JSON using lrclib.net synced lyrics.

Only songs available on lrclib get sync; we never guess timings.
Copyright note: lyrics are fetched transiently to extract per-word
timings (seconds) and are NOT stored — song JSONs keep words only.

Usage:
  # 1) find the right lrclib track id
  python3 scripts/sync_timestamps.py search "Lee Mujin Traffic light"

  # 2) apply its timings to a song file (optional MV intro offset in seconds)
  python3 scripts/sync_timestamps.py apply songs/leemujin-traffic-light.json 2121745 [--offset 10]

Then re-run scripts/consolidate_songs.py and push.
"""
import json
import re
import sys
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"


def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "kpop-hangul-sync/1.0"})
    with urllib.request.urlopen(req, timeout=15) as res:
        return json.load(res)


def search(query: str):
    results = fetch(f"{API}/search?q={urllib.parse.quote(query)}")
    for r in results[:10]:
        print(f"{r['id']:>10} | {r['artistName']} | {r['trackName']} | "
              f"synced: {bool(r.get('syncedLyrics'))} | dur: {r.get('duration')}s")


def parse_lrc(lrc: str):
    """[mm:ss.xx] line -> (seconds, text)"""
    lines = []
    for raw in lrc.splitlines():
        m = re.match(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)", raw)
        if m:
            t = int(m.group(1)) * 60 + float(m.group(2))
            text = m.group(3).strip()
            if text:
                lines.append((t, text))
    return lines


def stem(korean: str) -> str:
    """Dictionary form -> likely lyric stem (best effort)."""
    w = korean.rstrip("?!.")
    if w.endswith("하다"):
        return w[:-2]
    if len(w) > 1 and w.endswith("다"):
        return w[:-1]
    return w


def apply(song_path: str, track_id: str, offset: float):
    track = fetch(f"{API}/get/{track_id}")
    lrc = track.get("syncedLyrics")
    if not lrc:
        sys.exit("❌ track has no synced lyrics")
    lines = parse_lrc(lrc)
    print(f"🎵 {track['artistName']} - {track['trackName']} "
          f"({track.get('duration')}s, {len(lines)} lines, offset {offset:+g}s)")

    with open(song_path, encoding="utf-8") as f:
        song = json.load(f)

    matched = 0
    for word in song["words"]:
        s = stem(word["korean"])
        hit = next((t for t, text in lines if s in text), None)
        if hit is not None:
            word["timestamp"] = max(0, round(hit + offset, 1))
            matched += 1
        else:
            word["timestamp"] = None
            print(f"   · no match: {word['korean']}")

    # Keep card order aligned with playback: timed words first, by time.
    song["words"].sort(key=lambda w: (w["timestamp"] is None, w["timestamp"] or 0))

    with open(song_path, "w", encoding="utf-8") as f:
        json.dump(song, f, ensure_ascii=False, indent=2)
    print(f"✅ {matched}/{len(song['words'])} words timestamped → {song_path}")
    if matched < 10:
        print("⚠️  under 10 matches — song will stay unsynced (SYNC needs ≥10)")


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "search":
        search(" ".join(sys.argv[2:]))
    elif len(sys.argv) >= 4 and sys.argv[1] == "apply":
        offset = 0.0
        args = sys.argv[2:]
        if "--offset" in args:
            i = args.index("--offset")
            offset = float(args[i + 1])
            args = args[:i] + args[i + 2:]
        apply(args[0], args[1], offset)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
