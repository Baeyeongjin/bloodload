# -*- coding: utf-8 -*-
# 모션 폴더의 프레임을 통째로 좌우 반전한다.
#   python flip.py plague_hag_walk blood_queen_attack ...
# 원본은 **왼쪽을 봐야 한다** — Foe 가 오른쪽으로 갈 때만 flip_h 로 뒤집으므로,
# 원본이 오른쪽을 보면 화면에서 몹이 영웅에게 등을 돌린다(사장님 2026-08-13).
import sys, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "anim")
# 모션 전체:  plague_hag_walk
# 일부 프레임: plague_hag_attack:0,1,2,3,4,8
# **생성기가 한 모션 안에서도 방향을 섞는다** — 프레임 단위로 짚어야 고쳐진다.
for arg in sys.argv[1:]:
    name, _, want = arg.partition(":")
    idxs = None if not want else set(int(i) for i in want.split(","))
    d = os.path.join(ANIM, name)
    n = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        if idxs is not None and int(os.path.splitext(f)[0]) not in idxs:
            continue
        fp = os.path.join(d, f)
        Image.open(fp).transpose(Image.FLIP_LEFT_RIGHT).save(fp)
        n += 1
    print(name, n)
