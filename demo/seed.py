#!/usr/bin/env python3
"""把 seed-knowledge.json（16 篇校园知识）灌入 GraphRAG。
每篇用 id=source 逐篇 POST，按 id 幂等可重跑（重复灌入覆盖，不重复建节点）。
全新 Neo4j 直接跑本脚本即可灌满全部知识。
"""
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

BASE = os.environ.get("GRAPHRAG_BASE", "http://localhost:8011")
SEED_FILE = Path(__file__).resolve().parent / "seed-knowledge.json"


def _req(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=600) as resp:
        return json.loads(resp.read().decode())


def main():
    with open(SEED_FILE) as f:
        docs = json.load(f)["documents"]

    print(f"[plan] 待灌 {len(docs)} 篇", flush=True)
    ok = 0
    for i, d in enumerate(docs, 1):
        doc = {"id": d["source"], "title": d["title"],
               "content": d["content"], "source": d["source"]}
        t0 = time.time()
        try:
            res = _req("POST", "/index", {"documents": [doc]})
            dt = time.time() - t0
            print(f"[{i}/{len(docs)}] {d['source']:24s} ok={res} ({dt:.1f}s)", flush=True)
            ok += 1
        except Exception as e:
            print(f"[{i}/{len(docs)}] {d['source']:24s} FAILED: {e}", flush=True)

    print(f"[done] 成功 {ok}/{len(docs)} 篇", flush=True)


if __name__ == "__main__":
    sys.exit(main())
