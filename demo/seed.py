#!/usr/bin/env python3
"""把 seed-knowledge.json 灌入 graphrag。
- 跳过已完整灌入的 3 篇（course/dorm/library）
- 删除残缺的 canteen 后重灌
- 每篇用 id=source，逐篇 POST，幂等可重跑
"""
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

BASE = os.environ.get("GRAPHRAG_BASE", "http://localhost:8001")
SEED_FILE = Path(__file__).resolve().parent / "seed-knowledge.json"
ALREADY_DONE = {"seed:course", "seed:dorm", "seed:library"}
OLD_CANTEEN_ID = "08a508a9-4973-4c2d-b0bd-148b0cf3bd72"


def _req(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=600) as resp:
        return json.loads(resp.read().decode())


def main():
    with open(SEED_FILE) as f:
        docs = json.load(f)["documents"]

    # 删除残缺 canteen
    try:
        print(f"[del] 删除残缺 canteen {OLD_CANTEEN_ID} ...", flush=True)
        print("      ->", _req("DELETE", f"/documents/{OLD_CANTEEN_ID}"), flush=True)
    except Exception as e:
        print("      删除失败（可能已不存在）:", e, flush=True)

    todo = [d for d in docs if d["source"] not in ALREADY_DONE]
    print(f"[plan] 待灌 {len(todo)} 篇，跳过已完成 {len(ALREADY_DONE)} 篇", flush=True)

    ok = 0
    for i, d in enumerate(todo, 1):
        doc = {"id": d["source"], "title": d["title"],
               "content": d["content"], "source": d["source"]}
        t0 = time.time()
        try:
            res = _req("POST", "/index", {"documents": [doc]})
            dt = time.time() - t0
            print(f"[{i}/{len(todo)}] {d['source']:24s} ok={res} ({dt:.1f}s)", flush=True)
            ok += 1
        except Exception as e:
            print(f"[{i}/{len(todo)}] {d['source']:24s} FAILED: {e}", flush=True)

    print(f"[done] 成功 {ok}/{len(todo)} 篇", flush=True)


if __name__ == "__main__":
    sys.exit(main())
