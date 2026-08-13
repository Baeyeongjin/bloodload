# -*- coding: utf-8 -*-
# 모션 폴더의 프레임을 통째로 좌우 반전한다.
#   python flip.py plague_hag_walk blood_queen_attack ...
# 원본은 **왼쪽을 봐야 한다** — Foe 가 오른쪽으로 갈 때만 flip_h 로 뒤집으므로,
# 원본이 오른쪽을 보면 화면에서 몹이 영웅에게 등을 돌린다(사장님 2026-08-13).
import sys, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "anim")
for name in sys.argv[1:]:
    d = os.path.join(ANIM, name)
    n = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        p = os.path.join(d, f)
        Image.open(p).transpose(Image.FLIP_LEFT_RIGHT).save(p)
        n += 1
    print(name, n)
