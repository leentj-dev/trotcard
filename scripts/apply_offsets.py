#!/usr/bin/env python3
"""Apply user-submitted sync offsets to song JSONs.

The app's "Export sync offsets" button copies lines like:
    akmu-somune-nagwon: 12.0
    yoasobi-idol: 3.5

Paste those into a file (or pipe via stdin) and run this; it sets
`introOffset` on the matching source song JSON in songs/ or songs_jpop/.
Then run consolidate_songs.py for the affected pack(s) and push.

Usage:
    python3 scripts/apply_offsets.py offsets.txt
    pbpaste | python3 scripts/apply_offsets.py -
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIRS = [ROOT / "songs", ROOT / "songs_jpop"]


def norm_stem(path: Path) -> str:
    return re.sub(r"-(sync|lyrics)$", "", path.stem)


def find_file(song_id: str):
    for d in SRC_DIRS:
        if not d.exists():
            continue
        for f in d.glob("*.json"):
            if norm_stem(f) == song_id:
                return f
            try:
                if json.loads(f.read_text(encoding="utf-8")).get("id") == song_id:
                    return f
            except (json.JSONDecodeError, OSError):
                continue
    return None


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw = sys.stdin.read() if sys.argv[1] == "-" else Path(sys.argv[1]).read_text()

    applied, missing = [], []
    for line in raw.splitlines():
        line = line.strip()
        m = re.match(r"^(.+?):\s*(-?\d+(?:\.\d+)?)\s*$", line)
        if not m:
            continue
        song_id, value = m.group(1).strip(), float(m.group(2))
        f = find_file(song_id)
        if f is None:
            missing.append(song_id)
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        if value == 0:
            data.pop("introOffset", None)
        else:
            data["introOffset"] = value
        f.write_text(json.dumps(data, ensure_ascii=False, indent=2),
                     encoding="utf-8")
        applied.append(f"{song_id} -> {value} ({f.parent.name}/{f.name})")

    print(f"✅ applied {len(applied)}:")
    for a in applied:
        print("  ", a)
    if missing:
        print(f"⚠️  not found {len(missing)}: {', '.join(missing)}")
    print("\nNext: python3 scripts/consolidate_songs.py "
          "&& python3 scripts/consolidate_songs.py songs_jpop app/assets/songs_jpop")


if __name__ == "__main__":
    main()
