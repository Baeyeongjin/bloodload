# -*- coding: utf-8 -*-
# 배경을 **지면 행이 늘 같도록** 세로로 잘라 낸다.
#   python tools/fit_ground.py          (make_seamless.py **앞에** 돌린다)
#
# 왜 필요한가: 화면의 지면선은 막이 바뀌어도 같은 높이여야 한다. 그런데 생성 결과는
# 지면이 그림마다 45~75% 사이 아무 데나 온다. 코드로 배경을 밀어서 맞추면 반대쪽에
# 빈 자리가 생기고, 그 자리를 메우려고 하늘 그라데이션·담 잇기 같은 보정이 다시 붙는다
# (그게 지워 달라던 그 띠다). **그림을 자르는 쪽이 맞다.**
#
# 그래서 배경은 여유 있게 320줄로 뽑고, 여기서 208줄 창을 지면 기준으로 떠낸다:
#
#     창 = [지면행 - ABOVE, 지면행 + BELOW)
#     ABOVE 145 x 2 = 290px  화면 위끝 ~ 지면선   (캐릭터가 서는 자리)
#     BELOW  63 x 2 = 126px  지면선 ~ 띠 아래끝  (보물상자·가이드가 앉는 자리)
#     합 208 x 2 = 416px = 전투 띠 전체
#
# 잘라 낸 뒤에는 모든 배경의 지면이 145행이므로 StageDefs 에 막마다 값을 적을 필요가
# 없다 — GROUND_ROW 하나로 끝난다.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_seamless import load, save, BG, NAMES   # PNG 입출력은 이미 있는 것을 쓴다

ABOVE = 145
BELOW = 63
OUT_H = ABOVE + BELOW


def ground_row(rows, w, h, bpp):
    """바닥 윗면이 몇 번째 행인가. 아래위 밝기 차가 가장 큰 자리다.

    **찾는 범위를 잘라 낼 창으로 묶는다.** 그림 전체에서 가장 대비가 큰 줄을
    고르면 엉뚱한 데를 잡는다 — 화형의 언덕은 맨 아래 불꽃 줄(313행)이 이겨서
    "320줄에서 못 뜬다"로 튕겼다. 어차피 지면은 [ABOVE, h-BELOW] 안에 있어야
    자를 수 있으니, 그 밖은 볼 이유도 없다.
    """
    lum = []
    for y in range(h):
        r = rows[y]
        s = 0
        for x in range(0, w, 2):        # 두 열 걸러 재도 순위는 안 바뀐다
            o = x * bpp
            s += 0.30 * r[o] + 0.59 * r[o + 1] + 0.11 * r[o + 2]
        lum.append(s / (w // 2))
    best, besty = -1.0, ABOVE
    for y in range(ABOVE, h - BELOW + 1):
        d = abs(lum[min(h - 1, y + 4)] - lum[max(0, y - 4)])
        if d > best:
            best, besty = d, y
    return besty


def fit(name):
    src = os.path.join(BG, name + ".png")
    w, h, bpp, ct, rows = load(src)
    if h == OUT_H:
        return "skip (이미 %d줄)" % OUT_H
    g = ground_row(rows, w, h, bpp)
    top = g - ABOVE
    if top < 0 or top + OUT_H > h:
        return ("NG 지면 %d행: 위 %d줄 / 아래 %d줄 이 필요한데 %d줄짜리 그림에서 못 뜬다"
                % (g, ABOVE, BELOW, h))
    save(src, w, OUT_H, bpp, ct, rows[top:top + OUT_H])
    return "지면 %3d행 -> %d줄 창 [%d, %d)" % (g, OUT_H, top, top + OUT_H)


if __name__ == "__main__":
    for n in NAMES:
        if not os.path.exists(os.path.join(BG, n + ".png")):
            print("없음:", n)
            continue
        print("%-16s %s" % (n, fit(n)))
    print("\n다음: *.orig.png 를 지우고 python tools/make_seamless.py")
