# 캐릭터 스킨을 **팔레트 치환**으로 만든다.
#
# 왜 생성 모델을 안 쓰나: 지금 캐릭터는 모션 12종 x 9프레임 = 108장이다.
# 그걸 img2img 로 다시 뽑으면 프레임마다 그림이 미묘하게 달라져 **모션이
# 깨진다**(걷다가 옷이 펄럭이는 게 아니라 옷이 매 프레임 바뀐다).
# 팔레트 치환은 108장에 같은 규칙을 적용하므로 움직임이 그대로 남는다.
#
#     python tools/make_skin.py            # 전 스킨을 만든다
#     python tools/make_skin.py --preview  # idle 첫 프레임만 미리보기 한 장
import os
import sys
from PIL import Image

SRC = "valentino_1"
ANIM = "assets/anim"
HERO = "assets/hero"

# 원본 의상 색 셋(망토·옷). 실측으로 뽑았다 — 32색 중 이 셋이 붉은 의상이다.
CLOTH = [(0x52, 0x16, 0x25), (0x4E, 0x10, 0x20), (0x40, 0x13, 0x17)]

# 스킨 = 그 셋을 무엇으로 바꾸는가. 밝은 순서(하이라이트·중간·그림자)를 지킨다 —
# 순서가 뒤집히면 옷의 입체가 뒤집혀 평평해 보인다.
# [의상 3색, 머리 장식]. 장식이 실루엣을 바꾼다 — 색만으로는 약하다(사장님).
SKINS = {
    "valentino_silver": ([(0x8A, 0x92, 0xA8), (0x5C, 0x64, 0x78), (0x3A, 0x40, 0x50)], "plume"),
    "valentino_gold":   ([(0xC8, 0x9B, 0x3C), (0x96, 0x70, 0x22), (0x5E, 0x45, 0x14)], "crown"),
    "valentino_abyss":  ([(0x5B, 0x3A, 0x8C), (0x3E, 0x27, 0x62), (0x26, 0x17, 0x3E)], "horns"),
    "valentino_plague": ([(0x5E, 0x8C, 0x3A), (0x3F, 0x62, 0x26), (0x25, 0x3E, 0x17)], "hood"),
}


# ── 실루엣 (사장님: 색만으로는 약하다) ──────────────────────────────────────
# 108장을 손으로 고칠 수는 없으니 **머리를 찾아 얹는다**: 프레임마다 불투명
# 픽셀의 꼭대기와 그 줄의 가로 중심을 재서, 그 자리에 장식을 합성한다.
# 규칙이 하나라 모든 프레임이 같이 움직인다 — 생성 모델로 뽑으면 프레임마다
# 장식 모양이 달라져 깜빡인다.
#
# 장식은 문자 그림으로 적는다(. 은 비움). 도트 몇 픽셀은 코드로 그리는 쪽이
# 그림판보다 정확하고, 색을 스킨 표에서 그대로 가져다 쓸 수 있다.
CRESTS = {
    # 왕관 — 가운데가 높은 톱니.
    "crown": [
        ".1...1...1.",
        ".1.1.1.1.1.",
        ".1111111111",
        ".0000000000",
    ],
    # 뿔 — 양옆에서 위로 굽는다. 가운데는 비워 머리가 보이게.
    "horns": [
        "1.........1",
        ".1.......1.",
        ".1.......1.",
        "..0.....0..",
    ],
    # 투구 깃 — 위로 솟은 한 줄.
    "plume": [
        ".....1.....",
        ".....1.....",
        "....101....",
        "..0011100..",
    ],
    # 후드 뿔 — 낮고 뭉툭하게 둘.
    "hood": [
        "..1.....1..",
        "..1.....1..",
        ".011...110.",
        "00000.00000",
    ],
}


# 살색 — 얼굴을 찾는 열쇠다. **최상단 불투명 픽셀로는 못 찾는다**: 지팡이가
# 머리보다 위로 뻗어 있어서 그걸 머리로 잡고 장식을 허공에 그렸다(실측).
SKIN_TONE = [(0xAA, 0x8D, 0x76), (0xD3, 0xB5, 0x9D)]


def head_anchor(im):
    """얼굴 꼭대기 (x 중심, y). 살색이 처음 나오는 줄이 이마다."""
    px = im.load()
    for y in range(im.height):
        xs = [x for x in range(im.width)
              if px[x, y][3] > 40 and px[x, y][:3] in SKIN_TONE]
        if xs:
            return (sum(xs) // len(xs), y)
    return None


def add_crest(im, kind, table):
    """머리 위에 장식을 얹는다. 1=밝은 색, 0=그림자 색(스킨 표에서 가져온다)."""
    art = CRESTS.get(kind)
    if not art:
        return im
    at = head_anchor(im)
    if at is None:
        return im
    cx, top = at
    w = len(art[0])
    px = im.load()
    for row, line in enumerate(art):
        y = top - len(art) + row + 2
        if y < 0:
            continue
        for col, ch in enumerate(line):
            if ch == ".":
                continue
            x = cx - w // 2 + col
            if not (0 <= x < im.width):
                continue
            px[x, y] = (table[0] if ch == "1" else table[2]) + (255,)
    return im


def recolor(im, table):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for i, src in enumerate(CLOTH):
                if (r, g, b) == src:
                    px[x, y] = table[i] + (a,)
                    break
    return im


def build(name, table, crest):
    n = 0
    for entry in os.listdir(ANIM):
        if not entry.startswith(SRC + "_"):
            continue
        motion = entry[len(SRC) + 1:]
        out_dir = "%s/%s_%s" % (ANIM, name, motion)
        os.makedirs(out_dir, exist_ok=True)
        for f in os.listdir("%s/%s" % (ANIM, entry)):
            if not f.endswith(".png"):
                continue
            im = Image.open("%s/%s/%s" % (ANIM, entry, f))
            add_crest(recolor(im, table), crest, table).save("%s/%s" % (out_dir, f))
            n += 1
    # 초상화·카드에 쓰는 정지 그림도 같이.
    im = Image.open("%s/%s.png" % (HERO, SRC))
    add_crest(recolor(im, table), crest, table).save("%s/%s.png" % (HERO, name))
    print("%-20s %3d 프레임" % (name, n))


def preview():
    """네 스킨의 idle 첫 프레임을 한 줄로 이어 붙인다 — 고르기 위한 그림."""
    base = Image.open("%s/%s_idle/0.png" % (ANIM, SRC)).convert("RGBA")
    w, h = base.size
    sheet = Image.new("RGBA", (w * (len(SKINS) + 1), h), (0, 0, 0, 0))
    sheet.paste(base, (0, 0))
    for i, (name, (table, crest)) in enumerate(SKINS.items()):
        sheet.paste(add_crest(recolor(base.copy(), table), crest, table),
                    (w * (i + 1), 0))
    sheet = sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST)
    sheet.save("skin_preview.png")
    print("skin_preview.png — 왼쪽부터 원본 · " + " · ".join(SKINS))


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview()
    else:
        for name, (table, crest) in SKINS.items():
            build(name, table, crest)
