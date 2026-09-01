# -*- coding: utf-8 -*-
# 도감 스틸을 걷기 첫 프레임에서 만든다.
#   python tools/codex_stills.py            (검사만 — 빠진 것 목록)
#   python tools/codex_stills.py --write
#
# 왜 따로 있나: 도감은 `FoeTiers.sprite_of()` 가 가리키는
# `assets/enemies/<key>.png` **한 장**을 본다. 애니 폴더가 아니다 — 새 몹을
# 넣을 때 애니만 깔면 도감이 빈 칸으로 남는다. 실제로 10막 확장(2026-08-27)
# 에서 열다섯 종이 그렇게 빠졌고 `tests/GearTest` 가 잡았다.
#
# **전부 32x32 다**(기존 28장 실측 — 보스인 눈알 덩어리도 32). 64px 보스는
# 줄여서 넣는다. 줄일 때 NEAREST 를 쓴다 — 부드럽게 줄이면 도트가 뭉갠다.
import io
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "anim")
OUT = os.path.join(ROOT, "assets", "enemies")
SIZE = 32


def keys():
    ks = [a for a in sys.argv[1:] if not a.startswith("--")]
    if ks:
        return ks
    # 인자가 없으면 **FoeTiers.TIERS 에 적힌 몹 중** 스틸이 없는 것을 찾는다.
    # 애니 폴더를 훑으면 영웅 스킨(dragon·shadow…)과 보스 애니(boss_1…)까지
    # 잡힌다 — 도감이 요구하는 것은 그 표에 있는 키뿐이다(GearTest 233줄).
    tiers = os.path.join(ROOT, "FoeTiers.gd")
    body = io.open(tiers, encoding="utf-8").read()
    body = body[body.index("const TIERS"):body.index("static func")]
    ks = re.findall(r'^	"([a-z_0-9]+)":', body, re.M)
    return [k for k in ks
            if not os.path.exists(os.path.join(OUT, k + ".png"))]


def make(key, write):
    src = os.path.join(ANIM, key + "_walk", "0.png")
    if not os.path.exists(src):
        return "%-18s 걷기 0.png 이 없다" % key
    im = Image.open(src).convert("RGBA")
    if im.size != (SIZE, SIZE):
        # 잉크만 남기고 32 칸에 맞춘다 — 그냥 줄이면 여백까지 같이 줄어
        # 몹이 칸 안에서 작아 보인다.
        box = im.getbbox()
        if box:
            im = im.crop(box)
        w, h = im.size
        k = min(SIZE / float(w), SIZE / float(h))
        im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.NEAREST)
        pad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        # 가로는 가운데, 세로는 **아래 맞춤** — 도감 칸에서 발이 같은 줄에 선다.
        pad.paste(im, ((SIZE - im.width) // 2, SIZE - im.height), im)
        im = pad
    if write:
        im.save(os.path.join(OUT, key + ".png"))
    return "%-18s %s" % (key, "만듦" if write else "빠져 있음")


def main():
    write = "--write" in sys.argv
    ks = keys()
    if not ks:
        print("도감 스틸이 다 있다 — 손댈 것 없음")
        return
    for k in ks:
        print(make(k, write))
    if not write:
        print("\n검사만 했다. 실제로 만들려면 --write")


if __name__ == "__main__":
    main()
