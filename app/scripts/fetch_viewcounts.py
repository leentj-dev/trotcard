#!/usr/bin/env python3
"""manifest.json 의 모든 youtubeId 조회수를 yt-dlp로 수집해 viewcounts.json 에 저장.
{youtubeId: view_count}. build_manifest_cards.py 가 이 파일을 읽어 manifest 에 viewCount 를 실는다."""
import json
import os
import subprocess

HERE = os.path.dirname(__file__)
SONGS = os.path.join(HERE, "..", "assets", "songs")
OUT = os.path.join(HERE, "viewcounts.json")

manifest = json.load(open(os.path.join(SONGS, "manifest.json")))
vids = [e["youtubeId"] for e in manifest if e.get("youtubeId")]
urls = [f"https://www.youtube.com/watch?v={v}" for v in vids]

counts = {}
if os.path.exists(OUT):
    counts = json.load(open(OUT))

# 배치로 처리(한 프로세스). 실패한 영상은 건너뜀.
proc = subprocess.Popen(
    ["python3", "-m", "yt_dlp", "--no-warnings", "--ignore-errors",
     "--extractor-args", "youtube:player_client=android",
     "--print", "%(id)s\t%(view_count)s"] + urls,
    stdout=subprocess.PIPE, text=True,
)
done = 0
for line in proc.stdout:
    parts = line.strip().split("\t")
    if len(parts) == 2 and len(parts[0]) == 11:
        vid, vc = parts
        try:
            counts[vid] = int(vc)
        except ValueError:
            counts[vid] = 0
        done += 1
        if done % 20 == 0:
            json.dump(counts, open(OUT, "w"))
            print(f"  {done}/{len(vids)}")
proc.wait()
json.dump(counts, open(OUT, "w"), indent=0)
print(f"완료: {len(counts)}곡 조회수 저장")
