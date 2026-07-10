#!/usr/bin/env python3
"""Consolidate songs/*.json into app/assets/songs/ for the Flutter app.

Rules:
- Group files by normalized (artist, title).
- Within a group, prefer the file with >=10 timestamped words (sync version);
  otherwise the file with the most words.
- Skip files with no words or no youtubeId.
- Output: app/assets/songs/<id>.json + app/assets/songs/manifest.json
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Default (K-pop) src/dst; override with: consolidate_songs.py <src> <dst>
SRC = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "songs")
DST = ROOT / (sys.argv[2] if len(sys.argv) > 2 else "app/assets/songs")


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9가-힣ぁ-んァ-ヶ一-龯]", "", s.lower())


def added_order(path: Path) -> int:
    """Unix time the file was first added to git (recency signal for sorting).
    Uncommitted/new files sort newest via the file's mtime."""
    try:
        out = subprocess.run(
            ["git", "log", "--diff-filter=A", "--format=%ct", "--", str(path)],
            cwd=ROOT, capture_output=True, text=True, timeout=15,
        ).stdout.split()
        if out:
            return int(out[-1])  # earliest add commit
    except (subprocess.SubprocessError, ValueError, OSError):
        pass
    try:
        return int(path.stat().st_mtime)
    except OSError:
        return 0


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def has_sync(data) -> bool:
    words = data.get("words", [])
    ts_words = [w for w in words if w.get("timestamp") is not None]
    return len(ts_words) >= 10


def main():
    groups: dict[tuple, list] = {}
    skipped = []
    for path in sorted(SRC.glob("*.json")):
        data = load(path)
        if data is None:
            skipped.append((path.name, "invalid json"))
            continue
        words = data.get("words", [])
        if len(words) < 5 or not data.get("youtubeId"):
            skipped.append((path.name, f"{len(words)} words, yt={data.get('youtubeId', '')!r}"))
            continue
        key = (norm(data.get("artist", "")), norm(data.get("title", "")))
        groups.setdefault(key, []).append((path, data))

    DST.mkdir(parents=True, exist_ok=True)
    for old in DST.glob("*.json"):
        old.unlink()

    manifest = []
    for key, entries in sorted(groups.items()):
        synced = [e for e in entries if has_sync(e[1])]
        pool = synced if synced else entries
        path, data = max(pool, key=lambda e: len(e[1].get("words", [])))
        song_id = re.sub(r"-(sync|lyrics)$", "", path.stem)
        data["id"] = song_id
        (DST / f"{song_id}.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        manifest.append({
            "id": song_id,
            "title": data.get("title", ""),
            "artist": data.get("artist", ""),
            "youtubeId": data.get("youtubeId", ""),
            "synced": bool(synced),
            "wordCount": len(data.get("words", [])),
            # When this song was first added (git add time, unix seconds).
            # The app sorts by this descending so newest songs are on top.
            "order": added_order(path),
        })

    (DST / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"✅ {len(manifest)} songs → {DST.relative_to(ROOT)}")
    print(f"   synced: {sum(1 for m in manifest if m['synced'])}, "
          f"unsynced: {sum(1 for m in manifest if not m['synced'])}")
    if skipped:
        print(f"⚠️  skipped {len(skipped)}:")
        for name, reason in skipped:
            print(f"   - {name}: {reason}")


if __name__ == "__main__":
    main()
