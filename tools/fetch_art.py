# -*- coding: utf-8 -*-
# PixelLab 생성 결과를 프로젝트로 내려받는다.
#   python tools/fetch_art.py <job_id> <저장경로(프로젝트 기준)>
# 예) python tools/fetch_art.py 5694... assets/bg/act_graveyard.png
#
# 이미 있으면 건너뛴다 — 생성은 이미 끝나 있어 여러 번 돌려도 비용이 안 든다.
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fetch(job_id: str, rel_path: str) -> bool:
    dest = os.path.join(ROOT, rel_path.replace("/", os.sep))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print("skip (있음):", rel_path)
        return True
    url = "https://api.pixellab.ai/mcp/images/%s/download" % job_id
    with urllib.request.urlopen(url, timeout=60) as r:
        data = r.read()
    if len(data) < 200:
        print("아직 안 됨:", job_id)
        return False
    open(dest, "wb").write(data)
    print("받음: %s (%d bytes)" % (rel_path, len(data)))
    return True


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(0 if fetch(sys.argv[1], sys.argv[2]) else 1)
