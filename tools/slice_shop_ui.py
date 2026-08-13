# 상점 UI 시트를 조각 png 로 자른다. PixelLab ui_asset 은 조각들을 한 장에
# 그려 주므로, 알파 행/열 투영으로 띄어진 덩어리를 찾아 개별 저장한다.
# 재뽑기가 잦아서 도구로 둔다 — 시트가 바뀌면 그냥 다시 돌리면 된다.
import sys
from PIL import Image

BASE = "assets/ui/shop"


def bands(mask, along):
    """along=0: 행 투영(세로 분할), along=1: 열 투영(가로 분할). (시작, 끝) 목록."""
    size = mask.size[1 - along]
    other = mask.size[along]
    px = mask.load()
    filled = []
    for i in range(size):
        # PIL 은 px[x, y] — 행 투영(i=y)이면 j 가 x 다.
        row_has = any(
            (px[j, i] if along == 0 else px[i, j]) > 8 for j in range(other))
        filled.append(row_has)
    out = []
    start = None
    for i, f in enumerate(filled):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, size))
    return out


def crop_trim(im, box):
    part = im.crop(box)
    a = part.getchannel("A")
    bb = a.getbbox()
    return part.crop(bb) if bb else part


def slice_v(im, names):
    """세로로 쌓인 조각들 — 행 투영으로."""
    a = im.getchannel("A")
    rows = bands(a, along=0)
    assert len(rows) == len(names), f"{len(names)}조각이어야 하는데 {len(rows)}개"
    for (y0, y1), name in zip(rows, names):
        crop_trim(im, (0, y0, im.width, y1)).save(f"{BASE}/{name}.png")
        print(name, "ok")


def main():
    # 세로 카드: 제목 띠 / 그림 창 / 가격 띠
    slice_v(Image.open(f"{BASE}/card_v.png").convert("RGBA"),
            ["card_title", "card_art", "card_price"])

    # 와이드: 리본 / 카드 몸 / 알약
    slice_v(Image.open(f"{BASE}/card_w.png").convert("RGBA"),
            ["ribbon", "wide_body", "pill"])

    # 배지 시트: 위(배지·도장) / 아래(자물쇠·탭2) — 밴드 안에서 열 투영으로.
    im = Image.open(f"{BASE}/badges.png").convert("RGBA")
    a = im.getchannel("A")
    rows = bands(a, along=0)
    assert len(rows) >= 2, f"배지 시트 행이 {len(rows)}개"
    top, bottom = rows[0], rows[-1]

    top_im = im.crop((0, top[0], im.width, top[1]))
    cols = bands(top_im.getchannel("A"), along=1)
    assert len(cols) == 2, f"윗줄 열이 {len(cols)}개"
    crop_trim(top_im, (cols[0][0], 0, cols[0][1], top_im.height)).save(
        f"{BASE}/badge_star.png")
    crop_trim(top_im, (cols[1][0], 0, cols[1][1], top_im.height)).save(
        f"{BASE}/stamp_soldout.png")

    bot_im = im.crop((0, bottom[0], im.width, bottom[1]))
    cols = bands(bot_im.getchannel("A"), along=1)
    assert len(cols) == 2, f"아랫줄 열이 {len(cols)}개"
    crop_trim(bot_im, (cols[0][0], 0, cols[0][1], bot_im.height)).save(
        f"{BASE}/lock.png")
    right = bot_im.crop((cols[1][0], 0, cols[1][1], bot_im.height))
    tabs = bands(right.getchannel("A"), along=0)
    assert len(tabs) == 2, f"탭이 {len(tabs)}개"
    crop_trim(right, (0, tabs[0][0], right.width, tabs[0][1])).save(
        f"{BASE}/tab_on.png")
    crop_trim(right, (0, tabs[1][0], right.width, tabs[1][1])).save(
        f"{BASE}/tab_off.png")
    print("badges ok")


if __name__ == "__main__":
    main()
