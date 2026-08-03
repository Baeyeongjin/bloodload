# -*- coding: utf-8 -*-
# 바닥 띠(돌벽)의 윗면이 원본 몇 번째 행인지 잰다.
# 방법: 아래에서 위로 올라가며 행 밝기가 급격히 밝아지는 지점 = 벽 위쪽 경계.
import zlib, struct, os
os.chdir(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "bg")))


def load(p):
    d = open(p, "rb").read(); pos = 8; idat = b""
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]; typ = d[pos + 4:pos + 8]
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", d[pos + 8:pos + 18])
        if typ == b"IDAT":
            idat += d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    raw = zlib.decompress(idat); bpp = {0: 1, 2: 3, 4: 2, 6: 4}[ct]; stride = w * bpp
    rows = []; prev = bytearray(stride); i = 0
    for y in range(h):
        f = raw[i]; i += 1; line = bytearray(raw[i:i + stride]); i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c; pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(bytes(line)); prev = line
    return w, h, bpp, rows


def lum(rows, bpp, w, y):
    r = rows[y]; s = 0
    for x in range(w):
        o = x * bpp
        s += 0.30 * r[o] + 0.59 * r[o + 1] + 0.11 * r[o + 2]
    return s / w


for n in ["wide_graveyard", "wide_hell", "wide_glacier", "wide_sanctum", "wide_castle"]:
    w, h, bpp, rows = load(n + ".png")
    ls = [lum(rows, bpp, w, y) for y in range(h)]
    # 아래 절반에서 위아래 밝기 차가 가장 큰 행 = 지면 경계
    best, besty = 0.0, h - 30
    for y in range(h // 2, h - 6):
        d = abs(ls[y + 4] - ls[y - 4])
        if d > best:
            best, besty = d, y
    print("%-16s ground_row=%3d  (screen y = 160 + %d = %d)  delta=%.1f"
          % (n, besty, besty * 2, 160 + besty * 2, best))
