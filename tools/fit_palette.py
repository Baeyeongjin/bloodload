"""생성된 이펙트 프레임을 **게임의 피 계열 팔레트**로 맞춘다.

왜 필요한가: PixelLab 이 주황·노랑·뼈흰색을 섞어 내놓는다. 이 게임은 원소가 없고
전부 피(붉은) 계열이라(DESIGN 2-2c) 그대로 넣으면 그 한 종만 톤이 튄다. 실측:

    기존 이펙트   아가리 20%  ·  감시의 눈 0%  ·  뱀 1%   (붉지 않은 색 비율)
    2026-08-10 생성  아가리 75%  ·  눈 71%  ·  뱀 30%

프롬프트로는 안 잡힌다(색을 지정해도 모델이 하이라이트를 제 맘대로 넣는다).
**뽑은 뒤 코드로 맞추는 쪽이 확실하고 공짜다.**

기준 팔레트는 `assets/anim/fx_sk_*` 에서 직접 읽는다 — 표를 따로 적으면 자산과
갈린다. 붉지 않은 색(채도 있고 색상환 30~330도)은 기준에서 뺀다: 기존 자산에도
20% 쯤 섞여 있어서 그대로 두면 "맞출 대상"에 오염된 색이 들어간다.

    python tools/fit_palette.py <입력폴더> <출력폴더>

같은 폴더를 두 번 주면 제자리에서 바꾼다. 알파는 안 건드린다 — 모양은 생성물 그대로고
색만 옮긴다.
"""
import colorsys
import os
import sys
from PIL import Image

FX_DIR = "assets/anim"


def _is_red(rgb):
    """붉은 계열인가. 채도가 낮으면(회색·검정) 톤을 안 깨므로 통과시킨다."""
    r, g, b = rgb
    mx, mn = max(r, g, b), min(r, g, b)
    sat = 0.0 if mx == 0 else (mx - mn) / mx
    if sat < 0.25:
        return True
    hue = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)[0] * 360.0
    return hue <= 30.0 or hue >= 330.0


def game_palette(root="."):
    """기존 스킬 이펙트에서 쓰는 붉은 계열 색 전부."""
    out = set()
    base = os.path.join(root, FX_DIR)
    for name in os.listdir(base):
        if not name.startswith("fx_sk_"):
            continue
        first = os.path.join(base, name, "0.png")
        if not os.path.exists(first):
            continue
        im = Image.open(first).convert("RGBA")
        w, h = im.size
        px = im.load()
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if p[3] >= 128 and _is_red(p[:3]):
                    out.add(p[:3])
    return sorted(out)


def fit(src_dir, dst_dir, palette):
    os.makedirs(dst_dir, exist_ok=True)
    cache = {}

    def near(c):
        if c not in cache:
            cache[c] = min(palette, key=lambda q:
                (q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 + (q[2] - c[2]) ** 2)
        return cache[c]

    names = sorted((f for f in os.listdir(src_dir) if f.endswith(".png")),
                   key=lambda f: int(os.path.splitext(f)[0]))
    moved = 0
    total = 0
    for name in names:
        im = Image.open(os.path.join(src_dir, name)).convert("RGBA")
        w, h = im.size
        px = im.load()
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        op = out.load()
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if p[3] == 0:
                    continue
                total += 1
                if _is_red(p[:3]):
                    op[x, y] = p
                    continue
                c = near(p[:3])
                op[x, y] = (c[0], c[1], c[2], p[3])
                moved += 1
        out.save(os.path.join(dst_dir, name))
    return len(names), moved, total


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    palette = game_palette()
    if not palette:
        print("기준 팔레트를 못 읽었다 — 저장소 루트에서 돌려야 한다")
        return 1
    n, moved, total = fit(src, dst, palette)
    print("기준 팔레트 %d색 · %d프레임 · 옮긴 픽셀 %d / %d (%.0f%%)"
          % (len(palette), n, moved, total, 100.0 * moved / max(1, total)))
    return 0


def _demo():
    """자체 점검: 붉지 않은 색은 반드시 붉은 색으로 옮겨지고, 알파는 안 변한다."""
    assert _is_red((200, 20, 30)), "진한 빨강이 붉은 계열이 아니라고 나온다"
    assert _is_red((40, 38, 42)), "채도 낮은 회색은 통과해야 한다"
    assert not _is_red((40, 120, 220)), "파랑이 붉은 계열로 나온다"
    assert not _is_red((240, 200, 40)), "노랑이 붉은 계열로 나온다"
    pal = [(150, 20, 30), (60, 8, 12)]
    got = min(pal, key=lambda q: sum((a - b) ** 2 for a, b in zip(q, (240, 200, 40))))
    assert _is_red(got), "옮긴 결과가 붉은 계열이 아니다"
    print("fit_palette self-check OK")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--demo":
        _demo()
    else:
        sys.exit(main())
