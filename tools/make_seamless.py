# -*- coding: utf-8 -*-
# 배경을 가로로 진짜 이어지게(seamless) 만든다.
#
# 왜 필요한가: "좌우 끝에 같은 기둥을 그려라"는 프롬프트만으로는 두 끝의 하늘·산·
# 지면 높이가 정확히 안 맞아 이음매가 선으로 보인다. 프롬프트로는 못 없앤다.
#
# 방법: 오른쪽 끝 B열을 왼쪽 끝 B열 위에 램프로 겹쳐 섞고 오른쪽 B열을 잘라낸다.
#   new[x] = right[x]*(1 - x/B) + left[x]*(x/B)   (x < B)
#   new[x] = img[x]                               (x >= B)
# 새 오른쪽 끝(원본 W-B-1)과 새 왼쪽 끝(거의 원본 W-B)은 원본에서 원래 이웃이던
# 열이라 자연히 이어진다.
#
# **어디서 섞느냐가 전부다.** 큰 나무 위에서 섞으면 두 나무가 겹쳐 보이는
# 잔상(유령)이 남는다 — 처음에 그래서 실패했다. 그래서 섞기 전에 그림을 가로로
# 굴려(roll) **두 끝이 가장 비슷한 자리**를 찾는다. 보통 하늘이나 빈 바닥이라
# 섞어도 티가 안 난다.
#
#   python tools/make_seamless.py
import zlib
import struct
import os

BG = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  "assets", "bg")
BLEND = 24          # 섞는 폭(원본 px). 좁을수록 잔상이 적다
STEP = 4            # 굴림 후보 간격
NAMES = ["wide_graveyard", "wide_hell", "wide_glacier", "wide_sanctum", "wide_castle",
         "wide_maze", "wide_maze_deep", "wide_raid_blood", "wide_raid_essence",
         "wide_raid_pact", "wide_raid_hunt", "wide_raid_trial", "wide_abyss", "wide_ruins"]


def load(path):
    d = open(path, "rb").read()
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
        rows.append(bytearray(line)); prev = line
    return w, h, bpp, ct, rows


def save(path, w, h, bpp, ct, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b""))


def blend_cost(rows, h, bpp, w, r):
    """굴림 r 에서, 섞이게 될 두 열 묶음이 얼마나 다른가. 작을수록 잔상이 적다."""
    total = 0
    for y in range(0, h, 2):          # 두 줄 걸러 재도 순위는 안 바뀐다
        row = rows[y]
        for x in range(0, BLEND, 2):
            a = ((r + x) % w) * bpp
            b = ((r + w - BLEND + x) % w) * bpp
            total += (abs(row[a] - row[b]) + abs(row[a + 1] - row[b + 1])
                      + abs(row[a + 2] - row[b + 2]))
    return total


FINAL_W = 744          # 완성 폭. 이 폭이면 이미 이은 그림이다.


def seamless(name):
    src = os.path.join(BG, name + ".png")
    orig = os.path.join(BG, name + ".orig.png")
    # **이미 이은 그림은 건드리지 않는다.** 이 가드가 없어서 사고가 났다
    # (2026-08-12): `.orig` 를 지운 뒤 다시 돌리면 완성본을 원본으로 삼아
    # 24px 을 또 깎는다 — 배경 8장이 744 -> 720 -> 696 으로 줄어 있었고,
    # CombatRulesTest 의 규격 검사가 잡아냈다. git 에서 복구했다.
    # (bg-pipeline 스킬의 ".orig 지뢰"와 짝이다: 남겨도 문제, 지워도 문제였다.
    #  폭으로 판단하면 둘 다 안전하다.)
    if load(src)[0] <= FINAL_W:
        return None
    # 원본을 한 번만 보관한다. 두 번 돌려도 결과가 계속 좁아지지 않게.
    if not os.path.exists(orig):
        open(orig, "wb").write(open(src, "rb").read())
    w, h, bpp, ct, rows = load(orig)

    best_r, best_c = 0, None
    for r in range(0, w, STEP):
        c = blend_cost(rows, h, bpp, w, r)
        if best_c is None or c < best_c:
            best_r, best_c = r, c

    nw = w - BLEND
    out = []
    for y in range(h):
        r0 = rows[y]
        line = bytearray(nw * bpp)
        for x in range(nw):
            do = x * bpp
            so = ((best_r + x) % w) * bpp
            if x < BLEND:
                t = x / float(BLEND)
                ro = ((best_r + w - BLEND + x) % w) * bpp
                for c in range(bpp):
                    line[do + c] = int(round(r0[ro + c] * (1.0 - t) + r0[so + c] * t))
            else:
                line[do:do + bpp] = r0[so:so + bpp]
        out.append(line)
    save(src, nw, h, bpp, ct, out)
    return w, nw, h, best_r, best_c


if __name__ == "__main__":
    nw = 0
    for n in NAMES:
        if not os.path.exists(os.path.join(BG, n + ".png")):
            print("없음:", n)
            continue
        got = seamless(n)
        if got is None:
            print("%-16s skip (이미 이었다)" % n)
            continue
        w, nw, h, r, c = got
        print("%-16s %dx%d -> %dx%d | 굴림 %3d 에서 섞음(차이 %d)"
              % (n, w, h, nw, h, r, c))
    print("\nGrid.BG_SRC 의 가로를 %d 로 맞출 것." % nw)
