# -*- coding: utf-8 -*-
# 스프라이트를 **발밑에 앉힌다**.
#   python tools/seat_sprites.py            (검사만)
#   python tools/seat_sprites.py --write    (실제로 옮긴다)
#
# 왜 필요한가: Foe._draw 는 **원점이 발밑**이라, PNG 아래쪽 투명 여백이 그대로
# "떠 있는 높이"가 된다. 그런데 그 여백은 화면에서 원본 px 이 아니라
# `여백 x 그려지는 높이 / 원본 높이` 만큼 커진다 — 32px 원본을 61px 로 그리는
# 몹이라면 여백 7px 이 화면에서는 13px 이다.
#
# 실측(2026-08-27): 기존 몹은 0~5px 뜨는데 PixelLab 로 새로 뽑은 것 일부가
# 8~13px 떴다. 사장님: "캐릭터랑 보스가 바닥보다 조금 위에있는것같아서".
#
# **한 유닛을 통째로 같은 만큼 옮긴다.** 프레임마다 여백을 0 으로 맞추면
# 걷기의 위아래 흔들림과 내려찍기의 눌림이 통째로 평평해진다 — 그건 애니를
# 죽이는 것이다. 그래서 그 유닛의 **모든 동작·모든 프레임 중 제일 낮은 것**을
# 기준으로 잡아 다 같이 내린다. 상대 높이차는 그대로 남는다.
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "anim")

# 기존 몹의 관례. 0 으로 붙이지 않는 이유: 그림자·발끝 한 줄이 잘려 보인다.
TARGET = 1
# 이만큼 넘게 뜬 유닛만 손댄다. 기존 최대가 3 이라 4 부터가 이상한 것이다.
TRIGGER = 4

MOTIONS = ("walk", "attack", "special")


def bottom_pad(a):
    rows = np.nonzero((a[..., 3] > 0).any(axis=1))[0]
    return None if len(rows) == 0 else a.shape[0] - 1 - int(rows.max())


def top_pad(a):
    rows = np.nonzero((a[..., 3] > 0).any(axis=1))[0]
    return None if len(rows) == 0 else int(rows.min())


def unit_frames(key):
    """이 유닛의 (경로, 이미지) 전부. 동작을 가리지 않는다 — 같이 옮겨야 한다."""
    out = []
    for m in MOTIONS:
        d = os.path.join(ANIM, "%s_%s" % (key, m))
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                p = os.path.join(d, f)
                out.append((p, np.asarray(Image.open(p).convert("RGBA"))))
    return out


# **대상을 명시한다.** 폴더를 훑으면 영웅 스킨(valentino·hawaii·shadow…)까지
# 잡히는데, 그건 Main 이 따로 그리는 것이라 여기 관례가 안 통한다. 눈알 덩어리
# (boss_4)처럼 **원래 떠 있는 게 맞는** 몹도 있다. 손댈 것만 인자로 받는다.
def units():
    ks = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not ks:
        sys.exit("고칠 유닛 키를 적어라: python tools/seat_sprites.py crystal_crab ...")
    return ks


def seat(key, write):
    fr = unit_frames(key)
    if not fr:
        return None
    pads = [bottom_pad(a) for _, a in fr]
    pads = [p for p in pads if p is not None]
    if not pads:
        return None
    low = min(pads)                      # 제일 낮게 내려온 프레임
    if low < TRIGGER:
        return None
    shift = low - TARGET
    # 위로 잘리면 안 된다. 머리 여유가 모자라면 그만큼만 내린다.
    head = min(top_pad(a) for _, a in fr if top_pad(a) is not None)
    shift = min(shift, head)
    if shift <= 0:
        return ("%-18s 여백 %d 인데 머리 여유가 %d — 못 내린다" % (key, low, head))
    if write:
        for p, a in fr:
            out = np.zeros_like(a)
            out[shift:, :, :] = a[: a.shape[0] - shift, :, :]
            Image.fromarray(out, "RGBA").save(p)
    return "%-18s 여백 %d -> %d  (%d px 내림, 머리 여유 %d, 프레임 %d장)" % (
        key, low, low - shift, shift, head, len(fr))


def main():
    write = "--write" in sys.argv
    hits = [seat(k, write) for k in units()]
    hits = [h for h in hits if h]
    if not hits:
        print("전부 관례(여백 %d 미만) 안이다 — 손댈 것 없음" % TRIGGER)
        return
    for h in hits:
        print(h)
    if not write:
        print("\n검사만 했다. 실제로 옮기려면 --write")


if __name__ == "__main__":
    main()
