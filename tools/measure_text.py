# -*- coding: utf-8 -*-
# 버튼 안 글자가 세로 어디에 찍히는지 스크린샷에서 직접 잰다.
#
# 왜 필요한가: Button 의 세로 중앙정렬은 폰트가 보고하는 높이를 쓰는데, 그 높이에는
# 이 도트 폰트가 실제로 안 쓰는 여백이 들어 있다. 눈대중으로 보정하면 반대로 넘친다.
# 여기서 나온 "어긋남" 값을 Ui.TEXT_NUDGE 에 부호 반대로 넣으면 된다.
#
#   godot --path . --rendering-method gl_compatibility --resolution 576x896 \
#         -- --autoshot --tab=growth
#   python tools/measure_text.py
import zlib
import struct
import os

SHOT = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata",
                    "Bloodlord", "autoshot.png")

# Main.gd 의 배치와 **같은 값**을 여기 적는다. 레이아웃을 고치면 여기도 고쳐야 한다 —
# 안 그러면 엉뚱한 자리를 재고 멀쩡한 화면에 보정값을 넣게 된다.
PANEL_Y = 480           # 하단 콘텐츠 창 시작 y
PAD = 26                # Main.PAD
CONTENT_W = 524         # Main.CONTENT_W
STEP_H = 40
GAP = 16
ROWS_Y = PAD + STEP_H + GAP     # 82
ROW_H = 60
BTN_W, BTN_H = 176, 48
STEP_W = (CONTENT_W - GAP * 2) / 3.0

BUTTONS = [
    # 이름, x, 창 안 y, 폭, 높이  (전부 픽셀)
    ("배수 x1", PAD, PAD, STEP_W, STEP_H),
    ("훈련 1행", 576 - PAD - BTN_W, ROWS_Y + (ROW_H - BTN_H) / 2.0, BTN_W, BTN_H),
]


def load(p):
    d = open(p, "rb").read()
    pos, idat = 8, b""
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", d[pos + 8:pos + 18])
        if typ == b"IDAT":
            idat += d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    raw = zlib.decompress(idat)
    bpp = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for y in range(h):
        f = raw[i]; i += 1
        line = bytearray(raw[i:i + stride]); i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(bytes(line)); prev = line
    return w, h, bpp, rows


W, H, BPP, ROWS = load(SHOT)


def ink_span(x0, y0, x1, y1, thr=150, min_px=2):
    """밝은 글자 픽셀이 있는 첫/마지막 행."""
    hit = []
    for y in range(max(0, y0), min(H, y1)):
        r = ROWS[y]
        n = 0
        for x in range(max(0, x0), min(W, x1)):
            o = x * BPP
            if (r[o] + r[o + 1] + r[o + 2]) / 3 > thr:
                n += 1
                if n >= min_px:
                    break
        if n >= min_px:
            hit.append(y)
    return (hit[0], hit[-1]) if hit else None


print("칸 안에서 글자가 세로로 어디에 찍히는가 (음수 = 위로 쏠림)")
for name, bx, by, bw, bh in BUTTONS:
    x0 = round(bx)
    y0 = round(PANEL_Y + by)
    x1 = x0 + round(bw)
    y1 = y0 + round(bh)
    span = ink_span(x0, y0, x1, y1)
    if span is None:
        print("  %-10s 글자를 못 찾음  (%d,%d)-(%d,%d)" % (name, x0, y0, x1, y1))
        continue
    box_h = y1 - y0
    top, bot = span[0] - y0, span[1] - y0
    off = (top + bot) / 2.0 - box_h / 2.0
    print("  %-10s 칸 %dpx | 잉크 %d..%d | 어긋남 %+.1f px  -> TEXT_NUDGE %+d"
          % (name, box_h, top, bot, off, round(-off)))
