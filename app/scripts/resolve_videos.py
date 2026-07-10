#!/usr/bin/env python3
"""곡 리스트(title|artist)에 대해 유튜브에서 **임베드 가능한 최고 조회수** 영상을 찾는다.

- yt-dlp ytsearch 로 후보 + 조회수를 받아 조회수 내림차순 정렬.
- 연속듣기/메들리/모음/노래방/MR 등 곡이 아닌 것은 건너뜀(가능하면).
- 각 후보를 oEmbed(HTTP 200)로 임베드 가능 여부 확인 → 첫 임베드 가능 채택.
- 출력(stdout): "<videoId>|<artist> - <title>"  (gen_program_songs.py 입력 형식)
- 못 찾은 곡은 stderr 에 "MISS ..." 로 남긴다.

사용: python3 resolve_videos.py <list.txt>  > out.txt
list.txt 각 줄: "<title>|<artist>"
"""
import subprocess
import sys
import urllib.error
import urllib.request

BAD = ["연속", "메들리", "메드리", "모음", "히트곡", "전곡", "노래방", "1시간",
       "mix", "Mix", "MIX", "반주", " MR", "(MR", "Inst", "inst", "cover", "Cover",
       "커버", "LIVE", "live", "직캠", "reaction", "리액션", "shorts", "Shorts"]


def search(query, n=8):
    try:
        out = subprocess.run(
            ["python3", "-m", "yt_dlp", f"ytsearch{n}:{query}",
             "--flat-playlist", "--no-warnings",
             "--print", "%(id)s\t%(view_count)s\t%(title)s"],
            capture_output=True, text=True, timeout=90,
        )
    except Exception:
        return []
    rows = []
    for line in out.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 3 and len(parts[0]) == 11:
            try:
                vc = int(parts[1])
            except ValueError:
                vc = 0
            rows.append((parts[0], vc, parts[2]))
    return rows


def embeddable(vid):
    url = (f"https://www.youtube.com/oembed?url="
           f"https://www.youtube.com/watch?v={vid}&format=json")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=12) as r:
            return r.status == 200
    except Exception:
        return False


def is_single(title):
    return not any(b in title for b in BAD)


def resolve(title, artist):
    cands = search(f"{artist} {title}")
    cands.sort(key=lambda x: -x[1])
    # 1순위: 곡으로 보이는 것 중 조회수 높은 임베드 가능
    for vid, vc, t in cands:
        if is_single(t) and embeddable(vid):
            return vid, vc, t
    # 2순위: 필터 무시, 조회수 높은 임베드 가능
    for vid, vc, t in cands:
        if embeddable(vid):
            return vid, vc, t
    return None


def main():
    for line in open(sys.argv[1], encoding="utf-8"):
        line = line.strip()
        if not line or "|" not in line:
            continue
        title, artist = line.split("|", 1)
        title, artist = title.strip(), artist.strip()
        pick = resolve(title, artist)
        if pick:
            sys.stdout.write(f"{pick[0]}|{artist} - {title}\n")
            sys.stdout.flush()
            sys.stderr.write(f"OK  {artist} - {title}  ({pick[1]:,}뷰) {pick[0]}\n")
        else:
            sys.stderr.write(f"MISS {artist} - {title}\n")


if __name__ == "__main__":
    main()
